#!/bin/bash
set -euo pipefail
src="$(cd "$(dirname "$0")" && pwd)"
build="${BUILD_DIR:-$src/build}"
release="${RELEASE_DIR:-$src/Releases/Builds}"
version='2.0'
mkdir -p "$build" "$release"
root="$build/root"
scripts="$build/scripts"
rm -rf "$root" "$scripts"
mkdir -p "$root/Applications" "$root/Library/LaunchDaemons" "$root/Library/LaunchAgents" "$root/Library/PrivilegedHelperTools" "$scripts"
app="$root/Applications/Private DNS.app"
uninstaller="$root/Applications/Uninstall Private DNS.app"
runtime="$root/Library/Application Support/Private DNS/Runtime"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$uninstaller/Contents/MacOS" "$uninstaller/Contents/Resources" "$runtime"
swiftc -O -file-prefix-map "$src=/PrivateDNS/Source" -target arm64-apple-macos13.0 "$src/Sources/Core.swift" "$src/Sources/Service.swift" -o "$build/PrivateDNSService" -framework SystemConfiguration
swiftc -O -file-prefix-map "$src=/PrivateDNS/Source" -target arm64-apple-macos13.0 "$src/Sources/Core.swift" "$src/Sources/Controls.swift" -o "$app/Contents/MacOS/PrivateDNS" -framework Cocoa -framework SystemConfiguration
swiftc -O -file-prefix-map "$src=/PrivateDNS/Source" -target arm64-apple-macos13.0 "$src/Sources/Core.swift" "$src/Sources/Uninstaller.swift" -o "$uninstaller/Contents/MacOS/UninstallPrivateDNS" -framework Cocoa -framework SystemConfiguration
cp "$build/PrivateDNSService" "$root/Library/PrivilegedHelperTools/local-private-dns-helper"
cp "$build/PrivateDNSService" "$uninstaller/Contents/MacOS/PrivateDNSService"
cp "$build/PrivateDNSService" "$scripts/PrivateDNSService"
cp "$src/Resources/dnscrypt-proxy" "$runtime/dnscrypt-proxy"
cp "$src/Resources/dnscrypt-proxy.toml" "$runtime/dnscrypt-proxy.toml"
cp "$src/Resources/dnscrypt-proxy-LICENSE.txt" "$src/Resources/dnscrypt-proxy-README.txt" "$app/Contents/Resources/"
cp "$src/Resources/controls-service.sh" "$app/Contents/Resources/controls-service.sh"
cp "$src/Packaging/uninstall.sh" "$uninstaller/Contents/Resources/uninstall.sh"
cp "$src/Packaging/preinstall" "$src/Packaging/postinstall" "$scripts/"
chmod 755 "$scripts/preinstall" "$scripts/postinstall" "$scripts/PrivateDNSService"
chmod 755 "$app/Contents/MacOS/PrivateDNS" "$uninstaller/Contents/MacOS/UninstallPrivateDNS" "$uninstaller/Contents/MacOS/PrivateDNSService" "$runtime/dnscrypt-proxy"
python3 "$src/Packaging/metadata.py" "$root" "$version"
"$runtime/dnscrypt-proxy" -config "$runtime/dnscrypt-proxy.toml" -check
if [ -n "${SIGNING_IDENTITY:-}" ]; then
    sign=(/usr/bin/codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY")
else
    sign=(/usr/bin/codesign --force --options runtime --sign -)
fi
"${sign[@]}" --identifier local.private-dns.engine "$runtime/dnscrypt-proxy"
for binary in "$root/Library/PrivilegedHelperTools/local-private-dns-helper" "$scripts/PrivateDNSService" "$uninstaller/Contents/MacOS/PrivateDNSService"; do "${sign[@]}" --identifier local.private-dns.helper "$binary"; done
cp "$runtime/dnscrypt-proxy" "$scripts/dnscrypt-proxy"
cp "$runtime/dnscrypt-proxy.toml" "$scripts/dnscrypt-proxy.toml"
"${sign[@]}" "$app"
"${sign[@]}" "$uninstaller"
codesign --verify --deep --strict "$app"
codesign --verify --deep --strict "$uninstaller"
pkgbuild --analyze --root "$root" "$build/components.plist"
python3 - "$build/components.plist" <<'PYCOMP'
import plistlib, sys
from pathlib import Path
p = Path(sys.argv[1])
components = plistlib.loads(p.read_bytes())
for item in components:
    item.update(BundleIsRelocatable=False, BundleIsVersionChecked=False, BundleHasStrictIdentifier=True)
p.write_bytes(plistlib.dumps(components))
PYCOMP
pkgbuild --root "$root" --component-plist "$build/components.plist" --scripts "$scripts" --identifier local.private-dns.package --version "$version" --install-location / --ownership recommended "$build/component.pkg"
python3 "$src/Packaging/distribution.py" "$build"
if [ -n "${INSTALLER_IDENTITY:-}" ]; then
    productbuild --distribution "$build/Distribution.xml" --package-path "$build" --sign "$INSTALLER_IDENTITY" "$release/Private-DNS-$version-Apple-Silicon.pkg"
else
    productbuild --distribution "$build/Distribution.xml" --package-path "$build" "$release/Private-DNS-$version-Apple-Silicon-UNSIGNED.pkg"
fi
ditto -c -k --sequesterRsrc --keepParent "$uninstaller" "$release/Uninstall-Private-DNS.zip"
if [ -n "${NOTARY_PROFILE:-}" ]; then
    test -n "${SIGNING_IDENTITY:-}" && test -n "${INSTALLER_IDENTITY:-}"
    pkg="$release/Private-DNS-$version-Apple-Silicon.pkg"
    xcrun notarytool submit "$pkg" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$pkg"
    xcrun stapler validate "$pkg"
    spctl --assess --type install --verbose "$pkg"
    xcrun notarytool submit "$release/Uninstall-Private-DNS.zip" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$uninstaller"
    ditto -c -k --sequesterRsrc --keepParent "$uninstaller" "$release/Uninstall-Private-DNS.zip"
    spctl --assess --type execute --verbose "$uninstaller"
fi
echo "Build complete: $release"
