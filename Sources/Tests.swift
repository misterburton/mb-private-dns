import Foundation

@main struct Tests {
    static func main() throws {
        func expect(_ condition: Bool, _ description: String) {
            guard condition else { fatalError("FAIL: " + description) }
            print("PASS: " + description)
        }
        var policy = PausePolicy(boot: "boot-a", until: 1900)
        policy.update(now: 1899, boot: "boot-a")
        expect(!policy.enabled, "15-minute pause remains active before deadline")
        policy.update(now: 1900, boot: "boot-a")
        expect(policy.enabled, "protection resumes exactly at the pause deadline")
        policy = PausePolicy(boot: "boot-a", until: 1900)
        policy.update(now: 9999, boot: "boot-a")
        expect(policy.enabled, "an expired pause resumes after sleep")
        policy = PausePolicy(boot: "boot-a", until: -1)
        policy.update(now: 9999, boot: "boot-a")
        expect(!policy.enabled, "until-restart pause survives a same-boot service restart")
        policy.update(now: 10000, boot: "boot-b")
        expect(policy.enabled, "a new boot re-enables protection even after an indefinite pause")
        policy = PausePolicy(boot: "boot-a", until: 1900)
        policy.update(now: 1100, boot: "boot-b")
        expect(policy.enabled, "a new boot overrides an unexpired timed pause")
        expect(canRestore(current: ["ServerAddresses": ["127.0.0.1"]], owned: true), "uninstaller restores DNS settings owned by this app")
        expect(!canRestore(current: ["ServerAddresses": ["9.9.9.9"]], owned: true), "uninstaller preserves later third-party DNS changes")
        expect(!canRestore(current: ["ServerAddresses": ["127.0.0.1"]], owned: false), "uninstaller leaves unowned loopback configurations alone")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let path = folder.appendingPathComponent("state.plist").path
        let state = try DNSState(path: path)
        state.policy = PausePolicy(boot: "boot-c", until: 10000)
        state.baseline = ["service-1": ["name": "Custom Wi-Fi name", "config": ["ServerAddresses": ["192.0.2.1"], "SearchDomains": ["example.test"]], "existed": true]]
        try state.save()
        let loaded = try DNSState(path: path)
        expect(loaded.policy.until == 10000 && loaded.policy.boot == "boot-c", "pause deadline survives process exit")
        expect(NSDictionary(dictionary: loaded.baseline).isEqual(to: state.baseline), "recovery state preserves custom DNS and search domains")
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600, "recovery state is private to its owner")
        try writePlist(["version": 99], path)
        do { _ = try DNSState(path: path); fatalError("Unknown state version accepted") }
        catch { print("PASS: unknown state versions fail without modifying network settings") }
    }
}
