#!/usr/bin/env python3
"""Озвучка через ElevenLabs API: tools/voice_jobs_*.csv → voice_src/<file>_a.mp3 (и _b — второй дубль).
Ключ API — в файле .secrets/elevenlabs_key.txt (в .gitignore) или в переменной ELEVEN_API_KEY.
Голоса — по имени из твоего аккаунта (как в docs/ОЗВУЧКА_и_ЗВУКИ.md): Georgy, Sergey, Egor T, Dmitry, Victoria…
  python tools/tts_eleven.py --voices                    # список голосов аккаунта
  python tools/tts_eleven.py tools/voice_jobs_156.csv    # сгенерировать недостающее
  python tools/tts_eleven.py tools/voice_jobs_156.csv --only rt_t1_l1 --takes 2
  python tools/tts_eleven.py ... --map ZOYA="Имя голоса"  # подставить голос вместо метки
Потом: python tools/process_voice.py (радио, громкость, OGG, подключение в игру).
"""
import os, sys, csv, json, time, urllib.request, urllib.error

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "voice_src")
API = "https://api.elevenlabs.io/v1"
MODEL = os.environ.get("ELEVEN_MODEL", "eleven_multilingual_v2")
SETTINGS = {"stability": 0.4, "similarity_boost": 0.75, "style": 0.1, "use_speaker_boost": True}


def key():
    k = os.environ.get("ELEVEN_API_KEY", "").strip()
    p = os.path.join(ROOT, ".secrets", "elevenlabs_key.txt")
    if not k and os.path.exists(p):
        k = open(p, encoding="utf-8").read().strip()
    if not k:
        sys.exit("Нет ключа: положи его в .secrets/elevenlabs_key.txt или в ELEVEN_API_KEY")
    return k


def req(path, data=None, accept="application/json"):
    h = {"xi-api-key": key(), "Accept": accept}
    body = None
    if data is not None:
        body = json.dumps(data).encode("utf-8")
        h["Content-Type"] = "application/json"
    r = urllib.request.Request(API + path, data=body, headers=h, method="POST" if body else "GET")
    with urllib.request.urlopen(r, timeout=120) as resp:
        return resp.read()


def voices():
    js = json.loads(req("/voices"))
    return {v["name"]: v["voice_id"] for v in js.get("voices", [])}, js.get("voices", [])


def main():
    args = sys.argv[1:]
    if "--voices" in args:
        _, raw = voices()
        for v in raw:
            lab = v.get("labels") or {}
            print(f'{v["name"]:<32} {v["voice_id"]}  {lab.get("gender", "")} {lab.get("age", "")} {lab.get("accent", "")}')
        return
    csv_path = args[0]
    only = set(args[args.index("--only") + 1].split(",")) if "--only" in args else None
    takes = int(args[args.index("--takes") + 1]) if "--takes" in args else 1
    remap = {}
    for a in args:
        if "=" in a and not a.startswith("--"):
            k, v = a.split("=", 1)
            remap[k.strip()] = v.strip().strip('"')
    by_name, _ = voices()
    os.makedirs(OUT, exist_ok=True)
    rows = list(csv.DictReader(open(csv_path, encoding="utf-8"), delimiter=";"))
    done = fail = 0
    for r in rows:
        f, vname, text = r["file"], remap.get(r["voice"], r["voice"]), r["text"]
        if only and f not in only:
            continue
        vid = by_name.get(vname)
        if vid is None:
            print("нет голоса", vname, "для", f); fail += 1; continue
        if MODEL != "eleven_v3":
            text = text.replace("[pause]", "...").replace("[whispers]", "")
        for t in range(takes):
            dst = os.path.join(OUT, f"{f}_{'abc'[t]}.mp3")
            if os.path.exists(dst):
                continue
            payload = {"text": text, "model_id": MODEL, "voice_settings": dict(SETTINGS)}
            if f.startswith(("yrka_", "door_")) or "[whispers]" in r["text"]:
                payload["voice_settings"]["stability"] = 0.3
            for attempt in range(3):
                try:
                    audio = req(f"/text-to-speech/{vid}?output_format=mp3_44100_128", payload, "audio/mpeg")
                    open(dst, "wb").write(audio)
                    done += 1
                    print("ok", os.path.basename(dst), len(audio) // 1024, "КБ")
                    break
                except urllib.error.HTTPError as e:
                    msg = e.read().decode("utf-8", "replace")[:200]
                    print("ошибка", f, e.code, msg)
                    if e.code in (401, 402, 403):
                        sys.exit("ключ не принят или кончились кредиты")
                    time.sleep(3 + attempt * 5)
            else:
                fail += 1
    print(f"готово: {done}, не вышло: {fail}")


if __name__ == "__main__":
    main()
