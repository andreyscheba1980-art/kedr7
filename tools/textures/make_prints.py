# «Кедр-7» — текстуры отпечатков (PIL): ладони на стекле и трещины во льду.
#   hand_glass.png  — ладонь, прижатая к стеклу снаружи, видна сквозь иней: мягкая, подушечки светлее
#   hand_thaw.png   — оттаявший в инее отпечаток: прозрачная пятерня, инеистая кайма, подтёки вниз
#   hand_dirt.png   — тёмная грязная пятерня (сажа/кровь не нужна — просто грязь на стекле)
#   ice_cracks.png  — трещины во льду: R — яркость линии, G — «когда» появляется (от центра наружу)
# Пальцы длинные (long=1.35): это не совсем человек. Запуск: python make_prints.py <out_dir>
import math, random, sys, os
from PIL import Image, ImageDraw, ImageFilter, ImageChops

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(OUT, exist_ok=True)
S = 1024                 # рисуем крупно, потом уменьшаем — края мягкие


def hand_mask(long=1.35, spread=1.0, seed=3):
    """Маска пятерни: ладонь — многоугольник, пальцы — сужающиеся капсулы по фалангам, большой палец вбок."""
    rnd = random.Random(seed)
    m = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(m)
    cx, cy = S * 0.5, S * 0.66
    pw, ph = S * 0.25, S * 0.27
    palm = [(cx - pw * 0.52, cy - ph * 0.45), (cx - pw * 0.2, cy - ph * 0.55), (cx + pw * 0.25, cy - ph * 0.55), (cx + pw * 0.55, cy - ph * 0.4),
            (cx + pw * 0.6, cy + ph * 0.1), (cx + pw * 0.45, cy + ph * 0.48), (cx, cy + ph * 0.6), (cx - pw * 0.45, cy + ph * 0.5), (cx - pw * 0.6, cy + ph * 0.05)]
    d.polygon(palm, fill=255)
    # Пальцы: указательный..мизинец слева направо; угол веером, три фаланги с лёгким изгибом
    base = [(-0.38, 0.92, -14), (-0.12, 1.06, -4), (0.14, 1.0, 5), (0.38, 0.78, 15)]
    for bx, ln, ang in base:
        x, y = cx + bx * pw, cy - ph * 0.48
        a = math.radians(ang * spread - 90 + rnd.uniform(-2, 2))
        L = S * 0.2 * ln * long
        w0 = S * 0.034 * (1.0 if ln > 0.85 else 0.85)
        for k, fr in enumerate((0.42, 0.32, 0.26)):
            l = L * fr
            w = w0 * (1.0 - k * 0.12)
            x2, y2 = x + math.cos(a) * l, y + math.sin(a) * l
            d.line([(x, y), (x2, y2)], fill=255, width=int(w * 2))
            d.ellipse([x2 - w, y2 - w, x2 + w, y2 + w], fill=255)
            x, y = x2, y2
            a += math.radians(rnd.uniform(-3, 3) + 2.0 * (bx))
    # Большой палец: от основания ладони вбок и вверх
    x, y = cx + pw * 0.55, cy + ph * 0.05
    a = math.radians(-58)
    for k, (fr, w) in enumerate(((0.1, 0.042), (0.085, 0.035))):
        l = S * fr * long
        x2, y2 = x + math.cos(a) * l, y + math.sin(a) * l
        d.line([(x, y), (x2, y2)], fill=255, width=int(S * w * 2))
        d.ellipse([x2 - S * w, y2 - S * w, x2 + S * w, y2 + S * w], fill=255)
        x, y = x2, y2
        a += math.radians(-12)
    # скруглить углы ладони: размыть и снова обрезать по порогу
    return m.filter(ImageFilter.GaussianBlur(S * 0.012)).point(lambda v: 255 if v > 120 else 0)


