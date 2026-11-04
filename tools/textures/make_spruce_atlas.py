# «Кедр-7» — атлас ели 2×2 (PIL): раскладка та же, что ждёт SpruceMesh.near():
#   [0,0] лапа хвои: основание слева, кончик справа (u 0..0.5), ширина — по v 0..0.5, стебель по v=0.25
#   [1,0] снежная шапка: u 0.5..1 вдоль лапы, v 0..0.5 поперёк (середина — гребень)
#   [0,1] кора: вертикальные чешуйчатые пластины, лишайник
#   [1,1] лапа заиндевевшая (светлые ветки): кончики хвоинок в инее
# Рисуем 2048 и уменьшаем до 1024 — тонкие хвоинки остаются мягкими. Запуск: python make_spruce_atlas.py <png>
import math, random, sys
from PIL import Image, ImageDraw, ImageFilter, ImageChops

OUT = sys.argv[1] if len(sys.argv) > 1 else "spruce_atlas.png"
C = 1024                      # клетка при рисовании
img = Image.new("RGBA", (C * 2, C * 2), (0, 0, 0, 0))


def lerp(a, b, t):
    return a + (b - a) * t


def mixc(c1, c2, t):
    return tuple(int(lerp(c1[i], c2[i], t)) for i in range(len(c1)))


