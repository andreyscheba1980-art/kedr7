class_name JournalTM1UI
extends Control
## Советский вахтенный журнал метеорологических наблюдений (Форма ТМ-1 Госкомгидромета СССР):
## Главный инструмент аналитической работы дежурного полярной станции «Кедр-7».
## Выполнен в виде аутентичного двухстраничного разворота канцелярской книги в кожаном переплете.
## Чистая эстетика советского бланка: тёмно-синие чернила, приглушённые пометки, отсутствие HUD-обводок.
## Ячейки приборов заполняются ТОЛЬКО тогда, когда дежурный реально снял замер на станции.
## После отправки радиограммы дежурный получает живой разбор сводки от диспетчера Свердловска-44.

signal closed

const STAMP_SFX := "res://assets/audio/clank.ogg"
const TICK_SFX := "res://assets/audio/ui_tick.ogg"   # одиночный щелчок: clock_tick зациклен (настенные часы)
const PAGE_SFX := "res://assets/audio/tea_sip.ogg"

const BOOK_W := 1080.0
const BOOK_H := 630.0
const PAGE_W := 496.0
const PAGE_H := 550.0

# Цветовая палитра советского канцелярского журнала
const C_LEATHER := Color(0.12, 0.14, 0.19)
const C_GOLD := Color(0.74, 0.62, 0.35)
const C_GOLD_DIM := Color(0.55, 0.45, 0.25)
const C_PAGE := Color(0.93, 0.90, 0.82)
const C_PAGE_SHADOW := Color(0.85, 0.81, 0.72)
const C_RULING := Color(0.78, 0.74, 0.64, 0.40)
const C_RIBBON := Color(0.72, 0.16, 0.16)

# Аутентичные чернила для бумаги (без обводки и теней!)
const C_INK_MAIN := Color(0.10, 0.12, 0.28)      # Печатный текст: тёмно-синие чернила
const C_INK_TITLE := Color(0.08, 0.09, 0.16)     # Заголовки таблицы: чуть темнее основного текста, без цветного акцента
const C_INK_RED := Color(0.55, 0.10, 0.10)       # Приглушённый красный для пометок и предупреждений
const C_INK_MUTED := Color(0.42, 0.40, 0.36)     # Приглушённый цвет для подсказок и не снятых замеров
const C_STAMP := Color(0.24, 0.18, 0.48, 0.60)   # Фиолетовые чернила советской гербовой печати

var _tab_shift_btn: Button
var _tab_archive_btn: Button
var _tab_notes_btn: Button
var _close_btn: Button

var _canvas: Control
var _shift_spread: Control
var _archive_spread: Control
var _notes_spread: Control
var _tab := 0

# «Замечания дежурного» (Tab 3)
var _notes_zone: StringName = &"house"
var _notes_items: VBoxContainer
var _notes_list: VBoxContainer
var _zone_btns: Dictionary = {}

# Карточки вердикта
var _verdict_cards: Dictionary = {}
var _chosen_front: StringName = &""
var _status_lbl: Label
var _submit_btn: Button
var _transmitted := false

# Анимация перелистывания страницы (низкий FPS)
var _flip_frame := 0
var _flipping := false

# Архивные дела (Tab 2)
var _archive_list_box: VBoxContainer
var _archive_doc_title: Label
var _archive_doc_meta: Label
var _archive_doc_body: Label
var _archive_doc_note: Label
var _archive_buttons: Array[Button] = []
var _active_archive_idx: int = 0


## Канцелярский стиль надписи чернилами на бумаге: без обводки, без теней, с чётким размером.
static func style_paper_label(l: Label, ink: Color, size: int) -> void:
	l.add_theme_color_override(&"font_color", ink)
	l.add_theme_constant_override(&"outline_size", 0)
	l.add_theme_constant_override(&"shadow_offset_x", 0)
	l.add_theme_constant_override(&"shadow_offset_y", 0)
	l.add_theme_font_size_override(&"font_size", size)


## Стиль кнопок на бумаге: без обводки, без теней.
static func style_paper_button(b: Button, ink: Color, size: int) -> void:
	b.add_theme_color_override(&"font_color", ink)
	b.add_theme_color_override(&"font_hover_color", ink)
	b.add_theme_color_override(&"font_pressed_color", ink)
	b.add_theme_color_override(&"font_focus_color", ink)
	b.add_theme_color_override(&"font_disabled_color", Color(ink.r, ink.g, ink.b, 0.45))
	b.add_theme_constant_override(&"outline_size", 0)
	b.add_theme_constant_override(&"shadow_offset_x", 0)
	b.add_theme_constant_override(&"shadow_offset_y", 0)
	b.add_theme_font_size_override(&"font_size", size)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# 1. Затемняющая подложка с виньеткой
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.04, 0.88)
	UiKit.place(self, dim, 0, 0, 1, 1, 0, 0, 0, 0)

	# 2. Корневой узел книги (1080x630, строго отцентрированный)
	var book_root := Control.new()
	book_root.custom_minimum_size = Vector2(BOOK_W, BOOK_H)
	book_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	UiKit.place(self, book_root, 0.5, 0.5, 0.5, 0.5, -BOOK_W * 0.5, -BOOK_H * 0.5, BOOK_W * 0.5, BOOK_H * 0.5)

	# 3. Чистая бумажная тема для документов (полное отключение HUD-обводок и теней)
	var paper_theme := Theme.new()
	paper_theme.default_font = UiStyle.type_font()
	paper_theme.set_constant("outline_size", "Label", 0)
	paper_theme.set_color("font_outline_color", "Label", Color.TRANSPARENT)
	paper_theme.set_constant("shadow_offset_x", "Label", 0)
	paper_theme.set_constant("shadow_offset_y", "Label", 0)
	paper_theme.set_color("font_shadow_color", "Label", Color.TRANSPARENT)
	paper_theme.set_constant("outline_size", "Button", 0)
	paper_theme.set_constant("shadow_offset_x", "Button", 0)
	paper_theme.set_constant("shadow_offset_y", "Button", 0)
	paper_theme.set_color("font_outline_color", "Button", Color.TRANSPARENT)
	paper_theme.set_color("font_shadow_color", "Button", Color.TRANSPARENT)
	paper_theme.set_constant("outline_size", "RichTextLabel", 0)
	paper_theme.set_constant("shadow_offset_x", "RichTextLabel", 0)
	paper_theme.set_constant("shadow_offset_y", "RichTextLabel", 0)

	# 4. Холст фоновой прорисовки (кожа, бумага, линовка, след от кружки, закладка-ляссе)
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.draw.connect(_on_draw_book)
	book_root.add_child(_canvas)

	# 5. Верхняя панель вкладок и закрытия
	var top_bar := HBoxContainer.new()
	top_bar.position = Vector2(24, 8)
	top_bar.size = Vector2(BOOK_W - 48, 38)
	top_bar.add_theme_constant_override("separation", 10)
	book_root.add_child(top_bar)

	_tab_shift_btn = _make_tab_btn(Loc.p("📘 ВАХТЕННЫЙ ЖУРНАЛ ТМ-1 [Q]", "📘 DUTY LOG TM-1 [Q]"), func() -> void: _switch_tab(0))
	_tab_archive_btn = _make_tab_btn(Loc.p("📁 АРХИВ ВАХТЫ И ДЕЛА ДЕЖУРНЫХ [E]", "📁 SHIFT ARCHIVE & DUTY FILES [E]"), func() -> void: _switch_tab(1))
	_tab_notes_btn = _make_tab_btn(Loc.t(&"anom.tab"), func() -> void: _switch_tab(2))
	top_bar.add_child(_tab_shift_btn)
	top_bar.add_child(_tab_archive_btn)
	if _notes_on():
		top_bar.add_child(_tab_notes_btn)

	top_bar.add_spacer(false)

	_close_btn = _make_close_btn()
	top_bar.add_child(_close_btn)

	# 6. Разворот Вкладки 1: Форма ТМ-1 (Левая и Правая страницы)
	_shift_spread = Control.new()
	_shift_spread.position = Vector2(0, 48)
	_shift_spread.size = Vector2(BOOK_W, PAGE_H)
	_shift_spread.theme = paper_theme
	_shift_spread.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	book_root.add_child(_shift_spread)

	_build_shift_spread()

	# 7. Разворот Вкладки 2: Архив вахты (Дела 1974-1983)
	_archive_spread = Control.new()
	_archive_spread.position = Vector2(0, 48)
	_archive_spread.size = Vector2(BOOK_W, PAGE_H)
	_archive_spread.theme = paper_theme
	_archive_spread.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_archive_spread.visible = false
	book_root.add_child(_archive_spread)
	# Архив и «Замечания» собираются при первом открытии вкладки: журнал по Q открывается без подвисания

	# 8. Разворот Вкладки 3: «Замечания дежурного» — что на станции не так
	_notes_spread = Control.new()
	_notes_spread.position = Vector2(0, 48)
	_notes_spread.size = Vector2(BOOK_W, PAGE_H)
	_notes_spread.theme = paper_theme
	_notes_spread.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_notes_spread.visible = false
	book_root.add_child(_notes_spread)

	# Фактура бумаги поверх обеих страниц (умножением: текст, линовка и штампы остаются видны)
	UiStyle.paper_mul(book_root, Rect2(24, 48, PAGE_W, PAGE_H), 2.1, 0.6)
	UiStyle.paper_mul(book_root, Rect2(BOOK_W - 24 - PAGE_W, 48, PAGE_W, PAGE_H), 5.7, 0.8)

	_switch_tab(0)


