class_name LanguagePick
extends Control
## Первый запуск: выбор языка — до калибровки яркости и до меню. Подписи сразу на обоих языках.

signal done


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.015, 0.025)
	UiKit.place(self, bg, 0, 0, 1, 1, 0, 0, 0, 0)
	var title := UiKit.label("Язык  ·  Language", 30, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_color", UiKit.AMBER)
	UiKit.place(self, title, 0.5, 0.5, 0.5, 0.5, -400, -150, 400, -100)
	var ru := UiKit.button("Русский", func() -> void: _pick("ru"))
	UiKit.place(self, ru, 0.5, 0.5, 0.5, 0.5, -220, -40, -20, 20)
	var en := UiKit.button("English", func() -> void: _pick("en"))
	UiKit.place(self, en, 0.5, 0.5, 0.5, 0.5, 20, -40, 220, 20)
	var note := UiKit.label("Можно поменять в Настройках  ·  You can change it later in Settings", 15, HORIZONTAL_ALIGNMENT_CENTER)
	note.modulate = Color(1, 1, 1, 0.55)
	UiKit.place(self, note, 0.5, 0.5, 0.5, 0.5, -420, 60, 420, 90)
	(ru if Settings.language == "ru" else en).grab_focus.call_deferred()


func _pick(lang: String) -> void:
	Settings.language = lang
	Settings.lang_chosen = true
	Settings.save()
	Settings.apply()
	done.emit()
