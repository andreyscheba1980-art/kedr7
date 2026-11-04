# Генератор цельной 3D-модели подземного аппаратного зала спецсвязи «Отзвук» для «Кедр-7» (1983 год).
# Включает:
# 1. Тамбур спуска (-7.5..-4.5) с колодцем, дренажным приямком, лестницей и порталом гермодвери
# 2. Узкий сырой коридор (-4.5..2.0) с кабель-каналами, пучками кабелей, воздуховодом и аварийными фонарями
# 3. Большой аппаратный зал (2.0..14.0 x -4.0..4.0, h: 3.2m):
#    - Железобетонные своды и ригели потолка с потёками влаги и швами опалубки
#    - Бетонный пол с трафаретной желтой разметкой безопасности и кабельными каналами
#    - 10 высоких 19-дюймовых стоек аппаратуры связи «Отзвук» (по 5 в 2 ряда) с лицевыми панелями,
#      стрелочными приборами, тумблерами, бобинами магнитной ленты и индикаторами
#    - Массивный подвесной воздуховод вентиляции под потолком с решетками
#    - Главный металлический пульт радиста связи в торце зала с приборными мостиками
#    - Трафареты: «ОБЪЕКТ «ОТЗВУК»», «СЕКТОР СВЯЗИ», «ПРИ ТРЕВОГЕ ОТКЛЮЧИТЬ ПИТАНИЕ»
# Координаты строятся сразу в координатах BUNKER_ROOM (origin="keep").
# Запуск: blender --background --python tools/blender/bunker_interior.py -- assets/models/kedr
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, tube, mat, text

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "assets/models/kedr"
os.makedirs(OUT, exist_ok=True)
kit.reset()

# --- Материалы бункера ГО 1970-х годов ---
CONC_WALL = mat("bunk_conc", (0.44, 0.45, 0.43), rough=0.92, noise=0.25, noise_scale=12.0, wear=0.5, dirt=0.75, wear_col=(0.32, 0.30, 0.28))
CONC_FLOOR = mat("bunk_floor", (0.36, 0.38, 0.36), rough=0.95, noise=0.2, noise_scale=8.0, wear=0.6, dirt=0.8, wear_col=(0.28, 0.28, 0.26))
CONC_CEIL = mat("bunk_ceil", (0.42, 0.43, 0.41), rough=0.92, noise=0.25, wear=0.4, dirt=0.85)

RACK_BODY = mat("bunk_rack", (0.24, 0.28, 0.24), rough=0.6, wear=0.75, dirt=0.5, wear_col=(0.42, 0.25, 0.16))
RACK_PANEL = mat("bunk_panel", (0.16, 0.18, 0.17), rough=0.55, wear=0.7, dirt=0.4)
RACK_DIAL = mat("bunk_dial", (0.84, 0.82, 0.74), rough=0.4)
TAPE_SPOOL = mat("bunk_tape", (0.28, 0.18, 0.12), rough=0.6)
TAPE_FLANGE = mat("bunk_flange", (0.62, 0.64, 0.65), rough=0.35, wear=0.5)

VENT_ZINC = mat("bunk_vent", (0.58, 0.62, 0.64), rough=0.45, wear=0.7, dirt=0.6, wear_col=(0.34, 0.26, 0.18))
STEEL_DARK = mat("bunk_steel", (0.18, 0.20, 0.21), rough=0.5, wear=0.8, wear_col=(0.45, 0.28, 0.16))
CABLE_BLACK = mat("bunk_cable", (0.10, 0.11, 0.12), rough=0.85, noise=0.1)

SAFETY_YELLOW = mat("bunk_yellow", (0.82, 0.68, 0.12), rough=0.7, wear=0.8, wear_col=(0.35, 0.35, 0.35))
STENCIL_RED = mat("bunk_red", (0.75, 0.12, 0.10), rough=0.8)
STENCIL_BLACK = mat("bunk_sten", (0.12, 0.12, 0.12), rough=0.85)
LAMP_RED = mat("bunk_lamp_red", (0.90, 0.20, 0.15), rough=0.2)
LAMP_AMBER = mat("bunk_lamp_amber", (0.95, 0.65, 0.12), rough=0.2)

