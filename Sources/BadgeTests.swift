import Cocoa
@main struct Smoke {
 static func main() {
  let app = NSApplication.shared
  let c = Controls(); c.configureMenu()
  let animated = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
  precondition((c.badgeTimer != nil) == animated)
  for (mode,enabled) in [("on",true),("paused",false),("starting",true),("managed",true),("vpn-managed",true),("partial",true),("attention",true)] {
   c.show(["ok":true,"enabled":enabled,"healthy":true,"mode":mode])
   let image = c.status.button!.image!
   precondition(image.isTemplate && image.size == NSSize(width:18,height:18))
   let pixels = NSBitmapImageRep(data:image.tiffRepresentation!)!
   var visible = 0
   for y in 0..<pixels.pixelsHigh { for x in 0..<pixels.pixelsWide { if pixels.colorAt(x:x,y:y)!.alphaComponent > 0.5 { visible += 1 } } }
   precondition(visible > 100, "Blank icon for \(mode)")
   precondition((c.badgeTimer != nil) == (mode == "starting" && animated))
  }
  c.show(["ok":true,"enabled":true,"mode":"starting"])
  let timer = c.badgeTimer
  RunLoop.current.run(until:Date().addingTimeInterval(0.12))
  if animated { precondition(c.badgeFrame > 0) }
  c.show(["ok":true,"enabled":true,"mode":"starting"])
  precondition(c.badgeTimer === timer)
  c.show(["ok":true,"enabled":true,"healthy":true,"mode":"on"])
  precondition(c.badgeTimer == nil)
  c.show(["ok":true,"enabled":true,"healthy":true,"mode":"on"])
  precondition(c.badgeTimer == nil)
  NSStatusBar.system.removeStatusItem(c.status)
  print("PASS: production AppKit controls load; all seven modes have visible 18pt template icons; loader advances, preserves timer across startup polls, stops on recovery, and stays off during healthy refresh")
  _ = app
 }
}
