#!/usr/bin/env python3
"""Процедурные бесшовные текстуры «Кедр-7» (PS1-стиль: малое разрешение, nearest-фильтр).
Все текстуры тайлятся без швов (шум строится через FFT, т.е. периодичен по построению).
Средняя яркость ~0.62: шейдер умножает на 1.6 и на цвет палитры, так что палитра не «плывёт».
Запуск: python3 tools/gen_textures.py  → assets/textures/tex_*.png
"""
import numpy as np
from PIL import Image
import os, sys

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
TARGET_MEAN = 0.62


def fnoise(n, lo, hi, seed, aniso=(1.0, 1.0), power=1.0):
    """Периодический шум: белый шум, отфильтрованный в полосе частот [lo, hi] (циклов на текстуру).
    aniso растягивает спектр по осям (x, y): >1 — больше частот по этой оси (полосы поперёк)."""
    rng = np.random.default_rng(seed)
    w = rng.standard_normal((n, n))
    F = np.fft.fft2(w)
    fy = np.fft.fftfreq(n)[:, None] * n
    fx = np.fft.fftfreq(n)[None, :] * n
    r = np.sqrt((fx / aniso[0]) ** 2 + (fy / aniso[1]) ** 2)
    mask = ((r >= lo) & (r <= hi)).astype(float)
    mask *= np.where(r > 0, r, 1.0) ** (-power)
    out = np.real(np.fft.ifft2(F * mask))
    out -= out.mean()
    s = out.std()
    return out / (s if s > 0 else 1.0)


def fbm(n, seed, base=2, octaves=5, aniso=(1.0, 1.0), gain=0.55):
    acc = np.zeros((n, n))
    amp = 1.0
    f = base
    for o in range(octaves):
        acc += amp * fnoise(n, f, f * 2, seed + o * 17, aniso, power=0.0)
        amp *= gain
        f *= 2
    acc -= acc.mean()
    return acc / acc.std()


def norm01(a):
    a = a - a.min()
    return a / (a.max() if a.max() > 0 else 1.0)


UPSCALE = 2   # тексель вдвое мельче: рядом с запечёнными моделями (1–2К) квадраты 128-px текстур лезли в глаза


