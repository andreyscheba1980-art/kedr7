class_name MainMenu
extends Control
## Главное меню: премиальный советский телеметрический оверлей Госкомгидромета СССР (1983).
## Живой фон полярной ночи, мерцающий маяк ЗОМ-1 на мачте, качание фонаря и тактильные реле.

signal continue_pressed
signal new_game(difficulty: String)
signal new_shift
signal quit_pressed

const POST_SHADER := "res://assets/shaders/ps1_post.gdshader"
const TelemetryButtonClass = preload("res://scripts/ui/telemetry_button.gd")

var _box: VBoxContainer
var _ui: Control
var _backdrop: MenuBackdrop
var _lang := ""
var _container: SubViewportContainer
var _in_difficulty := false


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var container := SubViewportContainer.new()
	_container = container
	container.stretch = true
	container.stretch_shrink = 1
	container.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var post := ShaderMaterial.new()
	post.shader = load(POST_SHADER)
	container.material = post
	UiKit.place(self, container, 0, 0, 1, 1, 0, 0, 0, 0)
	var vp := SubViewport.new()
	container.add_child(vp)
	_backdrop = MenuBackdrop.new()
	vp.add_child(_backdrop)

	# Хвойно-угольный градиент слева (Alpha 85% -> 0%) под текст меню
	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color(0.035, 0.05, 0.055, 0.94),
		Color(0.035, 0.05, 0.055, 0.78),
		Color(0.035, 0.05, 0.055, 0.0)
	])
	grad.offsets = PackedFloat32Array([0.0, 0.44, 0.78])
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_LINEAR
	gtex.fill_from = Vector2(0.0, 0.5)
	gtex.fill_to = Vector2(1.0, 0.5)

	var shade := TextureRect.new()
	shade.texture = gtex
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(self, shade, 0, 0, 1, 1, 0, 0, 0, 0)

	_ui = Control.new()
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(self, _ui, 0, 0, 1, 1, 0, 0, 0, 0)
	Settings.changed.connect(_on_settings_changed)
	_start_menu_music()
	_rebuild()


var _music: AudioStreamPlayer
var _menu_wind: AudioStreamPlayer

func _start_menu_music() -> void:
	if _music != null:
		return
	_music = AudioStreamPlayer.new()
	var s := load("res://assets/audio/menu_music.ogg") as AudioStream
	if s != null:
		_music.stream = s
		_music.volume_db = -8.0
		_music.bus = &"Music"
		add_child(_music)
		_music.finished.connect(_music.play)
		_music.play()
	if _menu_wind == null:
		_menu_wind = AudioStreamPlayer.new()
		var ws := load("res://assets/audio/wind_loop.ogg") as AudioStream
		if ws != null:
			_menu_wind.stream = ws
			_menu_wind.volume_db = -22.0
			_menu_wind.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
			add_child(_menu_wind)
			_menu_wind.finished.connect(_menu_wind.play)
			_menu_wind.play()


func _exit_tree() -> void:
	if _music != null:
		_music.stop()
		_music.queue_free()
		_music = null
	if _menu_wind != null:
		_menu_wind.stop()
		_menu_wind.queue_free()
		_menu_wind = null


func _on_settings_changed() -> void:
	if _container.stretch_shrink != Settings.render_shrink():
		_container.stretch_shrink = Settings.render_shrink()
	if Settings.language != _lang:
		_rebuild()


