class_name Creatures
extends RefCounted
## Лоу-поли существа и люди, собранные из трубок и эллипсоидов (MeshKit) под PS1-стиль.
## Каждое — CreatureRig: части висят на опорных узлах и шевелятся (бег, дыхание, подёргивания).
## Все смотрят в -Z, ноги на y = 0.
##
## Узлы, на которые опираются испуги и Ырка:
##   Жердяй — "Upper/Head", "Upper/Chest"; Ырка и люди — "Head", "Chest".

const SHADER := "res://assets/shaders/ps1_creature.gdshader"
const TEX := "res://assets/textures/"

const BONE := Color(0.78, 0.74, 0.62)
const BLOOD := Color(0.3, 0.03, 0.02)
const MOUTH := Color(0.12, 0.02, 0.02)
const VOID := Color(0.01, 0.01, 0.01)

static var _mats: Dictionary = {}
static var _shader_skin: Shader
static var legacy := false   ## true — старые «шарнирные» существа (для сравнения в автотесте)


# --- Ырка ---------------------------------------------------------------------

## Сгорбленный бледный упырь: фокус на спину и затылок (по канону игрок видит его сзади).
## Обледенелый воротник ватника, рваный шарф, торчащая вата, склонённая набок сломанная шея.
static func make_yrka() -> CreatureRig:
	var sk := _make_yrka_skeletal()
	if sk != null:
		return sk
	var rig := CreatureRig.new()
	rig.name = "Yrka"
	rig.twitch = 1.2
	var skin := Color(0.55, 0.57, 0.54)
	var jacket := Color(0.24, 0.26, 0.21)    # выцветший полярный ватник
	var scarf := Color(0.42, 0.45, 0.48)     # обледенелый серый шарф
	var wadding := Color(0.74, 0.72, 0.64)   # клочья торчащей ваты из швов
	var frost := Color(0.72, 0.78, 0.82)     # налипший ледяной куржак
	var mat := _mat(&"yrka", Color.WHITE, "tex_skin.png", 0.04)

	_part(rig, rig, &"", Vector3.ZERO, mat, func(k: MeshKit) -> void:
		# Нижняя часть таза: обрывки темных ватных штанов
		k.blob(Vector3(0, 0.88, 0.05), Vector3(0.17, 0.12, 0.14), jacket * 0.9)
		# Сгорбленный дугообразный позвоночник ватника
		k.tube([Vector3(0, 0.9, 0.08), Vector3(0.02, 1.08, 0.0), Vector3(-0.02, 1.26, -0.16), Vector3(0, 1.38, -0.38)],
			[0.13, 0.15, 0.17, 0.11], jacket, 7)

		# Грудная клетка и сгорбленная спина: тяжелый горб ватника
		k.blob(Vector3(0, 1.22, -0.12), Vector3(0.22, 0.24, 0.19), jacket, 9, 9, Basis(Vector3.RIGHT, deg_to_rad(-38.0)),
			func(d: Vector3) -> float:
				# Выпуклый горб сзади (+z), впалая грудина спереди (-z)
				var hunch := 0.22 if d.z > 0.1 and d.y > 0.0 else 0.0
				var belly := -0.16 if d.z < -0.3 and d.y < 0.0 else 0.0
				return 1.0 + hunch + belly)

		# Воротник полушубка на затылке и плечах (крупный объемный валик)
		k.tube([Vector3(-0.24, 1.36, -0.28), Vector3(0, 1.44, -0.22), Vector3(0.22, 1.32, -0.28)],
			[0.08, 0.11, 0.07], jacket * 1.15, 6)

		# Вмёрзший обледенелый шарф, свисающий между лопатками
		k.tube([Vector3(0.04, 1.38, -0.25), Vector3(0.06, 1.22, -0.08), Vector3(0.03, 1.05, 0.02)],
			[0.05, 0.04, 0.025], scarf, 5)

		# Торчащие пучки ваты из разорванных швов на спине и лопатках
		k.spike(Vector3(-0.08, 1.30, -0.06), Vector3(-0.13, 1.34, 0.02), 0.03, wadding, 3)
		k.spike(Vector3(0.10, 1.24, -0.04), Vector3(0.16, 1.27, 0.03), 0.035, wadding, 3)
		k.spike(Vector3(-0.04, 1.12, 0.06), Vector3(-0.07, 1.14, 0.12), 0.025, wadding, 3)

		# Обледенелые наросты куржака на горбу
		k.blob(Vector3(-0.02, 1.34, -0.14), Vector3(0.09, 0.06, 0.05), frost, 4, 5)

		# Асимметричные плечи (левое плечо вздернуто, правое опущено)
		k.tube([Vector3(-0.25, 1.36, -0.3), Vector3(0, 1.35, -0.34), Vector3(0.22, 1.28, -0.3)],
			[0.07, 0.08, 0.06], jacket, 6)
	, &"yrka_body")

	var chest := Node3D.new()
	chest.name = "Chest"
	chest.position = Vector3(0, 1.2, -0.25)
	rig.add_child(chest)

	# Голова и склонённая на 28° сломанная шея (затылок и воротник на виду у дежурного)
	var head := _part(rig, rig, &"Head", Vector3(-0.03, 1.39, -0.48), mat, func(k: MeshKit) -> void:
		# Кривая шейная хорда
		k.tube([Vector3(0.02, -0.08, 0.09), Vector3(0, 0.0, -0.06)], [0.065, 0.052], skin, 6)

		# Вытянутый затылок назад (именно его видит игрок за спиной!)
		k.blob(Vector3(0, 0.04, -0.16), Vector3(0.105, 0.11, 0.19), skin, 7, 8, Basis(),
			func(d: Vector3) -> float:
				# Увеличенный затылочный бугор сзади (+z)
				return 1.25 if d.z > 0.45 and d.y > -0.1 else (0.85 if d.z < -0.55 else 1.0))

		# Остатки примерзшей шапки-ушанки/трикотажа на затылке
		k.blob(Vector3(0, 0.09, -0.10), Vector3(0.11, 0.06, 0.13), jacket * 0.85, 5, 6)

		# Надбровье и лицо (показывается только при контакте/погоне)
		k.box(Vector3(0, 0.075, -0.28), Vector3(0.18, 0.035, 0.05), skin * 0.85)
		for side: float in [-1.0, 1.0]:
			k.blob(Vector3(0.045 * side, 0.04, -0.29), Vector3(0.03, 0.025, 0.02), VOID, 3, 5)   # глазницы
			k.box(Vector3(0.012 * side, 0.0, -0.33), Vector3(0.012, 0.02, 0.01), VOID)          # ноздри
		k.blob(Vector3(0, -0.04, -0.22), Vector3(0.07, 0.04, 0.09), MOUTH, 3, 6)          # пасть
		for i in range(5):
			var x := -0.04 + i * 0.02
			k.spike(Vector3(x, -0.02, -0.3), Vector3(x * 1.1, -0.08, -0.31), 0.008, BONE, 3)
	, &"yrka_head")
	head.name = "Head"
	# Сломанный наклон шеи набок
	head.rotation_degrees = Vector3(12.0, -18.0, 14.0)
	rig.add_pivot(&"Head", head)   # иначе анимация затирала наклон: «поза покоя» запоминалась до поворота

	# Светоотражающие глаза: чёрные впотьмах, но ярко вспыхивающие при луче фонаря
	_eyes_reactive(head, [Vector3(-0.045, 0.04, -0.285), Vector3(0.045, 0.04, -0.285)], 0.018)

	var jaw := _part(rig, head, &"Jaw", Vector3(0, -0.04, -0.1), mat, func(k: MeshKit) -> void:
		k.blob(Vector3(0, -0.03, -0.12), Vector3(0.075, 0.028, 0.13), skin * 0.95, 4, 7)
		k.blob(Vector3(0, -0.005, -0.11), Vector3(0.05, 0.012, 0.08), Color(0.35, 0.08, 0.08), 3, 5)   # язык
		k.blob(Vector3(0, -0.05, -0.2), Vector3(0.05, 0.02, 0.06), BLOOD, 3, 5)                       # замерзшая кровь
		for i in range(5):
			var x := -0.04 + i * 0.02
			k.spike(Vector3(x, -0.01, -0.22), Vector3(x, 0.035, -0.225), 0.007, BONE, 3)
	, &"yrka_jaw")
	jaw.rotation.x = -0.55
	rig.add_pivot(&"Jaw", jaw)

	for side: float in [-1.0, 1.0]:
		var is_left: bool = side < 0
		var shoulder_pos := Vector3(-0.25, 1.36, -0.3) if is_left else Vector3(0.22, 1.28, -0.3)
		var arm := _part(rig, rig, &"ArmL" if is_left else &"ArmR", shoulder_pos, mat, func(k: MeshKit) -> void:
			var s: float = side
			# Рукав ватника до локтя
			var elbow := Vector3(0.1 * s, -0.38, -0.05)
			k.tube([Vector3.ZERO, elbow], [0.07, 0.05], jacket, 6)
			k.blob(elbow, Vector3(0.05, 0.05, 0.05), jacket * 0.9, 3, 5)

			# Обнаженное предплечье и кисть
			var wrist := Vector3(0.08 * s, -0.84, -0.15)
			k.tube([elbow, wrist], [0.045, 0.03], skin, 6)
			k.blob(wrist + Vector3(0, -0.04, -0.02), Vector3(0.038, 0.05, 0.03), skin, 3, 6)

			# Гангренозные черные отмороженные когти
			var claw_col := Color(0.12, 0.10, 0.09)
			for f in range(4):
				var dx := (-0.03 + f * 0.02) * s
				var a := wrist + Vector3(dx, -0.07, -0.03)
				var b := a + Vector3(dx * 0.6, -0.13, -0.05)
				var c := b + Vector3(dx * 0.4, -0.12, 0.02)
				k.tube([a, b, c], [0.012, 0.01, 0.008], skin * 0.8, 4, false, false, [skin * 0.8, BLOOD * 1.5])
				k.spike(c, c + Vector3(0, -0.065, -0.03), 0.009, claw_col, 3)
		, StringName("yrka_arm_" + str(side)))
		rig.add_pivot(&"ArmL" if is_left else &"ArmR", arm)

		var leg := _part(rig, rig, &"LegL" if side < 0 else &"LegR", Vector3(0.12 * side, 0.88, 0.05), mat, func(k: MeshKit) -> void:
			var s: float = side
			var knee := Vector3(0.04 * s, -0.38, -0.16)
			var ankle := Vector3(0.02 * s, -0.78, 0.06)
			var toe := Vector3(0.02 * s, -0.86, -0.12)
			# Ватные стеганые штаны до колена
			k.tube([Vector3.ZERO, knee], [0.08, 0.058], jacket * 0.85, 6)
			k.blob(knee, Vector3(0.055, 0.055, 0.055), jacket * 0.8, 3, 5)
			# Обмерзшие ноги
			k.tube([knee, ankle], [0.045, 0.03], skin, 6)
			k.tube([ankle, toe], [0.032, 0.02], skin, 5)
			for f in range(3):
				var dx := (-0.02 + f * 0.02) * s
				k.spike(toe + Vector3(dx, 0, 0), toe + Vector3(dx * 1.5, -0.01, -0.07), 0.01, Color(0.12, 0.10, 0.09), 3)
		, StringName("yrka_leg_" + str(side)))
		rig.add_pivot(&"LegL" if side < 0 else &"LegR", leg)
	return rig


