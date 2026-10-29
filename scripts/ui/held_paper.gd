class_name HeldPaper
extends Control
## Бумага в руках (вариант Б): бумажный экран рисуется в свой вьюпорт, а картинка ложится на лист,
## который держат перед камерой: он поднимается из-под кадра, наклонён к глазам, дышит вместе
## с дежурным, его освещает фонарь в левой руке (без фонаря в темноте лист едва угадывается).
##
## Положение листа — настоящее 3D (узлы под камерой), а рисуется он поверх кадра по спроецированной
## сетке точек: так он стоит в руке перспективой, но не попадает под PS1-пикселизацию мира и мелкий
## текст остаётся читаемым. Клик мышью — лучом из камеры в лист, точка на листе — в координаты
## вьюпорта: вся логика экрана остаётся прежней.
##
## Два вида:
##   journal(inner, base)  — модальное окно: раскрытая книга (журнал ТМ-1) в обеих руках;
##   notebook(owner, book) — книжка КМ-1 в правой руке у прибора; owner — экран прибора.

signal closed

const ENTER_TIME := 0.32
const SS := 2                                   ## рендер вьюпорта с запасом — буквы чёткие
const GRID := 6                                 ## сетка проекции листа (перспектива и свет по точкам)
const LAMP := Vector3(-0.22, -0.12, -0.12)      ## фонарь в левой руке (в осях камеры)

var mode := &"journal"
var inner: Control                              ## экран, нарисованный на листе
var _vp: SubViewport
var _base := Vector2i(1080, 630)                ## логический размер экрана на листе
var _root: Node3D                               ## всё, что в руках (только для положения)
var _pages: Array[Dictionary] = []              ## [{"node": Node3D, "size": Vector2, "uv": Rect2, "shade": float, "side": float}]
var _slabs: Array[Dictionary] = []              ## обложка и обрез страниц: [{"node", "size", "color"}]
var _target: Transform3D
var _hidden: Transform3D
var _t := 0.0
var _closing := false
var _fallback := false                          ## нет камеры (меню, тесты без игрока) — обычный 2D
var _torch := 0.0


## Журнал: обёртка-модалка вокруг готового экрана.
static func journal(p_inner: Control, base: Vector2i) -> HeldPaper:
	var h := HeldPaper.new()
	h.mode = &"journal"
	h.inner = p_inner
	h._base = base
	return h


## Книжка у прибора: book уезжает на лист в руке, экран прибора остаётся как был.
static func notebook(owner: Control, book: Control, base := Vector2i(400, 460)) -> HeldPaper:
	var h := HeldPaper.new()
	h.mode = &"notebook"
	h.inner = book
	h._base = base
	h.mouse_filter = Control.MOUSE_FILTER_STOP
	# ловим мышь только над правой половиной экрана — там лист
	UiKit.place(owner, h, 0.5, 0, 1, 1, 60, 0, 0, 0)
	return h


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var cam: Camera3D = Game.player.camera if Game.player != null and is_instance_valid(Game.player) else null
	if cam == null:
		_fallback = true
		_place_2d()
		return
	_vp = SubViewport.new()
	_vp.size = _base * SS
	_vp.size_2d_override = _base
	_vp.size_2d_override_stretch = true
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.gui_embed_subwindows = true
	add_child(_vp)
	_vp.add_child(inner)
	if mode == &"journal":
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if inner.has_signal(&"closed"):
			inner.connect(&"closed", _close)
	else:
		inner.position = Vector2(10, 14)
		inner.size = Vector2(_base) - Vector2(20, 28)
	_root = Node3D.new()
	cam.add_child(_root)
	if mode == &"journal":
		_build_book(cam)
	else:
		_build_notebook(cam)
	_root.transform = _hidden
	Game.audio.play_2d("res://assets/audio/ui_tick.ogg", -10.0)


func _exit_tree() -> void:
	if _root != null and is_instance_valid(_root):
		_root.queue_free()


## Без камеры — как раньше: экран просто поверх игры.
func _place_2d() -> void:
	if mode == &"journal":
		add_child(inner)
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if inner.has_signal(&"closed"):
			inner.connect(&"closed", func() -> void: closed.emit())
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var owner := get_parent() as Control
		UiKit.place(owner, inner, 0.5, 0.5, 0.5, 0.5, 120, -252, 500, 180)


# --- Положение в руках ------------------------------------------------------------------

## Где на экране и какого размера: центр в долях NDC (−1..1), высота — доля высоты кадра.
static func _screen_pose(cam: Camera3D, center: Vector2, height_frac: float, dist: float) -> Array:
	var half_h := dist * tan(deg_to_rad(cam.fov) * 0.5)
	var vs := cam.get_viewport().get_visible_rect().size
	var aspect := vs.x / maxf(vs.y, 1.0)
	return [Vector3(center.x * half_h * aspect, center.y * half_h, -dist), height_frac * 2.0 * half_h]


