class_name Atmosphere
extends Node3D
## Воздух ночи: позёмка у земли, видимый луч фонаря в снегу, лучи из окон, ореолы ламп, следы игрока,
## которые заметает метель. Плотность «воздуха» (снег, туман, метель) — одна величина для всех эффектов.

const MAX_PRINTS := 320
const STEP_DIST := 0.62

static var _glare: ImageTexture
static var _beam_shader: Shader
static var _shaft_mat: ShaderMaterial    ## общий для всех лучей из окон

var density := 0.0                      ## 0 — ясно и в доме, 1 — метель
var _drift: CPUParticles3D
var _veil: CPUParticles3D
var _ribbons: CPUParticles3D        ## быстрые стелющиеся ленты позёмки над настом
var _dust: CPUParticles3D           ## пыль в доме — видна только в луче фонаря и у ламп
var _ridge: CPUParticles3D          ## в метель с конька крыши срывает снежные струи
var _spark: CPUParticles3D          ## «алмазная пыль»: в ясный мороз ледяные искры блестят только в луче фонаря
var _prints: MultiMeshInstance3D
var _print_alpha: PackedFloat32Array = []
var _print_next := 0
var _last_step := Vector3.INF
var _left := false


func _ready() -> void:
	_build_drift()
	_build_dust()
	_build_ridge()
	_build_fall()
	_build_prints()
	_build_trodden()
	# Луч фонаря от первого лица делаем не конусом (изнутри он виден как пузырь), а светом на снежинках:
	# частицы освещаемые — в луче и у ламп снег вспыхивает, в темноте гаснет.


# --- Позёмка ------------------------------------------------------------------

func _build_drift() -> void:
	# Мелкая снежная пыль, которую ветер несёт над самым настом
	_drift = _ground_emitter(int(520 * Settings.detail()), Vector2(0.05, 0.05), Color(0.85, 0.9, 0.97, 0.5), 0.1, 2.2)
	# Быстрые позёмные ленты-струи, стелющиеся над самым настом
	_ribbons = _ground_emitter(int(140 * Settings.detail()), Vector2(0.38, 0.032), Color(0.88, 0.92, 0.98, 0.55), 0.06, 1.8)
	_ribbons.initial_velocity_min = 4.2
	_ribbons.initial_velocity_max = 7.5
	_ribbons.spread = 7.0
	_ribbons.scale_amount_min = 0.8
	_ribbons.scale_amount_max = 1.6
	# И полупрозрачная пелена — рваные клубы позёмки по колено
	_veil = _ground_emitter(int(46 * Settings.detail()), Vector2(1.6, 0.7), Color(0.75, 0.82, 0.92, 0.07), 0.35, 3.4)
	_veil.scale_amount_min = 0.7
	_veil.scale_amount_max = 1.8
	# Клубы пелены большие: у камеры проявляются только издалека, иначе висят белым диском перед лицом.
	var vm := ((_veil.mesh as QuadMesh).material as StandardMaterial3D)
	vm.distance_fade_min_distance = 3.5
	vm.distance_fade_max_distance = 7.0


func _ground_emitter(amount: int, size: Vector2, col: Color, height: float, life: float) -> CPUParticles3D:
	var e := CPUParticles3D.new()
	e.amount = maxi(amount, 8)
	e.lifetime = life
	e.preprocess = life
	e.local_coords = false
	e.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	e.emission_box_extents = Vector3(13.0, height, 13.0)
	e.direction = Vector3(1.0, 0.04, 0.3)
	e.spread = 10.0
	e.initial_velocity_min = 2.0
	e.initial_velocity_max = 4.5
	e.gravity = Vector3(0.6, -0.03, 0.1)
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = size
	var mat := drift_material(col)
	quad.material = mat
	e.mesh = quad
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.25, Color(1, 1, 1, 1))
	ramp.add_point(0.75, Color(1, 1, 1, 1))
	e.color_ramp = ramp
	add_child(e)
	return e


