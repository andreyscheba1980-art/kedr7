"""Процедурная генерация заглушек: звуки (WAV 22 кГц моно) и текстура лица для скримера.

Запуск из корня проекта:  python tools/gen_assets.py
Нужны numpy, scipy, pillow. Всё детерминировано (фиксированный сид).
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import signal
from scipy.io import wavfile

SR = 22050
ROOT = Path(__file__).resolve().parent.parent
AUDIO = ROOT / "assets" / "audio"
TEX = ROOT / "assets" / "textures"
rng = np.random.default_rng(1983)


def t_axis(sec: float) -> np.ndarray:
    return np.arange(int(SR * sec)) / SR


def save(name: str, x: np.ndarray, peak: float = 0.9) -> None:
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    wavfile.write(AUDIO / name, SR, (x * 32767).astype(np.int16))


def bandpass(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], btype="band", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lowpass(x, f, order=2):
    sos = signal.butter(order, f, btype="low", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def seamless(x: np.ndarray, fade: float = 0.5) -> np.ndarray:
    """Склеивает хвост с началом, чтобы луп не щёлкал."""
    n = int(SR * fade)
    head, body, tail = x[:n], x[n:-n], x[-n:]
    ramp = np.linspace(0, 1, n)
    return np.concatenate([tail * (1 - ramp) + head * ramp, body])


def radio_fx(x: np.ndarray, drive: float = 3.0) -> np.ndarray:
    """Звук «через рацию»: узкая полоса + мягкий перегруз. Верх срезан — без «песка» в ушах."""
    x = bandpass(x, 280, 2600)
    y = np.tanh(x / (np.max(np.abs(x)) + 1e-9) * drive * 0.55)
    return lowpass(y, 2400, 4)


# --- Фон -----------------------------------------------------------------

def hum_loop():
    t = t_axis(4.0)  # 200 периодов 50 Гц — луп без шва
    x = sum((0.8 / k) * np.sin(2 * np.pi * 50 * k * t + k) for k in range(1, 8))
    x += 0.25 * np.sign(np.sin(2 * np.pi * 100 * t)) * 0.3
    x *= 1 + 0.05 * np.sin(2 * np.pi * 0.5 * t)
    save("hum_loop.wav", lowpass(x, 900), 0.6)


def wind_loop():
    t = t_axis(10.5)
    noise = rng.standard_normal(len(t))
    gust = 0.55 + 0.45 * np.sin(2 * np.pi * 0.11 * t) * np.sin(2 * np.pi * 0.047 * t + 1.3)
    x = lowpass(noise, 500) * gust + bandpass(noise, 600, 1400) * 0.15 * gust ** 3
    save("wind_loop.wav", seamless(x, 0.5), 0.8)


# --- Эфир ----------------------------------------------------------------

def buzzer_loop():
    """Жужжание в духе «Жужжалки» УВБ-76: зуммер 1 с, пауза 0.2 с."""
    period, buzz = 1.2, 1.0
    t = t_axis(period)
    saw = signal.sawtooth(2 * np.pi * 88 * t)
    env = (t < buzz).astype(float)
    env = np.convolve(env, np.ones(200) / 200, mode="same")
    one = np.tanh(saw * 3) * env
    save("buzzer_loop.wav", radio_fx(np.tile(one, 5), 2.5), 0.8)


def numbers_loop():
    t_beep = t_axis(0.18)
    beep = np.sin(2 * np.pi * 1020 * t_beep) * np.hanning(len(t_beep))
    gap = np.zeros(int(SR * 0.14))
    pause = np.zeros(int(SR * 0.9))
    group = np.concatenate([beep, gap, beep, gap, beep, pause])
    x = np.concatenate([group, group, np.concatenate([beep, gap] * 5), pause])
    save("numbers_loop.wav", radio_fx(x + 0.02 * rng.standard_normal(len(x)), 2.0), 0.7)


def carrier_loop():
    t = t_axis(4.0)
    x = np.sin(2 * np.pi * 800 * t) * (1 + 0.08 * np.sin(2 * np.pi * 3 * t))
    x += 0.04 * rng.standard_normal(len(t))
    save("carrier_loop.wav", seamless(radio_fx(x, 1.5), 0.3), 0.5)


VOWELS = {"a": (800, 1150), "o": (500, 900), "u": (350, 800), "e": (550, 1770), "i": (300, 2200)}


def fake_voice(sec: float, pitch: float = 115.0) -> np.ndarray:
    """Неразборчивая «речь»: импульсы голосовых связок через форманты, по слогам."""
    out = np.zeros(int(SR * sec))
    pos = int(SR * 0.2)
    while pos < len(out) - SR // 3:
        syl = int(SR * rng.uniform(0.12, 0.26))
        f1, f2 = VOWELS[rng.choice(list(VOWELS))]
        t = np.arange(syl) / SR
        f0 = pitch * (1 + 0.04 * np.sin(2 * np.pi * 5 * t)) * rng.uniform(0.9, 1.1)
        phase = np.cumsum(f0) / SR
        pulses = (np.diff(np.floor(phase), prepend=0) > 0).astype(float)
        src = pulses + 0.05 * rng.standard_normal(syl)  # немного шума — «согласные»
        v = bandpass(src, f1 * 0.8, f1 * 1.2) + 0.6 * bandpass(src, f2 * 0.85, f2 * 1.15)
        out[pos:pos + syl] += v * np.hanning(syl)
        pos += syl + int(SR * (rng.uniform(0.02, 0.08) if rng.random() > 0.2 else rng.uniform(0.3, 0.6)))
    return out


def voice_loop():
    x = fake_voice(6.0)
    x += 0.15 * rng.standard_normal(len(x)) * (np.max(np.abs(x)) + 1e-9)
    save("voice_loop.wav", seamless(radio_fx(x, 4.0), 0.2), 0.75)


# --- Испуги --------------------------------------------------------------

def knock():
    out = np.zeros(int(SR * 1.2))
    for start in (0.0, 0.3, 0.62):
        t = t_axis(0.25)
        thud = np.sin(2 * np.pi * (85 + 40 * np.exp(-t * 40)) * t) * np.exp(-t * 22)
        click = lowpass(rng.standard_normal(len(t)), 2500) * np.exp(-t * 90) * 0.5
        i = int(SR * start)
        out[i:i + len(t)] += (thud + click) * rng.uniform(0.85, 1.0)
    save("knock.wav", out, 0.95)


def scream():
    t = t_axis(1.6)
    env = np.minimum(t / 0.02, 1.0) * np.exp(-np.maximum(t - 0.9, 0) * 4)
    sweep = 520 + 900 * (1 - np.exp(-t * 6)) + 60 * np.sin(2 * np.pi * 9 * t)
    x = np.zeros_like(t)
    for detune in (1.0, 1.013, 0.987, 1.51, 2.02):
        x += signal.sawtooth(2 * np.pi * np.cumsum(sweep * detune) / SR) / detune
    x += 1.5 * bandpass(rng.standard_normal(len(t)), 1500, 5000)
    x = np.tanh(x * 2.5) * env
    save("scream.wav", x, 0.98)


def sub_drop():
    t = t_axis(2.8)
    f = 75 * np.exp(-t * 0.6) + 28
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 1.3)
    x += 0.3 * lowpass(rng.standard_normal(len(t)), 120) * np.exp(-t * 1.8)
    save("sub_drop.wav", x, 0.9)


# --- v0.2: двор, шаги, Ырка ----------------------------------------------

def _crunch(sec: float, bright: float = 1.0) -> np.ndarray:
    """Хруст снега: короткие пачки фильтрованного шума."""
    t = t_axis(sec)
    x = np.zeros_like(t)
    for _ in range(rng.integers(5, 9)):
        i = rng.integers(0, int(len(t) * 0.6))
        n = rng.integers(200, 900)
        burst = rng.standard_normal(n) * np.exp(-np.arange(n) / (n / 4))
        x[i:i + n] += burst * rng.uniform(0.4, 1.0)
    x = bandpass(x, 400 * bright, 4500 * bright) + 0.4 * lowpass(x, 300)
    return x * np.exp(-t * 6)


def steps():
    for i in range(1, 4):
        save(f"step_snow_{i}.wav", _crunch(0.28, rng.uniform(0.85, 1.15)), 0.8)
    for i in range(1, 3):
        t = t_axis(0.22)
        thud = np.sin(2 * np.pi * rng.uniform(90, 120) * t) * np.exp(-t * 35)
        creak = bandpass(rng.standard_normal(len(t)), 700, 1800) * np.exp(-t * 25) * 0.3
        save(f"step_wood_{i}.wav", thud + creak, 0.7)


def yrka_steps():
    """Три шага по снегу — тяжелее и медленнее человеческих."""
    out = np.zeros(int(SR * 2.0))
    for k, start in enumerate((0.0, 0.62, 1.3)):
        c = _crunch(0.35, 0.7)
        i = int(SR * start)
        out[i:i + len(c)] += c * (0.7 + 0.15 * k)
    save("yrka_steps.wav", out, 0.85)


def yrka_run_loop():
    period = 0.36
    one = np.zeros(int(SR * period))
    c = _crunch(0.2, 0.75)
    one[:len(c)] += c
    x = np.tile(one, 6)
    x += 0.15 * lowpass(rng.standard_normal(len(x)), 200)
    save("yrka_run_loop.wav", x, 0.85)


def whistle():
    """Свист из леса: долгая нисходящая нота с дрожью, как будто кто-то зовёт."""
    t = t_axis(2.6)
    f = 1900 - 650 * (t / t[-1]) ** 1.5 + 25 * np.sin(2 * np.pi * 6 * t)
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR)
    breath = bandpass(rng.standard_normal(len(t)), 1200, 2600) * 0.25
    env = np.minimum(t / 0.25, 1.0) * np.exp(-np.maximum(t - 1.7, 0) * 3)
    save("whistle.wav", (tone + breath) * env, 0.7)


def growl():
    t = t_axis(1.8)
    f0 = 55 + 15 * np.sin(2 * np.pi * 3 * t)
    x = signal.sawtooth(2 * np.pi * np.cumsum(f0) / SR) * (1 + 0.6 * rng.standard_normal(len(t)) * 0.3)
    x = lowpass(x, 700) + 0.4 * bandpass(rng.standard_normal(len(t)), 200, 1200)
    env = np.minimum(t / 0.1, 1.0) * np.exp(-np.maximum(t - 1.1, 0) * 4)
    save("growl.wav", np.tanh(x * 2) * env, 0.95)


def shriek():
    t = t_axis(1.4)
    f = 900 + 1400 * np.exp(-t * 2) + 80 * np.sin(2 * np.pi * 13 * t)
    x = sum(signal.sawtooth(2 * np.pi * np.cumsum(f * d) / SR) for d in (1.0, 1.02, 0.5))
    x += bandpass(rng.standard_normal(len(t)), 2000, 6000)
    env = np.minimum(t / 0.03, 1.0) * np.exp(-t * 2.5)
    save("shriek.wav", np.tanh(x) * env, 0.9)


def door():
    t = t_axis(0.9)
    f = 260 + 140 * np.sin(2 * np.pi * 1.1 * t) + 30 * rng.standard_normal(len(t)).cumsum() / 400
    creak = signal.sawtooth(2 * np.pi * np.cumsum(f) / SR) * (0.5 + 0.5 * (rng.random(len(t)) > 0.7))
    creak = bandpass(creak, 300, 2500) * np.exp(-np.maximum(t - 0.55, 0) * 6)
    thud_t = t_axis(0.3)
    thud = np.sin(2 * np.pi * 70 * thud_t) * np.exp(-thud_t * 18)
    x = np.concatenate([creak, thud])
    save("door.wav", x, 0.8)


def crank_loop():
    """Фонарь-жучок: шестерёнки + жужжание динамо."""
    t = t_axis(1.0)  # 7 оборотов в секунду — целое число периодов
    whir = signal.sawtooth(2 * np.pi * 140 * t) * 0.4 + np.sin(2 * np.pi * 280 * t) * 0.3
    clicks = np.zeros_like(t)
    for k in range(28):
        i = int(k * len(t) / 28)
        clicks[i:i + 60] += rng.standard_normal(60) * np.exp(-np.arange(60) / 12)
    x = bandpass(whir, 100, 2500) + bandpass(clicks, 1500, 6000) * 0.8
    save("crank_loop.wav", x * (1 + 0.15 * np.sin(2 * np.pi * 7 * t)), 0.6)


def breath_loop():
    t = t_axis(3.0)
    env = np.maximum(np.sin(2 * np.pi * t / 1.5), 0) ** 1.5
    env += 0.6 * np.maximum(-np.sin(2 * np.pi * t / 1.5), 0) ** 2
    x = bandpass(rng.standard_normal(len(t)), 500, 2200) * env
    save("breath_loop.wav", seamless(x, 0.05), 0.6)


def ice_hit():
    t = t_axis(0.5)
    knock_ = np.sin(2 * np.pi * 180 * t) * np.exp(-t * 30)
    shards = bandpass(rng.standard_normal(len(t)), 2500, 8000) * np.exp(-t * 12)
    tinkle = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * rng.uniform(8, 16)) for f in rng.uniform(2500, 5000, 5)) * 0.1
    save("ice_hit.wav", knock_ + shards * 0.7 + tinkle, 0.9)


def clank():
    t = t_axis(0.8)
    x = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * d) for f, d in ((320, 9), (811, 12), (1530, 18), (2440, 25)))
    x += bandpass(rng.standard_normal(len(t)), 1000, 5000) * np.exp(-t * 40)
    save("clank.wav", x, 0.75)


def stove_add():
    t = t_axis(0.9)
    thud = np.sin(2 * np.pi * 80 * t) * np.exp(-t * 14)
    rustle = bandpass(rng.standard_normal(len(t)), 600, 3000) * np.exp(-t * 5) * 0.4
    crackle = np.zeros_like(t)
    for _ in range(12):
        i = rng.integers(int(SR * 0.2), len(t) - 100)
        crackle[i:i + 40] += rng.standard_normal(40)
    save("stove_add.wav", thud + rustle + bandpass(crackle, 2000, 7000) * 0.5, 0.8)


def frost_vignette():
    """Иней по краям экрана: прозрачный центр, белёсые кристаллы к углам."""
    w, h = 320, 180
    yy, xx = np.mgrid[0:h, 0:w]
    nx, ny = (xx / w - 0.5) * 2, (yy / h - 0.5) * 2
    r = np.sqrt(nx ** 2 * 0.9 + ny ** 2 * 1.2)
    noise = np.asarray(Image.fromarray((rng.random((h // 4, w // 4)) * 255).astype(np.uint8)).resize((w, h), Image.BILINEAR)) / 255
    fine = rng.random((h, w))
    a = np.clip((r - 0.72) * 1.9 + (noise - 0.5) * 0.5, 0, 1) ** 1.4
    a *= 0.75 + 0.25 * fine
    rgb = np.stack([np.full_like(a, 205), np.full_like(a, 222), np.full_like(a, 240)], -1)
    img = np.dstack([rgb, a * 235]).astype(np.uint8)
    Image.fromarray(img, "RGBA").save(TEX / "frost_vignette.png")


# --- v0.3: эфир, плёнка, дом, вездеход -----------------------------------

def voice_mainland():
    """Большая Земля: неразборчивая речь через рацию (голосов нет — только субтитры)."""
    x = fake_voice(4.5, pitch=135.0)
    x += 0.1 * rng.standard_normal(len(x)) * (np.max(np.abs(x)) + 1e-9)
    save("voice_mainland.wav", radio_fx(x, 5.0), 0.7)


def morse_loop():
    """Морзянка 700 Гц: «ИЗБА» и пауза."""
    code = {"И": "..", "З": "--..", "Б": "-...", "А": ".-"}
    unit = 0.08
    parts = []
    for ch in "ИЗБА":
        for sym in code[ch]:
            n = unit * (3 if sym == "-" else 1)
            t = t_axis(n)
            parts.append(np.sin(2 * np.pi * 700 * t) * np.hanning(len(t)) ** 0.1)
            parts.append(np.zeros(int(SR * unit)))
        parts.append(np.zeros(int(SR * unit * 3)))
    parts.append(np.zeros(int(SR * 1.2)))
    x = np.concatenate(parts)
    save("morse_loop.wav", radio_fx(x + 0.02 * rng.standard_normal(len(x)), 1.8), 0.6)


def lullaby_loop():
    """Музыкальная шкатулка, расстроенная и замедленная: колыбельная из эфира."""
    notes = [76, 74, 72, 74, 76, 76, 76, 0, 74, 74, 74, 0, 76, 79, 79, 0]
    beat = 0.42
    out = np.zeros(int(SR * beat * len(notes)) + SR)
    for i, n in enumerate(notes):
        if n == 0:
            continue
        f = 440.0 * 2 ** ((n - 69) / 12) * (1 + 0.012 * np.sin(i))
        t = t_axis(1.6)
        tone = (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 2.01 * t)) * np.exp(-t * 3.2)
        k = int(SR * i * beat)
        out[k:k + len(tone)] += tone
    out = out[:int(SR * beat * len(notes))]
    save("lullaby_loop.wav", seamless(radio_fx(out, 1.6), 0.1), 0.6)


def tape_hiss():
    t = t_axis(3.0)
    x = bandpass(rng.standard_normal(len(t)), 2000, 9000) * (1 + 0.1 * np.sin(2 * np.pi * 0.7 * t))
    x += 0.3 * lowpass(rng.standard_normal(len(t)), 300) * (1 + 0.3 * np.sin(2 * np.pi * 1.3 * t))
    save("tape_hiss.wav", seamless(x, 0.2), 0.4)


def door_knock():
    """Три тяжёлых удара кулаком в деревянную дверь."""
    out = np.zeros(int(SR * 1.6))
    for start in (0.0, 0.42, 0.84):
        t = t_axis(0.35)
        thud = np.sin(2 * np.pi * (70 + 50 * np.exp(-t * 30)) * t) * np.exp(-t * 14)
        wood = bandpass(rng.standard_normal(len(t)), 150, 1200) * np.exp(-t * 35) * 0.8
        rattle = bandpass(rng.standard_normal(len(t)), 2500, 6000) * np.exp(-t * 20) * 0.15
        i = int(SR * start)
        out[i:i + len(t)] += thud + wood + rattle
    save("door_knock.wav", np.tanh(out * 1.5), 0.95)


def engine_loop():
    """Дизель вездехода на холостых."""
    t = t_axis(2.0)
    f0 = 28.0
    x = sum(np.sin(2 * np.pi * f0 * k * t + k) / k for k in range(1, 12))
    x *= 1 + 0.3 * np.sign(np.sin(2 * np.pi * f0 * 2 * t))
    x += 0.4 * bandpass(rng.standard_normal(len(t)), 80, 600)
    save("engine_loop.wav", np.tanh(lowpass(x, 900) * 1.5), 0.7)


def drone_loop():
    """Низкий давящий дрон: биения двух близких частот + дрожащий шум."""
    t = t_axis(8.0)
    x = np.sin(2 * np.pi * 41.0 * t) + np.sin(2 * np.pi * 41.5 * t) + 0.5 * np.sin(2 * np.pi * 61.25 * t)
    x += 0.35 * lowpass(rng.standard_normal(len(t)), 120) * (1 + 0.5 * np.sin(2 * np.pi * 0.125 * t))
    save("drone_loop.wav", seamless(x, 0.5), 0.6)


def heart_loop():
    """Сердцебиение 70 уд/мин."""
    period = 60.0 / 70.0
    one = np.zeros(int(SR * period))
    for start, amp in ((0.0, 1.0), (0.24, 0.7)):
        t = t_axis(0.18)
        beat = np.sin(2 * np.pi * 48 * t) * np.exp(-t * 28) * amp
        i = int(SR * start)
        one[i:i + len(t)] += beat
    save("heart_loop.wav", lowpass(np.tile(one, 4), 200), 0.9)


# --- Текстуры 64×64, бесшовные --------------------------------------------

def _tile_noise(size=64, scale=8, octaves=3, seed=0):
    r = np.random.default_rng(seed)
    acc = np.zeros((size, size))
    amp = 1.0
    for o in range(octaves):
        cells = scale * 2 ** o
        grid = r.random((cells, cells))
        img = Image.fromarray((grid * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC)
        # бесшовность: усредняем со сдвигом на полпериода
        a = np.asarray(img) / 255.0
        a = (a + np.roll(a, size // 2, 0) + np.roll(a, size // 2, 1) + np.roll(np.roll(a, size // 2, 0), size // 2, 1)) / 4
        acc += a * amp
        amp *= 0.5
    acc -= acc.min()
    return acc / (acc.max() + 1e-9)


def _save_tex(name, gray, tint=(1.0, 1.0, 1.0), mean=0.62):
    g = gray / (gray.mean() + 1e-9) * mean
    rgb = np.stack([np.clip(g * c, 0, 1) for c in tint], -1)
    Image.fromarray((rgb * 255).astype(np.uint8)).save(TEX / name)


def textures():
    S = 256
    y, x = np.mgrid[0:S, 0:S]

    # Штукатурка / масляная краска со следами кисти и микротрещинами (tex_plaster.png)
    n_base = _tile_noise(S, scale=6, octaves=4, seed=1)
    n_fine = _tile_noise(S, scale=24, octaves=3, seed=2)
    cracks = (np.abs(_tile_noise(S, scale=8, seed=101) - 0.5) < 0.02).astype(float)
    cracks = cracks + np.roll(cracks, S // 2, 0)
    plaster = 0.82 + 0.14 * n_base + 0.06 * n_fine - 0.15 * cracks
    _save_tex("tex_plaster.png", plaster, mean=0.65)

    # Доски с фасками, волокнами и коваными гвоздями (tex_planks.png)
    plank_idx = x // 32
    plank_u = x % 32
    seam = ((plank_u < 2) | (plank_u == 31)).astype(float)
    r_plank = np.random.default_rng(42)
    plank_tones = r_plank.uniform(0.85, 1.15, size=8)[plank_idx]
    grain_wave = _tile_noise(S, scale=4, octaves=3, seed=3)
    grain = 0.5 + 0.5 * np.sin((x + grain_wave * 18.0) * 0.45)
    nails = np.zeros((S, S))
    for px in range(16, S, 32):
        for py in (24, 152):
            dist = np.hypot(x - px, y - py)
            nails = np.maximum(nails, (dist < 3.2).astype(float) * 0.4)
    planks = (0.75 + 0.18 * grain + 0.08 * _tile_noise(S, scale=16, seed=4)) * plank_tones - 0.5 * seam - nails
    _save_tex("tex_planks.png", planks, mean=0.62)

    # Дерево / сосна с сучками и годовыми кольцами (tex_wood.png)
    wave = _tile_noise(S, scale=4, octaves=4, seed=5)
    dx1, dy1 = (x - 64) % S - S/2, (y - 80) % S - S/2
    dx2, dy2 = (x - 192) % S - S/2, (y - 200) % S - S/2
    r1 = np.hypot(dx1, dy1 * 1.8)
    r2 = np.hypot(dx2, dy2 * 1.8)
    knot_distort = 25.0 * np.exp(-r1 / 22.0) + 20.0 * np.exp(-r2 / 20.0)
    fibers = 0.5 + 0.5 * np.sin((x + wave * 22.0 + knot_distort) * 0.35)
    knots = (r1 < 6.0).astype(float) * 0.45 + (r2 < 5.0).astype(float) * 0.45
    wood = 0.72 + 0.22 * fibers + 0.08 * _tile_noise(S, scale=16, seed=12) - knots
    _save_tex("tex_wood.png", wood, mean=0.62)

    # Бревна сруба: цилиндрический объём, конопатка паклей, трещины (tex_logs.png)
    log_v = y % 64
    cos_val = np.maximum(0.0, np.sin(log_v / 64.0 * np.pi))
    roundness = cos_val ** 1.4
    chinking = ((log_v < 4) | (log_v > 60)).astype(float)
    tow_noise = _tile_noise(S, scale=20, octaves=2, seed=66) * chinking
    bark_grain = 0.5 + 0.5 * np.sin((x / 3.0 + 8.0 * _tile_noise(S, scale=4, seed=6)))
    logs = (0.65 + 0.35 * roundness) * (0.8 + 0.2 * bark_grain) - 0.45 * chinking + 0.15 * tow_noise
    _save_tex("tex_logs.png", logs, mean=0.60)

    # Снежный наст: заструги, кристаллы льда, мягкие тени (tex_snow.png)
    drift1 = np.sin((x * 0.04 + y * 0.015) + _tile_noise(S, scale=4, seed=7) * 4.0)
    drift2 = np.sin((x * 0.02 - y * 0.05) + _tile_noise(S, scale=6, seed=77) * 3.0)
    sparkles = (rng.random((S, S)) > 0.985).astype(float) * 0.25
    snow = 0.88 + 0.08 * drift1 + 0.05 * drift2 + 0.04 * _tile_noise(S, scale=12, seed=78) + sparkles
    _save_tex("tex_snow.png", snow, mean=0.72)

    # Хвоя кедра и ели (tex_needles.png)
    n_lay = _tile_noise(S, scale=16, octaves=3, seed=8)
    spikes = np.abs(np.sin(x * 0.6 + y * 0.4 + n_lay * 8.0))
    needles = 0.5 + 0.35 * spikes + 0.15 * _tile_noise(S, scale=8, seed=88)
    _save_tex("tex_needles.png", needles, mean=0.55)

    # Берёзовая кора с горизонтальными чечевичками и трещинами (tex_bark.png)
    lent = np.zeros((S, S))
    r_bark = np.random.default_rng(99)
    for _ in range(90):
        lx = r_bark.integers(0, S)
        ly = r_bark.integers(0, S)
        lw = r_bark.integers(8, 28)
        lh = r_bark.integers(2, 4)
        for dy in range(lh):
            yy = (ly + dy) % S
            for dx in range(lw):
                xx = (lx + dx) % S
                lent[yy, xx] = max(lent[yy, xx], 1.0 - (dy / (lh/2.0) - 1.0)**2)
    bark_fine = _tile_noise(S, scale=12, octaves=3, seed=9)
    bark = 0.88 + 0.12 * bark_fine - 0.55 * lent
    _save_tex("tex_bark.png", bark, mean=0.68)

    # Металл: штампованная сталь, заклепки, микроцарапины (tex_metal.png)
    m_base = _tile_noise(S, scale=6, octaves=3, seed=10)
    rivet_map = np.zeros((S, S))
    for rx in (12, 116, 140, 244):
        for ry in range(16, S, 32):
            d = np.hypot(x - rx, y - ry)
            rivet_map = np.maximum(rivet_map, (d < 3.0).astype(float) * 0.35)
    scratches = (np.abs(_tile_noise(S, scale=32, seed=11) - 0.5) < 0.015).astype(float) * 0.18
    metal = 0.80 + 0.12 * m_base + scratches - rivet_map
    _save_tex("tex_metal.png", metal, mean=0.62)


def creature_textures():
    """Кожа (пятна, вены), мех ушанки, сукно тулупа — для существ и людей."""
    S = 128
    y, x = np.mgrid[0:S, 0:S]
    veins1 = (np.abs(_tile_noise(S, scale=6, seed=23) - 0.5) < 0.02).astype(float)
    veins2 = (np.abs(_tile_noise(S, scale=12, seed=33) - 0.5) < 0.015).astype(float)
    skin = 0.82 + 0.15 * _tile_noise(S, scale=6, seed=21) - 0.28 * (veins1 + veins2 * 0.7)
    _save_tex("tex_skin.png", skin, mean=0.66)

    fur_flow = _tile_noise(S, scale=8, seed=24)
    fur_strands = np.sin((x * 1.5 + fur_flow * 14.0) * 0.8) * 0.5 + 0.5
    fur = 0.65 + 0.25 * fur_strands + 0.10 * _tile_noise(S, scale=20, seed=25)
    _save_tex("tex_fur.png", fur, mean=0.60)

    twill = np.sin((x * 1.2 + y * 1.2) * np.pi) * 0.5 + 0.5
    cloth = 0.80 + 0.12 * twill + 0.08 * _tile_noise(S, scale=16, seed=26)
    _save_tex("tex_cloth.png", cloth, mean=0.65)


def gore_hit():
    """Удар когтями: глухой мокрый шлепок + хруст."""
    r = np.random.default_rng(31)
    t = t_axis(0.6)
    thud = np.sin(2 * np.pi * (60 + 50 * np.exp(-t * 30)) * t) * np.exp(-t * 14)
    wet = lowpass(r.standard_normal(len(t)), 900) * np.exp(-t * 9) * 0.8
    crunch = np.zeros_like(t)
    for _ in range(9):
        i = r.integers(int(SR * 0.02), int(SR * 0.25))
        n = r.integers(80, 300)
        crunch[i:i + n] += r.standard_normal(n) * np.exp(-np.arange(n) / 60)
    x = thud + wet + bandpass(crunch, 1500, 6000) * 0.7
    save("gore_hit.wav", np.tanh(x * 1.5), 0.95)


def hidden_images():
    """Что проступает на спектрограмме при чистке плёнки."""
    w, h = 160, 100
    # Цифры станции: «КОД 417» — крупные штрихи.
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    for i, ch in enumerate("417"):
        x0 = 30 + i * 36
        if ch == "4":
            d.line([x0, 20, x0, 55, x0 + 24, 55], fill=255, width=5)
            d.line([x0 + 18, 20, x0 + 18, 80], fill=255, width=5)
        elif ch == "1":
            d.line([x0 + 12, 20, x0 + 12, 80], fill=255, width=5)
            d.line([x0 + 4, 30, x0 + 12, 20], fill=255, width=5)
        else:
            d.line([x0, 22, x0 + 26, 22, x0 + 8, 80], fill=255, width=5)
    img = img.filter(ImageFilter.GaussianBlur(0.8))
    Image.merge("RGBA", (img, img, img, img)).save(TEX / "hidden_numbers.png")
    # Схема: план чего-то под землёй — коридор, круглый зал, стрелка вниз.
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    d.rectangle([20, 40, 90, 56], outline=255, width=3)
    d.ellipse([90, 22, 140, 74], outline=255, width=3)
    d.line([115, 48, 115, 92], fill=255, width=3)
    d.line([108, 84, 115, 94, 122, 84], fill=255, width=3)
    for k in range(5):
        d.line([30 + k * 12, 40, 30 + k * 12, 56], fill=200, width=1)
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    Image.merge("RGBA", (img, img, img, img)).save(TEX / "hidden_scheme.png")


# --- Текстура лица -------------------------------------------------------

def face_flash():
    """Лицо Ауки для скримера: 160×120, потом растягивается с nearest-фильтром."""
    w, h = 160, 120
    img = Image.fromarray((rng.random((h, w)) * 38).astype(np.uint8), "L").convert("RGB")
    d = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2 + 6
    # Вытянутое лицо с затенением к краям (несколько концентрических эллипсов).
    for i, shade in enumerate((70, 92, 110, 122)):
        k = i * 5
        d.ellipse([cx - 33 + k, cy - 60 + k, cx + 31 - k, cy + 64 - k], fill=(shade, shade - 4, shade - 10))
    # Глазницы — неровные и разного размера.
    d.polygon([(cx - 27, cy - 24), (cx - 8, cy - 31), (cx - 5, cy - 6), (cx - 22, cy + 1)], fill=(3, 2, 2))
    d.polygon([(cx + 6, cy - 27), (cx + 24, cy - 21), (cx + 22, cy + 5), (cx + 9, cy - 1)], fill=(3, 2, 2))
    d.rectangle([cx - 15, cy - 14, cx - 14, cy - 13], fill=(230, 225, 205))      # зрачки-точки
    d.rectangle([cx + 15, cy - 11, cx + 16, cy - 10], fill=(230, 225, 205))
    # Рот — растянутый вниз, как будто челюсть вывихнута.
    d.polygon([(cx - 9, cy + 12), (cx + 7, cy + 10), (cx + 13, cy + 40), (cx + 5, cy + 66),
               (cx - 6, cy + 64), (cx - 12, cy + 36)], fill=(8, 3, 3))
    for _ in range(18):                                                          # трещины-тени
        x0, y0 = rng.integers(cx - 28, cx + 28), rng.integers(cy - 50, cy + 50)
        d.line([x0, y0, x0 + rng.integers(-6, 6), y0 + rng.integers(4, 20)], fill=(45, 40, 36), width=1)
    img = img.filter(ImageFilter.GaussianBlur(0.7))
    arr = np.asarray(img).astype(np.int16)
    # Вертикальный смаз — как сбой сигнала.
    for col in rng.integers(0, w, 10):
        arr[:, col] = np.roll(arr[:, col], rng.integers(-12, 12), axis=0)
    arr[::2] = (arr[::2] * 0.7).astype(np.int16)                                  # строки развёртки
    arr += rng.integers(-18, 18, arr.shape)
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(TEX / "face_flash.png")


def static_loop():
    """Помехи эфира: белый + коричневый шум и редкие щелчки. Громкость ведёт Radio (громкость = амплитуда)."""
    r = np.random.default_rng(77)
    n = SR * 4
    white = r.uniform(-1.0, 1.0, n)
    brown = np.zeros(n)
    acc = 0.0
    for i in range(n):
        acc = min(max(acc * 0.97 + white[i] * 0.15, -1.0), 1.0)
        brown[i] = acc
    crackle = np.where(r.random(n) < 0.0008, r.uniform(-1.0, 1.0, n), 0.0)
    x = np.clip(white * 0.5 + brown * 0.65 + crackle, -1.0, 1.0)
    x = seamless(x, 0.2)
    wavfile.write(AUDIO / "static_loop.wav", SR, (x * 32767).astype(np.int16))   # без нормализации


# --- Полная игра: новые звуки и картинки ----------------------------------

def _env(n, a, r):
    e = np.ones(n)
    na, nr = int(SR * a), int(SR * r)
    e[:na] = np.linspace(0, 1, na)
    e[-nr:] *= np.linspace(1, 0, nr) ** 2
    return e


def flare():
    """Ракетница: хлопок, свист взлёта, шипение горения."""
    r = np.random.default_rng(31)
    t = t_axis(2.6)
    n = len(t)
    pop = r.standard_normal(n) * np.exp(-t * 60) + np.sin(2 * np.pi * 70 * t) * np.exp(-t * 18) * 2.0
    whoosh_f = 900 + 2600 * np.clip(t / 0.6, 0, 1)
    whoosh = np.sin(2 * np.pi * np.cumsum(whoosh_f) / SR) * np.exp(-((t - 0.3) / 0.25) ** 2) * 0.25
    hiss = bandpass(r.standard_normal(n), 2500, 7000) * np.clip((t - 0.15) * 4, 0, 1) * np.exp(-t * 0.9) * 0.9
    save("flare.wav", np.tanh((pop + whoosh + hiss) * 1.4), 0.95)


def gust():
    """Порыв ветра и удар распахнутой двери."""
    r = np.random.default_rng(32)
    t = t_axis(3.0)
    n = len(t)
    swell = np.exp(-((t - 0.9) / 0.55) ** 2)
    wind = (lowpass(r.standard_normal(n), 700) * 1.5 + bandpass(r.standard_normal(n), 900, 2200) * 0.4) * swell
    bang_t = t - 0.75
    bang = np.where(bang_t > 0, (r.standard_normal(n) * 0.6 + np.sin(2 * np.pi * 85 * t)) * np.exp(-np.clip(bang_t, 0, None) * 14), 0)
    creak = np.where((t > 0.4) & (t < 0.8), signal.sawtooth(2 * np.pi * (180 + 90 * np.sin(2 * np.pi * 3 * t)) * t) * 0.15, 0)
    save("gust.wav", np.tanh(wind + bang * 1.5 + bandpass(creak, 300, 2500)), 0.95)


def whisper():
    """Шёпот: безголосые «слоги» — шум через форманты, без основного тона."""
    r = np.random.default_rng(33)
    out = np.zeros(int(SR * 2.4))
    pos = int(SR * 0.1)
    while pos < len(out) - SR // 4:
        syl = int(SR * r.uniform(0.12, 0.3))
        f1, f2 = VOWELS[r.choice(list(VOWELS))]
        src = r.standard_normal(syl)
        v = bandpass(src, f1 * 0.8, f1 * 1.25) * 0.6 + bandpass(src, f2 * 0.8, f2 * 1.2) + bandpass(src, 3500, 6000) * 0.5
        out[pos:pos + syl] += v * np.hanning(syl)
        pos += syl + int(SR * r.uniform(0.03, 0.18))
    # Близко к уху: лёгкое эхо комнаты.
    d = int(SR * 0.045)
    out[d:] += out[:-d] * 0.3
    save("whisper.wav", out, 0.8)


def fire_loop():
    r = np.random.default_rng(34)
    n = SR * 5
    roar = lowpass(r.standard_normal(n), 300) * 2.0
    roar *= 0.7 + 0.3 * np.sin(2 * np.pi * 0.6 * np.arange(n) / SR)
    crackle = np.zeros(n)
    for _ in range(260):
        p = r.integers(0, n - 400)
        L = r.integers(40, 380)
        crackle[p:p + L] += r.standard_normal(L) * np.exp(-np.arange(L) / (L / 4)) * r.uniform(0.3, 1.5)
    x = roar + bandpass(crackle, 1200, 8000) * 1.2
    save("fire_loop.wav", seamless(np.tanh(x), 0.3), 0.9)


def mother_loop():
    """Женский голос по радио: выше, медленнее, с «колодезным» эхом."""
    x = fake_voice(7.0, pitch=215.0)
    d = int(SR * 0.23)
    y = x.copy()
    for k in range(1, 4):
        y[d * k:] += x[:-d * k] * (0.45 ** k)
    y += 0.1 * rng.standard_normal(len(y)) * (np.max(np.abs(y)) + 1e-9)
    save("mother_loop.wav", seamless(radio_fx(y, 3.0), 0.25), 0.7)


def roll_loop():
    """Перекличка: короткие фразы мужским голосом, писк, пауза."""
    parts = []
    for i in range(5):
        parts.append(fake_voice(rng.uniform(0.9, 1.4), pitch=rng.uniform(90, 140)))
        tb = t_axis(0.12)
        parts.append(np.sin(2 * np.pi * 1450 * tb) * np.hanning(len(tb)) * 0.6)
        parts.append(np.zeros(int(SR * rng.uniform(0.5, 0.9))))
    x = np.concatenate(parts)
    x += 0.03 * rng.standard_normal(len(x))
    save("roll_loop.wav", seamless(radio_fx(x, 2.6), 0.15), 0.7)


def otzvuk_loop():
    """Гул из-под земли: низкие биения, медленное «дыхание» огромного объёма."""
    t = t_axis(8.0)
    x = np.sin(2 * np.pi * 41 * t) + 0.8 * np.sin(2 * np.pi * 43.5 * t) + 0.4 * np.sin(2 * np.pi * 82 * t + 1)
    breath = (0.5 + 0.5 * np.sin(2 * np.pi * 0.125 * t - np.pi / 2)) ** 2
    air = bandpass(rng.standard_normal(len(t)), 150, 900) * breath * 0.9
    x = x * (0.6 + 0.4 * breath) + air
    save("otzvuk_loop.wav", seamless(np.tanh(x * 0.8), 0.4), 0.75)


def echo_loop():
    """Твой голос: тот же мужской голос, что у «Большой Земли», с длинным повтором — отзвук."""
    x = fake_voice(6.0, pitch=118.0)
    d = int(SR * 0.37)
    y = x.copy()
    for k in range(1, 6):
        y[d * k:] += x[:-d * k] * (0.6 ** k)
    save("echo_loop.wav", seamless(radio_fx(y, 3.5), 0.3), 0.7)


def hidden_images_2():
    w, h = 160, 100
    # Мама: дверь, за ней — фигура выше дверного проёма.
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    d.rectangle([50, 18, 92, 92], outline=255, width=3)
    d.ellipse([98, 4, 116, 24], outline=255, width=2)
    d.line([107, 24, 107, 70], fill=255, width=3)
    d.line([107, 34, 92, 58], fill=255, width=2)
    d.line([107, 70, 100, 95], fill=255, width=2)
    d.line([107, 70, 114, 95], fill=255, width=2)
    img = img.filter(ImageFilter.GaussianBlur(0.7))
    Image.merge("RGBA", (img, img, img, img)).save(TEX / "hidden_door.png")
    # Перекличка: семь строк, шесть зачёркнуты, седьмая — пустой квадрат.
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    for i in range(7):
        y = 12 + i * 12
        d.line([30, y, 110, y], fill=200, width=2)
        if i < 6:
            d.line([26, y - 4, 116, y + 4], fill=255, width=2)
        else:
            d.rectangle([118, y - 5, 128, y + 5], outline=255, width=2)
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    Image.merge("RGBA", (img, img, img, img)).save(TEX / "hidden_roll.png")
    # Отзвук: люк, лестница вниз, под ней — огромный глаз.
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    d.rectangle([66, 4, 94, 12], outline=255, width=2)
    d.line([72, 12, 72, 48], fill=255, width=2)
    d.line([88, 12, 88, 48], fill=255, width=2)
    for k in range(5):
        d.line([72, 18 + k * 7, 88, 18 + k * 7], fill=255, width=2)
    d.ellipse([28, 58, 132, 96], outline=255, width=3)
    d.ellipse([68, 64, 92, 90], fill=255)
    d.ellipse([76, 71, 84, 83], fill=0)
    img = img.filter(ImageFilter.GaussianBlur(0.7))
    Image.merge("RGBA", (img, img, img, img)).save(TEX / "hidden_bunker.png")


# --- Звуковой проход v1.0: живее и «пространственнее» -----------------------

def reverb(x: np.ndarray, sec: float = 1.2, wet: float = 0.3, damp: float = 3000.0, seed: int = 5) -> np.ndarray:
    """Простая реверберация: свёртка с затухающим шумом (импульс комнаты/леса)."""
    r = np.random.default_rng(seed)
    t = t_axis(sec)
    ir = r.standard_normal(len(t)) * np.exp(-t * 6.9 / sec)
    ir = lowpass(ir, damp)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    y = signal.fftconvolve(x, ir)
    dry = np.concatenate([x, np.zeros(len(y) - len(x))])
    return dry * (1 - wet) + y * wet * (np.max(np.abs(x)) / (np.max(np.abs(y)) + 1e-9))


def wind_loop_v2():
    """Ветер: низкий гул, шелест хвои и редкие «завывания» — узкие резонансы, плывущие по высоте."""
    r = np.random.default_rng(101)
    sec = 24.0
    t = t_axis(sec)
    n = len(t)
    base = lowpass(r.standard_normal(n), 380) * 1.4
    gust = 0.55 + 0.45 * np.sin(2 * np.pi * t / 12.0) * np.sin(2 * np.pi * t / 8.0 + 1.1)
    needles = bandpass(r.standard_normal(n), 1800, 6000) * 0.12 * gust ** 2
    howl = np.zeros(n)
    for k, (f0, ph) in enumerate(((420, 0.0), (610, 2.0), (330, 4.1))):
        f = f0 * (1 + 0.12 * np.sin(2 * np.pi * t / (6.0 * (k + 1)) + ph))
        src = r.standard_normal(n)
        # «Резонатор»: узкая полоса вокруг плывущей частоты — рассчитываем блоками.
        blk = SR // 4
        out = np.zeros(n)
        for i in range(0, n, blk):
            fc = float(np.mean(f[i:i + blk]))
            sos = signal.butter(2, [fc * 0.97, fc * 1.03], btype="band", fs=SR, output="sos")
            out[i:i + blk] = signal.sosfilt(sos, src[i:i + blk])
        env = np.clip(np.sin(2 * np.pi * t / sec * (k + 1) + ph), 0, 1) ** 3
        howl += out * env * 2.2
    x = (base + needles) * gust + howl * gust
    save("wind_loop.wav", seamless(x, 1.0), 0.8)


def scream_v2():
    """Крик: «голосовой» источник с рваным тоном через форманты А/Э, перегруз, хвост в реверберации."""
    r = np.random.default_rng(102)
    t = t_axis(1.5)
    n = len(t)
    f0 = 380 + 520 * (1 - np.exp(-t * 9)) - 160 * np.clip(t - 0.8, 0, None)
    f0 *= 1 + 0.035 * r.standard_normal(n).cumsum() / np.sqrt(np.arange(1, n + 1)) + 0.03 * np.sin(2 * np.pi * 11 * t)
    phase = np.cumsum(f0) / SR
    src = signal.sawtooth(2 * np.pi * phase) + 0.6 * signal.sawtooth(2 * np.pi * phase * 1.5) + 0.8 * r.standard_normal(n)
    v = bandpass(src, 750, 1300) + 0.8 * bandpass(src, 1700, 2600) + 0.5 * bandpass(src, 2800, 3800)
    env = np.minimum(t / 0.015, 1.0) * np.exp(-np.maximum(t - 0.95, 0) * 6)
    x = np.tanh(v * 3.5) * env
    save("scream.wav", reverb(x, 0.9, 0.25, 4500, 7), 0.98)


def whistle_v2():
    """Свист в лесу: двухтоновое «фью-ить», как зовут собаку, далеко и с эхом леса."""
    r = np.random.default_rng(103)
    t = t_axis(1.6)
    seg1 = np.clip(t / 0.55, 0, 1)
    f = np.where(t < 0.6, 1500 - 300 * seg1, 1150 + 1100 * np.clip((t - 0.75) / 0.35, 0, 1))
    f += 18 * np.sin(2 * np.pi * 5.5 * t)
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR)
    gate = np.clip(np.minimum(t / 0.08, 1) * (1 - np.clip((t - 0.56) / 0.04, 0, 1) * np.clip((0.8 - t) / 0.04, 0, 1)), 0, 1)
    env = gate * np.exp(-np.maximum(t - 1.2, 0) * 8)
    breath = bandpass(r.standard_normal(len(t)), 1000, 3000) * 0.12
    x = (tone + breath) * env
    save("whistle.wav", reverb(lowpass(x, 5000), 2.2, 0.45, 2500, 11), 0.7)


def growl_v2():
    """Рык: хриплые импульсы (вокальный фрай) + субгармоника + клокотание."""
    r = np.random.default_rng(104)
    t = t_axis(2.0)
    n = len(t)
    f0 = 42 + 10 * np.sin(2 * np.pi * 2.3 * t) + 4 * r.standard_normal(n).cumsum() / 300
    phase = np.cumsum(f0) / SR
    pulses = (np.diff(np.floor(phase), prepend=0) > 0).astype(float) * (0.6 + 0.4 * r.random(n))
    body = bandpass(pulses, 90, 900) * 3 + 0.5 * np.sin(2 * np.pi * phase * 0.5)
    gurgle = bandpass(r.standard_normal(n), 250, 1400) * (0.5 + 0.5 * np.sin(2 * np.pi * 17 * t)) * 0.6
    env = np.minimum(t / 0.15, 1.0) * np.exp(-np.maximum(t - 1.3, 0) * 4)
    save("growl.wav", reverb(np.tanh((body + gurgle) * 2.2) * env, 0.6, 0.2, 2000, 13), 0.95)


def door_knock_v2():
    """Стук в дверь: костяшки по доскам — короткий удар + резонанс полотна + дребезг."""
    r = np.random.default_rng(105)
    def hit(level):
        t = t_axis(0.35)
        thump = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * d) for f, d in ((110, 26), (190, 30), (420, 45), (760, 60)))
        tick = bandpass(r.standard_normal(len(t)), 1500, 6000) * np.exp(-t * 160)
        return (thump + tick * 0.8) * level
    out = np.zeros(int(SR * 2.4))
    for start in (0.0, 0.22, 0.44, 1.05, 1.27, 1.49):
        h = hit(r.uniform(0.8, 1.0))
        i = int(SR * start)
        out[i:i + len(h)] += h
    save("door_knock.wav", reverb(np.tanh(out * 1.3), 0.7, 0.3, 3000, 17), 0.95)


def yrka_run_loop_v2():
    """Бег Ырки на четырёх: тяжёлые неровные удары по снегу + хриплое дыхание."""
    r = np.random.default_rng(106)
    period = 0.72
    n = int(SR * period)
    x = np.zeros(n * 4)
    for k in range(4):
        for off in (0.0, 0.11, 0.36, 0.45):
            c = _crunch(0.22, 0.65)
            t = t_axis(0.22)
            thud = np.sin(2 * np.pi * 60 * t) * np.exp(-t * 28) * 1.5
            i = int(SR * (k * period + off + r.uniform(-0.01, 0.01)))
            seg = (c + thud)[:len(x) - i]
            x[i:i + len(seg)] += seg
    t = t_axis(period * 4)
    breath_env = np.maximum(np.sin(2 * np.pi * t / period), 0) ** 2
    breath = bandpass(r.standard_normal(len(t)), 300, 1500) * breath_env * 0.5
    save("yrka_run_loop.wav", np.tanh(x + breath), 0.85)


def drone_loop_v2():
    """Фоновая тревога: низкие биения + далёкий металлический «вой» мачты."""
    r = np.random.default_rng(107)
    sec = 16.0
    t = t_axis(sec)
    x = np.sin(2 * np.pi * 55 * t) + 0.7 * np.sin(2 * np.pi * 55.5 * t) + 0.3 * np.sin(2 * np.pi * 110.25 * t)
    metal = sum(np.sin(2 * np.pi * f * t + p) for f, p in ((612.5, 0.0), (1008.75, 1.3), (1502.5, 2.1))) / 3
    metal *= (0.5 + 0.5 * np.sin(2 * np.pi * t / sec)) ** 4 * 0.25
    air = lowpass(r.standard_normal(len(t)), 200) * 0.3
    save("drone_loop.wav", seamless(x * 0.5 + metal + air, 1.0), 0.6)


# --- v1.1: мягче — дверь, рация, металл ---------------------------------------

def static_loop_v2():
    """Помехи эфира: тёплый «розовый» шум без верхов, медленное дыхание и редкие мягкие щелчки."""
    r = np.random.default_rng(78)
    n = SR * 6
    t = np.arange(n) / SR
    white = r.standard_normal(n)
    pink = lowpass(white, 1600, 2) * 0.9 + bandpass(white, 1600, 2800) * 0.1
    pink *= 0.85 + 0.15 * np.sin(2 * np.pi * 0.33 * t) * np.sin(2 * np.pi * 0.11 * t + 1.0)
    crackle = np.zeros(n)
    for _ in range(40):
        i = r.integers(0, n - 300)
        L = r.integers(60, 280)
        crackle[i:i + L] += r.standard_normal(L) * np.exp(-np.arange(L) / (L / 3)) * r.uniform(0.3, 1.0)
    x = pink + lowpass(crackle, 2500) * 0.8
    x = seamless(x, 0.3)
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.55
    wavfile.write(AUDIO / "static_loop.wav", SR, (x * 32767).astype(np.int16))   # громкость ведёт Radio


def door_v2():
    """Дверь: низкий деревянный скрип петель и глухой мягкий удар — без визга."""
    r = np.random.default_rng(79)
    t = t_axis(0.8)
    f = 120 + 45 * np.sin(2 * np.pi * 0.9 * t) + 12 * np.sin(2 * np.pi * 7 * t)
    stick = (r.random(len(t)) > 0.55).astype(float)
    stick = np.convolve(stick, np.ones(90) / 90, mode="same")         # «прилипание» петли — без щелчков
    creak = signal.sawtooth(2 * np.pi * np.cumsum(f) / SR, 0.3) * (0.35 + 0.65 * stick)
    creak = lowpass(bandpass(creak, 150, 1400), 1100, 4) * np.minimum(t / 0.08, 1) * np.exp(-np.maximum(t - 0.5, 0) * 7)
    tt = t_axis(0.45)
    thud = (np.sin(2 * np.pi * 62 * tt) + 0.5 * np.sin(2 * np.pi * 95 * tt)) * np.exp(-tt * 14)
    thud += lowpass(r.standard_normal(len(tt)), 400) * np.exp(-tt * 30) * 0.6
    x = np.concatenate([creak * 0.55, thud])
    save("door.wav", reverb(x, 0.5, 0.2, 2000, 19), 0.6)


def clank_v2():
    """Металл: глухой удар по железу, высокие обертоны быстро гаснут."""
    r = np.random.default_rng(80)
    t = t_axis(0.7)
    x = sum(a * np.sin(2 * np.pi * f * t) * np.exp(-t * d) for f, d, a in ((210, 8, 1.0), (523, 12, 0.6), (1130, 22, 0.3), (1870, 40, 0.15)))
    x += lowpass(r.standard_normal(len(t)), 1500) * np.exp(-t * 50) * 0.4
    save("clank.wav", reverb(lowpass(x, 3000), 0.6, 0.25, 2200, 23), 0.6)


def crank_loop_v2():
    """Жучок: мягкое жужжание динамо и трещотка, без пронзительных верхов."""
    r = np.random.default_rng(81)
    t = t_axis(1.0)
    whir = np.sin(2 * np.pi * 140 * t) * 0.5 + np.sin(2 * np.pi * 280 * t) * 0.2 + signal.sawtooth(2 * np.pi * 140 * t) * 0.15
    clicks = np.zeros_like(t)
    for k in range(28):
        i = int(k * len(t) / 28)
        clicks[i:i + 50] += r.standard_normal(50) * np.exp(-np.arange(50) / 10)
    x = lowpass(whir, 1200) + lowpass(bandpass(clicks, 800, 3500), 2500) * 0.5
    save("crank_loop.wav", x * (1 + 0.1 * np.sin(2 * np.pi * 7 * t)), 0.45)


def gust_v2():
    r = np.random.default_rng(82)
    t = t_axis(3.0)
    n = len(t)
    swell = np.exp(-((t - 0.9) / 0.6) ** 2)
    wind = (lowpass(r.standard_normal(n), 600) * 1.5 + bandpass(r.standard_normal(n), 700, 1600) * 0.25) * swell
    bang_t = np.clip(t - 0.75, 0, None)
    bang = np.where(t > 0.75, (np.sin(2 * np.pi * 70 * t) + lowpass(r.standard_normal(n), 500) * 0.5) * np.exp(-bang_t * 12), 0)
    save("gust.wav", reverb(wind + bang * 1.2, 0.8, 0.25, 1800, 29), 0.75)


def beacon_loop():
    """Маяк: короткий писк раз в секунду через эфир."""
    t = t_axis(1.0)
    beep = np.sin(2 * np.pi * 1180 * t) * (t < 0.12) * np.minimum(t / 0.005, 1)
    x = np.tile(beep, 4) + 0.02 * np.random.default_rng(83).standard_normal(SR * 4)
    save("beacon_loop.wav", radio_fx(x, 1.6), 0.55)


# --- v1.2: живой лес ---------------------------------------------------------

def wolf_howl():
    """Волчий вой издалека: тон скользит вверх и долго тянется вниз, лёгкое вибрато, эхо леса."""
    r = np.random.default_rng(91)
    t = t_axis(4.2)
    f = 380 + 260 * np.clip(t / 0.8, 0, 1) - 180 * np.clip((t - 1.6) / 2.2, 0, 1) ** 1.4
    f += 6 * np.sin(2 * np.pi * 5.2 * t)
    ph = np.cumsum(f) / SR
    tone = np.sin(2 * np.pi * ph) + 0.35 * np.sin(4 * np.pi * ph) + 0.12 * np.sin(6 * np.pi * ph)
    breath = bandpass(r.standard_normal(len(t)), 500, 2000) * 0.08
    env = np.minimum(t / 0.5, 1) * np.exp(-np.maximum(t - 3.0, 0) * 2.5)
    x = lowpass((tone + breath) * env, 2500)
    save("wolf_howl.wav", reverb(x, 3.0, 0.5, 1800, 31), 0.6)


def tree_creak():
    """Скрип ствола на морозе: медленный низкий «стон» с прерывистым трением."""
    r = np.random.default_rng(92)
    t = t_axis(2.2)
    f = 70 + 25 * np.sin(2 * np.pi * 0.45 * t)
    stick = np.convolve((r.random(len(t)) > 0.6).astype(float), np.ones(220) / 220, mode="same")
    x = signal.sawtooth(2 * np.pi * np.cumsum(f) / SR, 0.2) * (0.3 + 0.7 * stick)
    x = lowpass(bandpass(x, 60, 900), 700, 4) * np.sin(np.pi * t / t[-1]) ** 0.7
    save("tree_creak.wav", reverb(x, 1.6, 0.35, 1200, 33), 0.55)


def owl():
    """Филин: два глухих «у-ух»."""
    t = t_axis(2.4)
    x = np.zeros_like(t)
    for st, d in ((0.0, 0.45), (0.9, 0.7)):
        m = (t >= st) & (t < st + d)
        tt = t[m] - st
        f = 310 - 40 * tt / d
        x[m] += np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / d) ** 1.5
    save("owl.wav", reverb(lowpass(x, 1200), 2.0, 0.45, 1500, 35), 0.5)


def raven():
    """Ворон: хриплое «крра» дважды."""
    r = np.random.default_rng(93)
    t = t_axis(1.6)
    x = np.zeros_like(t)
    for st in (0.0, 0.55):
        m = (t >= st) & (t < st + 0.32)
        tt = t[m] - st
        f0 = 520 - 120 * tt / 0.32
        ph = np.cumsum(f0) / SR
        src = signal.sawtooth(2 * np.pi * ph) * (0.6 + 0.4 * r.random(len(tt)))
        v = bandpass(src, 800, 1500) + 0.6 * bandpass(src, 1800, 2600)
        x[m] += np.tanh(v * 2) * np.sin(np.pi * tt / 0.32)
    save("raven.wav", reverb(lowpass(x, 3000), 1.8, 0.4, 2200, 37), 0.55)


def snow_fall():
    """Снег сорвался с ветки: шорох и мягкий удар в сугроб."""
    r = np.random.default_rng(94)
    t = t_axis(1.4)
    rustle = lowpass(bandpass(r.standard_normal(len(t)), 400, 3000), 2500) * np.exp(-((t - 0.25) / 0.2) ** 2)
    thud = np.where(t > 0.5, np.sin(2 * np.pi * 55 * t) * np.exp(-np.clip(t - 0.5, 0, None) * 10), 0)
    puff = np.where(t > 0.5, lowpass(r.standard_normal(len(t)), 600) * np.exp(-np.clip(t - 0.5, 0, None) * 6), 0) * 0.6
    save("snow_fall.wav", reverb(rustle * 0.7 + thud + puff, 0.6, 0.2, 2000, 39), 0.6)


if __name__ == "__main__":
    AUDIO.mkdir(parents=True, exist_ok=True)
    TEX.mkdir(parents=True, exist_ok=True)
    for fn in (gore_hit, creature_textures, static_loop, hum_loop, wind_loop, buzzer_loop, numbers_loop, carrier_loop, voice_loop,
               knock, scream, sub_drop, face_flash,
               steps, yrka_steps, yrka_run_loop, whistle, growl, shriek, door, crank_loop,
               breath_loop, ice_hit, clank, stove_add, frost_vignette,
               voice_mainland, morse_loop, lullaby_loop, tape_hiss, door_knock, engine_loop,
               drone_loop, heart_loop, textures, hidden_images,
               flare, gust, whisper, fire_loop, mother_loop, roll_loop, otzvuk_loop, echo_loop, hidden_images_2,
               wind_loop_v2, scream_v2, whistle_v2, growl_v2, door_knock_v2, yrka_run_loop_v2, drone_loop_v2,
               static_loop_v2, door_v2, clank_v2, crank_loop_v2, gust_v2, beacon_loop,
               wolf_howl, tree_creak, owl, raven, snow_fall):
        fn()
        print("ok", fn.__name__)
