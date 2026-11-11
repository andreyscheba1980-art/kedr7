class_name Zenit
extends Node
## Фотоаппарат «Зенит-Е» Семёнова — в кладовой, на ящике. [Z]: держать — видоискатель, отпустить — кадр.
## На ночь — плёнка на 12 кадров и 4 лампы-вспышки. Проявка утром, под красным фонарём.
##   • в кадре аномалия — снимок идёт в журнал доказательством (пропущенной она уже не считается);
##   • голос из леса: снял источник — голос обрывается, а на снимке у кромки стоит тот, кто звал;
##   • «только на плёнке»: иногда на отпечатке есть то, чего в кадре не было;
##   • вспышка в темноте: на улице её видно издалека — Ырка идёт на свет; у двери гость-подражатель
##     от неё отшатывается. Без вспышки снимок тёмный, но плёнка всё равно видит больше глаза.
## Звук на плёнку не снимешь — для этого есть магнитофон.

const FRAMES := 12
const BULBS := 4
const SHUTTER := "res://assets/audio/clank.ogg"
const PRINT_SIZE := Vector2i(384, 216)
const DayPOIsClass = preload("res://scripts/world/day_pois.gd")

var frames_left := FRAMES
var bulbs_left := BULBS
var photos: Array[Dictionary] = []          ## {"img": Image, "min": int, "tags": Array, "ghost": bool, "voice": bool, "flash": bool}
var partner_photos: Array[Dictionary] = []
var raised := false
static var force_ghost := false   ## автотест: «только на плёнке» в каждом кадре

var _view: Control
var _shade: ColorRect
var _busy := false
var _ghost: Node3D
var _told_flash := false
var _wind_t := 0.0
var _shoot_down := false
var _last_luma := 0.0


func _ready() -> void:
	Game.zenit = self


func _exit_tree() -> void:
	if Game.zenit == self:
		Game.zenit = null
	_lower()


func available() -> bool:
	return Game.has_item(&"zenit") and Game.player != null and not Game.dead and not Game.dying and not Game.shift_over


func _process(delta: float) -> void:
	_wind_t = maxf(_wind_t - delta, 0.0)
	if not available():
		if raised:
			_lower()
		return
	var p := Game.player
	var free := p.mode == Player.Mode.WALK and Game.hud != null and Game.hud.modal() == null
	var want := Input.is_action_pressed(&"photo") and free
	if want and not raised:
		_raise()
	elif raised and not want:
		_lower()   # опустил аппарат — кадр не тратится
	# Затвор — по фронту нажатия (RT — ось: «just_pressed» на ней ненадёжен).
	var shoot := Input.is_action_pressed(&"photo_shoot")
	if raised and shoot and not _shoot_down and not _busy and _wind_t <= 0.0:
		_wind_t = 0.7   # взвод затвора: следующий кадр — не раньше
		snap()
	_shoot_down = shoot
	if raised and _view != null:
		_view.queue_redraw()


func _raise() -> void:
	raised = true
	Game.player.zoom_fov = Settings.fov * 0.7
	Game.audio.play_2d(SHUTTER, -22.0)
	if _view == null and Game.hud != null:
		_view = Control.new()
		_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_view.draw.connect(_draw_view)
		Game.hud.add_child(_view)


func _lower() -> void:
	raised = false
	if Game.player != null and is_instance_valid(Game.player):
		Game.player.zoom_fov = 0.0
	if _view != null and is_instance_valid(_view):
		_view.queue_free()
	_view = null


