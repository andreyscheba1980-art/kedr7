class_name Dog
extends Node3D
## Найда — лайка-подросток с лесосеки. Её бросила бригада: лежит под нарами в вагончике, замерзает.
## Берёшь на руки, везёшь на «Буране» домой, кладёшь у печки, кормишь — день за днём она оживает:
## слабая (дрожит у печки) → поправляется (спит, сидит) → здорова (ходит за тобой по комнате, радуется, лает).
## Чует Ырку раньше тебя: рычит на окно и дверь. На голос из леса не реагирует — это тоже подсказка.
## Умереть не может: голод только отнимает силы.
## Здоровая (75+) — компаньон: свист [H] коротко — «Ко мне / Рядом» ↔ «Сидеть»; держать — «Домой».
## Рядом с ней на морозе остываешь медленнее, напряжение копится медленнее, погладить — легче.
## Едет на «Буране» сзади. Ночью рычит в сторону твари; в погоне может сорваться в лес — ищи по следам.

enum Where { CAMP, HELD, GROUND, HOME, LOST, FOLLOW, STAY }

const STOVE_SPOT := Vector3(-0.9, 0.0, 2.15)
const BED_SPOT := Vector3(-0.35, 0.0, 5.3)
const BOWL_POS := Vector3(-0.35, 0.0, 1.95)
const ROOM_MIN := Vector2(-2.3, 0.2)
const ROOM_MAX := Vector2(3.3, 6.4)
const WALK := 1.1
const RUN := 2.4
const RUN_FAR := 5.2           ## догоняет игрока, отставшего на десяток метров
const FOLLOW_MIN := 75.0       ## с какого здоровья ходит с тобой
const NEAR_M := 3.5            ## «рядом»: греет и успокаивает
const WHISTLE_HOLD := 0.55

static var instance: Dog

var where := Where.CAMP
var _model: Node3D
var _anim: AnimationPlayer
var _clip := &""
var _it: Interactable
var _bowl: Node3D
var _whine_t := 6.0
var _growl_t := 10.0
var _think_t := 0.0
var _target := Vector3.INF
var _busy_t := 0.0          ## одноразовый клип (ест, радуется) — не перебивать
var _yaw := 0.0
var _fleeing := false
var _flee_t := 0.0
var _trail: Node3D
var _whistle_t := -1.0         ## сколько держат свист
var _lost_sight_t := 0.0
var _pet_cd := 0.0
var _on_buran := false
var _bolted_tonight := false
var _uncanny := false
var _uncanny_t := 0.0
var _uncanny_cooldown := 90.0
var _uncanny_eyes: Node3D = null


static func health() -> float:
	return float(SaveGame.flags.get("dog_health", 12.0))


static func set_health(v: float) -> void:
	SaveGame.flags["dog_health"] = clampf(v, 5.0, 100.0)


static func is_home() -> bool:
	return SaveGame.flags.get("dog_state", "") == "home"


## Двор вызывает при постройке: щенок на лесосеке или дома у печки.
static func ensure(yard: Node3D) -> void:
	# Старая Найда из прошлой сцены (фон меню) ещё не удалена — queue_free отложен. Раньше из-за неё
	# новая не создавалась, и в игре, начатой из меню, Найды не было вовсе.
	if instance != null and is_instance_valid(instance) and not instance.is_queued_for_deletion() 			and instance.is_inside_tree() and yard.is_ancestor_of(instance) or (instance != null and is_instance_valid(instance) and Game.level != null and Game.level.is_ancestor_of(instance) and not instance.is_queued_for_deletion()):
		return
	var state: String = SaveGame.flags.get("dog_state", "")
	var d := Dog.new()
	var ground: Variant = SaveGame.flags.get("dog_ground", null)
	if state == "home":
		d.where = Where.HOME
		var lv: Node = Game.level if Game.level != null else yard.get_parent()
		if lv == null:
			d.free()
			return
		lv.add_child.call_deferred(d)
		d.position = STOVE_SPOT
	elif state == "lost" and Game.is_day():
		# Не нашёл за ночь — утром сама скреблась в дверь: дома, но замёрзла
		SaveGame.flags["dog_state"] = "home"
		set_health(health() - 20.0)
		SaveGame.flags["dog_came_back"] = true
		d.where = Where.HOME
		var lv2: Node = Game.level if Game.level != null else yard.get_parent()
		if lv2 == null:
			d.free()
			return
		lv2.add_child.call_deferred(d)
		d.position = STOVE_SPOT
	elif state == "lost" and ground is Array and (ground as Array).size() == 3:
		d.where = Where.LOST
		yard.add_child(d)
		d.position = Vector3(float(ground[0]), float(ground[1]), float(ground[2]))
		d._lay_trail()
	elif state == "ground" and ground is Array and (ground as Array).size() == 3:
		d.where = Where.GROUND
		yard.add_child(d)
		d.position = Vector3(float(ground[0]), float(ground[1]), float(ground[2]))
	else:
		# Не найдена (или сохранились с ней на руках) — лежит под нарами на лесосеке
		d.where = Where.CAMP
		SaveGame.flags["dog_state"] = "" if not SaveGame.flags.get("dog_found", false) else "ground"
		yard.add_child(d)
		# У торцевой двери второго КУНГа, на открытом месте: прежняя точка (11.5, -5) была внутри корпуса
		var c := Terrain.pad_pos(&"camp") + Vector3(6.2, 0.0, -4.2)
		c.y = Terrain.height(c.x, c.z)
		d.position = c
		d.rotation.y = 0.6


