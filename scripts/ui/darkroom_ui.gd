class_name DarkroomUI
extends Control
## Советская фотолаборатория с увеличителем «Ленинград-4» и кюветами проявки.
## Проявка фотоплёнок под неактиничным красным светом: «Проявитель СТ-1», «Стоп-ванна» и «Фиксаж БКФ-2».
## Отпечатки постепенно проступают в химическом растворе.
## Инструмент оптической лупы (8x) позволяет разглядеть скрытые пугающие микродетали зерна эмульсии.

signal closed

const PRINT_SHADER := """shader_type canvas_item;
uniform float seed = 0.0;
uniform float develop_progress: hint_range(0.0, 1.0) = 1.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	float n = fract(sin(dot(UV * vec2(311.7, 183.3) + seed, vec2(12.9898, 78.233))) * 43758.5453);
	// Проявление: в растворе сначала медленно выходят тени, затем полутона и света
	float latent = smoothstep(1.0 - develop_progress * 1.15, 1.0 - develop_progress * 0.85, 1.0 - g);
	g = (1.0 - exp(-1.9 * g)) / (1.0 - exp(-1.9));
	g = clamp(g + (n - 0.5) * 0.09, 0.0, 1.0);
	g = mix(0.95, g, latent);
	float v = 1.0 - length(UV - 0.5) * 0.55;
	COLOR = vec4(vec3(g * v) * vec3(1.0, 0.92, 0.8), c.a * COLOR.a);
}
"""
const CELL := Vector2(232, 130)

static var tank_loaded_this_session := false
var _black_overlay: ColorRect
var _black_label: Label
var _spiral_turns := 0
var _breathed := false

var _shader: Shader
var _n := 0
var _loupe_overlay: Control
var _loupe_img: TextureRect
var _loupe_title: Label
var _loupe_desc: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_shader = Shader.new()
	_shader.code = PRINT_SHADER
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.012, 0.008, 1.0)
	UiKit.place(self, bg, 0, 0, 1, 1, 0, 0, 0, 0)

	var lamp := ColorRect.new()   # красный неактиничный фонарь сверху
	lamp.color = Color(0.85, 0.06, 0.04, 0.14)
	UiKit.place(self, lamp, 0.15, 0.0, 0.85, 0.45, 0, 0, 0, 0)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	UiKit.place(self, root, 0.5, 0.5, 0.5, 0.5, -540, -330, 540, 330)

	# Заголовок фотолаборатории
	var title := UiKit.label(Loc.p("ФОТОЛАБОРАТОРИЯ «ЛЕНИНГРАД-4» · БУМАГА «УНИБРОМ»", "DARKROOM 'LENINGRAD-4' · 'UNIBROM' PAPER"), 20)
	title.add_theme_color_override(&"font_color", Color(1.0, 0.6, 0.5))
	root.add_child(title)

	var sub := UiKit.label(Loc.p("Фаза 2: Экспонирование на фотобумагу и покачивание кювет в проявителе УП-2", "Phase 2: Paper exposure and tray agitation in UP-2 developer"), 12)
	sub.add_theme_color_override(&"font_color", Color(0.88, 0.52, 0.46))
	root.add_child(sub)

	# Три кюветы (Проявитель, Стоп-ванна, Фиксаж)
	var trays_box := HBoxContainer.new()
	trays_box.add_theme_constant_override("separation", 12)
	root.add_child(trays_box)
	trays_box.add_child(_make_tray_badge(Loc.t(&"darkroom.tray_dev"), Color(0.28, 0.08, 0.06)))
	trays_box.add_child(_make_tray_badge(Loc.t(&"darkroom.tray_stop"), Color(0.18, 0.12, 0.08)))
	trays_box.add_child(_make_tray_badge(Loc.t(&"darkroom.tray_fix"), Color(0.12, 0.14, 0.20)))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var z := Game.zenit
	var has_photos := z != null and not z.photos.is_empty()

	if has_photos:
		var shots: Array[Dictionary] = z.photos.duplicate()
		if Game.night >= 4:
			shots.append(_create_paradox_shot())
		_film(list, shots, Loc.t(&"zenit.dr_title", [Game.night]))
		if not z.partner_photos.is_empty():
			_film(list, z.partner_photos, Loc.t(&"zenit.dr_partner"))
	else:
		# Архивная плёнка Семёнова №3 из кладовой
		var sem_shots: Array[Dictionary] = _get_semenov_archive_shots()
		if Game.night >= 4:
			sem_shots.append(_create_paradox_shot())
		_film(list, sem_shots, Loc.t(&"darkroom.semenov_film"))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(row)

	var hint_lbl := UiKit.label(Loc.t(&"darkroom.loupe_hint"), 12)
	hint_lbl.add_theme_color_override(&"font_color", Color(0.75, 0.55, 0.5))
	row.add_child(hint_lbl)
	row.add_spacer(false)

	var btn := UiKit.button(Loc.t(&"zenit.dr_done"), func() -> void: closed.emit())
	row.add_child(btn)
	btn.grab_focus.call_deferred()

	_build_loupe_overlay()
	if not tank_loaded_this_session:
		_build_blind_tank_phase()


