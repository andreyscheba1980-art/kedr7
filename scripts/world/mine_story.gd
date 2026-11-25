class_name MineStory
extends Node
## Ночь 4 — «Логово». Сюжетная вылазка в «Горизонт-40»:
##   1. Большая Земля по рации: на 4170 сигнал идёт из старой штольни (POI 11) — снять с треноги
##      у устья маяк Дубова с кассетой.
##   2. Катсцена «Провал»: под ногами трещит наледь, пол уходит, падение, темнота. Очнулся в забое.
##   3. Логово: кости, лёжки из ватников пропавших дежурных, их вещи; кассета выпала рядом.
##   4. Стелс: оно ходит по штреку. Видит луч фонаря издалека и тебя вблизи, слышит бег; задержанное
##      дыхание и темнота спасают, за поворотом рассечки — не видно. Заметило — погоня; поймало —
##      снова в забое (без смерти, как контрольная точка). Ракета отгоняет.
##   5. У самого выхода: крик в глубине, топот — оно бежит сюда. Добеги до лестницы.
##   6. Катсцена «Наверх»: вылез, внизу в темноте — два огня глаз. Тишина.

const ROOT := MineHorizon.ROOT
const FALL_LOCAL := Vector3(0.6, 0.05, -41.8)      ## где очнулся — забой
const LADDER_LOCAL := Vector3(0.0, 0.05, 1.2)
const PATROL: Array[Vector3] = [Vector3(0, 0, -30), Vector3(0, 0, -20), Vector3(0, 0, -8), Vector3(0, 0, -16), Vector3(-7, 0, -26), Vector3(0, 0, -26)]
const RUN_TRIGGER_Z := -9.0                        ## ближе к стволу — оно бросается из глубины
const STEP := "res://assets/audio/yrka_steps.ogg"
const SHRIEK := "res://assets/audio/shriek.ogg"
const GROWL := "res://assets/audio/growl.ogg"
const HEART := "res://assets/audio/heart_loop.ogg"

static var instance: MineStory

var stage := &"idle"        ## idle → ordered → fallen → stealth → run → done
var _lurker: CreatureRig
var _pi := 0
var _sus := 0.0
var _chase := false
var _t := 0.0
var _step_t := 0.0
var _beacon: Node3D
var _hint_t := 0.0
var _grace := 0.0          ## после поимки: пока не видит (экран в затемнении, ты в забое)
var _caught_n := 0
var _heart: AudioStreamPlayer    ## сердце: чем ближе оно, тем громче и чаще
var _listen: AudioStreamPlayer   ## тонкий звон, когда оно замерло и слушает
var _breath_t := 0.0


static func is_active() -> bool:
	return instance != null and instance.stage in [&"fallen", &"stealth", &"run"]


func _ready() -> void:
	name = "MineStory"
	if not Game.is_night() or Game.night != 4 or Game.is_prologue() or Game.has_flag("mine_story_done"):
		queue_free()
		return
	instance = self
	_t = 150.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and instance == self:
		instance = null


func _process(delta: float) -> void:
	match stage:
		&"idle":
			_t -= delta
			if _t <= 0.0 and Game.is_home() and not Cutscene.active:
				_order()
		&"stealth", &"run":
			_tick_lurker(delta)


# --- 1. Приказ ---------------------------------------------------------------------

func _order() -> void:
	stage = &"ordered"
	Game.audio.play_2d("res://assets/audio/static_loop.ogg", -12.0)
	for i in range(1, 4):
		Game.hud.subtitle(Loc.t(StringName("mst.order.%d" % i)), 5.5)
		await get_tree().create_timer(5.6, false).timeout
	Game.story_goal = Loc.t(&"mst.goal.beacon")
	_build_beacon()


func _build_beacon() -> void:
	var mh := MineHorizon.instance
	if mh == null:
		return
	var at: Vector3 = mh.get("_surface") + Vector3(1.8, 0, 2.6)
	at.y = Terrain.height(at.x, at.z)
	_beacon = Node3D.new()
	_beacon.name = "DubovBeacon"
	Game.yard.add_child(_beacon)
	_beacon.global_position = at
	for k in 3:
		var a := k * TAU / 3.0
		var leg := Geo.cylinder(_beacon, 0.02, 1.3, Vector3(cos(a) * 0.22, 0.6, sin(a) * 0.22), Palette.m(&"metal"), false)
		leg.rotation = Vector3(sin(a) * 0.3, 0, -cos(a) * 0.3)
	Geo.block(_beacon, Vector3(0.36, 0.2, 0.26), Vector3(0, 1.28, 0), Palette.m(&"radio"), false)
	var lamp := Geo.omni(_beacon, Vector3(0, 1.5, 0), 4.0, 1.2, Color(1.0, 0.25, 0.15))
	var tw := lamp.create_tween().set_loops()
	tw.tween_property(lamp, "light_energy", 0.0, 0.1).set_delay(0.8)
	tw.tween_property(lamp, "light_energy", 1.2, 0.1)
	# Огонёк виден издалека — сквозь туман и метель, постоянного размера на экране
	var dot := MeshInstance3D.new()
	var dq := QuadMesh.new()
	dq.size = Vector2(0.012, 0.012)
	dot.mesh = dq
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.fixed_size = true
	dm.disable_fog = true
	dm.albedo_color = Color(1.0, 0.2, 0.12)
	dot.material_override = dm
	dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dot.position = Vector3(0, 1.55, 0)
	_beacon.add_child(dot)
	var dtw := dot.create_tween().set_loops()
	dtw.tween_property(dot, "visible", false, 0.0).set_delay(0.8)
	dtw.tween_property(dot, "visible", true, 0.0).set_delay(0.2)
	var snd := AudioStreamPlayer3D.new()
	snd.stream = AudioDirector.cached_stream("res://assets/audio/morse_loop.ogg")
	snd.volume_db = -8.0
	snd.max_distance = 60.0
	snd.position = Vector3(0, 1.3, 0)
	_beacon.add_child(snd)
	snd.play()
	var it := Geo.interactable(_beacon, Vector3(1.0, 1.6, 1.0), Vector3(0, 0.8, 0), null, Loc.t(&"mst.it.beacon"), func(_p: Player) -> void: _fall())
	it.name = "DubovBeaconIt"


