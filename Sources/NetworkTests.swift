import Foundation
import SystemConfiguration

@main struct NetworkTests {
 static func main() throws {
  // Use a read-only service reference; every write/commit below is intercepted.
  let reference = try Network().list(currentOnly: false).first!.reference
  let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
  defer { try? FileManager.default.removeItem(at: folder) }
  let state = try DNSState(path: folder.appendingPathComponent("state.plist").path)
  func service(_ id: String, _ config: [String: Any], current: Bool = true, locations: [String] = ["Show [location-a]"]) -> DNSService {
   DNSService(id: id, name: "Ethernet", reference: reference, existed: true, config: config, locations: locations, device: "en7", current: current, enabled: true)
  }
  let custom: [String: Any] = ["ServerAddresses": ["192.168.3.1"], "SearchDomains": ["show.local"]]
  precondition(shouldPreserveDNS(custom, saved: ["config": custom]))
  print("PASS: restored manual baselines are not reclaimed on resume")
  let auto: [String: Any] = ["SearchDomains": ["example.test"]]
  var writes: [String: [String: Any]] = [:]; var commits = 0
  let excluded = try state.apply(enabled: true, services: [service("automatic", auto), service("manual", custom)], write: { service, config, _ in writes[service.id] = config }, commit: { commits += 1 })
  precondition(writes.count == 1 && servers(writes["automatic"]!) == ["127.0.0.1"])
  precondition(writes["automatic"]?["SearchDomains"] as? [String] == ["example.test"])
  precondition(state.baseline["manual"] == nil && commits == 1)
  precondition(excluded.count == 1 && excluded[0].contains("manual") && excluded[0].contains("192.168.3.1") && excluded[0].contains("Show [location-a]"))
  print("PASS: mixed automatic/manual services apply only eligible DNS and preserve search domains")
  let orphan = service("orphan-id", custom, current: false, locations: [])
  precondition(orphan.diagnostic.contains("orphaned") && orphan.diagnostic.contains("outside current location") && orphan.diagnostic.contains("orphan-id"))
  print("PASS: duplicate service names remain identifiable; orphan services identify missing location")
  writes = [:]; commits = 0
  _ = try state.apply(enabled: true, services: [service("automatic", custom), service("manual", custom)], write: { service, config, _ in writes[service.id] = config }, commit: { commits += 1 })
  precondition(writes.isEmpty && commits == 0)
  print("PASS: later third-party changes and all-manual setups produce no writes")
  _ = try state.apply(enabled: false, services: [service("automatic", custom), orphan], write: { service, config, _ in writes[service.id] = config }, commit: { commits += 1 })
  precondition(writes.isEmpty && commits == 0)
  print("PASS: pause/uninstall preserves changed and unowned manual DNS")
  _ = try state.apply(enabled: false, services: [service("automatic", ["ServerAddresses": ["127.0.0.1"], "SearchDomains": ["new.test"]])], write: { service, config, _ in writes[service.id] = config }, commit: { commits += 1 })
  precondition(servers(writes["automatic"]!).isEmpty && writes["automatic"]?["SearchDomains"] as? [String] == ["new.test"])
  print("PASS: owned DNS restoration retains later non-DNS fields")
 }
}
