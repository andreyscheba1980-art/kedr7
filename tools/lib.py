import subprocess, numpy as np, os
SR = 44100
def load(path, sr=SR):
    out = subprocess.run(['ffmpeg','-v','error','-i',path,'-ac','1','-ar',str(sr),'-f','f32le','-'],capture_output=True).stdout
    return np.frombuffer(out, dtype=np.float32).copy()
def save(path, x, sr=SR, q=5):
    x = np.asarray(x, dtype=np.float32)
    p = subprocess.run(['ffmpeg','-v','error','-y','-f','f32le','-ar',str(sr),'-ac','1','-i','-','-c:a','libvorbis','-q:a',str(q),path],input=x.tobytes())
    return p.returncode
def env(x, sr=SR, win=0.02):
    n = int(sr*win); m = len(x)//n
    return np.sqrt((x[:m*n].reshape(m,n)**2).mean(1)+1e-12)
def norm(x, peak_db=-1.0):
    p = np.abs(x).max()+1e-9
    return x*(10**(peak_db/20)/p)
def norm_rms(x, rms_db=-20.0):
    r = np.sqrt((x**2).mean())+1e-9
    y = x*(10**(rms_db/20)/r)
    pk = np.abs(y).max()
    if pk > 0.98: y *= 0.98/pk
    return y
def fade(x, fi=0.005, fo=0.05, sr=SR):
    x = x.copy(); a=int(fi*sr); b=int(fo*sr)
    if a>0: x[:a]*=np.linspace(0,1,a)
    if b>0: x[-b:]*=np.linspace(1,0,b)
    return x
def loop(x, cross=1.0, sr=SR):
    c = int(cross*sr)
    body = x[:-c].copy(); tail = x[-c:]
    w = np.linspace(0,1,c)
    body[:c] = body[:c]*w + tail*(1-w)
    return body
def hp(x, hz, sr=SR):
    # простой однополюсный ФВЧ
    a = np.exp(-2*np.pi*hz/sr); y=np.zeros_like(x); prev_x=0; prev_y=0
    for i in range(len(x)):
        prev_y = a*(prev_y + x[i] - prev_x); prev_x = x[i]; y[i]=prev_y
    return y
def onsets(x, sr=SR, thr_db=-30, gap=0.25, win=0.01):
    e = env(x, sr, win); db = 20*np.log10(e/ (e.max()+1e-9))
    res=[]; last=-1e9
    for i in range(1,len(db)):
        if db[i] > thr_db and db[i-1] <= thr_db and (i*win - last) > gap:
            res.append(i*win); last=i*win
    return res