func _get_measured_count() -> int:
	var has_b: bool = Game.readings.has(&"baro")
	var has_t: bool = Game.readings.has(&"temp")
	var has_w: bool = Game.readings.has(&"wind")
	var has_s: bool = Game.readings.has(&"sv20")
	var has_m: bool = Game.readings.has(&"meteor")
	return (1 if has_b else 0) + (1 if has_t else 0) + (1 if has_w else 0) + (1 if has_s else 0) + (1 if has_m else 0)


func _compute_shift_objective() -> String:
	if not Game.power_on:
		return Loc.t(&"objective.restore_power")
	if not Game.has_readings():
		return Loc.t(&"objective.take_readings")
	var report_due := Game.is_night() and Game.reports_sent < Game.report_times().size()
	if report_due:
		return Loc.t(&"objective.send_report")
	if Game.night == 7 and Game.helipad_cleared:
		var pots := mini(int(SaveGame.flags.get("helipad_firepots_lit_count", 0)), 4)
		var psnd := 1 if bool(SaveGame.flags.get("psnd_flare_lit", false)) else 0
		return Loc.t(&"objective.evac_prep", [pots, psnd])
	return Loc.t(&"objective.await_next_shift")


# --- ОТРИСОВКА КНИГИ (КАНВАС) ------------------------------------------------

func _on_draw_book() -> void:
	# Кожаный переплёт книги
	var book_rect := Rect2(0, 0, BOOK_W, BOOK_H)
	_canvas.draw_rect(book_rect, C_LEATHER)

	# Золотое тиснение по контуру обложки
	var gold_rect := book_rect.grow(-4)
	_canvas.draw_rect(gold_rect, C_GOLD_DIM, false, 2.0)
	var gold_inner := book_rect.grow(-8)
	_canvas.draw_rect(gold_inner, C_GOLD * 0.7, false, 1.0)

	# Латунные защитные уголки книги
	_draw_corner(Vector2(4, 4), 1, 1)
	_draw_corner(Vector2(BOOK_W - 4, 4), -1, 1)
	_draw_corner(Vector2(4, BOOK_H - 4), 1, -1)
	_draw_corner(Vector2(BOOK_W - 4, BOOK_H - 4), -1, -1)

	# Левая и Правая бумажные страницы
	var page_y := 48.0
	var left_page := Rect2(24, page_y, PAGE_W, PAGE_H)
	var right_page := Rect2(BOOK_W - 24 - PAGE_W, page_y, PAGE_W, PAGE_H)

	# Тени страниц
	_canvas.draw_rect(left_page.grow(2), Color(0, 0, 0, 0.35))
	_canvas.draw_rect(right_page.grow(2), Color(0, 0, 0, 0.35))

	_canvas.draw_rect(left_page, C_PAGE)
	_canvas.draw_rect(right_page, C_PAGE)

	# Тонкая рамка страницы
	_canvas.draw_rect(left_page.grow(-4), Color(0.70, 0.65, 0.55), false, 1.0)
	_canvas.draw_rect(right_page.grow(-4), Color(0.70, 0.65, 0.55), false, 1.0)

	# Красная черта полей слева (как в конторских амбарных книгах)
	var margin_x := left_page.position.x + 32.0
	_canvas.draw_line(Vector2(margin_x, page_y + 8), Vector2(margin_x, page_y + PAGE_H - 8), Color(0.75, 0.25, 0.25, 0.45), 1.0)

	# Канцелярская разлиновка страниц
	for y: float in range(page_y + 36, page_y + PAGE_H - 20, 22.0):
		_canvas.draw_line(Vector2(left_page.position.x + 12, y), Vector2(left_page.end.x - 12, y), C_RULING, 1.0)
		_canvas.draw_line(Vector2(right_page.position.x + 12, y), Vector2(right_page.end.x - 12, y), C_RULING, 1.0)

	# Реалистичный полупрозрачный след от чайной кружки Виктора на полях (тонкий, органически неровный)
	var cup_center := Vector2(left_page.position.x + 440, page_y + 115)
	var num_pts := 40
	var cup_pts := PackedVector2Array()
	for i in range(num_pts + 1):
		var ang := float(i) * TAU / float(num_pts)
		# Естественные микронеровности ободка кружки
		var r_var := 37.0 + sin(ang * 3.0) * 0.7 + cos(ang * 5.0) * 0.4
		cup_pts.append(cup_center + Vector2(cos(ang), sin(ang)) * r_var)
	_canvas.draw_polyline(cup_pts, Color(0.48, 0.32, 0.16, 0.09), 1.2)

	# Локальный натёк чая в нижней части ободка кружки
	var tea_pool := PackedVector2Array()
	for i in range(14):
		var ang := float(i) * (PI * 0.7) / 14.0 + PI * 0.35
		var r_pool := 36.6 + sin(ang * 4.0) * 0.5
		tea_pool.append(cup_center + Vector2(cos(ang), sin(ang)) * r_pool)
	_canvas.draw_polyline(tea_pool, Color(0.45, 0.28, 0.14, 0.12), 1.0)

	# Центральный корешок / сгиб книги (тень переплёта)
	var spine_center := BOOK_W * 0.5
	var spine_shadow_w := 28.0
	_canvas.draw_rect(Rect2(spine_center - spine_shadow_w * 0.5, page_y - 4, spine_shadow_w, PAGE_H + 8), Color(0.04, 0.05, 0.06, 0.30))
	_canvas.draw_line(Vector2(spine_center, page_y - 8), Vector2(spine_center, page_y + PAGE_H + 8), Color(0.02, 0.03, 0.04, 0.65), 3.0)

	# Красная шелковая закладка-ляссе, свисающая из корешка
	var ribbon_w := 14.0
	_canvas.draw_rect(Rect2(spine_center - ribbon_w * 0.5, 12, ribbon_w, PAGE_H + 42), C_RIBBON)
	_canvas.draw_rect(Rect2(spine_center - ribbon_w * 0.5 + 2, 12, ribbon_w - 4, PAGE_H + 42), Color(0.85, 0.22, 0.22))
	# Косой срез ленты
	_canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(spine_center - ribbon_w * 0.5, PAGE_H + 54),
		Vector2(spine_center, PAGE_H + 44),
		Vector2(spine_center + ribbon_w * 0.5, PAGE_H + 54),
	]), C_RIBBON)

	# Круглый фиолетовый штамп метеостанции «КЕДР-7» (ставится ТОЛЬКО после утверждения вердикта!)
	if _transmitted or SaveGame.flags.get("forecast_day", -1) == Game.phase_index:
		var stamp_pos := Vector2(left_page.position.x + 72, left_page.end.y - 64)
		_draw_soviet_station_stamp(stamp_pos)

	# Штамп «ПЕРЕДАНО В УГКС», если радиограмма уже отправлена
	if _transmitted or SaveGame.flags.get("forecast_day", -1) == Game.phase_index:
		var trans_rect := Rect2(right_page.position.x + 120, right_page.end.y - 120, 260, 48)
		_canvas.draw_rect(trans_rect, Color(0.15, 0.35, 0.75, 0.12))
		_canvas.draw_rect(trans_rect, Color(0.15, 0.35, 0.75, 0.65), false, 2.0)
		_canvas.draw_string(UiStyle.type_font(), trans_rect.position + Vector2(18, 30), Loc.p("ПЕРЕДАНО В УГКС • 22:15 МСК", "SENT TO UGKS • 22:15 MSK"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.15, 0.35, 0.75, 0.85))

	# Анимация перелистывания страницы (3 кадра низкий FPS)
	if _flipping and _flip_frame > 0:
		var fx := float(_flip_frame) / 3.0
		var flap_w := PAGE_W * (1.0 - fx * 0.8)
		var flap_rect := Rect2(spine_center - flap_w, page_y + 10, flap_w, PAGE_H - 20)
		_canvas.draw_rect(flap_rect, Color(0.88, 0.84, 0.74, 0.85))
		_canvas.draw_line(flap_rect.position, flap_rect.position + Vector2(0, flap_rect.size.y), Color(0.4, 0.3, 0.2, 0.5), 2.0)


func _draw_soviet_station_stamp(pos: Vector2) -> void:
	# Аутентичный советский круглый фиолетовый штамп метеостанции «КЕДР-7»
	# Ставится ТОЛЬКО после отправки вердикта в УГМС!
	var stamp_col := C_STAMP
	_canvas.draw_arc(pos, 34.0, 0, TAU, 48, stamp_col, 1.4)
	_canvas.draw_arc(pos, 26.0, 0, TAU, 40, Color(stamp_col.r, stamp_col.g, stamp_col.b, stamp_col.a * 0.8), 0.8)

	var font := UiStyle.type_font()
	_canvas.draw_string(font, pos + Vector2(-24, -6), Loc.p("КЕДР-7", "KEDR-7"), HORIZONTAL_ALIGNMENT_CENTER, 48, 10, stamp_col)
	_canvas.draw_string(font, pos + Vector2(-24, 6), Loc.p("УГКС", "UGKS"), HORIZONTAL_ALIGNMENT_CENTER, 48, 10, stamp_col)
	_canvas.draw_string(font, pos + Vector2(-24, 17), "1983", HORIZONTAL_ALIGNMENT_CENTER, 48, 9, Color(stamp_col.r, stamp_col.g, stamp_col.b, stamp_col.a * 0.75))
	_canvas.draw_circle(pos + Vector2(0, -16), 1.8, stamp_col)


