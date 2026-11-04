# Генератор 3D-моделей для расширенных точек интереса (POI) и утренних последствий ночи («Кедр-7»).
# 1. soviet_snowmobile.glb — снегоход «Буран» Семёнова в овраге
# 2. hunting_trap.glb — кустарный волчий капкан №5 на цепи с серой ватой
# 3. expedition_tent.glb — заснеженная брезентовая палатка геологов 1974 г.
# 4. mansi_shrine.glb — мансийская оленья кормушка с тамгами и оберегами
# 5. chertov_finger.glb — базальтовый останец «Чёртов палец»
# 6. triangulation_tower.glb — деревянная пирамида-триангулятор
# 7. geology_shaft.glb — заброшенный шурф №7 с деревянной крепью
# 8. beacon_komar.glb — аварийный парашютный радиомаяк Р-855 «Комар»
# 9. siberian_sledge.glb — занесенные снегом охотничьи нарты с рогами
# 10. seismo_post.glb — сейсмо-пост №12 с защитным коробом
# 11. broken_window_plank.glb — фанерная заплатка для окна сеней
# 12. frozen_crow.glb — замерзший ворон на ступенях крыльца

import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, tube, mat

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)

def mats():
    return {
        "SNOW": mat("poi_snow", (0.88, 0.92, 0.95), rough=0.85, wear=0.2, dirt=0.15),
        "WOOD": mat("poi_tar_wood", (0.28, 0.20, 0.14), rough=0.75, wear=0.6, dirt=0.55, wear_col=(0.45, 0.35, 0.25)),
        "ROTTEN": mat("poi_rotten_wood", (0.22, 0.18, 0.15), rough=0.85, wear=0.7, dirt=0.6),
        "IRON": mat("poi_rust_iron", (0.22, 0.18, 0.16), rough=0.7, wear=0.7, dirt=0.6, wear_col=(0.45, 0.25, 0.15)),
        "ORANGE": mat("poi_paint_orange", (0.75, 0.35, 0.12), rough=0.5, wear=0.65, dirt=0.45, wear_col=(0.25, 0.22, 0.20)),
        "CANVAS": mat("poi_canvas", (0.42, 0.38, 0.30), rough=0.85, wear=0.5, dirt=0.55),
        "BASALT": mat("poi_basalt", (0.16, 0.17, 0.18), rough=0.8, wear=0.4, dirt=0.45, noise=0.15, noise_scale=45.0),
        "BRASS": mat("poi_brass", (0.68, 0.54, 0.22), rough=0.35, wear=0.5, dirt=0.35),
        "RUBBER": mat("poi_rubber", (0.12, 0.12, 0.12), rough=0.8, wear=0.4, dirt=0.3),
        "GLASS": mat("poi_glass", (0.80, 0.88, 0.90), rough=0.25, wear=0.5, dirt=0.2),
        "WADDING": mat("poi_wadding", (0.72, 0.70, 0.62), rough=0.9, wear=0.2, dirt=0.4),
        "FEATHER": mat("poi_feathers", (0.08, 0.08, 0.09), rough=0.65, wear=0.3, dirt=0.3),
        "PLYWOOD": mat("poi_plywood", (0.65, 0.52, 0.36), rough=0.7, wear=0.5, dirt=0.45),
        "ANTLER": mat("poi_antler", (0.75, 0.70, 0.58), rough=0.65, wear=0.4, dirt=0.4),
    }

