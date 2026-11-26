class_name CorpusDressing
extends Node3D
## Жизнь корпуса поверх запечённой обстановки (corpus_furn.glb): пульт анеморумбометра со шкалами,
## стрелками и лампами; барограф и термограф под стеклянными колпаками, с барабаном и пером;
## плакаты, календарь, карта района, доска приказов, часы, кружки, пепельницы, бумаги.
## Всё — слой «внутри» (Station.LAYER_IN): светят лампы корпуса, луна не достаёт.

const FL := MeteoCorpus.FL
const CAB := MeteoCorpus.CAB
const PX := 91.7
const PZ := -33.75

static var instance: CorpusDressing

var _needles: Array[Node3D] = []      ## [скорость, румб]
var _gust_pivot: Node3D               ## красный контрольный указатель максимума (порыв)
var _drive := Vector3.ZERO            ## стрелки ведёт экран пульта (WindPanelUI): x — скорость, y — порыв, z — румб
var _drive_t := 0.0
var _lamp_net: MeshInstance3D
var _lamp_ice: MeshInstance3D
var _pens: Array[Node3D] = []
var _t := 0.0
var _speed := 0.0
var _dust: CPUParticles3D


func _ready() -> void:
	instance = self
	_build_pult()
	_build_recorders()
	_build_posters()
	_build_clutter()
	_build_dust()
	for g: GeometryInstance3D in find_children("*", "GeometryInstance3D", true, false):
		g.layers = Station.LAYER_IN
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _exit_tree() -> void:
	if instance == self:
		instance = null


## Экран пульта ведёт стрелки сам (аномалии, порывы, контрольный указатель) — пока зовёт каждый кадр.
func drive(speed: float, gust: float, az: float) -> void:
	_drive = Vector3(speed, gust, az)
	_drive_t = 0.25


## Центр шкалы (0 — скорость, 1 — румб) в мире; лицо шкалы смотрит на +Z.
static func dial_center(i: int) -> Vector3:
	return Vector3(PX - 0.35 if i == 0 else PX + 0.35, FL + 1.02, PZ - 0.12 + 0.031)


# --- Помощники ----------------------------------------------------------------------------

