class_name Efir
extends RefCounted
## Второй контур — эфир: откуда передают, пеленги, пересечения на схеме, находки, случайные сигналы.
##
## Цепочка: услышал сигнал → записал → взял пеленг рамочной антенной (DirectionFinderUI) в доме и на башне
## корпуса → две линии на схеме сходятся в квадрат → на месте — находка (EfirSites) → расшифровка
## (MorseUI / CodebookUI) → ключевые находки идут в «Дело №83-М» и открывают концовки.
##
## Пеленг дежурный читает по лимбу сам и вписывает в книжку: ошибся — линия легла не туда.
## Состояние — в SaveGame.flags: "df" {сигнал: {точка: азимут}}, "find_<ключ>", "run_seed".

## Где слушают: рамка у рации в доме и рамка на крыше башни (приёмник в кабине).
const POINTS := {&"house": Vector3(11.0, 1.3, -0.45), &"tower": Vector3(96.9, 10.6, -36.6)}

## Сюжетные передатчики. pos — где стоит (у далёких — только направление), find — что там лежит,
## window — минуты смены, когда в эфире (нет — всю ночь), close — из дома рамку забивает в упор.
const KEY := {
	&"morse": {"pos": Vector3(-104.0, 0.0, -124.0), "find": &"beacon", "kind": &"morse"},
	&"semenov": {"pos": Vector3(59.6, 0.0, 13.4), "find": &"bunker"},
	&"mother": {"pos": Vector3(-36.9, 0.0, 34.9), "find": &"hole", "window": [300, 480]},
	&"lullaby": {"pos": Vector3(-14.6, 0.0, -29.2), "find": &"izba"},
	&"roll": {"pos": Vector3(292.0, 0.0, -316.0), "find": &"roll"},
	&"alone": {"pos": Vector3(5.2, 0.0, -5.0), "find": &"alone", "window": [420, 600], "close": true},
	&"numbers": {"pos": Vector3(-92.0, 0.0, 66.0), "find": &"otzvuk"},
	&"otzvuk": {"pos": Vector3(-92.0, 0.0, 66.0), "find": &"otzvuk"},
	&"code": {"pos": Vector3(73.6, 0.0, -60.6), "find": &"repeater"},
	&"buzzer": {"pos": Vector3(-5200.0, 0.0, -8600.0), "far": true},
}
## Ключевые находки — в порядке «Дела»
const FINDS: Array[StringName] = [&"beacon", &"bunker", &"izba", &"hole", &"repeater", &"alone", &"roll", &"otzvuk"]

## Ключевое сообщение морзе (3870 кГц): аварийный ключ-автомат Семёнова
const KEY_MORSE := {"ru": "КЕДР СЕМЬ ПОСЛЕ ТРЕХ НЕ ОТВЕЧАЙ ЭТО НЕ ОНИ", "en": "KEDR SEVEN AFTER THREE DONT ANSWER NOT THEM"}

