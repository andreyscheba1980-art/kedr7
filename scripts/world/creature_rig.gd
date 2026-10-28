class_name CreatureRig
extends Node3D
## Процедурная анимация существа без скелета: части висят на опорных узлах (pivots),
## их повороты качаются по синусам. gait 0 — стоит (дыхание, подёргивания головы), 1 — бег.

var gait := 0.0
var gait_speed := 9.0          ## частота шага при беге, рад/с
var twitch := 0.6              ## насколько дёргается голова (0 — не дёргается)
var breath := 1.0

var stepped_mode := true          ## дискретная 12 Гц анимация для жуткого PS1 стоп-моушн эффекта
var stepped_hz := 12.0
var _stepped_acc := 0.0
var _cached_materials: Array[ShaderMaterial] = []
var _eye_mats: Array[ShaderMaterial] = []   ## только глаза: блестят в луче, остальное тело — нет
var auto_eyeshine := true                   ## глаза сами вспыхивают, когда на голову падает луч фонаря
var eye_glow_min := 0.0                     ## тлеют и без луча (Жердяй: две искры высоко между елями)

## Плавный поворот головы (отслеживание собеседника, взгляд на дежурного)
var head_look_target_yaw := 0.0
var head_look_yaw := 0.0
var head_look_target_pitch := 0.0
var head_look_pitch := 0.0
var seated := false
var talk := 0.0                 ## сколько ещё говорит: жестикулирует и кивает
var engine_vibe := 0.0

var _pivots: Dictionary = {}   ## имя → Node3D
var _rest: Dictionary = {}     ## имя → исходный поворот
var _t := 0.0
var _twitch_t := 0.0
var _twitch_target := Vector3.ZERO
var _twitch_now := Vector3.ZERO
var _rng := RandomNumberGenerator.new()

## Скелетная версия (модель из Блендера с клипами). Без неё работает старая «шарнирная» анимация.
var anim: AnimationPlayer
var skel: Skeleton3D
var pose_override: StringName = &""   ## принудительный клип: peek, sniff, lunge, pin…
var _clip: StringName = &""
var _head_bone := -1
var _anim_acc := 0.0
var _idle_t := 4.0
var _idle_clip: StringName = &"idle"
var clip_walk: StringName = &"stalk"   ## клип шага (у Ырки — «крадётся», у людей — walk)
var clip_run: StringName = &"run"
var idle_alts: Array = []              ## чем разбавлять стояние (Ырка нюхает, тени замирают)
var _bone_add: Dictionary = {}         ## имя кости → Quaternion, добавляется поверх клипа
var _bone_idx: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	_t = _rng.randf() * 10.0
	_gather_materials(self)


func _gather_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.material_override is ShaderMaterial:
			var sm := mi.material_override as ShaderMaterial
			if sm.has_meta(&"eye"):
				if not _eye_mats.has(sm):
					_eye_mats.append(sm)
			else:
				_cached_materials.append(sm)
	for child in node.get_children():
		_gather_materials(child)


## Управление блеском глаз в луче фонарика дежурного
## (Раньше блеск ставился на все материалы существа — и в луче зеленовато светилось всё тело.)
func set_eye_glow(intensity: float) -> void:
	for mat: ShaderMaterial in _eye_mats:
		mat.set_shader_parameter(&"eye_glow", intensity)


## Блеск глаз от фонаря дежурного: только когда луч смотрит почти точно на голову и она не дальше 30 м.
func _update_eyeshine() -> void:
	var p := Game.player
	if p == null or p.camera == null:
		return
	var head := pivot(&"Head")
	var head_pos := head.global_position + Vector3(0, 0.12, 0) if head != null else global_position + Vector3(0, 1.5, 0)
	var k := 0.0
	if p.flashlight_on() and Game.flash_charge > 0.0:
		var to_mob := head_pos - p.camera.global_position
		var d := to_mob.length()
		if d < 30.0 and d > 0.01:
			k = pow(maxf((-p.camera.global_basis.z).dot(to_mob / d), 0.0), 18.0) * clampf(1.4 - d / 30.0, 0.0, 1.0)
	set_eye_glow(maxf(k * 2.8, eye_glow_min))