# --- 2. Провал ---------------------------------------------------------------------

## Провал — от первого лица, без кинорамки: смотришь под ноги, по наледи бегут трещины и трещат всё
## чаще; пол уходит, ты летишь по старому стволу (крепь, обломки лестницы мелькают, руки хватают воздух,
## фонарь вырывается и кувыркается рядом, луч мечется по стенам), удар о полок, удар о дно. Темнота,
## звон в ушах, дыхание. Лежишь на боку; фонарь мигает в двух метрах. Встаёшь — сперва на колени.
func _fall() -> void:
	if stage != &"ordered":
		return
	stage = &"falling"
	Game.story_goal = ""
	if Game.yrka != null:
		Game.yrka.enabled = false
	Director.hold = true
	Cutscene.active = true
	var p := Game.player
	p.mode = Player.Mode.LOCKED
	p.velocity = Vector3.ZERO
	Game.flash_charge = maxf(Game.flash_charge, 75.0)
	p.set_flashlight(true)
	var hands: FPHands = p._hands
	var fx := _overlay()
	var yaw := p.rotation.y
	var feet := p.global_position
	# --- Наледь трещит ---
	Game.hud.subtitle(Loc.t(&"mst.fall.1"), 3.0)
	var cracks := _cracks(feet)
	var crack_snd := ["res://assets/sfx/cc0/log_frost_crack.ogg", "res://assets/sfx/cc0/log_frost_crack_v3.ogg", "res://assets/audio/ice_hit_v3.ogg",
		"res://assets/sfx/cc0/log_frost_crack_v4.ogg", "res://assets/audio/ice_hit_v4.ogg", "res://assets/sfx/cc0/log_frost_crack_v5.ogg"]
	var hits := [0.25, 1.1, 1.75, 2.15, 2.42, 2.6]
	var hi := 0
	var t := 0.0
	var pitch0 := p.head.rotation.x
	while t < 2.8:
		var dt := get_process_delta_time()
		t += dt
		var k := clampf(t / 1.1, 0.0, 1.0)
		var look_pitch := lerpf(pitch0, deg_to_rad(-62.0), smoothstep(0.0, 1.0, k))
		var tremble := pow(t / 2.8, 2.0) * 0.012
		p.head.rotation.x = look_pitch + randf_range(-1, 1) * tremble
		p.rotation.y = yaw + randf_range(-1, 1) * tremble
		for c: MeshInstance3D in cracks:
			(c.material_override as ShaderMaterial).set_shader_parameter(&"grow", pow(clampf(t / 2.7, 0.0, 1.0), 1.4))
		if hi < hits.size() and t >= hits[hi]:
			Game.audio.play_3d(crack_snd[hi], feet + Vector3(0, 0.1, 0), -6.0 + hi * 2.0, 6.0)
			hi += 1
		await get_tree().process_frame
	# --- Пол уходит --- дальше своя камера: кувыркаться
	var cam := Camera3D.new()
	cam.fov = p.camera.fov
	cam.near = 0.03
	cam.far = 90.0
	Game.level.add_child(cam)
	cam.global_transform = p.camera.global_transform
	cam.current = true
	hands.reparent(cam, false)
	var beam := SpotLight3D.new()
	beam.light_color = Color(1.0, 0.92, 0.78)
	beam.light_energy = 2.2
	beam.spot_range = 16.0
	beam.spot_angle = 28.0
	cam.add_child(beam)
	beam.position = Vector3(-0.15, -0.15, -0.3)
	p.set_flashlight(false)
	var eye := cam.global_position
	Game.audio.play_2d("res://assets/audio/ice_hit_v2.ogg", 6.0)
	Game.audio.play_2d("res://assets/audio/sub_drop.ogg", 4.0)
	hands.flail = 1.0
	t = 0.0
	while t < 0.32:
		t += get_process_delta_time()
		var k := t / 0.32
		cam.global_transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-62.0 - 25.0 * k), yaw + k * 0.3, k * 0.4)), eye + Vector3(0, -0.9 * k * k, 0))
		await get_tree().process_frame
	fx["black"].color.a = 1.0
	for c in cracks:
		c.queue_free()
	if _beacon != null:
		_beacon.queue_free()
	# --- Ствол: летишь ---
	var base := ROOT + FALL_LOCAL
	var shaft := _build_shaft(base)
	_build_lair()
	var top := base + Vector3(0, 15.0, 0)
	var torch := _falling_torch(top + Vector3(0.3, -0.4, -0.2))
	beam.visible = false
	# Отсвет луны и фонаря на стенах ствола (вершинный свет — нужен точечный, конус по редким вершинам не попадает)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.62, 0.7, 0.9)
	glow.light_energy = 1.1
	glow.omni_range = 4.0
	cam.add_child(glow)
	var debris := _debris(cam)
	await get_tree().process_frame
	fx["black"].color.a = 0.0
	var vy := -1.5
	var y := top.y
	var ledge_hit := false
	t = 0.0
	var spin := Vector3(randf_range(1.5, 2.5), randf_range(-1.0, 1.0), randf_range(1.0, 2.0))
	var rot := Vector3(deg_to_rad(-70.0), yaw, 0.4)
	while true:
		var dt := minf(get_process_delta_time(), 0.05)
		t += dt
		vy -= 9.8 * dt
		y += vy * dt
		rot += spin * dt
		# Смотрит то в стену, то вверх — на дыру с луной, что уходит
		var up_k := smoothstep(0.4, 1.2, t)
		var r := Vector3(lerp_angle(rot.x, deg_to_rad(70.0) + sin(t * 3.0) * 0.3, up_k * 0.7), rot.y, rot.z * (1.0 - up_k * 0.5))
		cam.global_transform = Transform3D(Basis.from_euler(r), Vector3(base.x + sin(t * 5.0) * 0.15, y, base.z + cos(t * 4.0) * 0.15))
		torch.global_position.y = maxf(y - 1.0 - t * 0.4, base.y + 0.06)
		torch.rotate_object_local(Vector3(1, 0.3, 0.2).normalized(), dt * 9.0)
		if not ledge_hit and y < base.y + 9.0:
			# Полок крепи: удар, отбросило, крутит в другую сторону
			ledge_hit = true
			vy = -1.0
			spin = Vector3(-spin.x * 1.2, spin.y + 1.5, -spin.z)
			Game.audio.play_2d("res://assets/audio/gore_hit.ogg", 0.0)
			Game.audio.play_2d("res://assets/audio/clank_v2.ogg", -4.0)
			_flash(fx, 0.55)
			hands.flail = 0.6
		if y <= base.y + 2.7:
			break
		await get_tree().process_frame
	# --- Дно ---
	Game.audio.play_2d("res://assets/audio/gore_hit.ogg", 6.0)
	Game.audio.play_2d("res://assets/audio/sub_drop.ogg", 2.0)
	fx["black"].color.a = 1.0
	_flash(fx, 0.9)
	hands.flail = 0.0
	hands.visible = false
	debris.queue_free()
	shaft.queue_free()
	torch.global_position = base + Vector3(1.7, 0.06, 1.1)
	torch.rotation = Vector3(0, 0.6, PI * 0.5)
	_torch_flicker(torch)
	var ring := AudioStreamPlayer.new()
	ring.stream = AudioDirector.cached_stream("res://assets/audio/hum_loop.ogg")
	ring.pitch_scale = 3.6
	ring.volume_db = -10.0
	add_child(ring)
	ring.play()
	var rtw := ring.create_tween()
	rtw.tween_property(ring, "volume_db", -40.0, 9.0)
	rtw.tween_callback(ring.queue_free)
	await get_tree().create_timer(2.2, false).timeout
	# --- Очнулся: лежишь на боку ---
	var breath := AudioStreamPlayer.new()
	breath.stream = AudioDirector.cached_stream("res://assets/sfx/cc0/player_breath_loop.ogg")
	breath.volume_db = -4.0
	breath.pitch_scale = 1.15
	add_child(breath)
	breath.play()
	var lie := base + Vector3(0.0, 0.22, 0.0)
	var to_torch := (torch.global_position - lie)
	var lie_yaw := atan2(-to_torch.x, -to_torch.z)
	cam.global_transform = Transform3D(Basis.from_euler(Vector3(-0.05, lie_yaw, deg_to_rad(78.0))), lie)
	fx["vig"].modulate.a = 1.0
	Game.hud.subtitle(Loc.t(&"mst.fall.2"), 4.5)
	for a: float in [0.55, 0.9, 0.35, 0.7, 0.15, 0.4, 0.0]:
		var tw := create_tween()
		tw.tween_property(fx["black"], "color:a", a, 0.55)
		await tw.finished
	Game.audio.play_3d("res://assets/audio/knock_v3.ogg", ROOT + PATROL[0] + Vector3(0, 1.0, 0), -10.0, 14.0)   # далеко щёлкнуло
	await get_tree().create_timer(1.2, false).timeout
	# Встаёшь: на колени, пауза, на ноги
	var pose := [[Vector3(-0.05, lie_yaw, deg_to_rad(78.0)), lie], [Vector3(-0.35, lie_yaw, deg_to_rad(8.0)), base + Vector3(0, 0.8, 0)],
		[Vector3(-0.3, lie_yaw, deg_to_rad(-3.0)), base + Vector3(0, 0.86, 0)], [Vector3(-0.15, lie_yaw, 0.0), base + Vector3(0, 1.55, 0)]]
	var durs := [1.5, 0.8, 1.3]
	for i in 3:
		t = 0.0
		var d: float = durs[i]
		while t < d:
			t += get_process_delta_time()
			var k := smoothstep(0.0, 1.0, t / d)
			var e0: Vector3 = pose[i][0]
			var e1: Vector3 = pose[i + 1][0]
			var wob := sin(t * 7.0) * 0.015 * (1.0 if i != 1 else 0.3)
			cam.global_transform = Transform3D(Basis.from_euler(Vector3(lerpf(e0.x, e1.x, k) + wob, e0.y, lerpf(e0.z, e1.z, k) + wob)), (pose[i][1] as Vector3).lerp(pose[i + 1][1], k))
			await get_tree().process_frame
	var vt := create_tween()
	vt.tween_property(fx["vig"], "modulate:a", 0.35, 4.0)
	vt.tween_callback(fx["layer"].queue_free)
	var btw := breath.create_tween()
	btw.tween_property(breath, "volume_db", -30.0, 8.0)
	btw.tween_callback(breath.queue_free)
	# Управление — игроку, где стоит камера
	p.global_position = base
	p.rotation.y = lie_yaw
	p.head.rotation.x = -0.15
	p.velocity = Vector3.ZERO
	hands.reparent(p.camera, false)
	hands.transform = Transform3D.IDENTITY
	p.camera.current = true
	cam.queue_free()
	p.mode = Player.Mode.WALK
	Cutscene.active = false
	p.torch_lost = true
	p.set_flashlight(false)
	if hands.torch_root != null:
		hands.torch_root.visible = false
	stage = &"fallen"
	Game.story_goal = Loc.t(&"mst.goal.torch")
	var it := Geo.interactable(torch, Vector3(0.6, 0.5, 0.6), Vector3(0, 0.1, 0), null, Loc.t(&"mst.it.torch"), func(_pl: Player) -> void: _pick_torch(torch))
	it.name = "DroppedTorch"


