class_name TapeDeckUI
extends Control
## Магнитофон «Репортёр-7» / «Весна»: катушки с лентой Семёнова, перехваты,
## ручная перемотка, изменение скорости, реверс со скрытым слоем и спектрограмма.

signal closed

const SPECTRO_SHADER := "res://assets/shaders/spectrogram.gdshader"
const HISS := "res://assets/audio/tape_hiss.ogg"
const SCREAM := "res://assets/audio/scream.ogg"
const REWIND_SFX_1 := "res://assets/sfx/tape_rewind.ogg"
const REWIND_SFX_2 := "res://assets/sfx/tape_rewind_v2.ogg"
const F_TOP := 4000.0
const REVEAL_AT := 0.9
const REVEAL_HOLD := 1.0

var _list: ItemList
var _info: Label
var _clean_btn: Button
var _speed_btn: Button
var _rev_btn: Button
var _spectro_box: Control
var _spectro: ColorRect
var _hidden_img: TextureRect
var _low: HSlider
var _high: HSlider
var _clarity_label: Label
var _hidden_label: Label
var _low_line: ColorRect
var _high_line: ColorRect
var _ids: Array[StringName] = []
var _selected: StringName = &""
var _tape_player: AudioStreamPlayer
var _hiss_player: AudioStreamPlayer
var _rev_whisper_player: AudioStreamPlayer
var _line_t := 0.0
var _line_i := 0
var _cleaning := false
var _hold := 0.0

var _speed_idx := 0
const SPEEDS := [1.0, 0.5]
const SPEED_NAMES := ["19.05 см/с", "9.53 см/с"]
var _reversed := false
var _tape_pos := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	UiKit.place(self, dim, 0, 0, 1, 1, 0, 0, 0, 0)

	var panel := UiKit.panel()
	UiKit.place(self, panel, 0.5, 0.5, 0.5, 0.5, -590, -340, 590, 340)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(cols)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 460
	left.size_flags_horizontal = Control.SIZE_FILL
	cols.add_child(left)
	var title := UiStyle.brass_plate(Loc.p("МАГНИТОФОН «МАЯК-205» · КАТУШКИ СЕМЁНОВА", "TAPE DECK 'MAYAK-205' · SEMENOV REELS"), 16)
	title.size_flags_horizontal = Control.SIZE_FILL
	left.add_child(title)

	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_selected)
	left.add_child(_list)

	_info = UiKit.label("", 13)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size.y = 56
	left.add_child(_info)

	var row_ctl := HBoxContainer.new()
	row_ctl.add_theme_constant_override("separation", 8)
	left.add_child(row_ctl)

	row_ctl.add_child(UiKit.button(Loc.t(&"tape.play"), _play))
	row_ctl.add_child(UiKit.button(Loc.t(&"tape.stop"), _stop))

	_clean_btn = UiKit.button(Loc.t(&"tape.clean"), _toggle_clean)
	row_ctl.add_child(_clean_btn)

	_speed_btn = UiKit.button(Loc.p("СКОРОСТЬ: " + SPEED_NAMES[_speed_idx], "SPEED: " + SPEED_NAMES[_speed_idx]), _cycle_speed)
	row_ctl.add_child(_speed_btn)

	var row_ctl2 := HBoxContainer.new()
	row_ctl2.add_theme_constant_override("separation", 8)
	left.add_child(row_ctl2)

	_rev_btn = UiKit.button(Loc.p("ДОРОЖКИ: 1-4", "TRACKS: 1-4"), _toggle_reverse)
	row_ctl2.add_child(_rev_btn)

	var rw_back := UiKit.button("<< [Q]", func() -> void: _rewind(-5.0))
	row_ctl2.add_child(rw_back)

	var rw_fwd := UiKit.button("[E] >>", func() -> void: _rewind(5.0))
	row_ctl2.add_child(rw_fwd)

	var hint_lbl := UiKit.label(Loc.t(&"tape.rewind_hint"), 11)
	hint_lbl.modulate = Color(0.7, 0.7, 0.7)
	left.add_child(hint_lbl)

	left.add_child(UiKit.button(Loc.t(&"ui.close"), _close))

	_spectro_box = VBoxContainer.new()
	_spectro_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spectro_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(_spectro_box)
	_build_spectro()

	_tape_player = _make_player()
	_hiss_player = _make_player()
	_hiss_player.stream = AudioDirector.cached_stream(HISS)
	_hiss_player.volume_db = -12.0

	_rev_whisper_player = _make_player()
	_rev_whisper_player.stream = AudioDirector.cached_stream("res://assets/sfx/whisper_many.ogg")
	_rev_whisper_player.volume_db = -10.0

	# 1. Пленки Семёнова (по мере прогресса ночей)
	var max_sem := clampi(Game.night, 1, 6)
	for s_idx in range(1, max_sem + 1):
		var sid := StringName("sem_log_" + str(s_idx))
		_ids.append(sid)
		_list.add_item(Loc.t(StringName("tape." + String(sid))))

	# 2. Перехваты и кассеты из сейфа/архива
	for id: StringName in SaveGame.tapes:
		if not _ids.has(id):
			_ids.append(id)
			_list.add_item(Efir.tape_name(id))

	if _ids.is_empty():
		_info.text = Loc.t(&"tape.empty")
	else:
		_list.select(0)
		_list.grab_focus.call_deferred()
		_on_selected(0)
	_set_filters(0.0, F_TOP)