## Ырка из Блендера: скелет и клипы (idle, stalk, run, sniff, lunge, peek, pin).
## Узлы "Head" и "Chest" — прикрепления к костям прямо под существом, как у старой версии.
static func _make_yrka_skeletal() -> CreatureRig:
	# Глаза-катафоты — глубоко в глазницах (yrka_hbm.py, сутулая поза покоя): блеснут только в луче фонаря
	var rig := _skeletal("yrka", "Yrka", &"Head", [Vector3(-0.033, 1.434, -0.342), Vector3(0.033, 1.434, -0.342)], 0.009, 0.5, 0.0)   # тёмная и глухая: под фонарём не «высвечивается» в бежевый
	if rig == null:
		return null
	rig.twitch = 1.2
	rig.clip_walk = &"stalk"
	rig.idle_alts = [&"sniff"]
	return rig


## Общая сборка существа со скелетом: модель kedr/<id>.glb, шейдер PS1 по запечённой текстуре,
## прикрепления "Head"/"Chest" (или "<parent>/Head"), глаза-катафоты в координатах модели.
## head_parent: &"Head" — узлы прямо под существом; &"Upper/Head" — внутри узла Upper (Жердяй).
static func _skeletal(id: String, rig_name: String, head_parent: StringName, eyes: Array, eye_r: float, bright: float, emission: float) -> CreatureRig:
	if legacy:
		return null
	var ps := Models._scene("kedr/" + id)
	if ps == null:
		return null
	var inst := ps.instantiate() as Node3D
	var a := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var s := _find_skeleton(inst)
	if a == null or s == null:
		inst.free()
		return null
	var rig := CreatureRig.new()
	rig.name = rig_name
	rig.add_child(inst)
	if _shader_skin == null:
		_shader_skin = load("res://assets/shaders/ps1_skinned.gdshader") as Shader
	var tex_path := "res://assets/models/kedr/%s_%s.png" % [id, id]
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		var src := mi.get_active_material(0) as BaseMaterial3D
		var m := ShaderMaterial.new()
		m.shader = _shader_skin
		var tex: Texture2D = src.albedo_texture if src != null else null
		if tex == null and ResourceLoader.exists(tex_path):
			tex = load(tex_path) as Texture2D
		m.set_shader_parameter(&"tex", tex)
		m.set_shader_parameter(&"albedo", Color(bright, bright, bright))
		m.set_shader_parameter(&"emission", emission)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var holder: Node3D = rig
	var parts := String(head_parent).split("/")
	if parts.size() > 1:
		holder = Node3D.new()
		holder.name = parts[0]
		rig.add_child(holder)
	var to_rig := Transform3D.IDENTITY
	var walk: Node = s
	while walk != rig and walk != null:
		to_rig = (walk as Node3D).transform * to_rig
		walk = walk.get_parent()
	for pair: Array in [["Head", "head"], ["Chest", "chest"]]:
		var att := BoneAttachment3D.new()
		att.name = pair[0]
		holder.add_child(att)
		att.use_external_skeleton = true
		att.external_skeleton = att.get_path_to(s)
		att.bone_name = pair[1]
		# Кадр «как у модели в покое»: глаза и прочее ставим в координатах существа
		var frame := Node3D.new()
		frame.name = "Rest"
		frame.transform = (to_rig * s.get_bone_global_rest(s.find_bone(pair[1]))).affine_inverse()
		att.add_child(frame)
		if pair[0] == "Head" and not eyes.is_empty():
			_eyes_reactive(frame, eyes, eye_r)
	rig.setup_skeletal(a, s)
	return rig


