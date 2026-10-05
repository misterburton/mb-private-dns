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
        controls.show(["ok": true, "enabled": true, "healthy": true, "mode": "partial", "dnsOwner": "private-dns", "excludedServices": ["Ethernet [service-id] • en7\nLocations: Show [location-id]\nDNS: 192.168.3.1"]])
        precondition(controls.status.button?.title == "DoH Partial")
        precondition(controls.summary.contains("192.168.3.1") && controls.summary.contains("service-id") && controls.summary.contains("Keep these settings"))
        print("PASS: partial coverage shows preserved network details without instructing deletion")
        controls.show(["ok": true, "enabled": true, "healthy": false, "mode": "starting"])
        precondition(controls.headline.title == "Starting Private DNS…" && controls.status.button?.title == "DoH Starting…")
        precondition(!controls.resume.isEnabled && controls.pause15.isEnabled && controls.pause60.isEnabled && controls.pauseBoot.isEnabled)
        precondition(controls.refreshInterval == 2 && controls.summary.contains("Protection is not verified yet"))
        controls.show(["ok": false, "enabled": true, "mode": "attention", "error": "launch failed"])
        precondition(controls.status.button?.title == "DoH !" && controls.summary.contains("launch failed"))
        show("private-dns", "on")
        precondition(controls.refreshInterval == 10 && controls.status.button?.title == "DoH On")
        show("private-dns", "attention", healthy: false)
        precondition(controls.status.button?.title == "DoH !" && controls.resume.isEnabled)
        print("PASS: startup copy, disabled Resume, available Pause, immediate errors, recovery and timeout warning")
        let now = Date()
        var calls = 0
        let candidate = UpdateCandidate(version: "99.0", asset: .init(name: "unused", browser_download_url: "unused", size: 1, digest: nil))
        controls.lookupUpdate = { _ in calls += 1; return candidate }
        func finishCheck() {
            let deadline = Date().addingTimeInterval(3)
            while controls.updating && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
            precondition(!controls.updating)
        }
        controls.checkForScheduledUpdates(now: now)
        controls.checkForScheduledUpdates(now: now)
        finishCheck()
        precondition(calls == 1)
        precondition(controls.updateItem.title == "Update Available (99.0)…")
        precondition(controls.window == nil && controls.updateItem.isEnabled)
        controls.checkForScheduledUpdates(now: now.addingTimeInterval(86399))
        precondition(calls == 1 && !controls.updating)
        controls.lookupUpdate = { _ in calls += 1; throw error("offline") }
        controls.checkForScheduledUpdates(now: now.addingTimeInterval(86400))
        finishCheck()
        precondition(calls == 2 && controls.updateItem.title.contains("99.0"))
        controls.checkForScheduledUpdates(now: now.addingTimeInterval(86410))
        precondition(!controls.updating)
        controls.lookupUpdate = { _ in calls += 1; return nil }
        controls.checkForScheduledUpdates(now: now.addingTimeInterval(86400 * 4))
        finishCheck()
        precondition(calls == 3 && controls.updateItem.title == "Check for Updates…")
        print("PASS: launch check, duplicate prevention, daily deadline, quiet offline failure, retained update notice, sleep catch-up and cleared notice")
        func coexist(_ mode: String, healthy: Bool = true) {
            controls.show(["ok": true, "enabled": true, "healthy": healthy,
                           "dnsOwner": "private-dns", "mode": mode, "splitDNS": true,
                           "scopedDNS": true, "tailscaleDNS": true, "tailscaleCoexistence": true])
        }
        coexist("on")
        precondition(controls.headline.title == "DoH is on" && controls.status.button?.title == "DoH On")
        precondition(controls.detail.title == "Tailscale also handles some DNS queries")
        precondition(!controls.resume.isEnabled && controls.summary.contains("cannot verify the provider or encryption"))
        coexist("attention", healthy: false)
        precondition(controls.status.button?.title == "DoH !")
        precondition(controls.detail.title == "Encrypted resolver is not responding")
        coexist("partial")
        precondition(controls.status.button?.title == "DoH Partial" && !controls.resume.isEnabled)
        coexist("on")
        controls.showDetails()
        let scroll = controls.scroll!
        let document = controls.detailsDocument
        precondition(controls.window!.isVisible && document.isFlipped)
        precondition(document.subviews.contains { $0 is NSImageView })
        precondition(controls.text.superview === document)
        precondition(scroll.contentView.bounds.origin.y == 0)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 120))
        scroll.reflectScrolledClipView(scroll.contentView)
        let position = scroll.contentView.bounds.origin.y
        precondition(position > 72 && !scroll.documentVisibleRect.intersects(document.subviews.first { $0 is NSImageView }!.frame))
        controls.updateDetails()
        precondition(scroll.contentView.bounds.origin.y == position, "status refresh must preserve reading position")
        controls.summary = "Short status"
        controls.updateDetails()
        precondition(scroll.contentView.bounds.origin.y == 0, "shorter contents must clamp the scroll position")
        controls.window?.close()
        print("PASS: Tailscale coexistence is informational; failures and exclusions remain visible; Details icon scrolls with text and refresh preserves reading position")
        NSStatusBar.system.removeStatusItem(controls.status)
        print("PASS: AppKit app loads; managed, failed, split, unknown, paused and recovered menu states render without opening windows or changing DNS")
    }
}
