class_name Props
extends RefCounted
## Предметы станции, собранные кодом (MeshKit): стол, стул, рация, лампа, кровать, печь, полка,
## генератор, бочка, журнал, поленница. Только визуал — столкновения и взаимодействие остаются
## на прежних коробках в Station/Yard. Начало координат — пол под центром предмета, если не сказано иначе.

const WOOD := Color(0.3, 0.23, 0.16)        ## × текстура дерева: светлее — иначе мебель в доме читалась чёрными коробками
const WOOD_DARK := Color(0.2, 0.155, 0.11)
const METAL := Color(0.32, 0.34, 0.35)
const METAL_DARK := Color(0.14, 0.15, 0.16)
const RADIO := Color(0.20, 0.23, 0.21)
const BLACK := Color(0.04, 0.04, 0.04)
const WHITEWASH := Color(0.65, 0.63, 0.58)
const RED := Color(0.40, 0.10, 0.08)
const BARK := Color(0.14, 0.10, 0.07)
const LOG_END := Color(0.35, 0.28, 0.20)
## Яркость предметов: цвет вершин × текстура (~0.6) давал альбедо 0.1–0.2 — втрое темнее стен из Blender
const PROP_GAIN := 1.6


static var _mesh_cache: Dictionary = {}


static func _instance_from_cache(key: StringName, tex := "") -> MeshInstance3D:
	if not _mesh_cache.has(key):
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh_cache[key]
	mi.material_override = _prop_mat(key, tex)
	return mi


