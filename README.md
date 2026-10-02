# Private DNS

**Keep your Mac’s DNS lookups private from the network you’re using.** Private DNS encrypts these requests so your internet provider and Wi-Fi operator can’t simply read or alter them in transit.

DNS lookups reveal the domain names your Mac connects to. When sent unencrypted, your home ISP, mobile carrier when tethering, or office network administrator can read and log them, even when the website uses HTTPS or you use a private browsing window. Private DNS closes that privacy gap for lookups using your Mac’s system resolver.

Install it once: it sends those requests to **Cloudflare over HTTPS**, starts automatically at boot, and gives you a simple menu-bar pause for airplane or hotel Wi-Fi. No Homebrew required.

**Requirements:** Apple Silicon, macOS 13 or later, and an administrator account. Tested on macOS 27.0.1; Intel Macs are not supported.

## Install

1. Download **[Private-DNS-2.0-Apple-Silicon.pkg](https://github.com/misterburton/mb-private-dns/releases/download/v2.0/Private-DNS-2.0-Apple-Silicon.pkg)** from [Releases](https://github.com/misterburton/mb-private-dns/releases/latest).
2. Open the package and follow the installer, authorizing with your Mac administrator password when prompted.
3. Look for **DoH On** in the menu bar. Protection runs in the background and re-enables at every restart.

The installer and standalone uninstaller are Developer ID signed and notarized by Apple. If another DNS configuration conflicts, the installer stops rather than overwriting it.

The published v2.0 installer predates the DoH labels and full **Quit Private DNS** action. These updates are in the current source and local controls update; a new notarized installer has not been published.

## Airplane, hotel, or public Wi-Fi

Choose **Pause for 15 Minutes** or **Pause for 1 Hour** from the DoH menu, then complete the network’s sign-in page. Protection resumes automatically; select **Resume Protection** to turn it on sooner. **Pause Until Restart** is also available. Choose **Quit Private DNS** to restore network DNS and stop the app and its background processes. macOS asks for administrator authorization. Reopening the app or restarting your Mac enables protection again. **Quit Controls (protection continues)** closes only the menu controls.

## Uninstall

1. Open **Uninstall Private DNS** in Applications. Alternatively, download [Uninstall-Private-DNS.zip](https://github.com/misterburton/mb-private-dns/releases/download/v2.0/Uninstall-Private-DNS.zip), extract it, and open the app.
2. Choose **Uninstall** and authorize with your Mac administrator password.
3. The uninstaller restores saved DNS addresses, preserves later changes by other tools, and removes Private DNS’s apps and background components.

Use the uninstaller instead of dragging the app to Trash. An administrator-only recovery archive remains in `/Library/Application Support/Private DNS Uninstall Backup-<date>`.

## Protection and compatibility

Encrypted DNS protects against **network snooping, logging of plaintext DNS requests, and tampering with those requests in transit**. It reduces the information your network gets about the sites and services you use. [How DNS encryption protects you](https://developers.cloudflare.com/1.1.1.1/encryption/).

Cloudflare resolves the queries and can see them. Networks may still identify destinations through IP addresses or other connection information, and monitoring software on a managed Mac can see more. VPNs or apps with their own DNS may take another path. Pausing temporarily restores network DNS; network changes can also create brief gaps in coverage.

See [verification notes](Releases/2.0/Verification.txt) for tested behavior and remaining limitations, including untested airplane Wi-Fi and actual reboot behavior.

## Files and development

Local downloads: **Documents → GitHub → mb-private-dns → Releases → 2.0**. GitHub downloads require access to this private repository; you can share the downloaded installer directly.

Source lives in `Sources/`, installer scripts in `Packaging/`, and the bundled dnscrypt-proxy engine and ISC license in `Resources/`. Run `build.sh` to build; new artifacts go to `Releases/Builds`. See [build and signing instructions](README.txt). Private keys and notarization credentials stay in Keychain.
