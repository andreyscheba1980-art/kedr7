class_name MeshKit
extends RefCounted
## Сборщик лоу-поли мешей в PS1-стиле: трубки по точкам (конечности, шеи), деформированные
## эллипсоиды (черепа, торсы), коробки. Плоские нормали и цвет вершин; нормаль каждой грани
## ориентируется по подсказке «наружу», поэтому порядок обхода вершин не важен
## (материал существ рисует обе стороны).

var _st := SurfaceTool.new()
var _rng := RandomNumberGenerator.new()
## Случайная вариация яркости вершин: пятна на коже, грязь на одежде.
var mottle := 0.0


func _init(seed_value := 1) -> void:
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_rng.seed = seed_value


func commit() -> ArrayMesh:
	return _st.commit()


## Треугольник с нормалью, развёрнутой в сторону outward.
func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, outward: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	# В Godot лицевая грань — с обходом по часовой стрелке, если смотреть снаружи: тогда
	# геометрическая нормаль (b−a)×(c−a) смотрит внутрь. Иначе двусторонний материал
	# считает грань «изнанкой», переворачивает нормаль — и грань выходит чёрной.
	var verts := [a, b, c]
	if n.dot(outward) > 0.0:
		verts = [a, c, b]
	else:
		n = -n
	var face_col := _vary(col)   # одна вариация на грань — пятна, а не «шум»
	for v in verts:
		_st.set_normal(n)
		_st.set_color(face_col)
		_st.add_vertex(v)


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, outward: Vector3) -> void:
	tri(a, b, c, col, outward)
	tri(a, c, d, col, outward)


## Трубка по точкам с радиусом в каждой. cols — цвет на каждое кольцо (иначе col).
func tube(points: Array, radii: Array, col: Color, sides := 6, cap_start := true, cap_end := true, cols: Array = []) -> void:
	var n := points.size()
	if n < 2:
		return
	var rings: Array = []
	var ref := Vector3.UP
	for i in range(n):
		var p: Vector3 = points[i]
		var t: Vector3
		if i == 0:
			t = (points[1] as Vector3) - p
		elif i == n - 1:
			t = p - (points[i - 1] as Vector3)
		else:
			t = (points[i + 1] as Vector3) - (points[i - 1] as Vector3)
		t = t.normalized()
		if absf(t.dot(ref)) > 0.95:
			ref = Vector3.RIGHT
		var u := t.cross(ref).normalized()
		var v := u.cross(t).normalized()
		ref = v   # «транспорт» опорного вектора — трубка не перекручивается на изгибах
		var r: float = radii[mini(i, radii.size() - 1)]
		var ring: Array[Vector3] = []
		for j in range(sides):
			var a := TAU * j / sides
			ring.append(p + (u * cos(a) + v * sin(a)) * r)
		rings.append(ring)
	for i in range(n - 1):
		var ca: Vector3 = points[i]
		var cb: Vector3 = points[i + 1]
		var mid := (ca + cb) * 0.5
		var c: Color = cols[i] if i < cols.size() else col
		var r0: Array[Vector3] = rings[i]
		var r1: Array[Vector3] = rings[i + 1]
		for j in range(sides):
			var k := (j + 1) % sides
			var face_mid := (r0[j] + r0[k] + r1[j] + r1[k]) * 0.25
			quad(r0[j], r1[j], r1[k], r0[k], c, face_mid - mid)
	if cap_start:
		_cap(rings[0], points[0], (points[0] as Vector3) - (points[1] as Vector3), col)
	if cap_end:
		_cap(rings[n - 1], points[n - 1], (points[n - 1] as Vector3) - (points[n - 2] as Vector3), cols[n - 2] if n - 2 < cols.size() else col)


func _cap(ring: Array[Vector3], center: Vector3, outward: Vector3, col: Color) -> void:
	var tip := center + outward.normalized() * 0.002
	for j in range(ring.size()):
		tri(tip, ring[j], ring[(j + 1) % ring.size()], col, outward)


## Эллипсоид с деформацией: deform(dir) → множитель радиуса для единичного направления.
func blob(center: Vector3, radii: Vector3, col: Color, rings := 5, segs := 7, basis := Basis(), deform: Callable = Callable(), cols_by_y: Callable = Callable()) -> void:
	var grid: Array = []
	for i in range(rings + 1):
		var phi := PI * i / rings          # 0 — верх, PI — низ
		var row: Array[Vector3] = []
		for j in range(segs):
			var th := TAU * j / segs
			var dir := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			var k := 1.0
			if deform.is_valid():
				k = float(deform.call(dir))
			row.append(center + basis * (dir * radii * k))
		grid.append(row)
	for i in range(rings):
		var r0: Array[Vector3] = grid[i]
		var r1: Array[Vector3] = grid[i + 1]
		for j in range(segs):
			var k := (j + 1) % segs
			var face_mid := (r0[j] + r0[k] + r1[j] + r1[k]) * 0.25
			var c := col
			if cols_by_y.is_valid():
				c = cols_by_y.call((face_mid - center).normalized())
			if i == 0:
				tri(r0[j], r1[j], r1[k], c, face_mid - center)
			elif i == rings - 1:
				tri(r0[j], r1[j], r0[k], c, face_mid - center)
			else:
				quad(r0[j], r1[j], r1[k], r0[k], c, face_mid - center)


func box(center: Vector3, size: Vector3, col: Color, basis := Basis()) -> void:
	var h := size * 0.5
	var corners: Array[Vector3] = []
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				corners.append(center + basis * Vector3(h.x * x, h.y * y, h.z * z))
	# индексы: x*4 + y*2 + z
	var faces := [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
	for f: Array in faces:
		var a: Vector3 = corners[f[0]]
		var b: Vector3 = corners[f[1]]
		var c: Vector3 = corners[f[2]]
		var d: Vector3 = corners[f[3]]
		quad(a, b, c, d, col, (a + b + c + d) * 0.25 - center)


## Конус/клин — когти, зубы, ушанка. base — центр основания, tip — остриё.
func spike(base: Vector3, tip: Vector3, radius: float, col: Color, sides := 4) -> void:
	tube([base, base.lerp(tip, 0.5), tip], [radius, radius * 0.55, 0.002], col, sides, true, false)


func _vary(c: Color) -> Color:
	if mottle <= 0.0:
		return c
	var k := 1.0 + _rng.randf_range(-mottle, mottle)
	return Color(c.r * k, c.g * k, c.b * k, c.a)
