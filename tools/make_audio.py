"""Original offline soundtrack and soft candy sound effects. No external samples."""
from pathlib import Path
import numpy as np
import wave
OUT = Path(__file__).resolve().parents[1] / 'assets/audio'
OUT.mkdir(parents=True,exist_ok=True)
RATE=22050
rng=np.random.default_rng(728)
def write(name,a):
    a=np.tanh(a)*0.76
    stereo=np.stack([a,np.roll(a,35)*0.96],axis=1)
    with wave.open(str(OUT/(name+'.wav')),'wb') as f:
        f.setnchannels(2);f.setsampwidth(2);f.setframerate(RATE)
        f.writeframes((np.clip(stereo,-1,1)*32767).astype('<i2').tobytes())
def note(freq,duration,kind='bell'):
    t=np.arange(int(RATE*duration))/RATE
    if kind=='bass':return (np.sin(2*np.pi*freq*t)+.18*np.sin(4*np.pi*freq*t))*np.exp(-t*5)*np.minimum(t*80,1)
    return (np.sin(2*np.pi*freq*t)+.32*np.sin(2*np.pi*freq*2*t)+.12*np.sin(2*np.pi*freq*3*t))*np.exp(-t*8)*np.minimum(t*160,1)
def midi(n):return 440*2**((n-69)/12)
for name,bpm,root in [('menu',100,60),('arena',124,62),('boss',138,57)]:
    beat=60/bpm; duration=beat*64; a=np.zeros(int(duration*RATE))
    chords=[0,5,9,7,0,5,2,7]
    motif=[0,7,4,12,9,7,4,2,0,4,7,14,12,7,4,7]
    def add(pos,sound,gain):
        idx=int(pos*RATE);end=min(len(a),idx+len(sound));a[idx:end]+=sound[:end-idx]*gain
    for b in range(64):
        chord=chords[b//8];add(b*beat,note(midi(root-24+chord),beat*.8,'bass'),.22)
        for sub in [0,.5]:
            tone=root+12+chord+motif[(b*2+int(sub*2))%16]
            if (b*2+int(sub*2))%7!=3:add((b+sub)*beat,note(midi(tone),beat*.7),.105)
        if b%2==0:
            t=np.arange(int(.12*RATE))/RATE
            kick=np.sin(2*np.pi*(90*t-220*t*t))*np.exp(-t*35)
            add(b*beat,kick,.18)
        else:
            noise=rng.uniform(-1,1,int(.07*RATE))*np.exp(-np.arange(int(.07*RATE))/RATE*65)
            add(b*beat,noise,.075)
    a[:200]*=np.linspace(0,1,200);a[-300:]*=np.linspace(1,0,300);write(name,a)
spec={'hover':(760,.06),'click':(960,.11),'back':(420,.1),'charge':(180,.32),'dash':(260,.18),'push':(160,.12),'hit':(120,.13),'bounce':(390,.12),'absorb':(620,.19),'pickup':(1100,.09),'heal':(880,.3),'hurt':(150,.24),'win':(660,.9),'lose':(240,.65),'warning':(330,.28)}
for name,(freq,dur) in spec.items():
    t=np.arange(int(RATE*dur))/RATE
    if name in ('win','heal','lose'):
        a=np.zeros(len(t))
        for i,n in enumerate(([0,4,7,12] if name!='lose' else [7,3,0,-5])):
            idx=int(i*dur/5*RATE);s=note(freq*2**(n/12),dur*.4)
            end=min(len(a),idx+len(s));a[idx:end]+=s[:end-idx]*.3
    else:
        direction=1 if name in ('charge','absorb','pickup','bounce') else -1
        a=np.sin(2*np.pi*(freq*t+direction*freq*.7*t*t/dur))*np.exp(-t/dur*5)*.5
        if name in ('hit','dash','hurt','push'):a+=rng.uniform(-1,1,len(t))*np.exp(-t/dur*9)*.12
    write(name,a)
print('Created 3 original music loops and 15 sound effects.')
