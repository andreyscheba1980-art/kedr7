class_name MeteorFaxUI
extends Control
## Советский приёмо-регистрирующий фототелеграфный аппарат «Нева-МТ» (ИСЗ «Метеор-2»):
## Воспроизводит аутентичную электрохимическую термопечать на рулонной бумаге:
## построчная протяжка термоголовки, 16 квантованных градаций серого, горизонтальный дрейф строк,
## вихревая деформация облачных масс (FBM domain warping), калибровочный клин и ИК-спектр.

signal closed

const FAX_SFX := "res://assets/audio/carrier_loop.ogg"
const TICK_SFX := "res://assets/audio/ui_tick.ogg"   # одиночный щелчок: clock_tick зациклен (настенные часы)
const CLANK_SFX := "res://assets/audio/clank.ogg"
const FAX_SHADER := "res://assets/shaders/meteor_fax.gdshader"

const TEX_W := 320
const TEX_H := 240

var _fax_mat: ShaderMaterial
var _cloud_tex: ImageTexture
var _paper_rect: TextureRect

var _print_tween: Tween
var _ir_mode := false

var _fax_player: AudioStreamPlayer
var _tick_timer := 0.0

var _info_label: Label
var _btn_ir: Button
var _btn_print: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Засчитываем снятие метеоданных со спутника для журнала ТМ-1
	Game.readings[&"meteor"] = true

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	UiKit.place(self, dim, 0, 0, 1, 1, 0, 0, 0, 0)

	# Корпус терминала «Нева-МТ» (молотковая серая эмаль со стальной окантовкой)
	var panel := UiKit.panel()
	UiKit.place(self, panel, 0.5, 0.5, 0.5, 0.5, -480, -320, 480, 320)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	panel.add_child(root_vbox)

	# Заголовок терминала
	var top_bar := HBoxContainer.new()
	root_vbox.add_child(top_bar)

	top_bar.add_child(UiStyle.brass_plate(Loc.p("ИСЗ «МЕТЕОР-2» • ФОТОТЕЛЕГРАФ «НЕВА-МТ»", "«METEOR-2» SATELLITE • «NEVA-MT» PHOTOTELEGRAPH"), 17))

	top_bar.add_spacer(false)
	var close_btn := UiKit.button(Loc.t(&"ui.close"), _close)
	top_bar.add_child(close_btn)
	close_btn.grab_focus.call_deferred()

	var sub := UiKit.label(Loc.p("ГОСКОМГИДРОМЕТ СССР • ВИТОК 1482 • 18:40 МСК • КВАДРАТ 72-СВ (СЕВЕРНЫЙ УРАЛ)", "USSR HYDROMET • ORBIT 1482 • 18:40 MSK • SQUARE 72-NE (NORTHERN URALS)"), 12)
	sub.modulate = Color(1, 1, 1, 0.65)
	root_vbox.add_child(sub)

	# Окно лентопротяжного барабана фототелеграфа
	var drum_frame := PanelContainer.new()
	drum_frame.custom_minimum_size = Vector2(920, 450)
	var drum_sb := StyleBoxFlat.new()
	drum_sb.bg_color = Color(0.06, 0.07, 0.06)
	drum_sb.border_color = Color(0.35, 0.38, 0.32)
	drum_sb.set_border_width_all(2)
	drum_frame.add_theme_stylebox_override("panel", drum_sb)
	root_vbox.add_child(drum_frame)

	# Генерация текстуры облачного вихря (FBM шум + domain warp)
	_generate_cloud_texture()

	# Центрирующий контейнер с точным соотношением сторон 4:3
	var aspect_box := AspectRatioContainer.new()
	aspect_box.ratio = float(TEX_W) / float(TEX_H)
	aspect_box.alignment_horizontal = AspectRatioContainer.ALIGNMENT_CENTER
	aspect_box.alignment_vertical = AspectRatioContainer.ALIGNMENT_CENTER
	aspect_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aspect_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drum_frame.add_child(aspect_box)

	# Шейдерный просмотрщик термопечати
	_paper_rect = TextureRect.new()
	_paper_rect.texture = _cloud_tex
	_paper_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_paper_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_paper_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_paper_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paper_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_fax_mat = ShaderMaterial.new()
	_fax_mat.shader = load(FAX_SHADER)
	_fax_mat.set_shader_parameter("progress", 1.0)
	_fax_mat.set_shader_parameter("levels", 16.0)
	_fax_mat.set_shader_parameter("noise_amt", 0.08)
	_fax_mat.set_shader_parameter("jitter", 0.003)
	_fax_mat.set_shader_parameter("ir_mode", false)

	_paper_rect.material = _fax_mat
	aspect_box.add_child(_paper_rect)

	# Нижняя панель управления и телеметрии
	var bot_box := HBoxContainer.new()
	bot_box.add_theme_constant_override("separation", 14)
	root_vbox.add_child(bot_box)

	_info_label = UiKit.label("", 12)
	_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bot_box.add_child(_info_label)

	_btn_ir = UiKit.button(Loc.p("СПЕКТР: ВИДИМЫЙ", "SPECTRUM: VISIBLE"), _toggle_ir_mode)
	_btn_ir.custom_minimum_size = Vector2(170, 32)
	bot_box.add_child(_btn_ir)

	_btn_print = UiKit.button(Loc.p("ПРОТЯЖКА / ПЕЧАТЬ", "FEED / PRINT"), _start_print)
	_btn_print.custom_minimum_size = Vector2(170, 32)
	bot_box.add_child(_btn_print)

	# Звук радионесущей фототелетайпа
	_fax_player = AudioStreamPlayer.new()
	_fax_player.stream = AudioDirector.cached_stream(FAX_SFX)
	_fax_player.volume_db = -28.0
	_fax_player.pitch_scale = 0.88
	add_child(_fax_player)
	_fax_player.play()

	_update_info()


