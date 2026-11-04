class_name MeteoCorpus
extends Node3D
## Аэрологический корпус УГМС с башней и хозяйство вокруг (tools/blender/corpus.py, corpus_yard.py).
## Г-образный кирпичный корпус: тамбур, коридор, аппаратная, кабинет наблюдателя, радиорубка, архив,
## кладовая, газогенераторная, башня с маршами и застеклённой кабиной. Свой дизель в пристройке:
## пока не заведёшь — корпус тёмный. Рядом ангар для шаров, навес с баллонами, радиомачта.
## Модели стоят сразу на своих местах (origin «keep»); коллизии — из scripts/data/corpus_col_*.gd.

const COL_MAIN := preload("res://scripts/data/corpus_col_ext.gd")
const COL_YARD := preload("res://scripts/data/corpus_col_yard.gd")
const COL_FURN := preload("res://scripts/data/corpus_col_furn.gd")
const RING_SOUND := "res://assets/audio/buzzer_loop.ogg"
const CABIN_FIGURE := Vector3(96.75, CAB, -35.35)    ## где стоит фигура в окне кабины (у южного стекла)
const LAYER_OUT := Station.LAYER_OUT
const LAYER_IN := Station.LAYER_IN

## Габариты (как в corpus.py)
const FL := 0.45
const CAB := 9.75
const DOOR := Vector3(90.0, FL, -27.25)          ## входная дверь (западный фасад)
const PORCH := Vector3(88.4, 0.0, -27.25)        ## у крыльца — сюда приходит леер
const GEN_DOOR := Vector3(100.55, 0.15, -30.5)   ## дверь дизельной пристройки (юг)
const GEN_POS := Vector3(100.4, 0.15, -32.6)     ## дизель-генератор
const STOVE_POS := Vector3(91.2, FL, -21.3)      ## буржуйка в кабинете наблюдателя
const PULT_POS := Vector3(91.7, FL, -33.75)      ## пульт анеморумбометра у северной стены аппаратной
const BARO_POS := Vector3(94.3, FL, -30.0)       ## стол с барографом и термографом у перегородки
const JOURNAL_POS := Vector3(91.0, FL + 0.8, -24.2)   ## журнал на столе у окна кабинета
const PHONE_POS := Vector3(94.6, FL + 1.4, -24.6)
const LADDER_TOWER := Vector3(97.8, 0.0, -39.4)  ## скоба-лестница на башню (север), вверху — балкон
const LADDER_ROOF := Vector3(98.2, 0.0, -19.6)   ## лестница на кровлю (юг)
const ROOF_Y := 3.8
const HANGAR_GATE_X := 128.0
const HANGAR_ZC := -36.0
const WICKET := Vector3(116.0, 0.1, -34.35)

static var instance: MeteoCorpus

var powered := false               ## дизель работает — свет в корпусе
var stove_lit := false
var _stove_t := 0.0
var _gen_tries := 0
var _stall_t := 0.0
var _engine: AudioStreamPlayer3D
var _engine_in: AudioStreamPlayer        ## гул дизеля сквозь стены — внутри корпуса (3D-звук стены глушат почти в ноль)
var _stove_audio: AudioStreamPlayer3D
var _lamps: Array[Light3D] = []
var _glows: Array[Node3D] = []
var _stove_light: OmniLight3D
var _gates_open := false
var _gate_leaves: Array[Node3D] = []
var _gate_col: CollisionShape3D
# Испуги корпуса — по разу за ночь
var _ring: AudioStreamPlayer3D
var _ring_t := 0.0
var _next_ring := 0.0
var _rang := 0
var _roof_t := -1.0
var _knock_t := -1.0
var _knock_open_until := 0.0
var _figure: Node3D
var _figure_t := 0.0
var _done := {}
var _baro_odd := false


func _ready() -> void:
	instance = self
	# Без тени от луны: на дальних белых стенах её грубый каскад штриховал корпус диагональными полосами
	var ext := Models.spawn(self, "kedr/corpus_ext", Vector3(0, 0.0, 0), 0.0, -1.0, {"keep": true, "center": false, "grime": 0.0, "bright": 1.0, "sat": 1.0, "shadow": false})
	var inn := Models.spawn(self, "kedr/corpus_int", Vector3.ZERO, 0.0, -1.0, {"keep": true, "center": false, "grime": 0.0, "bright": 1.6, "sat": 1.0})
	var yard := Models.spawn(self, "kedr/corpus_yard", Vector3(0, -0.008, 0), 0.0, -1.0, {"center": false, "grime": 0.0, "bright": 1.0, "sat": 1.0})
	var furn := Models.spawn(self, "kedr/corpus_furn", Vector3.ZERO, 0.0, -1.0, {"keep": true, "center": false, "grime": 0.0, "bright": 1.6, "sat": 1.0})
	_set_layers(ext, LAYER_OUT)
	_set_layers(inn, LAYER_IN)
	_set_layers(furn, LAYER_IN)
	_build_collision(COL_FURN.BOXES)
	_set_layers(yard, LAYER_OUT)
	_build_collision(COL_MAIN.BOXES)
	_build_collision(COL_YARD.BOXES)
	_build_doors()
	_build_hangar_gates()
	_build_generator()
	_build_lights()
	_build_ladders()
	_build_stove()
	_build_things()
	_build_tower_glass()
	_seal_walls_and_fix_geometry()
	_build_balcony_wind()
	add_child(CorpusDressing.new())   # пульт со шкалами, самописцы под стеклом, плакаты, мелочи
	_set_power(false)
	_next_ring = randf_range(90.0, 200.0)
	_roof_t = randf_range(70.0, 200.0)
	_knock_t = randf_range(150.0, 320.0)


