#!/usr/bin/env python3
"""Список реплик для озвучки сюжета 1.54–1.56 (сеансы связи, флешбэки Семёнова, находки дней, двойник на фарах).
Берёт русский текст из scripts/loc/story_strings.gd, чистит от «ЗОЯ: —», скобок-ремарок и пишет
tools/voice_jobs_156.csv:  файл;голос;текст;как читать
Имена файлов — с префиксами process_voice.py: rt_ (рация: Зоя/Михалыч), v_ (Виктор в микрофон, чисто),
v_th_ (мысли «про себя»), ml_ (эфир), door_ (из-за двери), yrka_ (шёпот со спины), call_ (не они).
  python tools/voice_jobs_156.py
"""
import os, re, csv

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SRC = os.path.join(ROOT, "scripts", "loc", "story_strings.gd")
OUT = os.path.join(ROOT, "tools", "voice_jobs_156.csv")

BS = chr(92)
q = '"((?:[^"' + BS + BS + ']|' + BS + BS + '.)*)"'
PAT = re.compile('&"([^"]+)":' + BS + 's*' + BS + '[' + BS + 's*' + q, re.S)

ZOYA = os.environ.get("ZOYA_VOICE", "ZOYA")      # женский голос — выберем по списку голосов аккаунта
MIKH, SEM, VIK, ML = "Georgy", "Egor T", "Sergey", "Dmitry"


def clean(t):
    t = t.replace(BS + '"', '"')
    t = re.sub(r"^[А-ЯЁ ()]+(?:\([^)]*\))?:\s*", "", t)   # «ЗОЯ: », «РАЦИЯ (голосом Семёнова): »
    t = t.strip().strip("—").strip()
    if t.startswith("(") and t.endswith(")"):
        t = t[1:-1]                                     # мысль целиком в скобках
    t = t.replace("«", "").replace("»", "").replace("Кедр-7", "Кедр-семь").replace("Кедр-семь", "Кедр-семь")
    # ремарки в скобках → теги ElevenLabs v3 (в v2 их просто уберём при генерации)
    t = re.sub(r"\((долгая пауза|пауза|долго молчит)\)", "[pause]", t)
    t = re.sub(r"\((тихо)\)", "[whispers]", t)
    t = re.sub(r"\(([^)]*)\)", "", t)
    return re.sub(r"\s+", " ", t).strip(" —")


def jobs(strings):
    out = []
    add = lambda f, v, k, how: out.append((f, v, clean(strings[k]), how))
    who_of = {0: MIKH, 1: ZOYA, 2: MIKH, 3: ZOYA, 4: MIKH, 5: ZOYA, 6: MIKH, 7: ZOYA}
    # Сеансы связи: реплики собеседника (через эфир) и ответы Виктора (в микрофон)
    for k in sorted(strings):
        m = re.fullmatch(r"t(\d)([ab]?)\.(l\d+h?|r\d|rs)", k)
        if m:
            n = int(m.group(1))
            how = "по рации, устало-тепло" if who_of[n] == ZOYA else "по рации, хрипло, с ленцой"
            if k == "t7.r2":
                how = "нормально, потом медленнее и ниже, слово тянется"
            add("rt_" + k.replace(".", "_"), who_of[n], k, how)
        m = re.fullmatch(r"t(\d)([ab]?)\.c\d", k)
        if m:
            add("v_" + k.replace(".", "_"), VIK, k, "Виктор в микрофон, коротко")
    add("v_talk_ask_dog", VIK, "talk.ask_dog", "кричит в метель")
    add("call_talk_dog_wrong", MIKH, "talk.dog_wrong", "голосом Михалыча, но пусто, после паузы")
    add("v_th_talk_dog_after", VIK, "talk.dog_after", "про себя, холодно")
    add("v_th_cov_trap_seen", VIK, "cov.trap_seen", "про себя")
    # Флешбэки: Семёнов про себя, голоса за дверью/в эфире/в наушниках
    for k in sorted(strings):
        if not re.fullmatch(r"fb\d\.(t\d|v\d)", k):
            continue
        txt = strings[k]
        if txt.startswith("СЕМЁНОВ:"):
            add("v_th_" + k.replace(".", "_"), SEM, k, "Семёнов про себя: тихо, устало, на грани")
        elif txt.startswith("РАЦИЯ (голосом Семёнова)"):
            add("ml_" + k.replace(".", "_"), SEM, k, "ровно, как чужой")
        elif txt.startswith("РАЦИЯ"):
            add("ml_" + k.replace(".", "_"), ML if k != "fb3.t1" else "Victoria", k, "эфир, казённо" if k != "fb3.t1" else "цифры, ровно")
        elif txt.startswith("ГОЛОС ЗА ДВЕРЬЮ"):
            add("door_" + k.replace(".", "_"), MIKH, k, "Брагин: старик, замёрзший, просит")
        elif txt.startswith("ШЁПОТ"):
            add("yrka_" + k.replace(".", "_"), VIK, k, "шёпот вплотную")
        elif txt.startswith("В НАУШНИКАХ"):
            add("ml_" + k.replace(".", "_"), VIK, k, "Орехов в эфире: сводка ровно; v2 — тише, ближе")
    # Находки дней: мысли Виктора (текст в скобках)
    for k in sorted(strings):
        if re.fullmatch(r"find\d\.[ab]", k) and strings[k].startswith("("):
            add("v_th_" + k.replace(".", "_"), VIK, k, "про себя")
    return out


def main():
    s = open(SRC, encoding="utf-8").read()
    strings = {m.group(1): m.group(2) for m in PAT.finditer(s)}
    rows = jobs(strings)
    with open(OUT, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter=";")
        w.writerow(["file", "voice", "text", "how"])
        w.writerows(rows)
    print("реплик:", len(rows), "->", OUT)
    by = {}
    for r in rows:
        by[r[1]] = by.get(r[1], 0) + 1
    print("по голосам:", by)


if __name__ == "__main__":
    main()