def build_snowmobile():
    kit.reset()
    m = mats()
    box("track_frame", (0.55, 1.25, 0.28), (0, -0.25, 0.14), m["RUBBER"], bevel=0.01)
    for s in [-1, 1]:
        box(f"ski_{s}", (0.16, 1.10, 0.04), (s * 0.38, 0.90, 0.04), m["IRON"], bevel=0.005)
        tube(f"ski_tip_{s}", [(s * 0.38, 1.40, 0.04), (s * 0.38, 1.55, 0.18)], 0.02, m["IRON"], 6)
        cyl(f"ski_strut_{s}", 0.025, 0.30, (s * 0.38, 0.90, 0.22), m["IRON"], verts=8)
    box("chassis", (0.78, 1.80, 0.35), (0, 0.10, 0.35), m["IRON"], bevel=0.02)
    box("hood_base", (0.76, 0.85, 0.38), (0, 0.60, 0.62), m["ORANGE"], bevel=0.03)
    cyl("headlight", 0.08, 0.06, (0, 1.03, 0.70), m["GLASS"], rot=(math.radians(90), 0, 0), verts=10)
    box("windshield", (0.65, 0.02, 0.32), (0, 0.35, 0.95), m["GLASS"], bevel=0.005)
    tube("handlebar", [(-0.28, 0.28, 0.92), (0, 0.30, 0.95), (0.28, 0.28, 0.92)], 0.02, m["IRON"], 6)
    box("seat", (0.50, 0.90, 0.22), (0, -0.35, 0.62), m["RUBBER"], bevel=0.015)
    box("trunk_rack", (0.62, 0.40, 0.04), (0, -0.92, 0.54), m["IRON"], bevel=0.01)
    box("leather_case", (0.52, 0.32, 0.26), (0, -0.92, 0.68), m["WOOD"], bevel=0.015)
    box("snow_drift", (0.85, 0.95, 0.25), (0.1, -0.70, 0.45), m["SNOW"], bevel=0.04)

    kit.finish("soviet_snowmobile", OUT, res=512, origin="bottom", samples=16, ao_min=0.35)
    kit.export(os.path.join(OUT, "soviet_snowmobile.glb"), os.path.join(OUT, "soviet_snowmobile.blend"))

def build_hunting_trap():
    kit.reset()
    m = mats()
    cyl("log_trunk", 0.18, 1.80, (0, 0, 0.16), m["WOOD"], rot=(0, math.radians(90), 0), verts=10)
    cyl("trap_base", 0.16, 0.025, (0, 0, 0.35), m["IRON"], verts=14)
    tube("jaw_left", [(-0.14, -0.12, 0.36), (-0.14, 0, 0.50), (-0.14, 0.12, 0.36)], 0.016, m["IRON"], 6)
    tube("jaw_right", [(0.14, -0.12, 0.36), (0.14, 0, 0.50), (0.14, 0.12, 0.36)], 0.016, m["IRON"], 6)
    for i in range(-2, 3):
        box(f"tooth_l_{i}", (0.012, 0.012, 0.04), (-0.13, i * 0.045, 0.46), m["IRON"])
        box(f"tooth_r_{i}", (0.012, 0.012, 0.04), (0.13, i * 0.045, 0.46), m["IRON"])
    tube("clamped_branch", [(-0.25, -0.05, 0.42), (0, 0, 0.46), (0.28, 0.04, 0.44)], 0.022, m["WOOD"], 6)
    sphere("wadding_1", 0.045, (-0.02, 0.02, 0.47), m["WADDING"], segs=8, rings=6)
    sphere("wadding_2", 0.035, (0.05, -0.02, 0.48), m["WADDING"], segs=8, rings=6)
    tube("trap_chain", [
        (0, -0.16, 0.35), (-0.15, -0.22, 0.25), (-0.18, -0.15, 0.08),
        (0.0, -0.18, 0.02), (0.18, -0.15, 0.10), (0.15, -0.20, 0.25)
    ], 0.014, m["IRON"], 5)

    kit.finish("hunting_trap", OUT, res=512, origin="bottom", samples=16, ao_min=0.35)
    kit.export(os.path.join(OUT, "hunting_trap.glb"), os.path.join(OUT, "hunting_trap.blend"))

