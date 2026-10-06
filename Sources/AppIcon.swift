import Cocoa

enum StatusBadge: String {
    case protected = "protected", paused = "paused", starting = "starting-checking"
    case routes = "vpn-other-routes", attention = "needs-attention"
}

enum AppIcon {
    static func statusBadge(_ badge: StatusBadge, frame: Int = 0, bundle: Bundle = .main) -> NSImage? {
        let name = badge == .starting ? String(format: "loader-%02d", frame % 24) : badge.rawValue
        guard let url = bundle.url(forResource: name, withExtension: "png", subdirectory: "StatusBadges"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        image.accessibilityDescription = badge.rawValue
        return image
    }

    static func statusBar(bundle: Bundle = .main) -> NSImage? {
        guard let url = bundle.url(forResource: "StatusTemplate", withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        image.accessibilityDescription = "Private DNS"
        return image
    }
    static func template(bundle: Bundle = .main) -> NSImage? {
        guard let url = bundle.url(forResource: "Template", withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.isTemplate = true
        return image
    }
    static func application(bundle: Bundle = .main) -> NSImage? {
        guard let url = bundle.url(forResource: "AppIcon-macOS", withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.size = NSSize(width: 128, height: 128)
        return image
    }
}
