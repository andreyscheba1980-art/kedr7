class_name SettingsPanel
extends PanelContainer
## Настройки: экран (режим, разрешение, пиксельность, FPS), звук по каналам, мышь, FOV, яркость,
## PS1-фильтр, язык, субтитры. Изменения применяются сразу и сохраняются при закрытии.

signal closed

const LABEL_W := 270.0


var _scroll: ScrollContainer


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiKit.DARK
	sb.set_content_margin_all(22)
	add_theme_stylebox_override("panel", sb)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	add_child(outer)
	var title := UiKit.label(Loc.t(&"set.title"), 24)
	title.add_theme_color_override("font_color", UiKit.AMBER)
	outer.add_child(title)

	# Пунктов больше, чем влезает в 720 px по высоте, — список прокручивается.
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	outer.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)

	_section(box, &"set.screen")
	_choice(box, &"set.window", [&"set.fullscreen", &"set.windowed"], 0 if Settings.fullscreen else 1,
		func(i: int) -> void: Settings.fullscreen = i == 0)
	var res_names: Array = []
	for r: Vector2i in Settings.RESOLUTIONS:
		res_names.append("%d × %d" % [r.x, r.y])
	_choice(box, &"set.resolution", res_names, Settings.resolution,
		func(i: int) -> void: Settings.resolution = i)
	_choice(box, &"set.quality", [&"set.q0", &"set.q1", &"set.q2", &"set.q3"], Settings.quality,
		func(i: int) -> void: Settings.quality = i)
	_slider(box, &"set.render_scale", "render_scale", 0.5, 1.0, 0.05)
	_choice(box, &"set.pixel", [&"set.pixel0", &"set.pixel1", &"set.pixel2", &"set.pixel3"], Settings.pixelation,
		func(i: int) -> void: Settings.pixelation = i)
	_toggle(box, &"set.ps1", Settings.ps1_filter, func(on: bool) -> void: Settings.ps1_filter = on)
	_toggle(box, &"set.fps", Settings.show_fps, func(on: bool) -> void: Settings.show_fps = on)
	_toggle(box, &"set.auto_res", Settings.auto_res, func(on: bool) -> void: Settings.auto_res = on)
	_choice(box, &"set.fps_limit", [&"set.fps_lim0", &"set.fps_lim60", &"set.fps_lim30"], [0, 60, 30].find(Settings.fps_limit) if [0, 60, 30].has(Settings.fps_limit) else 0,
		func(i: int) -> void: Settings.fps_limit = [0, 60, 30][i])
	_slider(box, &"set.brightness", "brightness", 0.7, 1.5, 0.05)
	box.add_child(UiKit.button(Loc.t(&"calib.open"), func() -> void:
		var layer := CanvasLayer.new()
		layer.layer = 60   # поверх паузы (30) и меню
		layer.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child(layer)
		var cal := BrightnessCalib.new()
		layer.add_child(cal)
		cal.done.connect(layer.queue_free)))
	_slider(box, &"set.fov", "fov", 60.0, 95.0, 1.0)

	_section(box, &"set.sound")
	_slider(box, &"set.master", "master_volume", 0.0, 1.0, 0.05)
	_slider(box, &"set.sfx", "sfx_volume", 0.0, 1.0, 0.05)
	_slider(box, &"set.music", "music_volume", 0.0, 1.0, 0.05)
	_slider(box, &"set.ambient", "ambient_volume", 0.0, 1.0, 0.05)
	_slider(box, &"set.weather", "weather_volume", 0.0, 1.0, 0.05)
	_slider(box, &"set.radio", "radio_volume", 0.0, 1.0, 0.05)
	_choice(box, &"set.voice_mode", [&"set.voice_zas", &"set.voice_classic"], 0 if Settings.voice_mode == "zas" else 1,
		func(i: int) -> void: Settings.voice_mode = "zas" if i == 0 else "classic")

	_section(box, &"set.mic")
	_toggle(box, &"set.mic_enabled", Settings.mic_enabled, func(on: bool) -> void:
		Settings.mic_enabled = on
		Settings.mic_consent = on)
	_toggle(box, &"set.mic_mimic", Settings.mic_mimic, func(on: bool) -> void: Settings.mic_mimic = on)
	var mm_hint := UiKit.label(Loc.t(&"set.mic_mimic_hint"), 12)
	mm_hint.modulate = Color(1, 1, 1, 0.5)
	mm_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(mm_hint)
	var input_devs := AudioServer.get_input_device_list()
	if input_devs.size() > 1:
		var cur_dev_idx := 0
		for di in range(input_devs.size()):
			if input_devs[di] == Settings.mic_device:
				cur_dev_idx = di
				break
		_choice(box, &"set.mic_device", input_devs, cur_dev_idx, func(i: int) -> void:
			if i >= 0 and i < input_devs.size():
				var picked: String = input_devs[i]
				Settings.mic_device = picked
				if Mic != null and is_instance_valid(Mic):
					Mic.switch_device(picked)
				Settings.save())
	_slider(box, &"set.mic_sens", "mic_sensitivity", 0.2, 5.0, 0.1)
	_slider(box, &"set.mic_thresh", "mic_threshold", 0.04, 0.50, 0.01)
	_build_mic_meter(box)

	_section(box, &"set.other")
	_slider(box, &"set.sens", "mouse_sens", 0.3, 2.5, 0.05)
	_slider(box, &"set.gamepad_sens", "gamepad_sens", 0.3, 3.0, 0.1)
	_toggle(box, &"set.invert_y", Settings.invert_y, func(on: bool) -> void: Settings.invert_y = on)
	_slider(box, &"set.head_bob", "head_bob", 0.0, 1.0, 0.1)
	_slider(box, &"set.subs", "subtitle_size", 16.0, 32.0, 1.0)
	_toggle(box, &"set.rumble", Settings.rumble, func(on: bool) -> void: Settings.rumble = on)
	_toggle(box, &"set.toggle_breath", Settings.toggle_breath, func(on: bool) -> void: Settings.toggle_breath = on)
	_toggle(box, &"set.toggle_sprint", Settings.toggle_sprint, func(on: bool) -> void: Settings.toggle_sprint = on)
	_section(box, &"set.access")
	_slider(box, &"set.camera_shake", "camera_shake", 0.0, 1.0, 0.1)
	_toggle(box, &"set.reduce_flashes", Settings.reduce_flashes, func(on: bool) -> void: Settings.reduce_flashes = on)
	_slider(box, &"set.film_fx", "film_fx", 0.0, 1.0, 0.1)
	_toggle(box, &"set.subtitle_bg", Settings.subtitle_bg, func(on: bool) -> void: Settings.subtitle_bg = on)
	_build_keys(box)
	_build_pad(box)
	var lang := HBoxContainer.new()
	box.add_child(lang)
	lang.add_child(_row_label(&"set.lang"))
	lang.add_child(UiKit.button("Русский", func() -> void: _set_lang("ru")))
	lang.add_child(UiKit.button("English", func() -> void: _set_lang("en")))

	var back_btn := TelemetryButton.new()
	back_btn.set_data(Loc.p("ВЫХ-00", "RET-00"), Loc.t(&"ui.back").to_upper(), Loc.p("СОХРАНИТЬ", "APPLY"))
	back_btn.pressed.connect(_close)
	outer.add_child(back_btn)
	UiKit.safe_focus(back_btn)



