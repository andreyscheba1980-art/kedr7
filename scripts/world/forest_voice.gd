class_name ForestVoice
extends Node
## «Голос из леса». Тайга запоминает, что ты говорил, и зовёт тебя твоим же голосом.
##
## Откуда голос:
##   • кооп — передачи напарника по рации (их же подделывает Ырка в эфире);
##   • с микрофоном (и галочкой «Ырка может использовать мой голос») — твои последние фразы.
##     Хранятся только в памяти, на диск не пишутся, стираются при выходе и при снятии галочки;
##   • без микрофона — мама, Семёнов, Витя.
## Как растёт по ночам:
##   2 — далеко и неразборчиво; 3–4 — внятно, с кромки леса; 5+ — не отвечаешь, он подходит сам;
##   6+ — и в доме: из-за двери, из-под пола; 7 — из-под пола диктуют цифры сводки.
## Правила (Семёнов): не отвечай вслух и не сходи с леера на голос. Промолчал — безопасно, голос стихнет.
## Снять источник на «Зенит-Е» — голос обрывается и до утра молчит.

const RATE := 11025
const PRE_ROLL := 0.35
const MIN_CLIP := 0.7
const MIN_SPEECH := 0.35
const MAX_CLIP := 4.0
const KEEP := 5
const HANGOVER := 0.45
const SOURCE_GAP := 9.0         ## ближе голос не подходит — дальше уже Ырка

## Свои фразы игрока — только в памяти, переживают смену ночь/день, но не выход из игры.
static var clips: Array[PackedFloat32Array] = []
static var test_allow := false   ## автотест: своя «фраза» без микрофона

var banished := false           ## источник снят на плёнку — до утра тихо
var episode := false
var kind: StringName = &"forest"   ## forest | door | floor | numbers
var source := Vector3.ZERO

var _cd := 0.0
var _calls_left := 0
var _calls_done := 0
var _call_t := 0.0
var _listen_t := 0.0            ## окно «ответа» после зова
var _playing_t := 0.0           ## пока звучит — микрофон не слушаем: в колонках он поймал бы сам себя
var _follow_d0 := 0.0
var _warned_follow := false
var _clip: Dictionary = {}
var _own_heard := false
var _rule_told := false
var _quiet_told := false
var _numbers_done := false
var _players: Array[AudioStreamPlayer3D] = []

# Запись
var _pre := PackedFloat32Array()
var _cur := PackedFloat32Array()
var _recording := false
var _quiet_t := 0.0
var _speech_t := 0.0
var _dec_acc := 0.0
var _dec_sum := 0.0
var _dec_n := 0


func _ready() -> void:
	Game.forest_voice = self
	Mic.frames_captured.connect(_on_frames)
	Settings.changed.connect(_on_settings)
	_cd = Game.rng.randf_range(90.0, 160.0)
	_on_settings()


func _exit_tree() -> void:
	if Game.forest_voice == self:
		Game.forest_voice = null


static func voice_allowed() -> bool:
	return (Settings.mic_enabled or test_allow) and Settings.mic_mimic


func _on_settings() -> void:
	if not voice_allowed() and not test_allow:
		clips.clear()        # сняли галочку — чужих (своих) слов в памяти не остаётся
		_cur = PackedFloat32Array()
		_recording = false


# --- Запись своих фраз --------------------------------------------------------

func _can_record() -> bool:
	if not voice_allowed() or _playing_t > 0.0 or Game.player == null or Game.dead:
		return false
	# В коопе мир слышит только сказанное в рацию — болтовню в Discord Ырка не запоминает.
	return Net.role == "" or Net.talking


func _on_frames(buf: PackedVector2Array) -> void:
	if not _can_record():
		_recording = false
		_pre = PackedFloat32Array()
		return
	var tmp := PackedFloat32Array()
	var step := AudioServer.get_mix_rate() / float(RATE)
	for v in buf:
		_dec_sum += (v.x + v.y) * 0.5
		_dec_n += 1
		_dec_acc += 1.0
		if _dec_acc >= step:
			_dec_acc -= step
			tmp.append(_dec_sum / float(_dec_n))
			_dec_sum = 0.0
			_dec_n = 0
	var dt := tmp.size() / float(RATE)
	var speaking := Mic.current_level >= Settings.mic_threshold
	if _recording:
		_cur.append_array(tmp)
		if speaking:
			_quiet_t = 0.0
			_speech_t += dt
		else:
			_quiet_t += dt
		if _quiet_t > HANGOVER or _cur.size() > int(MAX_CLIP * RATE):
			_finish_clip()
	elif speaking:
		_recording = true
		_cur = _pre.duplicate()
		_cur.append_array(tmp)
		_quiet_t = 0.0
		_speech_t = dt
	_pre.append_array(tmp)
	var keep := int(PRE_ROLL * RATE)
	if _pre.size() > keep:
		_pre = _pre.slice(_pre.size() - keep)


