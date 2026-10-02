import Cocoa

final class Controls: NSObject, NSApplicationDelegate {
    var status: NSStatusItem!
    let menu = NSMenu()
    let headline = NSMenuItem(title: "Checking DNS…", action: nil, keyEquivalent: "")
    let detail = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    var resume: NSMenuItem!
    var pause15: NSMenuItem!
    var pause60: NSMenuItem!
    var pauseBoot: NSMenuItem!
    var timer: Timer?
    var window: NSWindow?
    let text = NSTextField(wrappingLabelWithString: "Checking DNS…")
    let queue = DispatchQueue(label: "PrivateDNS.controls")
    var changing = false
    var refreshing = false
    var summary = "Checking DNS…"
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        signal(SIGPIPE, SIG_IGN)
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.title = "DNS"
        status.button?.image = NSImage(systemSymbolName: "network", accessibilityDescription: "Private DNS")
        status.button?.imagePosition = .imageLeading
        menu.autoenablesItems = false
        headline.isEnabled = false; detail.isEnabled = false
        menu.addItem(headline); menu.addItem(detail); menu.addItem(.separator())
        resume = add("Resume Protection", #selector(turnOn))
        pause15 = add("Pause for 15 Minutes", #selector(pauseShort))
        pause60 = add("Pause for 1 Hour", #selector(pauseLong))
        pauseBoot = add("Pause Until Restart", #selector(pauseUntilRestart))
        menu.addItem(.separator())
        _ = add("Details…", #selector(showDetails))
        _ = add("Quit Controls (protection continues)", #selector(quit))
        status.menu = menu
        // No window appears at installation, login, or app launch.
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in self?.refresh() }
    }
    func add(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = self
        menu.addItem(item); return item
    }
    func show(_ value: [String: Any]) {
        let enabled = value["enabled"] as? Bool ?? false
        let mode = value["mode"] as? String ?? "attention"
        let healthy = value["healthy"] as? Bool ?? false
        let until = value["pauseUntil"] as? Double ?? 0
        let errorText = value["error"] as? String ?? ""
        var message: String
        if value["ok"] as? Bool != true {
            headline.title = "DNS needs attention"; status.button?.title = "DNS !"
            detail.title = "Open Details for the service message"
            message = errorText.isEmpty ? "The DNS service could not be reached." : errorText
        } else if !enabled {
            headline.title = "DNS protection is paused"; status.button?.title = "DNS Paused"
            if until > 0 {
                let date = Date(timeIntervalSince1970: until)
                let time = DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
                detail.title = "Resumes automatically at \(time)"
            } else { detail.title = "Resumes when you restart your Mac" }
            message = "Network-provided DNS is active.\n\n\(detail.title). You can resume protection sooner from the DNS menu."
        } else {
            headline.title = mode == "on" ? "DNS protection is on" : "DNS protection needs attention"
            status.button?.title = mode == "on" ? "DNS On" : "DNS !"
            detail.title = healthy ? "Cloudflare • DNS over HTTPS" : "Encrypted resolver is not responding"
            message = healthy ? "Cloudflare DNS over HTTPS is configured and the local resolver is responding." : "DNS over HTTPS is configured, but the encrypted resolver isn't responding. Pause protection if you need to sign in to Wi-Fi."
            if value["override"] as? Bool == true { message += "\n\nA VPN or another DNS resolver currently takes priority. Private DNS does not disconnect or change your VPN." }
            let conflicts = value["conflicts"] as? [String] ?? []
            if !conflicts.isEmpty { message += "\n\nOther DNS settings were preserved for: " + conflicts.joined(separator: ", ") + ". Resolve those settings before enabling protection there." }
        }
        message += "\n\nProtection resumes at every restart. Timed pauses also expire while the controls are closed; after sleep, protection resumes when the service runs again."
        summary = message; text.stringValue = message; status.button?.toolTip = message
        resume.isEnabled = !changing && (!enabled || mode == "attention")
        [pause15!, pause60!, pauseBoot!].forEach { $0.isEnabled = !changing && value["ok"] as? Bool == true }
    }
    func refresh() {
        guard !changing && !refreshing else { return }; refreshing = true
        queue.async {
            let value: [String: Any]
            do { value = try sendCommand("status") } catch { value = ["ok": false, "error": error.localizedDescription] }
            DispatchQueue.main.async { self.refreshing = false; if !self.changing { self.show(value) } }
        }
    }
    func command(_ action: String) {
        guard !changing else { return }; changing = true
        headline.title = "Updating DNS…"
        [resume!, pause15!, pause60!, pauseBoot!].forEach { $0.isEnabled = false }
        queue.async {
            let value: [String: Any]
            do { value = try sendCommand(action) } catch { value = ["ok": false, "error": error.localizedDescription] }
            DispatchQueue.main.async { self.changing = false; self.show(value) }
        }
    }
    @objc func turnOn() { command("on") }
    @objc func pauseShort() { command("pause 900") }
    @objc func pauseLong() { command("pause 3600") }
    @objc func pauseUntilRestart() { command("pause reboot") }
    @objc func showDetails() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 340), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "Private DNS"; w.isReleasedWhenClosed = false; w.center()
            text.font = .systemFont(ofSize: 14); text.frame = NSRect(x: 25, y: 20, width: 490, height: 295)
            w.contentView?.addSubview(text); window = w
        }
        text.stringValue = summary; window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { refresh(); return false }
}
@main struct ControlsMain {
    static func main() {
        let controller = Controls()
        NSApplication.shared.delegate = controller
        withExtendedLifetime(controller) { NSApplication.shared.run() }
    }
}
