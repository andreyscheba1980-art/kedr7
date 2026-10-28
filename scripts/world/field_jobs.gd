class_name FieldJobs
extends Node3D
## Наряды на выезд — как в Voices of the Void: днём Свердловск даёт 2–3 работы по большой карте.
## Четыре автоматические метеостанции (АМС) у зимников: перезапустить, сменить аккумулятор, сбить лёд
## с датчиков. На старой вышке — сменить ленту самописца. На лесосеке или буровой — забрать кейс с пробами
## и довезти до станции. За каждую работу — пайки (бланк заявки у рации).
## Наряды появляются, когда расчехлён «Буран» (FarSites.known()). Состояние — в SaveGame.flags:
##   fj_key — для какой фазы выданы, fj_list — [{k, t, done}], fj_battery / fj_samples — что везёшь.
## У каждой АМС в шкафу журнал с записями обходчиков — у последних записей почерк меняется.

const AMS: Array[StringName] = [&"ams1", &"ams2", &"ams3", &"ams4"]
const KINDS := {
	&"ams_reset": 1,
	&"ams_battery": 2,
	&"ams_ice": 1,
	&"tower_tape": 1,
	&"samples": 2,
	&"probe": 2,          ## пайки за зонд начисляет само событие MapEvents.probe
	&"ams_alarm": 3,      ## ночной выезд: тревога вскрытия шкафа
	&"scout": 1,          ## разведать дальнюю точку (пайку платит записка на месте — FarSites)
	&"survey": 2,         ## снегомерный маршрут ВС-43: три вехи у станции
}
## Пеленги на сигнал 03:10 (Signal0310). Сходятся на капище (SourceSite). Три нити:
##   карта — каждая АМС и лента со старой вышки;
##   след Семёнова — тетрадь пеленгов в сарае (день 1, азимут от шлагбаума зимника), шифровка цифровой станции
##   (день 2: шифроблокнот из избы → азимут от избы), азимут в шкафу ретранслятора (день 3), запись 03:10
##   из проруби (день 4: распадок на спектрограмме → азимут от проруби), кабель из бункера «Отзвук» (день 5);
##   ночь — «Слухач» в доме в момент удара.
## Трёх пеленгов хватает, чтобы проступила старая просека: дойти можно любой из нитей.
const BEARING_SITES: Array[String] = ["ams1", "ams2", "ams3", "ams4", "tower", "repeater", "bunker", "station", "zimnik", "izba", "lake"]
## Пеленги, снятые у самой станции: точнее (±1°), иначе почти параллельные линии расходятся.
const NEAR_SITES: Array[String] = ["repeater", "bunker", "station", "zimnik", "izba", "lake"]
const SAMPLE_SITES: Array[StringName] = [&"camp", &"drill"]
const BATTERY_POS := Vector3(52.6, 0.0, 31.5)      ## в гараже у северной стены
const STATIC_LOOP := "res://assets/audio/static_loop.ogg"

static var instance: FieldJobs

var _ice: Dictionary = {}          ## ams → Node3D с наледью (виден, пока висит наряд на лёд)
var _case: Dictionary = {}         ## site → Node3D кейса с пробами
var _battery_model: Node3D
var _announced := false
var _t := 0.0
var _probe_tried := false
var _ghost: Node3D               ## ночью у АМС с тревогой стоит кто-то
var _ghost_done := false


func _ready() -> void:
	instance = self
	name = "FieldJobs"
	_ensure_jobs()
	for a in AMS:
		_build_ams(a)
	_build_tower_tape()
	for s in SAMPLE_SITES:
		_build_samples(s)
	_build_battery_rack()
	_refresh()


func _exit_tree() -> void:
	if instance == self:
		instance = null


# --- Состояние ------------------------------------------------------------------------

static func enabled() -> bool:
	if not FarSites.known() or Game.is_prologue():
		return false
	return Game.is_day() or (Game.is_night() and Game.night >= 3)


static func _key() -> String:
	return "%s_%d" % [Game.phase_kind, Game.phase_index]


static func jobs() -> Array:
	if not enabled() or String(SaveGame.flags.get("fj_key", "")) != _key():
		return []
	return SaveGame.flags.get("fj_list", []) as Array