## Материал позёмки: освещаемый (вспыхивает в луче фонаря и у ламп) и чуть светится сам.
static func drift_material(col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = glare_texture()
	mat.albedo_color = col
	mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = true                  # в метель позёмку видно и без фонаря
	mat.emission = Color(0.16, 0.19, 0.25)
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA   # у самой камеры не лепится белым пятном
	mat.distance_fade_min_distance = 1.0
	mat.distance_fade_max_distance = 2.6
	return mat


## Для прогрева шейдеров под карточкой загрузки: горстка частиц позёмки.
static func prewarm_node() -> Node3D:
	var e := CPUParticles3D.new()
	e.amount = 16
	e.lifetime = 1.0
	e.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	e.emission_box_extents = Vector3(0.4, 0.3, 0.4)
	e.gravity = Vector3.ZERO
	var quad := QuadMesh.new()
	quad.size = Vector2(0.2, 0.2)
	quad.material = drift_material(Color(0.85, 0.9, 0.97, 0.5))
	e.mesh = quad
	return e


# --- Пыль и снег с крыши ----------------------------------------------------------

func _build_dust() -> void:
	_dust = CPUParticles3D.new()
	_dust.amount = int(140 * Settings.detail())
	_dust.lifetime = 9.0
	_dust.preprocess = 9.0
	_dust.local_coords = false
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(3.0, 1.2, 3.0)
	_dust.direction = Vector3(0.3, 0.2, 0.1)
	_dust.spread = 180.0
	_dust.initial_velocity_min = 0.01
	_dust.initial_velocity_max = 0.06
	_dust.gravity = Vector3(0, -0.004, 0)
	_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.012)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX   # в темноте не видна, в луче вспыхивает
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = glare_texture()
	m.albedo_color = Color(1.0, 0.95, 0.85, 0.35)
	m.vertex_color_use_as_albedo = true
	m.emission_enabled = true          # тот же вариант шейдера, что у позёмки (прогрет заранее)
	m.emission = Color(0.0, 0.0, 0.0)
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 1.1
	m.distance_fade_max_distance = 2.2
	q.material = m
	_dust.mesh = q
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.3, Color(1, 1, 1, 1))
	ramp.add_point(0.7, Color(1, 1, 1, 1))
	_dust.color_ramp = ramp
	add_child(_dust)


## Ледяные искры в ясный мороз («алмазная пыль»): светятся только в луче фонаря.
## (Падающий снег — у игрока, Player.make_snow: он тоже освещаемый и почти не светится сам.)
func _build_fall() -> void:
	_spark = CPUParticles3D.new()
	_spark.amount = int(220 * Settings.detail())
	_spark.lifetime = 5.0
	_spark.preprocess = 5.0
	_spark.local_coords = false
	_spark.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_spark.emission_box_extents = Vector3(2.6, 1.3, 2.6)
	_spark.direction = Vector3(0.2, -0.1, 0.1)
	_spark.spread = 180.0
	_spark.initial_velocity_min = 0.02
	_spark.initial_velocity_max = 0.12
	_spark.gravity = Vector3(0.03, -0.02, 0.0)
	_spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sq := QuadMesh.new()
	sq.size = Vector2(0.014, 0.014)
	var sm := drift_material(Color(1.0, 1.0, 1.0, 1.0))
	sm.emission = Color(0, 0, 0)
	sm.distance_fade_min_distance = 0.6
	sm.distance_fade_max_distance = 1.4
	sq.material = sm
	_spark.mesh = sq
	var ramp := Gradient.new()   # мерцание: искра вспыхивает и гаснет
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	for k in range(6):
		ramp.add_point(0.1 + k * 0.15, Color(1, 1, 1, 1.0 if k % 2 == 0 else 0.15))
	_spark.color_ramp = ramp
	add_child(_spark)


func _build_ridge() -> void:
	# Конёк дома: x −2.6…14.6 на z = 3.3; ветер с запада несёт снег струями на восток и вниз по скату.
	_ridge = CPUParticles3D.new()
	_ridge.amount = int(90 * Settings.detail())
	_ridge.lifetime = 2.6
	_ridge.local_coords = false
	_ridge.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_ridge.emission_box_extents = Vector3(8.6, 0.05, 0.25)
	_ridge.position = Vector3(6.0, 5.65, 3.3)
	_ridge.direction = Vector3(1.0, 0.25, 0.6)
	_ridge.spread = 18.0
	_ridge.initial_velocity_min = 2.0
	_ridge.initial_velocity_max = 4.0
	_ridge.gravity = Vector3(0.8, -1.2, 0.3)
	_ridge.scale_amount_min = 0.6
	_ridge.scale_amount_max = 1.8
	_ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var q := QuadMesh.new()
	q.size = Vector2(0.35, 0.35)
	q.material = drift_material(Color(0.85, 0.9, 0.97, 0.22))
	_ridge.mesh = q
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.2, Color(1, 1, 1, 1))
	_ridge.color_ramp = ramp
	_ridge.emitting = false
	add_child(_ridge)