func _ready() -> void:
	instance = self
	name = "Naida"
	_build()
	_it = Interactable.new()
	_it.collision_layer = Geo.LAYER_INTERACT
	_it.add_child(Geo.box_shape(Vector3(0.6, 0.55, 0.9), Vector3(0, 0.27, 0)))
	_it.prompt_provider = _prompt
	_it.used.connect(_on_use)
	add_child(_it)
	if where == Where.HOME:
		_make_bowl()
		if SaveGame.flags.get("dog_came_back", false):
			SaveGame.flags["dog_came_back"] = false
			if Game.hud != null:
				Game.hud.subtitle.call_deferred(Loc.t(&"dog.came_back"), 6.0)
	_update_hunger()


func _enter_tree() -> void:
	instance = self


## Переезд между двором и домом (reparent) выводит узел из дерева — ссылку чистим только при удалении.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and instance == self:
		instance = null


# --- Модель --------------------------------------------------------------------

static func make_model() -> Array:
	var ps := Models._scene("kedr/dog")
	if ps == null:
		return []
	var inst := ps.instantiate() as Node3D
	var a := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var shader := load("res://assets/shaders/ps1_skinned.gdshader") as Shader
	var tex: Texture2D = null
	if ResourceLoader.exists("res://assets/textures/dog_dog.png"):
		tex = load("res://assets/textures/dog_dog.png") as Texture2D
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		var src := mi.get_active_material(0) as BaseMaterial3D
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter(&"tex", src.albedo_texture if src != null and src.albedo_texture != null else tex)
		m.set_shader_parameter(&"albedo", Color(1.0, 1.0, 1.0))
		m.set_shader_parameter(&"emission", 0.06)
		mi.material_override = m
	if a != null:
		for n: StringName in a.get_animation_list():
			a.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	return [inst, a]


func _build() -> void:
	var mm := make_model()
	if mm.is_empty():
		_model = Geo.block(self, Vector3(0.25, 0.3, 0.55), Vector3(0, 0.15, 0), Palette.m(&"canister"), false)
		return
	_model = mm[0]
	_anim = mm[1]
	add_child(_model)

	_uncanny_eyes = Node3D.new()
	_uncanny_eyes.name = "UncannyEyes"
	_uncanny_eyes.visible = false
	var eye_mat := StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.albedo_color = Color(0.92, 0.96, 0.45, 0.9)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.025, 0.025)
	for eye_x in [-0.045, 0.045]:
		var eye := MeshInstance3D.new()
		eye.mesh = qm
		eye.material_override = eye_mat
		eye.position = Vector3(eye_x, 0.38, 0.32)
		_uncanny_eyes.add_child(eye)
	add_child(_uncanny_eyes)

	_play(&"lie_shiver")


func _play(c: StringName, blend := 0.25) -> void:
	if _anim == null or _clip == c or not _anim.has_animation(c):
		return
	_clip = c
	_anim.play(c, blend)


# --- Взаимодействие ---------------------------------------------------------------

func _prompt() -> String:
	var p := Game.player
	if p == null:
		return ""
	match where:
		Where.CAMP, Where.GROUND, Where.LOST:
			return Loc.t(&"dog.take") if p.held == &"" else Loc.t(&"dog.hands_full")
		Where.HOME:
			if health() < 40.0:
				return Loc.t(&"dog.stroke_weak")
			if can_follow():
				return Loc.t(&"dog.pet_cmd")
			return Loc.t(&"dog.pet")
		Where.FOLLOW, Where.STAY:
			return Loc.t(&"dog.pet_cmd")
	return ""


func _on_use(p: Player) -> void:
	match where:
		Where.CAMP, Where.GROUND, Where.LOST:
			if p.held != &"":
				Game.hud.subtitle(Loc.t(&"dog.hands_full"), 2.0)
				return
			_pick_up(p)
		Where.HOME, Where.FOLLOW, Where.STAY:
			_pet()