## Люди со скелетом: Михалыч и тень (запасной силуэт, если нет модели двойника).
static func _make_human_skeletal(style: StringName, seated: bool) -> CreatureRig:
	var eyes: Array = []
	if style == &"shadow":
		eyes = [Vector3(-0.036, 1.73, -0.105), Vector3(0.036, 1.73, -0.105)]
	var rig := _skeletal("human_" + String(style), "Human", &"Head", eyes, 0.009, 1.0 if style != &"shadow" else 0.6, 0.0)
	if rig == null:
		return null
	if style == &"driver":
		_blinker(rig)
		_breather(rig, Vector3(0.0, 1.49, -0.16))
	if style != &"shadow":
		rig.breathe_amp = 0.018           # живые дышат: грудь поднимается раз в ~4,5 с
		rig.find_lids()                   # люди эпилога моргают (кости век из ep_people.py)
	rig.twitch = 0.0 if style == &"driver" else 0.35
	rig.clip_walk = &"walk"
	rig.idle_alts = [] if style == &"driver" else [&"still"]
	rig.seated = seated
	rig.engine_vibe = 1.0 if (seated and style == &"driver") else 0.0
	if style == &"driver":
		rig.stepped_hz = 18.0          # живой человек — плавнее, чем нечисть
	return rig


static func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _find_skeleton(c)
		if r != null:
			return r
	return null


# --- Жердяй -------------------------------------------------------------------

## Очень высокий и тонкий, ~3 м. bend_deg — насколько согнут в поясе (83° — сложился и заглядывает в окно).
## Очень высокий и тонкий, ~3.4 м (Вариант Б: замёрзший в вечной мерзлоте бывший метеоролог).
## Рваный полярный ватник, командирские часы на левом запястье, обручальное кольцо, пальцы-ветви.
## bend_deg — насколько согнут в поясе (наклон к окну станции).
static func make_zherdyai(bend_deg: float) -> CreatureRig:
	# ~4.8 м, на болванке HBM (tools/blender/zherdyai_hbm.py). Лицо — темнота под капюшоном, в ней две искры.
	var sk := _skeletal("zherdyai", "Zherdyai", &"Upper/Head", [Vector3(-0.012, 4.645, -0.355), Vector3(0.064, 4.626, -0.35)], 0.03, 0.75, 0.02)
	if sk != null:
		sk.eye_glow_min = 1.6
		sk.twitch = 0.4
		sk.breath = 0.2
		sk.clip_walk = &"walk"
		sk.idle_alts = [&"still"]
		sk.set_bend(bend_deg)
		return sk
	var rig := CreatureRig.new()
	rig.name = "Zherdyai"
	rig.stepped_mode = true
	rig.stepped_hz = 12.0
	rig.twitch = 0.55
	rig.breath = 0.25
	var skin := Color(0.13, 0.12, 0.12)
	var jacket := Color(0.24, 0.25, 0.22)       # рваный полярный ватник наблюдателя
	var wadding := Color(0.72, 0.70, 0.62)      # клочья утеплителя
	var frost := Color(0.74, 0.80, 0.86)        # куржак на плечах и капюшоне
	var watch_metal := Color(0.75, 0.72, 0.65)  # командирские часы на запястье
	var gold_ring := Color(0.88, 0.76, 0.28)    # обручальное кольцо на пальце
	var mat := _mat(&"zherdyai", Color.WHITE, "tex_cloth.png", 0.02)
	var skin_mat := _mat(&"zherd_skin", Color.WHITE, "tex_skin.png", 0.01)

	# Удлинённые ноги (~1.7 м)
	for side: float in [-1.0, 1.0]:
		var leg := _part(rig, rig, &"LegL" if side < 0 else &"LegR", Vector3(0.12 * side, 1.68, 0), mat, func(k: MeshKit) -> void:
			var s: float = side
			var knee := Vector3(0.005 * s, -0.82, 0.06)
			var ankle := Vector3(0.0, -1.60, 0.0)
			# Обрывки штанин ватника
			k.tube([Vector3.ZERO, knee * 0.7], [0.075, 0.058], jacket, 6)
			# Истончённые обледенелые голени
			k.tube([knee * 0.7, knee, ankle], [0.055, 0.038, 0.026], skin, 6)
			k.blob(knee, Vector3(0.048, 0.055, 0.048), skin, 3, 5)
			k.tube([ankle, ankle + Vector3(0, -0.07, -0.24)], [0.026, 0.015], skin, 5)
		, StringName("zherd_leg_" + str(side)))
		rig.add_pivot(&"LegL" if side < 0 else &"LegR", leg)

	var upper := Node3D.new()
	upper.name = "Upper"
	upper.position = Vector3(0, 1.68, 0)
	upper.rotation_degrees.x = -bend_deg
	rig.add_child(upper)
	_part(rig, upper, &"", Vector3.ZERO, mat, func(k: MeshKit) -> void:
		k.blob(Vector3(0, 0.04, 0), Vector3(0.16, 0.11, 0.1), jacket)
		# Вытянутый сгорбленный позвоночник в ватнике
		k.tube([Vector3(0, 0.0, 0.01), Vector3(0, 0.55, 0.04), Vector3(0, 1.15, 0.0)], [0.08, 0.10, 0.12], jacket, 6)
		k.blob(Vector3(0, 0.9, 0.0), Vector3(0.18, 0.26, 0.11), jacket, 8, 8, Basis(),
			func(d: Vector3) -> float: return 1.0 + 0.1 * maxf(sin(d.y * 14.0), 0.0))
		# Торчащие клочья ваты из разорванных швов
		k.spike(Vector3(-0.09, 0.85, 0.08), Vector3(-0.16, 0.92, 0.14), 0.03, wadding, 3)
		k.spike(Vector3(0.11, 0.78, 0.06), Vector3(0.18, 0.84, 0.12), 0.03, wadding, 3)
		# Обледенелый воротник и плечи
		k.tube([Vector3(-0.24, 1.12, 0), Vector3(0, 1.18, 0), Vector3(0.24, 1.12, 0)], [0.06, 0.085, 0.06], jacket * 1.1, 6)
		k.blob(Vector3(0, 1.16, 0.04), Vector3(0.15, 0.06, 0.08), frost, 4, 5)
		# Длинная тонкая шея
		k.tube([Vector3(0, 1.16, 0), Vector3(0, 1.38, -0.03)], [0.045, 0.035], skin, 5)
	, &"zherd_body")

	var chest := Node3D.new()
	chest.name = "Chest"
	chest.position = Vector3(0, 0.8, 0)
	upper.add_child(chest)

	var head := _part(rig, upper, &"Head", Vector3(0, 1.38, -0.03), skin_mat, func(k: MeshKit) -> void:
		# Вытянутый мертвенный череп бывшего наблюдателя станции
		k.blob(Vector3(0, 0.16, -0.02), Vector3(0.09, 0.20, 0.11), skin, 7, 8, Basis(),
			func(d: Vector3) -> float: return 0.88 if d.y < -0.5 else 1.0)
		for side: float in [-1.0, 1.0]:
			k.blob(Vector3(0.038 * side, 0.22, -0.115), Vector3(0.025, 0.032, 0.016), VOID, 3, 5)
		# Провал рта
		k.box(Vector3(0, 0.04, -0.12), Vector3(0.014, 0.18, 0.014), VOID)
	, &"zherd_head")
	head.name = "Head"
	head.rotation_degrees = Vector3(bend_deg * 0.85, 0, 14.0)
	rig.add_pivot(&"Head", head)
	# Светоотражающие глаза (блестят только в луче фонаря дежурного)
	_eyes_reactive(head, [Vector3(-0.038, 0.22, -0.11), Vector3(0.038, 0.22, -0.11)], 0.014)

	# Руки: до колен и ниже, длинные сухие пальцы-ветви
	for side: float in [-1.0, 1.0]:
		var is_left: bool = side < 0
		var sh := _part(rig, upper, &"ArmL" if is_left else &"ArmR", Vector3(0.24 * side, 1.12, 0.0), mat, func(k: MeshKit) -> void:
			var s: float = side
			var elbow := Vector3(0.03 * s, -0.88, 0.07)
			var wrist := Vector3(0.0, -1.68, 0.0)
			# Рукав ватника до локтя
			k.tube([Vector3.ZERO, elbow * 0.8], [0.065, 0.048], jacket, 5)
			# Исхудавшее предплечье
			k.tube([elbow * 0.8, elbow, wrist], [0.045, 0.034, 0.024], skin, 5)

			# Левое запястье: Командирские часы метеоролога (стальной корпус и циферблат)
			if is_left:
				k.box(wrist + Vector3(0, 0.03, 0), Vector3(0.032, 0.025, 0.045), watch_metal)
				k.blob(wrist + Vector3(0, 0.045, 0), Vector3(0.018, 0.01, 0.018), Color(0.9, 0.92, 0.95), 3, 4)

			# Длинные сухие пальцы-ветки (alpha-scissor ветви)
			for f in range(4):
				var dx := (-0.03 + f * 0.02) * s
				var f_root := wrist + Vector3(dx, -0.02, 0)
				var f_mid := wrist + Vector3(dx * 1.5, -0.22, -0.02)
				var f_tip := wrist + Vector3(dx * 1.8, -0.38, 0.0)
				k.tube([f_root, f_mid, f_tip], [0.01, 0.007, 0.004], skin * 0.9, 4, false, true)

				# Правый безымянный палец: Обручальное кольцо
				if not is_left and f == 2:
					k.tube([f_root + Vector3(0, -0.04, 0), f_root + Vector3(0, -0.07, 0)], [0.011, 0.011], gold_ring, 4, false, false)
		, StringName("zherd_arm_" + str(side)))
		sh.rotation_degrees = Vector3(bend_deg, 0, 4.0 * side)
		rig.add_pivot(&"ArmL" if is_left else &"ArmR", sh)
	return rig


