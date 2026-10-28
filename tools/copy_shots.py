import os
import shutil
import glob

appdata = os.environ.get("APPDATA", "")
base_godot = os.path.join(appdata, "Godot", "app_userdata")

for name in os.listdir(base_godot):
    full = os.path.join(base_godot, name)
    shots_dir = os.path.join(full, "shots")
    if os.path.isdir(shots_dir):
        print(f"Checking {shots_dir} (folder name: {name.encode('utf-8', errors='replace')})")
        files = glob.glob(os.path.join(shots_dir, "*.png"))
        print(f"Total pngs: {len(files)}")
        # Sort by modification time to see newest
        files.sort(key=lambda x: os.path.getmtime(x), reverse=True)
        dst_dir = r"C:\Users\andre\.gemini\antigravity-ide\brain\599a3df7-ecb5-4228-97af-0fb7b928e510"
        for f in files[:25]:
            base = os.path.basename(f)
            shutil.copy2(f, os.path.join(dst_dir, base))
            print("Copied newest:", base)
