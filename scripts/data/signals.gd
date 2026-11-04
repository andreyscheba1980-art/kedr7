class_name Signals
extends RefCounted
## Сигналы эфира. Какие из них звучат в конкретную ночь — Phases.NIGHTS[n]["signals"].
##
## lines — ключи субтитров, пока сигнал слышен. tape — что окажется на плёнке:
##   hidden.band — полоса (Гц), в которой при чистке проступает скрытое;
##   hidden.image — картинка на спектрограмме, hidden.text — ключ строки, scare — удар при раскрытии.

const DATA := {
	&"mainland": {
		"freq": 6880.0, "width": 20.0, "stream": "res://assets/audio/carrier_loop.ogg",
		"lines": [&"sig.mainland.1"], "recordable": false,
	},
	&"buzzer": {
		"freq": 4625.0, "width": 18.0, "stream": "res://assets/audio/buzzer_loop.ogg",
		"lines": [&"sig.buzzer.1"], "recordable": true,
		"tape": {"hidden": {"band": Vector2(250.0, 700.0), "image": "res://assets/textures/hidden_scheme.png", "text": &"hid.buzzer"}},
	},
	&"numbers": {
		"freq": 5310.0, "width": 14.0, "stream": "res://assets/audio/numbers_loop.ogg",
		"lines": [&"sig.numbers.1", &"sig.numbers.2", &"sig.numbers.3"], "recordable": true,
		"tape": {"hidden": {"band": Vector2(1700.0, 2500.0), "image": "res://assets/textures/hidden_numbers.png", "text": &"hid.numbers"}},
	},
	&"semenov": {
		"freq": 7713.0, "width": 10.0, "stream": "res://assets/audio/voice_loop.ogg",
		"lines": [&"sig.semenov.1", &"sig.semenov.2", &"sig.semenov.3"], "recordable": true,
		"tape": {"hidden": {"band": Vector2(300.0, 900.0), "image": "res://assets/textures/face_flash.png", "text": &"hid.semenov", "scare": true}},
	},
	&"morse": {
		"freq": 3870.0, "width": 12.0, "stream": "res://assets/audio/morse_loop.ogg",
		"lines": [&"sig.morse.1"], "recordable": true,
		"tape": {"hidden": {"band": Vector2(600.0, 1000.0), "image": "", "text": &"hid.morse"}},
	},
	&"code": {
		"freq": 5480.0, "width": 14.0, "stream": "res://assets/audio/numbers_loop.ogg",
		"lines": [&"sig.code.1"], "recordable": true, "decodable": true,
	},
	&"lullaby": {
		"freq": 8320.0, "width": 10.0, "stream": "res://assets/audio/lullaby_loop.ogg",
		"lines": [&"sig.lullaby.1"], "recordable": true,
		"tape": {"hidden": {"band": Vector2(1900.0, 3100.0), "image": "", "text": &"hid.lullaby"}},
	},
	&"mother": {
		"freq": 3410.0, "width": 12.0, "stream": "res://assets/audio/mother_loop.ogg",
		"lines": [&"sig.mother.1", &"sig.mother.2", &"sig.mother.3"], "recordable": true,
		"tape": {"hidden": {"band": Vector2(150.0, 450.0), "image": "res://assets/textures/hidden_door.png", "text": &"hid.mother"}},
	},
	&"roll": {
		"freq": 6240.0, "width": 14.0, "stream": "res://assets/audio/roll_loop.ogg",
		"lines": [&"sig.roll.1", &"sig.roll.2", &"sig.roll.3"], "recordable": true,
		"tape": {"hidden": {"band": Vector2(1300.0, 2100.0), "image": "res://assets/textures/hidden_roll.png", "text": &"hid.roll"}},
	},
	&"otzvuk": {
		"freq": 4990.0, "width": 12.0, "stream": "res://assets/audio/otzvuk_loop.ogg",
		"lines": [&"sig.otzvuk.1"], "recordable": true,
		"tape": {"hidden": {"band": Vector2(60.0, 260.0), "image": "res://assets/textures/hidden_bunker.png", "text": &"hid.otzvuk", "scare": true}},
	},
	## Бобина из проруби (день 4): Семёнов записал удар 03:10 на льду. В эфире не звучит — только на плёнке.
	## При чистке проступает распадок — пеленг от проруби (TapeDeckUI._reveal → FieldJobs).
	&"rec0310": {
		"freq": 0.0, "width": 0.0, "stream": "res://assets/audio/otzvuk_loop.ogg",
		"lines": [&"sig.rec0310.1", &"sig.rec0310.2"], "recordable": false,
		"tape": {"hidden": {"band": Vector2(400.0, 900.0), "image": "res://assets/textures/hidden_ravine.png", "text": &"hid.ravine"}},
	},
	## Полевой дневник геофизика Дубова (найден на заброшенном посте РЛС на сопке)
	&"tape_field": {
		"freq": 0.0, "width": 0.0, "stream": "res://assets/audio/voice_mainland.ogg",
		"lines": [&"sig.tape_field.1", &"sig.tape_field.2", &"sig.tape_field.3"], "recordable": false,
		"tape": {"hidden": {"band": Vector2(300.0, 800.0), "image": "res://assets/textures/hidden_ravine.png", "text": &"hid.tape_field"}},
	},
	## Архив объекта «Отзвук» (найден в подземном бункере ГО)
	&"tape_bunker": {
		"freq": 0.0, "width": 0.0, "stream": "res://assets/audio/otzvuk_loop.ogg",
		"lines": [&"sig.tape_bunker.1", &"sig.tape_bunker.2", &"sig.tape_bunker.3"], "recordable": false,
		"tape": {"hidden": {"band": Vector2(100.0, 450.0), "image": "res://assets/textures/hidden_bunker.png", "text": &"hid.tape_bunker", "scare": true}},
	},
	## Сигналы заданий: частоту назначает NightTasks на ночь.
	&"beacon": {
		"freq": 0.0, "width": 9.0, "stream": "res://assets/audio/beacon_loop.ogg",
		"lines": [&"sig.beacon.1"], "recordable": false,
	},
	&"control": {
		"freq": 0.0, "width": 12.0, "stream": "res://assets/audio/numbers_loop.ogg",
		"lines": [&"sig.control.1"], "recordable": false,
	},
	&"old_call": {
		"freq": 0.0, "width": 12.0, "stream": "res://assets/audio/voice_loop.ogg",
		"lines": [&"sig.old_call.1", &"sig.old_call.2"], "recordable": false,
	},
	## Ночь 7, 4170 кГц («417» с плёнки цифровой станции): твой собственный голос. Секретная концовка.
	&"echo": {
		"freq": 4170.0, "width": 10.0, "stream": "res://assets/audio/echo_loop.ogg",
		"lines": [&"sig.echo.1", &"sig.echo.2", &"sig.echo.3", &"sig.echo.4"], "recordable": false,
	},
	## Аномальная сводка: «Виктор находится один...»
	&"alone": {
		"freq": 5210.0, "width": 14.0, "stream": "res://assets/audio/radio_anomaly.ogg",
		"lines": [&"sig.alone"], "recordable": true,
	},
	## Дневной эфир (Daytime Dread): метроном, обрывки радиоспектакля 50-х, переговоры геологов
	&"day_metronome": {
		"freq": 4220.0, "width": 14.0, "stream": "res://assets/audio/clock_tick.ogg",
		"lines": [&"sig.day_metronome"], "recordable": true,
		"tape": {"hidden": {"band": Vector2(100.0, 500.0), "image": "", "text": &"hid.metronome"}},
	},
	&"day_radioplay": {
		"freq": 5840.0, "width": 16.0, "stream": "res://assets/audio/voice_loop.ogg",
		"lines": [&"sig.day_radioplay.1", &"sig.day_radioplay.2"], "recordable": true,
		"tape": {"hidden": {"band": Vector2(600.0, 1400.0), "image": "", "text": &"hid.radioplay"}},
	},
	&"day_geologists": {
		"freq": 7310.0, "width": 14.0, "stream": "res://assets/audio/voice_mainland.ogg",
		"lines": [&"sig.day_geologists.1", &"sig.day_geologists.2", &"sig.day_geologists.3"], "recordable": true,
		"tape": {"hidden": {"band": Vector2(400.0, 1000.0), "image": "res://assets/textures/hidden_bunker.png", "text": &"hid.geologists"}},
	},
}