# --- Люди ---------------------------------------------------------------------

## Тёмный человеческий силуэт — «кто-то» в доме, на краю зрения.
static func make_silhouette() -> CreatureRig:
	var d := make_double()
	return d if d != null else make_human(&"shadow")


## Двойник — тот, кто стучится. Лицо по ночам: до 3-й — Михалыч, 4–5 — Семёнов, 6–7 — сам Орехов.
## Шея с каждым лицом длиннее, глаза распахнуты; тени не отбрасывает (заметить можно только на свету).
static func double_face(night: int) -> StringName:
	if night >= 6:
		return &"orekhov"
	if night >= 4:
		return &"semenov"
	return &"mikhalych"


static func make_double(face: StringName = &"") -> CreatureRig:
	if face == &"":
		face = double_face(Game.night)
	# Глаза Орехова ловят свет, как у зверя; у первых двух — обычные, человеческие
	var eyes: Array = [Vector3(-0.033, 1.704, -0.135), Vector3(0.033, 1.704, -0.135)] if face == &"orekhov" else []
	var rig := _skeletal("double_" + String(face), "Double", &"Head", eyes, 0.006, 0.42, 0.0)
	if rig == null:
		return null
	rig.twitch = 0.12 if face == &"mikhalych" else 0.25
	rig.clip_walk = &"walk"
	rig.idle_alts = [&"still"]
	rig._idle_clip = &"still"          # стоит и не шевелится
	rig.stepped_hz = 18.0 if face == &"mikhalych" else 12.0
	rig.set_meta(&"eye_h", {&"mikhalych": 1.599, &"semenov": 1.644, &"orekhov": 1.704}[face])   # глаз в покое (глазок)
	for mi: MeshInstance3D in rig.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return rig


## Подпечье: тёмная пустота под кирпичной печью с лохмотьями сажи. Суседко там не показывается —
## только скребётся (station._process_susedko) и съедает угощение.
static func make_susedko_hearth() -> Node3D:
	var root := Node3D.new()
	root.name = "SusedkoHearth"
	var mat_void := _mat(&"susedko_void", Color(0.012, 0.012, 0.015), "", 0.0)
	var soot_col := Color(0.025, 0.025, 0.03)

	# 1. Затеняющая пластина подпечья
	var kit_base := MeshKit.new(101)
	kit_base.box(Vector3(0, 0.01, 0), Vector3(0.55, 0.02, 0.42), soot_col)
	# Лохмотья сажи и паутина (alpha-scissor карточки)
	for i in range(6):
		var a := i * 0.75
		kit_base.spike(Vector3(sin(a) * 0.2, 0.12, cos(a) * 0.16), Vector3(sin(a) * 0.24, 0.01, cos(a) * 0.19), 0.02, soot_col * 0.7, 3)
	var base_mi := MeshInstance3D.new()
	base_mi.mesh = kit_base.commit()
	base_mi.material_override = mat_void
	root.add_child(base_mi)

	return root


## Живой человек моргает: веки — два «колпачка» цвета кожи поверх глаз на кости головы, на 0.12 с раз в 2–6 с.
## Двойник не моргает никогда — это и выдаёт его в глазке.
static func _blinker(rig: CreatureRig) -> void:
	var rest := rig.get_node_or_null("Head/Rest") as Node3D
	if rest == null:
		return
	var lid_mesh := SphereMesh.new()
	lid_mesh.radius = 0.0145
	lid_mesh.height = 0.02
	lid_mesh.radial_segments = 8
	lid_mesh.rings = 4
	var mat := _mat(&"eyelid", Color(0.66, 0.47, 0.39), "", 0.0)
	var lids: Array[MeshInstance3D] = []
	for s: float in [-1.0, 1.0]:
		var mi := MeshInstance3D.new()
		mi.mesh = lid_mesh
		mi.material_override = mat
		mi.position = Vector3(0.033 * s, 1.5745, -0.128)
		mi.scale = Vector3(1.15, 0.9, 0.7)
		mi.visible = false
		rest.add_child(mi)
		lids.append(mi)
	var timer := Timer.new()
	timer.one_shot = true
	rig.add_child(timer)
	timer.timeout.connect(func() -> void:
		for l in lids:
			l.visible = true
		await rig.get_tree().create_timer(0.12, false).timeout
		for l in lids:
			if is_instance_valid(l):
				l.visible = false
		if is_instance_valid(timer):
			timer.start(randf_range(2.0, 6.0)))
	timer.autostart = false
	rig.ready.connect(func() -> void: timer.start(randf_range(1.0, 4.0)))


## Живой дышит на морозе: облачко пара изо рта каждые 3–4.5 с (как у игрока, Player.puff_material).
## Двойникам пар не даём — «нет пара на морозе» видно в глазке и в окне.
static func _breather(rig: CreatureRig, mouth: Vector3) -> void:
	var rest := rig.get_node_or_null("Head/Rest") as Node3D
	if rest == null:
		return
	var e := CPUParticles3D.new()
	e.amount = 8
	e.lifetime = 1.4
	e.one_shot = true
	e.emitting = false
	e.explosiveness = 0.85
	e.local_coords = false
	e.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	e.emission_sphere_radius = 0.025
	e.direction = Vector3(0.0, 0.15, -1.0)
	e.spread = 16.0
	e.initial_velocity_min = 0.25
	e.initial_velocity_max = 0.45
	e.damping_min = 0.3
	e.damping_max = 0.5
	e.gravity = Vector3(0.0, 0.1, 0.0)
	e.scale_amount_min = 0.7
	e.scale_amount_max = 1.5
	e.color_ramp = Player.puff_ramp()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.1, 0.1)
	qm.material = Player.puff_material(0.16)
	e.mesh = qm
	e.position = mouth
	rest.add_child(e)
	var timer := Timer.new()
	timer.one_shot = true
	rig.add_child(timer)
	timer.timeout.connect(func() -> void:
		# в тёплом доме пара нет; в кабине ГТ-Т и на улице — есть
		if Game.is_outside() or Game.zone == &"" or rig.seated:
			e.restart()
		timer.start(randf_range(3.0, 4.5)))
	rig.ready.connect(func() -> void: timer.start(randf_range(0.5, 3.0)))