static func _ensure_jobs() -> void:
	if not enabled() or String(SaveGame.flags.get("fj_key", "")) == _key():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_key()) + int(SaveGame.flags.get("fj_done_total", 0)) * 31
	# АМС без пеленга — в первую очередь: наряды ведут к цели, а не по кругу
	var fresh: Array = []
	var old: Array = []
	for a in AMS:
		(old if has_bearing(String(a)) else fresh).append(a)
	fresh.shuffle()
	old.shuffle()
	var ams: Array = old + fresh          # pop_back() берёт с конца — сначала свежие
	var out: Array = []
	if Game.is_night():
		# Ночной выезд — не каждую ночь
		if rng.randf() < 0.75 and not ams.is_empty():
			out.append({"k": "ams_alarm", "t": String(ams.pop_back()), "done": false})
		SaveGame.flags["fj_key"] = _key()
		SaveGame.flags["fj_list"] = out
		SaveGame.flags["fj_new"] = not out.is_empty()
		return
	var n := 2 if Game.phase_index < 4 else 3
	# Дальние точки — тоже наряд: «разведать» ещё не прочитанную записку (раньше — отдельный список).
	var unseen: Array = []
	for s: StringName in FarSites.SITES:
		if not FarSites.visited(s):
			unseen.append(s)
	if not unseen.is_empty():
		out.append({"k": "scout", "t": String(unseen[rng.randi() % unseen.size()]), "done": false})
	# Снегомерный маршрут — один раз, со второго дня, пока вехи не замерены.
	# Место под наряд на АМС оставляем всегда: пеленги — главное, что дают выезды.
	if Game.phase_index >= 2 and not survey_done() and out.size() < n - 1:
		out.append({"k": "survey", "t": "survey", "done": false})
	var pool: Array = [&"ams_reset", &"ams_battery", &"ams_ice", &"samples", &"probe", &"ams_reset", &"ams_ice"]
	if not has_bearing("tower"):
		pool.append(&"tower_tape")
		pool.append(&"tower_tape")
	var used_kinds: Array = []
	while out.size() < n and not pool.is_empty():
		var k: StringName = pool[rng.randi() % pool.size()]
		pool.erase(k)
		if k in [&"tower_tape", &"samples", &"ams_battery", &"probe"] and used_kinds.has(k):
			continue
		var t := ""
		match k:
			&"tower_tape":
				t = "tower"
			&"probe":
				t = "probe"
			&"samples":
				t = String(SAMPLE_SITES[rng.randi() % SAMPLE_SITES.size()])
			_:
				if ams.is_empty():
					continue
				t = String(ams.pop_back())
		used_kinds.append(k)
		out.append({"k": String(k), "t": t, "done": false})
	SaveGame.flags["fj_key"] = _key()
	SaveGame.flags["fj_list"] = out
	SaveGame.flags["fj_battery"] = false
	SaveGame.flags["fj_samples"] = false
	SaveGame.flags["fj_new"] = true


static func survey_done() -> bool:
	return Game.has_flag("survey_stake_1") and Game.has_flag("survey_stake_2") and Game.has_flag("survey_stake_3")


## Записка на дальней точке прочитана (FarSites) — закрывает наряд «разведать», если он висит.
static func on_site_scouted(site: String, pos: Vector3) -> void:
	if instance == null:
		return
	var j := active_at(site, "scout")
	if not j.is_empty():
		instance._complete(j, pos, false)


## Замерена последняя веха снегомерного маршрута.
static func on_survey_done(pos: Vector3) -> void:
	if instance == null:
		return
	var j := active_at("survey", "survey")
	if not j.is_empty():
		instance._complete(j, pos)


static func active_at(target: String, kind := "") -> Dictionary:
	for j: Dictionary in jobs():
		if not bool(j["done"]) and String(j["t"]) == target and (kind == "" or String(j["k"]) == kind):
			return j
	return {}


static func remaining() -> int:
	var n := 0
	for j: Dictionary in jobs():
		if not bool(j["done"]):
			n += 1
	return n


