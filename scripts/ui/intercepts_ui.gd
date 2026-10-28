class_name InterceptsUI
extends Control
## Журнал перехватов (J): все сигналы эфира, что пойман, что записан, что проступило при чистке.
## Непойманные — «???» с подсказкой-диапазоном: повод крутить шкалу и перепроходить ночи.

signal closed

var _scroll: ScrollContainer

## Порядок — как встречаются по сюжету. Служебные сигналы заданий сюда не попадают.
const ORDER: Array[StringName] = [&"buzzer", &"numbers", &"semenov", &"morse", &"code", &"lullaby",
	&"alone", &"mother", &"roll", &"otzvuk", &"echo", &"old_call"]


## Сюжетные сигналы + эфирная сетка (станции и дневник Семёнова по ночам).
static func order() -> Array[StringName]:
	var o: Array[StringName] = ORDER.duplicate()
	o.append_array(Signals.broadcast_ids())
	for id: StringName in SaveGame.intercepts:   # случайный эфир — только пойманное
		if Efir.is_pool(id) and not o.has(id):
			o.append(id)
	return o


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	UiKit.place(self, dim, 0, 0, 1, 1, 0, 0, 0, 0)
	var panel := UiKit.panel(UiKit.PAPER)
	UiKit.place(self, panel, 0.5, 0.5, 0.5, 0.5, -560, -330, 560, 330)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var found := 0
	for id in order():
		if SaveGame.intercepts.has(id):
			found += 1
	box.add_child(UiKit.ink(UiKit.label(Loc.t(&"icp.title"), 20)))
	box.add_child(UiKit.ink(UiKit.label(Loc.t(&"icp.count", [found, order().size(), SaveGame.tapes.size(), _cleaned()]), 14)))

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(1060, 520)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	box.add_child(_scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(list)
	for id in order():
		list.add_child(_row(id))
	box.add_child(UiKit.ink(UiKit.label(Loc.t(&"icp.close"), 13)))


func _row(id: StringName) -> Control:
	var known := SaveGame.intercepts.has(id)
	var def := Signals.get_def(id)
	var v := VBoxContainer.new()
	var head := ""
	if known:
		var name_key := StringName("tape." + String(id))
		if Efir.is_pool(id):
			head = Efir.tape_name(id)
		else:
			head = Loc.t(name_key) if Loc.has_key(name_key) else Loc.t(&"icp.unknown_name", [def.get("freq", 0.0)])
		var marks: PackedStringArray = []
		if SaveGame.tapes.has(id):
			marks.append(Loc.t(&"icp.taped"))
		if SaveGame.decoded.has(StringName(String(id) + "_clean")) or (id == &"code" and SaveGame.decoded.has(&"code")):
			marks.append(Loc.t(&"icp.cleaned"))
		if not marks.is_empty():
			head += "   [" + ", ".join(marks) + "]"
	else:
		var f := float(def.get("freq", 0.0))
		head = Loc.t(&"icp.hidden", [int(f / 1000.0) * 1000, int(f / 1000.0) * 1000 + 1000]) if f > 0.0 else Loc.t(&"icp.hidden_any")
	var l := UiKit.ink(UiKit.label(head, 16))
	if not known:
		l.modulate = Color(1, 1, 1, 0.55)
	v.add_child(l)
	if known:
		var lines: Array = def.get("lines", [])
		var text := Loc.t(lines[0]) if not lines.is_empty() else ""
		var hidden: Dictionary = (def.get("tape", {}) as Dictionary).get("hidden", {})
		if SaveGame.decoded.has(StringName(String(id) + "_clean")) and hidden.has("text"):
			text += "\n" + Loc.t(hidden["text"])
		elif id == &"code" and SaveGame.decoded.has(&"code"):
			text += "\n" + Loc.t(&"code.solved")
		elif not hidden.is_empty() and Game.has_item(&"tape_recorder"):
			text += "\n" + Loc.t(&"icp.has_hidden")
		if Efir.kind_of(id) != &"" and id != &"code" and Efir.is_decoded(id):
			text += "\n" + Loc.t(&"icp.decoded", [Efir.plain(id)])
		var efir := _efir_line(id)
		if efir != "":
			text += "\n" + efir
		var d := UiKit.ink(UiKit.label("    " + text.replace("\n", "\n    "), 14))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 1000
		v.add_child(d)
		var kind := Efir.kind_of(id)
		if kind != &"" and not Efir.is_decoded(id) and SaveGame.tapes.has(id):
			var row := HBoxContainer.new()
			var btn := UiKit.button(Loc.t(&"icp.decode"), _open_decoder.bind(id, kind))
			row.add_child(btn)
			v.add_child(row)
	return v


## Пеленги и квадрат на схеме — строкой под перехватом.
func _efir_line(id: StringName) -> String:
	if not Efir.can_bearing(id):
		return ""
	var parts: PackedStringArray = []
	for point: StringName in Efir.POINTS:
		var az := Efir.df(id, point)
		parts.append(Loc.t(StringName("icp.df_" + String(point)), ["%03d°" % int(az) if az >= 0.0 else "—"]))
	var cr := Efir.cross(id)
	var tail := ""
	if cr.size() == 2:
		tail = Loc.t(&"icp.df_square")
	elif cr.size() == 1:
		tail = Loc.t(&"icp.df_far")
	return Loc.t(&"icp.df", [" · ".join(parts)]) + ("  " + tail if tail != "" else "")


func _open_decoder(id: StringName, kind: StringName) -> void:
	if kind == &"cipher" and not Game.has_item(&"codebook"):
		Game.hud.subtitle(Loc.t(&"icp.need_codebook"), 3.5)
		return
	closed.emit()
	if kind == &"morse":
		MorseUI.pending_id = id
		EventBus.ui_requested.emit.call_deferred(&"morse")
	else:
		CodebookUI.pending_id = id
		EventBus.ui_requested.emit.call_deferred(&"codebook")


func _cleaned() -> int:
	var n := 0
	for d in SaveGame.decoded:
		if String(d).ends_with("_clean") or d == &"code":
			n += 1
	return n


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"intercepts") or event.is_action_pressed(&"pause") or event.is_action_pressed(&"interact") or event.is_action_pressed(&"drop") or event.is_action_pressed(&"ui_cancel"):
		closed.emit()
	elif event.is_action_pressed(&"ui_down"):
		if _scroll != null:
			_scroll.scroll_vertical += 70
	elif event.is_action_pressed(&"ui_up"):
		if _scroll != null:
			_scroll.scroll_vertical = maxi(0, _scroll.scroll_vertical - 70)
