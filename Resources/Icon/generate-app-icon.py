"""Render the approved SVG as white-on-black app artwork and legacy macOS ICNS."""
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parent
repo = root.parent.parent
path = ET.parse(root / 'vpn-lock.svg').getroot().find('{http://www.w3.org/2000/svg}path').attrib['d']
# Square master: the original glyph occupies 800 of 1024 pixels.
master = f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><rect width="1024" height="1024" fill="black"/><path fill="white" transform="translate(32 992)" d="{path}"/></svg>\n'
# Legacy ICNS supplies its own rounded tile and transparent outer margin.
mac = f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><rect x="64" y="64" width="896" height="896" rx="196" fill="black"/><path fill="white" transform="translate(80 944) scale(.9)" d="{path}"/></svg>\n'
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
