class_name Hud
extends CanvasLayer
## Интерфейс поверх мира (в полном разрешении, мир — в низком): подсказки, часы, субтитры,
## панель рации, записки, модальные окна (карта, магнитофон, шифроблокнот), затемнения и вспышки.

const FACE_TEX := "res://assets/textures/face_flash.png"
const FROST_TEX := "res://assets/textures/frost_vignette.png"
const CovenantsClass = preload("res://scripts/data/covenants.gd")
const SpeechChatter = preload("res://scripts/data/speech_chatter.gd")

var root: Control
var _crosshair: _Crosshair
var _prompt_box: HBoxContainer
var _prompt_key: Label
var _prompt: Label
var _prompt_raw := ""
var _prompt_alpha := 0.0
var _hold_ring: _HoldRing
var _hold_was_full := false
var _clock: Label
var _fps: Label
var _objective: Label
var _subtitle: Label
var _radio_panel: PanelContainer
var _radio_face: _RadioFaceplate
var _radio_hint: Label
var _radio_prev_locked: StringName = &""
var _note_backdrop: Control
var _note_panel: PanelContainer
var _note_label: Label
var _debug_panel: PanelContainer
var _tension_bar: ProgressBar
var _debug_label: Label
var _black: ColorRect
var _red: ColorRect
var _face: TextureRect
var _screen: ColorRect
var _screen_card: PanelContainer
var _screen_meta: Label
var _screen_label: Label
var _screen_tip: Label
var _screen_tween: Tween
var _frost: TextureRect
var _dark_vignette: TextureRect
var _breath_vignette: TextureRect
var _held_label: Label
var _flash_gauge: _DynamoGauge
var _flash_show := 0.0
var _tasks_panel: PanelContainer
var _tasks_label: Label
var _tasks_tab := 0
var _tasks_container: Control
var _covenants_container: Control
var _cov_vbox: VBoxContainer
var _tab_btn_notes: Button
var _notes_container: ScrollContainer
var _notes_vbox: VBoxContainer
var _tab_btn_tasks: Button
var _tab_btn_cov: Button
var _sub_token := 0
var _sub_tween: Tween
var _sub_priority := 0
var _sub_until := 0
var _modal: Control
var cinematic := false            ## холодный старт и катсцены: без часов, задачи, фонаря
var _fps_timer := 0.0
var _frost_wipe_timer := 0.0


func _ready() -> void:
	layer = 10
	Game.hud = self
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.theme()
	add_child(root)

	_frost = TextureRect.new()
	_frost.texture = load(FROST_TEX)
	_frost.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # тонкие кристаллы, а не крупные пиксели
	_frost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frost.stretch_mode = TextureRect.STRETCH_SCALE
	_frost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frost.modulate.a = 0.0
	_place(_frost, 0, 0, 1, 1, 0, 0, 0, 0)

	_dark_vignette = TextureRect.new()
	_dark_vignette.texture = _vignette_texture()
	_dark_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dark_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_dark_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dark_vignette.modulate.a = 0.0
	_place(_dark_vignette, 0, 0, 1, 1, 0, 0, 0, 0)

	_clock = UiKit.label("", 18, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(_clock, 1, 0, 1, 0, -360, 16, -20, 44)
	_fps = UiKit.label("", 14, HORIZONTAL_ALIGNMENT_RIGHT)
	_fps.modulate = Color(0.7, 1.0, 0.7, 0.8)
	_place(_fps, 1, 0, 1, 0, -360, 44, -20, 66)
	_objective = UiKit.label("", 16)
	_objective.modulate = Color(1, 1, 1, 0.78)
	_place(_objective, 0, 0, 0, 0, 20, 16, 820, 44)

	_crosshair = _Crosshair.new()
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_crosshair, 0.5, 0.5, 0.5, 0.5, -24, -24, 24, 24)

	_prompt_box = HBoxContainer.new()
	_prompt_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt_box.add_theme_constant_override("separation", 8)
	_prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_box.modulate.a = 0.0
	_place(_prompt_box, 0.5, 0.5, 0.5, 0.5, -420, 26, 420, 70)

	_prompt_key = UiKit.label("", 14, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt_key.add_theme_color_override("font_color", Color("#FFA62B"))
	_prompt_key.add_theme_constant_override("outline_size", 0)
	_prompt_key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ksb := StyleBoxFlat.new()
	ksb.bg_color = Color(0.05, 0.07, 0.075, 0.90)
	ksb.border_color = Color(0.95, 0.65, 0.22, 0.85)
	ksb.set_border_width_all(1)
	ksb.content_margin_left = 7
	ksb.content_margin_right = 7
	ksb.content_margin_top = 2
	ksb.content_margin_bottom = 2
	_prompt_key.add_theme_stylebox_override("normal", ksb)
	_prompt_key.visible = false
	_prompt_box.add_child(_prompt_key)

	_prompt = UiKit.label("", 17, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_prompt_box.add_child(_prompt)

	_hold_ring = _HoldRing.new()
	_hold_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_hold_ring, 0.5, 0.5, 0.5, 0.5, -24, -24, 24, 24)

	_subtitle = UiKit.label("", Settings.subtitle_size, HORIZONTAL_ALIGNMENT_CENTER)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_place(_subtitle, 0.12, 1, 0.88, 1, 0, -190, 0, -80)

	_held_label = UiKit.label("", 15, HORIZONTAL_ALIGNMENT_RIGHT)
	_held_label.modulate = Color(0.92, 0.90, 0.84, 0.78)
	_place(_held_label, 1, 1, 1, 1, -520, -48, -22, -20)

	_build_flash()
	_build_breath()
	_build_radio_panel()
	_build_note()
	_build_tasks()
	_build_debug()

	_red = ColorRect.new()
	_red.color = Color(0.45, 0.0, 0.0, 0.0)
	_red.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_red, 0, 0, 1, 1, 0, 0, 0, 0)

	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.visible = false
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_black, 0, 0, 1, 1, 0, 0, 0, 0)

	_face = TextureRect.new()
	_face.texture = load(FACE_TEX)
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_face.visible = false
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_face, 0, 0, 1, 1, -40, -40, 40, 40)

	# Бланк утреннего отчёта и карточка смены (стиль телетайпа УГМС 1983 вместо пустого чёрного экрана)
	_screen = ColorRect.new()
	_screen.color = Color(0.018, 0.024, 0.026, 1.0)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_screen, 0, 0, 1, 1, 0, 0, 0, 0)

	_screen_card = PanelContainer.new()
	var sc_sb := StyleBoxFlat.new()
	sc_sb.bg_color = Color(0.042, 0.055, 0.058, 0.96)
	sc_sb.border_color = Color(0.38, 0.34, 0.24, 0.72)
	sc_sb.set_border_width_all(1)
	sc_sb.content_margin_left = 36
	sc_sb.content_margin_right = 36
	sc_sb.content_margin_top = 26
	sc_sb.content_margin_bottom = 26
	_screen_card.add_theme_stylebox_override("panel", sc_sb)
	_screen_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_screen, _screen_card, 0.5, 0.5, 0.5, 0.5, -420, -230, 420, 190)

	var sc_box := VBoxContainer.new()
	sc_box.add_theme_constant_override("separation", 12)
	sc_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_card.add_child(sc_box)

	var sc_hdr := UiKit.label(Loc.p("ГОСКОМГИДРОМЕТ СССР · ПОЛЯРНАЯ СТАНЦИЯ «КЕДР-7» · ТЕЛЕТАЙПНАЯ СВОДКА", "USSR HYDROMET · POLAR STATION KEDR-7 · TELETYPE DISPATCH"), 11, HORIZONTAL_ALIGNMENT_CENTER)
	sc_hdr.add_theme_color_override("font_color", Color("#768882"))
	sc_hdr.add_theme_constant_override("outline_size", 0)
	sc_box.add_child(sc_hdr)

	_screen_meta = UiKit.label("", 12, HORIZONTAL_ALIGNMENT_CENTER)
	_screen_meta.add_theme_color_override("font_color", Color("#FFA62B"))
	_screen_meta.add_theme_constant_override("outline_size", 0)
	sc_box.add_child(_screen_meta)

	var sc_rule := ColorRect.new()
	sc_rule.color = Color(0.45, 0.38, 0.25, 0.45)
	sc_rule.custom_minimum_size = Vector2(0, 1)
	sc_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc_box.add_child(sc_rule)

	_screen_label = UiKit.label("", 19, HORIZONTAL_ALIGNMENT_CENTER)
	_screen_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_screen_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_screen_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_screen_label.add_theme_color_override("font_color", Color("#E4E2D5"))
	_screen_label.add_theme_constant_override("outline_size", 0)
	sc_box.add_child(_screen_label)

	# Совет дежурному на бланке — внизу, деликатно
	_screen_tip = UiKit.label("", 13, HORIZONTAL_ALIGNMENT_CENTER)
	_screen_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_screen_tip.modulate = Color(0.76, 0.74, 0.66, 0.78)
	_screen_tip.add_theme_constant_override("outline_size", 0)
	UiKit.place(_screen, _screen_tip, 0.14, 1, 0.86, 1, 0, -96, 0, -34)
	_screen.visible = false


