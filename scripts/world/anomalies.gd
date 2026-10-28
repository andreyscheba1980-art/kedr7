class_name Anomalies
extends Node
## «Замечания дежурного». За ночь на станции тихо что-то меняется — в доме, во дворе, в приборах, в эфире.
## Заметил — запиши в вахтенный журнал ТМ-1 (вкладка «Замечания»): зона и что именно.
##   • верно — вещь «возвращается на место», как только отвернёшься; напряжение спадает;
##   • записал то, чего не было, — утром Свердловск спросит про самочувствие;
##   • пропустил три и больше — следующая ночь тяжелее: «гость» в доме заходит чаще.
## В коопе аномалии ставит хост, у напарника они те же: снаружи видно двор, изнутри — дом.
## Кто на улице — диктует по рации, кто в доме — пишет.

const ZONES: Array[StringName] = [&"house", &"yard", &"instr", &"radio"]

## id → [зона, с какой ночи]. Порядок — порядок строк в журнале.
const DEFS := {
	&"chair": [&"house", 2], &"cup": [&"house", 2], &"teapot": [&"house", 2], &"bucket": [&"house", 2],
	&"glass2": [&"house", 2], &"photo": [&"house", 3], &"tools": [&"house", 3], &"clock": [&"house", 3],
	&"pennant": [&"house", 3], &"boots": [&"house", 3], &"calendar": [&"house", 4], &"bed": [&"house", 4], &"journal": [&"house", 4],
	&"wet_steps": [&"house", 5],
	&"flag": [&"yard", 2], &"tracks": [&"yard", 3], &"izba_light": [&"yard", 3], &"mast_figure": [&"yard", 5],
	&"baro_tooth": [&"instr", 2], &"anemo_calm": [&"instr", 3], &"sv20_house": [&"instr", 3], &"therm_366": [&"instr", 4],
	&"retuned": [&"radio", 2], &"num_name": [&"radio", 3],
}
## Только «случаются» сами (их ставит другой код), по таймеру не включаются.
const EVENT_ONLY: Array[StringName] = [&"therm_366"]

var active: Dictionary = {}       ## id → {"min": int, "noted": bool, "reverted": bool}
var notes: Array[Dictionary] = [] ## {"id", "zone", "min", "ok"}
var false_notes := 0

var _apply: Dictionary = {}       ## id → Callable
var _revert: Dictionary = {}      ## id → Callable
var _pos: Dictionary = {}         ## id → Callable() -> Vector3 (где это видно — для взгляда и фотоплёнки)
var _t := 0.0
var _built := false


func _ready() -> void:
	Game.anomalies = self
	_t = Game.rng.randf_range(90.0, 160.0)
	_build.call_deferred()


func _exit_tree() -> void:
	if Game.anomalies == self:
		Game.anomalies = null


static func zone_of(id: StringName) -> StringName:
	return DEFS[id][0] if DEFS.has(id) else &"house"