def frond(frost=False, seed=1):
    """Лапа ели: стебель, веточки второго порядка вперёд-вбок, на них хвоинки щёткой.
    Три прохода: тёмная глубина, средний слой, светлые молодые кончики (у ели — сизые)."""
    rnd = random.Random(seed)
    cell = Image.new("RGBA", (C, C), (0, 0, 0, 0))
    d = ImageDraw.Draw(cell)
    cy = C * 0.5
    x0, x1 = C * 0.02, C * 0.985
    width = lambda t: C * 0.47 * (math.sin(math.pi * min(1.0, 0.12 + t * 0.95)) ** 0.8) * (1.0 - 0.25 * t)
    stem = [(lerp(x0, x1, k / 40), cy + math.sin(k * 0.3) * 3) for k in range(41)]
    dark, mid, lite = (12, 28, 21), (26, 54, 40), (58, 92, 72)
    tip_col = (112, 142, 130) if not frost else (196, 208, 220)
    # Подложка: плотный тёмный силуэт лапы — хвоя не просвечивает «скелетом»
    sil = Image.new("L", (C, C), 0)
    sdr = ImageDraw.Draw(sil)
    for i in range(90):
        t = i / 90
        x = lerp(x0, x1, t)
        w = width(t) * 0.5 * min(1.0, t * 4.0)
        sdr.ellipse([x - C * 0.03, cy - w, x + C * 0.03, cy + w], fill=255)
    sil = sil.filter(ImageFilter.GaussianBlur(14)).point(lambda v: 255 if v > 150 else 0)
    under = Image.new("RGBA", (C, C), (18, 40, 30, 255))
    cell.paste(under, (0, 0), sil)
    for layer, (col, w_k, needle_l) in enumerate([(dark, 1.0, 0.034), (mid, 0.95, 0.03), (lite, 0.82, 0.026)]):
        n_tw = 60 + layer * 12
        for i in range(n_tw):
            t = (i + rnd.random() * 0.8) / n_tw
            if t > 0.97:
                continue
            bx, by = lerp(x0, x1, t), cy
            for sgn in (-1, 1):
                if rnd.random() < 0.06:
                    continue
                L = width(t) * w_k * rnd.uniform(0.8, 1.08) / 0.75
                a = math.radians(rnd.uniform(48, 68)) * sgn
                pts = []
                for k in range(13):
                    s_ = k / 12
                    ang = a * (1.0 - s_ * 0.3)
                    pts.append((bx + math.cos(ang) * L * s_ * 0.9, by + math.sin(ang) * L * s_ * 0.85))
                d.line(pts, fill=col + (255,), width=max(3, int(C * 0.006)))
                for k in range(1, len(pts)):
                    px, py = pts[k]
                    s_ = k / 12
                    nl = C * needle_l * (1.0 - s_ * 0.4) * rnd.uniform(0.8, 1.2)
                    for side in (-1, 1):
                        na = a + math.radians(rnd.uniform(30, 60)) * side
                        ex, ey = px + math.cos(na) * nl, py + math.sin(na) * nl
                        nc = mixc(col, tip_col, s_ * (0.7 if layer == 2 else 0.3)) if layer > 0 else col
                        d.line([(px, py), (ex, ey)], fill=nc + (255,), width=max(3, int(C * 0.0055)))
                        if frost and layer == 2 and s_ > 0.6 and rnd.random() < 0.18:
                            r = C * 0.0035
                            d.ellipse([ex - r, ey - r, ex + r, ey + r], fill=(220, 228, 238, 255))
    # стебель поверх
    d.line(stem, fill=(48, 36, 26, 255), width=int(C * 0.009))
    d.line(stem[:30], fill=(66, 50, 36, 255), width=int(C * 0.004))
    # мягкая тень к основанию (внутрь кроны)
    shade = Image.new("L", (C, C), 0)
    sd = ImageDraw.Draw(shade)
    for k in range(60):
        x = C * 0.3 * (1 - k / 60)
        sd.line([(x, 0), (x, C)], fill=int(70 * (1 - k / 60)), width=int(C * 0.3 / 60) + 1)
    r, g, b, a = cell.split()
    sh = shade.filter(ImageFilter.GaussianBlur(20))
    r, g, b = [ImageChops.subtract(ch, sh.point(lambda v: v // 3)) for ch in (r, g, b)]
    return Image.merge("RGBA", [r, g, b, a])


def snow_cap(seed=5):
    """Снежная шапка: комковатая масса, гребень посередине (v=0.5 клетки), края темнее и рваные,
    наст блестит; к кончику (справа) сходит на нет."""
    rnd = random.Random(seed)
    cell = Image.new("RGBA", (C, C), (0, 0, 0, 0))
    mask = Image.new("L", (C, C), 0)
    md = ImageDraw.Draw(mask)
    core = []
    for k in range(41):
        t = k / 40
        core.append((C * (0.02 + t * 0.92), C * 0.5 - C * 0.36 * (1.0 - t ** 2.0 * 0.7)))
    for k in range(40, -1, -1):
        t = k / 40
        core.append((C * (0.02 + t * 0.92), C * 0.5 + C * 0.36 * (1.0 - t ** 2.0 * 0.7)))
    md.polygon(core, fill=255)
    for i in range(240):
        t = rnd.random()
        x = C * (0.03 + t * 0.9)
        half = C * 0.36 * (1.0 - t ** 2.0 * 0.7)
        y = C * 0.5 + rnd.choice((-1, 1)) * half * rnd.uniform(0.85, 1.12)
        r = C * rnd.uniform(0.02, 0.055) * (1.0 - t * 0.5)
        md.ellipse([x - r, y - r, x + r, y + r], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(4)).point(lambda v: 255 if v > 120 else 0)
    # объём: светлый гребень, к краям темнее (синева тени), снизу по краю — подтаявший голубоватый
    shade = Image.new("L", (C, C), 0)
    sd = ImageDraw.Draw(shade)
    for k in range(C):
        v = abs(k - C * 0.5) / (C * 0.5)
        sd.line([(0, k), (C, k)], fill=int(255 * (1.0 - v ** 1.6)))
    lumps = Image.new("L", (C, C), 0)
    ld = ImageDraw.Draw(lumps)
    for i in range(500):
        x, y = rnd.uniform(0, C), rnd.uniform(0, C)
        r = rnd.uniform(6, 30)
        ld.ellipse([x - r, y - r, x + r, y + r], fill=rnd.randint(30, 90))
    lumps = lumps.filter(ImageFilter.GaussianBlur(8))
    lit = ImageChops.add(shade.point(lambda v: v * 3 // 4), lumps)
    hi = (246, 249, 255)
    lo = (150, 170, 205)
    px_r = lit.point(lambda v: int(lerp(lo[0], hi[0], min(v, 255) / 255)))
    px_g = lit.point(lambda v: int(lerp(lo[1], hi[1], min(v, 255) / 255)))
    px_b = lit.point(lambda v: int(lerp(lo[2], hi[2], min(v, 255) / 255)))
    # кромка: тонкая тёмно-голубая обводка — шапка читается на тёмной хвое
    edge = ImageChops.subtract(mask, mask.filter(ImageFilter.MinFilter(5))).filter(ImageFilter.GaussianBlur(2)).point(lambda v: v // 2)
    px_r = ImageChops.subtract(px_r, edge.point(lambda v: v // 3))
    px_g = ImageChops.subtract(px_g, edge.point(lambda v: v // 4))
    # искры наста
    sp = ImageDraw.Draw(px_r), ImageDraw.Draw(px_g), ImageDraw.Draw(px_b)
    for i in range(180):
        x, y = rnd.uniform(0, C), rnd.uniform(C * 0.2, C * 0.8)
        for ch in sp:
            ch.point((x, y), fill=255)
    cell = Image.merge("RGBA", [px_r, px_g, px_b, mask])
    return cell


def bark(seed=9):
    rnd = random.Random(seed)
    cell = Image.new("RGBA", (C, C), (52, 38, 28, 255))
    d = ImageDraw.Draw(cell)
    # чешуйчатые пластины: вытянутые по вертикали, с тёмными бороздами между
    for i in range(900):
        x, y = rnd.uniform(0, C), rnd.uniform(0, C)
        w, h = rnd.uniform(14, 40), rnd.uniform(40, 120)
        c = rnd.randint(-14, 16)
        d.ellipse([x - w, y - h, x + w, y + h], fill=(62 + c, 46 + c, 34 + c, 255))
    for i in range(260):
        x = rnd.uniform(0, C)
        y0 = rnd.uniform(0, C)
        d.line([(x, y0), (x + rnd.uniform(-8, 8), y0 + rnd.uniform(60, 200))], fill=(22, 16, 12, 255), width=rnd.randint(2, 5))
    # лишайник — редкие неровные серо-зелёные пятна в бороздах
    for i in range(22):
        x, y = rnd.uniform(0, C), rnd.uniform(0, C)
        for j in range(9):
            r = rnd.uniform(4, 13)
            ox, oy = x + rnd.uniform(-20, 20), y + rnd.uniform(-26, 26)
            d.ellipse([ox - r, oy - r * 0.7, ox + r, oy + r * 0.7], fill=(78, 86, 70, 255))
    return cell.filter(ImageFilter.GaussianBlur(1.2))


img.paste(frond(False, 1), (0, 0))
img.paste(snow_cap(5), (C, 0))
img.paste(bark(9), (0, C))
img.paste(frond(True, 2), (C, C))
img.resize((1024, 1024), Image.LANCZOS).save(OUT)
print("saved", OUT)