func _seal_walls_and_fix_geometry() -> void:
	# 1. Сплошная южная стена шахты башни над лестницей (от верха коридора y = 3.45 до пола кабины CAB = 9.75):
	# В 3D-модели отсутствовала внутренняя плоскость выше 3.45 м — при подъёме открывалась открытая пустота.
	var wall_mat := Palette.m(&"white")
	var south_wall := Geo.block(self, Vector3(4.35, 6.35, 0.35), Vector3(96.75, 6.6, -34.6), wall_mat, true)
	if south_wall != null:
		_set_layers(south_wall, LAYER_IN | LAYER_OUT)

	# 2. Потолочное перекрытие стыка крыла корпуса и шахты башни на y = 3.6:
	var ceil_mat := Palette.m(&"ceiling")
	var ceil_cap := Geo.block(self, Vector3(4.35, 0.25, 1.2), Vector3(96.75, 3.65, -34.3), ceil_mat, true)
	if ceil_cap != null:
		_set_layers(ceil_cap, LAYER_IN | LAYER_OUT)


func _set_layers(root: Node, layer: int) -> void:
	if root == null:
		return
	for g: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
		g.layers = layer


func _build_collision(boxes: Array) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Geo.LAYER_WORLD
	body.collision_mask = 0
	add_child(body)
	for b: Array in boxes:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(b[3], b[4], b[5])
		cs.shape = sh
		cs.position = Vector3(b[0], b[1], b[2])
		# Godot: R = Ry·Rx (наклон марша — вокруг X, затем поворот вокруг вертикали)
		cs.basis = Basis.from_euler(Vector3(float(b[7]), float(b[6]), 0.0), EULER_ORDER_YXZ)
		body.add_child(cs)


# --- Зоны --------------------------------------------------------------------------------

## Зона по точке: внутри корпуса/башни, в дизельной, в ангаре; иначе «».
static func zone_at(p: Vector3) -> StringName:
	if p.x > 90.3 and p.x < 98.7 and p.z > -34.2 and p.z < -20.3 and p.y < 4.0:
		return &"corpus"
	if p.x > 94.6 and p.x < 98.9 and p.z > -38.98 and p.z < -34.4 and p.y < 12.5:
		return &"corpus"
	if p.x > 99.3 and p.x < 104.7 and p.z > -38.7 and p.z < -33.8 and p.y < 4.0:
		return &"corpus"
	if p.x > 98.9 and p.x < 102.1 and p.z > -33.6 and p.z < -30.8 and p.y < 3.0:
		return &"corpus_gen"
	if p.x > 116.1 and p.x < 127.9 and p.z > -39.9 and p.z < -32.1 and p.y < 6.0:
		return &"hangar"
	return &""


func is_dark() -> bool:
	return not powered


# --- Двери ------------------------------------------------------------------------------

func _build_doors() -> void:
	# Входная: обитая тёмно-зелёная, открывается внутрь (в тамбур)
	_door(Vector3(DOOR.x + 0.05, FL, -27.75), 0.0, 1.0, 2.1, 95.0, &"it.corpus_door")
	# Дизельная: в южной стене пристройки, наружу
	_door(Vector3(100.1, 0.15, -30.5), PI * 0.5, 0.9, 2.0, -100.0, &"it.gen_door")
	# Калитка в западном фронтоне ангара
	_door(Vector3(116.0, 0.1, -34.8), 0.0, 0.9, 2.0, 100.0, &"it.hangar_wicket")
	# Балконная дверь на башне: застеклённая советская дверь, распахивается наружу на балкон
	_build_balcony_door()
	# Ворота газогенераторной заперты изнутри: снаружи — коллизия и табличка
	var lock := Geo.interactable(self, Vector3(0.2, 2.3, 1.2), Vector3(105.08, FL + 1.15, -36.25), null, Loc.t(&"it.corpus_gas_locked"), func(_p: Player) -> void:
		Game.audio.play_3d("res://assets/sfx/door_handle.ogg", Vector3(105.1, FL + 1.1, -36.25), -6.0)
		Game.hud.subtitle(Loc.t(&"sub.corpus_gas_locked"), 3.0))
	lock.name = "GasGenGate"


## Дверь на петле: hinge — ось петли, yaw0 — поворот закрытой двери (полотно по +Z от петли при 0),
## open_deg — угол открывания. Полотно — простая доска с ручкой (вид как у павильона).
func _door(hinge: Vector3, yaw0: float, w: float, h: float, open_deg: float, prompt_key: StringName) -> void:
	var pivot := Node3D.new()
	pivot.position = hinge
	pivot.rotation.y = yaw0
	add_child(pivot)
	var d := Interactable.new()
	d.collision_layer = Geo.LAYER_WORLD
	d.position = Vector3(0, h / 2, w / 2)
	var k := MeshKit.new(29)
	k.mottle = 0.1
	var board := Color(0.17, 0.26, 0.19)
	k.box(Vector3.ZERO, Vector3(0.05, h - 0.02, w - 0.02), board)
	for ry: float in [-0.35, 0.35]:
		k.box(Vector3(-0.03, ry * h, 0), Vector3(0.02, 0.1, w - 0.1), board.darkened(0.25))
	k.box(Vector3(0.05, 0.0, w * 0.38), Vector3(0.04, 0.16, 0.04), Color(0.1, 0.1, 0.1))
	k.box(Vector3(-0.05, 0.0, w * 0.38), Vector3(0.04, 0.16, 0.04), Color(0.1, 0.1, 0.1))
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	mi.material_override = Creatures._mat(&"prop_corpus_door", Color.WHITE, "tex_wood.png", 0.0)
	d.add_child(mi)
	d.add_child(Geo.box_shape(Vector3(0.06, h, w)))
	var state := {"open": false, "busy": false}
	d.prompt_provider = func() -> String: return Loc.t(&"it.door_close") if state["open"] else Loc.t(prompt_key)
	d.used.connect(func(_p: Player) -> void:
		if state["busy"]:
			return
		state["busy"] = true
		state["open"] = not state["open"]
		Game.audio.play_3d("res://assets/audio/door.ogg", pivot.global_position + Vector3(0, 1.0, 0), -6.0)
		var tw := create_tween()
		tw.tween_property(pivot, "rotation:y", yaw0 + (deg_to_rad(open_deg) if state["open"] else 0.0), 0.45).set_trans(Tween.TRANS_SINE)
		tw.finished.connect(func() -> void: state["busy"] = false))
	pivot.add_child(d)