def pads(long=1.35, seed=3):
    """Места сильного прижатия: подушечки пальцев и бугры ладони — пятна светлее/плотнее."""
    p = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(p)
    cx, cy = S * 0.5, S * 0.66
    pw, ph = S * 0.25, S * 0.27
    for bx, ln, ang in [(-0.38, 0.92, -11), (-0.12, 1.06, -3), (0.14, 1.0, 4), (0.38, 0.78, 12)]:
        a = math.radians(ang - 90)
        L = S * 0.2 * ln * long
        tx, ty = cx + bx * pw + math.cos(a) * L * 0.9, cy - ph * 0.48 + math.sin(a) * L * 0.9
        r = S * 0.03
        d.ellipse([tx - r, ty - r * 1.3, tx + r, ty + r * 1.3], fill=255)
    for ox, oy, r in [(-0.3, 0.25, 0.08), (0.3, 0.25, 0.07), (0.0, -0.3, 0.1), (0.35, -0.05, 0.06)]:
        x, y = cx + ox * pw, cy + oy * ph
        d.ellipse([x - S * r, y - S * r * 0.8, x + S * r, y + S * r * 0.8], fill=255)
    return p.filter(ImageFilter.GaussianBlur(S * 0.02))


def noise_img(scale, seed):
    rnd = random.Random(seed)
    small = Image.new("L", (scale, scale))
    small.putdata([rnd.randint(0, 255) for _ in range(scale * scale)])
    return small.resize((S, S), Image.BICUBIC).filter(ImageFilter.GaussianBlur(S / scale * 0.6))


def save(img, name, size=512):
    img.resize((size, size), Image.LANCZOS).save(os.path.join(OUT, name))
    print("saved", name)


m = hand_mask()
pd = pads()
n1 = noise_img(48, 1)
n2 = noise_img(160, 2)

