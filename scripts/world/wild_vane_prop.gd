class_name WildVaneProp
extends Node3D
## Советский флюгер Вильда с лёгкой доской (ГОСТ 7195-75).
## Мачта 5.8м, неподвижные румбы (С, Ю, В, З), флюгарка с противовесом,
## дуга с 8 штифтами и качающаяся металлическая доска для визуального замера ветра.
## При морозе и шторме доска залипает между штифтами дуги (обледенение).
## Очищается ударом ломика, топорика или колотушки.
## Аномалии:
##   Ночь 3: стрелка отклоняется на 25° в сторону от истинного вектора метели.
##   Ночь 5: доска задрана на 80° навстречу шторму и стоит неподвижно без трепета.
##   Ночь 7: бешеное вращение флюгарки в полный штиль.

signal deiced

var is_iced := false
var plate_angle := 0.0          ## угол отклонения доски в градусах (0..85)
var vane_yaw := 0.0             ## азимут флюгарки в радианах

var _vane_head: Node3D          ## вращающийся узел (флюгарка + дуга)
var _plate_pivot: Node3D        ## шарнир доски Вильда
var _plate_mesh: MeshInstance3D
var _ice_mesh: MeshInstance3D
var _ice_mat: StandardMaterial3D
var _inspect_it: Interactable
var _t := 0.0
var _spin_speed := 0.0


func _ready() -> void:
	_build_vane()
	is_iced = Game.anemo_iced