def upscale(rgb, k=UPSCALE, seed=0):
    """Бесшовно увеличить в k раз (Ланцош по тайлу 3×3, центр) и добавить тонкое зерно нового размера."""
    if k <= 1:
        return rgb
    h, w, _ = rgb.shape
    out = np.empty((h * k, w * k, 3))
    for c in range(3):
        tile = np.tile(rgb[:, :, c].astype(np.float32), (3, 3))
        big = np.asarray(Image.fromarray(tile, "F").resize((w * 3 * k, h * 3 * k), Image.LANCZOS))
        out[:, :, c] = big[h * k:2 * h * k, w * k:2 * w * k]
    grain = fnoise(h * k, h * k // 4, h * k // 2, 7000 + seed) * 0.012
    return out + grain[:, :, None]


def finish(rgb, name, mean=TARGET_MEAN, levels=None):
    """rgb: HxWx3 в [0..1]. Подгоняем среднее, слегка квантуем (PS1 — 5 бит на канал)."""
    rgb = upscale(np.clip(rgb, 0, None), seed=len(name))
    rgb = np.clip(rgb, 0, None)
    m = rgb.mean()
    rgb = rgb * (mean / m)
    rgb = np.clip(rgb, 0, 1)
    q = levels or 32
    rgb = np.round(rgb * (q - 1)) / (q - 1)
    img = Image.fromarray((rgb * 255).astype(np.uint8), "RGB")
    img.save(os.path.join(OUT, name))
    print("wrote", name, img.size, "mean", round(float(rgb.mean()), 3), "std", round(float(rgb.std()), 3))


def gray(a):
    return np.repeat(a[:, :, None], 3, axis=2)


def tint(a, c):
    return a[:, :, None] * np.array(c)[None, None, :]


def shift(a, dx, dy):
    return np.roll(np.roll(a, dy, axis=0), dx, axis=1)


# ---------------------------------------------------------------------------------------------

def snow():
    n = 256
    # Крупные пятна наста + перемёты (застругi) поперёк ветра + мелкая искра.
    macro = fbm(n, 11, base=1, octaves=3)
    rip = fnoise(n, 6, 14, 12, aniso=(0.35, 1.0))            # вытянутые волны
    rip2 = fnoise(n, 14, 30, 13, aniso=(0.4, 1.0))
    grain = fnoise(n, 50, 128, 14)
    h = 0.55 * macro + 0.35 * rip + 0.18 * rip2
    # Освещение «рельефа» волн: производная по ветру даёт светлую/теневую сторону гребня
    shade = (shift(h, 0, 1) - shift(h, 0, -1))
    v = 1.0 + 0.05 * h + 0.07 * shade + 0.025 * grain
    rng = np.random.default_rng(15)
    sparkle = (rng.random((n, n)) > 0.9965).astype(float)
    v = v + sparkle * 0.18
    # Холодные тени в низинах, чуть тёплый свет на гребнях
    cold = np.clip(-h, 0, None) * 0.035
    rgb = np.stack([v - cold * 0.6, v - cold * 0.3, v + cold * 0.2], axis=2)
    finish(rgb, "tex_snow.png", mean=0.70)


def plaster():
    n = 256
    # Советская масляная краска по штукатурке: широкие мазки кистью, редкие волосяные трещинки,
    # потёртость к низу почти не видна (масштаб 1.6 м на тайл). Низкий контраст — без «камуфляжа».
    strokes = fnoise(n, 3, 24, 21, aniso=(0.4, 1.0))          # мазки кистью
    blot = fbm(n, 22, base=2, octaves=3)
    fine = fnoise(n, 60, 128, 23)
    v = 1.0 + 0.02 * strokes + 0.035 * blot + 0.018 * fine
    # Волосяные трещины: тонкие изломанные линии по изолинии шума, очень бледные
    c = fbm(n, 24, base=3, octaves=4)
    crack = np.exp(-(c / 0.035) ** 2) * (fbm(n, 25, base=2, octaves=2) > 0.9)
    v -= crack * 0.12
    rgb = gray(v)
    finish(rgb, "tex_plaster.png", mean=0.64)


def stove():
    n = 128
    # Побелённая печь: кирпичная кладка под известью — швы угадываются, побелка неровная.
    v = np.ones((n, n))
    bh, bw = 16, 32   # 8 рядов × 4 кирпича на тайл (0.8 м)
    yy, xx = np.mgrid[0:n, 0:n]
    row = yy // bh
    off = (row % 2) * (bw // 2)
    mortar = ((yy % bh) < 2) | (((xx + off) % bw) < 2)
    v -= mortar * 0.09
    wash = fbm(n, 31, base=2, octaves=4)
    soot = np.clip(fbm(n, 32, base=1, octaves=3) - 0.8, 0, None)
    v += 0.05 * wash - 0.12 * soot + 0.02 * fnoise(n, 30, 64, 33)
    finish(gray(v), "tex_stove.png", mean=0.66)


def concrete():
    n = 128
    v = 1.0 + 0.06 * fbm(n, 41, base=2, octaves=5)
    rng = np.random.default_rng(42)
    pits = (rng.random((n, n)) > 0.985).astype(float)
    v -= pits * 0.18
    yy, xx = np.mgrid[0:n, 0:n]
    v -= ((yy % 64) < 1) * 0.08          # шов опалубки
    v += 0.03 * fnoise(n, 1, 3, 43, aniso=(1.0, 0.2))   # потёки сверху вниз
    finish(gray(v), "tex_concrete.png", mean=0.6)


def logs():
    n = 256
    # Бревенчатый сруб: 4 венца на тайл (1.2 м → 0.3 м бревно). Скруглённая затенённая форма,
    # тёмный паз со мхом/паклей, волокна вдоль бревна, сучки.
    yy, xx = np.mgrid[0:n, 0:n].astype(float)
    period = n / 4
    t = (yy % period) / period                     # 0..1 поперёк бревна
    round_shade = np.sin(t * np.pi) ** 0.6         # выпуклость
    fiber = fnoise(n, 3, 60, 51, aniso=(0.08, 1.0))
    knots_n = fnoise(n, 10, 18, 52)
    knots = np.clip(knots_n - 2.3, 0, None)
    gap = np.exp(-((t - 0.0) / 0.06) ** 2) + np.exp(-((t - 1.0) / 0.06) ** 2)
    moss = (fnoise(n, 8, 30, 53) > 0.3) * gap
    v = 0.62 + 0.38 * round_shade + 0.06 * fiber - 0.25 * knots
    v = v * (1 - 0.75 * gap)
    rgb = gray(v)
    rgb[:, :, 1] += moss * 0.05      # пакля/мох в пазах — чуть зеленее
    rgb[:, :, 0] -= moss * 0.02
    # Неоднородность от бревна к бревну
    row = (yy // period).astype(int)
    tone = np.array([1.0, 0.93, 1.05, 0.97])[row % 4]
    rgb *= tone[:, :, None]
    finish(rgb, "tex_logs.png", mean=0.6)


def planks():
    n = 256
    # Доски: 5 на тайл (1 м → 20 см доска), волокно вдоль, тёмные щели, гвозди, разный тон.
    yy, xx = np.mgrid[0:n, 0:n].astype(float)
    w = n / 5
    col = (xx // w).astype(int)
    u = (xx % w) / w
    fiber = fnoise(n, 2, 50, 61, aniso=(1.0, 0.07))
    rings = np.sin((fnoise(n, 1, 4, 62, aniso=(1.0, 0.2)) * 3 + u * 6) * 3.0)
    tone = np.array([1.0, 0.9, 1.07, 0.95, 1.02])[col % 5]
    # торцевые стыки досок на разной высоте
    JY = [40, 170, 95, 220, 10]
    joint_y = np.array(JY)[col % 5]
    joint = (np.abs(yy - joint_y) < 1.0)
    v = (0.95 + 0.07 * fiber + 0.035 * rings) * tone
    gap = (u < 0.035) | (u > 0.975)
    v[gap] *= 0.35
    v[joint] *= 0.5
    # гвозди у стыков
    for c in range(5):
        for dy in (-6, 6):
            y0 = int((JY[c] + dy) % n)
            x0 = int(c * w + w * 0.5)
            for x in (x0 - 9, x0 + 9):
                v[y0 % n, x % n] *= 0.4
    finish(gray(v), "tex_planks.png", mean=0.6)


def wood():
    n = 128
    yy, xx = np.mgrid[0:n, 0:n].astype(float)
    warp = fnoise(n, 1, 5, 71, aniso=(1.0, 0.3)) * 4
    rings = np.sin(xx / n * 2 * np.pi * 9 + warp)
    fiber = fnoise(n, 4, 50, 72, aniso=(1.0, 0.08))
    v = 1.0 + 0.05 * rings + 0.05 * fiber
    knot = fnoise(n, 3, 6, 73)
    v -= np.clip(knot - 2.4, 0, None) * 0.3
    finish(gray(v), "tex_wood.png", mean=0.6)


def bark():
    n = 128
    # Кора сосны/ели: вертикальные пластины, тёмные продольные трещины, поперечные разломы пластин.
    yy, xx = np.mgrid[0:n, 0:n].astype(float)
    warp = fnoise(n, 1, 4, 81, aniso=(0.25, 1.0))
    k = 7   # трещин на тайл
    phase = (xx / n * k + warp * 0.12 + fnoise(n, 6, 12, 84) * 0.04) % 1.0
    crack = np.exp(-((phase - 0.5) / 0.1) ** 2)
    # поперечные разломы пластин — короткие горизонтальные тёмные штрихи
    plate_id = np.floor(xx / n * k + warp * 0.12)
    breaks = np.sin((yy / n * 6 + plate_id * 0.37) * 2 * np.pi)
    brk = np.exp(-((breaks - 1.0) / 0.01) ** 2) * (1 - crack) * (np.sin(plate_id * 2.1) > 0)
    scales = fnoise(n, 10, 40, 82)
    v = 1.0 - 0.55 * crack - 0.25 * brk + 0.07 * scales
    rgb = tint(v, (1.05, 1.0, 0.92))
    finish(rgb, "tex_bark.png", mean=0.58)


def needles():
    n = 128
    # Хвоя: мелкие штрихи-иглы, ярусы лап, мягкие тени между ними, редкие пятнышки снега.
    rng = np.random.default_rng(91)
    v = np.zeros((n, n)) + 0.8
    for _ in range(3000):
        x, y = rng.integers(0, n, 2)
        L = rng.integers(3, 6)
        d = rng.choice([-1, 1])
        b = rng.uniform(0.85, 1.12)
        for k in range(L):
            v[(y + k) % n, (x + d * k) % n] = b
    tiers = fnoise(n, 2, 4, 92, aniso=(0.2, 1.0))      # ярусы лап
    shadow = np.clip(-fnoise(n, 3, 8, 93) - 0.5, 0, None)
    v = v * (1.0 + 0.08 * tiers) - shadow * 0.12
    snow = np.clip(fnoise(n, 6, 14, 94) - 1.8, 0, None) * (tiers > 0.4)
    rgb = gray(v)
    rgb += snow[:, :, None] * np.array([0.5, 0.55, 0.65])[None, None, :]
    finish(rgb, "tex_needles.png", mean=0.56)


def metal():
    n = 128
    # Крашеный металл: облупившаяся краска, царапины, ржавые подтёки, точечные заклёпки по шву.
    paint = 1.0 + 0.04 * fbm(n, 101, base=2, octaves=4)
    chip = fbm(n, 102, base=3, octaves=4)
    chipped = chip > 1.9
    v = paint.copy()
    v[chipped] *= 0.85
    rng = np.random.default_rng(103)
    for _ in range(40):   # царапины
        x, y = rng.integers(0, n, 2)
        L = rng.integers(5, 16)
        for k in range(L):
            v[(y + k // 4) % n, (x + k) % n] *= 1.12
    streak = np.clip(fnoise(n, 1, 6, 104, aniso=(1.0, 0.1)) - 0.6, 0, None)
    rgb = gray(v)
    rgb[:, :, 0] += streak * 0.03 + chipped * 0.04
    rgb[:, :, 2] -= streak * 0.025 + chipped * 0.03
    yy, xx = np.mgrid[0:n, 0:n]
    seam = (yy % 64 == 0)
    rgb[seam] *= 0.7
    rivet = ((yy % 64) == 3) & ((xx % 16) == 8)
    rgb[rivet] *= 1.3
    finish(rgb, "tex_metal.png", mean=0.6)


def rust():
    n = 128
    base = fbm(n, 111, base=2, octaves=5)
    flakes = fnoise(n, 30, 64, 112)
    v = 1.0 + 0.1 * base + 0.06 * flakes
    rgb = tint(v, (1.15, 0.95, 0.8))
    finish(rgb, "tex_rust.png", mean=0.58)


def cloth():
    n = 128
    yy, xx = np.mgrid[0:n, 0:n]
    weave = (((xx // 2) + (yy // 2)) % 2) * 0.04 + ((xx % 2) * 0.02)
    v = 1.0 + weave + 0.05 * fbm(n, 121, base=2, octaves=4) + 0.03 * fnoise(n, 1, 3, 122, aniso=(0.2, 1.0))
    finish(gray(v), "tex_cloth.png", mean=0.64)


def fur():
    n = 128
    # Свалявшаяся шерсть/мех: пряди сверху вниз с изгибом.
    rng = np.random.default_rng(131)
    v = np.zeros((n, n)) + 0.8
    for _ in range(1500):
        x, y = rng.integers(0, n, 2)
        L = rng.integers(5, 12)
        b = rng.uniform(0.75, 1.25)
        sway = rng.uniform(-0.4, 0.4)
        for k in range(L):
            v[(y + k) % n, int(x + sway * k) % n] = b
    v += 0.1 * fbm(n, 132, base=2, octaves=3)
    finish(gray(v), "tex_fur.png", mean=0.6)


def skin():
    n = 128
    # Серая, будто обмороженная кожа: поры, сосуды, пятна.
    v = 1.0 + 0.07 * fbm(n, 141, base=2, octaves=5)
    rng = np.random.default_rng(142)
    pores = (rng.random((n, n)) > 0.97).astype(float)
    v -= pores * 0.08
    veins_n = fbm(n, 143, base=2, octaves=4)
    veins = np.exp(-(veins_n / 0.05) ** 2) * 0.12
    rgb = gray(v)
    rgb[:, :, 2] -= veins * 0.3
    rgb[:, :, 0] -= veins * 0.6
    rgb[:, :, 1] -= veins * 0.5
    finish(rgb, "tex_skin.png", mean=0.65)


def trail():
    n = 128
    # Натоптанная тропа (текстура в координатах полосы: ось Y картинки — вдоль тропы).
    # Края совпадают по яркости с целиной, к центру — утоптанный, чуть сероватый наст,
    # две колеи от валенок и редкие отпечатки.
    yy, xx = np.mgrid[0:n, 0:n].astype(float)
    u = (xx / n) - 0.5                      # -0.5..0.5 поперёк
    edge = np.clip(1.0 - np.abs(u) / 0.5, 0, 1) ** 0.7     # 0 на краю, 1 в центре
    wob = fnoise(n, 1, 3, 151, aniso=(0.2, 1.0)) * 0.03
    groove = np.exp(-((np.abs(u + wob) - 0.13) / 0.05) ** 2)
    base = 1.0 + 0.025 * fnoise(n, 30, 64, 152)
    v = base - 0.1 * edge - 0.08 * groove + 0.02 * fnoise(n, 3, 10, 153) * edge
    # отпечатки: овальные вмятины по колеям
    rng = np.random.default_rng(154)
    for i in range(14):
        side = -0.13 if i % 2 == 0 else 0.13
        cy = (i * n / 14 + rng.uniform(-2, 2)) % n
        cx = (side + 0.5) * n + rng.uniform(-3, 3)
        d = ((xx - cx) / 4.0) ** 2 + (((yy - cy + n / 2) % n - n / 2) / 8.0) ** 2
        v -= np.exp(-d * 2.0) * 0.07
    rgb = np.stack([v, v, v * 1.02], axis=2)
    rgb = np.roll(rgb, n // 2, axis=1)       # полоса центрируется на u=0 (так ложится на меш)
    # средняя ~ как у снега на краях: подгоняем так, чтобы края были ~0.70
    rgb = np.clip(rgb, 0, None)
    edge_mean = rgb[:, 0:3].mean()
    rgb *= 0.70 / edge_mean
    q = 31
    rgb = np.round(np.clip(rgb, 0, 1) * q) / q
    Image.fromarray((rgb * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, "tex_trail.png"))
    print("wrote tex_trail.png")


if __name__ == "__main__":
    only = set(sys.argv[1:])
    for fn in [trail, snow, plaster, stove, concrete, logs, planks, wood, bark, needles, metal, rust, cloth, fur, skin]:
        if not only or fn.__name__ in only:
            fn()
