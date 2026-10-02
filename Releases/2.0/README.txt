Private DNS 2.0 — Apple Silicon Macs

Requires macOS 13 or later and an administrator account. Intel Macs are not supported.

INSTALL
Open Private-DNS-2.0-Apple-Silicon.pkg and follow the macOS installer.
Private DNS starts automatically. Look for DNS On in the menu bar. It does not open a control window at login.
The installer includes the DNS engine; Homebrew is not required.

AIRPLANE / HOTEL / PUBLIC WI-FI
Before signing in to a Wi-Fi portal, open the DNS menu and choose Pause for 15 Minutes or Pause for 1 Hour.
Sign in to Wi-Fi normally. Protection resumes automatically when the pause expires, or choose Resume Protection sooner.
Pause Until Restart is also available. Every restart re-enables protection.
Quitting the controls does not stop protection or the pause timer.

WHAT IT DOES
It configures supported physical network services to use a local resolver that sends DNS queries to Cloudflare over HTTPS.
It does not log your DNS queries locally. Cloudflare receives those queries as the selected DNS provider.
It does not make browsing anonymous or hide destination IP addresses from your network. It is not a VPN or a blocker for ads, trackers, or malicious sites.
Applications using their own DNS and VPN-provided DNS may bypass this resolver. The menu indicates when another default resolver takes priority, but it is not a comprehensive leak detector.
When enabled, it does not deliberately fall back to plaintext DNS if Cloudflare is unreachable. Pause protection to restore network DNS when necessary; queries may then be unencrypted.
Newly enabled or connected supported network services are checked periodically, so this is not a firewall guarantee against every startup or network-transition DNS query.

OTHER DNS TOOLS
The installer checks for manual DNS settings, DNS configuration profiles, and a conflicting local DNS listener. It stops with an explanation instead of overwriting those settings.
VPN settings are left unchanged. Private DNS cannot guarantee compatibility with every VPN, network filter, or DNS tool.
The menu controls require an administrator account.

UNINSTALL
Open Uninstall Private DNS in Applications, or extract and open the separate Uninstall-Private-DNS.zip.
Confirm removal and authorize with macOS when asked. The uninstaller restores DNS addresses saved before Private DNS changed them, preserving later third-party DNS changes.
It removes this product's running service, login item, and applications. It retains an administrator-only recovery archive in /Library/Application Support/Private DNS Uninstall Backup-<date>.
Do not remove only the application in Finder: the background service and DNS configuration require the uninstaller.
The uninstaller can also remove the original custom version of Private DNS if its original recovery backup is present.

THIRD-PARTY SOFTWARE
Includes dnscrypt-proxy 2.1.18 for Apple Silicon. Its ISC license and upstream README are included in Private DNS.app/Contents/Resources.

BUILD AND SIGN
Run build.sh with Xcode command line tools and Python 3 available.
Set SIGNING_IDENTITY to your Developer ID Application identity.
Set INSTALLER_IDENTITY to your Developer ID Installer identity.
Set NOTARY_PROFILE to the name of credentials already stored securely using Apple's notarytool.
BUILD_DIR and RELEASE_DIR can select output directories.
Without signing identities the script produces an explicitly UNSIGNED local test candidate.
Do not distribute that test candidate as a notarized release.
