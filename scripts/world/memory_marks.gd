class_name MemoryMarks
extends RefCounted
## Мир помнит — и это видно. По итогам прошлых ночей (NightMemory, flags["mem_total"]) в начале ночи
## во дворе появляются тихие следы-последствия. Без субтитров и стингеров: их надо заметить самому.
##   out_after3  — ходил по двору после трёх: кто-то прошёл ТВОИМ маршрутом к дизельной — босиком,
##                 рядом с мостками, и встал у крыльца;
##   turned      — оборачивался на зов: ночью на тропе к сараю стоит фигура лицом к дому — с каждым
##                 разом ближе; подойдёшь или посветишь — её нет;
##   obeyed_fake — выполнял ложный приказ: от развилки к мачте ведут следы твоих валенок — только туда.
## С третьей ночи (и днём после неё) и только если такое было в прошлые ночи (сегодняшнее — завтра).

static func build(st: Node3D) -> void:
	var ok := (Game.is_night() and Game.night >= 3) or (Game.is_day() and Game.phase_index >= 3)
	if not ok:      # днём следы прошлой ночи тоже на месте — их видно при свете
		return
	var total: Dictionary = SaveGame.flags.get("mem_total", {})
	if OS.is_debug_build() and OS.get_cmdline_user_args().has("mem"):   # проверка в автотесте
		total = {"out_after3": 2, "turned": 1, "obeyed_fake": 1}
	if int(total.get("out_after3", 0)) > 0:
		_walked_your_route(st)
	if int(total.get("turned", 0)) > 0:
		_under_window(st)
	if int(total.get("obeyed_fake", 0)) > 0:
		_one_way(st)


static func _walked_your_route(st: Node3D) -> void:
	# Из леса на северо-востоке — к будке дизельной, вдоль мостков к дому, у крыльца стоп.
	var route := PackedVector3Array([Vector3(26.0, 0, -15.5), Vector3(17.6, 0, -12.6), Vector3(17.3, 0, -6.5),
		Vector3(17.5, 0, -1.5), Vector3(17.2, 0, 1.9)])
	Footprints.trail(st, &"bare", route, 0.0, 0.52)


static func _under_window(st: Node3D) -> void:
	# Ночью на тропе к сараю стоит фигура лицом к дому — её видно с крыльца. Каждый раз, когда игрок
	# оборачивался на зов, она стоит ближе: ~29 → 21 → 17 м. Подойдёшь или посветишь — её там нет.
	if not Game.is_night():
		return
	var total: Dictionary = SaveGame.flags.get("mem_total", {})
	var n := clampi(int(total.get("turned", 1)), 1, 3)
	var spots := [Vector3(36.0, 0, 24.0), Vector3(31.0, 0, 18.0), Vector3(28.0, 0, 14.5)]
	var w := Watcher.new()
	w.position = spots[n - 1]
	st.add_child(w)


static func _one_way(st: Node3D) -> void:
	# От развилки у крыльца к мачте — валенки игрока. Обратной цепочки нет, обрываются на полпути.
	var route := PackedVector3Array([Vector3(20.5, 0, 2.5), Vector3(22.5, 0, -5.0), Vector3(24.2, 0, -12.0), Vector3(25.0, 0, -16.5)])
	Footprints.trail(st, &"snow", route, 0.0, 0.62)


## Фигура на опушке: стоит неподвижно лицом к дому. Исчезает, если подойти ближе 14 м
## или посветить на неё фонарём. Никаких звуков — только «показалось».
class Watcher extends Node3D:
	## Без освещения и тумана, на пару тонов светлее ночного леса (фильмик-тонмаппинг съедает
	## всё ниже ~0.12). В метель тускнеет вместе с видимостью.
	const BASE := Color(0.15, 0.16, 0.19)
	var _body: Node3D
	var _mat: StandardMaterial3D

	func _ready() -> void:
		_body = Creatures.make_silhouette()
		add_child(_body)
		# Ночью без фонаря двор почти чёрный, тёмная фигура в нём не читается — поэтому серое пятно.
		var m := StandardMaterial3D.new()
		_mat = m
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.disable_fog = true   # иначе на 20–30 м туман съедает её целиком, а в разную погоду — по-разному
		m.albedo_color = BASE
		var stack: Array[Node] = [_body]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			if n is MeshInstance3D:
				(n as MeshInstance3D).material_override = m
		if OS.is_debug_build():
			print("[watcher] at ", global_position)
		_body.look_at_from_position(global_position, Vector3(16.0, 0.0, 3.3), Vector3.UP)

	func _process(_delta: float) -> void:
		var p := Game.player
		if p == null:
			return
		var to := global_position + Vector3(0, 1.4, 0) - p.camera.global_position
		var d := to.length()
		if Game.weather != null:
			_mat.albedo_color = BASE.lerp(Color(0.08, 0.085, 0.1), Game.weather.intensity)
		var lit := p.flashlight_on() and d < 32.0 and (-p.camera.global_basis.z).dot(to.normalized()) > 0.93
		if d < 14.0 or lit:
			if OS.is_debug_build():
				print("[watcher] gone d=%.1f lit=%s cam=%s" % [d, lit, p.camera.global_position])
			queue_free()
