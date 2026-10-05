import Foundation
import Darwin

func containsDNSProfile(_ value: Any) -> Bool {
    if let dictionary = value as? [String: Any] {
        if let type = dictionary["PayloadType"] as? String, ["com.apple.dnsSettings.managed", "com.apple.dnsProxy.managed"].contains(type) { return true }
        return dictionary.values.contains { containsDNSProfile($0) }
    }
    if let array = value as? [Any] { return array.contains { containsDNSProfile($0) } }
    return false
}
func preflight() throws {
    let knownInstall = FileManager.default.fileExists(atPath: dataPath + "/state.plist") || FileManager.default.fileExists(atPath: dataPath + "/Previous setup/network-preferences.plist")
    let profiles = run("/usr/bin/profiles", ["show", "-type", "configuration", "-all", "-output", "stdout-xml"])
    if let bytes = profiles.text.data(using: .utf8), let data = try? PropertyListSerialization.propertyList(from: bytes, format: nil), containsDNSProfile(data) {
        throw error("An encrypted-DNS or DNS-proxy configuration profile is already installed. Disable or remove that configuration before installing Private DNS. It has not been changed.")
    }
    let ownDaemon = run("/bin/launchctl", ["print", "system/" + daemonLabel])
    let runningOwnService = knownInstall && ownDaemon.code == 0 && ownDaemon.text.contains("state = running")
    if !runningOwnService {
        for kind in [SOCK_STREAM, SOCK_DGRAM] {
            let fd = socket(AF_INET, kind, 0); guard fd >= 0 else { throw error("Cannot check DNS port availability.") }
            var address = sockaddr_in(); address.sin_family = sa_family_t(AF_INET); address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            address.sin_port = UInt16(53).bigEndian; address.sin_addr.s_addr = inet_addr("127.0.0.1")
            let bound = withUnsafePointer(to: &address) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
            close(fd)
            guard bound == 0 else { throw error("Another DNS service is using 127.0.0.1:53. Turn that service off before installing Private DNS. No existing service has been stopped.") }
        }
    }
}