var _tower_glass_mat: StandardMaterial3D


func _glass_mat() -> StandardMaterial3D:
	if _tower_glass_mat != null:
		return _tower_glass_mat
	_tower_glass_mat = StandardMaterial3D.new()
	_tower_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_tower_glass_mat.albedo_color = Color(0.70, 0.82, 0.94, 0.20)
	_tower_glass_mat.roughness = 0.12
	_tower_glass_mat.metallic_specular = 0.85
	_tower_glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _tower_glass_mat


func _build_balcony_door() -> void:
	var hinge := Vector3(95.05, CAB, -39.0)
	var yaw0 := -PI * 0.5
	var w := 0.9
	var h := 2.05
	var open_deg := -95.0

	var pivot := Node3D.new()
	pivot.position = hinge
	pivot.rotation.y = yaw0
	add_child(pivot)

	var d := Interactable.new()
	d.collision_layer = Geo.LAYER_WORLD
	d.position = Vector3(0, h / 2, w / 2)

	# Деревянная застекленная дверь: бруски обвязки, филенка снизу, стекло сверху, ручки с обеих сторон
	var k := MeshKit.new(35)
	k.mottle = 0.08
	var wood_col := Color(0.22, 0.17, 0.12)
	k.box(Vector3(0, 0, -w / 2 + 0.04), Vector3(0.05, h - 0.02, 0.08), wood_col)
	k.box(Vector3(0, 0, w / 2 - 0.04), Vector3(0.05, h - 0.02, 0.08), wood_col)
	k.box(Vector3(0, -h / 2 + 0.07, 0), Vector3(0.05, 0.14, w - 0.04), wood_col)
	k.box(Vector3(0, h / 2 - 0.05, 0), Vector3(0.05, 0.10, w - 0.04), wood_col)
	var mid_y := -h / 2 + 0.95
	k.box(Vector3(0, mid_y, 0), Vector3(0.05, 0.10, w - 0.04), wood_col)
	var panel_h := mid_y - (-h / 2 + 0.14)
	k.box(Vector3(0, -h / 2 + 0.14 + panel_h / 2, 0), Vector3(0.025, panel_h - 0.02, w - 0.18), wood_col.darkened(0.15))
	var handle_y := mid_y + 0.05
	var handle_z := w * 0.38
	k.box(Vector3(0.045, handle_y, handle_z), Vector3(0.03, 0.14, 0.03), Color(0.12, 0.12, 0.13))
	k.box(Vector3(-0.045, handle_y, handle_z), Vector3(0.03, 0.14, 0.03), Color(0.12, 0.12, 0.13))
	k.box(Vector3(0.065, handle_y, handle_z - 0.04), Vector3(0.07, 0.025, 0.09), Color(0.12, 0.12, 0.13))
	k.box(Vector3(-0.065, handle_y, handle_z - 0.04), Vector3(0.07, 0.025, 0.09), Color(0.12, 0.12, 0.13))

	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	mi.material_override = Creatures._mat(&"prop_balcony_door", Color.WHITE, "tex_wood.png", 0.0)
	mi.layers = LAYER_IN | LAYER_OUT
	d.add_child(mi)

	# Стекло в верхней половине двери
	var glass_h := (h / 2 - 0.10) - (mid_y + 0.05)
	var glass_quad := QuadMesh.new()
	glass_quad.size = Vector2(w - 0.18, glass_h)
	var gmi := MeshInstance3D.new()
	gmi.mesh = glass_quad
	gmi.material_override = _glass_mat()
	gmi.position = Vector3(0, mid_y + 0.05 + glass_h / 2, 0)
	gmi.rotation.y = PI * 0.5
	gmi.layers = LAYER_IN | LAYER_OUT
	gmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d.add_child(gmi)

	d.add_child(Geo.box_shape(Vector3(0.06, h, w)))

	var state := {"open": false, "busy": false}
	d.prompt_provider = func() -> String: return Loc.t(&"it.door_close") if state["open"] else Loc.t(&"it.corpus_balcony_door")
	d.used.connect(func(_p: Player) -> void:
		if state["busy"]:
			return
		state["busy"] = true
		state["open"] = not state["open"]
		Game.audio.play_3d("res://assets/sfx/door_handle.ogg", pivot.global_position + Vector3(0, 1.0, 0), -4.0)
		Game.audio.play_3d("res://assets/audio/door.ogg", pivot.global_position + Vector3(0, 1.0, 0), -6.0)
		var tw := create_tween()
		tw.tween_property(pivot, "rotation:y", yaw0 + (deg_to_rad(open_deg) if state["open"] else 0.0), 0.45).set_trans(Tween.TRANS_SINE)
		tw.finished.connect(func() -> void: state["busy"] = false))
	pivot.add_child(d)


