class_name SupplyUI
extends Control
## Бланк заявки на снабжение: что заказать на пайки. Ящик сбросят с вертолёта к утру.

signal closed

var _rations: Label
var _list: VBoxContainer
var _status: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	UiKit.place(self, dim, 0, 0, 1, 1, 0, 0, 0, 0)
	var panel := UiKit.panel(UiKit.PAPER)
	UiKit.place(self, panel, 0.5, 0.5, 0.5, 0.5, -430, -300, 430, 300)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(UiKit.ink(UiKit.label(Loc.t(&"sup.title"), 22)))
	var hint := UiKit.ink(UiKit.label(Loc.t(&"sup.hint"), 14))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 800
	col.add_child(hint)
	_rations = UiKit.ink(UiKit.label("", 18))
	col.add_child(_rations)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	col.add_child(_list)
	_status = UiKit.ink(UiKit.label("", 15))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 800
	col.add_child(_status)
	col.add_child(UiKit.button(Loc.t(&"ui.close"), func() -> void: closed.emit()))
	_refresh()


func _refresh() -> void:
	_rations.text = Loc.t(&"sup.rations", [Supply.rations()])
	for c in _list.get_children():
		c.queue_free()
	var first: Button = null
	for id: StringName in Supply.ORDER:
		var it: Array = Supply.ITEMS[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var b := UiKit.button(Loc.t(&"sup.order_btn", [Loc.t(it[1]), int(it[0])]), func() -> void: _order(id))
		b.custom_minimum_size.x = 330
		b.disabled = not Supply.can_order(id)
		row.add_child(b)
		var d := UiKit.ink(UiKit.label(Loc.t(it[2]), 14))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 450
		row.add_child(d)
		_list.add_child(row)
		if first == null and not b.disabled:
			first = b
	var pend := Supply.pending()
	if not pend.is_empty():
		var names: PackedStringArray = []
		for s: String in pend:
			names.append(Loc.t(Supply.ITEMS[StringName(s)][1]))
		_status.text = Loc.t(&"sup.pending", [", ".join(names)])
	if first != null:
		first.grab_focus.call_deferred()


func _order(id: StringName) -> void:
	if Supply.order(id):
		Game.audio.play_2d("res://assets/audio/clank.ogg", -10.0)
	_refresh()


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"drop") or event.is_action_pressed(&"ui_cancel"):
		closed.emit()
