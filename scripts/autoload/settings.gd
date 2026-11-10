extends Node
## Настройки игрока: громкость по шинам, мышь, FOV, яркость, PS1-фильтр, язык, субтитры.
## Хранятся в user://settings.cfg, применяются сразу (apply) и сохраняются при закрытии панели (save).

signal changed

const PATH := "user://settings.cfg"
const BUSES: Array[String] = ["SFX", "Ambient", "Music", "Radio", "Tape", "Weather"]
const STYLE_VERSION := 2
const PS1_SNAP := 320.0   ## было 140 — крупный снап «ломал» текстуры на больших гранях
const KEYS: Array[String] = [
	"master_volume", "sfx_volume", "music_volume", "ambient_volume", "radio_volume",
	"mouse_sens", "gamepad_sens", "invert_y", "head_bob", "fov", "brightness", "subtitle_size", "ps1_filter", "language",
	"fullscreen", "resolution", "pixelation", "show_fps", "quality", "render_scale", "auto_tuned",
	"rumble", "mic_enabled", "mic_sensitivity", "mic_threshold", "mic_device", "mic_consent", "mic_mimic",
	"toggle_breath", "toggle_sprint", "keybinds", "padbinds", "calibrated", "lang_chosen", "warned",
	"camera_shake", "reduce_flashes", "film_fx", "subtitle_bg", "auto_res", "fps_limit", "voice_mode",
]
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
## Во сколько раз мир рисуется мельче окна: 1 — без пикселизации, 4 — сильная.
const PIXEL_SHRINK: Array[int] = [1, 2, 3, 4]

var master_volume := 0.85
var sfx_volume := 1.0
var music_volume := 0.8
var ambient_volume := 1.0
var radio_volume := 1.0
var mouse_sens := 1.0
var gamepad_sens := 1.0       ## отдельный множитель для правого аналогового стика
var invert_y := false          ## инверсия вертикальной оси обзора камеры (мышь и стик)
var head_bob := 1.0           ## интенсивность покачивания камеры при ходьбе (0.0 — отключено)
var fov := 72.0
var brightness := 1.0
var subtitle_size := 22
var camera_shake := 1.0          ## доступность: сила тряски камеры (0 — без тряски)
var reduce_flashes := false      ## доступность: красные и белые вспышки приглушены
var film_fx := 1.0               ## доступность: зерно, аберрация, виньетка (0 — чистая картинка)
var subtitle_bg := false         ## доступность: тёмная подложка под субтитрами
var auto_res := false            ## динамическое разрешение: по умолчанию выключено (без замыливания)
var fps_limit := 0               ## 0 — без ограничения, иначе потолок кадров (ноутбук не греется)
var ps1_filter := false       ## дрожание вершин и дизеринг PS1 — по желанию, по умолчанию чистая картинка
var language := "ru"
var fullscreen := true
var resolution := 2          ## индекс в RESOLUTIONS, для оконного режима
var pixelation := 0          ## индекс в PIXEL_SHRINK: 0 — чёткий рендер, 1–3 — крупнее пиксель (PS1-вид)
var show_fps := false
var batching := true          ## склейка статичной геометрии (StaticBatch); выключается для сравнения в автотесте
var render_scale := 1.0       ## доля разрешения 3D-рендера (0.6–1.0); на слабых видеокартах игра снижает сама
var auto_tuned := false       ## автоподстройка под железо уже была (делается один раз, при первой ночи)
var quality := 1             ## 0 — низкое, 1 — среднее, 2 — высокое, 3 — ультра (тени дальше, 8× сглаживание, лес гуще)
var rumble := true           ## виброотдача контроллера / геймпада
var mic_enabled := false     ## захват микрофона и реакция игры на голос/шум игрока — только по явному согласию
var mic_consent := false
var padbinds := {}               ## переназначенные кнопки геймпада: действие → [тип, индекс, знак]
var mic_mimic := true          ## Ырка может звать твоим голосом (фразы — только в памяти)
var toggle_breath := false       ## дыхание: нажать вместо держать
var toggle_sprint := false       ## бег: нажать вместо держать
var lang_chosen := false         ## язык выбран на первом экране
var calibrated := false          ## калибровка яркости при первом запуске пройдена
var warned := false              ## предупреждение о содержании (первый запуск) прочитано
var keybinds := {}               ## переназначенные клавиши: действие → physical_keycode     ## игрок сам включал микрофон (v1.13 включал его без спроса — такой флаг сбрасываем)
var mic_sensitivity := 1.0   ## множитель чувствительности микрофона (0.2–5.0)
var mic_threshold := 0.16    ## порог срабатывания (шумоподавление): 0.04..0.50
var mic_device := "Default"  ## выбранное устройство записи
var voice_mode := "zas"       ## "zas" (ЗАС-шифратор «Эльбрус» и телетайп) или "classic" (голос)