func _finish_clip() -> void:
	_recording = false
	# Хвост тишины подрезаем, оставляя короткий выдох.
	var cut := int(maxf(_quiet_t - 0.15, 0.0) * RATE)
	var clip := _cur.slice(0, maxi(_cur.size() - cut, 0))
	_cur = PackedFloat32Array()
	if clip.size() < int(MIN_CLIP * RATE) or _speech_t < MIN_SPEECH:
		return
	if clip.size() > int(MAX_CLIP * RATE):
		clip = clip.slice(0, int(MAX_CLIP * RATE))
	clips.append(clip)
	while clips.size() > KEEP:
		clips.pop_front()
	if Net.test_mode or OS.is_debug_build():
		print("[forest_voice] запомнена фраза: %.1f с (всего %d)" % [clip.size() / float(RATE), clips.size()])


## Для автотеста: подложить «фразу» без микрофона.
func inject_clip(clip: PackedFloat32Array) -> void:
	clips.append(clip)
	while clips.size() > KEEP:
		clips.pop_front()


# --- Эпизоды ------------------------------------------------------------------

func _process(delta: float) -> void:
	_playing_t -= delta
	_listen_t -= delta
	if not Game.is_night() or Game.dead or Game.dying or Game.shift_over or Game.player == null:
		if episode:
			_end_episode(false)
		return
	if Game.night < 2 or banished:
		return
	if episode:
		_update_episode(delta)
		return
	_cd -= delta
	if _cd > 0.0 or Director.hold:
		return
	if Game.yrka != null and Game.yrka.stage in [YrkaThreat.Stage.CHASE, YrkaThreat.Stage.CONTACT]:
		return
	if Game.is_outside() and Game.yard != null:
		# Зовут того, кто идёт по лееру: на верёвке — значит слушает.
		if Game.yard.distance_to_path(Game.player.global_position) < 4.0:
			start_episode(&"forest")
	elif Game.is_home() and Game.night >= 6:
		if Game.night >= 7 and Game.zone == &"radio_room" and not _numbers_done:
			start_episode(&"numbers")
		elif Game.zone == &"corridor" or Game.zone == &"vestibule":
			start_episode(&"door")
		elif Game.zone == &"room" or Game.zone == &"radio_room":
			start_episode(&"floor")


func start_episode(k: StringName) -> bool:
	var src := _pick_source(k)
	if src == Vector3.INF:
		_cd = 12.0
		return false
	kind = k
	source = src
	episode = true
	_calls_done = 0
	_warned_follow = false
	var n := Game.night
	match k:
		&"forest":
			_calls_left = 1 if n <= 2 else 2 if n <= 4 else 3
		&"numbers":
			_calls_left = 1
			_numbers_done = true
		_:
			_calls_left = 2
	_clip = _pick_clip(k)
	_call_t = 0.0
	_follow_d0 = _flat(Game.player.global_position, source)
	return true


func _update_episode(delta: float) -> void:
	# Ушёл под крышу — лес замолкает; вышел из дома — замолкает голос за дверью.
	if (kind == &"forest" and not Game.is_outside()) or (kind != &"forest" and not Game.is_home()):
		_end_episode(false)
		return
	if Game.yrka != null and Game.yrka.stage in [YrkaThreat.Stage.CHASE, YrkaThreat.Stage.CONTACT]:
		_end_episode(false)
		return
	if kind == &"forest":
		_check_follow()
	_check_answer()
	_call_t -= delta
	if _call_t > 0.0:
		return
	if _calls_left <= 0:
		_end_episode(true)
		return
	_call()
	_calls_left -= 1
	_calls_done += 1
	_call_t = Game.rng.randf_range(9.0, 13.0)