## Случайный эфир: короткие передачи из пула. Текст — то, что проступит при расшифровке.
const POOL := [
	{"ru": "ОБХОДЧИК КЛИМОВ ТРЕТИЙ ДЕНЬ НЕ ВЕРНУЛСЯ", "en": "LINEMAN KLIMOV NOT BACK THIRD DAY"},
	{"ru": "ВЫШКА ГОВОРИТ ГОЛОСОМ БРАГИНА", "en": "THE TOWER SPEAKS WITH BRAGINS VOICE"},
	{"ru": "ЛЕСОСЕКА ПУСТАЯ ЛЮДИ УШЛИ НА ЗВУК", "en": "LOGGING CAMP EMPTY MEN WENT TO THE SOUND"},
	{"ru": "НЕ СПИ ОНО СЧИТАЕТ ДЫХАНИЕ", "en": "DONT SLEEP IT COUNTS BREATHS"},
	{"ru": "КАРТА ВРЕТ ПРОСЕКА ВЕДЕТ ПО КРУГУ", "en": "THE MAP LIES THE CUT GOES IN CIRCLES"},
	{"ru": "ЛАЗАРЕВ ЖИВ НЕ ОТКРЫВАЙТЕ ЕМУ", "en": "LAZAREV ALIVE DONT OPEN FOR HIM"},
	{"ru": "ГРУППА ОТЗВУК ПРИНЯЛА ДЕЖУРНОГО", "en": "OTZVUK GROUP HAS TAKEN THE OFFICER"},
	{"ru": "ВЕРТОЛЕТА НЕ БУДЕТ ЖДИТЕ ВЕСНЫ", "en": "NO HELICOPTER WAIT FOR SPRING"},
	{"ru": "СОБАКА СЛЫШИТ ИХ РАНЬШЕ ВЕРЬ СОБАКЕ", "en": "THE DOG HEARS THEM FIRST TRUST THE DOG"},
	{"ru": "МАЛЬЦЕВ ТЫ УЖЕ БЫЛ ЗДЕСЬ", "en": "MALTSEV YOU HAVE BEEN HERE BEFORE"},
]
## Морзе: русская и латинская азбука
const MORSE_RU := {"А": ".-", "Б": "-...", "В": ".--", "Г": "--.", "Д": "-..", "Е": ".", "Ж": "...-", "З": "--..",
	"И": "..", "Й": ".---", "К": "-.-", "Л": ".-..", "М": "--", "Н": "-.", "О": "---", "П": ".--.", "Р": ".-.",
	"С": "...", "Т": "-", "У": "..-", "Ф": "..-.", "Х": "....", "Ц": "-.-.", "Ч": "---.", "Ш": "----", "Щ": "--.-",
	"Ы": "-.--", "Ь": "-..-", "Э": "..-..", "Ю": "..--", "Я": ".-.-"}
const MORSE_EN := {"A": ".-", "B": "-...", "C": "-.-.", "D": "-..", "E": ".", "F": "..-.", "G": "--.", "H": "....",
	"I": "..", "J": ".---", "K": "-.-", "L": ".-..", "M": "--", "N": "-.", "O": "---", "P": ".--.", "Q": "--.-",
	"R": ".-.", "S": "...", "T": "-", "U": "..-", "V": "...-", "W": ".--", "X": "-..-", "Y": "-.--", "Z": "--.."}

static var _pool_defs: Dictionary = {}


# --- Время в эфире ---------------------------------------------------------------------

## Звучит ли сигнал сейчас: у сюжетных и случайных бывает своё окно (минуты смены).
static func window_ok(id: StringName) -> bool:
	var w: Variant = null
	if KEY.has(id):
		w = (KEY[id] as Dictionary).get("window", null)
	elif is_pool(id):
		w = pool_def(id).get("window", null)
	if w == null or not Game.is_night():
		return true
	return Game.shift_minutes >= float(w[0]) and Game.shift_minutes <= float(w[1])


## Слабый сигнал: в доме не слышно, только приёмник на башне.
static func is_weak(id: StringName) -> bool:
	return is_pool(id) and bool(pool_def(id).get("weak", false))


# --- Где передатчик ---------------------------------------------------------------------

static func source_pos(id: StringName) -> Vector3:
	var s := String(id)
	if KEY.has(id):
		return (KEY[id] as Dictionary)["pos"]
	if s.begins_with("bc_sem_"):
		return (KEY[&"semenov"] as Dictionary)["pos"]
	if s.begins_with("bc_belov_"):
		return Vector3(800.0, 0.0, -40000.0)      # партия Белова: 40 км к северу
	if s.begins_with("bc_st_"):
		return Vector3(-9000.0, 0.0, -3000.0)     # соседние станции — далеко на западе
	if is_pool(id):
		return pool_def(id)["pos"]
	return Vector3.INF


static func can_bearing(id: StringName) -> bool:
	return source_pos(id) != Vector3.INF


## Пеленг (градусы от севера по часовой) с точки — как его покажет рамка, с ошибкой прибора ±1,5°.
static func true_bearing(id: StringName, point: StringName) -> float:
	var from: Vector3 = POINTS[point]
	var to := source_pos(id)
	var err := float(posmod(hash(String(id) + String(point)), 31)) / 10.0 - 1.5
	return fposmod(rad_to_deg(atan2(to.x - from.x, -(to.z - from.z))) + err, 360.0)


## Передатчик в упор — рамку забивает со всех сторон, «ноля» нет.
static func too_close(id: StringName, point: StringName) -> bool:
	var to := source_pos(id)
	return to != Vector3.INF and Vector2(to.x, to.z).distance_to(Vector2(POINTS[point].x, POINTS[point].z)) < 15.0


