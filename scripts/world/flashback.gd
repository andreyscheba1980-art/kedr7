class_name Flashback
extends Node
## Флешбэки «Семёнов, декабрь 1982» (1.54). После рассвета ночей 1–6, до утренней карточки:
## 1–2 минуты играешь за прошлого дежурного в том же доме — выцветшая плёнка, свет 1982 года.
## Каждый эпизод повторяет то, что игрок только что пережил, и обрывается в самый жуткий момент.
## Цели — Game.memory_goal (обычных целей нет: смена кончилась). [E] перехватываем сами, чтобы
## рация, кровать и прочее в доме не срабатывали. [Esc] — пропустить.

static var active := false
static var autopilot := false       ## автотест: цели выполняются сами (телепорт и взгляд)

const TABLE := Vector3(1.7, 0.8, 4.3)          ## стол у южного окна: тетрадь дежурных
const WINDOW_AT := Vector3(0.55, 0.05, 5.75)    ## где встать у южного окна
const VEST := Vector3(13.95, 0.05, 3.1)         ## тамбур, у глазка
const DOOR := Vector3(14.5, 1.3, 3.1)
const PORCH := Vector3(16.0, 0.05, 3.1)
const RADIO := Vector3(9.2, 1.0, -1.45)
const STORE := Vector3(5.25, 0.05, -4.4)
const PHONES := Vector3(5.0, 0.04, -4.75)
const BED := Vector3(-1.4, 0.0, 5.2)
const START := Vector3(2.4, 0.05, 2.6)

const KNOCK := "res://assets/audio/door_knock.ogg"
const KNOCK_SOFT := "res://assets/audio/knock.ogg"
const STINGER := "res://assets/audio/sub_drop.ogg"
const WHISPER := "res://assets/audio/whisper.ogg"
const SCREAM := "res://assets/audio/scream.ogg"
const WHISTLE := "res://assets/audio/whistle.ogg"
const STATIC := "res://assets/audio/radio_anomaly.ogg"
const NUMBERS := "res://assets/audio/numbers_loop.ogg"
const CLANK := "res://assets/audio/clank.ogg"
const GUST := "res://assets/audio/gust.ogg"
const HUM := "res://assets/audio/hum_loop.ogg"
const VOICE := "res://assets/audio/voice_mainland.ogg"

var _n := 0
var _skip := false
var _e := false
var _post: ShaderMaterial
var _nodes: Array[Node] = []
var _loops: Array[Node] = []
var _lamps: Array[OmniLight3D] = []   ## керосинки 1982 года: тёплый свет в комнате и в рубке


## Будет ли флешбэк после этой ночи. В коопе и в «Новой смене» (другой дежурный) — нет.
static func wants(n: int) -> bool:
	if n < 1 or n > 6 or Net.role != "" or Game.has_flag("new_shift"):
		return false
	if SaveGame._testing() and not autopilot:
		return false                  # автотесты гоняют смены подряд — флешбэк только в сквозном прогоне
	return not OS.get_cmdline_user_args().has("--no_flashback")


static func play(n: int) -> void:
	var f := Flashback.new()
	f._n = n
	Game.level.add_child(f)
	await f._run()
	f.queue_free()


func _run() -> void:
	active = true
	var p := Game.player
	Game.hud.close_modal()
	await Game.hud.fade_in_screen(Loc.t(StringName("fb.card.%d" % _n)), 1.6)
	await get_tree().create_timer(3.2, false).timeout
	_setup()
	await get_tree().process_frame
	Game.hud.fade_out_screen(1.4)
	Game.hud.hint(Loc.t(&"fb.skip"), 5.0)
	SessionLog.note("флешбэк Семёнова %d" % _n)
	match _n:
		1: await _fb1()
		2: await _fb2()
		3: await _fb3()
		4: await _fb4()
		5: await _fb5()
		6: await _fb6()
	if not _skip:
		SaveGame.flags["fb_done_%d" % _n] = true
		var all := true
		for i in range(1, 7):
			all = all and SaveGame.flags.get("fb_done_%d" % i, false)
		if all:
			Achievements.unlock(&"semenov")
	await _cut()
	_cleanup()
	if p != null and is_instance_valid(p):
		p.mode = Player.Mode.LOCKED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	active = false


