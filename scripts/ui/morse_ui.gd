class_name MorseUI
extends Control
## Расшифровка морзе по записи: лента ондулятора (точки и тире, буквы через пробел, слова через «/»),
## рядом — таблица азбуки. Дежурный сам переводит и вписывает текст; совпало — передача прочитана.

signal closed

static var pending_id: StringName = &"morse"   ## какую передачу открыть (ставит журнал перехватов)

var _id: StringName = &"morse"
var _input: LineEdit
var _result: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_id = pending_id
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	UiKit.place(self, dim, 0, 0, 1, 1, 0, 0, 0, 0)
	var panel := UiKit.panel(UiKit.PAPER)
	UiKit.place(self, panel, 0.5, 0.5, 0.5, 0.5, -560, -330, 560, 330)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 30)
	panel.add_child(cols)

	var left := VBoxContainer.new()
	cols.add_child(left)
	left.add_child(UiKit.ink(UiKit.label(Loc.t(&"morse.table"), 18)))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 1)
	left.add_child(grid)
	var table: Dictionary = Efir.MORSE_EN if Settings.language == "en" else Efir.MORSE_RU
	for ch: String in table:
		grid.add_child(UiKit.ink(UiKit.label("%s  %s" % [ch, String(table[ch]).replace(".", "·").replace("-", "−")], 15)))

	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 560
	right.add_theme_constant_override("separation", 12)
	cols.add_child(right)
	right.add_child(UiKit.ink(UiKit.label(Loc.t(&"morse.title", [Efir.tape_name(_id)]), 18)))
	var tape_text := Loc.t(&"morse.no_tape")
	if SaveGame.tapes.has(_id):
		tape_text = Efir.morse_of(Efir.plain(_id))
	var tape := UiKit.ink(UiKit.label(tape_text, 22))
	tape.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tape.custom_minimum_size.x = 540
	right.add_child(tape)
	right.add_child(UiKit.ink(UiKit.label(Loc.t(&"morse.answer"), 15)))
	_input = LineEdit.new()
	_input.placeholder_text = Loc.t(&"morse.placeholder")
	_input.text_submitted.connect(func(_t: String) -> void: _check())
	right.add_child(_input)
	var row := HBoxContainer.new()
	right.add_child(row)
	row.add_child(UiKit.button(Loc.t(&"code.check"), _check))
	row.add_child(UiKit.button(Loc.t(&"ui.close"), func() -> void: closed.emit()))
	_result = UiKit.ink(UiKit.label("", 16))
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.custom_minimum_size.x = 540
	right.add_child(_result)
	if Efir.is_decoded(_id):
		_result.text = Loc.t(&"morse.solved", [Efir.plain(_id)])
		_input.text = Efir.plain(_id)
	_input.grab_focus.call_deferred()


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		closed.emit()


func _check() -> void:
	if not SaveGame.tapes.has(_id):
		_result.text = Loc.t(&"morse.no_tape")
		return
	var want := Signals.normalize(Efir.plain(_id))
	var got := Signals.normalize(_input.text)
	if got == want:
		if Game.mark_decoded(StringName(String(_id) + "_dec")):
			Director.add_tension(6.0, "расшифровка морзе")
			SaveGame.write()
		_result.text = Loc.t(&"morse.solved", [Efir.plain(_id)])
		return
	var ok := 0
	for i in mini(got.length(), want.length()):
		if got[i] == want[i]:
			ok += 1
	_result.text = Loc.t(&"morse.partial", [ok, want.length()])