func _draw_corner(pos: Vector2, dx: float, dy: float) -> void:
	var pts := PackedVector2Array([
		pos,
		pos + Vector2(dx * 28, 0),
		pos + Vector2(0, dy * 28),
	])
	_canvas.draw_colored_polygon(pts, C_GOLD)
	_canvas.draw_polyline(pts, Color(0.45, 0.35, 0.15), 1.5)


# --- ПОСТРОЕНИЕ ВКЛАДКИ 1: ТЕКУЩАЯ СМЕНА ТМ-1 ---------------------------------

func _build_shift_spread() -> void:
	for c in _shift_spread.get_children():
		c.queue_free()

	var left_box := VBoxContainer.new()
	left_box.position = Vector2(38, 10)
	left_box.size = Vector2(PAGE_W - 28, PAGE_H - 20)
	left_box.add_theme_constant_override("separation", 5)
	_shift_spread.add_child(left_box)

	# Левая страница: Шапка формы ТМ-1
	var top_inst := Label.new()
	top_inst.text = Loc.p("ГОСКОМГИДРОМЕТ СССР • УГМС СЕВЕРНОГО УРАЛА", "USSR STATE HYDROMET COMMITTEE • NORTHERN URALS UGMS")
	style_paper_label(top_inst, C_INK_TITLE, 10)
	left_box.add_child(top_inst)

	var main_title := Label.new()
	main_title.text = Loc.p("ТАБЛИЦА НАБЛЮДЕНИЙ • ФОРМА ТМ-1", "OBSERVATION TABLE • FORM TM-1")
	style_paper_label(main_title, C_INK_TITLE, 16)
	left_box.add_child(main_title)

	var cur_night := Game.night if Game.is_night() else Game.phase_index
	var meta_lbl := Label.new()
	meta_lbl.text = Loc.p("Станция 2-го разряда «КЕДР-7» (Свердловск-44) • Смена №%d • Срок 22:00", "Class II station «KEDR-7» (Sverdlovsk-44) • Shift #%d • Due 22:00") % cur_night
	style_paper_label(meta_lbl, C_INK_MAIN, 12)
	left_box.add_child(meta_lbl)

	var obj_lbl := Label.new()
	obj_lbl.text = _compute_shift_objective()
	obj_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	style_paper_label(obj_lbl, C_INK_RED if not Game.power_on else C_INK_MAIN, 11)
	left_box.add_child(obj_lbl)

	left_box.add_child(_make_line(Color(0.20, 0.22, 0.35, 0.35)))

	# СНЯТЫЕ ПОКАЗАНИЯ ПРИБОРОВ (ЗАПОЛНЯЮТСЯ ТОЛЬКО ПРИ РЕАЛЬНОМ ИЗМЕРЕНИИ!)
	var s: Synoptic = Game.synoptic

	# 1. Барограф М-22
	var has_baro: bool = Game.readings.has(&"baro")
	var b_val := ""
	if has_baro and Game.notebook.has(&"baro"):
		b_val = Loc.p("%.1f мм рт. ст.  (за 3 ч %+0.1f мм)", "%.1f mmHg  (3 h %+0.1f mm)") % [float(Game.notebook[&"baro"]["v"]), float(Game.notebook[&"baro_tend"]["v"])]
	elif has_baro:
		b_val = Loc.p("%.1f мм рт. ст.  (%+0.1f мм/ч)", "%.1f mmHg  (%+0.1f mm/h)") % [s.pressure if s != null else 746.0, s.pressure_rate if s != null else -0.4]
	else:
		b_val = Loc.p("[ — — НЕ СНЯТО — — ]", "[ — — NOT TAKEN — — ]")
	var b_sub := (s.get_baro_summary() if s != null else Loc.p("Умеренный спад", "Moderate fall")) if has_baro else Loc.p("Осмотрите барограф М-22 на столе радиорубки.", "Check the M-22 barograph on the radio room desk.")
	left_box.add_child(_make_reading_row(Loc.p("1. БАРОГРАФ М-22", "1. M-22 BAROGRAPH"), b_val, b_sub, has_baro))

	# 2. Психрометрическая будка (замер в метеобудке)
	var has_temp: bool = Game.readings.has(&"temp")
	# Цифры — из книжки КМ-1, как дежурный их вписал (ошибся — ошибка и в журнале)
	var nb_dry: float = float(Game.notebook[&"temp_dry"]["v"]) if Game.notebook.has(&"temp_dry") else (s.temp_dry if s != null else -28.0)
	var nb_wet: float = float(Game.notebook[&"temp_wet"]["v"]) if Game.notebook.has(&"temp_wet") else (s.temp_wet if s != null else -30.0)
	var p_val := Loc.p("Тсух: %.1f°C  •  Твл: %.1f°C  •  Влажность: %d%%", "Dry: %.1f°C  •  Wet: %.1f°C  •  Humidity: %d%%") % [
		nb_dry,
		nb_wet,
		s.humidity if s != null else 86
	] if has_temp else Loc.p("[ — — НЕ СНЯТО — — ]", "[ — — NOT TAKEN — — ]")
	var p_sub := (s.get_psychro_summary() if s != null else Loc.p("Переохлаждение", "Supercooling")) if has_temp else Loc.p("Снимите замер термометров в метеобудке во дворе.", "Read the thermometers in the weather screen outside.")
	left_box.add_child(_make_reading_row(Loc.p("2. ПСИХРОМЕТР (БУДКА)", "2. PSYCHROMETER (SCREEN)"), p_val, p_sub, has_temp))

	# 3. Флюгер Вильда и Теодолит (замер ветра во дворе или шар-пилот)
	var has_wind: bool = Game.readings.has(&"wind")
	# Тоже из книжки КМ-1, как вписано с пульта
	var nb := Game.notebook
	var rumbs := Loc.t(&"pult.rumbs").split(",")
	var w_dir: String = rumbs[int(nb[&"wind_dir"]["v"]) % 16] if nb.has(&"wind_dir") else (s.wind_dir_name if s != null else Loc.p("С", "N"))
	var w_sp: float = float(nb[&"wind_speed"]["v"]) if nb.has(&"wind_speed") else (s.wind_speed if s != null else 8.5)
	var w_gu: float = float(nb[&"wind_gust"]["v"]) if nb.has(&"wind_gust") else (s.wind_gusts if s != null else 13.0)
	var w_val := Loc.p("%s %.1f м/с  (порывы до %.1f м/с)", "%s %.1f m/s  (gusts to %.1f m/s)") % [w_dir, w_sp, w_gu] 		if has_wind else Loc.p("[ — — НЕ СНЯТО — — ]", "[ — — NOT TAKEN — — ]")
	var w_sub := (Loc.p("Шар-пилот (1200 м): %.1f м/с • %s", "Pilot balloon (1200 m): %.1f m/s • %s") % [
		s.wind_aloft_speed if s != null else 22.0,
		s.get_wind_summary() if s != null else Loc.p("Умеренный перенос", "Moderate drift")
	]) if has_wind else Loc.p("Определите вектор и порывы ветра на метеоплощадке.", "Measure wind direction and gusts at the weather yard.")
	left_box.add_child(_make_reading_row(Loc.p("3. ФЛЮГЕР И ТЕОДОЛИТ", "3. WIND VANE & THEODOLITE"), w_val, w_sub, has_wind))

	# 4. Сейсмоприемник СВ-20 («Слухач»)
	var has_sv20: bool = Game.readings.has(&"sv20")
	var sv_val := Loc.p("%.2f мм/с²  (частота %.1f Гц)", "%.2f mm/s²  (frequency %.1f Hz)") % [
		s.seismic_amp if s != null else 0.25,
		s.seismic_freq if s != null else 14.0
	] if has_sv20 else Loc.p("[ — — НЕ СНЯТО — — ]", "[ — — NOT TAKEN — — ]")
	var sv_sub := (s.get_sv20_summary() if s != null else Loc.p("Мерзлота спокойна", "Permafrost quiet")) if has_sv20 else Loc.p("Включите сейсмоприемник СВ-20 в радиорубке.", "Switch on the SV-20 seismometer in the radio room.")
	left_box.add_child(_make_reading_row(Loc.p("4. СЕЙСМОПРИЕМНИК СВ-20", "4. SV-20 SEISMOMETER"), sv_val, sv_sub, has_sv20))

	# 5. ИСЗ «Метеор-2» (Фототелеграф)
	var has_meteor: bool = Game.readings.has(&"meteor")
	var sat_val := (Loc.p("Вихрь циклона: %s", "Cyclone eye: %s") % (s.get_satellite_summary() if s != null else Loc.p("В 135 км СВ", "135 km NE"))) if has_meteor else Loc.p("[ — — НЕ СНЯТО — — ]", "[ — — NOT TAKEN — — ]")
	var sat_sub := ((Loc.p("ИК: Тепловая аномалия зафиксирована!", "IR: thermal anomaly detected!") if (s != null and s.has_cold_spot) else Loc.p("ИК: Фоновые температуры в норме.", "IR: background temperatures normal.")) if has_meteor else Loc.p("Примите снимок на фототелетайпе «Нева-МТ».", "Receive an image on the «Neva-MT» phototelegraph."))
	left_box.add_child(_make_reading_row(Loc.p("5. ИСЗ «МЕТЕОР-2»", "5. «METEOR-2» SATELLITE"), sat_val, sat_sub, has_meteor))

	# Подвал левой страницы с рукописной подписью
	left_box.add_child(_make_line(Color(0.20, 0.22, 0.35, 0.35)))
	var sign_box := HBoxContainer.new()
	left_box.add_child(sign_box)

	var note_lbl := Label.new()
	var measured_cnt := _get_measured_count()
	note_lbl.text = Loc.p("Снято приборов: %d из 5.\nДежурный техник: В. Мальцев", "Instruments read: %d of 5.\nDuty technician: V. Maltsev") % measured_cnt
	style_paper_label(note_lbl, C_INK_MAIN, 12)
	sign_box.add_child(note_lbl)

	sign_box.add_spacer(false)

	if cur_night >= 2:
		var prop_box := PanelContainer.new()
		var psb := StyleBoxFlat.new()
		psb.bg_color = Color(0.15, 0.22, 0.45, 0.08)
		psb.border_color = Color(0.20, 0.30, 0.60, 0.35)
		psb.set_border_width_all(1)
		psb.content_margin_left = 8
		psb.content_margin_right = 8
		psb.content_margin_top = 4
		psb.content_margin_bottom = 4
		prop_box.add_theme_stylebox_override("panel", psb)
		var pl := Label.new()
		pl.text = "✍ " + Loc.t(&"tm1.prophecy_2")
		pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		style_paper_label(pl, Color(0.12, 0.16, 0.42), 11)
		prop_box.add_child(pl)
		left_box.add_child(prop_box)

	var is_sent: bool = (SaveGame.flags.get("forecast_day", -1) == Game.phase_index)
	_transmitted = is_sent

	var stamp_txt := Label.new()
	if _transmitted or is_sent:
		stamp_txt.text = Loc.p("[ КЕДР-7 • ТМ-1\n  СМЕНА СДАНА ]", "[ KEDR-7 • TM-1\n  SHIFT CLOSED ]")
		style_paper_label(stamp_txt, C_STAMP, 12)
	else:
		stamp_txt.text = Loc.p("[ КЕДР-7 • ТМ-1\n  ВАХТА ОТКРЫТА ]", "[ KEDR-7 • TM-1\n  SHIFT OPEN ]")
		style_paper_label(stamp_txt, C_INK_MUTED, 12)
	sign_box.add_child(stamp_txt)

	# --- ПРАВАЯ СТРАНИЦА: СИНОПТИЧЕСКИЙ ДИАГНОЗ И РЕГЛАМЕНТ ---
	var right_box := VBoxContainer.new()
	right_box.position = Vector2(BOOK_W - 24 - PAGE_W + 14, 10)
	right_box.size = Vector2(PAGE_W - 28, PAGE_H - 20)
	right_box.add_theme_constant_override("separation", 6)
	_shift_spread.add_child(right_box)

	var diag_title := Label.new()
	diag_title.text = Loc.p("СИНОПТИЧЕСКИЙ ДИАГНОЗ И РЕГЛАМЕНТ", "SYNOPTIC DIAGNOSIS & PROCEDURE")
	style_paper_label(diag_title, C_INK_TITLE, 16)
	right_box.add_child(diag_title)

	var diag_sub := Label.new()
	if measured_cnt == 0 and not (_transmitted or is_sent):
		diag_sub.text = Loc.p("Внимание: для постановки диагноза требуются замеры (снято 0 из 5).", "Note: a diagnosis needs readings (0 of 5 taken).")
		style_paper_label(diag_sub, C_INK_RED, 12)
	else:
		diag_sub.text = Loc.p("Сопоставьте снятые данные (%d из 5) и выберите регламент защиты:", "Compare the readings (%d of 5) and choose a protection procedure:") % measured_cnt
		style_paper_label(diag_sub, C_INK_MAIN, 12)
	diag_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_box.add_child(diag_sub)

	right_box.add_child(_make_line(Color(0.20, 0.22, 0.35, 0.35)))

	# Карточки 4 вердиктов
	_verdict_cards[&"blizzard"] = _make_verdict_card(
		right_box, &"blizzard",
		Loc.p("❄ НИЗОВАЯ МЕТЕЛЬ (БУРАН)", "❄ GROUND BLIZZARD (BURAN)"),
		Loc.p("Ветер 8–14 м/с, умеренный спад давления. Снеговой вал.", "Wind 8–14 m/s, moderate pressure fall. Snow bank."),
		Loc.p("Регламент: Штатный обогрев печи, контроль термометров.", "Procedure: normal stove heating, watch the thermometers.")
	)

	_verdict_cards[&"storm"] = _make_verdict_card(
		right_box, &"storm",
		Loc.p("🌪 АРКТИЧЕСКИЙ ШКВАЛ (ШТОРМ)", "🌪 ARCTIC SQUALL (STORM)"),
		Loc.p("Барический обвал >1.5 мм/ч, ветер до 26 м/с.", "Pressure collapse >1.5 mm/h, wind up to 26 m/s."),
		Loc.p("Регламент: Защита дымохода, затяжка растяжек мачты.", "Procedure: protect the chimney, tighten the mast guys.")
	)

	_verdict_cards[&"fog"] = _make_verdict_card(
		right_box, &"fog",
		Loc.p("🌫 РАДИАЦИОННЫЙ ТУМАН (МГЛА)", "🌫 RADIATION FOG (HAZE)"),
		Loc.p("Штиль (<2 м/с), влажность 100%, переохлажденная мгла.", "Calm (<2 m/s), humidity 100%, supercooled haze."),
		Loc.p("Регламент: Включение сигнального штормового маяка.", "Procedure: switch on the storm beacon.")
	)

	_verdict_cards[&"anomaly"] = _make_verdict_card(
		right_box, &"anomaly",
		Loc.p("⚡ ГЕОФИЗИЧЕСКАЯ АНОМАЛИЯ", "⚡ GEOPHYSICAL ANOMALY"),
		Loc.p("Рокот мерзлоты >1.2 мм/с², скачок давления, ИК-пятно ИСЗ.", "Permafrost rumble >1.2 mm/s², pressure jump, satellite IR spot."),
		Loc.p("Регламент: Запуск зуммера СВ-20, блокировка задвижек.", "Procedure: start the SV-20 buzzer, lock the bolts.")
	)

	# Инициализация выбора:
	# Если радиограмма уже передана в этот день — восстанавливаем выбор.
	# Если нет — выбор НЕ навязывается по умолчанию (пустое значение).
	if is_sent:
		var saved_choice: String = String(SaveGame.flags.get("forecast_choice", ""))
		if not saved_choice.is_empty():
			_chosen_front = StringName(saved_choice)
	else:
		_chosen_front = &""

	right_box.add_child(_make_line(Color(0.20, 0.22, 0.35, 0.35)))

	# Кнопка утверждения и отправки
	_submit_btn = Button.new()
	_submit_btn.custom_minimum_size = Vector2(PAGE_W - 28, 42)
	_submit_btn.pressed.connect(_submit_verdict)
	_style_submit_btn(_submit_btn)
	right_box.add_child(_submit_btn)

	_status_lbl = Label.new()
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	style_paper_label(_status_lbl, C_INK_MAIN, 12)
	right_box.add_child(_status_lbl)

	_update_card_styles()