func _generate_cloud_texture() -> void:
	var img := Image.create(TEX_W, TEX_H, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.016
	noise.fractal_octaves = 4
	noise.seed = Game.run_seed

	var s: Synoptic = Game.synoptic
	var cyc_uv := (s.cyclone_pos * 0.5 + Vector2(0.5, 0.5)) if s != null else Vector2(0.65, 0.35)
	var cyc_center := cyc_uv * Vector2(TEX_W, TEX_H)

	var has_anomaly := (s != null and s.has_cold_spot)
	var anomaly_uv := (s.cold_spot_pos * 0.5 + Vector2(0.5, 0.5)) if s != null else Vector2(0.48, 0.28)
	var anomaly_center := anomaly_uv * Vector2(TEX_W, TEX_H)

	for y in range(TEX_H):
		for x in range(TEX_W):
			var pos := Vector2(x, y)

			# 1. Верхний калибровочный клин (строки 0..10): 16 градаций серого (ГОСТ)
			if y < 10:
				var stripe := int(float(x) / float(TEX_W) * 16.0)
				var val := float(stripe) / 15.0
				img.set_pixel(x, y, Color(val, val, val, 1.0))
				continue

			# 2. Черная служебная полоса разделения
			if y == 10 or y == 11:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 1.0))
				continue

			# 3. Вихревое закручивание координат (Domain Warping вокруг центра циклона)
			var d_vec := pos - cyc_center
			var dist := d_vec.length()
			var ang := atan2(d_vec.y, d_vec.x)

			var swirl := exp(-dist * 0.018) * 4.5
			var warped_ang := ang + swirl
			var warped_pos := cyc_center + Vector2(cos(warped_ang), sin(warped_ang)) * dist

			# 4. Фрактальный шум облачности
			var n := noise.get_noise_2dv(warped_pos) * 0.5 + 0.5

			# Структура спиральных рукавов
			var spiral_band := sin(warped_ang * 3.0 + dist * 0.06) * 0.22
			var cloud_val := clampf(n + spiral_band, 0.0, 1.0)

			# 5. Рельеф Уральского хребта (вертикальная темная полоса)
			var ridge_x := float(TEX_W) * 0.46 + sin(float(y) * 0.04) * 8.0
			var ridge_dist := absf(float(x) - ridge_x)
			if ridge_dist < 18.0:
				var ridge_shadow := (1.0 - ridge_dist / 18.0) * 0.25
				cloud_val = maxf(0.0, cloud_val - ridge_shadow)

			# 6. Аномальное пятно (холодная депрессия на снимке)
			if has_anomaly:
				var a_dist := (pos - anomaly_center).length()
				if a_dist < 16.0:
					var a_core := (1.0 - a_dist / 16.0)
					cloud_val = minf(1.0, cloud_val + a_core * 0.85)

			# 7. Отметка станции «Кедр-7» в центре (координатный крестик +)
			var st_pos := Vector2(TEX_W * 0.5, TEX_H * 0.5)
			if (absf(pos.x - st_pos.x) < 5.0 and absf(pos.y - st_pos.y) < 1.0) or (absf(pos.y - st_pos.y) < 5.0 and absf(pos.x - st_pos.x) < 1.0):
				cloud_val = 1.0 if cloud_val < 0.5 else 0.0

			img.set_pixel(x, y, Color(cloud_val, cloud_val, cloud_val, 1.0))

	_cloud_tex = ImageTexture.create_from_image(img)


