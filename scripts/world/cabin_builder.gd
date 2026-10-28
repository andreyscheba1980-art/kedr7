class_name CabinBuilder
extends RefCounted
## Наружный сруб: стены из настоящих брёвен (гранёный восьмигранник), с выпуском «в чашу» на
## внешних углах, с перевязкой рядов (стены вдоль X и вдоль Z смещены на полбревна), с вырезами под
## окна и двери, со скошенным верхом под односкатную крышу и с рублеными фронтонами.
## Всё бревно — в один меш (две поверхности: кора и торцы), так что сруб — пара вызовов отрисовки.

const D := 0.26          ## диаметр бревна
const STEP := 0.235      ## шаг рядов (брёвна чуть врезаны друг в друга — без щелей)
const OVER := 0.26       ## выпуск бревна за наружный угол
const OFFSET := 0.23     ## ось бревна от линии штукатурной стены наружу
const SIDES := 8

var _side := SurfaceTool.new()
var _ends := SurfaceTool.new()
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	for st in [_side, _ends]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_smooth_group(-1)
	_rng.seed = 1983


## Бревно по оси X (axis = 0) или Z (axis = 2) от u0 до u1, центр сечения (c_a, y): c_a — координата по другой оси.
func add_log(axis: int, u0: float, u1: float, c: float, y: float, end0 := true, end1 := true) -> void:
	if u1 - u0 < 0.12:
		return
	var r := D * 0.5 * _rng.randf_range(0.93, 1.05)
	var phase := _rng.randf() * 0.4
	var ring0: Array[Vector3] = []
	var ring1: Array[Vector3] = []
	for i in SIDES:
		var a := phase + TAU * float(i) / float(SIDES)
		var dy := sin(a) * r
		var dc := cos(a) * r
		ring0.append(_p(axis, u0, c + dc, y + dy))
		ring1.append(_p(axis, u1, c + dc, y + dy))
	for i in SIDES:
		var j := (i + 1) % SIDES
		_side.add_vertex(ring0[i])
		_side.add_vertex(ring1[i])
		_side.add_vertex(ring1[j])
		_side.add_vertex(ring0[i])
		_side.add_vertex(ring1[j])
		_side.add_vertex(ring0[j])
	if end0:
		_cap(ring0, _p(axis, u0, c, y))
	if end1:
		_cap(ring1, _p(axis, u1, c, y))


func _cap(ring: Array[Vector3], center: Vector3) -> void:
	for i in SIDES:
		_ends.add_vertex(center)
		_ends.add_vertex(ring[i])
		_ends.add_vertex(ring[(i + 1) % SIDES])


static func _p(axis: int, u: float, c: float, y: float) -> Vector3:
	return Vector3(u, y, c) if axis == 0 else Vector3(c, y, u)


## Стена по оси axis на линии c (ось бревна), от u0 до u1. Верх — линейно от top0 (при u0) до top1 (при u1).
## openings: [[u_from, u_to, y_from, y_to], ...] — проёмы. ext0/ext1 — наружный угол (выпуск бревна).
## shift — 0 или 0.5: стены вдоль X и вдоль Z перевязаны со смещением на полряда.
func wall(axis: int, u0: float, u1: float, c: float, base: float, top0: float, top1: float,
		openings: Array = [], ext0 := false, ext1 := false, shift := 0.0) -> void:
	var y := base + STEP * shift
	while true:
		# Где бревно ещё под крышей: верх стены линеен по u.
		var ua := u0 - (OVER if ext0 else 0.0)
		var ub := u1 + (OVER if ext1 else 0.0)
		var need := y + D * 0.35
		if top0 < need and top1 < need:
			break
		if absf(top1 - top0) > 0.001:
			var u_at := u0 + (need - top0) / (top1 - top0) * (u1 - u0)   # где верх стены = need
			if top0 < need:
				ua = maxf(ua, u_at)
			if top1 < need:
				ub = minf(ub, u_at)
		# Проёмы режут ряд на куски.
		var pieces: Array = [[ua, ub]]
		for o: Array in openings:
			if y + D * 0.5 <= float(o[2]) or y - D * 0.5 >= float(o[3]):
				continue
			var next: Array = []
			for p: Array in pieces:
				var a: float = p[0]
				var b: float = p[1]
				var oa: float = o[0]
				var ob: float = o[1]
				if ob <= a or oa >= b:
					next.append(p)
					continue
				if oa > a:
					next.append([a, oa])
				if ob < b:
					next.append([ob, b])
			pieces = next
		for p: Array in pieces:
			add_log(axis, p[0], p[1], c, y)
		y += STEP


## Рубленый фронтон: брёвна вдоль axis, укорачиваются к коньку. u_c — середина, half — полуширина у основания.
func gable(axis: int, u_c: float, half: float, c: float, base: float, ridge: float, openings: Array = []) -> void:
	var y := base + STEP * 0.5
	while y < ridge - D * 0.3:
		var k := 1.0 - (y + D * 0.3 - base) / (ridge - base)
		var hw := half * maxf(k, 0.0)
		if hw < 0.08:
			break
		var pieces: Array = [[u_c - hw, u_c + hw]]
		for o: Array in openings:
			if y + D * 0.5 <= float(o[2]) or y - D * 0.5 >= float(o[3]):
				continue
			var next: Array = []
			for p: Array in pieces:
				if float(o[1]) <= float(p[0]) or float(o[0]) >= float(p[1]):
					next.append(p)
					continue
				if float(o[0]) > float(p[0]):
					next.append([p[0], o[0]])
				if float(o[1]) < float(p[1]):
					next.append([o[1], p[1]])
			pieces = next
		for p: Array in pieces:
			add_log(axis, p[0], p[1], c, y)
		y += STEP


func build(parent: Node, side_mat: Material, end_mat: Material) -> MeshInstance3D:
	_side.generate_normals()
	_ends.generate_normals()
	var mesh := ArrayMesh.new()
	_side.commit(mesh)
	_ends.commit(mesh)
	mesh.surface_set_material(0, side_mat)
	mesh.surface_set_material(1, end_mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = "LogWalls"
	parent.add_child(mi)
	return mi