func _build_vane() -> void:
	var iron := Color(0.24, 0.25, 0.27)
	var iron_dark := Color(0.14, 0.15, 0.16)
	var sheet := Color(0.40, 0.42, 0.44)
	var brass := Color(0.70, 0.60, 0.30)
	var white_text := Color(0.90, 0.92, 0.88)

	# 1. Стальная мачта высотой 5.8м с растяжками
	var k_mast := MeshKit.new(48)
	k_mast.mottle = 0.05
	k_mast.tube([Vector3(0, 0, 0), Vector3(0, 5.5, 0)], [0.055, 0.040], iron, 8)
	# 3 подкоса у основания (пирамида)
	for i in range(3):
		var ang := float(i) * TAU / 3.0
		var ground_pt := Vector3(cos(ang) * 0.9, 0.0, sin(ang) * 0.9)
		k_mast.tube([ground_pt, Vector3(0, 1.4, 0)], [0.024, 0.020], iron, 6)
		k_mast.box(ground_pt, Vector3(0.12, 0.04, 0.12), iron_dark)

	# Неподвижная крестовина указателей сторон света (румбы) на высоте 4.9м
	var arm_len := 0.52
	k_mast.tube([Vector3(-arm_len, 4.9, 0), Vector3(arm_len, 4.9, 0)], [0.016], iron_dark, 6)
	k_mast.tube([Vector3(0, 4.9, -arm_len), Vector3(0, 4.9, arm_len)], [0.016], iron_dark, 6)

	# Таблички с буквами: С (Север, -Z), Ю (Юг, +Z), В (Восток, +X), З (Запад, -X)
	# В советских флюгерах буквы С-Ю-В-З вырезаны из листовой стали
	k_mast.box(Vector3(0, 4.9, -arm_len), Vector3(0.12, 0.12, 0.015), sheet)
	k_mast.box(Vector3(0, 4.9, arm_len), Vector3(0.12, 0.12, 0.015), sheet)
	k_mast.box(Vector3(arm_len, 4.9, 0), Vector3(0.015, 0.12, 0.12), sheet)
	k_mast.box(Vector3(-arm_len, 4.9, 0), Vector3(0.015, 0.12, 0.12), sheet)

	var mast_mi := MeshInstance3D.new()
	mast_mi.mesh = k_mast.commit()
	var m_mat := StandardMaterial3D.new()
	m_mat.vertex_color_use_as_albedo = true
	m_mat.albedo_color = Color.WHITE
	m_mat.roughness = 0.6
	mast_mi.material_override = m_mat
	add_child(mast_mi)

	# 2. Поворотный узел флюгарки (высота 5.5м)
	_vane_head = Node3D.new()
	_vane_head.position = Vector3(0, 5.5, 0)
	add_child(_vane_head)

	var k_head := MeshKit.new(64)
	k_head.mottle = 0.04
	# Поворотная гильза на шпинделе
	k_head.tube([Vector3(0, 0, 0), Vector3(0, 0.32, 0)], [0.048, 0.045], iron_dark, 8)
	# Горизонтальная стрела флюгарки (хвостовик сзади, шар спереди)
	k_head.tube([Vector3(0, 0.22, -0.65), Vector3(0, 0.22, 0.75)], [0.018], iron, 6)
	# Свинцовый противовес спереди (шар)
	k_head.blob(Vector3(0, 0.22, -0.65), Vector3(0.07, 0.07, 0.07), iron_dark, 6, 8)
	# Двойное хвостовое оперение (клин) сзади
	k_head.box(Vector3(0.035, 0.22, 0.52), Vector3(0.012, 0.32, 0.50), sheet)
	k_head.box(Vector3(-0.035, 0.22, 0.52), Vector3(0.012, 0.32, 0.50), sheet)

	# Металлическая дуга со штифтами для измерения угла отклонения доски
	# 8 штифтов (0..7) от вертикали до 85 градусов
	var arc_radius := 0.26
	var arc_center := Vector3(0.08, 0.22, 0.0)
	for i in range(8):
		var pin_ang := deg_to_rad(float(i) * 12.0)
		var p_end := arc_center + Vector3(0, -cos(pin_ang) * arc_radius, sin(pin_ang) * arc_radius)
		var p_base := arc_center + Vector3(0, -cos(pin_ang) * (arc_radius - 0.05), sin(pin_ang) * (arc_radius - 0.05))
		k_head.tube([p_base, p_end], [0.008, 0.006], brass, 4)

	var head_mi := MeshInstance3D.new()
	head_mi.mesh = k_head.commit()
	head_mi.material_override = m_mat
	_vane_head.add_child(head_mi)

	# 3. Шарнир качающейся доски Вильда
	_plate_pivot = Node3D.new()
	_plate_pivot.position = Vector3(0, 0.22, 0.0)
	_vane_head.add_child(_plate_pivot)

	# Стальная прямоугольная пластина 150x300 мм, подвешенная на шарнире
	var k_plate := MeshKit.new(12)
	k_plate.mottle = 0.02
	k_plate.box(Vector3(0, -0.15, 0.006), Vector3(0.15, 0.30, 0.012), sheet)
	# Петли подвеса
	k_plate.tube([Vector3(-0.06, 0, 0), Vector3(0.06, 0, 0)], [0.012], iron_dark, 6)

	_plate_mesh = MeshInstance3D.new()
	_plate_mesh.mesh = k_plate.commit()
	_plate_mesh.material_override = m_mat
	_plate_pivot.add_child(_plate_mesh)

	# 4. Ледяная корка (обледенение доски и дуги)
	var k_ice := MeshKit.new(16)
	k_ice.mottle = 0.03
	k_ice.box(Vector3(0, -0.15, 0.014), Vector3(0.165, 0.32, 0.022), Color(0.85, 0.92, 0.98))
	_ice_mesh = MeshInstance3D.new()
	_ice_mesh.mesh = k_ice.commit()
	_ice_mat = StandardMaterial3D.new()
	_ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ice_mat.roughness = 0.15
	_ice_mat.albedo_color = Color(0.82, 0.90, 0.98, 0.75)
	_ice_mesh.material_override = _ice_mat
	_ice_mesh.visible = is_iced
	_plate_pivot.add_child(_ice_mesh)

	# 5. Интерактивная зона осмотра и de-icing у основания
	_inspect_it = Geo.interactable(self, Vector3(1.6, 2.2, 1.6), Vector3(0, 1.2, 0), null, "", _on_interact)
	_inspect_it.prompt_provider = _prompt
	_inspect_it.name = "WildVaneInteractable"