# --- ПОСТРОЕНИЕ ВКЛАДКИ 2: АРХИВ ВАХТЫ ----------------------------------------

func _build_archive_spread() -> void:
	for c in _archive_spread.get_children():
		c.queue_free()

	# Левая страница: Список архивных дел
	var left_box := VBoxContainer.new()
	left_box.position = Vector2(38, 10)
	left_box.size = Vector2(PAGE_W - 28, PAGE_H - 20)
	left_box.add_theme_constant_override("separation", 6)
	_archive_spread.add_child(left_box)

	var arch_title := Label.new()
	arch_title.text = Loc.p("АРХИВ СЛУЖЕБНЫХ ДЕЛ СТАНЦИИ", "STATION SERVICE FILES ARCHIVE")
	style_paper_label(arch_title, C_INK_TITLE, 16)
	left_box.add_child(arch_title)

	var arch_sub := Label.new()
	arch_sub.text = Loc.p("Материалы наблюдений и происшествий (1974–1983 гг.):", "Observation and incident records (1974–1983):")
	style_paper_label(arch_sub, C_INK_MAIN, 12)
	arch_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_box.add_child(arch_sub)

	left_box.add_child(_make_line(Color(0.20, 0.22, 0.35, 0.35)))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_box.add_child(scroll)

	_archive_list_box = VBoxContainer.new()
	_archive_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_archive_list_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_archive_list_box)

	# Правая страница: Подробный просмотр выбранного дела
	var right_box := VBoxContainer.new()
	right_box.position = Vector2(BOOK_W - 24 - PAGE_W + 14, 10)
	right_box.size = Vector2(PAGE_W - 28, PAGE_H - 20)
	right_box.add_theme_constant_override("separation", 8)
	_archive_spread.add_child(right_box)

	_archive_doc_title = Label.new()
	_archive_doc_title.text = Loc.p("СЛУЖЕБНАЯ ЗАПИСКА ДЕЖУРНОГО", "DUTY OFFICER'S MEMO")
	style_paper_label(_archive_doc_title, C_INK_TITLE, 16)
	right_box.add_child(_archive_doc_title)

	_archive_doc_meta = Label.new()
	_archive_doc_meta.text = Loc.p("Дата и автор документа", "Document date and author")
	style_paper_label(_archive_doc_meta, C_INK_MAIN, 12)
	right_box.add_child(_archive_doc_meta)

	right_box.add_child(_make_line(Color(0.20, 0.22, 0.35, 0.35)))

	var doc_scroll := ScrollContainer.new()
	doc_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	doc_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_box.add_child(doc_scroll)

	var doc_vbox := VBoxContainer.new()
	doc_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	doc_vbox.add_theme_constant_override("separation", 10)
	doc_scroll.add_child(doc_vbox)

	_archive_doc_body = Label.new()
	_archive_doc_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	style_paper_label(_archive_doc_body, C_INK_MAIN, 14)
	doc_vbox.add_child(_archive_doc_body)

	_archive_doc_note = Label.new()
	_archive_doc_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	style_paper_label(_archive_doc_note, C_INK_RED, 12)
	doc_vbox.add_child(_archive_doc_note)

	_populate_archive_entries()