func _draw_view() -> void:
	var s := _view.size
	var dark := Color(0, 0, 0, 0.82)
	var fw := s.y * 1.42
	var fx := (s.x - fw) * 0.5
	_view.draw_rect(Rect2(0, 0, fx, s.y), dark)
	_view.draw_rect(Rect2(s.x - fx, 0, fx, s.y), dark)
	var inner := Rect2(fx + 18, 18, fw - 36, s.y - 36)
	_view.draw_rect(inner, Color(1, 1, 1, 0.35), false, 1.5)
	var c := s * 0.5
	_view.draw_arc(c, s.y * 0.09, 0, TAU, 40, Color(1, 1, 1, 0.45), 1.5)
	_view.draw_arc(c, s.y * 0.035, 0, TAU, 24, Color(1, 1, 1, 0.3), 1.0)
	_view.draw_line(c - Vector2(s.y * 0.035, 0), c + Vector2(s.y * 0.035, 0), Color(1, 1, 1, 0.3), 1.0)
	var font := ThemeDB.fallback_font
	var txt := Loc.t(&"zenit.counter", [FRAMES - frames_left + 1 if frames_left > 0 else FRAMES, FRAMES, bulbs_left])
	if frames_left <= 0:
		txt = Loc.t(&"zenit.no_film")
	_view.draw_string(font, Vector2(inner.position.x + 8, inner.end.y - 12), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.85, 0.55, 0.9))
	var shoot := Loc.t(&"zenit.shoot_pad", [Game.pad_name(&"photo_shoot"), Game.pad_name(&"photo")]) if Game.is_gamepad else Loc.t(&"zenit.shoot_kb")
	_view.draw_string(font, Vector2(inner.position.x + 8, inner.position.y + 26), shoot, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.85, 0.55, 0.7))
	if _needs_flash():
		_view.draw_string(font, Vector2(inner.end.x - 160, inner.end.y - 12), Loc.t(&"zenit.flash_on") if bulbs_left > 0 else Loc.t(&"zenit.flash_out"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.85, 0.55, 0.9))


func _needs_flash() -> bool:
	return Game.is_dark() or (Game.is_night() and Game.is_outside())


# --- Кадр ---------------------------------------------------------------------