func _build_tower_glass() -> void:
	var gmat := _glass_mat()
	# Панорамное остекление кабины и лестничные бойницы башни
	var panes := [
		# Кабина: Южное остекление (с видом на тайгу и корпус)
		[Vector3(96.75, 11.4, -34.55), Vector3(0, 0, 1), Vector2(4.35, 1.48)],
		# Кабина: Западное остекление (с видом на тропу и жилой дом)
		[Vector3(94.55, 11.4, -36.75), Vector3(1, 0, 0), Vector2(4.35, 1.48)],
		# Кабина: Восточное остекление (с видом на метеоплощадку и ангар)
		[Vector3(98.95, 11.4, -36.75), Vector3(1, 0, 0), Vector2(4.35, 1.48)],
		# Кабина: Северное остекление (слева от двери)
		[Vector3(94.775, 11.4, -38.95), Vector3(0, 0, 1), Vector2(0.53, 1.48)],
		# Кабина: Северное остекление (справа от двери)
		[Vector3(97.475, 11.4, -38.95), Vector3(0, 0, 1), Vector2(3.03, 1.48)],
		# Кабина: Северная фрамуга над дверью (11.80 .. 12.15)
		[Vector3(95.5, 11.975, -38.95), Vector3(0, 0, 1), Vector2(0.88, 0.33)],
		# Башня: Окна-бойницы лестничных пролетов (1, 2, 3 этажи)
		[Vector3(94.55, 2.4, -37.8), Vector3(1, 0, 0), Vector2(0.38, 0.98)],
		[Vector3(94.55, 5.7, -37.8), Vector3(1, 0, 0), Vector2(0.38, 0.98)],
		[Vector3(96.0, 4.0, -38.95), Vector3(0, 0, 1), Vector2(0.38, 0.98)],
		[Vector3(96.0, 7.3, -38.95), Vector3(0, 0, 1), Vector2(0.38, 0.98)],
	]
	for p: Array in panes:
		var q := QuadMesh.new()
		var sz: Vector2 = p[2]
		q.size = sz
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = gmat
		mi.position = p[0]
		var norm: Vector3 = p[1]
		mi.rotation.y = atan2(norm.x, norm.z)
		mi.layers = LAYER_IN | LAYER_OUT
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _build_balcony_wind() -> void:
	var wind := AudioStreamPlayer3D.new()
	var ws := load("res://assets/sfx/cc0/wind_whistle_loop.ogg") as AudioStream
	if ws is AudioStreamOggVorbis:
		ws = ws.duplicate()
		(ws as AudioStreamOggVorbis).loop = true
	wind.stream = ws
	wind.volume_db = -8.0
	wind.unit_size = 6.0
	wind.max_distance = 25.0
	wind.bus = &"Ambience"
	wind.position = Vector3(96.75, CAB + 1.2, -40.0)
	add_child(wind)
	wind.play()


func _build_hangar_gates() -> void:
	# Две створки по 2 м на петлях у косяков; открываются наружу — для выпуска шара
	for s: int in [-1, 1]:
		var hinge := Node3D.new()
		hinge.position = Vector3(HANGAR_GATE_X + 0.05, 0.1, HANGAR_ZC + s * 2.0)
		hinge.rotation.y = 0.0 if s > 0 else PI
		add_child(hinge)
		var leaf := Models.spawn(hinge, "kedr/hangar_gate", Vector3.ZERO, 0.0, -1.0, {"center": false, "grime": 0.0, "bright": 1.0, "sat": 1.0})
		if leaf != null:
			leaf.position = Vector3.ZERO
			_set_layers(leaf, LAYER_OUT)
		_gate_leaves.append(hinge)
	var body := StaticBody3D.new()
	body.collision_layer = Geo.LAYER_WORLD
	add_child(body)
	_gate_col = CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.15, 4.6, 4.0)
	_gate_col.shape = sh
	_gate_col.position = Vector3(HANGAR_GATE_X + 0.05, 2.4, HANGAR_ZC)
	body.add_child(_gate_col)
	var it := Geo.interactable(self, Vector3(0.4, 2.0, 1.0), Vector3(HANGAR_GATE_X + 0.3, 1.2, HANGAR_ZC), null, "", func(_p: Player) -> void:
		set_gates(not _gates_open))
	it.prompt_provider = func() -> String: return Loc.t(&"it.hangar_gate_close") if _gates_open else Loc.t(&"it.hangar_gate_open")
	it.collision_layer = Geo.LAYER_INTERACT
	it.name = "HangarGate"


func set_gates(open: bool) -> void:
	if open == _gates_open:
		return
	_gates_open = open
	Game.audio.play_3d("res://assets/audio/clank_v3.ogg", Vector3(HANGAR_GATE_X, 2.0, HANGAR_ZC), -4.0)
	for i in _gate_leaves.size():
		var s := -1 if i == 0 else 1
		var base := PI if s < 0 else 0.0
		var tw := create_tween()
		tw.tween_property(_gate_leaves[i], "rotation:y", base + (deg_to_rad(-100.0 * s) if open else 0.0), 1.4).set_trans(Tween.TRANS_SINE)
	_gate_col.disabled = open


func gates_open() -> bool:
	return _gates_open


# --- Дизель и свет ------------------------------------------------------------------------