func _process(delta: float) -> void:
	if not is_inside_tree() or Game == null or _clock == null or _held_label == null:
		return
	var phase := Loc.t(&"hud.night", [Game.night]) if Game.is_night() else (Loc.t(&"hud.day", [Game.phase_index]) if not Game.is_prologue() else (Loc.t(&"hud.morning") if Game.has_flag("prologue_arrived") else Loc.t(&"hud.prologue")))
	_clock.text = "%s   %s" % [phase, Game.clock_text()] if not Flashback.active else Loc.t(&"fb.clock")
	var show_fps_flag: bool = (Settings != null and is_instance_valid(Settings) and Settings.show_fps) or (_debug_panel != null and _debug_panel.visible)
	if _fps != null:
		_fps.visible = show_fps_flag
		if show_fps_flag:
			_fps_timer -= delta
			if _fps_timer <= 0.0:
				_fps_timer = 0.25
				_fps.text = "FPS %d" % Engine.get_frames_per_second()
	_clock.visible = (not cinematic and _modal == null) or Flashback.active
	# Книга в руках закрывает центр: субтитр торчал из-за листа по краям — пока читаешь, он ждёт
	if _subtitle != null:
		var m := modal()
		_subtitle.self_modulate.a = 0.0 if m is HeldPaper and (m as HeldPaper).inner is BookUI else 1.0
	if _flash_gauge != null:
		_flash_gauge.visible = not cinematic and _modal == null
	if _crosshair != null:
		var hide_reticle := cinematic or _modal != null or (_radio_panel != null and _radio_panel.visible)
		_crosshair.visible = not hide_reticle
		if not hide_reticle:
			var target_focus := 1.0 if _prompt_raw != "" else 0.0
			_crosshair.focus_w = lerpf(_crosshair.focus_w, target_focus, minf(delta * 14.0, 1.0))
			_crosshair.queue_redraw()
	if _prompt_box != null:
		var want_a := 1.0 if (_prompt_raw != "" and _modal == null and (_radio_panel == null or not _radio_panel.visible)) else 0.0
		_prompt_alpha = lerpf(_prompt_alpha, want_a, minf(delta * 14.0, 1.0))
		_prompt_box.modulate.a = _prompt_alpha
	if _objective != null:
		_objective.visible = not cinematic and _modal == null
		# Сюжетный режим ведёт за руку; на обычной и сложной — только аварии (их нельзя пропустить).
		_objective.text = Game.objective_text() if Game.is_story() or Game.is_prologue() or Game.story_goal != "" or Game.memory_goal != "" else Game.alarm_text()
	if _frost != null:
		if _frost_wipe_timer > 0.0:
			_frost_wipe_timer -= delta
		var frost := clampf((65.0 - Game.warmth) / 55.0, 0.0, 1.0)
		if Game.mirror_covered or _frost_wipe_timer > 0.0:
			frost = 0.0
		# Возле горящей печи в избе иней тает в 3 раза быстрее, давая ощущение согревающего тепла
		var melt_k := 2.0
		if Game.is_indoors() and Game.zone == &"room" and Game.stove_wood > 0.0 and frost < _frost.modulate.a:
			melt_k = 5.5
		_frost.modulate.a = lerpf(_frost.modulate.a, frost * 0.88, minf(delta * melt_k, 1.0))
		if _frost.modulate.a > 0.38 and Game.is_outside() and _frost_wipe_timer <= 0.0:
			if _prompt_raw == "":
				set_prompt(Loc.t(&"hint.wipe_face"))

	if _dark_vignette != null:
		var tension_factor := Director.tension / 100.0 if Game.is_night() else 0.0
		var fatigue_factor := Game.fatigue / 100.0 if Game.is_night() else 0.0
		var vig_target := clampf(tension_factor * 0.55 + fatigue_factor * 0.35, 0.0, 0.82)
		if Game.retinal_dazzle > 0.0:
			vig_target = maxf(vig_target, Game.retinal_dazzle)
		var k_vig := 4.5 if Game.retinal_dazzle > _dark_vignette.modulate.a else 2.0
		_dark_vignette.modulate.a = lerpf(_dark_vignette.modulate.a, vig_target, minf(delta * k_vig, 1.0))
	_update_flash(delta)
	_update_breath(delta)
	if _radio_face != null and _radio_panel != null and _radio_panel.visible:
		_radio_face.step(delta)
	if _held_label != null:
		var held := Game.player.held if Game.player != null else &""
		_held_label.text = "" if held == &"" else Loc.t(StringName("held." + String(held)))
	if _tasks_panel != null and _tasks_panel.visible and _tasks_label != null:
		_tasks_label.text = Game.tasks_text()
	if _debug_panel != null and _debug_panel.visible:
		_update_debug()


# --- Публичное API -----------------------------------------------------------

## Удержание [E]: кольцо у прицела заполняется по часовой (0 — скрыто).
func set_hold(k: float) -> void:
	var ck := clampf(k, 0.0, 1.0)
	if ck >= 0.995 and not _hold_was_full:
		_hold_was_full = true
		UiKit.play_tick(-10.0, 1.25)
	elif ck < 0.1:
		_hold_was_full = false
	if _hold_ring != null:
		_hold_ring.k = ck
		_hold_ring.queue_redraw()


class _Crosshair extends Control:
	var focus_w := 0.0

	func _draw() -> void:
		var c := size * 0.5
		var dot_col := Color(0.92, 0.92, 0.90, 0.38).lerp(Color(1.0, 0.68, 0.22, 0.96), focus_w)
		draw_circle(c, lerpf(1.6, 2.2, focus_w), dot_col)
		if focus_w > 0.03:
			var r := lerpf(11.5, 7.5, focus_w)
			var arm := 3.6
			var bcol := Color(1.0, 0.68, 0.22, focus_w * 0.85)
			for sx: float in [-1.0, 1.0]:
				for sy: float in [-1.0, 1.0]:
					var corner := c + Vector2(sx * r, sy * r)
					draw_line(corner, corner - Vector2(sx * arm, 0.0), bcol, 1.4, true)
					draw_line(corner, corner - Vector2(0.0, sy * arm), bcol, 1.4, true)


