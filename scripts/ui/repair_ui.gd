class_name RepairUI
extends Control
## Ремонт руками вместо «держи E». Два вида:
##   • &"rhythm"   — стрелка ходит по шкале; [E]/[Пробел]/клик, когда она в зелёном: ключ дотянул, гвоздь вошёл.
##                   Нужно N попаданий; промах — звон и стрелка быстрее (на морозе руки не слушаются).
##   • &"sequence" — шаги по порядку (клавиши W/A/S/D на табличке): открутить, слить, продуть, закрутить.
##                   Ошибся — начинай заново. Обмороженные пальцы: шкала уже.
## Открывается через RepairUI.open(...) → EventBus.ui_requested(&"repair"). [Esc] — бросить.

signal closed

const KEYS := [KEY_W, KEY_A, KEY_S, KEY_D]
const KEY_NAMES := ["W", "A", "S", "D"]

static var _req: Dictionary = {}

var _kind := &"rhythm"
var _title := ""
var _steps: PackedStringArray = []
var _on_done: Callable
var _need := 3
var _hits := 0
var _pos := 0.0
var _dir := 1.0
var _speed := 0.9
var _zone := Vector2(0.42, 0.58)
var _seq: Array[int] = []
var _seq_i := 0
var _flash := 0.0
var _flash_col := Color.WHITE
var _done := false
var _status := ""


## kind: &"rhythm" или &"sequence"; steps — подписи шагов (для sequence — по одному на клавишу).
static func open(kind: StringName, title_key: StringName, on_done: Callable, need := 3, steps: Array = []) -> void:
	_req = {"kind": kind, "title": Loc.t(title_key), "done": on_done, "need": need, "steps": steps}
	EventBus.ui_requested.emit(&"repair")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_kind = _req.get("kind", &"rhythm")
	_title = _req.get("title", "")
	_on_done = _req.get("done", Callable())
	_need = int(_req.get("need", 3))
	for s in _req.get("steps", []):
		_steps.append(Loc.t(StringName(s)))
	_req = {}
	var k := Consequences.hands_k()     # обморожение: < 1 — пальцы не гнутся
	var w := 0.16 * (1.0 if k >= 1.0 else 0.7)
	var c := randf_range(0.3, 0.7)
	_zone = Vector2(c - w * 0.5, c + w * 0.5)
	_speed = 0.8 + Game.night * 0.04
	if _kind == &"sequence":
		for i in maxi(_steps.size(), 3):
			_seq.append(randi() % KEYS.size())
	_status = Loc.t(&"rep.hint_rhythm") if _kind == &"rhythm" else Loc.t(&"rep.hint_seq")


func _process(delta: float) -> void:
	if _kind == &"rhythm" and not _done:
		_pos += _dir * _speed * delta
		if _pos > 1.0:
			_pos = 1.0
			_dir = -1.0
		elif _pos < 0.0:
			_pos = 0.0
			_dir = 1.0
	_flash = maxf(_flash - delta * 2.5, 0.0)
	queue_redraw()


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		closed.emit()
		return
	if _done:
		return
	if _kind == &"rhythm":
		var hit: bool = event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept") \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
		if hit:
			_strike()
	elif event is InputEventKey and event.pressed and not event.echo:
		var idx := KEYS.find(event.physical_keycode)
		if idx >= 0:
			_press(idx)


func _strike() -> void:
	if _pos >= _zone.x and _pos <= _zone.y:
		_hits += 1
		_flash = 1.0
		_flash_col = Color(0.4, 0.8, 0.35)
		Game.audio.play_2d("res://assets/audio/clank.ogg", -6.0)
		if _hits >= _need:
			_finish()
			return
		var c := randf_range(0.22, 0.78)
		var w := _zone.y - _zone.x
		_zone = Vector2(c - w * 0.5, c + w * 0.5)
	else:
		_flash = 1.0
		_flash_col = Color(0.85, 0.2, 0.15)
		_speed *= 1.08
		Game.audio.play_2d("res://assets/audio/ice_hit.ogg", -10.0)
		_status = Loc.t(&"rep.miss")


func _press(idx: int) -> void:
	if idx == _seq[_seq_i]:
		_seq_i += 1
		_flash = 0.6
		_flash_col = Color(0.4, 0.8, 0.35)
		Game.audio.play_2d("res://assets/audio/clank.ogg", -8.0)
		if _seq_i >= _seq.size():
			_finish()
	else:
		_seq_i = 0
		_flash = 1.0
		_flash_col = Color(0.85, 0.2, 0.15)
		Game.audio.play_2d("res://assets/audio/ice_hit.ogg", -10.0)
		_status = Loc.t(&"rep.wrong")


func _finish() -> void:
	_done = true
	_status = Loc.t(&"rep.done")
	get_tree().create_timer(0.6, false).timeout.connect(func() -> void:
		closed.emit()
		if _on_done.is_valid():
			_on_done.call())


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.5))
	var sheet := Rect2(size * 0.5 - Vector2(360, 170), Vector2(720, 340))
	draw_rect(sheet, UiKit.PAPER)
	draw_rect(sheet.grow(-8), Color(0.4, 0.33, 0.25, 0.5), false, 2.0)
	var font := UiKit.theme().default_font
	var ink := UiKit.INK
	draw_string(font, sheet.position + Vector2(28, 44), _title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, ink)
	draw_string(font, sheet.position + Vector2(28, sheet.size.y - 24), Loc.t(&"rep.esc"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(ink, 0.55))
	if _kind == &"rhythm":
		var bar := Rect2(sheet.position + Vector2(50, 130), Vector2(sheet.size.x - 100, 34))
		draw_rect(bar, Color(0.25, 0.22, 0.2))
		var zr := Rect2(bar.position + Vector2(bar.size.x * _zone.x, 0), Vector2(bar.size.x * (_zone.y - _zone.x), bar.size.y))
		draw_rect(zr, Color(0.35, 0.62, 0.3))
		var x := bar.position.x + bar.size.x * _pos
		draw_line(Vector2(x, bar.position.y - 10), Vector2(x, bar.end.y + 10), Color(0.75, 0.12, 0.08), 4.0)
		for i in _need:
			var cc := sheet.position + Vector2(sheet.size.x * 0.5 + (i - (_need - 1) * 0.5) * 34, 210)
			draw_circle(cc, 11, Color(0.35, 0.62, 0.3) if i < _hits else Color(ink, 0.25))
	else:
		for i in _seq.size():
			var bx := Rect2(sheet.position + Vector2(60 + i * 150, 105), Vector2(120, 110))
			var col := Color(0.35, 0.62, 0.3, 0.35) if i < _seq_i else Color(ink, 0.08)
			draw_rect(bx, col)
			draw_rect(bx, Color(ink, 0.5), false, 1.5)
			draw_string(font, bx.position + Vector2(40, 52), KEY_NAMES[_seq[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 36, ink)
			if i < _steps.size():
				draw_string(font, bx.position + Vector2(8, 92), _steps[i], HORIZONTAL_ALIGNMENT_LEFT, 104, 13, Color(ink, 0.8))
	draw_string(font, sheet.position + Vector2(28, 270), _status, HORIZONTAL_ALIGNMENT_LEFT, sheet.size.x - 56, 16, ink)
	if _flash > 0.0:
		draw_rect(sheet, Color(_flash_col, _flash * 0.25))
