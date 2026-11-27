class_name Signal0310
extends Node
## Сигнал 03:10 — хребет игры. Каждую ночь в 03:10 из-под земли бьёт удар, который пишут все приборы
## округи: свет проседает, барограф чиркает до края, в рации — треск, «Слухач» слышит удар снизу.
## Отсюда и правило «после трёх в эфир не выходить»: в 03:10 эфир чужой.
## Кто в наушниках «Слухача» в момент удара — снимает пеленг прямо из дома (FieldJobs, сайт «station»).
## Источник — капище с ящиком «ОТЗВУК-2» (SourceSite). Пеленги со всей карты сходятся туда.

const STRIKE_MIN := 430          ## 03:10
const HINT_MIN := 415            ## 02:55 — напомнить про «Слухача», если пеленга из дома ещё нет
const WINDOW_END := 440          ## до 03:20 «Слухач» ещё слышит отголосок и даёт пеленг
const THUD := "res://assets/audio/sub_drop.ogg"
const SCRATCH := "res://assets/sfx/scratch_wall.ogg"
const STATIC := "res://assets/audio/static_loop.ogg"
const RADIO_POS := Vector3(9.2, 1.0, -1.4)

static var surge_level := 0.0

var _fired := false


func _ready() -> void:
	name = "Signal0310"
	surge_level = 0.0
	if Game.resumed and Game.shift_minutes > STRIKE_MIN:
		_fired = true
	EventBus.clock_minute.connect(_on_minute)


func _exit_tree() -> void:
	surge_level = 0.0


static func _night_ok() -> bool:
	return Game.is_night() and not Game.is_prologue()


## Идёт удар или его отголосок: «Слухач» показывает направление на источник.
static func ringing() -> bool:
	return _night_ok() and Game.shift_minutes >= STRIKE_MIN and Game.shift_minutes <= WINDOW_END


## Направление на источник из дома, градусы по часовой от севера.
static func bearing_deg() -> int:
	return int(fposmod(rad_to_deg(FieldJobs.bearing_angle("station")), 360.0))


func _on_minute(m: int) -> void:
	if not _night_ok() or Game.dead or Game.shift_over:
		return
	if m == HINT_MIN and Game.night >= 2 and not FieldJobs.has_bearing("station"):
		Hints.show(&"sig0310")
	if m >= STRIKE_MIN and not _fired:
		_fired = true
		_strike()


func _process(_delta: float) -> void:
	if _night_ok() and not Game.dead and not Game.shift_over:
		# Плавный аномальный всполох окна 03:10 (427..435 мин смены)
		var m: float = Game.shift_minutes
		if m >= 427.0 and m <= 436.0:
			var peak_dist := absf(m - float(STRIKE_MIN)) / 4.5
			surge_level = clampf(1.0 - peak_dist, 0.0, 1.0)
		else:
			surge_level = move_toward(surge_level, 0.0, _delta * 0.4)
	else:
		surge_level = 0.0
	# Пеленг: наушники надеты, пока удар ещё звенит в мерзлоте
	if _fired and Game.sv20_active and ringing() and not FieldJobs.has_bearing("station"):
		FieldJobs.record_bearing("station")
		SaveGame.write()


func _strike() -> void:
	Game.set_flag("sig0310_seen", true)
	Director.add_tension(12.0 if Game.night == 1 else 7.0, "сигнал 03:10")
	AudioDirector.play_raw(THUD, -1.0)
	Game.vibrate(0.5, 0.7, 0.6)
	if Game.player != null:
		Game.player.shake(0.03, 0.8)
	if Game.audio != null:
		Game.audio.play_3d(STATIC, RADIO_POS, -6.0, 4.0, 2.6)
	if Game.barograph_live():
		AudioDirector.play_raw(SCRATCH, -4.0 if Game.is_home() else -14.0)
	if Game.power_on and Game.level != null and Game.is_home():
		Game.level.flicker(1.2)
	if Game.hud == null or Game.final_call:
		return
	var key := &"sig.n1" if Game.night == 1 else (&"sig.home" if Game.is_home() else &"sig.out")
	if Game.sv20_active:
		return   # в наушниках — пеленг скажет сам
	Game.hud.subtitle(Loc.t(key), 6.0)
