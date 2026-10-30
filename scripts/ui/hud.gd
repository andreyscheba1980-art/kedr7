class_name Hud
extends CanvasLayer
## Интерфейс поверх мира (в полном разрешении, мир — в низком): подсказки, часы, субтитры,
## панель рации, записки, модальные окна (карта, магнитофон, шифроблокнот), затемнения и вспышки.

const FACE_TEX := "res://assets/textures/face_flash.png"
const FROST_TEX := "res://assets/textures/frost_vignette.png"
const CovenantsClass = preload("res://scripts/data/covenants.gd")

var root: Control
var _prompt: Label
var _clock: Label
var _fps: Label
var _objective: Label
var _subtitle: Label
var _radio_panel: PanelContainer
var _freq_label: Label
var _strength: ProgressBar
var _lock_label: Label
var _record_label: Label
var _record_bar: ProgressBar
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
var _screen_label: Label
var _frost: TextureRect
var _dark_vignette: TextureRect
var _held_label: Label
var _flash_box: HBoxContainer
var _flash_bar: ProgressBar
var _breath_box: HBoxContainer
var _breath_bar: ProgressBar
var _flash_show := 0.0
var _tasks_panel: PanelContainer
var _tasks_label: Label
var _tasks_tab := 0
var _tasks_container: Control
var _covenants_container: Control
var _cov_vbox: VBoxContainer
var _tab_btn_tasks: Button
var _tab_btn_cov: Button
var _sub_token := 0

var _sub_priority := 0
var _sub_until := 0
var _modal: Control
var cinematic := false            ## холодный старт и катсцены: без часов, задачи, фонаря
var _fps_timer := 0.0


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

	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.55)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(dot, 0.5, 0.5, 0.5, 0.5, -2, -2, 2, 2)

	_prompt = UiKit.label("", 18, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_prompt, 0.5, 0.5, 0.5, 0.5, -420, 28, 420, 90)

	_subtitle = UiKit.label("", Settings.subtitle_size, HORIZONTAL_ALIGNMENT_CENTER)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_place(_subtitle, 0.12, 1, 0.88, 1, 0, -190, 0, -80)

	_held_label = UiKit.label("", 16, HORIZONTAL_ALIGNMENT_RIGHT)
	_held_label.modulate = Color(1, 1, 1, 0.7)
	_place(_held_label, 1, 1, 1, 1, -520, -50, -20, -20)

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

	_screen = ColorRect.new()
	_screen.color = Color.BLACK
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_screen, 0, 0, 1, 1, 0, 0, 0, 0)
	_screen_label = UiKit.label("", 20, HORIZONTAL_ALIGNMENT_CENTER)
	_screen_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_screen_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_screen.add_child(_screen_label)
	_screen_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen_label.offset_left = 120
	_screen_label.offset_right = -120
	_screen.visible = false


func _process(delta: float) -> void:
	if not is_inside_tree() or Game == null or _clock == null or _held_label == null:
		return
	var phase := Loc.t(&"hud.night", [Game.night]) if Game.is_night() else (Loc.t(&"hud.day", [Game.phase_index]) if not Game.is_prologue() else (Loc.t(&"hud.morning") if Game.has_flag("prologue_arrived") else Loc.t(&"hud.prologue")))
	_clock.text = "%s   %s" % [phase, Game.clock_text()]
	var show_fps_flag: bool = (Settings != null and is_instance_valid(Settings) and Settings.show_fps) or (_debug_panel != null and _debug_panel.visible)
	if _fps != null:
		_fps.visible = show_fps_flag
		if show_fps_flag:
			_fps_timer -= delta
			if _fps_timer <= 0.0:
				_fps_timer = 0.25
				_fps.text = "FPS %d" % Engine.get_frames_per_second()
	_clock.visible = not cinematic
	# Книга в руках закрывает центр: субтитр торчал из-за листа по краям — пока читаешь, он ждёт
	if _subtitle != null:
		var m := modal()
		_subtitle.self_modulate.a = 0.0 if m is HeldPaper and (m as HeldPaper).inner is BookUI else 1.0
	if _flash_box != null and cinematic:
		_flash_box.visible = false
	if _objective != null:
		_objective.visible = not cinematic
		# Сюжетный режим ведёт за руку; на обычной и сложной — только аварии (их нельзя пропустить).
		_objective.text = Game.objective_text() if Game.is_story() or Game.is_prologue() else Game.alarm_text()
	if _frost != null:
		var frost := clampf((65.0 - Game.warmth) / 55.0, 0.0, 1.0)
		if Game.mirror_covered:
			frost = 0.0
		_frost.modulate.a = lerpf(_frost.modulate.a, frost * 0.85, minf(delta * 2.0, 1.0))

	if _dark_vignette != null:
		var tension_factor := Director.tension / 100.0 if Game.is_night() else 0.0
		var fatigue_factor := Game.fatigue / 100.0 if Game.is_night() else 0.0
		var vig_target := clampf(tension_factor * 0.55 + fatigue_factor * 0.35, 0.0, 0.82)
		_dark_vignette.modulate.a = lerpf(_dark_vignette.modulate.a, vig_target, minf(delta * 2.0, 1.0))
	_update_flash(delta)
	_update_breath(delta)
	if _held_label != null:
		var held := Game.player.held if Game.player != null else &""
		_held_label.text = "" if held == &"" else Loc.t(StringName("held." + String(held)))
	if _tasks_panel != null and _tasks_panel.visible and _tasks_label != null:
		_tasks_label.text = Game.tasks_text()
	if _debug_panel != null and _debug_panel.visible:
		_update_debug()


