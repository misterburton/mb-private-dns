"""Render the approved SVG as white-on-black app artwork and legacy macOS ICNS."""
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET
import json
import shutil

root = Path(__file__).resolve().parent
repo = root.parent.parent
path = ET.parse(root / 'vpn-lock.svg').getroot().find('{http://www.w3.org/2000/svg}path').attrib['d']
# Square master: the original glyph occupies 800 of 1024 pixels.
master = f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><rect width="1024" height="1024" fill="black"/><path fill="white" transform="translate(32 992)" d="{path}"/></svg>\n'
# Use the same opaque, edge-to-edge black artwork on every surface.
mac = master
for name, svg in [('AppIcon', master), ('AppIcon-macOS', mac)]:
    (root / f'{name}.svg').write_text(svg)
    subprocess.run(['magick', '-background', 'none', str(root / f'{name}.svg'), str(root / f'{name}.png')], check=True)
iconset = repo / 'build/PrivateDNS.iconset'
iconset.mkdir(parents=True, exist_ok=True)
for size in [16, 32, 128, 256, 512]:
    for scale in [1, 2]:
        suffix = '@2x' if scale == 2 else ''
        subprocess.run(['magick', str(root / 'AppIcon-macOS.png'), '-resize', f'{size*scale}x{size*scale}', str(iconset / f'icon_{size}x{size}{suffix}.png')], check=True)
subprocess.run(['iconutil', '-c', 'icns', str(iconset), '-o', str(root / 'PrivateDNS.icns')], check=True)
catalog = root / 'AppIcon.xcassets/AppIcon.appiconset'
catalog.mkdir(parents=True, exist_ok=True)
images = []
for size in [16, 32, 128, 256, 512]:
    for scale in [1, 2]:
        suffix = '@2x' if scale == 2 else ''
        name = f'icon_{size}x{size}{suffix}.png'
        shutil.copyfile(iconset / name, catalog / name)
        images.append({'filename': name, 'idiom': 'mac', 'scale': f'{scale}x', 'size': f'{size}x{size}'})
(catalog / 'Contents.json').write_text(json.dumps({'images': images, 'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')