func _rebuild() -> void:
	_lang = Settings.language
	_box = null
	for c in _ui.get_children():
		c.queue_free()

	# 1. Паспортная табличка ГОСТ / Штамп Госкомгидромета СССР
	var stamp := PanelContainer.new()
	var stamp_sb := StyleBoxFlat.new()
	stamp_sb.bg_color = Color(0.04, 0.055, 0.06, 0.78)
	stamp_sb.border_color = Color("#2C3834")
	stamp_sb.set_border_width_all(1)
	stamp_sb.set_content_margin_all(12)
	stamp.add_theme_stylebox_override("panel", stamp_sb)
	UiKit.place(_ui, stamp, 0, 0, 0, 0, 72, 38, 545, 178)

	var stamp_vbox := VBoxContainer.new()
	stamp_vbox.add_theme_constant_override("separation", 2)
	stamp.add_child(stamp_vbox)

	var agency := Label.new()
	agency.text = Loc.t(&"menu.agency")
	agency.add_theme_font_size_override("font_size", 11)
	agency.add_theme_color_override("font_color", Color("#687873"))
	stamp_vbox.add_child(agency)

	var station_desc := Label.new()
	station_desc.text = Loc.t(&"menu.station_desc")
	station_desc.add_theme_font_size_override("font_size", 10)
	station_desc.add_theme_color_override("font_color", Color("#4A5854"))
	stamp_vbox.add_child(station_desc)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	stamp_vbox.add_child(title_row)

	var title_label := Label.new()
	title_label.text = "КЕДР"
	title_label.add_theme_font_size_override("font_size", 40)
	title_label.add_theme_color_override("font_color", Color("#C5CFCB"))
	title_row.add_child(title_label)

	var dash_label := Label.new()
	dash_label.text = "—"
	dash_label.add_theme_font_size_override("font_size", 40)
	dash_label.add_theme_color_override("font_color", Color("#687873"))
	title_row.add_child(dash_label)

	var num_label := Label.new()
	num_label.text = "7"
	num_label.add_theme_font_size_override("font_size", 40)
	num_label.add_theme_color_override("font_color", Color("#FFA62B"))
	title_row.add_child(num_label)

	var passport := Label.new()
	passport.text = Loc.t(&"menu.passport")
	passport.add_theme_font_size_override("font_size", 10)
	passport.add_theme_color_override("font_color", Color("#687873"))
	stamp_vbox.add_child(passport)

	# 2. Нижняя телеметрическая сводка (вместо предупреждения о скримерах)
	var bottom_bar := HBoxContainer.new()
	bottom_bar.add_theme_constant_override("separation", 24)
	UiKit.place(_ui, bottom_bar, 0, 1, 1, 1, 72, -42, -72, -18)

	var telem_label := Label.new()
	telem_label.text = Loc.t(&"menu.status_telemetry")
	telem_label.add_theme_font_size_override("font_size", 11)
	telem_label.add_theme_color_override("font_color", Color("#687873"))
	bottom_bar.add_child(telem_label)

	bottom_bar.add_spacer(false)

	var ver_label := Label.new()
	ver_label.text = "v" + String(ProjectSettings.get_setting("application/config/version", "")) + " · ГОСКОМГИДРОМЕТ СССР · F9 — ЖУРНАЛ"
	ver_label.add_theme_font_size_override("font_size", 11)
	ver_label.add_theme_color_override("font_color", Color("#4A5854"))
	bottom_bar.add_child(ver_label)

	_show_main()


func _make_telem_btn(idx: String, title: String, hint: String, on_press: Callable) -> Button:
	var b = TelemetryButtonClass.new()
	b.set_data(idx, title, hint)
	b.pressed.connect(on_press)
	return b


