class_name Closeup3D
extends Node3D
## Крупный план прибора в мире: своя камера плавно подходит к модели, смотрит на неё и ездит вдоль
## шкалы (scroll). На время крупного плана мир рисуется без PS1-пикселизации — шкала резкая.
## Фонарь в руке светит и отсюда. Мышь → луч в мир (ray) — стирать иней прямо по стеклу.
## Создаёт экран прибора; удаляется вместе с ним (освобождает камеру и пикселизацию).

const ENTER := 0.35

var cam: Camera3D
var _from: Transform3D
var _base: Transform3D            ## куда подошли (scroll — сдвиг вдоль axis)
var _axis := Vector3.UP
var _min := 0.0
var _max := 0.0
var _off := 0.0
var _t := 0.0
var _spot: SpotLight3D
var _prev_shrink := -1
var _container: SubViewportContainer


## eye — где глаз, target — куда смотрит; scroll вдоль axis в пределах [lo, hi] метров.
func setup(eye: Vector3, target: Vector3, fov: float, axis := Vector3.UP, lo := 0.0, hi := 0.0, start := 0.0) -> void:
	_axis = axis.normalized()
	_min = lo
	_max = hi
	_off = clampf(start, lo, hi)
	var pc: Camera3D = Game.player.camera
	_from = pc.global_transform
	cam = Camera3D.new()
	cam.fov = fov
	cam.near = 0.01
	cam.far = 400.0
	add_child(cam)
	_base = Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)
	cam.global_transform = _from
	cam.current = true
	_spot = SpotLight3D.new()
	_spot.spot_range = 3.5
	_spot.spot_angle = 34.0
	_spot.light_energy = 0.45
	_spot.light_color = Color(1.0, 0.93, 0.8)
	_spot.shadow_enabled = false
	_spot.position = Vector3(-0.08, -0.05, 0.0)
	cam.add_child(_spot)
	var s := get_tree().get_first_node_in_group(&"session")
	if s != null:
		_container = s.get(&"_container") as SubViewportContainer
		if _container != null:
			_prev_shrink = _container.stretch_shrink
			_container.stretch_shrink = 1


func _exit_tree() -> void:
	if _container != null and is_instance_valid(_container) and _prev_shrink > 0:
		_container.stretch_shrink = _prev_shrink
	if Game.player != null and is_instance_valid(Game.player):
		Game.player.camera.current = true


func scroll(meters: float) -> void:
	_off = clampf(_off + meters, _min, _max)


func offset() -> float:
	return _off


func lit() -> bool:
	return Game.player != null and Game.player.flashlight != null and Game.player.flashlight.visible


## Видно ли шкалу: днём — да; ночью — только с фонарём.
func can_see() -> bool:
	return Game.is_daylight() or lit()


func _process(delta: float) -> void:
	if cam == null:
		return
	_t += delta
	var k := clampf(_t / ENTER, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var goal := _base
	goal.origin += _axis * _off
	var tr := _from.interpolate_with(goal, k)
	tr.origin += Vector3(0, sin(_t * 1.1) * 0.0008, 0)   # дыхание
	cam.global_transform = tr
	_spot.visible = lit()


## Луч из камеры через точку экрана (координаты HUD): [origin, dir].
func ray(screen: Vector2) -> Array:
	var p := screen
	if _container != null:
		p = (_container.get_global_transform_with_canvas() * Transform2D().scaled(Vector2.ONE * float(_container.stretch_shrink))).affine_inverse() * screen
	return [cam.project_ray_origin(p), cam.project_ray_normal(p)]


## Пересечение луча с плоскостью узла (его XY): локальная точка или null.
static func hit_plane(r: Array, node: Node3D) -> Variant:
	var gt := node.global_transform
	var n := gt.basis.z.normalized()
	var den := n.dot(r[1])
	if absf(den) < 0.0001:
		return null
	var t := n.dot(gt.origin - (r[0] as Vector3)) / den
	if t <= 0.0:
		return null
	return gt.affine_inverse() * ((r[0] as Vector3) + (r[1] as Vector3) * t)


# --- Иней на стекле: квадрат с прозрачной картинкой, стирается мышью --------------------

class Frost:
	extends MeshInstance3D
	var img: Image
	var tex: ImageTexture
	var size := Vector2.ONE
	var _dirty := false

	func _init(p_size: Vector2, amount: float, res := Vector2i(24, 160)) -> void:
		size = p_size
		var q := QuadMesh.new()
		q.size = p_size
		mesh = q
		img = Image.create(res.x, res.y, false, Image.FORMAT_RGBA8)
		var noise := FastNoiseLite.new()
		noise.seed = randi()
		noise.frequency = 0.12
		var grain := FastNoiseLite.new()
		grain.seed = randi()
		grain.frequency = 0.7
		for y in res.y:
			for x in res.x:
				var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
				var g := grain.get_noise_2d(x, y) * 0.5 + 0.5
				var th := 0.68 - amount * 0.14   # пятнами — в сильный мороз на треть стекла, сквозь иней шкала угадывается
				var a := smoothstep(th, th + 0.1, n) * (0.4 + g * 0.3)
				img.set_pixel(x, y, Color(0.9, 0.94, 0.98, a))
		tex = ImageTexture.create_from_image(img)
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 1.0
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		material_override = m
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	## Стереть рукавицей вокруг локальной точки (в плоскости квадрата).
	func wipe(local: Vector3, delta: float) -> bool:
		var u := local.x / size.x + 0.5
		var v := 0.5 - local.y / size.y
		if u < -0.05 or u > 1.05 or v < -0.05 or v > 1.05:
			return false
		var cell := Vector2(u * img.get_width(), v * img.get_height())
		var r := Vector2(img.get_width() * 0.6, img.get_width() * 0.35 * (size.x / size.y) * float(img.get_height()) / img.get_width())
		var hit := false
		for y in range(maxi(0, int(cell.y - r.y)), mini(img.get_height(), int(cell.y + r.y) + 1)):
			for x in range(maxi(0, int(cell.x - r.x)), mini(img.get_width(), int(cell.x + r.x) + 1)):
				var d := Vector2((x + 0.5 - cell.x) / r.x, (y + 0.5 - cell.y) / r.y).length()
				if d > 1.0:
					continue
				var c := img.get_pixel(x, y)
				if c.a <= 0.0:
					continue
				c.a = maxf(0.0, c.a - delta * 3.5 * (1.0 - d))
				img.set_pixel(x, y, c)
				hit = true
		if hit:
			_dirty = true
		return hit

	func _process(_delta: float) -> void:
		if _dirty:
			_dirty = false
			tex.update(img)


## Шкала, нарисованная один раз во вьюпорт: через пару кадров картинка копируется в обычную текстуру,
## вьюпорт удаляется (отключённый вьюпорт в GL Compatibility теряет картинку).
static func canvas_tex(owner: Node, size: Vector2i, draw_fn: Callable) -> Texture2D:
	var out := ImageTexture.create_from_image(Image.create(size.x, size.y, false, Image.FORMAT_RGBA8))
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	owner.add_child(vp)
	var c := Control.new()
	c.size = Vector2(size)
	c.draw.connect(func() -> void: draw_fn.call(c))
	vp.add_child(c)
	_bake.call_deferred(vp, out)
	return out


static func _bake(vp: SubViewport, out: ImageTexture) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	if not is_instance_valid(vp):
		return
	var img := vp.get_texture().get_image()
	if img != null:
		img.generate_mipmaps()
		out.set_image(img)
	vp.queue_free()