class _HoldRing extends Control:
	var k := 0.0

	func _draw() -> void:
		if k <= 0.001:
			return
		var c := size * 0.5
		draw_arc(c, 16.0, 0.0, TAU, 40, Color(0, 0, 0, 0.48), 4.5, true)
		var col := Color(1.0, 0.72, 0.28, 0.96) if k < 0.98 else Color(0.65, 1.0, 0.68, 1.0)
		draw_arc(c, 16.0, -PI * 0.5, -PI * 0.5 + TAU * k, 40, col, 2.8, true)


func set_prompt(text: String) -> void:
	if _modal != null:
		_prompt_raw = ""
		_prompt.text = ""
		if _prompt_key != null:
			_prompt_key.visible = false
		return
	if Game != null and Game.is_gamepad:
		text = _format_gamepad_prompt(text)
	_prompt_raw = text.strip_edges()
	if _prompt_raw.is_empty():
		_prompt.text = ""
		if _prompt_key != null:
			_prompt_key.visible = false
		return
	# Выделяем ведущий токен клавиши ([E], [E держать], (A)) в отдельный советский шильдик
	var badge := ""
	var action_text := _prompt_raw
	if _prompt_raw.begins_with("["):
		var close_i := _prompt_raw.find("]")
		if close_i > 1:
			badge = _prompt_raw.substr(1, close_i - 1)
			action_text = _prompt_raw.substr(close_i + 1).strip_edges()
	elif _prompt_raw.begins_with("("):
		var close_p := _prompt_raw.find(")")
		if close_p > 1:
			badge = _prompt_raw.substr(1, close_p - 1)
			action_text = _prompt_raw.substr(close_p + 1).strip_edges()
	if _prompt_key != null:
		_prompt_key.text = badge
		_prompt_key.visible = not badge.is_empty()
	_prompt.text = action_text


## Подсказка «[E] Взять» на геймпаде — «(A) Взять»: кнопки берём из текущей раскладки (её можно переназначить).
const _PAD_PROMPT := {&"interact": ["E"], &"crank": ["Q"], &"flashlight": ["F"], &"drop": ["G"], &"tasks": ["TAB", "Tab"],
	&"sprint": ["Shift"], &"hold_breath": ["Пробел", "Space"], &"flare": ["V"]}


func _format_gamepad_prompt(text: String) -> String:
	for a: StringName in _PAD_PROMPT:
		var pad := "(%s)" % Game.pad_name(a)
		var keys: Array = (_PAD_PROMPT[a] as Array).duplicate()
		keys.append(OS.get_keycode_string(Game.key_of(a) as Key))   # клавиша могла быть переназначена
		for k: String in keys:
			text = text.replace("[%s]" % k, pad)
	text = text.replace("[ESC]", "(Start)")
	return text


var _last_save_toast_time := 0


## priority: 0 — атмосфера (шёпот, ворон), 1 — обычное, 2 — авария/правило.
static var log_subs := false   ## автотест: печатать каждый субтитр (проверка, что реплики пролога звучат)


func subtitle(text: String, duration := 3.0, priority := 1, custom_color := Color.TRANSPARENT) -> void:
	var now := Time.get_ticks_msec()
	if log_subs:
		print("[sub] ", text.replace("
", " ").left(90))
	if priority < _sub_priority and now < _sub_until:
		return
	_sub_priority = priority
	_sub_until = now + int(duration * 1000.0)
	_sub_token += 1
	var token := _sub_token

	var low := text.to_lower()
	var is_radio := low.contains("3820") or low.contains("угмс") or low.contains("радио") or low.contains("эфир") or low.contains("диспетчер") or low.contains("семенов") or low.contains("семёнов") or text.begins_with("«")
	var is_whisper := low.contains("шёпот") or low.contains("шепот") or low.contains("тайг") or low.contains("выдох") or low.contains("урман") or low.contains("ырк") or low.contains("шаг")

	var col: Color = custom_color
	if col == Color.TRANSPARENT:
		if text.begins_with("(") or text.begins_with("（"):
			col = Color(0.88, 0.85, 0.78, 0.92) # Внутренний голос / осмотр
		elif is_radio:
			col = Color(1.0, 0.82, 0.38, 0.98) # Радиоэфир и архив
		elif is_whisper:
			col = Color(0.68, 0.88, 1.0, 0.98) # Мистический шёпот тайги
		elif priority >= 2:
			col = Color(1.0, 0.45, 0.35, 0.98) # Тревога / авария
		else:
			col = Color(0.96, 0.96, 0.96, 0.96) # Обычная речь

	var display_text := text
	if is_radio and Settings.voice_mode == "zas" and not text.begins_with("•") and not text.begins_with("("):
		display_text = "• ЗАС «ЭЛЬБРУС» 3820 кГц •\n" + text

	_subtitle.text = display_text
	_subtitle.add_theme_color_override("font_color", col)
	if Settings.subtitle_bg:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.042, 0.046, 0.72)
		sb.border_color = Color(0.32, 0.36, 0.34, 0.40)
		sb.set_border_width_all(1)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		_subtitle.add_theme_stylebox_override("normal", sb)
	else:
		_subtitle.remove_theme_stylebox_override("normal")

	if _sub_tween != null and _sub_tween.is_valid():
		_sub_tween.kill()

	# Телетайпная дешифрация (машинопись текста) ТОЛЬКО для радиоэфира и мистического шёпота
	var total_chars := display_text.length()
	if (is_radio or is_whisper) and total_chars > 4 and OS.get_name() != "headless":
		_subtitle.visible_characters = 0
		var type_speed := 36.0
		var type_dur := clampf(float(total_chars) / type_speed, 0.35, minf(duration * 0.75, 4.0))
		_sub_tween = create_tween()
		_sub_tween.tween_property(_subtitle, "visible_characters", total_chars, type_dur)
		var speaker := SpeechChatter.detect_speaker(display_text)
		SpeechChatter.play_line_chatter(self, speaker, display_text, type_dur, token)
	else:
		_subtitle.visible_characters = -1

	await get_tree().create_timer(duration, false).timeout
	if token == _sub_token:
		if _sub_tween != null and _sub_tween.is_valid():
			_sub_tween.kill()
		_subtitle.text = ""
		_subtitle.visible_characters = -1
		_subtitle.remove_theme_stylebox_override("normal")
		_sub_priority = 0


## Смахнуть налипший снег и иней с лица/очков шерстяной варежкой
func wipe_face_frost() -> void:
	if _frost == null or _frost.modulate.a <= 0.08:
		return
	_frost_wipe_timer = 25.0
	_frost.modulate.a = 0.0
	if Game.player != null:
		Game.player.shake(0.018, 0.22)
	AudioDirector.play_raw(InstrumentView.WIPE_SFX, -12.0)
	AudioDirector.play_raw("res://assets/audio/whisper.ogg", -16.0)
	subtitle(Loc.t(&"sub.wipe_face"), 2.6, 1)


## Ненавязчивая советская пиктограмма сохранения смены
func show_save_toast() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_save_toast_time < 3500:
		return
	_last_save_toast_time = now
	var l := UiKit.label("●  " + Loc.t(&"hud.save_toast"), 13, HORIZONTAL_ALIGNMENT_RIGHT)
	l.add_theme_color_override("font_color", Color(1.0, 0.42, 0.35))
	l.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_place(l, 1, 1, 1, 1, -340, -42, -24, -18)
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 0.95, 0.25)
	tw.tween_interval(2.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.7)
	tw.tween_callback(l.queue_free)


## Получено достижение: плашка справа сверху — бумажная бирка с названием.
func achievement_toast(title: String) -> void:
	var p := UiKit.panel(Color(0.86, 0.82, 0.7, 0.95))
	var v := VBoxContainer.new()
	p.add_child(v)
	var head := UiKit.ink(UiKit.label(Loc.t(&"ach.toast"), 12))
	head.add_theme_color_override("font_color", Color(0.55, 0.12, 0.08))
	v.add_child(head)
	v.add_child(UiKit.ink(UiKit.label(title, 16)))
	p.modulate.a = 0.0
	_place(p, 1, 0, 1, 0, -360, 120, -24, 190)
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.3)
	tw.tween_interval(3.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.8)
	tw.tween_callback(p.queue_free)
	Game.audio.play_2d("res://assets/audio/ui_tick.ogg", -6.0)


