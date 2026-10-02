# Private DNS

System-wide DNS over HTTPS controls for Apple Silicon Macs. Includes its DNS engine, starts at boot, and provides timed pauses for Wi-Fi sign-in.

## Installer and uninstaller

On this Mac, open **Documents → GitHub → private-dns → Releases → 2.0**.

- `Private-DNS-2.0-Apple-Silicon.pkg` — signed and notarized installer
- `Uninstall-Private-DNS.zip` — signed and notarized uninstaller
- `README.txt` — installation, pause, and removal instructions
- `Verification.txt` — tests performed and limitations

Downloadable files are also attached to the GitHub **v2.0** release. The repository is private.

## Source

- `Sources/`: macOS controls, privileged helper, uninstaller, and policy tests
- `Packaging/`: installer, removal scripts, and package metadata
- `Resources/`: bundled ARM64 dnscrypt-proxy and its ISC license
- `build.sh`: build, Developer ID signing, and optional notarization

See [README.txt](README.txt) for build environment variables and privacy limitations. New builds go into `Releases/Builds` by default. Signing private keys and notarization credentials stay in macOS Keychain and are not included here.

Requires macOS 13 or newer; tested on macOS 27.0.1. Intel Macs are not supported.