func _start_print() -> void:
	if _print_tween and _print_tween.is_valid():
		_print_tween.kill()

	AudioDirector.play_raw(CLANK_SFX, -4.0)
	_fax_mat.set_shader_parameter("progress", 0.0)

	_print_tween = create_tween()
	_print_tween.tween_method(func(val: float) -> void:
		_fax_mat.set_shader_parameter("progress", val)
	, 0.0, 1.0, 2.8).set_trans(Tween.TRANS_LINEAR)


func _toggle_ir_mode() -> void:
	_ir_mode = not _ir_mode
	_fax_mat.set_shader_parameter("ir_mode", _ir_mode)
	_btn_ir.text = Loc.p("СПЕКТР: ИК-ТЕПЛОВОЙ", "SPECTRUM: THERMAL IR") if _ir_mode else Loc.p("СПЕКТР: ВИДИМЫЙ", "SPECTRUM: VISIBLE")
	AudioDirector.play_raw(TICK_SFX, -3.0)
	_update_info()


func _process(delta: float) -> void:
	# Механический стук шагового привода барабана во время печати
	if _print_tween and _print_tween.is_running():
		_tick_timer += delta
		if _tick_timer >= 0.16:
			_tick_timer = 0.0
			AudioDirector.play_raw(TICK_SFX, -16.0)


func _update_info() -> void:
	var s: Synoptic = Game.synoptic
	if s == null:
		_info_label.text = Loc.p("Связь со спутником не установлена.", "No satellite link.")
		return

	var dist := int(s.cyclone_pos.length() * 240.0)
	var speed := int(s.wind_speed * 2.2)
	var text := Loc.p("ЦИКЛОН: эпицентр в %d км, дрейф %d км/ч (азимут %d°). ", "CYCLONE: center %d km away, drifting %d km/h (azimuth %d°). ") % [dist, speed, int(s.wind_azimuth_deg)]

	if _ir_mode:
		if s.has_cold_spot:
			text += Loc.p("ИК-АНАЛИЗ: ТЕРМАЛЬНЫЙ ЭПИЦЕНТР -%d°C НАД ХРЕБТОМ. ОБНАРУЖЕНА НЕЕСТЕСТВЕННАЯ ДЕПРЕССИЯ В ТАЙГЕ!", "IR ANALYSIS: THERMAL EPICENTER -%d°C OVER THE RIDGE. UNNATURAL DEPRESSION DETECTED IN THE TAIGA!") % [int(abs(s.temp_dry) + 14)]
		else:
			text += Loc.p("ИК-АНАЛИЗ: Радиационные изотермы от -24°C до -38°C в пределах нормы.", "IR ANALYSIS: radiation isotherms from -24°C to -38°C, within normal.")
	else:
		if s.front_type == &"storm":
			text += Loc.p("ВИДИМЫЙ СПЕКТР: Сплошной арктический шквальный вал (10 баллов).", "VISIBLE: solid arctic squall line (10/10 cover).")
		elif s.front_type == &"fog":
			text += Loc.p("ВИДИМЫЙ СПЕКТР: Низкослоистый покров, переохлажденная радиационная мгла.", "VISIBLE: low stratus, supercooled radiation haze.")
		elif s.front_type == &"anomaly":
			text += Loc.p("ВИДИМЫЙ СПЕКТР: Аномальная закрутка облачности над точкой [КЕДР-7].", "VISIBLE: anomalous cloud spiral over point [KEDR-7].")
		else:
			text += Loc.p("ВИДИМЫЙ СПЕКТР: Гряда слоисто-кучевых снеговых облаков (8-9 баллов).", "VISIBLE: band of stratocumulus snow clouds (8-9/10 cover).")

	_info_label.text = text


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"drop") or event.is_action_pressed(&"pause") or event.is_action_pressed(&"interact"):
		_close()
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_toggle_ir_mode()
			return true
		elif event.keycode == KEY_ENTER:
			_start_print()
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	handle_input(event)


func _close() -> void:
	closed.emit()