func show_radio(on: bool) -> void:
	_radio_panel.visible = on
	if _prompt_box != null:
		_prompt_box.visible = not on
	if not on:
		_radio_prev_locked = &""


func update_radio(freq: float, strength: float, locked_id: StringName, record_text: String, record_progress: float, fine_tune := 0.0, vario_res := 0.85, magic_eye := 0.0, magic_overload := false) -> void:
	if locked_id != &"" and locked_id != _radio_prev_locked:
		UiKit.play_tick(-9.0, 0.88)   # короткий щелчок реле при захвате несущей
	_radio_prev_locked = locked_id
	if _radio_face != null:
		var lock_str := ""
		if locked_id != &"":
			if String(locked_id).begins_with("bc_belov_"):
				lock_str = Loc.t(&"sig.belov.title") + " · " + Loc.t(&"radio.locked")
			else:
				lock_str = Loc.t(&"radio.locked")
		_radio_face.set_telemetry(freq, strength, lock_str, record_text, record_progress, fine_tune, vario_res, magic_eye, magic_overload)


## Подсказка дежурному: карточка под строкой задачи, сама гаснет (Hints решает, когда и какую).
func hint(text: String, duration := 8.0) -> void:
	var card := UiKit.panel(Color(0.05, 0.07, 0.1, 0.82))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiKit.label(text, 16)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(560, 0)
	l.modulate = Color(0.93, 0.88, 0.74)
	card.add_child(l)
	_place(card, 0, 0, 0, 0, 20, 56, 640, 56)
	card.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.35)
	tw.tween_interval(duration)
	tw.tween_property(card, "modulate:a", 0.0, 0.9)
	tw.tween_callback(card.queue_free)


## Короткая надпись в углу (сохранение и т.п.).
func toast(text: String, duration := 2.5) -> void:
	var l := UiKit.label(text, 14, HORIZONTAL_ALIGNMENT_RIGHT)
	l.modulate = Color(0.8, 1.0, 0.8, 0.0)
	_place(l, 1, 1, 1, 1, -420, -84, -20, -60)
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 0.85, 0.3)
	tw.tween_interval(duration)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)


## Записка/документ — крупным листом (DocView), длинное — по страницам.
var _doc: DocView


func show_note(text: String) -> void:
	_remember_note(text)
	if _doc != null and is_instance_valid(_doc):
		_doc.queue_free()
	var low := text.to_lower()
	_doc = DocView.sheet(PackedStringArray([text]), low.contains("секрет") or low.contains("secret"))
	root.add_child(_doc)
	_doc.closed.connect(hide_note)
	_subtitle.visible = false
	if Game.player != null and not Game.dead:
		Game.player.mode = Player.Mode.READING


## Ввод, пока открыт документ: дальше / назад / закрыть.
func note_input(event: InputEvent) -> void:
	if _doc != null and is_instance_valid(_doc):
		_doc.handle_input(event)
	else:
		hide_note()


func _show_note_old(text: String) -> void:
	_note_label.text = text + "\n\n" + Loc.t(&"ui.close_e")
	# Длинные страницы (журнал с дописками) — мельче, пока не влезут в лист: панель растёт под текст,
	# и журнал Семёнова уезжал низом за экран.
	for fs: int in [17, 16, 15, 14, 13, 12, 11]:
		_note_label.add_theme_font_size_override("font_size", fs)
		if _note_label.get_line_count() * _note_label.get_line_height() <= 530:
			break
	_note_panel.offset_top = -290.0     # контейнер мог вырасти под прошлую страницу — вернуть лист
	_note_panel.offset_bottom = 290.0
	_subtitle.visible = false     # иначе субтитр лезет из-под листа обрывками
	if _note_backdrop != null:
		_note_backdrop.visible = true
	_note_panel.visible = true
	if Game.player != null and not Game.dead:
		Game.player.mode = Player.Mode.READING


func hide_note() -> void:
	if _doc != null and is_instance_valid(_doc):
		_doc.queue_free()
	_doc = null
	if _note_backdrop != null:
		_note_backdrop.visible = false
	_note_panel.visible = false
	_subtitle.visible = true
	if Game.player != null and Game.player.mode == Player.Mode.READING and not Game.dead:
		Game.player.mode = Player.Mode.WALK


func is_note_open() -> bool:
	return (_doc != null and is_instance_valid(_doc)) or (_note_panel != null and _note_panel.visible)


func toggle_tasks() -> void:
	_tasks_panel.visible = not _tasks_panel.visible
	if _tasks_panel.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_rebuild_covenants_ui()
		if Game.player != null:
			Game.player.mode = Player.Mode.UI
		if _tab_btn_tasks != null:
			_tab_btn_tasks.grab_focus.call_deferred()
	else:
		if Game.player != null and not Game.dead:
			Game.player.mode = Player.Mode.WALK
		if _modal == null and Game.player != null and Game.player.mode == Player.Mode.WALK:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED



func toggle_debug() -> void:
	_debug_panel.visible = not _debug_panel.visible


## Модальное окно (карта, магнитофон, шифроблокнот). Одно за раз.
func open_modal(c: Control) -> void:
	close_modal()
	_modal = c
	UiKit.place(root, c, 0, 0, 1, 1, 0, 0, 0, 0)
	root.move_child(c, _red.get_index())


func close_modal() -> void:
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null


func modal() -> Control:
	return _modal if _modal != null and is_instance_valid(_modal) else null


func set_black(on: bool) -> void:
	_black.visible = on


## Красная вспышка (удар, смерть). Корутина.
func flash_red(peak := 0.6, time := 0.8) -> void:
	if Settings.reduce_flashes:
		peak *= 0.3
	_red.color.a = peak
	var tw := create_tween()
	tw.tween_property(_red, "color:a", 0.0, time)
	await tw.finished


func blink(duration := 0.1) -> void:
	_black.visible = true
	await get_tree().create_timer(duration, false).timeout
	_black.visible = false


## Лицо на весь экран с дёрганьем. Корутина.
var _last_face := -1

func flash_face(duration: float, tex: Texture2D = null) -> void:
	if tex == null:
		# Случайное лицо, но не то же, что в прошлый раз.
		var n := 9
		var k := randi() % n
		if k == _last_face:
			k = (k + 1) % n
		_last_face = k
		var path := FACE_TEX if k == 0 else "res://assets/textures/face_flash_%d.png" % (k + 1)
		if ResourceLoader.exists(path):
			tex = load(path)
	if tex != null:
		_face.texture = tex
	var t := 0.0
	while t < duration:
		_face.visible = randf() > 0.15
		_face.position = Vector2(randf_range(-30, 0), randf_range(-30, 0))
		_face.modulate = Color(1.0, randf_range(0.6, 1.0), randf_range(0.6, 1.0))
		await get_tree().create_timer(0.04, false).timeout
		t += 0.04
	_face.visible = false


func _format_screen_meta() -> String:
	var n := Game.night if Game != null else 1
	var day_dec := clampi(24 + n, 25, 31)
	var ph := Loc.p("ПОЛЯРНАЯ НОЧЬ", "POLAR NIGHT") if (Game != null and Game.is_night()) else Loc.p("УТРЕННЯЯ СВОДКА", "MORNING DISPATCH")
	return Loc.p("СУТКИ %02d · %d ДЕКАБРЯ 1983 · %s" % [n, day_dec, ph], "SHIFT %02d · DEC %d, 1983 · %s" % [n, day_dec, ph])


