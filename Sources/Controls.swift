import Cocoa
import CoreServices

final class DetailsDocumentView: NSView {
    override var isFlipped: Bool { true }
}

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
    var updateItem: NSMenuItem!
    var updating = false
    var availableUpdateVersion: String?
    var updateSchedule = UpdateSchedule()
    var lookupUpdate: @MainActor (String) async throws -> UpdateCandidate? = { try await Updates.check(current: $0) }
    var currentUpdateVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown" }
    var attemptedStart = false
    var badge: StatusBadge = .starting
    var badgeTimer: Timer?
    var badgeFrame = 0
    lazy var loaderFrames = (0..<24).compactMap { AppIcon.statusBadge(.starting, frame: $0) }
    func setBadge(_ next: StatusBadge) {
        if next == badge && (next != .starting || badgeTimer != nil) && status.button?.image != nil { return }
        badgeTimer?.invalidate(); badgeTimer = nil
        badge = next; badgeFrame = 0
        status.button?.image = AppIcon.statusBadge(next)
        guard next == .starting, loaderFrames.count == 24,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        let animation = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.badgeFrame = (self.badgeFrame + 1) % 24
            self.status.button?.image = self.loaderFrames[self.badgeFrame]
        }
        badgeTimer = animation
        RunLoop.main.add(animation, forMode: .common)
    }
    func applicationWillTerminate(_ notification: Notification) { badgeTimer?.invalidate() }
    var timer: Timer?
    var window: NSWindow?
    var scroll: NSScrollView?
    let detailsDocument = DetailsDocumentView()
    let text = NSTextField(wrappingLabelWithString: "Checking DoH…")
    let queue = DispatchQueue(label: "PrivateDNS.controls")
    var changing = false
    var refreshing = false
    var refreshInterval: TimeInterval = 10
    var lastRefreshAt: TimeInterval = -.infinity
    var summary = "Checking DoH…"
    func applicationDidFinishLaunching(_ notification: Notification) {
        LSRegisterURL(Bundle.main.bundleURL as CFURL, true)
        configureMenu()
        // No window appears at installation, login, or app launch.
        refresh()
        checkForScheduledUpdates()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self else { return }
            if ProcessInfo.processInfo.systemUptime - self.lastRefreshAt >= self.refreshInterval { self.refresh() }
            self.checkForScheduledUpdates()
        }
    }
    func configureMenu() {
        NSApp.setActivationPolicy(.accessory)
        signal(SIGPIPE, SIG_IGN)
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.title = "DoH"
        setBadge(.starting)
        status.button?.imagePosition = .imageLeading
        menu.autoenablesItems = false
        headline.isEnabled = false; detail.isEnabled = false
        menu.addItem(headline); menu.addItem(detail); menu.addItem(.separator())
        resume = add("Resume Protection", #selector(turnOn))
        resume.isEnabled = false
        pause15 = add("Pause for 15 Minutes", #selector(pauseShort))
        pause60 = add("Pause for 1 Hour", #selector(pauseLong))
        pauseBoot = add("Pause Until Restart", #selector(pauseUntilRestart))
        menu.addItem(.separator())
        _ = add("Details…", #selector(showDetails))
        updateItem = add("Check for Updates…", #selector(checkForUpdates))
        quitControls = add("Quit Controls (protection continues)", #selector(quitControlsOnly))
        quitApp = add("Quit Private DNS", #selector(quit))
        quitApp.keyEquivalent = "q"
        status.menu = menu
    }
    func add(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = self
        menu.addItem(item); return item
    }
    func show(_ value: [String: Any]) {
        let enabled = value["enabled"] as? Bool ?? false
        let mode = value["mode"] as? String ?? "attention"
        refreshInterval = mode == "starting" ? 2 : 10
        let healthy = value["healthy"] as? Bool ?? false
        let until = value["pauseUntil"] as? Double ?? 0
        let errorText = value["error"] as? String ?? ""
        let owner = value["dnsOwner"] as? String
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
            message = "Private DNS is paused. Your network or VPN controls DNS.\n\n\(detail.title). You can resume protection sooner from the DoH menu."
        } else if mode == "starting" {
            headline.title = "Starting Private DNS…"; status.button?.title = "DoH Starting…"
            detail.title = "Connecting to the encrypted resolver…"
            message = "Private DNS is starting and checking its encrypted resolver. Protection is not verified yet. This normally takes a few seconds; no action is needed. You can still pause protection to sign in to Wi-Fi."
        } else {
            headline.title = mode == "on" ? "DoH is on" : "DoH needs attention"
            status.button?.title = mode == "on" ? "DoH On" : "DoH !"
            detail.title = healthy ? "Cloudflare • DNS over HTTPS" : "Encrypted resolver is not responding"
            message = healthy ? "Cloudflare DNS over HTTPS is configured and the local resolver is responding." : "DNS over HTTPS is configured, but the encrypted resolver isn't responding. Pause protection if you need to sign in to Wi-Fi."
            if let owner {
                switch owner {
                case "vpn":
                    if mode == "vpn-managed" {
                        headline.title = "DNS managed by VPN"
                        status.button?.title = "DNS VPN"
                    }
                    detail.title = healthy ? "Your VPN handles default DNS lookups" : "Private DNS resolver is not responding"
                    message = "macOS routes default DNS lookups through a VPN tunnel interface. Your VPN controls where those lookups go. Private DNS remains enabled, but those queries are outside its verified protection. This is an expected VPN configuration, not a reason to click Resume.\n\nPrivate DNS cannot verify the VPN's DNS provider or upstream encryption. It leaves VPN settings unchanged. When macOS routes DNS back to Private DNS, the status updates automatically."
                    if !healthy { message += "\n\nThe Private DNS resolver is also not responding and needs attention before its protection can resume reliably." }
                case "tailscale":
                    if mode == "managed" {
                        headline.title = "DNS managed by Tailscale"
                        status.button?.title = "DNS Tailscale"
                    }
                    detail.title = "Tailscale upstream encryption is unverified"
                    message = "macOS lists Tailscale as its default DNS resolver. Private DNS remains enabled, but cannot verify which provider or encryption Tailscale uses upstream. This is not a claim that your public DNS is protected by Private DNS.\n\nTailscale can handle public lookups itself or through an exit node (another device that routes your internet traffic). Its presence alone does not prove those lookups use HTTPS. Private DNS leaves these settings unchanged."
                    if !healthy { message += "\n\nThe Private DNS resolver is also not responding. Its protection cannot resume reliably until it recovers." }
                case "private-dns":
                    if healthy {
                        message = "The default DNS resolver is Private DNS, and its Cloudflare HTTPS resolver is responding."
                    }
                    if value["splitDNS"] as? Bool == true {
                        detail.title = "Default DNS: Cloudflare • Other domains: separate DNS"
                        message += "\n\nSome domains use separate DNS settings. These routes are preserved and are outside Private DNS's verified protection."
                        if value["tailscaleDNS"] as? Bool == true {
                            message += " Tailscale's MagicDNS lets you reach your devices by name instead of IP address."
                        }
                    }
                    if value["scopedDNS"] as? Bool == true {
                        detail.title = "Some network interfaces use other DNS"
                        message += "\n\nOther DNS servers are available to interface-specific queries. Private DNS cannot verify their encryption."
                    }
                    if value["tailscaleCoexistence"] as? Bool == true {
                        if mode == "on" && healthy {
                            detail.title = "Tailscale also handles some DNS queries"
                        }
                        message += "\n\nTailscale also handles some DNS queries alongside Private DNS. This is an expected configuration. Private DNS verifies its own default route, but cannot verify the provider or encryption of queries handled by Tailscale."
                    }
                    if value["vpnCoexistence"] as? Bool == true {
                        if mode == "on" && healthy { detail.title = "Your VPN also handles some DNS queries" }
                        message += "\n\nYour VPN supplies additional DNS routes alongside Private DNS. Queries using those routes are controlled by the VPN and are outside Private DNS's verified protection. This is expected; VPN settings are left unchanged."
                    }
                    if !healthy { detail.title = "Encrypted resolver is not responding" }
                case "unknown":
                    detail.title = "System DNS routing could not be verified"
                    message = "Private DNS cannot determine the default DNS route from macOS. A responding local resolver alone does not establish that your apps are using it."
                default:
                    detail.title = "Default DNS bypasses Private DNS"
                    message = "macOS lists other or mixed default DNS servers. Private DNS cannot verify the provider or encryption for those routes. VPN and third-party DNS settings have been preserved."
                }
            } else if value["override"] as? Bool == true {
                // Preserve accurate behavior when newer controls talk to an older service.
                message += "\n\nA VPN or another DNS resolver currently takes priority. Private DNS does not disconnect or change your VPN."
            }
            if let routes = value["defaultDNSRoutes"] as? [String], !routes.isEmpty {
                message += "\n\nDefault DNS servers reported by macOS:\n" + routes.joined(separator: "\n")
            }
            if mode == "partial" {
                headline.title = "DoH is on with exclusions"; status.button?.title = "DoH Partial"
                detail.title = "Custom DNS preserved • See Details"
            }
            let conflicts = value["conflicts"] as? [String] ?? []
            if value["excludedServices"] == nil && !conflicts.isEmpty { message += "\n\nOther DNS settings were preserved for: " + conflicts.joined(separator: ", ") + ". These services are outside Private DNS protection." }
        }
        if let excluded = value["excludedServices"] as? [String], !excluded.isEmpty {
            message += "\n\nPreserved custom DNS (excluded from Private DNS protection):\n\n" + excluded.joined(separator: "\n\n")
            message += "\n\nKeep these settings if they are needed for your devices or work networks. Disabled services and services outside the current location are listed for reference."
        }
        message += "\n\nPrivate DNS re-enables at every restart. Timed pauses also expire while the controls are closed; after sleep, they expire when the service runs again. VPN DNS may still take priority."
        let nextBadge: StatusBadge
        if value["ok"] as? Bool != true { nextBadge = .attention }
        else if !enabled { nextBadge = .paused }
        else {
            switch mode {
            case "starting": nextBadge = .starting
            case "on": nextBadge = .protected
            case "managed", "vpn-managed", "partial": nextBadge = .routes
            default: nextBadge = .attention
            }
        }
        setBadge(nextBadge)
        status.button?.toolTip = message
        summary = message + "\n\n" + """
        What is DoH?
        DoH means DNS over HTTPS. DNS looks up the internet address for a name such as example.com so your Mac can connect. DNS still works when DoH is off.

        When DoH is on
        Lookups routed through Private DNS are encrypted on their way to Cloudflare. Your ISP, employer, school, or Wi-Fi operator cannot read or alter those lookups in transit on the network. Domain-specific, interface-specific, and VPN DNS can take a different route.

        When DoH is off or paused
        Your Mac uses network-provided DNS. Unless another app or VPN encrypts it, these lookups can reveal the domain names of websites and services you use to your ISP and the operator of your work, school, or Wi-Fi network, even when websites use HTTPS.

        Privacy limits
        Cloudflare can still see the lookups it resolves. DoH is not a VPN: networks may still infer sites from connection information, and monitoring software on your Mac may see your activity. Apps or VPNs using their own DNS may bypass this protection.
        """
        updateDetails()
        quitApp.isEnabled = !changing; quitControls.isEnabled = !changing
        resume.isEnabled = !changing && (!enabled || (mode == "attention" && owner != "tailscale" && owner != "vpn"))
        [pause15!, pause60!, pauseBoot!].forEach { $0.isEnabled = !changing && value["ok"] as? Bool == true }
    }
    func refresh() {
        guard !changing && !refreshing else { return }; refreshing = true
        lastRefreshAt = ProcessInfo.processInfo.systemUptime
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
    func checkForScheduledUpdates(now: Date = Date()) {
        guard updateSchedule.isDue(now: now) else { return }
        performUpdateCheck(background: true, now: now)
    }
    func restoreUpdateMenu() {
        updateItem.isEnabled = true
        updateItem.title = availableUpdateVersion.map { "Update Available (\($0))…" } ?? "Check for Updates…"
    }
    @objc func checkForUpdates() { performUpdateCheck(background: false) }
    func performUpdateCheck(background: Bool, now: Date = Date()) {
        guard !updating else { return }
        updateSchedule.recordAttempt(now: now)
        updating = true; updateItem.isEnabled = false; updateItem.title = "Checking for Updates…"
        Task { @MainActor in
            defer { updating = false; restoreUpdateMenu() }
            @MainActor func alert(_ title: String, _ message: String) -> NSAlert {
                let alert = NSAlert(); alert.messageText = title; alert.informativeText = message
                alert.icon = AppIcon.application()
                NSApp.activate(ignoringOtherApps: true)
                return alert
            }
            do {
                let current = currentUpdateVersion
                let candidate = try await lookupUpdate(current)
                availableUpdateVersion = candidate?.version
                if background { return }
                guard let candidate else {
                    alert("You're up to date", "Private DNS \(current) is the latest available version.").runModal(); return
                }
                let offer = alert("Private DNS \(candidate.version) is available", "You have version \(current). Download and verify the update, then open the macOS installer? Your DNS settings will be preserved. The installer requests administrator authorization and briefly restarts Private DNS.")
                offer.addButton(withTitle: "Download Update"); offer.addButton(withTitle: "Not Now")
                guard offer.runModal() == .alertFirstButtonReturn else { return }
                updateItem.title = "Downloading and Verifying…"
                let package = try await Updates.download(candidate)
                let ready = alert("Update verified", "Private DNS \(candidate.version) is ready. Continue in the macOS installer to install it.")
                ready.addButton(withTitle: "Open Installer"); ready.addButton(withTitle: "Cancel")
                guard ready.runModal() == .alertFirstButtonReturn else {
                    try? FileManager.default.removeItem(at: package.deletingLastPathComponent()); return
                }
                guard NSWorkspace.shared.open(package) else { throw error("macOS could not open the verified installer. Try again.") }
            } catch {
                if !background { alert("Could not update Private DNS", error.localizedDescription).runModal() }
            }
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
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 412), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "Private DNS"; w.isReleasedWhenClosed = false; w.center()
            let icon = NSImageView(frame: NSRect(x: 0, y: 0, width: 72, height: 72))
            icon.image = AppIcon.template()
            icon.contentTintColor = .labelColor
            icon.imageScaling = .scaleProportionallyUpOrDown
            icon.setAccessibilityLabel("Private DNS globe and lock")
            detailsDocument.addSubview(icon)
            let scroller = NSScrollView(frame: NSRect(x: 17, y: 20, width: 498, height: 384))
            scroller.hasVerticalScroller = true; scroller.autohidesScrollers = true
            scroller.drawsBackground = false
            text.font = .systemFont(ofSize: 14)
            detailsDocument.addSubview(text)
            scroller.documentView = detailsDocument
            w.contentView?.addSubview(scroller); scroll = scroller; window = w
        }
        updateDetails(); window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func updateDetails() {
        text.stringValue = summary
        guard let scroll else { return }
        let origin = scroll.contentView.bounds.origin
        let width = scroll.contentSize.width - 8
        let height = text.sizeThatFits(NSSize(width: width, height: .greatestFiniteMagnitude)).height
        text.frame = NSRect(x: 8, y: 89, width: width, height: ceil(height))
        detailsDocument.frame = NSRect(x: 0, y: 0, width: scroll.contentSize.width,
                                      height: max(89 + ceil(height), scroll.contentSize.height))
        scroll.contentView.scroll(to: NSPoint(x: 0, y: min(origin.y, max(0, detailsDocument.frame.height - scroll.contentSize.height))))
        scroll.reflectScrolledClipView(scroll.contentView)
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
#if !CONTROLS_TESTING
@main struct ControlsMain {
    static func main() {
        let controller = Controls()
        NSApplication.shared.delegate = controller
        withExtendedLifetime(controller) { NSApplication.shared.run() }
    }
}
#endif