func _pick_up(p: Player) -> void:
	var first := where == Where.CAMP
	var found_lost := where == Where.LOST
	where = Where.HELD
	if found_lost:
		Game.hud.subtitle(Loc.t(&"dog.lost_found"), 5.0)
		Director.add_tension(-15.0, "нашёл Найду")
		if _trail != null and is_instance_valid(_trail):
			_trail.queue_free()
	SaveGame.flags["dog_state"] = "held"
	visible = false
	_it.collision_layer = 0
	p.set_held(&"dog")
	Game.audio.play_3d(Voice.sfx_or(&"dog_whine", "res://assets/audio/whisper.ogg"), global_position + Vector3(0, 0.3, 0), -4.0)
	if found_lost:
		pass
	elif first:
		SaveGame.flags["dog_found"] = true
		Game.hud.subtitle(Loc.t(&"dog.found"), 6.0)
	elif not found_lost:
		Game.hud.subtitle(Loc.t(&"dog.picked"), 3.0)


## Игрок опустил щенка (drop_held): дома — к печке, на улице — лежит, где положили.
func put_down(at: Vector3) -> void:
	visible = true
	_it.collision_layer = Geo.LAYER_INTERACT
	var home := Game.level != null and Game.level.has_method("is_pos_inside_house") and Game.level.is_pos_inside_house(at)
	if home:
		where = Where.HOME
		SaveGame.flags["dog_state"] = "home"
		if get_parent() != Game.level:
			reparent(Game.level, false)
		position = STOVE_SPOT
		rotation.y = 0.4
		_make_bowl()
		Game.hud.subtitle(Loc.t(&"dog.home") if not SaveGame.flags.get("dog_home_once", false) else Loc.t(&"dog.put_down"), 6.0)
		SaveGame.flags["dog_home_once"] = true
	else:
		where = Where.GROUND
		SaveGame.flags["dog_state"] = "ground"
		if Game.yard != null and get_parent() != Game.yard:
			reparent(Game.yard, false)
		global_position = at
		SaveGame.flags["dog_ground"] = [at.x, at.y, at.z]
		Game.hud.subtitle(Loc.t(&"dog.put_snow"), 3.5)
	_play(&"lie_shiver")
	SaveGame.write()


func _pet() -> void:
	if _uncanny:
		Game.hud.subtitle(Loc.t(&"dog.uncanny_stare" if randf() < 0.5 else &"dog.uncanny_breath"), 4.5)
		Game.audio.play_3d("res://assets/audio/whisper.ogg", global_position + Vector3(0, 0.3, 0), -16.0)
		Director.add_tension(6.0, "оцепенение Найды")
		return
	if _busy_t > 0.0:
		return
	var h := health()
	_face(Game.player.global_position)
	if h < 40.0:
		_play(&"lie_shiver")
		Game.hud.subtitle(Loc.t(&"dog.stroked_weak"), 3.0)
	else:
		_play(&"happy", 0.15)
		_busy_t = 3.0
		Game.hud.subtitle(Loc.t(&"dog.petted_%d" % (randi() % 3)), 3.0)
		Game.audio.play_3d(Voice.sfx_or(&"dog_whine", "res://assets/audio/whisper.ogg"), global_position + Vector3(0, 0.4, 0), -10.0)
	Game.add_fatigue(-4.0)
	# Погладить в тайге — сильнее, чем дома у печки (но не чаще раза в полминуты)
	if Game.is_outside() and _pet_cd <= 0.0:
		_pet_cd = 30.0
		Director.add_tension(-10.0, "погладил Найду в тайге")
		Game.warmth = minf(Game.warmth + 4.0, 100.0)
	else:
		Director.add_tension(-4.0, "погладил Найду")


# --- Миска -------------------------------------------------------------------------

func _make_bowl() -> void:
	if _bowl != null and is_instance_valid(_bowl):
		return
	_bowl = Geo.interactable(Game.level, Vector3(0.3, 0.12, 0.3), BOWL_POS + Vector3(0, 0.06, 0), null, "", Callable())
	_bowl.name = "DogBowl"
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.09
	cm.height = 0.06
	cm.radial_segments = 12
	m.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.52, 0.55)
	mat.metallic = 0.6
	mat.roughness = 0.35
	m.material_override = mat
	m.position.y = -0.03
	_bowl.add_child(m)
	(_bowl as Interactable).prompt_provider = func() -> String:
		if fed_this_phase():
			return Loc.t(&"dog.bowl_full")
		if int(SaveGame.flags.get("dog_food", 0)) > 0:
			return Loc.t(&"dog.bowl_food", [int(SaveGame.flags.get("dog_food", 0))])
		if stew() > 0:
			return Loc.t(&"dog.bowl_stew", [stew()])
		return Loc.t(&"dog.bowl_empty")
	(_bowl as Interactable).used.connect(func(_p: Player) -> void: feed())


static func stew() -> int:
	return int(SaveGame.flags.get("stew", 3))


static func phase_key() -> String:
	return "%s_%d" % [Game.phase_kind, Game.phase_index]


static func fed_this_phase() -> bool:
	return SaveGame.flags.get("dog_fed", "") == phase_key()


