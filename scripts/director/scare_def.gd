class_name ScareDef
extends Resource
## Описание одного испуга. Директор выбирает испуги по этим данным,
## а сама постановка живёт в event_script (наследник ScareEvent).

enum Type { HARD, SOFT, AUDIO, FAKE }

@export var id: StringName
@export var creature: StringName = &"none"
@export var type: Type = Type.SOFT
@export var event_script: GDScript

@export_group("Когда может сработать")
@export var nights := Vector2i(1, 7)
@export var zones: Array[StringName] = []        ## пусто = в любой зоне
@export var activities: Array[StringName] = []   ## пусто = при любом занятии
@export var requires_dark := false
@export var min_tension := 50.0
@export var min_fatigue := 0.0                   ## галлюцинации — только при скрытой усталости

@export_group("Выбор и последствия")
@export var weight := 1.0
@export var max_per_run := 1                     ## 0 = без ограничения
@export var tension_release := 50.0
@export var cooldown_sec := 40.0

@export_group("Обязательный бит")
@export var is_beat := false
@export var beat_from_min := 0                   ## минуты от начала смены (20:00)
@export var beat_to_min := 0


func fits_night(n: int) -> bool:
	return n >= nights.x and n <= nights.y


func matches(ctx: ScareContext) -> bool:
	if not zones.is_empty() and not zones.has(ctx.zone):
		return false
	if not activities.is_empty() and not activities.has(ctx.activity):
		return false
	if requires_dark and not ctx.dark:
		return false
	if ctx.fatigue < min_fatigue:
		return false
	return true


static func type_name(t: int) -> String:
	match t:
		Type.HARD:
			return "HARD"
		Type.SOFT:
			return "SOFT"
		Type.AUDIO:
			return "AUDIO"
		Type.FAKE:
			return "FAKE"
	return "?"
