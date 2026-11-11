class_name TelemetryButton
extends Button
## Аутентичная советская телеметрическая кнопка интерфейса станции «Кедр-7».
## Без дефолтных прямоугольных рамок Godot: гладкий отклик, янтарный курсор,
## смещение вправо при наведении и аппаратный щелчок реле.

@export var index_code: String = "КН-01"
@export var label_title: String = "ПРИСТУПИТЬ К ВАХТЕ"
@export var status_hint: String = ""

const COLOR_IDLE := Color("#687873")
const COLOR_NORMAL_TEXT := Color("#C5CFCB")
const COLOR_FOCUS := Color("#FFA62B")
const COLOR_BG_GLOW := Color(1.0, 0.65, 0.17, 0.15)

var _hover_weight: float = 0.0
var _shift_x: float = 0.0
var _tween: Tween


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(450.0, 42.0)
	text = "" # Отрисовка текста выполняется кастомно в _draw
	
	# Убираем все дефолтные прямоугольные рамки Godot
	var empty := StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty)
	add_theme_stylebox_override("hover", empty)
	add_theme_stylebox_override("pressed", empty)
	add_theme_stylebox_override("focus", empty)
	add_theme_stylebox_override("disabled", empty)
	
	mouse_entered.connect(_on_focused)
	focus_entered.connect(_on_focused)
	mouse_exited.connect(_on_unfocused)
	focus_exited.connect(_on_unfocused)
	pressed.connect(_on_pressed)


func set_data(idx: String, title: String, hint := "") -> void:
	index_code = idx
	label_title = title
	status_hint = hint
	queue_redraw()


func _on_focused() -> void:
	if is_inside_tree():
		AudioDirector.play_raw("res://assets/audio/ui_tick.ogg", -12.0)
	_animate_state(1.0, 10.0)


func _on_unfocused() -> void:
	_animate_state(0.0, 0.0)


func _on_pressed() -> void:
	if is_inside_tree():
		AudioDirector.play_raw("res://assets/audio/clank.ogg", -6.0)


func _animate_state(target_weight: float, target_shift: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "_hover_weight", target_weight, 0.16)
	_tween.tween_property(self, "_shift_x", target_shift, 0.16)


func _process(_delta: float) -> void:
	if _hover_weight > 0.001 or _shift_x > 0.001 or is_hovered() or has_focus():
		queue_redraw()


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var font_size: int = get_theme_default_font_size()
	if font_size <= 0:
		font_size = 15
	var h: float = size.y
	var w: float = size.x

	# 1. Мягкая янтарная полоса и нижняя телеметрическая черта при наведении
	if _hover_weight > 0.01:
		var glow_col := COLOR_BG_GLOW
		glow_col.a *= _hover_weight
		draw_rect(Rect2(0.0, 2.0, w * _hover_weight, h - 4.0), glow_col, true)
		
		var line_col := COLOR_FOCUS
		line_col.a = _hover_weight * 0.85
		draw_line(Vector2(0.0, h - 2.0), Vector2(w * _hover_weight, h - 2.0), line_col, 1.0)
		
		# Левый маркер-блок "▌"
		draw_rect(Rect2(0.0, 6.0, 4.0, h - 12.0), line_col, true)

	# 2. Технический индекс слева (например: [КН-01])
	var idx_col := COLOR_IDLE.lerp(COLOR_FOCUS, _hover_weight)
	var idx_text := "[" + index_code + "]"
	draw_string(font, Vector2(14.0, h * 0.65), idx_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 2, idx_col)
	
	# 3. Основной текст пункта со смещением _shift_x
	var main_col := COLOR_NORMAL_TEXT.lerp(COLOR_FOCUS, _hover_weight)
	if _hover_weight > 0.8 and Engine.get_process_frames() % 6 == 0:
		main_col = main_col.lightened(0.08)

	var hint_w := clampf(w * 0.40, 130.0, 220.0) if not status_hint.is_empty() else 0.0
	var title_max_w := (w - hint_w - 110.0) if not status_hint.is_empty() else (w - 110.0)
	draw_string(font, Vector2(96.0 + _shift_x, h * 0.66), label_title, HORIZONTAL_ALIGNMENT_LEFT, title_max_w, font_size + 2, main_col)
	
	# 4. Дополнительный статус справа (например: "СУТКИ 03 // -41°C")
	if not status_hint.is_empty():
		var hint_pos_x := w - hint_w - 16.0
		draw_string(font, Vector2(hint_pos_x, h * 0.65), status_hint, HORIZONTAL_ALIGNMENT_RIGHT, hint_w, font_size - 3, idx_col)
