# res://scripts/world/footsteps_trail.gd
class_name FootstepsTrail
extends Node3D

## Динамическая цепочка следов на снегу.
## Заметается метелью (от 240 до 90 с в зависимости от Storm.intensity).
## Служит ориентиром для возвращения в избу.

const POOL := 80
const STRIDE := 0.75

var player: CharacterBody3D = null
var _pool: Array[MeshInstance3D] = []
var _age: Array[float] = []
var _idx := 0
var _left := false
var _last := Vector3.INF

func _ready() -> void:
	for i in POOL:
		var pm := PlaneMesh.new()
		pm.size = Vector2(0.24, 0.42)
		var m := MeshInstance3D.new()
		m.mesh = pm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.12, 0.18, 0.28, 0.0)
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m.material_override = mat
		m.visible = false
		add_child(m)
		_pool.append(m)
		_age.append(INF)

func _physics_process(delta: float) -> void:
	if player == null:
		player = Game.player
		if player == null:
			return

	var flat_speed := Vector2(player.velocity.x, player.velocity.z).length()
	if player.is_on_floor() and flat_speed > 0.5 and player.global_position.distance_to(_last) > STRIDE and Game.is_outside():
		_place()
		_last = player.global_position

	var life := lerpf(220.0, 75.0, Storm.intensity)
	for i in POOL:
		if _age[i] >= life:
			continue
		_age[i] += delta
		var a := 1.0 - _age[i] / life
		(_pool[i].material_override as StandardMaterial3D).albedo_color.a = a * 0.6
		if a <= 0.0:
			_pool[i].visible = false
			_age[i] = INF

func _place() -> void:
	var from := player.global_position + Vector3.UP * 0.8
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.5, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return

	var m := _pool[_idx]
	var pool_pos := _idx
	_idx = (_idx + 1) % POOL
	_left = not _left

	m.global_position = hit.position + hit.normal * 0.015 + player.global_basis.x * (0.16 if _left else -0.16)
	m.global_rotation = Vector3(0, player.global_rotation.y, 0)
	m.visible = true
	_age[pool_pos] = 0.0