## Шифр для цифровой станции ночи 3. Таблица «буква → две цифры» — в шифроблокноте Семёнова.
const CODE_WORD := {"ru": "НЕОТКРЫВАЙ", "en": "DONTOPEN"}
const ALPHABET := {"ru": "АБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЫЬЭЮЯ", "en": "ABCDEFGHIJKLMNOPQRSTUVWXYZ"}


## Свободна ли частота: не ближе gap кГц к постоянным сигналам (сюжетным и Большой Земле).
static func is_free(f: float, gap := 60.0) -> bool:
	for id: StringName in DATA:
		var sf := float((DATA[id] as Dictionary).get("freq", 0.0))
		if sf > 0.0 and absf(sf - f) < gap:
			return false
	return absf(f - BC_STATIONS) >= gap and absf(f - BC_DIARY) >= gap and absf(f - BC_BELOV) >= gap


## Эфирная сетка: передачи, которые меняются от ночи к ночи на постоянных частотах.
## 7140 кГц — соседние станции (сначала живут, потом замолкают, в конце кто-то передаёт за тебя).
## 3950 кГц — дневник Семёнова: по записи в ночь. Голос — Voice.path(voice), иначе общий «голос в эфире».
## 3820 кГц — партия Белова («Таёжная-4», геологи в 40 км к северу: сеансы связи в 14:00 и 21:00).
const BC_STATIONS := 7140.0
const BC_DIARY := 3950.0
const BC_BELOV := 3820.0
const BROADCAST := {
	1: [[&"bc_st_1", BC_STATIONS, &"st_sosna_1"], [&"bc_sem_1", BC_DIARY, &"sem_log_1"], [&"bc_belov_1", BC_BELOV, &"belov_1"]],
	2: [[&"bc_st_2", BC_STATIONS, &"st_bereza_1"], [&"bc_sem_2", BC_DIARY, &"sem_log_2"], [&"bc_belov_2", BC_BELOV, &"belov_2"]],
	3: [[&"bc_st_3", BC_STATIONS, &"st_sosna_2"], [&"bc_sem_3", BC_DIARY, &"sem_log_3"], [&"bc_belov_3", BC_BELOV, &"belov_3"]],
	4: [[&"bc_st_4", BC_STATIONS, &"st_bereza_2"], [&"bc_sem_4", BC_DIARY, &"sem_log_4"], [&"bc_belov_4", BC_BELOV, &"belov_4"]],
	5: [[&"bc_st_5", BC_STATIONS, &"st_sosna_3"], [&"bc_sem_5", BC_DIARY, &"sem_log_5"], [&"bc_belov_5", BC_BELOV, &"belov_5"]],
	6: [[&"bc_st_6", BC_STATIONS, &"st_kedr7_fake"], [&"bc_sem_6", BC_DIARY, &"sem_log_6"]],
}
const BC_FALLBACK_STREAM := "res://assets/audio/voice_loop.ogg"