func _end_episode(ignored: bool) -> void:
	episode = false
	_listen_t = 0.0
	_cd = Game.rng.randf_range(240.0, 340.0) if Game.is_home() else Game.rng.randf_range(150.0, 240.0)
	if not ignored or Game.hud == null:
		return
	if not _rule_told and Game.night <= 3:
		_rule_told = true
		Game.hud.subtitle(Loc.t(&"fv.rule"), 5.0)
	elif kind == &"forest" and Game.night >= 5 and not _quiet_told:
		_quiet_told = true
		Game.hud.subtitle(Loc.t(&"fv.quiet"), 3.5)
	Director.add_tension(-6.0, "голос из леса стих: не ответил")


func _call() -> void:
	var p := Game.player
	var n := Game.night
	if kind == &"numbers":
		_say_numbers()
		return
	# С пятой ночи молчание его не останавливает: каждый следующий зов — ближе.
	if kind == &"forest" and _calls_done > 0 and n >= 5:
		var to := source - p.global_position
		to.y = 0.0
		var d := to.length()
		var nd := maxf(d * 0.62, SOURCE_GAP)
		source = p.global_position + to.normalized() * nd
		source.y = Terrain.height(source.x, source.z)
		if Game.hud != null and _calls_done == 1:
			Game.hud.subtitle(Loc.t(&"fv.closer"), 2.5)
	var muffled := kind == &"floor" or (kind == &"forest" and n <= 2)
	var pos := source + Vector3(0, 1.3 if kind != &"floor" else 0.0, 0)
	var len := _play(_clip, pos, muffled)
	_playing_t = len + 0.6
	_listen_t = len + 6.0
	_subtitle_for_clip(muffled)
	if kind == &"forest" and n >= 3 and Game.audio != null:
		Game.audio.trigger_vacuum(len + 0.8)   # метель стихает, чтобы ты точно расслышал
	Director.add_tension(9.0 if _calls_done == 0 else 6.0, "голос из леса")
	if Net.test_mode or OS.is_debug_build():
		print("[forest_voice] зов %s (%s) %.0f м, ночь %d" % [kind, _clip.get("src", "?"), _flat(p.global_position, source), n])


func _subtitle_for_clip(muffled: bool) -> void:
	if Game.hud == null:
		return
	var src: StringName = _clip.get("src", &"stock")
	if kind == &"forest" and muffled:
		Game.hud.subtitle(Loc.t(&"fv.muffled"), 3.0)
		return
	match src:
		&"own":
			var key := &"fv.own" if _own_heard else &"fv.own_first"
			if kind == &"door":
				key = &"fv.door"
			elif kind == &"floor":
				key = &"fv.floor"
			_own_heard = true
			Game.hud.subtitle(Loc.t(key), 3.5, 2)
		&"partner":
			var inside := Net.partner_indoors()
			Game.hud.subtitle(Loc.t(&"fv.partner_in" if inside else &"fv.partner"), 3.5, 2)
		_:
			var where := &"fv.where_forest" if kind == &"forest" else &"fv.where_door" if kind == &"door" else &"fv.where_floor"
			Game.hud.subtitle(Loc.t(where, [Loc.t(_clip.get("sub", &"yrka.voice.1"))]), 3.2)


# --- Правила: ответ вслух и уход с леера ------------------------------------------

func _check_answer() -> void:
	if _listen_t <= 0.0 or _playing_t > 0.0 or not Settings.mic_enabled:
		return
	if not Mic.is_speaking or Mic.current_level < Settings.mic_threshold:
		return
	if Net.role != "" and not Net.talking:
		return
	answered()


## Дежурный ответил голосу вслух.
func answered() -> void:
	_listen_t = 0.0
	if Game.hud != null:
		Game.hud.subtitle(Loc.t(&"fv.answered"), 3.0, 2)
	Director.add_tension(14.0, "ответил голосу из леса")
	if Game.yrka != null and Game.yrka.enabled and kind == &"forest":
		Game.yrka.notice_sound(source, 1.5)
		Game.yrka.threat = maxf(Game.yrka.threat, YrkaThreat.CALL_AT)
	# Ответил — значит, есть с кем говорить: зовёт ещё раз и ближе.
	if Game.night >= 3:
		_calls_left = maxi(_calls_left, 1) + 1
		_call_t = minf(_call_t, 4.0)
		if kind == &"forest":
			var to := source - Game.player.global_position
			to.y = 0.0
			source = Game.player.global_position + to.normalized() * maxf(to.length() * 0.6, SOURCE_GAP)