func _populate_archive_entries() -> void:
	for c in _archive_list_box.get_children():
		c.queue_free()
	_archive_buttons.clear()

	var entries: Array[Dictionary] = [
		{
			"date": Loc.p("14 ноября 1974 г.", "14 November 1974"),
			"author": Loc.p("Техник-метеоролог Брагин (вахта 1974)", "Meteorological technician Bragin (1974 shift)"),
			"title": Loc.p("ДЕЛО №74-Б: АНОМАЛИЯ БАРОГРАФА", "FILE #74-B: BAROGRAPH ANOMALY"),
			"body": Loc.p("«Барограф М-22 вычертил глубокий зубец -9 мм рт. ст. за 15 минут при полном штиле флюгера. Такого градиента в природе не бывает. На чердаке пахнет свежим озоном, будто рядом прошёл грозовой разряд.\n\nВ тайге мерзлота дрожит на частоте 12 Гц. Забил все рамы нагелями. Не верьте шагам за дверью.»", "\"The M-22 barograph drew a deep notch of -9 mmHg in 15 minutes with the wind vane dead still. No such gradient exists in nature. The attic smells of fresh ozone, as if lightning struck nearby.\n\nThe permafrost in the taiga trembles at 12 Hz. I've pegged every window frame shut. Don't trust the footsteps behind the door.\""),
			"note": Loc.p("Особая отметка: лист надорван, следы застывшего стеарина свечи.", "Special note: page torn, traces of hardened candle wax.")
		},
		{
			"date": Loc.p("21 ноября 1978 г.", "21 November 1978"),
			"author": Loc.p("Техник-метеоролог Пастухов (вахта 1978)", "Meteorological technician Pastukhov (1978 shift)"),
			"title": Loc.p("ДЕЛО №78-П: СПУТНИКОВОЕ ТЕПЛОВОЕ ПЯТНО", "FILE #78-P: SATELLITE THERMAL SPOT"),
			"body": Loc.p("«Фототелеграф со спутника „Метеор“ выдал тепловую полосу -68°C прямо над гребнем в 25 км к северу. Пятно смещается против розы ветров, прямо в сторону станции.\n\nНе открывайте дверь на зов. Звук голоса снаружи — не человеческий, а подражание мембране громкоговорителя.»", "\"The Meteor satellite phototelegraph printed a -68°C thermal band right over the ridge 25 km to the north. The spot is moving against the wind rose, straight toward the station.\n\nDo not open the door when called. The voice outside is not human — it imitates a loudspeaker membrane.\""),
			"note": Loc.p("Резолюция УГМС: дежурному Пастухову объявлен строгий выговор за мистицизм.", "UGMS resolution: duty officer Pastukhov is formally reprimanded for mysticism.")
		},
		{
			"date": Loc.p("3 декабря 1982 г.", "3 December 1982"),
			"author": Loc.p("Старший техник Семёнов (вахта 1982)", "Senior technician Semyonov (1982 shift)"),
			"title": Loc.p("ДЕЛО №82-С: СЕЙСМИЧЕСКИЙ СЛУХАЧ И ПОДПОЛ", "FILE #82-S: THE SEISMIC LISTENER AND THE CELLAR"),
			"body": Loc.p("«Сейсмоприемник СВ-20 непрерывно бьёт тревогу. Под полом кухни — глухие удары с интервалом в 4 секунды. Оставил ящик с инструментами и аварийные заветы в тайнике на чердаке.\n\nТот, кто придёт после меня: доверяй барографу больше, чем собственным глазам. Если стрелка пошла вверх при метели — гаси все огни.»", "\"The SV-20 seismometer keeps sounding the alarm. Under the kitchen floor — dull thuds every 4 seconds. I left the toolbox and the emergency rules in the attic cache.\n\nWhoever comes after me: trust the barograph more than your own eyes. If the needle rises during a blizzard — put out every light.\""),
			"note": Loc.p("Последняя официальная запись Семёнова перед исчезновением в тайге.", "Semyonov's last official entry before he vanished in the taiga.")
		}
	]

	# Записи текущих дежурств Виктора
	var history: Array = SaveGame.flags.get("journal_tm1_log", [])
	for item: Dictionary in history:
		var n_idx: int = int(item.get("night", 1))
		var ch: String = String(item.get("chosen", "blizzard"))
		var act: String = String(item.get("actual", "blizzard"))
		var cor: bool = bool(item.get("correct", true))
		var res_str := Loc.p("ВЕРДИКТ ПОДТВЕРЖДЁН СВЕРДЛОВСКОМ", "VERDICT CONFIRMED BY SVERDLOVSK") if cor else Loc.p("ОШИБКА ДИАГНОЗА (факт: %s)", "WRONG DIAGNOSIS (actual: %s)") % act
		entries.append({
			"date": Loc.p("Ночь %d вахты 1983 г.", "Night %d of the 1983 shift") % n_idx,
			"author": Loc.p("Дежурный Виктор Мальцев (Ваша рука)", "Duty officer Viktor Maltsev (your hand)"),
			"title": Loc.p("СМЕНА №%d: ФОРМУЛЯР ТМ-1", "SHIFT #%d: TM-1 FORM") % n_idx,
			"body": Loc.p("«Зафиксирован фронт: %s. Давление: %.1f мм рт. ст., ветер: %.1f м/с.\nИтог ночной сводки: %s.»", "\"Front recorded: %s. Pressure: %.1f mmHg, wind: %.1f m/s.\nNight report result: %s.\"") % [
				ch, float(item.get("pressure", 746.0)), float(item.get("wind", 8.0)), res_str
			],
			"note": Loc.p("Запись внесена в Государственный архив метеонаблюдений.", "Entered into the State Archive of Weather Observations.")
		})

	# Пророческие записи наперёд (почерком Виктора)
	if Game.night >= 2 or Game.is_night():
		entries.append({
			"date": Loc.p("Ночь %d — Срок 04:00 (БУДУЩЕЕ)", "Night %d — Due 04:00 (FUTURE)") % (Game.night if Game.is_night() else 2),
			"author": Loc.p("Ваш почерк (тёмно-синие чернила)", "Your handwriting (dark blue ink)"),
			"title": Loc.t(&"tm1.prophecy_title"),
			"body": "%s\n\n%s\n\n%s" % [Loc.t(&"tm1.prophecy_1"), Loc.t(&"tm1.prophecy_2"), Loc.t(&"tm1.prophecy_3")],
			"note": Loc.p("Особая отметка: чернила ещё не высохли. Но ты этого не писал...", "Special note: the ink is still wet. But you never wrote this..."),
			"prophecy": true
		})

	for i in range(entries.size()):
		var e := entries[i]
		var btn := Button.new()
		btn.text = "📁 %s — %s" % [e["date"], e["author"]]
		btn.custom_minimum_size = Vector2(PAGE_W - 32, 34)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style_archive_btn(btn)
		var idx := i
		btn.pressed.connect(func() -> void: _select_archive_entry(idx, entries))
		_archive_list_box.add_child(btn)
		_archive_buttons.append(btn)

	if not entries.is_empty():
		_select_archive_entry(0, entries)


func _select_archive_entry(idx: int, entries: Array[Dictionary]) -> void:
	if idx < 0 or idx >= entries.size():
		return
	_active_archive_idx = idx
	AudioDirector.play_raw(TICK_SFX, -4.0)

	var e := entries[idx]
	if e.get("prophecy", false) and not bool(SaveGame.flags.get("journal_prophecy_seen", false)):
		SaveGame.flags["journal_prophecy_seen"] = true
		SaveGame.write()
		AudioDirector.play_raw("res://assets/audio/radio_anomaly.ogg", -6.0)
		if Game.hud != null:
			Game.hud.subtitle(Loc.t(&"sub.journal_prophecy_seen"), 4.5)
		Director.add_tension(14.0, "пророческие записи в журнале")

	for i in range(_archive_buttons.size()):
		var b := _archive_buttons[i]
		b.modulate = Color(1.2, 1.1, 0.8) if i == idx else Color.WHITE

	_archive_doc_title.text = e.get("title", "")
	_archive_doc_meta.text = "%s • %s" % [e.get("date", ""), e.get("author", "")]
	_archive_doc_body.text = e.get("body", "")
	_archive_doc_note.text = e.get("note", "")