static func job_text(j: Dictionary) -> String:
	var t := String(j["t"])
	var where := Loc.t(StringName("map." + t) if t.begins_with("ams") or t == "probe" or t == "survey" else StringName("map.site_" + t))
	return Loc.t(StringName("fj.k_" + String(j["k"])), [where])


## Строки для списка обязанностей (Tab).
static func task_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	if FarSites.known() and not Game.is_prologue():
		lines.append("")
		lines.append(Loc.t(&"fj.brg_line", [bearing_count()]) + ("  " + Loc.t(&"fj.brg_found") if SourceSite.found() else ""))
	var js := jobs()
	if js.is_empty():
		return lines
	lines.append(Loc.t(&"fj.title", [Supply.rations()]))
	for j: Dictionary in js:
		var reward: int = KINDS.get(StringName(String(j["k"])), 1)
		lines.append("  %s %s  (+%d)" % ["[x]" if bool(j["done"]) else "[ ]", job_text(j), reward])
	if bool(SaveGame.flags.get("fj_samples", false)):
		lines.append("  " + Loc.t(&"fj.carry_samples"))
	if bool(SaveGame.flags.get("fj_battery", false)):
		lines.append("  " + Loc.t(&"fj.carry_battery"))
	return lines


## Угловая строка, когда сюжетная цель дня уже сделана.
static func objective() -> String:
	if bool(SaveGame.flags.get("fj_samples", false)):
		return Loc.t(&"fj.obj_deliver")
	for j: Dictionary in jobs():
		if not bool(j["done"]):
			return Loc.t(&"fj.obj", [job_text(j), remaining()])
	return ""


## Метки для схемы [M]: АМС всегда (когда открыт регион), с пометкой, если там наряд.
static func map_sites() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not FarSites.known():
		return out
	for a in AMS:
		out.append({"pos": Terrain.pad_pos(a), "label": StringName("map." + String(a)), "size": Vector2(7, 7), "far": true,
			"job": not active_at(String(a)).is_empty()})
	# Зонд: на схеме — только круг, где искать (пеленг на его маячок неточный)
	var jp := active_at("probe")
	if not jp.is_empty() and jp.has("px"):
		out.append({"pos": Vector3(float(jp["px"]), 0, float(jp["pz"])), "label": &"map.probe", "size": Vector2(3, 3), "far": true,
			"job": true, "circle": 34.0})
	return out


# --- Пеленги на 03:10 -------------------------------------------------------------------

static func has_bearing(site: String) -> bool:
	return Game.has_flag("brg_" + site)


static func bearing_count() -> int:
	var n := 0
	for s in BEARING_SITES:
		if has_bearing(s):
			n += 1
	return n


static func site_pos(site: String) -> Vector3:
	match site:
		"station":
			return Yard.HOUSE_CENTER
		"repeater":
			return Yard.REPEATER
		"bunker":
			return Yard.BUNKER
		"zimnik":
			return Yard.ZIMNIK
		"izba":
			return Yard.IZBA
		"lake":
			return Yard.HOLE
	return Terrain.pad_pos(StringName(site))


## Направление (рад, по часовой от севера) с точки на источник, с ошибкой прибора ±3°.
static func bearing_angle(site: String) -> float:
	var from := site_pos(site)
	var to := Terrain.pad_pos(&"source")
	var spread := 3 if NEAR_SITES.has(site) else 7
	var err := deg_to_rad(float(hash(site) % spread) - float(spread - 1) * 0.5)
	return atan2(to.x - from.x, -(to.z - from.z)) + err


## Центр и радиус круга поиска на схеме: чем больше пеленгов, тем уже.
static func search_zone() -> Array:
	var n := bearing_count()
	if n < 2:
		return []
	var r: float = [0.0, 0.0, 75.0, 40.0, 20.0, 12.0][mini(n, 5)]
	var src := Terrain.pad_pos(&"source")
	var off := Vector3(cos(1.1), 0, sin(1.1)) * r * 0.45
	return [src + off, r]