# --- Пеленги дежурного ------------------------------------------------------------------

static func _df() -> Dictionary:
	var d: Variant = SaveGame.flags.get("df", {})
	if not (d is Dictionary):
		d = {}
	SaveGame.flags["df"] = d
	return d


static func record_df(id: StringName, point: StringName, az: float) -> void:
	var d := _df()
	var e: Dictionary = d.get(String(id), {})
	e[String(point)] = fposmod(az, 360.0)
	d[String(id)] = e


## Азимут, вписанный дежурным, или -1.
static func df(id: StringName, point: StringName) -> float:
	var e: Dictionary = _df().get(String(id), {})
	return float(e.get(String(point), -1.0))


static func df_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for k in _df():
		out.append(StringName(k))
	return out


static func dir_of(az_deg: float) -> Vector2:
	var a := deg_to_rad(az_deg)
	return Vector2(sin(a), -cos(a))


## Пересечение двух линий (рамка видит направление с точностью до 180° — линия в обе стороны).
## [] — пеленгов меньше двух; ["far"] — линии почти параллельны или сходятся за краем схемы;
## [Vector3, радиус] — квадрат на схеме.
static func cross(id: StringName) -> Array:
	var a := df(id, &"house")
	var b := df(id, &"tower")
	if a < 0.0 or b < 0.0:
		return []
	var p1 := Vector2(POINTS[&"house"].x, POINTS[&"house"].z)
	var p2 := Vector2(POINTS[&"tower"].x, POINTS[&"tower"].z)
	var d1 := dir_of(a)
	var d2 := dir_of(b)
	var den := d1.x * d2.y - d1.y * d2.x
	if absf(den) < sin(deg_to_rad(3.0)):
		return ["far"]
	var t := ((p2 - p1).x * d2.y - (p2 - p1).y * d2.x) / den
	var c := p1 + d1 * t
	if c.length() > 480.0:
		return ["far"]
	# Чем острее угол между линиями и дальше точка — тем шире квадрат
	var dist := c.distance_to(p1)
	var r := clampf(18.0 + dist * 0.035 / maxf(absf(den), 0.15), 18.0, 90.0)
	return [Vector3(c.x, 0.0, c.y), r]


# --- Находки ----------------------------------------------------------------------------

static func has_find(k: StringName) -> bool:
	return Game.has_flag("find_" + String(k))


static func mark_find(k: StringName) -> bool:
	if has_find(k):
		return false
	Game.set_flag("find_" + String(k), true)
	SaveGame.write()
	return true


static func find_count() -> int:
	var n := 0
	for k in FINDS:
		if has_find(k):
			n += 1
	return n


static func pool_found() -> int:
	return int(SaveGame.flags.get("pool_found", 0))


# --- Случайный эфир ---------------------------------------------------------------------

static func is_pool(id: StringName) -> bool:
	return String(id).begins_with("rnd_")


static func run_seed() -> int:
	if not SaveGame.flags.has("run_seed"):
		SaveGame.flags["run_seed"] = randi() % 100000
	return int(SaveGame.flags["run_seed"])


## Случайные передачи ночи: 1 в ночи 1–3, 2 в ночи 4–6; в последнюю — тишина.
static func pool_for_night(n: int) -> Array[StringName]:
	var out: Array[StringName] = []
	var cnt := 1 if n <= 3 else (2 if n <= 6 else 0)
	for k in cnt:
		out.append(StringName("rnd_%d_%d" % [n, k]))
	return out


