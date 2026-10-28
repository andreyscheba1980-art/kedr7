# Ограда метеоплощадки «Кедр-7» 26×26 м: белёные столбы через 2 м, три жерди, калитка на западе
# (проём у Yard.M_GATE), столбы калитки с перекладиной. Коллизии столбов — в yard.gd.
# Запуск: blender --background --python meteo_fence.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit, ugms
from ugms import box

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()
M = ugms.mats()

MX, MZ, H = 98.0, -30.0, 13.0
GATE = (MX - 13.0, MZ)        # центр проёма калитки
corners = [(-H, -H), (H, -H), (H, H), (-H, H)]
per = int(2 * H / 2.0)
for side in range(4):
    a, b = corners[side], corners[(side + 1) % 4]
    for i in range(per):
        k0, k1 = i / per, (i + 1) / per
        px, pz = MX + a[0] + (b[0] - a[0]) * k0, MZ + a[1] + (b[1] - a[1]) * k0
        qx, qz = MX + a[0] + (b[0] - a[0]) * k1, MZ + a[1] + (b[1] - a[1]) * k1
        if math.hypot(px - GATE[0], pz - GATE[1]) < 0.9:
            continue
        box((px, 0.6, pz), (0.09, 1.2, 0.09), M["white"])
        box((px, 1.23, pz), (0.12, 0.05, 0.12), M["snow"])
        mx, mz = (px + qx) / 2, (pz + qz) / 2
        if math.hypot(mx - GATE[0], mz - GATE[1]) < 1.2:
            continue
        L = math.hypot(qx - px, qz - pz)
        yaw = math.atan2(qx - px, qz - pz)
        for y in (0.3, 0.7, 1.1):
            box((mx, y, mz), (0.04, 0.07, L), M["white"], yaw=yaw)
        box((mx, 1.155, mz), (0.07, 0.03, L), M["snow"], yaw=yaw)
# Калитка: высокие столбы с перекладиной
for dz in (-1.0, 1.0):
    box((GATE[0], 1.0, GATE[1] + dz), (0.12, 2.0, 0.12), M["white"])
box((GATE[0], 2.05, GATE[1]), (0.1, 0.12, 2.24), M["white"])
box((GATE[0], 2.13, GATE[1]), (0.14, 0.05, 2.3), M["snow"])

obj, img, tris = kit.finish("meteo_fence", OUT, res=1024, origin="keep", samples=24, pack=0.003, ao_blur=2)
kit.export(os.path.join(OUT, "meteo_fence.glb"), None)
print(f"[OK] meteo_fence: {tris} tris")