def build_expedition_tent():
    kit.reset()
    m = mats()
    tube("tent_ridge", [(0, -1.1, 1.25), (0, 1.1, 1.18)], 0.03, m["WOOD"], 6)
    cyl("pole_front", 0.025, 1.30, (0, 1.1, 0.65), m["WOOD"], verts=8)
    cyl("pole_back", 0.025, 1.25, (0, -1.1, 0.62), m["WOOD"], verts=8)
    box("tent_left_slope", (0.04, 2.2, 1.55), (-0.75, 0, 0.65), m["CANVAS"], rot=(0, 0, math.radians(-38)), bevel=0.01)
    box("tent_right_slope", (0.04, 2.2, 1.55), (0.75, 0, 0.65), m["CANVAS"], rot=(0, 0, math.radians(38)), bevel=0.01)
    box("drift_left", (0.9, 2.4, 0.45), (-1.1, 0.05, 0.22), m["SNOW"], bevel=0.05)
    box("flap_open", (0.45, 0.03, 0.8), (0.35, 1.15, 0.45), m["CANVAS"], rot=(0, math.radians(25), 0))
    cyl("pot", 0.11, 0.14, (-0.20, 0.85, 0.07), m["IRON"], verts=12)
    cyl("pot_handle", 0.008, 0.22, (-0.20, 0.85, 0.16), m["BRASS"], rot=(math.radians(90), 0, 0), verts=6)
    box("field_case", (0.24, 0.32, 0.05), (0.15, 0.82, 0.03), m["WOOD"], bevel=0.008)

    kit.finish("expedition_tent", OUT, res=512, origin="bottom", samples=16, ao_min=0.35)
    kit.export(os.path.join(OUT, "expedition_tent.glb"), os.path.join(OUT, "expedition_tent.blend"))

def build_mansi_shrine():
    kit.reset()
    m = mats()
    for sx in [-0.45, 0.45]:
        for sy in [-0.6, 0.6]:
            cyl(f"post_{sx}_{sy}", 0.065, 1.45, (sx, sy, 0.72), m["WOOD"], verts=8)
    box("trough_bottom", (0.85, 1.35, 0.08), (0, 0, 0.85), m["WOOD"], bevel=0.015)
    box("trough_side_l", (0.06, 1.35, 0.32), (-0.42, 0, 1.02), m["WOOD"], bevel=0.015)
    box("trough_side_r", (0.06, 1.35, 0.32), (0.42, 0, 1.02), m["WOOD"], bevel=0.015)
    box("trough_end_f", (0.85, 0.06, 0.32), (0, 0.65, 1.02), m["WOOD"], bevel=0.015)
    box("trough_end_b", (0.85, 0.06, 0.32), (0, -0.65, 1.02), m["WOOD"], bevel=0.015)
    tube("crossbeam", [(0, -0.75, 1.85), (0, 0.75, 1.85)], 0.045, m["WOOD"], 6)
    for idx, y_pos in enumerate([-0.4, 0.0, 0.4]):
        tube(f"cord_{idx}", [(0, y_pos, 1.85), (0, y_pos, 1.55)], 0.006, m["IRON"], 4)
        box(f"bark_talisman_{idx}", (0.08, 0.02, 0.16), (0, y_pos, 1.47), m["PLYWOOD"], bevel=0.005)
        cyl(f"feathers_{idx}", 0.025, 0.12, (0, y_pos, 1.33), m["FEATHER"], verts=6)
    box("tamga_1", (0.03, 0.015, 0.18), (0, 0.68, 1.05), m["IRON"])
    box("tamga_2", (0.12, 0.015, 0.03), (0, 0.68, 1.10), m["IRON"])

    kit.finish("mansi_shrine", OUT, res=512, origin="bottom", samples=16, ao_min=0.35)
    kit.export(os.path.join(OUT, "mansi_shrine.glb"), os.path.join(OUT, "mansi_shrine.blend"))

def build_chertov_finger():
    kit.reset()
    m = mats()
    cyl("pillar_base", 1.25, 0.8, (0, 0, 0.4), m["BASALT"], verts=10)
    cyl("pillar_mid", 0.95, 1.8, (0.05, -0.05, 1.6), m["BASALT"], verts=9)
    cyl("pillar_high", 0.68, 2.2, (-0.02, 0.08, 3.4), m["BASALT"], verts=8)
    cyl("pillar_top", 0.38, 1.4, (0.02, 0.02, 5.0), m["BASALT"], verts=7)
    box("ledge_1", (0.6, 0.45, 0.5), (0.65, 0.2, 2.1), m["BASALT"], bevel=0.03)
    box("ledge_2", (0.5, 0.55, 0.4), (-0.55, -0.3, 3.2), m["BASALT"], bevel=0.03)
    cyl("geodetic_marker", 0.07, 0.018, (0, 0.96, 1.55), m["BRASS"], rot=(math.radians(90), 0, 0), verts=12)
    box("snow_apron", (2.4, 2.4, 0.35), (0, 0, 0.15), m["SNOW"], bevel=0.08)

    kit.finish("chertov_finger", OUT, res=512, origin="bottom", samples=16, ao_min=0.35)
    kit.export(os.path.join(OUT, "chertov_finger.glb"), os.path.join(OUT, "chertov_finger.blend"))

