# Генератор 3D-моделей советских приборов метеоплощадки для «Кедр-7»:
# 1. meteo_screen (Психрометрическая будка Селянинова с жалюзи, белая краска УГМС)
# 2. old_meteo_screen (Старая психрометрическая будка — потемневшее дерево, выбитые жалюзи)
# 3. precip_gauge (Осадкомер Третьякова с 16 лепестками ветрозащиты)
# 4. heliograph (Гелиограф Кэмпбелла-Стокса — стеклянный шар на чугунной дуге)
# 5. soil_thermometers (Почвенно-глубинные термометры Савинова)
# 6. wild_vane (Флюгер Вильда с доской и румбами)
# Запуск: blender --background --python tools/blender/meteo_instruments.py -- assets/models/kedr
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, tube, mat, text

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "assets/models/kedr"
os.makedirs(OUT, exist_ok=True)

# -----------------------------------------------------------------------------------
# 1 & 2. ПСИХРОМЕТРИЧЕСКАЯ БУДКА СЕЛЯНИНОВА (НОВАЯ И СТАРАЯ)
# -----------------------------------------------------------------------------------
def build_meteo_screen(is_old=False):
    kit.reset()
    
    WHITE_PAINT = mat("screen_white", (0.84, 0.86, 0.87), rough=0.75, wear=0.6, dirt=0.5, wear_col=(0.38, 0.32, 0.25))
    OLD_WOOD = mat("screen_old", (0.30, 0.25, 0.20), rough=0.9, noise=0.3, wear=0.7, dirt=0.7)
    MAIN_WOOD = OLD_WOOD if is_old else WHITE_PAINT
    LOUVER_DARK = mat("screen_dark", (0.12, 0.13, 0.14), rough=0.9)
    BRASS = mat("screen_brass", (0.65, 0.55, 0.25), rough=0.4, wear=0.6)
    SNOW = mat("screen_snow", (0.86, 0.90, 0.95), rough=0.9)

    # 4 наклонные ножки штатива высотой до 1.25м
    for dx in (-0.32, 0.32):
        for dy in (-0.28, 0.28):
            pts = [(dx * 1.2, dy * 1.2, 0.0), (dx, dy, 1.25)]
            tube(f"leg_{dx}_{dy}", pts, 0.028, MAIN_WOOD, verts=6)
    # Поперечные перемычки штатива и лесенка
    box("brace_x1", (0.72, 0.04, 0.04), (0.0, -0.32, 0.45), MAIN_WOOD)
    box("brace_x2", (0.72, 0.04, 0.04), (0.0, 0.32, 0.45), MAIN_WOOD)
    box("brace_y1", (0.04, 0.62, 0.04), (-0.35, 0.0, 0.45), MAIN_WOOD)
    box("brace_y2", (0.04, 0.62, 0.04), (0.35, 0.0, 0.45), MAIN_WOOD)
    # Ступенька для наблюдателя спереди (+Y в blender / -Z)
    box("step_board", (0.55, 0.20, 0.035), (0.0, -0.38, 0.45), MAIN_WOOD, 0.005)

    # Дно будки
    box("floor_base", (0.76, 0.66, 0.04), (0.0, 0.0, 1.26), MAIN_WOOD, 0.008)
    # Темное внутреннее пространство
    box("interior_block", (0.66, 0.56, 0.64), (0.0, 0.0, 1.62), LOUVER_DARK)

    # 4 угловые стойки будки
    for cx in (-0.35, 0.35):
        for cy in (-0.30, 0.30):
            box(f"corner_post_{cx}_{cy}", (0.05, 0.05, 0.68), (cx, cy, 1.62), MAIN_WOOD, 0.005)

    # Жалюзи (наклонные пластины) по всем 4 сторонам
    for i in range(8):
        z = 1.34 + i * 0.075
        # Боковые стенки (X = -0.35 и +0.35)
        for sx in (-0.35, 0.35):
            box(f"louver_side_{sx}_{i}", (0.035, 0.56, 0.02), (sx, 0.0, z), MAIN_WOOD, rot=(math.radians(35), 0, 0))
        # Задняя стенка (Y = 0.30)
        box(f"louver_back_{i}", (0.66, 0.035, 0.02), (0.0, 0.30, z), MAIN_WOOD, rot=(0, math.radians(35), 0))
        # Передняя дверца (Y = -0.30)
        if not (is_old and i == 4): # у старой выбита одна планка
            box(f"louver_front_l_{i}", (0.30, 0.035, 0.02), (-0.16, -0.30, z), MAIN_WOOD, rot=(0, math.radians(-35), 0))
            box(f"louver_front_r_{i}", (0.30, 0.035, 0.02), (0.16, -0.30, z), MAIN_WOOD, rot=(0, math.radians(-35), 0))

    # Рамка створок дверцы и латунная ручка
    box("door_frame_mid", (0.03, 0.04, 0.64), (0.0, -0.31, 1.62), MAIN_WOOD)
    box("door_handle", (0.02, 0.06, 0.08), (0.05, -0.33, 1.62), BRASS, 0.004)

    # Двойная крыша с воздушным зазором (наклон к задней части)
    rot_roof = (math.radians(-6), 0, 0)
    box("roof_sub", (0.84, 0.76, 0.04), (0.0, 0.0, 1.98), MAIN_WOOD, 0.008, rot=rot_roof)
    box("roof_top", (0.92, 0.84, 0.04), (0.0, 0.0, 2.05), MAIN_WOOD, 0.008, rot=rot_roof)
    # Снежная шапка на крыше
    box("roof_snow", (0.94, 0.86, 0.05), (0.0, 0.0, 2.09), SNOW, 0.02, rot=rot_roof)

    name = "old_meteo_screen" if is_old else "meteo_screen"
    obj, img, tris = kit.finish(name, OUT, res=1024, origin="bottom", samples=28)
    kit.export(os.path.join(OUT, f"{name}.glb"), os.path.join(OUT, f"{name}.blend"))
    print(f"[OK] {name}: {tris} tris")