# ===================================================================================
# 1. ТАМБУР СПУСКА (X: -7.6 .. -4.5, Z: -2.5 .. 2.5, Y: 0.0 .. 3.0)
# Внимание: kit использует Z вверх, X восток, -Y юг (или в терминах Godot: Godot Y -> Blender Z, Godot Z -> Blender -Y)
# Сделаем вспомогательную функцию перевода:
# pos_g: (gx, gy, gz) -> (gx, -gz, gy)
# ===================================================================================
def gbox(name, center, size, m, bevel=0.0):
    gx, gy, gz = center
    sx, sy, sz = size
    # В Blender: X=gx, Y=-gz, Z=gy. Размер: sx, sz, sy!
    return box(name, (sx, sz, sy), (gx, -gz, gy), m, bevel=bevel)

def gcyl(name, r, h, center, m, axis="y", verts=16):
    gx, gy, gz = center
    rot = {"y": (0, 0, 0), "x": (0, math.pi / 2, 0), "z": (math.pi / 2, 0, 0)}[axis]
    return cyl(name, r, h, (gx, -gz, gy), m, rot=rot, verts=verts)

# 1.1 Тамбур
# Пол
gbox("tam_floor", (-6.05, -0.15, 0.0), (3.3, 0.3, 5.2), CONC_FLOOR)
# Потолок
gbox("tam_ceil", (-6.05, 3.15, 0.0), (3.3, 0.3, 5.2), CONC_CEIL)
# Западная стена (глухая, у нее скобы)
gbox("tam_wall_w", (-7.65, 1.5, 0.0), (0.3, 3.0, 5.2), CONC_WALL)
# Северная и южная стены тамбура
gbox("tam_wall_n", (-6.05, 1.5, -2.55), (3.1, 3.0, 0.3), CONC_WALL)
gbox("tam_wall_s", (-6.05, 1.5, 2.55), (3.1, 3.0, 0.3), CONC_WALL)
# Восточная стена тамбура с проемом гермодвери на X = -4.5
gbox("tam_wall_e_top", (-4.5, 2.5, 0.0), (0.3, 1.0, 5.2), CONC_WALL)
gbox("tam_wall_e_n", (-4.5, 1.05, -1.8), (0.3, 2.1, 1.8), CONC_WALL)
gbox("tam_wall_e_s", (-4.5, 1.05, 1.8), (0.3, 2.1, 1.8), CONC_WALL)
# Массивная рама гермодвери
gbox("blast_frame_top", (-4.5, 2.15, 0.0), (0.45, 0.12, 1.4), STEEL_DARK, 0.01)
gbox("blast_frame_l", (-4.5, 1.05, -0.65), (0.45, 2.1, 0.12), STEEL_DARK, 0.01)
gbox("blast_frame_r", (-4.5, 1.05, 0.65), (0.45, 2.1, 0.12), STEEL_DARK, 0.01)
gbox("blast_threshold", (-4.5, 0.08, 0.0), (0.45, 0.16, 1.4), STEEL_DARK, 0.01)

# Скобы-лестница на западной стене тамбура
for k in range(8):
    y = 0.35 + k * 0.38
    gbox(f"tam_rung_{k}", (-7.42, y, 0.0), (0.12, 0.035, 0.55), STEEL_DARK, 0.005)

# ===================================================================================
# 2. СЫРОЙ КОРИДОР С КАБЕЛЬ-КАНАЛАМИ (X: -4.5 .. 2.0, Z: -1.1 .. 1.1, Y: 0.0 .. 2.5)
# ===================================================================================
# Пол коридора
gbox("cor_floor", (-1.25, -0.15, 0.0), (6.7, 0.3, 2.4), CONC_FLOOR)
# Потолок коридора
gbox("cor_ceil", (-1.25, 2.55, 0.0), (6.7, 0.3, 2.4), CONC_CEIL)
# Стены коридора (север Z=-1.15, юг Z=1.15)
gbox("cor_wall_n", (-1.25, 1.2, -1.25), (6.7, 2.4, 0.3), CONC_WALL)
gbox("cor_wall_s", (-1.25, 1.2, 1.25), (6.7, 2.4, 0.3), CONC_WALL)

# Железобетонные усиливающие арки коридора каждые 1.8м
for ax in (-3.3, -1.5, 0.3):
    gbox(f"cor_arch_l_{ax}", (ax, 1.2, -1.02), (0.25, 2.4, 0.16), CONC_WALL, 0.01)
    gbox(f"cor_arch_r_{ax}", (ax, 1.2, 1.02), (0.25, 2.4, 0.16), CONC_WALL, 0.01)
    gbox(f"cor_arch_top_{ax}", (ax, 2.32, 0.0), (0.25, 0.22, 2.1), CONC_WALL, 0.01)