func feed() -> void:
	if fed_this_phase():
		Game.hud.subtitle(Loc.t(&"dog.already_fed"), 2.5)
		return
	var food := int(SaveGame.flags.get("dog_food", 0))
	if food > 0:
		SaveGame.flags["dog_food"] = food - 1
		set_health(health() + 30.0)
	elif stew() > 0:
		SaveGame.flags["stew"] = stew() - 1
		set_health(health() + 22.0)
		Game.add_fatigue(4.0)    # отдал свою тушёнку — сам голодный
	else:
		Game.hud.subtitle(Loc.t(&"dog.no_food"), 4.0)
		return
	SaveGame.flags["dog_fed"] = phase_key()
	SaveGame.flags["dog_hungry"] = 0
	Game.audio.play_3d("res://assets/audio/clank.ogg", BOWL_POS, -12.0)
	# Идёт к миске и ест
	_target = BOWL_POS + Vector3(0.0, 0.0, 0.45)
	_busy_t = 0.0
	Game.hud.subtitle(Loc.t(&"dog.fed_weak") if health() < 45.0 else Loc.t(&"dog.fed"), 4.0)
	SaveGame.write()


## Голод: каждая новая фаза без еды отнимает силы, но не убивает.
func _update_hunger() -> void:
	if where != Where.HOME:
		return
	var last: String = SaveGame.flags.get("dog_phase_seen", "")
	var now := phase_key()
	if last == now:
		return
	SaveGame.flags["dog_phase_seen"] = now
	if last == "":
		return
	if SaveGame.flags.get("dog_fed", "") != last:
		SaveGame.flags["dog_hungry"] = int(SaveGame.flags.get("dog_hungry", 0)) + 1
		if int(SaveGame.flags["dog_hungry"]) >= 2:
			set_health(health() - 10.0)
	else:
		set_health(health() + 8.0)   # сытая и в тепле — поправляется за ночь


# --- Поведение ---------------------------------------------------------------------

func _process(delta: float) -> void:
	_pet_cd = maxf(_pet_cd - delta, 0.0)
	_uncanny_cooldown = maxf(_uncanny_cooldown - delta, 0.0)
	_read_whistle(delta)
	if where == Where.HELD:
		return
	_busy_t = maxf(_busy_t - delta, 0.0)
	if where == Where.FOLLOW:
		_follow(delta)
		return
	if where == Where.STAY:
		_stay(delta)
		return
	_whine_t -= delta
	if where == Where.LOST:
		_play(&"lie_shiver")
		if _whine_t <= 0.0 and Game.player != null and Game.player.global_position.distance_to(global_position) < 140.0:
			_whine_t = randf_range(7.0, 11.0)
			var s := Voice.sfx_or(&"dog_bark", "res://assets/audio/whisper.ogg") if randf() < 0.35 else Voice.sfx_or(&"dog_whine", "res://assets/audio/whisper.ogg")
			Game.audio.play_3d(s, global_position + Vector3(0, 0.3, 0), 2.0, 9.0)
		return
	if where == Where.CAMP or where == Where.GROUND:
		_play(&"lie_shiver")
		if _whine_t <= 0.0 and Game.player != null and Game.player.global_position.distance_to(global_position) < 30.0:
			_whine_t = randf_range(5.0, 9.0)
			Game.audio.play_3d(Voice.sfx_or(&"dog_whine", "res://assets/audio/whisper.ogg"), global_position + Vector3(0, 0.3, 0), -2.0, 3.0)
		return
	_home(delta)


func _home(delta: float) -> void:
	var h := health()
	if Game.is_home():
		set_health(h + delta * 0.02)          # в тепле понемногу оживает

	# Синдром Найды: Uncanny Valley оцепенение
	if not _uncanny and _uncanny_cooldown <= 0.0 and Game.is_night() and Game.night >= 3 and Game.is_home():
		var tension_high := Director.tension > 45.0 or (Game.yrka != null and Game.yrka.stage >= YrkaThreat.Stage.PRESSURE)
		if tension_high and randf() < delta * 0.05:
			_start_uncanny()

	if _uncanny:
		_tick_uncanny(delta)
		return

	if h < 40.0:
		if _target == Vector3.INF:
			_play(&"lie_shiver")
			if _whine_t <= 0.0 and Game.is_home():
				_whine_t = randf_range(14.0, 26.0)
				Game.audio.play_3d(Voice.sfx_or(&"dog_whine", "res://assets/audio/whisper.ogg"), global_position + Vector3(0, 0.3, 0), -8.0, 2.0)
		_walk(delta, WALK * 0.6)
		return
	_alert(delta)
	if _fleeing:
		_flee_step(delta)
		return
	_check_escape(delta)
	if _busy_t > 0.0:
		return
	_think_t -= delta
	if _think_t <= 0.0:
		_think_t = randf_range(4.0, 9.0)
		_choose()
	_walk(delta, WALK)