# -----------------------------------------------------------------------------------
# 3. ОСАДКОМЕР ТРЕТЬЯКОВА (16 лепестков ветрозащиты)
# -----------------------------------------------------------------------------------
def build_precip_gauge():
    kit.reset()
    
    POST_WOOD = mat("precip_post", (0.32, 0.26, 0.20), rough=0.85, noise=0.2)
    ZINC_SHEET = mat("precip_zinc", (0.64, 0.68, 0.70), rough=0.45, noise=0.15, wear=0.7, dirt=0.4, wear_col=(0.32, 0.28, 0.24))
    IRON_RING = mat("precip_iron", (0.22, 0.24, 0.25), rough=0.55, wear=0.7)
    SNOW = mat("precip_snow", (0.86, 0.90, 0.95), rough=0.9)

    H_POST = 1.85
    # Деревянный гранёный столб-опора
    cyl("base_post", 0.07, H_POST, (0, 0, H_POST * 0.5), POST_WOOD, verts=8)
    
    # Центральное ведро-приемник осадков
    cyl("bucket_body", 0.11, 0.42, (0, 0, H_POST + 0.16), ZINC_SHEET, verts=16)
    cyl("bucket_rim", 0.118, 0.02, (0, 0, H_POST + 0.36), ZINC_SHEET, verts=16)
    
    # Опорное кольцо-каркас ветрозащиты
    R_RING = 0.36
    cyl("support_ring", R_RING, 0.025, (0, 0, H_POST + 0.12), IRON_RING, verts=20)
    # 4 радиальные спицы от столба к кольцу
    for a in range(4):
        ang = a * math.pi / 2
        tube(f"spoke_{a}", [(0, 0, H_POST + 0.05), (math.cos(ang) * R_RING, math.sin(ang) * R_RING, H_POST + 0.12)], 0.012, IRON_RING, verts=6)

    # 16 поворотных лепестков ветрозащиты Третьякова, отогнутых наружу
    for i in range(16):
        ang = i * (math.pi * 2.0 / 16.0)
        cx = math.cos(ang) * (R_RING + 0.02)
        cy = math.sin(ang) * (R_RING + 0.02)
        cz = H_POST + 0.20
        # Лепесток: трапециевидная/прямоугольная пластина 12х32 см с наклоном наружу 24 градуса
        rot = (math.radians(-24) * math.sin(ang), math.radians(24) * math.cos(ang), ang)
        box(f"lamella_{i}", (0.12, 0.008, 0.34), (cx, cy, cz), ZINC_SHEET, 0.002, rot=rot)

    # Снежная корка на дне ведра
    cyl("snow_slush", 0.105, 0.04, (0, 0, H_POST + 0.25), SNOW, verts=12)

    obj, img, tris = kit.finish("precip_gauge", OUT, res=512, origin="bottom", samples=24)
    kit.export(os.path.join(OUT, "precip_gauge.glb"), os.path.join(OUT, "precip_gauge.blend"))
    print(f"[OK] precip_gauge: {tris} tris")