func _check_follow() -> void:
	if Game.yard == null or _calls_done == 0:
		return
	var p := Game.player.global_position
	var d := _flat(p, source)
	var off := Game.yard.distance_to_path(p) > 6.0
	if not off or d > _follow_d0 - 5.0:
		return
	if not _warned_follow:
		_warned_follow = true
		if Game.hud != null:
			Game.hud.subtitle(Loc.t(&"fv.follow"), 3.0, 2)
		Director.add_tension(10.0, "пошёл на голос")
		if Game.yrka != null and Game.yrka.enabled:
			Game.yrka.threat = minf(Game.yrka.threat + 20.0, 100.0)
	elif d < SOURCE_GAP + 1.5 or d < _follow_d0 - 16.0:
		_end_episode(false)
		NightMemory.mark(&"obeyed_fake")
		if Game.yrka != null:
			Game.yrka.lure_strike()


# --- Источник и звук --------------------------------------------------------------

func _pick_source(k: StringName) -> Vector3:
	var p := Game.player.global_position
	match k:
		&"door":
			return Yard.DOOR_OUT + Vector3(-0.8, 0, 0)
		&"floor", &"numbers":
			var a := Game.rng.randf() * TAU
			return p + Vector3(sin(a), 0, cos(a)) * Game.rng.randf_range(1.0, 2.2) + Vector3(0, -0.9, 0)
	if Game.yard == null or Game.level == null:
		return Vector3.INF
	var n := Game.night
	for i in 20:
		var a := Game.rng.randf() * TAU
		var dir := Vector3(sin(a), 0, cos(a))
		var d := Game.rng.randf_range(34.0, 44.0) if n <= 2 else Game.rng.randf_range(25.0, 40.0)
		var c := p + dir * d
		c.y = Terrain.height(c.x, c.z)
		if Game.yard.distance_to_path(c) < 14.0:
			continue
		if _flat(c, Yard.HOUSE_CENTER) < 22.0:
			continue
		if Game.level.zone_at(c) != &"yard":
			continue
		return c
	return Vector3.INF


func _pick_clip(k: StringName) -> Dictionary:
	if k == &"numbers":
		return {"src": &"numbers"}
	# Кооп: голос напарника — особенно страшно, когда он сидит в доме.
	if Net.role != "" and Net.in_session and not Net.partner_dead():
		var pc := Net.partner_clip()
		if not pc.is_empty() and (Net.partner_indoors() or Game.rng.randf() < 0.6):
			return {"src": &"partner", "pcm": pc}
	if voice_allowed() and not clips.is_empty():
		return {"src": &"own", "pcm": clips[Game.rng.randi_range(0, clips.size() - 1)]}
	var idx := Game.rng.randi_range(0, 3)
	var alts: Array[String] = []
	for who in ["mom", "sem"]:
		var ap := Voice.path(StringName("yrka_%s_%d" % [who, idx + 1]))
		if ap != "":
			alts.append(ap)
	if alts.is_empty():
		alts.append(YrkaThreat.VOICES[idx])
	return {"src": &"stock", "path": alts[Game.rng.randi_range(0, alts.size() - 1)], "sub": YrkaThreat.VOICE_SUBS[idx]}