func _start_uncanny() -> void:
	_uncanny = true
	_uncanny_t = randf_range(12.0, 18.0)
	_target = Vector3.INF
	_face(Vector3(-2.4, 0.0, 0.8)) # глухой темный угол за печью
	_play(&"sit")
	if _anim != null:
		_anim.speed_scale = 0.0
	if _uncanny_eyes != null:
		_uncanny_eyes.visible = true


func _tick_uncanny(delta: float) -> void:
	_uncanny_t -= delta
	var p := Game.player
	if p == null:
		return
	var to_dog := global_position - p.global_position
	var look_dir := -p.camera.global_basis.z if p.camera != null else Vector3.FORWARD
	look_dir.y = 0.0
	var dot := look_dir.normalized().dot(to_dog.normalized())
	if _uncanny_t <= 0.0 or (_uncanny_t < 9.0 and dot < 0.25):
		_exit_uncanny()


func _exit_uncanny() -> void:
	_uncanny = false
	_uncanny_cooldown = randf_range(110.0, 220.0)
	if _anim != null:
		_anim.speed_scale = 1.0
	if _uncanny_eyes != null:
		_uncanny_eyes.visible = false
	_play(&"sit")
	if Game.player != null and global_position.distance_to(Game.player.global_position) < 3.8:
		Game.hud.subtitle(Loc.t(&"dog.uncanny_snapped"), 3.5)
		Game.audio.play_3d(Voice.sfx_or(&"dog_whine", "res://assets/audio/whisper.ogg"), global_position + Vector3(0, 0.3, 0), -6.0)


func _choose() -> void:
	var p := Game.player
	var h := health()
	var in_room := p != null and Game.zone == &"room"
	if Game.is_night() and not Game.is_home():
		_target = STOVE_SPOT       # ждёт у печки
		return
	if in_room and h >= 75.0:
		var off := Vector3(randf_range(-0.9, 0.9), 0, randf_range(0.8, 1.3)).rotated(Vector3.UP, p.rotation.y)
		var t := p.global_position + off
		t.x = clampf(t.x, ROOM_MIN.x, ROOM_MAX.x)
		t.z = clampf(t.z, ROOM_MIN.y, ROOM_MAX.y)
		t.y = 0.0
		if global_position.distance_to(t) > 1.0:
			_target = t
			return
	if _target == Vector3.INF and _anim != null:
		var r := randf()
		if h < 75.0:
			_play(&"sleep" if r < 0.6 else &"sit")
		else:
			_play(&"sit" if r < 0.45 else &"stand" if r < 0.7 else &"sleep" if r < 0.9 else &"sniff")


func _walk(delta: float, speed: float) -> void:
	if _target == Vector3.INF:
		return
	var to := _target - global_position
	to.y = 0.0
	var d := to.length()
	if d < 0.15:
		_target = Vector3.INF
		if global_position.distance_to(BOWL_POS) < 0.7 and fed_this_phase() and _busy_t <= 0.0:
			_face(BOWL_POS)
			_play(&"eat", 0.2)
			_busy_t = 5.0
			Game.audio.play_3d(Voice.sfx_or(&"dog_sniff", "res://assets/audio/clank.ogg"), BOWL_POS, -8.0, 2.0)
		else:
			_play(&"sit")
		return
	var step := minf(speed * delta, d)
	global_position += to / d * step
	_yaw = lerp_angle(_yaw, atan2(-to.x, -to.z), minf(delta * 8.0, 1.0))
	rotation.y = _yaw
	_play(&"run" if speed > 2.0 else &"walk", 0.15)


func _face(p: Vector3) -> void:
	var to := p - global_position
	_yaw = atan2(-to.x, -to.z)
	rotation.y = _yaw


## Ночью чует Ырку: рычит на окно, лает при погоне. Голос из леса её не волнует.
func _alert(delta: float) -> void:
	var y := Game.yrka
	if y == null or not Game.is_night():
		return
	_growl_t -= delta
	var st := y.stage
	if (st == YrkaThreat.Stage.CONTACT or st == YrkaThreat.Stage.CHASE) and _growl_t <= 0.0:
		_growl_t = randf_range(2.5, 4.0)
		_play(&"bark", 0.1)
		_busy_t = 1.2
		Game.audio.play_3d(Voice.sfx_or(&"dog_bark", "res://assets/audio/growl.ogg"), global_position + Vector3(0, 0.4, 0), 2.0, 6.0)
	elif st >= YrkaThreat.Stage.PRESSURE and _growl_t <= 0.0:
		_growl_t = randf_range(14.0, 24.0)
		_face(Vector3(13.5, 0, 3.5) if randf() < 0.5 else Vector3(1.0, 0, -0.5))   # дверь или окно
		_play(&"growl", 0.2)
		_busy_t = 3.0
		Game.audio.play_3d(Voice.sfx_or(&"dog_growl", "res://assets/audio/growl.ogg"), global_position + Vector3(0, 0.4, 0), -4.0, 3.0)


