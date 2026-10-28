# Генератор 3D-модели заброшенной советской метеорологической вышки 1950-х годов.
# 4-опорная металлическая решетчатая мачта (уголковая сталь), наклонные раскосы,
# скоб-трап, верхняя площадка с обломанным леером, флюгер и чашечный анемометр с отломанной чашкой.
# Запуск: blender --background --python old_meteo_tower.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, tube, mat

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()

RUST_STEEL = mat("tower_rust", (0.24, 0.18, 0.14), rough=0.85, wear=0.85, dirt=0.7, wear_col=(0.48, 0.28, 0.18))
OLD_WOOD = mat("tower_wood", (0.32, 0.28, 0.24), rough=0.9, wear=0.6, dirt=0.8, wear_col=(0.45, 0.40, 0.35))
SNOW = mat("tower_snow", (0.88, 0.92, 0.96), rough=0.95, wear=0.0, dirt=0.0)

# Высота вышки ~3.8 м, основание 1.4х1.4 м, верхняя площадка 0.8х0.8 м
H = 3.8
BASE_W = 0.7   # полуширина снизу
TOP_W = 0.4    # полуширина сверху

# 4 наклонных угловых стойки (уголковая сталь)
corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
for cx, cy in corners:
    p_bot = (cx * BASE_W, cy * BASE_W, 0.0)
    p_top = (cx * TOP_W, cy * TOP_W, H)
    tube(f"leg_{cx}_{cy}", [p_bot, p_top], 0.035, RUST_STEEL, 4)
    # Бетонные пасынки / тумбы у основания
    box(f"shoe_{cx}_{cy}", (0.16, 0.16, 0.22), (cx * BASE_W, cy * BASE_W, 0.11), RUST_STEEL, 0.02)

# Горизонтальные пояса и крестовые раскосы (4 яруса по высоте)
tiers = [0.8, 1.7, 2.6, 3.4]
for t_idx, hz in enumerate(tiers):
    w = BASE_W + (TOP_W - BASE_W) * (hz / H)
    # 4 горизонтальные перекладины
    for side in range(4):
        c1 = corners[side]
        c2 = corners[(side + 1) % 4]
        tube(f"belt_{t_idx}_{side}", [(c1[0] * w, c1[1] * w, hz), (c2[0] * w, c2[1] * w, hz)], 0.022, RUST_STEEL, 4)
    # Диагональные раскосы (X) на каждой грани
    prev_z = 0.0 if t_idx == 0 else tiers[t_idx - 1]
    prev_w = BASE_W + (TOP_W - BASE_W) * (prev_z / H)
    for side in range(4):
        c1 = corners[side]
        c2 = corners[(side + 1) % 4]
        tube(f"brace1_{t_idx}_{side}", [(c1[0] * prev_w, c1[1] * prev_w, prev_z), (c2[0] * w, c2[1] * w, hz)], 0.016, RUST_STEEL, 4)
        tube(f"brace2_{t_idx}_{side}", [(c2[0] * prev_w, c2[1] * prev_w, prev_z), (c1[0] * w, c1[1] * w, hz)], 0.016, RUST_STEEL, 4)

# Лестница (скоб-трап) по одной из граней (cx = -1)
rungs = 12
for r in range(rungs):
    rz = 0.3 + r * (H - 0.5) / rungs
    rw = (BASE_W + (TOP_W - BASE_W) * (rz / H)) * 0.4
    tube(f"ladder_rung_{r}", [(-rw, -BASE_W * 0.95, rz), (rw, -BASE_W * 0.95, rz)], 0.012, RUST_STEEL, 4)

# Верхняя деревянная площадка (настил из серых досок с щелями)
box("plat_frame", (TOP_W * 2.2, TOP_W * 2.2, 0.05), (0, 0, H), RUST_STEEL, 0.01)
for p in range(5):
    py = -TOP_W + 0.08 + p * (TOP_W * 2.0 / 5.0)
    box(f"plat_plank_{p}", (TOP_W * 2.1, 0.14, 0.025), (0, py, H + 0.038), OLD_WOOD, 0.005)

# Частично сломанное ограждение площадки
tube("rail_post1", [(TOP_W, TOP_W, H), (TOP_W, TOP_W, H + 0.85)], 0.02, RUST_STEEL, 4)
tube("rail_post2", [(-TOP_W, TOP_W, H), (-TOP_W, TOP_W, H + 0.85)], 0.02, RUST_STEEL, 4)
tube("rail_post3", [(TOP_W, -TOP_W, H), (TOP_W, -TOP_W, H + 0.70)], 0.02, RUST_STEEL, 4)
# Погнутая перекладина
tube("rail_bar_bent", [(-TOP_W, TOP_W, H + 0.85), (TOP_W, TOP_W, H + 0.85), (TOP_W, -TOP_W * 0.3, H + 0.60)], 0.018, RUST_STEEL, 4)

# Центральная штанга приборов (анемометр и флюгер)
cyl("sensor_mast", 0.028, 1.2, (0, 0, H + 0.6), RUST_STEEL, verts=8)

# Сломанный флюгер (стрелка с перекошенным хвостом)
tube("vane_rod", [(-0.35, 0.08, H + 1.2), (0.28, -0.06, H + 1.15)], 0.014, RUST_STEEL, 4)
box("vane_tail", (0.008, 0.22, 0.16), (-0.35, 0.08, H + 1.2), RUST_STEEL, 0.004, rot=(0.2, 0, 0.4))

# Чашечный анемометр: 2 чашки целы, третья оторвана
cyl("anemo_cross", 0.01, 0.32, (0, 0, H + 0.95), RUST_STEEL, rot=(0, math.radians(90), 0), verts=6)
sphere("anemo_cup1", 0.038, (0.16, 0, H + 0.95), RUST_STEEL, segs=8, rings=6)
sphere("anemo_cup2", 0.038, (-0.16, 0, H + 0.95), RUST_STEEL, segs=8, rings=6)

# Снежные шапки на перекладинах площадки
box("snow_on_top", (TOP_W * 1.8, TOP_W * 1.8, 0.04), (0, 0, H + 0.06), SNOW, 0.01)

obj, img, tris = kit.finish("old_meteo_tower", OUT, res=1024, origin="bottom", samples=32)
kit.export(os.path.join(OUT, "old_meteo_tower.glb"), os.path.join(OUT, "old_meteo_tower.blend"))
print("[OK] Old meteo tower exported, tris:", tris)