## Подобрал фонарь — дальше как было: свет, логово, оно выходит в штрек.
func _pick_torch(torch: Node3D) -> void:
	var p := Game.player
	if not p.torch_lost:
		return
	p.torch_lost = false
	torch.queue_free()
	var hands: FPHands = p._hands
	if hands.torch_root != null:
		hands.torch_root.visible = true
	_wake()


## Чёрный экран, красная вспышка, тёмная виньетка по краям (оглушило).
func _overlay() -> Dictionary:
	var layer := CanvasLayer.new()
	layer.layer = 79
	add_child(layer)
	var vig := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 0.95))
	g.add_point(0.55, Color(0, 0, 0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 0.5)
	vig.texture = gt
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig.modulate.a = 0.0
	layer.add_child(vig)
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var red := ColorRect.new()
	red.color = Color(0.55, 0.02, 0.02, 0.0)
	red.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(red)
	red.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(black)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return {"layer": layer, "vig": vig, "red": red, "black": black}


func _flash(fx: Dictionary, a: float) -> void:
	var red: ColorRect = fx["red"]
	red.color.a = a
	var tw := red.create_tween()
	tw.tween_property(red, "color:a", 0.0, 0.7)


## Трещины по наледи: сетка трещин (ice_cracks.png) расползается от ног — лучи, ветки, кольца.
func _cracks(feet: Vector3) -> Array:
	var q := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4.2, 4.2)
	q.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/ice_cracks.gdshader") as Shader
	m.set_shader_parameter(&"tex", load("res://assets/textures/ice_cracks.png"))
	m.set_shader_parameter(&"grow", 0.0)
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Game.yard.add_child(q)
	var h := Terrain.height(feet.x, feet.z) if Terrain.ready() else feet.y
	q.global_position = Vector3(feet.x, h + 0.03, feet.z)
	q.rotation.y = randf() * TAU
	return [q]