func _setup() -> void:
	var p := Game.player
	Game.hud.cinematic = false
	p.global_position = START
	p.velocity = Vector3.ZERO
	p.rotation.y = deg_to_rad(200.0)
	p.head.rotation.x = 0.0
	p.set_flashlight(false)
	p.mode = Player.Mode.WALK
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Game.power_on = true
	Game.house_switch_off = false     # у Семёнова в доме горит свет
	var st := Game.level as Station
	if st != null:
		if st.door_open:
			st.set_door_open(false)
		st.set_lit(true)
	for lp: Vector3 in [Vector3(1.7, 1.7, 3.8), Vector3(9.0, 1.8, -0.6), Vector3(5.6, 1.7, -4.0), Vector3(12.6, 2.0, 3.1)]:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.78, 0.5)
		l.light_energy = 0.9
		l.omni_range = 5.5
		l.omni_attenuation = 1.4
		Game.level.add_child(l)
		l.global_position = lp
		_nodes.append(l)
		_lamps.append(l)
	_post = _find_post()
	_set_memory(0.0)
	var tw := create_tween()
	tw.tween_method(_set_memory, 0.0, 1.0, 1.6)


func _find_post() -> ShaderMaterial:
	var c := get_viewport().get_parent() as CanvasItem if get_viewport() != null else null
	if c != null and c.material is ShaderMaterial:
		return c.material as ShaderMaterial
	return null


func _set_memory(v: float) -> void:
	if _post != null:
		_post.set_shader_parameter(&"memory", v)


func _cleanup() -> void:
	Game.memory_goal = ""
	_set_memory(0.0)
	for n in _nodes + _loops:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	_loops.clear()
	Game.audio.silence(false)
	Game.hud.cinematic = false


func _exit_tree() -> void:
	active = false
	Game.memory_goal = ""
	_set_memory(0.0)


func _input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		_skip = true
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"interact"):
		_e = true
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"flare") or event.is_action_pressed(&"drop") or event.is_action_pressed(&"transmit") \
			or (event is InputEventMouseButton and event.is_pressed() and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT):
		get_viewport().set_input_as_handled()


# --- Помощники ----------------------------------------------------------------

func _wait(t: float) -> void:
	var e := 0.0
	while e < t and not _skip and is_inside_tree():
		await get_tree().process_frame
		e += get_process_delta_time()


func _think(key: StringName, t := 0.0, col := Color.TRANSPARENT) -> void:
	if _skip:
		return
	var text := Loc.t(key)
	var d := t if t > 0.0 else clampf(text.length() * 0.055, 3.2, 7.5)
	var vl := Voice.line(key, ["v_th_", "ml_", "door_", "yrka_"])   # Семёнов, эфир, за дверью, шёпот
	if vl > 0.0:
		d = maxf(d * 0.6, vl + 0.4)
	Game.hud.subtitle(text, d, 2, col)
	await _wait(d + 0.3)


## Цель: дойти до точки (и посмотреть на look, и нажать [E], если нужно). Через 2,5 мин — дальше сама.
func _goal(key: StringName, pos: Vector3, r: float, look := Vector3.INF, need_e := false) -> void:
	if _skip:
		return
	Game.memory_goal = Loc.t(key)
	_e = false
	if autopilot:
		await _wait(1.0)
		var p := Game.player
		var dir := (look if look != Vector3.INF else pos + Vector3(1, 1.5, 0)) - pos
		p.global_position = Vector3(pos.x, 0.05, pos.z) - Vector3(dir.x, 0, dir.z).normalized() * minf(r * 0.5, 0.6)
		var to := (look if look != Vector3.INF else pos + Vector3(1, 1.5, 0)) - (p.global_position + Vector3(0, 1.6, 0))
		p.rotation.y = atan2(-to.x, -to.z)
		p.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
		_e = true
		await _wait(0.6)
	var t := 0.0
	while not _skip and is_inside_tree():
		var pp := Game.player.global_position
		var near := Vector2(pp.x - pos.x, pp.z - pos.z).length() < r
		var ok := near
		if ok and look != Vector3.INF:
			ok = _looking(look, 0.8)
		if ok and need_e:
			ok = _e
		if ok or t > 150.0:
			break
		if not near:
			_e = false
		await get_tree().process_frame
		t += get_process_delta_time()
	Game.memory_goal = ""