# --- Лучи (окна) ---------------------------------------------------------------

## Аддитивный луч, мягкий к краям (по углу к взгляду) и к концу. Виден в снегу и тумане.
static func beam_material(col: Color) -> ShaderMaterial:
	if _beam_shader == null:
		_beam_shader = Shader.new()
		_beam_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.9, 0.75, 1.0);
uniform float strength = 0.05;
varying float along;
void vertex() { along = UV.y; }
void fragment() {
	float edge = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.6);
	float fade = (1.0 - along) * (1.0 - along);
	ALBEDO = color.rgb * strength * edge * fade;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _beam_shader
	m.set_shader_parameter("color", col)
	return m


## Луч из окна наружу: усечённая пирамида, тёплая. Ребёнок лампы окна — гаснет вместе со светом.
static func add_window_shaft(light: Node3D, glass_pos: Vector3, size: Vector3, outward: Vector3) -> void:
	if _shaft_mat == null:
		_shaft_mat = beam_material(Color(1.0, 0.62, 0.3))
	var w := maxf(size.x, size.z)
	var shaft := CylinderMesh.new()
	shaft.radial_segments = 4
	shaft.rings = 1
	shaft.cap_top = false
	shaft.cap_bottom = false
	shaft.height = 3.2
	shaft.top_radius = w * 0.62
	shaft.bottom_radius = w * 1.25
	var mi := MeshInstance3D.new()
	mi.mesh = shaft
	mi.material_override = _shaft_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	light.add_child(mi)
	mi.global_position = glass_pos + outward * 1.6 + Vector3(0, -0.35, 0)
	# ось Y цилиндра → наружу и чуть вниз (свет падает на снег)
	var axis := (outward + Vector3(0, -0.22, 0)).normalized()
	mi.global_basis = Basis(Quaternion(Vector3.DOWN, axis)) * Basis(Vector3.UP, PI * 0.25)


## Ореол лампы в морозном воздухе: мягкий биллборд, гаснет вместе со светом.
static var _halo_shader: Shader


static func add_halo(light: Node3D, size := 1.4, col := Color(1.0, 0.7, 0.4, 0.55)) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	if _halo_shader == null:
		_halo_shader = load("res://assets/shaders/halo.gdshader") as Shader
	var m := ShaderMaterial.new()
	m.shader = _halo_shader
	m.set_shader_parameter(&"col", col)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = size      # биллборд крутится — не отсекать по исходной рамке квада
	light.add_child(mi)
	return mi


static func glare_texture() -> ImageTexture:
	if _glare != null:
		return _glare
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x - n / 2.0 + 0.5, y - n / 2.0 + 0.5).length() / (n / 2.0)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_glare = ImageTexture.create_from_image(img)
	return _glare


# --- Следы игрока ---------------------------------------------------------------

func _build_prints() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = PlaneMesh.new()
	(mm.mesh as PlaneMesh).size = Vector2(0.15, 0.32)
	mm.instance_count = MAX_PRINTS
	mm.visible_instance_count = 0
	var mat := Footprints.material(&"snow").duplicate() as StandardMaterial3D
	mat.vertex_color_use_as_albedo = true       # прозрачность каждого следа — в цвете экземпляра
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.albedo_color = Color(0.32, 0.4, 0.55, 1.0)
	_prints = MultiMeshInstance3D.new()
	_prints.multimesh = mm
	_prints.material_override = mat
	_prints.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_prints)
	_print_alpha.resize(MAX_PRINTS)


func _step_print(p: Player) -> void:
	var pos := p.global_position
	if _last_step != Vector3.INF and pos.distance_to(_last_step) < STEP_DIST:
		return
	var dir := Vector3.FORWARD if _last_step == Vector3.INF else (pos - _last_step)
	dir.y = 0.0
	_last_step = pos
	if dir.length_squared() < 0.0001:
		return
	dir = dir.normalized()
	var side := Vector3(-dir.z, 0, dir.x) * (0.11 if _left else -0.11)
	var t := Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)), Vector3(pos.x, pos.y + 0.012, pos.z) + side)
	if _left:
		t.basis = t.basis.scaled(Vector3(-1, 1, 1))
	_left = not _left
	var mm := _prints.multimesh
	mm.set_instance_transform(_print_next, t)
	_print_alpha[_print_next] = 0.62
	mm.set_instance_color(_print_next, Color(1, 1, 1, 0.62))
	_print_next = (_print_next + 1) % MAX_PRINTS
	mm.visible_instance_count = mini(mm.visible_instance_count + 1, MAX_PRINTS)