## Старый ствол над забоем: порода, венцы крепи, обломки лестницы, сверху — дыра с лунным светом.
func _build_shaft(base: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "FallShaft"
	Game.yard.add_child(root)
	var rock := Palette.m(&"concrete")
	var wood := Palette.m(&"wood")
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for k in 14:
		var y := base.y + 2.6 + k * 1.0
		for side in 4:
			var a := side * PI * 0.5
			var wall := Geo.block(root, Vector3(2.6, 1.02, 0.4), base + Vector3(cos(a) * 1.3, y - base.y, sin(a) * 1.3), rock, false)
			wall.rotation.y = -a + PI * 0.5
			wall.rotation.x = rng.randf_range(-0.04, 0.04)
		if k % 2 == 0:   # венец крепи
			for side in 4:
				var a := side * PI * 0.5
				var beam := Geo.block(root, Vector3(2.3, 0.14, 0.14), base + Vector3(cos(a) * 1.05, y - base.y, sin(a) * 1.05), wood, false)
				beam.rotation.y = -a + PI * 0.5
		if k % 3 == 1:   # остатки лестницы
			var rung := Geo.block(root, Vector3(0.6, 0.04, 0.04), base + Vector3(rng.randf_range(-0.3, 0.3), y - base.y, -0.95), wood, false)
			rung.rotation.z = rng.randf_range(-0.5, 0.5)
	for k in 3:
		var moon := OmniLight3D.new()
		moon.light_color = Color(0.6, 0.7, 0.95)
		moon.light_energy = 1.4 - k * 0.4
		moon.omni_range = 6.0
		root.add_child(moon)
		moon.global_position = base + Vector3(0, 15.5 - k * 4.5, 0)
	var sky := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.9, 1.9)
	sky.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0.5, 0.58, 0.75)
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	sm.disable_fog = true
	sky.material_override = sm
	root.add_child(sky)
	sky.global_position = base + Vector3(0, 16.6, 0)
	return root


## Фонарь вырвало из руки: летит рядом, кувыркается, луч мечется по стенам.
func _falling_torch(at: Vector3) -> Node3D:
	var t := Node3D.new()
	t.name = "FallenTorch"
	Game.yard.add_child(t)
	t.global_position = at
	Geo.block(t, Vector3(0.07, 0.05, 0.11), Vector3.ZERO, Palette.m(&"dark"), false)
	var rim := Geo.cylinder(t, 0.03, 0.02, Vector3(0, 0, -0.06), Palette.m(&"metal"), false)
	rim.rotation.x = PI * 0.5
	var lens := Geo.block(t, Vector3(0.04, 0.04, 0.005), Vector3(0, 0, -0.072), Palette.glow(&"amber"), false)
	lens.name = "Lens"
	var l := SpotLight3D.new()
	l.name = "Beam"
	l.light_color = Color(1.0, 0.92, 0.78)
	l.light_energy = 2.6
	l.spot_range = 10.0
	l.spot_angle = 26.0
	l.shadow_enabled = false
	l.position = Vector3(0, 0, -0.08)
	t.add_child(l)
	var pool := OmniLight3D.new()
	pool.name = "Pool"
	pool.light_color = Color(1.0, 0.9, 0.72)
	pool.light_energy = 2.4
	pool.omni_range = 6.5
	pool.position = Vector3(0, 0.05, -0.4)
	t.add_child(pool)
	return t