## Человек. style: &"shadow" (силуэт — запасной, если нет модели двойника), &"driver" (Михалыч).
static func make_human(style: StringName, seated := false) -> CreatureRig:
	var sk := _make_human_skeletal(style, seated)
	if sk != null:
		return sk
	var rig := CreatureRig.new()
	rig.name = "Human"
	rig.twitch = 0.0 if style == &"driver" else 0.35
	rig.seated = seated
	rig.engine_vibe = 1.0 if (seated and style == &"driver") else 0.0
	var p := _human_palette(style)
	var cloth_mat := _mat(StringName("cloth_" + String(style)), Color.WHITE, "tex_cloth.png", 0.0)
	var face_mat := _mat(StringName("face_" + String(style)), Color.WHITE, "tex_skin.png", 0.12 if style == &"hunter" else 0.015 if style == &"noon" else 0.0)
	var noon := style == &"noon"

	for side: float in [-1.0, 1.0]:
		var leg := _part(rig, rig, &"LegL" if side < 0 else &"LegR", Vector3(0.12 * side, 0.92, 0), cloth_mat, func(k: MeshKit) -> void:
			if seated:
				var hip := Vector3.ZERO
				var knee := Vector3(0, -0.05, -0.42)
				var ankle := Vector3(0, -0.46, -0.42)
				k.tube([hip, knee, ankle], [0.085, 0.07, 0.06], p["pants"], 6)
				k.box(ankle + Vector3(0, -0.03, -0.05), Vector3(0.11, 0.1, 0.26), p["boots"])
				k.tube([ankle, ankle + Vector3(0, 0.22, 0)], [0.07, 0.07], p["boots"], 6, false, false)
				return
			var knee := Vector3(0, -0.42, -0.02)
			var ankle := Vector3(0, -0.84, 0)
			k.tube([Vector3.ZERO, knee, ankle], [0.08, 0.065, 0.055], p["pants"], 6)
			k.box(ankle + Vector3(0, -0.03, -0.05), Vector3(0.11, 0.1, 0.26), p["boots"])                # валенки
			k.tube([ankle + Vector3(0, 0.0, 0), ankle + Vector3(0, 0.25, 0)], [0.07, 0.07], p["boots"], 6, false, false)
		, StringName("human_leg_" + String(style) + "_" + str(side) + ("_seat" if seated else "")))
		rig.add_pivot(&"LegL" if side < 0 else &"LegR", leg)

	_part(rig, rig, &"", Vector3.ZERO, cloth_mat, func(k: MeshKit) -> void:
		if seated:
			k.tube([Vector3(0, 1.47, 0), Vector3(0, 1.3, 0), Vector3(0, 0.95, 0), Vector3(0, 0.55, -0.12)],
				[0.17, 0.22, 0.25, 0.28], p["coat"], 8, true, false)
			k.tube([Vector3(-0.2, 1.42, 0), Vector3(0.2, 1.42, 0)], [0.08, 0.08], p["coat"], 6)
			k.blob(Vector3(0, 0.97, 0), Vector3(0.255, 0.03, 0.255), p["belt"], 2, 8)
			return
		# Тулуп/шинель: колокол от плеч почти до колен.
		k.tube([Vector3(0, 1.47, 0), Vector3(0, 1.3, 0), Vector3(0, 0.95, 0), Vector3(0, 0.55, 0.01)],
			[0.17, 0.22, 0.24, 0.27], p["coat"], 8, true, false)
		k.tube([Vector3(-0.2, 1.42, 0), Vector3(0.2, 1.42, 0)], [0.08, 0.08], p["coat"], 6)
		k.blob(Vector3(0, 0.97, 0), Vector3(0.255, 0.03, 0.255), p["belt"], 2, 8)   # кушак
		if style == &"hunter":
			# Ружьё за спиной — наискосок.
			k.tube([Vector3(-0.22, 0.75, 0.24), Vector3(0.25, 1.62, 0.2)], [0.022, 0.018], Color(0.18, 0.12, 0.08), 4)
			k.tube([Vector3(0.12, 1.4, 0.21), Vector3(0.32, 1.78, 0.19)], [0.012, 0.012], Color(0.2, 0.2, 0.22), 4)
	, StringName("human_body_" + String(style) + ("_seat" if seated else "")))

	var chest := Node3D.new()
	chest.name = "Chest"
	chest.position = Vector3(0, 1.25, 0)
	rig.add_child(chest)

	for side: float in [-1.0, 1.0]:
		var arm := _part(rig, rig, &"ArmL" if side < 0 else &"ArmR", Vector3(0.24 * side, 1.4, 0), cloth_mat, func(k: MeshKit) -> void:
			var s: float = side
			if seated and style == &"driver":
				var elbow := Vector3(0.03 * s, -0.16, -0.22)
				var wrist := Vector3(0.01 * s, -0.32, -0.38)
				k.tube([Vector3.ZERO, elbow, wrist], [0.075, 0.065, 0.058], p["coat"], 6)
				k.blob(wrist + Vector3(0, -0.04, -0.02), Vector3(0.05, 0.07, 0.045), p["mitten"], 3, 6)
				return
			if noon:
				# Полуденница из паралича: руки длиннее, голые серые кисти с пальцами-прутьями
				var el := Vector3(0.04 * s, -0.4, 0.02)
				var wr := Vector3(0.02 * s, -0.84, -0.06)
				k.tube([Vector3.ZERO, el * 0.7], [0.075, 0.06], p["coat"], 6)
				k.tube([el * 0.7, el, wr], [0.042, 0.034, 0.026], p["face"], 5)
				for f in range(4):
					var dx := (-0.02 + f * 0.013) * s
					var a := wr + Vector3(dx, -0.02, 0)
					k.tube([a, a + Vector3(dx * 0.6, -0.13, -0.02), a + Vector3(dx, -0.26, 0.0)], [0.008, 0.006, 0.003], p["face"] * 0.9, 3, false, true)
				return
			var elbow := Vector3(0.04 * s, -0.3, 0.02)
			var wrist := Vector3(0.02 * s, -0.6, -0.05)
			k.tube([Vector3.ZERO, elbow, wrist], [0.075, 0.065, 0.06], p["coat"], 6)
			k.blob(wrist + Vector3(0, -0.06, -0.01), Vector3(0.05, 0.07, 0.045), p["mitten"], 3, 6)
		, StringName("human_arm_" + String(style) + "_" + str(side) + ("_seat" if seated else "")))
		rig.add_pivot(&"ArmL" if side < 0 else &"ArmR", arm)

	var head := _part(rig, rig, &"Head", Vector3(0, 1.6 if noon else 1.52, 0), face_mat, func(k: MeshKit) -> void:
		k.tube([Vector3(0, -0.12 if noon else -0.04, 0), Vector3(0, 0.05, 0)], [0.05 if noon else 0.06, 0.045 if noon else 0.055], p["face"], 6)
		k.blob(Vector3(0, 0.14, -0.01), Vector3(0.1, 0.12, 0.11), p["face"], 6, 8)
		if style == &"noon":
			# Полуденница: шея длиннее, чёрные волосы до пояса, лицо закрыто прядями — в щель видно один глаз.
			k.blob(Vector3(0, 0.17, 0.02), Vector3(0.125, 0.14, 0.125), p["hat"], 5, 8)
			k.tube([Vector3(0, 0.14, 0.08), Vector3(0, -0.2, 0.13), Vector3(0, -0.65, 0.16)], [0.13, 0.15, 0.1], p["hat"], 7, false, true)
			for s: float in [-1.0, 1.0]:
				k.blob(Vector3(0.035 * s, 0.15, -0.1), Vector3(0.024, 0.02, 0.012), VOID, 3, 5)
			k.tube([Vector3(-0.055, 0.25, -0.11), Vector3(-0.04, 0.06, -0.125), Vector3(-0.05, -0.3, -0.1)], [0.052, 0.046, 0.02], p["hat"], 5)
			k.tube([Vector3(0.075, 0.25, -0.105), Vector3(0.08, 0.06, -0.115), Vector3(0.09, -0.28, -0.095)], [0.022, 0.02, 0.012], p["hat"], 4)
			k.box(Vector3(0, 0.05, -0.105), Vector3(0.05, 0.06, 0.012), VOID)
		else:
			# Ушанка: макушка и уши.
			k.blob(Vector3(0, 0.22, 0.0), Vector3(0.13, 0.08, 0.13), p["hat"], 4, 8, Basis(),
				func(d: Vector3) -> float: return 0.6 if d.y < -0.2 else 1.0)
			for s: float in [-1.0, 1.0]:
				k.box(Vector3(0.11 * s, 0.13, 0.0), Vector3(0.04, 0.12, 0.12), p["hat"])
			k.box(Vector3(0, 0.235, -0.12), Vector3(0.2, 0.06, 0.04), p["hat"])
		if style == &"driver":
			for s: float in [-1.0, 1.0]:
				k.box(Vector3(0.035 * s, 0.16, -0.105), Vector3(0.02, 0.012, 0.01), VOID)
			k.box(Vector3(0, 0.07, -0.11), Vector3(0.09, 0.035, 0.03), Color(0.75, 0.75, 0.72))    # седые усы
		elif style == &"hunter":
			# Почти человек: восковое лицо, пустые немигающие глазницы, тонкая застывшая линия рта (uncanny valley)
			for s: float in [-1.0, 1.0]:
				k.blob(Vector3(0.037 * s, 0.155, -0.1), Vector3(0.02, 0.018, 0.012), VOID, 3, 5)
			k.box(Vector3(0, 0.08, -0.108), Vector3(0.065, 0.008, 0.01), VOID)
	, StringName("human_head_" + String(style)))
	head.name = "Head"
	if style == &"noon":
		rig.scale = Vector3(1.0, 1.15, 1.0)
		head.rotation_degrees = Vector3(12.0, 0.0, -26.0)   # голова завалена набок, как у сломанной куклы
		rig.add_pivot(&"Head", head)
		_eyes_reactive(head, [Vector3(0.035, 0.15, -0.106)], 0.01)
	elif style == &"shadow":
		# Тень: лица нет, но в луче фонаря на месте глаз — две тусклые точки
		_eyes_reactive(head, [Vector3(-0.036, 0.15, -0.105), Vector3(0.036, 0.15, -0.105)], 0.009)
	return rig