# Металлические перфорированные кабель-каналы и жгуты кабелей вдоль обеих стен
for side in (-1.0, 1.0):
    sz = side * 0.95
    # Кабельный лоток
    gbox(f"cable_tray_{side}", (-1.25, 2.18, sz), (6.5, 0.06, 0.26), STEEL_DARK)
    # Жгуты толстых силовых и радиокабелей
    gcyl(f"cable_main_{side}", 0.038, 6.4, (-1.25, 2.22, sz - side * 0.05), CABLE_BLACK, axis="x")
    gcyl(f"cable_sub1_{side}", 0.024, 6.4, (-1.25, 2.24, sz + side * 0.04), CABLE_BLACK, axis="x")
    gcyl(f"cable_sub2_{side}", 0.020, 6.4, (-1.25, 2.14, sz + side * 0.02), CABLE_BLACK, axis="x")
    # Оцинкованная вентиляционная труба
    gcyl(f"vent_pipe_{side}", 0.07, 6.4, (-1.25, 1.95, sz), VENT_ZINC, axis="x")

# Аварийные светильники в защитных решетках в коридоре
for lx in (-3.2, 0.2):
    gbox(f"lamp_cage_base_{lx}", (lx, 2.25, 0.0), (0.16, 0.04, 0.16), STEEL_DARK)
    gcyl(f"lamp_glass_{lx}", 0.055, 0.12, (lx, 2.16, 0.0), LAMP_RED, axis="y")
    gbox(f"lamp_cage_{lx}", (lx, 2.16, 0.0), (0.13, 0.14, 0.13), STEEL_DARK, 0.005)

# Проем входа в аппаратный зал на X = 2.0
gbox("hall_entry_wall_top", (2.0, 2.7, 0.0), (0.35, 1.0, 8.4), CONC_WALL)
gbox("hall_entry_wall_n", (2.0, 1.1, -2.6), (0.35, 2.2, 3.4), CONC_WALL)
gbox("hall_entry_wall_s", (2.0, 1.1, 2.6), (0.35, 2.2, 3.4), CONC_WALL)
gbox("hall_entry_beam", (2.0, 2.25, 0.0), (0.5, 0.25, 1.8), CONC_WALL, 0.01)

# ===================================================================================
# 3. АППАРАТНЫЙ ЗАЛ СВЯЗИ «ОТЗВУК» (X: 2.0 .. 14.0, Z: -4.0 .. 4.0, H: 3.2m)
# ===================================================================================
hall_w = 12.0
hall_d = 8.0
hall_h = 3.2
hall_cx = 8.0

# 3.1 Оболочка зала
# Пол зала
gbox("hall_floor", (hall_cx, -0.15, 0.0), (hall_w + 0.4, 0.3, hall_d + 0.4), CONC_FLOOR)
# Потолок зала
gbox("hall_ceil", (hall_cx, hall_h + 0.15, 0.0), (hall_w + 0.4, 0.3, hall_d + 0.4), CONC_CEIL)
# Северная и южная стены
gbox("hall_wall_n", (hall_cx, hall_h * 0.5, -hall_d * 0.5 - 0.15), (hall_w + 0.4, hall_h, 0.3), CONC_WALL)
gbox("hall_wall_s", (hall_cx, hall_h * 0.5, hall_d * 0.5 + 0.15), (hall_w + 0.4, hall_h, 0.3), CONC_WALL)
# Восточная глухая стена в торце
gbox("hall_wall_e", (hall_cx + hall_w * 0.5 + 0.15, hall_h * 0.5, 0.0), (0.3, hall_h, hall_d + 0.4), CONC_WALL)

# Мощные железобетонные ригели перекрытия под потолком зала каждые 2.4м
for rx in (4.2, 6.6, 9.0, 11.4):
    gbox(f"hall_beam_{rx}", (rx, hall_h - 0.2, 0.0), (0.35, 0.4, hall_d), CONC_WALL, 0.015)

# Желтая линия разметки безопасности на полу вокруг стоек
gbox("safety_line_n", (hall_cx, 0.005, -3.15), (10.0, 0.005, 0.08), SAFETY_YELLOW)
gbox("safety_line_s", (hall_cx, 0.005, 3.15), (10.0, 0.005, 0.08), SAFETY_YELLOW)
gbox("safety_line_mid", (hall_cx, 0.005, 0.0), (9.0, 0.005, 0.08), SAFETY_YELLOW)

# Металлические люки кабельных каналов в полу
for cx in (4.5, 7.5, 10.5):
    gbox(f"floor_trench_{cx}", (cx, 0.006, 0.0), (0.9, 0.006, 0.7), STEEL_DARK, 0.004)