def build_triangulation_tower():
    kit.reset()
    m = mats()
    h = 6.5
    w_base = 2.4
    w_top = 0.55
    for sx in [-1, 1]:
        for sy in [-1, 1]:
            p_bot = (sx * w_base * 0.5, sy * w_base * 0.5, 0)
            p_top = (sx * w_top * 0.5, sy * w_top * 0.5, h)
            tube(f"leg_{sx}_{sy}", [p_bot, p_top], 0.075, m["WOOD"], 6)
    for k in range(1, 4):
        y_frac = k / 4.0
        cur_h = h * y_frac
        cur_w = w_base * (1 - y_frac) + w_top * y_frac
        box(f"belt_x1_{k}", (cur_w, 0.07, 0.07), (0, cur_w * 0.5, cur_h), m["WOOD"])
        box(f"belt_x2_{k}", (cur_w, 0.07, 0.07), (0, -cur_w * 0.5, cur_h), m["WOOD"])
        box(f"belt_y1_{k}", (0.07, cur_w, 0.07), (cur_w * 0.5, 0, cur_h), m["WOOD"])
        box(f"belt_y2_{k}", (0.07, cur_w, 0.07), (-cur_w * 0.5, 0, cur_h), m["WOOD"])
    box("top_platform", (0.75, 0.75, 0.08), (0, 0, h), m["WOOD"], bevel=0.01)
    cyl("top_spire", 0.04, 1.2, (0, 0, h + 0.6), m["IRON"], verts=6)
    box("ammo_box", (0.35, 0.22, 0.16), (0.65, 0.55, 0.08), m["IRON"], bevel=0.008)
    for idx in range(3):
        cyl(f"flare_shell_{idx}", 0.018, 0.07, (0.58 + idx * 0.045, 0.52, 0.18), m["BRASS"], rot=(math.radians(90), 0, 0), verts=8)

    kit.finish("triangulation_tower", OUT, res=512, origin="bottom", samples=16, ao_min=0.35)
    kit.export(os.path.join(OUT, "triangulation_tower.glb"), os.path.join(OUT, "triangulation_tower.blend"))

def build_geology_shaft():
    kit.reset()
    m = mats()
    w = 2.0
    for z_layer in range(4):
        zh = 0.15 + z_layer * 0.22
        cyl(f"log_n_{z_layer}", 0.10, w + 0.3, (0, w * 0.5, zh), m["WOOD"], rot=(0, math.radians(90), 0), verts=8)
        cyl(f"log_s_{z_layer}", 0.10, w + 0.3, (0, -w * 0.5, zh), m["WOOD"], rot=(0, math.radians(90), 0), verts=8)
        cyl(f"log_w_{z_layer}", 0.10, w + 0.3, (-w * 0.5, 0, zh + 0.08), m["WOOD"], rot=(math.radians(90), 0, 0), verts=8)
        cyl(f"log_e_{z_layer}", 0.10, w + 0.3, (w * 0.5, 0, zh + 0.08), m["WOOD"], rot=(math.radians(90), 0, 0), verts=8)
    box("shaft_void", (w - 0.2, w - 0.2, 0.05), (0, 0, 0.10), m["RUBBER"])
    cyl("winch_post_l", 0.06, 1.3, (-w * 0.5, 0, 1.3), m["WOOD"], verts=8)
    cyl("winch_post_r", 0.06, 1.3, (w * 0.5, 0, 1.3), m["WOOD"], verts=8)
    cyl("winch_drum", 0.09, w, (0, 0, 1.7), m["IRON"], rot=(0, math.radians(90), 0), verts=10)
    tube("winch_handle", [(w * 0.5 + 0.08, 0, 1.7), (w * 0.5 + 0.22, 0, 1.7), (w * 0.5 + 0.22, 0.18, 1.7)], 0.02, m["IRON"], 6)

    kit.finish("geology_shaft", OUT, res=512, origin="bottom", samples=16, ao_min=0.35)
    kit.export(os.path.join(OUT, "geology_shaft.glb"), os.path.join(OUT, "geology_shaft.blend"))

