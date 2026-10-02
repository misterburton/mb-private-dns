import Cocoa

final class Controls: NSObject, NSApplicationDelegate {
    var status: NSStatusItem!
    let menu = NSMenu()
    let headline = NSMenuItem(title: "Checking DoH…", action: nil, keyEquivalent: "")
    let detail = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    var resume: NSMenuItem!
    var pause15: NSMenuItem!
    var pause60: NSMenuItem!
    var pauseBoot: NSMenuItem!
    var quitApp: NSMenuItem!
    var quitControls: NSMenuItem!
    var attemptedStart = false
    var timer: Timer?
    var window: NSWindow?
    var scroll: NSScrollView?
    let text = NSTextField(wrappingLabelWithString: "Checking DoH…")
    let queue = DispatchQueue(label: "PrivateDNS.controls")
    var changing = false
    var refreshing = false
    var summary = "Checking DoH…"
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        signal(SIGPIPE, SIG_IGN)
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.title = "DoH"
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
        quitControls = add("Quit Controls (protection continues)", #selector(quitControlsOnly))
        quitApp = add("Quit Private DNS", #selector(quit))
        quitApp.keyEquivalent = "q"
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
            headline.title = "DoH needs attention"; status.button?.title = "DoH !"
            detail.title = "Open Details for the service message"
            message = errorText.isEmpty ? "The DNS service could not be reached." : errorText
        } else if !enabled {
            headline.title = "DoH is paused"; status.button?.title = "DoH Paused"
            if until > 0 {
                let date = Date(timeIntervalSince1970: until)
                let time = DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
                detail.title = "Resumes automatically at \(time)"
            } else { detail.title = "Resumes when you restart your Mac" }
            message = "Network-provided DNS is active.\n\n\(detail.title). You can resume protection sooner from the DoH menu."
        } else {
            headline.title = mode == "on" ? "DoH is on" : "DoH needs attention"
            status.button?.title = mode == "on" ? "DoH On" : "DoH !"
            detail.title = healthy ? "Cloudflare • DNS over HTTPS" : "Encrypted resolver is not responding"
            message = healthy ? "Cloudflare DNS over HTTPS is configured and the local resolver is responding." : "DNS over HTTPS is configured, but the encrypted resolver isn't responding. Pause protection if you need to sign in to Wi-Fi."
            if value["override"] as? Bool == true { message += "\n\nA VPN or another DNS resolver currently takes priority. Private DNS does not disconnect or change your VPN." }
            let conflicts = value["conflicts"] as? [String] ?? []
            if !conflicts.isEmpty { message += "\n\nOther DNS settings were preserved for: " + conflicts.joined(separator: ", ") + ". Resolve those settings before enabling protection there." }
        }
        message += "\n\nProtection resumes at every restart. Timed pauses also expire while the controls are closed; after sleep, protection resumes when the service runs again."
        status.button?.toolTip = message
        summary = message + "\n\n" + """
        What is DoH?
        DoH means DNS over HTTPS. DNS looks up the internet address for a name such as example.com so your Mac can connect. DNS still works when DoH is off.

        When DoH is on
        Private DNS encrypts your Mac's system DNS lookups on their way to Cloudflare. Your ISP, employer, school, or Wi-Fi operator cannot read or alter those lookups in transit on the network.

        When DoH is off or paused
        Your Mac uses network-provided DNS. Unless another app or VPN encrypts it, these lookups can reveal the domain names of websites and services you use to your ISP and the operator of your work, school, or Wi-Fi network, even when websites use HTTPS.

        Privacy limits
        Cloudflare can still see the lookups it resolves. DoH is not a VPN: networks may still infer sites from connection information, and monitoring software on your Mac may see your activity. Apps or VPNs using their own DNS may bypass this protection.
        """
        updateDetails()
        quitApp.isEnabled = !changing; quitControls.isEnabled = !changing
        resume.isEnabled = !changing && (!enabled || mode == "attention")
        [pause15!, pause60!, pauseBoot!].forEach { $0.isEnabled = !changing && value["ok"] as? Bool == true }
    }
    func refresh() {
        guard !changing && !refreshing else { return }; refreshing = true
        queue.async {
            let value: [String: Any]
            do { value = try sendCommand("status") } catch { value = ["ok": false, "error": error.localizedDescription] }
            let stopped = value["ok"] as? Bool != true && run("/bin/launchctl", ["print", "system/" + daemonLabel]).code != 0
            DispatchQueue.main.async {
                self.refreshing = false
                guard !self.changing else { return }
                self.show(value)
                if stopped && !self.attemptedStart {
                    self.attemptedStart = true
                    self.startService()
                }
            }
        }
    }
    func command(_ action: String) {
        guard !changing else { return }; changing = true
        headline.title = "Updating DoH…"
        [resume!, pause15!, pause60!, pauseBoot!, quitApp!, quitControls!].forEach { $0.isEnabled = false }
        queue.async {
            let value: [String: Any]
            do { value = try sendCommand(action) } catch { value = ["ok": false, "error": error.localizedDescription] }
            DispatchQueue.main.async { self.changing = false; self.show(value) }
        }
    }
    @objc func turnOn() {
        if run("/bin/launchctl", ["print", "system/" + daemonLabel]).code != 0 { startService() }
        else { command("on") }
    }
    @objc func pauseShort() { command("pause 900") }
    @objc func pauseLong() { command("pause 3600") }
    @objc func pauseUntilRestart() { command("pause reboot") }
    @objc func showDetails() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 340), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "Private DNS"; w.isReleasedWhenClosed = false; w.center()
            let scroller = NSScrollView(frame: NSRect(x: 25, y: 20, width: 490, height: 295))
            scroller.hasVerticalScroller = true; scroller.autohidesScrollers = true
            scroller.drawsBackground = false
            text.font = .systemFont(ofSize: 14)
            scroller.documentView = text
            w.contentView?.addSubview(scroller); scroll = scroller; window = w
        }
        updateDetails(); window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func updateDetails() {
        text.stringValue = summary
        guard let scroll else { return }
        let width = scroll.contentSize.width
        let height = text.sizeThatFits(NSSize(width: width, height: .greatestFiniteMagnitude)).height
        text.frame = NSRect(x: 0, y: 0, width: width, height: max(height, scroll.contentSize.height))
    }
    func authorizedServiceAction(_ action: String) throws {
        guard ["start", "stop"].contains(action),
              let resource = Bundle.main.path(forResource: "controls-service", ofType: "sh") else {
            throw error("Private DNS lifecycle controls are missing. Reinstall the updated app.")
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("private-dns-controls-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: folder) }
        let staged = folder.appendingPathComponent("controls-service.sh")
        try FileManager.default.copyItem(atPath: resource, toPath: staged.path)
        let quoted = "'" + staged.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        let command = "/bin/bash " + quoted + " " + action
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let prompt = action == "stop" ? "Quit Private DNS and restore network-provided DNS. Protection resumes when you reopen the app or restart your Mac." : "Start Private DNS and enable DNS over HTTPS."
        var failure: NSDictionary?
        guard let script = NSAppleScript(source: "do shell script \"\(escaped)\" with administrator privileges with prompt \"\(prompt)\"") else {
            throw error("Could not prepare administrator authorization.")
        }
        _ = script.executeAndReturnError(&failure)
        if let failure { throw error(failure[NSAppleScript.errorMessage] as? String ?? "The operation was cancelled or failed.") }
    }
    func startService() {
        guard !changing else { return }
        changing = true
        do { try authorizedServiceAction("start") }
        catch {
            let alert = NSAlert(); alert.messageText = "Private DNS could not start"
            alert.informativeText = error.localizedDescription; alert.runModal()
        }
        changing = false; refresh()
    }
    @objc func quitControlsOnly() { if !changing { NSApp.terminate(nil) } }
    @objc func quit() {
        guard !changing else { return }
        changing = true
        do {
            try authorizedServiceAction("stop")
            timer?.invalidate()
            NSApp.terminate(nil)
        } catch {
            changing = false; attemptedStart = true
            let alert = NSAlert(); alert.messageText = "Private DNS could not quit"
            alert.informativeText = error.localizedDescription; alert.runModal()
            refresh()
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { refresh(); return false }
}
@main struct ControlsMain {
    static func main() {
        let controller = Controls()
        NSApplication.shared.delegate = controller
        withExtendedLifetime(controller) { NSApplication.shared.run() }
    }
}
