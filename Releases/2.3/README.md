# Private DNS

**Keep your Mac’s DNS lookups private from the network you’re using.** Private DNS encrypts these requests so your internet provider and Wi-Fi operator can’t simply read or alter them in transit.

DNS lookups reveal the domain names your Mac connects to. When sent unencrypted, your home ISP, mobile carrier when tethering, or office network administrator can read and log them, even when the website uses HTTPS or you use a private browsing window. Private DNS closes that privacy gap for lookups using your Mac’s system resolver.

Install it once: it sends those requests to **Cloudflare over HTTPS**, starts automatically at boot, and gives you a simple menu-bar pause for airplane or hotel Wi-Fi. No Homebrew required.

**Requirements:** Apple Silicon, macOS 13 or later, and an administrator account. Tested on macOS 27.0.1; Intel Macs are not supported.

## Install

1. Download **[Private-DNS-2.3-Apple-Silicon.pkg](https://github.com/misterburton/mb-private-dns/releases/download/v2.3/Private-DNS-2.3-Apple-Silicon.pkg)** from [Releases](https://github.com/misterburton/mb-private-dns/releases/latest).
2. Open the package and follow the installer, authorizing with your Mac administrator password when prompted.
3. Look for **DoH On** in the menu bar. Protection runs in the background and re-enables at every restart.

The installer and standalone uninstaller are Developer ID signed and notarized by Apple. If another DNS configuration conflicts, the installer stops rather than overwriting it.


## Airplane, hotel, or public Wi-Fi

Choose **Pause for 15 Minutes** or **Pause for 1 Hour** from the DoH menu, then complete the network’s sign-in page. Protection resumes automatically; select **Resume Protection** to turn it on sooner. **Pause Until Restart** is also available. Choose **Quit Private DNS** to restore network DNS and stop the app and its background processes. macOS asks for administrator authorization. Reopening the app or restarting your Mac enables protection again. **Quit Controls (protection continues)** closes only the menu controls.

## Update

Choose **Check for Updates…** from the menu bar. If an update is available, choose **Download Update**, then **Open Installer** after verification. The updater checks the download checksum, the expected Apple developer signature, and macOS Gatekeeper approval. The installer preserves saved settings and briefly restarts Private DNS; authorize installation with your administrator password. Checking and downloading do not require authorization.

The app checks GitHub at launch and every 24 hours while the menu controls are running. After sleep, an overdue check runs once. When a newer version is found, the menu shows **Update Available (version)…**. Background checks stay quiet when offline and never download or install automatically. You can check manually at any time; checks and downloads require no GitHub sign-in. Version 2.2 users can install this version through **Check for Updates…**. Earlier versions need a manual installation first.

## Uninstall

1. Open **Uninstall Private DNS** in Applications. Alternatively, download [Uninstall-Private-DNS.zip](https://github.com/misterburton/mb-private-dns/releases/download/v2.3/Uninstall-Private-DNS.zip), extract it, and open the app.
2. Choose **Uninstall** and authorize with your Mac administrator password.
3. The uninstaller restores saved DNS addresses, preserves later changes by other tools, and removes Private DNS’s apps and background components.

Use the uninstaller instead of dragging the app to Trash. An administrator-only recovery archive remains in `/Library/Application Support/Private DNS Uninstall Backup-<date>`.

## Protection and compatibility

Encrypted DNS protects against **network snooping, logging of plaintext DNS requests, and tampering with those requests in transit**. It reduces the information your network gets about the sites and services you use. [How DNS encryption protects you](https://developers.cloudflare.com/1.1.1.1/encryption/).

Cloudflare resolves the queries and can see them. Networks may still identify destinations through IP addresses or other connection information, and monitoring software on a managed Mac can see more. VPNs or apps with their own DNS may take another path. Pausing temporarily restores network DNS; network changes can also create brief gaps in coverage.

See [verification notes](Releases/2.3/Verification.txt) for tested behavior and remaining limitations, including untested airplane Wi-Fi and actual reboot behavior.

## Tailscale compatibility

MagicDNS is Tailscale's device naming feature: it lets you connect to a device by name instead of its IP address. Private DNS preserves those routes and your VPN settings.

The updated controls distinguish a separate route for private names from Tailscale managing default DNS. In the latter case, they show **DNS managed by Tailscale**, with upstream encryption marked unverified. Actual resolver failures still require attention. This prevents an expected VPN configuration from looking like a broken app without claiming protection we cannot verify.

Automated routing and menu checks pass. Live Tailscale connection and exit-node behavior remain unverified. See [research and test results](Releases/Tailscale-Compatibility-Verification.md).

## Files and development

Local downloads: **Documents → GitHub → mb-private-dns → Releases → 2.3**. Downloads are public and require no GitHub account.

Source lives in `Sources/`, installer scripts in `Packaging/`, and the bundled dnscrypt-proxy engine and ISC license in `Resources/`. Run `build.sh` to build; new artifacts go to `Releases/Builds`. See [build and signing instructions](README.txt). Private keys and notarization credentials stay in Keychain.

Run `bash test.sh` for policy, resolver routing, and AppKit menu tests. Add `--live` to read and classify the current macOS DNS snapshot without changing it.