## Описание случайной передачи — однозначно из id и сида прохождения.
static func pool_def(id: StringName) -> Dictionary:
	if _pool_defs.has(id):
		return _pool_defs[id]
	var parts := String(id).split("_")
	var n := int(parts[1]) if parts.size() > 2 else 1
	var k := int(parts[2]) if parts.size() > 2 else 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(id)) ^ run_seed()
	var kind := &"morse" if (n + k) % 2 == 1 else &"cipher"
	# Сообщения раздаются по кругу со сдвигом сида — за прохождение не повторяются
	var msg := posmod(run_seed() + (n - 1) * 2 + k, POOL.size())
	var f := 0.0
	for i in 40:
		f = roundf(rng.randf_range(3300.0, 8800.0))
		if Signals.is_free(f, 80.0):
			break
	var start := rng.randi_range(430, 500) if k == 1 else rng.randi_range(170, 380)
	var ang := rng.randf() * TAU
	var dist := rng.randf_range(120.0, 300.0)
	var p := Vector3(6.0 + sin(ang) * dist, 0.0, 4.0 - cos(ang) * dist)
	p.x = clampf(p.x, -440.0, 440.0)
	p.z = clampf(p.z, -440.0, 440.0)
	var d := {
		"freq": f, "width": 12.0, "kind": kind, "msg": msg,
		"stream": "res://assets/audio/morse_loop.ogg" if kind == &"morse" else "res://assets/audio/numbers_loop.ogg",
		"lines": [], "recordable": true, "window": [start, start + 45], "weak": (n + k) % 3 == 0, "pos": p,
	}
	_pool_defs[id] = d
	return d


## Открытый текст передачи (что получится после расшифровки).
static func plain(id: StringName) -> String:
	var lang := "en" if Settings.language == "en" else "ru"
	if id == &"morse":
		return String(KEY_MORSE[lang])
	if is_pool(id):
		return String((POOL[int(pool_def(id)["msg"])] as Dictionary)[lang])
	return ""


static func kind_of(id: StringName) -> StringName:
	if id == &"morse":
		return &"morse"
	if is_pool(id):
		return pool_def(id)["kind"]
	if id == &"code":
		return &"cipher"
	return &""


## Морзе: буквы через пробел, слова через « / ».
static func morse_of(text: String) -> String:
	var table: Dictionary = MORSE_EN if Settings.language == "en" else MORSE_RU
	var words: PackedStringArray = []
	for w in text.split(" ", false):
		var letters: PackedStringArray = []
		for ch in w:
			if table.has(ch):
				letters.append(String(table[ch]).replace(".", "·").replace("-", "−"))
		words.append(" ".join(letters))
	return "  /  ".join(words)


## Цифровые группы шифра Семёнова для передачи (пробелы выпадают).
static func cipher_groups(id: StringName) -> PackedStringArray:
	if id == &"code":
		return Signals.code_groups(Settings.language)
	var table := Signals.cipher_table(Settings.language)
	var out: PackedStringArray = []
	for ch in plain(id).replace(" ", ""):
		out.append(String(table.get(ch, "00")))
	return out


static func is_decoded(id: StringName) -> bool:
	return SaveGame.decoded.has(StringName(String(id) + "_dec")) or (id == &"code" and SaveGame.decoded.has(&"code"))


## Строка эфира в субтитрах: что слышно в наушниках.
static func air_line(id: StringName) -> String:
	match kind_of(id):
		&"morse":
			return Loc.t(&"efir.morse_line", [morse_of(plain(id))])
		&"cipher":
			return Loc.t(&"efir.cipher_line", [" · ".join(cipher_groups(id))])
	return ""


static func tape_name(id: StringName) -> String:
	if is_pool(id):
		var d := pool_def(id)
		return Loc.t(&"efir.tape_pool", [int(d["freq"]), Loc.t(&"efir.kind_morse" if d["kind"] == &"morse" else &"efir.kind_cipher")])
	return Loc.t(StringName("tape." + String(id)))


# --- Риск после трёх --------------------------------------------------------------------

static var _after3_t := 0.0


## Сидишь в наушниках после трёх: эфир чужой, а вокруг ты ничего не слышишь.
static func after3_tick(delta: float) -> void:
	if not Game.is_night() or not Game.after_hour(3):
		return
	Director.tension = clampf(Director.tension + delta * 0.5, 0.0, 100.0)   # без записи в лог каждый кадр
	_after3_t -= delta
	if _after3_t > 0.0:
		return
	_after3_t = randf_range(28.0, 50.0)
	var roll := randf()
	if roll < 0.4:
		Game.audio.play_2d("res://assets/audio/whisper.ogg", -6.0)
		Game.hud.subtitle(Loc.t(&"efir.after3_name"), 3.0)
	elif roll < 0.7:
		Game.audio.play_2d("res://assets/audio/door_knock.ogg", -10.0)
		Game.hud.subtitle(Loc.t(&"efir.after3_knock"), 3.0)
	Game.add_fatigue(1.5)
