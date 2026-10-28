class_name Interactable
extends StaticBody3D
## Объект, с которым можно взаимодействовать по E.
## hold_time > 0 — нужно удерживать E (сбить лёд, снять показания). Подсказка — строка или функция.

signal used(player: Player)

@export var prompt := "[E] Использовать"
@export var hold_time := 0.0
@export var hold_sound := ""      ## звук, повторяющийся во время удержания (удары по льду и т.п.)
var prompt_provider: Callable
var hold_check: Callable          ## если задан и вернул false — удержание не начинается
var enabled := true


func get_prompt() -> String:
	if prompt_provider.is_valid():
		return prompt_provider.call()
	if prompt == "[E] Использовать":
		return Loc.t(&"it.use")   # значение по умолчанию из инспектора — по языку игры
	return prompt


func can_hold() -> bool:
	return not hold_check.is_valid() or bool(hold_check.call())


func interact(p: Player) -> void:
	if enabled:
		used.emit(p)
