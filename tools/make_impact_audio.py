"""Original layered jelly impacts; deterministic synthesis, no external samples."""
from pathlib import Path
import numpy as np
import wave,json

out=Path(__file__).resolve().parents[1]/'assets/audio'
rate=44100
rng=np.random.default_rng(2505)
report={}
for name,duration,base in [('jelly_tap',.19,210),('jelly_slam',.30,125),('shell_tink',.22,880),('jelly_pop',.23,330)]:
 t=np.arange(int(rate*duration))/rate
 if name=='shell_tink':
  a=(np.sin(2*np.pi*base*t)+.35*np.sin(2*np.pi*base*2.37*t))*np.exp(-t*24)*.4
 else:
  # A low body transient, elastic pitch drop, and soft filtered contact noise.
  f=base*(.40+.95*np.exp(-t*38))
  phase=2*np.pi*np.cumsum(f)/rate
  a=np.sin(phase)*np.exp(-t*15)*.65
  a+=np.sin(phase*1.92)*np.exp(-t*24)*.14
  noise=rng.uniform(-1,1,len(t));noise=np.convolve(noise,np.ones(9)/9,mode='same')
  a+=noise*np.exp(-t*65)*.35
  if name=='jelly_slam':a+=np.sin(2*np.pi*55*t)*np.exp(-t*13)*.3
  if name=='jelly_pop':a+=np.sin(2*np.pi*(520*t+900*t*t))*np.exp(-((t-.045)/.038)**2)*.22
 a*=np.minimum(t/.003,1)*np.minimum((duration-t)/.016,1)
 a=np.tanh(a)*.8
 stereo=np.stack([a,np.roll(a,12)*.97],axis=1)
 with wave.open(str(out/(name+'.wav')),'wb') as f:
  f.setnchannels(2);f.setsampwidth(2);f.setframerate(rate)
  f.writeframes((stereo*32767).astype('<i2').tobytes())
 report[name]={'seconds':duration,'peak':float(np.max(np.abs(stereo))),'rms':float(np.sqrt(np.mean(stereo**2)))}
(out/'impact_audio.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