func _show_main() -> void:
	_in_difficulty = false
	_clear_box()

	var has_save := SaveGame.has_save()
	var save_hint := ""
	if has_save:
		var s_night := int(SaveGame.flags.get("night", 1))
		var s_is_night := bool(SaveGame.flags.get("is_night", true))
		var s_temp := -38 - s_night * 2
		var s_phase := Loc.p("НОЧЬ", "NIGHT") if s_is_night else Loc.p("УТРО", "DAY")
		save_hint = Loc.p("СУТКИ %02d · %s // %d°C" % [s_night, s_phase, s_temp], "SHIFT %02d · %s // %d°C" % [s_night, s_phase, s_temp])
	else:
		save_hint = Loc.p("НАЧАЛО ВАХТЫ", "COMMENCE")

	# Пункт 1: ВАХТА (Продолжить / Начать)
	if has_save:
		var cont_btn := _make_telem_btn(Loc.p("КН-01", "BTN-01"), Loc.t(&"menu.btn_continue"), save_hint, func() -> void:
			stop_music()
			continue_pressed.emit())
		_box.add_child(cont_btn)
		cont_btn.grab_focus.call_deferred()

		var new_btn := _make_telem_btn(Loc.p("СМН-02", "SFT-02"), Loc.t(&"menu.btn_new"), Loc.p("ПЕРЕЗАПИСЬ", "OVERWRITE"), _show_difficulty)
		_box.add_child(new_btn)
	else:
		var new_btn := _make_telem_btn(Loc.p("КН-01", "BTN-01"), Loc.t(&"menu.btn_new"), save_hint, _show_difficulty)
		_box.add_child(new_btn)
		new_btn.grab_focus.call_deferred()

	# Пункт 2: ДВЕ ВАХТЫ (Связь)
	var coop_btn := _make_telem_btn(Loc.p("ЗАС-02", "SEC-02"), Loc.t(&"menu.btn_coop"), Loc.p("3820 кГц // ЭФИР", "3820 kHz // RADIO"), _show_coop)
	_box.add_child(coop_btn)

	# Пункт 3: АРХИВ И ФОРМУЛЯРЫ (Единый картотечный хаб)
	var archive_btn := _make_telem_btn(Loc.p("ТМ-03", "DOC-03"), Loc.t(&"menu.btn_archive"), Loc.p("КАРТОТЕКА", "DOSSIER"), _show_dossier_hub)
	_box.add_child(archive_btn)

	# Пункт 4: РЕГЛАМЕНТ ПРИБОРОВ (Настройки)
	var set_btn := _make_telem_btn(Loc.p("РГ-04", "REG-04"), Loc.t(&"menu.btn_settings"), Loc.p("ПРИБОРЫ", "CALIBRATION"), _show_settings)
	_box.add_child(set_btn)

	# Пункт 5: СДАТЬ СМЕНУ (Выход)
	var quit_btn := _make_telem_btn(Loc.p("ВЫХ-00", "EXT-00"), Loc.t(&"menu.btn_quit"), Loc.p("РУБИЛЬНИК", "POWER OFF"), func() -> void:
		quit_pressed.emit())
	_box.add_child(quit_btn)

	_link_focus_chain()
	grab_initial_focus.call_deferred()


func _link_focus_chain() -> void:
	if _box == null:
		return
	var btns: Array[Control] = []
	for c in _box.get_children():
		if c is Control and c.focus_mode != Control.FOCUS_NONE and c.visible:
			btns.append(c)
	for i in btns.size():
		var prev: Control = btns[(i - 1 + btns.size()) % btns.size()]
		var nxt: Control = btns[(i + 1) % btns.size()]
		btns[i].focus_neighbor_top = prev.get_path()
		btns[i].focus_neighbor_bottom = nxt.get_path()


func grab_initial_focus() -> void:
	if _box != null and is_inside_tree():
		for c in _box.get_children():
			if c is Button and c.visible and c.is_inside_tree():
				c.grab_focus()
				return


func _clear_box() -> void:
	if _box != null:
		_box.queue_free()
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	UiKit.place(_ui, _box, 0, 0, 0, 0, 72, 196, 560, 640)


func _show_dossier_hub() -> void:
	_in_difficulty = true
	_clear_box()

	var hdr := UiKit.label(Loc.t(&"menu.btn_archive"), 18)
	hdr.add_theme_color_override("font_color", Color("#FFA62B"))
	_box.add_child(hdr)

	var b1 := _make_telem_btn(Loc.p("ДОК-01", "DOC-01"), Loc.t(&"menu.dossier_tab1"), Loc.p("УПРАВЛЕНИЕ", "CONTROLS"), _show_controls)
	_box.add_child(b1)
	b1.grab_focus.call_deferred()

	var b2 := _make_telem_btn(Loc.p("ДОК-02", "DOC-02"), Loc.t(&"menu.dossier_tab2"), Loc.p("СЕМЁНОВ", "SEMENOV"), _show_archive)
	_box.add_child(b2)

	var b3 := _make_telem_btn(Loc.p("ДОК-03", "DOC-03"), Loc.t(&"menu.dossier_tab3"), Loc.p("ДОСТИЖЕНИЯ", "AWARDS"), _show_achievements)
	_box.add_child(b3)

	var b4 := _make_telem_btn(Loc.p("ДОК-04", "DOC-04"), Loc.t(&"menu.dossier_tab4"), Loc.p("ФОРМУЛЯР", "PERSONNEL"), show_credits)
	_box.add_child(b4)

	var back := _make_telem_btn(Loc.p("НАЗ-00", "BCK-00"), Loc.t(&"ui.back"), Loc.p("ГЛАВНОЕ МЕНЮ", "MAIN MENU"), _show_main)
	_box.add_child(back)
	_link_focus_chain()