func _process(delta: float) -> void:
	if _tape_player.playing:
		_tape_pos += delta * SPEEDS[_speed_idx]
		_line_t -= delta
		if _line_t <= 0.0:
			_line_t = 3.4
			_show_line()

	if not _cleaning or _selected == &"":
		return

	var hidden := _hidden_def()
	var lo := _low.value
	var hi := _high.value
	_set_filters(lo, hi)
	var mat := _spectro.material as ShaderMaterial
	mat.set_shader_parameter(&"low_cut", lo / F_TOP)
	mat.set_shader_parameter(&"high_cut", hi / F_TOP)
	_place_line(_low_line, lo)
	_place_line(_high_line, hi)
	var clarity := 0.0
	if not hidden.is_empty():
		var band: Vector2 = hidden["band"]
		var err := (absf(lo - band.x) + absf(hi - band.y)) / 1400.0
		clarity = pow(clampf(1.0 - err, 0.0, 1.0), 2.0)
	mat.set_shader_parameter(&"clarity", clarity)
	_hidden_img.modulate.a = clarity
	_hiss_player.volume_db = lerpf(-12.0, -32.0, clarity)
	_clarity_label.text = Loc.t(&"tape.clarity", [int(clarity * 100.0)])
	if clarity >= REVEAL_AT and not _revealed():
		_hold += delta
		if _hold >= REVEAL_HOLD:
			_reveal(hidden)
	else:
		_hold = 0.0


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"drop") or event.is_action_pressed(&"ui_cancel"):
		_close()
	elif event.is_action_pressed(&"sprint"): # LB / Shift: перемотка назад
		_rewind(-5.0)
	elif event.is_action_pressed(&"hold_breath"): # RB: перемотка вперед
		_rewind(5.0)
	elif event.is_action_pressed(&"crank"): # X: переключение скорости
		_cycle_speed()
	elif event.is_action_pressed(&"flashlight"): # Y: переключение реверса
		_toggle_reverse()
	elif event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_rewind(-3.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_rewind(3.0)
	elif event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_Q:
			_rewind(-5.0)
		elif event.keycode == KEY_E:
			_rewind(5.0)


# --- Управление воспроизведением и реверсом -----------------------------------

func _cycle_speed() -> void:
	_speed_idx = (_speed_idx + 1) % SPEEDS.size()
	_speed_btn.text = Loc.t(&"tape.speed", [SPEED_NAMES[_speed_idx]])
	_tape_player.pitch_scale = SPEEDS[_speed_idx]
	_check_secret_reveals()


func _toggle_reverse() -> void:
	_reversed = not _reversed
	_rev_btn.text = Loc.p("ДОРОЖКИ: 2-3 [ШЁПОТ]" if _reversed else "ДОРОЖКИ: 1-4 [ОСНОВНАЯ]", "TRACKS: 2-3 [WHISPER]" if _reversed else "TRACKS: 1-4 [MAIN]")
	_rev_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3) if _reversed else Color(0.9, 0.9, 0.9))

	if _reversed:
		Director.add_tension(6.0, "магнитофон: переключено на дорожки 2-3")
		_rev_whisper_player.play()
		# Показ скрытого послания на дорожках 2-3 для пленок Семёнова
		if String(_selected).begins_with("sem_log_"):
			var num := String(_selected).replace("sem_log_", "")
			var rev_key := StringName("tape.rev_sub_" + num)
			_info.text = Loc.t(rev_key)
			Game.hud.subtitle(Loc.t(rev_key), 4.5)
		_check_secret_reveals()
	else:
		_rev_whisper_player.stop()
		_on_selected(_list.get_selected_items()[0] if _list.is_anything_selected() else 0)