static func _mi(kit: MeshKit, key: StringName, tex := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh: ArrayMesh
	if _mesh_cache.has(key):
		mesh = _mesh_cache[key]
	else:
		mesh = kit.commit()
		_mesh_cache[key] = mesh
	mi.mesh = mesh
	mi.material_override = _prop_mat(key, tex)
	return mi


static func _prop_mat(key: StringName, tex: String) -> ShaderMaterial:
	return _gained(Creatures._mat(StringName("prop_" + String(key)), Color.WHITE, tex, 0.0))


static func _gained(m: ShaderMaterial) -> ShaderMaterial:
	m.set_shader_parameter(&"gain", PROP_GAIN)
	return m


static func _kit(seed_value: int, mottle := 0.08) -> MeshKit:
	var k := MeshKit.new(seed_value)
	k.mottle = mottle
	return k


## Стол 2.1 × 0.85, высота 0.75: широкая столешница, ножки слева, тумба с ящиками справа.
static func desk() -> Node3D:
	var k := _kit(11)
	k.box(Vector3(0, 0.725, 0), Vector3(2.1, 0.05, 0.85), WOOD)
	for sx: float in [-0.96, -0.38]:
		for sz: float in [-0.36, 0.36]:
			k.box(Vector3(sx, 0.35, sz), Vector3(0.06, 0.7, 0.06), WOOD_DARK)
	k.box(Vector3(0.70, 0.35, 0.0), Vector3(0.56, 0.7, 0.76), WOOD_DARK)
	for i in range(3):
		var y := 0.15 + i * 0.2
		k.box(Vector3(0.70, y, 0.385), Vector3(0.50, 0.17, 0.01), WOOD)
		k.box(Vector3(0.70, y, 0.395), Vector3(0.12, 0.025, 0.02), METAL)
	k.box(Vector3(-0.15, 0.16, -0.37), Vector3(1.6, 0.04, 0.03), WOOD_DARK)   # царга
	return _mi(k, &"desk", "tex_wood.png")


## Табурет со спинкой. Начало — центр сиденья по высоте 0.225 (как у старой коробки).
static func chair() -> Node3D:
	var k := _kit(12)
	k.box(Vector3(0, 0.2, 0), Vector3(0.44, 0.04, 0.42), WOOD)
	for sx: float in [-0.19, 0.19]:
		for sz: float in [-0.18, 0.18]:
			k.box(Vector3(sx, -0.02, sz), Vector3(0.04, 0.44, 0.04), WOOD_DARK)
	for sx: float in [-0.19, 0.19]:
		k.box(Vector3(sx, 0.46, 0.19), Vector3(0.04, 0.5, 0.04), WOOD_DARK)
	k.box(Vector3(0, 0.62, 0.19), Vector3(0.42, 0.12, 0.03), WOOD)
	k.box(Vector3(0, 0.42, 0.19), Vector3(0.42, 0.05, 0.025), WOOD)
	var mi := _mi(k, &"chair", "tex_wood.png")
	mi.position.y = -0.225
	var root := Node3D.new()
	root.add_child(mi)
	return root


## Р-250: корпус, тёмная панель, шкала, ручки, стрелочные приборы, ручки для переноски.
## Начало — центр корпуса 0.9 × 0.42 × 0.38, лицевая сторона +Z.
static func radio() -> Node3D:
	var k := _kit(13, 0.05)
	k.box(Vector3.ZERO, Vector3(0.9, 0.42, 0.36), RADIO)
	k.box(Vector3(0, 0, 0.181), Vector3(0.84, 0.36, 0.01), RADIO * 0.7)
	k.box(Vector3(-0.15, 0.06, 0.187), Vector3(0.36, 0.11, 0.008), BLACK)        # окно шкалы
	for i in range(9):
		k.box(Vector3(-0.31 + i * 0.04, 0.06, 0.192), Vector3(0.004, 0.06 if i % 2 == 0 else 0.03, 0.002), WHITEWASH)
	for i in range(2):
		var x := 0.15 + i * 0.16
		k.box(Vector3(x, 0.08, 0.188), Vector3(0.12, 0.09, 0.008), WHITEWASH * 0.9)   # приборы
		k.box(Vector3(x - 0.01, 0.07, 0.193), Vector3(0.004, 0.06, 0.002), BLACK, Basis(Vector3.FORWARD, deg_to_rad(-25.0 + i * 40.0)))
	for i in range(4):
		var x := -0.3 + i * 0.2
		k.tube([Vector3(x, -0.1, 0.185), Vector3(x, -0.1, 0.225)], [0.032, 0.03], BLACK, 8)
		k.box(Vector3(x, -0.08, 0.226), Vector3(0.006, 0.02, 0.004), WHITEWASH)
	k.box(Vector3(0.36, -0.12, 0.19), Vector3(0.05, 0.03, 0.02), METAL)          # тумблер
	for sx: float in [-0.38, 0.38]:
		k.tube([Vector3(sx, 0.21, -0.05), Vector3(sx, 0.26, -0.05), Vector3(sx, 0.26, 0.05), Vector3(sx, 0.21, 0.05)], [0.012], METAL, 4, false, false)
	k.tube([Vector3(0.44, 0.0, -0.1), Vector3(0.55, -0.1, -0.15), Vector3(0.6, -0.2, -0.18)], [0.012], BLACK, 4)   # кабель
	return _mi(k, &"radio")


## Портативный кассетный магнитофон «Весна-306»:
## Корпус 0.36 × 0.10 × 0.24, панель с кассетой, клавиши пианино, решётка динамика, индикатор.
## Модель из Блендера (tools/blender/*.py → assets/models/kedr/<id>.glb): запечённые цвет и AO,
## поэтому без триплан-грязи и с почти полной насыщенностью. Нет файла — null (строим по-старому).
static func _kedr_model(id: String, opts := {}) -> Node3D:
	var path := "res://assets/models/kedr/%s.glb" % id
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return null
	var root := Node3D.new()
	var o := {"grime": 0.0, "bright": 1.25, "sat": 0.85, "scale": 1.0}
	o.merge(opts, true)
	if Models.spawn(root, "kedr/" + id, Vector3.ZERO, 0.0, -1.0, o) == null:
		root.free()
		return null
	return root


static func tape_deck() -> Node3D:
	var glb := _kedr_model("vesna306")
	if glb != null:
		return glb
	var k := _kit(42, 0.04)
	var body_col := Color(0.24, 0.23, 0.22)       # Тёмно-серый / графитовый корпус
	var alu_col := Color(0.72, 0.74, 0.76)        # Алюминиевая матовая панель
	var cassette_bay := Color(0.12, 0.12, 0.12)   # Ниша кассеты
	var tape_amber := Color(0.42, 0.25, 0.12)     # Корпус кассеты
	var tape_label := Color(0.85, 0.82, 0.75)     # Бумажная наклейка на кассете
	var spool_col := Color(0.92, 0.92, 0.95)      # Белые катушки

	# Основной корпус
	k.box(Vector3(0, 0.05, 0), Vector3(0.36, 0.09, 0.24), body_col)
	# Верхняя алюминиевая фасадная накладка
	k.box(Vector3(0, 0.096, 0), Vector3(0.34, 0.004, 0.22), alu_col)

	# --- Кассетный отсек (слева, x от -0.14 до -0.01, z от -0.06 до 0.06) ---
	k.box(Vector3(-0.075, 0.098, 0.0), Vector3(0.15, 0.005, 0.11), cassette_bay)
	# Корпус компакт-кассеты
	k.box(Vector3(-0.075, 0.101, 0.0), Vector3(0.12, 0.004, 0.08), tape_amber)
	k.box(Vector3(-0.075, 0.104, 0.0), Vector3(0.09, 0.002, 0.035), tape_label)
	# Прозрачное окно в центре наклейки
	k.box(Vector3(-0.075, 0.105, 0.0), Vector3(0.05, 0.002, 0.016), BLACK)
	# Две белые катушки (зубчатые сердечники кассеты)
	k.tube([Vector3(-0.105, 0.101, 0.0), Vector3(-0.105, 0.106, 0.0)], [0.012], spool_col, 8)
	k.tube([Vector3(-0.045, 0.101, 0.0), Vector3(-0.045, 0.106, 0.0)], [0.012], spool_col, 8)
	k.box(Vector3(-0.105, 0.107, 0.0), Vector3(0.004, 0.003, 0.004), BLACK)
	k.box(Vector3(-0.045, 0.107, 0.0), Vector3(0.004, 0.003, 0.004), BLACK)
	# Защитная крышка кассетного отсека (прозрачно-дымчатое стекло с металлической рамкой)
	k.box(Vector3(-0.075, 0.108, 0.0), Vector3(0.146, 0.002, 0.106), Color(0.18, 0.20, 0.22, 0.8))

	# --- Решётка громкоговорителя (справа, x от 0.03 до 0.14) ---
	k.box(Vector3(0.085, 0.098, 0.01), Vector3(0.13, 0.003, 0.12), BLACK)
	for r in range(7):
		var z_rib := -0.04 + r * 0.015
		k.box(Vector3(0.085, 0.101, z_rib), Vector3(0.12, 0.003, 0.005), alu_col)

	# --- Клавиши управления (спереди, z от 0.08 до 0.11) ---
	var btn_cols := [Color(0.85, 0.2, 0.15), alu_col, alu_col, alu_col, alu_col, alu_col]
	for b in range(6):
		var bx := -0.13 + b * 0.024
		k.box(Vector3(bx, 0.095, 0.095), Vector3(0.019, 0.016, 0.026), btn_cols[b])

	# --- Стрелочный индикатор уровня сигнала (VU meter) ---
	k.box(Vector3(-0.075, 0.099, -0.08), Vector3(0.08, 0.003, 0.035), WHITEWASH)
	k.box(Vector3(-0.055, 0.101, -0.08), Vector3(0.025, 0.002, 0.004), RED)
	k.box(Vector3(-0.085, 0.101, -0.08), Vector3(0.03, 0.002, 0.003), BLACK)
	k.box(Vector3(-0.072, 0.103, -0.08), Vector3(0.003, 0.002, 0.022), Color(0.9, 0.1, 0.05), Basis(Vector3.UP, deg_to_rad(20.0)))
	k.box(Vector3(-0.075, 0.105, -0.08), Vector3(0.084, 0.002, 0.039), Color(0.3, 0.35, 0.4))

	# --- Регуляторы громкости и тембра (справа вверху) ---
	for s in range(2):
		var rx := 0.05 + s * 0.06
		k.tube([Vector3(rx, 0.097, -0.08), Vector3(rx, 0.112, -0.08)], [0.016, 0.014], BLACK, 8)
		k.box(Vector3(rx, 0.113, -0.08), Vector3(0.004, 0.002, 0.014), alu_col)

	# --- Красный светодиод питания/записи ---
	k.tube([Vector3(0.14, 0.098, -0.08), Vector3(0.14, 0.108, -0.08)], [0.006], Color(1.0, 0.15, 0.1), 6)

	# --- Металлическая скоба-ручка для переноски ---
	for sx: float in [-0.17, 0.17]:
		k.box(Vector3(sx, 0.06, -0.12), Vector3(0.012, 0.02, 0.02), METAL)
	k.tube([Vector3(-0.17, 0.06, -0.12), Vector3(-0.17, 0.06, -0.15), Vector3(0.17, 0.06, -0.15), Vector3(0.17, 0.06, -0.12)], [0.006], METAL, 4, false, false)

	return _mi(k, &"tape_deck")



## Настольная лампа. Начало — на столешнице.
static func desk_lamp() -> Node3D:
	var k := _kit(14)
	k.tube([Vector3(0, 0.0, 0), Vector3(0, 0.03, 0)], [0.08, 0.08], METAL_DARK, 8)
	k.tube([Vector3(0, 0.03, 0), Vector3(0.02, 0.25, 0.03), Vector3(0.05, 0.38, 0.1)], [0.012], METAL, 5)
	k.tube([Vector3(0.05, 0.42, 0.06), Vector3(0.05, 0.36, 0.14)], [0.03, 0.08], Color(0.15, 0.16, 0.16), 8, true, false)
	var mi := _mi(k, &"lamp")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Железная кровать: спинки из труб, матрас, подушка, шерстяное одеяло. Изголовье — +Z.
static func bed() -> Node3D:
	var k := _kit(15)
	for sz: float in [-0.98, 0.98]:
		var h := 0.95 if sz > 0.0 else 0.7
		for sx: float in [-0.43, 0.43]:
			k.tube([Vector3(sx, 0, sz), Vector3(sx, h, sz)], [0.018], METAL_DARK, 5)
		k.tube([Vector3(-0.43, h, sz), Vector3(0.43, h, sz)], [0.018], METAL_DARK, 5, false, false)
		for i in range(5):
			var x := -0.3 + i * 0.15
			k.tube([Vector3(x, 0.32, sz), Vector3(x, h, sz)], [0.01], METAL_DARK, 4, false, false)
	for sx: float in [-0.43, 0.43]:
		k.tube([Vector3(sx, 0.3, -0.98), Vector3(sx, 0.3, 0.98)], [0.02], METAL_DARK, 5, false, false)
	k.box(Vector3(0, 0.37, 0), Vector3(0.84, 0.14, 1.92), Color(0.55, 0.53, 0.47))   # матрас
	k.blob(Vector3(0, 0.49, 0.72), Vector3(0.34, 0.07, 0.18), Color(0.78, 0.76, 0.7), 3, 8)
	k.box(Vector3(0, 0.455, -0.25), Vector3(0.9, 0.04, 1.35), Color(0.32, 0.17, 0.12))   # одеяло
	k.box(Vector3(0, 0.46, -0.3), Vector3(0.91, 0.045, 0.06), Color(0.55, 0.42, 0.18))   # полоса на одеяле
	k.box(Vector3(0.455, 0.36, -0.25), Vector3(0.02, 0.2, 1.3), Color(0.3, 0.16, 0.11))
	return _mi(k, &"bed", "tex_cloth.png")


## Печь: побелённый кирпич, уступ, чугунная дверца и плита, труба в потолок. Топка — на −Z.
static func stove(ceiling_y: float) -> Node3D:
	if is_equal_approx(ceiling_y, 2.8):
		var glb := _kedr_model("stove_brick", {"center": false, "bright": 0.85})   # побелка и так светлая; печь светится изнутри огнём
		if glb != null:
			return glb
	var k := _kit(16, 0.06)
	k.box(Vector3(0, 0.08, 0), Vector3(0.98, 0.16, 0.98), WHITEWASH * 0.85)
	k.box(Vector3(0, 0.66, 0), Vector3(0.9, 1.0, 0.9), WHITEWASH)
	k.box(Vector3(0, 1.2, 0), Vector3(0.96, 0.08, 0.96), WHITEWASH * 0.9)
	k.box(Vector3(0, 1.165, -0.2), Vector3(0.6, 0.02, 0.45), METAL_DARK)       # чугунная плита
	k.tube([Vector3(-0.12, 1.18, -0.2), Vector3(-0.12, 1.19, -0.2)], [0.1], BLACK, 8)
	k.tube([Vector3(0.14, 1.18, -0.2), Vector3(0.14, 1.19, -0.2)], [0.08], BLACK, 8)
	k.box(Vector3(0, 0.35, -0.452), Vector3(0.44, 0.3, 0.01), METAL_DARK)      # рамка дверцы (огонь — свой блок)
	k.box(Vector3(0, 0.7, -0.452), Vector3(0.3, 0.16, 0.01), METAL_DARK)       # поддувало
	k.box(Vector3(0.12, 0.7, -0.46), Vector3(0.04, 0.02, 0.02), METAL)
	k.tube([Vector3(0.25, 1.24, 0.2), Vector3(0.25, ceiling_y, 0.2)], [0.09], METAL_DARK, 8, false, false)
	return _mi(k, &"stove", "tex_stove.png")


## Стеллаж у западной стены: полки, книги, банки. Лицевая сторона +X.
static func shelf() -> Node3D:
	var k := _kit(17)
	for sz: float in [-0.58, 0.58]:
		k.box(Vector3(0, 0.8, sz), Vector3(0.38, 1.6, 0.03), WOOD_DARK)
	k.box(Vector3(-0.18, 0.8, 0), Vector3(0.02, 1.6, 1.16), WOOD_DARK)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in range(4):
		var y := 0.05 + i * 0.45
		k.box(Vector3(0, y, 0), Vector3(0.38, 0.03, 1.16), WOOD)
		if i == 3:
			continue
		var z := -0.52
		while z < 0.5:
			var w := rng.randf_range(0.03, 0.07)
			var h := rng.randf_range(0.2, 0.32)
			if rng.randf() < 0.2:
				k.tube([Vector3(0.0, y + 0.015, z + 0.05), Vector3(0.0, y + 0.18, z + 0.05)], [0.05], Color(0.5, 0.55, 0.45, 1) * rng.randf_range(0.6, 1.0), 6)
				z += 0.13
				continue
			var c := Color.from_hsv(rng.randf_range(0.0, 0.12), rng.randf_range(0.3, 0.6), rng.randf_range(0.2, 0.45))
			k.box(Vector3(0.02, y + 0.015 + h * 0.5, z + w * 0.5), Vector3(0.24, h, w), c)
			z += w + 0.005
	return _mi(k, &"shelf", "tex_wood.png")


## Дизель-генератор на салазках: блок, рёбра цилиндра, бак, выхлоп в стену, щиток. Лицо −Z.
static func generator() -> Node3D:
	var glb := _kedr_model("generator_ab4", {"center": false, "bright": 1.0})
	if glb != null:
		return glb
	var k := _kit(18, 0.06)
	var green := Color(0.28, 0.33, 0.24)
	for sx: float in [-0.45, 0.45]:
		k.box(Vector3(sx, 0.04, 0), Vector3(0.08, 0.08, 0.62), METAL_DARK)
	k.box(Vector3(-0.15, 0.3, 0), Vector3(0.55, 0.42, 0.48), green)
	for i in range(6):
		k.box(Vector3(-0.15, 0.53 + i * 0.03, 0), Vector3(0.5, 0.012, 0.44), METAL)    # рёбра
	k.tube([Vector3(0.28, 0.32, 0.0), Vector3(0.42, 0.32, 0.0)], [0.2], RED * 1.2, 10)  # генератор-цилиндр
	k.box(Vector3(-0.15, 0.78, 0.0), Vector3(0.6, 0.14, 0.34), RED)                 # бак
	k.tube([Vector3(-0.3, 0.86, 0.0), Vector3(-0.3, 0.9, 0.0)], [0.04], BLACK, 6)    # крышка бака
	k.tube([Vector3(-0.42, 0.45, 0.1), Vector3(-0.5, 0.6, 0.25), Vector3(-0.5, 1.6, 0.3)], [0.035], METAL_DARK, 6, true, false)
	k.box(Vector3(0.3, 0.55, -0.26), Vector3(0.3, 0.2, 0.03), METAL_DARK)            # щиток
	k.tube([Vector3(0.25, 0.57, -0.28), Vector3(0.25, 0.57, -0.29)], [0.045], WHITEWASH, 8)
	k.box(Vector3(0.38, 0.52, -0.28), Vector3(0.04, 0.06, 0.02), RED)
	return _mi(k, &"generator", "tex_metal.png")


## Бочка 200 л: обручи, пробка. Начало — пол.
static func barrel() -> Node3D:
	var cached := _instance_from_cache(&"barrel", "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(19, 0.05)
	k.tube([Vector3(0, 0, 0), Vector3(0, 0.9, 0)], [0.27], RED, 12)
	for y: float in [0.25, 0.65]:
		k.tube([Vector3(0, y - 0.015, 0), Vector3(0, y + 0.015, 0)], [0.28], RED * 0.75, 12, false, false)
	k.tube([Vector3(0.12, 0.9, 0.0), Vector3(0.12, 0.92, 0.0)], [0.035], METAL_DARK, 6)
	return _mi(k, &"barrel", "tex_metal.png")


## Журнал дежурного: толстая тетрадь в тёмном переплёте, чуть раскрыта. Начало — на столе.
static func book() -> Node3D:
	var k := _kit(20, 0.03)
	k.box(Vector3(0, 0.012, 0), Vector3(0.26, 0.024, 0.34), Color(0.70, 0.67, 0.58))           # страницы
	k.box(Vector3(0, 0.026, 0), Vector3(0.27, 0.006, 0.35), Color(0.22, 0.18, 0.14))            # обложка (тёмная кожа)
	k.box(Vector3(-0.135, 0.015, 0), Vector3(0.012, 0.03, 0.35), Color(0.16, 0.12, 0.09))      # корешок
	k.box(Vector3(0.0, 0.0302, -0.05), Vector3(0.14, 0.001, 0.05), Color(0.75, 0.70, 0.60))      # наклейка
	k.tube([Vector3(0.1, 0.03, 0.12), Vector3(0.14, 0.03, -0.05)], [0.006], Color(0.25, 0.25, 0.26), 4)            # графитовый карандаш
	var mi := _mi(k, &"book")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Поленница: штабель берёзовых и еловых чурбаков под навесом на столбах. Начало — земля.
static func woodpile(length: float, depth: float) -> Node3D:
	var k := _kit(21, 0.12)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var r := 0.085
	var rows := 4
	for row in range(rows):
		var y := r + row * r * 1.75
		var n := int(length / (r * 2.05)) - (row % 2)
		for i in range(n):
			var x := -length * 0.5 + r + (row % 2) * r + i * r * 2.05
			var rr := r * rng.randf_range(0.85, 1.05)
			var birch := rng.randf() < 0.3
			var bark := Color(0.72, 0.7, 0.64) if birch else BARK * rng.randf_range(0.8, 1.2)
			var z0 := -depth * 0.5 + rng.randf_range(-0.03, 0.03)
			var z1 := depth * 0.5 + rng.randf_range(-0.03, 0.03)
			k.tube([Vector3(x, y, z0), Vector3(x, y, z0 + 0.01), Vector3(x, y, z1 - 0.01), Vector3(x, y, z1)],
				[rr], bark, 6, true, true, [LOG_END, bark, LOG_END])
	# Навес: четыре столба и скат.
	var top := rows * r * 1.75 + 0.45
	for sx: float in [-length * 0.5 - 0.05, length * 0.5 + 0.05]:
		for sz: float in [-depth * 0.5 - 0.05, depth * 0.5 + 0.05]:
			k.box(Vector3(sx, top * 0.5, sz), Vector3(0.07, top, 0.07), WOOD_DARK)
	k.box(Vector3(0, top + 0.03, 0), Vector3(length + 0.4, 0.05, depth + 0.35), WOOD_DARK, Basis(Vector3.RIGHT, deg_to_rad(8.0)))
	k.box(Vector3(0, top + 0.07, 0), Vector3(length + 0.3, 0.05, depth + 0.25), Color(0.75, 0.77, 0.82), Basis(Vector3.RIGHT, deg_to_rad(8.0)))   # снег на навесе
	return _mi(k, &"woodpile", "tex_bark.png")


## Советская металлическая канистра 20 л: штампованный корпус, выштамповка «X»,
## 3 трубчатые ручки сверху, горловина с рычажной крышкой и нижний завальцованный шов.
static func canister(held := false) -> Node3D:
	var glb := _kedr_model("fuel_canister", {"scale": 0.72 if held else 1.0, "bright": 1.05})
	if glb != null:
		return glb
	var key := &"canister_held" if held else &"canister_world"
	var cached := _instance_from_cache(key, "tex_metal.png")
	if cached != null:
		if held:
			cached.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return cached
	var k := _kit(31, 0.05)
	var scale_factor: float = 0.72 if held else 1.0
	var c_body := Color(0.26, 0.32, 0.18)   # советский защитный хаки
	var c_rim := Color(0.18, 0.22, 0.15)
	var c_metal := Color(0.35, 0.37, 0.38)
	var c_cap := Color(0.48, 0.12, 0.08)   # рыжеватый рычаг/крышка
	var s: float = scale_factor

	# Основной корпус (штампованный бак)
	k.box(Vector3(0, 0.18 * s, 0), Vector3(0.32, 0.36, 0.165) * s, c_body)
	# Нижний завальцованный шов / юбка
	k.box(Vector3(0, 0.015 * s, 0), Vector3(0.33, 0.03, 0.175) * s, c_rim)
	# Верхняя скошенная грань под ручки
	k.box(Vector3(0, 0.36 * s, 0), Vector3(0.30, 0.04, 0.15) * s, c_body)

	# Выштамповка «X» на боковинах (передней и задней)
	for sz: float in [-0.084 * s, 0.084 * s]:
		var b1 := Basis(Vector3.FORWARD, deg_to_rad(45.0))
		var b2 := Basis(Vector3.FORWARD, deg_to_rad(-45.0))
		k.box(Vector3(0, 0.18 * s, sz), Vector3(0.22 * s, 0.02 * s, 0.008 * s), c_rim, b1)
		k.box(Vector3(0, 0.18 * s, sz), Vector3(0.22 * s, 0.02 * s, 0.008 * s), c_rim, b2)
		k.box(Vector3(0, 0.28 * s, sz), Vector3(0.22 * s, 0.012 * s, 0.008 * s), c_rim)
		k.box(Vector3(0, 0.08 * s, sz), Vector3(0.22 * s, 0.012 * s, 0.008 * s), c_rim)

	# 3 верхние ручки (продольные трубки)
	for ox: float in [-0.04 * s, 0.0, 0.04 * s]:
		k.tube([
			Vector3(ox, 0.37 * s, -0.06 * s),
			Vector3(ox, 0.42 * s, -0.04 * s),
			Vector3(ox, 0.42 * s, 0.04 * s),
			Vector3(ox, 0.37 * s, 0.06 * s)
		], [0.011 * s, 0.011 * s, 0.011 * s, 0.011 * s], c_body, 6)

	# Горловина с рычажным затвором (на переднем скате)
	k.tube([
		Vector3(0.09 * s, 0.36 * s, -0.05 * s),
		Vector3(0.10 * s, 0.43 * s, -0.07 * s)
	], [0.022 * s, 0.020 * s], c_metal, 7)
	# Крышка / бугельный замок
	k.box(Vector3(0.10 * s, 0.44 * s, -0.07 * s), Vector3(0.045 * s, 0.02 * s, 0.035 * s), c_cap)
	k.tube([
		Vector3(0.08 * s, 0.44 * s, -0.07 * s),
		Vector3(0.06 * s, 0.41 * s, -0.06 * s)
	], [0.006 * s], c_metal, 4)

	var mi := _mi(k, key, "tex_metal.png")
	if held:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Охапка колотых и круглых берёзово-сосновых поленьев со спилами и верёвкой.
static func firewood_bundle(held := false) -> Node3D:
	var key := &"firewood_held" if held else &"firewood_world"
	var cached := _instance_from_cache(key, "tex_wood.png")
	if cached != null:
		if held:
			cached.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return cached
	var k := _kit(32, 0.10)
	var s: float = 0.85 if held else 1.0
	var birch_bark := Color(0.76, 0.74, 0.68)
	var pine_bark := Color(0.30, 0.20, 0.14)
	var split_wood := Color(0.62, 0.48, 0.32)
	var log_end := LOG_END
	var rope := Color(0.48, 0.42, 0.30)

	var length := 0.44 * s
	var z0 := -length * 0.5
	var z1 := length * 0.5

	# 1. Круглое берёзовое полено снизу слева
	k.tube([
		Vector3(-0.09 * s, 0.06 * s, z0),
		Vector3(-0.09 * s, 0.06 * s, z0 + 0.01),
		Vector3(-0.09 * s, 0.06 * s, z1 - 0.01),
		Vector3(-0.09 * s, 0.06 * s, z1)
	], [0.055 * s], birch_bark, 7, true, true, [log_end, birch_bark, log_end])

	# 2. Колотое полено (сосна) снизу справа
	var b_x := 0.08 * s
	var b_y := 0.06 * s
	k.box(Vector3(b_x, b_y, 0), Vector3(0.09 * s, 0.08 * s, length), split_wood)
	k.box(Vector3(b_x + 0.046 * s, b_y, 0), Vector3(0.008 * s, 0.082 * s, length), pine_bark)

	# 3. Среднее круглое полено (берёза)
	k.tube([
		Vector3(0.01 * s, 0.14 * s, z0 + 0.02 * s),
		Vector3(0.01 * s, 0.14 * s, z0 + 0.03 * s),
		Vector3(0.01 * s, 0.14 * s, z1 - 0.03 * s),
		Vector3(0.01 * s, 0.14 * s, z1 - 0.02 * s)
	], [0.052 * s], birch_bark, 7, true, true, [log_end, birch_bark, log_end])

	# 4. Верхнее колотое полено (четвертинка сосны)
	k.box(Vector3(-0.04 * s, 0.20 * s, 0), Vector3(0.075 * s, 0.065 * s, length * 0.95), split_wood, Basis(Vector3.FORWARD, deg_to_rad(15.0)))
	k.box(Vector3(-0.03 * s, 0.235 * s, 0), Vector3(0.08 * s, 0.008 * s, length * 0.95), pine_bark, Basis(Vector3.FORWARD, deg_to_rad(15.0)))

	# Веревка / джутовая бечевка вокруг охапки
	for ox: float in [-0.06 * s, 0.06 * s]:
		k.tube([
			Vector3(-0.14 * s, 0.08 * s, ox),
			Vector3(0.0, 0.01 * s, ox),
			Vector3(0.14 * s, 0.08 * s, ox),
			Vector3(0.08 * s, 0.24 * s, ox),
			Vector3(-0.08 * s, 0.24 * s, ox),
			Vector3(-0.14 * s, 0.08 * s, ox)
		], [0.007 * s], rope, 5)

	var mi := _mi(k, key, "tex_wood.png")
	if held:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Советская прямоугольная жестяная банка моторного масла МС-20 с ручкой и носиком.
static func oil_can(held := false) -> Node3D:
	var key := &"oil_held" if held else &"oil_world"
	var cached := _instance_from_cache(key, "tex_metal.png")
	if cached != null:
		if held:
			cached.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return cached
	var k := _kit(33, 0.06)
	var s: float = 0.8 if held else 1.0
	var c_tin := Color(0.18, 0.22, 0.20)     # тёмно-оливковая жесть
	var c_label := Color(0.70, 0.16, 0.12)   # красная этикетка МС-20
	var c_metal := Color(0.42, 0.44, 0.45)

	# Основная жестяная банка
	k.box(Vector3(0, 0.13 * s, 0), Vector3(0.18, 0.24, 0.11) * s, c_tin)
	# Завальцованные торцы сверху и снизу
	k.box(Vector3(0, 0.01 * s, 0), Vector3(0.188, 0.02, 0.118) * s, c_metal)
	k.box(Vector3(0, 0.25 * s, 0), Vector3(0.188, 0.02, 0.118) * s, c_metal)
	# Красная этикетка на лицевой стороне
	k.box(Vector3(0, 0.13 * s, 0.056 * s), Vector3(0.15, 0.12, 0.004) * s, c_label)
	k.box(Vector3(0, 0.13 * s, 0.058 * s), Vector3(0.12, 0.025, 0.002) * s, Color(0.9, 0.88, 0.8)) # полоска надписи

	# Металлическая проволочная ручка сверху
	k.tube([
		Vector3(-0.06 * s, 0.26 * s, 0),
		Vector3(-0.06 * s, 0.31 * s, 0),
		Vector3(0.06 * s, 0.31 * s, 0),
		Vector3(0.06 * s, 0.26 * s, 0)
	], [0.006 * s], c_metal, 5)

	# Винтовая горловина с латунной пробкой
	k.tube([
		Vector3(0.05 * s, 0.26 * s, 0.02 * s),
		Vector3(0.05 * s, 0.30 * s, 0.02 * s)
	], [0.016 * s], Color(0.65, 0.55, 0.25), 6)
	k.box(Vector3(0.05 * s, 0.305 * s, 0.02 * s), Vector3(0.038, 0.012, 0.038) * s, c_metal)

	var mi := _mi(k, key, "tex_metal.png")
	if held:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Деревянный экспедиционный ящик Семёнова с оковкой углов и надписью «КЕДР-7».
static func semenov_crate() -> Node3D:
	var cached := _instance_from_cache(&"semenov_crate", "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(34, 0.08)
	var wood := Color(0.38, 0.28, 0.18)
	var wood_dark := Color(0.24, 0.18, 0.12)
	var metal := Color(0.20, 0.22, 0.23)

	k.box(Vector3(0, 0.25, 0), Vector3(0.8, 0.48, 0.52), wood)
	for y in [0.03, 0.47]:
		k.box(Vector3(0, y, 0), Vector3(0.82, 0.05, 0.54), wood_dark)
	for sx in [-0.39, 0.39]:
		for sy in [0.04, 0.46]:
			for sz in [-0.25, 0.25]:
				k.box(Vector3(sx, sy, sz), Vector3(0.05, 0.07, 0.05), metal)
	for sx in [-0.41, 0.41]:
		k.tube([
			Vector3(sx, 0.28, -0.08),
			Vector3(sx * 1.05, 0.24, 0.0),
			Vector3(sx, 0.28, 0.08)
		], [0.012], Color(0.48, 0.42, 0.30), 5)
	k.box(Vector3(0, 0.26, 0.262), Vector3(0.38, 0.08, 0.002), Color(0.10, 0.10, 0.10))
	return _mi(k, &"semenov_crate", "tex_wood.png")


## Металлический ящик с инструментами: штампованная красная сталь, замок и ручка.
static func tools_box() -> Node3D:
	var cached := _instance_from_cache(&"tools_box", "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(35, 0.06)
	var red := Color(0.52, 0.12, 0.08)
	var metal := Color(0.32, 0.34, 0.36)

	k.box(Vector3(0, 0.10, 0), Vector3(0.56, 0.18, 0.28), red)
	k.box(Vector3(0, 0.22, 0), Vector3(0.54, 0.07, 0.26), red * 1.1)
	k.box(Vector3(0, 0.18, 0.142), Vector3(0.06, 0.08, 0.012), metal)
	k.tube([
		Vector3(-0.08, 0.26, 0),
		Vector3(-0.08, 0.30, 0),
		Vector3(0.08, 0.30, 0),
		Vector3(0.08, 0.26, 0)
	], [0.008], metal, 5)
	return _mi(k, &"tools_box", "tex_metal.png")


## Углы сруба с остатком (в чашу / в обло): выступающие брёвна по вертикали.
## dir_x (+1 или -1) и dir_z (+1 или -1) задают внешние стороны угла.
## Выпуски брёвен направлены ТОЛЬКО наружу здания и никогда не заходят внутрь комнат.
static func corner_logs(height: float, radius := 0.09, dir_x := 1.0, dir_z := 1.0) -> Node3D:
	var dx := signf(dir_x)
	var dz := signf(dir_z)
	var key := StringName("corner_logs_%.2f_%.3f_%d_%d" % [height, radius, int(dx), int(dz)])
	var cached := _instance_from_cache(key, "tex_logs.png")
	if cached != null:
		return cached
	var k := _kit(48, 0.08)
	var log_col := Color(0.42, 0.35, 0.26)
	var log_end := Color(0.55, 0.46, 0.34)
	var log_ring := Color(0.30, 0.24, 0.18)
	var moss_tow := Color(0.24, 0.26, 0.19)
	var snow_cap := Color(0.88, 0.90, 0.94)

	var step := radius * 1.85
	var count := int(height / step)
	var overhang := 0.32

	for i in range(count):
		var y := radius + i * step
		var along_x := (i % 2) == 0
		var r := radius * (0.95 + 0.1 * ((i * 7) % 3))
		if along_x:
			# Бревно идет от границы стены (внутри 4см) строго наружу в сторону dx
			var p_in := Vector3(-dx * 0.04, y, 0)
			var p_pre := Vector3(dx * (overhang - 0.02), y, 0)
			var p_out := Vector3(dx * overhang, y, 0)
			k.tube([p_in, p_pre, p_out], [r], log_col, 8, false, true, [log_col, log_col, log_end])
			k.box(Vector3(dx * (overhang + 0.005), y, 0), Vector3(0.005, r * 1.2, r * 1.2), log_ring)
		else:
			# Бревно идет от границы стены (внутри 4см) строго наружу в сторону dz
			var p_in := Vector3(0, y, -dz * 0.04)
			var p_pre := Vector3(0, y, dz * (overhang - 0.02))
			var p_out := Vector3(0, y, dz * overhang)
			k.tube([p_in, p_pre, p_out], [r], log_col, 8, false, true, [log_col, log_col, log_end])
			k.box(Vector3(0, y, dz * (overhang + 0.005)), Vector3(r * 1.2, r * 1.2, 0.005), log_ring)

		# Межвенцовая конопатка на наружном стыке
		k.box(Vector3(dx * 0.08, y - step * 0.48, dz * 0.08), Vector3(r * 1.8, 0.02, r * 1.8), moss_tow)

	# Снежная шапочка на наружном верхнем венце
	var top_y := float(count) * step
	k.box(Vector3(dx * (overhang * 0.45), top_y + 0.03, dz * (overhang * 0.45)), Vector3(overhang * 0.6, 0.05, overhang * 0.6), snow_cap)

	return _mi(k, key, "tex_logs.png")


## Ряд полупрозрачных ледяных сосулек вдоль карниза.
static func icicles(length: float, count := 8) -> Node3D:
	var key := StringName("icicles_%.2f_%d" % [length, count])
	var cached := _instance_from_cache(key, "tex_snow.png")
	if cached != null:
		cached.material_override = Palette.m(&"ice")
		return cached
	var k := _kit(37, 0.05)
	var ice_col := Color(0.85, 0.92, 0.98, 0.9)
	var rng := RandomNumberGenerator.new()
	rng.seed = 44
	var step := length / float(maxi(count, 1))
	for i in range(count):
		var x := -length * 0.5 + (i + 0.5) * step + rng.randf_range(-0.02, 0.02)
		var h := rng.randf_range(0.12, 0.38)
		var r := rng.randf_range(0.015, 0.028)
		k.spike(Vector3(x, 0, 0), Vector3(x, -h, 0), r, ice_col, 5)
	var mi := _mi(k, key, "tex_snow.png")
	mi.material_override = Palette.m(&"ice")
	return mi


## Металлическая печная труба с дефлектором-зонтиком на крыше.
static func chimney_pipe() -> Node3D:
	var cached := _instance_from_cache(&"chimney_pipe", "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(38, 0.06)
	var rust_metal := Color(0.25, 0.24, 0.22)
	var soot := Color(0.12, 0.12, 0.12)

	k.tube([
		Vector3(0, 0, 0),
		Vector3(0, 1.2, 0)
	], [0.09], rust_metal, 8, true, true)
	k.spike(Vector3(0, 1.34, 0), Vector3(0, 1.44, 0), 0.20, rust_metal, 8)
	for i in range(3):
		var a := i * TAU / 3.0
		var sx := cos(a) * 0.12
		var sz := sin(a) * 0.12
		k.tube([Vector3(sx, 1.18, sz), Vector3(sx, 1.35, sz)], [0.01], soot, 4)
	return _mi(k, &"chimney_pipe", "tex_metal.png")


## Традиционная русская печь для избы: побелка, лежанка, арочное устье (шесток),
## чугунная заслонка и кирпичный свод.
static func russian_stove() -> Node3D:
	var cached := _instance_from_cache(&"russian_stove", "tex_stove.png")
	if cached != null:
		return cached
	var k := _kit(39, 0.08)
	var whitewash := Color(0.68, 0.66, 0.62)
	var hearth_black := Color(0.08, 0.08, 0.08)
	var iron := Color(0.18, 0.19, 0.20)
	var brick := Color(0.48, 0.26, 0.18)

	k.box(Vector3(0, 0.45, 0), Vector3(1.1, 0.9, 1.3), whitewash)
	k.box(Vector3(0, 1.05, 0.15), Vector3(1.05, 0.32, 0.95), whitewash)
	k.box(Vector3(0, 0.52, -0.64), Vector3(0.52, 0.46, 0.04), hearth_black)
	k.box(Vector3(0, 0.50, -0.63), Vector3(0.48, 0.42, 0.02), iron)
	k.tube([Vector3(0, 0.50, -0.65), Vector3(0, 0.50, -0.67)], [0.015], iron, 6)
	k.box(Vector3(0.22, 1.6, -0.25), Vector3(0.42, 0.9, 0.42), brick)
	k.blob(Vector3(-0.35, 0.26, -0.52), Vector3(0.12, 0.12, 0.12), iron, 6, 7)
	k.tube([Vector3(-0.35, 0.36, -0.52), Vector3(-0.35, 0.39, -0.52)], [0.08], iron, 6)
	return _mi(k, &"russian_stove", "tex_stove.png")


## Дощатый стол из грубых плах для избы с косыми подкосами.
static func izba_table() -> Node3D:
	var cached := _instance_from_cache(&"izba_table", "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(40, 0.08)
	var wood := Color(0.34, 0.24, 0.15)
	var wood_dark := Color(0.22, 0.15, 0.10)

	k.box(Vector3(0, 0.72, 0), Vector3(1.3, 0.06, 0.75), wood)
	for sx in [-0.5, 0.5]:
		k.box(Vector3(sx, 0.34, -0.26), Vector3(0.08, 0.68, 0.08), wood_dark, Basis(Vector3.FORWARD, deg_to_rad(8.0 * (1.0 if sx > 0 else -1.0))))
		k.box(Vector3(sx, 0.34, 0.26), Vector3(0.08, 0.68, 0.08), wood_dark, Basis(Vector3.FORWARD, deg_to_rad(8.0 * (1.0 if sx > 0 else -1.0))))
		k.box(Vector3(sx, 0.16, 0), Vector3(0.06, 0.06, 0.58), wood_dark)
	k.box(Vector3(0, 0.16, 0), Vector3(0.96, 0.05, 0.06), wood_dark)
	return _mi(k, &"izba_table", "tex_wood.png")


## Широкая лавка из массивной плахи.
static func izba_bench() -> Node3D:
	var cached := _instance_from_cache(&"izba_bench", "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(41, 0.08)
	var wood := Color(0.32, 0.23, 0.14)
	var wood_dark := Color(0.20, 0.14, 0.09)
	k.box(Vector3(0, 0.42, 0), Vector3(1.4, 0.05, 0.32), wood)
	for sx in [-0.55, 0.55]:
		k.box(Vector3(sx, 0.20, 0), Vector3(0.08, 0.40, 0.26), wood_dark)
	k.box(Vector3(0, 0.16, 0), Vector3(1.05, 0.04, 0.05), wood_dark)
	return _mi(k, &"izba_bench", "tex_wood.png")


## Божница в красном углу: резная деревянная полочка, потемневший складень и рушник.
static func icon_corner() -> Node3D:
	var cached := _instance_from_cache(&"icon_corner", "tex_cloth.png")
	if cached != null:
		return cached
	var k := _kit(42, 0.05)
	var wood := Color(0.28, 0.19, 0.12)
	var gold_dark := Color(0.55, 0.44, 0.20)
	var cloth := Color(0.78, 0.76, 0.70)
	var red_thread := Color(0.65, 0.15, 0.12)

	k.box(Vector3(0, 0, 0), Vector3(0.38, 0.025, 0.38), wood)
	k.box(Vector3(0, 0.15, 0), Vector3(0.24, 0.28, 0.03), wood)
	k.box(Vector3(0, 0.15, 0.016), Vector3(0.18, 0.22, 0.005), gold_dark)
	k.box(Vector3(0, 0.20, 0.018), Vector3(0.08, 0.09, 0.004), Color(0.32, 0.25, 0.18))
	for sx in [-0.14, 0.14]:
		k.box(Vector3(sx, -0.12, 0.16), Vector3(0.08, 0.25, 0.01), cloth)
		k.box(Vector3(sx, -0.22, 0.162), Vector3(0.08, 0.03, 0.006), red_thread)
	return _mi(k, &"icon_corner", "tex_cloth.png")


## Заколоченное окно: крест-накрест прибитые серые выветренные доски.
static func boarded_window(size := Vector2(0.8, 1.0)) -> Node3D:
	var key := StringName("boarded_window_%.2f_%.2f" % [size.x, size.y])
	var cached := _instance_from_cache(key, "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(43, 0.09)
	var plank := Color(0.35, 0.32, 0.28)
	var nail := Color(0.15, 0.15, 0.16)

	for i in range(3):
		var y := -size.y * 0.35 + i * (size.y * 0.35)
		k.box(Vector3(0, y, 0.01), Vector3(size.x * 1.15, 0.12, 0.02), plank)
		for sx in [-size.x * 0.45, size.x * 0.45]:
			k.box(Vector3(sx, y, 0.022), Vector3(0.015, 0.015, 0.005), nail)
	var diag_len := Vector2(size.x, size.y).length() * 1.05
	var angle := atan2(size.y, size.x)
	k.box(Vector3(0, 0, 0.03), Vector3(diag_len, 0.11, 0.02), plank * 0.9, Basis(Vector3.FORWARD, angle))
	return _mi(k, key, "tex_wood.png")


## Рыбацкий верстак: грубый стол, чугунные тиски, смотанные леера и ледобур.
static func lake_workbench() -> Node3D:
	var cached := _instance_from_cache(&"lake_workbench", "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(44, 0.08)
	var wood := Color(0.28, 0.22, 0.16)
	var wood_dark := Color(0.18, 0.14, 0.10)
	var metal := Color(0.32, 0.34, 0.36)
	var steel_bright := Color(0.60, 0.62, 0.65)

	k.box(Vector3(0, 0.68, 0), Vector3(1.6, 0.08, 0.65), wood)
	for sx in [-0.7, 0.7]:
		for sz in [-0.24, 0.24]:
			k.box(Vector3(sx, 0.32, sz), Vector3(0.09, 0.64, 0.09), wood_dark)
	k.box(Vector3(0, 0.18, 0), Vector3(1.35, 0.04, 0.5), wood_dark)
	k.box(Vector3(-0.6, 0.78, 0.22), Vector3(0.16, 0.12, 0.14), metal)
	k.box(Vector3(-0.6, 0.81, 0.30), Vector3(0.14, 0.05, 0.03), metal)
	k.tube([Vector3(-0.6, 0.78, 0.30), Vector3(-0.6, 0.78, 0.38)], [0.015], steel_bright, 6)
	k.tube([Vector3(0.4, 0.1, -0.1), Vector3(0.55, 0.95, -0.1)], [0.018], Color(0.15, 0.38, 0.62), 6)
	k.tube([Vector3(0.4, 0.1, -0.1), Vector3(0.46, 0.45, -0.1)], [0.065], steel_bright, 6)
	return _mi(k, &"lake_workbench", "tex_wood.png")


## Советский эмалированный чайник: корпус, носик, дуговая ручка с накладкой, крышка.
static func kettle() -> Node3D:
	var glb := _kedr_model("soviet_kettle", {"scale": 1.0, "bright": 1.1})
	if glb != null:
		return glb
	var cached := _instance_from_cache(&"kettle", "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(52, 0.05)
	var enamel := Color(0.22, 0.40, 0.46)
	var enamel_dark := Color(0.12, 0.16, 0.18)
	var wood_handle := Color(0.38, 0.24, 0.14)

	# Корпус (конический цилиндр)
	k.tube([Vector3(0, 0.01, 0), Vector3(0, 0.14, 0)], [0.088, 0.075], enamel, 10)
	k.tube([Vector3(0, 0.138, 0), Vector3(0, 0.145, 0)], [0.077, 0.072], enamel_dark, 10)

	# Крышка
	k.tube([Vector3(0, 0.145, 0), Vector3(0, 0.165, 0)], [0.065, 0.05], enamel, 8)
	k.tube([Vector3(0, 0.165, 0), Vector3(0, 0.185, 0)], [0.015, 0.015], enamel_dark, 6)

	# Носик
	k.tube([Vector3(0.06, 0.04, 0), Vector3(0.11, 0.09, 0), Vector3(0.13, 0.14, 0)], [0.024, 0.02, 0.016], enamel, 6)

	# Дуговая металлическая ручка
	k.tube([Vector3(-0.065, 0.13, 0), Vector3(-0.06, 0.22, 0), Vector3(0.06, 0.22, 0), Vector3(0.065, 0.13, 0)], [0.007], enamel_dark, 6, false, false)
	# Деревянная рукоять на дужке
	k.tube([Vector3(-0.035, 0.22, 0), Vector3(0.035, 0.22, 0)], [0.016], wood_handle, 6, false, false)

	return _mi(k, &"kettle", "tex_metal.png")


## Следы глубоких когтей на досках двери/стен.
static func claw_scratches() -> Node3D:
	var cached := _instance_from_cache(&"claw_scratches")
	if cached != null:
		return cached
	var k := _kit(53, 0.02)
	var scratch_raw := Color(0.65, 0.52, 0.36)
	var scratch_shadow := Color(0.12, 0.08, 0.05)

	for i in range(4):
		var x_off := -0.06 + i * 0.038
		var curve := (i - 1.5) * 0.015
		var len_var := 0.22 + (i % 2) * 0.05
		k.tube([
			Vector3(x_off, len_var * 0.5, 0.005),
			Vector3(x_off + curve, 0.0, 0.008),
			Vector3(x_off + curve * 1.8, -len_var * 0.5, 0.005)
		], [0.008, 0.011, 0.006], scratch_shadow, 5)
		k.tube([
			Vector3(x_off + 0.004, len_var * 0.45, 0.007),
			Vector3(x_off + curve + 0.004, 0.0, 0.010),
			Vector3(x_off + curve * 1.8 + 0.004, -len_var * 0.45, 0.007)
		], [0.004, 0.005, 0.003], scratch_raw, 4)
	return _mi(k, &"claw_scratches")


## Отпечаток неестественно длиннопалой ладони на морозном стекле.
static func frost_handprint() -> Node3D:
	var root := Node3D.new()
	root.name = "FrostHandprint"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.9, 0.95, 1.0, 0.45)

	var palm := Geo.box_mesh(Vector3(0.09, 0.11, 0.004), mat)
	root.add_child(palm)

	var angles := [-28.0, -14.0, 0.0, 16.0, 32.0]
	var lengths := [0.12, 0.16, 0.18, 0.15, 0.11]
	for idx in range(5):
		var ang: float = deg_to_rad(angles[idx])
		var flen: float = lengths[idx]
		var f := Geo.box_mesh(Vector3(0.014, flen, 0.004), mat)
		f.position = Vector3(sin(ang) * (flen * 0.5 + 0.05), cos(ang) * (flen * 0.5 + 0.04), 0.0)
		f.rotation.z = -ang
		root.add_child(f)
	return root


## Лаз на чердак: массивная дощатая крышка с петлями и свисающей верёвкой с узлом.
static func attic_hatch() -> Node3D:
	var cached := _instance_from_cache(&"attic_hatch", "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(61, 0.07)
	var wood := Color(0.32, 0.22, 0.14)
	var wood_dark := Color(0.20, 0.14, 0.09)
	var iron := Color(0.18, 0.18, 0.20)
	var rope := Color(0.55, 0.48, 0.36)

	# Косяк рамы лаза
	k.box(Vector3(0, 0, -0.42), Vector3(0.94, 0.06, 0.08), wood_dark)
	k.box(Vector3(0, 0, 0.42), Vector3(0.94, 0.06, 0.08), wood_dark)
	k.box(Vector3(-0.42, 0, 0), Vector3(0.08, 0.06, 0.78), wood_dark)
	k.box(Vector3(0.42, 0, 0), Vector3(0.08, 0.06, 0.78), wood_dark)
	# Дощатый щит люка
	k.box(Vector3(0, 0.02, 0), Vector3(0.78, 0.035, 0.78), wood)
	# Поперечные бруски
	k.box(Vector3(0, 0.04, -0.22), Vector3(0.76, 0.03, 0.07), wood_dark)
	k.box(Vector3(0, 0.04, 0.22), Vector3(0.76, 0.03, 0.07), wood_dark)
	# Кованые железные петли
	k.box(Vector3(-0.25, 0.045, -0.36), Vector3(0.06, 0.015, 0.22), iron)
	k.box(Vector3(0.25, 0.045, -0.36), Vector3(0.06, 0.015, 0.22), iron)
	# Засов и железное кольцо
	k.box(Vector3(0, 0.045, 0.34), Vector3(0.18, 0.02, 0.04), iron)
	k.tube([Vector3(0, 0.04, 0.34), Vector3(0, -0.05, 0.34)], [0.012], iron, 6)
	# Свисающий пеньковый канат с узлом на конце
	k.tube([
		Vector3(0, -0.05, 0.34),
		Vector3(0.02, -0.25, 0.35),
		Vector3(-0.01, -0.50, 0.33),
		Vector3(0.01, -0.72, 0.34)
	], [0.014], rope, 6, false, false)
	# Узел на конце каната
	k.blob(Vector3(0.01, -0.74, 0.34), Vector3(0.035, 0.045, 0.035), rope, 4, 6)
	return _mi(k, &"attic_hatch", "tex_wood.png")


## Стеллаж с резервными щелочными аккумуляторами (аккумуляторная станции).
static func battery_rack() -> Node3D:
	var cached := _instance_from_cache(&"battery_rack", "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(62, 0.06)
	var iron := Color(0.22, 0.23, 0.25)
	var battery_jar := Color(0.12, 0.12, 0.13)
	var terminal_copper := Color(0.72, 0.42, 0.22)
	var wire_black := Color(0.08, 0.08, 0.09)

	# Сварной каркас из угловой стали
	for sx in [-0.58, 0.58]:
		for sz in [-0.22, 0.22]:
			k.box(Vector3(sx, 0.55, sz), Vector3(0.05, 1.1, 0.05), iron)
	# 2 яруса полок
	for y in [0.25, 0.72]:
		k.box(Vector3(0, y, 0), Vector3(1.22, 0.04, 0.48), iron)
		# Батареи 5НК-125 в рядах
		for i in range(5):
			var bx := -0.46 + i * 0.23
			for bz in [-0.12, 0.12]:
				k.box(Vector3(bx, y + 0.16, bz), Vector3(0.18, 0.28, 0.18), battery_jar)
				k.tube([Vector3(bx - 0.05, y + 0.30, bz), Vector3(bx - 0.05, y + 0.34, bz)], [0.012], terminal_copper, 6)
				k.tube([Vector3(bx + 0.05, y + 0.30, bz), Vector3(bx + 0.05, y + 0.34, bz)], [0.012], terminal_copper, 6)
				# Медные перемычки
				k.box(Vector3(bx, y + 0.34, bz), Vector3(0.10, 0.008, 0.015), terminal_copper)
	# Толстый кабель питания, уходящий в пол
	k.tube([Vector3(0.55, 0.85, 0.15), Vector3(0.58, 0.4, 0.22), Vector3(0.58, 0.0, 0.22)], [0.022], wire_black, 6, false, false)
	return _mi(k, &"battery_rack", "tex_metal.png")


## Полки холодной кладовой: коробки с радиолампами, керосинка, банки.
static func storage_shelves() -> Node3D:
	var cached := _instance_from_cache(&"storage_shelves", "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(63, 0.08)
	var wood := Color(0.35, 0.26, 0.18)
	var wood_dark := Color(0.22, 0.16, 0.10)
	var cardboard := Color(0.55, 0.44, 0.30)
	var lantern_metal := Color(0.18, 0.22, 0.25)
	var glass := Color(0.70, 0.82, 0.88)

	# Стеллаж
	for sx in [-0.68, 0.68]:
		for sz in [-0.18, 0.18]:
			k.box(Vector3(sx, 0.85, sz), Vector3(0.06, 1.7, 0.06), wood_dark)
	for y in [0.35, 0.80, 1.25, 1.65]:
		k.box(Vector3(0, y, 0), Vector3(1.42, 0.04, 0.42), wood)

	# Коробки с лампами на верхней полке
	for i in range(4):
		k.box(Vector3(-0.45 + i * 0.18, 1.34, -0.05), Vector3(0.15, 0.14, 0.18), cardboard)
		k.box(Vector3(-0.45 + i * 0.18, 1.34, 0.042), Vector3(0.12, 0.06, 0.005), Color(0.85, 0.82, 0.75))

	# Керосиновая лампа «Летучая мышь» на средней полке
	k.tube([Vector3(0.40, 0.82, 0.0), Vector3(0.40, 0.90, 0.0)], [0.07, 0.05], lantern_metal, 8)
	k.tube([Vector3(0.40, 0.90, 0.0), Vector3(0.40, 1.05, 0.0)], [0.045, 0.04], glass, 8)
	k.tube([Vector3(0.40, 1.05, 0.0), Vector3(0.40, 1.12, 0.0)], [0.055, 0.035], lantern_metal, 8)
	k.tube([Vector3(0.33, 0.92, 0.0), Vector3(0.33, 1.14, 0.0), Vector3(0.47, 1.14, 0.0), Vector3(0.47, 0.92, 0.0)], [0.008], lantern_metal, 4, false, false)

	# Стеклянные банки на нижней полке
	for j in range(3):
		k.tube([Vector3(-0.35 + j * 0.22, 0.37, 0.0), Vector3(-0.35 + j * 0.22, 0.58, 0.0)], [0.065], glass * 0.75, 8)
		k.tube([Vector3(-0.35 + j * 0.22, 0.58, 0.0), Vector3(-0.35 + j * 0.22, 0.61, 0.0)], [0.045], lantern_metal, 8)

	return _mi(k, &"storage_shelves", "tex_wood.png")


## Легендарный советский снегоход «Буран» СБ-640:
## Однолыжная компоновка с рессорой, две широкие гусеницы, катки, клиновидный оранжевый капот
## с фарой и вентиляцией, ветровое стекло, мотоциклетный руль, двухместное сиденье,
## частично откинутый армейский брезент с верёвками и инеем.
static func snowmobile_tarp() -> Node3D:
	var cached := _instance_from_cache(&"snowmobile_tarp", "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(64, 0.06)
	var buran_orange := Color(0.85, 0.42, 0.14)      # Классический оранжевый капот «Бурана»
	var buran_cream := Color(0.82, 0.80, 0.74)       # Кремово-белая полоса/боковина
	var frame_steel := Color(0.18, 0.20, 0.22)       # Стальная рама и подвеска
	var metal_dark := Color(0.12, 0.13, 0.14)
	var rubber_track := Color(0.10, 0.11, 0.11)      # Гусеницы и катки
	var seat_leather := Color(0.14, 0.14, 0.15)      # Чёрный дерматин сиденья
	var chrome := Color(0.78, 0.80, 0.84)            # Ободок фары, стекло
	var glass := Color(0.88, 0.92, 0.96, 0.85)       # Ветровое стекло
	var tarp := Color(0.25, 0.29, 0.22)              # Армейский брезент
	var tarp_shadow := Color(0.15, 0.18, 0.13)
	var rope := Color(0.50, 0.44, 0.32)              # Пеньковая верёвка
	var frost := Color(0.85, 0.88, 0.94)

	# 1. СТАЛЬНАЯ РАМА И ТУННЕЛЬ ГУСЕНИЦ
	# Центральный туннель под сиденьем
	k.box(Vector3(0, 0.36, -0.42), Vector3(0.74, 0.32, 1.48), frame_steel)
	# Подножки вдоль обоих бортов
	for sx: float in [-0.44, 0.44]:
		k.box(Vector3(sx, 0.20, -0.35), Vector3(0.14, 0.03, 1.45), frame_steel)
		# Резиновые противоскользящие накладки
		k.box(Vector3(sx, 0.22, -0.35), Vector3(0.11, 0.012, 1.35), rubber_track)
		# Отбортовка (боковой защитный кант)
		k.box(Vector3(sx + (0.07 if sx > 0 else -0.07), 0.24, -0.35), Vector3(0.015, 0.06, 1.45), frame_steel)
	# Задний трубчатый бампер-поручень
	k.tube([Vector3(-0.42, 0.22, -1.18), Vector3(-0.42, 0.46, -1.24), Vector3(0.42, 0.46, -1.24), Vector3(0.42, 0.22, -1.18)], [0.016], frame_steel, 6, false, false)
	# Задний резиновый брызговик
	k.box(Vector3(0, 0.22, -1.20), Vector3(0.68, 0.28, 0.02), rubber_track)

	# 2. ДВЕ ШИРОКИЕ ГУСЕНИЦЫ И КАТКИ («Буран» славен 2 гусеницами!)
	for tx: float in [-0.20, 0.20]:
		# Нижняя опорная лента гусеницы
		k.box(Vector3(tx, 0.035, -0.38), Vector3(0.32, 0.045, 1.46), rubber_track)
		# Передний наклонный заход гусеницы на звездочку
		k.box(Vector3(tx, 0.12, 0.42), Vector3(0.32, 0.045, 0.26), rubber_track, Basis(Vector3.RIGHT, deg_to_rad(-26.0)))
		# Задний подгиб вокруг натяжного катка
		k.box(Vector3(tx, 0.10, -1.14), Vector3(0.32, 0.045, 0.18), rubber_track, Basis(Vector3.RIGHT, deg_to_rad(28.0)))
		# Грунтозацепы на гусенице
		for i in range(7):
			var z_lug: float = -1.0 + i * 0.22
			k.box(Vector3(tx, 0.015, z_lug), Vector3(0.30, 0.018, 0.04), metal_dark)
		# Опорные катки (тележки) внутри гусениц
		for z_bog: float in [-0.85, -0.45, -0.05]:
			k.tube([Vector3(tx - 0.12, 0.09, z_bog), Vector3(tx + 0.12, 0.09, z_bog)], [0.065], frame_steel, 8)
			k.tube([Vector3(tx - 0.13, 0.09, z_bog), Vector3(tx + 0.13, 0.09, z_bog)], [0.04], chrome, 6)

	# 3. ЕДИНСТВЕННАЯ ПЕРЕДНЯЯ ЛЫЖА И ЛИСТОВАЯ РЕССОРА
	# Стальная штампованная лыжа с загнутым носком
	k.box(Vector3(0, 0.025, 0.98), Vector3(0.24, 0.025, 0.72), frame_steel)
	# Загнутый вверх носок лыжи
	k.box(Vector3(0, 0.09, 1.38), Vector3(0.22, 0.022, 0.22), frame_steel, Basis(Vector3.RIGHT, deg_to_rad(-38.0)))
	k.tube([Vector3(-0.09, 0.17, 1.48), Vector3(0.09, 0.17, 1.48)], [0.015], frame_steel, 6) # носовая скоба
	# Центральный подрез снизу лыжи
	k.box(Vector3(0, 0.006, 0.98), Vector3(0.02, 0.015, 0.65), metal_dark)
	# Многолистовая полуэллиптическая рессора над лыжей
	for leaf in range(3):
		var w_leaf: float = 0.44 - leaf * 0.09
		var y_leaf: float = 0.05 + leaf * 0.022
		k.box(Vector3(0, y_leaf, 0.98), Vector3(0.065, 0.018, w_leaf), frame_steel)
	# Стремянки и центральный поворотный шпиндель
	k.tube([Vector3(0, 0.11, 0.98), Vector3(0, 0.38, 0.92)], [0.032], frame_steel, 8)

	# 4. КАПОТ «БУРАНА» (характерный клиновидный советский нос)
	# Нижняя часть капота
	k.box(Vector3(0, 0.40, 0.72), Vector3(0.76, 0.28, 0.92), buran_orange)
	# Верхний наклонный скат капота
	k.box(Vector3(0, 0.60, 0.68), Vector3(0.72, 0.24, 0.84), buran_orange, Basis(Vector3.RIGHT, deg_to_rad(-16.0)))
	# Белые декоративные молдинги по бокам капота
	for sx: float in [-0.382, 0.382]:
		k.box(Vector3(sx, 0.44, 0.72), Vector3(0.005, 0.06, 0.86), buran_cream)
	# Решётка забора воздуха охлаждения на капоте (продольные щели)
	for i in range(4):
		k.box(Vector3(0, 0.68 + i * 0.015, 0.86 - i * 0.06), Vector3(0.38, 0.01, 0.035), metal_dark)
	# Крупная прямоугольная фара в хромированном ободке
	k.box(Vector3(0, 0.62, 1.14), Vector3(0.24, 0.15, 0.04), chrome, Basis(Vector3.RIGHT, deg_to_rad(-16.0)))
	k.box(Vector3(0, 0.62, 1.16), Vector3(0.20, 0.12, 0.02), Color(0.95, 0.96, 0.90), Basis(Vector3.RIGHT, deg_to_rad(-16.0)))

	# 5. ДВИГАТЕЛЬ РМЗ-640 (приоткрыт с правой стороны)
	# Алюминиевый картер и 2 ребристых цилиндра
	k.box(Vector3(0.18, 0.38, 0.55), Vector3(0.28, 0.22, 0.28), frame_steel)
	for i in range(5):
		k.box(Vector3(0.18, 0.48 + i * 0.025, 0.55), Vector3(0.24, 0.012, 0.24), chrome) # ребра охлаждения
	# Свечные колпачки и проводка
	k.tube([Vector3(0.18, 0.61, 0.50), Vector3(0.18, 0.64, 0.50)], [0.015], Color(0.6, 0.15, 0.1), 6)
	k.tube([Vector3(0.18, 0.61, 0.60), Vector3(0.18, 0.64, 0.60)], [0.015], Color(0.6, 0.15, 0.1), 6)
	# Снятое магнето (пустое гнездо с висящими оборванными проводами)
	k.tube([Vector3(0.34, 0.38, 0.55), Vector3(0.38, 0.38, 0.55)], [0.05], metal_dark, 8)
	k.tube([Vector3(0.36, 0.36, 0.52), Vector3(0.39, 0.30, 0.48), Vector3(0.36, 0.24, 0.46)], [0.006], Color(0.8, 0.2, 0.1), 4, false, false)
	# Т-образная ручка ручного стартера
	k.box(Vector3(0.26, 0.68, 0.42), Vector3(0.08, 0.02, 0.02), rubber_track)

	# 6. ПРИБОРНАЯ ПАНЕЛЬ И ВЫСОКОЕ ВЕТРОВОЕ СТЕКЛО
	# Консоль приборов
	k.box(Vector3(0, 0.74, 0.34), Vector3(0.58, 0.18, 0.18), metal_dark)
	# Круглый спидометр со шкалой
	k.tube([Vector3(-0.12, 0.81, 0.33), Vector3(-0.12, 0.84, 0.31)], [0.045], chrome, 8)
	k.tube([Vector3(-0.12, 0.84, 0.31), Vector3(-0.12, 0.845, 0.305)], [0.04], Color(0.9, 0.9, 0.85), 8)
	# Ветровое стекло с резиновой окантовкой
	k.box(Vector3(0, 0.96, 0.40), Vector3(0.66, 0.32, 0.015), glass, Basis(Vector3.RIGHT, deg_to_rad(-24.0)))
	k.box(Vector3(0, 0.81, 0.34), Vector3(0.68, 0.03, 0.02), rubber_track) # резиновый уплотнитель

	# 7. МОТОЦИКЛЕТНЫЙ РУЛЬ «БУРАНА»
	# Рулевая колонка
	k.tube([Vector3(0, 0.72, 0.32), Vector3(0, 0.92, 0.25)], [0.02], frame_steel, 6)
	# Поперечина руля
	k.tube([Vector3(-0.36, 0.95, 0.24), Vector3(0.36, 0.95, 0.24)], [0.014], frame_steel, 6, false, false)
	# Резиновые рифленые рукоятки
	for sx: float in [-0.34, 0.34]:
		k.tube([Vector3(sx + (-0.05 if sx < 0 else 0.01), 0.95, 0.24), Vector3(sx + (-0.01 if sx < 0 else 0.05), 0.95, 0.24)], [0.022], rubber_track, 8)
	# Мягкий защитный валик на руле
	k.tube([Vector3(-0.14, 0.95, 0.24), Vector3(0.14, 0.95, 0.24)], [0.028], Color(0.6, 0.15, 0.12), 8)
	# Рычаг тормоза слева
	k.box(Vector3(-0.28, 0.93, 0.26), Vector3(0.09, 0.01, 0.02), chrome)

	# 8. ДВУХМЕСТНОЕ СИДЕНЬЕ
	# Мягкая подушка из дерматина
	k.box(Vector3(0, 0.54, -0.22), Vector3(0.44, 0.18, 0.86), seat_leather)
	# Продольные строчки и мягкий рельеф
	for i in range(5):
		k.box(Vector3(0, 0.635, -0.55 + i * 0.16), Vector3(0.42, 0.01, 0.02), Color(0.08, 0.08, 0.08))
	# Ремешок пассажира поперек сиденья
	k.box(Vector3(0, 0.56, -0.15), Vector3(0.46, 0.025, 0.035), Color(0.2, 0.2, 0.22))

	# 9. ХУДОЖЕСТВЕННЫЙ АРМЕЙСКИЙ БРЕЗЕНТ, СТЯНУТЫЙ К КОРМЕ
	# Брезент покрывает заднюю часть машины, багажник и спадает на подножки
	k.box(Vector3(0, 0.58, -0.72), Vector3(0.68, 0.32, 0.62), tarp)
	# Складки и провисания брезента
	k.box(Vector3(0, 0.52, -1.02), Vector3(0.72, 0.40, 0.38), tarp_shadow, Basis(Vector3.RIGHT, deg_to_rad(12.0)))
	for sx: float in [-0.36, 0.36]:
		k.box(Vector3(sx, 0.42, -0.75), Vector3(0.08, 0.36, 0.75), tarp_shadow)
	# Завязанные стягивающие верёвки
	for z_rope: float in [-0.55, -0.92]:
		k.tube([Vector3(-0.42, 0.22, z_rope), Vector3(-0.35, 0.74, z_rope), Vector3(0.35, 0.74, z_rope), Vector3(0.42, 0.22, z_rope)], [0.014], rope, 4, false, false)
	# Намёты снега и корка инея на брезенте
	k.box(Vector3(0, 0.75, -0.74), Vector3(0.56, 0.015, 0.48), frost)
	k.box(Vector3(0.08, 0.68, -0.98), Vector3(0.45, 0.015, 0.24), frost)

	return _mi(k, &"snowmobile_tarp", "tex_metal.png")


## Советский гусеничный вездеход-тягач ГТ-Т:
## Бронированный водоизмещающий нос «лодка», 6 катков на борт, гусеницы с грунтозацепами,
## кабина с остеклением, люками, фарами в защитных решётках, выхлопная труба с крышкой,
## грузовой кузов с дугами и армейским брезентом.
static func tracked_vehicle() -> Node3D:
	var cached := _instance_from_cache(&"tracked_vehicle", "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(75, 0.05)
	var green := Color(0.24, 0.32, 0.18)            # Защитный советский армейский хаки
	var green_dark := Color(0.16, 0.22, 0.12)
	var green_camo := Color(0.20, 0.26, 0.15)
	var frame_steel := Color(0.18, 0.19, 0.20)
	var track_rubber := Color(0.11, 0.11, 0.12)     # Траки гусениц
	var glass := Color(0.85, 0.90, 0.95, 0.9)
	var tarp := Color(0.28, 0.33, 0.24)             # Брезентовый тент кузова
	var tarp_shadow := Color(0.18, 0.22, 0.15)
	var chrome := Color(0.72, 0.75, 0.78)

	# 1. ВОДОИЗМЕЩАЮЩИЙ НОСОВОЙ КОРПУС («ЛОДКА» ГТ-Т)
	k.box(Vector3(0, 0.72, -1.8), Vector3(2.5, 0.65, 1.2), green_dark, Basis(Vector3.RIGHT, deg_to_rad(-24.0)))
	k.box(Vector3(0, 0.95, 0.3), Vector3(2.5, 0.85, 3.8), green)
	k.box(Vector3(0, 0.95, -2.32), Vector3(2.4, 0.18, 0.05), green_dark)
	for hx: float in [-0.85, 0.85]:
		k.tube([Vector3(hx, 0.75, -2.35), Vector3(hx, 0.60, -2.40)], [0.035], frame_steel, 6)

	# 2. КАБИНА ЭКИПАЖА
	k.box(Vector3(0, 1.55, -1.1), Vector3(2.3, 0.65, 0.9), green, Basis(Vector3.RIGHT, deg_to_rad(18.0)))
	k.box(Vector3(0, 1.95, -0.7), Vector3(2.3, 0.12, 1.1), green_dark)
	for wx: float in [-0.55, 0.55]:
		k.box(Vector3(wx, 1.62, -1.48), Vector3(0.75, 0.42, 0.02), glass, Basis(Vector3.RIGHT, deg_to_rad(18.0)))
		k.box(Vector3(wx, 1.62, -1.47), Vector3(0.80, 0.46, 0.01), Color(0.08, 0.08, 0.08), Basis(Vector3.RIGHT, deg_to_rad(18.0)))
		k.box(Vector3(wx, 1.62, -1.50), Vector3(0.02, 0.35, 0.01), frame_steel, Basis(Vector3.RIGHT, deg_to_rad(18.0)))
	for lx: float in [-0.55, 0.55]:
		k.box(Vector3(lx, 2.02, -0.65), Vector3(0.65, 0.04, 0.65), green)
	k.tube([Vector3(0, 2.02, -1.0), Vector3(0, 2.22, -1.0)], [0.025], frame_steel, 6)
	k.blob(Vector3(0, 2.26, -1.0), Vector3(0.11, 0.11, 0.11), chrome, 4, 8)

	# 3. ФАРЫ В ЗАЩИТНЫХ РЕШЁТКАХ
	for fx: float in [-0.95, 0.95]:
		k.blob(Vector3(fx, 1.25, -2.15), Vector3(0.12, 0.12, 0.12), chrome, 4, 8)
		k.tube([Vector3(fx - 0.15, 1.25, -2.25), Vector3(fx + 0.15, 1.25, -2.25)], [0.012], frame_steel, 4, false, false)
		k.tube([Vector3(fx, 1.10, -2.25), Vector3(fx, 1.40, -2.25)], [0.012], frame_steel, 4, false, false)

	# 4. ГУСЕНИЧНЫЙ ДВИЖИТЕЛЬ (6 КАТКОВ НА БОРТ + ЗВЕЗДОЧКА И ЛЕНИВЕЦ)
	for side: float in [-1.0, 1.0]:
		var tx: float = side * 1.35
		k.box(Vector3(tx, 0.92, -0.1), Vector3(0.52, 0.06, 4.6), green_dark)
		k.box(Vector3(tx, 0.65, -2.35), Vector3(0.50, 0.45, 0.03), Color(0.1, 0.1, 0.1), Basis(Vector3.RIGHT, deg_to_rad(-15.0)))
		k.box(Vector3(tx, 0.55, 2.15), Vector3(0.50, 0.50, 0.03), Color(0.1, 0.1, 0.1))

		k.box(Vector3(tx, 0.04, -0.1), Vector3(0.44, 0.06, 4.2), track_rubber)
		k.box(Vector3(tx, 0.72, -0.1), Vector3(0.44, 0.05, 4.1), track_rubber)
		k.box(Vector3(tx, 0.40, -2.15), Vector3(0.44, 0.05, 0.55), track_rubber, Basis(Vector3.RIGHT, deg_to_rad(-45.0)))
		k.box(Vector3(tx, 0.40, 1.95), Vector3(0.44, 0.05, 0.55), track_rubber, Basis(Vector3.RIGHT, deg_to_rad(45.0)))

		for i in range(12):
			var z_tr: float = -1.9 + i * 0.35
			k.box(Vector3(tx, 0.015, z_tr), Vector3(0.42, 0.02, 0.05), frame_steel)

		for w in range(6):
			var zw: float = -1.6 + w * 0.65
			k.tube([Vector3(tx - 0.15, 0.36, zw), Vector3(tx + 0.15, 0.36, zw)], [0.32], green_camo, 12)
			k.tube([Vector3(tx - 0.16, 0.36, zw), Vector3(tx + 0.16, 0.36, zw)], [0.12], frame_steel, 8)

	# 5. ВЫХЛОПНАЯ ТРУБА С ЗАЩИТНЫМ КОЖУХОМ
	k.tube([Vector3(0.85, 1.45, -0.1), Vector3(0.85, 2.35, -0.1)], [0.065], frame_steel, 8)
	k.box(Vector3(0.85, 2.38, -0.06), Vector3(0.15, 0.015, 0.15), frame_steel, Basis(Vector3.RIGHT, deg_to_rad(20.0)))

	# 6. ГРУЗОВОЙ КУЗОВ С БРЕЗЕНТОВЫМ ТЕНТОМ НА ДУГАХ
	k.box(Vector3(0, 1.25, 0.95), Vector3(2.4, 0.55, 2.4), green)
	for az: float in [-0.15, 0.65, 1.45, 2.1]:
		k.tube([Vector3(-1.15, 1.5, az), Vector3(-1.15, 2.25, az), Vector3(1.15, 2.25, az), Vector3(1.15, 1.5, az)], [0.022], frame_steel, 6, false, false)
	k.box(Vector3(0, 2.05, 0.98), Vector3(2.34, 0.55, 2.35), tarp)
	k.box(Vector3(0, 2.32, 0.98), Vector3(2.1, 0.12, 2.3), tarp_shadow)

	return _mi(k, &"tracked_vehicle", "tex_metal.png")


## Колода с топором-колуном у поленницы.
static func axe_stump() -> Node3D:
	var cached := _instance_from_cache(&"axe_stump", "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(65, 0.08)
	var bark := Color(0.24, 0.17, 0.11)
	var wood_end := Color(0.58, 0.44, 0.28)
	var axe_steel := Color(0.28, 0.30, 0.32)
	var haft := Color(0.42, 0.32, 0.20)

	# Массивная лиственничная колода
	k.tube([Vector3(0, 0, 0), Vector3(0, 0.65, 0)], [0.34, 0.32], bark, 10)
	k.tube([Vector3(0, 0.63, 0), Vector3(0, 0.655, 0)], [0.315], wood_end, 10)
	# Радиальные морозобойные трещины
	k.box(Vector3(0, 0.656, 0), Vector3(0.55, 0.005, 0.02), Color(0.12, 0.08, 0.05))
	k.box(Vector3(0, 0.656, 0), Vector3(0.02, 0.005, 0.48), Color(0.12, 0.08, 0.05))

	# Колун, врубленный в торец колоды
	var axe_rot := Basis(Vector3.FORWARD, deg_to_rad(-16.0)) * Basis(Vector3.UP, deg_to_rad(25.0))
	# Обух и лезвие
	k.box(Vector3(0.04, 0.76, 0.0), Vector3(0.07, 0.16, 0.24), axe_steel, axe_rot)
	# Топорище
	k.box(Vector3(0.12, 1.05, 0.02), Vector3(0.04, 0.65, 0.05), haft, axe_rot)
	# Металлический расклинивающий клин в торце топорища
	k.box(Vector3(0.06, 0.81, 0.0), Vector3(0.015, 0.01, 0.03), axe_steel, axe_rot)
	return _mi(k, &"axe_stump", "tex_wood.png")


## Заброшенная полуразрушенная метеобудка 1961 года.
static func old_meteo_screen() -> Node3D:
	var cached := _instance_from_cache(&"old_meteo_screen", "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(66, 0.09)
	var paint := Color(0.62, 0.62, 0.6)          # остатки белил
	var bare := Color(0.36, 0.33, 0.3)           # серое, выбеленное ветром дерево
	var rot_wood := Color(0.24, 0.21, 0.18)
	var rusted_hinge := Color(0.32, 0.18, 0.12)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1961
	# Будку повело целиком: всё строим прямо и наклоняем вокруг точки на земле
	var tilt := Basis(Vector3.FORWARD, deg_to_rad(-7.0)) * Basis(Vector3.RIGHT, deg_to_rad(4.0))
	var b := func(pos: Vector3, size: Vector3, col: Color, rot := Basis()) -> void:
		k.box(tilt * pos, size, col, tilt * rot)
	var wood := func() -> Color: return paint if rng.randf() < 0.45 else bare

	for dx: float in [-0.32, 0.32]:
		for dz: float in [-0.27, 0.27]:
			b.call(Vector3(dx, 0.62, dz), Vector3(0.06, 1.25, 0.06), rot_wood)
	b.call(Vector3(0, 1.24, 0), Vector3(0.78, 0.04, 0.68), bare)
	b.call(Vector3(0, 1.58, -0.02), Vector3(0.64, 0.6, 0.52), Color(0.06, 0.06, 0.06))   # темнота внутри
	# Жалюзи: часть планок выбита — сквозь дыры чернота
	for c in range(8):
		var ly := 1.31 + float(c) * 0.075
		for side: float in [-0.355, 0.355]:
			if rng.randf() > 0.18:
				b.call(Vector3(side, ly, -0.01), Vector3(0.05, 0.026, 0.58), wood.call(), Basis(Vector3.FORWARD, deg_to_rad(40.0 * signf(side))))
		if rng.randf() > 0.15:
			b.call(Vector3(0, ly, -0.3), Vector3(0.66, 0.026, 0.05), wood.call(), Basis(Vector3.RIGHT, deg_to_rad(-40.0)))
		if rng.randf() > 0.35:   # уцелевшая левая створка спереди
			b.call(Vector3(-0.17, ly, 0.3), Vector3(0.3, 0.026, 0.05), wood.call(), Basis(Vector3.RIGHT, deg_to_rad(40.0)))
	for cx: float in [-0.35, 0.35]:
		for cz: float in [-0.3, 0.3]:
			b.call(Vector3(cx, 1.58, cz), Vector3(0.05, 0.66, 0.05), bare)
	# Крыша: одна доска обломана, на ней — шапка снега
	b.call(Vector3(-0.12, 1.94, 0), Vector3(0.62, 0.05, 0.84), bare, Basis(Vector3.RIGHT, deg_to_rad(-5.0)))
	b.call(Vector3(0.3, 1.94, 0.08), Vector3(0.3, 0.05, 0.6), rot_wood, Basis(Vector3.RIGHT, deg_to_rad(-5.0)))
	b.call(Vector3(-0.1, 1.99, 0.0), Vector3(0.6, 0.06, 0.74), Color(0.86, 0.88, 0.92))
	# Правая створка висит на одной ржавой петле
	b.call(Vector3(0.42, 1.46, 0.45), Vector3(0.3, 0.6, 0.04), paint, Basis(Vector3.UP, deg_to_rad(75.0)) * Basis(Vector3.FORWARD, deg_to_rad(9.0)))
	b.call(Vector3(0.36, 1.76, 0.31), Vector3(0.04, 0.08, 0.04), rusted_hinge)
	return _mi(k, &"old_meteo_screen", "tex_wood.png")


## Флюгер Вильда с вращающейся пластиной и указателями сторон света.
static func wild_vane() -> Node3D:
	var cached := _instance_from_cache(&"wild_vane", "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(67, 0.05)
	var iron := Color(0.25, 0.26, 0.28)
	var iron_dark := Color(0.15, 0.16, 0.17)
	var sheet := Color(0.42, 0.44, 0.46)

	# Высокая стальная мачта
	k.tube([Vector3(0, 0, 0), Vector3(0, 5.8, 0)], [0.065, 0.04], iron, 8)
	# Крестовина указателей сторон света (румбы) на высоте 5.0м
	k.box(Vector3(0, 5.0, 0), Vector3(0.9, 0.03, 0.03), iron_dark)
	k.box(Vector3(0, 5.0, 0), Vector3(0.03, 0.03, 0.9), iron_dark)
	for p in [Vector3(0.45, 5.0, 0), Vector3(-0.45, 5.0, 0), Vector3(0, 5.0, 0.45), Vector3(0, 5.0, -0.45)]:
		k.box(p, Vector3(0.08, 0.08, 0.02), sheet)

	# Поворотный узел флюгера на высоте 5.6м
	k.tube([Vector3(0, 5.5, 0), Vector3(0, 5.85, 0)], [0.055], iron_dark, 8)
	# Хвостовое оперение флюгера (двойной клин)
	k.box(Vector3(0, 5.75, -0.45), Vector3(0.03, 0.28, 0.65), sheet)
	# Противовес с шаром спереди
	k.tube([Vector3(0, 5.75, 0), Vector3(0, 5.75, 0.45)], [0.018], iron, 6)
	k.blob(Vector3(0, 5.75, 0.45), Vector3(0.06, 0.06, 0.06), iron_dark, 4, 6)
	# Дуга с делениями и отклонённая ветром доска Вильда
	k.tube([Vector3(0.08, 5.75, 0.1), Vector3(0.08, 5.45, 0.3)], [0.01], iron, 6, false, false)
	k.box(Vector3(0, 5.60, 0.18), Vector3(0.14, 0.25, 0.015), sheet, Basis(Vector3.RIGHT, deg_to_rad(35.0)))
	return _mi(k, &"wild_vane", "tex_metal.png")


## Трансформаторный ящик у мачты с предупреждающим знаком опасности.
static func transformer_booth() -> Node3D:
	var cached := _instance_from_cache(&"transformer_booth", "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(68, 0.05)
	var grey := Color(0.35, 0.38, 0.36)
	var grey_dark := Color(0.20, 0.22, 0.21)
	var ceramic := Color(0.48, 0.25, 0.15)
	var yellow_warn := Color(0.85, 0.72, 0.12)
	var black := Color(0.08, 0.08, 0.08)

	# Стальной шкаф с двухскатным козырьком
	k.box(Vector3(0, 0.75, 0), Vector3(0.95, 1.45, 0.65), grey)
	k.box(Vector3(0, 1.48, 0), Vector3(1.05, 0.06, 0.75), grey_dark)
	# Вентиляционные жалюзи
	for i in range(5):
		k.box(Vector3(0, 0.45 + i * 0.08, 0.33), Vector3(0.65, 0.025, 0.01), grey_dark)

	# Жёлтая табличка «НЕ ВЛЕЗАЙ — УБЬЕТ!»
	k.box(Vector3(0, 1.05, 0.33), Vector3(0.32, 0.28, 0.01), yellow_warn)
	k.box(Vector3(0, 1.05, 0.336), Vector3(0.28, 0.24, 0.005), black)
	k.box(Vector3(0, 1.05, 0.340), Vector3(0.24, 0.20, 0.005), yellow_warn)
	# Знак молнии
	k.tube([Vector3(0.03, 1.12, 0.345), Vector3(-0.02, 1.05, 0.345), Vector3(0.02, 1.05, 0.345), Vector3(-0.03, 0.98, 0.345)], [0.008], black, 4, false, false)

	# Керамические высоковольтные изоляторы на крыше
	for sx in [-0.32, 0.0, 0.32]:
		k.tube([Vector3(sx, 1.51, 0), Vector3(sx, 1.72, 0)], [0.045, 0.035], ceramic, 8)
		k.tube([Vector3(sx, 1.72, 0), Vector3(sx, 1.82, 0)], [0.015], grey_dark, 6)
	return _mi(k, &"transformer_booth", "tex_metal.png")


## Бытовка дорожников (КУНГ на стальных полозьях) на Зимнике.
static func kung_trailer() -> Node3D:
	# Модель tools/blender/kung.py (стиль построек); процедурный ящик ниже — запасной
	var glb := _kedr_model("kung", {"bright": 1.0, "sat": 1.0})
	if glb != null:
		return glb
	var cached := _instance_from_cache(&"kung_trailer", "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(69, 0.07)
	var kung_body := Color(0.48, 0.28, 0.16)         # Выцветший оранжево-коричневый арктический цвет
	var kung_trim := Color(0.24, 0.25, 0.26)
	var skid_steel := Color(0.18, 0.19, 0.20)
	var window_frost := Color(0.80, 0.85, 0.90)
	var soot := Color(0.08, 0.08, 0.08)

	# Стальные полозья-лыжи под фургоном
	for sz in [-1.15, 1.15]:
		k.box(Vector3(0, 0.12, sz), Vector3(5.6, 0.20, 0.22), skid_steel)
		# Загнутые концы лыж
		k.box(Vector3(2.9, 0.35, sz), Vector3(0.45, 0.18, 0.22), skid_steel, Basis(Vector3.FORWARD, deg_to_rad(35.0)))
		k.box(Vector3(-2.9, 0.35, sz), Vector3(0.45, 0.18, 0.22), skid_steel, Basis(Vector3.FORWARD, deg_to_rad(-35.0)))

	# Основной утеплённый кузов фургона (5.0 x 2.3 x 2.4м)
	k.box(Vector3(0, 1.45, 0), Vector3(5.0, 2.3, 2.5), kung_body)
	# Скруглённая крыша
	k.box(Vector3(0, 2.62, 0), Vector3(4.9, 0.14, 2.3), kung_trim)

	# Узкая торцевая дверь с козырьком
	k.box(Vector3(-2.51, 1.35, 0), Vector3(0.05, 1.85, 0.85), kung_trim)
	k.box(Vector3(-2.53, 1.35, 0.32), Vector3(0.03, 0.05, 0.10), Color(0.6, 0.6, 0.65)) # ручка

	# Окна-иллюминаторы со скруглёнными углами по бокам
	for x in [-1.2, 1.2]:
		k.box(Vector3(x, 1.65, 1.26), Vector3(0.75, 0.55, 0.02), kung_trim)
		k.box(Vector3(x, 1.65, 1.27), Vector3(0.65, 0.45, 0.01), window_frost)
		k.box(Vector3(x, 1.65, -1.26), Vector3(0.75, 0.55, 0.02), kung_trim)
		k.box(Vector3(x, 1.65, -1.27), Vector3(0.65, 0.45, 0.01), window_frost)

	# Печная труба на крыше с копотью
	k.tube([Vector3(1.6, 2.6, 0.6), Vector3(1.6, 3.4, 0.6)], [0.08], skid_steel, 8)
	k.box(Vector3(1.6, 3.42, 0.6), Vector3(0.24, 0.03, 0.24), soot)
	return _mi(k, &"kung_trailer", "tex_metal.png")


## Зияющий лаз в подпол избы со сломанной лестницей.
static func cellar_hole() -> Node3D:
	var cached := _instance_from_cache(&"cellar_hole", "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(70, 0.08)
	var wood := Color(0.28, 0.20, 0.12)
	var pit_dark := Color(0.03, 0.03, 0.04)

	# Обрамление проёма в полу
	k.box(Vector3(0, 0.01, -0.46), Vector3(0.96, 0.04, 0.08), wood)
	k.box(Vector3(0, 0.01, 0.46), Vector3(0.96, 0.04, 0.08), wood)
	k.box(Vector3(-0.46, 0.01, 0), Vector3(0.08, 0.04, 0.84), wood)
	k.box(Vector3(0.46, 0.01, 0), Vector3(0.08, 0.04, 0.84), wood)

	# Дно провала (чернота)
	k.box(Vector3(0, -0.75, 0), Vector3(0.85, 0.05, 0.85), pit_dark)
	for sx in [-0.42, 0.42]:
		k.box(Vector3(sx, -0.38, 0), Vector3(0.02, 0.8, 0.85), pit_dark)
	for sz in [-0.42, 0.42]:
		k.box(Vector3(0, -0.38, sz), Vector3(0.85, 0.8, 0.02), pit_dark)

	# Сломанная приставная лестница, уходящая вглубь
	for k_rung in range(3):
		k.box(Vector3(0, -0.15 - k_rung * 0.22, 0.15 - k_rung * 0.08), Vector3(0.42, 0.03, 0.06), wood)
	return _mi(k, &"cellar_hole", "tex_wood.png")


## Обледеневшие рыболовные сети на шестах у заимки.
static func frozen_nets() -> Node3D:
	var glb := _kedr_model("lake_nets", {"bright": 0.95})
	if glb != null:
		return glb
	var cached := _instance_from_cache(&"frozen_nets", "tex_cloth.png")
	if cached != null:
		return cached
	var k := _kit(71, 0.09)
	var pole_wood := Color(0.32, 0.25, 0.18)
	var net_frost := Color(0.72, 0.78, 0.85, 0.4)
	var cork := Color(0.45, 0.32, 0.18)

	# 2 наклонных жердевых шеста
	k.tube([Vector3(-1.1, 0, 0), Vector3(-0.9, 2.1, 0)], [0.045], pole_wood, 6)
	k.tube([Vector3(1.1, 0, 0), Vector3(0.9, 2.05, 0)], [0.045], pole_wood, 6)
	# Поперечная жердь
	k.tube([Vector3(-1.0, 1.95, 0), Vector3(1.0, 1.9, 0)], [0.035], pole_wood, 6)

	# Сетка, развешенная волнами
	k.box(Vector3(0, 1.15, 0), Vector3(1.95, 1.45, 0.02), net_frost)
	# Деревянные поплавки на подборе
	for i in range(5):
		k.blob(Vector3(-0.75 + i * 0.38, 1.88, 0.02), Vector3(0.04, 0.03, 0.03), cork, 3, 5)
	return _mi(k, &"frozen_nets", "tex_cloth.png")


## Массивная гермодверь убежища «Отзвук» со штурвалом.
static func bunker_blast_door() -> Node3D:
	var cached := _instance_from_cache(&"bunker_blast_door", "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(72, 0.05)
	var steel_heavy := Color(0.20, 0.22, 0.24)
	var steel_plate := Color(0.28, 0.30, 0.32)
	var wheel_paint := Color(0.4, 0.14, 0.1)     # Сурик, потемневший и затёртый до металла

	# Мощная чугунная коробка портала
	k.box(Vector3(0, 1.1, 0), Vector3(1.35, 2.3, 0.22), steel_heavy)
	# Полотно гермодвери (приоткрыто)
	var door_b := Basis(Vector3.UP, deg_to_rad(65.0))
	k.box(Vector3(0.45, 1.1, 0.35), Vector3(0.95, 2.05, 0.12), steel_plate, door_b)
	# Массивные шарнирные петли
	k.tube([Vector3(-0.52, 0.45, 0.05), Vector3(-0.52, 0.70, 0.05)], [0.065], steel_heavy, 8)
	k.tube([Vector3(-0.52, 1.55, 0.05), Vector3(-0.52, 1.80, 0.05)], [0.065], steel_heavy, 8)
	# Центральный штурвал запирания
	var wheel_pos := Vector3(0.45, 1.1, 0.35) + door_b * Vector3(0, 0, 0.09)
	k.tube([wheel_pos, wheel_pos + door_b * Vector3(0, 0, 0.06)], [0.04], steel_heavy, 8)
	# Штурвал: обод из 16 звеньев, ступица, три спицы
	var wc := wheel_pos + door_b * Vector3(0, 0, 0.07)
	for s in 16:
		var a := s * TAU / 16.0
		var seg_c := wc + door_b * Vector3(cos(a) * 0.2, sin(a) * 0.2, 0)
		k.box(seg_c, Vector3(0.085, 0.028, 0.028), wheel_paint, door_b * Basis(Vector3.FORWARD, a + PI * 0.5))
	k.tube([wc - door_b * Vector3(0, 0, 0.02), wc + door_b * Vector3(0, 0, 0.03)], [0.05], steel_heavy, 8)
	for ang in [0.0, 60.0, 120.0]:
		k.box(wc, Vector3(0.4, 0.02, 0.02), steel_plate, door_b * Basis(Vector3.FORWARD, deg_to_rad(ang)))
	# Клиновые задрайки по краю полотна и резиновый уплотнитель
	for e: Array in [[Vector3(0.0, 1.95, 0.42), 0.0], [Vector3(0.0, 0.25, 0.42), 0.0], [Vector3(0.38, 1.1, 0.42), 90.0], [Vector3(-0.38, 1.1, 0.42), 90.0]]:
		var pp: Vector3 = Vector3(0.45, 0, 0.35) + door_b * (e[0] - Vector3(0.45, 0, 0.35) + Vector3(0.45, 0, 0))
		k.box(pp, Vector3(0.14, 0.05, 0.05), steel_heavy, door_b * Basis(Vector3.FORWARD, deg_to_rad(e[1])))
	k.box(Vector3(0, 1.1, 0.115), Vector3(1.0, 2.1, 0.012), Color(0.08, 0.08, 0.08))
	# Заклёпки по раме портала
	for j in 7:
		for sx: float in [-0.6, 0.6]:
			k.box(Vector3(sx, 0.15 + j * 0.32, 0.115), Vector3(0.035, 0.035, 0.02), steel_plate)
	return _mi(k, &"bunker_blast_door", "tex_metal.png")


## Медный русский самовар с краником и конфоркой.
static func samovar() -> Node3D:
	var cached := _instance_from_cache(&"samovar", "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(81, 0.04)
	var brass := Color(0.72, 0.58, 0.24)
	var brass_dark := Color(0.48, 0.38, 0.16)
	var wood_handle := Color(0.25, 0.15, 0.08)

	# Круглое ступенчатое основание (шейка и поддон)
	k.tube([Vector3(0, 0.0, 0), Vector3(0, 0.06, 0)], [0.12, 0.08], brass_dark, 8)
	k.tube([Vector3(0, 0.06, 0), Vector3(0, 0.10, 0)], [0.08, 0.11], brass, 8)
	# Тулово («банка» / самоварное тело)
	k.tube([Vector3(0, 0.10, 0), Vector3(0, 0.32, 0)], [0.14, 0.16], brass, 10)
	# Крышка и конфорка под чайник
	k.tube([Vector3(0, 0.32, 0), Vector3(0, 0.38, 0)], [0.15, 0.08], brass, 8)
	k.tube([Vector3(0, 0.38, 0), Vector3(0, 0.44, 0)], [0.09, 0.09], brass_dark, 8)
	# Краник с ключом
	k.tube([Vector3(0, 0.16, 0.12), Vector3(0, 0.15, 0.22)], [0.015], brass_dark, 6)
	k.box(Vector3(0, 0.18, 0.20), Vector3(0.04, 0.03, 0.015), wood_handle)
	# Две боковые фигурные ручки
	for sx: float in [-0.17, 0.17]:
		k.tube([Vector3(sx * 0.9, 0.24, 0), Vector3(sx * 1.25, 0.25, 0)], [0.012], brass_dark, 4)
		k.box(Vector3(sx * 1.25, 0.25, 0), Vector3(0.02, 0.05, 0.02), wood_handle)
	return _mi(k, &"samovar", "tex_metal.png")


## Советский тяжёлый несгораемый стальной сейф для документации и шифров.
static func safe() -> Node3D:
	var cached := _instance_from_cache(&"safe", "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(82, 0.05)
	var safe_green := Color(0.18, 0.24, 0.20)
	var safe_dark := Color(0.11, 0.15, 0.12)
	var metal_bolt := Color(0.55, 0.58, 0.60)

	# Массивный бронированный корпус
	k.box(Vector3(0, 0.60, 0), Vector3(0.75, 1.20, 0.65), safe_green)
	# Цоколь и верхний карниз
	k.box(Vector3(0, 0.05, 0), Vector3(0.80, 0.10, 0.70), safe_dark)
	k.box(Vector3(0, 1.18, 0), Vector3(0.79, 0.06, 0.69), safe_dark)
	# Утопленная бронедверь
	k.box(Vector3(0, 0.62, 0.31), Vector3(0.64, 1.02, 0.04), safe_dark)
	# Поворотная Т-образная ручка ригелей
	k.tube([Vector3(-0.16, 0.62, 0.33), Vector3(-0.16, 0.62, 0.38)], [0.02], metal_bolt, 8)
	k.box(Vector3(-0.16, 0.62, 0.38), Vector3(0.14, 0.03, 0.03), metal_bolt)
	# Лимб кодового замка с насечками
	k.tube([Vector3(0.12, 0.65, 0.33), Vector3(0.12, 0.65, 0.36)], [0.045, 0.04], metal_bolt, 10)
	# Проушины под опечатывание сургучом
	k.box(Vector3(0.24, 0.62, 0.34), Vector3(0.04, 0.03, 0.02), RED)
	return _mi(k, &"safe", "tex_metal.png")


## Войлочные валенки с резиновыми галошами
static func valenki() -> Node3D:
	var cached := _instance_from_cache(&"valenki", "tex_cloth.png")
	if cached != null:
		return cached
	var k := _kit(52, 0.03)
	var felt := Color(0.28, 0.27, 0.26)
	var galosh := Color(0.08, 0.08, 0.08)

	for side: float in [-0.08, 0.08]:
		var base := Vector3(side, 0.0, 0)
		# Черная резиновая калоша (низ)
		k.box(base + Vector3(0, 0.025, 0.04), Vector3(0.11, 0.05, 0.25), galosh)
		# Мысок
		k.tube([base + Vector3(0, 0.025, 0.10), base + Vector3(0, 0.055, 0.08)], [0.052, 0.048], galosh, 8)
		# Войлочная стопа
		k.box(base + Vector3(0, 0.065, 0.03), Vector3(0.10, 0.06, 0.22), felt)
		# Высокое прямое голенище валенка
		k.tube([base + Vector3(0, 0.08, -0.01), base + Vector3(0, 0.38, -0.01)], [0.060, 0.066], felt, 10)
		# Верхний закругленный рант
		k.tube([base + Vector3(0, 0.38, -0.01), base + Vector3(0, 0.39, -0.01)], [0.066, 0.064], felt, 10, false, false)

	return _mi(k, &"valenki", "tex_cloth.png")


## Деревянная снеговая лопата (широкий фанерный совок на черенке).
static func snow_shovel(_is_held := false) -> Node3D:
	var cached := _instance_from_cache(&"snow_shovel", "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(84, 0.05)
	var plywood := Color(0.55, 0.44, 0.28)
	var metal_edge := Color(0.35, 0.38, 0.40)
	var stick := Color(0.42, 0.32, 0.18)

	# Широкий фанерный совок с бортиками
	k.box(Vector3(0, 0.25, 0), Vector3(0.52, 0.50, 0.02), plywood)
	k.box(Vector3(0, 0.01, 0), Vector3(0.53, 0.03, 0.025), metal_edge) # оковка
	# Длинный круглый черенок
	k.tube([Vector3(0, 0.20, 0.02), Vector3(0, 1.45, 0.08)], [0.02], stick, 6)
	return _mi(k, &"snow_shovel", "tex_wood.png")


## Металлическая пожарная/служебная лестница на стену станции.
static func wall_ladder(height := 3.2) -> Node3D:
	var key := StringName("wall_ladder_%.2f" % height)
	var cached := _instance_from_cache(key, "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(91, 0.04)
	var iron := Color(0.22, 0.23, 0.25)
	var rust := Color(0.32, 0.24, 0.18)

	var half_w := 0.24
	# Две вертикальные направляющие стойки
	for sx: float in [-half_w, half_w]:
		k.tube([Vector3(sx, 0.0, 0.08), Vector3(sx, height, 0.08)], [0.022], iron, 6)
		# Настенные кронштейны-опоры
		var mounts := int(height / 1.0) + 1
		for m in range(mounts):
			var my := float(m) * 1.0
			k.tube([Vector3(sx, my, 0.08), Vector3(sx, my, 0.0)], [0.016], iron, 4)

	# Ступени лестницы каждые 0.3м
	var rungs := int(height / 0.3)
	for r in range(1, rungs):
		var ry := float(r) * 0.3
		var col := rust if (r % 3 == 0) else iron
		k.tube([Vector3(-half_w, ry, 0.08), Vector3(half_w, ry, 0.08)], [0.015], col, 6)

	return _mi(k, key, "tex_metal.png")


## Ржавый таёжный капкан на зверя.
static func bear_trap() -> Node3D:
	var cached := _instance_from_cache(&"bear_trap", "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(85, 0.08)
	var rust := Color(0.28, 0.22, 0.18)

	# Стальная дуговая рама с острыми зубьями
	k.tube([Vector3(-0.25, 0, -0.15), Vector3(0, 0, -0.28), Vector3(0.25, 0, -0.15)], [0.02], rust, 5, false, false)
	k.tube([Vector3(-0.25, 0, 0.15), Vector3(0, 0, 0.28), Vector3(0.25, 0, 0.15)], [0.02], rust, 5, false, false)
	# Зубья капкана
	for i in range(5):
		var x := -0.18 + i * 0.09
		k.spike(Vector3(x, 0.01, -0.20), Vector3(x, 0.08, -0.18), 0.015, rust, 3)
		k.spike(Vector3(x, 0.01, 0.20), Vector3(x, 0.08, 0.18), 0.015, rust, 3)
	# Центральная тарелочка насторожки и пружина
	k.tube([Vector3(0, -0.01, 0), Vector3(0, 0.02, 0)], [0.07], rust, 6)
	k.box(Vector3(0.28, 0.02, 0), Vector3(0.18, 0.03, 0.08), rust)
	return _mi(k, &"bear_trap", "tex_metal.png")


## Дощатые козлы для распиловки с бревном и двуручной пилой «Дружба-2».
static func sawhorse() -> Node3D:
	var cached := _instance_from_cache(&"sawhorse", "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(86, 0.08)
	var wood := Color(0.38, 0.28, 0.18)
	var bark := Color(0.22, 0.16, 0.11)
	var wood_end := LOG_END
	var steel := Color(0.35, 0.38, 0.40)
	var rust := Color(0.32, 0.22, 0.16)

	# Два X-образных козла по краям (x = -0.55 и x = +0.55)
	for sx: float in [-0.55, 0.55]:
		var r1 := Basis(Vector3.FORWARD, deg_to_rad(28.0))
		var r2 := Basis(Vector3.FORWARD, deg_to_rad(-28.0))
		k.box(Vector3(sx, 0.45, 0), Vector3(0.08, 1.05, 0.08), wood, r1)
		k.box(Vector3(sx, 0.45, 0), Vector3(0.08, 1.05, 0.08), wood, r2)
		# Поперечная стяжка внизу
		k.box(Vector3(sx, 0.18, 0), Vector3(0.06, 0.06, 0.52), wood)

	# Продольная перемычка между козлами
	k.box(Vector3(0, 0.42, 0), Vector3(1.2, 0.08, 0.08), wood)

	# Распиливаемое бревно в верхнем V-образном ложе
	k.tube([Vector3(-0.75, 0.62, 0), Vector3(0.75, 0.62, 0)], [0.13], bark, 8, true, true, [wood_end, bark, wood_end])
	# Шапка снега на бревне
	k.box(Vector3(0, 0.74, 0), Vector3(1.4, 0.04, 0.16), Color(0.85, 0.88, 0.92))

	# Двуручная пила «Дружба-2», прислонённая к козлам
	var saw_rot := Basis(Vector3.UP, deg_to_rad(15.0)) * Basis(Vector3.RIGHT, deg_to_rad(18.0))
	# Полотно пилы
	k.box(Vector3(0.12, 0.48, 0.36), Vector3(1.35, 0.14, 0.008), rust, saw_rot)
	# Деревянные рукоятки на концах
	k.box(Vector3(-0.52, 0.48, 0.36), Vector3(0.04, 0.26, 0.04), wood, saw_rot)
	k.box(Vector3(0.76, 0.48, 0.36), Vector3(0.04, 0.26, 0.04), wood, saw_rot)
	return _mi(k, &"sawhorse", "tex_wood.png")


## Зловещий обгорелый пень-силуэт с расщеплёнными ветвями (парейдолия).
static func silhouette_stump() -> Node3D:
	var glb := _kedr_model("snag_figure", {"bright": 1.1})
	if glb != null:
		return glb
	var cached := _instance_from_cache(&"silhouette_stump", "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(87, 0.12)
	var charred := Color(0.11, 0.09, 0.08)
	var inner := Color(0.24, 0.18, 0.12)
	var snow := Color(0.86, 0.89, 0.94)

	# Ствол с изломом: напоминает сгорбленную фигуру человека
	k.tube([
		Vector3(0, 0, 0),
		Vector3(0.04, 0.7, 0.02),
		Vector3(-0.03, 1.25, -0.02),
		Vector3(0, 1.62, 0)
	], [0.26, 0.22, 0.18, 0.12], charred, 7)

	# Разлом верхушки («голова / капюшон»)
	k.box(Vector3(0, 1.65, 0), Vector3(0.22, 0.14, 0.24), charred)
	k.box(Vector3(0, 1.74, 0), Vector3(0.24, 0.06, 0.26), snow)

	# Торчащие обломанные сучья («руки / когти»)
	var l_arm := Basis(Vector3.FORWARD, deg_to_rad(35.0)) * Basis(Vector3.UP, deg_to_rad(-20.0))
	var r_arm := Basis(Vector3.FORWARD, deg_to_rad(-42.0)) * Basis(Vector3.UP, deg_to_rad(25.0))
	k.box(Vector3(-0.28, 1.15, 0.05), Vector3(0.48, 0.09, 0.09), charred, l_arm)
	k.box(Vector3(0.32, 1.05, -0.04), Vector3(0.55, 0.08, 0.08), charred, r_arm)
	# Снег на «плечах»
	k.box(Vector3(-0.16, 1.32, 0.02), Vector3(0.22, 0.04, 0.15), snow)
	k.box(Vector3(0.18, 1.28, -0.02), Vector3(0.24, 0.04, 0.15), snow)

	return _mi(k, &"silhouette_stump", "tex_wood.png")


## Дровница у печи (ящик для дров) с отображением 0..3 поленьев.
static func woodbox(count := 3) -> Node3D:
	var root := Node3D.new()
	var k := _kit(88 + count, 0.07)
	var wood := Color(0.42, 0.30, 0.18)
	var dark := Color(0.24, 0.17, 0.10)
	var birch := Color(0.76, 0.74, 0.68)
	var log_end := LOG_END

	# Дощатый открытый короб 0.70 × 0.40 × 0.45
	k.box(Vector3(0, 0.02, 0), Vector3(0.70, 0.04, 0.45), wood) # дно
	k.box(Vector3(-0.33, 0.22, 0), Vector3(0.04, 0.40, 0.45), wood) # левая стенка
	k.box(Vector3(0.33, 0.22, 0), Vector3(0.04, 0.40, 0.45), wood)  # правая стенка
	k.box(Vector3(0, 0.22, -0.21), Vector3(0.66, 0.40, 0.03), wood) # задняя стенка
	k.box(Vector3(0, 0.10, 0.21), Vector3(0.66, 0.16, 0.03), wood)  # низкий передний бортик

	# Поленья внутри ящика
	if count >= 1:
		k.tube([Vector3(-0.14, 0.10, -0.06), Vector3(-0.14, 0.10, 0.14)], [0.07], birch, 7, true, true, [log_end, birch, log_end])
	if count >= 2:
		k.tube([Vector3(0.14, 0.10, -0.04), Vector3(0.14, 0.10, 0.16)], [0.075], dark, 7, true, true, [log_end, dark, log_end])
	if count >= 3:
		k.tube([Vector3(0.0, 0.22, -0.02), Vector3(0.0, 0.22, 0.16)], [0.072], birch, 7, true, true, [log_end, birch, log_end])

	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	mi.material_override = _gained(Creatures._mat(StringName("woodbox_%d" % count), Color.WHITE, "tex_wood.png", 0.0))
	root.add_child(mi)
	return root


## Штормовой маяк на крыше станции (кронштейн, фонарь в защитной решётке).
static func beacon_lantern() -> Node3D:
	var cached := _instance_from_cache(&"beacon_lantern", "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(89, 0.06)
	var iron := Color(0.24, 0.26, 0.28)
	var glow := Color(1.0, 0.72, 0.22)
	var glass := Color(0.9, 0.8, 0.5, 0.8)

	# Опорная вертикальная мачта 1.2 м и укосина
	k.tube([Vector3(0, 0, 0), Vector3(0, 1.2, 0)], [0.04], iron, 6)
	k.tube([Vector3(0, 0.2, 0.35), Vector3(0, 0.9, 0)], [0.025], iron, 5)

	# Платформа оголовка и защитный колпак
	k.tube([Vector3(0, 1.2, 0), Vector3(0, 1.25, 0)], [0.18], iron, 8)
	k.tube([Vector3(0, 1.52, 0), Vector3(0, 1.64, 0)], [0.22, 0.02], iron, 8) # коническая крышка

	# Стеклянный фонарный цилиндр
	k.tube([Vector3(0, 1.25, 0), Vector3(0, 1.52, 0)], [0.13], glass, 8)

	# Защитная решётка (вертикальные прутья)
	for i in range(6):
		var a := i * TAU / 6.0
		var pos_bottom := Vector3(cos(a) * 0.15, 1.25, sin(a) * 0.15)
		var pos_top := Vector3(cos(a) * 0.15, 1.52, sin(a) * 0.15)
		k.tube([pos_bottom, pos_top], [0.012], iron, 4)

	# Светящийся элемент внутри
	k.tube([Vector3(0, 1.32, 0), Vector3(0, 1.45, 0)], [0.06], glow, 6)

	return _mi(k, &"beacon_lantern", "tex_metal.png")


## Советские деревянные настенные часы «Янтарь» с качающимся маятником и гирьками
static func wall_clock() -> Node3D:
	var root := Node3D.new()
	root.name = "WallClock"

	var k := _kit(93, 0.05)
	var wood := Color(0.38, 0.24, 0.14)
	var wood_dark := Color(0.24, 0.15, 0.08)
	var dial_white := Color(0.92, 0.90, 0.82)
	var brass := Color(0.78, 0.65, 0.28)
	var black := Color(0.12, 0.12, 0.12)

	# Деревянный прямоугольный корпус с карнизом
	k.box(Vector3(0, 0, 0), Vector3(0.26, 0.48, 0.10), wood)
	k.box(Vector3(0, 0.26, 0.01), Vector3(0.30, 0.04, 0.12), wood_dark)
	k.box(Vector3(0, -0.26, 0.01), Vector3(0.28, 0.04, 0.12), wood_dark)

	# Круглый циферблат с ободком и стрелками
	k.tube([Vector3(0, 0.11, 0.051), Vector3(0, 0.11, 0.056)], [0.085], dial_white, 12)
	k.tube([Vector3(0, 0.11, 0.054), Vector3(0, 0.11, 0.058)], [0.09], brass, 12, false, false)
	# Стрелки часов (на 02:15)
	k.tube([Vector3(0, 0.11, 0.058), Vector3(0.02, 0.15, 0.058)], [0.005], black, 4)
	k.tube([Vector3(0, 0.11, 0.058), Vector3(0.04, 0.11, 0.058)], [0.004], black, 4)

	# Нижнее застеклённое окошко
	k.box(Vector3(0, -0.11, 0.051), Vector3(0.16, 0.18, 0.005), Color(0.8, 0.85, 0.9, 0.6))

	# Подвесные цепочки и шишковидные гирьки снизу
	for side: float in [-0.05, 0.05]:
		k.tube([Vector3(side, -0.26, 0.02), Vector3(side, -0.38, 0.02)], [0.003], brass, 4)
		k.tube([Vector3(side, -0.38, 0.02), Vector3(side, -0.46, 0.02)], [0.015, 0.008], brass, 6)

	root.add_child(_mi(k, &"wall_clock_case", "tex_wood.png"))

	# Динамический маятник: качается в такт тиканью
	var pend := Node3D.new()
	pend.name = "Pendulum"
	pend.position = Vector3(0, 0.01, 0.035)
	root.add_child(pend)

	var pk := _kit(94, 0.02)
	pk.tube([Vector3(0, 0, 0), Vector3(0, -0.16, 0)], [0.003], brass, 4)
	pk.tube([Vector3(0, -0.15, -0.002), Vector3(0, -0.15, 0.004)], [0.032], brass, 10)
	pend.add_child(_mi(pk, &"wall_clock_pendulum", "tex_metal.png"))

	return root


## Мельхиоровый советский подстаканник с гранёным стаканом чая и ложечкой
static func podstakannik() -> Node3D:
	var cached := _instance_from_cache(&"podstakannik", "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(48, 0.02)
	var silver := Color(0.82, 0.84, 0.86)
	var glass := Color(0.88, 0.92, 0.96)
	var tea := Color(0.48, 0.22, 0.08)

	# Нижняя подставка подстаканника
	k.tube([Vector3(0, 0.0, 0), Vector3(0, 0.012, 0)], [0.044], silver, 12)
	# Металлическая ажурная юбка
	k.tube([Vector3(0, 0.012, 0), Vector3(0, 0.065, 0)], [0.042], silver, 10, false, false)
	# Изогнутая металлическая ручка
	k.tube([
		Vector3(0.042, 0.055, 0), Vector3(0.062, 0.050, 0),
		Vector3(0.065, 0.025, 0), Vector3(0.042, 0.015, 0)
	], [0.005], silver, 4)

	# Гранёный стеклянный стакан внутри
	k.tube([Vector3(0, 0.008, 0), Vector3(0, 0.115, 0)], [0.038, 0.041], glass, 12, false, false)
	# Горячий чай внутри стакана
	k.tube([Vector3(0, 0.014, 0), Vector3(0, 0.095, 0)], [0.035, 0.038], tea, 8)

	# Чайная ложечка с черенком, наклонённая к краю
	k.tube([Vector3(0.01, 0.015, 0), Vector3(-0.022, 0.135, 0.01)], [0.003], silver, 4)

	return _mi(k, &"podstakannik", "tex_metal.png")


## Обледенение чашек флюгера-анемометра (наледь, корка на чашках и сосульки)
static func anemo_ice() -> Node3D:
	var cached := _instance_from_cache(&"anemo_ice", "tex_snow.png")
	if cached != null:
		cached.material_override = Palette.m(&"ice")
		return cached
	var k := _kit(92, 0.05)
	var ice_col := Color(0.85, 0.92, 0.98, 0.88)
	var rime := Color(0.92, 0.96, 1.0, 0.95)

	# Нарост льда на центральной втулке
	k.blob(Vector3(0, 0, 0), Vector3(0.18, 0.16, 0.18), rime, 5, 8)
	# Ледяные наросты на 4 радиальных чашках анемометра
	for i in range(4):
		var a := i * TAU / 4.0
		var dir := Vector3(cos(a), 0, sin(a))
		k.tube([Vector3(0, 0, 0), dir * 0.28], [0.035, 0.045], ice_col, 5)
		k.blob(dir * 0.28, Vector3(0.12, 0.11, 0.12), rime, 5, 7)
		k.spike(dir * 0.28 + Vector3(0, -0.02, 0), dir * 0.28 + Vector3(0, -0.22, 0), 0.028, ice_col, 4)
		k.spike(dir * 0.14 + Vector3(0, -0.01, 0), dir * 0.14 + Vector3(0, -0.15, 0), 0.020, ice_col, 4)

	var mi := _mi(k, &"anemo_ice", "tex_snow.png")
	mi.material_override = Palette.m(&"ice")
	return mi


## Обледенение оголовка печной трубы (ледяная шапка с сосульками вокруг дефлектора)
static func chimney_ice() -> Node3D:
	var cached := _instance_from_cache(&"chimney_ice", "tex_snow.png")
	if cached != null:
		cached.material_override = Palette.m(&"ice")
		return cached
	var k := _kit(93, 0.06)
	var ice_col := Color(0.85, 0.92, 0.98, 0.90)
	var rime := Color(0.94, 0.97, 1.0, 0.96)

	k.tube([Vector3(0, -0.3, 0), Vector3(0, 0.15, 0)], [0.18, 0.26], ice_col, 8)
	k.blob(Vector3(0, 0.20, 0), Vector3(0.32, 0.16, 0.32), rime, 6, 8)
	for i in range(8):
		var a := i * TAU / 8.0
		var sx := cos(a) * 0.22
		var sz := sin(a) * 0.22
		var h := 0.25 + 0.15 * ((i * 3) % 4)
		k.spike(Vector3(sx, 0.15, sz), Vector3(sx, 0.15 - h, sz), 0.03, ice_col, 4)

	var mi := _mi(k, &"chimney_ice", "tex_snow.png")
	mi.material_override = Palette.m(&"ice")
	return mi


## Советская жалюзийная психрометрическая метеобудка Селянинова
static func meteo_screen() -> Node3D:
	var cached := _instance_from_cache(&"meteo_screen", "tex_planks.png")
	if cached != null:
		return cached
	var k := _kit(94, 0.04)
	var white := Color(0.86, 0.88, 0.90)
	var white_wood := Color(0.78, 0.80, 0.82)
	var brass := Color(0.72, 0.62, 0.32)
	var dark_interior := Color(0.18, 0.19, 0.20)

	for dx: float in [-0.32, 0.32]:
		for dz: float in [-0.28, 0.28]:
			k.tube([Vector3(dx * 1.15, 0.0, dz * 1.15), Vector3(dx, 1.25, dz)], [0.032], white, 4)
	k.tube([Vector3(-0.35, 0.4, -0.30), Vector3(0.35, 0.4, 0.30)], [0.018], white, 4)
	k.tube([Vector3(-0.35, 0.4, 0.30), Vector3(0.35, 0.4, -0.30)], [0.018], white, 4)
	k.box(Vector3(0, 0.35, 0.45), Vector3(0.55, 0.04, 0.22), white)
	k.box(Vector3(0, 0.75, 0.38), Vector3(0.55, 0.04, 0.22), white)

	k.box(Vector3(0, 1.26, 0), Vector3(0.78, 0.04, 0.68), white)
	k.box(Vector3(0, 1.62, -0.02), Vector3(0.66, 0.66, 0.54), dark_interior)   # темнота в щелях жалюзи

	# Жалюзи со всех сторон (будка Селянинова): наклонные планки, между ними — темнота внутри
	var slat_x := Basis(Vector3.RIGHT, deg_to_rad(40.0))
	for c in range(9):
		var ly := 1.33 + float(c) * 0.072
		for side: float in [-0.365, 0.365]:
			k.box(Vector3(side, ly, -0.01), Vector3(0.05, 0.026, 0.6), white_wood, Basis(Vector3.FORWARD, deg_to_rad(40.0 * signf(side))))
		k.box(Vector3(0, ly, -0.315), Vector3(0.68, 0.026, 0.05), white_wood, slat_x.inverse())
		for dx: float in [-0.17, 0.17]:   # створки дверцы — закрыты
			k.box(Vector3(dx, ly, 0.305), Vector3(0.3, 0.026, 0.05), white_wood, slat_x)
	# Каркас: угловые стойки, обвязка, рамки створок, ручка и щеколда
	for cx: float in [-0.36, 0.36]:
		for cz: float in [-0.31, 0.31]:
			k.box(Vector3(cx, 1.62, cz), Vector3(0.05, 0.72, 0.05), white)
	for y: float in [1.29, 1.95]:
		k.box(Vector3(0, y, 0.31), Vector3(0.76, 0.04, 0.05), white)
		k.box(Vector3(0, y, -0.31), Vector3(0.76, 0.04, 0.05), white)
		for side: float in [-0.36, 0.36]:
			k.box(Vector3(side, y, 0), Vector3(0.05, 0.04, 0.64), white)
	for dx: float in [-0.015, 0.015]:
		k.box(Vector3(dx, 1.62, 0.322), Vector3(0.026, 0.66, 0.03), white)
	k.box(Vector3(0.06, 1.64, 0.345), Vector3(0.02, 0.09, 0.02), brass)
	k.box(Vector3(-0.02, 1.7, 0.342), Vector3(0.07, 0.018, 0.015), Color(0.3, 0.3, 0.32))

	var roof_tilt := Basis(Vector3.RIGHT, deg_to_rad(-6.0))
	k.box(Vector3(0, 1.98, 0.02), Vector3(0.88, 0.05, 0.82), white, roof_tilt)
	k.box(Vector3(0, 2.05, 0.02), Vector3(0.92, 0.04, 0.86), white, roof_tilt)

	return _mi(k, &"meteo_screen", "tex_planks.png")


## Советская деревянная снегомерная рейка М-103
static func snow_gauge_rod() -> Node3D:
	var cached := _instance_from_cache(&"snow_gauge_rod", "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(95, 0.03)
	var white := Color(0.92, 0.94, 0.95)
	var red := Color(0.78, 0.15, 0.12)
	var iron_spike := Color(0.20, 0.21, 0.22)
	var black := Color(0.10, 0.10, 0.10)

	k.spike(Vector3(0, 0.12, 0), Vector3(0, -0.08, 0), 0.035, iron_spike, 4)
	for seg in range(18):
		var y := 0.10 + float(seg) * 0.10
		var col := red if (seg % 2 == 1) else white
		k.box(Vector3(0, y + 0.05, 0), Vector3(0.055, 0.10, 0.035), col)
		if seg % 2 == 0:
			k.box(Vector3(0, y + 0.05, 0.019), Vector3(0.035, 0.01, 0.002), black)
	k.box(Vector3(0, 1.91, 0), Vector3(0.055, 0.02, 0.035), red)

	return _mi(k, &"snow_gauge_rod", "tex_wood.png")


## Металлическая решетчатая ферменная радиомачта на бетонном постаменте
static func radio_mast(height := 16.0) -> Node3D:
	if is_equal_approx(height, 16.0):
		var glb := _kedr_model("radio_mast16", {"center": false, "bright": 1.1})
		if glb != null:
			return glb
	var key := StringName("radio_mast_%.1f" % height)
	var cached := _instance_from_cache(key, "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(96, 0.05)
	var iron := Color(0.26, 0.28, 0.30)
	var iron_rust := Color(0.34, 0.26, 0.22)
	var red_warn := Color(0.78, 0.15, 0.12)
	var white := Color(0.85, 0.88, 0.90)

	var segs := int(height / 1.6)
	var base_w := 0.65
	var top_w := 0.28

	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var b_pos := Vector3(sx * base_w * 0.5, 0.0, sz * base_w * 0.5)
			var t_pos := Vector3(sx * top_w * 0.5, height, sz * top_w * 0.5)
			k.tube([b_pos, t_pos], [0.035, 0.025], iron, 4)

	for s in range(segs):
		var y0 := float(s) * 1.6
		var y1 := float(s + 1) * 1.6
		var t0 := y0 / height
		var t1 := y1 / height
		var w0 := lerpf(base_w, top_w, t0) * 0.5
		var w1 := lerpf(base_w, top_w, t1) * 0.5
		var col := red_warn if (s % 2 == 1 or s >= segs - 2) else white

		var corners0 := [Vector3(-w0, y0, -w0), Vector3(w0, y0, -w0), Vector3(w0, y0, w0), Vector3(-w0, y0, w0)]
		var corners1 := [Vector3(-w1, y1, -w1), Vector3(w1, y1, -w1), Vector3(w1, y1, w1), Vector3(-w1, y1, w1)]
		for side in range(4):
			var c0a: Vector3 = corners0[side]
			var c0b: Vector3 = corners0[(side + 1) % 4]
			var c1a: Vector3 = corners1[side]
			var c1b: Vector3 = corners1[(side + 1) % 4]
			k.tube([c0a, c0b], [0.018], col, 4)
			k.tube([c0a, c1b], [0.014], col, 4)
			k.tube([c0b, c1a], [0.014], col, 4)

	k.box(Vector3(0, height, 0), Vector3(top_w * 1.2, 0.04, top_w * 1.2), iron)
	k.tube([Vector3(0, height, 0), Vector3(0, height + 1.2, 0)], [0.02, 0.005], iron_rust, 6)

	return _mi(k, key, "tex_metal.png")


## Массивное обледенение основания мачты с ледяными сталагмитами и сосульками
static func mast_ice_base() -> Node3D:
	var cached := _instance_from_cache(&"mast_ice_base", "tex_snow.png")
	if cached != null:
		cached.material_override = Palette.m(&"ice")
		return cached
	var k := _kit(97, 0.08)
	var ice_col := Color(0.85, 0.92, 0.98, 0.90)
	var rime := Color(0.92, 0.96, 1.0, 0.95)

	k.blob(Vector3(0, 0.7, 0), Vector3(0.55, 0.65, 0.55), ice_col, 6, 8)
	k.blob(Vector3(0.15, 1.2, -0.1), Vector3(0.35, 0.45, 0.35), rime, 5, 7)
	for i in range(6):
		var a := i * TAU / 6.0
		var sx := cos(a) * 0.28
		var sz := sin(a) * 0.28
		k.spike(Vector3(sx, 1.4, sz), Vector3(sx, 0.4, sz), 0.045, ice_col, 5)
		k.spike(Vector3(sx * 1.2, 0.0, sz * 1.2), Vector3(sx * 1.2, 0.8, sz * 1.2), 0.055, rime, 5)

	var mi := _mi(k, &"mast_ice_base", "tex_snow.png")
	mi.material_override = Palette.m(&"ice")
	return mi


## Ледяной чехол на оттяжке мачты
static func guy_wire_ice(length := 2.2) -> Node3D:
	var key := StringName("guy_wire_ice_%.1f" % length)
	var cached := _instance_from_cache(key, "tex_snow.png")
	if cached != null:
		cached.material_override = Palette.m(&"ice")
		return cached
	var k := _kit(98, 0.06)
	var ice_col := Color(0.85, 0.92, 0.98, 0.90)

	k.tube([Vector3(0, 0, -length * 0.5), Vector3(0, 0, length * 0.5)], [0.06, 0.07], ice_col, 6)
	for i in range(5):
		var z := -length * 0.4 + float(i) * (length * 0.2)
		k.spike(Vector3(0, -0.04, z), Vector3(0, -0.22 - 0.08 * (i % 2), z), 0.025, ice_col, 4)

	var mi := _mi(k, key, "tex_snow.png")
	mi.material_override = Palette.m(&"ice")
	return mi


## Деревянный кол путеводного леера с крепежной скобой и красным флажком
static func rope_post(has_flag := false, flag_col := Color(0.82, 0.14, 0.12), shape := 0) -> Node3D:
	var key := StringName("rope_post_%s" % (("flag_%s_%d" % [flag_col.to_html(false), shape]) if has_flag else "bare"))
	var cached := _instance_from_cache(key, "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(99, 0.05)
	var wood_col := Color(0.36, 0.33, 0.29)
	var wood_top := Color(0.26, 0.23, 0.20)
	var staple := Color(0.20, 0.21, 0.22)
	var red_flag := flag_col   # цвет маршрута (см. Yard.ROUTES)

	# Круглый вбитый в сугроб столб (высота 1.35м)
	k.tube([Vector3(0, 0, 0), Vector3(0, 1.32, 0)], [0.042, 0.038], wood_col, 6)
	k.box(Vector3(0, 1.33, 0), Vector3(0.065, 0.03, 0.065), wood_top)
	k.blob(Vector3(0.004, 1.365, 0.0), Vector3(0.05, 0.028, 0.048), Color(0.72, 0.78, 0.86), 3, 6)   # снежная шапка
	# Металлическая скоба-рым для продевания троса на высоте 1.05м
	k.tube([Vector3(0.035, 1.05, -0.02), Vector3(0.065, 1.05, 0.0), Vector3(0.035, 1.05, 0.02)], [0.007], staple, 4)
	# Снег, обтоптанный у основания вешки
	k.blob(Vector3(0, 0.02, 0), Vector3(0.16, 0.06, 0.16), Color(0.72, 0.78, 0.86), 3, 7)

	# Красный треугольный сигнальный вымпел на ветру
	if has_flag:
		var flag_slant := Basis(Vector3.UP, deg_to_rad(15.0)) * Basis(Vector3.FORWARD, deg_to_rad(-8.0))
		# Ткань флажка — изломами (складки на ветру), а не плоская пластина
		var cloth := func(c: Vector3, sz: Vector3) -> void:
			var n := 3
			for j in n:
				var seg_w := sz.x / n
				var bend := Basis(Vector3.UP, deg_to_rad(18.0 if j % 2 == 0 else -18.0))
				k.box(c + Vector3(-sz.x * 0.5 + seg_w * (j + 0.5), 0, 0.012 * (j % 2)), Vector3(seg_w + 0.01, sz.y - 0.012 * j, sz.z), red_flag, flag_slant * bend)
		# Флажок покрупнее: по нему теперь читают маршрут (щитов-указателей больше нет).
		# Форма — для тех, кто не различает цвета (см. Yard.ROUTES).
		match shape:
			1:   # прямоугольник
				cloth.call(Vector3(0.2, 1.2, 0), Vector3(0.34, 0.2, 0.015))
			2:   # «ласточкин хвост»: два языка
				k.box(Vector3(0.13, 1.2, 0), Vector3(0.2, 0.2, 0.015), red_flag, flag_slant)
				k.spike(Vector3(0.23, 1.25, 0), Vector3(0.4, 1.27, 0.02), 0.045, red_flag, 4)
				k.spike(Vector3(0.23, 1.15, 0), Vector3(0.4, 1.13, 0.02), 0.045, red_flag, 4)
			3:   # два вымпела один над другим
				for fy: float in [1.27, 1.1]:
					k.box(Vector3(0.12, fy, 0), Vector3(0.18, 0.1, 0.015), red_flag, flag_slant)
					k.spike(Vector3(0.21, fy, 0), Vector3(0.34, fy, 0.02), 0.04, red_flag, 4)
			4:   # прямоугольник с белой полосой
				cloth.call(Vector3(0.2, 1.2, 0), Vector3(0.34, 0.2, 0.015))
				k.box(Vector3(0.2, 1.2, 0.009), Vector3(0.34, 0.06, 0.004), Color(0.92, 0.92, 0.9), flag_slant)
			_:   # вымпел
				cloth.call(Vector3(0.15, 1.20, 0), Vector3(0.24, 0.15, 0.015))
				k.spike(Vector3(0.27, 1.20, 0), Vector3(0.44, 1.20, 0.02), 0.055, red_flag, 4)

	return _mi(k, key, "tex_wood.png")


## Дощатый деревянный настил мостков с поперечными досками и зазорами
static func plank_walkway(length: float) -> Node3D:
	var key := StringName("plank_walkway_%.1f" % length)
	var cached := _instance_from_cache(key, "tex_planks.png")
	if cached != null:
		return cached
	var k := _kit(100, 0.04)
	var plank_col := Color(0.48, 0.44, 0.38)
	var sleeper_col := Color(0.32, 0.28, 0.24)
	var nail_col := Color(0.15, 0.16, 0.17)

	# Две продольные опорные лаги снизу
	for sx in [-0.28, 0.28]:
		k.tube([Vector3(sx, 0.02, -length * 0.5), Vector3(sx, 0.02, length * 0.5)], [0.035], sleeper_col, 4)

	# Поперечные доски настила каждые ~0.18м
	var plank_count := maxi(2, int(length / 0.18))
	var step := length / float(plank_count)
	for i in range(plank_count):
		var z := -length * 0.5 + (float(i) + 0.5) * step
		var w := 0.74 + 0.04 * ((i * 5) % 3)
		var p_thick := 0.035
		var plank_y := 0.055
		k.box(Vector3(0, plank_y, z), Vector3(w, p_thick, step * 0.88), plank_col)
		# Шляпки гвоздей по краям досок
		k.box(Vector3(-w * 0.38, plank_y + 0.018, z), Vector3(0.012, 0.004, 0.012), nail_col)
		k.box(Vector3(w * 0.38, plank_y + 0.018, z), Vector3(0.012, 0.004, 0.012), nail_col)

	return _mi(k, key, "tex_planks.png")


## Слесарно-столярный верстак в сарае ГСМ с тисками и полкой
static func workbench() -> Node3D:
	var cached := _instance_from_cache(&"workbench", "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(101, 0.04)
	var wood_bench := Color(0.42, 0.34, 0.26)
	var wood_dark := Color(0.28, 0.22, 0.17)
	var iron := Color(0.24, 0.25, 0.26)
	var iron_bright := Color(0.50, 0.52, 0.54)
	var oil_dark := Color(0.12, 0.10, 0.08)

	var w := 2.2
	var d := 0.75
	var h := 0.85

	# 4 массивные деревянные ножки
	for sx in [-w * 0.45, w * 0.45]:
		for sz in [-d * 0.42, d * 0.42]:
			k.box(Vector3(sx, h * 0.5, sz), Vector3(0.09, h, 0.09), wood_dark)
	# Продольные и поперечные проножки (каркас жесткости)
	k.box(Vector3(0, 0.22, -d * 0.42), Vector3(w * 0.88, 0.06, 0.05), wood_dark)
	k.box(Vector3(0, 0.22, d * 0.42), Vector3(w * 0.88, 0.06, 0.05), wood_dark)
	k.box(Vector3(0, 0.22, 0), Vector3(w * 0.85, 0.03, d * 0.80), wood_dark) # нижняя полка
	k.box(Vector3(0.3, 0.24, 0.1), Vector3(0.4, 0.01, 0.3), oil_dark)       # масляное пятно на полке

	# Массивная наборная дощатая столешница с окантовкой стальным уголком
	k.box(Vector3(0, h + 0.03, 0), Vector3(w, 0.06, d), wood_bench)
	k.box(Vector3(0, h + 0.03, d * 0.5), Vector3(w, 0.065, 0.015), iron)
	k.box(Vector3(-w * 0.5, h + 0.03, 0), Vector3(0.015, 0.065, d), iron)
	k.box(Vector3(w * 0.5, h + 0.03, 0), Vector3(0.015, 0.065, d), iron)

	# Чугунные слесарные поворотные тиски на левом углу верстака
	var vp := Vector3(-w * 0.38, h + 0.06, d * 0.32)
	k.tube([vp, vp + Vector3(0, 0.04, 0)], [0.08], iron, 8)                # поворотное основание
	k.box(vp + Vector3(0, 0.08, 0), Vector3(0.14, 0.08, 0.22), iron)       # корпус тисков
	k.box(vp + Vector3(0, 0.14, 0.05), Vector3(0.12, 0.06, 0.03), iron_bright) # неподвижная губка
	k.box(vp + Vector3(0, 0.14, -0.02), Vector3(0.12, 0.06, 0.03), iron_bright) # подвижная губка
	k.tube([vp + Vector3(0, 0.08, 0.11), vp + Vector3(0, 0.08, -0.11)], [0.015], iron, 6) # ходовой винт
	k.tube([vp + Vector3(-0.08, 0.08, 0.11), vp + Vector3(0.08, 0.08, 0.11)], [0.007], iron_bright, 4) # рукоятка

	# Разложенные на верстаке слесарные инструменты
	k.box(Vector3(0.15, h + 0.065, 0.1), Vector3(0.24, 0.015, 0.04), iron_bright, Basis(Vector3.UP, deg_to_rad(20.0))) # разводной ключ
	k.tube([Vector3(-0.1, h + 0.065, 0.15), Vector3(-0.1, h + 0.065, -0.15)], [0.012], wood_dark, 4) # напильник с деревянной ручкой
	k.box(Vector3(-0.1, h + 0.065, -0.06), Vector3(0.025, 0.01, 0.18), iron, Basis(Vector3.UP, deg_to_rad(-10.0)))

	return _mi(k, &"workbench", "tex_wood.png")


## Подвесная цепная ручная таль со стропила над снегоходом
static func chain_hoist() -> Node3D:
	var cached := _instance_from_cache(&"chain_hoist", "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(102, 0.04)
	var iron := Color(0.25, 0.26, 0.28)
	var iron_bright := Color(0.48, 0.50, 0.52)
	var rust := Color(0.38, 0.26, 0.18)

	# Подвесная балочная струбцина/каретка
	k.box(Vector3(0, 0.9, 0), Vector3(0.14, 0.08, 0.18), iron)
	# Верхняя подвесная серьга
	k.tube([Vector3(0, 0.9, 0), Vector3(0, 0.75, 0)], [0.015], iron, 6)
	# Корпус шестеренчатого редуктора тали (круглый с ребрами)
	k.tube([Vector3(0, 0.65, -0.08), Vector3(0, 0.65, 0.08)], [0.14], iron, 10)
	k.box(Vector3(0, 0.65, 0), Vector3(0.24, 0.22, 0.14), rust)
	# Свисающие стальные цепи (грузовая и управляющая)
	k.tube([Vector3(-0.05, 0.55, 0), Vector3(-0.05, -0.4, 0)], [0.012], iron_bright, 4)
	k.tube([Vector3(0.05, 0.55, 0), Vector3(0.05, -0.2, 0)], [0.008], iron_bright, 4)
	# Массивный кованый грузовой крюк снизу
	k.tube([Vector3(-0.05, -0.4, 0), Vector3(-0.05, -0.48, 0)], [0.02], iron, 6)
	k.tube([Vector3(-0.05, -0.48, 0), Vector3(-0.01, -0.56, 0), Vector3(-0.08, -0.58, 0), Vector3(-0.09, -0.48, 0)], [0.018], iron, 6)

	return _mi(k, &"chain_hoist", "tex_metal.png")


## Сложенные деревянные транспортировочные ящики для полярной базы
static func stacked_crates() -> Node3D:
	var cached := _instance_from_cache(&"stacked_crates", "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(103, 0.05)
	var wood_col := Color(0.48, 0.38, 0.26)
	var wood_dark := Color(0.32, 0.25, 0.18)
	var metal_corner := Color(0.22, 0.23, 0.24)
	var stencil_black := Color(0.08, 0.08, 0.08)

	# Нижний большой ящик
	k.box(Vector3(0, 0.25, 0), Vector3(0.92, 0.50, 0.78), wood_col)
	k.box(Vector3(0, 0.25, 0.395), Vector3(0.90, 0.06, 0.01), wood_dark)
	k.box(Vector3(0, 0.25, 0.40), Vector3(0.25, 0.08, 0.005), stencil_black) # трафаретный номер «КЕДР-7»
	for sx in [-0.46, 0.46]:
		for sz in [-0.39, 0.39]:
			k.box(Vector3(sx, 0.25, sz), Vector3(0.04, 0.50, 0.04), metal_corner) # стальные уголки

	# Верхний ящик, слегка сдвинутый и повернутый
	var top_rot := Basis(Vector3.UP, deg_to_rad(12.0))
	var top_pos := Vector3(-0.06, 0.72, 0.04)
	k.box(top_pos, Vector3(0.72, 0.44, 0.62), wood_col, top_rot)
	k.box(top_pos + top_rot * Vector3(0, 0, 0.315), Vector3(0.68, 0.05, 0.01), wood_dark, top_rot)
	for sx in [-0.36, 0.36]:
		for sz in [-0.31, 0.31]:
			k.box(top_pos + top_rot * Vector3(sx, 0, sz), Vector3(0.035, 0.44, 0.035), metal_corner, top_rot)

	return _mi(k, &"stacked_crates", "tex_wood.png")


## Наземный железобетонный капонир входа в бункер ГО с гермолюком и дефлектором ЦАГИ
static func bunker_caponier_portal() -> Node3D:
	# Модель tools/blender/bunker_portal.py; процедурный вариант ниже — запасной
	var glb := _kedr_model("bunker_portal", {"bright": 1.0, "sat": 1.0})
	if glb != null:
		return glb
	var cached := _instance_from_cache(&"bunker_caponier_portal", "tex_concrete.png")
	if cached != null:
		return cached
	var k := _kit(104, 0.04)
	var concrete := Color(0.44, 0.45, 0.46)
	var concrete_dark := Color(0.32, 0.33, 0.35)
	var concrete_lip := Color(0.50, 0.51, 0.52)
	var iron_dark := Color(0.20, 0.21, 0.22)
	var iron_rust := Color(0.36, 0.24, 0.18)
	var iron_bright := Color(0.48, 0.50, 0.52)
	var snow_col := Color(0.88, 0.90, 0.94)
	var red_stencil := Color(0.75, 0.15, 0.12)

	# 1. Массивный ступенчатый бетонный оголовок
	# Нижняя подушка цоколя
	k.box(Vector3(0, 0.40, 0), Vector3(3.5, 0.80, 3.5), concrete_dark)
	# Основной наклонный капонир со скошенными амбразурными гранями
	k.box(Vector3(0, 0.95, 0), Vector3(2.8, 0.50, 2.8), concrete)
	# Верхняя плита с защитным выступом-козырьком
	k.box(Vector3(0, 1.25, 0), Vector3(2.5, 0.14, 2.5), concrete_lip)
	# Окаймляющий бортик люкового колодца (комингс)
	k.box(Vector3(0, 1.34, 0), Vector3(1.45, 0.08, 1.45), concrete_dark)

	# Снежные надувы по ветровым граням капонира
	k.box(Vector3(-1.4, 0.45, 0), Vector3(0.5, 0.70, 3.2), snow_col, Basis(Vector3.FORWARD, deg_to_rad(15.0)))
	k.box(Vector3(0, 0.35, 1.4), Vector3(3.2, 0.60, 0.5), snow_col, Basis(Vector3.RIGHT, deg_to_rad(-12.0)))

	# Монтажные стальные рым-петли на углах плиты (для кранового монтажа)
	for sx in [-1.1, 1.1]:
		for sz in [-1.1, 1.1]:
			k.tube([Vector3(sx, 1.32, sz - 0.04), Vector3(sx, 1.40, sz), Vector3(sx, 1.32, sz + 0.04)], [0.018], iron_rust, 4)

	# Красный трафарет ГО на фронтальной грани плиты
	k.box(Vector3(0, 0.95, 1.41), Vector3(1.2, 0.16, 0.01), red_stencil)

	# 2. Массивный круглый бронелюк ГО
	# Опорное кольцо комингса люка с болтами
	k.tube([Vector3(0, 1.36, 0), Vector3(0, 1.40, 0)], [0.65], iron_dark, 14)
	# Выпуклая крышка люка
	k.tube([Vector3(0, 1.40, 0), Vector3(0, 1.45, 0)], [0.62], iron_rust, 14)
	k.tube([Vector3(0, 1.45, 0), Vector3(0, 1.48, 0)], [0.55], iron_dark, 12)
	# Центральный 4-спицевый штурвал ригельного затвора
	k.tube([Vector3(0, 1.48, 0), Vector3(0, 1.55, 0)], [0.04], iron_bright, 8)
	k.tube([Vector3(-0.25, 1.55, 0), Vector3(0.25, 1.55, 0)], [0.016], iron_bright, 6)
	k.tube([Vector3(0, 1.55, -0.25), Vector3(0, 1.55, 0.25)], [0.016], iron_bright, 6)
	# Мощные коробчатые петли люка и торсионные рычаги
	k.box(Vector3(0, 1.43, -0.66), Vector3(0.28, 0.12, 0.16), iron_dark)
	k.tube([Vector3(-0.16, 1.43, -0.66), Vector3(0.16, 1.43, -0.66)], [0.035], iron_bright, 6)
	# Проушины под навесной замок и пломбировочную проволоку
	k.box(Vector3(0, 1.46, 0.60), Vector3(0.08, 0.08, 0.04), iron_bright)

	# 3. Вытяжная вентиляционная шахта с дефлектором ЦАГИ («грибок»)
	var vp := Vector3(1.1, 1.25, 1.1)
	# Фланцевое соединение с плитой
	k.tube([vp, vp + Vector3(0, 0.06, 0)], [0.20], iron_dark, 10)
	# Вертикальная стальная труба воздуховода
	k.tube([vp + Vector3(0, 0.06, 0), vp + Vector3(0, 1.35, 0)], [0.14], iron_dark, 10)
	# Промежуточный соединительный фланец
	k.tube([vp + Vector3(0, 0.70, 0), vp + Vector3(0, 0.74, 0)], [0.17], iron_bright, 10)
	# Кожух диффузора дефлектора с щелями
	k.tube([vp + Vector3(0, 1.35, 0), vp + Vector3(0, 1.70, 0)], [0.26, 0.24], iron_dark, 10)
	# Вентиляционные прорези (воздухозабор)
	k.tube([vp + Vector3(0, 1.40, 0), vp + Vector3(0, 1.62, 0)], [0.18], iron_rust, 8)
	# Зонтичный конический колпак («грибок») с шапкой снега
	k.tube([vp + Vector3(0, 1.70, 0), vp + Vector3(0, 1.82, 0)], [0.32, 0.08], iron_dark, 10)
	k.tube([vp + Vector3(0, 1.82, 0), vp + Vector3(0, 1.86, 0)], [0.08, 0.30], snow_col, 10)

	return _mi(k, &"bunker_caponier_portal", "tex_concrete.png")



## Замёрзшая меховая шапка-ушанка в сугробе (шапка Семёнова у проруби)
static func ushanka() -> Node3D:
	var cached := _instance_from_cache(&"ushanka", "tex_fur.png")
	if cached != null:
		return cached
	var k := _kit(106, 0.03)
	var cloth_top := Color(0.24, 0.25, 0.26)
	var fur_black := Color(0.14, 0.14, 0.15)
	var fur_frost := Color(0.36, 0.38, 0.40)
	var star_red := Color(0.82, 0.14, 0.12)
	var string_col := Color(0.18, 0.18, 0.18)

	# Полусферический суконный верх шапки
	k.tube([Vector3(0, 0.02, 0), Vector3(0, 0.14, 0)], [0.12, 0.10], cloth_top, 10)
	k.tube([Vector3(0, 0.14, 0), Vector3(0, 0.17, 0)], [0.10, 0.04], cloth_top, 8)

	# Подвернутый передний меховой козырек (налобник) с кокардой
	k.box(Vector3(0, 0.11, 0.11), Vector3(0.14, 0.09, 0.04), fur_frost)
	k.tube([Vector3(0, 0.11, 0.13), Vector3(0, 0.11, 0.135)], [0.018], star_red, 5) # красная звезда

	# Затылочная часть
	k.box(Vector3(0, 0.07, -0.11), Vector3(0.16, 0.08, 0.04), fur_black)

	# Боковые меховые "уши", разбросанные по снегу
	# Левое ухо
	k.box(Vector3(-0.14, 0.03, 0.02), Vector3(0.10, 0.035, 0.14), fur_black, Basis(Vector3.FORWARD, deg_to_rad(-20.0)))
	k.tube([Vector3(-0.19, 0.015, 0.06), Vector3(-0.25, 0.005, 0.11)], [0.005], string_col, 4) # тесьма

	# Правое ухо, слегка подвернутое на снегу
	k.box(Vector3(0.14, 0.035, -0.02), Vector3(0.10, 0.035, 0.14), fur_black, Basis(Vector3.FORWARD, deg_to_rad(25.0)))
	k.tube([Vector3(0.19, 0.015, 0.02), Vector3(0.24, 0.005, 0.08)], [0.005], string_col, 4)

	# Иней на ворсе
	k.box(Vector3(0, 0.165, 0.02), Vector3(0.12, 0.015, 0.12), fur_frost)

	return _mi(k, &"ushanka", "tex_fur.png")


## Рыбацкая жерлица / вешка у проруби с бечевкой, уходящей под лёд
static func ice_hole_rig() -> Node3D:
	var cached := _instance_from_cache(&"ice_hole_rig", "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(107, 0.04)
	var wood_col := Color(0.40, 0.34, 0.26)
	var wood_dark := Color(0.26, 0.22, 0.18)
	var cord_col := Color(0.12, 0.12, 0.12)
	var flag_red := Color(0.85, 0.16, 0.14)
	var ice_col := Color(0.65, 0.78, 0.85)

	# Наклонная оструганная деревянная жердь, вмороженная в лёд
	k.tube([Vector3(0, -0.2, 0), Vector3(0.22, 0.95, -0.08)], [0.032, 0.022], wood_col, 6)
	# Поперечная опорная крестовина на льду
	k.tube([Vector3(-0.25, 0.03, 0), Vector3(0.25, 0.03, 0)], [0.025], wood_dark, 5)
	k.tube([Vector3(0, 0.03, -0.25), Vector3(0, 0.03, 0.25)], [0.025], wood_dark, 5)

	# Намотка смоленой бечевки на развилке
	k.tube([Vector3(0.10, 0.45, -0.04), Vector3(0.14, 0.60, -0.05)], [0.045], cord_col, 6)
	# Провисающая нить лески, уходящая в воду
	k.tube([Vector3(0.12, 0.50, -0.04), Vector3(-0.35, 0.10, -0.2), Vector3(-0.65, -0.4, -0.3)], [0.007], cord_col, 4)

	# Пружинный металлический сигнализатор с красным флажком
	k.tube([Vector3(0.20, 0.88, -0.07), Vector3(0.28, 1.15, 0.05)], [0.006], Color(0.4, 0.4, 0.42), 4)
	k.box(Vector3(0.32, 1.15, 0.05), Vector3(0.08, 0.06, 0.008), flag_red)

	# Намерзший бугор льда в основании вешки
	k.tube([Vector3(0, -0.02, 0), Vector3(0, 0.08, 0)], [0.18, 0.08], ice_col, 8)

	return _mi(k, &"ice_hole_rig", "tex_wood.png")


## Дощатые сходни / мостки на сваях с перилами и упорами
static func pier_walkway(length: float) -> Node3D:
	var key := StringName("pier_walkway_%.1f" % length)
	var cached := _instance_from_cache(key, "tex_planks.png")
	if cached != null:
		return cached
	var k := _kit(108, 0.04)
	var plank_col := Color(0.44, 0.40, 0.35)
	var beam_col := Color(0.28, 0.25, 0.22)
	var rail_col := Color(0.36, 0.32, 0.27)
	var rope_col := Color(0.50, 0.45, 0.36)
	var nail_col := Color(0.15, 0.16, 0.17)

	# Продольные тяжелые несущие балки
	for sx in [-0.65, 0.65]:
		k.box(Vector3(sx, 0.04, 0), Vector3(0.12, 0.14, length), beam_col)

	# Настил из поперечных досок с неравномерными зазорами
	var num_planks := maxi(3, int(length / 0.20))
	var step := length / float(num_planks)
	for i in range(num_planks):
		var z := -length * 0.5 + (float(i) + 0.5) * step
		var w := 1.55 + 0.05 * ((i * 3) % 3)
		k.box(Vector3(0, 0.12, z), Vector3(w, 0.04, step * 0.86), plank_col)
		# Шляпки кованых гвоздей
		k.box(Vector3(-w * 0.44, 0.142, z), Vector3(0.014, 0.005, 0.014), nail_col)
		k.box(Vector3(w * 0.44, 0.142, z), Vector3(0.014, 0.005, 0.014), nail_col)

	# Стойки перил с канатом по левой и правой стороне
	var num_posts := maxi(2, int(length / 1.6))
	var p_step := length / float(num_posts)
	for i in range(num_posts + 1):
		var z := -length * 0.5 + float(i) * p_step
		for sx in [-0.72, 0.72]:
			k.tube([Vector3(sx, 0.05, z), Vector3(sx, 0.95, z)], [0.035, 0.03], rail_col, 5)

	# Натянутый страховочный канат между стойками
	for sx in [-0.72, 0.72]:
		k.tube([Vector3(sx, 0.88, -length * 0.5), Vector3(sx, 0.88, length * 0.5)], [0.014], rope_col, 5)

	return _mi(k, key, "tex_planks.png")


## Тканевые советские шторы с карнизом
static func curtains(width := 1.2, height := 1.35) -> Node3D:
	var root := Node3D.new()
	root.name = "Curtains"
	var rod_mat := Palette.m(&"wood")
	var cloth_mat := Palette.m(&"cloth")
	var dark_cloth := Palette.m(&"dark")

	# Карниз со штангой и наконечниками
	var rod := Geo.cylinder(root, 0.02, width + 0.16, Vector3(0, height * 0.5 + 0.04, 0), rod_mat, false)
	rod.rotation.z = deg_to_rad(90.0)
	Geo.block(root, Vector3(0.06, 0.06, 0.06), Vector3(-width * 0.5 - 0.08, height * 0.5 + 0.04, 0), rod_mat, false)
	Geo.block(root, Vector3(0.06, 0.06, 0.06), Vector3(width * 0.5 + 0.08, height * 0.5 + 0.04, 0), rod_mat, false)

	# Левая и правая свисающие шторы со складками
	var half_w := width * 0.26   # шторы подвязаны по краям: окно открыто, в нём видно, кто стоит снаружи
	for side: float in [-1.0, 1.0]:
		var panel := Node3D.new()
		panel.name = "PanelL" if side < 0 else "PanelR"
		panel.position = Vector3((width * 0.5 - half_w * 0.5) * side, height * 0.5, 0.02)
		root.add_child(panel)

		# Вертикальные драпированные складки
		for s in range(4):
			var fx := (-half_w * 0.5 + s * (half_w / 3.0))
			var fold := Geo.box_mesh(Vector3(half_w * 0.32, height, 0.02), cloth_mat if s % 2 == 0 else dark_cloth)
			fold.position = Vector3(fx, -height * 0.5, 0.008 if s % 2 == 0 else -0.008)
			panel.add_child(fold)

		# Подхват шторы (тесьма)
		var tie := Geo.box_mesh(Vector3(half_w * 1.05, 0.04, 0.05), Palette.m(&"paper"))
		tie.position = Vector3(0, -height * 0.65, 0)
		panel.add_child(tie)

	return root


## Советский настенный радиорепродуктор «Рекорд» (черная тарелка)
static func radio_speaker_plate() -> Node3D:
	var key := &"radio_plate"
	var cached := _instance_from_cache(key, "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(109, 0.03)
	var body_col := Color(0.12, 0.11, 0.11)
	var chrome_col := Color(0.72, 0.74, 0.76)
	var wire_col := Color(0.3, 0.28, 0.25)

	# Задняя пластина крепления к стене
	k.box(Vector3(0, 0, -0.04), Vector3(0.08, 0.12, 0.02), body_col)
	# Большой диффузор-тарелка (раструб конуса)
	k.tube([Vector3(0, 0, -0.03), Vector3(0, 0, 0.03)], [0.06, 0.24], body_col, 12, false, true)
	# Центральный хромированный колпачок
	k.blob(Vector3(0, 0, 0.035), Vector3(0.045, 0.045, 0.02), chrome_col, 4, 6)
	# Провод, спускающийся вниз
	k.tube([Vector3(0, -0.06, -0.04), Vector3(0.01, -0.35, -0.03)], [0.005], wire_col, 4)

	return _mi(k, key, "tex_metal.png")


## Настенный латунный барометр-анероид
static func barometer() -> Node3D:
	var key := &"barometer"
	var cached := _instance_from_cache(key, "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(110, 0.03)
	var brass := Color(0.68, 0.55, 0.28)
	var dial := Color(0.88, 0.86, 0.80)
	var pointer := Color(0.1, 0.1, 0.1)

	# Латунный цилиндрический корпус
	k.tube([Vector3(0, 0, -0.02), Vector3(0, 0, 0.02)], [0.12, 0.12], brass, 10, true, false)
	# Белый циферблат
	k.blob(Vector3(0, 0, 0.022), Vector3(0.105, 0.105, 0.004), dial, 6, 8)
	# Стрелка давления и деления
	k.box(Vector3(0, 0.035, 0.026), Vector3(0.006, 0.06, 0.002), pointer, Basis(Vector3.FORWARD, deg_to_rad(35.0)))
	# Кольцо подвеса сверху
	k.tube([Vector3(-0.02, 0.12, 0), Vector3(0, 0.15, 0), Vector3(0.02, 0.12, 0)], [0.008], brass, 4)

	return _mi(k, key, "tex_metal.png")


## Тканая дорожка / домотканый половик на дощатый пол: выцветшие тряпичные полосы неровной ширины,
## уток виден, середина вытоптана до серого, по краям бахрома. Картинка рисуется один раз и кэшируется.
static var _rug_tex: ImageTexture


static func carpet(width := 1.05, length := 3.4) -> Node3D:
	var root := Node3D.new()
	root.name = "Carpet"
	var plane := PlaneMesh.new()
	plane.size = Vector2(width, length)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	var m := StandardMaterial3D.new()
	m.albedo_texture = _rug_texture()
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.uv1_scale = Vector3(1.0, length / 3.2, 1.0)
	mi.material_override = m
	mi.position.y = 0.007
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	# Толщина половика — тёмная кромка снизу, чтобы край не «лип» к полу
	var under := Geo.box_mesh(Vector3(width - 0.01, 0.006, length - 0.01), _rug_edge_mat())
	under.position.y = 0.003
	root.add_child(under)
	# Бахрома по торцам: короткие кисти из той же основы
	var fr := _rug_edge_mat()
	for end_side: float in [-1.0, 1.0]:
		var n := int(width / 0.035)
		for k in n:
			var tassel := Geo.box_mesh(Vector3(0.012, 0.004, 0.06 + 0.02 * float(k % 3)), fr)
			tassel.position = Vector3(-width * 0.5 + 0.02 + k * (width - 0.04) / maxf(n - 1, 1), 0.004, end_side * (length * 0.5 + 0.03))
			tassel.rotation.y = 0.15 * sin(k * 1.7)
			root.add_child(tassel)
	return root


static func _rug_edge_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.48, 0.44, 0.38)
	m.roughness = 1.0
	return m


static func _rug_texture() -> ImageTexture:
	if _rug_tex != null:
		return _rug_tex
	var w := 256
	var h := 768
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1964
	# Полосы тряпичного утка: приглушённые, выцветшие (свёкла, пыльная синь, охра, серо-зелёный, суровый)
	var palette := [Color(0.46, 0.22, 0.2), Color(0.3, 0.36, 0.44), Color(0.58, 0.48, 0.3), Color(0.38, 0.42, 0.34),
		Color(0.62, 0.58, 0.5), Color(0.27, 0.24, 0.24), Color(0.52, 0.34, 0.3)]
	var bands: Array = []
	var y := 0
	while y < h:
		var bw := rng.randi_range(10, 46)
		bands.append([y, y + bw, palette[rng.randi() % palette.size()]])
		y += bw
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.02
	var wear := FastNoiseLite.new()
	wear.seed = 9
	wear.frequency = 0.008
	var base := Color(0.62, 0.58, 0.5)   # основа (суровая нить) — видна у краёв и в просветах
	for band: Array in bands:
		var c: Color = band[2]
		for yy in range(band[0], mini(band[1], h)):
			for x in w:
				var col := c
				# Тряпичная лента: каждая нить утка чуть другого тона, просветы основы через 4 пикселя
				var row_tone := 0.9 + 0.2 * sin(float(yy) * 2.1 + float(band[0]))
				col = col * row_tone
				if (x + (yy % 2) * 2) % 4 == 0:
					col = col.lerp(base, 0.35)
				# Неровно окрашено и выцвело пятнами
				col = col.lerp(base, 0.25 + 0.15 * noise.get_noise_2d(x, yy))
				# Вытоптанная середина — к серому
				var mid := 1.0 - absf(float(x) / w - 0.5) * 2.0
				var worn := clampf(mid * 0.55 + wear.get_noise_2d(x, yy) * 0.3, 0.0, 1.0)
				col = col.lerp(Color(0.45, 0.43, 0.4), worn * 0.45)
				# Кромка — плотная основа
				if x < 7 or x >= w - 7:
					col = base.darkened(0.15)
				img.set_pixel(x, yy, Color(col.r * 0.82, col.g * 0.8, col.b * 0.78, 1.0))   # приглушить: рядом с тёмным полом пастель резала глаз
	img.generate_mipmaps()
	_rug_tex = ImageTexture.create_from_image(img)
	return _rug_tex


## Настольная жестяная керосиновая лампа «Летучая мышь»
static func kerosene_lamp() -> Node3D:
	var glb := _kedr_model("kerosene_lamp", {"scale": 1.0, "bright": 1.15})
	if glb != null:
		return glb
	var key := &"kerosene_lamp"
	var cached := _instance_from_cache(key, "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(111, 0.03)
	var tin := Color(0.25, 0.26, 0.28)
	var brass := Color(0.62, 0.52, 0.28)
	var glass := Color(0.85, 0.90, 0.95)

	# Круглый резервуар для керосина снизу
	k.tube([Vector3(0, 0.0, 0), Vector3(0, 0.06, 0)], [0.08, 0.07], tin, 8, true, false)
	# Горелка с колесиком фитиля
	k.tube([Vector3(0, 0.06, 0), Vector3(0, 0.09, 0)], [0.045, 0.04], brass, 6)
	k.box(Vector3(0.045, 0.075, 0), Vector3(0.015, 0.015, 0.015), brass)
	# Стеклянная пузатая колба
	k.blob(Vector3(0, 0.16, 0), Vector3(0.055, 0.07, 0.055), glass, 5, 7)
	# Верхний металлический дефлектор и вытяжка
	k.tube([Vector3(0, 0.23, 0), Vector3(0, 0.28, 0)], [0.035, 0.05], tin, 6)
	k.blob(Vector3(0, 0.285, 0), Vector3(0.06, 0.012, 0.06), tin, 5, 6)
	# Проволочная дужка-ручка
	k.tube([Vector3(-0.06, 0.10, 0), Vector3(-0.07, 0.33, 0), Vector3(0, 0.35, 0), Vector3(0.07, 0.33, 0), Vector3(0.06, 0.10, 0)], [0.006], tin, 4)

	return _mi(k, key, "tex_metal.png")


## Наклонный люк старого ледника/погреба в сугробе за домом
static func cellar_hatch() -> Node3D:
	var key := &"cellar_hatch"
	var cached := _instance_from_cache(key, "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(112, 0.04)
	var wood := Color(0.32, 0.28, 0.23)
	var iron := Color(0.18, 0.19, 0.20)
	var snow := Color(0.85, 0.88, 0.94)

	# Наклонная коробка погреба из плах
	k.box(Vector3(0, 0.22, 0), Vector3(1.3, 0.44, 1.6), wood)
	# Наклонная двухстворчатая дощатая крышка
	k.box(Vector3(0, 0.46, 0.05), Vector3(1.36, 0.06, 1.65), wood * 1.1, Basis(Vector3.RIGHT, deg_to_rad(-18.0)))
	# Кованые амбарные петли
	for sx in [-0.45, 0.45]:
		k.box(Vector3(sx, 0.52, -0.6), Vector3(0.07, 0.02, 0.3), iron, Basis(Vector3.RIGHT, deg_to_rad(-18.0)))
		k.box(Vector3(sx, 0.42, 0.6), Vector3(0.07, 0.02, 0.2), iron, Basis(Vector3.RIGHT, deg_to_rad(-18.0)))
	# Кованая железная ручка-скоба
	k.tube([Vector3(-0.08, 0.45, 0.55), Vector3(-0.08, 0.50, 0.55), Vector3(0.08, 0.50, 0.55), Vector3(0.08, 0.45, 0.55)], [0.01], iron, 4)
	# Сугроб снега, наметенный к стенкам погреба
	k.blob(Vector3(-0.65, 0.15, -0.2), Vector3(0.35, 0.25, 0.8), snow, 4, 6)
	k.blob(Vector3(0.65, 0.15, 0.2), Vector3(0.35, 0.25, 0.8), snow, 4, 6)
	k.blob(Vector3(0, 0.1, -0.85), Vector3(0.7, 0.22, 0.4), snow, 4, 6)

	return _mi(k, key, "tex_wood.png")


## Приставная деревянная лестница
static func ladder(height := 2.6) -> Node3D:
	var key := StringName("ladder_" + str(int(height * 10)))
	var cached := _instance_from_cache(key, "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(113, 0.03)
	var wood := Color(0.42, 0.37, 0.31)

	# Тетивы (боковые брусья)
	for sx in [-0.22, 0.22]:
		k.box(Vector3(sx, height * 0.5, 0), Vector3(0.05, height, 0.08), wood)

	# Перекладины (ступени)
	var num_steps := int(height / 0.32)
	for i in range(1, num_steps):
		var y := float(i) * 0.32
		k.box(Vector3(0, y, 0), Vector3(0.44, 0.035, 0.04), wood * 0.95)

	return _mi(k, key, "tex_wood.png")


## Деревянный экспедиционный ящик снабжения
static func crate() -> Node3D:
	var key := &"crate"
	var cached := _instance_from_cache(key, "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(114, 0.04)
	var wood := Color(0.38, 0.29, 0.20)
	var iron := Color(0.20, 0.20, 0.22)
	k.box(Vector3(0, 0.3, 0), Vector3(0.8, 0.6, 0.6), wood)
	for sx in [-0.38, 0.38]:
		k.box(Vector3(sx, 0.3, 0), Vector3(0.04, 0.61, 0.61), iron)
	for sz in [-0.28, 0.28]:
		k.box(Vector3(0, 0.3, sz), Vector3(0.81, 0.61, 0.04), iron)
	return _mi(k, key, "tex_wood.png")


## Гранёная заснеженная ель тайги в кинематографичном low-poly стиле (по референсу 1):
## 4 плотных яруса ветвей с нависающими снежными шапками на гранях.
static func faceted_spruce(scale_mult := 1.0, seed_val := 42) -> Node3D:
	var root := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	# Ствол (гранёный тёмный цилиндр коры)
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.15 * scale_mult
	trunk_mesh.bottom_radius = 0.28 * scale_mult
	trunk_mesh.height = 5.2 * scale_mult
	trunk_mesh.radial_segments = 6
	trunk_mesh.material = Palette.m(&"bark")

	var trunk_inst := MeshInstance3D.new()
	trunk_inst.mesh = trunk_mesh
	trunk_inst.position.y = 2.6 * scale_mult
	root.add_child(trunk_inst)

	var tiers: Array[Dictionary] = [
		{"y": 0.35, "r_base": 2.35, "r_top": 0.55, "h": 2.05, "segs": 7, "snow_h": 1.15, "snow_r": 1.85},
		{"y": 1.75, "r_base": 1.95, "r_top": 0.42, "h": 1.95, "segs": 6, "snow_h": 1.10, "snow_r": 1.50},
		{"y": 3.10, "r_base": 1.45, "r_top": 0.28, "h": 1.75, "segs": 6, "snow_h": 0.98, "snow_r": 1.12},
		{"y": 4.35, "r_base": 0.92, "r_top": 0.0,  "h": 1.60, "segs": 5, "snow_h": 1.48, "snow_r": 0.88},
	]

	var needle_mat := Palette.m(&"tree")
	var snow_mat := Palette.m(&"snow")

	for i in range(tiers.size()):
		var t: Dictionary = tiers[i]
		var y_pos: float = float(t["y"]) * scale_mult
		var r_b: float = float(t["r_base"]) * scale_mult
		var r_t: float = float(t["r_top"]) * scale_mult
		var h: float = float(t["h"]) * scale_mult
		var segs: int = int(t["segs"])
		var rot_offset: float = rng.randf_range(-0.4, 0.4)

		var needle_mesh := CylinderMesh.new()
		needle_mesh.bottom_radius = r_b
		needle_mesh.top_radius = r_t
		needle_mesh.height = h
		needle_mesh.radial_segments = segs
		needle_mesh.material = needle_mat

		var needle_inst := MeshInstance3D.new()
		needle_inst.mesh = needle_mesh
		needle_inst.position.y = y_pos + (h * 0.5)
		needle_inst.rotation.y = rot_offset
		root.add_child(needle_inst)

		var snow_h: float = float(t["snow_h"]) * scale_mult
		var snow_r: float = float(t["snow_r"]) * scale_mult
		var snow_mesh := CylinderMesh.new()
		snow_mesh.bottom_radius = snow_r
		snow_mesh.top_radius = r_t * 0.42
		snow_mesh.height = snow_h
		snow_mesh.radial_segments = segs
		snow_mesh.material = snow_mat

		var snow_inst := MeshInstance3D.new()
		snow_inst.mesh = snow_mesh
		snow_inst.position.y = y_pos + h - (snow_h * 0.48)
		snow_inst.rotation.y = rot_offset + deg_to_rad(15.0)
		root.add_child(snow_inst)

	return root


## Тактильный переносной радиоприёмник (по образцу советских/ретро транзисторов, референс 2):
## Шкала частот со светящейся риской, круглая перфорированная решётка, выдвинутая антенна.
static func retro_transistor_radio() -> Node3D:
	var root := Node3D.new()
	var k := MeshKit.new(44)
	k.mottle = 0.02

	var body_col := Color(0.24, 0.27, 0.29)
	var panel_col := Color(0.18, 0.20, 0.22)
	var metal_col := Color(0.75, 0.77, 0.80)
	var dark_bay := Color(0.06, 0.06, 0.07)
	var white_mark := Color(0.95, 0.95, 0.92)

	k.box(Vector3(0, 0.13, 0), Vector3(0.20, 0.26, 0.08), body_col)
	k.box(Vector3(0, 0.13, 0.041), Vector3(0.185, 0.245, 0.003), panel_col)
	k.box(Vector3(0, 0.195, 0.044), Vector3(0.16, 0.065, 0.003), dark_bay)

	for i in range(8):
		var x := -0.062 + i * 0.0175
		var tick_h := 0.035 if i % 2 == 0 else 0.02
		k.box(Vector3(x, 0.198, 0.046), Vector3(0.002, tick_h, 0.002), white_mark)

	k.tube([Vector3(0, 0.085, 0.042), Vector3(0, 0.085, 0.045)], [0.046, 0.046], Color(0.12, 0.13, 0.14), 12)
	k.tube([Vector3(0, 0.085, 0.045), Vector3(0, 0.085, 0.047)], [0.048, 0.048], Color(0.48, 0.50, 0.52), 12, false, true)

	k.tube([Vector3(-0.045, 0.022, 0.042), Vector3(-0.045, 0.022, 0.056)], [0.016, 0.016], metal_col, 8)
	k.tube([Vector3(0.045, 0.022, 0.042), Vector3(0.045, 0.022, 0.056)], [0.016, 0.016], metal_col, 8)
	k.tube([Vector3(0.075, 0.26, 0.0), Vector3(0.075, 0.58, 0.0)], [0.0035, 0.002], metal_col, 6)

	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	var mat := _gained(Creatures._mat(&"retro_radio", Color.WHITE, "tex_metal.png", 0.0))
	mi.material_override = mat
	root.add_child(mi)

	Geo.block(root, Vector3(0.003, 0.045, 0.004), Vector3(0.008, 0.195, 0.048), Palette.glow(&"amber"), false)
	return root


## Советский недельный барограф М-22 (ГОСТ 7193-79) под стеклянным колпаком.
## Литое чугунное основание, стопка анероидных коробок, часовой барабан с лентой и пером.
static func barograph() -> Node3D:
	var glb := _kedr_model("barograph_m22")
	if glb != null:
		glb.add_child(_barograph_glass(Vector3(0.312, 0.148, 0.152), 0.112))
		return glb
	var root := Node3D.new()
	var k := _kit(88, 0.03)

	var cast_iron := Color(0.16, 0.20, 0.18)      # Заводская молотковая эмаль
	var brass := Color(0.82, 0.72, 0.38)          # Полированная латунь
	var aneroid_col := Color(0.70, 0.73, 0.75)    # Никелированные мембраны
	var paper_col := Color(0.92, 0.89, 0.80)      # Бумага диаграммной ленты
	var ink_col := Color(0.35, 0.12, 0.45)        # Фиолетовые чернила «Радуга»
	var glass_edge := Color(0.60, 0.75, 0.72)     # Латунные ребра колпака

	# 1. Чугунное основание со скошенными ножками
	k.box(Vector3(0, 0.015, 0), Vector3(0.34, 0.03, 0.18), cast_iron)
	for sx: float in [-0.15, 0.15]:
		for sz: float in [-0.07, 0.07]:
			k.box(Vector3(sx, 0.003, sz), Vector3(0.025, 0.006, 0.025), brass)

	# 2. Стопка анероидных коробок (сильфон слева, x = -0.08)
	k.box(Vector3(-0.08, 0.035, 0.0), Vector3(0.05, 0.01, 0.05), brass)
	for b in range(5):
		var by := 0.045 + b * 0.014
		k.tube([Vector3(-0.08, by, 0.0), Vector3(-0.08, by + 0.009, 0.0)], [0.038, 0.038], aneroid_col, 12)
		k.box(Vector3(-0.08, by + 0.009, 0.0), Vector3(0.012, 0.005, 0.012), brass)

	# 3. Рычажная передача и ось пера (центр)
	k.box(Vector3(-0.02, 0.07, 0.0), Vector3(0.015, 0.08, 0.015), brass)
	k.tube([Vector3(-0.08, 0.115, 0.0), Vector3(-0.02, 0.11, 0.0)], [0.004, 0.004], brass, 6)
	# Длинная упругая стрелка пера к барабану
	k.tube([Vector3(-0.02, 0.10, 0.0), Vector3(0.045, 0.09, 0.028)], [0.0025, 0.0015], Color(0.1, 0.1, 0.1), 4)
	# Перо с фиолетовыми чернилами
	k.box(Vector3(0.046, 0.09, 0.03), Vector3(0.004, 0.006, 0.003), ink_col)

	# 4. Часовой барабан с лентой (справа, x = 0.08)
	k.tube([Vector3(0.08, 0.03, 0.0), Vector3(0.08, 0.155, 0.0)], [0.046, 0.046], brass, 16)
	# Диаграммная лента на барабане
	k.tube([Vector3(0.08, 0.035, 0.0), Vector3(0.08, 0.145, 0.0)], [0.0475, 0.0475], paper_col, 16)
	# Тонкая чернильная линия на ленте
	k.tube([Vector3(0.08, 0.088, 0.0), Vector3(0.08, 0.092, 0.0)], [0.048, 0.048], ink_col, 16)

	# 5. Заводной ключ и верхний винт барабана
	k.box(Vector3(0.08, 0.16, 0.0), Vector3(0.015, 0.01, 0.015), brass)
	k.box(Vector3(0.08, 0.165, 0.0), Vector3(0.03, 0.006, 0.008), brass)

	# 6. Латунная табличка прибора
	k.box(Vector3(0.0, 0.022, 0.091), Vector3(0.12, 0.016, 0.002), brass)

	# 7. Стеклянный колпак (рёбра и ручка)
	k.box(Vector3(0, 0.10, 0), Vector3(0.32, 0.004, 0.16), glass_edge)
	k.box(Vector3(0, 0.185, 0), Vector3(0.32, 0.004, 0.16), glass_edge)
	for cx: float in [-0.158, 0.158]:
		for cz: float in [-0.078, 0.078]:
			k.box(Vector3(cx, 0.10, cz), Vector3(0.005, 0.165, 0.005), glass_edge)
	# Ручка для поднятия колпака
	k.box(Vector3(0, 0.192, 0), Vector3(0.04, 0.012, 0.015), brass)

	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	var mat := _gained(Creatures._mat(&"prop_barograph", Color.WHITE, "tex_metal.png", 0.0))
	mi.material_override = mat
	root.add_child(mi)

	root.add_child(_barograph_glass(Vector3(0.315, 0.155, 0.155), 0.108))
	return root


## Прозрачное стекло колпака барографа (BoxMesh с прозрачным материалом)
static func _barograph_glass(size: Vector3, y: float) -> MeshInstance3D:
	var glass_box := MeshInstance3D.new()
	var bmesh := BoxMesh.new()
	bmesh.size = size
	glass_box.mesh = bmesh
	glass_box.position = Vector3(0, y, 0)
	var gmat := StandardMaterial3D.new()
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmat.albedo_color = Color(0.70, 0.88, 0.92, 0.22)
	gmat.roughness = 0.1
	glass_box.material_override = gmat
	glass_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return glass_box


## Оптический метеорологический теодолит АШТ / ПТ-1 на чугунной треноге.
static func theodolite() -> Node3D:
	var root := Node3D.new()
	var k := _kit(99, 0.04)

	var wood_leg := Color(0.26, 0.19, 0.13)       # Березовые бруски штатива
	var cast_green := Color(0.20, 0.25, 0.22)     # Приборный серо-зеленый молотковый лак
	var brass := Color(0.80, 0.70, 0.35)          # Латунные винты и шкалы
	var optics_black := Color(0.12, 0.13, 0.14)   # Матовое чернение зрительной трубы

	# 1. Три раздвижные деревянные ноги штатива до земли (h = 1.35)
	for leg_idx in range(3):
		var ang := deg_to_rad(leg_idx * 120.0 + 30.0)
		var top_pos := Vector3(cos(ang) * 0.10, 1.28, sin(ang) * 0.10)
		var bot_pos := Vector3(cos(ang) * 0.42, 0.0, sin(ang) * 0.42)
		k.tube([top_pos, bot_pos], [0.024, 0.016], wood_leg, 6)
		# Металлические наконечники в снег
		k.tube([bot_pos, bot_pos + Vector3(0, -0.06, 0)], [0.016, 0.005], Color(0.3, 0.3, 0.3), 4)

	# 2. Массивная головка штатива и становая плита
	k.tube([Vector3(0, 1.28, 0), Vector3(0, 1.32, 0)], [0.12, 0.12], cast_green, 12)
	# Три подъемных винта
	for i in range(3):
		var a := deg_to_rad(i * 120.0)
		var vpos := Vector3(cos(a) * 0.07, 1.33, sin(a) * 0.07)
		k.tube([vpos, vpos + Vector3(0, 0.03, 0)], [0.014, 0.014], brass, 8)

	# 3. Подставка с горизонтальным кругом (лимбом азимута)
	k.tube([Vector3(0, 1.35, 0), Vector3(0, 1.40, 0)], [0.09, 0.08], cast_green, 16)
	k.tube([Vector3(0, 1.39, 0), Vector3(0, 1.41, 0)], [0.092, 0.092], brass, 16)

	# 4. Колонки алидады (U-образная вилка)
	for sx: float in [-0.055, 0.055]:
		k.box(Vector3(sx, 1.48, 0), Vector3(0.026, 0.16, 0.04), cast_green)
		k.tube([Vector3(sx, 1.54, 0), Vector3(sx * 1.3, 1.54, 0)], [0.014, 0.014], brass, 8)

	# 5. Оптическая зрительная труба с вертикальным кругом
	# Корпус трубы под углом к небу (~35 градусов)
	var rot_x := deg_to_rad(35.0)
	var fwd := Vector3(0, sin(rot_x), -cos(rot_x))
	var obj_pos := Vector3(0, 1.54, 0) + fwd * 0.16
	var eye_pos := Vector3(0, 1.54, 0) - fwd * 0.14
	k.tube([eye_pos, obj_pos], [0.022, 0.028], optics_black, 12)
	# Окуляр
	k.tube([eye_pos, eye_pos - fwd * 0.03], [0.016, 0.016], brass, 10)
	# Объектив (бленда)
	k.tube([obj_pos, obj_pos + fwd * 0.04], [0.032, 0.034], cast_green, 12)
	# Вертикальный круг с делениями
	k.tube([Vector3(0.06, 1.54, 0), Vector3(0.075, 1.54, 0)], [0.055, 0.055], brass, 16)

	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	var mat := _gained(Creatures._mat(&"prop_theodolite", Color.WHITE, "tex_metal.png", 0.0))
	mi.material_override = mat
	root.add_child(mi)

	return root


## Пусковой пост шаров-пилотов: 40-литровый водородный баллон с редуктором и ящик с шарами.
static func balloon_stand() -> Node3D:
	var root := Node3D.new()
	var k := _kit(77, 0.04)

	var steel_red := Color(0.48, 0.16, 0.14)     # Баллон водорода ГОСТ (красно-коричневый)
	var brass := Color(0.82, 0.72, 0.38)         # Вентили высокого давления
	var wood_box := Color(0.24, 0.18, 0.12)      # Деревянный ящик снабжения
	var white_latex := Color(0.92, 0.94, 0.95)   # Свернутые резиновые шары

	# 1. Стальной 40-литровый баллон водорода
	# Башмак баллона в снегу
	k.box(Vector3(0, 0.04, 0), Vector3(0.24, 0.08, 0.24), Color(0.18, 0.18, 0.20))
	# Цилиндрический корпус баллона
	k.tube([Vector3(0, 0.08, 0), Vector3(0, 1.25, 0)], [0.11, 0.11], steel_red, 16)
	# Сферическая горловина
	k.tube([Vector3(0, 1.25, 0), Vector3(0, 1.36, 0)], [0.11, 0.04], steel_red, 12)

	# 2. Вентиль ВВ-400 и редуктор с двумя манометрами
	k.tube([Vector3(0, 1.36, 0), Vector3(0, 1.44, 0)], [0.024, 0.02], brass, 8)
	k.box(Vector3(0.04, 1.42, 0), Vector3(0.06, 0.03, 0.04), brass)
	# Два круглых стрелочных манометра
	for m in range(2):
		var mz := -0.03 + m * 0.06
		k.tube([Vector3(0.07, 1.45, mz), Vector3(0.09, 1.45, mz)], [0.026, 0.026], Color(0.9, 0.9, 0.88), 10)
		k.box(Vector3(0.091, 1.45, mz), Vector3(0.002, 0.018, 0.003), Color(0.1, 0.1, 0.1))

	# Гибкий заправочный шланг
	k.tube([Vector3(0.05, 1.40, -0.04), Vector3(0.15, 1.10, -0.10), Vector3(0.26, 0.65, -0.05)], [0.012, 0.012], Color(0.15, 0.15, 0.16), 6)

	# 3. Деревянный ящик со сложенными шарами и фонариками (рядом на снегу)
	k.box(Vector3(0.42, 0.18, 0.0), Vector3(0.46, 0.36, 0.40), wood_box)
	k.box(Vector3(0.42, 0.35, 0.0), Vector3(0.42, 0.03, 0.36), Color(0.12, 0.10, 0.08))
	# Оболочки шаров
	k.tube([Vector3(0.36, 0.36, 0.0), Vector3(0.36, 0.42, 0.0)], [0.09, 0.08], white_latex, 8)
	# Бумажный фонарик со свечой
	k.box(Vector3(0.52, 0.42, 0.0), Vector3(0.12, 0.15, 0.12), Color(0.85, 0.82, 0.70))

	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	var mat := _gained(Creatures._mat(&"prop_balloon_stand", Color.WHITE, "tex_metal.png", 0.0))
	mi.material_override = mat
	root.add_child(mi)

	return root


## Надутый шар-пилот со свечным фонариком для ночного зондирования атмосферы.
static func pilot_balloon() -> Node3D:
	var root := Node3D.new()

	# 1. Белый латексный шар
	var balloon_mesh := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.32
	sm.height = 0.70
	balloon_mesh.mesh = sm
	balloon_mesh.position = Vector3(0, 1.1, 0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.92, 0.94, 0.96, 0.95)
	bmat.roughness = 0.3
	balloon_mesh.material_override = bmat
	root.add_child(balloon_mesh)

	# 2. Шнур подвески
	var cord := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.003
	cm.bottom_radius = 0.003
	cm.height = 0.75
	cord.mesh = cm
	cord.position = Vector3(0, 0.42, 0)
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.2, 0.2, 0.2)
	cord.material_override = cmat
	root.add_child(cord)

	# 3. Бумажный фонарик со свечой
	var lantern := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.14, 0.18, 0.14)
	lantern.mesh = lm
	lantern.position = Vector3(0, 0.0, 0)
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(0.95, 0.88, 0.65)
	lmat.emission_enabled = true
	lmat.emission = Color(1.0, 0.75, 0.35)
	lmat.emission_energy_multiplier = 1.4
	lantern.material_override = lmat
	root.add_child(lantern)

	# 4. Светящийся огонек свечи с широким освещением двора
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.82, 0.45)
	light.light_energy = 1.6
	light.omni_range = 22.0   # свечной фонарик: светит на двор, пока шар низко, а не заливает всю тайгу
	light.omni_attenuation = 1.1
	light.shadow_enabled = false
	root.add_child(light)

	return root


## Одностоечная деревянная опора ЛЭП 0.4 кВ: траверса вдоль локальной оси X, два фарфоровых изолятора на концах.
## Провода крепятся к верху изоляторов — точки отдаёт pole_wire_points().
const POLE_INS_X := 0.62

static func pole_wire_points(height := 5.4) -> Array[Vector3]:
	var top := height - 0.30 + 0.05 + 0.26
	return [Vector3(-POLE_INS_X, top, 0), Vector3(POLE_INS_X, top, 0)]


static func utility_pole(height := 5.4) -> Node3D:
	var key := StringName("utility_pole_v2_%.2f" % height)
	var cached := _instance_from_cache(key, "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(95, 0.10)
	var creosote := Color(0.20, 0.15, 0.11)
	var wood := Color(0.46, 0.38, 0.29)
	var wood_dark := Color(0.34, 0.27, 0.20)
	var steel := Color(0.36, 0.38, 0.40)
	var porcelain := Color(0.90, 0.92, 0.88)
	var snow := Color(0.86, 0.90, 0.95)

	# 1. Столб: комель в креозоте, выше — выветренное дерево, сверху шатровый затёсок
	k.tube([
		Vector3(0, 0, 0),
		Vector3(0, 1.4, 0),
		Vector3(0.015, height * 0.55, 0.01),
		Vector3(0, height - 0.12, 0)
	], [0.19, 0.17, 0.14, 0.11], wood, 10, true, false, [creosote, wood, wood])
	k.spike(Vector3(0, height - 0.12, 0), Vector3(0, height + 0.12, 0), 0.11, wood_dark, 10)

	# 2. Траверса и деревянные подкосы к её концам
	var arm_y := height - 0.30
	k.box(Vector3(0, arm_y, 0), Vector3(1.7, 0.13, 0.15), wood_dark)
	for sx: float in [-1.0, 1.0]:
		k.tube([Vector3(0, arm_y - 0.62, 0.0), Vector3(sx * 0.62, arm_y - 0.04, 0.0)], [0.045], wood_dark, 5)
	# Стальной болт-стяжка и шайбы на столбе
	k.box(Vector3(0, arm_y, 0.11), Vector3(0.30, 0.05, 0.04), steel)

	# 3. Штыревые изоляторы ТФ-20: штырь, широкий колокол с юбкой, шапка снега
	for sx: float in [-POLE_INS_X, POLE_INS_X]:
		k.box(Vector3(sx, arm_y + 0.10, 0), Vector3(0.035, 0.14, 0.035), steel)
		k.tube([Vector3(sx, arm_y + 0.07, 0), Vector3(sx, arm_y + 0.15, 0), Vector3(sx, arm_y + 0.26, 0)], [0.095, 0.075, 0.045], porcelain, 8, true, true)
		k.box(Vector3(sx, arm_y + 0.275, 0), Vector3(0.07, 0.025, 0.07), snow)

	# 4. Скобы-ступени для монтёра по обе стороны столба
	for i in range(5):
		var y := 1.4 + float(i) * 0.65
		var sx := 0.18 if (i % 2 == 0) else -0.18
		k.box(Vector3(sx, y, 0), Vector3(0.16, 0.03, 0.03), steel)

	# 5. Табличка с номером опоры
	k.box(Vector3(0, 2.4, 0.15), Vector3(0.26, 0.16, 0.012), Color(0.82, 0.80, 0.70))

	return _mi(k, key, "tex_wood.png")


## Советский снегозадерживающий решётчатый щит (СД-1) с опорными укосинами.
static func snow_fence(length := 2.6, height := 1.7) -> Node3D:
	var key := StringName("snow_fence_%.2f_%.2f" % [length, height])
	var cached := _instance_from_cache(key, "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(96, 0.06)
	var wood := Color(0.32, 0.25, 0.18)
	var wood_dark := Color(0.22, 0.17, 0.12)
	var snow := Color(0.88, 0.91, 0.96)

	var half_len := length * 0.5
	# Вертикальные опорные стойки (по краям и в центре)
	for sx: float in [-half_len + 0.1, 0.0, half_len - 0.1]:
		k.box(Vector3(sx, height * 0.5, 0), Vector3(0.08, height, 0.08), wood_dark)
		# Наклонная укосина с подветренной стороны (+Z)
		k.tube([Vector3(sx, height * 0.75, 0), Vector3(sx, 0.0, 0.9)], [0.035], wood, 4)

	# Горизонтальные дощатые планки с зазорами (6 рядов)
	var rows := 6
	for r in range(rows):
		var y := 0.25 + float(r) * (height - 0.35) / float(rows - 1)
		k.box(Vector3(0, y, -0.04), Vector3(length, 0.11, 0.025), wood)
		# Шапка снега на верхней планке
		if r == rows - 1:
			k.box(Vector3(0, y + 0.06, -0.04), Vector3(length, 0.03, 0.05), snow)

	return _mi(k, key, "tex_wood.png")


## Экспедиционные деревянные сани-волокуши геодезистов (1965 г.) с обледенелым брезентом и ящиками.
static func surveyor_sledge() -> Node3D:
	var key := &"surveyor_sledge_v1"
	var cached := _instance_from_cache(key, "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(160, 0.08)
	var wood := Color(0.34, 0.26, 0.18)
	var wood_dark := Color(0.24, 0.18, 0.12)
	var wood_aged := Color(0.28, 0.22, 0.16)
	var steel := Color(0.18, 0.18, 0.20)
	var tarp := Color(0.22, 0.27, 0.23)      # выцветший брезент хаки
	var tarp_dark := Color(0.16, 0.20, 0.17)
	var snow := Color(0.88, 0.91, 0.96)
	var ice := Color(0.72, 0.82, 0.92)
	var red_strap := Color(0.55, 0.12, 0.10)
	var rope := Color(0.48, 0.42, 0.32)

	# 1. Массивные полозья (два продольных бруса с загнутыми носками спереди, по -Z)
	for sx: float in [-0.55, 0.55]:
		# Прямая часть полоза
		k.box(Vector3(sx, 0.10, 0.15), Vector3(0.14, 0.18, 2.5), wood_dark)
		# Стальной подрез на подошве полоза
		k.box(Vector3(sx, 0.01, 0.15), Vector3(0.14, 0.02, 2.5), steel)
		# Загнутый носок (под наклоном вверх спереди -Z)
		var nose_rot := Basis(Vector3.RIGHT, deg_to_rad(-30.0))
		k.box(Vector3(sx, 0.22, -1.32), Vector3(0.14, 0.16, 0.65), wood_dark, nose_rot)
		k.box(Vector3(sx, 0.18, -1.34), Vector3(0.14, 0.02, 0.65), steel, nose_rot)
		# Оковка носка железом
		k.box(Vector3(sx, 0.38, -1.58), Vector3(0.15, 0.12, 0.08), steel)

	# 2. Поперечные брусья (нащепы/копылья)
	for sz: float in [-0.8, -0.25, 0.35, 0.95]:
		k.box(Vector3(0, 0.22, sz), Vector3(1.36, 0.10, 0.12), wood)
		# Металлические кованые скобы крепления к полозьям
		for sx: float in [-0.55, 0.55]:
			k.box(Vector3(sx, 0.22, sz), Vector3(0.16, 0.12, 0.14), steel)

	# 3. Дощатый настил волокуш (5 продольных досок с зазорами)
	for i in range(5):
		var px := -0.44 + float(i) * 0.22
		k.box(Vector3(px, 0.28, 0.10), Vector3(0.19, 0.035, 2.3), wood_aged.darkened(0.04 * float(i % 2)))

	# 4. Боковые стойки (стойки бортов для фиксации груза)
	for sz: float in [-0.75, 0.0, 0.75]:
		for sx: float in [-0.62, 0.62]:
			k.box(Vector3(sx, 0.42, sz), Vector3(0.06, 0.32, 0.06), wood_dark)
	# Продольные бортовые жерди
	for sx: float in [-0.62, 0.62]:
		k.box(Vector3(sx, 0.55, 0.05), Vector3(0.05, 0.06, 2.1), wood)

	# 5. Груз на санях:
	# А) Деревянный экспедиционный ящик с маркировкой (впереди)
	k.box(Vector3(-0.18, 0.46, -0.65), Vector3(0.65, 0.32, 0.55), wood_dark)
	k.box(Vector3(-0.18, 0.46, -0.65), Vector3(0.67, 0.30, 0.03), steel) # стальная лента ящика
	k.box(Vector3(-0.18, 0.46, -0.65), Vector3(0.03, 0.30, 0.57), steel)
	# Шапка наста на ящике
	k.box(Vector3(-0.18, 0.63, -0.65), Vector3(0.60, 0.04, 0.50), snow)

	# Б) Обледенелый брезентовый тюк (основной груз сзади)
	k.box(Vector3(0.02, 0.52, 0.35), Vector3(1.05, 0.44, 1.35), tarp)
	k.box(Vector3(0.02, 0.76, 0.30), Vector3(0.85, 0.12, 1.10), tarp_dark)
	k.box(Vector3(0.02, 0.83, 0.25), Vector3(0.70, 0.08, 0.85), tarp)
	# Снежные наплывы и ледяная корка на брезенте
	k.box(Vector3(0.02, 0.88, 0.25), Vector3(0.65, 0.05, 0.80), snow)
	k.box(Vector3(0.25, 0.78, 0.45), Vector3(0.40, 0.04, 0.55), ice)
	k.box(Vector3(-0.20, 0.76, 0.15), Vector3(0.35, 0.05, 0.45), snow)

	# В) Увязочные канаты крест-накрест поверх брезента
	for rz: float in [-0.15, 0.35, 0.80]:
		k.box(Vector3(0.02, 0.75, rz), Vector3(1.10, 0.03, 0.03), rope)
	k.box(Vector3(0.02, 0.76, 0.35), Vector3(0.03, 0.03, 1.40), rope)

	# Г) Геодезическая красно-белая веха, привязанная вдоль борта
	k.tube([Vector3(0.66, 0.40, -1.2), Vector3(0.66, 0.40, 1.1)], [0.025], Color(0.9, 0.9, 0.9), 6)
	for seg in range(4):
		var pz := -0.9 + float(seg) * 0.55
		k.box(Vector3(0.66, 0.40, pz), Vector3(0.055, 0.055, 0.22), red_strap)

	var root := _mi(k, key, "tex_wood.png")
	var col := StaticBody3D.new()
	col.collision_layer = Geo.LAYER_WORLD
	col.add_child(Geo.box_shape(Vector3(1.45, 0.95, 3.1), Vector3(0, 0.45, 0)))
	root.add_child(col)
	return root


## Широкие охотничьи лыжи Семёнова с палками и юфтевыми креплениями
static func hunting_skis() -> Node3D:
	var key := &"hunting_skis"
	var cached := _instance_from_cache(key, "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(44, 0.05)
	var wood := Color(0.62, 0.48, 0.32)
	var wood_dark := Color(0.36, 0.26, 0.16)
	var leather := Color(0.22, 0.15, 0.10)
	var metal := Color(0.42, 0.44, 0.46)
	var ring_col := Color(0.25, 0.25, 0.25)
	for sx: float in [-0.10, 0.10]:
		k.box(Vector3(sx, 0.82, -0.04), Vector3(0.13, 1.60, 0.02), wood)
		k.box(Vector3(sx, 0.82, -0.052), Vector3(0.11, 1.58, 0.005), wood_dark)
		k.box(Vector3(sx, 1.66, 0.03), Vector3(0.12, 0.12, 0.02), wood)
		k.box(Vector3(sx, 1.72, 0.08), Vector3(0.11, 0.06, 0.02), wood)
		k.box(Vector3(sx, 0.80, -0.015), Vector3(0.11, 0.28, 0.02), leather)
		k.box(Vector3(sx, 0.86, 0.01), Vector3(0.12, 0.04, 0.04), leather)
		k.box(Vector3(sx, 0.86, 0.01), Vector3(0.13, 0.01, 0.01), metal)
	for sx: float in [-0.22, 0.22]:
		k.tube([Vector3(sx, 0.02, 0.02), Vector3(sx * 0.9, 1.40, 0.02)], [0.014, 0.011], Color(0.70, 0.62, 0.45), 5)
		k.tube([Vector3(sx, 0.12, 0.02), Vector3(sx, 0.13, 0.02)], [0.065, 0.065], ring_col, 8)
		k.box(Vector3(sx, 0.125, 0.02), Vector3(0.13, 0.01, 0.01), leather)
		k.box(Vector3(sx, 0.125, 0.02), Vector3(0.01, 0.01, 0.13), leather)
		k.box(Vector3(sx * 0.9, 1.34, 0.02), Vector3(0.03, 0.14, 0.03), leather)
		k.box(Vector3(sx * 0.9, 1.39, -0.01), Vector3(0.015, 0.08, 0.04), leather)
	return _mi(k, key, "tex_wood.png")


## Советский весовой снегомер ВС-43 (дюралевая труба со шкалой и безмен)
static func snow_tube_vs43() -> Node3D:
	var key := &"snow_tube_vs43"
	var cached := _instance_from_cache(key, "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(52, 0.04)
	var dural := Color(0.74, 0.77, 0.80)
	var steel := Color(0.35, 0.38, 0.42)
	var black := Color(0.12, 0.12, 0.14)
	var brass := Color(0.75, 0.62, 0.28)
	k.tube([Vector3(0, 0.0, 0), Vector3(0, 1.25, 0)], [0.04, 0.04], dural, 8)
	k.tube([Vector3(0, 0.0, 0), Vector3(0, 0.06, 0)], [0.043, 0.041], steel, 8)
	for i in range(8):
		var a := float(i) * TAU / 8.0
		k.spike(Vector3(cos(a) * 0.041, 0.01, sin(a) * 0.041), Vector3(cos(a) * 0.041, -0.015, sin(a) * 0.041), 0.008, steel, 3)
	for s in range(1, 12):
		var y := float(s) * 0.10
		k.tube([Vector3(0, y - 0.002, 0), Vector3(0, y + 0.002, 0)], [0.041, 0.041], black, 8)
	k.box(Vector3(0, 1.26, 0), Vector3(0.18, 0.022, 0.03), steel)
	k.tube([Vector3(0, 1.27, 0), Vector3(0, 1.31, 0)], [0.018, 0.018], steel, 6)
	k.tube([Vector3(0.14, 0.90, 0), Vector3(0.14, 1.18, 0)], [0.024, 0.024], brass, 8)
	k.box(Vector3(0.14, 1.04, 0.02), Vector3(0.015, 0.16, 0.01), black)
	k.tube([Vector3(0.14, 0.84, 0), Vector3(0.14, 0.90, 0)], [0.006, 0.006], steel, 4)
	k.tube([Vector3(0.14, 0.81, 0), Vector3(0.14, 0.84, 0)], [0.018, 0.018], steel, 6)
	k.tube([Vector3(0.14, 1.18, 0), Vector3(0.14, 1.24, 0)], [0.016, 0.016], steel, 6)
	return _mi(k, key, "tex_metal.png")


## Снегомерная веха-рейка (высокая полосатая рейка в сугробе)
static func survey_stake() -> Node3D:
	var key := &"survey_stake"
	var cached := _instance_from_cache(key, "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(63, 0.05)
	var white := Color(0.88, 0.90, 0.92)
	var red := Color(0.72, 0.18, 0.14)
	var black := Color(0.14, 0.14, 0.16)
	var snow := Color(0.85, 0.88, 0.94)
	k.blob(Vector3(0, 0.15, 0), Vector3(0.55, 0.22, 0.55), snow, 4, 6)
	k.box(Vector3(0, 1.20, 0), Vector3(0.07, 2.40, 0.07), white)
	for seg in range(6):
		var y := 0.25 + float(seg) * 0.35
		var col := red if seg % 2 == 0 else black
		k.box(Vector3(0, y, 0), Vector3(0.076, 0.14, 0.076), col)
	k.box(Vector3(0, 2.25, 0.04), Vector3(0.16, 0.10, 0.01), Color(0.75, 0.76, 0.78))
	k.box(Vector3(0, 2.42, 0), Vector3(0.10, 0.04, 0.10), snow)
	return _mi(k, key, "tex_wood.png")


## Геодезическая триангуляционная вышка на сопке (День 2)
static func triangulation_tower() -> Node3D:
	var key := &"triangulation_tower"
	var cached := _instance_from_cache(key, "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(71, 0.07)
	var log_col := Color(0.32, 0.24, 0.16)
	var log_dark := Color(0.22, 0.16, 0.11)
	var steel := Color(0.40, 0.42, 0.45)
	var snow := Color(0.86, 0.89, 0.95)
	var h := 4.8
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var bottom := Vector3(sx * 1.5, 0.0, sz * 1.5)
			var top := Vector3(sx * 0.25, h, sz * 0.25)
			k.tube([bottom, top], [0.11, 0.07], log_col, 6)
	for tier in [1.4, 2.8, 4.0]:
		var scale_w := lerpf(1.5, 0.25, tier / h)
		for i in range(4):
			var a := Vector3(scale_w, tier, scale_w).rotated(Vector3.UP, float(i) * PI * 0.5)
			var b := Vector3(scale_w, tier, scale_w).rotated(Vector3.UP, float(i + 1) * PI * 0.5)
			k.tube([a, b], [0.05, 0.05], log_dark, 5)
			var cross_mid := (a + b) * 0.5 + Vector3(0, 0.6, 0)
			k.tube([a, cross_mid], [0.035, 0.035], log_dark, 4)
	k.tube([Vector3(0, 3.5, 0), Vector3(0, h + 0.9, 0)], [0.06, 0.04], steel, 6)
	k.tube([Vector3(0, h + 0.4, 0), Vector3(0, h + 0.85, 0)], [0.18, 0.18], steel, 8)
	for sx: float in [-0.8, 0.8]:
		k.box(Vector3(sx, 1.45, 0), Vector3(0.12, 0.05, 1.2), snow)
	k.tube([Vector3(2.2, 0, 0.6), Vector3(2.1, 4.0, 0.5)], [0.18, 0.14], Color(0.24, 0.17, 0.12), 6)
	k.box(Vector3(2.02, 1.45, 0.58), Vector3(0.08, 0.06, 0.12), Color(0.65, 0.68, 0.70))
	k.box(Vector3(2.00, 1.47, 0.58), Vector3(0.02, 0.03, 0.08), Color(0.78, 0.25, 0.15))
	return _mi(k, key, "tex_wood.png")


## Таёжный охотничий лабаз на сваях (День 3)
static func storage_cache_shed() -> Node3D:
	var key := &"storage_cache_shed"
	var cached := _instance_from_cache(key, "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(82, 0.06)
	var log_col := Color(0.28, 0.20, 0.14)
	var log_aged := Color(0.19, 0.14, 0.09)
	var board_col := Color(0.38, 0.29, 0.20)
	var blood_claw := Color(0.28, 0.08, 0.06)
	var snow := Color(0.86, 0.89, 0.95)
	for sx: float in [-0.95, 0.95]:
		for sz: float in [-0.85, 0.85]:
			k.tube([Vector3(sx, 0, sz), Vector3(sx, 2.85, sz)], [0.13, 0.10], log_col, 6)
			k.tube([Vector3(sx, 2.35, sz), Vector3(sx, 2.45, sz)], [0.26, 0.26], log_aged, 8)
	k.box(Vector3(0, 2.85, 0), Vector3(2.3, 0.14, 2.1), log_aged)
	for tier in range(7):
		var y := 2.95 + float(tier) * 0.18
		for sz: float in [-0.95, 0.95]:
			k.box(Vector3(0, y, sz), Vector3(2.15, 0.16, 0.18), log_col)
		for sx: float in [-1.0, 1.0]:
			k.box(Vector3(sx, y, 0), Vector3(0.18, 0.16, 1.85), log_col)
	k.box(Vector3(0, 4.30, 0), Vector3(2.50, 0.08, 2.30), board_col)
	k.box(Vector3(0, 4.42, 0), Vector3(2.55, 0.16, 2.35), snow)
	for c in range(4):
		var y := 2.65 + float(c) * 0.12
		k.box(Vector3(0.96, y, -0.73), Vector3(0.04, 0.08, 0.02), blood_claw)
		k.box(Vector3(0.97, y + 0.02, -0.73), Vector3(0.02, 0.06, 0.015), Color(0.10, 0.05, 0.04))
	k.box(Vector3(0.4, 0.15, 1.5), Vector3(0.35, 0.08, 1.8), board_col)
	return _mi(k, key, "tex_wood.png")


## Заброшенная полуземлянка геодезистов (День 4)
static func hunter_dugout() -> Node3D:
	var key := &"hunter_dugout"
	var cached := _instance_from_cache(key, "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(93, 0.08)
	var turf := Color(0.24, 0.18, 0.12)
	var log_col := Color(0.26, 0.19, 0.13)
	var rusty := Color(0.34, 0.22, 0.16)
	var snow := Color(0.85, 0.88, 0.94)
	k.blob(Vector3(0, 0.8, -0.6), Vector3(2.4, 1.1, 2.2), turf, 5, 8)
	k.blob(Vector3(0, 1.4, -0.6), Vector3(2.1, 0.45, 1.9), snow, 4, 7)
	for tier in range(6):
		var y := 0.15 + float(tier) * 0.22
		k.box(Vector3(-1.2, y, 0.8), Vector3(0.9, 0.20, 0.22), log_col)
		k.box(Vector3(1.2, y, 0.8), Vector3(0.9, 0.20, 0.22), log_col)
	k.box(Vector3(0, 1.45, 0.8), Vector3(3.1, 0.22, 0.24), log_col)
	k.box(Vector3(0, 0.65, 0.70), Vector3(0.85, 1.25, 0.06), Color(0.12, 0.09, 0.06))
	k.box(Vector3(-0.15, 0.55, 0.74), Vector3(0.25, 1.10, 0.04), Color(0.32, 0.22, 0.14))
	k.tube([Vector3(0.6, 1.2, -0.4), Vector3(0.6, 2.45, -0.4)], [0.06, 0.06], rusty, 6)
	k.tube([Vector3(0.6, 2.45, -0.4), Vector3(0.6, 2.65, -0.4)], [0.12, 0.04], rusty, 6)
	k.tube([Vector3(0.4, 0.1, 0.0), Vector3(0.4, 0.55, 0.0)], [0.18, 0.18], Color(0.18, 0.18, 0.18), 8)
	k.box(Vector3(0.4, 0.18, 0.18), Vector3(0.14, 0.08, 0.04), Color(0.14, 0.14, 0.14))
	k.box(Vector3(0.4, 0.16, 0.22), Vector3(0.11, 0.02, 0.08), Color(0.72, 0.70, 0.65))
	return _mi(k, key, "tex_wood.png")


## Советский грунтовый геофон и сейсмоприемник СВ-20 («Слухач»)
static func seismograph_sv20() -> Node3D:
	var key := &"seismograph_sv20"
	var cached := _instance_from_cache(key, "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(41, 0.05)
	var body_col := Color(0.20, 0.25, 0.22)
	var metal_dark := Color(0.12, 0.13, 0.14)
	var paper_col := Color(0.88, 0.85, 0.76)
	var brass := Color(0.44, 0.38, 0.20)
	var dial_white := Color(0.92, 0.90, 0.84)
	var phone_black := Color(0.06, 0.06, 0.07)
	var cable_col := Color(0.15, 0.12, 0.10)

	# 1. Чугунный корпус и основание с ножками
	k.box(Vector3(0, 0.04, 0), Vector3(0.36, 0.08, 0.26), body_col)
	for sx: float in [-0.16, 0.16]:
		for sz: float in [-0.11, 0.11]:
			k.box(Vector3(sx, 0.01, sz), Vector3(0.03, 0.02, 0.03), brass)

	# 2. Вертикальный цилиндрический сейсмодатчик
	k.tube([Vector3(-0.09, 0.08, 0.0), Vector3(-0.09, 0.24, 0.0)], [0.065, 0.065], body_col, 10)
	k.box(Vector3(-0.09, 0.245, 0.0), Vector3(0.14, 0.015, 0.14), metal_dark)
	k.tube([Vector3(-0.09, 0.255, 0.0), Vector3(-0.09, 0.262, 0.0)], [0.018, 0.018], brass, 8)

	# 3. Барабан самописца с бумажной лентой
	k.tube([Vector3(0.06, 0.14, -0.075), Vector3(0.06, 0.14, 0.075)], [0.052, 0.052], paper_col, 10)
	k.tube([Vector3(0.06, 0.14, -0.082), Vector3(0.06, 0.14, 0.082)], [0.008, 0.008], metal_dark, 6)
	k.box(Vector3(0.02, 0.15, 0.0), Vector3(0.06, 0.006, 0.006), metal_dark)

	# 4. Гальванометр / милливольтметр
	k.tube([Vector3(0.10, 0.19, -0.06), Vector3(0.125, 0.19, -0.06)], [0.035, 0.035], metal_dark, 8)
	k.box(Vector3(0.126, 0.19, -0.06), Vector3(0.004, 0.05, 0.05), dial_white)
	k.box(Vector3(0.128, 0.195, -0.06), Vector3(0.002, 0.03, 0.003), Color(0.8, 0.15, 0.1))

	# 5. Клеммы заземления и кабель в пол
	k.tube([Vector3(-0.16, 0.07, 0.08), Vector3(-0.16, 0.09, 0.08)], [0.012, 0.012], brass, 6)
	k.tube([Vector3(-0.16, 0.08, 0.08), Vector3(-0.18, 0.0, 0.08), Vector3(-0.18, -0.85, 0.08)], [0.01, 0.01, 0.01], cable_col, 5)

	# 6. Армейские наушники ТА-56М рядом на столе
	k.tube([Vector3(0.24, 0.03, 0.04), Vector3(0.24, 0.06, 0.04)], [0.042, 0.042], phone_black, 8)
	k.tube([Vector3(0.24, 0.03, -0.06), Vector3(0.24, 0.06, -0.06)], [0.042, 0.042], phone_black, 8)
	k.tube([Vector3(0.24, 0.06, 0.04), Vector3(0.26, 0.14, -0.01), Vector3(0.24, 0.06, -0.06)], [0.006, 0.006, 0.006], metal_dark, 6)
	k.tube([Vector3(0.22, 0.04, 0.04), Vector3(0.16, 0.04, 0.06), Vector3(0.12, 0.05, 0.09)], [0.005, 0.005, 0.005], cable_col, 4)

	return _mi(k, key, "tex_metal.png")


## Охотничий таёжный нож
static func hunting_knife() -> Node3D:
	var key := &"hunting_knife"
	var cached := _instance_from_cache(key, "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(47, 0.04)
	var steel := Color(0.72, 0.74, 0.76)
	var brass := Color(0.48, 0.40, 0.18)
	var handle_col := Color(0.24, 0.18, 0.12)
	k.box(Vector3(0, 0.10, 0), Vector3(0.015, 0.16, 0.035), steel)
	k.box(Vector3(0, 0.015, 0), Vector3(0.025, 0.01, 0.06), brass)
	k.tube([Vector3(0, 0.01, 0), Vector3(0, -0.11, 0)], [0.016, 0.016], handle_col, 8)
	k.box(Vector3(0, -0.115, 0), Vector3(0.022, 0.01, 0.028), brass)
	return _mi(k, key, "tex_metal.png")


## Советский вертолёт Ми-8 снабжения и эвакуации
static func mi8_helicopter() -> Node3D:
	var key := &"mi8_helicopter"
	var cached := _instance_from_cache(key, "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(88, 0.06)
	var heli_green := Color(0.24, 0.28, 0.20)
	var glass_col := Color(0.12, 0.16, 0.22)
	var rotor_metal := Color(0.15, 0.16, 0.18)
	var ski_col := Color(0.20, 0.21, 0.22)
	var red_star := Color(0.85, 0.15, 0.12)

	# 1. Основной фюзеляж (грузовая кабина)
	k.box(Vector3(0, 1.85, 0), Vector3(2.4, 2.1, 6.2), heli_green)
	k.box(Vector3(0, 1.75, -3.5), Vector3(2.1, 1.8, 1.4), heli_green)
	k.box(Vector3(0, 1.95, -4.1), Vector3(1.8, 0.95, 0.4), glass_col)
	for sx: float in [-1.02, 1.02]:
		k.box(Vector3(sx, 1.95, -3.4), Vector3(0.04, 0.85, 1.1), glass_col)

	# 2. Хвостовая балка и оперение
	k.tube([Vector3(0, 2.1, 3.0), Vector3(0, 2.6, 9.8)], [0.55, 0.28], heli_green, 8)
	k.box(Vector3(0, 3.4, 9.8), Vector3(0.12, 1.4, 0.8), heli_green)
	k.box(Vector3(0, 2.6, 9.2), Vector3(2.2, 0.08, 0.5), heli_green)
	k.tube([Vector3(0.2, 3.8, 9.8), Vector3(0.35, 3.8, 9.8)], [0.08, 0.08], rotor_metal, 6)
	for rot_i in range(3):
		var ang := float(rot_i) * (TAU / 3.0)
		var b_end := Vector3(0.36, 3.8 + sin(ang) * 0.95, 9.8 + cos(ang) * 0.95)
		k.box((Vector3(0.36, 3.8, 9.8) + b_end) * 0.5, Vector3(0.02, 0.14, 0.85), rotor_metal)

	# 3. Несущий винт (5 лопастей) и втулка
	k.tube([Vector3(0, 2.9, -0.6), Vector3(0, 3.6, -0.6)], [0.28, 0.24], rotor_metal, 8)
	for blade_i in range(5):
		var b_ang := float(blade_i) * (TAU / 5.0)
		var blade_mid := Vector3(sin(b_ang) * 3.6, 3.65, -0.6 + cos(b_ang) * 3.6)
		k.box(blade_mid, Vector3(0.24, 0.04, 6.8), rotor_metal)

	# 4. Лыжное шасси
	for sx: float in [-1.55, 1.55]:
		k.tube([Vector3(sx, 0.15, -3.2), Vector3(sx, 0.15, 3.2)], [0.12, 0.12], ski_col, 6)
		k.tube([Vector3(sx, 0.15, -3.2), Vector3(sx, 0.55, -3.8)], [0.11, 0.11], ski_col, 6)
		for sz: float in [-1.6, 1.6]:
			k.tube([Vector3(sx, 0.15, sz), Vector3(sx * 0.7, 1.1, sz)], [0.06, 0.06], rotor_metal, 5)

	# 5. Красная звезда
	k.box(Vector3(1.21, 2.1, 0.8), Vector3(0.02, 0.65, 0.65), red_star)
	k.box(Vector3(-1.21, 2.1, 0.8), Vector3(0.02, 0.65, 0.65), red_star)

	return _mi(k, key, "tex_metal.png")


## Сброшенный деревянный экспедиционный ящик снабжения
static func supply_crate() -> Node3D:
	var key := &"supply_crate"
	var cached := _instance_from_cache(key, "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(52, 0.06)
	var wood_col := Color(0.34, 0.26, 0.16)
	var band_col := Color(0.18, 0.18, 0.18)
	var parachute := Color(0.85, 0.32, 0.18)
	k.box(Vector3(0, 0.4, 0), Vector3(0.95, 0.8, 0.75), wood_col)
	for sz: float in [-0.34, 0.34]:
		k.box(Vector3(0, 0.4, sz), Vector3(0.98, 0.82, 0.04), band_col)
	for sx: float in [-0.44, 0.44]:
		k.box(Vector3(sx, 0.4, 0), Vector3(0.04, 0.82, 0.77), band_col)
	k.blob(Vector3(0.7, 0.22, 0.3), Vector3(0.85, 0.42, 0.85), parachute, 4, 7)
	return _mi(k, key, "tex_wood.png")


## Советский фототелеграфный факс-терминал ИСЗ «Метеор-2» («Нева-МТ»)
static func meteor_fax() -> Node3D:
	var key := &"meteor_fax"
	var cached := _instance_from_cache(key, "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(84, 0.05)
	var body_col := Color(0.22, 0.26, 0.23)
	var panel_col := Color(0.14, 0.16, 0.15)
	var drum_metal := Color(0.55, 0.58, 0.60)
	var paper_col := Color(0.88, 0.85, 0.78)
	var green_led := Color(0.15, 0.85, 0.25)
	var amber_led := Color(0.95, 0.65, 0.15)

	# Корпус фототелеграфа
	k.box(Vector3(0, 0.12, 0), Vector3(0.52, 0.24, 0.42), body_col)
	# Наклонная панель управления
	k.box(Vector3(0, 0.18, 0.12), Vector3(0.48, 0.12, 0.16), panel_col)
	# Барабан приёма термобумаги
	k.tube([Vector3(-0.19, 0.22, -0.06), Vector3(0.19, 0.22, -0.06)], [0.055, 0.055], drum_metal, 8)
	# Выходящий лист спутникового снимка
	k.box(Vector3(0, 0.25, 0.01), Vector3(0.34, 0.006, 0.22), paper_col)
	# Рулон чистой бумаги сзади
	k.tube([Vector3(-0.18, 0.19, -0.15), Vector3(0.18, 0.19, -0.15)], [0.045, 0.045], paper_col, 8)
	# Индикаторы (зелёный «СЕТЬ/СИНХРО», оранжевый «СИГНАЛ ИСЗ»)
	k.box(Vector3(-0.18, 0.24, 0.16), Vector3(0.015, 0.015, 0.015), green_led)
	k.box(Vector3(-0.14, 0.24, 0.16), Vector3(0.015, 0.015, 0.015), amber_led)
	# Ручки настройки развертки
	for i in range(3):
		var rx := -0.04 + float(i) * 0.08
		k.tube([Vector3(rx, 0.23, 0.15), Vector3(rx, 0.25, 0.15)], [0.018, 0.018], Color(0.1, 0.1, 0.1), 6)

	return _mi(k, key, "tex_metal.png")


## Вахтенный журнал метеонаблюдений ТМ-1 в ледериновом переплете
static func journal_tm1() -> Node3D:
	var key := &"journal_tm1"
	var cached := _instance_from_cache(key, "tex_cloth.png")
	if cached != null:
		return cached
	var k := _kit(88, 0.04)
	var cover_col := Color(0.14, 0.20, 0.28)  # тёмно-синий советский ледерин
	var pages_col := Color(0.86, 0.82, 0.73)  # состаренная бумага
	var gold_ribbon := Color(0.78, 0.62, 0.22)
	var bookmark := Color(0.65, 0.12, 0.12)   # красная закладка-ляссе

	# Обложка
	k.box(Vector3(0, 0.025, 0), Vector3(0.36, 0.05, 0.48), cover_col)
	# Бумажный блок страниц
	k.box(Vector3(0.01, 0.025, 0), Vector3(0.33, 0.044, 0.46), pages_col)
	# Тиснёный золотой корешок
	k.box(Vector3(-0.175, 0.025, 0), Vector3(0.02, 0.052, 0.48), gold_ribbon)
	# Красная ленточка-закладка
	k.box(Vector3(0.08, 0.052, 0.12), Vector3(0.025, 0.005, 0.28), bookmark)
	# Чернильная ручка рядом на подставке
	k.tube([Vector3(0.22, 0.01, -0.18), Vector3(0.22, 0.01, 0.18)], [0.006, 0.006], Color(0.1, 0.1, 0.1), 6)
	k.tube([Vector3(0.22, 0.01, 0.18), Vector3(0.22, 0.01, 0.21)], [0.006, 0.001], Color(0.8, 0.7, 0.3), 5)

	return _mi(k, key, "tex_cloth.png")


## Заснеженная ель (вековая ель двора)
static func spruce(height: float = 8.0) -> Node3D:
	var root := Node3D.new()
	root.name = "SpruceProp"
	var mi := MeshInstance3D.new()
	mi.mesh = SpruceMesh.near(0) if SpruceMesh.cards_enabled() else SpruceMesh.mesh(0)
	var scale_factor := height / 6.0
	mi.scale = Vector3(scale_factor, scale_factor, scale_factor)
	root.add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = Geo.LAYER_WORLD
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.45 * scale_factor
	cyl.height = height * 0.7
	col.shape = cyl
	col.position = Vector3(0, height * 0.35, 0)
	body.add_child(col)
	root.add_child(body)
	return root


## Экспедиционные нарты Семёнова из Блендера (assets/models/kedr/sled_semenov.glb):
## кованые полозья, перерезанная упряжь, брезентовый баул, планшет с запиской.
static func sled_semenov() -> Node3D:
	var glb := _kedr_model("sled_semenov", {"scale": 1.0, "bright": 1.1})
	if glb != null:
		return glb
	return Node3D.new()


## Вывороченный из мерзлоты леерный столб из Блендера (assets/models/kedr/broken_post.glb):
## комья льда у комля, фарфоровый изолятор, оборванный трос и сигнальная лента.
static func broken_post() -> Node3D:
	var glb := _kedr_model("broken_post", {"scale": 1.0, "bright": 1.1})
	if glb != null:
		return glb
	return Node3D.new()


## Советский шахтерский/аккумуляторный фонарь ФАС-4 из Блендера (assets/models/kedr/fas4_lantern.glb):
## металлический корпус молотковой эмали, латунный безель, тумблер и ремень.
static func fas4_lantern() -> Node3D:
	var glb := _kedr_model("fas4_lantern", {"scale": 1.0, "bright": 1.15})
	if glb != null:
		return glb
	return Node3D.new()


## Полевой офицерский планшет с картой и компасом Адрианова (assets/models/kedr/officer_tablet.glb):
## кожаный планшет, целлулоидное окно, топокарта, компас со светящимся лимбом и карандаши.
static func officer_tablet() -> Node3D:
	var glb := _kedr_model("officer_tablet", {"scale": 1.0, "bright": 1.1})
	if glb != null:
		return glb
	return Node3D.new()


## Экспедиционный дюралевый рундук дежурного (assets/models/kedr/expedition_trunk.glb):
## ребра жесткости, стальные уголки, защелки-лягушки, пломба и трафареты «ГИДРОМЕТСЛУЖБА».
static func expedition_trunk() -> Node3D:
	var glb := _kedr_model("expedition_trunk", {"scale": 1.0, "bright": 1.05})
	if glb != null:
		return glb
	return Node3D.new()


## Заброшенная металлическая решетчатая метеовышка 50-х годов (assets/models/kedr/old_meteo_tower.glb):
## 4-опорная ржавая ферма, скоб-трап, сломанная верхняя площадка и поврежденный флюгер.
static func old_meteo_tower() -> Node3D:
	var glb := _kedr_model("old_meteo_tower", {"scale": 1.0, "bright": 1.0})
	if glb != null:
		return glb
	return Node3D.new()


## Дорожная вешка зимника с катафотами (assets/models/kedr/winter_road_marker.glb):
## черно-белый граненый столб, янтарный и красный граненые световозвращатели.
static func winter_road_marker() -> Node3D:
	var glb := _kedr_model("winter_road_marker", {"scale": 1.0, "bright": 1.1})
	if glb != null:
		return glb
	return Node3D.new()


static func gtt_transporter() -> Node3D:
	var glb := _kedr_model("gtt_transporter", {"scale": 1.0, "bright": 1.0})
	if glb != null:
		return glb
	return Node3D.new()


static func outhouse() -> Node3D:
	var glb := _kedr_model("outhouse", {"scale": 1.0, "bright": 1.0})
	if glb != null:
		return glb
	return Node3D.new()





# --- Дальние точки: лесосека и буровая ---------------------------------------------

## Лесопильный стан: рама на стойках, рельсы с кареткой и бревном, дисковая пила, навес-козырёк, опилки.
## Длинная сторона — по X, пила посередине.
static func sawmill() -> Node3D:
	var key := &"sawmill_v1"
	var cached := _instance_from_cache(key, "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(201, 0.10)
	var wood := Color(0.54, 0.43, 0.31)
	var wood_dark := Color(0.38, 0.30, 0.21)
	var log_c := Color(0.36, 0.26, 0.19)
	var cut := Color(0.72, 0.58, 0.40)
	var steel := Color(0.34, 0.36, 0.38)
	var rust := Color(0.44, 0.22, 0.12)
	var dust := Color(0.58, 0.44, 0.28)
	var snow := Color(0.82, 0.87, 0.93)

	# Стойки и продольные балки станины
	for sx: float in [-3.0, -1.0, 1.0, 3.0]:
		for sz: float in [-0.7, 0.7]:
			k.box(Vector3(sx, 0.45, sz), Vector3(0.18, 0.9, 0.18), wood_dark)
	for sz: float in [-0.7, 0.7]:
		k.box(Vector3(0, 0.95, sz), Vector3(6.4, 0.16, 0.2), wood)
		k.box(Vector3(0, 1.06, sz), Vector3(6.4, 0.04, 0.07), steel)   # рельс
	for sx: float in [-3.0, 0.0, 3.0]:
		k.box(Vector3(sx, 0.95, 0), Vector3(0.18, 0.14, 1.5), wood_dark)

	# Бревно на каретке, торец светлый (свежий рез)
	k.tube([Vector3(-2.6, 1.42, 0), Vector3(2.7, 1.42, 0)], [0.30], log_c, 9, true, true)
	k.box(Vector3(-2.62, 1.42, 0), Vector3(0.05, 0.5, 0.5), cut)
	for sx: float in [-1.8, 1.8]:
		k.box(Vector3(sx, 1.08, 0), Vector3(0.3, 0.12, 1.2), steel)

	# Дисковая пила на козлах: диск с зубьями, кожух, шкив и ремень к мотору
	k.tube([Vector3(0.0, 1.55, -0.02), Vector3(0.0, 1.55, 0.02)], [0.62], steel, 14, true, true)
	for i in range(14):
		var a := TAU * float(i) / 14.0
		k.box(Vector3(sin(a) * 0.66, 1.55 + cos(a) * 0.66, 0), Vector3(0.07, 0.07, 0.03), rust, Basis(Vector3.BACK, -a))
	k.box(Vector3(0.0, 1.55, 0.0), Vector3(0.12, 0.12, 0.30), rust)
	for sz: float in [-0.28, 0.28]:
		k.box(Vector3(0, 1.0, sz), Vector3(0.12, 1.4, 0.10), wood_dark)
	k.box(Vector3(1.1, 0.35, 1.15), Vector3(0.6, 0.45, 0.5), rust)           # мотор
	k.tube([Vector3(1.1, 0.5, 0.95), Vector3(0.0, 1.5, 0.15)], [0.015], Color(0.07, 0.07, 0.07), 4)   # ремень

	# Навес-козырёк над пилой, на шапке снег
	for sx: float in [-1.4, 1.4]:
		k.box(Vector3(sx, 1.65, -0.9), Vector3(0.12, 3.3, 0.12), wood_dark)
	k.box(Vector3(0, 3.3, -0.55), Vector3(3.4, 0.08, 1.7), wood_dark, Basis(Vector3.RIGHT, deg_to_rad(8.0)))
	k.box(Vector3(0, 3.4, -0.55), Vector3(3.4, 0.07, 1.6), snow, Basis(Vector3.RIGHT, deg_to_rad(8.0)))

	# Опилки и горбыль под станком
	k.blob(Vector3(0.0, 0.05, 1.0), Vector3(1.4, 0.22, 1.0), dust, 3, 8)
	k.blob(Vector3(-1.6, 0.04, -1.1), Vector3(0.9, 0.16, 0.6), dust, 3, 7)
	for i in range(5):
		k.box(Vector3(2.0 + i * 0.18, 0.08 + i * 0.05, 1.3), Vector3(1.4, 0.04, 0.2), wood, Basis(Vector3.UP, 0.2 * i))

	return _mi(k, key, "tex_wood.png")


## Штабель хлыстов: три яруса брёвен, на торцах свежий срез, сверху снег.
static func log_pile(length := 5.0) -> Node3D:
	var key := StringName("log_pile_%.1f" % length)
	var cached := _instance_from_cache(key, "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(202, 0.12)
	var log_c := Color(0.34, 0.25, 0.18)
	var cut := Color(0.66, 0.52, 0.36)
	var snow := Color(0.84, 0.88, 0.94)
	var r := 0.22
	var rows := [3, 2, 1]
	for row in range(rows.size()):
		var n: int = rows[row]
		for i in range(n):
			var x := (float(i) - (n - 1) * 0.5) * (r * 2.0 + 0.02)
			var y := r + float(row) * r * 1.75
			var l := length - 0.4 * float((row + i) % 2)
			k.tube([Vector3(-l * 0.5, y, x), Vector3(l * 0.5, y, x)], [r * (0.9 + 0.1 * float((i + row) % 2))], log_c, 8, true, true)
			k.box(Vector3(-l * 0.5 - 0.01, y, x), Vector3(0.03, r * 1.5, r * 1.5), cut)
	k.box(Vector3(0, r * 1.75 * 2.0 + r + 0.04, 0), Vector3(length - 0.8, 0.07, r * 2.2), snow)
	for sx: float in [-length * 0.38, length * 0.38]:
		k.box(Vector3(sx, 0.04, 0), Vector3(0.12, 0.08, 1.5), Color(0.18, 0.14, 0.10))
	return _mi(k, key, "tex_wood.png")


## Пень от свежей рубки: светлый срез и шапка снега.
static func stump(radius := 0.32) -> Node3D:
	var key := StringName("stump_%.2f" % radius)
	var cached := _instance_from_cache(key, "tex_wood.png")
	if cached != null:
		return cached
	var k := _kit(203, 0.14)
	k.tube([Vector3(0, 0, 0), Vector3(0, 0.22, 0), Vector3(0, 0.42, 0)], [radius * 1.25, radius * 1.05, radius], Color(0.22, 0.16, 0.12), 8, true, true)
	k.box(Vector3(0, 0.425, 0), Vector3(radius * 1.8, 0.02, radius * 1.8), Color(0.62, 0.48, 0.33))
	k.blob(Vector3(0, 0.46, 0), Vector3(radius * 0.95, 0.08, radius * 0.95), Color(0.84, 0.88, 0.94), 2, 7)
	return _mi(k, key, "tex_wood.png")


## Штабель бурильных труб на лагах, с ржавчиной и снегом сверху.
static func pipe_rack(length := 4.5) -> Node3D:
	var key := StringName("pipe_rack_%.1f" % length)
	var cached := _instance_from_cache(key, "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(204, 0.10)
	var steel := Color(0.30, 0.32, 0.34)
	var rust := Color(0.42, 0.24, 0.14)
	var snow := Color(0.84, 0.88, 0.94)
	var wood := Color(0.26, 0.20, 0.14)
	for sx: float in [-length * 0.4, 0.0, length * 0.4]:
		k.box(Vector3(sx, 0.08, 0), Vector3(0.18, 0.16, 1.5), wood)
	var rows := [4, 3, 2]
	for row in range(rows.size()):
		var n: int = rows[row]
		for i in range(n):
			var z := (float(i) - (n - 1) * 0.5) * 0.30
			var y := 0.30 + float(row) * 0.26
			k.tube([Vector3(-length * 0.5, y, z), Vector3(length * 0.5, y, z)], [0.12], rust if (i + row) % 2 == 0 else steel, 7, true, true)
	k.box(Vector3(0, 0.88, 0), Vector3(length * 0.9, 0.06, 0.55), snow)
	return _mi(k, key, "tex_metal.png")


## Лежачая ёмкость ГСМ на стальных салазках, с лазом и трубой.
static func fuel_tank() -> Node3D:
	var key := &"fuel_tank_v1"
	var cached := _instance_from_cache(key, "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(205, 0.08)
	var body := Color(0.34, 0.20, 0.14)
	var steel := Color(0.22, 0.23, 0.25)
	var snow := Color(0.84, 0.88, 0.94)
	k.tube([Vector3(-1.6, 0.85, 0), Vector3(1.6, 0.85, 0)], [0.72], body, 12, true, true)
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(sx, 0.18, 0), Vector3(0.14, 0.36, 1.2), steel)
		k.box(Vector3(sx, 0.34, 0), Vector3(0.10, 0.06, 1.5), steel)
	k.box(Vector3(0.2, 1.6, 0), Vector3(0.5, 0.12, 0.5), steel)               # люк
	k.tube([Vector3(-1.0, 1.55, 0), Vector3(-1.0, 2.1, 0)], [0.04], steel, 5)  # дыхательная труба
	k.tube([Vector3(1.6, 0.4, 0), Vector3(2.0, 0.4, 0.3), Vector3(2.0, 0.1, 0.6)], [0.035], steel, 5)   # сливной шланг
	k.blob(Vector3(0, 1.55, 0), Vector3(1.4, 0.08, 0.35), snow, 2, 8)
	return _mi(k, key, "tex_metal.png")


# --- Метеоплощадка: приборы для вида ----------------------------------------------

## Осадкомер Третьякова: столб, ведро-приёмник и ветровая защита из 16 отогнутых пластин.
static func precip_gauge() -> Node3D:
	var key := &"precip_gauge_v1"
	var cached := _instance_from_cache(key, "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(211, 0.06)
	var wood := Color(0.30, 0.24, 0.18)
	var zinc := Color(0.62, 0.65, 0.66)
	var snow := Color(0.86, 0.90, 0.95)
	k.box(Vector3(0, 0.95, 0), Vector3(0.12, 1.9, 0.12), wood)
	k.tube([Vector3(0, 1.75, 0), Vector3(0, 2.15, 0)], [0.10, 0.10], zinc, 10, true, false)
	for i in 16:
		var a := TAU * float(i) / 16.0
		var d := Vector3(cos(a), 0, sin(a))
		var base := Vector3(0, 1.95, 0) + d * 0.32
		k.box(base + d * 0.08 + Vector3(0, 0.08, 0), Vector3(0.04, 0.34, 0.11), zinc, Basis(Vector3.UP, -a) * Basis(Vector3.BACK, 0.45))
	k.tube([Vector3(0, 1.85, 0) + Vector3(0.3, 0, 0), Vector3(0, 1.85, 0) + Vector3(-0.3, 0, 0)], [0.01], zinc, 3)
	k.blob(Vector3(0, 2.16, 0), Vector3(0.09, 0.03, 0.09), snow, 2, 7)
	return _mi(k, key, "tex_metal.png")


## Гелиограф Кэмпбелла: стеклянный шар на чугунной подставке, на столбе.
static func heliograph() -> Node3D:
	var key := &"heliograph_v1"
	var cached := _instance_from_cache(key, "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(212, 0.05)
	var iron := Color(0.20, 0.21, 0.22)
	var glass := Color(0.70, 0.80, 0.86)
	k.box(Vector3(0, 0.75, 0), Vector3(0.16, 1.5, 0.16), Color(0.30, 0.24, 0.18))
	k.box(Vector3(0, 1.53, 0), Vector3(0.36, 0.05, 0.26), iron)
	k.tube([Vector3(0, 1.62, -0.11), Vector3(0, 1.62, 0.11)], [0.12], iron, 10, true, true)
	k.blob(Vector3(0, 1.74, 0), Vector3(0.11, 0.11, 0.11), glass, 5, 9)
	return _mi(k, key, "tex_metal.png")


## Почвенно-глубинные термометры Савинова: дощатая рама и четыре коленчатые трубки.
static func soil_thermometers() -> Node3D:
	var key := &"soil_thermo_v1"
	var cached := _instance_from_cache(key, "tex_metal.png")
	if cached != null:
		return cached
	var k := _kit(213, 0.08)
	var wood := Color(0.36, 0.29, 0.21)
	var glass := Color(0.74, 0.82, 0.86)
	for sz: float in [-0.5, 0.5]:
		k.box(Vector3(0, 0.08, sz), Vector3(1.6, 0.08, 0.08), wood)
	for sx: float in [-0.75, 0.75]:
		k.box(Vector3(sx, 0.08, 0), Vector3(0.08, 0.08, 1.0), wood)
	for i in 4:
		var x := -0.5 + float(i) * 0.33
		k.tube([Vector3(x, 0.0, 0.1), Vector3(x, 0.25, 0.1), Vector3(x, 0.28 + i * 0.06, -0.15)], [0.018], glass, 5)
		k.box(Vector3(x, 0.30 + i * 0.06, -0.18), Vector3(0.04, 0.04, 0.04), Color(0.55, 0.12, 0.10))
	return _mi(k, key, "tex_metal.png")
