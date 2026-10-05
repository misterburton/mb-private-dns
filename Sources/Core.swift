import Foundation
import SystemConfiguration
import Darwin

let appPath = "/Applications/Private DNS.app"
let dataPath = "/Library/Application Support/Private DNS"
let socketPath = "/var/run/local.private-dns.sock"
let daemonLabel = "local.private-dns.resolver"
let packageID = "local.private-dns.package"

struct RunResult { var code: Int32; var text: String }
func run(_ executable: String, _ arguments: [String]) -> RunResult {
    let task = Process(), pipe = Pipe()
    task.executableURL = URL(fileURLWithPath: executable); task.arguments = arguments
    task.standardOutput = pipe; task.standardError = pipe
    do { try task.run() } catch { return RunResult(code: 1, text: error.localizedDescription) }
    let bytes = pipe.fileHandleForReading.readDataToEndOfFile(); task.waitUntilExit()
    return RunResult(code: task.terminationStatus, text: String(decoding: bytes, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
}
func error(_ message: String) -> NSError { NSError(domain: "PrivateDNS", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
func readPlist(_ path: String) throws -> [String: Any] {
    try PropertyListSerialization.propertyList(from: Data(contentsOf: URL(fileURLWithPath: path)), format: nil) as? [String: Any] ?? [:]
}
func writePlist(_ value: [String: Any], _ path: String) throws {
    let bytes = try PropertyListSerialization.data(fromPropertyList: value, format: .xml, options: 0)
    try bytes.write(to: URL(fileURLWithPath: path), options: .atomic)
    chmod(path, 0o600)
}
func bootID() -> String { run("/usr/sbin/sysctl", ["-n", "kern.bootsessionuuid"]).text }
func servers(_ config: [String: Any]) -> [String] { config["ServerAddresses"] as? [String] ?? [] }
func isOurs(_ config: [String: Any]) -> Bool { servers(config) == ["127.0.0.1"] }

// Read the complete resolver snapshot. Domain-specific and interface-scoped
// resolvers are not interchangeable with the default resolver (resolver(5)).
struct ResolverEntry {
    var domain = ""
    var addresses: [String] = []
    var scoped = false
    var supplemental = false
    var multicast = false
    var unavailable = false
    var port = 53
    var isDefault: Bool { !scoped && !multicast && (domain == "." || (!supplemental && domain.isEmpty)) }
    var isPrivateDNS: Bool { addresses == ["127.0.0.1"] && port == 53 }
    var isTailscale: Bool {
        !addresses.isEmpty && port == 53 && addresses.allSatisfy {
            ["100.100.100.100", "fd7a:115c:a1e0::53"].contains($0.lowercased())
        }
    }
}

struct DNSRouting {
    let owner: String // private-dns, tailscale, other, mixed, unknown
    let splitDNS: Bool
    let scopedDNS: Bool
    let tailscalePresent: Bool
    let tailscaleCoexistence: Bool

    init(output: String, succeeded: Bool) {
        var entries: [ResolverEntry] = []
        var entry: ResolverEntry?
        var scopedSection = false
        for raw in output.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("DNS configuration") {
                if let current = entry { entries.append(current); entry = nil }
                scopedSection = line != "DNS configuration"
            } else if line.hasPrefix("resolver #") {
                if let current = entry { entries.append(current) }
                entry = ResolverEntry(scoped: scopedSection)
            } else if let colon = line.firstIndex(of: ":"), entry != nil {
                let key = line[..<colon].trimmingCharacters(in: .whitespaces)
                let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                if key == "domain" { entry?.domain = value }
                else if key.hasPrefix("nameserver[") { entry?.addresses.append(value) }
                else if key == "flags" {
                    entry?.scoped = scopedSection || value.contains("Scoped") || value.contains("Service-specific")
                    entry?.supplemental = value.contains("Supplemental")
                } else if key == "options" { entry?.multicast = value.split(separator: " ").contains("mdns") }
                else if key == "reach" { entry?.unavailable = value.contains("Not Reachable") }
                else if key == "port" { entry?.port = Int(value) ?? -1 }
            }
        }
        if let current = entry { entries.append(current) }
        let defaults = entries.filter(\.isDefault)
        splitDNS = entries.contains { !$0.scoped && !$0.isDefault && !$0.multicast && !$0.addresses.isEmpty && !$0.isPrivateDNS }
        scopedDNS = entries.contains { $0.scoped && !$0.multicast && !$0.unavailable && !$0.addresses.isEmpty && !$0.isPrivateDNS }
        tailscalePresent = entries.contains(where: \.isTailscale)
        if !succeeded || defaults.isEmpty || defaults.contains(where: { $0.addresses.isEmpty || $0.unavailable }) {
            owner = "unknown"
        } else if defaults.allSatisfy(\.isPrivateDNS) { owner = "private-dns" }
        else if defaults.allSatisfy(\.isTailscale) { owner = "tailscale" }
        else if defaults.contains(where: { $0.addresses.contains("127.0.0.1") || $0.isTailscale }) { owner = "mixed" }
        else { owner = "other" }
        // A known Tailscale route is informational while our default is intact.
        // Its presence must never conceal another active interface resolver.
        tailscaleCoexistence = owner == "private-dns"
            && entries.contains { $0.isTailscale && !$0.unavailable }
            && !entries.contains { $0.scoped && !$0.multicast && !$0.unavailable
                && !$0.addresses.isEmpty && !$0.isPrivateDNS && !$0.isTailscale }
    }

    func mode(enabled: Bool, healthy: Bool, conflicts: [String], error: String) -> String {
        if !error.isEmpty { return "attention" }
        if !enabled { return "paused" }
        if !healthy || !conflicts.isEmpty { return "attention" }
        if owner == "tailscale" { return "managed" }
        if owner == "private-dns" && (!scopedDNS || tailscaleCoexistence) { return "on" }
        return "attention"
    }
}

// One grace period per service launch, measured with a monotonic clock.
struct ResolverReadiness {
    let began: TimeInterval
    var healthy = false
    var succeeded = false
    var failed = false
    var lastCheck: TimeInterval?
    func isStarting(now: TimeInterval) -> Bool {
        !succeeded && !failed && now - began < 30
    }
    func checkDue(now: TimeInterval) -> Bool {
        guard let lastCheck else { return true }
        return now - lastCheck >= (succeeded ? 30 : 5)
    }
    mutating func record(healthy: Bool, now: TimeInterval) {
        self.healthy = healthy
        succeeded = succeeded || healthy
        lastCheck = now
    }
    func mode(_ normal: String, enabled: Bool, error: String, conflicts: [String], owner: String, now: TimeInterval, routingReady: Bool = true) -> String {
        if normal == "attention" && enabled && error.isEmpty && conflicts.isEmpty
            && routingReady && ["private-dns", "tailscale"].contains(owner) && isStarting(now: now) { return "starting" }
        return normal
    }
}

struct DNSService {
    let id: String
    let name: String
    let reference: SCNetworkService
    let existed: Bool
    let config: [String: Any]
    let locations: [String]
    let device: String
    let current: Bool
    let enabled: Bool
    var diagnostic: String {
        "\(name) [\(id)] • \(device) • \(enabled ? "enabled" : "disabled")\(current ? ", current location" : ", outside current location")\nLocations: \(locations.isEmpty ? "No network location (orphaned service)" : locations.joined(separator: "; "))\nDNS: \(servers(config).joined(separator: ", "))"
    }
}
func shouldPreserveDNS(_ config: [String: Any], saved: [String: Any]?) -> Bool {
    // Never replace an explicit resolver unless this saved service still points
    // at our own resolver. A restored manual baseline is an exclusion too.
    return !servers(config).isEmpty && (saved == nil || !isOurs(config))
}
final class Network {
    let prefs: SCPreferences
    init() throws {
        guard let p = SCPreferencesCreate(nil, "Private DNS" as CFString, nil) else { throw error("Cannot read network preferences.") }
        prefs = p
    }
    func list(currentOnly: Bool) -> [DNSService] {
        let values: [SCNetworkService]
        if currentOnly {
            guard let set = SCNetworkSetCopyCurrent(prefs) else { return [] }
            values = SCNetworkSetCopyServices(set) as? [SCNetworkService] ?? []
        } else { values = SCNetworkServiceCopyAll(prefs) as? [SCNetworkService] ?? [] }
        let sets = SCNetworkSetCopyAll(prefs) as? [SCNetworkSet] ?? []
        let currentIDs = Set((SCNetworkSetCopyCurrent(prefs).flatMap { SCNetworkSetCopyServices($0) as? [SCNetworkService] } ?? []).compactMap { SCNetworkServiceGetServiceID($0) as String? })
        var locations: [String: [String]] = [:]
        for set in sets {
            let label = "\(SCNetworkSetGetName(set) as String? ?? "Unnamed") [\(SCNetworkSetGetSetID(set) as String? ?? "unknown")]"
            for service in SCNetworkSetCopyServices(set) as? [SCNetworkService] ?? [] {
                if let id = SCNetworkServiceGetServiceID(service) as String? { locations[id, default: []].append(label) }
            }
        }
        return values.compactMap { service in
            guard let interface = SCNetworkServiceGetInterface(service),
                  let type = SCNetworkInterfaceGetInterfaceType(interface) as String?,
                  ["Ethernet", "IEEE80211", "Bridge"].contains(type),
                  !currentOnly || SCNetworkServiceGetEnabled(service),
                  let name = SCNetworkServiceGetName(service) as String?,
                  let serviceID = SCNetworkServiceGetServiceID(service) as String? else { return nil }
            let proto = SCNetworkServiceCopyProtocol(service, kSCNetworkProtocolTypeDNS)
            let config = proto.flatMap { SCNetworkProtocolGetConfiguration($0) as? [String: Any] } ?? [:]
            return DNSService(id: serviceID, name: name, reference: service, existed: proto != nil, config: config, locations: (locations[serviceID] ?? []).sorted(), device: SCNetworkInterfaceGetBSDName(interface) as String? ?? type, current: currentIDs.contains(serviceID), enabled: SCNetworkServiceGetEnabled(service))
        }
    }
    func set(_ service: DNSService, _ config: [String: Any], existed: Bool = true) throws {
        if !existed {
            if SCNetworkServiceCopyProtocol(service.reference, kSCNetworkProtocolTypeDNS) != nil {
                guard SCNetworkServiceRemoveProtocolType(service.reference, kSCNetworkProtocolTypeDNS) else { throw error("Cannot remove temporary DNS settings for \(service.name).") }
            }
            return
        }
        if SCNetworkServiceCopyProtocol(service.reference, kSCNetworkProtocolTypeDNS) == nil {
            guard SCNetworkServiceAddProtocolType(service.reference, kSCNetworkProtocolTypeDNS) else { throw error("Cannot configure DNS for \(service.name).") }
        }
        guard let proto = SCNetworkServiceCopyProtocol(service.reference, kSCNetworkProtocolTypeDNS), SCNetworkProtocolSetConfiguration(proto, config as CFDictionary) else { throw error("Cannot update DNS for \(service.name).") }
    }
    func commit() throws {
        guard SCPreferencesCommitChanges(prefs), SCPreferencesApplyChanges(prefs) else { throw error("macOS could not save the DNS settings.") }
    }
}

struct PausePolicy {
    var boot: String
    var until: Double // 0 = on, -1 = until restart, positive = Unix deadline
    mutating func update(now: Double, boot newBoot: String) {
        if boot != newBoot || (until > 0 && until <= now) { until = 0 }
        boot = newBoot
    }
    var enabled: Bool { until == 0 }
}
func canRestore(current: [String: Any], owned: Bool) -> Bool { owned && isOurs(current) }

final class DNSState {
    let path: String
    var data: [String: Any]
    init(path: String = dataPath + "/state.plist") throws {
        self.path = path
        data = FileManager.default.fileExists(atPath: path) ? try readPlist(path) : ["version": 2, "baseline": [String: Any](), "pauseUntil": 0.0, "boot": ""]
        guard data["version"] as? Int == 2 else { throw error("Unrecognized saved state. Settings were not changed.") }
    }
    func save() throws { try writePlist(data, path) }
    var baseline: [String: [String: Any]] {
        get { data["baseline"] as? [String: [String: Any]] ?? [:] }
        set { data["baseline"] = newValue }
    }
    var policy: PausePolicy {
        get { PausePolicy(boot: data["boot"] as? String ?? "", until: data["pauseUntil"] as? Double ?? 0) }
        set { data["boot"] = newValue.boot; data["pauseUntil"] = newValue.until }
    }
    func apply(enabled: Bool) throws -> [String] {
        let network = try Network()
        let list = network.list(currentOnly: enabled)
        return try apply(enabled: enabled, services: list, write: { try network.set($0, $1, existed: $2) }, commit: {
            try network.commit()
            _ = run("/usr/bin/dscacheutil", ["-flushcache"])
            _ = run("/usr/bin/killall", ["-HUP", "mDNSResponder"])
        })
    }
    func apply(enabled: Bool, services list: [DNSService], write: (DNSService, [String: Any], Bool) throws -> Void, commit: () throws -> Void) throws -> [String] {
        var backups = baseline
        var conflicts: [String] = []
        var changes: [(DNSService, [String: Any], Bool)] = []
        for service in list {
            let saved = backups[service.id]
            if enabled {
                if shouldPreserveDNS(service.config, saved: saved) {
                    conflicts.append(service.diagnostic); continue
                }
                if saved == nil {
                    backups[service.id] = ["name": service.name, "config": service.config, "existed": service.existed]
                }
                if !isOurs(service.config) {
                    var config = service.config; config["ServerAddresses"] = ["127.0.0.1"]
                    changes.append((service, config, true))
                }
            } else if let saved, canRestore(current: service.config, owned: true) {
                // Restore only our DNS address, preserving unrelated settings changed later.
                var config = service.config
                let original = saved["config"] as? [String: Any] ?? [:]
                if let addresses = original["ServerAddresses"] { config["ServerAddresses"] = addresses }
                else { config.removeValue(forKey: "ServerAddresses") }
                let keepProtocol = (saved["existed"] as? Bool ?? true) || !config.isEmpty
                changes.append((service, config, keepProtocol))
            }
        }
        // Persist recovery information before the first network mutation.
        if !NSDictionary(dictionary: backups).isEqual(to: baseline) { baseline = backups; try save() }
        if !changes.isEmpty {
            for (service, config, existed) in changes { try write(service, config, existed) }
            try commit()
        }
        return conflicts
    }
    func importLegacy() throws {
        guard baseline.isEmpty else { return }
        let old = dataPath + "/Previous setup/network-preferences.plist"
        guard FileManager.default.fileExists(atPath: old) else { throw error("The previous version's DNS backup is missing. No settings were changed.") }
        let original = try readPlist(old)["NetworkServices"] as? [String: [String: Any]] ?? [:]
        var result: [String: [String: Any]] = [:]
        for service in try Network().list(currentOnly: false) where isOurs(service.config) {
            guard let entry = original[service.id] else { throw error("Cannot locate the original DNS setting for \(service.name).") }
            let config = entry["DNS"] as? [String: Any] ?? [:]
            guard !isOurs(config) else { throw error("The DNS backup for \(service.name) points to the old proxy. Resolve this before upgrading.") }
            result[service.id] = ["name": service.name, "config": config, "existed": entry["DNS"] != nil]
        }
        baseline = result; try save()
    }
}

func socketAddress(_ path: String) -> sockaddr_un {
    var addr = sockaddr_un(); addr.sun_family = sa_family_t(AF_UNIX)
    withUnsafeMutableBytes(of: &addr.sun_path) { buffer in
        for (i, byte) in (Array(path.utf8) + [0]).enumerated() where i < buffer.count { buffer[i] = byte }
    }
    addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
    return addr
}
func sendCommand(_ command: String, path: String = socketPath) throws -> [String: Any] {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { throw error("Cannot create the control connection.") }
    defer { close(fd) }
    var timeout = timeval(tv_sec: 8, tv_usec: 0)
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
    var addr = socketAddress(path)
    let result = withUnsafePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) } }
    guard result == 0 else { throw error("The Private DNS service is unavailable, or this account lacks access. Run the installer using an administrator account.") }
    let request = Array((command + "\n").utf8)
    guard request.withUnsafeBytes({ write(fd, $0.baseAddress, $0.count) }) == request.count else { throw error("Could not send the DNS command.") }
    shutdown(fd, SHUT_WR)
    var received = Data(), buffer = [UInt8](repeating: 0, count: 4096)
    while received.count < 65536 {
        let count = read(fd, &buffer, buffer.count)
        if count == 0 { break }; if count < 0 { throw error("The DNS service did not respond in time.") }
        received.append(contentsOf: buffer.prefix(count))
    }
    guard let value = try JSONSerialization.jsonObject(with: received) as? [String: Any] else { throw error("Invalid service response.") }
    return value
}