func _play(c: Dictionary, pos: Vector3, muffled: bool) -> float:
	if Game.level == null:
		return 0.0
	var pl := AudioStreamPlayer3D.new()
	var len := 2.5
	var src: StringName = c.get("src", &"stock")
	if c.has("pcm"):
		var pcm: PackedFloat32Array = c["pcm"]
		pl.stream = to_wav(pcm, muffled)
		len = pcm.size() / float(RATE)
		# Голос тот же, но «не совсем»: ниже, и чем дальше в зиму — тем ниже.
		pl.pitch_scale = 0.95 if Game.night <= 4 else 0.9
		len /= pl.pitch_scale
	else:
		pl.stream = AudioDirector.cached_stream(String(c.get("path", YrkaThreat.VOICES[0])))
		if pl.stream != null:
			len = pl.stream.get_length()
	pl.bus = &"SFX"
	pl.volume_db = 3.0 if kind == &"forest" else -2.0
	pl.unit_size = 7.0 if kind == &"forest" else 3.0
	pl.max_distance = 80.0
	if muffled:
		pl.attenuation_filter_cutoff_hz = 1100.0
		pl.volume_db -= 4.0
	Game.level.add_child(pl)
	pl.global_position = pos
	pl.add_to_group(&"occludable")
	pl.finished.connect(pl.queue_free)
	pl.play()
	_track(pl)
	if src == &"own" and Game.night >= 5:
		# Эхо: тот же голос ещё раз, тише и с другой стороны — в лесу их несколько.
		var echo := pl.duplicate() as AudioStreamPlayer3D
		echo.volume_db -= 9.0
		echo.pitch_scale *= 0.97
		Game.level.add_child(echo)
		echo.global_position = pos + Vector3(Game.rng.randf_range(-12, 12), 0, Game.rng.randf_range(-12, 12))
		echo.finished.connect(echo.queue_free)
		_track(echo)
		get_tree().create_timer(0.35).timeout.connect(func() -> void:
			if is_instance_valid(echo):
				echo.play())
	return len


func _track(pl: AudioStreamPlayer3D) -> void:
	var alive: Array[AudioStreamPlayer3D] = []
	for x in _players:
		if is_instance_valid(x):
			alive.append(x)
	alive.append(pl)
	_players = alive


## PCM 11 кГц → WAV: громкость выравниваем (микрофон ПК даёт пик 0.02–0.05), края — без щелчков.
static func to_wav(pcm: PackedFloat32Array, muffled := false) -> AudioStreamWAV:
	var peak := 0.0
	for s in pcm:
		peak = maxf(peak, absf(s))
	var g := minf(0.72 / maxf(peak, 0.01), 30.0)
	var n := pcm.size()
	var fade := mini(int(0.012 * RATE), n / 4)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	for i in n:
		var s := pcm[i] * g
		if muffled:
			lp += 0.16 * (s - lp)
			s = lp * 1.7
		if i < fade:
			s *= i / float(fade)
		elif i > n - fade:
			s *= (n - i) / float(fade)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## Ночь 7: из-под пола, у рации, диктуют цифры сводки. Чужие.
func _say_numbers() -> void:
	var words: Array[StringName] = []
	if Voice.has(&"num_attention"):
		words.append(&"num_attention")
	var digits := PackedInt32Array([3, 1, 1, 4, 5, 2])
	for d in digits:
		var id := StringName("num_%d" % d)
		if Voice.has(id):
			words.append(id)
	if Game.hud != null:
		Game.hud.subtitle(Loc.t(&"fv.numbers"), 4.0, 2)
	Director.add_tension(10.0, "под полом диктуют цифры")
	_listen_t = 9.0
	_playing_t = 0.6 * words.size() + 0.6
	var pos := source
	for i in words.size():
		if not episode or Game.player == null:
			return
		var pl := Game.audio.play_3d(Voice.path(words[i]), pos, -4.0, 2.5) if Game.audio != null else null
		if pl != null:
			_track(pl)
			pl.pitch_scale = 0.82
			pl.attenuation_filter_cutoff_hz = 1400.0
		await get_tree().create_timer(0.62 if i > 0 else 1.1, false).timeout


# --- Снимок на «Зенит-Е» ----------------------------------------------------------

## Попал ли источник голоса в кадр (кадр — направление камеры, угол ~поле зрения объектива).
func in_frame(cam: Camera3D, half_angle_deg := 16.0) -> bool:
	if not episode or kind != &"forest" or cam == null:
		return false
	var to := source + Vector3(0, 1.3, 0) - cam.global_position
	if to.length() > 70.0:
		return false
	return rad_to_deg((-cam.global_basis.z).angle_to(to.normalized())) < half_angle_deg


## Источник снят: голос обрывается на полуслове и до утра молчит.
func banish() -> void:
	banished = true
	_end_episode(false)
	for pl in _players:
		if is_instance_valid(pl):
			pl.stop()
			pl.queue_free()
	_players.clear()
	if Game.hud != null:
		Game.hud.subtitle(Loc.t(&"fv.photo"), 3.0, 2)
	Director.add_tension(-12.0, "голос снят на плёнку")


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