static func ids_for(zone: StringName, night: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in DEFS:
		if DEFS[id][0] == zone and int(DEFS[id][1]) <= maxi(night, 2):
			out.append(id)
	return out


func is_active(id: StringName) -> bool:
	return active.has(id) and not bool(active[id].get("reverted", false))


func pos_of(id: StringName) -> Vector3:
	return (_pos[id] as Callable).call() if _pos.has(id) else Vector3.INF


# --- Постройка ----------------------------------------------------------------

func _build() -> void:
	var st := Game.level
	if st == null:
		return
	_built = true
	# Старые «изменения в доме» (Station.props) — те же предметы, теперь с возвратом на место.
	for id: String in st.props.keys():
		var sid := StringName(id)
		if not DEFS.has(sid):
			continue
		var p: Dictionary = st.props[id]
		var node: Node3D = p["node"]
		var xf := node.transform
		var vis := {}
		for c: Node in node.get_children():
			if c is Node3D:
				vis[c] = (c as Node3D).visible
		_apply[sid] = func() -> void:
			(p["apply"] as Callable).call()
			p["changed"] = true
		_revert[sid] = func() -> void:
			if is_instance_valid(node):
				node.transform = xf
				for c: Node3D in vis:
					if is_instance_valid(c):
						c.visible = vis[c]
			p["changed"] = false
		_pos[sid] = func() -> Vector3: return node.global_position if is_instance_valid(node) else Vector3.INF

	# Дом: валенки у двери, второй подстаканник, примятая кровать, вымпел, мокрые следы.
	var boots := Props.valenki()
	boots.position = Vector3(13.4, 0.05, 4.8)
	boots.rotation.y = deg_to_rad(200.0)
	_hidden(st, &"boots", boots)

	var glass := Props.podstakannik()
	glass.position = Vector3(0.8, 0.75, 3.62)
	_hidden(st, &"glass2", glass)

	var dent := Node3D.new()
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.03, 0.03, 0.05, 0.6)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.roughness = 1.0
	var body := Geo.box_mesh(Vector3(0.46, 0.006, 1.2), dm)
	body.position = Vector3(0, 0, -0.25)
	dent.add_child(body)
	var head := Geo.box_mesh(Vector3(0.26, 0.006, 0.16), dm)
	head.position = Vector3(0, 0.085, 0.72)
	dent.add_child(head)
	dent.position = Vector3(-1.4, 0.479, 5.2)
	_hidden(st, &"bed", dent)

	var pennant: Node3D = st.get_meta(&"pennant") if st.has_meta(&"pennant") else null
	if pennant != null:
		var pxf := pennant.transform
		_apply[&"pennant"] = func() -> void:
			pennant.rotate_object_local(Vector3(0, 0, 1), PI)
		_revert[&"pennant"] = func() -> void:
			pennant.transform = pxf
		_pos[&"pennant"] = func() -> Vector3: return pennant.global_position

	var wet := Footprints.trail(st, &"wet", PackedVector3Array([Vector3(14.0, 0, 3.4), Vector3(11.2, 0, 3.2),
		Vector3(3.6, 0, 3.15), Vector3(0.2, 0, 4.2), Vector3(-0.7, 0, 4.8)]), 0.05, 0.55)
	wet.visible = false
	_toggle(&"wet_steps", wet, Vector3(7.0, 0.2, 3.2))

	# Двор: босые следы к крыльцу, лишние вешки с флажками в лес, свет в избе, фигура на мачте.
	var yard := Game.yard
	if yard != null:
		var tr := Footprints.trail(yard, &"bare", PackedVector3Array([Vector3(36, 0, 21), Vector3(27, 0, 11),
			Vector3(19.5, 0, 5.4), Vector3(16.9, 0, 4.1)]), 0.0, 0.62)
		tr.visible = false
		_toggle(&"tracks", tr, Vector3(24.0, 0.2, 9.0))

		var flags := Node3D.new()
		yard.add_child(flags)
		for i in 3:
			var post := Props.rope_post(true)
			post.position = Yard.FORK + Vector3(5.5 + i * 5.0, 0, 3.0 + i * 3.2)
			post.rotation.y = deg_to_rad(30.0)
			flags.add_child(post)
		flags.visible = false
		_toggle(&"flag", flags, Yard.FORK + Vector3(10.0, 0.8, 6.0))

		var glow := Node3D.new()
		var gm := StandardMaterial3D.new()
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.albedo_color = Color(1.0, 0.62, 0.26)
		var win := Geo.box_mesh(Vector3(0.82, 0.92, 0.02), gm)
		win.position = Vector3(0, 0, 0)
		glow.add_child(win)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.6, 0.3)
		lamp.light_energy = 0.9
		lamp.omni_range = 4.5
		lamp.position = Vector3(0, 0, 0.7)
		glow.add_child(lamp)
		glow.position = Yard.IZBA + Vector3(-0.65, 1.5, 3.04)
		yard.add_child(glow)
		glow.visible = false
		_toggle(&"izba_light", glow, glow.position)

		# Человек в тулупе на ферме мачты — на фоне неба, в отсвете красного огня.
		var fig := Creatures.make_human(&"driver")
		yard.add_child(fig)
		fig.position = Yard.MAST + Vector3(0.0, 6.8, 0.75)
		fig.rotation.y = 0.0
		fig.visible = false
		fig.set_process(false)
		if fig.has_method(&"set_eye_glow"):
			fig.call(&"set_eye_glow", 1.2)   # в темноте его видно по глазам
		var rim := OmniLight3D.new()   # отсвет красного огня мачты — силуэт видно на фоне фермы
		rim.light_color = Color(1.0, 0.25, 0.2)
		rim.light_energy = 2.6
		rim.omni_range = 4.0
		rim.position = Vector3(0.0, 1.9, 1.1)
		fig.add_child(rim)
		_toggle(&"mast_figure", fig, Yard.MAST + Vector3(0, 7.6, 0.75))

	# Приборы и эфир — флаги: их читают барограф, анемометр, термометр и рация.
	# Календарь в рубке: поверх дат кто-то нацарапал бурым.
	var scrawl := Label3D.new()
	scrawl.text = Loc.t(&"anom.calendar_scrawl")
	scrawl.font_size = 40
	scrawl.pixel_size = 0.0016
	scrawl.modulate = Color(0.42, 0.14, 0.07)
	scrawl.outline_size = 0
	scrawl.shaded = true
	scrawl.position = Vector3(5.0, 1.36, 2.066)
	scrawl.rotation = Vector3(0, PI, deg_to_rad(-7.0))
	_hidden(st, &"calendar", scrawl)

	for id: StringName in [&"baro_tooth", &"anemo_calm", &"sv20_house", &"therm_366", &"num_name"]:
		_apply[id] = func() -> void: pass
		_revert[id] = func() -> void: pass
	_pos[&"baro_tooth"] = func() -> Vector3: return Vector3(8.4, 0.95, -1.35)
	_pos[&"sv20_house"] = func() -> Vector3: return Vector3(7.7, 0.95, -1.35)
	_pos[&"anemo_calm"] = func() -> Vector3: return Yard.METEO + Yard.M_VANE + Vector3(0, 1.6, 0)
	_pos[&"therm_366"] = func() -> Vector3: return Yard.METEO + Yard.M_BOOTH + Vector3(0, 1.5, 0)
	_pos[&"num_name"] = func() -> Vector3: return Game.radio.global_position if Game.radio != null else Vector3.INF
	_apply[&"retuned"] = func() -> void:
		if Game.radio != null:
			Game.radio.freq = 7713.0
	_revert[&"retuned"] = func() -> void: pass
	_pos[&"retuned"] = func() -> Vector3: return Game.radio.global_position if Game.radio != null else Vector3.INF