# --- Публичное API -----------------------------------------------------------

func set_prompt(text: String) -> void:
	if Game != null and Game.is_gamepad:
		text = _format_gamepad_prompt(text)
	_prompt.text = text


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

	var col: Color = custom_color
	if col == Color.TRANSPARENT:
		var low := text.to_lower()
		if text.begins_with("(") or text.begins_with("（"):
			col = Color(0.88, 0.85, 0.78, 0.92) # Внутренний голос / осмотр
		elif low.contains("3820") or low.contains("угмс") or low.contains("радио") or low.contains("эфир") or low.contains("диспетчер") or low.contains("семенов") or low.contains("семёнов"):
			col = Color(1.0, 0.82, 0.38, 0.98) # Радиоэфир и архив
		elif low.contains("шёпот") or low.contains("шепот") or low.contains("тайг") or low.contains("выдох") or low.contains("урман") or low.contains("ырк") or low.contains("шаг"):
			col = Color(0.68, 0.88, 1.0, 0.98) # Мистический шёпот тайги
		elif priority >= 2:
			col = Color(1.0, 0.45, 0.35, 0.98) # Тревога / авария
		else:
			col = Color(0.96, 0.96, 0.96, 0.96) # Обычная речь

	_subtitle.text = text
	_subtitle.add_theme_color_override("font_color", col)
	await get_tree().create_timer(duration, false).timeout
	if token == _sub_token:
		_subtitle.text = ""
		_sub_priority = 0


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


func show_radio(on: bool) -> void:
	_radio_panel.visible = on
	_prompt.visible = not on


func update_radio(freq: float, strength: float, locked_id: StringName, record_text: String, record_progress: float) -> void:
	var freq_str := Loc.t(&"radio.freq", [freq])
	if absf(freq - 3820.0) <= 35.0:
		freq_str += Loc.p("  [ 3820.0 · ТАЁЖНАЯ-4 / БЕЛОВ ]", "  [ 3820.0 · TAYOZHNAYA-4 / BELOV ]")
	_freq_label.text = freq_str
	_strength.value = strength * 100.0
	if locked_id != &"":
		if String(locked_id).begins_with("bc_belov_"):
			_lock_label.text = Loc.t(&"sig.belov.title") + " · " + Loc.t(&"radio.locked")
		else:
			_lock_label.text = Loc.t(&"radio.locked")
	else:
		_lock_label.text = ""
	_record_label.text = record_text
	_record_bar.visible = record_progress >= 0.0
	_record_bar.value = maxf(record_progress, 0.0) * 100.0


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


func show_note(text: String) -> void:
	_note_label.text = text + "\n\n" + Loc.t(&"ui.close_e")
	# Длинные страницы (журнал с дописками) — мельче, чтобы влезали в лист.
	_note_label.add_theme_font_size_override("font_size", 17 if text.length() < 900 else 15 if text.length() < 1250 else 14)
	if _note_backdrop != null:
		_note_backdrop.visible = true
	_note_panel.visible = true
	if Game.player != null and not Game.dead:
		Game.player.mode = Player.Mode.READING


func hide_note() -> void:
	if _note_backdrop != null:
		_note_backdrop.visible = false
	_note_panel.visible = false
	if Game.player != null and Game.player.mode == Player.Mode.READING and not Game.dead:
		Game.player.mode = Player.Mode.WALK