func _check_secret_reveals() -> void:
	if _selected == &"sem_log_2" and _reversed and not Game.countersign_known:
		Game.countersign_known = true
		Director.add_tension(-6.0, "узнан отзыв «Бирюса»")
		Game.hud.subtitle(Loc.t(&"tape.countersign_revealed"), 5.0)
	elif _selected == &"sem_log_3" and _reversed and SPEEDS[_speed_idx] == 0.5:
		if not Game.countersign_known:
			Game.countersign_known = true
		if not Game.safe_code_known:
			Game.safe_code_known = true
			Director.add_tension(-8.0, "распознан секрет 9-й скорости: шифр сейфа и фонетическая ловушка «Бирюса / Бирюза»")
			Game.hud.subtitle(Loc.p("Секрет 9-й скорости: на замедлении щебет стал шёпотом Семёнова! Код двери U (••—) и шифр сейфа раскрыты.", "9th speed secret: bird chirping slowed into Semenov's whisper! Door code U and safe cipher revealed."), 6.5)


func _rewind(sec_offset: float) -> void:
	var sfx := REWIND_SFX_1 if sec_offset < 0.0 else REWIND_SFX_2
	AudioDirector.play_raw(sfx, -8.0)
	if _tape_player.playing:
		var cur_pos := _tape_player.get_playback_position()
		var new_pos := maxf(cur_pos + sec_offset, 0.0)
		_tape_player.seek(new_pos)
	_tape_pos = maxf(_tape_pos + sec_offset, 0.0)


func _on_selected(index: int) -> void:
	_stop()
	_selected = _ids[index]
	var rw := Voice.sfx(&"tape_rewind")
	if rw != "":
		AudioDirector.play_raw(rw, -8.0)
	var has := Signals.has_hidden(_selected)
	_clean_btn.disabled = not has
	_info.text = Loc.t(&"tape.info_hidden") if has and not _revealed() else Loc.t(&"tape.info")
	if _revealed():
		_info.text = Loc.t(_hidden_def().get("text", &"tape.info"))
	elif _reversed and String(_selected).begins_with("sem_log_"):
		var num := String(_selected).replace("sem_log_", "")
		var rev_key := StringName("tape.rev_sub_" + num)
		_info.text = Loc.t(rev_key)
	_set_cleaning(false)
	_check_secret_reveals()


func _play() -> void:
	if _selected == &"":
		return

	if String(_selected).begins_with("sem_log_"):
		var vpath := Voice.path(_selected)
		if vpath != "":
			_tape_player.stream = AudioDirector.cached_stream(vpath)
		else:
			_tape_player.stream = NumbersVoice.stream_or_default(_selected)
	else:
		_tape_player.stream = NumbersVoice.stream_or_default(_selected)

	_tape_player.pitch_scale = SPEEDS[_speed_idx]
	_tape_player.play(_tape_pos)
	_hiss_player.play()
	_line_t = 0.0
	_line_i = 0

	if _reversed:
		_rev_whisper_player.play()
	_check_secret_reveals()


func _stop() -> void:
	if _tape_player != null:
		_tape_pos = _tape_player.get_playback_position() if _tape_player.playing else _tape_pos
		_tape_player.stop()
		_hiss_player.stop()
		_rev_whisper_player.stop()


func _toggle_clean() -> void:
	_set_cleaning(not _cleaning)
	if _cleaning and not _tape_player.playing:
		_play()


func _set_cleaning(on: bool) -> void:
	_cleaning = on and _selected != &"" and Signals.has_hidden(_selected)
	_spectro_box.modulate.a = 1.0 if _cleaning else 0.35
	_low.editable = _cleaning
	_high.editable = _cleaning
	_hold = 0.0
	if _cleaning:
		var hidden := _hidden_def()
		var img_path: String = hidden.get("image", "")
		_hidden_img.texture = load(img_path) if img_path != "" else null
		_hidden_label.text = ""
		_low.value = 0.0
		_high.value = F_TOP
	else:
		_hidden_img.modulate.a = 0.0
		_set_filters(0.0, F_TOP)


func _reveal(hidden: Dictionary) -> void:
	Game.mark_decoded(StringName(String(_selected) + "_clean"))
	var text: StringName = hidden.get("text", &"")
	_hidden_label.text = Loc.t(text) if text != &"" else ""
	_info.text = _hidden_label.text
	Director.add_tension(10.0, "плёнка: проступило скрытое")
	if _selected == &"tape_field" and not Game.has_flag("mine_adit_known"):
		Game.set_flag("mine_adit_known", true)   # Дубов: ходок Горизонта-40 за завалом в устье
		Game.hud.subtitle(Loc.t(&"sub.mine_known"), 6.0)
		SaveGame.write()
	if _selected == &"rec0310":
		FieldJobs.record_bearing("lake")      # распадок на спектрограмме — пеленг от проруби
		SaveGame.write()
	if bool(hidden.get("scare", false)):
		_scare()


