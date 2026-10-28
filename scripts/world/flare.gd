class_name Flare
extends Node3D
## Сигнальная ракета: летит дугой, горит красным ~10 секунд. Ырка огня боится — отступает.

const BURN_TIME := 10.0
const GRAVITY := 4.5

var velocity := Vector3.ZERO
var _t := 0.0
var _light: OmniLight3D
var _core: MeshInstance3D
var _sparks: CPUParticles3D


func _ready() -> void:
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.18, 0.08)
	_light.light_energy = 3.0
	_light.omni_range = 26.0
	_light.omni_attenuation = 1.3
	add_child(_light)
	_core = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.08
	sm.height = 0.16
	sm.radial_segments = 6
	sm.rings = 3
	_core.mesh = sm
	_core.material_override = Palette.glow(&"red", true)
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core)
	_sparks = CPUParticles3D.new()
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sparks.amount = 40
	_sparks.lifetime = 0.9
	_sparks.direction = Vector3(0, -1, 0)
	_sparks.spread = 30.0
	_sparks.initial_velocity_min = 0.5
	_sparks.initial_velocity_max = 1.5
	_sparks.gravity = Vector3(0, -2.0, 0)
	_sparks.scale_amount_min = 0.03
	_sparks.scale_amount_max = 0.06
	var pm := QuadMesh.new()
	pm.size = Vector2(1, 1)
	pm.material = Palette.glow(&"amber", true)
	_sparks.mesh = pm
	add_child(_sparks)


func _process(delta: float) -> void:
	_t += delta
	# Взлёт, потом медленное падение на «парашютике».
	velocity.y -= GRAVITY * delta
	if velocity.y < -1.2:
		velocity.y = -1.2
	velocity.x *= 1.0 - delta * 0.6
	velocity.z *= 1.0 - delta * 0.6
	position += velocity * delta
	if position.y < 0.15:
		position.y = 0.15
		velocity = Vector3.ZERO
	var fade := clampf((BURN_TIME - _t) / 2.0, 0.0, 1.0)
	_light.light_energy = (2.6 + randf() * 0.8) * fade
	if _t > BURN_TIME:
		queue_free()
