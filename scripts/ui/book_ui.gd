class_name BookUI
extends Control
## Книга или бумаги в руках (Books): разворот из двух страниц, листается ←/→ (A/D), кликом по
## левой/правой странице или колёсиком. Вид — по документу: почерк ручкой, машинопись со штампом,
## типография, газета; иней на страницах, опалённый край. Открывается обёрткой HeldPaper (в руках).

signal closed

const W := 1080.0
const H := 630.0
const PAGE := Vector2(490, 560)
const FLIP_SFX := ["res://assets/sfx/page_turn.wav", "res://assets/sfx/page_turn_2.wav"]

static var pending_id: StringName = &"bragin"

var _id: StringName
var _pages: Array = []
var _spread := 0
var _left: RichTextLabel
var _right: RichTextLabel
var _num_l: Label
var _num_r: Label
var _marks: Control


func _ready() -> void:
	_id = pending_id
	mouse_filter = Control.MOUSE_FILTER_STOP
	_pages = Books.pages(_id)
	Books.mark_read(_id)
	var d: Dictionary = Books.DATA.get(_id, {})
	var cover: Color = d.get("cover", Color(0.3, 0.25, 0.2))
	# Переплёт и две страницы
	var bg := ColorRect.new()
	bg.color = cover.darkened(0.35)
	UiKit.place(self, bg, 0, 0, 1, 1, 0, 0, 0, 0)
	var spine := ColorRect.new()
	spine.color = cover.darkened(0.6)
	UiKit.place(self, spine, 0.5, 0, 0.5, 1, -8, 0, 8, 0)
	var style: StringName = d.get("style", &"print")
	for side in 2:
		var x := 40.0 if side == 0 else W - 40.0 - PAGE.x
		var sheet := Control.new()
		sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sheet.position = Vector2(x, (H - PAGE.y) * 0.5)
		sheet.size = PAGE
		add_child(sheet)
		var tint := Color(0.92, 0.89, 0.8) if style != &"news" else Color(0.86, 0.84, 0.78)
		UiStyle.paper(sheet, float(side) * 3.7 + float(hash(_id) % 13), tint, 0.5)
		var rt := RichTextLabel.new()
		rt.bbcode_enabled = true
		rt.fit_content = false
		rt.scroll_active = false
		rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rt.position = Vector2(46, 38)
		rt.size = PAGE - Vector2(80, 86)
		_style_text(rt, style)
		sheet.add_child(rt)
		var num := Label.new()
		num.add_theme_font_override("font", UiStyle.type_font())
		num.add_theme_font_size_override("font_size", 13)
		num.add_theme_color_override("font_color", Color(UiStyle.PENCIL, 0.8))
		num.position = Vector2(PAGE.x * 0.5 - 12, PAGE.y - 36)
		sheet.add_child(num)
		if side == 0:
			_left = rt
			_num_l = num
		else:
			_right = rt
			_num_r = num
	_marks = Control.new()
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marks.draw.connect(_draw_marks)
	add_child(_marks)
	var hint := UiStyle.hint(Loc.t(&"book.keys"))
	hint.add_theme_color_override("font_color", Color(0.9, 0.86, 0.76, 0.65))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.place(self, hint, 0, 1, 1, 1, 0, -22, 0, -4)
	_show()
	Game.audio.play_2d("res://assets/sfx/paper_pick.wav", -8.0)


func _style_text(rt: RichTextLabel, style: StringName) -> void:
	var font: Font = UiStyle.type_font()
	var size := 16
	var col := UiStyle.INK_TYPE
	match style:
		&"hand":
			font = UiStyle.hand_font()
			size = 27
			col = UiStyle.INK_PEN
		&"print":
			font = UiStyle.plate_font(false)
			size = 20
		&"news":
			font = UiStyle.plate_font(false)
			size = 19
	rt.add_theme_font_override("normal_font", font)
	rt.add_theme_font_override("bold_font", UiStyle.plate_font() if style != &"hand" else font)
	rt.add_theme_font_size_override("normal_font_size", size)
	rt.add_theme_font_size_override("bold_font_size", size + 4)
	rt.add_theme_color_override("default_color", col)
	rt.add_theme_constant_override("line_separation", 2 if style == &"hand" else 4)


## «|строка» — заголовок; остальное — как есть.
static func _bb(text: String) -> String:
	var out: PackedStringArray = []
	for line in text.split("\n"):
		if line.begins_with("|"):
			out.append("[b]" + line.substr(1).replace("[", "[lb]") + "[/b]")
		else:
			out.append(line.replace("[", "[lb]"))
	return "\n".join(out)


func _show() -> void:
	var li := _spread * 2
	_left.text = _bb(_pages[li]) if li < _pages.size() else ""
	_right.text = _bb(_pages[li + 1]) if li + 1 < _pages.size() else ""
	_num_l.text = "— %d —" % (li + 1) if li < _pages.size() else ""
	_num_r.text = "— %d —" % (li + 2) if li + 1 < _pages.size() else ""
	_marks.queue_redraw()