func _play_screen_typewriter(text: String) -> void:
	if _screen_tween != null and _screen_tween.is_valid():
		_screen_tween.kill()
	_screen_label.text = text
	if text.length() > 6 and OS.get_name() != "headless":
		_screen_label.visible_characters = 0
		var dur := clampf(float(text.length()) / 52.0, 0.45, 2.2)
		_screen_tween = create_tween()
		_screen_tween.tween_property(_screen_label, "visible_characters", text.length(), dur)
		UiKit.play_tick(-11.0, 1.05)
	else:
		_screen_label.visible_characters = -1


func show_screen(text: String) -> void:
	if _screen_meta != null:
		_screen_meta.text = _format_screen_meta()
	_play_screen_typewriter(text)
	if _screen_tip != null:
		var n := 1
		while Loc.has_key(StringName("tip.%d" % (n + 1))):
			n += 1
		_screen_tip.text = Loc.t(&"tip.head") + "  " + Loc.t(StringName("tip.%d" % (1 + randi() % n)))
	_screen.modulate.a = 1.0
	_screen.visible = true


func fade_in_screen(text: String, time := 1.5) -> void:
	if _screen_meta != null:
		_screen_meta.text = _format_screen_meta()
	_play_screen_typewriter(text)
	if _screen_tip != null:
		_screen_tip.text = ""
	_screen.modulate.a = 0.0
	_screen.visible = true
	var tw := create_tween()
	tw.tween_property(_screen, "modulate:a", 1.0, time)
	await tw.finished


func fade_out_screen(time := 1.5) -> void:
	var tw := create_tween()
	tw.tween_property(_screen, "modulate:a", 0.0, time)
	await tw.finished
	_screen.visible = false


func is_screen_shown() -> bool:
	return _screen != null and _screen.visible


# --- Сборка ------------------------------------------------------------------

## Аналоговый микро-гальванометр заряда динамо-фонаря (заменяет сухой ProgressBar).
func _build_flash() -> void:
	_flash_gauge = _DynamoGauge.new()
	_flash_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_gauge.modulate.a = 0.0
	_place(_flash_gauge, 0, 1, 0, 1, 20, -86, 156, -20)


func _update_flash(delta: float) -> void:
	var p := Game.player
	if p == null or _flash_gauge == null:
		return
	var c := Game.flash_charge
	var want := p.flashlight_on() or p.cranking or c < 99.0
	_flash_show = 1.0 if want else maxf(_flash_show - delta * 0.55, 0.0)
	_flash_gauge.modulate.a = lerpf(_flash_gauge.modulate.a, _flash_show, minf(delta * 6.0, 1.0))
	var yrka_press: bool = Game.yrka != null and Game.yrka.threat >= 45.0 and Game.is_outside()
	_flash_gauge.update_gauge(c, p.flashlight_on(), p.cranking, yrka_press, delta)


## Телесная обратная связь дыхания через мягкую периферийную виньетку и импульс передержки (без полоски).
func _build_breath() -> void:
	_breath_vignette = TextureRect.new()
	_breath_vignette.texture = _vignette_texture()
	_breath_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_breath_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_breath_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_breath_vignette.modulate = Color(0.55, 0.78, 0.96, 0.0)
	_place(_breath_vignette, 0, 0, 1, 1, 0, 0, 0, 0)


func _update_breath(delta: float) -> void:
	var p := Game.player
	if p == null or _breath_vignette == null:
		return
	var b: float = p.breath_stamina
	var target_a := 0.0
	var target_col := Color(0.42, 0.68, 0.90, 1.0)
	if p.holding_breath:
		var strain := clampf((100.0 - b) / 100.0, 0.0, 1.0)
		target_a = 0.22 + strain * 0.48
		if b < 25.0:
			var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.014)
			target_col = Color(0.88, 0.22, 0.16, 1.0)
			target_a = 0.48 + pulse * 0.26
	elif b < 45.0:
		# Одышка после задержки: лёгкое холодное мерцание по краю обзора
		var rec := clampf((45.0 - b) / 45.0, 0.0, 1.0)
		var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.008)
		target_a = rec * (0.18 + 0.14 * pulse)
	var cur := _breath_vignette.modulate
	cur.r = lerpf(cur.r, target_col.r, minf(delta * 6.0, 1.0))
	cur.g = lerpf(cur.g, target_col.g, minf(delta * 6.0, 1.0))
	cur.b = lerpf(cur.b, target_col.b, minf(delta * 6.0, 1.0))
	cur.a = lerpf(cur.a, target_a, minf(delta * (7.0 if p.holding_breath else 3.0), 1.0))
	_breath_vignette.modulate = cur


## Аналоговая приборная лицевая панель «ВОЛНА-К / АНГАРА-РА» с живой лампой 6Е1П, верньером и S-метром.
func _build_radio_panel() -> void:
	_radio_panel = PanelContainer.new()
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(0.038, 0.050, 0.052, 0.95)
	rsb.border_color = Color(0.46, 0.39, 0.27, 0.90)
	rsb.set_border_width_all(2)
	rsb.content_margin_left = 14
	rsb.content_margin_right = 14
	rsb.content_margin_top = 10
	rsb.content_margin_bottom = 8
	rsb.shadow_color = Color(0, 0, 0, 0.65)
	rsb.shadow_size = 12
	_radio_panel.add_theme_stylebox_override("panel", rsb)
	_place(_radio_panel, 0.5, 1, 0.5, 1, -380, -172, 380, -24)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_radio_panel.add_child(box)

	_radio_face = _RadioFaceplate.new()
	_radio_face.custom_minimum_size = Vector2(730.0, 104.0)
	_radio_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_radio_face)

	_radio_hint = UiKit.label(Loc.p("[ЛКМ / Колёсико] Верньер   [Q/E] Тон   [TAB/V] Вариометр УСС   [Пробел/T] ДЭМШ-1А   [E] Выйти", "[LMB / Wheel] Vernier   [Q/E] Tone   [TAB/V] USS Variometer   [Space/T] DEMSH-1A   [E] Exit"), 11, HORIZONTAL_ALIGNMENT_CENTER)
	_radio_hint.modulate = Color(0.76, 0.80, 0.77, 0.68)
	_radio_hint.add_theme_constant_override("outline_size", 0)
	box.add_child(_radio_hint)
	_radio_panel.visible = false


func _build_note() -> void:
	_note_backdrop = Control.new()
	_note_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_note_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_note_backdrop.visible = false
	_note_backdrop.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.is_pressed():
			hide_note()
	)
	root.add_child(_note_backdrop)

	_note_panel = UiKit.panel(UiKit.PAPER)
	_place(_note_panel, 0.5, 0.5, 0.5, 0.5, -360, -290, 360, 290)
	_note_label = UiKit.ink(UiKit.label("", 17))
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_panel.add_child(_note_label)
	_note_panel.visible = false
	_note_panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.is_pressed():
			hide_note()
	)


