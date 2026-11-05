class_name MainMenu
extends Control
## Главное меню на живом фоне: станция в метель, мигает огонь мачты, трещит рация.

signal continue_pressed
signal new_game(difficulty: String)
signal new_shift
signal quit_pressed

const POST_SHADER := "res://assets/shaders/ps1_post.gdshader"

var _box: VBoxContainer
var _ui: Control
var _backdrop: MenuBackdrop
var _lang := ""
var _container: SubViewportContainer


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var container := SubViewportContainer.new()
	_container = container
	container.stretch = true
	container.stretch_shrink = Settings.render_shrink()
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var post := ShaderMaterial.new()
	post.shader = load(POST_SHADER)
	container.material = post
	UiKit.place(self, container, 0, 0, 1, 1, 0, 0, 0, 0)
	var vp := SubViewport.new()
	container.add_child(vp)
	_backdrop = MenuBackdrop.new()
	vp.add_child(_backdrop)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(self, shade, 0, 0, 0.45, 1, 0, 0, 0, 0)

	_ui = Control.new()
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(self, _ui, 0, 0, 1, 1, 0, 0, 0, 0)
	Settings.changed.connect(_on_settings_changed)
	_start_menu_music()
	_rebuild()


var _music: AudioStreamPlayer

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


func _exit_tree() -> void:
	if _music != null:
		_music.stop()
		_music.queue_free()
		_music = null



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
	var title := UiKit.label(Loc.t(&"menu.title"), 72)
	title.add_theme_color_override("font_color", UiKit.AMBER)
	UiKit.place(_ui, title, 0, 0, 0, 0, 80, 90, 700, 180)
	var sub := UiKit.label(Loc.t(&"menu.subtitle"), 18)
	sub.modulate = Color(1, 1, 1, 0.7)
	UiKit.place(_ui, sub, 0, 0, 0, 0, 84, 180, 700, 210)
	_show_main()
	var ver := UiKit.label("v" + String(ProjectSettings.get_setting("application/config/version", "")) + "  ·  " + Loc.t(&"menu.demo_tag"), 12)
	ver.modulate = Color(1, 1, 1, 0.45)
	UiKit.place(_ui, ver, 0, 1, 0, 1, 20, -30, 900, -10)


var _in_difficulty := false


func _show_main() -> void:
	_in_difficulty = false
	_clear_box()
	if SaveGame.has_save():
		var cont := UiKit.button(Loc.t(&"menu.continue"), func() -> void:
			stop_music()
			continue_pressed.emit())
		_box.add_child(cont)
		cont.grab_focus.call_deferred()
	var new_btn := UiKit.button(Loc.t(&"menu.new"), _show_difficulty)
	if Achievements.has(&"seven"):
		# После финала: «скоро прибудет новый сотрудник» — это ты. В одной строке с «Новой игрой».
		var nrow := HBoxContainer.new()
		nrow.add_theme_constant_override("separation", 8)
		_box.add_child(nrow)
		var ns := UiKit.button(Loc.t(&"menu.new_shift"), func() -> void:
			stop_music()
			new_shift.emit())
		for bt: Button in [new_btn, ns]:
			bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nrow.add_child(bt)
	else:
		_box.add_child(new_btn)
	if not SaveGame.has_save():
		new_btn.grab_focus.call_deferred()
	_box.add_child(UiKit.button(Loc.t(&"menu.coop"), _show_coop))
	_box.add_child(UiKit.button(Loc.t(&"menu.settings"), _show_settings))
	_box.add_child(UiKit.button(Loc.t(&"menu.controls"), _show_controls))
	_box.add_child(UiKit.button(Loc.t(&"menu.archive"), _show_archive))
	var row := HBoxContainer.new()   # две кнопки в строку — меню влезает в 720p
	row.add_theme_constant_override("separation", 8)
	_box.add_child(row)
	for bt: Button in [UiKit.button(Loc.t(&"menu.achievements"), _show_achievements), UiKit.button(Loc.t(&"menu.credits"), show_credits)]:
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bt)
	_box.add_child(UiKit.button(Loc.t(&"menu.quit"), func() -> void: quit_pressed.emit()))
	var warn := UiKit.label(Loc.t(&"menu.warning"), 13)
	warn.modulate = Color(1, 1, 1, 0.5)
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(warn)
	grab_initial_focus.call_deferred()


func grab_initial_focus() -> void:
	if _box != null and is_inside_tree():
		for c in _box.get_children():
			if c is Button and c.visible and c.is_inside_tree():
				c.grab_focus()
				return


func _show_difficulty() -> void:
	_in_difficulty = true
	_clear_box()
	_box.add_child(UiKit.label(Loc.t(&"menu.choose_diff"), 20))
	var story_btn := UiKit.button(Loc.t(&"diff.story"), func() -> void:
		stop_music()
		new_game.emit("story"))
	_box.add_child(story_btn)
	story_btn.grab_focus.call_deferred()
	_box.add_child(_desc(&"diff.story_desc"))
	_box.add_child(UiKit.button(Loc.t(&"diff.hard"), func() -> void:
		stop_music()
		new_game.emit("hard")))
	_box.add_child(_desc(&"diff.hard_desc"))
	if SaveGame.has_save():
		_box.add_child(_desc(&"menu.overwrite"))
	_box.add_child(UiKit.button(Loc.t(&"ui.back"), _show_main))


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
	UiKit.place(_ui, p, 0, 0, 0, 0, 80, 200, 900, 690)
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
		_show_main())


func show_credits() -> void:
	if _box != null:
		_box.queue_free()
		_box = null
	var c := CreditsUI.new()
	UiKit.place(_ui, c, 0, 0, 1, 1, 0, 0, 0, 0)
	c.closed.connect(func() -> void:
		c.queue_free()
		_show_main())


func _show_achievements() -> void:
	if _box != null:
		_box.queue_free()
		_box = null
	var a := AchievementsUI.new()
	UiKit.place(_ui, a, 0, 0, 1, 1, 0, 0, 0, 0)
	a.closed.connect(func() -> void:
		a.queue_free()
		_show_main())


func _show_archive() -> void:
	if _box != null:
		_box.queue_free()
		_box = null
	var a := ArchiveUI.new()
	UiKit.place(_ui, a, 0, 0, 1, 1, 0, 0, 0, 0)
	a.closed.connect(func() -> void:
		a.queue_free()
		_show_main())


## «Две вахты»: создать (ты в доме) или подключиться (ты снаружи) — по коду комнаты или по адресу.
## Хост выбирает ночь кооп-кампании; после рассвета оба переходят к следующей.
func _show_coop() -> void:
	_in_difficulty = true   # Esc — назад
	_clear_box()
	_box.add_child(UiKit.label(Loc.t(&"coop.title"), 22))
	# Две колонки: слева — ночь и подключение, справа — описание и статус (иначе не влезает в 720p).
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
	# Ночь: продолжить кампанию или выбрать любую
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
	# По адресу (одна сеть, Radmin VPN / ZeroTier). Если есть комнаты — спрятано под кнопкой.
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


func _clear_box() -> void:
	if _box != null:
		_box.queue_free()
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	UiKit.place(_ui, _box, 0, 0, 0, 0, 84, 250, 520, 700)


func _desc(key: StringName) -> Label:
	var l := UiKit.label(Loc.t(key), 14)
	l.modulate = Color(1, 1, 1, 0.65)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