func _build_generator() -> void:
	var it := Geo.interactable(self, Vector3(1.6, 1.0, 0.8), GEN_POS + Vector3(0, 0.5, 0), null, "", _on_generator)
	it.prompt_provider = func() -> String: return Loc.t(&"it.corpus_gen_stop") if powered else Loc.t(&"it.corpus_gen_start")
	it.hold_time = 1.2
	it.hold_sound = "res://assets/audio/crank_loop.ogg"
	it.hold_check = func() -> bool: return not powered
	it.name = "CorpusGenerator"
	_engine = AudioStreamPlayer3D.new()
	_engine.stream = AudioDirector.cached_stream("res://assets/audio/engine_loop.ogg")
	_engine.volume_db = -6.0
	_engine.unit_size = 4.0
	_engine.max_distance = 60.0
	_engine.pitch_scale = 1.04
	_engine.bus = &"SFX"
	_engine.position = GEN_POS + Vector3(0, 0.6, 0)
	add_child(_engine)
	_engine.finished.connect(func() -> void:
		if powered:
			_engine.play())
	# Внутри корпуса 3D-дизель за стеной глушится почти до тишины — казалось, что он заглох, стоит
	# зайти. Ровный низкий гул «через пол» слышен, пока дизель работает и игрок в корпусе.
	_engine_in = AudioStreamPlayer.new()
	_engine_in.stream = AudioDirector.cached_stream("res://assets/audio/engine_loop.ogg")
	_engine_in.pitch_scale = 0.98
	_engine_in.volume_db = -80.0
	_engine_in.bus = &"Ambient"
	add_child(_engine_in)
	_engine_in.finished.connect(func() -> void:
		if powered:
			_engine_in.play())


func _on_generator(_p: Player) -> void:
	if powered:
		_set_power(false)
		Game.audio.play_3d("res://assets/sfx/gen_stall.ogg", GEN_POS, -2.0, 6.0)
		return
	_gen_tries += 1
	# На морозе дизель берёт не с первого раза: ночью — чаще с третьего, днём — со второго
	var need := 2 if Game.is_day() else 3
	if Game.is_story():
		need -= 1
	if Gear.has(&"spark_plug"):
		need = 1     # новая свеча — дизель берёт с первого рывка
	if _gen_tries < need and randf() < 0.85:
		Game.audio.play_3d("res://assets/sfx/gen_stall.ogg", GEN_POS, -2.0, 6.0)
		Game.hud.subtitle(Loc.t(&"sub.corpus_gen_fail"), 2.5)
		return
	_gen_tries = 0
	Game.audio.play_3d("res://assets/sfx/gen_start.ogg", GEN_POS, 0.0, 6.0)
	await get_tree().create_timer(1.1, false).timeout
	_set_power(true)
	Game.hud.subtitle(Loc.t(&"sub.corpus_gen_ok"), 3.0)


func _set_power(on: bool) -> void:
	powered = on
	_stall_t = randf_range(240.0, 480.0)
	for l in _lamps:
		if is_instance_valid(l):
			l.visible = on
	for g in _glows:
		if is_instance_valid(g):
			g.visible = on
	if _engine != null:
		if on and not _engine.playing:
			_engine.play()
		elif not on:
			_engine.stop()
	if _engine_in != null:
		if on and not _engine_in.playing:
			_engine_in.play()
		elif not on:
			_engine_in.stop()


func _build_lights() -> void:
	# Внутренние лампы — только «внутри»; фонари крыльца и ангара — «снаружи»
	var inner := [
		[Vector3(92.6, 3.4, -31.3), 6.0], [Vector3(92.6, 3.4, -27.2), 3.5], [Vector3(92.6, 3.4, -23.0), 6.0],
		[Vector3(95.6, 3.4, -31.0), 5.0], [Vector3(95.6, 3.4, -24.0), 5.0],
		[Vector3(97.5, 3.4, -31.8), 4.0], [Vector3(97.5, 3.4, -22.6), 4.0],
		[Vector3(102.0, 3.4, -36.2), 6.0], [Vector3(98.0, 3.3, -37.0), 4.5], [Vector3(97.9, 6.6, -37.0), 4.5],
		[Vector3(96.7, 9.6, -36.2), 4.5], [Vector3(96.7, 11.9, -36.7), 5.0], [Vector3(100.7, 2.4, -32.0), 3.5],
	]
	for e: Array in inner:
		var l := Geo.omni(self, e[0], e[1], 0.85, Color(1.0, 0.84, 0.62))
		l.light_cull_mask = 1 | LAYER_IN
		l.shadow_enabled = false
		Geo.bulb(l, &"bulb", 0.05)
		_lamps.append(l)
	# Фотолаборатория — красный фонарь
	var red := Geo.omni(self, Vector3(97.5, 2.6, -27.2), 4.0, 0.7, Color(1.0, 0.18, 0.12))
	red.light_cull_mask = 1 | LAYER_IN
	_lamps.append(red)
	for e: Array in [[Vector3(89.75, 2.75, -27.25), 7.0, 1.0], [Vector3(128.3, 3.2, HANGAR_ZC), 8.0, 0.9], [Vector3(121.5, 4.3, HANGAR_ZC), 9.0, 0.7]]:   # последняя — лампа под балкой оболочечной
		var l := Geo.omni(self, e[0], e[1], e[2], Color(1.0, 0.78, 0.5))
		l.light_cull_mask = 1 | LAYER_OUT
		_lamps.append(l)
	# Свечение окон снаружи, когда горит свет: тёплое «стекло» поверх тёмного
	var wins := [
		[Vector3(89.98, 1.95, -32.8), Vector3(-1, 0, 0), Vector2(1.0, 1.1)], [Vector3(89.98, 1.95, -30.0), Vector3(-1, 0, 0), Vector2(1.0, 1.1)],
		[Vector3(89.98, 1.95, -24.2), Vector3(-1, 0, 0), Vector2(1.0, 1.1)], [Vector3(92.5, 1.95, -19.98), Vector3(0, 0, 1), Vector2(1.0, 1.1)],
		[Vector3(95.6, 2.0, -19.98), Vector3(0, 0, 1), Vector2(0.6, 0.8)], [Vector3(97.6, 2.0, -19.98), Vector3(0, 0, 1), Vector2(0.6, 0.6)],
		[Vector3(99.02, 2.0, -22.6), Vector3(1, 0, 0), Vector2(0.7, 0.6)], [Vector3(92.2, 1.95, -34.52), Vector3(0, 0, -1), Vector2(1.0, 1.1)],
		[Vector3(101.0, 2.75, -39.02), Vector3(0, 0, -1), Vector2(0.7, 0.5)], [Vector3(104.0, 2.75, -33.48), Vector3(0, 0, 1), Vector2(0.7, 0.5)],
		[Vector3(102.42, 1.7, -32.0), Vector3(1, 0, 0), Vector2(0.7, 0.5)],
	]
	for wdef: Array in wins:
		_glows.append(_window_glow(wdef[0], wdef[1], wdef[2]))
	# Кабина: светится остекление (северная грань разбита в обход дверного проема на балкон)
	for wdef: Array in [
			[Vector3(96.75, 11.4, -34.42), Vector3(0, 0, 1), Vector2(4.3, 1.4)],
			[Vector3(94.42, 11.4, -36.75), Vector3(-1, 0, 0), Vector2(4.3, 1.4)],
			[Vector3(99.08, 11.4, -36.75), Vector3(1, 0, 0), Vector2(4.3, 1.4)],
			[Vector3(94.775, 11.4, -39.08), Vector3(0, 0, -1), Vector2(0.53, 1.4)],
			[Vector3(97.475, 11.4, -39.08), Vector3(0, 0, -1), Vector2(3.03, 1.4)],
			[Vector3(95.5, 11.975, -39.08), Vector3(0, 0, -1), Vector2(0.88, 0.33)]]:
		_glows.append(_window_glow(wdef[0], wdef[1], wdef[2]))


