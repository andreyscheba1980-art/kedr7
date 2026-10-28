class_name Synoptic
extends RefCounted
## Процедурная синоптическая и геофизическая модель смены станции «Кедр-7»:
## Рассчитывает взаимосвязанные физические параметры атмосферы и мерзлоты (давление, градиент,
## температуру, влажность, вектор ветра, сейсмику и спутниковые координаты фронта).
## Все приборы (барограф М-22, психрометр, флюгер, СВ-20, ИСЗ «Метеор-2») считывают живые значения отсюда.

var pressure: float = 746.0            ## мм рт. ст. (715.0 .. 772.0)
var pressure_rate: float = -0.4        ## мм/ч (-3.2 .. +1.5)
var temp_dry: float = -28.0            ## °C (-16.0 .. -54.0)
var temp_wet: float = -30.0            ## °C
var humidity: int = 86                 ## % (65 .. 100)
var wind_speed: float = 8.5            ## м/с у земли (0.5 .. 28.0)
var wind_gusts: float = 13.0           ## м/с порывы
var wind_azimuth_deg: float = 350.0    ## азимут флюгера (0..360)
var wind_dir_name: String = Loc.p("С", "N")        ## С, ССЗ, СЗ, СВ, В, etc.
var wind_aloft_speed: float = 22.0     ## м/с на высоте 1200 м (шар-пилот)
var snow_depth_cm: int = 94            ## см снежного покрова
var seismic_amp: float = 0.25          ## мм/с² (0.1 .. 3.5)
var seismic_freq: float = 14.0         ## Гц
var cyclone_pos: Vector2 = Vector2(0.2, 0.4)       ## координаты облачного вихря на карте ИСЗ
var cold_spot_pos: Vector2 = Vector2.ZERO          ## инфракрасная тепловая аномалия
var has_cold_spot: bool = false
var front_type: StringName = &"blizzard"           ## &"blizzard", &"storm", &"fog", &"anomaly"
var peak_hour_string: String = "02:30"             ## расчетный час пика удара фронта
var baro_history: Array[float] = []                ## 48 точек для суточной ленты барографа
var anomaly_spikes_count: int = 0