func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		save()


func _ready() -> void:
	_ensure_buses()
	language = "ru" if OS.get_locale_language() == "ru" else "en"
	_load()
	apply()
	_apply_window.call_deferred()


func apply() -> void:
	_set_bus("Master", master_volume)
	_set_bus("SFX", sfx_volume)
	_set_bus("Music", music_volume)
	_set_bus("Ambient", ambient_volume)
	_set_bus("Weather", ambient_volume)
	_set_bus("Radio", radio_volume)
	_set_bus("Tape", radio_volume)
	if mic_device != "" and mic_device != "Default":
		var dev_list := AudioServer.get_input_device_list()
		if dev_list.has(mic_device):
			AudioServer.input_device = mic_device
	RenderingServer.global_shader_parameter_set(&"ps1_snap", PS1_SNAP if ps1_filter else 0.0)
	RenderingServer.global_shader_parameter_set(&"ps1_post", 1.0 if ps1_filter else 0.0)
	RenderingServer.global_shader_parameter_set(&"brightness", brightness)
	RenderingServer.global_shader_parameter_set(&"film_fx", film_fx)
	Engine.max_fps = fps_limit
	Loc.set_language(language)
	_apply_window()
	if not OS.has_feature("editor") and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED if OS.get_cmdline_user_args().has("--novsync") else DisplayServer.VSYNC_ENABLED)
	changed.emit()


## Множитель «тяжёлых» вещей по пресету: густота леса, число частиц.
func detail() -> float:
	return [0.55, 0.8, 1.0, 1.2][clampi(quality, 0, 3)]


func msaa() -> Viewport.MSAA:
	return [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_2X, Viewport.MSAA_4X][clampi(quality, 0, 3)]   # 4× на ноутбуках съедал до трети кадра


## Во сколько раз уменьшать рендер мира (SubViewportContainer.stretch_shrink).
func render_shrink() -> int:
	return PIXEL_SHRINK[clampi(pixelation, 0, PIXEL_SHRINK.size() - 1)]


func _apply_window() -> void:
	# В редакторе (игра часто встроена в его окно) и без экрана окно не трогаем.
	if OS.has_feature("editor") or DisplayServer.get_name() == "headless":
		return
	if fullscreen:
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var size := RESOLUTIONS[clampi(resolution, 0, RESOLUTIONS.size() - 1)]
	var screen := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	size = Vector2i(mini(size.x, screen.size.x), mini(size.y, screen.size.y))
	if DisplayServer.window_get_size() != size:
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)


func save() -> void:
	var cfg := ConfigFile.new()
	for k in KEYS:
		cfg.set_value("settings", k, get(k))
	cfg.set_value("settings", "style", STYLE_VERSION)
	var err := cfg.save(PATH)
	if err == OK:
		print("[Settings] Сохранено в %s" % PATH)
	else:
		push_warning("[Settings] Ошибка сохранения в %s (код %d)" % [PATH, err])


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for k in KEYS:
		if cfg.has_section_key("settings", k):
			set(k, cfg.get_value("settings", k))
	# v1.8: игра сменила вид на чёткий стилизованный — старые сохранённые PS1-настройки сбрасываем один раз.
	if int(cfg.get_value("settings", "style", 1)) < STYLE_VERSION:
		pixelation = 0
		ps1_filter = false
	if not Loc.LANGS.has(language):
		language = "ru"
	# v1.13 включал микрофон по умолчанию. Без явного согласия игрока — выключаем.
	if mic_enabled and not mic_consent:
		mic_enabled = false
	print("[Settings] Загружено из %s" % PATH)