## Клавиши: щёлкни по кнопке и нажми новую клавишу (Esc — отмена). AZERTY, левши, свои привычки.
var _waiting_action: StringName = &""
var _waiting_btn: Button
var _key_btns: Dictionary = {}


func _build_keys(box: VBoxContainer) -> void:
	_section(box, &"set.keys")
	for a: StringName in Game.REBINDABLE:
		var row := HBoxContainer.new()
		box.add_child(row)
		row.add_child(_row_label(StringName("key." + String(a))))
		var b := Button.new()
		b.custom_minimum_size = Vector2(200, 34)
		b.text = _key_name(Game.key_of(a))
		b.pressed.connect(func() -> void:
			if _waiting_btn != null:
				_waiting_btn.text = _key_name(Game.key_of(_waiting_action))
			_waiting_action = a
			_waiting_btn = b
			b.text = Loc.t(&"set.key_wait"))
		row.add_child(b)
		_key_btns[a] = b
	box.add_child(UiKit.button(Loc.t(&"set.keys_reset"), func() -> void:
		for a: StringName in Game.REBINDABLE:
			Game.rebind(a, 0)
			if _key_btns.has(a):
				(_key_btns[a] as Button).text = _key_name(Game.key_of(a))))


## Геймпад: выбери действие и нажми кнопку или курок на геймпаде (Start — отмена).
var _pad_action: StringName = &""
var _pad_btn: Button
var _pad_btns: Dictionary = {}


