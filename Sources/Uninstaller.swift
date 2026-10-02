import Cocoa

@main struct UninstallMain {
    static func main() {
        NSApplication.shared.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Uninstall Private DNS?"
        alert.informativeText = "This restores the DNS settings saved before Private DNS was installed, stops its background service, and removes its apps. Later DNS changes made by other tools will be preserved. Your VPN and browser settings will not be changed."
        alert.addButton(withTitle: "Uninstall"); alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard let script = Bundle.main.path(forResource: "uninstall", ofType: "sh"), let helper = Bundle.main.path(forAuxiliaryExecutable: "PrivateDNSService") else { return }
        // Stage only our own signed resources outside Documents to avoid an elevated TCC read.
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("private-dns-uninstall-" + UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            let stagedScript = temp.appendingPathComponent("uninstall.sh"), stagedHelper = temp.appendingPathComponent("PrivateDNSService")
            try FileManager.default.copyItem(atPath: script, toPath: stagedScript.path)
            try FileManager.default.copyItem(atPath: helper, toPath: stagedHelper.path)
            defer { try? FileManager.default.removeItem(at: temp) }
            let quote: (String) -> String = { "'" + $0.replacingOccurrences(of: "'", with: "'\\''") + "'" }
            let command = "/bin/bash " + quote(stagedScript.path) + " " + quote(stagedHelper.path)
            let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            var failure: NSDictionary?
            let source = "do shell script \"\(escaped)\" with administrator privileges with prompt \"Restore your previous DNS settings and uninstall Private DNS.\""
            let result = NSAppleScript(source: source)?.executeAndReturnError(&failure)
            if let failure { throw error(failure[NSAppleScript.errorMessage] as? String ?? "Uninstall cancelled or failed.") }
            let done = NSAlert(); done.messageText = "Private DNS was uninstalled"; done.informativeText = result?.stringValue ?? "Your previous DNS settings were restored."; done.runModal()
        } catch { let failed = NSAlert(); failed.messageText = "Uninstall did not complete"; failed.informativeText = error.localizedDescription; failed.runModal() }
    }
}