# -----------------------------------------------------------------------------------
# 4. ГЕЛИОГРАФ КЭМПБЕЛЛА-СТОКСА
# -----------------------------------------------------------------------------------
def build_heliograph():
    kit.reset()
    
    POST_WOOD = mat("helio_post", (0.34, 0.28, 0.22), rough=0.85, noise=0.2)
    CAST_IRON = mat("helio_iron", (0.18, 0.20, 0.22), rough=0.55, wear=0.6, dirt=0.4, wear_col=(0.35, 0.22, 0.14))
    BRASS = mat("helio_brass", (0.75, 0.64, 0.30), rough=0.35, wear=0.5)
    GLASS = mat("helio_glass", (0.85, 0.92, 0.96), rough=0.08, noise=0.0)

    H_POST = 1.45
    # Опорный столб с массивным оголовком
    cyl("helio_post", 0.09, H_POST, (0, 0, H_POST * 0.5), POST_WOOD, verts=8)
    box("head_plate", (0.34, 0.30, 0.05), (0, 0, H_POST + 0.025), CAST_IRON, 0.006)

    # Чугунная полусферическая чаша-ложе под ленту
    cyl("bowl_bracket", 0.13, 0.03, (0, 0, H_POST + 0.08), CAST_IRON, rot=(math.pi / 2, 0, 0), verts=16)
    box("card_holder", (0.24, 0.06, 0.12), (0, 0, H_POST + 0.12), BRASS, 0.004, rot=(math.radians(25), 0, 0))

    # Стеклянный шар-линза (диаметр 10 см)
    sphere("glass_sphere", 0.06, (0, 0, H_POST + 0.19), GLASS, segs=16, rings=12)

    obj, img, tris = kit.finish("heliograph", OUT, res=512, origin="bottom", samples=24)
    kit.export(os.path.join(OUT, "heliograph.glb"), os.path.join(OUT, "heliograph.blend"))
    print(f"[OK] heliograph: {tris} tris")

# -----------------------------------------------------------------------------------
# 5. ПОЧВЕННЫЕ ТЕРМОМЕТРЫ САВИНОВА
# -----------------------------------------------------------------------------------
def build_soil_thermometers():
    kit.reset()
    
    FRAME_WOOD = mat("soil_wood", (0.35, 0.28, 0.20), rough=0.85, noise=0.25)
    GLASS = mat("soil_glass", (0.80, 0.88, 0.92), rough=0.15)
    RED_FLUID = mat("soil_fluid", (0.75, 0.10, 0.08), rough=0.3)
    BRASS_SCALE = mat("soil_scale", (0.78, 0.75, 0.65), rough=0.4)

    # Деревянная защитная рамка 1.4м х 0.9м вокруг делянки
    box("frame_side1", (1.4, 0.08, 0.10), (0, -0.45, 0.05), FRAME_WOOD, 0.008)
    box("frame_side2", (1.4, 0.08, 0.10), (0, 0.45, 0.05), FRAME_WOOD, 0.008)
    box("frame_end1", (0.08, 0.82, 0.10), (-0.66, 0, 0.05), FRAME_WOOD, 0.008)
    box("frame_end2", (0.08, 0.82, 0.10), (0.66, 0, 0.05), FRAME_WOOD, 0.008)

    # 4 наклонных коленчатых термометра разной глубины (5, 10, 15, 20 см)
    for i in range(4):
        x = -0.45 + i * 0.30
        h_stem = 0.22 + i * 0.06
        # Вертикальная защитная трубка
        cyl(f"stem_{i}", 0.016, h_stem, (x, -0.10, h_stem * 0.5), GLASS, verts=8)
        # Наклонная шкала термометра
        box(f"scale_{i}", (0.04, 0.012, 0.14), (x, -0.10, h_stem), BRASS_SCALE, 0.002, rot=(math.radians(35), 0, 0))
        # Резервуар с красной жидкостью
        cyl(f"bulb_{i}", 0.012, 0.05, (x, -0.10, h_stem), RED_FLUID, verts=6)

    obj, img, tris = kit.finish("soil_thermometers", OUT, res=512, origin="bottom", samples=24)
    kit.export(os.path.join(OUT, "soil_thermometers.glb"), os.path.join(OUT, "soil_thermometers.blend"))
    print(f"[OK] soil_thermometers: {tris} tris")