static func _mat(c: Color, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mi := Geo.box_mesh(size, mat)
	mi.position = pos
	mi.rotation = rot
	(parent if parent != null else self).add_child(mi)
	return mi


func _cyl(r: float, h: float, pos: Vector3, mat: Material, rot := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 16
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	(parent if parent != null else self).add_child(mi)
	return mi


func _label(text: String, pos: Vector3, yaw: float, size: int, font: Font, col: Color, w := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = size
	l.pixel_size = 0.0011
	l.modulate = col
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.position = pos
	l.rotation.y = yaw
	if w > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.width = w
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if w > 0.0 else HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	return l


## Лист бумаги на стене: подложка + текст. yaw — куда смотрит лицевая сторона.
func _sheet(pos: Vector3, yaw: float, size: Vector2, title: String, body := "", body_font: Font = null, tint := Color(0.88, 0.85, 0.76)) -> void:
	var paper := _box(Vector3(size.x, size.y, 0.006), pos, _mat(tint, 0.95), Vector3(0, yaw, 0))
	paper.rotation.z = randf_range(-0.02, 0.02)
	var fwd := Vector3(sin(yaw), 0, cos(yaw)) * 0.006
	var top := pos + Vector3(0, size.y * 0.5 - 0.05, 0) + fwd
	_label(title, top, yaw, 28, UiStyle.plate_font(), Color(0.15, 0.13, 0.12))
	if body != "":
		var left := Vector3(cos(yaw), 0, -sin(yaw)) * (-size.x * 0.5 + 0.04)
		var l := _label(body, pos + Vector3(0, size.y * 0.5 - 0.1, 0) + left + fwd, yaw, 20, body_font if body_font != null else UiStyle.type_font(), Color(0.15, 0.13, 0.12), (size.x - 0.08) / 0.0011)
		l.vertical_alignment = VERTICAL_ALIGNMENT_TOP


## Текстура, нарисованная один раз (шкала, лента): вьюпорт с Control, рисующим draw_fn.
func _canvas_tex(size: Vector2i, draw_fn: Callable) -> Texture2D:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS   # пару кадров, пока шрифт готов; потом — стоп
	# связь через метод самого вьюпорта: если уровень пересобрали раньше таймера — связь снимется сама
	get_tree().create_timer(1.5, false).timeout.connect(vp.set.bind(&"render_target_update_mode", SubViewport.UPDATE_DISABLED))
	add_child(vp)
	var c := Control.new()
	c.size = Vector2(size)
	c.draw.connect(func() -> void: draw_fn.call(c))
	vp.add_child(c)
	return vp.get_texture()


func _tex_mat(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED   # фонарь не даёт белого блика на шкалах и листах
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m


# --- Пульт анеморумбометра ----------------------------------------------------------------

func _build_pult() -> void:
	var face_z := PZ - 0.12 + 0.031
	var bez := _mat(Color(0.12, 0.12, 0.12), 0.4)
	var speed_tex := _canvas_tex(Vector2i(512, 512), _draw_speed_face)   # 512 — крупный план читает их вблизи
	var rumb_tex := _canvas_tex(Vector2i(512, 512), _draw_rumb_face)
	for i in 2:
		var cx := PX - 0.35 if i == 0 else PX + 0.35
		var q := QuadMesh.new()
		q.size = Vector2(0.34, 0.34)
		var face := MeshInstance3D.new()
		face.mesh = q
		face.material_override = _tex_mat(speed_tex if i == 0 else rumb_tex)
		face.position = Vector3(cx, FL + 1.02, face_z + 0.008)
		add_child(face)
		_cyl(0.19, 0.01, Vector3(cx, FL + 1.02, face_z - 0.010), bez, Vector3(PI * 0.5, 0, 0))   # ободок за шкалой
		var pivot := Node3D.new()
		pivot.position = Vector3(cx, FL + 1.02, face_z + 0.006)
		add_child(pivot)
		_box(Vector3(0.006, 0.13, 0.004), Vector3(0, 0.055, 0), _mat(Color(0.08, 0.08, 0.08)), Vector3.ZERO, pivot)
		_cyl(0.012, 0.008, Vector3.ZERO, _mat(Color(0.3, 0.3, 0.3), 0.3), Vector3(PI * 0.5, 0, 0), pivot)
		_needles.append(pivot)
		if i == 0:
			_gust_pivot = Node3D.new()
			_gust_pivot.position = pivot.position - Vector3(0, 0, 0.002)
			add_child(_gust_pivot)
			_box(Vector3(0.004, 0.14, 0.002), Vector3(0, 0.06, 0), _mat(Color(0.7, 0.08, 0.06), 0.5), Vector3.ZERO, _gust_pivot)
			_gust_pivot.rotation.z = _speed_angle(0.0)
		_label(Loc.t(&"corpus.dial_speed") if i == 0 else Loc.t(&"corpus.dial_dir"), Vector3(cx, FL + 0.82, face_z + 0.004), 0.0, 22, UiStyle.plate_font(), Color(0.85, 0.8, 0.65))
	_label(Loc.t(&"corpus.pult_plate"), Vector3(PX, FL + 1.21, face_z + 0.004), 0.0, 24, UiStyle.plate_font(), Color(0.85, 0.8, 0.65))
	# Лампы «СЕТЬ» и «ОБЛЕДЕНЕНИЕ», тумблеры на столешнице, самописец ленты сбоку
	var glow_g := StandardMaterial3D.new()
	glow_g.albedo_color = Color(0.2, 0.5, 0.2)
	glow_g.emission_enabled = true
	glow_g.emission = Color(0.3, 1.0, 0.35)
	_lamp_net = _cyl(0.015, 0.02, Vector3(PX - 0.68, FL + 1.12, face_z + 0.01), glow_g, Vector3(PI * 0.5, 0, 0))
	var glow_r := glow_g.duplicate() as StandardMaterial3D
	glow_r.albedo_color = Color(0.5, 0.15, 0.1)
	glow_r.emission = Color(1.0, 0.2, 0.1)
	_lamp_ice = _cyl(0.015, 0.02, Vector3(PX + 0.68, FL + 1.12, face_z + 0.01), glow_r, Vector3(PI * 0.5, 0, 0))
	for k in 6:
		var tx := PX - 0.45 + k * 0.18
		_box(Vector3(0.05, 0.02, 0.04), Vector3(tx, FL + 0.865, PZ + 0.2), _mat(Color(0.15, 0.15, 0.15)))
		_box(Vector3(0.008, 0.035, 0.008), Vector3(tx, FL + 0.89, PZ + 0.2), _mat(Color(0.7, 0.7, 0.68), 0.3), Vector3(0.4 if k % 2 == 0 else -0.4, 0, 0))
	var rec := Vector3(PX - 0.62, FL + 0.86, PZ + 0.12)
	_box(Vector3(0.24, 0.12, 0.26), rec + Vector3(0, 0.06, 0), _mat(Color(0.25, 0.28, 0.26), 0.5))
	_cyl(0.035, 0.22, rec + Vector3(0, 0.15, 0.0), _mat(Color(0.86, 0.84, 0.78)), Vector3(0, 0, PI * 0.5))
	_box(Vector3(0.2, 0.002, 0.3), rec + Vector3(0, 0.125, 0.12), _mat(Color(0.86, 0.84, 0.78)))
	# Стопка книжек КМ-1, карандаш, термос
	for k in 3:
		_box(Vector3(0.15, 0.012, 0.21), Vector3(PX + 0.45, FL + 0.862 + k * 0.015, PZ + 0.18), _mat(Color(0.25, 0.3, 0.42).darkened(k * 0.1)), Vector3(0, k * 0.08, 0))
	_box(Vector3(0.15, 0.006, 0.006), Vector3(PX + 0.2, FL + 0.86, PZ + 0.25), _mat(Color(0.75, 0.6, 0.2)), Vector3(0, 0.6, 0))
	_cyl(0.04, 0.26, Vector3(PX + 0.72, FL + 0.99, PZ + 0.22), _mat(Color(0.3, 0.12, 0.1), 0.4))


func _draw_speed_face(c: Control) -> void:
	_dial_bg(c)
	var k := c.size.x / 256.0
	var cc := c.size * 0.5
	var r := c.size.x * 0.46
	var f := UiStyle.plate_font()
	var a0 := deg_to_rad(135.0)
	var span := deg_to_rad(270.0)
	for v in 41:
		var a := a0 + span * v / 40.0
		var d := Vector2(cos(a), sin(a))
		var long := v % 5 == 0
		c.draw_line(cc + d * (r - (22 if long else 11) * k), cc + d * (r - 3 * k), Color(0.1, 0.1, 0.1), (3.0 if long else 1.5) * k)
		if long:
			var s := str(v)
			var fs := int(22 * k)
			var sw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			c.draw_string(f, cc + d * (r - 42 * k) + Vector2(-sw * 0.5, 8 * k), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.1, 0.1, 0.1))
	var unit := Loc.t(&"pult.ms")
	var uw := f.get_string_size(unit, HORIZONTAL_ALIGNMENT_LEFT, -1, int(20 * k)).x
	c.draw_string(f, cc + Vector2(-uw * 0.5, r * 0.5), unit, HORIZONTAL_ALIGNMENT_LEFT, -1, int(20 * k), Color(0.1, 0.1, 0.1))


func _draw_rumb_face(c: Control) -> void:
	_dial_bg(c)
	var k := c.size.x / 256.0
	var cc := c.size * 0.5
	var r := c.size.x * 0.46
	var f := UiStyle.plate_font()
	var names := Loc.t(&"pult.rumbs").split(",")
	for i in 16:
		var a := deg_to_rad(i * 22.5 - 90.0)
		var d := Vector2(cos(a), sin(a))
		var major := i % 4 == 0
		c.draw_line(cc + d * (r - (24 if major else 12) * k), cc + d * (r - 3 * k), Color(0.1, 0.1, 0.1), (3.0 if major else 1.5) * k)
		if names.size() == 16 and i % 2 == 0:   # главные румбы крупно, промежуточные (СВ, ЮЗ…) — мельче
			var fs := int((28 if major else 17) * k)
			var sw := f.get_string_size(names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			c.draw_string(f, cc + d * (r - (46 if major else 40) * k) + Vector2(-sw * 0.5, fs * 0.36), names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.1, 0.1, 0.1))


static func _speed_angle(v: float) -> float:
	return -(deg_to_rad(-135.0) + deg_to_rad(270.0) * clampf(v / 40.0, 0.0, 1.0))


static func _dial_bg(c: Control) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.12, 0.12, 0.12))
	c.draw_circle(c.size * 0.5, c.size.x * 0.47, Color(0.87, 0.84, 0.74))
	var k := c.size.x / 256.0
	for i in 6:
		c.draw_arc(c.size * 0.5, c.size.x * 0.47 - i * 3.0 * k, 0.0, TAU, 96, Color(0.5, 0.45, 0.35, 0.05 * (6 - i)), 3.0 * k)


# --- Барограф и термограф под колпаками -------------------------------------------------

func _build_recorders() -> void:
	var drum_tex := _canvas_tex(Vector2i(512, 128), _draw_chart_paper)
	var drum_mat := _tex_mat(drum_tex)
	var wood := _mat(Color(0.22, 0.14, 0.09), 0.6)
	var brass := _mat(Color(0.62, 0.5, 0.27), 0.35)
	brass.metallic = 0.7
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.8, 0.88, 0.92, 0.18)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 0.9
	for k in 2:
		var o := Vector3(94.3, FL + 0.76, -30.4 if k == 0 else -29.65)
		# Каждый прибор — свой узел: крупный план барографа (BarographUI) прячет его и ставит свой барабан
		var holder := Node3D.new()
		add_child(holder)
		if k == 0:
			holder.add_to_group(&"barograph_model")
			holder.set_meta(&"rig_base", o)
			holder.set_meta(&"rig_yaw", -PI * 0.5)   # стол у перегородки: смотрят на прибор с запада
		_box(Vector3(0.24, 0.04, 0.38), o + Vector3(0, 0.020, 0), wood, Vector3.ZERO, holder)
		_box(Vector3(0.2, 0.008, 0.34), o + Vector3(0, 0.056, 0), _mat(Color(0.3, 0.3, 0.3), 0.4), Vector3.ZERO, holder)
		# барабан с лентой
		_cyl(0.05, 0.09, o + Vector3(-0.03, 0.105, 0.08), drum_mat, Vector3.ZERO, holder)
		_cyl(0.052, 0.006, o + Vector3(-0.03, 0.153, 0.08), brass, Vector3.ZERO, holder)
		# чувствительный элемент: анероидные коробки / биметаллическая пластина
		if k == 0:
			for j in 6:
				_cyl(0.035, 0.008, o + Vector3(0.0, 0.065 + j * 0.011, -0.09), brass, Vector3.ZERO, holder)
		else:
			_box(Vector3(0.012, 0.012, 0.16), o + Vector3(0.06, 0.09, -0.06), brass, Vector3(0, 0.2, 0), holder)
		# перо на рычаге — от элемента к барабану
		var pen := Node3D.new()
		pen.position = o + Vector3(0.0, 0.12, -0.09)
		holder.add_child(pen)
		_box(Vector3(0.004, 0.004, 0.18), Vector3(-0.015, 0, 0.09), _mat(Color(0.1, 0.1, 0.1)), Vector3(0, 0.15, 0), pen)
		_box(Vector3(0.006, 0.012, 0.006), Vector3(-0.03, 0, 0.17), _mat(Color(0.35, 0.1, 0.5)), Vector3.ZERO, pen)
		_pens.append(pen)
		# колпак: стекло в латунной рамке
		_box(Vector3(0.22, 0.17, 0.36), o + Vector3(0, 0.144, 0), glass, Vector3.ZERO, holder)
		for e: Array in [[Vector3(0.22, 0.008, 0.008), Vector3(0, 0.225, 0.18)], [Vector3(0.22, 0.008, 0.008), Vector3(0, 0.225, -0.18)],
				[Vector3(0.008, 0.008, 0.36), Vector3(0.11, 0.225, 0)], [Vector3(0.008, 0.008, 0.36), Vector3(-0.11, 0.225, 0)]]:
			_box(e[0], o + e[1], brass, Vector3.ZERO, holder)
		_label(Loc.t(&"corpus.baro_plate") if k == 0 else Loc.t(&"corpus.thermo_plate"), o + Vector3(-0.121, 0.03, 0), -PI * 0.5, 14, UiStyle.plate_font(), Color(0.85, 0.75, 0.45)).reparent(holder)
	# Флакон чернил и кисточка — перо надо заправлять
	_cyl(0.018, 0.04, Vector3(94.45, FL + 0.78, -30.0), _mat(Color(0.25, 0.1, 0.4), 0.2))


