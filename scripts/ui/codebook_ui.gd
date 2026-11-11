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
	left.add_child(UiKit.ink(UiKit.label(Loc.p("БЛАНК Ф-14 · ШИФРОБЛОКНОТ «КАМА»", "FORM F-14 · 'KAMA' ONE-TIME PAD"), 18)))
	left.add_child(UiKit.ink(UiKit.label(Loc.p("Вычитание по модулю 10 без заёма десятка: (A + 10 - B) mod 10", "Modulo 10 subtraction without borrow: (A + 10 - B) mod 10"), 12)))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 2)
	left.add_child(grid)
	var table := Signals.cipher_table(Settings.language)
	var letters: String = Signals.ALPHABET.get(Settings.language, Signals.ALPHABET["ru"])
	for i in range(letters.length()):
		var ch := letters[i]
		grid.add_child(UiKit.ink(UiKit.label("%s — %s" % [ch, table[ch]], 15)))

	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 460
	right.add_theme_constant_override("separation", 10)
	cols.add_child(right)
	right.add_child(UiKit.ink(UiKit.label(Loc.p("ПЕРЕХВАТ РАДИОГРАММЫ (5-ЗНАЧНЫЕ ГРУППЫ):", "RADIO CIPHERGRAM INTERCEPT:"), 14)))
	var groups_text := Loc.t(&"code.no_tape")
	var gamma_text := ""
	if SaveGame.tapes.has(_id):
		var raw_grps := Efir.cipher_groups(_id)
		groups_text = " ".join(raw_grps)
		# Гамма шифроблокнота «Кама» для снятия шифра:
		gamma_text = Loc.p("КЛЮЧЕВАЯ ГАММА (ОДНОРАЗОВЫЙ ЛИСТ №%d):\n" % (48 if Game.night >= 4 else 12), "KEY GAMMA (OTP SHEET #%d):\n" % (48 if Game.night >= 4 else 12))
		var g_chunks: Array[String] = []
		for grp in raw_grps:
			var g_str := ""
			for c in grp:
				g_str += str((int(c) + 7) % 10)
			g_chunks.append(g_str)
		gamma_text += " ".join(g_chunks)

	var groups := UiKit.ink(UiKit.label(groups_text, 20))
	groups.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	groups.custom_minimum_size.x = 440
	right.add_child(groups)

	if gamma_text != "":
		var gamma_lbl := UiKit.ink(UiKit.label(gamma_text, 14))
		gamma_lbl.modulate = Color(0.2, 0.45, 0.65)
		right.add_child(gamma_lbl)

	right.add_child(UiKit.ink(UiKit.label(Loc.t(&"code.answer"), 14)))
	_input = LineEdit.new()
	_input.placeholder_text = Loc.t(&"code.placeholder")
	_input.text_submitted.connect(func(_t: String) -> void: _check())
	right.add_child(_input)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	right.add_child(row)
	row.add_child(UiKit.button(Loc.t(&"code.check"), _check))
	row.add_child(UiKit.button(Loc.p("Сжечь лист в печи [КГБ]", "Burn OTP sheet [KGB]"), func() -> void:
		Game.audio.play_2d("res://assets/audio/clank.ogg", -4.0)
		Director.add_tension(-4.0, "сжигание использованного листа шифроблокнота")
		Game.hud.subtitle(Loc.p("Использованный листок шифроблокнота «Кама» сожжён в чугунной печи.", "Used 'Kama' cipher sheet incinerated in the cast-iron stove."), 3.5)
	))
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
		var solved_msg: String = Loc.t(&"code.solved")
		if Game.night >= 4:
			solved_msg = Loc.p("ПРОВЕРИТЬ ШТОЛЬНЮ И ВЕРНУТЬСЯ... НЕ СМОТРИ В ОКНО ЗА СПИНОЙ\n[В эфир станции вклинился передатчик Ырки с ключами вашего шифроблокнота!]", "CHECK THE ADIT AND RETURN... DO NOT LOOK OUT THE WINDOW BEHIND YOU\n[Yrka's transmitter hijacked the airwaves using your own OTP keys!]")
		_result.text = solved_msg + "\n\n" + Loc.t(&"code.solved_brg", [int(fposmod(rad_to_deg(FieldJobs.bearing_angle("izba")), 360.0))])
		FieldJobs.record_bearing("izba")      # хвост шифровки — азимут и «изба»: пеленг от избы (хребет, день 2)
		SaveGame.write()
	else:
		_result.text = Loc.t(&"code.wrong")