func add_pivot(id: StringName, node: Node3D) -> void:
	_pivots[id] = node
	_rest[id] = node.rotation


## Поменять «позу покоя» сустава: ручной поворот головы иначе затрётся анимацией в следующем кадре.
## У существ со скелетом — добавка к кости поверх клипа ("Head" → кость head).
func set_rest(id: StringName, rot: Vector3) -> void:
	if anim != null:
		_bone_add[StringName(String(id).to_lower())] = Quaternion.from_euler(rot)
		return
	if _pivots.has(id):
		_rest[id] = rot


## Жердяй: наклон в поясе (0 — стоит, 83 — сложился и заглядывает в окно). Позы сделаны в Блендере.
func set_bend(deg: float) -> void:
	if deg > 70.0:
		pose_override = &"bend83"
	elif deg > 20.0:
		pose_override = &"bend45"
	else:
		pose_override = &""


func pivot(id: StringName) -> Node3D:
	var n: Node3D = _pivots.get(id)
	if n == null and anim != null:
		n = get_node_or_null(NodePath(String(id))) as Node3D
	return n


func setup_skeletal(a: AnimationPlayer, s: Skeleton3D) -> void:
	anim = a
	skel = s
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for n: StringName in anim.get_animation_list():
		var clip := anim.get_animation(n)
		clip.loop_mode = Animation.LOOP_NONE if n == &"lunge" else Animation.LOOP_LINEAR
	_head_bone = skel.find_bone("head")
	_play(&"idle")
	anim.advance(0.0)


func has_clip(n: StringName) -> bool:
	return anim != null and anim.has_animation(n)


func _play(n: StringName) -> void:
	if _clip == n or not anim.has_animation(n):
		return
	_clip = n
	anim.play(n, 0.0)
	if n != &"lunge":
		anim.seek(_rng.randf() * anim.get_animation(n).length, true)


