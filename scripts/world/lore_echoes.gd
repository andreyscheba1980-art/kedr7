class_name LoreEchoes
extends Node
## Визуально-звуковой лор в 3D вместо сухих записок:
##   • Физические следы прошлых смен (упавший термос, зарубки на стене избы, вмёрзшая катушка у проруби,
##     оборванная лента у вышки) и короткие ледяные эхо-силуэты при первом приближении.
##   • Кульминация окна 03:10: на опушке в багровом всполохе неба на несколько секунд проступают
##     безмолвные фигуры прежних дежурных и растворяются в морозной пыли.

const CLANK := "res://assets/audio/clank.ogg"
const ICE_HIT := "res://assets/audio/ice_hit.ogg"
const GUST := "res://assets/audio/gust.ogg"
const WHISPER := "res://assets/audio/whisper.ogg"

var _spots: Array[Dictionary] = []
var _surge_ghost: Node3D = null
var _surge_shown_night := false


func _ready() -> void:
	name = "LoreEchoes"
	if Game.is_prologue() and not Game.has_flag("prologue_arrived"):
		queue_free()
		return
	_build.call_deferred()


func _exit_tree() -> void:
	if _surge_ghost != null and is_instance_valid(_surge_ghost):
		_surge_ghost.queue_free()
	_surge_ghost = null


func _build() -> void:
	if Game.yard == null or not is_inside_tree():
		return
	var camp_c := Terrain.pad_pos(&"camp")
	var tower_c := Terrain.pad_pos(&"tower")
	var src_c := Terrain.pad_pos(&"source")

	_add_artifact(&"camp", camp_c + Vector3(0.2, 0.0, -8.8), -0.9, &"thermos",
		CLANK, "«Инструмент бросаем… машины греются! Эй — щенка с цепи кто спустит?!»",
		"\"Drop the gear… trucks are idling! Hey—who's untying the pup?!\"")

	_add_artifact(&"izba", Yard.IZBA + Vector3(2.8, 0.0, 2.2), 1.2, &"notches",
		WHISPER, "«Занавесь зеркало, Витя… пока не стемнело — оно смотрит через стекло.»",
		"\"Cover the mirror, Vitya… before dark—it watches through the glass.\"")

	_add_artifact(&"lake", Yard.HOLE + Vector3(-1.5, 0.0, 1.2), 2.1, &"reel",
		ICE_HIT, "Подо льдом глухо стукнуло — на краю проруби лежат оборванная плёнка и очки.",
		"A hollow thud beneath the ice—snapped tape and spectacles frozen by the edge.")

	_add_artifact(&"tower", tower_c + Vector3(3.4, 0.0, 2.2), -2.2, &"ribbon",
		GUST, "«Небо над станцией как медь… прибор пишет сам по себе, рука не держит.»",
		"\"The sky over the station looks like copper… the needle's writing by itself.\"")

	_add_artifact(&"source", src_c + Vector3(-2.4, 0.0, 3.2), 0.4, &"satchel",
		WHISPER, "Семь теней у корней лиственницы — кто-то из них повернул голову на твой фонарь.",
		"Seven silhouettes around the dead larch—one turns toward your beam.")


func _add_artifact(id: StringName, pos: Vector3, yaw: float, prop_kind: StringName, sfx: String, ru: String, en: String) -> void:
	var p := Vector3(pos.x, Terrain.height(pos.x, pos.z), pos.z)
	var holder := Node3D.new()
	holder.name = "EchoProp_" + String(id)
	holder.position = p
	holder.rotation.y = yaw
	Game.yard.add_child(holder)

	match prop_kind:
		&"thermos":
			var body := Geo.cylinder(holder, 0.055, 0.24, Vector3(0, 0.06, 0), Palette.m(&"metal"), false)
			body.rotation = Vector3(deg_to_rad(82.0), 0.3, 0.0)
			var cup := Geo.cylinder(holder, 0.045, 0.06, Vector3(0.18, 0.03, 0.08), Palette.m(&"rust"), false)
			cup.rotation.z = deg_to_rad(65.0)
		&"notches":
			for i in 5:
				var mark := Geo.box_mesh(Vector3(0.015, 0.14, 0.012), Palette.m(&"dark"))
				mark.position = Vector3(-0.35 + i * 0.045, 1.35, -0.02)
				mark.rotation.z = deg_to_rad(-8.0 if i < 4 else 52.0)
				holder.add_child(mark)
		&"reel":
			var rim := Geo.cylinder(holder, 0.11, 0.025, Vector3(0, 0.02, 0), Palette.m(&"dark"), false)
			rim.rotation.z = deg_to_rad(8.0)
			var tape_tail := Geo.box_mesh(Vector3(0.32, 0.008, 0.014), Palette.m(&"dark"))
			tape_tail.position = Vector3(0.16, 0.015, 0.04)
			holder.add_child(tape_tail)
		&"ribbon":
			var paper := StandardMaterial3D.new()
			paper.albedo_color = Color(0.84, 0.80, 0.72)
			paper.roughness = 0.9
			var strip := Geo.box_mesh(Vector3(0.10, 0.008, 0.55), paper)
			strip.position = Vector3(0, 0.02, 0.15)
			strip.rotation.y = 0.45
			holder.add_child(strip)
		&"satchel":
			var cloth := StandardMaterial3D.new()
			cloth.albedo_color = Color(0.24, 0.22, 0.18)
			cloth.roughness = 0.95
			var bag := Geo.box_mesh(Vector3(0.34, 0.14, 0.26), cloth)
			bag.position = Vector3(0, 0.07, 0)
			bag.rotation.y = 0.35
			holder.add_child(bag)

	var triggered := Game.has_flag("echo_" + String(id))
	_spots.append({
		"id": id,
		"pos": p,
		"yaw": yaw,
		"sfx": sfx,
		"ru": ru,
		"en": en,
		"done": triggered,
	})


