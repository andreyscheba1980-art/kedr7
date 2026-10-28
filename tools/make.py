import sys, os, glob, numpy as np
sys.path.insert(0, os.path.expanduser('~/sfxw'))
from lib import *
SRC = os.path.expanduser('~/mnt/kedr7/assets_src/sfx_cc0/')
OUT = os.path.expanduser('~/sfxw/out/')
os.makedirs(OUT, exist_ok=True)
def f(prefix): return glob.glob(SRC + prefix + '*')[0]
def seg(x, a, b): return x[int(a*SR):int(b*SR)]
report = []
def put(name, y):
    save(OUT + name + '.ogg', y); report.append((name, round(len(y)/SR, 2)))
def mkloop(name, src, a, b, rms=-20.0, cross=1.5):
    x = load(f(src)); put(name, norm_rms(loop(seg(x, a, b), cross), rms))
def slices(base, src, n, thr=-24, gap=0.3, length=0.5, pre=0.02, peak=-3.0, skip=0, a=0, b=None, hp_hz=0):
    x = load(f(src)); x = seg(x, a, b if b else len(x)/SR)
    if hp_hz: x = hp(x, hp_hz)
    on = onsets(x, thr_db=thr, gap=gap)[skip:]
    # выбираем самые громкие n
    cand = []
    for t in on:
        s = x[max(0, int((t-pre)*SR)): int((t+length)*SR)]
        if len(s) < int(0.1*SR): continue
        cand.append((np.abs(s).max(), t, s))
    cand.sort(key=lambda c: -c[0])
    chosen = sorted(cand[:n], key=lambda c: c[1])
    for i, (_, t, s) in enumerate(chosen):
        put('%s_%d' % (base, i+1), norm(fade(s, 0.003, min(0.15, length*0.4)), peak))
    return [round(c[1],2) for c in chosen]

# --- Ветер ---
mkloop('wind_blizzard_loop', '679941', 0, 7.61, -18, 0.8)
mkloop('wind_indoor_loop', '623603', 2, 34, -20, 2.0)
mkloop('wind_indoor_loop_b', '623604', 2, 36, -20, 2.0)
mkloop('wire_gust_loop', '829000', 8, 52, -22, 2.5)
mkloop('wind_whistle_loop', '319337', 40, 76, -24, 2.0)
x = load(f('26189')); put('chimney_howl', norm(fade(x, 0.3, 1.5), -2))
# --- Окна и двери ---
x = load(f('371256'))
for i, (a, b) in enumerate([(25.5, 30), (31.5, 36), (39.5, 44), (47, 51.5)]):
    put('window_rattle_%d' % (i+1), norm(fade(seg(x, a, b), 0.05, 0.8), -3))
x = load(f('455758')); put('door_rattle', norm(fade(x, 0.002, 1.0), -2))
# --- Шаги ---
print('wood', slices('step_plank', '398780', 8, thr=-22, length=0.45))
print('deck', slices('step_deck', '534477', 8, thr=-18, gap=0.35, length=0.4))
print('metal', slices('step_metal', '451864', 6, thr=-18, gap=0.35, length=0.5))
print('metal2', slices('step_metal_b', '50723', 3, thr=-20, gap=0.3, length=0.45))
for i, p in enumerate(['384423', '384421', '384424']):
    x = load(f(p)); e = env(x); st = max(0, int(np.argmax(e > e.max()*0.1)*0.02*SR) - int(0.02*SR))
    put('step_crust_%d' % (i+1), norm(fade(x[st:st+int(0.6*SR)], 0.003, 0.15), -3))
# --- Дом ---
mkloop('stove_crackle_loop', '453472', 5, 34, -22, 1.5)
mkloop('bulb_buzz_loop', '454067', 2, 22, -26, 1.0)
mkloop('elec_buzz_loop', '438501', 5, 30, -24, 1.5)
mkloop('radio_hum_loop', '721813__chungus43a__bpsn-electrical-hum-2.wav', 0.5, 12.5, -24, 1.0)
print('drip', slices('drip', '166324', 5, thr=-20, gap=0.6, length=0.6, peak=-4))
x = load(f('164523')); put('floor_creak_1', norm(fade(x, 0.002, 0.1), -3))
put('floor_creak_2', norm(fade(np.interp(np.arange(0, len(x), 0.82), np.arange(len(x)), x).astype(np.float32), 0.002, 0.1), -4))
x = load(f('669457')); put('log_frost_crack', norm(fade(x, 0.002, 0.4), -2))
# --- Даль ---
x = load(f('452570')); put('tree_frost_crack', norm(fade(x, 0.001, 0.15), -2))
x = load(f('453711')); put('plane_far', norm(fade(x, 2.0, 4.0), -6))
x = load(f('814318')); put('plane_far_2', norm(fade(x, 2.0, 3.0), -8))
x = load(f('486557')); y = np.interp(np.arange(0, len(x), 0.62), np.arange(len(x)), x).astype(np.float32)
put('drone_far', norm(fade(y, 1.5, 4.0), -6))
print('snowdrop', slices('branch_snow_drop', '116136', 3, thr=-18, gap=1.5, length=2.2, peak=-4))
# --- Живность и техника ---
print('crow', slices('crow_caw', '494833', 5, thr=-16, gap=1.0, length=0.9, peak=-3, a=8, b=95))
x = load(f('813115')); put('crow_caw_6', norm(fade(x, 0.002, 0.1), -3))
mkloop('anemometer_squeak_loop', '559470', 0.2, 9.4, -22, 0.6)
mkloop('flag_flap_loop', '187364', 100, 130, -22, 2.0)
mkloop('pole_hum_loop', '169942', 120, 150, -24, 2.0)
for r in report: print(r)