# 1. Ладонь за инеем: бледная, расплывчатая к краям; подушечки плотнее; иней «съедает» край пятнами
soft = m.filter(ImageFilter.GaussianBlur(S * 0.012))
edge_bite = ImageChops.multiply(soft, n1.point(lambda v: 150 + v * 105 // 255))
alpha = ImageChops.lighter(ImageChops.multiply(edge_bite, Image.new("L", (S, S), 205)), ImageChops.multiply(pd, m).point(lambda v: v * 225 // 255))
col = Image.merge("RGB", [Image.new("L", (S, S), 150), Image.new("L", (S, S), 160), Image.new("L", (S, S), 172)])
bright = ImageChops.multiply(pd.filter(ImageFilter.GaussianBlur(S * 0.02)), Image.new("L", (S, S), 28))
col = ImageChops.add(col, Image.merge("RGB", [bright, bright, bright]))
img = col.copy()
img.putalpha(alpha)
save(img, "hand_glass.png")

# 2. Оттаявший отпечаток в инее: внутри — прозрачное «окно» (тёмная ночь за стеклом), по краю — светлая
#    инеистая кайма, снизу — подтёки талой воды
rim = ImageChops.subtract(m.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(6)), m.filter(ImageFilter.GaussianBlur(3)))
drips = Image.new("L", (S, S), 0)
dd = ImageDraw.Draw(drips)
rnd = random.Random(9)
for k in range(9):
    x = S * (0.37 + rnd.random() * 0.27)
    y0 = S * (0.8 + rnd.random() * 0.05)
    ln = S * (0.03 + rnd.random() ** 2 * 0.2)
    w = S * (0.004 + rnd.random() * 0.004)
    steps = 12
    for j in range(steps):
        t0, t1 = j / steps, (j + 1) / steps
        ww = w * (1.0 - t0 * 0.6)
        dd.line([(x + math.sin(t0 * 3 + k) * 3, y0 + ln * t0), (x + math.sin(t1 * 3 + k) * 3, y0 + ln * t1)], fill=int(210 - t0 * 60), width=max(2, int(ww * 2)))
    dd.ellipse([x - w * 1.3, y0 + ln - w * 1.3, x + w * 1.3, y0 + ln + w * 1.3], fill=170)
inside = ImageChops.lighter(m.filter(ImageFilter.GaussianBlur(4)), drips.filter(ImageFilter.GaussianBlur(2)))
a_in = inside.point(lambda v: v * 150 // 255)
a_rim = rim.point(lambda v: min(255, v * 3))
alpha = ImageChops.lighter(a_in, a_rim)
alpha = ImageChops.multiply(alpha, n1.point(lambda v: 170 + v * 85 // 255))
r = ImageChops.add(Image.new("L", (S, S), 30), a_rim.point(lambda v: v * 200 // 255))
g = ImageChops.add(Image.new("L", (S, S), 38), a_rim.point(lambda v: v * 205 // 255))
b = ImageChops.add(Image.new("L", (S, S), 50), a_rim.point(lambda v: v * 200 // 255))
img = Image.merge("RGBA", [r, g, b, alpha])
save(img, "hand_thaw.png")

# 3. Грязная тёмная пятерня (на стекле кабины в метеокорпусе): пальцы смазаны вниз
smear = m.copy()
for k in range(1, 6):
    smear = ImageChops.lighter(smear, ImageChops.offset(m, 0, k * 10).point(lambda v, k=k: v * (6 - k) // 7))
smear = smear.filter(ImageFilter.GaussianBlur(5))
alpha = ImageChops.multiply(smear, n1.point(lambda v: 120 + v * 135 // 255))
alpha = ImageChops.lighter(alpha.point(lambda v: v * 200 // 255), ImageChops.multiply(pd, m).point(lambda v: v * 230 // 255))
img = Image.merge("RGBA", [Image.new("L", (S, S), 22), Image.new("L", (S, S), 20), Image.new("L", (S, S), 18), alpha])
save(img, "hand_dirt.png")

# 4. Трещины во льду: от центра лучами, ветвятся; G — расстояние от центра (для «растут» в шейдере)
W = 1024
cr = Image.new("L", (W, W), 0)
tm = Image.new("L", (W, W), 255)
dc, dt = ImageDraw.Draw(cr), ImageDraw.Draw(tm)
rnd = random.Random(41)


def branch(x, y, a, length, width, t0, depth):
    seg = 14
    for _ in range(int(length / seg)):
        a += rnd.uniform(-0.35, 0.35)
        x2, y2 = x + math.cos(a) * seg, y + math.sin(a) * seg
        t = min(255, int(t0))
        dc.line([(x, y), (x2, y2)], fill=255, width=max(1, int(width)))
        dt.line([(x, y), (x2, y2)], fill=t, width=max(3, int(width) + 4))
        x, y = x2, y2
        t0 += seg * 0.42
        width *= 0.985
        if depth < 3 and rnd.random() < 0.07:
            branch(x, y, a + rnd.choice((-1, 1)) * rnd.uniform(0.5, 1.1), length * 0.45, width * 0.7, t0, depth + 1)


for k in range(13):
    a = k * 2 * math.pi / 13 + rnd.uniform(-0.2, 0.2)
    branch(W / 2, W / 2, a, W * rnd.uniform(0.32, 0.47), 5.0, rnd.uniform(0, 30), 0)
# кольцевые трещины — как на настоящей наледи
for rr in (W * 0.12, W * 0.24, W * 0.36):
    pts = []
    for k in range(60):
        a = k * 2 * math.pi / 60
        if rnd.random() < 0.35:
            if len(pts) > 1:
                dc.line(pts, fill=200, width=2)
                dt.line(pts, fill=min(255, int(rr * 0.42 + 40)), width=5)
            pts = []
            continue
        q = rr * rnd.uniform(0.92, 1.08)
        pts.append((W / 2 + math.cos(a) * q, W / 2 + math.sin(a) * q))
    if len(pts) > 1:
        dc.line(pts, fill=200, width=2)
        dt.line(pts, fill=min(255, int(rr * 0.42 + 40)), width=5)
glow = cr.filter(ImageFilter.GaussianBlur(3))
lines = ImageChops.lighter(cr, glow.point(lambda v: v * 3 // 4))
img = Image.merge("RGBA", [lines, tm, Image.new("L", (W, W), 0), lines])
img.resize((512, 512), Image.LANCZOS).save(os.path.join(OUT, "ice_cracks.png"))
print("saved ice_cracks.png")