## forced — фронт, который уже «идёт» на станцию (его предвестники снимали днём): ночь обязана его исполнить.
static func generate_for_phase(kind: StringName, index: int, seed_val: int, forced: StringName = &"") -> Synoptic:
	var s := Synoptic.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val ^ (index * 9973 + (101 if kind == &"night" else 202))

	var is_night := (kind == &"night")
	var night_num := index if is_night else (index + 1)

	# 1. Определение типа доминирующего синоптического фронта:
	# С ростом ночей нарастает вероятность жестоких штормов и паранормальных депрессий
	var roll := rng.randf()
	if night_num >= 5:
		if roll < 0.45:
			s.front_type = &"anomaly"
		elif roll < 0.80:
			s.front_type = &"storm"
		else:
			s.front_type = &"blizzard"
	elif night_num >= 3:
		if roll < 0.35:
			s.front_type = &"storm"
		elif roll < 0.65:
			s.front_type = &"fog"
		elif roll < 0.85:
			s.front_type = &"blizzard"
		else:
			s.front_type = &"anomaly"
	else:
		if roll < 0.60:
			s.front_type = &"blizzard"
		elif roll < 0.85:
			s.front_type = &"fog"
		else:
			s.front_type = &"storm"

	if forced != &"":
		s.front_type = forced

	# 2. Физический расчёт термодинамики и барического поля согласно типу фронта:
	match s.front_type:
		&"storm":
			s.pressure = rng.randf_range(718.0, 734.0)
			s.pressure_rate = -rng.randf_range(1.6, 2.9)
			s.temp_dry = -rng.randf_range(34.0, 48.0)
			s.humidity = rng.randi_range(88, 96)
			s.wind_speed = rng.randf_range(17.0, 26.0)
			s.wind_gusts = s.wind_speed + rng.randf_range(5.0, 9.0)
			s.wind_azimuth_deg = rng.randf_range(330.0, 360.0) if rng.randf() < 0.7 else rng.randf_range(0.0, 30.0)
			s.wind_aloft_speed = s.wind_speed + rng.randf_range(10.0, 16.0)
			s.seismic_amp = rng.randf_range(0.6, 1.4)
			s.seismic_freq = rng.randf_range(18.0, 26.0)
			s.cyclone_pos = Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.4, 0.1))
			s.has_cold_spot = false

		&"fog":
			s.pressure = rng.randf_range(752.0, 768.0)
			s.pressure_rate = rng.randf_range(-0.3, 0.4)
			s.temp_dry = -rng.randf_range(16.0, 26.0)
			s.humidity = rng.randi_range(98, 100)
			s.wind_speed = rng.randf_range(0.4, 2.8)
			s.wind_gusts = s.wind_speed + rng.randf_range(1.0, 2.0)
			s.wind_azimuth_deg = rng.randf_range(0.0, 360.0)
			s.wind_aloft_speed = rng.randf_range(6.0, 12.0)
			s.seismic_amp = rng.randf_range(0.1, 0.3)
			s.seismic_freq = 10.0
			s.cyclone_pos = Vector2(rng.randf_range(0.4, 0.8), rng.randf_range(0.3, 0.7))
			s.has_cold_spot = false

		&"anomaly":
			s.pressure = rng.randf_range(724.0, 755.0)
			s.pressure_rate = -rng.randf_range(0.8, 1.8)
			s.temp_dry = -rng.randf_range(38.0, 56.0)
			s.humidity = rng.randi_range(80, 92)
			s.wind_speed = rng.randf_range(6.0, 15.0)
			s.wind_gusts = s.wind_speed + rng.randf_range(4.0, 7.0)
			s.wind_azimuth_deg = rng.randf_range(310.0, 350.0)
			s.wind_aloft_speed = rng.randf_range(24.0, 34.0)
			s.seismic_amp = rng.randf_range(1.4, 3.2)
			s.seismic_freq = rng.randf_range(6.0, 14.0)  # инфразвуковой гул
			s.cyclone_pos = Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2))
			s.has_cold_spot = true
			s.cold_spot_pos = Vector2(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.2, 0.1))
			s.anomaly_spikes_count = rng.randi_range(3, 7)

		_:  # &"blizzard" (штатная метель)
			s.pressure = rng.randf_range(740.0, 750.0)
			s.pressure_rate = -rng.randf_range(0.3, 0.7)
			s.temp_dry = -rng.randf_range(24.0, 33.0)
			s.humidity = rng.randi_range(84, 91)
			s.wind_speed = rng.randf_range(7.0, 13.0)
			s.wind_gusts = s.wind_speed + rng.randf_range(3.0, 6.0)
			s.wind_azimuth_deg = rng.randf_range(340.0, 360.0) if rng.randf() < 0.5 else rng.randf_range(0.0, 20.0)
			s.wind_aloft_speed = s.wind_speed + rng.randf_range(8.0, 12.0)
			s.seismic_amp = rng.randf_range(0.2, 0.45)
			s.seismic_freq = 12.0
			s.cyclone_pos = Vector2(rng.randf_range(0.2, 0.6), rng.randf_range(-0.3, 0.3))
			s.has_cold_spot = false

	# 3. Расчёт психрометрической разности (Твл):
	var depression: float = (100.0 - float(s.humidity)) * 0.14
	s.temp_wet = s.temp_dry - maxf(depression, 0.5)

	# 4. Название румба ветра:
	s.wind_dir_name = _azimuth_to_compass(s.wind_azimuth_deg)

	# 5. Глубина снежного покрова:
	s.snow_depth_cm = rng.randi_range(88, 118) + (night_num * 3)

	# 6. Расчётный пик удара фронта:
	var peak_h := rng.randi_range(1, 4)
	var peak_m := rng.randi_range(10, 50)
	s.peak_hour_string = "%02d:%02d" % [peak_h, peak_m]

	# 7. Генерация 48 точек суточной барограммы для барабана барографа:
	s._generate_barograph_curve(rng, night_num)

	return s


