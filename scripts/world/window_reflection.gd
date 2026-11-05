class_name WindowReflection
extends Node3D
## Отражение в ночном окне: стоишь у стекла и смотришь наружу — в тёмном стекле проступает бледное лицо
## у тебя за плечом. Место на стекле честное: отражение точки за спиной в плоскости окна, видимое из глаз.
## Обернёшься — в комнате пусто, отражение гаснет; отвернулся от окна — тоже. Со 2-й ночи, не чаще
## пары раз за ночь, и не каждый раз, когда смотришь.

const TEX := "res://assets/textures/reflection_figure.png"
const LOOK_NEED := 1.4          ## сколько секунд смотреть в стекло, прежде чем может появиться
const MAX_PER_NIGHT := 2

var station: Station
var _look_t := 0.0
var _cool := 30.0
var _shown := 0
var _quad: MeshInstance3D
var _mat: StandardMaterial3D
var _spot: Dictionary = {}
var _behind := Vector3.ZERO
var _alive := 0.0
var _night := -1


func _ready() -> void:
	name = "WindowReflection"
	_quad = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	_quad.mesh = q
	_mat = StandardMaterial3D.new()
	_mat.albedo_texture = load(TEX) as Texture2D
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.disable_fog = true
	_mat.albedo_color = Color(1, 1, 1, 0)
	_quad.material_override = _mat
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_quad.visible = false
	add_child(_quad)


func _process(delta: float) -> void:
	if Game.night != _night:
		_night = Game.night
		_shown = 0
	var p := Game.player
	if p == null or station == null or not Game.is_night() or Game.night < 2 or not Game.is_indoors() or p.mode != Player.Mode.WALK:
		_hide(true)
		return
	var cam := p.camera
	var eye := cam.global_position
	var fwd := -cam.global_basis.z
	if _quad.visible:
		_track(eye, fwd, delta)
		return
	_cool -= delta
	var best: Dictionary = {}
	for w: Dictionary in station.window_spots:
		var g: Vector3 = w["glass"]
		var to := g - eye
		if to.length() < 3.2 and fwd.dot(to.normalized()) > 0.9:
			best = w
			break
	if best.is_empty():
		_look_t = 0.0
		return
	_look_t += delta
	if _look_t < LOOK_NEED or _cool > 0.0 or _shown >= MAX_PER_NIGHT:
		return
	_cool = randf_range(25.0, 60.0)
	_look_t = 0.0
	if randf() > 0.45:
		return      # не каждый раз — иначе ждёшь, а не боишься
	_show(best, eye, fwd)


func _show(w: Dictionary, eye: Vector3, fwd: Vector3) -> void:
	_spot = w
	_shown += 1
	var side := Vector3(-fwd.z, 0, fwd.x).normalized() * (0.45 if randf() < 0.5 else -0.45)
	var flat := Vector3(fwd.x, 0, fwd.z).normalized()
	_behind = eye - flat * 1.25 + side + Vector3(0, 0.05, 0)
	_alive = 0.0
	_place(eye)
	_quad.visible = true
	_mat.albedo_color.a = 0.0
	var tw := create_tween()
	tw.tween_property(_mat, "albedo_color:a", 0.75, 1.1)
	Game.audio.play_3d("res://assets/sfx/cc0/player_breath_loop.ogg", _behind, -24.0, 2.0, 1.5)
	Director.add_tension(6.0, "отражение в окне")


## Отражение точки за спиной в плоскости стекла — и где луч из глаз к нему пересекает стекло.
func _place(eye: Vector3) -> void:
	var g: Vector3 = _spot["glass"]
	var n: Vector3 = _spot["inward"]
	var mirrored := _behind - 2.0 * (_behind - g).dot(n) * n
	var dir := mirrored - eye
	var den := dir.dot(n)
	if absf(den) < 0.001:
		return
	var t := (g - eye).dot(n) / den
	var on_glass := eye + dir * t + n * 0.015
	_quad.global_position = on_glass
	var k := eye.distance_to(on_glass) / maxf(eye.distance_to(mirrored), 0.01)
	_quad.scale = Vector3.ONE * 1.15 * k   # голова и плечи (текстура — с запасом по краям)
	_quad.look_at(on_glass + n, Vector3.UP)


func _track(eye: Vector3, fwd: Vector3, delta: float) -> void:
	_alive += delta
	_place(eye)
	var g: Vector3 = _spot["glass"]
	var to_glass := (g - eye).normalized()
	# Обернулся — за спиной никого: отражение гаснет сразу
	if fwd.dot(to_glass) < 0.35:
		_hide(true)
		Game.audio.play_3d("res://assets/sfx/cc0/floor_creak_1.ogg", _behind, -14.0, 3.0)
		Achievements.unlock(&"turned")
		return
	if _alive > 4.5:
		_hide(false)


func _hide(now: bool) -> void:
	if not _quad.visible:
		return
	if now:
		_quad.visible = false
		_mat.albedo_color.a = 0.0
		return
	var tw := create_tween()
	tw.tween_property(_mat, "albedo_color:a", 0.0, 1.6)
	tw.tween_callback(func() -> void: _quad.visible = false)
	_alive = -100.0
