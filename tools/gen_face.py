#!/usr/bin/env python3
"""Скример «лицо в упор» (assets/textures/face_flash.png): процедурно, 320×240, PS1-грязь.
Бледное вытянутое лицо, провалы глазниц с точками зрачков, рот шире лица, трещины, зерно, сдвиг каналов."""
import numpy as np
from PIL import Image, ImageFilter
import os

W, H = 320, 240
rng = np.random.default_rng(7)
yy, xx = np.mgrid[0:H, 0:W].astype(float)
cx, cy = W * 0.5, H * 0.52


def ell(x0, y0, rx, ry, soft=1.0, rot=0.0):
    c, s = np.cos(rot), np.sin(rot)
    dx, dy = xx - x0, yy - y0
    u = (dx * c + dy * s) / rx
    v = (-dx * s + dy * c) / ry
    d = np.sqrt(u * u + v * v)
    return np.clip((1.0 - d) / max(soft, 1e-3), 0, 1)


# Голова — вытянутый овал, сужение к подбородку
head = ell(cx, cy, 78, 112, 0.08)
chin_narrow = np.clip(1.0 - np.maximum(yy - cy - 30, 0) / 120.0, 0.55, 1.0)
head = ell(cx, cy, 78, 112, 0.08) * (np.abs(xx - cx) < 78 * chin_narrow)
# Объём: свет сверху-слева, впалые щёки
shade = 0.55 + 0.45 * np.clip(1.0 - ((xx - cx + 25) ** 2 / 90 ** 2 + (yy - cy + 45) ** 2 / 120 ** 2), 0, 1)
cheeks = ell(cx - 44, cy + 22, 22, 34, 1.0) + ell(cx + 44, cy + 22, 22, 34, 1.0)
skin = shade - 0.25 * cheeks
# Глазницы — глубокие, неровные, чуть разной высоты
sock_l = ell(cx - 30, cy - 18, 24, 18, 0.9, 0.15)
sock_r = ell(cx + 31, cy - 14, 23, 19, 0.9, -0.2)
skin = skin * (1 - 0.95 * np.clip(sock_l * 1.6, 0, 1)) * (1 - 0.95 * np.clip(sock_r * 1.6, 0, 1))
# Нос — две щели
skin *= 1 - 0.8 * (ell(cx - 6, cy + 20, 3, 6, 0.4) + ell(cx + 6, cy + 20, 3, 6, 0.4))
# Рот: шире лица, углы задраны вверх
mouth_curve = cy + 58 - 0.0045 * (xx - cx) ** 2
mouth = (np.abs(yy - mouth_curve) < (9 - np.abs(xx - cx) * 0.07)) & (np.abs(xx - cx) < 72)
skin[mouth] *= 0.03
# Зубы — узкие светлые штрихи по верхнему краю рта
for tx in range(int(cx - 60), int(cx + 60), 7):
    top = int(cy + 58 - 0.0045 * (tx - cx) ** 2 - (9 - abs(tx - cx) * 0.07))
    L = int(rng.integers(4, 9))
    for k in range(L):
        y = top + k
        if 0 <= y < H:
            skin[y, tx:tx + 3] = 0.75 - k * 0.05
# Трещины/сосуды
for _ in range(26):
    x, y = cx + rng.normal(0, 40), cy + rng.normal(0, 60)
    a = rng.uniform(0, np.pi * 2)
    for k in range(int(rng.integers(10, 35))):
        xi, yi = int(x), int(y)
        if 0 <= xi < W and 0 <= yi < H:
            skin[yi, xi] *= 0.55
        a += rng.uniform(-0.5, 0.5)
        x += np.cos(a)
        y += np.sin(a)
face = skin * head
# Зрачки — точки, смотрят прямо
for px, py in [(cx - 29, cy - 16), (cx + 31, cy - 12)]:
    face += ell(px, py, 2.6, 2.6, 0.5) * 1.4
# Цвет: серо-зелёная кожа, красноватые глазницы
r = face * 0.86 + (sock_l + sock_r) * head * 0.12
g = face * 0.90
b = face * 0.80
img = np.stack([r, g, b], axis=2)
# Виньетка, зерно, строки, постеризация
vig = np.clip(1.15 - np.sqrt(((xx - cx) / W) ** 2 + ((yy - cy) / H) ** 2) * 1.6, 0, 1)
img *= vig[:, :, None]
img += rng.normal(0, 0.05, img.shape)
img *= (1.0 - 0.18 * (yy.astype(int) % 2 == 0))[:, :, None]
img = np.clip(img, 0, 1)
q = 14
img = np.round(img * q) / q
# Сдвиг красного канала — «плёнка рвётся»
img[:, :, 0] = np.roll(img[:, :, 0], 2, axis=1)
out = Image.fromarray((img * 255).astype(np.uint8), "RGB")
dst = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "face_flash.png")
out.save(dst)
print("wrote", dst)