static func _azimuth_to_compass(deg: float) -> String:
	var d := fposmod(deg, 360.0)
	if d >= 337.5 or d < 22.5: return Loc.p("С", "N")
	if d >= 22.5 and d < 67.5: return Loc.p("СВ", "NE")
	if d >= 67.5 and d < 112.5: return Loc.p("В", "E")
	if d >= 112.5 and d < 157.5: return Loc.p("ЮВ", "SE")
	if d >= 157.5 and d < 202.5: return Loc.p("Ю", "S")
	if d >= 202.5 and d < 247.5: return Loc.p("ЮЗ", "SW")
	if d >= 247.5 and d < 292.5: return Loc.p("З", "W")
	return Loc.p("СЗ", "NW")


func _generate_barograph_curve(rng: RandomNumberGenerator, night_num: int) -> void:
	baro_history.clear()
	var points_count := 48
	var current_p := pressure + (-pressure_rate * 4.0)

	for i in range(points_count):
		var progress := float(i) / float(points_count - 1)
		# Базовый тренд с шумом
		var val := current_p + (pressure - current_p) * progress + rng.randf_range(-0.4, 0.4)
		
		# Если аномалия или шторм — резкие зубцы перепада
		if front_type == &"anomaly" and progress > 0.4 and progress < 0.85:
			if rng.randf() < 0.25:
				val += rng.randf_range(-3.5, 4.2)
		elif front_type == &"storm" and progress > 0.5:
			val += sin(progress * 30.0) * rng.randf_range(0.4, 1.2)

		baro_history.append(clampf(val, 705.0, 785.0))


func get_baro_summary() -> String:
	var trend_desc := ""
	if pressure_rate < -1.5:
		trend_desc = Loc.p("крутое падение (штормовой градиент %+.1f мм/ч)", "steep fall (storm gradient %+.1f mm/h)") % pressure_rate
	elif pressure_rate < -0.3:
		trend_desc = Loc.p("умеренный спад (%+.1f мм/ч)", "moderate fall (%+.1f mm/h)") % pressure_rate
	elif pressure_rate > 0.5:
		trend_desc = Loc.p("рост давления (%+.1f мм/ч)", "rising pressure (%+.1f mm/h)") % pressure_rate
	else:
		trend_desc = Loc.p("стабильное (колебания в пределах нормы)", "steady (fluctuations within normal)")
	return Loc.p("%.1f мм рт. ст. — %s", "%.1f mmHg — %s") % [pressure, trend_desc]


func get_psychro_summary() -> String:
	return Loc.p("Тсух = %.1f°C, Твл = %.1f°C, влажность %d%%", "Dry = %.1f°C, Wet = %.1f°C, humidity %d%%") % [temp_dry, temp_wet, humidity]


func get_wind_summary() -> String:
	return Loc.p("%s %.1f м/с (порывы до %.1f м/с)", "%s %.1f m/s (gusts to %.1f m/s)") % [wind_dir_name, wind_speed, wind_gusts]


func get_sv20_summary() -> String:
	var status := Loc.p("спокойно", "quiet")
	if seismic_amp > 1.2:
		status = Loc.p("АНОМАЛЬНЫЙ ГУЛ И ДРОЖЬ ПЛАСТОВ", "ANOMALOUS RUMBLE AND STRATA TREMOR")
	elif seismic_amp > 0.6:
		status = Loc.p("повышенная вибрация мерзлоты", "elevated permafrost vibration")
	return Loc.p("%.2f мм/с² (частота %.1f Гц) — %s", "%.2f mm/s² (frequency %.1f Hz) — %s") % [seismic_amp, seismic_freq, status]


func get_satellite_summary() -> String:
	var dist_km := int(cyclone_pos.length() * 240.0)
	var dir_str := Loc.p("северо-запада", "the northwest") if cyclone_pos.x < 0 else Loc.p("северо-востока", "the northeast")
	if has_cold_spot:
		return Loc.p("Фронт циклона в %d км с %s. ВНИМАНИЕ: зафиксировано термальное пятно -%d°C!", "Cyclone front %d km from %s. WARNING: thermal spot of -%d°C detected!") % [dist_km, dir_str, int(abs(temp_dry) + 12)]
	return Loc.p("Циклонический вихрь в %d км с %s.", "Cyclonic vortex %d km from %s.") % [dist_km, dir_str]