func _fade_prints(delta: float) -> void:
	# Метель заметает за минуту-две; в ясную ночь следы держатся почти всю смену.
	var rate := delta * (0.0006 + density * 0.012)
	var mm := _prints.multimesh
	for i in mm.visible_instance_count:
		var a := _print_alpha[i]
		if a <= 0.0:
			continue
		a = maxf(a - rate, 0.0)
		_print_alpha[i] = a
		mm.set_instance_color(i, Color(1, 1, 1, a))


# --- Тропы: отключены наклейки-прямоугольники --------------------------------
# Наклейки MultiMesh PlaneMesh создавали визуальные артефакты «синих плиток/коробок» на снегу.
# Игрок ходит по деревянным настилам, а следы валенок рисуются через PlayerFootprints.

const TREAD_CELL := 0.7
const TREAD_MAX := 1400
var _trodden: MultiMeshInstance3D
var _tread_last := Vector2i(1 << 20, 0)
var _trodden_t := 0.0
var _trodden_dirty := false


func _build_trodden() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = 1
	mm.visible_instance_count = 0
	_trodden = MultiMeshInstance3D.new()
	_trodden.multimesh = mm
	_trodden.visible = false
	add_child(_trodden)


func _tread(_pos: Vector3) -> void:
	pass


func _settle_trodden(_dt: float, _storm: float) -> void:
	pass


# --- Кадр ------------------------------------------------------------------------

var _fade_t := 0.0


func _process(delta: float) -> void:
	var p := Game.player
	if p == null:
		return
	var outside := Game.is_outside()
	var storm := Game.weather.intensity if Game.weather != null else 0.0
	var target := (0.35 + storm * 0.65) if outside else 0.0
	density = lerpf(density, target, minf(delta * 1.5, 1.0))
	# Позёмка — у ног игрока, гуще и быстрее в метель
	var ground_y: float = p.global_position.y
	for e: CPUParticles3D in [_drift, _veil, _ribbons]:
		if e == null:
			continue
		e.visible = outside
		var off_y := 0.05 if e == _ribbons else (0.10 if e == _drift else 0.32)
		e.global_position = Vector3(p.global_position.x, ground_y + off_y, p.global_position.z)
		e.speed_scale = 0.7 + storm * 1.8
	if _drift != null and _drift.mesh != null and _drift.mesh.material != null:
		(_drift.mesh.material as StandardMaterial3D).albedo_color.a = 0.25 + storm * 0.45
	if _ribbons != null and _ribbons.mesh != null and _ribbons.mesh.material != null:
		(_ribbons.mesh.material as StandardMaterial3D).albedo_color.a = 0.32 + storm * 0.48
	_dust.visible = not outside
	# Алмазная пыль — ясная ночь, мороз, перед глазами (горит только в луче фонаря)
	var sparkle := outside and storm < 0.25 and Game.is_night()
	_spark.visible = sparkle
	if sparkle and p.camera != null:
		_spark.global_position = p.camera.global_position - p.camera.global_basis.z * 3.0
	if not outside:
		_dust.global_position = p.global_position + Vector3(0, 1.4, 0)
	var ridge_on := storm > 0.3 and Game.level is Station
	if _ridge.emitting != ridge_on:
		_ridge.emitting = ridge_on
	_ridge.speed_scale = 0.6 + storm
	(_veil.mesh.material as StandardMaterial3D).albedo_color.a = 0.035 + storm * 0.16
	# Лучи из окон: в ясную ночь едва заметны, в снегу — плотные
	if _shaft_mat != null:
		_shaft_mat.set_shader_parameter("strength", 0.01 + density * 0.035)
	# Следы: только на снегу во дворе, не в доме и не в сарае
	if outside and p.is_on_floor():
		_step_print(p)
		_tread(p.global_position)
	_trodden_t += delta
	if _trodden_t > 3.0:
		_settle_trodden(_trodden_t, storm)
		_trodden_t = 0.0
	_fade_t += delta
	if _fade_t > 0.5:
		_fade_prints(_fade_t)
		_fade_t = 0.0
