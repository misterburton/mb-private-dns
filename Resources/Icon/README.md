# Private DNS icon

Google Material Icons globe/lock SVG supplied and approved by the user. Distributed under Apache 2.0; see LICENSE.txt. The original path is preserved in vpn-lock.svg.

padded.svg widens the viewBox to add space around the unchanged glyph. Template.png is a transparent 1024px render used by AppKit. In-app views use the system label color for light and dark appearances. PrivateDNS.icns supplies a black-on-white Finder icon for macOS 13 and later; Finder's icon is static, while in-app icons adapt to appearance.

To regenerate with ImageMagick and Apple's iconutil:

```sh
magick -background none Resources/Icon/padded.svg Resources/Icon/Template.png
mkdir -p build/PrivateDNS.iconset
for size in 16 32 128 256 512; do
  magick Resources/Icon/Template.png -background white -alpha remove -resize "${size}x${size}" "build/PrivateDNS.iconset/icon_${size}x${size}.png"
  double=$((size * 2))
  magick Resources/Icon/Template.png -background white -alpha remove -resize "${double}x${double}" "build/PrivateDNS.iconset/icon_${size}x${size}@2x.png"
done
iconutil -c icns build/PrivateDNS.iconset -o Resources/Icon/PrivateDNS.icns
```

The normal build copies the generated resources and license, so ImageMagick is not required to build the app.

`StatusTemplate.png` renders the original unpadded SVG at 72 × 72 pixels for the 18-point menu-bar template image. macOS supplies its color. Regenerate with:

```sh
magick -background none -density 288 Resources/Icon/vpn-lock.svg -resize 72x72 Resources/Icon/StatusTemplate.png
```
