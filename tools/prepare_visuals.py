from pathlib import Path
from PIL import Image
import json,urllib.request

root=Path(__file__).resolve().parents[1]
out=root/'assets/visuals'
raw=out/'originals'
raw.mkdir(parents=True,exist_ok=True)
images={'button':'21350659-e96f-40d9-9e41-2a23dca395f5','menu':'7985427b-bbaa-4155-b643-8f7ddb2bcfa3','icons':'2495e323-e60b-4bb0-ad43-61cf79e6077f','props':'e40b8502-3b98-4c58-876e-af725e7b04dd'}
tiles={'raspberry':'a05a1bae-e255-4844-896e-bc9577b51f0d','caramel':'58298bf0-9277-4873-bbf2-906652199884','mint':'00bcdf76-b5a8-4b0d-a7fc-aa7bbe1cce25'}
for name,job in images.items():
    if not (raw/(name+'.png')).exists():urllib.request.urlretrieve(f'https://api.pixellab.ai/mcp/images/{job}/download',raw/(name+'.png'))
for name,job in tiles.items():
    if not (raw/(name+'.png')).exists():urllib.request.urlretrieve(f'https://api.pixellab.ai/mcp/tilesets/{job}/image?inline=true',raw/(name+'.png'))
    if not (raw/(name+'.json')).exists():urllib.request.urlretrieve(f'https://api.pixellab.ai/mcp/tilesets/{job}/metadata',raw/(name+'.json'))
    metadata=json.loads((raw/(name+'.json')).read_text())
    atlas=Image.open(raw/(name+'.png')).convert('RGBA')
    for tile in metadata['tileset_data']['tiles']:
        c=tile['corners']; mask=sum((1<<i) for i,k in enumerate(['NW','NE','SW','SE']) if c[k]=='upper')
        b=tile['bounding_box'];atlas.crop((b['x'],b['y'],b['x']+b['width'],b['y']+b['height'])).save(out/f'{name}_{mask}.png')
    print(name,'16 Wang tiles extracted from metadata',flush=True)
for name in ['button','panel']:
    im=Image.open(raw/(name+'.png')).convert('RGBA');im=im.crop(im.getbbox())
    if name=='panel': im=im.resize((im.width//4,im.height//4),Image.Resampling.NEAREST)
    im.save(out/(name+'.png'))
Image.open(raw/'menu.png').save(out/'menu.png')
for name,columns,rows in [('icons',4,4),('props',4,2)]:
    im=Image.open(raw/(name+'.png')).convert('RGBA')
    for i in range(columns*rows):
        # The generated icons occupy an inset grid, unlike the full-size props.
        xs=[26,76,125,174,226] if name=='icons' else [0,64,128,192,256]
        ys=[31,79,128,177,226] if name=='icons' else [0,64,128]
        cell=im.crop((xs[i%columns],ys[i//columns],xs[i%columns+1],ys[i//columns+1]))
        box=cell.getbbox()
        if box:cell=cell.crop(box)
        cell.save(out/f'{name}_{i}.png')
manifest={'date':'2026-11-05','provider':'PixelLab','images':images,'tilesets':tiles,'panel':'295c4b85-a2db-4203-a15f-daf88f2c9d5a','processing':'Transparent border trimming, visually verified inset icon grid / full prop grid extraction, 4x nearest-neighbor UI frame reduction. Terrain regions selected exclusively by metadata bounding_box and NW/NE/SW/SE corners. Originals retained.','fonts':{'Lilita One':'SIL OFL; Google Fonts','Nunito':'SIL OFL; Google Fonts'}}
(out/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print('Visual assets prepared.')