# --- Сцена: Найда выскочила в метель ------------------------------------------------
## Ночью, если дверь открыта, а снаружи буран или рядом Ырка, здоровая Найда может сорваться за дверь.
## По собачьим следам от крыльца — в лес, там она лежит и скулит. Не нашёл до утра — вернётся сама, замёрзшая.

func _check_escape(delta: float) -> void:
	if not Game.is_night() or Game.night < 2 or health() < 60.0 or Game.level == null:
		return
	if not bool(Game.level.get("door_open")):
		return
	var key := "dog_fled_%d" % Game.night
	if SaveGame.flags.get(key, false) or SaveGame.flags.get("dog_fled_%d" % (Game.night - 1), false):
		return
	var storm: bool = Game.weather != null and Game.weather.blizzard
	var yrka_near: bool = Game.yrka != null and Game.yrka.stage >= YrkaThreat.Stage.PRESSURE
	if not (storm or yrka_near or Game.after_hour(1)):
		return
	if randf() > delta * 0.06:   # в среднем ~15 с открытой двери
		return
	SaveGame.flags[key] = true
	_fleeing = true
	_flee_t = 0.0
	_target = Vector3.INF
	_play(&"bark", 0.1)
	Game.audio.play_3d(Voice.sfx_or(&"dog_bark", "res://assets/audio/growl.ogg"), global_position + Vector3(0, 0.4, 0), 2.0, 6.0)
	Game.hud.subtitle(Loc.t(&"dog.fled"), 5.0, 2)


func _flee_step(delta: float) -> void:
	_flee_t += delta
	if _flee_t < 0.6:
		return
	var exit := Vector3(3.5, 0.0, 4.6)          # дверь из комнаты в коридор
	var to := exit - global_position
	to.y = 0.0
	if to.length() > 0.2 and _flee_t < 3.0:
		global_position += to.normalized() * minf(RUN * delta, to.length())
		rotation.y = atan2(-to.x, -to.z)
		_play(&"run", 0.1)
		return
	_fleeing = false
	_run_away()


func _run_away() -> void:
	where = Where.LOST
	SaveGame.flags["dog_state"] = "lost"
	Game.audio.play_3d("res://assets/audio/door.ogg", Vector3(14.3, 1.0, 3.5), -2.0)
	# Куда: 55–90 м от крыльца, в сторону леса
	var porch := Vector3(16.8, 0.0, 3.5)
	var ang := randf_range(-PI * 0.75, PI * 0.25)
	var dist := randf_range(55.0, 90.0)
	var spot := porch + Vector3(cos(ang), 0, sin(ang)) * dist
	spot.y = Terrain.height(spot.x, spot.z)
	SaveGame.flags["dog_ground"] = [spot.x, spot.y, spot.z]
	if Game.yard != null:
		reparent(Game.yard, false)
	global_position = spot
	rotation.y = randf() * TAU
	_bowl_hide()
	_lay_trail()
	Director.add_tension(20.0, "Найда убежала")
	SaveGame.write()


## Цепочка собачьих следов от крыльца, петляет к месту, где она лежит.
func _lay_trail() -> void:
	if Game.yard == null:
		return
	var porch := Vector3(16.8, 0.0, 3.5)
	var spot := global_position
	var route := PackedVector3Array()
	route.append(porch)
	var n := 6
	var side := Vector3(-(spot - porch).z, 0, (spot - porch).x).normalized()
	for i in range(1, n):
		var t := float(i) / n
		var p := porch.lerp(spot, t) + side * sin(t * PI * 2.0 + spot.x) * 4.0
		route.append(p)
	route.append(spot)
	for i in route.size():
		var q := route[i]
		q.y = Terrain.height(q.x, q.z) + 0.02
		route[i] = q
	_trail = Node3D.new()
	_trail.name = "NaidaTrail"
	Game.yard.add_child(_trail)
	for i in range(route.size() - 1):
		var seg := PackedVector3Array([route[i], route[i + 1]])
		var part := Footprints.trail(_trail, &"paw", seg, (route[i].y + route[i + 1].y) * 0.5, 0.36, 0.06)
		part.name = "seg%d" % i
		for fp: Node in part.get_children():
			(fp as Node3D).scale *= 1.8          # в темноте под фонарём их должно быть видно


func _bowl_hide() -> void:
	pass


## Охотник ставит засаду на привычной тропе — Найда замирает и рычит туда (раньше, чем ты услышишь).
func warn_toward(at: Vector3) -> void:
	if _on_buran:
		return
	_face(at)
	_play(&"growl", 0.1)
	_busy_t = 3.0
	_growl_t = 8.0
	Game.audio.play_3d(Voice.sfx_or(&"dog_growl", "res://assets/audio/growl.ogg"), global_position + Vector3(0, 0.4, 0), 0.0, 6.0)
	Game.hud.subtitle(Loc.t(&"dog.warns"), 3.5)