static var _bc_defs: Dictionary = {}


## Порядок передач для журнала перехватов.
static func broadcast_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for n in range(1, 7):
		for e: Array in BROADCAST.get(n, []):
			out.append(e[0])
	return out


## Передачи, которые идут в эту ночь.
static func broadcast_for_night(n: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for e: Array in BROADCAST.get(n, []):
		out.append(e[0])
	return out


## Передачи, которые идут в этот день (сеансы связи геологов Белова + дневной эфир).
static func broadcast_for_day(d: int) -> Array[StringName]:
	var out: Array[StringName] = [&"day_metronome", &"day_radioplay", &"day_geologists"]
	for e: Array in BROADCAST.get(d, []):
		if String(e[0]).begins_with("bc_belov_"):
			out.append(e[0])
	return out


static func _broadcast_def(id: StringName) -> Dictionary:
	if _bc_defs.has(id):
		return _bc_defs[id]
	for n in BROADCAST:
		for e: Array in BROADCAST[n]:
			if e[0] == id:
				var voice: StringName = e[2]
				var vp := Voice.path(voice)
				var d := {
					"freq": e[1], "width": 12.0,
					"stream": vp if vp != "" else BC_FALLBACK_STREAM,
					"lines": [StringName("bc." + String(voice))],
					"recordable": true,
				}
				if id == &"bc_belov_5":
					d["tape"] = {
						"hidden": {
							"band": Vector2(300.0, 900.0),
							"image": "res://assets/textures/hidden_bunker.png",
							"text": &"hid.belov_5",
							"scare": true
						}
					}
				_bc_defs[id] = d
				return d
	return {}


static func get_def(id: StringName) -> Dictionary:
	if DATA.has(id):
		return DATA[id]
	if Efir.is_pool(id):
		return Efir.pool_def(id)
	if String(id).begins_with("bc_"):
		return _broadcast_def(id)
	return {}


static func has_hidden(id: StringName) -> bool:
	var d := get_def(id)
	return d.has("tape") and (d["tape"] as Dictionary).has("hidden")


## Таблица шифра для языка: буква → «NN». Детерминированная (одна и та же у всех игроков).
static func cipher_table(lang: String) -> Dictionary:
	var letters: String = ALPHABET.get(lang, ALPHABET["ru"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 1961
	var codes: Array[int] = []
	for i in range(10, 100):
		codes.append(i)
	for i in range(codes.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := codes[i]
		codes[i] = codes[j]
		codes[j] = tmp
	var table := {}
	for i in range(letters.length()):
		table[letters[i]] = "%02d" % codes[i]
	return table


## Группы цифр, которые передаёт станция «code» на текущем языке.
static func code_groups(lang: String) -> PackedStringArray:
	var table := cipher_table(lang)
	var word: String = CODE_WORD.get(lang, CODE_WORD["ru"])
	var out: PackedStringArray = []
	for i in range(word.length()):
		out.append(String(table.get(word[i], "00")))
	return out


static func normalize(text: String) -> String:
	return text.to_upper().replace(" ", "").replace("Ё", "Е").replace("'", "").replace("-", "")
