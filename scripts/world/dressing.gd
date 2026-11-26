class_name Dressing
extends RefCounted
## Обжитость: мелочи и реквизит из CC0-паков (Kenney Survival / Furniture) по комнатам и двору.
## Только визуал без механик; крупное — с коробкой столкновения. Позиции подобраны по карте
## габаритов станции (autotest --tour … dump), чтобы ничего не врезалось в мебель и стены.

const F := 0.05   ## верх пола в доме


static func build(st: Node3D) -> void:
	_living(st)
	_radio(st)
	_corridor(st)
	_storage(st)
	_vestibule(st)
	_shack(st)
	_yard(st)


static func _m(st: Node3D, id: String, pos: Vector3, yaw := 0.0, h := -1.0, opts := {}) -> Node3D:
	return Models.spawn(st, id, pos, yaw, h, opts)


static func _living(st: Node3D) -> void:
	# Сундук в северо-восточном углу, на нём коробка; ведро у печи
	_m(st, "survival/chest", Vector3(2.95, F, 0.45), -90.0, 0.55, {"collide": true})
	_m(st, "furniture/cardboardBoxClosed", Vector3(2.95, F + 0.55, 0.5), 12.0, 0.32)
	_m(st, "survival/bucket", Vector3(-0.05, F, 0.35), 20.0, 0.32, {"tint": Color(0.5, 0.52, 0.55)})


static func _radio(st: Node3D) -> void:
	# Коробки с запчастями и бумагами в юго-восточном углу радиорубки
	_m(st, "furniture/cardboardBoxClosed", Vector3(11.05, F, 1.7), 8.0, 0.42, {"collide": true})
	_m(st, "furniture/cardboardBoxOpen", Vector3(10.6, F, 1.85), -14.0, 0.36)
	_m(st, "furniture/cardboardBoxClosed", Vector3(11.02, F + 0.42, 1.68), -20.0, 0.3)
	_m(st, "furniture/trashcan", Vector3(4.0, F, 1.85), 0.0, 0.42)


static func _corridor(st: Node3D) -> void:
	# Стеллаж у южной стены, ящики у северной: коридор — не пустая труба
	_m(st, "furniture/bookcaseOpen", Vector3(5.6, F, 6.27), 180.0, 1.7, {"collide": true})
	for i in 4:
		_m(st, "furniture/books", Vector3(5.25 + float(i) * 0.22, F + 0.716 + float(i % 2) * 0.463, 6.27), 180.0 + float(i) * 7.0, 0.22)
	_m(st, "survival/box-large", Vector3(3.8, F, 2.62), 90.0, 0.5, {"collide": true})   # к стене: шире проход в кладовую
	_m(st, "survival/box", Vector3(3.85, F + 0.5, 2.6), 76.0, 0.42)
	_m(st, "survival/bucket", Vector3(9.3, F, 2.55), 0.0, 0.3)
	_m(st, "furniture/cardboardBoxOpen", Vector3(8.6, F, 6.25), 6.0, 0.36)


static func _storage(st: Node3D) -> void:
	# Бочки с керосином и ящики в холодной кладовой (в стороне от стола фотолаборатории DarkroomTable)
	_m(st, "survival/barrel", Vector3(3.95, F, -2.55), 0.0, 0.85, {"collide": true, "tint": Color(0.62, 0.34, 0.26)})
	_m(st, "survival/barrel", Vector3(4.55, F, -2.55), 40.0, 0.85, {"collide": true, "tint": Color(0.5, 0.42, 0.36)})
	_m(st, "survival/box", Vector3(4.25, F, -4.35), 10.0, 0.45, {"collide": true})
	_m(st, "survival/bucket", Vector3(6.75, F, -2.4), 0.0, 0.3)
	_m(st, "survival/resource-planks", Vector3(6.2, F, -2.55), 90.0, 0.16)


