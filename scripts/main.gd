extends Node
## Корень игры: главное меню ↔ фазы (пролог, дни, ночи). Сохранение — в начале каждой фазы.

## День → места, которые с него появляются на схеме (и леера к ним).
const UNLOCKS := {2: ["izba"], 3: ["repeater"], 4: ["lake"], 5: ["bunker"], 6: ["zimnik"]}

var _menu: MainMenu
var _session: Session


func _ready() -> void:
	Perf.mark("main ready")
	Creatures.warmup()
	Perf.mark("creatures warmup")
	var all_cmd_args: Array = OS.get_cmdline_user_args() + OS.get_cmdline_args()
	if all_cmd_args.has("--preview"):
		add_child(ModelPreview.new())
		return
	if all_cmd_args.has("--arttest"):
		var art_script: GDScript = load("res://scripts/dev/art_test_taiga.gd")
		add_child(art_script.new())
		return
	if all_cmd_args.has("--epilogue"):   # отладка эпилога без прохождения (+ --eptour — автопрогон со снимками)
		Epilogue.pages = PackedStringArray(["(отладка) Лист разбора концовки."])
		_start_epilogue.call_deferred()
		if all_cmd_args.has("--eptour"):
			add_child(load("res://scripts/dev/ep_tour.gd").new())
		return
	_show_menu()
	Net.session_start.connect(_start_coop)
	var args := OS.get_cmdline_user_args()
	# Проверка коопа без меню: --coop-host / --coop-join 127.0.0.1 [--coop-test]
	Net.test_mode = args.has("--coop-test")
	if args.has("--coop-host"):
		if args.has("--coop-night") and args.size() > args.find("--coop-night") + 1:
			Net.host(int(args[args.find("--coop-night") + 1]))
		else:
			Net.host()
	elif args.has("--coop-join") and args.size() > args.find("--coop-join") + 1:
		Net.join(args[args.find("--coop-join") + 1])
	elif args.has("--coop-host-room"):
		# Проверка комнат: код пишем в user://room_code.txt — второй экземпляр его прочтёт.
		Net.room_code.connect(func(c: String) -> void:
			var f := FileAccess.open("user://room_code.txt", FileAccess.WRITE)
			f.store_string(c)
			print("[coop] код комнаты ", c))
		Net.host_room(1)
	elif args.has("--coop-join-room"):
		_test_join_room()
	if args.has("--autotest") or args.has("--deathtest") or args.has("--stage") or args.has("--inspect_fixes") or args.has("--tour") or args.has("--film") or args.has("--probe") or args.has("--probe2") or args.has("--polish_test") or all_cmd_args.has("--polish_test") or all_cmd_args.has("--autotest") or args.has("--joypad_test") or all_cmd_args.has("--joypad_test") or args.has("--test_cabin"):
		add_child(AutoTest.new())


func _test_join_room() -> void:
	for i in range(60):
		await get_tree().create_timer(0.5).timeout
		if FileAccess.file_exists("user://room_code.txt"):
			var c := FileAccess.get_file_as_string("user://room_code.txt").strip_edges()
			if c != "":
				print("[coop] подключаюсь по коду ", c)
				Net.join_room(c)
				return


func _show_menu() -> void:
	_clear()
	get_tree().paused = false
	Director.reset()
	# Фон меню — станция ночью; её системы читают конфиг ночи 1.
	Game.setup_phase(&"night", 1)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_menu = MainMenu.new()
	add_child(_menu)
	_menu.continue_pressed.connect(func() -> void:
		if SaveGame.read():
			_start_phase.call_deferred())
	_menu.new_game.connect(func(diff: String) -> void:
		SaveGame.new_game(diff)
		_start_phase.call_deferred())
	_menu.quit_pressed.connect(func() -> void:
		Settings.save()
		get_tree().quit())
	# Первый запуск: язык, потом яркость (в тёмном хорроре без неё половина «ничего не видно»,
	# половина выкручивает гамму), потом меню. Меню само пересобирается на новом языке по Settings.changed.
	var cli := OS.get_cmdline_user_args()
	if cli.has("--tour") or cli.has("--coop-host") or cli.has("--coop-join") or cli.has("--coop-host-room") or cli.has("--coop-join-room") or cli.has("--autotest"):
		return
	if cli.has("--menushot"):   # кадр главного меню для проверки/обложки: без экранов первого запуска
		if cli.has("--coopmenu"):
			_menu.call_deferred(&"_show_coop")
		_menu_shots()
		return
	_first_run_step()