# --- ПОСТРОЕНИЕ ВКЛАДКИ 3: ЗАМЕЧАНИЯ ДЕЖУРНОГО ---------------------------------
## Левая страница: зона и перечень того, что могло измениться. Правая — записи за ночь.
## Ответа «верно/неверно» журнал не даёт: верная запись — вещь вернётся на место, когда отвернёшься.

func _build_notes_spread() -> void:
	var left := VBoxContainer.new()
	left.position = Vector2(38, 10)
	left.size = Vector2(PAGE_W - 28, PAGE_H - 20)
	left.add_theme_constant_override("separation", 6)
	_notes_spread.add_child(left)

	var title := Label.new()
	title.text = Loc.t(&"anom.title")
	style_paper_label(title, C_INK_TITLE, 16)
	left.add_child(title)
	var sub := Label.new()
	sub.text = Loc.t(&"anom.sub")
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	style_paper_label(sub, C_INK_MAIN, 12)
	left.add_child(sub)
	left.add_child(_make_line(Color(0.20, 0.22, 0.35, 0.35)))

	var zones := HBoxContainer.new()
	zones.add_theme_constant_override("separation", 6)
	left.add_child(zones)
	for z: StringName in Anomalies.ZONES:
		var zb := Button.new()
		zb.text = Loc.t(StringName("anom.zone." + String(z)))
		zb.custom_minimum_size = Vector2(108, 30)
		_style_archive_btn(zb)
		var zz := z
		zb.pressed.connect(func() -> void: _select_zone(zz))
		zones.add_child(zb)
		_zone_btns[z] = zb

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_notes_items = VBoxContainer.new()
	_notes_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notes_items.add_theme_constant_override("separation", 5)
	scroll.add_child(_notes_items)

	var right := VBoxContainer.new()
	right.position = Vector2(BOOK_W - 24 - PAGE_W + 14, 10)
	right.size = Vector2(PAGE_W - 28, PAGE_H - 20)
	right.add_theme_constant_override("separation", 6)
	_notes_spread.add_child(right)
	var rt := Label.new()
	rt.text = Loc.t(&"anom.night_log", [Game.night])
	style_paper_label(rt, C_INK_TITLE, 16)
	right.add_child(rt)
	right.add_child(_make_line(Color(0.20, 0.22, 0.35, 0.35)))
	var rscroll := ScrollContainer.new()
	rscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(rscroll)
	_notes_list = VBoxContainer.new()
	_notes_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notes_list.add_theme_constant_override("separation", 6)
	rscroll.add_child(_notes_list)
	if Net.role != "" and Net.in_session:
		var hint := Label.new()
		hint.text = Loc.t(&"anom.coop_hint")
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		style_paper_label(hint, C_INK_MUTED, 12)
		right.add_child(hint)

	_notes_zone = _detect_current_zone()
	_select_zone(_notes_zone, true)
	_refresh_notes()


func _detect_current_zone() -> StringName:
	if Game == null:
		return &"house"
	if Game.zone == &"radio_room":
		return &"radio"
	if Game.is_outside():
		if Game.zone == &"meteo" or Game.zone == &"pavilion":
			return &"instr"
		return &"yard"
	return &"house"


func _update_zone_tab_labels() -> void:
	var an := Game.anomalies
	var cur_zone := _detect_current_zone()
	for z: StringName in Anomalies.ZONES:
		if not _zone_btns.has(z):
			continue
		var cnt := 0
		if an != null:
			for n: Dictionary in an.notes:
				if StringName(n.get("zone", &"")) == z:
					cnt += 1
		var base := Loc.t(StringName("anom.zone." + String(z)))
		var marker := "● " if z == cur_zone else ""
		var suffix := " (%d)" % cnt if cnt > 0 else ""
		(_zone_btns[z] as Button).text = "%s%s%s" % [marker, base, suffix]


func _select_zone(z: StringName, silent := false) -> void:
	_notes_zone = z
	if not silent:
		AudioDirector.play_raw(TICK_SFX, -8.0)
	_update_zone_tab_labels()
	for k: StringName in _zone_btns:
		var zb := _zone_btns[k] as Button
		zb.modulate = Color(1.22, 1.12, 0.82) if k == z else Color(0.95, 0.94, 0.90)
	for c in _notes_items.get_children():
		c.queue_free()
	var an := Game.anomalies
	if an == null:
		return
	for id: StringName in Anomalies.ids_for(z, Game.night):
		var b := Button.new()
		var done := an.noted(id)
		var reverted := done and an.active.has(id) and bool(an.active[id].get("reverted", false))
		var prefix := "✓ " if reverted else ("✎ " if done else "○ ")
		b.text = prefix + Loc.t(StringName("anom." + String(id)))
		b.custom_minimum_size = Vector2(PAGE_W - 32, 30)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.disabled = done
		_style_archive_btn(b)
		var iid := id
		b.pressed.connect(func() -> void: _write_note(iid, b))
		_notes_items.add_child(b)


func _write_note(id: StringName, b: Button) -> void:
	if Game.anomalies == null or not Game.anomalies.note(id):
		return
	# Сухой росчерк пера по бумаге + тихий щелчок штампа вместо громкого металлического лязга
	AudioDirector.play_raw(PAGE_SFX, -12.0)
	AudioDirector.play_raw(TICK_SFX, -8.0)
	b.text = "✎ " + Loc.t(StringName("anom." + String(id)))
	b.disabled = true
	_update_zone_tab_labels()
	_refresh_notes()


func _refresh_notes() -> void:
	for c in _notes_list.get_children():
		c.queue_free()
	var an := Game.anomalies
	if an == null or an.notes.is_empty():
		var empty := Label.new()
		empty.text = Loc.t(&"anom.empty")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		style_paper_label(empty, C_INK_MUTED, 12)
		_notes_list.add_child(empty)
		return
	for n: Dictionary in an.notes:
		var nid := StringName(n.get("id", &""))
		var reverted := an.active.has(nid) and bool(an.active[nid].get("reverted", false))
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 1)

		var hdr := Label.new()
		var stamp_str := Loc.p("[ВОЗВРАЩЕНО В НОРМУ]", "[REVERTED]") if reverted else Loc.p("[ЗАФИКСИРОВАНО]", "[LOGGED]")
		hdr.text = "%s · %s   %s" % [
			Game.minutes_to_clock(int(n["min"])),
			Loc.t(StringName("anom.zone." + String(n["zone"]))).to_upper(),
			stamp_str
		]
		style_paper_label(hdr, C_STAMP if not reverted else C_INK_MUTED, 10)
		row.add_child(hdr)

		var body := Label.new()
		body.text = Loc.t(StringName("anom." + String(nid)))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		style_paper_label(body, C_INK_MUTED if reverted else C_INK_MAIN, 18)
		body.add_theme_font_override(&"font", UiStyle.hand_font())
		row.add_child(body)

		row.add_child(_make_line(Color(0.20, 0.22, 0.35, 0.14)))
		_notes_list.add_child(row)


# --- ВСПОМОГАТЕЛЬНЫЕ КОМПОНЕНТЫ И СТИЛИ ---------------------------------------

func _make_tab_btn(title: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = title
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(on_press)
	b.custom_minimum_size = Vector2(240, 32)

	var sb := StyleBoxFlat.new()
	sb.bg_color = C_LEATHER * 1.3
	sb.border_color = C_GOLD_DIM
	sb.set_border_width_all(1)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	b.add_theme_stylebox_override("normal", sb)

	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = C_LEATHER * 1.7
	sb_h.border_color = C_GOLD
	b.add_theme_stylebox_override("hover", sb_h)
	b.add_theme_stylebox_override("focus", sb_h)

	b.add_theme_constant_override(&"outline_size", 0)
	b.add_theme_constant_override(&"shadow_offset_x", 0)
	b.add_theme_constant_override(&"shadow_offset_y", 0)
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", C_GOLD)
	return b


func _make_close_btn() -> Button:
	var b := Button.new()
	b.text = Loc.p("✕ ЗАКРЫТЬ [ESC]", "✕ CLOSE [ESC]")
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(_close)
	b.custom_minimum_size = Vector2(130, 32)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.25, 0.08, 0.08, 0.9)
	sb.border_color = C_GOLD_DIM
	sb.set_border_width_all(1)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	b.add_theme_stylebox_override("normal", sb)

	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(0.40, 0.10, 0.10, 0.95)
	sb_h.border_color = C_GOLD
	b.add_theme_stylebox_override("hover", sb_h)
	b.add_theme_stylebox_override("focus", sb_h)

	b.add_theme_constant_override(&"outline_size", 0)
	b.add_theme_constant_override(&"shadow_offset_x", 0)
	b.add_theme_constant_override(&"shadow_offset_y", 0)
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85))
	return b


