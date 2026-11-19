#!/usr/bin/env python3
# Пакетная сборка новых и обновлённых low-poly моделей «Кедр-7» (Блок 1 + Блок 2 + Печь).
# Генерирует .glb + запечённые .png текстуры в assets/models/kedr/, а исходные .blend
# переносит в tools/blender/.
#
# Запуск из корня репозитория:
#   python3 tools/blender/bake_kedr_props.py
# Либо с явным путём до Blender:
#   BLENDER_BIN="C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" python tools/blender/bake_kedr_props.py

import glob
import os
import shutil
import subprocess
import sys

SCRIPTS = [
    "new_year_table.py",   # table_fir_jar.glb, ny_still_life.glb, samovar.glb
    "yard_buildings.py",   # outpost_stand.glb, doghouse.glb, ice_cellar.glb, ice_cellar_lid.glb, russian_stove.glb
    "outhouse.py",         # outhouse.glb (доски со щелями, петли, скоба, козырёк, снег)
    "stove.py",            # stove_brick.glb (чугунная варочная плита с конфорками и дверца ДТ-3)
]


def find_blender():
    env_bin = os.environ.get("BLENDER_BIN")
    if env_bin and os.path.isfile(env_bin):
        return env_bin
    candidates = [
        r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe",
        r"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe",
        r"C:\Program Files\Blender Foundation\Blender 5.0\blender.exe",
        r"C:\Program Files\Blender Foundation\Blender 4.4\blender.exe",
        r"C:\Program Files\Blender Foundation\Blender 4.3\blender.exe",
        r"C:\Program Files\Blender Foundation\Blender 4.2\blender.exe",
        "/Applications/Blender.app/Contents/MacOS/Blender",
    ]
    for path in candidates:
        if os.path.isfile(path):
            return path
    found = shutil.which("blender")
    if found:
        return found
    raise FileNotFoundError(
        "Blender не найден. Укажите путь в переменной окружения BLENDER_BIN "
        "или добавьте blender в PATH."
    )


def main():
    blender = find_blender()
    base_dir = os.path.dirname(os.path.abspath(__file__))
    out_dir = os.path.abspath(os.path.join(base_dir, "..", "..", "assets", "models", "kedr"))
    os.makedirs(out_dir, exist_ok=True)
    extra_args = sys.argv[1:]

    print(f"Blender: {blender}")
    print(f"Output : {out_dir}")

    failed = []
    for script in SCRIPTS:
        py_path = os.path.join(base_dir, script)
        print(f"\n=== BAKING {script} ===")
        cmd = [blender, "--background", "--factory-startup", "--python", py_path, "--", out_dir] + extra_args
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode != 0:
            print(f"[FAIL] {script} (exit {res.returncode}):")
            print((res.stderr or res.stdout)[-1200:])
            failed.append(script)
            continue
        for line in res.stdout.splitlines():
            if "[OK]" in line or "tris" in line or "UV_BOOST" in line:
                print(" ", line)

    for blend_path in glob.glob(os.path.join(out_dir, "*.blend")):
        dest = os.path.join(base_dir, os.path.basename(blend_path))
        shutil.move(blend_path, dest)
        print(f"Moved .blend -> {dest}")

    if failed:
        print("\nОшибки при сборке:", ", ".join(failed))
        sys.exit(1)
    print("\n[DONE] Все модели успешно запечены в assets/models/kedr/!")


if __name__ == "__main__":
    main()