func _menu_shots() -> void:
	DirAccess.make_dir_recursive_absolute("user://shots")
	for i in range(3):
		await get_tree().create_timer(6.0 if i == 0 else 20.0).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if img != null:
			img.save_png("user://shots/%02d_menu.png" % (i + 1))
	get_tree().quit()


func _first_run_step() -> void:
	if _menu == null or not is_instance_valid(_menu):
		return
	var screen: Control = null
	if not Settings.lang_chosen:
		screen = LanguagePick.new()
	elif not Settings.warned:
		screen = ContentWarning.new()
	elif not Settings.calibrated:
		screen = BrightnessCalib.new()
	if screen == null:
		_menu.grab_initial_focus()
		return
	add_child(screen)   # поверх меню (меню — раньше в списке детей)
	screen.connect(&"done", func() -> void:
		screen.queue_free()
		_first_run_step.call_deferred())


func _start_phase() -> void:
	_clear()
	Director.reset()
	var ph: Dictionary = SaveGame.phase
	var kind := StringName(String(ph["kind"]))
	var index := int(ph["index"])
	# Схема станции растёт: каждый день Семёнов «подсказывает» новое место.
	if kind == &"day":
		for site: String in UNLOCKS.get(index, []):
			Game.set_flag(site, true)
	# Чекпоинт живёт только внутри своей ночи.
	var cp: Variant = SaveGame.flags.get("cp")
	if cp is Dictionary and (kind != &"night" or int((cp as Dictionary).get("night", -1)) != index):
		SaveGame.flags.erase("cp")
	SaveGame.write()
	Game.setup_phase(kind, index)
	_session = Session.new()
	add_child(_session)
	_session.finished.connect(_on_session_finished, CONNECT_DEFERRED)


## Кооп-ночь «Две вахты»: та же ночь и то же зерно у обоих, сохранение одиночной кампании не трогаем.
## Дней в коопе нет — места, которые днём открывает Семёнов, к этой ночи уже открыты.
func _start_coop(night: int, seed: int) -> void:
	_clear()
	Director.reset()
	SaveGame.memory_only = true
	SaveGame.new_game("story")
	SaveGame.phase = {"kind": "night", "index": night}
	for d: int in UNLOCKS:
		if d < night:
			for site: String in UNLOCKS[d]:
				Game.set_flag(site, true)
	Game.forced_seed = seed
	Game.setup_phase(&"night", night)
	_session = Session.new()
	add_child(_session)
	_session.finished.connect(func(r: String) -> void: _on_coop_finished.call_deferred(r), CONNECT_DEFERRED)


## Рассвет — хост ведёт обоих в следующую ночь; погибли оба — ту же заново. Иначе — в меню.
func _on_coop_finished(result: String) -> void:
	if Net.on_local_finished(result):
		return
	_end_coop()


func _end_coop() -> void:
	Net.leave()
	Game.forced_seed = 0
	SaveGame.memory_only = false
	if SaveGame.has_save():
		SaveGame.read()
	_show_menu()


func _on_session_finished(result: String) -> void:
	match result:
		"advance":
			SaveGame.advance()
			var ph: Dictionary = SaveGame.phase
			if (String(ph["kind"]) == "night" and int(ph["index"]) > Phases.LAST_NIGHT) or (String(ph["kind"]) == "day" and int(ph["index"]) >= Phases.LAST_NIGHT):
				_show_menu()
			else:
				_start_phase()
		"retry":
			SaveGame.read()
			_start_phase()
		"epilogue":
			_start_epilogue()
		_:
			_show_menu()


## Эпилог «Свердловск, 1983» после концовки: своя сцена, по выходу — меню.
var _epilogue: Epilogue


func _start_epilogue() -> void:
	_clear()
	Director.reset()
	_epilogue = Epilogue.new()
	add_child(_epilogue)
	_epilogue.finished.connect(func() -> void:
		if _epilogue != null and is_instance_valid(_epilogue):
			_epilogue.queue_free()
		_epilogue = null
		_show_menu.call_deferred(), CONNECT_DEFERRED)


## Убирает текущую сцену сразу (а не в конце кадра), чтобы старые узлы не успели сработать.
func _clear() -> void:
	for n: Node in [_menu, _session]:
		if n != null and is_instance_valid(n):
			remove_child(n)
			n.queue_free()
	_menu = null
	_session = null