func _build_tasks() -> void:
	_tasks_panel = UiKit.panel(Color(0.86, 0.82, 0.7, 0.96))
	_place(_tasks_panel, 1, 0, 1, 0, -680, 50, -20, 560)   # три вкладки в ряд: «Задачи», «Заветы», «Записки»
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	_tasks_panel.add_child(main_vbox)

	var tabs_row := HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation", 10)
	main_vbox.add_child(tabs_row)

	_tab_btn_tasks = UiKit.button(Loc.t(&"cov.tab_tasks"), func() -> void: _switch_tasks_tab(0))
	_tab_btn_cov = UiKit.button(Loc.t(&"cov.tab_covenants"), func() -> void: _switch_tasks_tab(1))
	_tab_btn_notes = UiKit.button(Loc.t(&"cov.tab_notes"), func() -> void: _switch_tasks_tab(2))
	tabs_row.add_child(_tab_btn_tasks)
	tabs_row.add_child(_tab_btn_cov)
	tabs_row.add_child(_tab_btn_notes)

	_tasks_container = VBoxContainer.new()
	main_vbox.add_child(_tasks_container)
	_tasks_label = UiKit.ink(UiKit.label("", 15))
	_tasks_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tasks_container.add_child(_tasks_label)

	_covenants_container = ScrollContainer.new()
	_covenants_container.custom_minimum_size = Vector2(640, 440)
	_covenants_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_covenants_container.follow_focus = true
	main_vbox.add_child(_covenants_container)

	_cov_vbox = VBoxContainer.new()
	_cov_vbox.add_theme_constant_override("separation", 12)
	_cov_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_covenants_container.add_child(_cov_vbox)

	_notes_container = ScrollContainer.new()
	_notes_container.custom_minimum_size = Vector2(640, 440)
	_notes_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_notes_container.follow_focus = true
	main_vbox.add_child(_notes_container)
	_notes_vbox = VBoxContainer.new()
	_notes_vbox.add_theme_constant_override("separation", 6)
	_notes_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notes_container.add_child(_notes_vbox)

	_switch_tasks_tab(0)
	_tasks_panel.visible = false


func _switch_tasks_tab(tab: int) -> void:
	_tasks_tab = tab
	if _tasks_container != null:
		_tasks_container.visible = (_tasks_tab == 0)
	if _covenants_container != null:
		_covenants_container.visible = (_tasks_tab == 1)
	if _notes_container != null:
		_notes_container.visible = (_tasks_tab == 2)
	if _tab_btn_notes != null:
		_tab_btn_notes.modulate = Color(1.2, 1.1, 0.8) if _tasks_tab == 2 else Color(0.85, 0.85, 0.85)
	if _tasks_tab == 2:
		_rebuild_notes_ui()
	if _tab_btn_tasks != null:
		_tab_btn_tasks.modulate = Color(1.2, 1.1, 0.8) if _tasks_tab == 0 else Color(0.85, 0.85, 0.85)
	if _tab_btn_cov != null:
		_tab_btn_cov.modulate = Color(1.2, 1.1, 0.8) if _tasks_tab == 1 else Color(0.85, 0.85, 0.85)
	if _tasks_tab == 1:
		_rebuild_covenants_ui()


## Записки, письма, вырезки: всё, что прочитал, — в журнале по порядку; нажал — открылась снова.
func _remember_note(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	var notes: Array = SaveGame.flags.get("notes_read", [])
	if notes.has(text):
		return
	notes.append(text)
	if notes.size() > 80:
		notes.pop_front()
	SaveGame.flags["notes_read"] = notes
	if notes.size() >= 10:
		Achievements.unlock(&"reader")


func _rebuild_notes_ui() -> void:
	if _notes_vbox == null:
		return
	for c in _notes_vbox.get_children():
		c.queue_free()
	var notes: Array = SaveGame.flags.get("notes_read", [])
	if notes.is_empty():
		var e := UiKit.ink(UiKit.label(Loc.t(&"cov.notes_empty"), 14))
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_notes_vbox.add_child(e)
		return
	for i in range(notes.size() - 1, -1, -1):
		var t: String = notes[i]
		var first := t.strip_edges().split("\n", false)
		var title := (first[0] if not first.is_empty() else t).strip_edges()
		if title.length() > 58:
			title = title.substr(0, 56) + "…"
		var b := Button.new()
		b.text = "%d. %s" % [i + 1, title]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.custom_minimum_size = Vector2(620, 30)
		b.pressed.connect(func() -> void:
			toggle_tasks()
			show_note(t))
		_notes_vbox.add_child(b)


func _rebuild_covenants_ui() -> void:
	if _cov_vbox == null:
		return
	for c in _cov_vbox.get_children():
		c.queue_free()

	for entry: Dictionary in CovenantsClass.ENTRIES:
		if not CovenantsClass.visible(entry):
			continue
		var item_box := VBoxContainer.new()
		item_box.add_theme_constant_override("separation", 4)
		_cov_vbox.add_child(item_box)

		var head := CovenantsClass.author(entry)
		if CovenantsClass.is_new(entry):
			head += "   " + Loc.t(&"cov.new_tag")
		var author := UiKit.ink(UiKit.label(head, 13))
		author.add_theme_color_override("font_color", Color(0.42, 0.22, 0.12))
		item_box.add_child(author)

		if CovenantsClass.rewritten(entry):
			# Старый текст — зачёркнут; поверх — чужой, неровный почерк другими чернилами.
			var old := RichTextLabel.new()
			old.bbcode_enabled = true
			old.fit_content = true
			old.scroll_active = false
			old.custom_minimum_size = Vector2(600, 0)
			old.add_theme_color_override("default_color", Color(0.35, 0.3, 0.28, 0.75))
			old.add_theme_font_size_override("normal_font_size", 13)
			old.text = "[s]" + CovenantsClass.original_text(entry) + "[/s]"
			item_box.add_child(old)
		var rule := UiKit.ink(UiKit.label(CovenantsClass.text(entry), 14))
		rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if CovenantsClass.rewritten(entry) or String(entry.get("author", "")).begins_with("Орехов"):
			rule.add_theme_color_override("font_color", Color(0.38, 0.06, 0.05))
		item_box.add_child(rule)
		if CovenantsClass.rewritten(entry):
			var tag := UiKit.ink(UiKit.label(Loc.t(&"cov.edited_tag"), 11))
			tag.add_theme_color_override("font_color", Color(0.38, 0.06, 0.05))
			item_box.add_child(tag)

		var btn_row := HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 6)
		item_box.add_child(btn_row)

		var key := CovenantsClass.eid(entry)
		var cur_state: String = CovenantsClass.get_state(key)
		var states := ["true", "false", "danger"]
		var labels := [Loc.t(&"cov.true"), Loc.t(&"cov.false"), Loc.t(&"cov.danger")]
		for i in range(3):
			var s: String = states[i]
			var lbl: String = labels[i]
			var prefix := "✓ " if cur_state == s else ""
			var b := Button.new()
			b.text = prefix + lbl
			b.custom_minimum_size = Vector2(130, 26)
			b.pressed.connect(func():
				var was := CovenantsClass.get_state(key)
				CovenantsClass.set_state(key, s)
				if entry.id == "night5_delusion" and (s == "false" or s == "danger"):
					subtitle(Loc.t(&"cov.sanity_boost"), 3.5)
					Director.add_tension(-20.0, "морок зачеркнут")
				elif was != s:
					CovenantsClass.on_marked(entry, s)
				_rebuild_covenants_ui()
			)
			btn_row.add_child(b)



func _build_debug() -> void:
	_debug_panel = UiKit.panel(Color(0, 0, 0, 0.72))
	_place(_debug_panel, 0, 0, 0, 0, 16, 56, 720, 560)
	var box := VBoxContainer.new()
	_debug_panel.add_child(box)
	var title := UiKit.label("DIRECTOR · F3 hide · F4 +30 tension · F2 Yrka chase · F6 skip phase", 13)
	title.add_theme_color_override("font_color", UiKit.AMBER)
	box.add_child(title)
	_tension_bar = ProgressBar.new()
	_tension_bar.custom_minimum_size = Vector2(0, 14)
	_tension_bar.show_percentage = false
	box.add_child(_tension_bar)
	_debug_label = UiKit.label("", 13)
	box.add_child(_debug_label)
	_debug_panel.visible = false


