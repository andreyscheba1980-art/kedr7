"""
Bakes high-resolution, authentic vintage Soviet photographs (Svema-64 film on Unibrom paper)
for Kedr-7:
  1. photo_archive_mast.png (Radio mast at dusk with shadow creature on guy wire)
  2. photo_archive_adit.png (Adit #4 entrance with mine cart and emerging shadow)
  3. photo_archive_porch.png (Cabin porch in blizzard with pale hand in door slit and face on glass)
  4. photo_archive_crew.png (Crew portrait 1982 with the 4th uninvited figure behind Semyonov)
  5. photo_archive_paradox.png (Chronological paradox: darkroom from behind the player)
"""
import os, math, random
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 384, 216

def create_base_canvas():
    return Image.new("RGB", (W, H), (15, 15, 16))

def add_film_grain(img, intensity=18):
    pixels = img.load()
    w, h = img.size
    rng = random.Random(42)
    for y in range(h):
        for x in range(w):
            r, g, b = pixels[x, y]
            noise = int((rng.random() - 0.5) * intensity)
            r = max(0, min(255, r + noise))
            g = max(0, min(255, g + noise))
            b = max(0, min(255, b + noise))
            pixels[x, y] = (r, g, b)
    return img

def apply_vignette_and_sepia(img, strength=0.35, sepia_tone=(1.02, 0.98, 0.90)):
    pixels = img.load()
    w, h = img.size
    cx, cy = w / 2.0, h / 2.0
    max_d = math.sqrt(cx*cx + cy*cy)
    for y in range(h):
        for x in range(w):
            dx, dy = x - cx, y - cy
            d = math.sqrt(dx*dx + dy*dy) / max_d
            vig = 1.0 - (d * d * strength)
            r, g, b = pixels[x, y]
            lum = (0.299 * r + 0.587 * g + 0.114 * b) * vig
            nr = int(max(0, min(255, lum * sepia_tone[0])))
            ng = int(max(0, min(255, lum * sepia_tone[1])))
            nb = int(max(0, min(255, lum * sepia_tone[2])))
            pixels[x, y] = (nr, ng, nb)
    return img

def add_photo_paper_border(img, border_size=8, stamp_text=""):
    w, h = img.size
    out = Image.new("RGB", (w + border_size*2, h + border_size*2 + 6), (235, 230, 218))
    # Slight aged paper texture
    draw = ImageDraw.Draw(out)
    rng = random.Random(1983)
    p_pix = out.load()
    for y in range(out.size[1]):
        for x in range(out.size[0]):
            n = int((rng.random() - 0.5) * 8)
            r, g, b = p_pix[x, y]
            p_pix[x, y] = (max(0, min(255, r + n)), max(0, min(255, g + n)), max(0, min(255, b + n)))
    out.paste(img, (border_size, border_size))
    # Thin black photo outline
    draw.rectangle([border_size - 1, border_size - 1, border_size + w, border_size + h], outline=(60, 55, 50))
    # Rescale back to exact W, H
    return out.resize((W, H), Image.LANCZOS)

def draw_star(draw, x, y, r, color):
    draw.ellipse([x - r, y - r, x + r, y + r], fill=color)