func _build_blind_tank_phase() -> void:
	_black_overlay = ColorRect.new()
	_black_overlay.color = Color.BLACK
	_black_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	UiKit.place(self, _black_overlay, 0, 0, 1, 1, 0, 0, 0, 0)

	var center_box := VBoxContainer.new()
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center_box.add_theme_constant_override("separation", 14)
	_black_overlay.add_child(center_box)
	UiKit.place(_black_overlay, center_box, 0.5, 0.5, 0.5, 0.5, -380, -140, 380, 140)

	var h1 := UiKit.label(Loc.p("ФАЗА 1: ЗАРЯДКА В ЭБОНИТОВЫЙ БАЧОК (100% ТЕМНОТА)", "PHASE 1: EBONITE SPIRAL TANK LOADING (TOTAL DARKNESS)"), 16, HORIZONTAL_ALIGNMENT_CENTER)
	h1.add_theme_color_override("font_color", Color(0.85, 0.25, 0.22))
	center_box.add_child(h1)

	var desc := UiKit.label(Loc.p("Плёнка «Свема ФОТО-64» — изопанхроматическая (красный свет засветит её в черноту).\nОриентируйтесь вслепую по слуху и щелчкам перфорации спирали.\n\n[Колёсико мыши вверх (Wheel Up)] — вращать спираль\n[Wheel Down] — отмотка назад при заедании", "Film 'Svema PHOTO-64' is panchromatic (red light ruins it completely).\nWork by touch in total darkness, listening to perforation clicks.\n\n[Mouse Wheel Up] — turn spiral\n[Wheel Down] — unwind snag"), 13, HORIZONTAL_ALIGNMENT_CENTER)
	desc.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	center_box.add_child(desc)

	_black_label = UiKit.label(Loc.p("Заправлено витков: 0 / 10", "Spiral turns: 0 / 10"), 18, HORIZONTAL_ALIGNMENT_CENTER)
	_black_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	center_box.add_child(_black_label)

	var skip_btn := UiKit.button(Loc.p("Закрутить крышку бачка [Готово]", "Screw tank lid [Done]"), func() -> void:
		_finish_spiral_loading()
	)
	center_box.add_child(skip_btn)


func _unhandled_input(event: InputEvent) -> void:
	if _black_overlay != null and is_instance_valid(_black_overlay) and _black_overlay.visible:
		if event is InputEventMouseButton and event.is_pressed():
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_advance_spiral()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_rewind_spiral()