## Записать пеленг (один раз на место) и сказать игроку, что изменилось на схеме.
static func record_bearing(site: String) -> void:
	if not BEARING_SITES.has(site) or has_bearing(site):
		return
	Game.set_flag("brg_" + site, true)
	var deg := fposmod(rad_to_deg(bearing_angle(site)), 360.0)
	var n := bearing_count()
	var key := &"fj.brg_1"
	if n == 2:
		key = &"fj.brg_2"
	elif n == 3:
		key = &"fj.brg_3"
	elif n >= 4:
		key = &"fj.brg_4"
	if Game.hud != null:
		var got := StringName("fj.brg_got_" + site)
		if not Loc.has_key(got):
			got = &"fj.brg_got"
		Game.hud.subtitle(Loc.t(got, [int(deg)]) + " " + Loc.t(key), 8.0)


static func job_site(target: String) -> bool:
	return not active_at(target).is_empty()


func _complete(j: Dictionary, pos: Vector3, pay := true) -> void:
	j["done"] = true
	var reward: int = KINDS.get(StringName(String(j["k"])), 1)
	SaveGame.flags["fj_done_total"] = int(SaveGame.flags.get("fj_done_total", 0)) + 1
	if pay:
		Supply.add(reward, &"sup.r_job")
	_bearing_later(String(j["t"]))
	Game.audio.play_3d("res://assets/audio/clank_v2.ogg", pos, -4.0)
	Director.add_tension(-4.0, "наряд выполнен")
	if remaining() == 0:
		_say_later(&"fj.all_done", 4.5)
	SaveGame.write()
	_refresh()
	# Иногда в шкафу АМС отзывается эфир — не Свердловск
	if String(j["t"]).begins_with("ams") and randf() < 0.3:
		_voice_in_cabinet(pos)


func _bearing_later(site: String) -> void:
	if not BEARING_SITES.has(site) or has_bearing(site):
		return
	await get_tree().create_timer(4.8, false).timeout
	record_bearing(site)
	SaveGame.write()


## Зонд подобран (MapEvents.probe) — закрывает наряд «пеленг зонда», если он висит.
static func on_probe_taken(pos: Vector3) -> void:
	if instance == null:
		return
	var j := active_at("probe")
	if not j.is_empty():
		instance._complete(j, pos, false)


func _say_later(key: StringName, delay: float) -> void:
	await get_tree().create_timer(delay, false).timeout
	if Game.hud != null:
		Game.hud.subtitle(Loc.t(key), 5.0)


func _voice_in_cabinet(pos: Vector3) -> void:
	await get_tree().create_timer(2.5, false).timeout
	Game.audio.play_3d(STATIC_LOOP, pos, -4.0, 3.0, 4.0)
	await get_tree().create_timer(1.2, false).timeout
	Game.audio.play_3d("res://assets/audio/whisper.ogg", pos, -6.0, 3.0)
	if Game.hud != null:
		Game.hud.subtitle(Loc.t(StringName("fj.voice_%d" % (randi() % 3 + 1))), 5.5)
	Director.add_tension(10.0, "голос в шкафу АМС")


func _refresh() -> void:
	for a: StringName in _ice:
		(_ice[a] as Node3D).visible = not active_at(String(a), "ams_ice").is_empty()
	for s: StringName in _case:
		(_case[s] as Node3D).visible = not active_at(String(s), "samples").is_empty() and not bool(SaveGame.flags.get("fj_samples", false))
	if _battery_model != null:
		_battery_model.visible = not bool(SaveGame.flags.get("fj_battery", false))


func _process(delta: float) -> void:
	if not enabled() or Game.player == null:
		return
	_t += delta
	_process_probe()
	_process_alarm()
	if not _announced and bool(SaveGame.flags.get("fj_new", false)) and _t > (60.0 if Game.is_night() else 20.0) and Game.hud != null:
		_announced = true
		SaveGame.flags["fj_new"] = false
		var names: PackedStringArray = []
		for j: Dictionary in jobs():
			names.append(job_text(j))
		Game.hud.subtitle(Loc.t(&"fj.radio", ["; ".join(names)]), 8.0)
	# Кейс с пробами довезли до станции
	if bool(SaveGame.flags.get("fj_samples", false)) and Game.is_home():
		SaveGame.flags["fj_samples"] = false
		for j: Dictionary in jobs():
			if String(j["k"]) == "samples" and not bool(j["done"]):
				_complete(j, Game.player.global_position)
				if Game.hud != null:
					Game.hud.subtitle(Loc.t(&"fj.samples_done"), 4.5)
				break