# 3.2 Массивный подвесной короб вентиляции под потолком у южной стены
gbox("hall_vent_duct", (hall_cx, hall_h - 0.28, 2.8), (hall_w - 0.4, 0.36, 0.55), VENT_ZINC, 0.01)
# Решетки забора воздуха на коробе
for vx in (4.5, 7.5, 10.5):
    gbox(f"vent_grille_{vx}", (vx, hall_h - 0.47, 2.8), (0.6, 0.02, 0.38), STEEL_DARK)
    # Тяги подвеса к потолку
    gcyl(f"vent_rod_{vx}", 0.012, 0.25, (vx, hall_h - 0.12, 2.8), STEEL_DARK)

# 3.3 РЯДЫ 19-ДЮЙМОВЫХ СТОЕК АППАРАТУРЫ СВЯЗИ «ОТЗВУК» (10 стоек)
# Стоят в два ряда: z = -2.4 и z = +2.4, лицами к проходу
for row in (-1.0, 1.0):
    rz = row * 2.4
    face_z_sign = -row # лицо стойки направлено к центральному проходу (z=0)
    for i in range(5):
        rx = hall_cx - 4.5 + i * 1.5
        # Корпус стойки (1.1м х 2.4м х 0.72м)
        gbox(f"rack_body_{row}_{i}", (rx, 1.2, rz), (1.1, 2.4, 0.72), RACK_BODY, 0.01)
        # Цоколь стойки
        gbox(f"rack_base_{row}_{i}", (rx, 0.08, rz), (1.14, 0.16, 0.76), STEEL_DARK)
        # Верхний козырек
        gbox(f"rack_top_{row}_{i}", (rx, 2.38, rz), (1.14, 0.06, 0.76), STEEL_DARK)
        
        # Лицевая панель (выдвижные блоки аппаратуры)
        face_z = rz + face_z_sign * 0.37
        gbox(f"rack_face_{row}_{i}", (rx, 1.22, face_z), (1.02, 2.15, 0.02), RACK_PANEL)
        
        # Секция катушечного накопителя магнитной ленты (в верхней трети: y=1.85)
        for j in range(2):
            bx = rx + (j - 0.5) * 0.46
            # Катушка: фланец и лента
            gcyl(f"spool_flange_{row}_{i}_{j}", 0.19, 0.015, (bx, 1.85, face_z + face_z_sign * 0.01), TAPE_FLANGE, axis="z", verts=20)
            gcyl(f"spool_tape_{row}_{i}_{j}", 0.13 - j * 0.03, 0.025, (bx, 1.85, face_z + face_z_sign * 0.02), TAPE_SPOOL, axis="z", verts=20)
            gcyl(f"spool_hub_{row}_{i}_{j}", 0.045, 0.035, (bx, 1.85, face_z + face_z_sign * 0.025), TAPE_FLANGE, axis="z", verts=12)

        # Стеклянная крышка отсека бобин
        gbox(f"tape_glass_{row}_{i}", (rx, 1.85, face_z + face_z_sign * 0.03), (0.98, 0.48, 0.01), mat(f"glass_{row}_{i}", (0.5, 0.6, 0.65), rough=0.15))

        # Средняя секция: стрелочные приборы и тумблеры (y=1.38)
        for d in range(3):
            dx = rx - 0.3 + d * 0.3
            gcyl(f"dial_{row}_{i}_{d}", 0.06, 0.015, (dx, 1.38, face_z + face_z_sign * 0.01), RACK_DIAL, axis="z", verts=16)
            # Стрелка прибора
            gbox(f"dial_needle_{row}_{i}_{d}", (dx, 1.39, face_z + face_z_sign * 0.02), (0.01, 0.05, 0.005), STEEL_DARK)

        # Ряд тумблеров и переключателей под приборами
        for t in range(5):
            tx = rx - 0.32 + t * 0.16
            gbox(f"toggle_{row}_{i}_{t}", (tx, 1.15, face_z + face_z_sign * 0.015), (0.02, 0.04, 0.03), STEEL_DARK)

        # Мерцающие светосигнальные лампы и индикаторные полосы
        gbox(f"glow_bar1_{row}_{i}", (rx, 0.95, face_z + face_z_sign * 0.01), (0.75, 0.05, 0.01), LAMP_AMBER)
        gbox(f"glow_bar2_{row}_{i}", (rx, 0.55, face_z + face_z_sign * 0.01), (0.45, 0.04, 0.01), LAMP_AMBER)
        gbox(f"lamp_red_{row}_{i}", (rx + 0.38, 1.38, face_z + face_z_sign * 0.01), (0.04, 0.04, 0.02), LAMP_RED)

        # Вентиляционные жалюзи в нижней части стойки
        for v in range(4):
            gbox(f"louver_{row}_{i}_{v}", (rx, 0.32 + v * 0.06, face_z + face_z_sign * 0.008), (0.85, 0.012, 0.008), STEEL_DARK)