func _advance_spiral() -> void:
	_spiral_turns += 1
	Game.audio.play_2d("res://assets/audio/clank.ogg", -12.0)
	if _spiral_turns == 5 and not _breathed:
		_breathed = true
		Game.audio.play_2d("res://assets/audio/teeth_chatter.ogg", -6.0)
		Game.hud.subtitle(Loc.p("(В темноте в 30 см от вашего левого уха раздался тихий влажный вздох...)", "(In the darkness 30 cm from your ear, a wet breath sighed...)"), 4.0)
	if _black_label != null:
		_black_label.text = Loc.p("Заправлено витков: %d / 10" % _spiral_turns, "Spiral turns: %d / 10" % _spiral_turns)
	if _spiral_turns >= 10:
		_finish_spiral_loading()


func _rewind_spiral() -> void:
	_spiral_turns = maxi(_spiral_turns - 1, 0)
	Game.audio.play_2d("res://assets/audio/clank.ogg", -15.0)
	if _black_label != null:
		_black_label.text = Loc.p("Заправлено витков: %d / 10" % _spiral_turns, "Spiral turns: %d / 10" % _spiral_turns)


func _finish_spiral_loading() -> void:
	tank_loaded_this_session = true
	Game.audio.play_2d("res://assets/audio/clank.ogg", -2.0)
	Game.hud.subtitle(Loc.p("Крышка эбонитового бачка закручена намертво. Включаем красный лабораторный фонарь...", "Ebonite tank lid screwed lightproof. Turning on red lab lamp..."), 3.5)
	if _black_overlay != null and is_instance_valid(_black_overlay):
		_black_overlay.queue_free()


func _make_tray_badge(txt: String, bg_col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = Color(0.85, 0.35, 0.28, 0.5)
	sb.set_border_width_all(1)
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override(&"panel", sb)
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override(&"font_size", 11)
	l.add_theme_color_override(&"font_color", Color(1.0, 0.8, 0.75))
	p.add_child(l)
	return p


func _film(list: VBoxContainer, shots: Array[Dictionary], head: String) -> void:
	if head != "":
		var h := UiKit.label(head, 15)
		h.add_theme_color_override(&"font_color", Color(1.0, 0.65, 0.55))
		list.add_child(h)
	if shots.is_empty():
		return
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	list.add_child(grid)
	for i in shots.size():
		var ph: Dictionary = shots[i]
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(CELL.x, 0)
		cell.add_theme_constant_override("separation", 3)
		grid.add_child(cell)

		var frame := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.92, 0.88, 0.80)
		sb.set_content_margin_all(5)
		frame.add_theme_stylebox_override(&"panel", sb)
		cell.add_child(frame)

		var tr := TextureRect.new()
		tr.custom_minimum_size = CELL
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var img: Image = ph.get("img")
		if img != null and not img.is_empty():
			tr.texture = ImageTexture.create_from_image(img)
		var mat := ShaderMaterial.new()
		mat.shader = _shader
		mat.set_shader_parameter(&"seed", float(i) * 1.37)
		mat.set_shader_parameter(&"develop_progress", 0.0)
		tr.material = mat
		frame.add_child(tr)

		# Кнопка для вызова оптической лупы
		var inspect_btn := Button.new()
		inspect_btn.flat = true
		inspect_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var cur_ph := ph
		inspect_btn.pressed.connect(func() -> void: _inspect_photo_loupe(cur_ph))
		frame.add_child(inspect_btn)

		var cap := UiKit.label(_caption(ph), 12)
		cap.add_theme_color_override(&"font_color", Color(0.95, 0.7, 0.62) if not ph.get("ghost", false) else Color(1.0, 0.42, 0.36))
		cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cap.custom_minimum_size = Vector2(CELL.x, 0)
		cell.add_child(cap)

		# Химическое проявление: бумага окунается в кювету, изображение проступает
		frame.modulate = Color(1, 1, 1, 0)
		var tw := create_tween()
		tw.tween_interval(0.2 + _n * 0.35)
		tw.tween_property(frame, "modulate:a", 1.0, 0.25)
		if ph.get("paradox", false):
			tw.tween_callback(func() -> void:
				AudioDirector.play_raw("res://assets/audio/clank.ogg", -2.0)
				Director.add_tension(12.0, "хронологический парадокс")
			)
		tw.tween_method(func(val: float) -> void: mat.set_shader_parameter(&"develop_progress", val), 0.0, 1.0, 1.4)
		_n += 1


