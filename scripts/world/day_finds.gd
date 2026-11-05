class_name DayFinds
extends Node
## Дневные находки (1.55): днём у каждого дня своя короткая постановка — сразу после того, как
## сделана цель дня (Game.day_goal_done). Не катсцена: управление у игрока, мир просто «отвечает».
##   1 — сарай ГСМ: пока был внутри, к двери подошли босые следы и оборвались;
##   2 — изба: «Зорька» без питания сама играет колыбельную;
##   3 — ретранслятор: внизу фонарь крыльца мигает три раза — так сигналит Михалыч, а дома никого;
##   4 — прорубь: подо льдом проходит тёмная тень, и лёд щёлкает;
##   5 — бункер: люк над головой захлопывается и открывается сам;
##   6 — навес у озера: от навеса в лес уходит лыжня, рядом — босые следы.

const WHISPER := "res://assets/audio/whisper.ogg"
const STINGER := "res://assets/audio/sub_drop.ogg"
const CLANK := "res://assets/audio/clank.ogg"
const LULLABY := "res://assets/audio/lullaby_loop.ogg"
const ICE := "res://assets/audio/ice_hit.ogg"

var _done := false
var _nodes: Array[Node] = []


func _ready() -> void:
	if not Game.is_day() or Game.is_prologue() or Net.role != "" or SaveGame.flags.get("find_%d" % Game.phase_index, false):
		set_process(false)


func _process(_delta: float) -> void:
	if _done or not Game.day_goal_done or Game.shift_over:
		return
	var p := Game.player
	if p == null or p.mode != Player.Mode.WALK or Game.hud.modal() != null or Game.hud.is_note_open():
		return
	_done = true
	set_process(false)
	SaveGame.flags["find_%d" % Game.phase_index] = true
	_play(Game.phase_index)


func _think(key: StringName, wait := 0.0) -> void:
	var text := Loc.t(key)
	var d := clampf(text.length() * 0.055, 3.0, 7.0)
	Game.hud.subtitle(text, d, 2)
	await get_tree().create_timer(d + 0.3 + wait, false).timeout


func _wait(t: float) -> void:
	await get_tree().create_timer(t, false).timeout


func _prints(from: Vector3, to: Vector3, n: int, size := Vector3(0.1, 0.012, 0.24)) -> void:
	var dir := (to - from).normalized()
	for i in n:
		var k := float(i) / float(maxi(n - 1, 1))
		var pos := from.lerp(to, k) + dir.cross(Vector3.UP) * (0.13 if i % 2 == 0 else -0.13)
		var f := Geo.box_mesh(size, Palette.m(&"dark"))
		Game.level.add_child(f)
		_nodes.append(f)
		f.global_position = Vector3(pos.x, Terrain.height(pos.x, pos.z) + 0.012, pos.z)
		f.look_at(f.global_position + dir, Vector3.UP)


func _play(day: int) -> void:
	SessionLog.note("находка дня %d" % day)
	match day:
		1:
			await _wait(1.5)
			var to_st := (Vector3(12, 0, 3) - Yard.SHED).normalized()
			var end := Yard.SHED + to_st * 3.2
			_prints(end + Vector3(14.0, 0, 10.0), end, 16)
			Game.audio.play_3d(WHISPER, end + Vector3(0, 1.2, 0), -6.0, 4.0)
			await _think(&"find1.a", 0.8)
			await _think(&"find1.b")
		2:
			await _wait(1.0)
			var zr := Game.audio.play_3d(LULLABY, Yard.IZBA + Vector3(-0.6, 1.0, -1.0), -10.0, 3.0, 9.0)
			await _think(&"find2.a", 1.5)
			await _think(&"find2.b")
			if is_instance_valid(zr):
				zr.queue_free()
		3:
			await _wait(2.5)
			await _think(&"find3.a")
			var st := Game.level as Station
			for i in 3:
				if st != null:
					st.set_lit(false)
				await _wait(0.45)
				if st != null:
					st.set_lit(true)
				await _wait(0.45)
			await _think(&"find3.b")
		4:
			await _wait(0.8)
			var sh := Geo.box_mesh(Vector3(0.7, 0.01, 1.9), Palette.m(&"dark"))
			Game.level.add_child(sh)
			_nodes.append(sh)
			var y := Terrain.height(Yard.HOLE.x, Yard.HOLE.z) - 0.04
			sh.global_position = Vector3(Yard.HOLE.x - 4.0, y, Yard.HOLE.z + 2.0)
			var tw := create_tween()
			tw.tween_property(sh, "global_position", Vector3(Yard.HOLE.x + 5.0, y, Yard.HOLE.z - 3.0), 4.5).set_trans(Tween.TRANS_SINE)
			for i in 3:
				Game.audio.play_3d(ICE, Yard.HOLE + Vector3(randf_range(-3, 3), 0.2, randf_range(-3, 3)), -4.0, 6.0)
				await _wait(0.9)
			await _think(&"find4.a", 0.5)
			await _think(&"find4.b")
		5:
			await _wait(1.2)
			Game.audio.play_3d(CLANK, Yard.BUNKER + Vector3(0, 0.8, 0), 4.0, 6.0)
			Game.hud.set_black(true)
			Game.audio.play_2d(STINGER, -2.0)
			await _wait(2.2)
			Game.audio.play_3d(CLANK, Yard.BUNKER + Vector3(0, 0.8, 0), 0.0, 6.0)
			Game.hud.set_black(false)
			await _think(&"find5.a")
			await _think(&"find5.b")
		6:
			await _wait(1.5)
			var from := Yard.LAKE_SHACK + Vector3(2.0, 0, -2.5)
			var to := from + Vector3(-22.0, 0, -30.0)
			for side: float in [-0.12, 0.12]:
				var a := from + Vector3(side, 0, 0)
				var b := to + Vector3(side, 0, 0)
				for i in 30:
					var k := float(i) / 29.0
					var pos := a.lerp(b, k)
					var trk := Geo.box_mesh(Vector3(0.07, 0.01, 0.9), Palette.m(&"dark"))
					Game.level.add_child(trk)
					_nodes.append(trk)
					trk.global_position = Vector3(pos.x, Terrain.height(pos.x, pos.z) + 0.01, pos.z)
					trk.look_at(trk.global_position + (b - a).normalized(), Vector3.UP)
			_prints(from + Vector3(0.8, 0, 0), to + Vector3(0.8, 0, 0), 26)
			await _think(&"find6.a", 0.8)
			await _think(&"find6.b")