def build_beacon_komar():
    kit.reset()
    m = mats()
    cyl("tree_trunk", 0.24, 3.2, (0, 0, 1.6), m["WOOD"], verts=9)
    tube("branch_1", [(0, 0, 2.2), (0.45, 0.35, 2.7)], 0.08, m["WOOD"], 6)
    tube("branch_2", [(0, 0, 2.4), (-0.40, 0.40, 2.85)], 0.07, m["WOOD"], 6)
    cyl("beacon_body", 0.065, 0.38, (0.15, 0.25, 2.4), m["ORANGE"], verts=10)
    cyl("beacon_cap", 0.07, 0.06, (0.15, 0.25, 2.62), m["IRON"], verts=10)
    tube("beacon_ant", [(0.15, 0.25, 2.65), (0.12, 0.28, 3.25)], 0.008, m["BRASS"], 5)
    box("parachute_cloth_1", (0.55, 0.45, 0.25), (0.22, 0.32, 2.8), m["ORANGE"], bevel=0.03)
    box("parachute_cloth_2", (0.48, 0.38, 0.22), (-0.18, 0.36, 2.9), m["SNOW"], bevel=0.03)
    for i in range(4):
        tube(f"cord_{i}", [(0.15, 0.25, 2.6), (-0.15 + i * 0.12, 0.35, 2.8)], 0.004, m["SNOW"], 4)

    kit.finish("beacon_komar", OUT, res=512, origin="bottom", samples=16, ao_min=0.35)
    kit.export(os.path.join(OUT, "beacon_komar.glb"), os.path.join(OUT, "beacon_komar.blend"))

def build_siberian_sledge():
    kit.reset()
    m = mats()
    for sx in [-0.35, 0.35]:
        box(f"runner_{sx}", (0.07, 2.2, 0.04), (sx, 0, 0.04), m["WOOD"], bevel=0.005)
        tube(f"runner_tip_{sx}", [(sx, 1.1, 0.04), (sx, 1.35, 0.25)], 0.025, m["WOOD"], 6)
    for sx in [-0.35, 0.35]:
        for y_pos in [-0.7, -0.2, 0.3, 0.8]:
            cyl(f"strut_{sx}_{y_pos}", 0.022, 0.35, (sx, y_pos, 0.22), m["WOOD"], verts=6)
    for idx, y_pos in enumerate([-0.8, -0.6, -0.4, -0.2, 0.0, 0.2, 0.4, 0.6, 0.8]):
        box(f"slat_{idx}", (0.78, 0.08, 0.025), (0, y_pos, 0.40), m["WOOD"], bevel=0.003)
    tube("antler_l", [(-0.15, 0, 0.45), (-0.35, -0.2, 0.65), (-0.55, -0.15, 0.85)], 0.02, m["ANTLER"], 6)
    tube("antler_r", [(0.15, 0, 0.45), (0.35, -0.2, 0.65), (0.55, -0.15, 0.85)], 0.02, m["ANTLER"], 6)
    tube("antler_branch_1", [(-0.35, -0.2, 0.65), (-0.45, -0.4, 0.72)], 0.014, m["ANTLER"], 5)
    tube("antler_branch_2", [(0.35, -0.2, 0.65), (0.45, -0.4, 0.72)], 0.014, m["ANTLER"], 5)
    box("sledge_snow", (0.85, 0.95, 0.20), (0.1, -0.5, 0.48), m["SNOW"], bevel=0.03)

    kit.finish("siberian_sledge", OUT, res=512, origin="bottom", samples=16, ao_min=0.35)
    kit.export(os.path.join(OUT, "siberian_sledge.glb"), os.path.join(OUT, "siberian_sledge.blend"))