func _window_glow(pos: Vector3, out: Vector3, size: Vector2) -> Node3D:
	var quad := QuadMesh.new()
	quad.size = size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.66, 0.32, 0.7)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.rotation.y = atan2(out.x, out.z)
	mi.layers = LAYER_OUT
	add_child(mi)
	return mi


# --- Лестницы ----------------------------------------------------------------------------

func _build_ladders() -> void:
	_climb(LADDER_TOWER + Vector3(0, 1.3, 0), Vector3(97.8, CAB + 0.05, -39.5), &"it.corpus_ladder_up", &"sub.corpus_balcony")
	_climb(Vector3(97.8, CAB + 0.6, -39.55), LADDER_TOWER + Vector3(0, 0.05, -0.3), &"it.corpus_ladder_down", &"")
	_climb(LADDER_ROOF + Vector3(0, 1.3, 0), Vector3(98.0, ROOF_Y + 0.1, -21.0), &"it.corpus_roof_up", &"")
	_climb(Vector3(98.0, ROOF_Y + 0.5, -20.55), LADDER_ROOF + Vector3(0, 0.05, 0.3), &"it.corpus_ladder_down", &"")


func _climb(at: Vector3, to: Vector3, prompt_key: StringName, sub_key: StringName) -> void:
	var it := Geo.interactable(self, Vector3(0.9, 2.2, 0.6), at, null, Loc.t(prompt_key), func(_p: Player) -> void:
		if Game.player == null:
			return
		Game.audio.play_2d("res://assets/audio/clank.ogg", -4.0)
		if Game.hud != null:
			await Game.hud.blink(0.35)
		if Game.player != null:
			Game.player.global_position = to
		if sub_key != &"":
			Game.hud.subtitle(Loc.t(sub_key), 3.5))
	it.hold_time = 0.8
	it.collision_layer = Geo.LAYER_INTERACT


# --- Буржуйка в кабинете: тепло, если растоплена -----------------------------------------------

func _build_stove() -> void:
	var it := Geo.interactable(self, Vector3(0.6, 0.9, 0.6), STOVE_POS + Vector3(0, 0.45, 0), null, "", func(_p: Player) -> void:
		if stove_lit:
			Gear.refill_thermos()
		stove_lit = true
		_stove_t = 420.0
		Game.audio.play_3d("res://assets/audio/stove_add.ogg", STOVE_POS + Vector3(0, 0.5, 0), -3.0)
		Game.hud.subtitle(Loc.t(&"sub.corpus_stove_lit"), 3.0))
	it.prompt_provider = func() -> String: return Loc.t(&"it.corpus_stove_more") if stove_lit else Loc.t(&"it.corpus_stove")
	it.hold_time = 1.4
	it.name = "CorpusStove"
	_stove_light = Geo.omni(self, STOVE_POS + Vector3(0.3, 0.4, 0), 3.0, 0.0, Color(1.0, 0.5, 0.2))
	_stove_light.light_cull_mask = 1 | LAYER_IN

	_stove_audio = AudioStreamPlayer3D.new()
	var cs := load("res://assets/sfx/cc0/stove_crackle_loop.ogg") as AudioStream
	if cs is AudioStreamOggVorbis:
		cs = cs.duplicate()
		(cs as AudioStreamOggVorbis).loop = true
	_stove_audio.stream = cs
	_stove_audio.unit_size = 3.2
	_stove_audio.max_distance = 12.0
	_stove_audio.volume_db = -80.0
	_stove_audio.bus = &"SFX"
	_stove_audio.position = STOVE_POS + Vector3(0, 0.45, 0)
	add_child(_stove_audio)
	_stove_audio.play()


