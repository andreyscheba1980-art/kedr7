"""Обновляет project.godot: автозагрузки v0.3 и глобальные шейдерные параметры. Идемпотентно."""
import re, sys
path = sys.argv[1] if len(sys.argv) > 1 else "project.godot"
s = open(path, encoding="utf-8").read()
autoload = '''[autoload]

Settings="*res://scripts/autoload/settings.gd"
Loc="*res://scripts/autoload/loc.gd"
SaveGame="*res://scripts/autoload/save_game.gd"
EventBus="*res://scripts/autoload/event_bus.gd"
Game="*res://scripts/autoload/game.gd"
Director="*res://scripts/director/director.gd"
'''
globals_ = '''[shader_globals]

ps1_snap={
"type": "float",
"value": 140.0
}
ps1_post={
"type": "float",
"value": 1.0
}
brightness={
"type": "float",
"value": 1.0
}
'''
s = re.sub(r"\[autoload\]\n.*?(?=\n\[|\Z)", autoload, s, flags=re.S)
if "[shader_globals]" in s:
    s = re.sub(r"\[shader_globals\]\n.*?(?=\n\[|\Z)", globals_.rstrip("\n"), s, flags=re.S)
else:
    s = s.rstrip("\n") + "\n\n" + globals_
s = s.replace('config/description="Хоррор на радиометеостанции. Демо v0.1 (серые блоки)."', 'config/description="Хоррор на радиометеостанции. Демо v0.3."')
open(path, "w", encoding="utf-8").write(s)
print(s)
