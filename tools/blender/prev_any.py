# Превью-рендер: python3 prev_any.py <file.blend> <out.png> cx cy cz tx ty tz [lens] [extra.glb ox oy oz]
import bpy, sys, mathutils
a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
bpy.ops.wm.open_mainfile(filepath=a[0])
sc = bpy.context.scene
cam_p = mathutils.Vector(tuple(float(x) for x in a[2:5]))
tgt = mathutils.Vector(tuple(float(x) for x in a[5:8]))
lens = float(a[8]) if len(a) > 8 else 50
if len(a) > 12:
    bpy.ops.import_scene.gltf(filepath=a[9])
    for o in bpy.context.selected_objects:
        o.location = tuple(float(x) for x in a[10:13])
for o in list(sc.objects):
    if o.type in ("CAMERA", "LIGHT"):
        bpy.data.objects.remove(o)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam)
cam.location = cam_p
cam.rotation_euler = (tgt - cam_p).to_track_quat("-Z", "Y").to_euler()
cam.data.lens = lens; cam.data.clip_start = 0.005
sc.camera = cam
d = (tgt - cam_p).length
for n, off, e in [("k", (0.8, -1.0, 1.2), 300), ("f", (-1.2, -0.6, 0.5), 110), ("r", (0.3, 1.2, 0.8), 120)]:
    l = bpy.data.objects.new(n, bpy.data.lights.new(n, "POINT"))
    l.data.energy = e * d * d * 0.3; l.location = tgt + mathutils.Vector(off) * d
    sc.collection.objects.link(l)
sc.world = bpy.data.worlds.new("w")
nt = sc.world.node_tree
if nt:
    nt.nodes.clear()
    bg = nt.nodes.new("ShaderNodeBackground")
    bg.inputs[1].default_value = 0.25
    out = nt.nodes.new("ShaderNodeOutputWorld")
    nt.links.new(bg.outputs["Background"], out.inputs["Surface"])
sc.render.engine = "CYCLES"; sc.cycles.samples = 32; sc.cycles.device = "CPU"
sc.render.resolution_x = 900; sc.render.resolution_y = 600
import os
out_p = os.path.abspath(a[1])
os.makedirs(os.path.dirname(out_p), exist_ok=True)
sc.render.filepath = out_p
bpy.ops.render.render(write_still=True)