func is_note_open() -> bool:
	return _note_panel != null and _note_panel.visible


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


func show_screen(text: String) -> void:
	_screen_label.text = text
	_screen.modulate.a = 1.0
	_screen.visible = true


func fade_in_screen(text: String, time := 1.5) -> void:
	_screen_label.text = text
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

## Заряд фонаря-жучка: виден, пока фонарь горит, крутишь жучок или заряд неполный.
func _build_flash() -> void:
	_flash_box = HBoxContainer.new()
	_flash_box.add_theme_constant_override("separation", 10)
	_flash_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiKit.label(Loc.t(&"hud.flash"), 14)
	l.modulate = Color(1, 1, 1, 0.7)
	l.custom_minimum_size.x = 84.0   # подписи полосок одной ширины — полосы встают ровно друг под другом
	_flash_box.add_child(l)
	_flash_bar = ProgressBar.new()
	_flash_bar.show_percentage = false
	_flash_bar.custom_minimum_size = Vector2(150, 10)
	_flash_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_flash_box.add_child(_flash_bar)
	_place(_flash_box, 0, 1, 0, 1, 20, -50, 360, -24)
	_flash_box.modulate.a = 0.0


func _update_flash(delta: float) -> void:
	var p := Game.player
	if p == null:
		return
	var c := Game.flash_charge
	var want := p.flashlight_on() or p.cranking or c < 99.0
	_flash_show = 1.0 if want else maxf(_flash_show - delta * 0.5, 0.0)
	_flash_box.modulate.a = lerpf(_flash_box.modulate.a, _flash_show, minf(delta * 6.0, 1.0))
	_flash_bar.value = c
	var col := Color(0.95, 0.85, 0.5) if c > 25.0 else Color(1.0, 0.35, 0.25)
	if c <= 25.0 and p.flashlight_on() and fmod(Time.get_ticks_msec() / 400.0, 2.0) < 1.0:
		col = col.darkened(0.5)
	_flash_bar.modulate = col


## Запас дыхания: виден, пока держишь дыхание или он не восстановился. Серый — ещё рано держать снова.
func _build_breath() -> void:
	_breath_box = HBoxContainer.new()
	_breath_box.add_theme_constant_override("separation", 10)
	_breath_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiKit.label(Loc.t(&"hud.breath"), 14)
	l.modulate = Color(1, 1, 1, 0.7)
	l.custom_minimum_size.x = 84.0   # подписи полосок одной ширины — полосы встают ровно друг под другом
	_breath_box.add_child(l)
	_breath_bar = ProgressBar.new()
	_breath_bar.show_percentage = false
	_breath_bar.custom_minimum_size = Vector2(150, 8)
	_breath_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_breath_box.add_child(_breath_bar)
	_place(_breath_box, 0, 1, 0, 1, 20, -78, 360, -54)
	_breath_box.modulate.a = 0.0


func _update_breath(delta: float) -> void:
	var p := Game.player
	if p == null or _breath_box == null:
		return
	var b: float = p.breath_stamina
	var want: bool = p.holding_breath or b < 99.0
	_breath_box.modulate.a = lerpf(_breath_box.modulate.a, 1.0 if want else 0.0, minf(delta * (6.0 if want else 1.5), 1.0))
	_breath_bar.value = b
	var col := Color(0.62, 0.8, 0.95)
	if not p.holding_breath and b <= 40.0:
		col = Color(0.5, 0.5, 0.55)          # ещё не отдышался — снова задержать нельзя
	elif p.holding_breath and b < 25.0:
		col = Color(1.0, 0.45, 0.3)           # передержка: на морозе отпустишь — закашляешься
	_breath_bar.modulate = col