func _caption(ph: Dictionary) -> String:
	if ph.get("paradox", false):
		return Loc.t(&"darkroom.paradox_title")
	var t := Game.minutes_to_clock(int(ph.get("min", 0))) + " — "
	var img: Image = ph.get("img")
	if ph.get("archive_title", "") != "":
		return ph["archive_title"]
	if ph.get("voice", false):
		return t + Loc.t(&"zenit.cap_voice")
	var parts := PackedStringArray()
	for id in ph.get("tags", []):
		if String(id).begins_with("poi_"):
			parts.append(Loc.t(StringName("poi." + String(id) + ".cap")))
		else:
			parts.append(Loc.t(StringName("anom." + String(id))))
	if ph.get("has_eyes", false):
		parts.append(Loc.p("отражение зрачков в темноте", "pupil reflection in dark"))
	elif ph.get("has_shadow", false):
		parts.append(Loc.p("суставчатая тень в соснах", "jointed shadow in pines"))
	elif ph.get("has_tracks", false):
		parts.append(Loc.p("босые следы на снегу", "barefoot prints in snow"))
	elif ph.get("has_face", false):
		parts.append(Loc.p("двойная экспозиция: кричащее лицо", "double exposure: screaming face"))
	elif ph.get("has_fingers", false):
		parts.append(Loc.p("обмороженные пальцы на косяке", "frostbitten fingers on jamb"))
	elif ph.get("ghost", false):
		parts.append(Loc.t(&"zenit.cap_ghost"))
	if parts.is_empty():
		return t + (Loc.t(&"zenit.cap_empty") if img != null else Loc.t(&"zenit.cap_fogged"))
	return t + "; ".join(parts)


func _get_semenov_archive_shots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var data := [
		{
			"path": "res://assets/textures/photos/photo_archive_mast.png",
			"archive_title": Loc.p("Кадр №1: «Метеомачта АШ-4 на закате. Ноябрь 1982 г.»", "Frame #1: 'Mast ASH-4 at dusk. Nov 1982'"),
			"detail": Loc.p("Метеомачта АШ-4 и будка приборов в метели. На отметке 12м за растяжку цепляется длинный суставчатый силуэт, склонившийся над станцией. Два зрачка светятся отражённым светом вспышки.", "Mast ASH-4 and shelter in blizzard. At 12m mark a long jointed silhouette clings to the guy wire, leaning over the station. Two pupils gleam with flash reflection."),
			"ghost": true
		},
		{
			"path": "res://assets/textures/photos/photo_archive_adit.png",
			"archive_title": Loc.p("Кадр №2: «Штольня №4 и вагонетка. Октябрь 1982 г.»", "Frame #2: 'Adit #4 & mine cart. Oct 1982'"),
			"detail": Loc.p("Портал заброшенной штольни №4 в базальтовой скале и опрокинутая вагонетка УВО-0.6. Из абсолютной черноты тоннеля выступает фигура в бушлате, а по обледенелой скале за ней тянутся неестественно длинные пальцы.", "Portal of abandoned Adit #4 in basalt rock with overturned mine cart. Out of total blackness a figure in pea coat emerges, while unnaturally long fingers stretch along the icy rock behind it."),
			"ghost": true
		},
		{
			"path": "res://assets/textures/photos/photo_archive_porch.png",
			"archive_title": Loc.p("Кадр №3: «Крыльцо станции в буран. Декабрь 1982 г.»", "Frame #3: 'Cabin porch in blizzard. Dec 1982'"),
			"detail": Loc.p("Последний кадр из плёнки Семёнова. Дверь сруба приоткрыта: в узкой щели изнутри за косяк судорожно держится бледная обмороженная ладонь. На стекле окна рядом — расплющенное в оскале лицо, прижатое снаружи.", "Last shot on Semyonov's film. Cabin door ajar: in narrow slit from inside a pale frostbitten hand clutches the frame. On window glass nearby — a flattened grinning face pressed from outside."),
			"ghost": true
		},
		{
			"path": "res://assets/textures/photos/photo_archive_crew.png",
			"archive_title": Loc.p("Кадр №4: «Бригада ТДС Кедр-7. Август 1982 г.»", "Frame #4: 'Crew of TDS Kedr-7. Aug 1982'"),
			"detail": Loc.p("Групповой снимок смены метеорологов: Семёнов сидит на скамье, рядом техник и радист. Прямо за плечом Семёнова стоит четвёртая размытая фигура в тёмном балахоне без лица, положа длинную руку ему на спину.", "Group portrait of meteorologist shift: Semyonov sits on bench with tech and radio operator. Right behind Semyonov stands a fourth blurred figure in dark cowl without face, resting a long hand on his back."),
			"ghost": true
		}
	]
	for item in data:
		var img: Image = null
		if ResourceLoader.exists(item["path"]):
			var tex := load(item["path"]) as Texture2D
			if tex != null:
				img = tex.get_image()
		elif FileAccess.file_exists(item["path"]):
			img = Image.load_from_file(item["path"])
		if img != null:
			out.append({
				"img": img,
				"archive_title": item["archive_title"],
				"detail": item["detail"],
				"ghost": item["ghost"]
			})
	return out