func _process(_delta: float) -> void:
	var p := Game.player
	if p == null or Game.dead or Game.shift_over or Game.yard == null:
		return
	var pp := p.global_position

	for s: Dictionary in _spots:
		if bool(s["done"]):
			continue
		var dist := Vector2(pp.x - (s["pos"] as Vector3).x, pp.z - (s["pos"] as Vector3).z).length()
		if dist < 9.5 and Game.is_outside():
			s["done"] = true
			Game.set_flag("echo_" + String(s["id"]), true)
			_play_echo(s)

	# Кульминация 03:10 — далёкий призрачный силуэт у кромки леса в отсвете сияния
	if not _surge_shown_night and Game.is_night() and Signal0310.surge_level > 0.6 and Game.is_outside():
		_surge_shown_night = true
		_spawn_surge_silhouette(pp + Vector3(-18.0, 0.0, -14.0))


func _play_echo(s: Dictionary) -> void:
	var pos: Vector3 = s["pos"]
	var yaw := float(s["yaw"])
	if Game.audio != null:
		Game.audio.play_3d(String(s["sfx"]), pos + Vector3(0, 0.8, 0), -3.0, 10.0)
	if Game.hud != null:
		Game.hud.subtitle(Loc.p(String(s["ru"]), String(s["en"])), 5.0, 2)
	var fig := _spawn_frost_silhouette(pos, yaw)
	if fig != null:
		get_tree().create_timer(4.6, false).timeout.connect(func() -> void:
			if is_inside_tree() and is_instance_valid(fig):
				_burst_frost(fig.global_position + Vector3(0, 1.0, 0))
				fig.queue_free())


func _spawn_surge_silhouette(at: Vector3) -> void:
	var pos := Vector3(at.x, Terrain.height(at.x, at.z), at.z)
	var look_to := Vector3(Yard.HOUSE_CENTER.x - pos.x, 0.0, Yard.HOUSE_CENTER.z - pos.z)
	var fig := _spawn_frost_silhouette(pos, atan2(-look_to.x, -look_to.z))
	_surge_ghost = fig
	if fig != null:
		get_tree().create_timer(6.5, false).timeout.connect(func() -> void:
			if is_inside_tree() and is_instance_valid(fig):
				_burst_frost(fig.global_position + Vector3(0, 1.0, 0))
				fig.queue_free())


func _spawn_frost_silhouette(pos: Vector3, yaw: float) -> Node3D:
	if Game.yard == null or not is_inside_tree():
		return null
	var rig := Creatures.make_human(&"driver")
	if rig == null:
		return null
	rig.name = "FrostEcho"
	rig.position = pos
	rig.rotation.y = yaw
	rig.twitch = 0.0
	var frost_mat := StandardMaterial3D.new()
	frost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	frost_mat.albedo_color = Color(0.68, 0.88, 1.0, 0.34)
	frost_mat.emission_enabled = true
	frost_mat.emission = Color(0.32, 0.62, 0.90)
	frost_mat.emission_energy_multiplier = 0.45
	frost_mat.roughness = 0.7
	for c: Node in rig.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		mi.material_override = frost_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Game.yard.add_child(rig)
	return rig


func _burst_frost(at: Vector3) -> void:
	if Game.yard == null or not is_inside_tree():
		return
	var cp := CPUParticles3D.new()
	cp.one_shot = true
	cp.amount = 18
	cp.lifetime = 1.0
	cp.explosiveness = 0.85
	cp.direction = Vector3(0, 0.6, 0)
	cp.spread = 45.0
	cp.initial_velocity_min = 0.5
	cp.initial_velocity_max = 1.4
	cp.gravity = Vector3(0.3, -0.5, 0.0)
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.09
	sm.radial_segments = 5
	sm.rings = 3
	cp.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.75, 0.9, 1.0, 0.45)
	cp.material_override = mat
	cp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cp.position = at
	Game.yard.add_child(cp)
	cp.emitting = true
	get_tree().create_timer(1.2, false).timeout.connect(cp.queue_free)