func _show_difficulty() -> void:
	_in_difficulty = true
	_clear_box()

	var hdr := UiKit.label(Loc.t(&"menu.choose_diff"), 18)
	hdr.add_theme_color_override("font_color", Color("#FFA62B"))
	_box.add_child(hdr)

	var story_btn := _make_telem_btn(Loc.p("РЕЖ-01", "MOD-01"), Loc.t(&"diff.story"), Loc.p("ИССЛЕДОВАТЕЛЬ", "EXPLORER"), func() -> void:
		stop_music()
		new_game.emit("story"))
	_box.add_child(story_btn)
	story_btn.grab_focus.call_deferred()
	_box.add_child(_desc(&"diff.story_desc"))

	var hard_btn := _make_telem_btn(Loc.p("РЕЖ-02", "MOD-02"), Loc.t(&"diff.hard"), Loc.p("БУРАН-ХАРДКОР", "BLIZZARD HARDCORE"), func() -> void:
		stop_music()
		new_game.emit("hard"))
	_box.add_child(hard_btn)
	_box.add_child(_desc(&"diff.hard_desc"))

	if SaveGame.has_save():
		var warn := _desc(&"menu.overwrite")
		warn.add_theme_color_override("font_color", Color("#C82820"))
		_box.add_child(warn)

	var back_btn := _make_telem_btn(Loc.p("НАЗ-00", "BCK-00"), Loc.t(&"ui.back"), Loc.p("ОТМЕНА", "CANCEL"), _show_main)
	_box.add_child(back_btn)
	_link_focus_chain()


func _unhandled_input(event: InputEvent) -> void:
	if _in_difficulty and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause")):
		get_viewport().set_input_as_handled()
		if not Net.in_session:
			Net.leave()
		_show_main()


func stop_music() -> void:
	if _music != null:
		_music.stop()
		_music.queue_free()
		_music = null


func _show_settings() -> void:
	if _box != null:
		_box.queue_free()
		_box = null
	var p := SettingsPanel.new()
	UiKit.place(_ui, p, 0, 0, 0, 0, 72, 196, 900, 680)
	p.closed.connect(func() -> void:
		p.queue_free()
		_show_main())


func _show_controls() -> void:
	if _box != null:
		_box.queue_free()
		_box = null
	var c := ControlsMemoUI.new()
	UiKit.place(_ui, c, 0, 0, 1, 1, 0, 0, 0, 0)
	c.closed.connect(func() -> void:
		c.queue_free()
		_show_dossier_hub())


func show_credits() -> void:
	if _box != null:
		_box.queue_free()
		_box = null
	var c := CreditsUI.new()
	UiKit.place(_ui, c, 0, 0, 1, 1, 0, 0, 0, 0)
	c.closed.connect(func() -> void:
		c.queue_free()
		_show_dossier_hub())


func _show_achievements() -> void:
	if _box != null:
		_box.queue_free()
		_box = null
	var a := AchievementsUI.new()
	UiKit.place(_ui, a, 0, 0, 1, 1, 0, 0, 0, 0)
	a.closed.connect(func() -> void:
		a.queue_free()
		_show_dossier_hub())


