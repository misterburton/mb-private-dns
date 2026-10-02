#!/bin/bash
set -euo pipefail
restoreHelper="${1:?Missing restoration helper}"
base='/Library/Application Support/Private DNS'
daemon='/Library/LaunchDaemons/local.private-dns.resolver.plist'
if [ "$EUID" -ne 0 ]; then echo 'Administrator authorization is required.' >&2; exit 1; fi
if [ ! -d "$base" ]; then echo 'Private DNS is not installed.'; exit 0; fi
if [ -L "$base" ]; then echo 'Unexpected application support path; refusing to remove it.' >&2; exit 1; fi
restartOnFailure() {
    echo 'Restoration failed. Private DNS files were preserved.' >&2
    if [ -f "$daemon" ]; then /bin/launchctl bootstrap system "$daemon" 2>/dev/null || true; fi
}
trap restartOnFailure ERR
/bin/launchctl bootout system/local.private-dns.resolver 2>/dev/null || true
"$restoreHelper" --restore
# Foundation can place the resolver in its own process group. Stop that exact child too.
/usr/bin/pkill -f '^/Library/Application Support/Private DNS/Runtime/dnscrypt-proxy( |$)' 2>/dev/null || true
trap - ERR
/usr/bin/killall PrivateDNS 2>/dev/null || true
# Unload the app's login item in every active GUI session where it exists.
for userID in $(/usr/bin/dscl . -list /Users UniqueID | /usr/bin/awk '$2 >= 500 && $2 < 65534 {print $2}'); do
    /bin/launchctl bootout "gui/$userID/local.private-dns.controls" 2>/dev/null || true
done
for agent in /Users/*/Library/LaunchAgents/local.private-dns.controls.plist; do
    [ -f "$agent" ] || continue
    /bin/rm -f "$agent"
done
/bin/rm -f "$daemon" '/Library/LaunchAgents/local.private-dns.controls.plist' '/Library/PrivilegedHelperTools/local-private-dns-helper' '/var/run/local.private-dns.sock'
for bundle in '/Applications/Private DNS.app' '/Applications/Uninstall Private DNS.app'; do
    [ -d "$bundle" ] || continue
    identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$bundle/Contents/Info.plist")
    case "$identifier" in local.private-dns.controls|local.private-dns.uninstaller) /bin/rm -rf "$bundle";; esac
done
# Retain an administrator-only recovery archive, not a running service.
archive="/Library/Application Support/Private DNS Uninstall Backup-$(/bin/date +%Y%m%d-%H%M%S)"
/bin/chmod 700 "$base"
/bin/mv "$base" "$archive"
/usr/sbin/pkgutil --forget local.private-dns.package >/dev/null 2>&1 || true
echo "Original DNS settings restored. Private DNS and its startup items were removed. Recovery information was retained in $archive."
