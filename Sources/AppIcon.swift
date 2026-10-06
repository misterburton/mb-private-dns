import Cocoa

enum AppIcon {
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