# --- Постройка ------------------------------------------------------------------------

func _model(id: String, pos: Vector3, yaw_deg := 0.0, collide := true) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.global_position = pos
	root.rotation.y = deg_to_rad(yaw_deg)
	# center: false — координаты частей (шкаф, мачта) берём прямо из модели, без сдвига к центру габарита
	if Models.spawn(root, "kedr/" + id, Vector3.ZERO, 0.0, -1.0, {"grime": 0.0, "bright": 1.15, "sat": 0.9, "collide": collide, "center": false}) == null:
		Geo.block(root, Vector3(0.6, 1.0, 0.4), Vector3(0, 0.5, 0), Palette.m(&"metal"), collide)
	return root


func _build_ams(a: StringName) -> void:
	var c := Terrain.pad_pos(a)
	# Шкаф смотрит на зимник: разворачиваем станцию лицом к ближайшей точке дороги
	var yaw := _face_road(c)
	var root := _model("ams_post", c, rad_to_deg(yaw))
	SiteDressing.ams(get_parent() as Node3D, c, yaw, a)
	var basis := Basis(Vector3.UP, yaw)
	# Шкаф (в осях модели: x 0.65, y 1.3, z 0.55)
	var cab_pos := c + basis * Vector3(0.65, 1.3, 0.62)
	var cab := Geo.interactable(self, Vector3(0.8, 0.95, 0.45), cab_pos, null, "", Callable())
	cab.rotation.y = yaw
	cab.name = "AmsCabinet_" + String(a)
	cab.hold_sound = "res://assets/audio/crank_loop.ogg"
	cab.prompt_provider = func() -> String:
		var jr := active_at(String(a), "ams_reset")
		var jb := active_at(String(a), "ams_battery")
		if not active_at(String(a), "ams_alarm").is_empty():
			cab.hold_time = 3.0
			return Loc.t(&"fj.it_alarm")
		if not jr.is_empty():
			cab.hold_time = 4.0
			return Loc.t(&"fj.it_reset")
		if not jb.is_empty():
			cab.hold_time = 3.0 if bool(SaveGame.flags.get("fj_battery", false)) else 0.0
			return Loc.t(&"fj.it_battery") if bool(SaveGame.flags.get("fj_battery", false)) else Loc.t(&"fj.it_battery_need")
		cab.hold_time = 0.0
		return Loc.t(&"fj.it_log")
	cab.hold_check = func() -> bool:
		if not active_at(String(a), "ams_reset").is_empty() or not active_at(String(a), "ams_alarm").is_empty():
			return true
		return not active_at(String(a), "ams_battery").is_empty() and bool(SaveGame.flags.get("fj_battery", false))
	cab.used.connect(func(_p: Player) -> void:
		var jr := active_at(String(a), "ams_reset")
		var jb := active_at(String(a), "ams_battery")
		var jal := active_at(String(a), "ams_alarm")
		if not jal.is_empty():
			_complete(jal, cab_pos)
			Game.hud.subtitle(Loc.t(&"fj.alarm_done"), 5.0)
		elif not jr.is_empty():
			_complete(jr, cab_pos)
			Game.hud.subtitle(Loc.t(&"fj.reset_done"), 4.0)
		elif not jb.is_empty() and bool(SaveGame.flags.get("fj_battery", false)):
			SaveGame.flags["fj_battery"] = false
			_complete(jb, cab_pos)
			Game.hud.subtitle(Loc.t(&"fj.battery_done"), 4.0)
		elif not jb.is_empty():
			Game.hud.subtitle(Loc.t(&"fj.battery_need_sub"), 4.0)
		else:
			Game.hud.show_note(Loc.t(StringName("fj.log_" + String(a))))
			if not Game.has_flag("fj_log_" + String(a)):
				Game.set_flag("fj_log_" + String(a), true)
				Director.add_tension(4.0, "журнал АМС")
	)
	# Мачта: сбить наледь с датчиков, обстукивая трубу
	var mast := Geo.interactable(self, Vector3(0.5, 1.8, 0.5), c + Vector3(0, 1.1, 0), null, "", Callable())
	mast.name = "AmsMast_" + String(a)
	mast.hold_time = 5.0
	mast.hold_sound = "res://assets/audio/ice_hit.ogg"
	mast.prompt_provider = func() -> String:
		return Loc.t(&"fj.it_ice") if not active_at(String(a), "ams_ice").is_empty() else ""
	mast.hold_check = func() -> bool:
		return not active_at(String(a), "ams_ice").is_empty()
	mast.used.connect(func(_p: Player) -> void:
		var ji := active_at(String(a), "ams_ice")
		if ji.is_empty():
			return
		Game.audio.play_3d("res://assets/audio/snow_fall.ogg", c + Vector3(0, 3, 0), 0.0, 6.0)
		_complete(ji, c + Vector3(0, 2, 0))
		Game.hud.subtitle(Loc.t(&"fj.ice_done"), 4.0)
	)
	# Наледь: белые наросты на траверсе и будочке
	var ice := Node3D.new()
	root.add_child(ice)
	var im := Palette.m(&"ice")
	var blob := SphereMesh.new()
	blob.radius = 1.0
	blob.height = 2.0
	blob.radial_segments = 8
	blob.rings = 5
	for p: Vector3 in [Vector3(-0.6, 4.86, 0), Vector3(0.6, 4.86, 0), Vector3(0, 4.8, 0), Vector3(0, 2.66, 0.55), Vector3(0, 3.6, 0)]:
		var b := MeshInstance3D.new()
		b.mesh = blob
		b.material_override = im
		b.position = p
		b.scale = Vector3(0.16, 0.1, 0.14) if p.y > 3.0 else Vector3(0.22, 0.06, 0.2)
		ice.add_child(b)
	var ic := Props.icicles(1.2, 7)
	ic.position = Vector3(0, 4.62, 0)
	ice.add_child(ic)
	_ice[a] = ice
	# Огонёк на шкафу — видно с зимника, по нему находишь АМС в сумерках
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.3, 0.15)
	l.light_energy = 0.8
	l.omni_range = 5.0
	l.position = basis * Vector3(0.9, 1.9, 0.45)
	root.add_child(l)


