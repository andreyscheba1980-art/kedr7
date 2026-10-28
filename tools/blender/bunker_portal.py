# Капонир-вход в бункер «Отзвук»: бетонный блок с фаской под снежной обсыпкой, плита, круглый стальной
# люк со штурвалом и петлёй, скобы-лестница, трафарет, ржавые потёки. Габарит под коллизию yard.gd
# (3.5×1.4×3.5, люк сверху на высоте ~1.35). Ставится через Props.bunker_caponier_portal (_kedr_model).
# Запуск: blender --background --python bunker_portal.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit, ugms
from ugms import box, cyl, text

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()
M = ugms.mats()
M["conc"] = ugms.painted("b_conc", (0.47, 0.47, 0.45), under=(0.36, 0.33, 0.30), peel=0.2, scale=2.0, grain=0.25, detail=10)
M["steel"] = kit.mat("b_steel", (0.22, 0.24, 0.23), rough=0.5, wear=0.8, wear_col=(0.46, 0.27, 0.14), dirt=0.6)
M["stencil"] = kit.mat("b_sten", (0.12, 0.12, 0.12), rough=0.8)
M["earth"] = kit.mat("b_earth", (0.58, 0.64, 0.72), rough=0.8, noise=0.08, noise_scale=4)   # тон местного снега, не белый

# Бетонный блок с фаской и верхней плитой
box((0, 0.6, 0), (3.3, 1.2, 3.3), M["conc"], bevel=0.12)
box((0, 1.25, 0), (2.4, 0.14, 2.4), M["conc"], bevel=0.04)
# Обсыпка — намёты SiteDressing.bunker в движке (того же тона, что весь снег), не в модели
# Люк: кольцо-комингс, крышка, штурвал, петля, запор
cyl((0, 1.36, 0), 0.55, 0.12, M["steel"], verts=20)
cyl((0, 1.43, 0), 0.5, 0.05, M["steel"], verts=20)
cyl((0, 1.5, 0), 0.24, 0.03, M["steel"], verts=16)
for a in range(4):
    ang = a * math.pi / 4
    box((0, 1.5, 0), (0.5, 0.03, 0.03), M["steel"], yaw=ang)
box((0, 1.4, -0.58), (0.3, 0.1, 0.12), M["steel"])
box((0.55, 1.42, 0), (0.12, 0.08, 0.2), M["steel"])
# Скобы-ступени на южной грани
for i in range(4):
    y = 0.25 + i * 0.28
    box((0, y, 1.68), (0.4, 0.03, 0.03), M["steel"])
    for dx in (-0.19, 0.19):
        box((dx, y, 1.66), (0.03, 0.03, 0.06), M["steel"])
# Трафарет на бетоне и ржавые потёки под люком
text("ОБ. 17", 0.18, (-0.7, 0.75, 1.66), M["stencil"])
text("НЕ ОТКРЫВАТЬ", 0.09, (0.75, 0.45, 1.66), M["stencil"])
M["rust"] = kit.mat("b_rust", (0.30, 0.18, 0.11), rough=0.9)
for dx in (-1.25, 1.35):
    box((dx, 0.9, 1.655), (0.025, 0.45, 0.004), M["rust"])
# Вентиляционный патрубок с колпаком
cyl((1.1, 1.6, -0.9), 0.08, 0.6, M["steel"], verts=10)
cyl((1.1, 1.92, -0.9), 0.16, 0.06, M["steel"], verts=10, r2=0.06)

obj, img, tris = kit.finish("bunker_portal", OUT, res=1024, origin="bottom", samples=32, pack=0.003, ao_blur=2)
kit.export(os.path.join(OUT, "bunker_portal.glb"), None)
print(f"[OK] bunker_portal: {tris} tris")
