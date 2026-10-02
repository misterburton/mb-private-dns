# Private DNS

Private DNS sends your Mac’s system DNS queries to **Cloudflare over HTTPS**, with a quiet menu-bar control and timed pauses for Wi-Fi sign-in. It starts at boot and includes its own DNS engine—no Homebrew required.

**Requirements:** Apple Silicon, macOS 13 or later, and an administrator account. Tested on macOS 27.0.1; Intel Macs are not supported.

## Install

1. Download **[Private-DNS-2.0-Apple-Silicon.pkg](https://github.com/misterburton/mb-private-dns/releases/download/v2.0/Private-DNS-2.0-Apple-Silicon.pkg)** from [Releases](https://github.com/misterburton/mb-private-dns/releases/latest).
2. Open the package and follow the installer, authorizing with your Mac administrator password when prompted.
3. Look for **DNS On** in the menu bar. Protection runs in the background and re-enables at every restart.

The installer and standalone uninstaller are Developer ID signed and notarized by Apple. If another DNS configuration conflicts, the installer stops rather than overwriting it.

## Airplane, hotel, or public Wi-Fi

Choose **Pause for 15 Minutes** or **Pause for 1 Hour** from the DNS menu, then complete the network’s sign-in page. Protection resumes automatically; select **Resume Protection** to turn it on sooner. **Pause Until Restart** is also available. Quitting the controls does not stop protection.

## Uninstall

1. Open **Uninstall Private DNS** in Applications. Alternatively, download [Uninstall-Private-DNS.zip](https://github.com/misterburton/mb-private-dns/releases/download/v2.0/Uninstall-Private-DNS.zip), extract it, and open the app.
2. Choose **Uninstall** and authorize with your Mac administrator password.
3. The uninstaller restores saved DNS addresses, preserves later changes by other tools, and removes Private DNS’s apps and background components.

Use the uninstaller instead of dragging the app to Trash. An administrator-only recovery archive remains in `/Library/Application Support/Private DNS Uninstall Backup-<date>`.

## Privacy and compatibility

Cloudflare receives your DNS queries. This does not provide anonymity, hide destination IP addresses, or block trackers. VPNs and apps with their own DNS may use another resolver. Pausing restores network-provided DNS, which may be unencrypted. Network transitions are checked periodically; this is not a guarantee against every DNS leak.

See [verification notes](Releases/2.0/Verification.txt) for tested behavior and remaining limitations, including untested airplane Wi-Fi and actual reboot behavior.

## Files and development

Local downloads: **Documents → GitHub → mb-private-dns → Releases → 2.0**. GitHub downloads require access to this private repository; you can share the downloaded installer directly.

Source lives in `Sources/`, installer scripts in `Packaging/`, and the bundled dnscrypt-proxy engine and ISC license in `Resources/`. Run `build.sh` to build; new artifacts go to `Releases/Builds`. See [build and signing instructions](README.txt). Private keys and notarization credentials stay in Keychain.
