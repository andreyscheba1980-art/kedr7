class_name SessionLog
extends Node
## Журнал сессии для плейтеста: рядом с игрой, в sessions/<время>.txt — что игрок делал и где застревал.
##   • каждая смена цели — сколько минут ушло на прошлую;
##   • смерть, конец смены, F9-отчёт — с местом и временем;
##   • «тупик»: цель не меняется 3 минуты, а игрок за последние 2 минуты не ушёл дальше 12 м (ходит кругами
##     или стоит) — запись в журнал и тихая мысль-подсказка Виктора (не чаще раза в 4 минуты).
## Файл дописывается построчно — если игра упадёт, всё до падения останется.

const STUCK_AFTER := 180.0
const STUCK_RADIUS := 12.0
const HINT_COOLDOWN := 240.0

static var instance: SessionLog

var _path := ""
var _goal := ""
var _goal_t := 0.0
var _sample_t := 0.0
var _trail: Array[Vector3] = []          ## позиция раз в 10 с, последние 2 минуты
var _hint_cd := 0.0
var _stuck_said := false
var _deaths := 0


func _ready() -> void:
	instance = self
	name = "SessionLog"
	if SaveGame.memory_only or Achievements._testing():
		return
	var dir := AudioDirector._out_dir().path_join("sessions")
	DirAccess.make_dir_recursive_absolute(dir)
	_path = dir.path_join(Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_") + ".txt")
	write("Кедр-7 %s · %s · %s · %s" % [ProjectSettings.get_setting("application/config/version", "?"), OS.get_name(),
		RenderingServer.get_video_adapter_name(), Loc.t(StringName("set.q%d" % Settings.quality))])
	write("Фаза %s %d (ночь %d), сложность %s" % [Game.phase_kind, Game.phase_index, Game.night, SaveGame.difficulty])
	EventBus.player_died.connect(func(reason: StringName) -> void:
		_deaths += 1
		write("СМЕРТЬ: %s — на цели «%s» (%.1f мин)" % [reason, _goal, _goal_t / 60.0]))
	EventBus.shift_ended.connect(func() -> void: write("Конец смены. Последняя цель «%s» — %.1f мин" % [_goal, _goal_t / 60.0]))


func _exit_tree() -> void:
	if instance == self:
		instance = null


static func note(text: String) -> void:
	if instance != null:
		instance.write(text)


func write(text: String) -> void:
	if _path == "":
		return
	var f := FileAccess.open(_path, FileAccess.READ_WRITE if FileAccess.file_exists(_path) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	var p := Game.player
	var where := " @%s %s" % [Game.zone, p.global_position.snapped(Vector3.ONE)] if (p != null and p.is_inside_tree()) else ""
	f.store_line("[%s | игра %s%s] %s" % [Time.get_time_string_from_system(), Game.clock_text(), where, text])


func _process(delta: float) -> void:
	var p := Game.player
	if p == null or Game.shift_over or Game.dead:
		return
	_goal_t += delta
	_hint_cd = maxf(_hint_cd - delta, 0.0)
	_sample_t -= delta
	if _sample_t > 0.0:
		return
	_sample_t = 10.0
	var g := Game.objective_text()
	if g != _goal:
		if _goal != "":
			write("Цель выполнена/сменилась: «%s» — %.1f мин" % [_goal, _goal_t / 60.0])
		_goal = g
		_goal_t = 0.0
		_stuck_said = false
		_trail.clear()
		write("Новая цель: «%s»" % g)
	_trail.append(p.global_position)
	if _trail.size() > 12:
		_trail.pop_front()
	if _goal_t > STUCK_AFTER and _trail.size() >= 12 and p.mode == Player.Mode.WALK:
		var c := Vector3.ZERO
		for v in _trail:
			c += v
		c /= _trail.size()
		var spread := 0.0
		for v in _trail:
			spread = maxf(spread, v.distance_to(c))
		if spread < STUCK_RADIUS:
			if not _stuck_said:
				_stuck_said = true
				write("ТУПИК? Цель «%s» не меняется %.1f мин, игрок топчется в радиусе %.0f м" % [_goal, _goal_t / 60.0, spread])
			if _hint_cd <= 0.0 and Game.hud != null:
				_hint_cd = HINT_COOLDOWN
				Game.hud.subtitle(Loc.t(&"th.stuck"), 5.0)
