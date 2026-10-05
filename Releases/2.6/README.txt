Private DNS 2.6 ;  Apple Silicon Macs

Keep your Mac's DNS lookups private from the network you're using. Private DNS encrypts system domain lookups so your ISP or Wi-Fi operator cannot simply read or alter those requests in transit.
Unencrypted DNS can expose the domains you connect to to your home ISP, mobile carrier when tethering, or office network administrator, even when sites use HTTPS or your browser is in private mode. Install once to protect these lookups automatically, with a quick pause for Wi-Fi sign-in.

Requires macOS 13 or later and an administrator account. Intel Macs are not supported.

INSTALL
Open Private-DNS-2.6-Apple-Silicon.pkg and follow the macOS installer.
Private DNS starts automatically. Look for DoH On in the menu bar. It does not open a control window at login.
The installer includes the DNS engine; Homebrew is not required.

AIRPLANE / HOTEL / PUBLIC WI-FI
Before signing in to a Wi-Fi portal, open the DoH menu and choose Pause for 15 Minutes or Pause for 1 Hour.
Sign in to Wi-Fi normally. Protection resumes automatically when the pause expires, or choose Resume Protection sooner.
Pause Until Restart is also available. Every restart re-enables protection.
Quit Private DNS restores network DNS and stops the app and its background processes, with macOS administrator authorization. Reopening the app or restarting your Mac enables protection again. Quit Controls (protection continues) closes only the menu controls; protection and pause timers continue.

WHAT IT PROTECTS
Encrypted DNS protects against network snooping, logging of plaintext DNS requests, and tampering with those requests in transit. This removes one common source of information about the sites and services you use.
It configures supported physical network services to use a local resolver that sends DNS queries to Cloudflare over HTTPS.
It does not log your DNS queries locally. Cloudflare receives those queries as the selected DNS provider.
Networks may still identify destinations from IP addresses or other connection information. Monitoring software on a managed Mac can see more. DNS privacy is one layer of protection, not anonymity.
Applications using their own DNS and VPN-provided DNS may bypass this resolver. The menu indicates when another default resolver takes priority, but it is not a comprehensive leak detector.
When enabled, it does not deliberately fall back to plaintext DNS if Cloudflare is unreachable. Pause protection to restore network DNS when necessary; queries may then be unencrypted.
Newly enabled or connected supported network services are checked periodically, so this is not a firewall guarantee against every startup or network-transition DNS query.

OTHER DNS TOOLS
The installer preserves manual DNS settings without blocking installation. Details identifies excluded services by name, unique ID, interface, location and DNS addresses. Disabled services and services outside the current location remain untouched. DNS configuration profiles and a conflicting local DNS listener still stop installation before changes; see Window > Installer Log for the explanation.
VPN settings are left unchanged. Private DNS cannot guarantee compatibility with every VPN, network filter, or DNS tool.
The menu controls require an administrator account.

UPDATE
Choose Check for Updates from the menu bar, then Download Update and Open Installer. The updater verifies the checksum, expected developer signature, and Gatekeeper approval. The existing installer preserves saved settings and briefly restarts Private DNS. Administrator authorization is required only for installation.
Downloads are public; no GitHub account is required. The menu app checks GitHub at launch and every 24 hours, catching up once after sleep. A newer release changes the menu to Update Available (version). Offline background checks stay quiet; downloads and installation remain manual. Closing the controls stops scheduled checks. Version 2.2 can update through Check for Updates; earlier versions need one manual update.
Tailscale-managed DNS is reported separately, with upstream encryption unverified. The connected Tailscale coexistence case is covered by a captured resolver snapshot and menu tests; exit-node behavior remains untested.

UNINSTALL
Open Uninstall Private DNS in Applications, or extract and open the separate Uninstall-Private-DNS.zip.
Confirm removal and authorize with macOS when asked. The uninstaller restores DNS addresses saved before Private DNS changed them, preserving later third-party DNS changes.
It removes this product's running service, login item, and applications. It retains an administrator-only recovery archive in /Library/Application Support/Private DNS Uninstall Backup-<date>.
Do not remove only the application in Finder: the background service and DNS configuration require the uninstaller.
The uninstaller can also remove the original custom version of Private DNS if its original recovery backup is present.

THIRD-PARTY SOFTWARE
Includes dnscrypt-proxy 2.1.18 for Apple Silicon. Its ISC license and upstream README are included in Private DNS.app/Contents/Resources.

BUILD AND SIGN
Run bash test.sh for policy, routing, and AppKit menu tests. Optional --live reads current DNS routing without changing settings.
Run build.sh with Xcode command line tools and Python 3 available.
Set SIGNING_IDENTITY to your Developer ID Application identity.
Set INSTALLER_IDENTITY to your Developer ID Installer identity.
Set NOTARY_PROFILE to the name of credentials already stored securely using Apple's notarytool.
BUILD_DIR and RELEASE_DIR can select output directories.
Without signing identities the script produces an explicitly UNSIGNED local test candidate.
Do not distribute that test candidate as a notarized release.
