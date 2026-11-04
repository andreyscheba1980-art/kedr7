# Генератор 3D-модели леерного столба и страховочного троса «Кедр-7».
# Деревянный окоренный столб с затесанным конусом от снега,
# оцинкованный хомут со стальным кольцом, через которое пропущен натяжной трос,
# сигнальный жестяной красный флажок-указатель и скользящий карабин.
# Запуск: blender --background --python leers.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, tube, mat

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()

WOOD_POST = mat("leer_wood", (0.38, 0.32, 0.24), rough=0.75, wear=0.6, dirt=0.55, wear_col=(0.52, 0.46, 0.36))
STEEL_RUST = mat("leer_steel", (0.35, 0.34, 0.33), rough=0.55, wear=0.7, dirt=0.5, wear_col=(0.55, 0.42, 0.32))
FLAG_RED = mat("leer_flag", (0.68, 0.14, 0.12), rough=0.6, wear=0.8, dirt=0.6, wear_col=(0.45, 0.38, 0.35))
SNOW_CAP = mat("leer_snow", (0.92, 0.94, 0.96), rough=0.85, wear=0.0, dirt=0.05)

# 1. Деревянный столб (высота 1.35 м, диаметр 0.14 м, затесанный сверху)
cyl("post_body", 0.07, 1.25, (0, 0, 0.625), WOOD_POST, verts=10, bevel=0.006)
# Затесанный конусообразный верх
cyl("post_top", 0.07, 0.12, (0, 0, 1.31), WOOD_POST, verts=10, r2=0.02)
# Снежная шапочка на верхушке
sphere("snow_top", 0.045, (0, 0, 1.37), SNOW_CAP, scale=(1.2, 1.2, 0.5), segs=10, rings=6)

# 2. Стальной хомут с проушиной на высоте 0.95 м
cyl("clamp_ring", 0.076, 0.04, (0, 0, 0.95), STEEL_RUST, verts=10, bevel=0.003)
box("clamp_bracket", (0.04, 0.05, 0.03), (0, 0.09, 0.95), STEEL_RUST, bevel=0.002)

# Кольцо-направляющая для троса
cyl("guide_eye", 0.035, 0.018, (0, 0.12, 0.95), STEEL_RUST, rot=(0, math.radians(90), 0), verts=10, bevel=0.004)

# 3. Участок стального натяжного троса, проходящего сквозь кольцо (-X в +X)
cyl("cable_seg", 0.008, 0.80, (0, 0.12, 0.95), STEEL_RUST, rot=(0, math.radians(90), 0), verts=8)

# 4. Скользящий карабин на тросе
tube("carabiner_loop", [
    (0.06, 0.12, 0.96),
    (0.06, 0.12, 0.92),
    (0.04, 0.12, 0.90),
    (0.04, 0.12, 0.96),
    (0.06, 0.12, 0.96)
], 0.004, STEEL_RUST, 6)

# 5. Сигнальный жестяной красный треугольный флажок на хомуте (-Y)
tube("flag_sheet", [
    (0, -0.075, 0.97),
    (0, -0.280, 0.93),
    (0, -0.075, 0.89),
    (0, -0.075, 0.97)
], 0.003, FLAG_RED, 4)

body, img, tris = kit.finish("leers_post", OUT, res=512, origin="bottom", samples=16, ao_min=0.35)
print(f"[OK] leers_post: {tris} tris, texture -> {img.filepath_raw}")

glb_path = os.path.join(OUT, "leers_post.glb")
blend_path = os.path.join(OUT, "leers_post.blend")
kit.export(glb_path, blend_path)
print(f"[EXPORT] {glb_path}")