func _looking(target: Vector3, cos_min: float) -> bool:
	var cam := Game.player.camera
	if cam == null:
		return true
	var fwd := -cam.global_basis.z
	return fwd.dot((target - cam.global_position).normalized()) > cos_min


func _knocks(pos: Vector3, count := 3, path := KNOCK, vol := 4.0) -> void:
	for i in count:
		if _skip:
			return
		Game.audio.play_3d(path, pos, vol, 4.0)
		await _wait(0.42)


func _loop(path: String, pos: Vector3, vol: float) -> void:
	var a := Game.audio.play_3d(path, pos, vol, 4.0)
	if a != null:
		_loops.append(a)


func _stop_loops() -> void:
	for n in _loops:
		if is_instance_valid(n):
			n.queue_free()
	_loops.clear()


## Резкий обрыв: стингер, чёрный кадр, тишина — и «Виктор просыпается».
func _cut(scream := false) -> void:
	_stop_loops()
	Game.memory_goal = ""
	if not _skip:
		Game.audio.play_2d(SCREAM if scream else STINGER, -1.0 if scream else 2.0)
	await Game.hud.fade_in_screen("", 0.05)
	Game.audio.silence(true)
	_set_memory(0.0)
	await get_tree().create_timer(1.6, false).timeout
	Game.audio.silence(false)
	await Game.hud.fade_in_screen(Loc.t(&"fb.after"), 0.8)
	await get_tree().create_timer(2.6, false).timeout


func _double(face: StringName, pos: Vector3, look: Vector3) -> CreatureRig:
	var g := Creatures.make_double(face)
	if g == null:
		return null
	Game.level.add_child(g)
	_nodes.append(g)
	g.global_position = pos
	g.look_at(Vector3(look.x, pos.y, look.z), Vector3.UP)
	g.pose_override = &"still"
	return g


