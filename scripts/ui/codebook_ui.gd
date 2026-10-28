class_name CodebookUI
extends Control
## Шифроблокнот Семёнова: таблица «буква → две цифры» и поле для расшифровки перехвата.
## Шифровка ночи 3 (&"code") и случайные цифровые передачи эфира (Efir) — той же таблицей.

signal closed

static var pending_id: StringName = &"code"   ## какую шифровку открыть (ставит журнал перехватов)

var _id: StringName = &"code"

var _input: LineEdit
var _result: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_id = pending_id
	pending_id = &"code"
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	UiKit.place(self, dim, 0, 0, 1, 1, 0, 0, 0, 0)

	var panel := UiKit.panel(UiKit.PAPER)
	UiKit.place(self, panel, 0.5, 0.5, 0.5, 0.5, -540, -320, 540, 320)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 30)
	panel.add_child(cols)

	var left := VBoxContainer.new()
	cols.add_child(left)
	left.add_child(UiKit.ink(UiKit.label(Loc.t(&"code.title"), 20)))
	left.add_child(UiKit.ink(UiKit.label(Loc.t(&"code.table"), 14)))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 2)
	left.add_child(grid)
	var table := Signals.cipher_table(Settings.language)
	var letters: String = Signals.ALPHABET.get(Settings.language, Signals.ALPHABET["ru"])
	for i in range(letters.length()):
		var ch := letters[i]
		grid.add_child(UiKit.ink(UiKit.label("%s — %s" % [ch, table[ch]], 16)))

	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 440
	right.add_theme_constant_override("separation", 12)
	cols.add_child(right)
	right.add_child(UiKit.ink(UiKit.label(Loc.t(&"code.intercept"), 16)))
	var groups_text := Loc.t(&"code.no_tape")
	if SaveGame.tapes.has(_id):
		groups_text = " ".join(Efir.cipher_groups(_id))
	var groups := UiKit.ink(UiKit.label(groups_text, 22))
	groups.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	groups.custom_minimum_size.x = 420
	right.add_child(groups)
	right.add_child(UiKit.ink(UiKit.label(Loc.t(&"code.answer"), 16)))
	_input = LineEdit.new()
	_input.placeholder_text = Loc.t(&"code.placeholder")
	_input.text_submitted.connect(func(_t: String) -> void: _check())
	right.add_child(_input)
	var row := HBoxContainer.new()
	right.add_child(row)
	row.add_child(UiKit.button(Loc.t(&"code.check"), _check))
	row.add_child(UiKit.button(Loc.t(&"ui.close"), func() -> void: closed.emit()))
	_result = UiKit.ink(UiKit.label("", 16))
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_result)
	if _id == &"code" and SaveGame.decoded.has(&"code"):
		_result.text = Loc.t(&"code.solved") + "\n\n" + Loc.t(&"code.solved_brg", [int(fposmod(rad_to_deg(FieldJobs.bearing_angle("izba")), 360.0))])
	elif _id != &"code" and Efir.is_decoded(_id):
		_result.text = Loc.t(&"morse.solved", [Efir.plain(_id)])
	_input.grab_focus.call_deferred()


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"drop") or event.is_action_pressed(&"codebook") or event.is_action_pressed(&"ui_cancel"):
		closed.emit()


func _check() -> void:
	var answer := Signals.normalize(_input.text)
	if _id != &"code":
		if SaveGame.tapes.has(_id) and answer == Signals.normalize(Efir.plain(_id)):
			if Game.mark_decoded(StringName(String(_id) + "_dec")):
				Director.add_tension(6.0, "расшифровка цифровой передачи")
				SaveGame.write()
			_result.text = Loc.t(&"morse.solved", [Efir.plain(_id)])
		else:
			_result.text = Loc.t(&"code.wrong")
		return
	var word: String = Signals.CODE_WORD.get(Settings.language, Signals.CODE_WORD["ru"])
	if answer == word and SaveGame.tapes.has(&"code"):
		if Game.mark_decoded(&"code"):
			Director.add_tension(12.0, "расшифровка: НЕ ОТКРЫВАЙ")
		_result.text = Loc.t(&"code.solved") + "\n\n" + Loc.t(&"code.solved_brg", [int(fposmod(rad_to_deg(FieldJobs.bearing_angle("izba")), 360.0))])
		FieldJobs.record_bearing("izba")      # хвост шифровки — азимут и «изба»: пеленг от избы (хребет, день 2)
		SaveGame.write()
	else:
		_result.text = Loc.t(&"code.wrong")