func _build_loupe_overlay() -> void:
	_loupe_overlay = Control.new()
	_loupe_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loupe_overlay.visible = false
	add_child(_loupe_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.01, 0.01, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loupe_overlay.add_child(dim)

	var center := VBoxContainer.new()
	center.add_theme_constant_override("separation", 12)
	UiKit.place(_loupe_overlay, center, 0.5, 0.5, 0.5, 0.5, -340, -250, 340, 250)

	_loupe_title = UiKit.label(Loc.t(&"darkroom.loupe_active"), 16)
	_loupe_title.add_theme_color_override(&"font_color", Color(1.0, 0.7, 0.6))
	center.add_child(_loupe_title)

	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.92, 0.85)
	sb.set_content_margin_all(8)
	frame.add_theme_stylebox_override(&"panel", sb)
	center.add_child(frame)

	_loupe_img = TextureRect.new()
	_loupe_img.custom_minimum_size = Vector2(520, 310)
	_loupe_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_loupe_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter(&"seed", 4.12)
	mat.set_shader_parameter(&"develop_progress", 1.0)
	_loupe_img.material = mat
	frame.add_child(_loupe_img)

	_loupe_desc = UiKit.label("", 13)
	_loupe_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_loupe_desc.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.8))
	center.add_child(_loupe_desc)

	var close_loupe_btn := UiKit.button(Loc.p("✕ ЗАКРЫТЬ ЛУПУ", "✕ CLOSE LOUPE"), func() -> void: _loupe_overlay.visible = false)
	center.add_child(close_loupe_btn)


func _inspect_photo_loupe(ph: Dictionary) -> void:
	AudioDirector.play_raw("res://assets/audio/ui_tick.ogg", -4.0)
	var img: Image = ph.get("img")
	if img != null and not img.is_empty():
		_loupe_img.texture = ImageTexture.create_from_image(img)
	if ph.get("paradox", false):
		_loupe_title.text = Loc.t(&"darkroom.paradox_title")
		_loupe_desc.text = ph.get("detail", Loc.t(&"darkroom.paradox_desc"))
		Director.add_tension(15.0, "осознание хронологического парадокса")
		AudioDirector.play_raw("res://assets/audio/whisper.ogg", -4.0)
		Game.paradox_photo_seen = true
		_loupe_overlay.visible = true
		return
	var poi_tag: StringName = &""
	for t in ph.get("tags", []):
		if String(t).begins_with("poi_"):
			poi_tag = t
			break
	if poi_tag != &"":
		_loupe_title.text = Loc.t(&"darkroom.loupe_poi_revealed")
		_loupe_desc.text = ph.get("detail", Loc.t(StringName("poi." + String(poi_tag) + ".loupe")))
		Director.add_tension(4.0, "скрытая деталь снимка")
	else:
		_loupe_title.text = Loc.t(&"darkroom.loupe_active")
		_loupe_desc.text = ph.get("detail", _caption(ph))
		if ph.get("ghost", false) or ph.get("has_eyes", false) or ph.get("has_shadow", false) or ph.get("has_tracks", false) or ph.get("has_face", false) or ph.get("has_fingers", false):
			Director.add_tension(7.0, "аномалия на фотоплёнке")
			AudioDirector.play_raw("res://assets/audio/whisper.ogg", -8.0)
	_loupe_overlay.visible = true