func _snow_light(pos: Vector3, energy := 1.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = Color(0.62, 0.72, 0.92)
	l.light_energy = energy
	l.omni_range = 5.0
	Game.level.add_child(l)
	l.global_position = pos
	_nodes.append(l)
	return l


func _ground(x: float, z: float) -> float:
	return Terrain.height(x, z)


## Резкий разворот головы назад (как в холодном старте) — и обрыв.
func _turn_back() -> void:
	var p := Game.player
	p.mode = Player.Mode.LOCKED
	var tw := create_tween()
	tw.tween_property(p, "rotation:y", p.rotation.y + deg_to_rad(160.0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	await Game.hud.flash_face(0.14)


# --- 1. Заступление: тетрадь, свист, человек у опушки --------------------------

func _fb1() -> void:
	await _goal(&"fb1.g1", TABLE, 1.4, TABLE)
	await _think(&"fb1.t1")
	await _wait(1.0)
	Game.audio.play_3d(WHISTLE, Vector3(1.0, 2.0, 30.0), 6.0, 20.0)
	await _think(&"fb1.t2")
	var far := Vector3(1.0, _ground(1.0, 21.0), 21.0)
	var g := _double(&"orekhov", far, Vector3(0.5, 0, 6.6))
	var lamp := _snow_light(far + Vector3(0.8, 2.2, -1.2), 0.9)
	await _goal(&"fb1.g2", WINDOW_AT, 1.3, far + Vector3(0, 1.4, 0))
	await _think(&"fb1.t3")
	await _wait(1.2)
	if is_instance_valid(g) and not _skip:
		Game.hud.blink(0.12)
		var near := Vector3(0.7, _ground(0.7, 9.5), 9.5)
		g.global_position = near
		lamp.global_position = near + Vector3(0.6, 2.0, -1.0)
		Game.audio.play_2d(STINGER, -4.0)
	await _think(&"fb1.t4")
	var st := Game.level as Station
	if st != null and not _skip:
		st.set_lit(false)
		for l in _lamps:
			l.visible = false
		Game.audio.play_3d(CLANK, START, -2.0, 6.0)
	await _wait(1.6)


# --- 2. Стук: «Это Брагин», в глазке пусто, стук изнутри -----------------------

func _fb2() -> void:
	await _wait(1.5)
	await _knocks(DOOR)
	await _wait(0.9)
	await _knocks(DOOR)
	await _think(&"fb2.t1")
	Game.audio.play_3d(VOICE, DOOR + Vector3(0.6, 0, 0), -8.0, 3.0, 3.5)
	await _think(&"fb2.v1", 5.0)
	await _think(&"fb2.t2")
	await _goal(&"fb2.g1", VEST, 0.9, DOOR)
	if not _skip:
		Game.player.mode = Player.Mode.LOCKED
		Game.player.global_position = VEST
		Game.hud.cinematic = true
		var peep := PeepholeUI.new()
		Game.hud.open_modal(peep)
		await _wait(2.6)
		await _think(&"fb2.t3")
		Game.hud.close_modal()
		Game.hud.cinematic = false
		Game.player.mode = Player.Mode.WALK
	await _wait(1.2)
	var behind := Game.player.global_position + Game.player.camera.global_basis.z * 3.0 + Vector3(0, 1.1, 0)
	await _knocks(behind, 3, KNOCK_SOFT, 6.0)
	await _think(&"fb2.t4", 3.0)
	if not _skip:
		await _turn_back()


# --- 3. Цифры: шифровка называет «ОРЕХОВ В. 14.11.83» --------------------------

func _fb3() -> void:
	await _goal(&"fb3.g1", Vector3(9.2, 0, -0.75), 1.2, RADIO)
	if _skip:
		return
	_loop(NUMBERS, RADIO, -6.0)
	await _think(&"fb3.t1", 5.0)
	await _think(&"fb3.t2")
	await _think(&"fb3.t3", 5.5, Color(1.0, 0.55, 0.42))
	await _think(&"fb3.t4")
	_stop_loops()
	await _wait(1.6)
	Game.audio.play_3d(STATIC, RADIO, -2.0, 4.0, 2.0)
	await _think(&"fb3.t5", 4.0)


# --- 4. Приказ без пароля, следы его размера, «не оборачивайся» ----------------

func _fb4() -> void:
	await _wait(1.0)
	Game.audio.play_3d(STATIC, RADIO, -4.0, 5.0, 3.0)
	await _think(&"fb4.t1", 5.5)
	await _think(&"fb4.t2")
	await _goal(&"fb4.g1", VEST, 1.1)
	var st := Game.level as Station
	if st != null and not _skip:
		st.set_door_open(true)
	# Следы от леса к крыльцу — ровная цепочка, валенок сорок третьего размера
	var from := Vector3(30.0, 0, 9.0)
	var to := Vector3(16.6, 0, 3.4)
	var step_m := Geo.box_mesh(Vector3(0.13, 0.012, 0.29), Palette.m(&"dark"))
	var n := 18
	for i in n:
		var k := float(i) / float(n - 1)
		var pos := from.lerp(to, k) + Vector3(0, 0, 0.14 if i % 2 == 0 else -0.14)
		var foot := step_m.duplicate() as Node3D
		Game.level.add_child(foot)
		_nodes.append(foot)
		foot.global_position = Vector3(pos.x, _ground(pos.x, pos.z) + 0.01, pos.z)
		foot.look_at(foot.global_position + (to - from).normalized(), Vector3.UP)
	step_m.free()
	_snow_light(Vector3(18.5, 2.4, 4.5), 0.8)
	await _goal(&"fb4.g1", PORCH, 1.2, Vector3(20.0, 0.0, 4.6))
	await _think(&"fb4.t3")
	if _skip:
		return
	Game.audio.play_2d(WHISPER, 2.0)
	Game.hud.subtitle(Loc.t(&"fb4.v1"), 3.0, 2)
	# Обернёшься — обрыв с криком. Не обернёшься — обрыв через четыре секунды.
	var back := Game.player.camera.global_basis.z
	var t := 0.0
	while t < 4.0 and not _skip:
		await get_tree().process_frame
		t += get_process_delta_time()
		if (-Game.player.camera.global_basis.z).dot(back) > 0.3:
			await Game.hud.flash_face(0.14)
			break


# --- 5. Под полом: наушники, в них — сводка Орехова из 1983-го ------------------

func _fb5() -> void:
	await _goal(&"fb5.g1", STORE, 1.3)
	if _skip:
		return
	_loop(HUM, STORE + Vector3(0, -0.6, 0), 2.0)
	Game.player.shake(0.012, 1.2)
	var cord := Geo.box_mesh(Vector3(0.012, 0.012, 0.7), Palette.m(&"dark"))
	Game.level.add_child(cord)
	_nodes.append(cord)
	cord.global_position = PHONES + Vector3(0, 0.01, -0.3)
	var phones := Geo.box_mesh(Vector3(0.18, 0.06, 0.08), Palette.m(&"dark"))
	Game.level.add_child(phones)
	_nodes.append(phones)
	phones.global_position = PHONES + Vector3(0, 0.03, 0)
	await _think(&"fb5.t1")
	await _goal(&"fb5.g2", PHONES, 1.3, PHONES, true)
	if _skip:
		return
	phones.visible = false
	_stop_loops()
	_loop(STATIC, Game.player.global_position + Vector3(0, 1.6, 0), -14.0)
	await _think(&"fb5.v1", 6.5)
	await _think(&"fb5.t2")
	await _wait(1.4)
	await _think(&"fb5.v2", 4.5)


# --- 6. Гость: лицо Орехова в глазке, засов, кровать, последняя запись ---------

func _fb6() -> void:
	await _wait(1.2)
	await _knocks(DOOR, 3, KNOCK_SOFT, 0.0)
	await _think(&"fb6.t1")
	await _goal(&"fb6.g1", VEST, 0.9, DOOR)
	var guest := _double(&"orekhov", Vector3(15.6, 0.0, 3.1), Vector3(14.0, 0, 3.1))
	if not _skip:
		Game.player.mode = Player.Mode.LOCKED
		Game.player.global_position = VEST
		Game.hud.cinematic = true
		var peep := PeepholeUI.new()
		Game.hud.open_modal(peep)
		await _wait(1.2)
		if guest != null:
			peep.call(&"_press_face", guest)
		await _think(&"fb6.t2")
		Game.hud.close_modal()
		Game.hud.cinematic = false
		Game.player.mode = Player.Mode.WALK
	if is_instance_valid(guest):
		guest.global_position = Vector3(15.6, 0.0, 3.1)
		guest.look_at(Vector3(14.0, 0.0, 3.1), Vector3.UP)
	await _goal(&"fb6.g2", VEST, 1.3, DOOR, true)
	await _think(&"fb6.t3")
	var st := Game.level as Station
	if st != null and not _skip:
		Game.audio.play_3d(CLANK, DOOR, -2.0, 4.0)
		st.set_door_open(true)
		await _wait(0.8)
	# Гость идёт через дом — мимо, не глядя — и ложится на кровать лицом к стене.
	if is_instance_valid(guest) and not _skip:
		var path := [Vector3(14.2, 0, 3.05), Vector3(11.5, 0, 3.15), Vector3(7.9, 0, 3.05), Vector3(6.6, 0, 3.2),
			Vector3(3.5, 0, 3.15), Vector3(0.6, 0, 3.9), Vector3(-1.0, 0, 4.4)]
		if guest.has_clip(&"walk"):
			guest.pose_override = &"walk"
		for pt: Vector3 in path:
			if _skip:
				break
			var d := guest.global_position.distance_to(pt)
			if d > 0.05:
				guest.look_at(Vector3(pt.x, guest.global_position.y, pt.z), Vector3.UP)
			var tw := create_tween()
			tw.tween_property(guest, "global_position", pt, d / 1.1)
			while tw.is_running() and not _skip:
				await get_tree().process_frame
			Game.audio.play_3d("res://assets/audio/step_wood_%d.ogg" % (1 + randi() % 7), pt, -6.0, 3.0)
		guest.pose_override = &"still"
		guest.global_position = BED + Vector3(0, 0.52, -0.9)
		guest.rotation = Vector3(deg_to_rad(90.0), 0.0, 0.0)
	await _think(&"fb6.t4")
	await _goal(&"fb6.g3", TABLE, 1.4, TABLE)
	await _think(&"fb6.t5", 5.5, Color(1.0, 0.55, 0.42))
	await _think(&"fb6.t6")
	await _goal(&"fb6.g4", PORCH, 1.3)
	if _skip:
		return
	Game.audio.play_2d(GUST, 4.0)
	await _wait(1.8)
	Game.audio.play_2d(WHISPER, 0.0)
	await _wait(1.2)