func _node(parent: Node3D, pos: Vector3, rot := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation = rot
	parent.add_child(n)
	return n


## Раскрытая книга: две страницы под углом к корешку, под ними обрез и переплёт.
func _build_book(cam: Camera3D) -> void:
	var pose := _screen_pose(cam, Vector2(0.0, 0.03), 0.74, 0.42)
	var h: float = pose[1]
	var w := h * float(_base.x) / float(_base.y)
	var fold := deg_to_rad(8.0)
	_target = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-14.0), 0.0, 0.0)), pose[0])
	_hidden = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-60.0), 0.0, 0.0)), pose[0] + Vector3(0, -0.45, 0.1))
	for side in [-1, 1]:
		var hinge := _node(_root, Vector3.ZERO, Vector3(0, -side * fold, 0))
		var page := _node(hinge, Vector3(side * w * 0.25, 0, 0))
		_slabs.append({"node": _node(page, Vector3(side * 0.008, -0.004, -0.012)), "size": Vector2(w * 0.5 + 0.016, h + 0.024), "color": Color(0.12, 0.14, 0.19)})
		_slabs.append({"node": _node(page, Vector3(side * 0.003, -0.002, -0.004)), "size": Vector2(w * 0.5 + 0.004, h + 0.008), "color": Color(0.78, 0.74, 0.64)})
		var uv := Rect2(0.0 if side < 0 else 0.5, 0.0, 0.5, 1.0)
		_pages.append({"node": page, "size": Vector2(w * 0.5, h), "uv": uv, "shade": 0.35, "side": 1.0 if side < 0 else -1.0})


## Книжка КМ-1 в правой руке: листок на картонной обложке, чуть набок, к прибору.
func _build_notebook(cam: Camera3D) -> void:
	var pose := _screen_pose(cam, Vector2(0.5, 0.1), 0.58, 0.36)
	var h: float = pose[1]
	var w := h * float(_base.x) / float(_base.y)
	_target = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-10.0), deg_to_rad(-12.0), deg_to_rad(-3.0))), pose[0])
	_hidden = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-55.0), deg_to_rad(-20.0), 0.0)), pose[0] + Vector3(0.1, -0.4, 0.08))
	_slabs.append({"node": _node(_root, Vector3(0.004, -0.006, -0.008)), "size": Vector2(w * 0.94, h * 0.95), "color": Color(0.2, 0.24, 0.17)})
	_pages.append({"node": _root, "size": Vector2(w, h), "uv": Rect2(0, 0, 1, 1), "shade": 0.0, "side": 1.0})


# --- Анимация и свет --------------------------------------------------------------------

func _process(delta: float) -> void:
	if _fallback or _root == null:
		return
	_t += delta
	var k := clampf(_t / ENTER_TIME, 0.0, 1.0)
	if _closing:
		k = 1.0 - k
	k = k * k * (3.0 - 2.0 * k)
	var tr := _hidden.interpolate_with(_target, k)
	tr.origin += Vector3(sin(_t * 0.9) * 0.002, sin(_t * 1.3) * 0.003, 0.0)   # дыхание
	_root.transform = tr
	var on: bool = Game.player != null and Game.player.flashlight != null and Game.player.flashlight.visible
	_torch = lerpf(_torch, 1.0 if on else 0.0, clampf(delta * 10.0, 0.0, 1.0))
	queue_redraw()
	if _closing and _t >= ENTER_TIME:
		closed.emit()
		set_process(false)


## Освещённость точки листа (в осях камеры): день и лампа в комнате — ровно; ночью — пятно фонаря.
func _light(p: Vector3) -> Color:
	var amb := 1.0 if Game.is_daylight() else (0.82 if not Game.is_dark() else 0.06)
	var d := p.distance_to(LAMP)
	var torch := _torch * clampf(1.25 - d * 1.5, 0.0, 1.0)
	var k := clampf(amb + torch, 0.0, 1.0)
	var warm := clampf(torch / maxf(amb + torch, 0.001), 0.0, 1.0)
	return Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.92, 0.78), warm) * k


## Мир рендерится в уменьшенный вьюпорт (пикселизация, Session): его пиксели → экран HUD.
func _vp_to_screen(cam: Camera3D) -> Transform2D:
	var c := cam.get_viewport().get_parent() as SubViewportContainer
	if c == null:
		return Transform2D.IDENTITY
	return c.get_global_transform_with_canvas() * Transform2D().scaled(Vector2.ONE * float(c.stretch_shrink))


func _draw() -> void:
	if _fallback or _root == null:
		return
	var cam: Camera3D = Game.player.camera
	var inv := get_global_transform_with_canvas().affine_inverse() * _vp_to_screen(cam)
	var to_cam := cam.global_transform.affine_inverse()
	for s: Dictionary in _slabs:
		_draw_quad(cam, inv, to_cam, s["node"], s["size"], 1, null, Rect2(), s["color"], 0.0, 1.0)
	var tex := _vp.get_texture()
	for p: Dictionary in _pages:
		_draw_quad(cam, inv, to_cam, p["node"], p["size"], GRID, tex, p["uv"], Color.WHITE, p["shade"], p["side"])