func _make_reading_row(title: String, val: String, sub: String, measured: bool) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.90, 0.87, 0.79, 0.85) if measured else Color(0.91, 0.88, 0.81, 0.45)
	sb.border_color = Color(0.72, 0.68, 0.58, 0.70) if measured else Color(0.75, 0.71, 0.62, 0.40)
	sb.set_border_width_all(1)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	p.add_child(vb)

	var row := HBoxContainer.new()
	vb.add_child(row)

	var t_lbl := Label.new()
	t_lbl.text = title
	style_paper_label(t_lbl, C_INK_TITLE if measured else Color(0.30, 0.30, 0.36), 12)
	row.add_child(t_lbl)

	row.add_spacer(false)

	var v_lbl := Label.new()
	v_lbl.text = val
	style_paper_label(v_lbl, C_INK_MAIN if measured else C_INK_MUTED, 12)
	row.add_child(v_lbl)

	var s_lbl := Label.new()
	s_lbl.text = sub
	if measured:
		style_paper_label(s_lbl, C_INK_MAIN, 12)
	else:
		style_paper_label(s_lbl, C_INK_RED, 12)
	s_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(s_lbl)

	return p


func _make_verdict_card(parent: Control, front_id: StringName, title: String, sym: String, reg: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(PAGE_W - 28, 62)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void: _handle_card_click(front_id))

	var vb := VBoxContainer.new()
	vb.position = Vector2(8, 4)
	vb.size = Vector2(PAGE_W - 44, 54)
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(vb)

	var h_row := HBoxContainer.new()
	h_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(h_row)

	var t_lbl := Label.new()
	t_lbl.name = "TitleLabel"
	t_lbl.text = title
	style_paper_label(t_lbl, C_INK_TITLE, 14)
	t_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h_row.add_child(t_lbl)

	h_row.add_spacer(false)

	var check_lbl := Label.new()
	check_lbl.name = "CheckMark"
	check_lbl.text = Loc.p("[ ○ ВЫБРАТЬ ]", "[ ○ SELECT ]")
	style_paper_label(check_lbl, C_INK_MUTED, 12)
	check_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h_row.add_child(check_lbl)

	var sym_lbl := Label.new()
	sym_lbl.name = "SymLabel"
	sym_lbl.text = sym
	style_paper_label(sym_lbl, C_INK_MAIN, 12)
	sym_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sym_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(sym_lbl)

	var reg_lbl := Label.new()
	reg_lbl.name = "RegLabel"
	reg_lbl.text = reg
	style_paper_label(reg_lbl, C_INK_MAIN, 12)
	reg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reg_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(reg_lbl)

	parent.add_child(b)
	return b