func _prompt() -> String:
	if is_iced:
		var p := Game.player
		if p != null and (p.held == &"crowbar" or p.held == &"tools" or p.held == &"shovel"):
			return Loc.p("Сбить наледь с флюгера [ЛКМ]", "Chip ice off wind vane [LMB]")
		return Loc.p("Флюгер Вильда: обледенел, доска залипла (нужен инструмент)", "Wild vane: iced, plate stuck (tool needed)")
	return Loc.p("Флюгер Вильда: осмотреть скорость и румб ветра", "Wild vane: inspect wind speed & heading")


func _on_interact(_p: Player) -> void:
	if is_iced:
		var p := Game.player
		var has_tool: bool = p != null and (p.held == &"crowbar" or p.held == &"tools" or p.held == &"shovel")
		if has_tool:
			_deice_vane()
		else:
			Game.hud.subtitle(Loc.p("Доска флюгера намертво вмёрзла между штифтами дуги. Нужен лом или топорик.", "The vane plate is frozen solid between the arc pins. Need a crowbar or hatchet."), 4.0)
		return

	# Режим осмотра флюгера: смотрим снизу вверх в метель
	_inspect_reading()


func _deice_vane() -> void:
	is_iced = false
	Game.set_anemo_iced(false)
	if _ice_mesh != null:
		_ice_mesh.visible = false

	# Звук раскалывания льда и металлический резонанс
	Game.audio.play_3d("res://assets/audio/ice_hit.ogg", global_position + Vector3(0, 4.0, 0), 2.0)
	Game.audio.play_3d("res://assets/audio/clank.ogg", global_position + Vector3(0, 2.5, 0), 0.0)

	# Осыпь ледяных осколков
	_spawn_ice_shatter_particles(global_position + Vector3(0, 4.5, 0))

	# Физическая отдача дежурному
	if Game.player != null:
		Game.player.shake(0.06, 0.35)
		Game.player.crank_flash(-12.0) # механический шок от удара ломом

	Game.hud.subtitle(Loc.p("Звонкий удар по мачте! Корка льда с треском осыпалась, доска Вильда качнулась на ветру.", "Resonant strike on the mast! Ice crust shattered with a crack, Wild plate swung free in the wind."), 4.5)
	Director.add_tension(-5.0, "флюгер Вильда очищен от наледи")
	deiced.emit()


func _spawn_ice_shatter_particles(pos: Vector3) -> void:
	var sp := CPUParticles3D.new()
	sp.amount = 25
	sp.lifetime = 1.0
	sp.one_shot = true
	sp.explosiveness = 0.95
	sp.position = pos
	sp.direction = Vector3(0, -1, 0)
	sp.spread = 45.0
	sp.gravity = Vector3(0, -9.8, 0)
	sp.initial_velocity_min = 2.0
	sp.initial_velocity_max = 5.0

	var sm := BoxMesh.new()
	sm.size = Vector3(0.04, 0.04, 0.04)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.92, 0.98, 0.8)
	mat.roughness = 0.2
	sm.material = mat
	sp.mesh = sm

	add_child(sp)
	sp.emitting = true
	get_tree().create_timer(1.2, false).timeout.connect(sp.queue_free)


func _inspect_reading() -> void:
	# Формирование аутентичной советской сводки по шкале Вильда
	var spd: float = Game.synoptic.wind_speed if Game.synoptic != null else 12.0
	var pin := _speed_to_pin(spd)
	var rumb_name := _yaw_to_rumb_str(vane_yaw)

	# Аномалия Ночи 5: доска задрана на 80 градусов в неподвижности
	if Game.is_night() and Game.night == 5:
		Game.hud.subtitle(Loc.p("Флюгер Вильда: доска задрана на штифт 7 (шторм 24 м/с), но стоит мертво... Ни единого колебания.", "Wild vane: plate raised to pin 7 (24 m/s storm), but stands dead still... Not a single tremor."), 5.0)
		return

	# Аномалия Ночи 7: флюгер бешено крутит
	if Game.is_night() and Game.night == 7:
		Game.hud.subtitle(Loc.p("Флюгер Вильда: флюгарка с визгом вращается по кругу во тьме! Стрелка не ловит ветер.", "Wild vane: arrow shrieks in circles through the dark! Vane cannot catch the wind."), 5.0)
		return

	# Обычное чтение
	var text_ru := "Флюгер Вильда: ветер %s, ~%d м/с (штифт %d)." % [rumb_name, int(roundf(spd)), pin]
	var text_en := "Wild vane: wind %s, ~%d m/s (pin %d)." % [rumb_name, int(roundf(spd)), pin]
	Game.hud.subtitle(Loc.p(text_ru, text_en), 4.5)

	# Сохраняем в снятые показания
	Game.readings["wind_speed"] = spd
	Game.readings["wind_rumb"] = rumb_name


