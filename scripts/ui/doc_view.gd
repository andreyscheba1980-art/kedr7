class_name DocView
extends Control
## Документ крупно, как в руках над столом — вместо плашки на полэкрана.
##   &"sheet"  — лист А4 почти во всю высоту: бумага с волокнами, тень, наклон, скрепка, дырки дырокола,
##               сгиб, иногда кольцо от кружки; машинопись, пометки в скобках — от руки; у секретных — штамп.
##               Длинный текст сам делится на страницы.
##   &"folder" — папка дела: картонная обложка с грифом и завязками → разворот: слева изнанка обложки
##               (учётная карточка, фото на скрепке, штампы), справа подшитые листы, листаются.
## Управление: [E] / клик / [D] — дальше, [A] — назад, [Esc] — закрыть.

signal closed

const INK := Color(0.13, 0.11, 0.12)
const HAND := Color(0.12, 0.2, 0.52)
const STAMP := Color(0.72, 0.1, 0.08)
const CARD := Color(0.72, 0.58, 0.38)

var mode := &"sheet"
var pages: PackedStringArray = []
var secret := false
var cover_lines: PackedStringArray = []    ## папка: строки обложки (заголовок дела и пр.)
var _i := 0
var _opened := false
var _seed := 1.0

var _dim: ColorRect
var _book: Control            ## всё, что «лежит»: лист или разворот
var _sheet: Control
var _shadow: ColorRect
var _text: RichTextLabel
var _deco: Control
var _cover: Control
var _left: Control
var _hint: Label
var _pageno: Label


static func sheet(p: PackedStringArray, is_secret := false) -> DocView:
	var d := DocView.new()
	d.mode = &"sheet"
	d.pages = p
	d.secret = is_secret
	return d


static func folder(cover: PackedStringArray, p: PackedStringArray) -> DocView:
	var d := DocView.new()
	d.mode = &"folder"
	d.cover_lines = cover
	d.pages = p
	d.secret = true
	return d


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # ввод приходит через handle_input от владельца
	_seed = randf() * 10.0
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.02, 0.03, 0.82)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_book = Control.new()
	_book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_book)
	_hint = _ui_label(15, Color(0.85, 0.82, 0.72, 0.75))
	_pageno = _ui_label(15, Color(0.85, 0.82, 0.72, 0.75))
	if mode == &"sheet":
		pages = _paginate_all(pages)
		_build_sheet(_book)
	else:
		_build_cover()
	resized.connect(_layout)
	_layout.call_deferred()
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.18)


func _ui_label(sz: int, c: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override(&"font", UiStyle.type_font())
	l.add_theme_font_size_override(&"font_size", sz)
	l.add_theme_color_override(&"font_color", c)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


# --- Раскладка --------------------------------------------------------------------

func _sheet_size() -> Vector2:
	var h := size.y * 0.9
	return Vector2(h * 0.72, h)


func _layout() -> void:
	var s := _sheet_size()
	if mode == &"sheet":
		_place_sheet(Vector2((size.x - s.x) * 0.5, (size.y - s.y) * 0.5), s, -0.012)
	elif not _opened:
		var cs := s * Vector2(1.02, 1.0)
		_cover.position = Vector2((size.x - cs.x) * 0.5, (size.y - cs.y) * 0.5)
		_cover.size = cs
		_cover.pivot_offset = cs * 0.5
		_cover.rotation = -0.01
	else:
		# Разворот: изнанка обложки слева, лист справа
		var total := Vector2(s.x * 2.05, s.y)
		var org := Vector2((size.x - total.x) * 0.5, (size.y - total.y) * 0.5)
		_left.position = org
		_left.size = s
		_place_sheet(org + Vector2(s.x * 1.05, 0), s * Vector2(0.97, 0.985), 0.006)
	_hint.position = Vector2(size.x * 0.5 - 300, size.y - 34)
	_hint.size = Vector2(600, 24)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pageno.position = Vector2(size.x - 220, size.y - 34)
	_update_texts()


func _place_sheet(pos: Vector2, s: Vector2, rot: float) -> void:
	_shadow.position = pos + Vector2(14, 18)
	_shadow.size = s
	_shadow.pivot_offset = s * 0.5
	_shadow.rotation = rot
	_sheet.position = pos
	_sheet.size = s
	_sheet.pivot_offset = s * 0.5
	_sheet.rotation = rot
	var m := s * Vector2(0.11, 0.07)
	var top := s.y * (0.14 if secret else 0.08)   # под штампом «секретно»
	_text.position = Vector2(m.x * 1.15, top)
	_text.size = Vector2(s.x - m.x * 2.05, s.y - top - m.y * 1.3)
	_fit_text()


# --- Лист -------------------------------------------------------------------------

func _build_sheet(parent: Control) -> void:
	_shadow = ColorRect.new()
	_shadow.color = Color(0, 0, 0, 0.55)
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_shadow)
	_sheet = Control.new()
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_sheet)
	UiStyle.paper(_sheet, _seed, Color(0.9, 0.87, 0.78), 1.2)
	_deco = _Deco.new()
	_deco.doc = self
	_deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(_deco)
	_deco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = false
	_text.fit_content = false
	_text.scroll_active = false
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_color_override(&"default_color", INK)
	_sheet.add_child(_text)


