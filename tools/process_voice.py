#!/usr/bin/env python3
"""Озвучка и звуки для «Кедр-7»: voice_src/ и sfx_src/ → assets/voice/ и assets/sfx/ (OGG + .import).

  python3 tools/process_voice.py            # из корня проекта; нужен ffmpeg

Обработка зависит от префикса имени файла (см. docs/ОЗВУЧКА_и_ЗВУКИ.md):
  ml_*, st_*, sem_log_*, num_*  — радио: полоса 300–3200 Гц, компрессия, лёгкий перегруз, шипение эфира
  call_*                        — то же радио, но голос ниже и медленнее: «это уже не они»
  door_*                        — из-за двери: глухо (НЧ-фильтр), короткое отражение сеней
  yrka_*                        — шёпот со спины: срез низа, двойное эхо тайги
  drv_*                         — улица у вездехода: чисто, только выравнивание громкости
  v_radio_prologue_hq*          — Управление в эфире: радио
  belov_*                       — Белов с «Таёжной-4»: радио, голос чуть выше
  v_th_*                        — мысли Виктора «про себя»: ближе, суше, лёгкое отражение
  v_*                           — живые реплики (кабина, комната): чисто
Дубли _a/_b/_c: берётся первый по алфавиту (обычно _a). Звуки sfx_src/<имя>_1.._N →
assets/sfx/<имя>.ogg, <имя>_v2.ogg, … (игра сама чередует варианты и чуть меняет высоту).
"""
import os, re, subprocess, sys, glob

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
VSRC, SSRC = os.path.join(ROOT, "voice_src"), os.path.join(ROOT, "sfx_src")
VOUT, SOUT = os.path.join(ROOT, "assets", "voice"), os.path.join(ROOT, "assets", "sfx")
EXT = (".mp3", ".wav", ".ogg", ".flac", ".m4a")

RADIO = ("highpass=f=300,lowpass=f=3200,acompressor=threshold=-20dB:ratio=4:attack=5:release=80,"
         "asoftclip=type=tanh:param=1.2,volume=2dB")
FILTERS = [
    ("call_", "asetrate=44100*0.94,aresample=44100," + RADIO, True),
    ("ml_", RADIO, True), ("st_", RADIO, True), ("sem_log_", RADIO, True), ("num_", RADIO, True),
    ("door_", "lowpass=f=1500,highpass=f=90,aecho=0.8:0.5:35:0.25", False),
    ("yrka_", "highpass=f=220,lowpass=f=6500,aecho=0.7:0.45:70|140:0.3|0.18", False),
    ("drv_", "highpass=f=80", False),
    ("v_radio_prologue_hq", RADIO, True),
    ("belov_", "asetrate=44100*1.06,aresample=44100," + RADIO, True),
    ("v_th_", "highpass=f=110,lowpass=f=7000,aecho=0.5:0.3:14:0.12", False),
    ("v_", "highpass=f=80", False),
]
IMPORT = """[remap]

importer="oggvorbisstr"
type="AudioStreamOggVorbis"

[deps]

source_file="res://assets/{sub}/{name}.ogg"

[params]

loop=false
loop_offset=0
bpm=0
beat_count=0
bar_beats=4
"""


def pick_sources(folder):
    """id → исходный файл; из дублей id_a / id_b берём первый."""
    by_id = {}
    for f in sorted(glob.glob(os.path.join(folder, "*"))):
        if not f.lower().endswith(EXT):
            continue
        base = os.path.splitext(os.path.basename(f))[0].strip().lower()
        if not re.fullmatch(r"[a-z0-9_]+", base):
            continue   # неназванные файлы (ElevenLabs_…) пропускаем — их сначала нужно назвать по списку
        vid = re.sub(r"_[a-z]$", "", base)
        by_id.setdefault(vid, f)
    return by_id


def encode(src, dst, af, noise):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    norm = "loudnorm=I=-19:TP=-2:LRA=9"
    if noise:
        fc = (f"[0:a]aformat=channel_layouts=mono,{af}[v];"
              "anoisesrc=c=pink:a=0.012:r=44100[n];"
              f"[v][n]amix=inputs=2:duration=first:normalize=0,{norm}[o]")
        cmd = ["ffmpeg", "-v", "error", "-y", "-i", src, "-filter_complex", fc, "-map", "[o]"]
    else:
        cmd = ["ffmpeg", "-v", "error", "-y", "-i", src, "-af", f"aformat=channel_layouts=mono,{af},{norm}"]
    cmd += ["-ar", "44100", "-ac", "1", "-c:a", "libvorbis", "-q:a", "4", dst]
    subprocess.run(cmd, check=True)


def write_import(dst, sub):
    # .import пишет сам Godot (с uid и path). Заготовка без них ломала импорт: файл считался
    # обработанным, но в .godot/imported не попадал — в билде пропадали голос и звуки.
    # Удаляем устаревшую заготовку, после скрипта нужен `godot --headless --import`.
    stub = dst + ".import"
    if os.path.exists(stub):
        with open(stub, encoding="utf-8") as f:
            if "\npath=" not in f.read():
                os.remove(stub)


def voices():
    n = 0
    for vid, src in pick_sources(VSRC).items():
        af, noise = "anull", False
        for pre, flt, nz in FILTERS:
            if vid.startswith(pre):
                af, noise = flt, nz
                break
        dst = os.path.join(VOUT, vid + ".ogg")
        encode(src, dst, af, noise)
        write_import(dst, "voice")
        n += 1
        print("voice", vid)
    return n


def sfx():
    n = 0
    groups = {}
    for vid, src in pick_sources(SSRC).items():
        m = re.match(r"(.+?)_(\d+)$", vid)
        base, idx = (m.group(1), int(m.group(2))) if m else (vid, 1)
        groups.setdefault(base, []).append((idx, src))
    for base, items in groups.items():
        for k, (_, src) in enumerate(sorted(items)):
            name = base if k == 0 else f"{base}_v{k + 1}"
            dst = os.path.join(SOUT, name + ".ogg")
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", src, "-af", "loudnorm=I=-20:TP=-2",
                            "-ar", "44100", "-ac", "1", "-c:a", "libvorbis", "-q:a", "4", dst], check=True)
            write_import(dst, "sfx")
            n += 1
        print("sfx", base, len(items))
    return n


if __name__ == "__main__":
    v = voices() if os.path.isdir(VSRC) else 0
    s = sfx() if os.path.isdir(SSRC) else 0
    print(f"готово: голосов {v}, звуков {s}. Открой проект в Godot — он сам импортирует новые файлы.")