## Прямоугольник size в плоскости узла (XY), разбитый на n×n клеток: перспектива и свет по точкам.
func _draw_quad(cam: Camera3D, inv: Transform2D, to_cam: Transform3D, node: Node3D, size: Vector2, n: int,
		tex: Texture2D, uv: Rect2, base: Color, shade: float, side: float) -> void:
	var gt := node.global_transform
	var pts: Array[Vector2] = []
	var cols: Array[Color] = []
	var uvs: Array[Vector2] = []
	for gy in n + 1:
		for gx in n + 1:
			var u := float(gx) / n
			var v := float(gy) / n
			var w := gt * Vector3((u - 0.5) * size.x, (0.5 - v) * size.y, 0.0)
			if cam.is_position_behind(w):
				return
			pts.append(inv * cam.unproject_position(w))
			var c := _light(to_cam * w) * base
			if shade > 0.0:   # к корешку темнее — страница уходит в сгиб
				var sp := u if side > 0.0 else 1.0 - u
				c = c.darkened(shade * smoothstep(0.75, 1.0, sp))
			cols.append(c)
			uvs.append(uv.position + Vector2(u, v) * uv.size)
	for gy in n:
		for gx in n:
			var i := gy * (n + 1) + gx
			var idx := [i, i + 1, i + n + 2, i + n + 1]
			var pp := PackedVector2Array()
			var cc := PackedColorArray()
			var uu := PackedVector2Array()
			for j: int in idx:
				pp.append(pts[j])
				cc.append(cols[j])
				uu.append(uvs[j])
			if tex != null:
				draw_polygon(pp, cc, uu, tex)
			else:
				draw_polygon(pp, cc)


func _close() -> void:
	if _closing:
		return
	_closing = true
	_t = 0.0
	Game.audio.play_2d("res://assets/audio/ui_tick.ogg", -14.0)


# --- Ввод -------------------------------------------------------------------------------

## Точка экрана → пиксель листа (или null, если мимо).
func _screen_to_page(screen: Vector2) -> Variant:
	var cam: Camera3D = Game.player.camera
	var vp_pos := _vp_to_screen(cam).affine_inverse() * screen
	var from := cam.project_ray_origin(vp_pos)
	var dir := cam.project_ray_normal(vp_pos)
	var best: Variant = null
	var best_d := INF
	for p: Dictionary in _pages:
		var gt: Transform3D = (p["node"] as Node3D).global_transform
		var n := gt.basis.z.normalized()
		var den := n.dot(dir)
		if absf(den) < 0.0001:
			continue
		var t := n.dot(gt.origin - from) / den
		if t <= 0.0 or t >= best_d:
			continue
		var local := gt.affine_inverse() * (from + dir * t)
		var sz: Vector2 = p["size"]
		var u := local.x / sz.x + 0.5
		var v := 0.5 - local.y / sz.y
		if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
			continue
		var uv: Rect2 = p["uv"]
		best = Vector2(uv.position.x + u * uv.size.x, uv.position.y + v * uv.size.y) * Vector2(_base)
		best_d = t
	return best


func _gui_input(event: InputEvent) -> void:
	if _fallback or _vp == null or not (event is InputEventMouse):
		return
	var pos: Variant = _screen_to_page(get_global_transform_with_canvas() * (event as InputEventMouse).position)
	if pos == null:
		if event is InputEventMouseMotion:
			var away := InputEventMouseMotion.new()
			away.position = Vector2(-100, -100)
			_vp.push_input(away, true)
		return
	var ev := event.duplicate() as InputEventMouse
	ev.position = pos
	ev.global_position = pos
	_vp.push_input(ev, true)
	accept_event()


## Точка листа (пиксели экрана на листе) → точка в осях этого контрола: для проверок и подсказок.
func page_to_local(px: Vector2) -> Vector2:
	var p: Dictionary = _pages[0]
	for q: Dictionary in _pages:
		var r: Rect2 = q["uv"]
		if r.has_point(px / Vector2(_base)):
			p = q
	var r2: Rect2 = p["uv"]
	var uv := (px / Vector2(_base) - r2.position) / r2.size
	var sz: Vector2 = p["size"]
	var w := (p["node"] as Node3D).global_transform * Vector3((uv.x - 0.5) * sz.x, (0.5 - uv.y) * sz.y, 0.0)
	var cam: Camera3D = Game.player.camera
	return get_global_transform_with_canvas().affine_inverse() * _vp_to_screen(cam) * cam.unproject_position(w)


## Клавиши — самому экрану (как в 2D): Enter, стрелки, цифры, закрыть.
func handle_input(event: InputEvent) -> void:
	if _closing:
		return
	if inner != null and is_instance_valid(inner) and inner.has_method(&"handle_input"):
		inner.call(&"handle_input", event)
