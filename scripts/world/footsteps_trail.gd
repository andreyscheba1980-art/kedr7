# res://scripts/world/footsteps_trail.gd
class_name FootstepsTrail
extends Node3D

## Отключено: следы игрока штатно обрабатываются в Atmosphere._step_print
## с правильной текстурой валенка и спадом альфы (Footprints.material(&"snow")).
func _ready() -> void:
	set_physics_process(false)
	set_process(false)
