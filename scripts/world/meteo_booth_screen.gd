class_name MeteoBoothScreen
extends Node3D
## Советская психрометрическая будка Селянинова с распашными жалюзийными створками,
## открывающимися строго на север, защёлкой-крючком, гвоздём для ФАС-4 и набором приборов.

signal doors_state_changed(is_open: bool)

var is_open: bool = false
var is_frozen: bool = false
var door_l: Node3D
var door_r: Node3D

func setup(p_door_l: Node3D, p_door_r: Node3D) -> void:
	door_l = p_door_l
	door_r = p_door_r


func open_doors(animate: bool = true) -> void:
	if is_open:
		return
	is_open = true
	doors_state_changed.emit(true)
	if door_l != null and door_r != null:
		if animate:
			var tw := create_tween().set_parallel(true)
			tw.tween_property(door_l, "rotation:y", -deg_to_rad(108.0), 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(door_r, "rotation:y", deg_to_rad(108.0), 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			door_l.rotation.y = -deg_to_rad(108.0)
			door_r.rotation.y = deg_to_rad(108.0)


func close_doors(animate: bool = true) -> void:
	if not is_open:
		return
	is_open = false
	doors_state_changed.emit(false)
	if door_l != null and door_r != null:
		if animate:
			var tw := create_tween().set_parallel(true)
			tw.tween_property(door_l, "rotation:y", 0.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(door_r, "rotation:y", 0.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		else:
			door_l.rotation.y = 0.0
			door_r.rotation.y = 0.0
