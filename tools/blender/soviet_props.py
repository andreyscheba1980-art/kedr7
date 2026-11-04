# Пак аутентичного советского реквизита для замены generic Kenney ассетов («Кедр-7»):
# 1. soviet_barrel (200л стальная бочка ГОСТ 13950-68 с ребрами-зигами, пробками и трафаретом «А-76»)
# 2. soviet_barrel_open (открытая бочка со льдом и наледью)
# 3. soviet_crate (дощатый экспедиционный ящик со стальными уголками и веревочными ручками)
# 4. soviet_crate_large (крупный грузовой ящик ГОСТ 2991-85)
# 5. soviet_bucket (оцинкованное коническое ведро 10л с дужкой и деревянной ручкой)
# Запуск: blender --background --python tools/blender/soviet_props.py -- assets/models/kedr
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, tube, mat, text

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "assets/models/kedr"
os.makedirs(OUT, exist_ok=True)

# -----------------------------------------------------------------------------------
# 1. SOVIET BARREL (200л)
# -----------------------------------------------------------------------------------
def build_barrel(is_open=False):
    kit.reset()
    R = 0.29
    H = 0.88
    
    BARREL_PAINT = mat("barrel_col", (0.42, 0.22, 0.16) if not is_open else (0.35, 0.38, 0.36),
                       rough=0.6, wear=0.75, dirt=0.6, wear_col=(0.28, 0.20, 0.14))
    BARREL_RIMS = mat("barrel_rims", (0.24, 0.22, 0.20), rough=0.5, wear=0.8, wear_col=(0.45, 0.26, 0.15))
    STENCIL = mat("barrel_sten", (0.10, 0.10, 0.10), rough=0.85)
    SLUSH = mat("barrel_slush", (0.30, 0.34, 0.38), rough=0.2, dirt=0.3)
    SNOW = mat("barrel_snow", (0.86, 0.90, 0.95), rough=0.9)
    
    # Основное тело цилиндра
    cyl("barrel_body", R, H - 0.04, (0, 0, H * 0.5), BARREL_PAINT, rot=(0, 0, 0), verts=24)
    # Верхний и нижний закатные обода (chimes)
    cyl("chime_bot", R * 1.015, 0.035, (0, 0, 0.02), BARREL_RIMS, rot=(0, 0, 0), verts=24)
    cyl("chime_top", R * 1.015, 0.035, (0, 0, H - 0.02), BARREL_RIMS, rot=(0, 0, 0), verts=24)
    
    # Два выкатных кольца жесткости (зиги) на 1/3 и 2/3 высоты
    for z in (H * 0.33, H * 0.67):
        cyl(f"rolling_hoop_{z:.2f}", R * 1.025, 0.038, (0, 0, z), BARREL_RIMS, rot=(0, 0, 0), verts=24)
    
    if not is_open:
        # Верхняя утопленная крышка
        cyl("top_lid", R * 0.98, 0.02, (0, 0, H - 0.025), BARREL_PAINT, rot=(0, 0, 0), verts=24)
        # Большая горловина с шестигранной пробкой (G2)
        cyl("bung_large_base", 0.038, 0.015, (0.12, 0.08, H - 0.015), BARREL_RIMS, rot=(0, 0, 0), verts=12)
        cyl("bung_large_hex", 0.026, 0.014, (0.12, 0.08, H - 0.005), BARREL_RIMS, rot=(0, 0, 0), verts=6)
        # Малая стравливающая горловина с пробкой (G3/4)
        cyl("bung_small_base", 0.024, 0.015, (-0.12, -0.08, H - 0.015), BARREL_RIMS, rot=(0, 0, 0), verts=12)
        cyl("bung_small_hex", 0.016, 0.014, (-0.12, -0.08, H - 0.005), BARREL_RIMS, rot=(0, 0, 0), verts=6)
        # Трафаретная маркировка на боку: «А-76»
        text("A-76", 0.10, (0.0, -R * 1.005, H * 0.52), STENCIL, rot=(math.pi / 2, 0, 0))
        text("ГСМ", 0.065, (0.0, -R * 1.005, H * 0.42), STENCIL, rot=(math.pi / 2, 0, 0))
    else:
        # Внутренний уровень маслянистой жижи со льдом
        cyl("slush_surface", R * 0.96, 0.02, (0, 0, H * 0.72), SLUSH, rot=(0, 0, 0), verts=20)
        # Снег по кромке обода
        box("snow_rim", (0.18, 0.06, 0.03), (0.15, -0.15, H - 0.01), SNOW, 0.01)
        box("snow_rim2", (0.14, 0.05, 0.03), (-0.18, 0.10, H - 0.01), SNOW, 0.01)

    name = "soviet_barrel" if not is_open else "soviet_barrel_open"
    obj, img, tris = kit.finish(name, OUT, res=1024, origin="bottom", samples=28)
    kit.export(os.path.join(OUT, f"{name}.glb"), os.path.join(OUT, f"{name}.blend"))
    print(f"[OK] {name}: {tris} tris")