func _build_radio_panel() -> void:
	_radio_panel = UiKit.panel()
	_place(_radio_panel, 0.5, 1, 0.5, 1, -360, -330, 360, -180)
	var box := VBoxContainer.new()
	_radio_panel.add_child(box)
	var title := UiKit.label(Loc.t(&"radio.title"), 14)
	title.modulate = Color(1, 1, 1, 0.6)
	box.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	_freq_label = UiKit.label("", 30)
	_freq_label.add_theme_color_override("font_color", UiKit.AMBER)
	row.add_child(_freq_label)
	_strength = ProgressBar.new()
	_strength.show_percentage = false
	_strength.custom_minimum_size = Vector2(200, 14)
	_strength.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_strength.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_strength)
	var row2 := HBoxContainer.new()
	box.add_child(row2)
	_lock_label = UiKit.label("", 14)
	_lock_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_lock_label.custom_minimum_size.x = 200
	row2.add_child(_lock_label)
	_record_label = UiKit.label("", 14)
	_record_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45))
	row2.add_child(_record_label)
	_record_bar = ProgressBar.new()
	_record_bar.show_percentage = false
	_record_bar.custom_minimum_size = Vector2(120, 10)
	_record_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_record_bar.visible = false
	row2.add_child(_record_bar)
	var hint := UiKit.label(Loc.t(&"radio.hint"), 13)
	hint.modulate = Color(1, 1, 1, 0.6)
	box.add_child(hint)
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
	_place(_tasks_panel, 1, 0, 1, 0, -520, 50, -20, 560)
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	_tasks_panel.add_child(main_vbox)

	var tabs_row := HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation", 10)
	main_vbox.add_child(tabs_row)

	_tab_btn_tasks = UiKit.button(Loc.t(&"cov.tab_tasks"), func() -> void: _switch_tasks_tab(0))
	_tab_btn_cov = UiKit.button(Loc.t(&"cov.tab_covenants"), func() -> void: _switch_tasks_tab(1))
	tabs_row.add_child(_tab_btn_tasks)
	tabs_row.add_child(_tab_btn_cov)

	_tasks_container = VBoxContainer.new()
	main_vbox.add_child(_tasks_container)
	_tasks_label = UiKit.ink(UiKit.label("", 15))
	_tasks_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tasks_container.add_child(_tasks_label)

	_covenants_container = ScrollContainer.new()
	_covenants_container.custom_minimum_size = Vector2(480, 440)
	_covenants_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_covenants_container.follow_focus = true
	main_vbox.add_child(_covenants_container)

	_cov_vbox = VBoxContainer.new()
	_cov_vbox.add_theme_constant_override("separation", 12)
	_cov_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_covenants_container.add_child(_cov_vbox)

	_switch_tasks_tab(0)
	_tasks_panel.visible = false


func _switch_tasks_tab(tab: int) -> void:
	_tasks_tab = tab
	if _tasks_container != null:
		_tasks_container.visible = (_tasks_tab == 0)
	if _covenants_container != null:
		_covenants_container.visible = (_tasks_tab == 1)
	if _tab_btn_tasks != null:
		_tab_btn_tasks.modulate = Color(1.2, 1.1, 0.8) if _tasks_tab == 0 else Color(0.85, 0.85, 0.85)
	if _tab_btn_cov != null:
		_tab_btn_cov.modulate = Color(1.2, 1.1, 0.8) if _tasks_tab == 1 else Color(0.85, 0.85, 0.85)
	if _tasks_tab == 1:
		_rebuild_covenants_ui()


func _rebuild_covenants_ui() -> void:
	if _cov_vbox == null:
		return
	for c in _cov_vbox.get_children():
		c.queue_free()

	for entry in CovenantsClass.ENTRIES:
		var min_n: int = entry.get("min_night", 1)
		if Game.night < min_n:
			continue
		var item_box := VBoxContainer.new()
		item_box.add_theme_constant_override("separation", 4)
		_cov_vbox.add_child(item_box)

		var author := UiKit.ink(UiKit.label(CovenantsClass.author(entry), 13))
		author.add_theme_color_override("font_color", Color(0.42, 0.22, 0.12))
		item_box.add_child(author)

		var rule := UiKit.ink(UiKit.label(CovenantsClass.text(entry), 14))
		rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item_box.add_child(rule)

		var btn_row := HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 6)
		item_box.add_child(btn_row)

		var cur_state: String = CovenantsClass.get_state(entry.id)
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
				CovenantsClass.set_state(entry.id, s)
				if entry.id == "night5_delusion" and (s == "false" or s == "danger"):
					subtitle(Loc.t(&"cov.sanity_boost"), 3.5)
					Director.add_tension(-20.0, "морок зачеркнут")
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
		"warmth %.0f  flash %.0f  stove %.0f  storm %.2f  rope %.1f m" % [Game.warmth, Game.flash_charge, Game.stove_wood, Game.weather.intensity if Game.weather != null else 0.0, Game.yard.distance_to_path(Game.player.global_position) if Game.yard != null and Game.player != null else 0.0],
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

