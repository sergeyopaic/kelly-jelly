"""Download PixelLab frames, preserving pixels; trim only transparent borders."""
from pathlib import Path
from PIL import Image, ImageDraw
import json, urllib.request

root=Path(__file__).resolve().parents[1]
out=root/'assets/emotions'
raw=out/'originals'
raw.mkdir(parents=True,exist_ok=True)
jobs={
 'charge':('d98f21b2-b049-48e2-967f-93483d125e92',7),
 'absorb':('8bff5019-b608-4496-8aa9-94074d80af64',9),
 'idle':('89431919-c89d-4a01-aa0d-2f95d1b5aa0d',9),
 'hurt':('a97a283c-ab28-44ff-8c08-e20905502323',7),
 'dash':('6bbc161f-6a94-40ef-af05-95907ba8642c',7),
}
for name,(job,count) in jobs.items():
 for i in range(count):
  path=raw/(f'charge_final_{i}.png' if name=='charge' else f'{name}_{i}.png')
  if not path.exists():
   urllib.request.urlretrieve(f'https://api.pixellab.ai/mcp/images/{job}/download?index={i}',path)
  im=Image.open(path).convert('RGBA')
  bounds=im.getbbox()
  if not bounds:raise ValueError(f'Empty frame {path}')
  im.crop(bounds).save(out/f'{name}_{i}.png')
 print(name,'prepared',flush=True)
ground='4fa1e11f-4cda-46e5-8512-2c172564fe98'
if not (raw/'ground_matte.png').exists():
 urllib.request.urlretrieve(f'https://api.pixellab.ai/mcp/images/{ground}/download',raw/'ground_matte.png')
Image.open(raw/'ground_matte.png').save(out/'ground.png')
(out/'manifest.json').write_text(json.dumps({'provider':'PixelLab','source_character':'34dd9b78-e27b-41c3-9264-819d8314c5eb','animations':jobs,'ground':ground,'charge_target':'ef86f602-10c5-43d8-a0ec-ec073fc8cb01','processing':'Per-frame transparent border trim, no resampling. In-engine bottom anchoring retains native pixel sizes and expression changes.'},indent=2),encoding='utf-8')
# Contact sheet is only a QA artifact, never a game texture.
sheet=Image.new('RGB',(9*132,5*152),'#312337')
draw=ImageDraw.Draw(sheet)
for row,(name,(_,count)) in enumerate(jobs.items()):
 for i in range(count):
  im=Image.open(raw/(f'charge_final_{i}.png' if name=='charge' else f'{name}_{i}.png')).convert('RGBA').resize((128,128),Image.Resampling.NEAREST)
  sheet.paste(im,(i*132,row*152),im)
  draw.text((i*132+4,row*152+130),f'{name} {i}',fill='white')
sheet.save(root/'docs/emotions_contact_sheet.png')
