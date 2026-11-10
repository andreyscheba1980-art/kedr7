class_name MenuBackdrop
extends Node3D
## Живой фон главного меню — постановочный кадр: дом с тёплыми окнами и дымом из трубы в ясную морозную ночь,
## над лесом на севере северное сияние, лёгкий снег. Камера медленно наезжает на дом и так же медленно отъезжает.

const CENTER := Vector3(6.0, 1.5, 2.5)
const RADIUS := 26.0
# Камера стоит на тропе к дровам (там лес вырублен): дом с юго-востока, окна и фонарь крыльца к нам,
# сияние — на севере, за крышей.
const CAM_FAR := Vector3(21.5, 1.70, 7.5)
const CAM_NEAR := Vector3(19.8, 1.60, 5.8)
const LOOK_FAR := Vector3(14.0, 1.75, 3.2)   # крыльцо, мостки и дом — в правой части кадра, слева меню
const LOOK_NEAR := Vector3(13.5, 1.68, 3.0)
const DOLLY_S := 60.0

var _cam: Camera3D
var _snow: CPUParticles3D
var _t := 0.0


func _ready() -> void:
	var st := Station.new()
	st.is_backdrop = true
	add_child(st)
	_cam = Camera3D.new()
	_cam.fov = 58.0
	_cam.far = 180.0
	add_child(_cam)
	
	# Тёплый свет окон и крыльца на снегу в кадре меню
	var warm_fill := OmniLight3D.new()
	warm_fill.position = Vector3(15.2, 2.4, 3.8)
	warm_fill.omni_range = 14.0
	warm_fill.light_energy = 1.6
	warm_fill.light_color = Color(1.0, 0.82, 0.58)
	warm_fill.shadow_enabled = false
	add_child(warm_fill)

	_snow = Player.make_snow()
	_snow.amount = 200
	_snow.speed_scale = 0.65
	_snow.direction = Vector3(0.5, -1.0, 0.1)
	_cam.add_child(_snow)
	((_snow.mesh as QuadMesh).material as StandardMaterial3D).emission = Color(0.20, 0.22, 0.28)
	if Game.weather != null:
		Game.weather.intensity = 0.06
	if Game.level != null and Game.level.env != null:
		Game.level.env.fog_density = 0.022
		var sky: ShaderMaterial = null
		if Game.level.env.sky != null:
			sky = Game.level.env.sky.sky_material as ShaderMaterial
		if sky != null:
			sky.set_shader_parameter(&"aurora", 1.2)
			sky.set_shader_parameter(&"aurora_tint", Color(0.18, 0.95, 0.55))
			sky.set_shader_parameter(&"aurora_top", Color(0.48, 0.25, 0.70))
			sky.set_shader_parameter(&"cloud_amount", 0.06)
	_update_cam()


func _process(delta: float) -> void:
	_t += delta
	_update_cam()


func _update_cam() -> void:
	if _cam == null:
		return
	# Наезд и отъезд по плавной кривой (туда-обратно), с еле заметным покачиванием «с рук»
	var ph := fmod(_t / DOLLY_S, 2.0)
	var k := ph if ph <= 1.0 else 2.0 - ph
	k = k * k * (3.0 - 2.0 * k)
	var sway := Vector3(sin(_t * 0.31) * 0.08, sin(_t * 0.23) * 0.05, 0.0)
	_cam.position = CAM_FAR.lerp(CAM_NEAR, k) + sway
	_cam.look_at(LOOK_FAR.lerp(LOOK_NEAR, k), Vector3.UP)