static func _human_palette(style: StringName) -> Dictionary:
	match style:
		&"driver":
			return {"coat": Color(0.36, 0.27, 0.18), "pants": Color(0.18, 0.2, 0.24), "boots": Color(0.12, 0.11, 0.1),
				"belt": Color(0.1, 0.08, 0.06), "mitten": Color(0.25, 0.2, 0.15), "face": Color(0.72, 0.56, 0.48), "hat": Color(0.22, 0.17, 0.12)}
		&"noon":
			var w := Color(0.7, 0.69, 0.64)
			return {"coat": w, "pants": w, "boots": Color(0.62, 0.6, 0.57), "belt": w * 0.9, "mitten": Color(0.74, 0.72, 0.68),
				"face": Color(0.56, 0.59, 0.62), "hat": Color(0.025, 0.025, 0.03)}
		&"hunter":
			return {"coat": Color(0.27, 0.24, 0.19), "pants": Color(0.2, 0.19, 0.17), "boots": Color(0.1, 0.09, 0.08),
				"belt": Color(0.12, 0.08, 0.05), "mitten": Color(0.22, 0.18, 0.14), "face": Color(0.86, 0.86, 0.82), "hat": Color(0.3, 0.27, 0.22)}
		_:
			var d := Color(0.035, 0.035, 0.04)
			return {"coat": d, "pants": d, "boots": d, "belt": d, "mitten": d, "face": d * 1.4, "hat": d}


# --- Тела ---------------------------------------------------------------------

## Замёрзший охотник в избе: сидит у стены, голова свесилась, лицо и грудь в крови.
static func make_corpse() -> Node3D:
	var root := Node3D.new()
	root.name = "Corpse"
	var mat := _mat(&"corpse", Color.WHITE, "tex_cloth.png", 0.0)
	var coat := Color(0.25, 0.22, 0.18)
	var frost := Color(0.55, 0.62, 0.7)
	var kit := MeshKit.new(7)
	kit.mottle = 0.12
	# Ноги вытянуты вперёд (-Z), спина у стены (+Z).
	for s: float in [-1.0, 1.0]:
		kit.tube([Vector3(0.11 * s, 0.14, 0.05), Vector3(0.12 * s, 0.12, -0.38), Vector3(0.14 * s, 0.1, -0.8)], [0.08, 0.065, 0.055], Color(0.2, 0.19, 0.17), 6)
		kit.box(Vector3(0.15 * s, 0.12, -0.88), Vector3(0.11, 0.24, 0.12), Color(0.1, 0.09, 0.08))
	kit.tube([Vector3(0, 0.15, 0.08), Vector3(0, 0.5, 0.16), Vector3(0, 0.85, 0.2)], [0.25, 0.23, 0.19], coat, 8)
	kit.blob(Vector3(0.02, 0.6, -0.05), Vector3(0.16, 0.14, 0.05), BLOOD, 4, 6)      # грудь разорвана
	kit.blob(Vector3(-0.1, 0.32, -0.16), Vector3(0.1, 0.08, 0.04), BLOOD * 0.8, 3, 5)
	for s: float in [-1.0, 1.0]:
		kit.tube([Vector3(0.22 * s, 0.82, 0.18), Vector3(0.3 * s, 0.5, 0.05), Vector3(0.32 * s, 0.18, -0.1)], [0.07, 0.06, 0.055], coat, 6)
		kit.blob(Vector3(0.32 * s, 0.13, -0.13), Vector3(0.05, 0.04, 0.06), frost, 3, 5)
	# Голова свесилась на грудь, нижняя часть лица — сплошная рана.
	var hc := Vector3(0.06, 0.95, 0.04)
	kit.blob(hc, Vector3(0.1, 0.12, 0.11), frost, 6, 8)
	kit.blob(hc + Vector3(0, -0.05, -0.08), Vector3(0.07, 0.05, 0.04), BLOOD, 3, 6)
	kit.blob(hc + Vector3(0, -0.06, -0.09), Vector3(0.05, 0.02, 0.02), MOUTH, 3, 5)
	for s: float in [-1.0, 1.0]:
		kit.box(hc + Vector3(0.035 * s, 0.02, -0.1), Vector3(0.025, 0.006, 0.01), VOID)
	kit.blob(hc + Vector3(0, 0.08, 0.0), Vector3(0.13, 0.07, 0.13), Color(0.3, 0.27, 0.22), 4, 8)
	# Кровь застыла на полу.
	for i in range(5):
		var a := i * 1.3
		kit.blob(Vector3(cos(a) * 0.35, 0.005, -0.3 + sin(a) * 0.3), Vector3(0.12 + i * 0.02, 0.004, 0.09), BLOOD * 0.7, 2, 6)
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit()
	mi.material_override = mat
	root.add_child(mi)
	return root