func _process_skeletal(delta: float) -> void:
	var want := pose_override
	if want == &"" and seated:
		want = &"sit_talk" if talk > 0.0 and anim.has_animation(&"sit_talk") else &"sit_drive"
	if want == &"":
		if gait > 0.6:
			want = clip_run
		elif gait > 0.12:
			want = clip_walk
		else:
			# Стоит: то замирает, то принюхивается
			_idle_t -= delta
			if _idle_t <= 0.0:
				if _idle_clip == &"idle" and not idle_alts.is_empty():
					_idle_clip = idle_alts[_rng.randi() % idle_alts.size()]
					_idle_t = _rng.randf_range(2.5, 6.0)
				else:
					_idle_clip = &"idle"
					_idle_t = _rng.randf_range(3.0, 8.0)
			want = _idle_clip
	_play(want)
	if seated:
		talk = maxf(talk - delta, 0.0)
	anim.speed_scale = gait_speed / 13.0 if _clip == &"run" and clip_run == &"run" and name == "Yrka" else 1.0
	_anim_acc += delta
	var step := 1.0 / stepped_hz if stepped_mode else 0.0
	if _anim_acc < step:
		return
	anim.advance(_anim_acc)
	_anim_acc = 0.0
	# Поверх клипа — птичьи подёргивания головы и взгляд на цель
	_twitch_t -= step if stepped_mode else delta
	if _twitch_t <= 0.0:
		_twitch_t = _rng.randf_range(0.35, 1.8)
		_twitch_target = Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.4, 0.4), _rng.randf_range(-0.3, 0.3)) * twitch * 0.6
	_twitch_now = _twitch_now.lerp(_twitch_target, 0.45)
	head_look_yaw = lerp_angle(head_look_yaw, head_look_target_yaw, 0.3)
	head_look_pitch = lerpf(head_look_pitch, head_look_target_pitch, 0.3)
	for bn: StringName in _bone_add:
		var bi: int = _bone_idx.get(bn, -2)
		if bi == -2:
			bi = skel.find_bone(String(bn))
			_bone_idx[bn] = bi
		if bi >= 0:
			skel.set_bone_pose_rotation(bi, skel.get_bone_pose_rotation(bi) * (_bone_add[bn] as Quaternion))
	if _head_bone >= 0:
		var add := Quaternion.from_euler(_twitch_now + Vector3(head_look_pitch, head_look_yaw, 0.0))
		skel.set_bone_pose_rotation(_head_bone, skel.get_bone_pose_rotation(_head_bone) * add)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	if auto_eyeshine and not _eye_mats.is_empty():
		_update_eyeshine()
	if anim != null:
		_process_skeletal(delta)
		return

	# Дискретный шаг 12 Гц для жуткого эффекта стоп-моушн (совет Клода):
	# Ноги качаются плавно, а голова, челюсть и судорожные рывки обновляются с частотой 12 кадров/сек.
	var do_step := true
	if stepped_mode:
		_stepped_acc += delta
		if _stepped_acc >= 1.0 / stepped_hz:
			_stepped_acc = 0.0
			do_step = true
		else:
			do_step = false

	var swing := sin(_t * gait_speed) * gait
	_rot(&"LegL", Vector3(swing * 0.75, 0, 0))
	_rot(&"LegR", Vector3(-swing * 0.75, 0, 0))

	# Плавное сведение поворота головы к цели
	head_look_yaw = lerp_angle(head_look_yaw, head_look_target_yaw, minf(delta * 4.5, 1.0))
	head_look_pitch = lerpf(head_look_pitch, head_look_target_pitch, minf(delta * 4.5, 1.0))

	if do_step or not stepped_mode:
		talk = maxf(talk - ((1.0 / stepped_hz) if stepped_mode else delta), 0.0)
		var tk := clampf(talk, 0.0, 1.0)
		if seated and engine_vibe > 0.0:
			var vibe := sin(_t * 52.0) * engine_vibe
			# Говорит — правая рука отрывается от рычага: короткие жесты в такт словам
			var gest := (maxf(sin(_t * 3.1), 0.0) * 0.55 + sin(_t * 7.3) * 0.08) * tk
			_rot(&"ArmL", Vector3(vibe * 0.008 + sin(_t * 1.3) * 0.015 * breath, 0, 0))
			_rot(&"ArmR", Vector3(-vibe * 0.008 + sin(_t * 1.1 + 1.0) * 0.015 * breath - gest, 0, -gest * 0.4))
			_rot(&"Chest", Vector3(sin(_t * 1.6) * 0.02 * breath + vibe * 0.004 + sin(_t * 2.2) * 0.03 * tk, sin(_t * 1.4) * 0.05 * tk, 0))
		else:
			_rot(&"ArmL", Vector3(-swing * 0.9 + sin(_t * 1.3) * 0.03 * breath, 0, 0))
			_rot(&"ArmR", Vector3(swing * 0.9 + sin(_t * 1.1 + 1.0) * 0.03 * breath, 0, 0))
			_rot(&"Chest", Vector3(sin(_t * 1.6) * 0.02 * breath, 0, 0))

		# Голова: редкие резкие подёргивания — как у птицы + плавный взгляд на цель
		_twitch_t -= (1.0 / stepped_hz) if stepped_mode else delta
		if _twitch_t <= 0.0:
			_twitch_t = _rng.randf_range(0.35, 1.8)
			_twitch_target = Vector3(_rng.randf_range(-0.35, 0.35), _rng.randf_range(-0.45, 0.45), _rng.randf_range(-0.35, 0.35)) * twitch
		_twitch_now = _twitch_now.lerp(_twitch_target, 0.45 if stepped_mode else minf(delta * 18.0, 1.0))
		var nod := sin(_t * 4.2) * 0.07 * clampf(talk, 0.0, 1.0)
		_rot(&"Head", _twitch_now + Vector3(swing * 0.1 + head_look_pitch + nod, head_look_yaw, 0))
		var chat := absf(sin(_t * 11.0)) * 0.22 * clampf(talk, 0.0, 1.0)
		_rot(&"Jaw", Vector3(0.15 + sin(_t * 2.3) * 0.08 + chat, 0, 0))


func _rot(id: StringName, add: Vector3) -> void:
	var n: Node3D = _pivots.get(id)
	if n != null:
		n.rotation = (_rest[id] as Vector3) + add

