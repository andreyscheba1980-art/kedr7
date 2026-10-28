# Динамо-фонарик «Жучок» для рук от первого лица: корпус + рычаг (отдельно, вращается на шарнире).
# Координаты — как у torch_root в fp_hands.gd, но в осях Блендера: Godot (x, y, z) = Blender (x, z, -y).
# Линза смотрит в +Y Блендера (в Godot это -Z, вперёд от игрока). Линзу (стекло) ставит игра.
# Запуск: python3 zhuchok.py <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, torus, text, tube, mat

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)


def materials():
    return dict(
        bakelite=mat("bakelite", (0.05, 0.04, 0.034), 0.35, 0, 0.12, 90, wear=0.25, dirt=0.35, wear_col=(0.16, 0.11, 0.07)),
        ribs=mat("ribs", (0.065, 0.052, 0.043), 0.4, 0, 0.1, 120, wear=0.5, dirt=0.3, wear_col=(0.2, 0.14, 0.09)),
        chrome=mat("chrome", (0.62, 0.63, 0.64), 0.25, 1.0, 0.08, 300, wear=0.3, dirt=0.4, wear_col=(0.42, 0.36, 0.28)),
        steel=mat("steel", (0.36, 0.37, 0.38), 0.45, 1.0, 0.15, 200, wear=0.3, dirt=0.45, wear_col=(0.6, 0.6, 0.6)),
        black=mat("black", (0.025, 0.025, 0.025), 0.6),
        reflector=mat("reflector", (0.75, 0.74, 0.7), 0.2, 1.0),
        cord=mat("cord", (0.09, 0.075, 0.06), 0.9, 0, 0.3, 400),
        plate=mat("plate", (0.6, 0.52, 0.32), 0.4, 0.8, 0.1, 200, wear=0.8, dirt=0.3, wear_col=(0.8, 0.72, 0.5)),
        emboss=mat("emboss", (0.78, 0.72, 0.52), 0.4, 0.8),
    )


# ---------------- Корпус ----------------
kit.reset()
M = materials()
CY = 0.06                                   # центр корпуса по Y (Godot z = -0.06)
# «Жук»: сплюснутый эллипсоид, чуть шире книзу
body = sphere("shell", 1.0, (0, CY, 0), M["bakelite"], scale=(0.03, 0.062, 0.036), segs=32, rings=18)
for v in body.data.vertices:                # спинка покатая, брюшко плоское
    if v.co.z < -0.022:
        v.co.z = -0.022 + (v.co.z + 0.022) * 0.35
# Шов между половинками корпуса
torus("seam", 1.0, 0.053, (0, CY, -0.004), M["ribs"], rot=(0, 0, 0), maj=48, mino=6)
seam = kit.objs[-1]
seam.scale = (0.0303, 0.0625, 0.03)
# Латунная табличка на правом боку (её видно игроку) с выпуклой надписью
box("badge", (0.0016, 0.034, 0.012), (0.0285, CY + 0.004, 0.006), M["plate"], 0.0006, rot=(0, math.radians(-14), 0))
text("ЖУЧОК", 0.0068, (0.0297, CY + 0.004, 0.0062), M["black"], 0.0003, rot=(math.pi / 2, math.radians(-14), math.pi / 2))
# Винты на боках
for sx in (-1, 1):
    for dy in (-0.025, 0.03):
        sxr = 0.03 * math.sqrt(1 - (dy / 0.062) ** 2 - (0.008 / 0.036) ** 2) - 0.0004
        cyl(f"screw{sx}{dy}", 0.0022, 0.0012, (sx * sxr, CY + dy, -0.008), M["steel"], rot=(0, math.pi / 2, 0), verts=10)
        box(f"slot{sx}{dy}", (0.0006, 0.0032, 0.0005), (sx * (sxr + 0.0006), CY + dy, -0.008), M["black"], 0)
# Хромированный ободок фары (ось вдоль +Y) и отражатель внутри
cyl("bezel", 0.0285, 0.018, (0, 0.12, 0.004), M["chrome"], rot=(-math.pi / 2, 0, 0), verts=32, bevel=0.0015, r2=0.0265)
torus("bezel_lip", 0.0272, 0.0022, (0, 0.1292, 0.004), M["chrome"], rot=(-math.pi / 2, 0, 0), maj=32, mino=8)
cyl("reflector", 0.0255, 0.012, (0, 0.124, 0.004), M["reflector"], rot=(-math.pi / 2, 0, 0), verts=32, r2=0.008)
# Шейка между корпусом и ободком
cyl("neck", 0.026, 0.014, (0, 0.108, 0.002), M["bakelite"], rot=(-math.pi / 2, 0, 0), verts=28, r2=0.028)
# Ушко шарнира рычага снизу у носа
box("hinge_lug", (0.016, 0.012, 0.01), (0, 0.105, -0.027), M["bakelite"], 0.002)
cyl("hinge_pin", 0.0028, 0.022, (0, 0.105, -0.03), M["steel"], rot=(0, math.pi / 2, 0), verts=12)
# Прорезь под рычаг на брюшке
box("lever_slot", (0.012, 0.07, 0.003), (0, 0.06, -0.0225), M["black"], 0.001)
# Петля для шнурка сзади и обрывок шнурка
torus("loop", 0.009, 0.0022, (0, -0.004, 0.0), M["steel"], rot=(0, math.pi / 2, 0), maj=20, mino=6)
tube("cord", [(0, -0.013, -0.002), (0.003, -0.022, -0.012), (-0.002, -0.028, -0.026), (0.003, -0.03, -0.045)], 0.002, M["cord"], 6)

body_obj, img, tris = kit.finish("zhuchok", OUT, res=1024, origin="keep", samples=48, ao_min=0.4)
kit.export(os.path.join(OUT, "zhuchok.glb"), os.path.join(OUT, "zhuchok.blend"))
print("OK body tris:", tris)

# ---------------- Рычаг (точка вращения = шарнир) ----------------
kit.reset()
M = materials()
# Рычаг уходит от шарнира назад (-Y) под брюшко; в Godot это +Z, как у старой модели
tube("arm", [(0, 0, 0), (0, -0.05, -0.006), (0, -0.1, -0.004)], 0.0045, M["steel"], 10)
cyl("knuckle", 0.0045, 0.014, (0, 0, 0), M["steel"], rot=(0, math.pi / 2, 0), verts=14)
# Накладка под пальцы из карболита с рифлением
box("pad", (0.022, 0.07, 0.0055), (0, -0.06, -0.009), M["bakelite"], 0.002)
for i in range(9):
    box(f"groove{i}", (0.0225, 0.0016, 0.0008), (0, -0.032 - i * 0.0068, -0.0116), M["black"], 0)
cyl("tip", 0.005, 0.004, (0, -0.1, -0.004), M["steel"], rot=(math.pi / 2, 0, 0), verts=12)
lever_obj, img2, tris2 = kit.finish("zhuchok_lever", OUT, res=256, origin="keep", samples=32, ao_min=0.45)
kit.export(os.path.join(OUT, "zhuchok_lever.glb"), os.path.join(OUT, "zhuchok_lever.blend"))
print("OK lever tris:", tris2)
