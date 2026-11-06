# «Кедр-7» — скрежет когтей по насту (свой, процедурный, CC0): Ырка на четырёх.
# Короткие царапающие зёрна высокочастотного шума + хруст наста внизу, 4 варианта.
# Запуск: python tools/audio/gen_claws.py  → assets/sfx/cc0/claw_scrape_N.wav
import numpy as np, wave, os

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sfx", "cc0")


def onepole_hp(x, a):
    y = np.zeros_like(x)
    prev_x = prev_y = 0.0
    for i, v in enumerate(x):
        prev_y = a * (prev_y + v - prev_x)
        prev_x = v
        y[i] = prev_y
    return y


def onepole_lp(x, a):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def make(seed, dur):
    rng = np.random.default_rng(seed)
    n = int(SR * dur)
    t = np.arange(n) / SR
    out = np.zeros(n)
    # 3–5 когтей проходят по насту с небольшим разносом: каждое — серия микрозацепов
    for c in range(rng.integers(3, 6)):
        start = rng.uniform(0.0, 0.05)
        length = rng.uniform(0.09, 0.2)
        s0, s1 = int(start * SR), min(n, int((start + length) * SR))
        seg = rng.standard_normal(s1 - s0)
        # зацепы: амплитуда скачет 40–90 раз в секунду
        rate = rng.uniform(40, 90)
        tt = np.arange(s1 - s0) / SR
        grain = (np.sin(2 * np.pi * rate * tt + rng.uniform(0, 6)) > 0.3).astype(float)
        env = np.sin(np.pi * np.clip(tt / length, 0, 1)) ** 0.6
        seg = seg * (0.35 + 0.65 * grain) * env
        out[s0:s1] += seg * rng.uniform(0.6, 1.0)
    scratch = onepole_hp(out, 0.93)          # высокое — скрежет
    # хруст наста: низкий короткий удар в начале
    crunch = rng.standard_normal(n) * np.exp(-t * 38.0)
    crunch = onepole_lp(crunch, 0.12)
    y = scratch * 0.8 + crunch * 1.6
    y /= np.max(np.abs(y)) + 1e-9
    fade = np.minimum(1.0, (n - np.arange(n)) / (SR * 0.02))
    return (y * fade * 0.85).astype(np.float32)


os.makedirs(OUT, exist_ok=True)
for k in range(1, 5):
    y = make(1983 + k, 0.28)
    pcm = (y * 32767).astype(np.int16)
    path = os.path.normpath(os.path.join(OUT, f"claw_scrape_{k}.wav"))
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("ok", path)
