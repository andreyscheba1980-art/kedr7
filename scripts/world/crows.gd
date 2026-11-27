class_name Crows
extends Node3D
## Вороны днём и в сумерках:
##   • сидят на коньке дома и крыше дизельной, вертят головами — при приближении (или угрозе) с карканьем улетают;
##   • стаи высоко кружат над дальними ориентирами (лесосека, вышка, буровая) — живой указатель в небе.

const SPOTS := [Vector3(1.6, 5.62, 3.3), Vector3(6.8, 5.62, 3.3), Vector3(7.5, 5.62, 3.32), Vector3(12.2, 5.62, 3.3),
	Vector3(14.2, 2.72, -12.5)]
const SCARE_DIST := 9.0

var _birds: Array = []      ## [root, head, wing_l, wing_r, state(0 сидит/1 летит/2 кружит), velocity, t, meta]
var _flock_centers: Array[Vector3] = []


func _ready() -> void:
	if not Game.is_daylight():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count := rng.randi_range(2, 4)
	var spots := SPOTS.duplicate()
	spots.shuffle()
	for i in count:
		var b := _make_crow()
		b.position = spots[i]
		b.rotation.y = rng.randf() * TAU
		add_child(b)
		_birds.append([b, b.get_node("Head"), b.get_node("WingL"), b.get_node("WingR"), 0, Vector3.ZERO, rng.randf() * 5.0, {}])
	# Кружащие ориентиры над дальними точками (в прологе и днём)
	for site: StringName in [&"camp", &"tower", &"drill"]:
		var c := Terrain.pad_pos(site)
		var base_h := c.y + 22.0
		var n_flock := 3 if site == &"camp" else 2
		for j in n_flock:
			var b := _make_crow()
			var ang := rng.randf() * TAU
			var rad := rng.randf_range(12.0, 24.0)
			b.position = Vector3(c.x + cos(ang) * rad, base_h + rng.randf_range(0.0, 6.0), c.z + sin(ang) * rad)
			add_child(b)
			_birds.append([b, b.get_node("Head"), b.get_node("WingL"), b.get_node("WingR"), 2, Vector3.ZERO, rng.randf() * 6.0, {"c": c, "r": rad, "a": ang, "spd": rng.randf_range(0.28, 0.45) * (1.0 if j % 2 == 0 else -1.0), "y": b.position.y}])


func _process(delta: float) -> void:
	if _birds.is_empty() or Game.player == null:
		return
	var pp := Game.player.global_position
	var scare := Game.yrka != null and Game.yrka.enabled and Game.yrka.stage >= YrkaThreat.Stage.CALLING
	_birds = _birds.filter(func(b: Array) -> bool: return is_instance_valid(b[0]))
	for b: Array in _birds:
		if int(b[4]) == 0 and Game.is_outside() and Game.player.mode == Player.Mode.WALK and (b[0] as Node3D).global_position.distance_to(pp) < SCARE_DIST:
			scare = true
	for b: Array in _birds:
		var root: Node3D = b[0]
		b[6] = float(b[6]) + delta
		var t: float = b[6]
		var st := int(b[4])
		if st == 0:
			if scare:
				_take_off(b, pp)
				continue
			# Сидит: голова дёргается, изредка переступает и разворачивается
			(b[1] as Node3D).rotation.y = sin(t * 1.7) * 0.6 if fmod(t, 3.0) < 1.6 else -0.4
			if fmod(t, 7.0) < delta:
				root.rotation.y += randf_range(-0.8, 0.8)
		elif st == 2:
			var meta: Dictionary = b[7]
			var center: Vector3 = meta["c"]
			var a := float(meta["a"]) + float(meta["spd"]) * delta
			meta["a"] = a
			var r := float(meta["r"])
			var nx := center.x + cos(a) * r
			var nz := center.z + sin(a) * r
			var ny := float(meta["y"]) + sin(t * 1.2) * 0.8
			var next_p := Vector3(nx, ny, nz)
			var dir := next_p - root.position
			if dir.length_squared() > 0.0001:
				root.rotation.y = atan2(-dir.x, -dir.z)
			root.position = next_p
			var flap := sin(t * 9.0) * 0.65 if fmod(t, 4.5) < 2.2 else 0.12
			(b[2] as Node3D).rotation.z = flap
			(b[3] as Node3D).rotation.z = -flap
		else:
			var v: Vector3 = b[5]
			v.y = minf(v.y + delta * 0.6, 2.6)
			b[5] = v
			root.global_position += v * delta
			var flap := sin(t * 16.0) * 1.0
			(b[2] as Node3D).rotation.z = flap
			(b[3] as Node3D).rotation.z = -flap
			if t > 9.0:
				root.queue_free()


func _take_off(b: Array, from: Vector3) -> void:
	var root: Node3D = b[0]
	var away := root.global_position - from
	away.y = 0.0
	away = away.normalized().rotated(Vector3.UP, randf_range(-0.5, 0.5)) if away.length() > 0.1 else Vector3.FORWARD
	b[4] = 1
	(b[2] as Node3D).rotation.y = 0.0
	(b[3] as Node3D).rotation.y = 0.0
	b[5] = away * randf_range(4.0, 6.0) + Vector3(0, 1.4, 0)
	b[6] = 0.0
	root.look_at(root.global_position + away, Vector3.UP)
	if Game.audio != null and randf() < 0.7:
		Game.audio.play_3d("res://assets/sfx/cc0/crow_caw_%d.ogg" % randi_range(1, 5), root.global_position, -2.0, 6.0)


## Ворона: туловище, голова с клювом, хвост, лапки, два крыла на шарнирах (машут в полёте).
func _make_crow() -> Node3D:
	var black := Color(0.05, 0.05, 0.06)
	var root := Node3D.new()
	var k := MeshKit.new(randi())
	k.mottle = 0.08
	k.blob(Vector3(0, 0.13, 0.0), Vector3(0.07, 0.075, 0.14), black, 4, 7)
	k.box(Vector3(0, 0.12, 0.17), Vector3(0.07, 0.015, 0.13), black, Basis(Vector3.RIGHT, deg_to_rad(-15.0)))
	for sx: float in [-0.025, 0.025]:
		k.tube([Vector3(sx, 0.07, 0.0), Vector3(sx, 0.0, 0.01)], [0.006, 0.005], Color(0.12, 0.11, 0.1), 4)
	var body := MeshInstance3D.new()
	body.mesh = k.commit()
	body.material_override = Creatures._mat(&"crow", Color.WHITE, "", 0.02)
	root.add_child(body)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.2, -0.11)
	var hk := MeshKit.new(randi())
	hk.blob(Vector3.ZERO, Vector3(0.045, 0.045, 0.05), black, 4, 7)
	hk.spike(Vector3(0, -0.005, -0.04), Vector3(0, -0.015, -0.11), 0.016, Color(0.1, 0.1, 0.11), 4)
	var hm := MeshInstance3D.new()
	hm.mesh = hk.commit()
	hm.material_override = body.material_override
	head.add_child(hm)
	root.add_child(head)
	for side: float in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.name = "WingL" if side < 0 else "WingR"
		wing.position = Vector3(0.06 * side, 0.17, 0.0)
		var wk := MeshKit.new(randi())
		wk.box(Vector3(0.11 * side, 0, 0.02), Vector3(0.22, 0.012, 0.13), black)
		var wm := MeshInstance3D.new()
		wm.mesh = wk.commit()
		wm.material_override = body.material_override
		wing.add_child(wm)
		wing.rotation.y = -side * PI * 0.47     # сложено вдоль спины
		root.add_child(wing)
	return root