func _fill(t: RichTextLabel, body: String, fs: int) -> void:
	t.clear()
	var lines := body.split("\n")
	for k in lines.size():
		var ln: String = lines[k]
		var hand := ln.strip_edges().begins_with("(") or ln.strip_edges().begins_with("«(")
		t.push_font(UiStyle.hand_font() if hand else UiStyle.type_font(), int(fs * (1.25 if hand else 1.0)))
		t.push_color(HAND if hand else INK)
		t.add_text(ln)
		t.pop()
		t.pop()
		if k < lines.size() - 1:
			t.add_text("\n")


func _fit_text() -> void:
	if _text == null or pages.is_empty():
		return
	if _text.size.y < 50.0:
		return
	var body := pages[clampi(_i, 0, pages.size() - 1)]
	var top := clampi(int(_text.size.y / 26.0), 16, 26)
	for fs in range(top, 15, -1):
		_fill(_text, body, fs)
		if _text.get_content_height() <= _text.size.y:
			return
	# Не влезает крупным шрифтом — делим лист пополам по абзацам (мелкий кегль не читается)
	var lines := body.split("
")
	if lines.size() >= 4:
		var cut := lines.size() / 2
		for k in range(cut, lines.size()):
			if lines[k].strip_edges() == "":
				cut = k
				break
		var a_part := "
".join(lines.slice(0, cut)).strip_edges()
		var b_part := "
".join(lines.slice(cut)).strip_edges()
		if a_part != "" and b_part != "":
			pages[_i] = a_part
			pages.insert(_i + 1, b_part)
			_fit_text()
			_update_texts()
			return
	_fill(_text, body, 15)


## Длинное — на несколько листов: по абзацам, пока влезает при 14-м кегле на лист 0.9 экрана.
func _paginate_all(src: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = []
	var max_chars := 950   # крупный шрифт важнее: длинное — на второй лист
	for p in src:
		if p.length() <= max_chars:
			out.append(p)
			continue
		var cur := ""
		for para in p.split("\n"):
			if cur.length() + para.length() > max_chars and cur != "":
				out.append(cur.strip_edges())
				cur = ""
			cur += para + "\n"
		if cur.strip_edges() != "":
			out.append(cur.strip_edges())
	return out


# --- Папка ------------------------------------------------------------------------

func _build_cover() -> void:
	_cover = Control.new()
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(_cover)
	var sh := ColorRect.new()
	sh.color = Color(0, 0, 0, 0.55)
	sh.position = Vector2(16, 20)
	_cover.add_child(sh)
	sh.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sh.offset_left = 16
	sh.offset_top = 20
	sh.offset_right = 16
	sh.offset_bottom = 20
	UiStyle.paper(_cover, _seed + 3.0, CARD, 1.6)
	var d := _CoverDeco.new()
	d.doc = self
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.add_child(d)
	d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _open_folder() -> void:
	_opened = true
	var tw := create_tween()
	tw.tween_property(_cover, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func() -> void:
		_cover.visible = false
		_left = Control.new()
		_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_book.add_child(_left)
		UiStyle.paper(_left, _seed + 5.0, CARD * Color(1.04, 1.02, 1.0), 1.4)
		var ld := _InsideDeco.new()
		ld.doc = self
		ld.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_left.add_child(ld)
		ld.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_build_sheet(_book)
		_layout()
		if Game.audio != null:
			Game.audio.play_2d("res://assets/sfx/page_turn.wav", -6.0))


# --- Ввод -------------------------------------------------------------------------

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		closed.emit()
		return
	var next: bool = event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"move_right") \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if next:
		advance()
	elif event.is_action_pressed(&"move_left") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		back()


## Дальше: открыть папку / следующий лист / закрыть на последнем. true — документ ещё открыт.
func advance() -> bool:
	if mode == &"folder" and not _opened:
		_open_folder()
		return true
	if _i < pages.size() - 1:
		_i += 1
		_turn()
		return true
	closed.emit()
	return false


func back() -> void:
	if _i > 0:
		_i -= 1
		_turn()


func has_more() -> bool:
	return (mode == &"folder" and not _opened) or _i < pages.size() - 1


func _turn() -> void:
	if Game.audio != null:
		Game.audio.play_2d("res://assets/sfx/page_turn.wav", -8.0)
	_seed += 1.7
	var tw := create_tween()
	tw.tween_property(_sheet, "modulate:a", 0.0, 0.08)
	tw.tween_callback(func() -> void:
		_fit_text()
		_update_texts()
		_deco.queue_redraw())
	tw.tween_property(_sheet, "modulate:a", 1.0, 0.12)


func _update_texts() -> void:
	if mode == &"folder" and not _opened:
		_hint.text = Loc.t(&"doc.hint_open")
		_pageno.text = ""
		return
	_hint.text = Loc.t(&"doc.hint")
	_pageno.text = Loc.t(&"doc.page", [_i + 1, pages.size()]) if pages.size() > 1 else ""


# --- Отрисовка мелочей ---------------------------------------------------------------

## Лист: дырки дырокола, скрепка, сгиб, кольцо от кружки, штамп «секретно», номер листа.
class _Deco extends Control:
	var doc: DocView

	func _draw() -> void:
		var s := size
		if s.y < 40.0:
			return   # первый кадр: размер ещё не посчитан — шрифт вышел бы нулевым
		var rng := RandomNumberGenerator.new()
		rng.seed = int(doc._seed * 1000.0)
		# дырки дырокола у левого края
		for y in [0.3, 0.7]:
			draw_circle(Vector2(s.x * 0.045, s.y * y), s.x * 0.016, Color(0.05, 0.05, 0.06, 0.85))
		# сгиб пополам
		draw_line(Vector2(0, s.y * 0.5), Vector2(s.x, s.y * 0.5 + 2), Color(0, 0, 0, 0.05), 2.0)
		draw_line(Vector2(0, s.y * 0.5 + 2), Vector2(s.x, s.y * 0.5 + 4), Color(1, 1, 1, 0.08), 1.5)
		# скрепка в углу
		var sp := Vector2(s.x * 0.08, -s.y * 0.012)
		var clip := Color(0.55, 0.57, 0.6)
		draw_rect(Rect2(sp, Vector2(s.x * 0.035, s.y * 0.09)), clip, false, 3.0)
		draw_rect(Rect2(sp + Vector2(s.x * 0.008, s.y * 0.012), Vector2(s.x * 0.02, s.y * 0.06)), clip, false, 2.0)
		# кольцо от стакана — не на каждом листе
		if rng.randf() < 0.45:
			var c := Vector2(s.x * rng.randf_range(0.6, 0.85), s.y * rng.randf_range(0.65, 0.9))
			draw_arc(c, s.x * 0.085, 0, TAU, 48, Color(0.45, 0.3, 0.15, 0.16), s.x * 0.01)
		# штамп
		if doc.secret:
			var st := Vector2(s.x * 0.58, s.y * 0.045)
			draw_set_transform(st, -0.12, Vector2.ONE)
			var w := s.x * 0.36
			var h := s.y * 0.06
			draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(DocView.STAMP, 0.75), false, 3.0)
			draw_rect(Rect2(Vector2(4, 4), Vector2(w - 8, h - 8)), Color(DocView.STAMP, 0.6), false, 1.5)
			var f := UiStyle.plate_font()
			var fs := int(h * 0.42)
			var tx := Loc.t(&"doc.stamp_secret")
			var tw := f.get_string_size(tx, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(f, Vector2((w - tw) * 0.5, h * 0.66), tx, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(DocView.STAMP, 0.85))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# номер листа внизу, карандашом
		if doc.pages.size() > 1:
			draw_string(UiStyle.hand_font(), Vector2(s.x * 0.88, s.y * 0.965), str(doc._i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, int(s.y * 0.03), Color(0.3, 0.3, 0.35, 0.8))


## Обложка папки: «КГБ СССР», гриф, номер дела, «Хранить постоянно», завязки.
class _CoverDeco extends Control:
	var doc: DocView

	func _draw() -> void:
		var s := size
		if s.y < 40.0:
			return   # первый кадр: размер ещё не посчитан — шрифт вышел бы нулевым
		var ink := Color(0.15, 0.12, 0.1)
		var f := UiStyle.plate_font()
		var tf := UiStyle.type_font()
		var cx := s.x * 0.5
		var lines := doc.cover_lines
		_c(f, Loc.t(&"doc.cover_org"), Vector2(cx, s.y * 0.08), int(s.y * 0.026), ink)
		# гриф — крупный красный штамп
		draw_set_transform(Vector2(cx, s.y * 0.2), -0.06, Vector2.ONE)
		var w := s.x * 0.7
		var h := s.y * 0.075
		draw_rect(Rect2(Vector2(-w * 0.5, -h * 0.5), Vector2(w, h)), Color(DocView.STAMP, 0.85), false, 4.0)
		_c(f, Loc.t(&"doc.cover_secret"), Vector2(0, h * 0.18), int(h * 0.5), Color(DocView.STAMP, 0.9))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var y := s.y * 0.36
		for k in lines.size():
			var big := k == 0
			_c(f if big else tf, lines[k], Vector2(cx, y), int(s.y * (0.055 if big else 0.025)), ink)
			y += s.y * (0.085 if big else 0.045)
		# поля для заполнения
		var fy := s.y * 0.7
		for key: StringName in [&"doc.cover_begun", &"doc.cover_ended", &"doc.cover_keep"]:
			draw_string(tf, Vector2(s.x * 0.14, fy), Loc.t(key), HORIZONTAL_ALIGNMENT_LEFT, -1, int(s.y * 0.022), ink)
			draw_line(Vector2(s.x * 0.45, fy + 4), Vector2(s.x * 0.86, fy + 4), Color(ink, 0.6), 1.5)
			fy += s.y * 0.05
		draw_string(UiStyle.hand_font(), Vector2(s.x * 0.47, s.y * 0.7 - 2), "14.11.83", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s.y * 0.03), Color(0.12, 0.2, 0.52))
		draw_string(UiStyle.hand_font(), Vector2(s.x * 0.47, s.y * 0.75 - 2), "16.11.83", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s.y * 0.03), Color(0.12, 0.2, 0.52))
		draw_string(UiStyle.hand_font(), Vector2(s.x * 0.47, s.y * 0.8 - 2), Loc.t(&"doc.cover_forever"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(s.y * 0.03), Color(0.12, 0.2, 0.52))
		# завязки по краю
		for yy in [0.48, 0.52]:
			draw_line(Vector2(s.x - 4, s.y * yy), Vector2(s.x + s.x * 0.06, s.y * yy + 18), Color(0.85, 0.82, 0.72), 5.0)
		# ржавые следы скоросшивателя
		draw_rect(Rect2(Vector2(s.x * 0.04, s.y * 0.1), Vector2(s.x * 0.012, s.y * 0.8)), Color(0.4, 0.3, 0.2, 0.25))

	func _c(f: Font, t: String, p: Vector2, fs: int, col: Color) -> void:
		if fs < 1:
			return   # первый кадр: размер ещё не посчитан
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, p - Vector2(w * 0.5, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Изнанка обложки: учётная карточка, фото станции на скрепке, «ознакомлен» с подписями.
class _InsideDeco extends Control:
	var doc: DocView

	func _draw() -> void:
		var s := size
		if s.y < 40.0:
			return   # первый кадр: размер ещё не посчитан — шрифт вышел бы нулевым
		var ink := Color(0.15, 0.12, 0.1)
		var tf := UiStyle.type_font()
		# учётная карточка
		var card := Rect2(Vector2(s.x * 0.08, s.y * 0.07), Vector2(s.x * 0.84, s.y * 0.36))
		draw_rect(card, Color(0.9, 0.88, 0.8))
		draw_rect(card, Color(ink, 0.5), false, 1.5)
		var rows := [Loc.t(&"doc.card_1"), Loc.t(&"doc.card_2"), Loc.t(&"doc.card_3"), Loc.t(&"doc.card_4"), Loc.t(&"doc.card_5")]
		for k in rows.size():
			var y := card.position.y + card.size.y * (0.16 + k * 0.17)
			draw_string(tf, Vector2(card.position.x + 12, y), rows[k], HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 24, int(s.y * 0.02), ink)
			draw_line(Vector2(card.position.x + 8, y + 8), Vector2(card.end.x - 8, y + 8), Color(ink, 0.25), 1.0)
		# фото на скрепке: станция, мачта, ели — карандашная «фотография»
		var ph := Rect2(Vector2(s.x * 0.14, s.y * 0.48), Vector2(s.x * 0.5, s.y * 0.3))
		draw_set_transform(ph.get_center(), 0.05, Vector2.ONE)
		var r := Rect2(-ph.size * 0.5, ph.size)
		draw_rect(r.grow(10), Color(0.92, 0.9, 0.86))
		draw_rect(r, Color(0.22, 0.24, 0.27))
		var g := r.position
		var sz := r.size
		draw_rect(Rect2(g + Vector2(0, sz.y * 0.72), Vector2(sz.x, sz.y * 0.28)), Color(0.55, 0.58, 0.62))   # снег
		draw_rect(Rect2(g + Vector2(sz.x * 0.25, sz.y * 0.5), Vector2(sz.x * 0.35, sz.y * 0.24)), Color(0.12, 0.12, 0.13))   # дом
		draw_colored_polygon(PackedVector2Array([g + Vector2(sz.x * 0.22, sz.y * 0.5), g + Vector2(sz.x * 0.425, sz.y * 0.36), g + Vector2(sz.x * 0.63, sz.y * 0.5)]), Color(0.1, 0.1, 0.11))
		draw_line(g + Vector2(sz.x * 0.78, sz.y * 0.74), g + Vector2(sz.x * 0.8, sz.y * 0.08), Color(0.1, 0.1, 0.1), 2.0)   # мачта
		for k in 6:
			var tx := sz.x * (0.04 + k * 0.17)
			draw_colored_polygon(PackedVector2Array([g + Vector2(tx, sz.y * 0.72), g + Vector2(tx + sz.x * 0.05, sz.y * 0.4), g + Vector2(tx + sz.x * 0.1, sz.y * 0.72)]), Color(0.08, 0.1, 0.09))
		draw_circle(g + Vector2(sz.x * 0.36, sz.y * 0.6), 2.5, Color(0.9, 0.8, 0.5))   # окно горит
		draw_string(UiStyle.hand_font(), g + Vector2(8, sz.y + 32), Loc.t(&"doc.photo_caption"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(s.y * 0.026), Color(0.12, 0.2, 0.52))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var clip := Color(0.55, 0.57, 0.6)
		draw_rect(Rect2(Vector2(s.x * 0.2, s.y * 0.45), Vector2(s.x * 0.04, s.y * 0.1)), clip, false, 3.0)
		# лист ознакомления
		var y0 := s.y * 0.86
		draw_string(tf, Vector2(s.x * 0.08, y0), Loc.t(&"doc.read_by"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(s.y * 0.02), ink)
		draw_string(UiStyle.hand_font(), Vector2(s.x * 0.08, y0 + s.y * 0.05), Loc.t(&"doc.read_names"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(s.y * 0.028), Color(0.12, 0.2, 0.52))
