class_name ContentWarning
extends Control
## Первый запуск, после выбора языка: что за игра (хоррор, резкие звуки, мигание света), «играйте
## в наушниках» — половина испугов теперь звуком, — пометка «ДЕМО» и куда слать отзыв (F9-отчёт).

signal done

var _shown_at := 0


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_shown_at = Time.get_ticks_msec()
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.015, 0.025)
	UiKit.place(self, bg, 0, 0, 1, 1, 0, 0, 0, 0)
	var demo := UiKit.label(Loc.t(&"warn.demo"), 16, HORIZONTAL_ALIGNMENT_CENTER)
	demo.add_theme_color_override("font_color", UiKit.AMBER)
	UiKit.place(self, demo, 0.5, 0.5, 0.5, 0.5, -480, -230, 480, -200)
	var title := UiKit.label(Loc.t(&"warn.title"), 30, HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.place(self, title, 0.5, 0.5, 0.5, 0.5, -480, -180, 480, -130)
	var body := UiKit.label(Loc.t(&"warn.body"), 18, HORIZONTAL_ALIGNMENT_CENTER)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.modulate = Color(1, 1, 1, 0.85)
	UiKit.place(self, body, 0.5, 0.5, 0.5, 0.5, -460, -110, 460, 40)
	var phones := UiKit.label(Loc.t(&"warn.headphones"), 20, HORIZONTAL_ALIGNMENT_CENTER)
	phones.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	UiKit.place(self, phones, 0.5, 0.5, 0.5, 0.5, -460, 60, 460, 95)
	var f9 := UiKit.label(Loc.t(&"warn.f9"), 15, HORIZONTAL_ALIGNMENT_CENTER)
	f9.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	f9.modulate = Color(1, 1, 1, 0.6)
	UiKit.place(self, f9, 0.5, 0.5, 0.5, 0.5, -460, 110, 460, 160)
	var ok := UiKit.button(Loc.t(&"warn.ok"), _accept)
	UiKit.place(self, ok, 0.5, 0.5, 0.5, 0.5, -140, 185, 140, 240)
	ok.grab_focus.call_deferred()


func _accept() -> void:
	if Time.get_ticks_msec() - _shown_at < 800:
		return   # случайный двойной клик с экрана языка не должен пролистать предупреждение
	Settings.warned = true
	Settings.save()
	done.emit()