def build_seismo_post():
    kit.reset()
    m = mats()
    box("granite_slab", (1.2, 1.2, 0.35), (0, 0, 0.175), m["BASALT"], bevel=0.02)
    box("hut_wall_l", (0.06, 0.95, 0.65), (-0.45, 0, 0.68), m["WOOD"], bevel=0.01)
    box("hut_wall_r", (0.06, 0.95, 0.65), (0.45, 0, 0.68), m["WOOD"], bevel=0.01)
    box("hut_wall_b", (0.90, 0.06, 0.65), (0, -0.45, 0.68), m["WOOD"], bevel=0.01)
    box("hut_door", (0.42, 0.04, 0.62), (0.28, 0.48, 0.68), m["WOOD"], rot=(0, math.radians(45), 0), bevel=0.01)
    box("roof_slope_l", (0.04, 1.05, 0.65), (-0.32, 0, 1.15), m["WOOD"], rot=(0, 0, math.radians(-35)), bevel=0.01)
    box("roof_slope_r", (0.04, 1.05, 0.65), (0.32, 0, 1.15), m["WOOD"], rot=(0, 0, math.radians(35)), bevel=0.01)
    cyl("seismo_base", 0.18, 0.05, (0, 0, 0.375), m["IRON"], verts=10)
    cyl("seismo_pillar", 0.03, 0.38, (0, -0.10, 0.58), m["IRON"], verts=8)
    cyl("seismo_mass", 0.08, 0.12, (0, 0.06, 0.56), m["IRON"], rot=(math.radians(90), 0, 0), verts=10)
    tube("seismo_boom", [(0, -0.10, 0.68), (0, 0.18, 0.52)], 0.012, m["BRASS"], 5)

    kit.finish("seismo_post", OUT, res=512, origin="bottom", samples=16, ao_min=0.35)
    kit.export(os.path.join(OUT, "seismo_post.glb"), os.path.join(OUT, "seismo_post.blend"))

def build_aftermath_props():
    kit.reset()
    m = mats()
    box("plywood_board", (0.68, 0.025, 0.88), (0, 0, 0.44), m["PLYWOOD"], bevel=0.005)
    for gx in [-0.28, 0.28]:
        for gz in [0.12, 0.76]:
            cyl(f"nail_{gx}_{gz}", 0.008, 0.018, (gx, 0.018, gz), m["IRON"], rot=(math.radians(90), 0, 0), verts=6)
    kit.finish("broken_window_plank", OUT, res=256, origin="bottom", samples=16, ao_min=0.35)
    kit.export(os.path.join(OUT, "broken_window_plank.glb"), os.path.join(OUT, "broken_window_plank.blend"))

    kit.reset()
    m = mats()
    sphere("crow_body", 0.09, (0, 0, 0.08), m["FEATHER"], segs=8, rings=6)
    sphere("crow_head", 0.055, (0, 0.13, 0.07), m["FEATHER"], segs=8, rings=6)
    tube("crow_beak", [(0, 0.16, 0.07), (0, 0.24, 0.05)], 0.012, m["IRON"], 4)
    box("crow_wing_l", (0.03, 0.22, 0.08), (-0.08, -0.02, 0.08), m["FEATHER"], rot=(0, 0, math.radians(-20)))
    box("crow_wing_r", (0.03, 0.22, 0.08), (0.08, -0.02, 0.08), m["FEATHER"], rot=(0, 0, math.radians(20)))
    tube("crow_leg_l", [(-0.04, -0.04, 0.10), (-0.04, -0.04, 0.19)], 0.006, m["IRON"], 4)
    tube("crow_leg_r", [(0.04, -0.04, 0.10), (0.04, -0.04, 0.19)], 0.006, m["IRON"], 4)
    kit.finish("frozen_crow", OUT, res=256, origin="bottom", samples=16, ao_min=0.35)
    kit.export(os.path.join(OUT, "frozen_crow.glb"), os.path.join(OUT, "frozen_crow.blend"))

if __name__ == "__main__":
    print("[RUN] Генерация POI и предметов утреннего осмотра...")
    build_snowmobile()
    build_hunting_trap()
    build_expedition_tent()
    build_mansi_shrine()
    build_chertov_finger()
    build_triangulation_tower()
    build_geology_shaft()
    build_beacon_komar()
    build_siberian_sledge()
    build_seismo_post()
    build_aftermath_props()
    print("[ALL DONE] Все 12 моделей сгенерированы и запечены.")