func snap() -> void:
	if frames_left <= 0:
		var spare := int(SaveGame.flags.get("spare_film", 0))
		if spare > 0:
			SaveGame.flags["spare_film"] = spare - 1
			frames_left = FRAMES
			Game.hud.subtitle(Loc.t(&"zenit.reload"), 2.5)
			Game.audio.play_2d("res://assets/audio/clank.ogg", -14.0)
		else:
			Game.hud.subtitle(Loc.t(&"zenit.no_film"), 2.0)
		return
	_busy = true
	frames_left -= 1
	var p := Game.player
	var cam := p.camera
	var flash := _needs_flash() and bulbs_left > 0
	if flash:
		bulbs_left -= 1

	# Что в кадре: аномалии (доказательства) и голос из леса.
	var tags: Array[StringName] = []
	var an := Game.anomalies
	if an != null:
		for id: StringName in an.active:
			if not an.is_active(id):
				continue
			if _sees(cam, an.pos_of(id), _range_for(id)):
				tags.append(id)
				an.photographed(id)
	var poi_id: StringName = DayPOIsClass.check_poi_in_frame(cam)
	if poi_id != &"":
		tags.append(poi_id)
		SaveGame.flags["poi_photo_" + String(poi_id)] = true
	var fv := Game.forest_voice
	var voice := fv != null and fv.in_frame(cam)

	# «Только на плёнке»: в кадре — то, чего нет. Ставим на один кадр, пока затвор закрыт.
	var ghost_pos := Vector3.INF
	if voice:
		# Тот, кто звал, — ближе, чем звучал: на плёнке он в пяти шагах, в конусе вспышки.
		var to := fv.source - cam.global_position
		to.y = 0.0
		ghost_pos = cam.global_position + to.normalized() * minf(to.length(), 5.0)
		ghost_pos.y = Game.player.global_position.y - 0.05
	elif force_ghost or (Game.is_night() and Game.night >= 3 and Game.rng.randf() < (0.12 if Game.night < 5 else 0.22)):
		ghost_pos = _ghost_spot(cam)
	if ghost_pos != Vector3.INF:
		_place_ghost(ghost_pos, voice)
		if OS.is_debug_build():
			print("[zenit] призрак %s в %s, на кадре %s, позади=%s" % ["Ырка" if voice else "тень", ghost_pos, cam.unproject_position(ghost_pos + Vector3(0, 1, 0)), cam.is_position_behind(ghost_pos)])

	# Лампа-вспышка светит вперёд конусом и быстро гаснет с расстоянием: ближнее — светлое, дальнее — в темноте.
	# (Раньше всенаправленный свет заливал снег под ногами — на улице кадр уходил в белое.)
	var light: SpotLight3D = null
	if flash:
		light = SpotLight3D.new()
		light.light_color = Color(0.92, 0.95, 1.0)
		light.light_energy = 4.5 if Game.is_outside() else 2.6
		light.spot_range = 24.0
		light.spot_angle = 40.0
		light.spot_attenuation = 1.0
		light.spot_angle_attenuation = 1.4
		light.shadow_enabled = false
		cam.add_child(light)
		light.position = Vector3(0.06, 0.08, -0.15)
	# Затвор: экран на миг чёрный — игрок не видит того, что попадёт на плёнку.
	_shutter(true)
	Game.audio.play_2d(SHUTTER, -6.0)
	var img: Image = null
	if DisplayServer.get_name() != "headless":   # без отрисовки кадра не будет (сервер, тесты)
		# Новому существу нужен кадр, чтобы его шейдер собрался и оно попало в отрисовку.
		for _i in (3 if ghost_pos != Vector3.INF else 1):
			await RenderingServer.frame_post_draw
		var tex := p.get_viewport().get_texture()
		if tex != null:
			img = tex.get_image()
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.visible = false
	_shutter(false)
	if light != null:
		await get_tree().create_timer(0.12, false).timeout
		light.queue_free()
	if img != null and not img.is_empty():
		img.resize(PRINT_SIZE.x, PRINT_SIZE.y, Image.INTERPOLATE_BILINEAR)
		var avg := _mean_luma(img)
		_last_luma = avg
		if flash and avg > 0.4:
			img.adjust_bcs(clampf(0.4 / avg, 0.5, 1.0), 1.0, 1.0)   # «автомат» вспышки: снег не выбивает в белое
		elif not flash and _needs_flash():
			img.adjust_bcs(0.65, 1.0, 0.9)   # без вспышки — недодержка
	else:
		img = _synthesize_atmospheric_frame(cam, flash, tags, ghost_pos != Vector3.INF, voice)

	_develop_film_frame(img, flash)
	var shot := {"img": img, "min": int(Game.shift_minutes), "tags": tags, "ghost": ghost_pos != Vector3.INF, "voice": voice, "flash": flash}
	_inject_horror_anomalies(img, shot, cam, flash, ghost_pos != Vector3.INF, voice)
	photos.append(shot)
	Net.share_photo(shot)

	# Последствия.
	if voice:
		fv.banish()
	if flash:
		_on_flash()
	if OS.is_debug_build() or Net.test_mode:
		print("[zenit] кадр %d: метки %s, призрак=%s, голос=%s, вспышка=%s, картинка=%s, яркость %.2f" % [FRAMES - frames_left, tags, shot["ghost"], voice, flash, img != null, _last_luma])
	_busy = false


static func _mean_luma(img: Image) -> float:
	var s := 0.0
	var n := 0
	for y in range(4, img.get_height(), 12):
		for x in range(4, img.get_width(), 12):
			var c := img.get_pixel(x, y)
			s += c.r * 0.3 + c.g * 0.59 + c.b * 0.11
			n += 1
	return s / maxf(n, 1)


## Советская обработка плёнки «Свема ФОТО-64» и бумаги «Унибром»:
## виньетирование «Гелиос-44-2», серебряное зерно и тональная кривая.
static func _develop_film_frame(img: Image, flash: bool) -> void:
	if img == null or img.is_empty():
		return
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var is_night := Game.is_night()
	var is_outside := Game.is_outside()

	for y in range(h):
		var ny := float(y) / float(h)
		var dy := ny - 0.5
		for x in range(w):
			var nx := float(x) / float(w)
			var dx := (nx - 0.5) * 1.4

			var col := img.get_pixel(x, y)
			var luma := col.r * 0.299 + col.g * 0.587 + col.b * 0.114

			# Виньетирование объектива «Гелиос-44-2»
			var r2 := dx * dx + dy * dy
			var vig := clampf(1.0 - r2 * 0.40, 0.25, 1.0)
			luma *= vig

			# Радиальное затухание вспышки
			if flash:
				var flash_fall := clampf(1.15 - r2 * 0.70, 0.22, 1.25)
				luma *= flash_fall
			elif is_night and is_outside:
				luma *= 0.75

			# Серебряное микрозерно галогенидов серебра
			var seed_val := float(x * 131 + y * 397)
			var grain := (fmod(sin(seed_val) * 43758.5453, 1.0) - 0.5) * 0.075
			luma = clampf(luma + grain, 0.0, 1.0)

			# Контраст фотобумаги «Унибром»
			luma = pow(luma, 1.12)

			# Тёплый серебряно-желатиновый оттенок
			img.set_pixel(x, y, Color(luma * 1.0, luma * 0.94, luma * 0.88, 1.0))