func _process(delta: float) -> void:
	_tick_scares(delta)
	if _engine_in != null and _engine_in.playing:
		var target := -24.0 if Game.zone == &"corpus" else -80.0
		_engine_in.volume_db = lerpf(_engine_in.volume_db, target, minf(delta * 3.0, 1.0))
	if _stove_audio != null:
		var target_s := -10.0 if stove_lit else -80.0
		_stove_audio.volume_db = lerpf(_stove_audio.volume_db, target_s, minf(delta * 2.5, 1.0))
	if stove_lit:
		_stove_t -= delta
		_stove_light.light_energy = 0.7 + 0.15 * sin(Time.get_ticks_msec() * 0.007) + randf() * 0.05
		if _stove_t <= 0.0:
			stove_lit = false
			_stove_light.light_energy = 0.0
	# Дизель на морозе иногда глохнет сам — ночью, если рядом кто-то есть
	if powered and Game.is_night() and Game.player != null:
		_stall_t -= delta
		if _stall_t <= 0.0:
			_stall_t = randf_range(240.0, 480.0)
			if randf() < 0.35 and Game.player.global_position.distance_to(GEN_POS) < 60.0:
				Game.audio.play_3d("res://assets/sfx/gen_stall.ogg", GEN_POS, 0.0, 8.0)
				_set_power(false)
				Director.add_tension(10.0, "дизель корпуса заглох")
				Game.hud.subtitle(Loc.t(&"sub.corpus_gen_stalled"), 3.5)


# --- Приборы и вещи -------------------------------------------------------------------

## «Карат» (снаряжение с ретранслятора): у пульта ветра — передать сводку прямо отсюда, не бегая в дом.
func _build_karat() -> void:
	var it := Geo.interactable(self, Vector3(0.5, 0.4, 0.4), PULT_POS + Vector3(0.9, 1.05, 0.25), null, "", func(_p: Player) -> void:
		if Game.radio != null:
			Game.radio.field_transmit())
	it.prompt_provider = func() -> String:
		return Loc.t(&"it.karat_report") if Gear.has(&"field_radio") and Game.is_night() else ""
	it.name = "KaratReport"


func _build_things() -> void:
	_build_karat()
	var baro := Geo.interactable(self, Vector3(0.6, 0.4, 1.4), BARO_POS + Vector3(0, 0.95, 0), null, Loc.t(&"it.corpus_baro"), func(_p: Player) -> void:
		EventBus.ui_requested.emit(&"barograph")
		# Самописец рисует не то: с третьей ночи на ленте — ровный зубец в минуту стука
		if Game.is_night() and Game.night >= 3 and not _baro_odd:
			_baro_odd = true
			await get_tree().create_timer(1.6, false).timeout
			Game.hud.subtitle(Loc.t(&"sub.corpus_baro_odd"), 5.0)
			Director.add_tension(10.0, "самописец рисует не то"))
	baro.name = "CorpusBarograph"
	var log_it := Geo.interactable(self, Vector3(0.45, 0.2, 0.6), JOURNAL_POS, null, Loc.t(&"it.pav_log"), func(_p: Player) -> void:
		Game.hud.show_note(Loc.t(&"pav.log"))
		if not Game.has_flag("pav_log_read"):
			Game.set_flag("pav_log_read", true)
			Director.add_tension(3.0, "журнал корпуса"))
	log_it.name = "CorpusLog"
	var phone := Geo.interactable(self, Vector3(0.3, 0.4, 0.4), PHONE_POS, null, "", _on_phone)
	phone.prompt_provider = func() -> String: return Loc.t(&"it.pav_phone_ring") if _ring != null else Loc.t(&"it.pav_phone")
	phone.name = "CorpusPhone"
	for e: Array in [[Vector3(98.35, FL + 1.1, -27.2), Vector3(0.5, 2.2, 3.9), &"it.corpus_archive", &"sub.corpus_archive"],
			[Vector3(98.3, FL + 1.0, -33.0), Vector3(0.6, 1.9, 1.6), &"it.corpus_radio", &"sub.corpus_radio"],
			[Vector3(97.05, FL + 0.85, -25.58), Vector3(0.9, 0.3, 0.8), &"it.corpus_trays", &"sub.corpus_trays"],
			[Vector3(102.3, FL + 1.1, -37.7), Vector3(2.8, 2.2, 1.0), &"it.corpus_gasgen", &"sub.corpus_gasgen"]]:
		var key: StringName = e[3]
		var it := Geo.interactable(self, e[1], e[0], null, Loc.t(e[2]), func(_p: Player) -> void: Game.hud.subtitle(Loc.t(key), 5.0))
		it.collision_layer = Geo.LAYER_INTERACT


func _on_phone(_p: Player) -> void:
	if _ring == null:
		Game.audio.play_3d("res://assets/audio/static_loop.ogg", PHONE_POS, -10.0, 2.0, 2.5)
		Game.hud.subtitle(Loc.t(&"sub.pav_phone_quiet"), 3.5)
		return
	_stop_ring()
	Game.audio.play_3d("res://assets/audio/static_loop.ogg", PHONE_POS, -4.0, 2.0, 4.0)
	Game.hud.subtitle(Loc.t(StringName("sub.pav_phone_%d" % clampi(Game.night / 2, 0, 3))), 5.0)
	Director.add_tension(10.0, "трубка корпуса")


func _start_ring() -> void:
	_rang += 1
	_ring = AudioStreamPlayer3D.new()
	_ring.stream = AudioDirector.cached_stream(RING_SOUND)
	_ring.volume_db = 1.0
	_ring.unit_size = 5.0
	_ring.max_distance = 60.0
	_ring.pitch_scale = 1.45
	_ring.bus = &"SFX"
	_ring.position = PHONE_POS
	add_child(_ring)
	_ring.finished.connect(_ring.play)
	_ring.play()
	_ring_t = 18.0
	Director.add_tension(6.0, "звонит телефон корпуса — из пустого дома")


func _stop_ring() -> void:
	if _ring != null:
		_ring.queue_free()
		_ring = null


# --- Испуги: по разу за ночь, только когда дежурный в корпусе или идёт к нему -------------------