func _scare() -> void:
	Game.audio.play_2d(SCREAM, 0.0)
	if Game.player != null:
		Game.player.shake(0.06, 0.5)
	Game.add_fatigue(6.0)
	await Game.hud.flash_face(0.5)


func _close() -> void:
	_stop()
	_set_filters(0.0, F_TOP)
	closed.emit()


func _show_line() -> void:
	var lines: Array = Signals.get_def(_selected).get("lines", [])
	if lines.is_empty():
		return
	var text := Loc.t(lines[_line_i % lines.size()])
	if _selected == &"code":
		text += "  " + " · ".join(Signals.code_groups(Settings.language))
	_info.text = text
	_line_i += 1


func _hidden_def() -> Dictionary:
	var d := Signals.get_def(_selected)
	if not d.has("tape"):
		return {}
	return (d["tape"] as Dictionary).get("hidden", {})


func _revealed() -> bool:
	return SaveGame.decoded.has(StringName(String(_selected) + "_clean"))


func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = &"Tape"
	add_child(p)
	p.finished.connect(_on_player_finished.bind(p))
	return p


func _on_player_finished(p: AudioStreamPlayer) -> void:
	if p == _hiss_player:
		if _tape_player.playing:
			p.play()
	elif _cleaning:
		p.play()
	elif p == _tape_player:
		_tape_pos = 0.0
		_hiss_player.stop()
		_rev_whisper_player.stop()


func _set_filters(lo: float, hi: float) -> void:
	var idx := AudioServer.get_bus_index(&"Tape")
	if idx < 0 or AudioServer.get_bus_effect_count(idx) < 2:
		return
	(AudioServer.get_bus_effect(idx, 0) as AudioEffectHighPassFilter).cutoff_hz = maxf(lo, 20.0)
	(AudioServer.get_bus_effect(idx, 1) as AudioEffectLowPassFilter).cutoff_hz = clampf(hi, lo + 50.0, 20000.0) if hi < F_TOP else 20000.0


func _build_spectro() -> void:
	var cap := UiKit.label(Loc.t(&"tape.spectro"), 13)
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.modulate = Color(1, 1, 1, 0.7)
	_spectro_box.add_child(cap)
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(480, 340)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.clip_contents = true
	_spectro_box.add_child(frame)
	_spectro = ColorRect.new()
	var mat := ShaderMaterial.new()
	mat.shader = load(SPECTRO_SHADER)
	_spectro.material = mat
	UiKit.place(frame, _spectro, 0, 0, 1, 1, 0, 0, 0, 0)
	_hidden_img = TextureRect.new()
	_hidden_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hidden_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hidden_img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hidden_img.self_modulate = Color(0.55, 1.0, 0.65)
	_hidden_img.modulate.a = 0.0
	UiKit.place(frame, _hidden_img, 0, 0, 1, 1, 40, 20, -40, -20)
	_low_line = _line(frame, Color(1.0, 0.5, 0.3, 0.8))
	_high_line = _line(frame, Color(0.4, 0.7, 1.0, 0.8))

	_low = _slider(Loc.t(&"tape.low"))
	_high = _slider(Loc.t(&"tape.high"))
	_high.value = F_TOP
	_clarity_label = UiKit.label("", 16)
	_spectro_box.add_child(_clarity_label)
	_hidden_label = UiKit.label("", 18)
	_hidden_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.65))
	_hidden_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_spectro_box.add_child(_hidden_label)
	_spectro_box.modulate.a = 0.35


func _slider(caption: String) -> HSlider:
	var row := HBoxContainer.new()
	_spectro_box.add_child(row)
	var l := UiKit.label(caption, 14)
	l.custom_minimum_size.x = 180
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = F_TOP
	s.step = 10.0
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.editable = false
	row.add_child(s)
	return s


func _line(parent: Control, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(parent, r, 0, 0, 1, 0, 0, 0, 0, 2)
	return r


func _place_line(r: ColorRect, hz: float) -> void:
	var h := (r.get_parent() as Control).size.y
	var y := h * (1.0 - hz / F_TOP)
	r.offset_top = y - 1.0
	r.offset_bottom = y + 1.0
