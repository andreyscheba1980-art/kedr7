class_name MenuBackdrop
extends Node3D
## Живой фон главного меню — постановочный кадр: дом с тёплыми окнами и дымом из трубы в ясную морозную ночь,
## над лесом на севере северное сияние, лёгкий снег. Камера медленно наезжает на дом и так же медленно отъезжает.

const CENTER := Vector3(6.0, 1.5, 2.5)
const RADIUS := 26.0
# Камера стоит на тропе к дровам (там лес вырублен): дом с юго-востока, окна и фонарь крыльца к нам,
# сияние — на севере, за крышей.
const CAM_FAR := Vector3(22.8, 1.28, 7.6)
const CAM_NEAR := Vector3(21.2, 1.24, 6.2)
const LOOK_FAR := Vector3(13.4, 1.38, 2.6)   # крыльцо, мостки и дом — в правой части кадра, слева тень под меню
const LOOK_NEAR := Vector3(13.0, 1.34, 2.4)
const DOLLY_S := 55.0

var _cam: Camera3D
var _snow: CPUParticles3D
var _warm_fill: OmniLight3D
var _mast_beacon: OmniLight3D
var _t := 0.0


func _ready() -> void:
	var st := Station.new()
	st.is_backdrop = true
	add_child(st)
	_cam = Camera3D.new()
	_cam.fov = 40.0 # Кинематографичный длинный фокус без бочкообразных искажений
	_cam.far = 240.0
	add_child(_cam)
	
	# Тёплый свет окон и крыльца на снегу в кадре меню (с имитацией просадок напряжения дизеля)
	_warm_fill = OmniLight3D.new()
	_warm_fill.position = Vector3(15.2, 2.3, 3.6)
	_warm_fill.omni_range = 14.0
	_warm_fill.light_energy = 1.8
	_warm_fill.light_color = Color(1.0, 0.82, 0.58)
	_warm_fill.shadow_enabled = false
	add_child(_warm_fill)

	# Красный сигнальный огонь ЗОМ-1 на вершине метеомачты
	_mast_beacon = OmniLight3D.new()
	_mast_beacon.position = Vector3(24.0, 16.8, -62.0)
	_mast_beacon.omni_range = 35.0
	_mast_beacon.light_energy = 2.0
	_mast_beacon.light_color = Color(1.0, 0.12, 0.06)
	_mast_beacon.shadow_enabled = false
	add_child(_mast_beacon)

	_snow = Player.make_snow()
	_snow.amount = 220
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
	_update_lights()


func _update_lights() -> void:
	# Медленная тревожная пульсация красного огня ЗОМ-1 на мачте
	if _mast_beacon != null:
		var pulse := (sin(_t * 2.1) * 0.5 + 0.5)
		_mast_beacon.light_energy = lerpf(0.2, 3.2, pow(pulse, 2.5))
	
	# Микро-просадки напряжения от дизель-генератора ДГА-24 на фонаре крыльца
	if _warm_fill != null:
		var flicker := sin(_t * 14.3) * 0.06 + sin(_t * 2.7) * 0.04
		_warm_fill.light_energy = 1.8 + flicker


func _update_cam() -> void:
	if _cam == null:
		return
	# Наезд и отъезд по плавной кривой с дыханием ветра на камеру
	var ph := fmod(_t / DOLLY_S, 2.0)
	var k := ph if ph <= 1.0 else 2.0 - ph
	k = k * k * (3.0 - 2.0 * k)
	var wind_sway := Vector3(sin(_t * 0.41) * 0.06, sin(_t * 0.31) * 0.04, cos(_t * 0.29) * 0.03)
	_cam.position = CAM_FAR.lerp(CAM_NEAR, k) + wind_sway
	_cam.look_at(LOOK_FAR.lerp(LOOK_NEAR, k), Vector3.UP)
