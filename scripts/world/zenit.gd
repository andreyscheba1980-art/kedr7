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
	var shot := {"img": img, "min": int(Game.shift_minutes), "tags": tags, "ghost": ghost_pos != Vector3.INF, "voice": voice, "flash": flash}
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