# -----------------------------------------------------------------------------------
# 2. SOVIET CRATE (Деревянный ящик ГОСТ)
# -----------------------------------------------------------------------------------
def build_crate(is_large=False):
    kit.reset()
    W, D, H = (1.1, 0.7, 0.62) if is_large else (0.75, 0.48, 0.42)
    
    CRATE_WOOD = mat("crate_wood", (0.34, 0.38, 0.30) if not is_large else (0.38, 0.34, 0.26),
                     rough=0.9, noise=0.25, wear=0.6, dirt=0.55, wear_col=(0.28, 0.24, 0.18))
    CRATE_IRON = mat("crate_iron", (0.20, 0.22, 0.22), rough=0.5, wear=0.75, wear_col=(0.42, 0.25, 0.15))
    ROPE = mat("crate_rope", (0.52, 0.46, 0.35), rough=0.95, noise=0.3)
    STENCIL = mat("crate_sten", (0.12, 0.12, 0.14), rough=0.85)

    # Основной короб ящика
    box("crate_body", (W, D, H), (0, 0, H * 0.5), CRATE_WOOD, 0.008)
    # Накладная верхняя крышка с брусками
    box("lid_rim", (W + 0.02, D + 0.02, 0.035), (0, 0, H + 0.01), CRATE_WOOD, 0.006)
    
    # Угловые стальные окованные пластины на всех 8 углах
    cw, cd, ch = 0.06, 0.06, 0.09
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                px = sx * (W * 0.5 - cw * 0.4)
                py = sy * (D * 0.5 - cd * 0.4)
                pz = (H * 0.5) + sz * (H * 0.5 - ch * 0.45)
                box(f"corner_{sx}_{sy}_{sz}", (cw, cd, ch), (px, py, pz), CRATE_IRON, 0.004)

    # Стальные замки-защёлки спереди (-Y в kit)
    for sx in (-0.22, 0.22):
        box(f"latch_{sx}", (0.04, 0.015, 0.08), (sx * (W * 0.7), -D * 0.5 - 0.008, H - 0.02), CRATE_IRON, 0.002)

    # Веревочные ручки по бокам (X = -W/2 и +W/2)
    for sx in (-1, 1):
        # Петли крепления ручек
        box(f"handle_bracket_{sx}", (0.018, 0.12, 0.03), (sx * (W * 0.5 + 0.008), 0.0, H * 0.6), CRATE_IRON)
        # Провисающая веревочная ручка
        pts = [
            (sx * (W * 0.5 + 0.015), -0.05, H * 0.6),
            (sx * (W * 0.5 + 0.055), -0.02, H * 0.52),
            (sx * (W * 0.5 + 0.055), 0.02, H * 0.52),
            (sx * (W * 0.5 + 0.015), 0.05, H * 0.6)
        ]
        tube(f"rope_{sx}", pts, 0.014, ROPE, verts=8)

    # Трафарет на передней стенке (-Y)
    txt_lbl = "ИНВ. 317" if not is_large else "ЗАПЧАСТИ"
    text(txt_lbl, 0.065 if not is_large else 0.085, (0.0, -D * 0.505, H * 0.52), STENCIL, rot=(math.pi / 2, 0, 0))
    text("НЕ БРОСАТЬ", 0.042, (0.0, -D * 0.505, H * 0.38), STENCIL, rot=(math.pi / 2, 0, 0))

    name = "soviet_crate" if not is_large else "soviet_crate_large"
    obj, img, tris = kit.finish(name, OUT, res=1024, origin="bottom", samples=28)
    kit.export(os.path.join(OUT, f"{name}.glb"), os.path.join(OUT, f"{name}.blend"))
    print(f"[OK] {name}: {tris} tris")

# -----------------------------------------------------------------------------------
# 3. SOVIET BUCKET (Оцинкованное ведро 10л)
# -----------------------------------------------------------------------------------
def build_bucket():
    kit.reset()
    R_TOP = 0.14
    R_BOT = 0.10
    H = 0.28
    
    ZINC = mat("bucket_zinc", (0.58, 0.62, 0.64), rough=0.45, noise=0.15, wear=0.7, dirt=0.5, wear_col=(0.30, 0.26, 0.22))
    WIRE = mat("bucket_wire", (0.24, 0.25, 0.26), rough=0.5, wear=0.7)
    HANDLE_WOOD = mat("bucket_wood", (0.42, 0.35, 0.26), rough=0.85, noise=0.2)

    # Коническое тело ведра
    cyl("bucket_body", R_BOT, H, (0, 0, H * 0.5), ZINC, rot=(0, 0, 0), verts=20, r2=R_TOP)
    # Завальцованный верхний бортик
    cyl("bucket_rim_top", R_TOP * 1.025, 0.015, (0, 0, H - 0.007), ZINC, rot=(0, 0, 0), verts=20)
    # Нижний обод-поддон
    cyl("bucket_rim_bot", R_BOT * 1.03, 0.02, (0, 0, 0.01), ZINC, rot=(0, 0, 0), verts=20)
    # Ушки крепления дужки
    for sx in (-1, 1):
        box(f"ear_{sx}", (0.01, 0.025, 0.04), (sx * (R_TOP + 0.008), 0.0, H - 0.02), ZINC, 0.002)

    # Проволочная металлическая дужка, слегка откинутая в сторону (-Y / +Z)
    tilt_ang = math.radians(25)
    pts = [
        (-R_TOP - 0.01, 0.0, H - 0.02),
        (-R_TOP - 0.01, 0.10, H + 0.12),
        (0.0, 0.12, H + 0.16),
        (R_TOP + 0.01, 0.10, H + 0.12),
        (R_TOP + 0.01, 0.0, H - 0.02)
    ]
    tube("bail_handle", pts, 0.004, WIRE, verts=6)
    # Деревянный валик-ручка на вершине дужки
    cyl("wooden_grip", 0.014, 0.08, (0.0, 0.12, H + 0.16), HANDLE_WOOD, rot=(0, math.pi / 2, 0), verts=10)

    obj, img, tris = kit.finish("soviet_bucket", OUT, res=512, origin="bottom", samples=24)
    kit.export(os.path.join(OUT, "soviet_bucket.glb"), os.path.join(OUT, "soviet_bucket.blend"))
    print(f"[OK] soviet_bucket: {tris} tris")


if __name__ == "__main__":
    build_barrel(False)
    build_barrel(True)
    build_crate(False)
    build_crate(True)
    build_bucket()