# -------------------------------------------------------------
# 1. PHOTO ARCHIVE: MAST (Метеомачта АШ-4 на закате)
# -------------------------------------------------------------
def bake_mast_photo():
    img = create_base_canvas()
    draw = ImageDraw.Draw(img)
    # Sky gradient: cold northern dusk
    for y in range(H):
        t = y / float(H)
        c = int(22 + (1.0 - t) * 75)
        draw.line([(0, y), (W, y)], fill=(c + 5, c + 2, c))

    # Horizon taiga (dark tree silhouettes)
    tree_y = 135
    for x in range(W):
        h_tree = int(math.sin(x * 0.08) * 8 + math.sin(x * 0.25) * 4 + 18)
        draw.line([(x, tree_y - h_tree), (x, H)], fill=(20, 21, 23))

    # Distant snow hills & foreground drifts
    for y in range(130, H):
        for x in range(W):
            drift_wave = math.sin(x * 0.03 + y * 0.05) * 12 + math.sin(x * 0.09) * 4
            if y > 140 + drift_wave:
                snow_val = int(70 + (y - 140) * 0.8 + math.sin(x * 0.1) * 8)
                snow_val = min(170, max(45, snow_val))
                draw.point((x, y), fill=(snow_val, snow_val, snow_val - 4))

    # Instrument shelter (Метеобудка Селянинова на ножках)
    bx, by = 90, 138
    # 4 wooden legs
    for lx in [-16, -6, 6, 16]:
        draw.line([(bx + lx, by), (bx + lx, by + 28)], fill=(35, 33, 30), width=2)
    # Louvered box
    draw.rectangle([bx - 18, by - 24, bx + 18, by], fill=(120, 118, 112), outline=(40, 38, 35))
    for sl in range(by - 22, by - 2, 4):
        draw.line([(bx - 16, sl), (bx + 16, sl)], fill=(45, 42, 38), width=1)
    # Roof slope
    draw.polygon([(bx - 22, by - 24), (bx + 22, by - 24), (bx, by - 32)], fill=(140, 138, 130), outline=(40, 38, 35))

    # Lattice Mast (АШ-4)
    mx = 220
    # Main uprights
    draw.line([(mx - 6, 20), (mx - 10, 160)], fill=(30, 28, 26), width=2)
    draw.line([(mx + 6, 20), (mx + 10, 160)], fill=(30, 28, 26), width=2)
    draw.line([(mx, 10), (mx, 160)], fill=(40, 38, 35), width=1)
    # Cross struts and diagonals
    for my in range(24, 155, 12):
        draw.line([(mx - 8, my), (mx + 8, my)], fill=(35, 33, 30), width=1)
        draw.line([(mx - 8, my), (mx + 8, my + 12)], fill=(30, 28, 26), width=1)
        draw.line([(mx + 8, my), (mx - 8, my + 12)], fill=(30, 28, 26), width=1)

    # Guy wires (растяжки)
    for gy in [40, 85, 130]:
        draw.line([(mx - 8, gy), (0, gy + 85)], fill=(42, 40, 38), width=1)
        draw.line([(mx + 8, gy), (W, gy + 85)], fill=(42, 40, 38), width=1)

    # CREATURE ON THE GUY WIRE (at 12m height, gy=85 on right wire)
    # Jointed spindly shadow clinging to the wire
    cx, cy = mx + 55, 85 + 26
    # Body curving along the cable
    draw.line([(cx - 10, cy - 8), (cx + 8, cy + 4)], fill=(15, 14, 15), width=4)
    # Bent limb joints gripping the cable
    draw.line([(cx - 6, cy - 4), (cx - 14, cy - 12), (cx - 10, cy - 8)], fill=(12, 11, 12), width=2)
    draw.line([(cx + 4, cy + 2), (cx + 12, cy - 6), (cx + 16, cy + 8)], fill=(12, 11, 12), width=2)
    # Elongated neck and angled head staring directly toward viewer
    draw.line([(cx - 4, cy), (cx - 2, cy + 10)], fill=(10, 10, 10), width=3)
    draw.ellipse([cx - 5, cy + 9, cx + 1, cy + 15], fill=(8, 8, 8))
    # TAPETUM LUCIDUM: Piercing pinpoint white reflective eyes
    draw.point((cx - 3, cy + 12), fill=(255, 255, 240))
    draw.point((cx - 1, cy + 12), fill=(255, 255, 240))
    # Faint aura around eyes
    draw.ellipse([cx - 4, cy + 11, cx, cy + 13], outline=(200, 210, 220))

    # Blizzard flakes and wind streaks
    rng = random.Random(77)
    for _ in range(120):
        fx = rng.randint(0, W - 1)
        fy = rng.randint(0, H - 1)
        flen = rng.randint(3, 8)
        draw.line([(fx, fy), (fx - flen, fy + flen // 2)], fill=(210, 215, 220, 180), width=1)

    img = add_film_grain(img, 14)
    img = apply_vignette_and_sepia(img, strength=0.4)
    return add_photo_paper_border(img)

# -------------------------------------------------------------
# 2. PHOTO ARCHIVE: ADIT 4 (Штольня №4 и вагонетка)
# -------------------------------------------------------------
def bake_adit_photo():
    img = create_base_canvas()
    draw = ImageDraw.Draw(img)

    # Rock face background
    for y in range(H):
        for x in range(W):
            rock = int(25 + math.sin(x * 0.1) * 8 + math.cos(y * 0.15) * 10 + (x + y) * 0.1)
            rock = max(10, min(80, rock))
            draw.point((x, y), fill=(rock, rock, rock + 2))

    # Adit Portal Timber Frame (Вход в штольню)
    px, py = 150, 45
    pw, ph = 84, 120
    # Pitch black adit mouth
    draw.rectangle([px, py, px + pw, py + ph], fill=(3, 3, 4))
    # Massive timber beams (Оклад штольни)
    draw.rectangle([px - 14, py - 12, px, py + ph], fill=(42, 35, 28), outline=(15, 12, 10))
    draw.rectangle([px + pw, py - 12, px + pw + 14, py + ph], fill=(42, 35, 28), outline=(15, 12, 10))
    draw.rectangle([px - 16, py - 16, px + pw + 16, py], fill=(48, 40, 32), outline=(15, 12, 10))

    # Giant icicles hanging from timber lintel
    rng = random.Random(104)
    for ix in range(px - 10, px + pw + 10, 6):
        ilen = rng.randint(12, 38)
        draw.polygon([(ix, py), (ix + 4, py), (ix + 2, py + ilen)], fill=(180, 195, 205))

    # Snowbank and rail tracks in foreground
    for y in range(145, H):
        for x in range(W):
            s_val = int(75 + (y - 145) * 1.5 + math.sin(x * 0.05) * 15)
            s_val = max(50, min(210, s_val))
            draw.point((x, y), fill=(s_val, s_val, s_val - 2))

    # Narrow gauge rails (Узкоколейка)
    draw.line([(px + 15, py + ph), (70, H)], fill=(30, 26, 24), width=3)
    draw.line([(px + 55, py + ph), (180, H)], fill=(30, 26, 24), width=3)
    # Wooden sleepers (шпалы)
    for sy in range(py + ph, H, 14):
        t_pos = (sy - (py + ph)) / float(H - (py + ph))
        x1 = int((px + 15) * (1.0 - t_pos) + 70 * t_pos) - 10
        x2 = int((px + 55) * (1.0 - t_pos) + 180 * t_pos) + 10
        draw.line([(x1, sy), (x2, sy)], fill=(35, 30, 25), width=2)

    # Overturned mine cart UVO-0.6 (Опрокинутая вагонетка)
    cx, cy = 270, 160
    draw.polygon([(cx, cy), (cx + 55, cy - 15), (cx + 65, cy + 20), (cx + 10, cy + 35)], fill=(38, 36, 38), outline=(15, 15, 16))
    # Cast wheel sticking out in snow
    draw.ellipse([cx + 38, cy + 18, cx + 58, cy + 38], fill=(25, 24, 25), outline=(10, 10, 12))
    draw.ellipse([cx + 44, cy + 24, cx + 52, cy + 32], fill=(60, 58, 55))

    # HORROR ANOMALY IN THE ADIT:
    # A human figure in padded coat stands turned away in the black mouth
    hx, hy = px + 36, py + 38
    # Head and shoulders
    draw.ellipse([hx - 7, hy, hx + 7, hy + 14], fill=(18, 17, 18))
    draw.rectangle([hx - 14, hy + 14, hx + 14, hy + 58], fill=(14, 13, 14))
    # But from behind it, towering long limbs with fingers stretch out onto the rock wall
    draw.line([(hx - 12, hy + 22), (hx - 36, hy - 8), (hx - 48, hy + 15)], fill=(8, 7, 8), width=3)
    draw.line([(hx + 12, hy + 22), (hx + 38, hy - 14), (hx + 50, hy + 6)], fill=(8, 7, 8), width=3)
    # Long spindly claws
    for f in [-6, 0, 6]:
        draw.line([(hx - 48, hy + 15), (hx - 58, hy + 18 + f)], fill=(6, 6, 7), width=1)
        draw.line([(hx + 50, hy + 6), (hx + 62, hy + 8 + f)], fill=(6, 6, 7), width=1)

    img = add_film_grain(img, 15)
    img = apply_vignette_and_sepia(img, strength=0.45)
    return add_photo_paper_border(img)

# -------------------------------------------------------------
# 3. PHOTO ARCHIVE: PORCH (Крыльцо станции в буран)
# -------------------------------------------------------------
def bake_porch_photo():
    img = create_base_canvas()
    draw = ImageDraw.Draw(img)

    # Night blizzard background
    for y in range(H):
        draw.line([(0, y), (W, y)], fill=(12, 14, 16))

    # Log cabin wall on the right (Бревенчатый сруб)
    wall_x = 130
    for ly in range(0, H, 22):
        # Log highlight and shadow
        draw.rectangle([wall_x, ly, W, ly + 20], fill=(42, 34, 26), outline=(20, 16, 12))
        draw.line([(wall_x, ly + 2), (W, ly + 2)], fill=(65, 54, 42), width=1)

    # Door frame and recessed doorway
    dx, dy = 160, 40
    dw, dh = 72, 145
    draw.rectangle([dx - 8, dy - 8, dx + dw + 8, dy + dh], fill=(32, 26, 20), outline=(12, 10, 8))
    # Interior slit opening (Дверь приоткрыта на 18 см)
    slit_w = 22
    draw.rectangle([dx, dy, dx + dw, dy + dh], fill=(16, 14, 12))
    # Warm yellow lamplight spilling from interior slit!
    draw.rectangle([dx, dy, dx + slit_w, dy + dh], fill=(230, 185, 100))
    # Door leaf (приоткрытое полотно двери)
    draw.polygon([(dx + slit_w, dy), (dx + dw, dy + 8), (dx + dw, dy + dh - 6), (dx + slit_w, dy + dh)], fill=(48, 38, 28), outline=(18, 14, 10))

    # Porch steps and handrail covered in snow
    for step_i in range(4):
        sy = 165 + step_i * 12
        sw = 120 - step_i * 18
        draw.rectangle([70, sy, 70 + sw, sy + 10], fill=(160, 170, 180), outline=(60, 55, 50))

    # Storm lifeline rope (Канат-леер)
    draw.line([(0, 145), (140, 175)], fill=(185, 190, 195), width=3)

    # Window beside door (Окно с наличником)
    wx, wy = 265, 55
    ww, wh = 65, 75
    draw.rectangle([wx - 6, wy - 6, wx + ww + 6, wy + wh + 6], fill=(55, 45, 35), outline=(15, 12, 10))
    draw.rectangle([wx, wy, wx + ww, wy + wh], fill=(22, 24, 28))
    # Warm glow from inside behind frost flowers
    draw.rectangle([wx + 4, wy + 4, wx + ww - 4, wy + wh - 4], fill=(180, 140, 80))
    # Window panes cross
    draw.line([(wx + ww // 2, wy), (wx + ww // 2, wy + wh)], fill=(35, 28, 20), width=3)
    draw.line([(wx, wy + wh // 2), (wx + ww, wy + wh // 2)], fill=(35, 28, 20), width=3)

    # HORROR DETAILS:
    # 1. Pale frostbitten hand clutching the doorframe from inside the warm slit
    hand_y = dy + 68
    draw.rectangle([dx + slit_w - 6, hand_y, dx + slit_w + 3, hand_y + 16], fill=(220, 222, 225))
    # Blackened frostbitten fingertips
    for fx in range(dx + slit_w - 5, dx + slit_w + 3, 2):
        draw.line([(fx, hand_y + 12), (fx, hand_y + 16)], fill=(30, 25, 28), width=1)

    # 2. Flattened distorted face pressed against the cold glass outside
    fx, fy = wx + 18, wy + 16
    draw.ellipse([fx, fy, fx + 28, fy + 38], fill=(210, 215, 220, 220))
    # Hollow dark eye sockets
    draw.ellipse([fx + 4, fy + 12, fx + 11, fy + 20], fill=(25, 20, 25))
    draw.ellipse([fx + 17, fy + 12, fx + 24, fy + 20], fill=(25, 20, 25))
    # Gaping dark open mouth pressed flat on glass
    draw.ellipse([fx + 8, fy + 26, fx + 20, fy + 35], fill=(35, 25, 30))

    # Dense blizzard streaks cutting the beam of light
    rng = random.Random(305)
    for _ in range(160):
        bx = rng.randint(0, W - 1)
        by = rng.randint(0, H - 1)
        blen = rng.randint(4, 12)
        # Streaks are brightly illuminated where light spills from door
        in_beam = abs(bx - dx) < 60 and by > dy
        col = (250, 245, 220) if in_beam else (160, 170, 180)
        draw.line([(bx, by), (bx - blen, by + blen // 2)], fill=col, width=1)

    img = add_film_grain(img, 16)
    img = apply_vignette_and_sepia(img, strength=0.4)
    return add_photo_paper_border(img)

# -------------------------------------------------------------
# 4. PHOTO ARCHIVE: CREW 1982 (Бригада полярников «Кедр-7»)
# -------------------------------------------------------------
def bake_crew_photo():
    img = create_base_canvas()
    draw = ImageDraw.Draw(img)

    # Daylight summer overcast sky
    for y in range(H):
        c = int(145 - y * 0.3)
        draw.line([(0, y), (W, y)], fill=(c, c - 2, c - 6))

    # Station cabin wall and larch trees
    draw.rectangle([0, 50, W, H], fill=(75, 65, 52))
    for ly in range(50, H, 18):
        draw.line([(0, ly), (W, ly)], fill=(45, 38, 30), width=2)

    # Wooden bench in front
    bench_y = 135
    draw.rectangle([80, bench_y, 300, bench_y + 12], fill=(95, 82, 68), outline=(40, 35, 28))
    for leg in [95, 180, 285]:
        draw.line([(leg, bench_y + 12), (leg, H - 20)], fill=(45, 38, 30), width=4)

    # Ground (gravel and summer tundra moss)
    for y in range(H - 35, H):
        for x in range(W):
            g = int(60 + math.sin(x * 0.1) * 8 + (y - (H - 35)) * 1.2)
            draw.point((x, y), fill=(g + 5, g + 8, g))

    # THREE SCIENTISTS:
    # 1. Meteorologist technician (left, standing)
    tx, ty = 120, 60
    # Head & wool cap
    draw.ellipse([tx - 10, ty, tx + 10, ty + 24], fill=(160, 145, 130), outline=(40, 35, 30))
    draw.rectangle([tx - 11, ty, tx + 11, ty + 10], fill=(50, 45, 42)) # cap
    # Torso (sweater)
    draw.rectangle([tx - 18, ty + 24, tx + 18, ty + 95], fill=(70, 65, 58), outline=(30, 26, 22))
    # Legs
    draw.line([(tx - 8, ty + 95), (tx - 10, H - 25)], fill=(45, 40, 35), width=7)
    draw.line([(tx + 8, ty + 95), (tx + 10, H - 25)], fill=(45, 40, 35), width=7)

    # 2. Semyonov (Center, sitting on bench)
    sx, sy = 190, 78
    # Head & ushanka fur hat
    draw.ellipse([sx - 11, sy, sx + 11, sy + 25], fill=(170, 150, 135), outline=(40, 35, 30))
    # Ushanka flaps
    draw.polygon([(sx - 15, sy), (sx + 15, sy), (sx + 14, sy + 18), (sx - 14, sy + 18)], fill=(40, 35, 32))
    # Torso (heavy sheepskin coat / тулуп)
    draw.rectangle([sx - 24, sy + 25, sx + 24, sy + 75], fill=(90, 78, 62), outline=(35, 30, 25))
    # Hands holding notebook on knees
    draw.rectangle([sx - 12, sy + 58, sx + 12, sy + 72], fill=(190, 185, 170), outline=(40, 35, 30))
    # Sitting legs in felt boots (валенки)
    draw.line([(sx - 14, sy + 75), (sx - 18, H - 20)], fill=(65, 60, 55), width=10)
    draw.line([(sx + 14, sy + 75), (sx + 18, H - 20)], fill=(65, 60, 55), width=10)

    # 3. Radio operator (right, leaning against post)
    rx, ry = 260, 62
    draw.ellipse([rx - 10, ry, rx + 10, ry + 24], fill=(155, 140, 128), outline=(40, 35, 30))
    draw.rectangle([rx - 16, ry + 24, rx + 16, ry + 95], fill=(55, 52, 48), outline=(28, 25, 22))
    draw.line([(rx - 7, ry + 95), (rx - 8, H - 25)], fill=(40, 38, 35), width=7)
    draw.line([(rx + 7, ry + 95), (rx + 12, H - 25)], fill=(40, 38, 35), width=7)

    # CREEPY DETAIL: THE FOURTH FIGURE (between Semyonov and technician, standing behind)
    fx, fy = 155, 46
    # Faint, semi-transparent hooded shadow figure standing directly behind Semyonov's shoulder
    draw.ellipse([fx - 12, fy, fx + 12, fy + 32], fill=(25, 24, 26, 210))
    draw.rectangle([fx - 18, fy + 32, fx + 18, fy + 80], fill=(20, 19, 21, 210))
    # Spindly arm resting on Semyonov's back
    draw.line([(fx + 8, fy + 38), (sx - 4, sy + 32)], fill=(15, 14, 16), width=3)
    # No human eyes — just two pale hollow pits
    draw.point((fx - 4, fy + 14), fill=(180, 185, 190))
    draw.point((fx + 4, fy + 14), fill=(180, 185, 190))

    img = add_film_grain(img, 13)
    img = apply_vignette_and_sepia(img, strength=0.32, sepia_tone=(1.05, 0.98, 0.88))
    return add_photo_paper_border(img)

# -------------------------------------------------------------
# 5. PHOTO ARCHIVE: PARADOX (Хронологический парадокс)
# -------------------------------------------------------------
def bake_paradox_photo():
    img = create_base_canvas()
    draw = ImageDraw.Draw(img)

    # Red darkroom glow over storage room
    for y in range(H):
        for x in range(W):
            dx, dy = x - W/2, y - 50
            d = math.sqrt(dx*dx + dy*dy)
            red_intensity = max(10, min(140, int(120 - d * 0.45)))
            draw.point((x, y), fill=(red_intensity, int(red_intensity * 0.18), int(red_intensity * 0.12)))

    # Darkroom workbench table in front
    draw.rectangle([40, 130, W - 40, H], fill=(30, 15, 12), outline=(12, 6, 6))
    # Developing trays with reflective chemical liquid
    draw.rectangle([60, 145, 130, 185], fill=(70, 22, 16), outline=(20, 10, 8))
    draw.rectangle([150, 145, 220, 185], fill=(55, 25, 18), outline=(20, 10, 8))
    draw.rectangle([240, 145, 310, 185], fill=(45, 28, 35), outline=(20, 10, 8))

    # Leningrad-4 enlarger on the left
    draw.line([(75, 45), (75, 135)], fill=(35, 15, 12), width=4)
    draw.ellipse([60, 60, 90, 95], fill=(55, 18, 14), outline=(18, 8, 6))

    # THE PLAYER FROM BEHIND (Wearing vatnik and ushanka, leaning over trays)
    px, py = 185, 82
    # Ushanka fur hat from back
    draw.ellipse([px - 14, py, px + 14, py + 26], fill=(22, 12, 10), outline=(8, 4, 4))
    # Shoulders and vatnik coat
    draw.polygon([(px - 38, py + 48), (px + 38, py + 48), (px + 26, py + 22), (px - 26, py + 22)], fill=(40, 20, 16), outline=(14, 8, 6))
    draw.rectangle([px - 34, py + 48, px + 34, H], fill=(32, 16, 12), outline=(12, 6, 4))
    # Arms reaching forward to trays
    draw.line([(px - 32, py + 38), (110, 155)], fill=(35, 18, 14), width=10)
    draw.line([(px + 32, py + 38), (195, 155)], fill=(35, 18, 14), width=10)

    # CREEPY DETAIL: TALL FIGURE IN DOORWAY DIRECTLY BEHIND THE PLAYER (1 METER BACK)
    # Standing in the dark doorway gap on the right
    gx, gy = 310, 30
    draw.rectangle([gx - 18, gy, gx + 25, H - 40], fill=(6, 4, 5))
    # Head looking down toward player
    draw.ellipse([gx - 8, gy + 10, gx + 12, gy + 38], fill=(3, 2, 3))
    # Luminous tapetum eye points
    draw.point((gx - 2, gy + 22), fill=(255, 255, 240))
    draw.point((gx + 6, gy + 22), fill=(255, 255, 240))
    draw.ellipse([gx - 3, gy + 21, gx - 1, gy + 23], outline=(180, 200, 220))
    draw.ellipse([gx + 5, gy + 21, gx + 7, gy + 23], outline=(180, 200, 220))

    img = add_film_grain(img, 18)
    img = apply_vignette_and_sepia(img, strength=0.5, sepia_tone=(1.12, 0.92, 0.85))
    return add_photo_paper_border(img)

def main():
    out_dir = r"assets\textures\photos"
    os.makedirs(out_dir, exist_ok=True)
    
    print("Baking photo_archive_mast.png...")
    bake_mast_photo().save(os.path.join(out_dir, "photo_archive_mast.png"))
    
    print("Baking photo_archive_adit.png...")
    bake_adit_photo().save(os.path.join(out_dir, "photo_archive_adit.png"))
    
    print("Baking photo_archive_porch.png...")
    bake_porch_photo().save(os.path.join(out_dir, "photo_archive_porch.png"))
    
    print("Baking photo_archive_crew.png...")
    bake_crew_photo().save(os.path.join(out_dir, "photo_archive_crew.png"))
    
    print("Baking photo_archive_paradox.png...")
    bake_paradox_photo().save(os.path.join(out_dir, "photo_archive_paradox.png"))
    
    print("All 5 archival photographs baked successfully!")

if __name__ == "__main__":
    main()