func _spreads() -> int:
	return int(ceil(_pages.size() / 2.0))


func _flip(dir: int) -> void:
	var s := clampi(_spread + dir, 0, _spreads() - 1)
	if s == _spread:
		return
	_spread = s
	Game.audio.play_2d(FLIP_SFX[randi() % FLIP_SFX.size()], -6.0)
	_show()


## Штамп «секретно», иней, опалённый край — поверх страниц.
func _draw_marks() -> void:
	var d: Dictionary = Books.DATA.get(_id, {})
	var marks: Array = d.get("marks", [])
	var y0 := (H - PAGE.y) * 0.5
	if marks.has(&"secret") and _spread == 0:
		var c := Vector2(40 + PAGE.x * 0.62, y0 + PAGE.y - 120)
		_marks.draw_set_transform(c, deg_to_rad(-9.0), Vector2.ONE)
		var txt := Loc.t(&"book.secret")
		var f := UiStyle.plate_font()
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		_marks.draw_rect(Rect2(-w * 0.5 - 10, -22, w + 20, 34), Color(UiStyle.INK_RED, 0.75), false, 3.0)
		_marks.draw_string(f, Vector2(-w * 0.5, 4), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(UiStyle.INK_RED, 0.8))
		_marks.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if marks.has(&"frost"):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(_id) + _spread * 31
		var k := 0.25 + 0.75 * float(_spread) / maxf(1.0, _spreads() - 1)   # к концу дневника инея больше
		for i in int(260 * k):
			var side := rng.randi() % 2
			var x := (40.0 if side == 0 else W - 40.0 - PAGE.x) + rng.randf() * PAGE.x
			var y := y0 + rng.randf() * PAGE.y
			var edge := minf(minf(x - 40.0, W - 40.0 - x), minf(y - y0, y0 + PAGE.y - y))
			if rng.randf() > 1.4 - edge / 120.0:
				_marks.draw_circle(Vector2(x, y), rng.randf_range(1.0, 4.5), Color(0.92, 0.96, 1.0, rng.randf_range(0.3, 0.75)))
	if marks.has(&"burnt") and _spread == _spreads() - 1:
		var x1 := W - 40.0
		var y1 := y0 + PAGE.y
		for i in 26:
			var r := 140.0 - i * 4.5
			_marks.draw_circle(Vector2(x1, y1), r, Color(0.12, 0.07, 0.03, 0.06 + i * 0.012))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				_flip(-1 if mb.position.x < W * 0.5 else 1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_flip(1)
			MOUSE_BUTTON_WHEEL_UP:
				_flip(-1)


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		closed.emit()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).physical_keycode:
			KEY_RIGHT, KEY_D:
				_flip(1)
			KEY_LEFT, KEY_A:
				_flip(-1)
	elif event is InputEventJoypadButton and event.pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_RIGHT_SHOULDER:
				_flip(1)
			JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_LEFT_SHOULDER:
				_flip(-1)


# --- Книга в мире -----------------------------------------------------------------------

## Книга или бумага в мире: предмет на столе/полке и [E] — взять и читать.
static func place(parent: Node3D, id: StringName, pos: Vector3, yaw_deg := 0.0) -> Interactable:
	var d: Dictionary = Books.DATA.get(id, {})
	var style: StringName = d.get("style", &"print")
	var cover: Color = d.get("cover", Color(0.3, 0.25, 0.2))
	var size := Vector3(0.16, 0.035, 0.23)
	match style:
		&"type":
			size = Vector3(0.21, 0.012, 0.3)
		&"news":
			size = Vector3(0.3, 0.012, 0.4)
		&"hand":
			size = Vector3(0.15, 0.03, 0.21)
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = deg_to_rad(yaw_deg)
	parent.add_child(root)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cover
	mat.roughness = 0.9
	var body := Geo.box_mesh(size, mat)
	body.position.y = size.y * 0.5
	root.add_child(body)
	if size.y > 0.02:   # обрез страниц
		var pages := Geo.box_mesh(Vector3(size.x - 0.012, size.y * 0.7, size.z - 0.01), Palette.m(&"paper"))
		pages.position = Vector3(0.006, size.y * 0.5, 0)
		root.add_child(pages)
	var it := Geo.interactable(root, size + Vector3(0.12, 0.12, 0.12), Vector3(0, size.y * 0.5, 0), null, "", func(_p: Player) -> void:
		BookUI.pending_id = id
		EventBus.ui_requested.emit(&"book"))
	it.prompt_provider = func() -> String:
		return Loc.t(&"it.book_read" if Books.is_read(id) else &"it.book", [Books.title(id)])
	it.name = "Book_" + String(id)
	return it