func _draw_chart_paper(c: Control) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.93, 0.91, 0.84))
	for x in range(0, int(c.size.x), 16):
		c.draw_line(Vector2(x, 0), Vector2(x, c.size.y), Color(0.55, 0.42, 0.55, 0.5 if x % 64 == 0 else 0.25), 1.0)
	for y in range(0, int(c.size.y), 10):
		c.draw_line(Vector2(0, y), Vector2(c.size.x, y), Color(0.55, 0.42, 0.55, 0.25), 1.0)
	var pts := PackedVector2Array()
	for x in range(0, 380, 4):
		pts.append(Vector2(x, 64.0 + sin(x * 0.03) * 14.0 + sin(x * 0.11) * 4.0))
	c.draw_polyline(pts, Color(0.42, 0.12, 0.55), 2.0)


# --- Плакаты, календарь, карта, доска, часы ----------------------------------------------

func _build_posters() -> void:
	var tf := UiStyle.type_font()
	# Аппаратная: схема включения анеморумбометра (на перегородке, лицом на запад; дверь в коридор — z −31.8…−30.9)
	var ps := Vector3(94.705, FL + 1.65, -33.05)
	_sheet(ps, -PI * 0.5, Vector2(1.1, 0.8), Loc.t(&"corpus.poster_scheme"))
	var ink := _mat(Color(0.15, 0.15, 0.18))
	for b: Array in [[Vector3(0, 0.15, 0.3), Vector3(0.006, 0.12, 0.2)], [Vector3(0, 0.15, -0.3), Vector3(0.006, 0.12, 0.2)],
			[Vector3(0, -0.15, 0.0), Vector3(0.006, 0.16, 0.34)], [Vector3(0, 0.0, 0.3), Vector3(0.006, 0.18, 0.006)],
			[Vector3(0, 0.0, -0.3), Vector3(0.006, 0.18, 0.006)], [Vector3(0, -0.08, 0.0), Vector3(0.006, 0.006, 0.6)]]:
		_box(b[1], ps + Vector3(-0.020, 0, 0) + b[0], ink)
	# Кабинет наблюдателя: календарь (над столом, на западной стене) и карта района (на перегородке)
	# календарь — на простенке между перегородкой тамбура и окном (окно z −24.75…−23.65)
	var cal_z := -25.35
	_sheet(Vector3(90.42, FL + 1.6, cal_z), PI * 0.5, Vector2(0.42, 0.55), Loc.t(&"corpus.calendar_title"), Loc.t(&"corpus.calendar_days"), tf)
	for d in 13:
		var col := d % 7
		var row := d / 7
		_label("×", Vector3(90.426, FL + 1.53 - row * 0.042, cal_z - 0.15 + col * 0.044), PI * 0.5, 34, UiStyle.plate_font(), Color(0.65, 0.1, 0.08, 0.9))
	var map_pos := Vector3(92.6, FL + 1.55, -25.83)
	_sheet(map_pos, 0.0, Vector2(1.2, 0.85), Loc.t(&"corpus.map_title"), "", null, Color(0.82, 0.84, 0.74))
	var rng := RandomNumberGenerator.new()
	rng.seed = 83
	_draw_district_map(map_pos)
	for k in 5:   # флажки-булавки
		_cyl(0.008, 0.02, map_pos + Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.3, 0.25), 0.012), _mat(Color(0.75, 0.08, 0.06), 0.3), Vector3(PI * 0.5, 0, 0))
	_label(Loc.t(&"corpus.map_note"), map_pos + Vector3(0.28, -0.32, 0.008), 0.0, 22, UiStyle.hand_font(), Color(0.65, 0.1, 0.08))
	# Коридор: плакат и доска приказов с бумагами (лицом на восток)
	_sheet(Vector3(94.9, FL + 1.6, -21.6), PI * 0.5, Vector2(0.6, 0.82), Loc.t(&"corpus.poster_title"), Loc.t(&"corpus.poster_body"), UiStyle.plate_font(false), Color(0.85, 0.78, 0.62))
	_sheet(Vector3(94.915, FL + 1.66, -29.85), PI * 0.5, Vector2(0.3, 0.36), Loc.t(&"corpus.order_title"), Loc.t(&"corpus.order_body"), tf)
	_sheet(Vector3(94.915, FL + 1.6, -29.35), PI * 0.5, Vector2(0.28, 0.3), Loc.t(&"corpus.sched_title"), Loc.t(&"corpus.sched_body"), tf)
	_sheet(Vector3(94.915, FL + 1.38, -29.65), PI * 0.5, Vector2(0.26, 0.16), "", "", null, Color(0.9, 0.88, 0.8))
	_label(Loc.t(&"corpus.board_note"), Vector3(94.92, FL + 1.38, -29.65), PI * 0.5, 26, UiStyle.hand_font(), Color(0.12, 0.18, 0.46))
	# Аппаратная: часы над пультом стоят на 03:10
	var clk := Vector3(91.7, FL + 2.25, -33.88)
	_cyl(0.16, 0.04, clk, _mat(Color(0.88, 0.86, 0.8)), Vector3(PI * 0.5, 0, 0))
	_cyl(0.17, 0.03, clk + Vector3(0, 0, -0.01), _mat(Color(0.1, 0.1, 0.1)), Vector3(PI * 0.5, 0, 0))
	for h in 12:
		var a := h * TAU / 12.0
		_box(Vector3(0.006, 0.02, 0.004), clk + Vector3(sin(a) * 0.13, cos(a) * 0.13, 0.021), _mat(Color(0.1, 0.1, 0.1)), Vector3(0, 0, -a))
	_box(Vector3(0.008, 0.08, 0.004), clk + Vector3(0.022, 0.03, 0.024), _mat(Color(0.05, 0.05, 0.05)), Vector3(0, 0, -deg_to_rad(95.0)))    # 3 ч
	_box(Vector3(0.006, 0.12, 0.004), clk + Vector3(0.03, -0.04, 0.026), _mat(Color(0.05, 0.05, 0.05)), Vector3(0, 0, -deg_to_rad(240.0)))   # 10 мин
	# Тамбур: «Не забывай про леер»
	_sheet(Vector3(91.0, FL + 1.75, -26.015), PI, Vector2(0.5, 0.3), Loc.t(&"corpus.leer_title"), Loc.t(&"corpus.leer_body"), UiStyle.plate_font(false), Color(0.85, 0.75, 0.5))