func _inject_horror_anomalies(img: Image, shot: Dictionary, cam: Camera3D, flash: bool, ghost: bool, voice: bool) -> void:
	var is_outside := Game.is_outside()
	var is_night := Game.is_night()
	var night_num := Game.night
	var rng := Game.rng
	var pitch_down := cam != null and cam.global_transform.basis.z.y > 0.15

	# Приоритет 1: Голос из леса (100% суставчатый силуэт Ырки в соснах)
	if voice:
		var sx := int(PRINT_SIZE.x * (0.78 if rng.randf() > 0.5 else 0.22))
		var sy := int(PRINT_SIZE.y * 0.72)
		_draw_jointed_silhouette(img, sx, sy, 72)
		shot["has_shadow"] = true
		shot["ghost"] = true
		shot["detail"] = Loc.p("Осмотр под 8x лупой: На снимке в направлении голоса — неестественно высокий (более 2.5 м) суставчатый силуэт, полускрытый сосной. Руки с двумя локтевыми суставами сжимают кору. Лицо абсолютно черно, но на уровне глаз светятся две белые точки.", "Under 8x loupe: In the direction of the voice — an unnaturally tall (over 2.5m) jointed silhouette half-concealed by a pine. Double-elbowed arms grip the bark. The face is pitch black, but two white dots gleam at eye level.")
		return

	# Приоритет 2: Призрак на кадре (force_ghost или рандом ночи)
	if ghost:
		if rng.randf() < 0.55:
			var ex := int(PRINT_SIZE.x * (0.32 if rng.randf() > 0.5 else 0.68))
			var ey := int(PRINT_SIZE.y * 0.44)
			_draw_tapetum_eyes(img, ex, ey)
			shot["has_eyes"] = true
			shot["detail"] = Loc.p("Осмотр под 8x лупой: В глубине темноты светятся два точечных зрачка с зеленоватым ореолом светоотражающего тапетума (Tapetum lucidum). Существо смотрело в упор на объектив в момент вспышки с расстояния 12 метров.", "Under 8x loupe: In the darkness, two pinpoint pupils gleam with the greenish reflection of a tapetum lucidum. The creature was staring dead into the lens at the moment of flash from 12 meters.")
		else:
			var sx := int(PRINT_SIZE.x * (0.24 if rng.randf() > 0.5 else 0.76))
			var sy := int(PRINT_SIZE.y * 0.70)
			_draw_jointed_silhouette(img, sx, sy, 68)
			shot["has_shadow"] = true
			shot["detail"] = Loc.p("Осмотр под 8x лупой: На границе света вспышки — тонкий суставчатый силуэт в неестественной позе между деревьями. Плечи опущены, голова неестественно наклонена набок.", "Under 8x loupe: At the flash boundary — a thin jointed silhouette in an unnatural posture between trees. Shoulders slumped, head tilted unnaturally sideways.")
		return

	# Приоритет 3: Если ночь >= 1, шанс атмосферных аномалий
	if is_night:
		if is_outside:
			if pitch_down and flash and rng.randf() < (0.45 if night_num >= 2 else 0.25):
				_draw_barefoot_tracks(img)
				shot["has_tracks"] = true
				shot["ghost"] = true
				shot["detail"] = Loc.p("Осмотр под 8x лупой: На снегу в конусе вспышки видна чёткая цепочка свежих отпечатков босых человеческих ног на насте при -43°C. Следы выходят из темноты и обрываются ровно перед объективом.", "Under 8x loupe: In the flash cone on the snow, a distinct chain of fresh barefoot human prints at -43°C. The prints emerge from the dark and stop right in front of the lens.")
				return
			elif flash and rng.randf() < (0.40 if night_num >= 2 else 0.20):
				var ex := int(PRINT_SIZE.x * (0.26 if rng.randf() > 0.5 else 0.74))
				var ey := int(PRINT_SIZE.y * (0.42 + rng.randf_range(-0.06, 0.06)))
				_draw_tapetum_eyes(img, ex, ey)
				shot["has_eyes"] = true
				shot["ghost"] = true
				shot["detail"] = Loc.p("Осмотр под 8x лупой: Между соснами на границе кадра: два ярких светоотражающих огонька зрачков хищника, следившего за дежурным из чащи.", "Under 8x loupe: Between the pines at the frame edge: two bright reflective eye spots of a predator watching the duty officer from the thicket.")
				return
			elif night_num >= 3 and rng.randf() < 0.35:
				var sx := int(PRINT_SIZE.x * (0.18 if rng.randf() > 0.5 else 0.82))
				var sy := int(PRINT_SIZE.y * 0.68)
				_draw_jointed_silhouette(img, sx, sy, 64)
				shot["has_shadow"] = true
				shot["ghost"] = true
				shot["detail"] = Loc.p("Осмотр под 8x лупой: За сугробом виден затаившийся тонкий силуэт с многоколенными ногами, готовый к прыжку.", "Under 8x loupe: Behind the snowbank, a lurking thin silhouette with multi-jointed legs is crouched, ready to leap.")
				return
		else:
			# Внутри станции
			if night_num >= 2 and rng.randf() < 0.35:
				_draw_screaming_face_anomaly(img)
				shot["has_face"] = true
				shot["ghost"] = true
				shot["detail"] = Loc.p("Осмотр под 8x лупой: Сквозь зерно проступает полупрозрачный дефект двойной экспозиции: искажённое криком лицо Семёнова с провалившимися глазницами. Плёнка помнит то, что происходило в этой комнате.", "Under 8x loupe: Bleeding through the grain is a semi-transparent double exposure: Semyonov's screaming face with hollow sockets. The film remembers what happened in this room.")
				return
			elif rng.randf() < 0.30:
				_draw_frostbitten_fingers(img)
				shot["has_fingers"] = true
				shot["ghost"] = true
				shot["detail"] = Loc.p("Осмотр под 8x лупой: Из-за края косяка выступают четыре обмороженных, бледных до синевы пальца с черными ногтями, судорожно сжимающие дерево.", "Under 8x loupe: From around the doorframe edge, four frostbitten cyanotic fingers with blackened nails desperately grip the wood.")
				return