func _build_pad(box: VBoxContainer) -> void:
	_section(box, &"set.pad")
	var hint := UiKit.label(Loc.t(&"set.pad_hint"), 12)
	hint.modulate = Color(1, 1, 1, 0.5)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	for a: StringName in Game.PAD_REBINDABLE:
		var row := HBoxContainer.new()
		box.add_child(row)
		row.add_child(_row_label(StringName("pad." + String(a))))
		var b := Button.new()
		b.custom_minimum_size = Vector2(200, 34)
		b.text = Game.pad_name(a)
		b.pressed.connect(func() -> void:
			if _pad_btn != null:
				_pad_btn.text = Game.pad_name(_pad_action)
			_pad_action = a
			_pad_btn = b
			b.text = Loc.t(&"set.pad_wait"))
		row.add_child(b)
		_pad_btns[a] = b
	box.add_child(UiKit.button(Loc.t(&"set.pad_reset"), func() -> void:
		for a: StringName in Game.PAD_REBINDABLE:
			Game.rebind_pad(a, [])
		_refresh_pad()))


func _refresh_pad() -> void:
	for a: StringName in _pad_btns:
		(_pad_btns[a] as Button).text = Game.pad_name(a)


## Ловим кнопку геймпада для переназначения. Кнопку, которой нажали «ждать», игнорируем до отпускания.
func _pad_input(event: InputEvent) -> bool:
	if _pad_action == &"":
		return false
	var d: Array = []
	if event is InputEventJoypadButton and event.is_pressed():
		if (event as InputEventJoypadButton).button_index == JOY_BUTTON_START:
			d = ["cancel"]
		else:
			d = [0, int((event as InputEventJoypadButton).button_index), 1.0]
	elif event is InputEventJoypadMotion:
		var m := event as InputEventJoypadMotion
		if (m.axis == JOY_AXIS_TRIGGER_LEFT or m.axis == JOY_AXIS_TRIGGER_RIGHT) and m.axis_value > 0.6:
			d = [1, int(m.axis), 1.0]
	elif event is InputEventKey and event.is_pressed() and (event as InputEventKey).keycode == KEY_ESCAPE:
		d = ["cancel"]
	if d.is_empty():
		return event is InputEventJoypadButton or event is InputEventJoypadMotion   # пока ждём — геймпад в меню не ходит
	get_viewport().set_input_as_handled()
	if d[0] is int:
		Game.rebind_pad(_pad_action, d)
	_pad_action = &""
	_pad_btn = null
	_refresh_pad.call_deferred()
	return true


func _key_name(code: int) -> String:
	return "—" if code == 0 else OS.get_keycode_string(code as Key)


func _input(event: InputEvent) -> void:
	if _pad_action != &"":
		if _pad_input(event):
			get_viewport().set_input_as_handled()
		return
	if _waiting_action == &"" or not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	var k := event as InputEventKey
	var code := int(k.physical_keycode) if k.physical_keycode != KEY_NONE else int(k.keycode)
	if code != KEY_ESCAPE:
		# Та же клавиша у другого действия — меняем их местами, чтобы не было двойного назначения
		var old := Game.key_of(_waiting_action)
		for other: StringName in Game.REBINDABLE:
			if other != _waiting_action and Game.key_of(other) == code:
				Game.rebind(other, old)
				if _key_btns.has(other):
					(_key_btns[other] as Button).text = _key_name(Game.key_of(other))
		Game.rebind(_waiting_action, code)
	_waiting_btn.text = _key_name(Game.key_of(_waiting_action))
	_waiting_action = &""
	_waiting_btn = null


func _section(box: VBoxContainer, key: StringName) -> void:
	var l := UiKit.label(Loc.t(key), 15)
	l.add_theme_color_override("font_color", UiKit.AMBER)
	l.modulate = Color(1, 1, 1, 0.8)
	box.add_child(l)


func _row_label(key: StringName) -> Label:
	var l := UiKit.label(Loc.t(key), 16)
	l.custom_minimum_size.x = LABEL_W
	return l