## Замёрзший охотник под вековой елью (нарративный объект, 4 позы):
## pose 0: День 1-2 — сидит привалившись к стволу, голова на груди, ружьё на коленях, снег на плечах.
## pose 1: День 3 — голова приподнята и повернута к тропе, ружьё сжато в руке.
## pose 2: День 4 — накренился вперёд, рука указывает в сторону станции, ружьё в снегу.
## pose 3: Ночь 4/День 5 — пустое место! Лыжные палки в снегу, оборванный ремень, следы к дому.
static func make_frozen_hunter(pose: int = 0) -> Node3D:
	var root := Node3D.new()
	root.name = "FrozenHunter"
	var kit := MeshKit.new(hash(pose) & 0xffff)
	kit.mottle = 0.12

	var coat := Color(0.28, 0.24, 0.20)      # тулуп/овчина
	var pants := Color(0.20, 0.20, 0.19)     # ватные штаны
	var boots := Color(0.12, 0.11, 0.10)     # валенки
	var frost := Color(0.72, 0.78, 0.85)     # куржак / иней
	var skin := Color(0.48, 0.52, 0.56)      # мертвенно-серая обмороженная кожа
	var wood := Color(0.35, 0.22, 0.14)      # приклад ружья
	var steel := Color(0.22, 0.24, 0.26)     # стволы ИЖ-58
	var rucksack := Color(0.32, 0.35, 0.28)  # брезентовый рюкзак «колобок»
	var brass := Color(0.75, 0.65, 0.25)     # стреляные гильзы

	if pose >= 3:
		# ПОЗА 3: Охотник исчез! Под елью пусто.
		# Снежная лунка, где сидело тело
		kit.blob(Vector3(0, 0.05, 0), Vector3(0.42, 0.08, 0.38), frost * 0.9, 4, 6)
		# Лыжные палки, воткнутые в снег
		kit.tube([Vector3(-0.35, -0.05, 0.05), Vector3(-0.45, 1.25, -0.1)], [0.016, 0.012], wood, 4)
		kit.tube([Vector3(0.38, -0.05, -0.1), Vector3(0.48, 1.20, 0.08)], [0.016, 0.012], wood, 4)
		# Кольца лыжных палок (кожа/дерево)
		kit.tube([Vector3(-0.37, 0.15, 0.03), Vector3(-0.39, 0.15, 0.04)], [0.07, 0.07], Color(0.2, 0.16, 0.12), 4, false, false)
		kit.tube([Vector3(0.40, 0.15, -0.08), Vector3(0.42, 0.15, -0.07)], [0.07, 0.07], Color(0.2, 0.16, 0.12), 4, false, false)
		# Оборванная лямка рюкзака на снегу
		kit.tube([Vector3(-0.1, 0.02, 0.15), Vector3(0.12, 0.03, 0.22), Vector3(0.24, 0.02, 0.1)], [0.025, 0.02], rucksack * 0.8, 4)
		# Стреляные латунные гильзы
		kit.tube([Vector3(0.15, 0.02, -0.2), Vector3(0.18, 0.02, -0.2)], [0.012, 0.012], brass, 3)
		kit.tube([Vector3(0.08, 0.02, -0.28), Vector3(0.11, 0.02, -0.27)], [0.012, 0.012], brass, 3)
		# Цепочка вдавленных следов валенок, уходящих в сторону станции (+Z)
		for i in range(5):
			var step_z := 0.4 + i * 0.45
			var step_x := -0.12 if (i % 2 == 0) else 0.12
			kit.blob(Vector3(step_x, 0.01, step_z), Vector3(0.1, 0.015, 0.18), Color(0.45, 0.52, 0.58), 3, 5)
	else:
		# Рюкзак «колобок» за спиной охотника
		kit.blob(Vector3(0, 0.45, -0.22), Vector3(0.26, 0.28, 0.22), rucksack, 6, 6)
		kit.tube([Vector3(-0.16, 0.65, -0.15), Vector3(-0.18, 0.35, 0.05)], [0.025, 0.02], rucksack * 0.8, 3)
		kit.tube([Vector3(0.16, 0.65, -0.15), Vector3(0.18, 0.35, 0.05)], [0.025, 0.02], rucksack * 0.8, 3)

		# Ноги в ватных штанах и валенках
		for s: float in [-1.0, 1.0]:
			var hip := Vector3(0.14 * s, 0.18, -0.05)
			var knee := Vector3(0.16 * s, 0.38, 0.36)
			var ankle := Vector3(0.15 * s, 0.08, 0.68)
			kit.tube([hip, knee, ankle], [0.09, 0.08, 0.07], pants, 6)
			kit.box(ankle + Vector3(0, 0.0, 0.05), Vector3(0.12, 0.12, 0.28), boots)
			if pose == 0:
				kit.blob(knee + Vector3(0, 0.06, 0), Vector3(0.08, 0.04, 0.07), frost, 3, 5)
				kit.blob(ankle + Vector3(0, 0.05, 0.05), Vector3(0.07, 0.03, 0.1), frost, 3, 5)

		# Туловище в тулупе
		var torso_angle := -12.0 if pose == 0 else (-8.0 if pose == 1 else 28.0)
		var basis_torso := Basis(Vector3.RIGHT, deg_to_rad(torso_angle))
		var pelvis := Vector3(0, 0.16, 0)
		var chest_pos := pelvis + basis_torso * Vector3(0, 0.48, 0)
		kit.tube([pelvis, chest_pos], [0.22, 0.24], coat, 7)
		kit.tube([chest_pos + basis_torso * Vector3(-0.18, 0.12, -0.04), chest_pos + basis_torso * Vector3(0, 0.18, -0.02), chest_pos + basis_torso * Vector3(0.18, 0.12, -0.04)],
			[0.08, 0.11, 0.08], coat * 1.2, 5)

		# Куржак на плечах
		kit.blob(chest_pos + basis_torso * Vector3(-0.16, 0.14, 0), Vector3(0.09, 0.05, 0.07), frost, 3, 5)
		kit.blob(chest_pos + basis_torso * Vector3(0.16, 0.14, 0), Vector3(0.09, 0.05, 0.07), frost, 3, 5)

		# Голова и ушанка
		var head_pos := chest_pos + basis_torso * Vector3(0, 0.28, 0)
		var head_rot := Vector3.ZERO
		if pose == 0:
			head_rot = Vector3(26.0, 0.0, 6.0)     # голова свешена на грудь
		elif pose == 1:
			head_rot = Vector3(-4.0, -22.0, 8.0)   # голова приподнята и повернута к тропе
		else:
			head_rot = Vector3(-12.0, -14.0, 0.0)  # взгляд вперед к станции
		var head_basis := basis_torso * Basis.from_euler(Vector3(deg_to_rad(head_rot.x), deg_to_rad(head_rot.y), deg_to_rad(head_rot.z)))

		kit.blob(head_pos, Vector3(0.09, 0.11, 0.1), skin, 6, 7, head_basis)
		kit.blob(head_pos + head_basis * Vector3(0, 0.06, 0), Vector3(0.12, 0.07, 0.12), coat * 0.9, 5, 6, head_basis)
		kit.box(head_pos + head_basis * Vector3(-0.1, -0.01, 0), Vector3(0.03, 0.1, 0.1), coat * 0.85, head_basis)
		kit.box(head_pos + head_basis * Vector3(0.1, -0.01, 0), Vector3(0.03, 0.1, 0.1), coat * 0.85, head_basis)
		kit.blob(head_pos + head_basis * Vector3(0, 0.04, 0.1), Vector3(0.09, 0.03, 0.04), frost, 3, 5, head_basis)

		# Руки и ружьё ИЖ-58
		if pose == 0:
			for s: float in [-1.0, 1.0]:
				var sh := chest_pos + basis_torso * Vector3(0.22 * s, 0.08, 0)
				var el := sh + Vector3(0.06 * s, -0.22, 0.12)
				var wr := Vector3(0.14 * s, 0.42, 0.35)
				kit.tube([sh, el, wr], [0.07, 0.06, 0.05], coat, 5)
				kit.blob(wr, Vector3(0.05, 0.06, 0.05), boots, 3, 5)
			var gun_a := Vector3(-0.45, 0.44, 0.38)
			var gun_b := Vector3(0.48, 0.46, 0.34)
			kit.tube([gun_a, gun_a + Vector3(0.28, 0.01, -0.01)], [0.035, 0.025], wood, 4)
			kit.tube([gun_a + Vector3(0.28, 0.01, -0.01), gun_b], [0.018, 0.016], steel, 4)
			kit.blob(gun_a + Vector3(0.1, 0.05, 0), Vector3(0.06, 0.02, 0.04), frost, 3, 4)
		elif pose == 1:
			var sh_l := chest_pos + basis_torso * Vector3(-0.22, 0.08, 0)
			var el_l := sh_l + Vector3(-0.06, -0.22, 0.12)
			var wr_l := Vector3(-0.14, 0.42, 0.35)
			kit.tube([sh_l, el_l, wr_l], [0.07, 0.06, 0.05], coat, 5)
			kit.blob(wr_l, Vector3(0.05, 0.06, 0.05), boots, 3, 5)

			var sh_r := chest_pos + basis_torso * Vector3(0.22, 0.08, 0)
			var el_r := sh_r + Vector3(0.1, -0.15, 0.18)
			var wr_r := Vector3(0.16, 0.46, 0.22)
			kit.tube([sh_r, el_r, wr_r], [0.07, 0.06, 0.05], coat, 5)
			kit.blob(wr_r, Vector3(0.05, 0.06, 0.05), boots, 3, 5)

			var gun_butt := Vector3(0.24, 0.28, 0.1)
			var gun_tip := Vector3(-0.22, 0.88, 0.45)
			kit.tube([gun_butt, gun_butt + (gun_tip - gun_butt) * 0.35], [0.035, 0.025], wood, 4)
			kit.tube([gun_butt + (gun_tip - gun_butt) * 0.35, gun_tip], [0.018, 0.016], steel, 4)
		else:
			var sh_l := chest_pos + basis_torso * Vector3(-0.22, 0.08, 0)
			var wr_l := Vector3(-0.35, 0.04, 0.25)
			kit.tube([sh_l, (sh_l + wr_l) * 0.5 + Vector3(-0.08, 0, 0), wr_l], [0.07, 0.06, 0.05], coat, 5)
			kit.blob(wr_l, Vector3(0.05, 0.06, 0.05), boots, 3, 5)

			var sh_r := chest_pos + basis_torso * Vector3(0.22, 0.08, 0)
			var wr_r := Vector3(0.25, 0.42, 0.65)
			kit.tube([sh_r, (sh_r + wr_r) * 0.5, wr_r], [0.07, 0.06, 0.05], coat, 5)
			kit.blob(wr_r, Vector3(0.05, 0.05, 0.06), boots, 3, 5)
			kit.spike(wr_r, wr_r + Vector3(0.02, -0.01, 0.14), 0.015, boots * 0.9, 3)

			var gun_butt := Vector3(0.42, 0.04, 0.1)
			var gun_tip := Vector3(0.48, 0.04, 0.95)
			kit.tube([gun_butt, gun_butt + Vector3(0.02, 0, 0.3)], [0.035, 0.025], wood, 4)
			kit.tube([gun_butt + Vector3(0.02, 0, 0.3), gun_tip], [0.018, 0.016], steel, 4)

	var mat := _mat(StringName("frozen_hunter_" + str(pose)), Color.WHITE, "tex_cloth.png", 0.02)
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit()
	mi.material_override = mat
	root.add_child(mi)
	return root


