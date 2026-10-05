import Cocoa

enum AppIcon {
    static func template(bundle: Bundle = .main) -> NSImage? {
        guard let url = bundle.url(forResource: "Template", withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.isTemplate = true
        return image
    }
    static func adaptive(bundle: Bundle = .main) -> NSImage? {
        guard let template = template(bundle: bundle) else { return nil }
        template.isTemplate = false
        return NSImage(size: NSSize(width: 128, height: 128), flipped: false) { rect in
            template.draw(in: rect)
            NSColor.labelColor.setFill()
            rect.fill(using: .sourceIn)
            return true
        }
    }
}