func _face_road(c: Vector3) -> float:
	var best := Vector3.ZERO
	var bd := 1e9
	for road: StringName in Terrain.ROADS:
		for q in Terrain.road_points(road, 8.0):
			var d := Vector2(q.x - c.x, q.z - c.z).length_squared()
			if d < bd:
				bd = d
				best = q
	var to := best - c
	return atan2(to.x, to.z)      # +Z модели (дверца шкафа) — к дороге


func _build_tower_tape() -> void:
	var c := Terrain.pad_pos(&"tower") + Vector3(1.6, 0.0, 1.2)
	c.y = Terrain.height(c.x, c.z)
	var it := Geo.interactable(self, Vector3(0.6, 0.8, 0.5), c + Vector3(0, 1.1, 0), Palette.m(&"metal"), "", Callable())
	it.name = "TowerRecorder"
	it.hold_time = 4.0
	it.hold_sound = "res://assets/audio/crank_loop.ogg"
	it.prompt_provider = func() -> String:
		return Loc.t(&"fj.it_tape") if not active_at("tower", "tower_tape").is_empty() else Loc.t(&"fj.it_tape_idle")
	it.hold_check = func() -> bool:
		return not active_at("tower", "tower_tape").is_empty()
	it.used.connect(func(_p: Player) -> void:
		var j := active_at("tower", "tower_tape")
		if j.is_empty():
			return
		_complete(j, c)
		Game.hud.subtitle(Loc.t(&"fj.tape_done"), 5.0)
	)
	Geo.block(self, Vector3(0.08, 1.0, 0.08), c + Vector3(0, 0.5, -0.2), Palette.m(&"metal"), false)