# --- Мелочи на столах ------------------------------------------------------------------------

func _build_clutter() -> void:
	var enamel := _mat(Color(0.85, 0.85, 0.8), 0.3)
	var rim := _mat(Color(0.15, 0.25, 0.5), 0.3)
	# Кабинет: кружка, пепельница с окурками, бумаги, очки
	var desk := Vector3(90.8, FL + 0.76, -24.2)
	_cyl(0.04, 0.09, desk + Vector3(0.15, 0.045, -0.55), enamel)
	_cyl(0.041, 0.008, desk + Vector3(0.15, 0.09, -0.55), rim)
	_cyl(0.06, 0.02, desk + Vector3(0.2, 0.01, 0.55), _mat(Color(0.3, 0.3, 0.32), 0.3))
	for k in 4:
		_cyl(0.005, 0.04, desk + Vector3(0.2 + (k - 1.5) * 0.015, 0.025, 0.55 + (k % 2) * 0.02), _mat(Color(0.85, 0.82, 0.75)), Vector3(0, 0, PI * 0.5 + k * 0.4))
	for k in 5:
		_box(Vector3(0.21, 0.002, 0.3), desk + Vector3(-0.1 + k * 0.01, 0.003 + k * 0.004, 0.15 + k * 0.012), _mat(Color(0.86, 0.84, 0.76)), Vector3(0, k * 0.12 - 0.2, 0))
	# Буржуйка: эмалированный чайник
	var st := MeteoCorpus.STOVE_POS
	_cyl(0.09, 0.14, st + Vector3(0.17, 0.8, 0.0), _mat(Color(0.25, 0.4, 0.55), 0.3))   # с краю плиты — посередине труба
	_box(Vector3(0.1, 0.02, 0.02), st + Vector3(0.17, 0.92, 0.0), _mat(Color(0.1, 0.1, 0.1)))
	# Кабинет: телогрейка на колышке у двери — вплотную к перегородке (её плоскость x = 94.73)
	_build_quilted_jacket(Vector3(94.66, FL, -21.0))
	# Кабина башни: бинокль и журнал шаров
	_cyl(0.025, 0.12, Vector3(95.08, CAB + 0.8, -36.6), _mat(Color(0.1, 0.1, 0.1), 0.4), Vector3(0, 0, PI * 0.5))
	_cyl(0.025, 0.12, Vector3(95.08, CAB + 0.8, -36.55), _mat(Color(0.1, 0.1, 0.1), 0.4), Vector3(0, 0, PI * 0.5))