func _tick_scares(delta: float) -> void:
	if not Game.is_night() or Game.player == null or Game.dead:
		return
	var p := Game.player.global_position
	var inside := Game.zone == &"corpus"
	# Звонок из пустого дома
	if _ring != null:
		_ring_t -= delta
		if _ring_t <= 0.0:
			_stop_ring()
	elif inside and _rang < 2:
		_next_ring -= delta
		if _next_ring <= 0.0:
			_next_ring = randf_range(150.0, 320.0)
			if randf() < 0.5:
				_start_ring()
	# Шаги по крыше, потом скрежет на пожарной лестнице
	if inside and Game.night >= 2 and not _done.has("roof") and p.y < 4.0:
		_roof_t -= delta
		if _roof_t <= 0.0:
			_done["roof"] = true
			_roof_steps(p)
	# Стук во входную дверь — и сюда
	if inside and Game.night >= 3 and not _done.has("knock"):
		_knock_t -= delta
		if _knock_t <= 0.0:
			_done["knock"] = true
			_knock()
	# Фигура в окне кабины, пока идёшь по тропе
	if not inside and Game.night >= 2 and not _done.has("cabin_fig") and _figure == null:
		var d := Vector2(p.x - CABIN_FIGURE.x, p.z - CABIN_FIGURE.z).length()
		if d > 28.0 and d < 80.0 and Game.player.is_looking_at(CABIN_FIGURE + Vector3(0, 1.5, 0), 40.0):
			_done["cabin_fig"] = true
			_show_cabin_figure()
	if _figure != null:
		_figure_t -= delta
		var d2 := Vector2(p.x - CABIN_FIGURE.x, p.z - CABIN_FIGURE.z).length()
		if _figure_t <= 0.0 or d2 < 22.0:
			_figure.queue_free()
			_figure = null
	# Отпечаток ладони снаружи на стекле кабины — когда поднимешься
	if _done.has("cabin_fig") and not _done.has("palm") and p.y > CAB - 0.2 and Game.zone == &"corpus":
		_done["palm"] = true
		_palm_print()
	# Ледяной ветер при выходе на открытый балкон
	if p.y > CAB - 0.2 and p.z < -39.1 and not _done.has("balcony_wind_msg"):
		_done["balcony_wind_msg"] = true
		Game.hud.subtitle(Loc.t(&"sub.corpus_balcony_wind"), 4.0)


func _roof_steps(p: Vector3) -> void:
	var over := Vector3(p.x, ROOF_Y + 0.1, p.z)
	for k in 4:
		Game.audio.play_3d("res://assets/sfx/roof_steps.ogg", over + Vector3(0, 0, -1.5 * k), -2.0, 6.0)
		await get_tree().create_timer(0.9, false).timeout
	Director.add_tension(12.0, "шаги по крыше корпуса")
	Game.hud.subtitle(Loc.t(&"sub.corpus_roof"), 4.0)
	await get_tree().create_timer(5.0, false).timeout
	Game.audio.play_3d("res://assets/sfx/scratch_wall.ogg", LADDER_ROOF + Vector3(0, 2.5, 0), 0.0, 6.0)
	Game.audio.play_3d("res://assets/audio/clank.ogg", LADDER_ROOF + Vector3(0, 1.5, 0), -4.0, 6.0)


func _knock() -> void:
	for k in 3:
		Game.audio.play_3d("res://assets/sfx/knock_door.ogg", DOOR + Vector3(-0.1, 1.2, 0), 2.0, 5.0)
		await get_tree().create_timer(0.55 if k < 2 else 0.9, false).timeout
	Game.hud.subtitle(Loc.t(&"sub.corpus_knock"), 4.5)
	Director.add_tension(14.0, "стучат в дверь корпуса")
	_knock_open_until = Time.get_ticks_msec() + 15000.0
	# Откроешь — на крыльце никого, только мокрые босые следы от двери в темноту
	var trail := Footprints.trail(self, &"wet", PackedVector3Array([DOOR + Vector3(-0.4, 0, 0), DOOR + Vector3(-1.6, 0, 0.2), PORCH + Vector3(-2.0, 0, 1.0), PORCH + Vector3(-7.0, 0, 3.5)]), FL + 0.01, 0.5)
	Geo.free_after(trail, 240.0)


func _show_cabin_figure() -> void:
	_figure = Creatures.make_silhouette()
	add_child(_figure)
	_figure.global_position = CABIN_FIGURE
	var look := Game.player.global_position
	look.y = CAB
	_figure.look_at(look, Vector3.UP)
	_figure_t = 9.0
	# Без питания кабина тёмная — фигуру видно только против неба; подсветим холодным отсветом
	if not powered:
		var rim := OmniLight3D.new()
		rim.omni_range = 2.2
		rim.light_energy = 0.9
		rim.light_color = Color(0.6, 0.7, 0.9)
		_figure.add_child(rim)
		rim.position = Vector3(0, 1.8, -0.6)
	Director.add_tension(10.0, "фигура в окне кабины")


func _palm_print() -> void:
	# Ладонь снаружи на стекле: тёмная пятерня на инее
	var k := MeshKit.new(77)
	var c := Color(0.06, 0.06, 0.07)
	k.box(Vector3.ZERO, Vector3(0.11, 0.12, 0.004), c)
	for i in 4:
		k.box(Vector3(-0.04 + i * 0.027, 0.1 + (0.02 if i in [1, 2] else 0.0), 0.0), Vector3(0.018, 0.09, 0.004), c)
	k.box(Vector3(0.075, 0.0, 0.0), Vector3(0.05, 0.02, 0.004), c)
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	mi.material_override = Creatures._mat(&"palm_print", Color.WHITE, "", 0.0)
	mi.position = Vector3(96.4, CAB + 1.55, -34.42)
	mi.layers = LAYER_IN | LAYER_OUT
	add_child(mi)
	Game.hud.subtitle(Loc.t(&"sub.corpus_palm"), 5.0)
	Director.add_tension(12.0, "отпечаток ладони на стекле кабины")
