# Private DNS icon

Google Material Icons globe/lock SVG supplied and approved by the user. Distributed under Apache 2.0; see LICENSE.txt. The original path is preserved in vpn-lock.svg.

padded.svg widens the viewBox to add space around the unchanged glyph. Template.png is a transparent 1024px render used by AppKit. In-app views use the system label color for light and dark appearances. PrivateDNS.icns supplies a white-on-black app icon for macOS 13 and later. Details and menu-bar glyphs retain their adaptive template colors.

To regenerate the app artwork and all ICNS sizes:

```sh
python3 Resources/Icon/generate-app-icon.py
```

`AppIcon.svg` and `AppIcon.png` are square 1024px white-on-black masters, with the unchanged logo filling 78% of the canvas. `AppIcon-macOS.svg` and `.png` use the identical opaque square artwork. Every ICNS representation has an edge-to-edge black background, with no inset tile, border, or transparent padding. The generator uses the exact path from the original SVG. Update dialogs use this same app icon.

The normal build copies the generated resources and license, so ImageMagick is not required to build the app.

`StatusTemplate.png` renders the original unpadded SVG at 72 × 72 pixels for the 18-point menu-bar template image. macOS supplies its color. Regenerate with:

```sh
magick -background none -density 288 Resources/Icon/vpn-lock.svg -resize 72x72 Resources/Icon/StatusTemplate.png
```

The generator also creates `AppIcon.xcassets`. The build compiles it with Apple’s `actool` and merges its generated icon metadata into Info.plist. macOS uses this asset catalog instead of framing the standalone legacy ICNS. The native NSWorkspace icon lookup was verified without a pale border.