## Лежит и мигает: контакт отходит.
func _torch_flicker(torch: Node3D) -> void:
	var l := torch.get_node_or_null("Beam") as SpotLight3D
	if l == null:
		return
	var pool := torch.get_node_or_null("Pool") as OmniLight3D
	pool.global_position = torch.global_position + Vector3(0.0, 0.6, 0.0)   # свет вдоль пола под косым углом почти не даёт
	for x: Light3D in [l, pool]:
		var e := x.light_energy
		var tw := x.create_tween().set_loops()
		tw.tween_property(x, "light_energy", e * 0.1, 0.05).set_delay(0.6)
		tw.tween_property(x, "light_energy", e, 0.04)
		tw.tween_property(x, "light_energy", 0.0, 0.08).set_delay(0.15)
		tw.tween_property(x, "light_energy", e * 0.9, 0.05).set_delay(0.3)


## Обломки летят вместе с тобой (у камеры, в мировых координатах).
func _debris(cam: Camera3D) -> CPUParticles3D:
	var d := CPUParticles3D.new()
	d.amount = 40
	d.lifetime = 1.4
	d.local_coords = false
	d.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	d.emission_box_extents = Vector3(1.0, 0.6, 1.0)
	d.direction = Vector3(0, -1, 0)
	d.spread = 15.0
	d.initial_velocity_min = 2.0
	d.initial_velocity_max = 6.0
	d.gravity = Vector3(0, -9.8, 0)
	d.angular_velocity_min = -300.0
	d.angular_velocity_max = 300.0
	d.scale_amount_min = 0.5
	d.scale_amount_max = 1.6
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.04, 0.05)
	bm.material = Palette.m(&"concrete")
	d.mesh = bm
	cam.add_child(d)
	d.position = Vector3(0, 0.8, 0)
	return d


func _wake() -> void:
	stage = &"fallen"
	var p := Game.player
	Game.flash_charge = maxf(Game.flash_charge, 75.0)   # сюжетной сцене нужен свет: батарею берёг
	# Фонарь не сразу: мигает и ловит контакт
	for k in 6:
		p.set_flashlight(k % 2 == 0)
		await get_tree().create_timer(randf_range(0.08, 0.3), false).timeout
	p.set_flashlight(true)
	Game.hud.subtitle(Loc.t(&"mst.wake"), 6.0)
	Game.story_goal = Loc.t(&"mst.goal.out")
	await get_tree().create_timer(5.0, false).timeout
	_spawn_lurker()
	stage = &"stealth"


# --- 3. Логово ---------------------------------------------------------------------

