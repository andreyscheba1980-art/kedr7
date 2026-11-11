class_name YrkaRadioInterceptor
extends Node
## Кольцевой буфер и перехватчик радиосвязи Сущности для кооператива «Две вахты».
## Записывает реальные фрагменты речи игроков (или пакеты стандартных фраз),
## и при входе напарника в зону геомагнитной тени (Штольня №4, мачта, воронка)
## подменяет эфир искаженным голосом друга («выключи прожектор...»).

var _capture_effect: AudioEffectCapture
var _recorded_snippets: Array[PackedVector2Array] = []
var _current_recording: PackedVector2Array = PackedVector2Array()
var is_recording_ptt: bool = false
var _spoof_cooldown := 45.0


func _ready() -> void:
	name = "YrkaRadioInterceptor"
	var bus_idx: int = AudioServer.get_bus_index("PlayerMicInput")
	if bus_idx != -1 and AudioServer.get_bus_effect_count(bus_idx) > 0:
		_capture_effect = AudioServer.get_bus_effect(bus_idx, 0) as AudioEffectCapture


func _process(delta: float) -> void:
	_spoof_cooldown -= delta
	if is_recording_ptt and _capture_effect != null:
		var frames: int = _capture_effect.get_frames_available()
		if frames > 0:
			_current_recording.append_array(_capture_effect.get_buffer(frames))


func start_ptt() -> void:
	is_recording_ptt = true
	_current_recording.clear()


func stop_ptt_and_save_clip() -> void:
	is_recording_ptt = false
	# Сохраняем реплики длительностью от 1.5 до 6 секунд (при 44.1/48 кГц)
	if _current_recording.size() > 32000 and _current_recording.size() < 280000:
		if _recorded_snippets.size() >= 8:
			_recorded_snippets.pop_front()
		_recorded_snippets.append(_current_recording.duplicate())
	_current_recording.clear()


## Проверка, находится ли напарник на улице в зоне сильной экранировки/тени
static func is_partner_in_radio_shadow(partner_pos: Vector3) -> bool:
	# Штольня №4 (подземный горизонт или устье в овраге)
	if partner_pos.y < -15.0 or (partner_pos.distance_to(Vector3(48.0, 0.0, -48.0)) < 12.0 and Game.night >= 3):
		return true
	# Аномальная геомагнитная зона у мачты при буране
	if partner_pos.distance_to(Vector3(1.2, 0.0, -14.0)) < 6.0 and Game.antenna_iced:
		return true
	return false


## Воспроизведение фальшивого перехваченного вызова Ырки
func trigger_spoofed_call_to_operator() -> void:
	if _spoof_cooldown > 0.0 or Game.radio == null:
		return
	_spoof_cooldown = 90.0

	# Текст или синтезированная реплика подмены
	var lines := [
		Loc.t(&"coop.spoof_light"),
		Loc.t(&"coop.spoof_door"),
		Loc.t(&"coop.spoof_behind")
	]
	var spoof_text: String = lines.pick_random()

	# Искажение голоса через рацию «Ангара-РА»
	Game.audio.play_3d("res://assets/audio/radio_anomaly.ogg", Game.radio.global_position, 1.0, 8.0)
	Game.hud.subtitle(spoof_text, 6.0)
	Director.add_tension(15.0, "перехват голоса напарника Ыркой")
