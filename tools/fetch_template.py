"""Fetch only the Windows release member of the official Godot template ZIP using HTTP ranges."""
import io, urllib.request, zipfile
from pathlib import Path
URL='https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'
class Remote(io.RawIOBase):
    def __init__(self):
        req=urllib.request.Request(URL,headers={'Range':'bytes=0-0'})
        with urllib.request.urlopen(req,timeout=60) as r:
            self.url=r.url
            self.length=int(r.headers['Content-Range'].split('/')[-1])
            r.read()
        self.pos=0
    def seekable(self):return True
    def readable(self):return True
    def tell(self):return self.pos
    def seek(self,n,whence=0):
        self.pos= n if whence==0 else self.pos+n if whence==1 else self.length+n
        return self.pos
    def read(self,n=-1):
        if n<0:n=self.length-self.pos
        if n==0:return b''
        end=min(self.length-1,self.pos+n-1)
        req=urllib.request.Request(self.url,headers={'Range':f'bytes={self.pos}-{end}'})
        with urllib.request.urlopen(req,timeout=120) as r:
            if r.status!=206:raise RuntimeError('Server did not honor byte range')
            data=r.read()
        self.pos+=len(data)
        return data
out=Path(__file__).resolve().parents[1]/'tools/templates'
out.mkdir(exist_ok=True)
with zipfile.ZipFile(Remote()) as z:
    for info in z.infolist():
        if info.filename.endswith('windows_release_x86_64.exe') or info.filename.endswith('version.txt'):
            print('Downloading',info.filename,info.compress_size,flush=True)
            (out/Path(info.filename).name).write_bytes(z.read(info))
print('Official Windows release template ready.')
