from pathlib import Path
from PIL import Image,ImageDraw
import urllib.request,json

root=Path(__file__).resolve().parents[1]
out=root/'assets/emotions'
raw=out/'originals'
animation='8fcaf88d-fd5d-4d93-921d-5a784e4d3784'
icons='c189c479-0242-4ef0-aa9c-76a1998645fc'
for i in range(7):
 p=raw/f'sprint_{i}.png'
 if not p.exists():urllib.request.urlretrieve(f'https://api.pixellab.ai/mcp/images/{animation}/download?index={i}',p)
 im=Image.open(p).convert('RGBA');im.crop(im.getbbox()).save(out/f'sprint_{i}.png')
p=raw/'sprint_icons.png'
if not p.exists():urllib.request.urlretrieve(f'https://api.pixellab.ai/mcp/images/{icons}/download',p)
im=Image.open(p).convert('RGBA')
for i in range(3):
 cell=im.crop((i*64,0,i*64+64,64));cell.crop(cell.getbbox()).save(out/f'sprint_icon_{i}.png')
(out/'sprint_manifest.json').write_text(json.dumps({'provider':'PixelLab','animation':animation,'frames':7,'icons':icons,'upgrade_ids':[12,13,14],'processing':'Native-resolution frames and 64px icon cells trimmed to alpha bounds.'},indent=2))
sheet=Image.new('RGB',(7*128,152),'#312337');draw=ImageDraw.Draw(sheet)
for i in range(7):
 im=Image.open(raw/f'sprint_{i}.png').convert('RGBA').resize((128,128),Image.Resampling.NEAREST)
 sheet.paste(im,(i*128,0),im);draw.text((i*128+4,132),f'Sprint {i}',fill='white')
sheet.save(root/'docs/sprint_frames.png')
print('Sprint frames and three upgrade icons prepared.')