func _create_paradox_shot() -> Dictionary:
	var path := "res://assets/textures/photos/photo_archive_paradox.png"
	var img: Image = null
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			img = tex.get_image()
	elif FileAccess.file_exists(path):
		img = Image.load_from_file(path)
	if img == null:
		img = _create_paradox_image()
	return {
		"img": img,
		"paradox": true,
		"archive_title": Loc.t(&"darkroom.paradox_title"),
		"detail": Loc.p("На снимке — стол проявки и спина дежурного прямо в этот момент. В метре позади за косяком двери стоит наблюдающая Ырка со светящимися глазами. Снимок ещё мокрый.", "The print shows the darkroom table and the duty officer's back right now. One meter behind in the doorway stands the Yrka with glowing eyes. The print is still wet."),
		"ghost": true
	}


func _create_paradox_image() -> Image:
	var img := Image.create(160, 100, false, Image.FORMAT_RGB8)
	for y in range(100):
		for x in range(160):
			var nx := float(x) / 160.0
			var ny := float(y) / 100.0
			# Темная комната, неактиничный красный свет сверху
			var red_light := exp(-((nx - 0.5) * (nx - 0.5) * 4.0 + (ny - 0.2) * (ny - 0.2) * 8.0)) * 0.4
			var col := Color(red_light * 0.8 + 0.04, red_light * 0.15 + 0.02, red_light * 0.1 + 0.02)
			
			# Стол проявки впереди (ny > 0.65)
			if ny > 0.65:
				col = col.lerp(Color(0.12, 0.04, 0.03), 0.7)
				# Ванночки с раствором
				if absf(nx - 0.3) < 0.12 and absf(ny - 0.75) < 0.06:
					col = Color(0.25, 0.06, 0.04)
				elif absf(nx - 0.65) < 0.12 and absf(ny - 0.75) < 0.06:
					col = Color(0.2, 0.08, 0.05)

			# Фотоувеличитель Ленинград-4 слева на столе (штанга и фонарь)
			if absf(nx - 0.22) < 0.02 and ny > 0.25 and ny < 0.7:
				col = Color(0.18, 0.05, 0.04)
			if absf(nx - 0.22) < 0.06 and absf(ny - 0.35) < 0.07:
				col = Color(0.35, 0.08, 0.05)

			# Силуэт человека в ватнике со спины (по центру)
			var head_dist := ((nx - 0.5) * (nx - 0.5) * 3.5 + (ny - 0.42) * (ny - 0.42) * 2.5)
			if head_dist < 0.015:
				col = Color(0.02, 0.01, 0.01)
			var body_dist := ((nx - 0.5) * (nx - 0.5) * 1.5 + (ny - 0.68) * (ny - 0.68) * 1.2)
			if body_dist < 0.065 and ny >= 0.42:
				col = Color(0.01, 0.01, 0.01)

			img.set_pixel(x, y, col)
	return img


func handle_input(event: InputEvent) -> bool:
	if _loupe_overlay != null and _loupe_overlay.visible:
		if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"interact"):
			_loupe_overlay.visible = false
			return true
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_cancel"):
		closed.emit()
		return true
	return false