func _update_debug() -> void:
	_tension_bar.value = Director.tension
	var ctx := Director.make_context()
	var lines: PackedStringArray = [
		"tension %.1f / peak %.0f   phase %s   cooldown %.0f s" % [Director.tension, Director.peak_threshold, Director.phase_name(), maxf(Director.cooldown_left, 0.0)],
		"ctx: %s   fatigue %.0f" % [ctx.describe(), Game.fatigue],
		"scares: %d   seed: %d   fuel: %.0f%%" % [Director.scares_played, Game.run_seed, Game.generator_fuel],
		"fps %d   frame %.1f ms   draw calls %d   render %dx%d" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(get_viewport().get_visible_rect().size.x) / Settings.render_shrink(), int(get_viewport().get_visible_rect().size.y) / Settings.render_shrink()],
		"STORM clarity: %.2f (int: %.2f)  ATTENTION: %.1f (tier %d)" % [Storm.clarity, Storm.intensity, Attention.value, Attention.tier],
		"warmth %.0f  flash %.0f  stove %.0f  lost_time: %.1f s" % [Game.warmth, Game.flash_charge, Game.stove_wood, float(Game.player.get("nav_sense").lost_time) if Game.player != null and Game.player.get("nav_sense") != null else 0.0],
		"Yrka: %.0f (%+.1f/s) %s" % [Game.yrka.threat, Game.yrka.rate, Game.yrka.stage_name()] if Game.yrka != null else "",
		"",
	]
	lines.append_array(Director.log_lines)
	_debug_label.text = "\n".join(lines)


func _place(c: Control, al: float, at: float, ar: float, ab: float, ol: float, ot: float, o_r: float, ob: float) -> void:
	UiKit.place(root, c, al, at, ar, ab, ol, ot, o_r, ob)


static func _vignette_texture() -> ImageTexture:
	var w := 160
	var h := 90
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var c := Vector2(w * 0.5, h * 0.5)
	for y in range(h):
		for x in range(w):
			var d := Vector2((x - c.x) / (w * 0.5), (y - c.y) / (h * 0.5)).length()
			var a := clampf((d - 0.52) / 0.55, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.0, 0.01, 0.025, a * a))
	return ImageTexture.create_from_image(img)


## Советский микро-гальванометр заряда динамо-фонаря М4200 (векторная отрисовка, gl_compatibility).
class _DynamoGauge extends Control:
	var _val := 100.0
	var _needle := 1.0
	var _on := false
	var _crank := false
	var _jitter := false
	var _t := 0.0

	func update_gauge(charge: float, lit: bool, cranking: bool, yrka_jitter: bool, delta: float) -> void:
		_val = clampf(charge, 0.0, 100.0)
		_on = lit
		_crank = cranking
		_jitter = yrka_jitter or (charge < 25.0 and lit)
		_t += delta
		var target := _val / 100.0
		_needle = lerpf(_needle, target, minf(delta * 9.0, 1.0))
		if modulate.a > 0.01:
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var font := get_theme_default_font()
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.052, 0.055, 0.88), true)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.42, 0.36, 0.25, 0.85), false, 1.5)
		var pivot := Vector2(w * 0.5, h - 10.0)
		var r := 42.0
		var a0 := -PI * 0.84
		var a1 := -PI * 0.16
		var a_red := lerpf(a0, a1, 0.26)
		# Шкала дуги + красный сектор разряда
		draw_arc(pivot, r, a0, a_red, 16, Color(0.85, 0.24, 0.18, 0.90), 3.0, true)
		draw_arc(pivot, r, a_red, a1, 24, Color(0.76, 0.72, 0.60, 0.55), 2.0, true)
		for i in range(9):
			var u := float(i) / 8.0
			var ang := lerpf(a0, a1, u)
			var dir := Vector2(cos(ang), sin(ang))
			var inner := r - (7.0 if i % 2 == 0 else 4.0)
			draw_line(pivot + dir * inner, pivot + dir * r, Color(0.82, 0.78, 0.66, 0.72), 1.2, true)
		# Стрелка с живым дрожанием при давлении Ырки или низком заряде
		var j := sin(_t * 37.0) * 0.055 if _jitter else (sin(_t * 22.0) * 0.02 if _crank else 0.0)
		var na := clampf(lerpf(a0, a1, _needle) + j, a0 - 0.04, a1 + 0.04)
		var ndir := Vector2(cos(na), sin(na))
		var ncol := Color(1.0, 0.32, 0.22, 0.98) if _val <= 25.0 else Color(1.0, 0.68, 0.24, 0.98)
		draw_line(pivot, pivot + ndir * (r - 3.0), ncol, 2.0, true)
		draw_circle(pivot, 3.8, Color(0.45, 0.39, 0.28, 0.95))
		# Подпись прибора и контрольный огонёк накала
		var lbl := Loc.p("ДИНАМО", "DYNAMO")
		draw_string(font, Vector2(8.0, 14.0), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.68, 0.75, 0.72, 0.85))
		var lamp_col := Color(1.0, 0.72, 0.24, 0.95) if _on else Color(0.28, 0.32, 0.30, 0.65)
		if _val <= 25.0 and _on and fmod(_t, 0.5) < 0.25:
			lamp_col = Color(0.95, 0.22, 0.16, 0.95)
		draw_circle(Vector2(w - 11.0, 10.0), 3.0, lamp_col)