func _build_lair() -> void:
	var w := Game.yard
	var bone := Palette.m(&"paper")
	var cloth := Palette.m(&"cloth")
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var root := Node3D.new()
	root.name = "Lair"
	w.add_child(root)
	# Лёжки из ватников и тряпья — в забое и тупике
	for c: Vector3 in [Vector3(-1.0, 0, -43.0), Vector3(1.2, 0, -40.5), Vector3(-8.5, 0, -26.5)]:
		var m := MeshInstance3D.new()
		m.mesh = Props.snow_mound_mesh(rng.randi())
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.19, 0.16)
		mat.roughness = 1.0
		m.material_override = mat
		m.scale = Vector3(0.9, 0.22, 0.7)
		m.position = ROOT + c + Vector3(0, 0.05, 0)
		root.add_child(m)
		for k in 6:
			var b := Geo.cylinder(root, 0.025, rng.randf_range(0.25, 0.45), ROOT + c + Vector3(rng.randf_range(-0.8, 0.8), 0.08, rng.randf_range(-0.6, 0.6)), bone, false)
			b.rotation = Vector3(PI * 0.5, rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
	# Вещи пропавших: ключ радиста Брагина, шарф Ерёминой, ракетница Голубева (её нашли в схроне), ушанка Семёнова
	var items := [[&"bragin", Vector3(-1.4, 0.1, -42.6)], [&"eryomina", Vector3(1.5, 0.1, -40.2)], [&"golubev", Vector3(-8.0, 0.1, -25.9)]]
	for it: Array in items:
		var pos: Vector3 = ROOT + (it[1] as Vector3)
		var mark := Geo.block(root, Vector3(0.22, 0.05, 0.16), pos, cloth, false)
		mark.rotation.y = rng.randf() * TAU
		var spot := Geo.interactable(root, Vector3(0.6, 0.5, 0.6), pos + Vector3(0, 0.2, 0), null, Loc.t(StringName("mst.it.%s" % it[0])), func(_pl: Player) -> void:
			Game.hud.subtitle(Loc.t(StringName("mst.item.%s" % it[0])), 6.0))
		spot.name = "LairItem"
	# Кассета Дубова выпала рядом
	var tape := Geo.block(root, Vector3(0.1, 0.02, 0.065), ROOT + FALL_LOCAL + Vector3(0.5, 0.02, 0.6), Palette.m(&"dark"), false)
	var tit := Geo.interactable(root, Vector3(0.5, 0.4, 0.5), ROOT + FALL_LOCAL + Vector3(0.5, 0.2, 0.6), null, Loc.t(&"mst.it.tape"), func(_pl: Player) -> void:
		Game.set_flag("mine_story_tape", true)
		Achievements.unlock(&"tape")
		tape.visible = false
		Game.hud.subtitle(Loc.t(&"mst.tape"), 5.0))
	tit.name = "DubovTape"
	# Провал над забоем: лунный луч и снег, что насыпался сверху
	var moon := OmniLight3D.new()
	moon.light_color = Color(0.6, 0.7, 0.95)
	moon.light_energy = 5.0
	moon.omni_range = 9.0   # вершинный свет: радиус должен накрыть углы больших граней пола
	moon.shadow_enabled = false
	root.add_child(moon)
	moon.global_position = ROOT + FALL_LOCAL + Vector3(0.2, 2.3, 0.0)
	var pile := MeshInstance3D.new()
	pile.mesh = Props.snow_mound_mesh(1)
	pile.material_override = Palette.m(&"drift")
	pile.scale = Vector3(1.0, 0.3, 0.9)
	pile.position = ROOT + FALL_LOCAL + Vector3(0.2, 0.0, 0.2)
	root.add_child(pile)
	var dust := CPUParticles3D.new()
	dust.amount = 40
	dust.lifetime = 5.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(0.6, 0.1, 0.6)
	dust.direction = Vector3(0, -1, 0)
	dust.initial_velocity_min = 0.2
	dust.initial_velocity_max = 0.5
	dust.gravity = Vector3.ZERO
	var dq := QuadMesh.new()
	dq.size = Vector2(0.03, 0.03)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.albedo_color = Color(0.85, 0.9, 1.0, 0.8)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dq.material = dm
	dust.mesh = dq
	root.add_child(dust)
	dust.global_position = ROOT + FALL_LOCAL + Vector3(0.2, 3.0, 0.0)
	# Керосинка в тупике — кто-то оставил, еле тлеет
	var kl := Props.kerosene_lamp()
	root.add_child(kl)
	kl.global_position = ROOT + Vector3(-8.8, 0.0, -25.4)
	var flame := Geo.omni(root, ROOT + Vector3(-8.8, 0.45, -25.4), 8.0, 1.6, Color(1.0, 0.6, 0.3))
	flame.shadow_enabled = false
	var ftw := flame.create_tween().set_loops()
	ftw.tween_property(flame, "light_energy", 1.0, 0.25)
	ftw.tween_property(flame, "light_energy", 1.7, 0.3)
	# Зарубки на стене — счёт ночей, чужой рукой
	for k in 14:
		Geo.block(root, Vector3(0.01, 0.16, 0.012), ROOT + Vector3(-1.86, 1.0 + (k % 7) * 0.02, -43.6 + k * 0.05), Palette.m(&"dark"), false)


# --- 4–5. Оно в штреке ---------------------------------------------------------------

func _spawn_lurker() -> void:
	_lurker = Creatures.make_yrka()
	_lurker.name = "MineLurker"
	Game.yard.add_child(_lurker)
	_lurker.global_position = ROOT + PATROL[0]
	_lurker.gait = 0.3
	_pi = 1
	Game.audio.play_3d(GROWL, ROOT + PATROL[0] + Vector3(0, 1.2, 0), -4.0, 10.0)


func _tick_lurker(delta: float) -> void:
	if _lurker == null or Game.player == null:
		return
	if _grace > 0.0:
		_grace -= delta
		return
	var p := Game.player
	var pp := p.global_position
	var lp := _lurker.global_position
	var to_p := pp - lp
	to_p.y = 0.0
	var d := to_p.length()
	_tension_audio(d, delta)
	# Ракета — отступает в глубину
	if not get_tree().root.find_children("*", "Flare", true, false).is_empty() and d < 18.0:
		if _chase:
			Game.audio.play_3d(SHRIEK, lp + Vector3(0, 1.3, 0), 4.0, 10.0)
		_chase = false
		_sus = 0.0
		_go_to(ROOT + PATROL[0], 4.0, delta)
		return
	if stage == &"stealth" and pp.z - ROOT.z > RUN_TRIGGER_Z and not _chase:
		_start_run()
	if _chase or stage == &"run":
		_lurker.gait = 1.0
		var spd := 4.6 if stage == &"run" else 4.3
		_go_to(pp, spd, delta)
		if d < 1.1:
			_caught()
		return
	# Патруль
	var tgt := ROOT + PATROL[_pi]
	if Vector2(lp.x - tgt.x, lp.z - tgt.z).length() < 0.6:
		_pi = (_pi + 1) % PATROL.size()
	_lurker.gait = 0.3
	_go_to(tgt, 1.5, delta)
	# Шаги — слышно, где оно
	_step_t -= delta
	if _step_t <= 0.0:
		_step_t = 0.9
		Game.audio.play_3d(STEP, lp + Vector3(0, 0.2, 0), -6.0, 6.0)
	# Восприятие: свет фонаря издали, тело вблизи, бег — на слух; за углом не видно
	var head := lp + Vector3(0, 1.6, 0)
	var los := _clear(head, pp + Vector3(0, 1.3, 0))
	var breath := 0.7 if p.holding_breath else 1.0
	var sight := (15.0 if p.flashlight_on() else 5.0) * breath
	var seen := los and d < sight
	var heard := (p.is_sprinting() and d < 11.0) or (p.velocity.length() > 0.5 and d < 3.0)
	if seen or heard:
		_sus += delta * (1.6 if heard else clampf(1.8 - d / sight, 0.3, 1.8))
	else:
		_sus = maxf(_sus - delta * 0.35, 0.0)
	# Услышало — поворачивает голову на звук; подозревает — замирает и нюхает
	if heard or _sus > 0.3:
		var loc := _lurker.global_basis.inverse() * (pp - head)
		_lurker.head_look_target_yaw = clampf(atan2(-loc.x, -loc.z), -1.1, 1.1)
	else:
		_lurker.head_look_target_yaw = 0.0
	if _sus > 0.45:
		_lurker.gait = 0.0
	if _sus > 0.45 and _hint_t <= 0.0:
		_hint_t = 6.0
		Game.hud.subtitle(Loc.t(&"mst.suspect"), 3.0)
		_lurker.pose_override = &"sniff" if _lurker.has_clip(&"sniff") else &""
		Game.audio.play_3d(GROWL, head, -2.0, 8.0)
	_hint_t -= delta
	if _sus >= 1.0:
		_chase = true
		_lurker.pose_override = &""
		Game.audio.play_3d(SHRIEK, head, 6.0, 12.0)
		Game.player.shake(0.05, 0.5)
		_snap_to(head)
		Game.hud.subtitle(Loc.t(&"mst.seen"), 2.5)


## Заметило: голова сама дёргается к нему, кадр «прыгает» (FOV), красная кромка.
func _snap_to(at: Vector3) -> void:
	var p := Game.player
	var dir := at - p.camera.global_position
	var want := atan2(-dir.x, -dir.z)
	var tw := p.create_tween().set_parallel(true)
	tw.tween_property(p, "rotation:y", p.rotation.y + wrapf(want - p.rotation.y, -PI, PI), 0.22).set_ease(Tween.EASE_OUT)
	tw.tween_property(p.head, "rotation:x", clampf(atan2(dir.y, Vector2(dir.x, dir.z).length()), -0.6, 0.6), 0.22)
	var f0 := p.camera.fov
	p.camera.fov = f0 - 14.0
	var ft := p.camera.create_tween()
	ft.tween_property(p.camera, "fov", f0, 0.6).set_ease(Tween.EASE_OUT)
	Game.hud.flash_red(0.5, 0.4)


## Звук близости: сердце громче и чаще, когда оно рядом; дыхание твари вплотную; звон, когда слушает.
func _tension_audio(d: float, delta: float) -> void:
	if _heart == null:
		_heart = AudioStreamPlayer.new()
		_heart.stream = AudioDirector.cached_stream("res://assets/audio/heart_loop.ogg")
		_heart.volume_db = -60.0
		add_child(_heart)
		_heart.play()
		_heart.finished.connect(_heart.play)
		_listen = AudioStreamPlayer.new()
		_listen.stream = AudioDirector.cached_stream("res://assets/audio/hum_loop.ogg")
		_listen.pitch_scale = 3.2
		_listen.volume_db = -60.0
		add_child(_listen)
		_listen.play()
		_listen.finished.connect(_listen.play)
	var near := clampf(1.0 - d / 14.0, 0.0, 1.0)
	if stage == &"run" or _chase:
		near = 1.0
	_heart.volume_db = lerpf(_heart.volume_db, -40.0 + near * 36.0, minf(delta * 3.0, 1.0))
	_heart.pitch_scale = 0.9 + near * 0.55
	var listening := _sus > 0.3 and not _chase
	_listen.volume_db = lerpf(_listen.volume_db, -22.0 if listening else -60.0, minf(delta * 2.0, 1.0))
	_breath_t -= delta
	if d < 6.0 and _breath_t <= 0.0:
		_breath_t = randf_range(2.2, 3.6)
		Game.audio.play_3d("res://assets/audio/growl_v%d.ogg" % (2 + randi() % 3), _lurker.global_position + Vector3(0, 1.4, 0), -14.0, 4.0)


func _clear(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, Geo.LAYER_WORLD)
	return Game.yard.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _go_to(target: Vector3, speed: float, delta: float) -> void:
	var lp := _lurker.global_position
	var dir := target - lp
	dir.y = 0.0
	var l := dir.length()
	if l < 0.01:
		return
	# По штреку: сперва на ось x≈0, если цель на оси, — не срезать сквозь породу
	var step := dir / l * minf(speed * delta, l)
	_lurker.global_position = lp + step
	_lurker.global_position.y = ROOT.y
	_lurker.rotation.y = atan2(-dir.x, -dir.z)


func _start_run() -> void:
	stage = &"run"
	Game.audio.play_3d(SHRIEK, ROOT + Vector3(0, 1.5, -38.0), 8.0, 40.0)
	Game.hud.subtitle(Loc.t(&"mst.run"), 3.5)
	Game.player.shake(0.04, 1.0)
	_lurker.global_position = ROOT + Vector3(0, 0, -30.0)
	var steps := AudioStreamPlayer3D.new()
	steps.stream = AudioDirector.cached_stream("res://assets/audio/yrka_steps_v3.ogg")
	steps.volume_db = 4.0
	steps.max_distance = 40.0
	_lurker.add_child(steps)
	steps.play()
	steps.finished.connect(steps.play)
	Director.add_tension(40.0, "оно бежит по штреку")


func _caught() -> void:
	# Не смерть — назад в забой: «очнулся снова», оно опять в глубине
	_chase = false
	_sus = 0.0
	_grace = 6.0
	_caught_n += 1
	stage = &"stealth"
	var p := Game.player
	Game.audio.play_2d(SHRIEK, 2.0)
	Game.hud.flash_red(0.9, 0.6)
	p.shake(0.1, 0.5)
	Game.add_fatigue(15.0)
	await Game.hud.blink(1.2)
	p.global_position = ROOT + FALL_LOCAL
	p.velocity = Vector3.ZERO
	p.rotation.y = 0.0
	_lurker.global_position = ROOT + PATROL[0]
	for c in _lurker.get_children():
		if c is AudioStreamPlayer3D:
			c.queue_free()
	_pi = 1
	Game.hud.subtitle(Loc.t(&"mst.again"), 5.0)


# --- 6. Наверх ------------------------------------------------------------------------

## Лестница у ствола: во время сюжета — подъём от первого лица: перекладины, руки перехватывают;
## на середине оглядываешься вниз — в луче голова твари у подножия; крик, и лезешь быстрее, наверх —
## в снег. Наверху — два огня глаз в темноте ствола.
func climb(p: Player) -> bool:
	if not is_active():
		return false
	stage = &"done"
	Game.story_goal = ""
	Cutscene.active = true
	p.mode = Player.Mode.LOCKED
	p.velocity = Vector3.ZERO
	var mh := MineHorizon.instance
	var surf: Vector3 = mh.get("_surface") + MineHorizon.ENTRY
	surf.y = Terrain.height(surf.x, surf.z)
	var hands: FPHands = p._hands
	var cam := Camera3D.new()
	cam.fov = p.camera.fov
	cam.near = 0.03
	Game.level.add_child(cam)
	cam.current = true
	hands.reparent(cam, false)
	var beam := SpotLight3D.new()
	beam.light_color = Color(1.0, 0.92, 0.78)
	beam.light_energy = 2.4
	beam.spot_range = 14.0
	beam.spot_angle = 30.0
	cam.add_child(beam)
	beam.position = Vector3(-0.12, -0.1, -0.2)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.9, 0.75)
	glow.light_energy = 0.9
	glow.omni_range = 3.5
	glow.position = Vector3(0, 0, -1.0)
	cam.add_child(glow)
	p.set_flashlight(false)
	var fx := _overlay()
	var foot := ROOT + LADDER_LOCAL + Vector3(0, 0, 0.0)
	var face_yaw := PI        # лицом к лестнице (+z)
	hands.climb = 0.0
	# Первые перекладины
	var y := 1.5
	var rungs := 0
	var t := 0.0
	while y < 2.9:
		var dt := get_process_delta_time()
		t += dt
		y += dt * 0.7
		hands.climb = t * 1.4
		if int(t * 1.4) > rungs:
			rungs = int(t * 1.4)
			Game.audio.play_3d("res://assets/sfx/cc0/step_metal_%d.ogg" % (1 + rungs % 6), foot + Vector3(0, y, 0), -6.0, 6.0)
		cam.global_transform = Transform3D(Basis.from_euler(Vector3(0.25 + sin(t * 4.4) * 0.03, face_yaw, sin(t * 2.2) * 0.02)), foot + Vector3(0, y, 0.0))
		await get_tree().process_frame
	# Оно у подножия
	if _lurker != null:
		_lurker.global_position = ROOT + Vector3(0, 0, -0.6)
		_lurker.rotation.y = 0.0
		_lurker.gait = 0.0
		_lurker.pose_override = &"sniff" if _lurker.has_clip(&"sniff") else &""
	t = 0.0
	while t < 0.9:
		t += get_process_delta_time()
		var k := smoothstep(0.0, 1.0, t / 0.9)
		cam.global_transform = Transform3D(Basis.from_euler(Vector3(lerpf(0.25, -0.95, k), face_yaw + k * 2.4, k * 0.15)), foot + Vector3(0, y, 0.0))
		await get_tree().process_frame
	await get_tree().create_timer(0.6, false).timeout
	Game.audio.play_3d(SHRIEK, ROOT + Vector3(0, 1.5, -0.6), 9.0, 12.0)
	_flash(fx, 0.3)
	if _lurker != null:
		_lurker.pose_override = &"lunge" if _lurker.has_clip(&"lunge") else &""
	t = 0.0
	while t < 0.35:
		t += get_process_delta_time()
		var k := smoothstep(0.0, 1.0, t / 0.35)
		cam.global_transform = Transform3D(Basis.from_euler(Vector3(lerpf(-0.95, 0.55, k), face_yaw + (1.0 - k) * 2.4, randf_range(-0.03, 0.03))), foot + Vector3(0, y, 0.0))
		await get_tree().process_frame
	# Вверх что есть сил
	t = 0.0
	var fast := 0.0
	while t < 1.9:
		var dt := get_process_delta_time()
		t += dt
		y += dt * 1.6
		fast += dt * 3.2
		hands.climb = fast
		if int(fast) > rungs:
			rungs = int(fast)
			Game.audio.play_3d("res://assets/sfx/cc0/step_metal_%d.ogg" % (1 + rungs % 6), foot + Vector3(0, y, 0), -2.0, 6.0)
		cam.global_transform = Transform3D(Basis.from_euler(Vector3(0.55 + sin(t * 9.0) * 0.05, face_yaw + randf_range(-0.02, 0.02), sin(t * 4.5) * 0.04)), foot + Vector3(0, y, 0.0))
		if t > 1.3:
			(fx["black"] as ColorRect).color = Color(0.85, 0.88, 0.95, clampf((t - 1.3) / 0.6, 0.0, 1.0))   # снег в лицо
		await get_tree().process_frame
	Game.audio.play_2d("res://assets/audio/gust.ogg", 2.0)
	hands.climb = -1.0
	hands.reparent(p.camera, false)
	hands.transform = Transform3D.IDENTITY
	p.camera.current = true
	cam.queue_free()
	if _lurker != null:
		_lurker.queue_free()
		_lurker = null
	p.global_position = surf + Vector3(1.4, 0.05, -1.0)
	p.velocity = Vector3.ZERO
	Cutscene.active = false
	var wt := create_tween()
	wt.tween_property(fx["black"], "color:a", 0.0, 0.8)
	wt.tween_callback(fx["layer"].queue_free)
	await Cutscene.play([
		{"cam": [surf + Vector3(1.6, 1.4, 1.6), surf + Vector3(0, 0.2, 0)]},
		{"call": func() -> void: _eyes(surf + Vector3(0, -0.3, 0))},
		{"say": "mst.out.1", "t": 4.5, "hold": true},
		{"sfx": "res://assets/audio/whisper.ogg", "at": surf, "vol": 2.0},
		{"move": [surf + Vector3(3.0, 2.0, 3.5), surf + Vector3(0, 0.2, 0)], "t": 3.0},
		{"say": "mst.out.2", "t": 4.5, "hold": true},
	])
	Game.set_flag("mine_story_done", true)
	Achievements.unlock(&"lair")
	if _caught_n == 0:
		Achievements.unlock(&"lair_clean")
	for a in [_heart, _listen]:
		if a != null:
			a.queue_free()
	_heart = null
	if Game.yrka != null:
		Game.yrka.enabled = true
		Game.yrka.set_cooldown(90.0)
	Director.hold = false
	Director.add_tension(-30.0, "выбрался из логова")
	Supply.add(2, &"mst.r")
	SaveGame.write()
	return true


func _eyes(at: Vector3) -> void:
	for sx: float in [-0.06, 0.06]:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.05, 0.035)
		q.mesh = qm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_color = Color(1.0, 0.75, 0.4)
		m.disable_fog = true
		q.material_override = m
		Game.yard.add_child(q)
		q.global_position = at + Vector3(sx, 0, 0)
		get_tree().create_timer(9.0, false).timeout.connect(q.queue_free)