static func _speed_to_pin(spd: float) -> int:
	if spd < 1.0: return 0
	if spd < 3.5: return 1
	if spd < 6.5: return 2
	if spd < 9.5: return 3
	if spd < 13.0: return 4
	if spd < 17.5: return 5
	if spd < 22.0: return 6
	return 7


static func _yaw_to_rumb_str(yaw_rad: float) -> String:
	var deg := fposmod(rad_to_deg(yaw_rad), 360.0)
	var rumbs := ["С", "ССВ", "СВ", "ВСВ", "В", "ВЮВ", "ЮВ", "ЮЮВ", "Ю", "ЮЮЗ", "ЮЗ", "ЗЮЗ", "З", "ЗСЗ", "СЗ", "ССЗ"]
	var idx := int(roundf(deg / 22.5)) % 16
	return rumbs[idx]


func _process(delta: float) -> void:
	_t += delta

	# Синхронизация статуса обледенения
	if Game.anemo_iced != is_iced:
		is_iced = Game.anemo_iced
		if _ice_mesh != null:
			_ice_mesh.visible = is_iced

	var true_wind_spd: float = Game.synoptic.wind_speed if Game.synoptic != null else 10.0
	var true_wind_deg: float = Game.synoptic.wind_azimuth_deg if Game.synoptic != null else 0.0
	var true_wind_dir := deg_to_rad(true_wind_deg)

	# -----------------------------------------------------------------
	# Аномалии поведения флюгера по ночам:
	# -----------------------------------------------------------------
	# Ночь 7: бешеное вращение в штиль
	if Game.is_night() and Game.night == 7:
		_spin_speed = lerpf(_spin_speed, 8.5, delta * 2.0)
		vane_yaw += _spin_speed * delta
		plate_angle = 75.0 + sin(_t * 14.0) * 8.0
	# Ночь 5: доска задрана на штифт 7 (80 градусов) и абсолютно неподвижна
	elif Game.is_night() and Game.night == 5:
		vane_yaw = true_wind_dir
		plate_angle = 80.0
	# Ночь 3: флюгер отклоняется на 25 градусов в сторону от истинного ветра
	elif Game.is_night() and Game.night == 3:
		var target_yaw := true_wind_dir + deg_to_rad(25.0)
		vane_yaw = lerp_angle(vane_yaw, target_yaw, delta * 3.0)
		if not is_iced:
			var pin := _speed_to_pin(true_wind_spd)
			var base_ang := float(pin) * 11.5
			plate_angle = lerpf(plate_angle, base_ang + sin(_t * 7.0) * 2.5, delta * 4.0)
	# Обычный физический режим:
	else:
		# Флюгарка плавно поворачивается носом к ветру
		vane_yaw = lerp_angle(vane_yaw, true_wind_dir, delta * 3.5)

		# Доска Вильда: отклоняется ветром вдоль дуги
		if is_iced:
			# При обледенении доска намертво заклинена между штифтами 2 и 3 (~32 градуса)
			plate_angle = 32.0
		else:
			var pin := _speed_to_pin(true_wind_spd)
			var target_angle := float(pin) * 11.8
			# Трепет пластины на порывах ветра
			var flutter := sin(_t * 9.5) * 3.2 + cos(_t * 15.0) * 1.8
			plate_angle = clampf(lerpf(plate_angle, target_angle + flutter, delta * 5.0), 0.0, 85.0)

	# Применение вращения к нодам
	if _vane_head != null:
		_vane_head.rotation.y = vane_yaw
	if _plate_pivot != null:
		_plate_pivot.rotation.x = deg_to_rad(plate_angle)
