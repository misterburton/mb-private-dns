"""Render approved SVG badges and rotate only the loader vertices about its center."""
from pathlib import Path
import math, re, subprocess, tempfile, xml.etree.ElementTree as ET
base=Path(__file__).resolve().parent
for stem in ['protected','paused','starting-checking','vpn-other-routes','needs-attention']:
 for frame in (range(24) if stem=='starting-checking' else [None]):
  root=ET.parse(base/f'{stem}.svg').getroot()
  svg=ET.Element('svg',xmlns='http://www.w3.org/2000/svg',width='96',height='96')
  group=ET.SubElement(svg,'g',transform='scale(.1) translate(0 960)',fill='black')
  for index,child in enumerate(root):
   for element in child.iter(): element.tag=element.tag.split('}')[-1]
   if frame is not None and index>0:
    angle=math.radians(frame*15)
    def rotate(match):
     x,y=map(float,match.groups()); dx,dy=x-766,y+736
     return f'{766+dx*math.cos(angle)-dy*math.sin(angle):.3f},{-736+dx*math.sin(angle)+dy*math.cos(angle):.3f}'
    child.set('d',re.sub(r'(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)',rotate,child.attrib['d']))
   group.append(child)
  with tempfile.NamedTemporaryFile(suffix='.svg') as f:
   ET.ElementTree(svg).write(f.name)
   output=base/(f'loader-{frame:02}.png' if frame is not None else f'{stem}.png')
   subprocess.run(['magick','-background','none',f.name,str(output)],check=True)
for image in base.glob('*.png'):
 opacity=float(subprocess.check_output(['magick',str(image),'-format','%[fx:mean.a]','info:'],text=True))
 assert .1<opacity<.7, f'Blank or invalid icon: {image}'
frames=sorted(base.glob('loader-*.png'))
hashes=[subprocess.check_output(['magick',str(p),'-fill','black','-draw','rectangle 62,8 91,37','-format','%#','info:'],text=True) for p in frames]
assert len(frames)==24 and len(set(hashes))==1, 'Loader moved outside badge'
print('PASS: all icons visible; 24 loader frames confined to fixed badge region')
