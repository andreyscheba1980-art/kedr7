import subprocess, sys, os, glob, shutil

BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
SCRIPTS = [
    "gtt_transporter.py",
    "kerosene_lamp.py",
    "fuel_canister.py",
    "soviet_kettle.py",
    "outhouse.py"
]
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.abspath(os.path.join(BASE_DIR, "..", "..", "assets", "models", "kedr"))

for s in SCRIPTS:
    py_path = os.path.join(BASE_DIR, s)
    print(f"=== BAKING {s} ===")
    cmd = [BLENDER, "--background", "--python", py_path, "--", OUT_DIR]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"ERROR in {s}:", res.stderr[-500:] if res.stderr else res.stdout[-500:])
    else:
        for line in res.stdout.splitlines():
            if "[OK]" in line or "tris" in line or "export" in line:
                print(line)

# Move .blend files to tools/blender
for f in glob.glob(os.path.join(OUT_DIR, "*.blend")):
    dest = os.path.join(BASE_DIR, os.path.basename(f))
    shutil.move(f, dest)
    print("Moved blend to:", dest)

print("ALL NEW MODELS BAKED SUCCESSFULLY!")
