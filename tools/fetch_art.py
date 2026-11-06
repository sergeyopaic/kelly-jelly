from pathlib import Path
import urllib.request,json
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parents[1]
jobs={
'kelly':'34dd9b78-e27b-41c3-9264-819d8314c5eb',
'gummy':'56233fd3-efe3-4a03-85e6-73687514fa0c',
'fork':'267958d3-9240-4903-a2e0-4e01ba9b82a3',
'waffle':'c386409d-0746-4076-ad52-7864d3533c15',
'pepper':'10897e33-cd65-43b3-a9c9-386580618bd5',
'toffee':'23f1c7cc-d29a-4b50-baf7-74c80c4632ac',
'pudding':'6fe7ebdc-0aaa-4449-9b42-88ebc261f627',
'rolling':'4d8aca5e-2aee-44e9-a48e-34e4e8786ff2',
'whisk':'ddee0256-355f-4e75-a447-b5de4d6d4aa9'}
original=root/'assets/art/originals';original.mkdir(exist_ok=True)
manifest=[]
for name,job in jobs.items():
    url=f'https://api.pixellab.ai/mcp/images/{job}/download'
    raw=original/(name+'.png')
    if not raw.exists():urllib.request.urlretrieve(url,raw)
    im=Image.open(raw).convert('RGBA');bounds=im.getbbox()
    im=im.crop(bounds)
    # Trim only empty border, retaining native pixel grid and original artwork.
    im.save(root/'assets/art'/(name+'.png'))
    manifest.append({'name':name,'file':f'assets/art/{name}.png','source':'PixelLab Pro Flash','job_id':job,'url':url,'processing':'trim transparent border; procedural in-engine animation','original_size':Image.open(raw).size,'trim_bounds':bounds})
    print(name,im.size,flush=True)
(root/'assets/manifest.json').write_text(json.dumps({'date':'2026-11-04','generation_cost':48,'assets':manifest,'other_assets':'Original procedural UI/scenery/VFX and synthesized music/SFX in this repository.'},indent=2),encoding='utf8')
sheet=Image.new('RGB',(900,250),'#302139');d=ImageDraw.Draw(sheet)
for i,name in enumerate(jobs):
    im=Image.open(root/'assets/art'/(name+'.png')).convert('RGBA')
    scale=min(90/im.width,140/im.height)
    im=im.resize((int(im.width*scale),int(im.height*scale)),Image.Resampling.NEAREST)
    sheet.paste(im,(i*100+(100-im.width)//2,160-im.height),im)
    d.text((i*100+8,185),name,fill='#fff0c7')
sheet.save(root/'docs/art_contact_sheet.png')