# 3.4 ГЛАВНЫЙ ПУЛЬТ РАДИСТА В ТОРЦЕ ЗАЛА (X: 12.2, Z: 0.0)
desk_x = hall_cx + 4.2 # 12.2
# Массивный стальной каркас стола
gbox("desk_frame", (desk_x, 0.38, 0.0), (1.1, 0.76, 3.2), STEEL_DARK, 0.01)
# Столешница с матовым покрытием
gbox("desk_top", (desk_x, 0.77, 0.0), (1.18, 0.04, 3.28), RACK_BODY, 0.008)
# Тумбы с ящиками
gbox("desk_drawers_l", (desk_x, 0.38, -1.1), (0.9, 0.68, 0.75), RACK_PANEL)
gbox("desk_drawers_r", (desk_x, 0.38, 1.1), (0.9, 0.68, 0.75), RACK_PANEL)

# Приборный мостик связи на столе (радиостанция, коммутатор, осциллограф)
gbox("console_base", (desk_x + 0.25, 1.05, -0.2), (0.55, 0.52, 1.6), RACK_BODY, 0.01)
gbox("console_panel", (desk_x - 0.03, 1.05, -0.2), (0.02, 0.48, 1.54), RACK_PANEL)
# Круглый экран осциллографа
gcyl("scope_screen", 0.09, 0.02, (desk_x - 0.04, 1.12, 0.35), mat("scope_glass", (0.15, 0.45, 0.25), rough=0.2), axis="x", verts=16)
# Блоки стрелочных шкал и тумблеров на пульте
for k in range(3):
    gcyl(f"pult_meter_{k}", 0.045, 0.015, (desk_x - 0.04, 1.12, -0.65 + k * 0.22), RACK_DIAL, axis="x", verts=12)

# Настольная экранированная лампа радиста на гибкой стойке
gcyl("desk_lamp_base", 0.09, 0.02, (desk_x - 0.2, 0.80, 0.95), STEEL_DARK, axis="y")
tube("desk_lamp_neck", [(desk_x - 0.2, 0.81, 0.95), (desk_x - 0.15, 1.15, 0.95), (desk_x, 1.1, 0.8)], 0.012, STEEL_DARK, verts=6)
cyl("desk_lamp_shade", 0.08, 0.12, (desk_x, 1.1, 0.8), RACK_BODY, verts=10, r2=0.03)

# 3.5 СОВЕТСКИЕ АУТЕНТИЧНЫЕ ТРАФАРЕТЫ НА СТЕНАХ БУНКЕРА
# В Blender надписи ориентируем: текст лежит в плоскости стены
# Восточная стена зала (X = 14.1, нормаль -X):
# text() в kit поворачивает по умолчанию. Сделаем рельефный блок под трафарет:
gbox("sign_board_main", (14.05, 2.3, 0.0), (0.01, 0.35, 2.2), STENCIL_BLACK)
text("ОБЪЕКТ «ОТЗВУК»", 0.14, (14.03, 0.0, 2.3), mat("sten_white", (0.88, 0.88, 0.85), rough=0.6), rot=(math.pi / 2, 0, math.pi / 2))

# Предупреждающий трафарет на северной стене
gbox("sign_warn_plate", (hall_cx, 2.2, -3.95), (1.8, 0.28, 0.01), SAFETY_YELLOW)
text("ВЫСОКОЕ НАПРЯЖЕНИЕ", 0.085, (hall_cx, 3.93, 2.22), STENCIL_BLACK, rot=(math.pi / 2, 0, 0))
text("ОПАСНО ДЛЯ ЖИЗНИ", 0.065, (hall_cx, 3.93, 2.12), STENCIL_RED, rot=(math.pi / 2, 0, 0))

# Сборка модели в единый меш с запеканием Cycles AO (2048x2048, origin="keep")
obj, img, tris = kit.finish("bunker_interior", OUT, res=2048, origin="keep", samples=32, pack=0.003, ao_blur=2)
kit.export(os.path.join(OUT, "bunker_interior.glb"), os.path.join(OUT, "bunker_interior.blend"))
print(f"[OK] bunker_interior: {tris} tris exported to {OUT}")