# --- Компаньон: свист, «рядом», «сидеть», «домой» ---------------------------------------

static func can_follow() -> bool:
	return health() >= FOLLOW_MIN


## Рядом ли Найда с игроком (для тепла и Режиссёра)
static func is_near_player() -> bool:
	var d := instance
	if d == null or not is_instance_valid(d) or Game.player == null:
		return false
	if d._on_buran:
		return true
	if d.where != Where.FOLLOW and d.where != Where.STAY and d.where != Where.HOME:
		return false
	return d.is_inside_tree() and d.visible and d.global_position.distance_to(Game.player.global_position) < NEAR_M


func _read_whistle(delta: float) -> void:
	if Game.player == null or Game.dead or not InputMap.has_action(&"whistle"):
		return
	if Game.player.mode != Player.Mode.WALK and not Game.has_flag("riding"):
		return
	if Input.is_action_just_pressed(&"whistle"):
		_whistle_t = 0.0
	elif _whistle_t >= 0.0 and Input.is_action_pressed(&"whistle"):
		_whistle_t += delta
		if _whistle_t >= WHISTLE_HOLD:
			_whistle_t = -1.0
			whistle(true)
	elif _whistle_t >= 0.0:
		_whistle_t = -1.0
		whistle(false)


## Свист: коротко — «ко мне / рядом» или «сидеть»; long — «домой».
func whistle(long: bool) -> void:
	var p := Game.player
	Game.audio.play_3d("res://assets/audio/whistle_v2.ogg", p.global_position + Vector3(0, 1.6, 0), -6.0 if long else -10.0, 30.0)
	if where == Where.HELD or where == Where.CAMP or where == Where.GROUND:
		return
	var dist := global_position.distance_to(p.global_position) if is_inside_tree() else 999.0
	if where == Where.LOST:
		# Потерялась — отзывается лаем, если рядом: по звуку и следам её и ищут
		if dist < 90.0:
			Game.audio.play_3d(Voice.sfx_or(&"dog_bark", "res://assets/audio/growl.ogg"), global_position + Vector3(0, 0.3, 0), 4.0, 14.0)
		return
	if not can_follow():
		if where == Where.HOME and Game.is_home():
			Game.hud.subtitle(Loc.t(&"dog.too_weak"), 3.0)
		return
	if long:
		_command_home()
		return
	match where:
		Where.FOLLOW:
			_command_stay()
		Where.STAY, Where.HOME:
			if dist < 70.0 or (where == Where.HOME and Game.is_home()):
				_command_follow()
			else:
				Game.hud.subtitle(Loc.t(&"dog.too_far"), 3.0)


func _command_follow() -> void:
	where = Where.FOLLOW
	SaveGame.flags["dog_state"] = "home"      # между фазами она дома: смена начинается у печки
	if get_parent() != Game.level:
		reparent(Game.level, true)
	_target = Vector3.INF
	_busy_t = 0.0
	_play(&"happy", 0.15)
	Game.hud.subtitle(Loc.t(&"dog.cmd_follow"), 2.5)


func _command_stay() -> void:
	where = Where.STAY
	_target = Vector3.INF
	_play(&"sit", 0.2)
	Game.hud.subtitle(Loc.t(&"dog.cmd_stay"), 2.5)


func _command_home() -> void:
	if where == Where.HOME:
		return
	Game.hud.subtitle(Loc.t(&"dog.cmd_home"), 3.0)
	_go_home()


func _go_home() -> void:
	where = Where.HOME
	_on_buran = false
	visible = true
	_it.collision_layer = Geo.LAYER_INTERACT
	SaveGame.flags["dog_state"] = "home"
	if get_parent() != Game.level:
		reparent(Game.level, false)
	position = STOVE_SPOT
	rotation = Vector3.ZERO
	_target = Vector3.INF
	_make_bowl()


func _ground_y(at: Vector3) -> float:
	if Game.level != null and Game.level.has_method("is_pos_inside_house") and Game.level.is_pos_inside_house(at + Vector3(0, 0.3, 0)):
		return 0.0 if at.y < 2.5 else 2.95
	if Terrain.ready():
		return Terrain.height(at.x, at.z)
	return at.y


