import plistlib
import sys
from pathlib import Path

root = Path(sys.argv[1])
version = sys.argv[2]
for folder, name, executable, ident in [
    ('Private DNS.app', 'Private DNS', 'PrivateDNS', 'local.private-dns.controls'),
    ('Uninstall Private DNS.app', 'Uninstall Private DNS', 'UninstallPrivateDNS', 'local.private-dns.uninstaller'),
]:
    info = {'CFBundleName': name, 'CFBundleDisplayName': name, 'CFBundleExecutable': executable,
            'CFBundleIdentifier': ident, 'CFBundleVersion': version, 'CFBundleShortVersionString': version,
            'CFBundlePackageType': 'APPL', 'LSMinimumSystemVersion': '13.0', 'LSUIElement': True,
            'NSHighResolutionCapable': True, 'LSArchitecturePriority': ['arm64']}
    if ident == 'local.private-dns.controls':
        info['CFBundleIconFile'] = 'PrivateDNS.icns'
    (root / 'Applications' / folder / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
daemon = {'Label': 'local.private-dns.resolver',
          'ProgramArguments': ['/Library/PrivilegedHelperTools/local-private-dns-helper', '--daemon'],
          'RunAtLoad': True, 'KeepAlive': True, 'ThrottleInterval': 10, 'ProcessType': 'Background',
          'StandardOutPath': '/var/log/private-dns.log', 'StandardErrorPath': '/var/log/private-dns.log'}
agent = {'Label': 'local.private-dns.controls',
         'ProgramArguments': ['/Applications/Private DNS.app/Contents/MacOS/PrivateDNS', '--background'],
         'RunAtLoad': True, 'LimitLoadToSessionType': 'Aqua', 'ProcessType': 'Interactive'}
for job in (daemon, agent):
    job['AssociatedBundleIdentifiers'] = ['local.private-dns.controls']
for path, data in [('Library/LaunchDaemons/local.private-dns.resolver.plist', daemon), ('Library/LaunchAgents/local.private-dns.controls.plist', agent)]:
    (root / path).write_bytes(plistlib.dumps(data))