static var _mesh_cache: Dictionary = {}
static var _eye_meshes: Dictionary = {}
static var _shader_res: Shader = null
static var _tex_cache: Dictionary = {}


# --- Хелперы ------------------------------------------------------------------

## Часть тела на опорном узле: меш строится в координатах узла.
static func _part(rig: CreatureRig, parent: Node3D, id: StringName, pivot_pos: Vector3, mat: Material, build: Callable, cache_key: StringName = &"") -> Node3D:
	var pv := Node3D.new()
	pv.name = String(id) if id != &"" else "Body"
	pv.position = pivot_pos
	parent.add_child(pv)
	var mi := MeshInstance3D.new()
	if cache_key != &"" and _mesh_cache.has(cache_key):
		mi.mesh = _mesh_cache[cache_key]
	else:
		var kit := MeshKit.new(hash(id) & 0xffff)
		kit.mottle = 0.12
		build.call(kit)
		mi.mesh = kit.commit()
		if cache_key != &"":
			_mesh_cache[cache_key] = mi.mesh
	mi.material_override = mat
	pv.add_child(mi)
	if id != &"" and id != &"Jaw":
		rig.add_pivot(id, pv)
	return pv


static func _eyes(parent: Node3D, positions: Array, radius: float) -> void:
	var em: SphereMesh = _eye_meshes.get(radius)
	if em == null:
		em = SphereMesh.new()
		em.radius = radius
		em.height = radius * 2.0
		em.radial_segments = 5
		em.rings = 3
		_eye_meshes[radius] = em
	for pos: Vector3 in positions:
		var eye := MeshInstance3D.new()
		eye.mesh = em
		eye.material_override = Palette.glow(&"eyes", true)
		eye.position = pos
		parent.add_child(eye)


## Светоотражающие глаза (блеск только в луче фонарика дежурного)
static func _eyes_reactive(parent: Node3D, positions: Array, radius: float) -> void:
	var em: SphereMesh = _eye_meshes.get(radius)
	if em == null:
		em = SphereMesh.new()
		em.radius = radius
		em.height = radius * 2.0
		em.radial_segments = 5
		em.rings = 3
		_eye_meshes[radius] = em
	# Свой материал на каждое существо: блеск одного не зажигает глаза всем остальным.
	if _shader_res == null:
		_shader_res = load(SHADER) as Shader
	var eye_mat := ShaderMaterial.new()
	eye_mat.shader = _shader_res
	eye_mat.set_shader_parameter(&"albedo", Color(0.12, 0.22, 0.14))
	eye_mat.set_shader_parameter(&"emission", 0.0)
	eye_mat.set_meta(&"eye", true)
	for pos: Vector3 in positions:
		var eye := MeshInstance3D.new()
		eye.mesh = em
		eye.material_override = eye_mat
		eye.position = pos
		parent.add_child(eye)


static func _mat(key: StringName, tint: Color, tex_name: String, emission: float) -> ShaderMaterial:
	if _mats.has(key):
		return _mats[key]
	if _shader_res == null:
		_shader_res = load(SHADER) as Shader
	var m := ShaderMaterial.new()
	m.shader = _shader_res
	m.set_shader_parameter(&"albedo", tint)
	if tex_name != "":
		if not _tex_cache.has(tex_name):
			_tex_cache[tex_name] = load(TEX + tex_name)
		m.set_shader_parameter(&"tex", _tex_cache[tex_name])
		m.set_shader_parameter(&"use_tex", 1.0)
	m.set_shader_parameter(&"emission", emission)
	_mats[key] = m
	return m


## Предварительная компиляция шейдеров и кэширование мешей существ для исключения микрофризов при спавне
static func warmup() -> void:
	var dummy_nodes: Array[Node] = [
		make_yrka(),
		make_zherdyai(40.0),
		make_human(&"shadow"),
		make_human(&"driver"),
		make_double(&"mikhalych"),
		make_double(&"semenov"),
		make_double(&"orekhov"),
		make_susedko_hearth(),
		make_frozen_hunter(0),
		make_corpse()
	]
	for n in dummy_nodes:
		if n != null:
			n.queue_free()
