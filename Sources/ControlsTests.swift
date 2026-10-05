import Cocoa

// Runs the actual menu rendering with synthetic service responses. No daemon
// commands, startup hooks, authorization prompts, or network changes are run.
@main struct ControlsTests {
    static func main() {
        let app = NSApplication.shared
        let controls = Controls()
        controls.configureMenu()
        precondition(controls.updateItem.title == "Check for Updates…")
        precondition(controls.updateItem.action == #selector(Controls.checkForUpdates))
        precondition(controls.updateItem.isEnabled)
        func show(_ owner: String, _ mode: String, healthy: Bool = true, split: Bool = false) {
            controls.show(["ok": true, "enabled": true, "healthy": healthy,
                           "dnsOwner": owner, "mode": mode, "splitDNS": split])
        }
        show("tailscale", "managed")
        precondition(controls.headline.title == "DNS managed by Tailscale")
        precondition(controls.detail.title.contains("unverified"))
        precondition(!controls.resume.isEnabled)
        precondition(controls.summary.contains("not a claim"))
        show("tailscale", "attention", healthy: false)
        precondition(controls.headline.title == "DoH needs attention")
        precondition(controls.summary.contains("also not responding"))
        show("private-dns", "on", split: true)
        precondition(controls.headline.title == "DoH is on")
        precondition(controls.summary.contains("outside Private DNS"))
        show("unknown", "attention")
        precondition(controls.detail.title == "System DNS routing could not be verified")
        controls.show(["ok": true, "enabled": false, "mode": "paused"])
        precondition(controls.summary.contains("Your network or VPN controls DNS"))
        show("private-dns", "on")
        precondition(controls.status.button?.title == "DoH On")
        precondition(controls.window == nil)
        app.finishLaunching()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        NSStatusBar.system.removeStatusItem(controls.status)
        print("PASS: AppKit app loads; managed, failed, split, unknown, paused and recovered menu states render without opening windows or changing DNS")
    }
}