final class Service {
    let state: DNSState
    let queue = DispatchQueue(label: "PrivateDNS.service")
    var engine: Process?
    var tick: DispatchSourceTimer?
    var acceptSource: DispatchSourceRead?
    var listener: Int32 = -1
    var lastError = ""
    var conflicts: [String] = []
    var readiness = ResolverReadiness(began: ProcessInfo.processInfo.systemUptime)
    var healthy: Bool { readiness.healthy }
    init() throws { state = try DNSState() }
    func startEngine() throws {
        if engine?.isRunning == true { return }
        if engine != nil { readiness.failed = true; readiness.healthy = false; readiness.lastCheck = nil }
        // A forcibly restarted supervisor may leave Foundation's child process group alive.
        // Retire only this product's exact bundled resolver before starting its replacement.
        if engine == nil {
            _ = run("/usr/bin/pkill", ["-f", "^/Library/Application Support/Private DNS/Runtime/dnscrypt-proxy( |$)"])
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: dataPath + "/Runtime/dnscrypt-proxy")
        process.arguments = ["-config", dataPath + "/Runtime/dnscrypt-proxy.toml"]
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try process.run(); engine = process
    }
    func update() {
        do {
            try startEngine()
            var policy = state.policy; policy.update(now: Date().timeIntervalSince1970, boot: bootID())
            let changed = policy.boot != state.policy.boot || policy.until != state.policy.until
            state.policy = policy
            if changed { try state.save() }
            conflicts = try state.apply(enabled: policy.enabled)
            if readiness.checkDue(now: ProcessInfo.processInfo.systemUptime) {
                let answer = run("/usr/bin/dig", ["@127.0.0.1", "example.com", "A", "+time=2", "+tries=1", "+noall", "+comments", "+answer"])
                readiness.record(healthy: answer.code == 0 && answer.text.contains("status: NOERROR") && answer.text.contains("IN\tA"), now: ProcessInfo.processInfo.systemUptime)
            }
            lastError = ""
        } catch { lastError = error.localizedDescription; readiness.failed = true }
    }
    func snapshot() -> [String: Any] {
        let network = try? Network()
        let list = network?.list(currentOnly: true) ?? []
        let protected = list.filter { isOurs($0.config) }.map(\.name)
        let dns = run("/usr/sbin/scutil", ["--dns"])
        let routing = DNSRouting(output: dns.text, succeeded: dns.code == 0)
        let overrides = state.policy.enabled && ["tailscale", "vpn", "other", "mixed"].contains(routing.owner)
        let baseMode = routing.mode(enabled: state.policy.enabled, healthy: healthy, conflicts: [], error: lastError)
        let normalMode = baseMode == "on" && !conflicts.isEmpty ? "partial" : baseMode
        let mode = readiness.mode(normalMode, enabled: state.policy.enabled, error: lastError,
                                  conflicts: conflicts, owner: routing.owner, now: ProcessInfo.processInfo.systemUptime,
                                  routingReady: routing.mode(enabled: true, healthy: true, conflicts: [], error: "") != "attention")
        let exclusions = (network?.list(currentOnly: false) ?? []).filter { shouldPreserveDNS($0.config, saved: state.baseline[$0.id]) }.map(\.diagnostic)
        return ["ok": lastError.isEmpty, "mode": mode, "enabled": state.policy.enabled, "pauseUntil": state.policy.until,
                "healthy": healthy, "override": overrides, "conflicts": conflicts, "protectedServices": protected,
                "dnsOwner": routing.owner, "splitDNS": routing.splitDNS, "scopedDNS": routing.scopedDNS,
                "tailscaleDNS": routing.tailscalePresent,
                "tailscaleCoexistence": routing.tailscaleCoexistence,
                "vpnCoexistence": routing.vpnCoexistence, "defaultDNSRoutes": routing.defaultRoutes,
                "excludedServices": exclusions, "totalServices": list.count, "error": lastError, "provider": "Cloudflare", "version": "2.8"]
    }
    func handle(_ command: String) -> [String: Any] {
        guard ["status", "on", "pause 900", "pause 3600", "pause reboot"].contains(command) else { return ["ok": false, "error": "Unsupported command."] }
        if command != "status" {
            do {
                let until: Double
                if command == "on" { until = 0 }
                else if command == "pause reboot" { until = -1 }
                else { until = Date().timeIntervalSince1970 + (command == "pause 900" ? 900 : 3600) }
                let previous = state.policy
                state.policy = PausePolicy(boot: bootID(), until: until)
                do { try state.save(); conflicts = try state.apply(enabled: until == 0) }
                catch { state.policy = previous; try? state.save(); throw error }
                lastError = ""
            } catch { return ["ok": false, "error": error.localizedDescription] }
        }
        return snapshot()
    }
    func start() throws {
        signal(SIGPIPE, SIG_IGN)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw error("Cannot create service socket.") }
        listener = fd
        unlink(socketPath)
        var address = socketAddress(socketPath)
        let bound = withUnsafePointer(to: &address) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) } }
        guard bound == 0 else { throw error("Cannot bind service socket.") }
        guard let admin = getgrnam("admin") else { throw error("Administrator group not found.") }
        guard chown(socketPath, 0, admin.pointee.gr_gid) == 0, chmod(socketPath, 0o660) == 0, listen(fd, 8) == 0 else { throw error("Cannot secure service socket.") }
        _ = fcntl(fd, F_SETFL, O_NONBLOCK)
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in self?.acceptRequest() }
        queue.sync { self.update() }
        source.resume(); acceptSource = source
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 5, repeating: 5)
        timer.setEventHandler { [weak self] in self?.update() }
        timer.resume(); tick = timer
    }
    func acceptRequest() {
        let fd = accept(listener, nil, nil); guard fd >= 0 else { return }
        defer { close(fd) }
        _ = fcntl(fd, F_SETFL, 0)
        // The root:admin socket limits commands to administrators. Commands are a fixed allowlist.
        var timeout = timeval(tv_sec: 1, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
        var request = Data(), buffer = [UInt8](repeating: 0, count: 256)
        while request.count <= 256 {
            let n = read(fd, &buffer, buffer.count)
            if n <= 0 { break }; request.append(contentsOf: buffer.prefix(n))
            if request.contains(10) { break }
        }
        guard request.count <= 256 else { return }
        let command = String(decoding: request, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let response = handle(command)
        if let data = try? JSONSerialization.data(withJSONObject: response, options: [.sortedKeys]) {
            data.withUnsafeBytes { bytes in
                var offset = 0
                while offset < bytes.count {
                    let written = write(fd, bytes.baseAddress! + offset, bytes.count - offset)
                    if written <= 0 { break }; offset += written
                }
            }
        }
    }
}

@main struct ServiceMain {
    static func main() {
        signal(SIGPIPE, SIG_IGN)
        let args = Array(CommandLine.arguments.dropFirst())
        do {
            if args == ["--daemon"] {
                guard geteuid() == 0 else { throw error("Service mode requires administrator privileges.") }
                let service = try Service(); try service.start()
                withExtendedLifetime(service) { dispatchMain() }
            } else if args == ["--preflight"] {
                guard geteuid() == 0 else { throw error("Installation checks require administrator privileges.") }
                try preflight(); print("Installation checks passed. Existing manual DNS will be preserved.")
            } else if args == ["--import-legacy"] {
                guard geteuid() == 0 else { throw error("Migration requires administrator privileges.") }
                try DNSState().importLegacy(); print("Previous DNS settings imported.")
            } else if args == ["--restore"] {
                guard geteuid() == 0 else { throw error("Restoration requires administrator privileges.") }
                let state = try DNSState()
                if state.baseline.isEmpty && FileManager.default.fileExists(atPath: dataPath + "/Previous setup/network-preferences.plist") { try state.importLegacy() }
                _ = try state.apply(enabled: false); print("Original DNS settings restored; later third-party changes preserved.")
            } else if args.count == 2 && args[0] == "--command" {
                let value = try sendCommand(args[1])
                print(String(decoding: try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self))
                if value["ok"] as? Bool != true { exit(1) }
            } else { throw error("Usage: PrivateDNSService --command status|on|\"pause 900\"|\"pause 3600\"|\"pause reboot\"") }
        } catch { fputs(error.localizedDescription + "\n", stderr); exit(1) }
    }
}