# -----------------------------------------------------------------------------------
# 6. ФЛЮГЕР ВИЛЬДА С ДОСКОЙ
# -----------------------------------------------------------------------------------
def build_wild_vane():
    kit.reset()
    
    STEEL_MAST = mat("vane_steel", (0.24, 0.26, 0.28), rough=0.5, wear=0.7, dirt=0.4, wear_col=(0.45, 0.26, 0.15))
    IRON_SHEET = mat("vane_sheet", (0.35, 0.38, 0.40), rough=0.45, wear=0.75)
    LETTERS = mat("vane_text", (0.85, 0.82, 0.75), rough=0.6)

    # Стальная мачта высотой 5.8м
    cyl("mast_body", 0.045, 5.5, (0, 0, 2.75), STEEL_MAST, verts=10)
    
    # Крестовина сторон света (румбы) на высоте 5.0м
    tube("compass_x", [(-0.45, 0, 5.0), (0.45, 0, 5.0)], 0.015, STEEL_MAST, verts=6)
    tube("compass_y", [(0, -0.45, 5.0), (0, 0.45, 5.0)], 0.015, STEEL_MAST, verts=6)
    # Таблички румбов: С, Ю, В, З
    box("tab_N", (0.08, 0.01, 0.08), (0, 0.46, 5.0), IRON_SHEET)
    box("tab_S", (0.08, 0.01, 0.08), (0, -0.46, 5.0), IRON_SHEET)
    box("tab_E", (0.01, 0.08, 0.08), (0.46, 0, 5.0), IRON_SHEET)
    box("tab_W", (0.01, 0.08, 0.08), (-0.46, 0, 5.0), IRON_SHEET)

    # Поворотная гильза флюгера на высоте 5.6м
    cyl("vane_sleeve", 0.055, 0.35, (0, 0, 5.65), STEEL_MAST, verts=10)
    # Двойное хвостовое оперение
    box("vane_fin", (0.02, 0.55, 0.26), (0, 0.42, 5.72), IRON_SHEET, 0.005)
    # Противовес с шаром спереди
    tube("vane_spoke_fwd", [(0, 0, 5.72), (0, -0.42, 5.72)], 0.016, STEEL_MAST, verts=6)
    sphere("counter_ball", 0.055, (0, -0.42, 5.72), STEEL_MAST, segs=10, rings=8)

    # Дуга со штифтами и отклонённая ветром доска Вильда
    cyl("arc_ring", 0.16, 0.012, (0.06, 0, 5.55), STEEL_MAST, rot=(0, math.pi / 2, 0), verts=12)
    # Сама доска Вильда, отклоненная ветром на 35 градусов
    box("vane_plate", (0.012, 0.16, 0.28), (0, 0.14, 5.58), IRON_SHEET, 0.004, rot=(math.radians(35), 0, 0))

    obj, img, tris = kit.finish("wild_vane", OUT, res=512, origin="bottom", samples=24)
    kit.export(os.path.join(OUT, "wild_vane.glb"), os.path.join(OUT, "wild_vane.blend"))
    print(f"[OK] wild_vane: {tris} tris")


if __name__ == "__main__":
    build_meteo_screen(False)
    build_meteo_screen(True)
    build_precip_gauge()
    build_heliograph()
    build_soil_thermometers()
    build_wild_vane()