static func _vestibule(st: Node3D) -> void:
	_m(st, "survival/box", Vector3(11.85, F, 1.95), 18.0, 0.42, {"collide": true})
	_m(st, "survival/bucket", Vector3(12.25, F, 1.9), 0.0, 0.3, {"tint": Color(0.5, 0.52, 0.55)})


static func _shack(st: Node3D) -> void:
	var c := Vector3(14.5, 0.05, -13.5)
	var bench_top := 0.805
	# Инструмент на верстаке и у стены
	_m(st, "survival/tool-hammer", Vector3(15.25, bench_top + 0.03, -13.25), 70.0, -1.0, {"scale": 1.6, "tilt": Vector3(90, 0, 0), "shadow": false})
	_m(st, "survival/bottle", Vector3(15.8, bench_top, -12.85), 0.0, 0.25, {"tint": Color(0.6, 0.75, 0.5)})
	_m(st, "survival/tool-shovel", c + Vector3(-1.38, 1.24, 0.85), 90.0, 1.25, {"tilt": Vector3(0, 0, 171)})   # штык вниз
	_m(st, "survival/tool-axe", c + Vector3(-1.4, 0.05, 0.45), 90.0, 0.75, {"tilt": Vector3(0, 0, -11)})
	_m(st, "survival/bucket", c + Vector3(1.15, 0.05, 0.85), 0.0, 0.3)
	# Внутри дизельной: шкаф управления в углу, ящик с ЗИПом
	_m(st, "factory/screen-panel-small", c + Vector3(-1.08, 0.05, -0.98), 90.0, 1.25, {"collide": true, "tint": Color(0.55, 0.62, 0.55)})
	_m(st, "factory/box-small", c + Vector3(-1.1, 0.05, -0.3), 90.0, 0.4, {"tint": Color(0.5, 0.55, 0.45)})


static func _yard(st: Node3D) -> void:
	# Ящики под свесом у тамбура
	_m(st, "survival/box-large", Vector3(15.65, 0.0, 5.75), 84.0, 0.55, {"collide": true})
	_m(st, "survival/box", Vector3(15.7, 0.55, 5.7), 70.0, 0.45, {"collide": true})
	# Брёвна-кругляк у северной стены — запас на распил
	for i in 3:
		var y := 0.24 if i < 2 else 0.62
		var x := 11.4
		var z := -4.4 + (float(i) * 0.5 if i < 2 else 0.25)
		_m(st, "survival/tree-log", Vector3(x, y - 0.24, z), 90.0 + float(i) * 3.0, 0.48, {"collide": i == 0})
	# Камни под снегом по двору
	var rocks := [["rock-a", Vector3(-5.0, 0, 9.0), 0.55], ["rock-b", Vector3(3.0, 0, -10.5), 0.45], ["rock-c", Vector3(22.0, 0, -6.0), 0.7],
		["rock-a", Vector3(-6.5, 0, -8.0), 0.5], ["rock-b", Vector3(20.5, 0, 12.0), 0.6], ["rock-c", Vector3(-1.0, 0, 11.5), 0.4]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for r: Array in rocks:
		var p: Vector3 = r[1]
		if _free(p, 1.8):
			_m(st, "survival/" + str(r[0]), p + Vector3(0, -0.12, 0), rng.randf_range(0, 360), float(r[2]), {"tint": Color(0.7, 0.74, 0.8), "collide": true})


## Свободна ли точка двора: не на тропе, не в доме, не у дизельной.
static func _free(p: Vector3, r := 1.8) -> bool:
	if Game.yard != null and Game.yard._dist_to(Game.yard._all_paths, p) < r:
		return false
	# Контур дома станции со всеми комнатами (x: -3.0..18.0, z: -6.0..7.5) с запасом
	if p.x > -5.5 and p.x < 18.5 and p.z > -7.5 and p.z < 8.5:
		return false
	# Контур дизельной «ДЭС-8» и мостков (x: 12.0..17.5, z: -15.5..-10.5)
	if p.x > 11.5 and p.x < 18.0 and p.z > -16.0 and p.z < -10.0:
		return false
	return true