func _hidden(parent: Node3D, id: StringName, n: Node3D) -> void:
	parent.add_child(n)
	n.visible = false
	_toggle(id, n, Vector3.INF)


func _toggle(id: StringName, n: Node3D, look_pos: Vector3) -> void:
	_apply[id] = func() -> void: n.visible = true
	_revert[id] = func() -> void: n.visible = false
	_pos[id] = func() -> Vector3: return look_pos if look_pos != Vector3.INF else n.global_position


# --- Ход ночи -------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _built or not Game.is_night() or Game.night < 2 or Game.shift_over or Game.dead or Game.player == null:
		return
	_revert_noted()
	if Net.role == "client" and Net.in_session:
		return   # в коопе аномалии ставит хост — у обоих одни и те же
	_t -= delta
	if _t > 0.0 or Director.hold:
		return
	_t = Game.rng.randf_range(140.0, 230.0) / (1.0 + (Game.night - 2) * 0.08)
	var open := 0
	for id: StringName in active:
		if not active[id]["noted"]:
			open += 1
	if open >= 1 + Game.night:
		return   # незаписанных и так хватает
	trigger_random()


## Поставить одну аномалию там, куда игрок сейчас не смотрит. Возвращает false, если некуда.
func trigger_random(zone_hint := &"") -> bool:
	if not _built:
		return false
	var cand: Array[StringName] = []
	var w := PackedFloat32Array()
	for id: StringName in DEFS:
		if active.has(id) or id in EVENT_ONLY or int(DEFS[id][1]) > Game.night or not _apply.has(id):
			continue
		if not _unseen(id):
			continue
		var z: StringName = DEFS[id][0]
		var k := 1.0
		if zone_hint != &"":
			k = 3.0 if z == zone_hint else 0.5
		elif Game.is_home():
			k = 2.0 if z != &"house" else 0.6   # пока ты дома — меняется двор и эфир; вышел — дом
		else:
			k = 2.0 if z == &"house" or z == &"radio" else 0.7
		cand.append(id)
		w.append(k)
	if cand.is_empty():
		return false
	apply(cand[Game.rng.rand_weighted(w)])
	return true