func _show_archive() -> void:
	if _box != null:
		_box.queue_free()
		_box = null
	var a := ArchiveUI.new()
	UiKit.place(_ui, a, 0, 0, 1, 1, 0, 0, 0, 0)
	a.closed.connect(func() -> void:
		a.queue_free()
		_show_dossier_hub())


func _show_coop() -> void:
	_in_difficulty = true
	_clear_box()
	_box.add_child(UiKit.label(Loc.t(&"coop.title"), 22))

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 48)
	_box.add_child(cols)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.custom_minimum_size = Vector2(436, 0)
	cols.add_child(left)

	var right_panel := UiKit.panel(Color(0.02, 0.03, 0.05, 0.6))
	right_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cols.add_child(right_panel)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 18)
	right.custom_minimum_size = Vector2(460, 0)
	right_panel.add_child(right)
	right.add_child(_desc(&"coop.desc"))

	var night_row := HBoxContainer.new()
	night_row.add_theme_constant_override("separation", 10)
	night_row.add_child(UiKit.label(Loc.t(&"coop.night"), 18))
	var night_pick := OptionButton.new()
	for n in range(1, Net.LAST_NIGHT + 1):
		night_pick.add_item(Loc.t(&"coop.night_n", [n]), n)
	night_pick.select(Net.saved_night() - 1)
	night_pick.custom_minimum_size = Vector2(200, 40)
	night_row.add_child(night_pick)
	left.add_child(night_row)

	var night_of := func() -> int: return night_pick.get_selected_id()
	var status := _desc(&"coop.idle_rooms" if Net.rooms_available() else &"coop.idle")
	var code_out := LineEdit.new()
	code_out.editable = false
	code_out.visible = false
	code_out.custom_minimum_size = Vector2(380, 44)
	var first: Button
	if Net.rooms_available():
		first = UiKit.button(Loc.t(&"coop.host_room"), func() -> void: Net.host_room(night_of.call()))
		left.add_child(first)
		left.add_child(code_out)
		var code_in := LineEdit.new()
		code_in.placeholder_text = Loc.t(&"coop.code_hint")
		code_in.custom_minimum_size = Vector2(380, 44)
		left.add_child(code_in)
		left.add_child(UiKit.button(Loc.t(&"coop.join_room"), func() -> void: Net.join_room(code_in.text)))

	var ip_box := VBoxContainer.new()
	ip_box.add_theme_constant_override("separation", 12)
	var host_btn := UiKit.button(Loc.t(&"coop.host"), func() -> void: Net.host(night_of.call()))
	ip_box.add_child(host_btn)
	var addr := LineEdit.new()
	addr.placeholder_text = Loc.t(&"coop.addr_hint")
	addr.custom_minimum_size = Vector2(380, 44)
	ip_box.add_child(addr)
	ip_box.add_child(UiKit.button(Loc.t(&"coop.join"), func() -> void: Net.join(addr.text)))
	if first == null:
		first = host_btn
	else:
		ip_box.visible = false
		left.add_child(UiKit.button(Loc.t(&"coop.or_ip"), func() -> void: ip_box.visible = not ip_box.visible))
	left.add_child(ip_box)
	right.add_child(status)
	left.add_child(UiKit.button(Loc.t(&"ui.back"), func() -> void:
		Net.leave()
		_show_main()))
	var on_status := func(t: String) -> void:
		if is_instance_valid(status):
			status.text = t
	var on_code := func(c: String) -> void:
		if is_instance_valid(code_out):
			code_out.text = c
			code_out.visible = true
			DisplayServer.clipboard_set(c)
	Net.status.connect(on_status)
	Net.room_code.connect(on_code)
	status.tree_exiting.connect(func() -> void:
		if Net.status.is_connected(on_status):
			Net.status.disconnect(on_status)
		if Net.room_code.is_connected(on_code):
			Net.room_code.disconnect(on_code))
	first.grab_focus.call_deferred()


func _desc(key: StringName) -> Label:
	var l := UiKit.label(Loc.t(key), 14)
	l.modulate = Color(1, 1, 1, 0.65)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