## Карта района на листе (лицом на +z): сетка, река с притоком, озеро, горизонтали сопки, зимник
## пунктиром, станция, изба, ретранслятор, стрелка севера и масштаб. Раньше — случайные чёрточки.
func _draw_district_map(base: Vector3) -> void:
	var grid := _mat(Color(0.55, 0.62, 0.68))
	var water := _mat(Color(0.18, 0.32, 0.62))
	var relief := _mat(Color(0.55, 0.36, 0.2))
	var road := _mat(Color(0.35, 0.22, 0.12))
	var ink := _mat(Color(0.08, 0.08, 0.1))
	var forest := _mat(Color(0.22, 0.42, 0.24))
	for k in 7:
		_map_seg(base, Vector2(-0.54 + k * 0.18, -0.38), Vector2(-0.54 + k * 0.18, 0.3), 0.0025, grid)
	for k in 4:
		_map_seg(base, Vector2(-0.56, -0.34 + k * 0.2), Vector2(0.56, -0.34 + k * 0.2), 0.0025, grid)
	_map_line(base, [Vector2(-0.57, -0.02), Vector2(-0.4, -0.06), Vector2(-0.24, -0.16), Vector2(-0.05, -0.13), Vector2(0.12, -0.2), Vector2(0.3, -0.17), Vector2(0.45, -0.27), Vector2(0.57, -0.3)], 0.011, water)
	_map_line(base, [Vector2(-0.05, -0.13), Vector2(0.0, 0.0), Vector2(-0.06, 0.12), Vector2(-0.02, 0.26)], 0.006, water)
	_cyl(0.05, 0.002, base + Vector3(-0.33, 0.13, 0.007), water, Vector3(PI * 0.5, 0, 0)).scale = Vector3(1.6, 1.0, 1.0)
	for r: float in [0.05, 0.09, 0.13]:
		var pts: Array = []
		for i in 13:
			var a2 := i * TAU / 12.0
			pts.append(Vector2(0.3 + cos(a2) * r * 1.3, 0.1 + sin(a2) * r))
		_map_line(base, pts, 0.003, relief)
	var zim := [Vector2(-0.56, -0.35), Vector2(-0.38, -0.27), Vector2(-0.2, -0.3), Vector2(0.02, -0.24), Vector2(0.1, -0.05)]
	for i in zim.size() - 1:
		var a3: Vector2 = zim[i]
		var b3: Vector2 = zim[i + 1]
		for d in 4:      # пунктир
			_map_seg(base, a3.lerp(b3, d / 4.0), a3.lerp(b3, d / 4.0 + 0.14), 0.006, road)
	_box(Vector3(0.03, 0.03, 0.003), base + Vector3(0.1, -0.05, 0.008), _mat(Color(0.75, 0.08, 0.06)))   # станция
	_box(Vector3(0.016, 0.016, 0.003), base + Vector3(-0.2, 0.05, 0.008), ink)                            # изба
	_box(Vector3(0.016, 0.016, 0.003), base + Vector3(0.36, 0.22, 0.008), ink)                            # ретранслятор на сопке
	_map_seg(base, Vector2(0.36, 0.215), Vector2(0.36, 0.26), 0.003, ink)
	_label("Кедр-7", base + Vector3(0.1, -0.09, 0.009), 0.0, 18, UiStyle.hand_font(), Color(0.65, 0.1, 0.08))
	_label("изба", base + Vector3(-0.2, 0.02, 0.009), 0.0, 14, UiStyle.hand_font(), Color(0.12, 0.12, 0.14))
	_label("РТР", base + Vector3(0.36, 0.29, 0.009), 0.0, 14, UiStyle.hand_font(), Color(0.12, 0.12, 0.14))
	var frng := RandomNumberGenerator.new()
	frng.seed = 7
	for k in 40:     # значки леса
		var fp := Vector2(frng.randf_range(-0.55, 0.55), frng.randf_range(-0.36, 0.28))
		if fp.distance_to(Vector2(0.3, 0.1)) < 0.2 or fp.distance_to(Vector2(-0.33, 0.13)) < 0.1:
			continue
		_map_seg(base, fp, fp + Vector2(-0.008, -0.014), 0.003, forest)
		_map_seg(base, fp, fp + Vector2(0.008, -0.014), 0.003, forest)
	_map_seg(base, Vector2(0.52, 0.12), Vector2(0.52, 0.24), 0.004, ink)       # север
	_map_seg(base, Vector2(0.52, 0.24), Vector2(0.505, 0.21), 0.004, ink)
	_map_seg(base, Vector2(0.52, 0.24), Vector2(0.535, 0.21), 0.004, ink)
	_label("С", base + Vector3(0.52, 0.27, 0.009), 0.0, 16, UiStyle.plate_font(), Color(0.08, 0.08, 0.1))
	_map_seg(base, Vector2(-0.54, -0.39), Vector2(-0.34, -0.39), 0.005, ink)   # масштабная линейка
	for k in 3:
		_map_seg(base, Vector2(-0.54 + k * 0.1, -0.385), Vector2(-0.54 + k * 0.1, -0.4), 0.003, ink)