func apply(id: StringName, remote := false) -> void:
	if active.has(id) or not _apply.has(id):
		return
	(_apply[id] as Callable).call()
	active[id] = {"min": int(Game.shift_minutes), "noted": false, "reverted": false}
	if not remote:
		Net.echo_anomaly(id)
	Hints.show(&"anomalies")
	if OS.is_debug_build() or Net.test_mode:
		print("[anomaly] %s (%s) в %s" % [id, DEFS[id][0], Game.clock_text()])


## Аномалия «случилась» сама (термометр +36,6 и т. п.): в журнал её тоже можно записать.
func occur(id: StringName) -> void:
	if not active.has(id):
		active[id] = {"min": int(Game.shift_minutes), "noted": false, "reverted": false}


func _unseen(id: StringName) -> bool:
	var p := Game.player
	match DEFS[id][0]:
		&"radio":
			return Game.zone != &"radio_room"
		&"instr":
			return true
	var pos := pos_of(id)
	if pos == Vector3.INF:
		return true
	var d := p.global_position.distance_to(pos)
	if d < 3.0:
		return false
	return d > 30.0 or not p.is_looking_at(pos, 70.0)


func _revert_noted() -> void:
	for id: StringName in active:
		var a: Dictionary = active[id]
		if a["noted"] and not a["reverted"] and _unseen(id):
			a["reverted"] = true
			(_revert[id] as Callable).call()


# --- Журнал -----------------------------------------------------------------------

func noted(id: StringName) -> bool:
	for n in notes:
		if n["id"] == id:
			return true
	return false


## Запись в журнал. Ответа «верно/неверно» дежурный не получает — только вещь, вернувшаяся на место.
func note(id: StringName, remote := false) -> bool:
	if noted(id):
		return false
	var ok: bool = active.has(id) and not active[id]["noted"]
	notes.append({"id": id, "zone": zone_of(id), "min": int(Game.shift_minutes), "ok": ok})
	if ok:
		active[id]["noted"] = true
		Director.add_tension(-6.0, "замечание записано: " + String(id))
	elif not remote:
		false_notes += 1
	if not remote:
		Net.echo_anom_note(id)
	return true


## Снято на «Зенит» — доказательство: пропущенной такая аномалия уже не считается.
func photographed(id: StringName) -> void:
	if active.has(id):
		active[id]["photo"] = true


func missed() -> int:
	var n := 0
	for id: StringName in active:
		if not active[id]["noted"] and not active[id].get("photo", false):
			n += 1
	return n


## Конец ночи: итог для утренней карточки и долг на следующую ночь.
func tally() -> String:
	if not Game.is_night() or Game.night < 2:
		return ""
	var ok := 0
	for n in notes:
		if n["ok"]:
			ok += 1
	for id: StringName in active:
		if active[id].get("photo", false) and not active[id]["noted"]:
			ok += 1   # не записал, но снял — снимок в деле
	var miss := missed()
	SaveGame.flags["anom_debt"] = miss
	SaveGame.flags["anom_false"] = int(SaveGame.flags.get("anom_false", 0)) + false_notes
	SaveGame.flags["anom_notes_total"] = int(SaveGame.flags.get("anom_notes_total", 0)) + notes.size()
	SaveGame.flags["anom_ok_total"] = int(SaveGame.flags.get("anom_ok_total", 0)) + ok
	if active.is_empty() and notes.is_empty():
		return ""
	var lines := PackedStringArray([Loc.t(&"anom.tally", [ok, false_notes, miss])])
	if miss >= 3:
		lines.append(Loc.t(&"anom.debt"))
	if false_notes >= 2:
		lines.append(Loc.t(&"anom.suspect"))
	return "\n".join(lines)