static func _draw_tapetum_eyes(img: Image, center_x: int, center_y: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var eye_spacing := 7
	for eye_i in 2:
		var ox := center_x + (eye_i * eye_spacing - eye_spacing / 2)
		var oy := center_y
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var px := ox + dx
				var py := oy + dy
				if px < 0 or px >= w or py < 0 or py >= h:
					continue
				var d2 := float(dx * dx + dy * dy)
				if d2 <= 1.0:
					img.set_pixel(px, py, Color(1.0, 0.98, 0.92, 1.0))
				elif d2 <= 4.5:
					var bg := img.get_pixel(px, py)
					var glow := Color(0.35, 0.95, 0.45, 1.0)
					img.set_pixel(px, py, bg.lerp(glow, 0.75))
				elif d2 <= 9.0:
					var bg := img.get_pixel(px, py)
					var glow := Color(0.12, 0.45, 0.18, 1.0)
					img.set_pixel(px, py, bg.lerp(glow, 0.4))


static func _draw_jointed_silhouette(img: Image, base_x: int, base_y: int, height_px: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var col_shadow := Color(0.015, 0.015, 0.015, 1.0)
	var col_rim := Color(0.45, 0.42, 0.40, 1.0)

	var head_y := base_y - height_px
	var head_r := maxi(int(height_px * 0.08), 3)
	for dy in range(-head_r, head_r + 1):
		for dx in range(-head_r, head_r + 1):
			if dx * dx + dy * dy <= head_r * head_r:
				var px := base_x + dx
				var py := head_y + dy
				if px >= 0 and px < w and py >= 0 and py < h:
					img.set_pixel(px, py, col_shadow)

	if base_x - 1 >= 0 and base_x + 1 < w and head_y >= 0 and head_y < h:
		img.set_pixel(base_x - 2, head_y - 1, Color(0.85, 0.95, 0.7, 1.0))
		img.set_pixel(base_x + 2, head_y - 1, Color(0.85, 0.95, 0.7, 1.0))

	for y in range(head_y + head_r, base_y):
		var t := float(y - head_y) / float(height_px)
		var curve_x := base_x + int(sin(t * PI) * 5.0)
		var body_w := maxi(int(sin(t * PI) * 6.0), 2)
		for dx in range(-body_w, body_w + 1):
			var px := curve_x + dx
			if px >= 0 and px < w and y >= 0 and y < h:
				if dx == body_w:
					img.set_pixel(px, y, col_rim)
				else:
					img.set_pixel(px, y, col_shadow)

	var elbow_y: int = head_y + int(height_px * 0.45)
	var hand_y: int = head_y + int(height_px * 0.9)
	var arm_sides: Array[int] = [-1, 1]
	for arm_side in arm_sides:
		var elbow_x: int = base_x + arm_side * int(height_px * 0.22)
		var hand_x: int = base_x + arm_side * int(height_px * 0.12)
		_draw_line(img, base_x, head_y + int(height_px * 0.2), elbow_x, elbow_y, col_shadow, 2)
		_draw_line(img, elbow_x, elbow_y, hand_x, hand_y, col_shadow, 2)
		for f in range(3):
			_draw_line(img, hand_x, hand_y, hand_x + arm_side * (4 + f * 3), hand_y + 6 + f * 2, col_shadow, 1)


static func _draw_barefoot_tracks(img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var steps: Array[Dictionary] = [
		{"x": 0.52, "y": 0.52, "scale": 0.5, "left": false},
		{"x": 0.48, "y": 0.61, "scale": 0.65, "left": true},
		{"x": 0.53, "y": 0.71, "scale": 0.82, "left": false},
		{"x": 0.46, "y": 0.82, "scale": 1.05, "left": true},
		{"x": 0.52, "y": 0.94, "scale": 1.35, "left": false}
	]
	for step in steps:
		var cx: int = int(float(step["x"]) * float(w))
		var cy: int = int(float(step["y"]) * float(h))
		var sc: float = float(step["scale"])
		var left: bool = bool(step["left"])
		var footprint_col := Color(0.04, 0.04, 0.05, 1.0)

		var hr := int(4.0 * sc)
		for dy in range(-hr, hr + 1):
			for dx in range(-hr, hr + 1):
				if dx * dx + dy * dy <= hr * hr:
					var px := cx + dx
					var py := cy + int(6.0 * sc) + dy
					if px >= 0 and px < w and py >= 0 and py < h:
						img.set_pixel(px, py, footprint_col)

		var ball_y := cy - int(4.0 * sc)
		var br := int(5.0 * sc)
		for dy in range(-br, br + 1):
			for dx in range(-br, br + 1):
				var off_side := (dx - (1 if left else -1))
				if off_side * off_side + dy * dy <= br * br:
					var px := cx + dx
					var py := ball_y + dy
					if px >= 0 and px < w and py >= 0 and py < h:
						img.set_pixel(px, py, footprint_col)

		for t_idx in range(5):
			var toe_off_x := int((float(t_idx) - 2.0) * (2.2 * sc) * (-1.0 if left else 1.0))
			var toe_off_y := int(-br - (2.0 + (1.0 if t_idx == 0 else 0.0)) * sc)
			var tr := maxi(int(1.2 * sc), 1)
			for dy in range(-tr, tr + 1):
				for dx in range(-tr, tr + 1):
					if dx * dx + dy * dy <= tr * tr:
						var px := cx + toe_off_x + dx
						var py := ball_y + toe_off_y + dy
						if px >= 0 and px < w and py >= 0 and py < h:
							img.set_pixel(px, py, footprint_col)


static func _draw_screaming_face_anomaly(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var cx := int(w * 0.48)
	var cy := int(h * 0.44)
	var face_rx := int(w * 0.08)
	var face_ry := int(h * 0.16)

	for dy in range(-face_ry, face_ry + 1):
		for dx in range(-face_rx, face_rx + 1):
			var nx := float(dx) / float(face_rx)
			var ny := float(dy) / float(face_ry)
			var d2 := nx * nx + ny * ny
			if d2 <= 1.0:
				var px := cx + dx
				var py := cy + dy
				if px >= 0 and px < w and py >= 0 and py < h:
					var cur := img.get_pixel(px, py)
					var ghost_val := (1.0 - d2) * 0.35
					var is_eye := (absf(nx - 0.35) < 0.22 or absf(nx + 0.35) < 0.22) and absf(ny + 0.15) < 0.18
					var is_mouth := absf(nx) < 0.28 and ny > 0.25 and ny < 0.75
					if is_eye or is_mouth:
						img.set_pixel(px, py, cur.lerp(Color(0.01, 0.01, 0.01, 1.0), 0.55))
					else:
						img.set_pixel(px, py, cur.lerp(Color(0.85, 0.82, 0.78, 1.0), ghost_val))


static func _draw_frostbitten_fingers(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var start_y := int(h * 0.62)
	for i in range(4):
		var fy := start_y + i * 11
		var flen := 26 + int(sin(float(i)) * 6.0)
		for x in range(flen):
			var t := float(x) / float(flen)
			var curve_y := fy + int(sin(t * PI * 0.5) * 5.0)
			for dy in range(-2, 3):
				var px := x
				var py := curve_y + dy
				if px >= 0 and px < w and py >= 0 and py < h:
					if x > flen - 4:
						img.set_pixel(px, py, Color(0.02, 0.02, 0.03, 1.0))
					else:
						var flesh := Color(0.68, 0.72, 0.78, 1.0)
						img.set_pixel(px, py, flesh)


static func _draw_line(img: Image, x0: int, y0: int, x1: int, y1: int, col: Color, thickness := 1) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		for ty in range(-thickness / 2, thickness / 2 + 1):
			for tx in range(-thickness / 2, thickness / 2 + 1):
				var px := x0 + tx
				var py := y0 + ty
				if px >= 0 and px < w and py >= 0 and py < h:
					img.set_pixel(px, py, col)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


static func _synthesize_atmospheric_frame(cam: Camera3D, flash: bool, _tags: Array, _ghost: bool, _voice: bool) -> Image:
	var img := Image.create(PRINT_SIZE.x, PRINT_SIZE.y, false, Image.FORMAT_RGBA8)
	var w := PRINT_SIZE.x
	var h := PRINT_SIZE.y
	var is_outside := Game.is_outside()
	var is_night := Game.is_night()

	for y in range(h):
		var ny := float(y) / float(h)
		for x in range(w):
			var base_col: Color
			if is_outside:
				if ny < 0.45:
					var sky := 0.08 + (0.45 - ny) * 0.12 if is_night else 0.55 - ny * 0.2
					base_col = Color(sky, sky * 0.98, sky * 0.94, 1.0)
				else:
					var snow := 0.28 + (ny - 0.45) * 0.35 if is_night else 0.78 + (ny - 0.45) * 0.15
					base_col = Color(snow, snow * 0.98, snow * 0.92, 1.0)
			else:
				if ny < 0.65:
					var log_stripe := fmod(ny * 16.0, 1.0)
					var wall := (0.18 + log_stripe * 0.12) if is_night else (0.42 + log_stripe * 0.15)
					base_col = Color(wall, wall * 0.92, wall * 0.85, 1.0)
				else:
					var floor_val := 0.14 if is_night else 0.35
					base_col = Color(floor_val, floor_val * 0.92, floor_val * 0.82, 1.0)

			img.set_pixel(x, y, base_col)
	return img


func _range_for(id: StringName) -> float:
	match Anomalies.zone_of(id):
		&"yard":
			return 45.0
		&"instr", &"radio":
			return 3.0
	return 8.0


func _sees(cam: Camera3D, pos: Vector3, max_d: float) -> bool:
	if pos == Vector3.INF:
		return false
	var to := pos - cam.global_position
	var d := to.length()
	if d > max_d or d < 0.2:
		return false
	if rad_to_deg((-cam.global_basis.z).angle_to(to / d)) > 20.0:
		return false
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, pos, Geo.LAYER_WORLD, [Game.player.get_rid()])
	var hit := Game.player.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or (hit["position"] as Vector3).distance_to(pos) < 1.2


## Точка в кадре, где «стоит» то, что видит только плёнка: в 4–10 м, у края кадра, не в стене.
func _ghost_spot(cam: Camera3D) -> Vector3:
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.01:
		return Vector3.INF
	fwd = fwd.normalized()
	var side := Game.rng.randf_range(-13.0, 13.0)
	var dir := fwd.rotated(Vector3.UP, deg_to_rad(side))
	var dist := Game.rng.randf_range(4.0, 10.0)
	var from := cam.global_position
	var to := from + dir * dist
	to.y = from.y
	var q := PhysicsRayQueryParameters3D.create(from, to, Geo.LAYER_WORLD, [Game.player.get_rid()])
	var hit := Game.player.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var hp: Vector3 = hit["position"]
		if hp.distance_to(from) < 2.5:
			return Vector3.INF
		to = hp - dir * 0.6
	return Vector3(to.x, Game.player.global_position.y - 0.05, to.z)


## «Только на плёнке» — тень с двумя точками глаз. Тот, кто звал голосом, — сама Ырка:
## на снимке видно, кто на самом деле стоял у кромки.
func _place_ghost(pos: Vector3, voice_ghost := false) -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = Creatures.make_yrka() if voice_ghost else Creatures.make_silhouette()
	_ghost.set_process(false)
	Game.level.add_child(_ghost)
	# На отпечатке оно — бледное, полупрозрачное, как двойная экспозиция: читается и на снегу, и в темноте.
	var pale := StandardMaterial3D.new()
	pale.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pale.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pale.albedo_color = Color(0.86, 0.88, 0.9, 0.62 if voice_ghost else 0.42)
	pale.cull_mode = BaseMaterial3D.CULL_DISABLED
	for mi: Node in _ghost.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = pale
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.global_position = pos
	var look := Game.player.global_position
	look.y = pos.y
	if look.distance_squared_to(pos) > 0.01:
		_ghost.look_at(look, Vector3.UP)
	_ghost.visible = true


func _shutter(on: bool) -> void:
	if on:
		if _shade == null and Game.hud != null:
			_shade = ColorRect.new()
			_shade.color = Color(0, 0, 0, 1)
			_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			Game.hud.add_child(_shade)
	elif _shade != null:
		var s := _shade
		_shade = null
		get_tree().create_timer(0.08, false).timeout.connect(func() -> void:
			if is_instance_valid(s):
				s.queue_free())


func _on_flash() -> void:
	var p := Game.player
	if Game.is_outside() and Game.is_night():
		# Вспышку видно за километр — и не только людям.
		if Game.yrka != null and Game.yrka.enabled:
			Game.yrka.notice_sound(p.global_position, 0.9)
		if not _told_flash:
			_told_flash = true
			Game.hud.subtitle(Loc.t(&"zenit.flash_seen"), 3.0)
	# Гость у двери: вспышка в глазок/щель — отшатывается.
	var ev := Game.events
	if ev != null and ev.knocking and Game.is_home() and p.is_looking_at(NightEvents.DOOR_POS, 35.0) \
			and p.global_position.distance_to(NightEvents.DOOR_POS) < 7.0:
		ev.repel_knock_with_flash()


## Утро: проявка. Пустая плёнка — проявлять нечего.
func has_prints() -> bool:
	return not photos.is_empty() or not partner_photos.is_empty()


## Итог плёнки в «дело»: доказательства копятся к финалу.
func bank_evidence() -> int:
	var n := 0
	for ph in photos:
		n += (ph["tags"] as Array).size() + (1 if ph["ghost"] else 0)
	SaveGame.flags["evidence"] = int(SaveGame.flags.get("evidence", 0)) + n
	return n