func _style_verdict_card(b: Button, selected: bool, front_id: StringName, measured_cnt: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3

	if selected:
		match front_id:
			&"blizzard":
				sb.bg_color = Color(0.85, 0.89, 0.94)
				sb.border_color = Color(0.25, 0.40, 0.65)
			&"storm":
				sb.bg_color = Color(0.93, 0.86, 0.84)
				sb.border_color = Color(0.65, 0.25, 0.20)
			&"fog":
				sb.bg_color = Color(0.87, 0.92, 0.88)
				sb.border_color = Color(0.25, 0.50, 0.30)
			&"anomaly":
				sb.bg_color = Color(0.91, 0.85, 0.93)
				sb.border_color = Color(0.55, 0.20, 0.65)
			_:
				sb.bg_color = Color(0.90, 0.88, 0.82)
				sb.border_color = C_GOLD
		sb.set_border_width_all(2)
	else:
		sb.bg_color = Color(0.90, 0.87, 0.80, 0.85)
		sb.border_color = Color(0.74, 0.70, 0.60)
		sb.set_border_width_all(1)

	b.add_theme_stylebox_override("normal", sb)

	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.border_color = C_GOLD
	b.add_theme_stylebox_override("hover", sb_h)
	b.add_theme_stylebox_override("focus", sb_h)

	var check: Label = b.find_child("CheckMark", true, false) as Label
	if check:
		if _transmitted:
			if selected:
				check.text = Loc.p("[✔ УТВЕРЖДЕНО В УГМС]", "[✔ APPROVED BY UGMS]")
				style_paper_label(check, C_INK_RED, 12)
			else:
				check.text = Loc.p("[ — НЕ ВЫБРАНО — ]", "[ — NOT SELECTED — ]")
				style_paper_label(check, C_INK_MUTED, 12)
		elif measured_cnt == 0:
			check.text = Loc.p("[ НЕТ ЗАМЕРОВ ]", "[ NO READINGS ]")
			style_paper_label(check, C_INK_MUTED, 12)
		else:
			if selected:
				check.text = Loc.p("[ ● ВЫБРАНО ]", "[ ● SELECTED ]")
				style_paper_label(check, C_INK_MAIN, 12)
			else:
				check.text = Loc.p("[ ○ ВЫБРАТЬ ]", "[ ○ SELECT ]")
				style_paper_label(check, C_INK_MUTED, 12)


func _style_submit_btn(b: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.16, 0.22)
	sb.border_color = C_GOLD_DIM
	sb.set_border_width_all(2)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	b.add_theme_stylebox_override("normal", sb)

	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(0.20, 0.24, 0.32)
	sb_h.border_color = C_GOLD
	b.add_theme_stylebox_override("hover", sb_h)
	b.add_theme_stylebox_override("focus", sb_h)

	var sb_dis := sb.duplicate() as StyleBoxFlat
	sb_dis.bg_color = Color(0.22, 0.22, 0.24, 0.65)
	sb_dis.border_color = Color(0.45, 0.45, 0.45, 0.4)
	b.add_theme_stylebox_override("disabled", sb_dis)

	b.add_theme_constant_override(&"outline_size", 0)
	b.add_theme_constant_override(&"shadow_offset_x", 0)
	b.add_theme_constant_override(&"shadow_offset_y", 0)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", Color(0.96, 0.90, 0.72))
	b.add_theme_color_override("font_disabled_color", Color(0.65, 0.62, 0.58))


func _style_archive_btn(b: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.90, 0.87, 0.80, 0.85)
	sb.border_color = Color(0.72, 0.68, 0.58)
	sb.set_border_width_all(1)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	b.add_theme_stylebox_override("normal", sb)

	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(0.94, 0.91, 0.84)
	sb_h.border_color = C_GOLD
	b.add_theme_stylebox_override("hover", sb_h)
	b.add_theme_stylebox_override("focus", sb_h)

	style_paper_button(b, C_INK_MAIN, 12)


func _make_line(col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.custom_minimum_size = Vector2(0, 1)
	return r


# --- ПЕРЕКЛЮЧЕНИЕ ВКЛАДОК И ВЕРДИКТОВ -----------------------------------------

## Вкладка «Замечания» — с 2-й ночи, когда на станции вообще начинает что-то меняться.
func _notes_on() -> bool:
	return Game.anomalies != null and Game.night >= 2


var _archive_built := false
var _notes_built := false


func _switch_tab(tab_idx: int) -> void:
	if _flipping:
		return
	if tab_idx == 1 and not _archive_built:
		_archive_built = true
		_build_archive_spread()
	if tab_idx == 2 and _notes_on():
		if not _notes_built:
			_notes_built = true
			_build_notes_spread()
		else:
			_select_zone(_detect_current_zone(), true)
			_refresh_notes()
	_tab = tab_idx
	_flipping = true
	AudioDirector.play_raw(PAGE_SFX, -2.0)

	# 3-кадровая анимация листания страницы (низкий ретро-FPS)
	var t := create_tween()
	t.tween_method(func(step: int) -> void:
		_flip_frame = step
		_canvas.queue_redraw()
	, 1, 3, 0.24).set_trans(Tween.TRANS_LINEAR)

	t.finished.connect(func() -> void:
		_flip_frame = 0
		_flipping = false
		_shift_spread.visible = (tab_idx == 0)
		_archive_spread.visible = (tab_idx == 1)
		_notes_spread.visible = (tab_idx == 2)
		if tab_idx == 2 and _zone_btns.has(_notes_zone):
			(_zone_btns[_notes_zone] as Button).grab_focus()   # геймпад: фокус сразу на зоне
		_tab_notes_btn.modulate = Color(1.3, 1.2, 0.8) if tab_idx == 2 else Color(0.8, 0.8, 0.8)

		var active_color := Color(1.3, 1.2, 0.8)
		var idle_color := Color(0.8, 0.8, 0.8)
		_tab_shift_btn.modulate = active_color if tab_idx == 0 else idle_color
		_tab_archive_btn.modulate = active_color if tab_idx == 1 else idle_color
		_canvas.queue_redraw()
	)


func _handle_card_click(front_id: StringName) -> void:
	if _transmitted:
		return
	var cnt := _get_measured_count()
	if cnt == 0:
		AudioDirector.play_raw(TICK_SFX, -4.0)
		_status_lbl.text = Loc.p("Сначала снимите показания хотя бы одного прибора!", "Read at least one instrument first!")
		style_paper_label(_status_lbl, C_INK_RED, 12)
		return
	_select_front(front_id)


func _select_front(f: StringName) -> void:
	if _transmitted:
		return
	_chosen_front = f
	AudioDirector.play_raw(TICK_SFX, -4.0)
	_update_card_styles()


func _update_card_styles() -> void:
	var measured_cnt := _get_measured_count()
	for k: StringName in _verdict_cards.keys():
		var card: Button = _verdict_cards[k] as Button
		_style_verdict_card(card, k == _chosen_front, k, measured_cnt)
	_update_submit_and_status()


func _update_submit_and_status() -> void:
	if _submit_btn == null or _status_lbl == null:
		return
	var measured_cnt := _get_measured_count()
	if _transmitted:
		_submit_btn.disabled = true
		_submit_btn.text = Loc.p("✓ СВОДКА ПЕРЕДАНА В СВЕРДЛОВСК-44", "✓ REPORT SENT TO SVERDLOVSK-44")
		_status_lbl.text = Loc.p("Сводка утверждена и внесена в формуляр ТМ-1.", "Report approved and entered into the TM-1 form.")
		style_paper_label(_status_lbl, C_INK_MAIN, 12)
	elif measured_cnt == 0:
		_submit_btn.disabled = true
		_submit_btn.text = Loc.p("📡 СНИМИТЕ ПОКАЗАНИЯ ПРИБОРОВ (0 ИЗ 5)", "📡 READ THE INSTRUMENTS (0 OF 5)")
		_status_lbl.text = Loc.p("Осмотрите барограф, психрометр, флюгер или спутниковый снимок.", "Check the barograph, psychrometer, wind vane or satellite image.")
		style_paper_label(_status_lbl, C_INK_MUTED, 12)
	elif _chosen_front == &"":
		_submit_btn.disabled = true
		_submit_btn.text = Loc.p("📡 ВЫБЕРИТЕ РЕГЛАМЕНТ ЗАЩИТЫ (1–4)", "📡 CHOOSE A PROTECTION PROCEDURE (1–4)")
		_status_lbl.text = Loc.p("Сопоставьте снятые данные и укажите прогнозируемый фронт.", "Compare the readings and name the expected front.")
		style_paper_label(_status_lbl, C_INK_MAIN, 12)
	else:
		_submit_btn.disabled = false
		_submit_btn.text = Loc.p("📡 УТВЕРДИТЬ ВЕРДИКТ И ПЕРЕДАТЬ В УГМС [ENTER]", "📡 CONFIRM VERDICT AND SEND TO UGMS [ENTER]")
		_status_lbl.text = Loc.p("Шифрограмма готова к передаче в Свердловск-44.", "Coded report ready to send to Sverdlovsk-44.")
		style_paper_label(_status_lbl, C_INK_MAIN, 12)


func _submit_verdict() -> void:
	if _transmitted:
		return
	var measured_total := _get_measured_count()
	if measured_total == 0:
		_status_lbl.text = Loc.p("Нельзя передать сводку: нет данных ни одного прибора!", "Can't send a report: no instrument data at all!")
		style_paper_label(_status_lbl, C_INK_RED, 12)
		AudioDirector.play_raw(TICK_SFX, -4.0)
		return
	if _chosen_front == &"":
		_status_lbl.text = Loc.p("Сначала выберите регламент защиты погоды!", "Choose a weather protection procedure first!")
		style_paper_label(_status_lbl, C_INK_RED, 12)
		AudioDirector.play_raw(TICK_SFX, -4.0)
		return

	if Game.notebook.has(&"baro") and not Game.baro_tapped:
		var rej_text: String = Loc.t(&"radio.baro_rejected")
		_status_lbl.text = Loc.p("СВОДКА ЗАБРАКОВАНА: ЗАСТОЙ ТРЕНИЯ БАРОГРАФА", "REPORT REJECTED: BAROGRAPH FRICTION ERROR")
		style_paper_label(_status_lbl, C_INK_RED, 12)
		Game.hud.subtitle(rej_text, 7.0)
		AudioDirector.play_raw(STAMP_SFX, -1.0)
		Director.add_tension(8.0, "брак сводки из-за барографа")
		return

	_transmitted = true

	SaveGame.flags["forecast_choice"] = String(_chosen_front)
	SaveGame.flags["forecast_day"] = Game.phase_index

	var s: Synoptic = Game.synoptic
	var actual: StringName = s.front_type if s != null else &"blizzard"
	var is_correct := (_chosen_front == actual)

	# Логирование в историю формуляра ТМ-1
	var history: Array = SaveGame.flags.get("journal_tm1_log", [])
	history.append({
		"night": Game.night,
		"chosen": String(_chosen_front),
		"actual": String(actual),
		"correct": is_correct,
		"measured": measured_total,
		"pressure": s.pressure if s != null else 746.0,
		"wind": s.wind_speed if s != null else 8.0
	})
	SaveGame.flags["journal_tm1_log"] = history
	SaveGame.write()

	AudioDirector.play_raw(STAMP_SFX, -1.0)
	_update_card_styles()
	_canvas.queue_redraw()

	# Живой разбор сводки от диспетчера Свердловска-44
	var radio_text := ""
	if measured_total < 3:
		radio_text = Loc.p("«СВЕРДЛОВСК-44: Кедр, в формуляре ТМ-1 пропуски (%d из 5)! Вы не сняли показания приборов. Сводка принята условно, дежурному замечание!»", "\"SVERDLOVSK-44: Kedr, your TM-1 form has gaps (%d of 5)! You didn't read the instruments. Report accepted provisionally, duty officer warned!\"") % measured_total
		_status_lbl.text = Loc.p("СВОДКА ПРИНЯТА УСЛОВНО: ПРОПУСКИ В ДАННЫХ (%d/5)", "REPORT ACCEPTED PROVISIONALLY: DATA GAPS (%d/5)") % measured_total
		style_paper_label(_status_lbl, C_INK_RED, 12)
	elif is_correct:
		Game.stove_wood = minf(Game.stove_wood + 25.0, 100.0)
		Game.generator_fuel = minf(Game.generator_fuel + 20.0, 100.0)
		var peak_text := s.peak_hour_string if s != null else "02:30"
		radio_text = Loc.p("«СВЕРДЛОВСК-44: Сводка Кедра принята в полном объёме! Диагноз точен: ожидается %s (пик к %s). Регламент станции утверждён.»", "\"SVERDLOVSK-44: Kedr's report accepted in full! Diagnosis correct: expect %s (peak by %s). Station procedure approved.\"") % [
			_front_name_ru(_chosen_front), peak_text
		]
		_status_lbl.text = Loc.p("РЕГЛАМЕНТ УТВЕРЖДЁН СВЕРДЛОВСКОМ • ПИК: %s", "PROCEDURE APPROVED BY SVERDLOVSK • PEAK: %s") % peak_text
		style_paper_label(_status_lbl, Color(0.10, 0.45, 0.16), 12)
	else:
		radio_text = Loc.p("«СВЕРДЛОВСК-44: Кедр, ошибка расчёта! Вы заявили %s, но приборы показывают %s. Перепроверьте барограф и термометры!»", "\"SVERDLOVSK-44: Kedr, calculation error! You reported %s, but the instruments show %s. Recheck the barograph and thermometers!\"") % [
			_front_name_ru(_chosen_front), _front_name_ru(actual)
		]
		_status_lbl.text = Loc.p("ОШИБКА ДИАГНОЗА: ФАКТИЧЕСКИЙ ФРОНТ — %s", "WRONG DIAGNOSIS: ACTUAL FRONT — %s") % _front_name_ru(actual).to_upper()
		style_paper_label(_status_lbl, C_INK_RED, 12)

	Game.hud.subtitle(radio_text, 6.0)

	await get_tree().create_timer(1.4, false).timeout
	_close()


func _front_name_ru(f: StringName) -> String:
	match f:
		&"blizzard": return Loc.p("низовая метель", "ground blizzard")
		&"storm": return Loc.p("арктический шквал", "arctic squall")
		&"fog": return Loc.p("радиационный туман", "radiation fog")
		&"anomaly": return Loc.p("геофизическая аномалия", "geophysical anomaly")
	return Loc.p("неопределённый фронт", "undetermined front")


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"drop") or event.is_action_pressed(&"pause") or event.is_action_pressed(&"interact"):
		_close()
		return true

	# Геймпад: LB / RB листают вкладки журнала.
	if event is InputEventJoypadButton and event.is_pressed():
		var jb := (event as InputEventJoypadButton).button_index
		if jb == JOY_BUTTON_LEFT_SHOULDER or jb == JOY_BUTTON_RIGHT_SHOULDER:
			var n := 3 if _notes_on() else 2
			_switch_tab((_tab + (1 if jb == JOY_BUTTON_RIGHT_SHOULDER else n - 1)) % n)
			return true

	if event.is_action_pressed(&"ui_accept"):
		if _shift_spread.visible and not _transmitted and _chosen_front != &"" and _get_measured_count() > 0:
			_submit_verdict()
			return true

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			_switch_tab(0)
			return true
		elif event.keycode == KEY_E:
			_switch_tab(1)
			return true
		elif (event.keycode == KEY_R or event.keycode == KEY_N) and _notes_on():
			_switch_tab(2)
			return true
		elif event.keycode == KEY_1:
			_handle_card_click(&"blizzard")
			return true
		elif event.keycode == KEY_2:
			_handle_card_click(&"storm")
			return true
		elif event.keycode == KEY_3:
			_handle_card_click(&"fog")
			return true
		elif event.keycode == KEY_4:
			_handle_card_click(&"anomaly")
			return true

	return false


func _unhandled_input(event: InputEvent) -> void:
	handle_input(event)


func _close() -> void:
	closed.emit()