func _map_seg(base: Vector3, a: Vector2, b: Vector2, w: float, mat: Material) -> void:
	var d := b - a
	var mid := (a + b) * 0.5
	_box(Vector3(d.length() + w * 0.5, w, 0.002), base + Vector3(mid.x, mid.y, 0.007), mat, Vector3(0, 0, atan2(d.y, d.x)))


func _map_line(base: Vector3, pts: Array, w: float, mat: Material) -> void:
	for i in pts.size() - 1:
		_map_seg(base, pts[i], pts[i + 1], w, mat)


## Телогрейка на колышке, лицом на запад: плечи, полы, рукава вдоль, стёжка поперёк, пуговицы.
func _build_quilted_jacket(at: Vector3) -> void:
	var cloth := _mat(Color(0.2, 0.22, 0.16))
	var seam := _mat(Color(0.12, 0.13, 0.09))
	_box(Vector3(0.1, 0.025, 0.025), at + Vector3(0.03, 1.84, 0.0), _mat(Color(0.3, 0.22, 0.14)))         # колышек
	_box(Vector3(0.11, 0.1, 0.36), at + Vector3(0.0, 1.76, 0.0), cloth, Vector3(0, 0, 0))                  # плечи у колышка
	_box(Vector3(0.13, 0.66, 0.5), at + Vector3(-0.005, 1.38, 0.0), cloth)                                 # спина и полы
	_box(Vector3(0.12, 0.12, 0.46), at + Vector3(-0.005, 1.0, 0.0), cloth, Vector3(0.0, 0.0, 0.04))        # подол, чуть отвисший
	for sgn: float in [-1.0, 1.0]:
		_box(Vector3(0.1, 0.62, 0.12), at + Vector3(-0.01, 1.4, sgn * 0.3), cloth, Vector3(sgn * 0.07, 0, 0))   # рукава
		_box(Vector3(0.105, 0.06, 0.125), at + Vector3(-0.012, 1.1, sgn * 0.32), seam, Vector3(sgn * 0.07, 0, 0))   # манжеты
	for k in 7:   # стёжка поперёк
		_box(Vector3(0.004, 0.006, 0.5), at + Vector3(-0.072, 1.08 + k * 0.1, 0.0), seam)
	_box(Vector3(0.004, 0.68, 0.006), at + Vector3(-0.073, 1.38, 0.02), seam)   # борт
	for k in 4:
		_cyl(0.014, 0.008, at + Vector3(-0.075, 1.2 + k * 0.14, -0.02), _mat(Color(0.08, 0.08, 0.08), 0.4), Vector3(0, 0, PI * 0.5))