func _follow(delta: float) -> void:
	var p := Game.player
	if p == null:
		return
	# На «Буране» — едет сзади на сиденье
	if Game.has_flag("riding") and Snowmobile.instance != null:
		if not _on_buran:
			_on_buran = true
			_it.collision_layer = 0
			reparent(Snowmobile.instance, false)
			position = Vector3(0.0, 0.62, 0.95)
			rotation = Vector3.ZERO
			_play(&"sit", 0.2)
		_follow_alert(delta)
		return
	if _on_buran:
		_on_buran = false
		_it.collision_layer = Geo.LAYER_INTERACT
		var off := Snowmobile.instance.global_basis.x * -1.2 if Snowmobile.instance != null else Vector3(1, 0, 0)
		var at := global_position + off
		reparent(Game.level, true)
		at.y = _ground_y(at)
		global_position = at
		rotation = Vector3.ZERO
		Game.hud.subtitle(Loc.t(&"dog.off_buran"), 2.5)
	var pp := p.global_position
	var d := Vector2(pp.x - global_position.x, pp.z - global_position.z).length()
	# Потеряла из виду (стены, дверь, отстала на 25+ м) — догоняет «из-за угла», за спиной игрока
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.4, 0), p.head.global_position, Geo.LAYER_WORLD, [p.get_rid()])
	var blocked := not get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	_lost_sight_t = (_lost_sight_t + delta) if (blocked or d > 25.0) else 0.0
	if _lost_sight_t > 2.5 or d > 45.0:
		_lost_sight_t = 0.0
		var at2 := pp + p.global_basis.z * 1.6 + p.global_basis.x * 0.6
		at2.y = _ground_y(at2)
		global_position = at2
		return
	_follow_alert(delta)
	if _busy_t > 0.0:
		_busy_t = maxf(_busy_t - delta, 0.0)
		return
	if d > 2.2:
		var side := p.global_basis.x * (0.8 if int(Time.get_ticks_msec() / 9000) % 2 == 0 else -0.8)
		_target = pp + p.global_basis.z * 1.2 + side
		var speed := RUN_FAR if d > 9.0 else RUN if d > 4.0 else WALK * 1.3
		_walk(delta, speed)
		global_position.y = _ground_y(global_position)
	else:
		_target = Vector3.INF
		_think_t -= delta
		if _think_t <= 0.0:
			_think_t = randf_range(3.0, 7.0)
			var r := randf()
			_play(&"sniff" if r < 0.45 else &"sit" if r < 0.8 else &"stand")
			_face(pp)


func _stay(delta: float) -> void:
	_play(&"sit")
	_whine_t -= delta
	if Game.is_night() and _whine_t <= 0.0 and Game.player != null and Game.player.global_position.distance_to(global_position) < 40.0:
		_whine_t = randf_range(10.0, 18.0)
		Game.audio.play_3d(Voice.sfx_or(&"dog_whine", "res://assets/audio/whisper.ogg"), global_position + Vector3(0, 0.3, 0), -4.0, 6.0)
	_follow_alert(delta)


## На улице ночью: замирает и рычит в сторону твари; в погоне может сорваться в лес.
func _follow_alert(delta: float) -> void:
	var y := Game.yrka
	if y == null or not Game.is_night():
		return
	_growl_t -= delta
	var to_y := Vector3(y.virtual_pos.x, global_position.y, y.virtual_pos.y)
	if y.stage == YrkaThreat.Stage.CHASE and where == Where.FOLLOW and not _on_buran and not _bolted_tonight:
		_bolted_tonight = true
		if randf() < 0.5:
			_bolt()
			return
	if y.stage >= YrkaThreat.Stage.PRESSURE and _growl_t <= 0.0:
		_growl_t = randf_range(6.0, 11.0)
		if not _on_buran:
			_face(to_y)
		_play(&"growl", 0.2)
		_busy_t = 2.5
		Game.audio.play_3d(Voice.sfx_or(&"dog_growl", "res://assets/audio/growl.ogg"), global_position + Vector3(0, 0.4, 0), -2.0, 5.0)


## Сорвалась в погоне: убегает в сторону, лежит там и скулит. Свистни — отзовётся лаем; по следам — найти.
func _bolt() -> void:
	where = Where.LOST
	SaveGame.flags["dog_state"] = "lost"
	_play(&"run", 0.1)
	Game.audio.play_3d(Voice.sfx_or(&"dog_bark", "res://assets/audio/growl.ogg"), global_position + Vector3(0, 0.4, 0), 4.0, 8.0)
	Game.hud.subtitle(Loc.t(&"dog.bolted"), 5.0, 2)
	var from := global_position
	var ang := randf() * TAU
	var spot := from + Vector3(cos(ang), 0, sin(ang)) * randf_range(35.0, 60.0)
	spot.y = Terrain.height(spot.x, spot.z)
	SaveGame.flags["dog_ground"] = [spot.x, spot.y, spot.z]
	if Game.yard != null:
		reparent(Game.yard, false)
	global_position = spot
	_lay_trail_from(from)
	Director.add_tension(15.0, "Найда сорвалась в лес")
	SaveGame.write()


func _lay_trail_from(start: Vector3) -> void:
	if Game.yard == null:
		return
	var seg := PackedVector3Array([start, global_position])
	_trail = Node3D.new()
	_trail.name = "NaidaTrail"
	Game.yard.add_child(_trail)
	var part := Footprints.trail(_trail, &"paw", seg, (start.y + global_position.y) * 0.5, 0.36, 0.06)
	for fp: Node in part.get_children():
		(fp as Node3D).scale *= 1.8