## Аналоговая лицевая панель КВ-приёмника «Волна-К / Ангара-РА»:
## слева — живая лампа 6Е1П, в центре — оптический верньер кГц, справа — S-метр и контрольные лампы.
class _RadioFaceplate extends Control:
	var _freq := 3820.0
	var _strength := 0.0
	var _s_needle := 0.0
	var _lock_str := ""
	var _rec_str := ""
	var _rec_prog := -1.0
	var _fine := 0.0
	var _vario := 0.85
	var _eye := 0.0
	var _eye_smooth := 0.0
	var _overload := false
	var _t := 0.0

	func set_telemetry(freq: float, strength: float, lock_str: String, rec_str: String, rec_prog: float, fine_tune: float, vario_res: float, magic_eye: float, magic_overload: bool) -> void:
		_freq = freq
		_strength = clampf(strength, 0.0, 1.0)
		_lock_str = lock_str
		_rec_str = rec_str
		_rec_prog = rec_prog
		_fine = fine_tune
		_vario = clampf(vario_res, 0.0, 1.0)
		_eye = clampf(magic_eye, 0.0, 1.0)
		_overload = magic_overload
		queue_redraw()

	func step(delta: float) -> void:
		_t += delta
		_s_needle = lerpf(_s_needle, _strength, minf(delta * 10.0, 1.0))
		_eye_smooth = lerpf(_eye_smooth, _eye, minf(delta * 12.0, 1.0))
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var font := get_theme_default_font()

		# 1. ЛЕВЫЙ БЛОК: живой электронно-оптический индикатор 6Е1П («магический глаз»)
		var eye_c := Vector2(54.0, 54.0)
		var eye_r := 30.0
		draw_circle(eye_c, eye_r + 5.0, Color(0.18, 0.16, 0.12, 0.95))
		draw_circle(eye_c, eye_r + 2.0, Color(0.02, 0.04, 0.03, 1.0))
		var phos_col := Color(0.75, 0.42, 1.0, 0.95) if _overload else Color(0.10, 0.98, 0.40, 0.88)
		draw_circle(eye_c, eye_r, phos_col * Color(1, 1, 1, 0.25))
		draw_arc(eye_c, eye_r * 0.72, 0.0, TAU, 36, phos_col, 9.0, true)
		# Два смыкающихся теневых сектора: при _eye_smooth = 0 щель широкая, при 1.0 — лепестки сомкнуты
		var gap := lerpf(0.72, 0.04, _eye_smooth)
		if _overload:
			gap = 0.08 + absf(sin(_t * 42.0)) * 0.35
		for side_ang: float in [-PI * 0.5, PI * 0.5]:
			var pts := PackedVector2Array([eye_c])
			for s in range(9):
				var a := side_ang - gap + (2.0 * gap) * (float(s) / 8.0)
				pts.append(eye_c + Vector2(cos(a), sin(a)) * (eye_r + 1.0))
			draw_colored_polygon(pts, Color(0.02, 0.05, 0.03, 0.96))
		# Центральный колпачок катода
		draw_circle(eye_c, 8.5, Color(0.08, 0.10, 0.09, 1.0))
		draw_arc(eye_c, 8.5, 0.0, TAU, 24, Color(0.32, 0.36, 0.32, 0.65), 1.0, true)
		var eye_lbl := "6Е1П · ЗАХЛЁСТ" if _overload else "6Е1П · %d%%" % int(roundf(_eye_smooth * 100.0))
		draw_string(font, Vector2(10.0, 14.0), eye_lbl, HORIZONTAL_ALIGNMENT_LEFT, 108.0, 10, phos_col)

		# 2. ЦЕНТРАЛЬНЫЙ БЛОК: оптический верньер шкалы частот «ВОЛНА-К»
		var dial_r := Rect2(124.0, 18.0, w - 344.0, 52.0)
		draw_rect(dial_r, Color(0.09, 0.075, 0.045, 0.96), true)
		draw_rect(dial_r, Color(0.55, 0.45, 0.28, 0.85), false, 1.5)
		# Тёплая ламповая подсветка стекла верньера
		draw_rect(dial_r.grow(-2.0), Color(1.0, 0.68, 0.24, 0.08), true)
		var dial_cx := dial_r.position.x + dial_r.size.x * 0.5
		var px_per_khz := 2.4
		var base_tick := floorf(_freq / 10.0) * 10.0
		for step_i in range(-12, 13):
			var f_mark := base_tick + float(step_i) * 10.0
			var x := dial_cx + (f_mark - _freq) * px_per_khz
			if x < dial_r.position.x + 6.0 or x > dial_r.end.x - 6.0:
				continue
			var major := int(roundf(f_mark)) % 50 == 0
			var th := 18.0 if major else 10.0
			var tcol := Color(1.0, 0.78, 0.42, 0.88) if major else Color(0.75, 0.64, 0.45, 0.50)
			draw_line(Vector2(x, dial_r.end.y - th), Vector2(x, dial_r.end.y - 2.0), tcol, 1.4 if major else 1.0)
			if major:
				draw_string(font, Vector2(x - 18.0, dial_r.position.y + 15.0), "%d" % int(roundf(f_mark)), HORIZONTAL_ALIGNMENT_LEFT, 44.0, 10, Color(0.95, 0.78, 0.46, 0.82))
		# Фиксированная красная риска визирования
		draw_line(Vector2(dial_cx, dial_r.position.y + 2.0), Vector2(dial_cx, dial_r.end.y - 2.0), Color(0.95, 0.22, 0.16, 0.95), 2.0)

		# Шапка частоты и строка статуса под верньером
		var freq_txt := Loc.t(&"radio.freq", [_freq])
		if absf(_freq - 3820.0) <= 35.0:
			freq_txt += Loc.p("  [3820 · ТАЁЖНАЯ-4]", "  [3820 · TAYOZHNAYA-4]")
		draw_string(font, Vector2(dial_r.position.x, 13.0), freq_txt, HORIZONTAL_ALIGNMENT_LEFT, dial_r.size.x, 12, Color(1.0, 0.72, 0.28, 0.98))
		var fine_txt := Loc.p("ТОН %+0.1f кГц" % _fine, "FINE %+0.1f kHz" % _fine)
		draw_string(font, Vector2(dial_r.position.x, 86.0), fine_txt, HORIZONTAL_ALIGNMENT_LEFT, 130.0, 11, Color(0.84, 0.80, 0.64, 0.88))
		if not _lock_str.is_empty():
			draw_string(font, Vector2(dial_r.position.x + 128.0, 86.0), _lock_str, HORIZONTAL_ALIGNMENT_LEFT, dial_r.size.x - 130.0, 11, Color(0.42, 0.96, 0.56, 0.96))
		if _rec_prog >= 0.0:
			var bar_r := Rect2(dial_r.position.x, 93.0, dial_r.size.x, 6.0)
			draw_rect(bar_r, Color(0.12, 0.10, 0.10, 0.9), true)
			draw_rect(Rect2(bar_r.position, Vector2(bar_r.size.x * clampf(_rec_prog, 0.0, 1.0), bar_r.size.y)), Color(0.92, 0.26, 0.20, 0.95), true)
			if not _rec_str.is_empty():
				draw_string(font, Vector2(dial_r.position.x + dial_r.size.x - 180.0, 86.0), _rec_str, HORIZONTAL_ALIGNMENT_RIGHT, 180.0, 11, Color(1.0, 0.45, 0.38, 0.95))

		# 3. ПРАВЫЙ БЛОК: стрелочный S-метр + контрольные лампы УСС / ЗАХВАТ / ЗАПИСЬ
		var sm_x := w - 204.0
		var sm_r := Rect2(sm_x, 16.0, 196.0, 54.0)
		draw_rect(sm_r, Color(0.055, 0.068, 0.062, 0.95), true)
		draw_rect(sm_r, Color(0.42, 0.36, 0.25, 0.85), false, 1.4)
		var spivot := Vector2(sm_x + 98.0, sm_r.end.y - 4.0)
		var sr := 40.0
		var sa0 := -PI * 0.84
		var sa1 := -PI * 0.16
		draw_arc(spivot, sr, sa0, lerpf(sa0, sa1, 0.72), 20, Color(0.78, 0.82, 0.74, 0.60), 2.0, true)
		draw_arc(spivot, sr, lerpf(sa0, sa1, 0.72), sa1, 10, Color(0.92, 0.26, 0.20, 0.88), 2.5, true)
		var sn_ang := lerpf(sa0, sa1, clampf(_s_needle + sin(_t * 19.0) * 0.015 * _s_needle, 0.0, 1.0))
		draw_line(spivot, spivot + Vector2(cos(sn_ang), sin(sn_ang)) * (sr - 3.0), Color(1.0, 0.72, 0.26, 0.98), 2.0, true)
		draw_circle(spivot, 3.2, Color(0.48, 0.42, 0.30, 0.95))
		draw_string(font, Vector2(sm_x + 6.0, 12.0), "S-МЕТР · УСС %d%%" % int(roundf(_vario * 100.0)), HORIZONTAL_ALIGNMENT_LEFT, 190.0, 10, Color(0.74, 0.80, 0.76, 0.85))

		# Три контрольные лампы под S-метром
		var vario_ok := _vario >= 0.65
		var lamps: Array = [
			[Loc.p("УСС", "USS"), Color(0.32, 0.95, 0.48, 0.95) if vario_ok else Color(0.95, 0.32, 0.22, 0.90), true],
			[Loc.p("ЗАХВАТ", "LOCK"), Color(1.0, 0.72, 0.24, 0.98), not _lock_str.is_empty()],
			[Loc.p("ЗАП.", "REC"), Color(0.98, 0.24, 0.18, 0.98), _rec_prog >= 0.0 and fmod(_t, 0.7) < 0.45],
		]
		for i in range(lamps.size()):
			var lx := sm_x + 12.0 + float(i) * 64.0
			var ly := 84.0
			var lit: bool = lamps[i][2]
			var lc: Color = lamps[i][1]
			draw_circle(Vector2(lx, ly), 4.0, lc if lit else Color(0.18, 0.20, 0.19, 0.85))
			if lit:
				draw_circle(Vector2(lx, ly), 7.0, Color(lc.r, lc.g, lc.b, 0.22))
			draw_string(font, Vector2(lx + 8.0, ly + 4.0), String(lamps[i][0]), HORIZONTAL_ALIGNMENT_LEFT, 54.0, 10, Color(0.82, 0.86, 0.83, 0.92 if lit else 0.42))