func _build_samples(site: StringName) -> void:
	var c := Terrain.pad_pos(site) + (Vector3(-2.0, 0.0, 5.0) if site == &"camp" else Vector3(4.0, 0.0, -5.0))
	c.y = Terrain.height(c.x, c.z)
	var root := _model("sample_case", c, 20.0, false)
	var it := Geo.interactable(root, Vector3(0.55, 0.35, 0.35), Vector3(0, 0.17, 0), null, "", Callable())
	it.prompt_provider = func() -> String:
		return Loc.t(&"fj.it_samples") if root.visible else ""
	it.used.connect(func(_p: Player) -> void:
		if not root.visible:
			return
		SaveGame.flags["fj_samples"] = true
		Game.audio.play_3d("res://assets/audio/clank_v3.ogg", c, -6.0)
		Game.hud.subtitle(Loc.t(&"fj.samples_taken"), 4.5)
		_refresh()
	)
	_case[site] = root


func _build_battery_rack() -> void:
	# Два аккумулятора у стены гаража; один — для АМС
	_model("akb", BATTERY_POS + Vector3(0.6, 0, 0), 4.0, false)
	_battery_model = _model("akb", BATTERY_POS, -3.0, false)
	var it := Geo.interactable(self, Vector3(0.55, 0.35, 0.3), BATTERY_POS + Vector3(0, 0.17, 0), null, "", Callable())
	it.name = "AmsBattery"
	it.prompt_provider = func() -> String:
		if bool(SaveGame.flags.get("fj_battery", false)):
			return ""
		var need := false
		for j: Dictionary in jobs():
			if String(j["k"]) == "ams_battery" and not bool(j["done"]):
				need = true
		return Loc.t(&"fj.it_take_battery") if need else Loc.t(&"fj.it_battery_spare")
	it.used.connect(func(_p: Player) -> void:
		var need := false
		for j: Dictionary in jobs():
			if String(j["k"]) == "ams_battery" and not bool(j["done"]):
				need = true
		if not need or bool(SaveGame.flags.get("fj_battery", false)):
			return
		SaveGame.flags["fj_battery"] = true
		Game.audio.play_3d("res://assets/audio/clank.ogg", BATTERY_POS, -6.0)
		Game.hud.subtitle(Loc.t(&"fj.battery_taken"), 4.5)
		_refresh()
	)


## Наряд на зонд: ставим событие MapEvents.probe и запоминаем, где он (с ошибкой — круг на схеме).
func _process_probe() -> void:
	if _probe_tried or _t < 8.0 or MapEvents.instance == null:
		return
	var j := active_at("probe")
	if j.is_empty():
		_probe_tried = true
		return
	_probe_tried = true
	if not MapEvents.instance.force(&"probe"):
		return
	var node: Node3D = MapEvents.instance._active[-1].get("node")
	if node == null:
		return
	var a := randf() * TAU
	var r := randf_range(8.0, 22.0)
	j["px"] = node.global_position.x + cos(a) * r
	j["pz"] = node.global_position.z + sin(a) * r


## Ночная тревога на АМС: у шкафа кто-то стоит. Подъедешь ближе — его нет, шкаф распахнут.
func _process_alarm() -> void:
	if not Game.is_night() or _ghost_done:
		return
	var j: Dictionary = {}
	for jj: Dictionary in jobs():
		if String(jj["k"]) == "ams_alarm" and not bool(jj["done"]):
			j = jj
	if j.is_empty():
		return
	var c := Terrain.pad_pos(StringName(String(j["t"])))
	var d := Game.player.global_position.distance_to(c)
	if _ghost == null and d < 55.0:
		_ghost = Creatures.make_silhouette()
		add_child(_ghost)
		var away := (c - Game.player.global_position)
		away.y = 0.0
		var gp := c + away.normalized() * 2.5
		_ghost.global_position = Vector3(gp.x, Terrain.height(gp.x, gp.z), gp.z)
		var to := Game.player.global_position - _ghost.global_position
		_ghost.rotation.y = atan2(-to.x, -to.z)
	elif _ghost != null and d < 17.0:
		_ghost_done = true
		Game.audio.play_3d("res://assets/audio/whisper.ogg", _ghost.global_position + Vector3(0, 1.5, 0), -2.0)
		Game.audio.play_3d("res://assets/sfx/snow_steps_run.ogg", _ghost.global_position, -2.0, 6.0)
		_ghost.queue_free()
		_ghost = null
		Director.add_tension(14.0, "фигура у АМС")
		if Game.hud != null:
			Game.hud.subtitle(Loc.t(&"fj.alarm_ghost"), 5.0)