## Пыль в лучах ламп аппаратной и коридора — когда есть свет.
func _build_dust() -> void:
	_dust = CPUParticles3D.new()
	_dust.amount = 70
	_dust.lifetime = 9.0
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(2.5, 1.3, 4.5)
	_dust.position = Vector3(93.0, FL + 1.6, -30.5)
	_dust.direction = Vector3(0.2, 0.3, 0.1)
	_dust.spread = 180.0
	_dust.initial_velocity_min = 0.01
	_dust.initial_velocity_max = 0.04
	_dust.gravity = Vector3(0, -0.005, 0)
	_dust.scale_amount_min = 0.6
	_dust.scale_amount_max = 1.2
	var qm := QuadMesh.new()
	qm.size = Vector2(0.006, 0.006)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.95, 0.9, 0.8, 0.5)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.material = dm
	_dust.mesh = qm
	add_child(_dust)


var _far_t := 0.0


func _process(delta: float) -> void:
	_t += delta
	# Пульт, самописцы, лампы — внутри корпуса: игрок дальше 45 м их не видит — раз в полсекунды
	if Game.player != null and Game.zone != &"corpus" and Game.player.global_position.distance_to(Yard.CORPUS_PORCH) > 45.0:
		_far_t -= delta
		if _far_t > 0.0:
			return
		_far_t = 0.5
	var c := MeteoCorpus.instance
	var on := c != null and c.powered
	_dust.emitting = on
	# Стрелки пульта: живут, пока есть ток и чашки не обледенели
	var sy = Game.synoptic
	var target := 0.0
	var az := 0.0
	if on and not Game.anemo_iced and sy != null:
		target = sy.wind_speed + (sy.wind_gusts - sy.wind_speed) * 0.4 * (sin(_t * 0.9) * 0.5 + 0.5)
		az = sy.wind_azimuth_deg + sin(_t * 0.7) * 6.0
	_speed = lerpf(_speed, target, clampf(delta * 3.0, 0.0, 1.0))
	var shown := _speed
	if _drive_t > 0.0:
		_drive_t -= delta
		shown = _drive.x
		az = _drive.z
		_gust_pivot.rotation.z = _speed_angle(_drive.y)
	if _needles.size() == 2:
		_needles[0].rotation.z = _speed_angle(shown)
		_needles[1].rotation.z = -deg_to_rad(az)
	_lamp_net.visible = on
	_lamp_ice.visible = on and Game.anemo_iced and fmod(_t, 1.0) < 0.5
	# Перья самописцев чуть дрожат
	for i in _pens.size():
		_pens[i].rotation.y = sin(_t * (0.3 + i * 0.13)) * 0.04