func _set_bus(bus_name: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(idx, value <= 0.001)


## Шины создаются кодом, чтобы не зависеть от default_bus_layout.tres.
func _ensure_buses() -> void:
	# Общий лимитер: крик и удары не перегружают, а громкие места не «звенят».
	if AudioServer.get_bus_effect_count(0) == 0:
		# Мягкий прозрачный компрессор: сдерживает пиковые перегрузки (выстрел ракетницы, визг, удар),
		# сохраняя динамический диапазон между тишиной избы и рёвом бурана.
		var comp := AudioEffectCompressor.new()
		comp.threshold = -12.0
		comp.ratio = 2.5
		comp.attack_us = 5000.0
		comp.release_ms = 180.0
		comp.gain = 0.5
		AudioServer.add_bus_effect(0, comp, 0)
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -1.0
		lim.pre_gain_db = 0.0
		AudioServer.add_bus_effect(0, lim, 1)
		var m_lp := AudioEffectLowPassFilter.new()
		m_lp.cutoff_hz = 20000.0
		AudioServer.add_bus_effect(0, m_lp, 2)
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
		if bus_name == "Radio":
			# Эфир: полосовой фильтр связного диапазона 260..3400 Гц и вещательная компрессия
			var hp := AudioEffectHighPassFilter.new()
			hp.cutoff_hz = 260.0
			AudioServer.add_bus_effect(idx, hp, 0)
			var lp := AudioEffectLowPassFilter.new()
			lp.cutoff_hz = 3400.0
			AudioServer.add_bus_effect(idx, lp, 1)
			var comp := AudioEffectCompressor.new()
			comp.threshold = -15.0
			comp.ratio = 3.2
			comp.attack_us = 2500.0
			comp.release_ms = 140.0
			comp.gain = 1.0
			AudioServer.add_bus_effect(idx, comp, 2)
		if bus_name == "SFX":
			var lp2 := AudioEffectLowPassFilter.new()
			lp2.cutoff_hz = 14000.0
			AudioServer.add_bus_effect(idx, lp2, 0)
		if bus_name == "Tape":
			# Магнитофон чистит плёнку настоящими фильтрами: срез низов, срез верхов, аналоговая сатурация
			var hp_t := AudioEffectHighPassFilter.new()
			hp_t.cutoff_hz = 180.0
			AudioServer.add_bus_effect(idx, hp_t, 0)
			var lp_t := AudioEffectLowPassFilter.new()
			lp_t.cutoff_hz = 6500.0
			AudioServer.add_bus_effect(idx, lp_t, 1)
			var comp_t := AudioEffectCompressor.new()
			comp_t.threshold = -12.0
			comp_t.ratio = 2.2
			comp_t.gain = 0.8
			AudioServer.add_bus_effect(idx, comp_t, 2)
		if bus_name == "Weather":
			# Внешняя метель: динамическая окклюзия при входе в дом + срез инфразвука
			var lpw := AudioEffectLowPassFilter.new()
			lpw.cutoff_hz = 20000.0
			AudioServer.add_bus_effect(idx, lpw, 0)
			var hpw := AudioEffectHighPassFilter.new()
			hpw.cutoff_hz = 35.0
			AudioServer.add_bus_effect(idx, hpw, 1)
		if bus_name == "Ambient":
			var hpa := AudioEffectHighPassFilter.new()
			hpa.cutoff_hz = 35.0
			AudioServer.add_bus_effect(idx, hpa, 0)