## Выбор из нескольких вариантов. items — ключи строк (StringName) или готовый текст (String).
func _choice(box: VBoxContainer, key: StringName, items: Array, selected: int, on_pick: Callable) -> void:
	var row := HBoxContainer.new()
	box.add_child(row)
	row.add_child(_row_label(key))
	var opt := OptionButton.new()
	for it: Variant in items:
		opt.add_item(Loc.t(it) if it is StringName else str(it))
	opt.select(clampi(selected, 0, items.size() - 1))
	opt.custom_minimum_size.x = 260
	opt.item_selected.connect(func(i: int) -> void:
		on_pick.call(i)
		Settings.apply()
		Settings.save())
	row.add_child(opt)


func _toggle(box: VBoxContainer, key: StringName, value: bool, on_set: Callable) -> void:
	var cb := CheckButton.new()
	cb.text = Loc.t(key)
	cb.button_pressed = value
	cb.toggled.connect(func(on: bool) -> void:
		on_set.call(on)
		Settings.apply()
		Settings.save())
	box.add_child(cb)


func _slider(box: VBoxContainer, key: StringName, prop: String, lo: float, hi: float, step: float) -> void:
	var row := HBoxContainer.new()
	box.add_child(row)
	row.add_child(_row_label(key))
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Settings.get(prop))
	s.custom_minimum_size.x = 300
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var v := UiKit.label("", 14)
	v.custom_minimum_size.x = 60
	row.add_child(v)
	var update := func(val: float) -> void:
		if prop == "subtitle_size":
			Settings.set(prop, int(val))
		else:
			Settings.set(prop, val)
		v.text = str(snappedf(val, step))
		Settings.apply()
		Settings.save()
	s.value_changed.connect(update)
	v.text = str(snappedf(s.value, step))


func _set_lang(lang: String) -> void:
	Settings.language = lang
	Settings.save()
	Settings.apply()   # меню пересоберётся по сигналу changed


func _close() -> void:
	Settings.save()
	closed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_EXIT_TREE:
		Settings.save()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		if get_viewport() != null:
			get_viewport().set_input_as_handled()
		_close()


var _meter_bar: ProgressBar
var _meter_label: Label


func _build_mic_meter(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	box.add_child(row)
	row.add_child(_row_label(&"set.mic_meter"))
	_meter_bar = ProgressBar.new()
	_meter_bar.custom_minimum_size = Vector2(240, 18)
	_meter_bar.min_value = 0.0
	_meter_bar.max_value = 1.0
	_meter_bar.show_percentage = false
	_meter_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.12, 0.13, 0.14)
	sb_bg.set_corner_radius_all(3)
	_meter_bar.add_theme_stylebox_override("background", sb_bg)
	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = Color(0.3, 0.75, 0.35)
	sb_fill.set_corner_radius_all(3)
	_meter_bar.add_theme_stylebox_override("fill", sb_fill)
	row.add_child(_meter_bar)
	_meter_label = UiKit.label(Loc.p("ТИШИНА", "SILENCE"), 13)
	_meter_label.custom_minimum_size.x = 90
	row.add_child(_meter_label)

	var hint := UiKit.label(Loc.t(&"set.mic_hint"), 12)
	hint.modulate = Color(1, 1, 1, 0.5)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)


func _process(_delta: float) -> void:
	if _meter_bar != null and is_instance_valid(_meter_bar):
		var lvl: float = Mic.current_level if is_instance_valid(Mic) else 0.0
		# Перцептивная кривая: даже тихий голос/шепот наглядно шевелит полоску
		var bar_val: float = pow(lvl, 0.75) if lvl > 0.0 else 0.0
		_meter_bar.value = clampf(bar_val, 0.0, 1.0)
		var threshold: float = Settings.mic_threshold
		var fill_sb: StyleBoxFlat = _meter_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if not Settings.mic_enabled:
			_meter_label.text = Loc.p("ОТКЛЮЧЁН", "OFF")
			_meter_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
			if fill_sb != null:
				fill_sb.bg_color = Color(0.4, 0.4, 0.4)
		elif lvl >= threshold:
			_meter_label.text = Loc.p("СИГНАЛ!", "SIGNAL!")
			_meter_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
			if fill_sb != null:
				fill_sb.bg_color = Color(0.95, 0.25, 0.25)
		elif lvl > 0.03:
			_meter_label.text = Loc.p("ФОН...", "NOISE...")
			_meter_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
			if fill_sb != null:
				fill_sb.bg_color = Color(0.85, 0.75, 0.25)
		else:
			_meter_label.text = Loc.p("ТИШИНА", "SILENCE")
			_meter_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
			if fill_sb != null:
				fill_sb.bg_color = Color(0.3, 0.75, 0.35)

