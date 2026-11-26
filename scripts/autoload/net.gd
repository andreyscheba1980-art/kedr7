extends Node
## Кооп «Две вахты». Хост — он же сервер (ENet, без отдельной машины). Подключиться можно двумя путями:
##   • по коду комнаты через сервер комнат (noray на VPS: пробивает NAT, а не вышло — ретранслирует);
##   • по адресу (в одной сети, UPnP, Radmin VPN / ZeroTier).
##
## Кампания на двоих: хост выбирает ночь, после рассвета оба переходят к следующей (прогресс — у хоста
## в user://coop.json). Дней в коопе нет: места, которые открываются днём, к ночи уже открыты.
##
## Каждая машина пугает своего игрока сама (директор, испуги, Ырка — локально), но:
##   • позы напарников (видно друг друга), часы смены и метель (ведёт хост), выполненные задания — общие;
##   • «громкие» испуги отражаются у напарника (echo_*): стук в стену слышат оба, Жердяя в окне видно
##     и с улицы, свет в доме гаснет у обоих. Галлюцинации усталости и паранойя остаются личными;
##   • Ырка «живёт» у того, кто снаружи (клиент): хосту приходит её положение — для «Слухача» и барографа;
##   • рация на кнопке [C] (геймпад — R3): голос идёт только пока кнопка зажата; без микрофона — готовые
##     фразы на [X];
##   • сводку в доме передаёт хост, но цифры есть только у того, кто снимал приборы: их диктуют по рации.
## Главный страх: последние передачи напарника запоминаются, и в плохую минуту рация «говорит» его голосом
## (или его фразой), хотя он ничего не нажимал. Погибший остаётся в эфире и изредка пробивается сквозь
## помехи — и после этого живому уже не понять, где напарник, а где Ырка. Сверяйтесь паролем.

signal status(text: String)
signal session_start(night: int, seed: int)
signal partner_left
signal remote_ending(id: StringName)
signal room_code(code: String)

const PORT := 24777
const POSE_HZ := 20.0
const VOICE_RATE := 11025          ## голос рации: 11 кГц моно, 16 бит — ~22 КБ/с, с запасом для любого интернета
const MAX_CLIP_S := 8.0
const MIMIC_SILENCE := 45.0        ## сколько напарник должен молчать, чтобы «его» голос прозвучал сам
const MIMIC_COOLDOWN := 150.0
const SQUELCH := "res://assets/sfx/radio_squelch.ogg"
const SQUELCH_2 := "res://assets/sfx/radio_squelch_v2.ogg"
const STATIC := "res://assets/audio/static_loop.ogg"
const SAVE_PATH := "user://coop.json"
const LAST_NIGHT := 7
## Сервер комнат (noray). Пусто — кнопки «по коду» нет, только по адресу. Можно переопределить
## в user://net.cfg: [rooms] host="kedr.example.ru" port=8890 (см. docs/СЕРВЕР_КОМНАТ.md).
const ROOM_SERVER := ""
const ROOM_PORT := 8890
const RECONNECT_TRIES := 8
const RECONNECT_EVERY := 6.0
## Готовые фразы рации (для тех, кто без микрофона; [X], потом цифра).
## Фразы с геймпада: D-pad ↑ → ↓ ←, потом X и Y.
const PAD_BUTTONS: Array[JoyButton] = [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_X, JOY_BUTTON_Y]
const PHRASE_PAD: Array[String] = ["↑", "→", "↓", "←", "X", "Y"]
const PHRASES: Array[StringName] = [&"coop.ph.copy", &"coop.ph.home", &"coop.ph.password", &"coop.ph.help", &"coop.ph.readings", &"coop.ph.wait"]
## Сводка: насколько цифры могут расходиться с приборами, чтобы Большая Земля приняла.
const TOL := {&"temp": 1, &"wind": 1, &"snow": 2}

var role := ""                     ## "" | "host" | "client"
var coop_night := 1
var coop_seed := 0
var ghost := false                 ## мы погибли, но остались в эфире
var room_host := ""
var room_port := ROOM_PORT
var partner_id := 0
var in_session := false
var talking := false               ## мы держим [V] (и микрофон включён)
var external_ip := ""
var local_ip := ""
var test_mode := false             ## --coop-test: синтетический голос и диагностика в лог

var _upnp: UPNP
var _upnp_thread: Thread
var _pose_t := 0.0
var _slow_t := 0.0
var _partner: Node3D
var _partner_pos := Vector3.ZERO
var _partner_yaw := 0.0
var _partner_seen := false
var _partner_dead := false
var _poses_rx := 0
var _tasks_sent: Array[StringName] = []

# Голос
var _voice_player: AudioStreamPlayer
var _voice_pb: AudioStreamGeneratorPlayback
var _rx_clip := PackedFloat32Array()
var _clips: Array[PackedFloat32Array] = []   ## последние передачи напарника — материал для подделки
var _partner_silent := 0.0
var _mimic_cd := 60.0
var _mimicking := false
var _decim_acc := 0.0
var _decim_sum := 0.0
var _decim_n := 0
var _tx_buf := PackedFloat32Array()

# Комнаты и переподключение
var _noray: NorayClient
var _hs: PacketHandshake
var _join_mode := ""               ## "ip" | "room" — как подключались (для переподключения)
var _join_target := ""
var _reconnect_left := 0
var _reconnect_t := 0.0
var _reconnecting := false

# Призрак и фразы
var _ghost_cam: Camera3D
var _ghost_window := 0.0           ## > 0 — эфир «пробит», можно говорить
var _ghost_next := 20.0
var _phrase_menu := 0.0
var _test_mark := 0.0
var _phrases_heard: Array[int] = []   ## какие фразы напарник уже говорил — их Ырка и повторит
var report_open := false           ## хост держит открытым бланк сводки (CoopReportUI)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(func() -> void:
		if not _reconnecting:
			status.emit(Loc.t(&"coop.connected")))
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_peer_disconnected.bind(1))
	Mic.frames_captured.connect(_on_mic_frames)
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or (a.begins_with("172.") and not a.begins_with("172.17.")):
			local_ip = a
			break
	_noray = NorayClient.new()
	_noray.name = "Noray"
	add_child(_noray)
	_hs = PacketHandshake.new()
	_hs.name = "Handshake"
	add_child(_hs)
	_noray.on_connect_nat.connect(_on_room_connect.bind(false))
	_noray.on_connect_relay.connect(_on_room_connect.bind(true))
	room_host = ROOM_SERVER
	var cf := ConfigFile.new()
	if cf.load("user://net.cfg") == OK:
		room_host = String(cf.get_value("rooms", "host", room_host))
		room_port = int(cf.get_value("rooms", "port", room_port))


func active() -> bool:
	return role != "" and partner_id != 0 and multiplayer.multiplayer_peer != null


func rooms_available() -> bool:
	return room_host.strip_edges() != ""


# --- Кампания ------------------------------------------------------------------

## Ночь, с которой продолжить кооп-кампанию (у хоста).
func saved_night() -> int:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return 1
	var d: Variant = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		return clampi(int((d as Dictionary).get("night", 1)), 1, LAST_NIGHT)
	return 1


func _save_night(n: int) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"night": clampi(n, 1, LAST_NIGHT)}))


## Хост начинает ночь у обоих (новое зерно — новые испуги, та же ночь сюжета).
func start_night(n: int) -> void:
	if role != "host" or not active():
		return
	coop_night = clampi(n, 1, LAST_NIGHT)
	_save_night(coop_night)
	_start.rpc(coop_night, randi() % 2000000000 + 1)


## Сессия у нас кончилась (Main). "advance" — рассвет, "retry" — ночь потеряна (оба погибли).
## Возвращает true, если кооп продолжается и Main не должен уходить в меню.
func on_local_finished(result: String) -> bool:
	if not active():
		return false
	match result:
		"advance":
			if role == "host":
				var next := coop_night + 1
				if next > LAST_NIGHT:
					_save_night(1)
					return false
				_save_night(next)
				get_tree().create_timer(1.5).timeout.connect(start_night.bind(next))
			return true
		"retry":
			if role == "host":
				get_tree().create_timer(1.0).timeout.connect(start_night.bind(coop_night))
			else:
				_request_restart.rpc_id(1)
			return true
		"demo_end":
			if role == "host":
				_save_night(1)   # кампания пройдена — в следующий раз с первой ночи
	return false


@rpc("any_peer", "call_remote", "reliable")
func _request_restart() -> void:
	if role == "host":
		start_night(coop_night)


## Ночь 7: кто-то из двоих выбрал концовку — она играет у обоих.
func share_ending(id: StringName) -> void:
	if active() and in_session:
		_ending.rpc(id)


@rpc("any_peer", "call_remote", "reliable")
func _ending(id: StringName) -> void:
	remote_ending.emit(id)


# --- Лобби --------------------------------------------------------------------

func host(night := 1) -> void:
	leave()
	coop_night = clampi(night, 1, LAST_NIGHT)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, 1)
	if err != OK:
		status.emit(Loc.t(&"coop.port_busy", [PORT]))
		return
	multiplayer.multiplayer_peer = peer
	role = "host"
	status.emit(Loc.t(&"coop.waiting_local", [local_ip if local_ip != "" else "127.0.0.1", PORT]))
	# UPnP блокирует на пару секунд — в отдельном потоке, чтобы меню не замирало.
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_open)


func _upnp_open() -> void:
	var u := UPNP.new()
	var res := u.discover(2000, 2, "InternetGatewayDevice")
	var ok := false
	var ext := ""
	if res == UPNP.UPNP_RESULT_SUCCESS and u.get_gateway() != null and u.get_gateway().is_valid_gateway():
		var m := u.add_port_mapping(PORT, PORT, "Kedr-7", "UDP", 0)
		ok = m == UPNP.UPNP_RESULT_SUCCESS
		ext = u.query_external_address()
	_upnp = u if ok else null
	call_deferred(&"_upnp_done", ok, ext)


func _upnp_done(ok: bool, ext: String) -> void:
	if _upnp_thread != null:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
	if role != "host" or partner_id != 0:
		return
	external_ip = ext
	if ok and ext != "":
		status.emit(Loc.t(&"coop.waiting_ext", [ext, PORT, local_ip]))
	else:
		status.emit(Loc.t(&"coop.no_upnp", [local_ip if local_ip != "" else "?", PORT]))


func join(address: String) -> void:
	leave()
	_join_mode = "ip"
	_join_target = address.strip_edges()
	_join_ip(_join_target)


func _join_ip(address: String) -> void:
	var addr := address
	var port := PORT
	if addr.contains(":"):
		port = int(addr.get_slice(":", 1))
		addr = addr.get_slice(":", 0)
	if addr == "":
		status.emit(Loc.t(&"coop.no_address"))
		return
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(addr, port)
	if err != OK:
		status.emit(Loc.t(&"coop.failed"))
		return
	multiplayer.multiplayer_peer = peer
	role = "client"
	if not _reconnecting:
		status.emit(Loc.t(&"coop.connecting", [addr, port]))


# --- Комнаты (noray) ------------------------------------------------------------

## Хост через сервер комнат: регистрируемся, получаем код, слушаем на зарегистрированном порту.
func host_room(night := 1) -> void:
	leave()
	coop_night = clampi(night, 1, LAST_NIGHT)
	role = "host"
	status.emit(Loc.t(&"coop.room_connecting"))
	if not await _room_register():
		_reset()
		return
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(_noray.local_port, 1)
	if err != OK:
		status.emit(Loc.t(&"coop.room_failed"))
		_reset()
		return
	multiplayer.multiplayer_peer = peer
	var code := _noray.oid
	room_code.emit(code)
	status.emit(Loc.t(&"coop.room_waiting", [code]))


## Клиент по коду: регистрируемся сами (нужен свой внешний порт), просим соединение через NAT,
## не вышло — через ретранслятор.
func join_room(code: String) -> void:
	leave()
	var c := code.strip_edges().to_upper().replace("КЕДР-", "").replace("KEDR-", "").replace(" ", "")
	if c == "":
		status.emit(Loc.t(&"coop.no_code"))
		return
	_join_mode = "room"
	_join_target = c
	await _join_room_code(c)


func _join_room_code(c: String) -> void:
	role = "client"
	if not _reconnecting:
		status.emit(Loc.t(&"coop.room_connecting"))
	if not await _room_register():
		if not _reconnecting:
			_reset()
		return
	if OS.get_cmdline_user_args().has("--coop-relay"):
		_noray.connect_relay(c)   # проверка ретранслятора: сразу через него, без пробивки NAT
	else:
		_noray.connect_nat(c)


func _room_register() -> bool:
	if not rooms_available():
		status.emit(Loc.t(&"coop.room_failed"))
		return false
	var err: Error = await _noray.connect_to_host(room_host, room_port)
	if err != OK:
		status.emit(Loc.t(&"coop.room_failed"))
		return false
	_noray.register_host()
	await _noray.on_pid
	err = await _noray.register_remote()
	if err != OK:
		status.emit(Loc.t(&"coop.room_failed"))
		return false
	return true


func _on_room_connect(address: String, port: int, relay: bool) -> void:
	if role == "host":
		var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
		if peer != null:
			await _hs.over_enet_peer(peer, address, port)
		return
	if role != "client":
		return
	var udp := PacketPeerUDP.new()
	udp.bind(_noray.local_port)
	udp.set_dest_address(address, port)
	var err: Error = await _hs.over_packet_peer(udp)
	udp.close()
	if err != OK and err != ERR_BUSY:
		if not relay:
			_noray.connect_relay(_join_target)   # через NAT не пробились — через ретранслятор
		elif not _reconnecting:
			status.emit(Loc.t(&"coop.room_failed"))
		return
	var peer := ENetMultiplayerPeer.new()
	err = peer.create_client(address, port, 0, 0, 0, _noray.local_port)
	if err != OK:
		if not relay:
			_noray.connect_relay(_join_target)
		return
	multiplayer.multiplayer_peer = peer
	var t := 0.0
	while peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING and t < 8.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		multiplayer.multiplayer_peer = null
		if not relay:
			_noray.connect_relay(_join_target)
		elif not _reconnecting:
			status.emit(Loc.t(&"coop.room_failed"))


func leave() -> void:
	_reconnecting = false
	_reconnect_left = 0
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	if _upnp != null:
		_upnp.delete_port_mapping(PORT, "UDP")
		_upnp = null
	if _noray != null:
		_noray.disconnect_from_host()
	_reset()


func _reset() -> void:
	role = ""
	partner_id = 0
	in_session = false
	talking = false
	_partner_dead = false
	_partner_seen = false
	_clips.clear()
	_tasks_sent.clear()
	_phrases_heard.clear()
	report_open = false
	_end_ghost()
	if _partner != null and is_instance_valid(_partner):
		_partner.queue_free()
	_partner = null


func _on_connection_failed() -> void:
	if _reconnecting:
		return   # следующая попытка — по таймеру
	status.emit(Loc.t(&"coop.failed"))
	_reset()


func _on_peer_connected(id: int) -> void:
	if partner_id != 0:
		return
	partner_id = id
	if _reconnecting:
		_reconnecting = false
		_reconnect_left = 0
		if Game.hud != null:
			Game.hud.subtitle(Loc.t(&"coop.back"), 4.0)
	if role == "host":
		if in_session:
			# Напарник вернулся посреди ночи: пусть продолжит ту же (или подхватит текущую).
			_resume.rpc_id(id, coop_night, coop_seed, Game.shift_minutes)
			if Game.hud != null:
				Game.hud.subtitle(Loc.t(&"coop.back"), 4.0)
			if Game.yrka != null and not _partner_dead:
				Game.yrka.set_process(false)
		else:
			status.emit(Loc.t(&"coop.partner_here"))
			start_night(coop_night)


func _on_peer_disconnected(_id: int) -> void:
	var was := partner_id != 0
	partner_id = 0
	if _partner != null and is_instance_valid(_partner):
		_partner.queue_free()
	_partner = null
	if not was:
		return
	partner_left.emit()
	if in_session:
		if Game.hud != null:
			Game.hud.subtitle(Loc.t(&"coop.lost_retry"), 5.0, 2)
		if role == "client":
			_reconnecting = true
			_reconnect_left = RECONNECT_TRIES
			_reconnect_t = 2.0
		elif role == "host" and Game.yrka != null and Game.is_night():
			Game.yrka.set_process(true)   # пока напарника нет, Ырка — наша
	else:
		status.emit(Loc.t(&"coop.lost"))


func _tick_reconnect(delta: float) -> void:
	if not _reconnecting:
		return
	_reconnect_t -= delta
	if _reconnect_t > 0.0:
		return
	if _reconnect_left <= 0:
		_reconnecting = false
		if Game.hud != null:
			Game.hud.subtitle(Loc.t(&"coop.lost"), 6.0, 2)
		return
	_reconnect_left -= 1
	_reconnect_t = RECONNECT_EVERY
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	if _join_mode == "room":
		_join_room_code(_join_target)
	else:
		_join_ip(_join_target)


@rpc("authority", "call_local", "reliable")
func _start(night: int, seed: int) -> void:
	if test_mode:
		print("[coop] старт ночи %d, seed %d (%s)" % [night, seed, role])
	in_session = true
	coop_night = night
	coop_seed = seed
	_end_ghost()
	_partner_dead = false
	session_start.emit(night, seed)


## Переподключились посреди ночи: та же ночь — играем дальше, иначе подхватываем ту, что идёт у хоста.
@rpc("authority", "call_remote", "reliable")
func _resume(night: int, seed: int, minutes: float) -> void:
	if in_session and night == coop_night and seed == coop_seed:
		Game.shift_minutes = maxf(Game.shift_minutes, minutes)
		return
	_start(night, seed)


## Сессия собрана (зовёт Session после появления игрока): клиент — снаружи, у крыльца.
func on_session_ready() -> void:
	if role == "":
		return
	_mimic_cd = 60.0
	_partner_silent = 0.0
	if role == "client" and Game.player != null:
		Game.player.global_position = Yard.DOOR_OUT + Vector3(0.6, 0.1, 1.2)
		Game.player.rotation.y = deg_to_rad(-90.0)
	_ensure_voice_player()


func on_session_begun() -> void:
	if role == "":
		return
	if role == "host" and Game.yrka != null and active():
		# Ырка у хоста — зеркало чужой: её считает клиент (он снаружи), сюда приходят только координаты.
		Game.yrka.set_process(false)
	if Game.hud != null:
		Game.hud.subtitle(Loc.t(&"coop.role_host", [coop_night]) if role == "host" else Loc.t(&"coop.role_client", [coop_night]), 9.0)
		Hints.show(&"coop")


# --- Каждый кадр ----------------------------------------------------------------

func _process(delta: float) -> void:
	_tick_reconnect(delta)
	if _phrase_menu > 0.0:
		_phrase_menu -= delta
	if ghost:
		_update_ghost(delta)
	if not active() or not in_session or Game.player == null or not is_instance_valid(Game.player):
		talking = false
		return
	_pose_t -= delta
	if _pose_t <= 0.0:
		_pose_t = 1.0 / POSE_HZ
		var p := Game.player
		_pose.rpc(p.global_position, p.rotation.y, p.flashlight_on(), Game.dead)
	_slow_t -= delta
	if _slow_t <= 0.0:
		_slow_t = 0.5
		_slow_sync()
	_update_partner(delta)
	_update_talk()
	_update_mimic(delta)
	if test_mode:
		_test_tick(delta)


var _test_t := 0.0
var _test_stage := 0


## --coop-test: голос и фраза клиента, сверка сводки и отражённые испуги у хоста, подделка голоса,
## гибель клиента (эфир), гибель хоста (ночь потеряна → заново), итог и выход.
func _test_tick(delta: float) -> void:
	_test_t += delta
	var args := OS.get_cmdline_user_args()
	if args.has("--coop-dawn"):   # рассвет → оба переходят к следующей ночи
		if role == "host" and _test_stage == 0 and _test_t > 8.0 and coop_night == 1:
			_test_stage = 1
			Game.shift_minutes = Game.NIGHT_END_MIN - 0.3
		if _test_t > 40.0 and _test_stage < 9:
			_test_stage = 9
			print("[coop] ИТОГ рассвет %s: ночь %d, часы %s" % [role, coop_night, Game.clock_text()])
			get_tree().quit()
		return
	if args.has("--coop-anom"):   # аномалии, записи и кадры «Зенита» — общие на двоих
		if role == "host" and _test_stage == 0 and _test_t > 10.0 and Game.anomalies != null:
			_test_stage = 1
			Game.anomalies.apply(&"boots")
			Game.anomalies.apply(&"flag")
			Game.give_item(&"zenit")
			Game.zenit.snap()
			print("[coop] тест: хост поставил boots и flag, снял кадр")
		if role == "client" and _test_stage == 0 and _test_t > 16.0 and Game.anomalies != null and (not Game.zenit.partner_photos.is_empty() or _test_t > 80.0):
			_test_stage = 1
			_test_mark = _test_t
			var pimg: Image = Game.zenit.partner_photos[0]["img"] if not Game.zenit.partner_photos.is_empty() else null
			print("[coop] тест: у клиента аномалии %s, кадров напарника %d, картинка %s" % [Game.anomalies.active.keys(), Game.zenit.partner_photos.size(),
				str(pimg.get_size()) if pimg != null else "нет"])
			Game.anomalies.note(&"boots")
			# Фраза с геймпада: Back, потом D-pad →
			Game.is_gamepad = true
			for b: JoyButton in [JOY_BUTTON_BACK, JOY_BUTTON_DPAD_RIGHT]:
				var ev := InputEventJoypadButton.new()
				ev.button_index = b
				ev.pressed = true
				_input(ev)
		if role == "host" and _test_stage == 1 and _test_t > 20.0 and (not Game.anomalies.notes.is_empty() or _test_t > 90.0):
			_test_stage = 2
			print("[coop] тест: у хоста boots записаны напарником=%s, записей %d, фразы с геймпада %s" % [Game.anomalies.active[&"boots"]["noted"], Game.anomalies.notes.size(), _phrases_heard])
		var done := _test_stage >= 2 if role == "host" else (_test_stage >= 1 and _test_t > _test_mark + 10.0)
		if (_test_t > 26.0 and done or _test_t > 110.0) and _test_stage < 9:
			_test_stage = 9
			print("[coop] ИТОГ аномалии %s: ночь %d, активных %d" % [role, coop_night, Game.anomalies.active.size() if Game.anomalies != null else -1])
			get_tree().quit()
		return
	if args.has("--coop-drop"):   # обрыв связи у клиента → переподключение посреди ночи
		if role == "client" and _test_stage == 0 and _test_t > 8.0:
			_test_stage = 1
			print("[coop] тест: рвём связь")
			multiplayer.multiplayer_peer.close()
			_on_peer_disconnected(1)
		if _test_t > 40.0 and _test_stage < 9:
			_test_stage = 9
			print("[coop] ИТОГ обрыв %s: ночь %d seed %d, на связи %s, часы %s" % [role, coop_night, coop_seed, active(), Game.clock_text()])
			get_tree().quit()
		return
	if role == "client" and _test_stage == 0 and _test_t > 10.0:
		_test_stage = 1
		_ptt.rpc(true)
		var rate := AudioServer.get_mix_rate()
		for c in range(20):
			var buf := PackedVector2Array()
			for j in range(int(rate * 0.1)):
				var t := (c * rate * 0.1 + j) / rate
				var v := sin(TAU * 440.0 * t) * 0.3
				buf.append(Vector2(v, v))
			send_voice_samples(buf, rate)
		_ptt.rpc(false)
		send_phrase(1)
		print("[coop] тест: передан синус 2 с и фраза 1")
	if role == "host" and _test_stage == 0 and _test_t > 14.0:
		_test_stage = 1
		var sy := Game.synoptic
		print("[coop] тест: фраз от напарника %d, сводка верно=%s, неверно=%s, 36=%s" % [_phrases_heard.size(),
			check_report(int(roundf(sy.temp_dry)), int(roundf(sy.wind_speed)), int(sy.snow_depth_cm)),
			check_report(int(roundf(sy.temp_dry)) + 7, 3, 10), check_report(36, 5, 90)])
		echo_sound("res://assets/audio/knock.ogg", Game.player.global_position, 2.0)
		echo_figure(&"zherdyai", Game.player.global_position + Vector3(2, 0, 0), 0.0, 5.0)
		echo_lights(2.0)
	if role == "host" and _test_stage == 1 and _test_t > 18.0:
		_test_stage = 2
		print("[coop] тест: клипов напарника %d" % _clips.size())
		mimic()
	if role == "client" and _test_stage == 1 and _test_t > 22.0:
		_test_stage = 2
		print("[coop] тест: клиент погибает")
		Game.die(&"cold")
	if role == "client" and _test_stage == 2 and _test_t > 25.0:
		_test_stage = 3
		print("[coop] тест: клиент в эфире=%s, часы идут=%s %s, камера=%s" % [ghost, Game.clock_running, Game.clock_text(),
			str(_ghost_cam != null and is_instance_valid(_ghost_cam) and _ghost_cam.current)])
		_ghost_window = 5.0
		send_phrase(3)
	if role == "host" and _test_stage == 2 and _test_t > 27.0:
		_test_stage = 3
		print("[coop] тест: хост видит гибель=%s, Ырка у хоста ожила=%s, фраз %d" % [_partner_dead,
			str(Game.yrka != null and Game.yrka.is_processing()), _phrases_heard.size()])
		Game.die(&"cold")
	if _test_t > 62.0 and _test_stage < 9:
		_test_stage = 9
		print("[coop] ИТОГ %s: ночь %d seed %d, поз получено %d, напарник в мире %s, клипов %d, часы %s, мёртв=%s, эфир=%s" % [role,
			coop_night, coop_seed, _poses_rx, str(_partner != null and is_instance_valid(_partner)), _clips.size(), Game.clock_text(),
			Game.dead, ghost])
		get_tree().quit()


func _slow_sync() -> void:
	if role == "host":
		_clock.rpc(Game.shift_minutes, Game.weather != null and Game.weather.blizzard)
		if Game.level != null and Game.level.has_method(&"get_coop_fx"):
			var fx: Dictionary = Game.level.call(&"get_coop_fx")
			_station_fx.rpc(float(fx.get("sag", 0.0)), bool(fx.get("frozen_tea", false)), float(fx.get("hand", 0.0)))
	elif Game.yrka != null and Game.yrka.enabled:
		_yrka_state.rpc(Game.yrka.virtual_pos, Game.yrka.threat, int(Game.yrka.stage))
	if Game.tasks != null:
		for id: StringName in Game.tasks.done:
			if not _tasks_sent.has(id):
				_tasks_sent.append(id)
				_task_done.rpc(id)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _pose(pos: Vector3, yaw: float, light: bool, dead: bool) -> void:
	_poses_rx += 1
	_partner_pos = pos
	_partner_yaw = yaw
	if dead and not _partner_dead:
		_partner_dead = true
		_mimic_cd = minf(_mimic_cd, 40.0)
		if Game.hud != null and not Game.dead:
			Game.hud.subtitle(Loc.t(&"coop.partner_dead"), 6.0, 2)
		if role == "host" and Game.yrka != null and not Game.dead:
			Game.yrka.set_process(true)   # напарник снаружи погиб — теперь Ырка ходит за нами
		if _partner != null and is_instance_valid(_partner):
			_partner.queue_free()
		_partner = null
		return
	if _partner_dead or Game.level == null:
		return
	if _partner == null or not is_instance_valid(_partner):
		_partner = _make_partner()
		Game.level.add_child(_partner)
		_partner.global_position = pos
	var lamp := _partner.get_node_or_null("Lamp") as SpotLight3D
	if lamp != null:
		lamp.visible = light


func _make_partner() -> Node3D:
	var rig := Creatures.make_human(&"driver")   # напарник в тулупе: в темноте его легко спутать с Обмирало
	rig.name = "Partner"
	var lamp := SpotLight3D.new()
	lamp.name = "Lamp"
	lamp.position = Vector3(0.2, 1.4, -0.3)
	lamp.light_energy = 2.2
	lamp.spot_range = 18.0
	lamp.spot_angle = 22.0
	lamp.light_color = Color(1.0, 0.92, 0.75)
	lamp.shadow_enabled = false
	rig.add_child(lamp)
	return rig


func _update_partner(delta: float) -> void:
	if _partner == null or not is_instance_valid(_partner):
		return
	var rig := _partner as CreatureRig
	var before := _partner.global_position
	_partner.global_position = before.lerp(_partner_pos, minf(delta * 12.0, 1.0))
	_partner.rotation.y = lerp_angle(_partner.rotation.y, _partner_yaw, minf(delta * 12.0, 1.0))
	var speed := Vector2(_partner.global_position.x - before.x, _partner.global_position.z - before.z).length() / maxf(delta, 0.001)
	if rig != null:
		rig.gait = clampf(speed / 3.5, 0.0, 1.0)


@rpc("authority", "call_remote", "unreliable_ordered")
func _clock(minutes: float, blizzard: bool) -> void:
	if not in_session:
		return
	if absf(Game.shift_minutes - minutes) > 0.5:
		Game.shift_minutes = minutes
	if Game.weather != null and Game.weather.blizzard != blizzard:
		Game.weather.force_blizzard(blizzard, 30.0)


@rpc("authority", "call_remote", "unreliable_ordered")
func _station_fx(sag: float, frozen_tea: bool, hand: float) -> void:
	if not in_session:
		return
	if Game.level != null and Game.level.has_method(&"apply_coop_fx"):
		Game.level.call(&"apply_coop_fx", sag, frozen_tea, hand)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _yrka_state(vpos: Vector2, threat: float, stage: int) -> void:
	if role != "host" or Game.yrka == null:
		return
	Game.yrka.enabled = true
	Game.yrka.virtual_pos = vpos
	Game.yrka.threat = threat
	Game.yrka.stage = stage as YrkaThreat.Stage


@rpc("any_peer", "call_remote", "reliable")
func _task_done(id: StringName) -> void:
	if not _tasks_sent.has(id):
		_tasks_sent.append(id)
	if Game.tasks != null and Game.tasks.is_active(id):
		Game.tasks.complete(id)


# --- Рация ----------------------------------------------------------------------

func _ensure_voice_player() -> void:
	if _voice_player != null and is_instance_valid(_voice_player):
		return
	_voice_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = VOICE_RATE
	gen.buffer_length = 0.6
	_voice_player.stream = gen
	_voice_player.bus = &"Radio" if AudioServer.get_bus_index(&"Radio") >= 0 else &"Master"
	_voice_player.volume_db = 2.0
	add_child(_voice_player)
	_voice_player.play()
	_voice_pb = _voice_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _update_talk() -> void:
	var can := Game.hud != null and (Game.hud.modal() == null or Game.hud.modal() is CoopReportUI) and (not Game.dead or ghost)
	var want := Input.is_action_pressed(&"coop_talk") and can
	if want and ghost and _ghost_window <= 0.0:
		if Input.is_action_just_pressed(&"coop_talk"):
			Game.hud.subtitle(Loc.t(&"coop.ghost_closed"), 2.5)
			Game.audio.play_2d(STATIC, -14.0, 0.8)
		want = false
	if want and not Settings.mic_enabled and not test_mode:
		if Input.is_action_just_pressed(&"coop_talk"):
			Game.hud.subtitle(Loc.t(&"coop.mic_off"), 4.0)
		want = false
	if want != talking:
		talking = want
		_ptt.rpc(talking)
		Game.audio.play_2d(SQUELCH if talking else SQUELCH_2, -10.0)
		if talking:
			_decim_acc = 0.0
			_decim_sum = 0.0
			_decim_n = 0


## Кадры с микрофона (их читает Mic): пока зажата [V] — прореживаем до 11 кГц и шлём напарнику.
func _on_mic_frames(buf: PackedVector2Array) -> void:
	if not talking or not active():
		return
	send_voice_samples(buf, AudioServer.get_mix_rate())


func send_voice_samples(buf: PackedVector2Array, rate: float) -> void:
	var step := rate / float(VOICE_RATE)
	for v in buf:
		_decim_sum += (v.x + v.y) * 0.5
		_decim_n += 1
		_decim_acc += 1.0
		if _decim_acc >= step:
			_decim_acc -= step
			_tx_buf.append(_decim_sum / float(_decim_n))
			_decim_sum = 0.0
			_decim_n = 0
	# Кусками по 512 отсчётов (1 КБ): больше MTU пакет дробится, и в плохой сети теряется целиком.
	while _tx_buf.size() >= 512:
		var bytes := PackedByteArray()
		bytes.resize(512 * 2)
		for i in range(512):
			bytes.encode_s16(i * 2, int(clampf(_tx_buf[i] * 1.6, -1.0, 1.0) * 32767.0))
		_tx_buf = _tx_buf.slice(512)
		_voice.rpc(bytes)


@rpc("any_peer", "call_remote", "reliable")
func _ptt(on: bool) -> void:
	_partner_silent = 0.0
	if Game.audio != null:
		Game.audio.play_2d(SQUELCH if on else SQUELCH_2, -6.0)
	if on:
		_rx_clip = PackedFloat32Array()
	elif _rx_clip.size() > VOICE_RATE * 0.6:
		_clips.append(_rx_clip)
		if _clips.size() > 3:
			_clips.pop_front()
		if test_mode:
			print("[coop] запомнена передача напарника: %.1f с" % (_rx_clip.size() / float(VOICE_RATE)))


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _voice(bytes: PackedByteArray) -> void:
	_partner_silent = 0.0
	# Жёсткий полудуплекс: реле приёма-передачи отключает приёмник от антенны во время передачи (PTT)
	if talking:
		return

	# Геомагнитная тень / штольня / мачта: прямая связь рвётся в помехи
	if YrkaRadioInterceptor.is_partner_in_radio_shadow(_partner_pos):
		if _voice_pb != null:
			for i in range(min(bytes.size() / 4, 40)):
				if _voice_pb.can_push_buffer(1):
					var h := randf_range(-0.12, 0.12)
					_voice_pb.push_frame(Vector2(h, h))
		return

	_ensure_voice_player()
	var n := bytes.size() / 2
	# Погибший пробивается сквозь помехи: рваный, с белым шумом — так же Ырка подделывает его голос.
	var gate := not _partner_dead or randf() > 0.3
	for i in range(n):
		var s := bytes.decode_s16(i * 2) / 32767.0
		if _rx_clip.size() < VOICE_RATE * MAX_CLIP_S:
			_rx_clip.append(s)
		if _partner_dead:
			s = _ghostify(s, gate)
		if _voice_pb != null and _voice_pb.can_push_buffer(1):
			_voice_pb.push_frame(Vector2(s, s))
	if test_mode and randi() % 20 == 0:
		print("[coop] голос: %d отсчётов" % n)


# --- Подделка голоса --------------------------------------------------------------

func _update_mimic(delta: float) -> void:
	_partner_silent += delta
	_mimic_cd -= delta
	if _mimicking or _mimic_cd > 0.0 or Game.dead:
		return
	# Пока хост заполняет бланк сводки и ждёт цифр — самое время «продиктовать» что-нибудь не то.
	var waiting_numbers := report_open and _partner_silent > 12.0
	var silence := 20.0 if _partner_dead else MIMIC_SILENCE
	if _partner_silent < silence and not waiting_numbers:
		return
	var bad := Director.tension > 65.0 or waiting_numbers or _partner_dead
	if Game.yrka != null and Game.yrka.enabled and Game.yrka.stage in [YrkaThreat.Stage.CALLING, YrkaThreat.Stage.PRESSURE]:
		bad = true
	if not bad:
		return
	if not _clips.is_empty() and (randf() < 0.7 or _phrases_heard.is_empty()):
		mimic()
	else:
		mimic_phrase()


## «Напарник» выходит на связь — его голосом, его словами, только чуть ниже. Он ничего не нажимал.
func mimic() -> void:
	if _clips.is_empty() or _mimicking:
		return
	_mimicking = true
	_mimic_cd = MIMIC_COOLDOWN
	_ensure_voice_player()
	var clip: PackedFloat32Array = _clips[randi() % _clips.size()]
	print("[coop] mimic: %.1f с" % (clip.size() / float(VOICE_RATE)))
	Game.audio.play_2d(SQUELCH, -6.0)
	await get_tree().create_timer(0.25).timeout
	# Ниже на ~8%: растягиваем запись (каждый 12-й отсчёт повторяем) — голос тот же, но «не совсем».
	var i := 0
	var k := 0
	var stuck := 0
	while i < clip.size() and stuck < 120:   # без звукового вывода (headless) буфер не освобождается — не виснем
		var before_i := i
		var chunk := 0
		while chunk < 600 and i < clip.size():
			if _voice_pb != null and _voice_pb.can_push_buffer(1):
				var v := clip[i] * 0.9
				if _partner_dead:
					v = _ghostify(v, (k / 2400) % 4 != 1)
				_voice_pb.push_frame(Vector2(v, v))
				k += 1
				if k % 12 != 0:
					i += 1
				chunk += 1
			else:
				break
		stuck = stuck + 1 if i == before_i else 0
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	Game.audio.play_2d(SQUELCH_2, -6.0)
	Director.add_tension(10.0, "рация: напарник? (не нажимал)")
	_mimic_cd = MIMIC_COOLDOWN * (0.5 if _partner_dead else 1.0)
	_mimicking = false



func _ghostify(s: float, gate: bool) -> float:
	var noise := randf_range(-1.0, 1.0)
	return (s * 0.75 if gate else s * 0.08) + noise * 0.16


# --- Готовые фразы ([X], потом цифра) --------------------------------------------------

func _input(event: InputEvent) -> void:
	if role == "" or not in_session or Game.hud == null:
		return
	if event.is_action_pressed(&"coop_phrase"):
		if Game.hud.modal() != null:
			return
		_phrase_menu = 5.0
		var lines := PackedStringArray()
		for i in PHRASES.size():
			lines.append("%s — %s" % [PHRASE_PAD[i] if Game.is_gamepad else str(i + 1), Loc.t(PHRASES[i])])
		Game.hud.subtitle(Loc.t(&"coop.ph.menu") + "\n" + "   ".join(lines), 5.0, 2)
		get_viewport().set_input_as_handled()
		return
	if _phrase_menu > 0.0 and event is InputEventKey and event.is_pressed() and not event.is_echo():
		var k := int((event as InputEventKey).physical_keycode) - KEY_1
		if k >= 0 and k < PHRASES.size():
			_phrase_menu = 0.0
			send_phrase(k)
			get_viewport().set_input_as_handled()
	# Геймпад: пока меню открыто, D-pad и X/Y выбирают фразу (карта/блокнот в это время не открываются).
	if _phrase_menu > 0.0 and event is InputEventJoypadButton and event.is_pressed():
		var k := PAD_BUTTONS.find((event as InputEventJoypadButton).button_index)
		if k >= 0 and k < PHRASES.size():
			_phrase_menu = 0.0
			send_phrase(k)
			get_viewport().set_input_as_handled()


func send_phrase(idx: int) -> void:
	if not active():
		return
	if Game.dead and not ghost:
		return
	if ghost and _ghost_window <= 0.0:
		Game.hud.subtitle(Loc.t(&"coop.ghost_closed"), 2.5)
		Game.audio.play_2d(STATIC, -14.0, 0.8)
		return
	Game.audio.play_2d(SQUELCH, -10.0)
	Game.hud.subtitle(Loc.t(&"coop.ph.you", [Loc.t(PHRASES[idx])]), 3.0)
	_phrase.rpc(idx)


@rpc("any_peer", "call_remote", "reliable")
func _phrase(idx: int) -> void:
	if idx < 0 or idx >= PHRASES.size():
		return
	_partner_silent = 0.0
	if not _phrases_heard.has(idx):
		_phrases_heard.append(idx)
	_say_phrase(idx)


func _say_phrase(idx: int) -> void:
	if Game.audio == null or Game.hud == null:
		return
	Game.audio.play_2d(SQUELCH, -6.0)
	if _partner_dead:
		Game.audio.play_2d(STATIC, -10.0, 1.6)
	var key := &"coop.ph.heard_static" if _partner_dead else &"coop.ph.heard"
	Game.hud.subtitle(Loc.t(key, [Loc.t(PHRASES[idx])]), 4.0, 2, Color(0.75, 0.9, 1.0))
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if Game.audio != null:
			Game.audio.play_2d(SQUELCH_2, -6.0))


## Ырка «говорит» фразой напарника — той, что он уже говорил, а лучше «иду к дому».
func mimic_phrase() -> void:
	if _mimicking:
		return
	_mimic_cd = MIMIC_COOLDOWN * (0.5 if _partner_dead else 1.0)
	var pool: Array[int] = []
	pool.append_array(_phrases_heard)
	pool.append(1)   # «Иду к дому» — самая страшная, когда никто не идёт
	_say_phrase(pool[randi() % pool.size()])
	Director.add_tension(10.0, "рация: фраза напарника (не нажимал)")


# --- Общие испуги: отражение у напарника ------------------------------------------

## «Зенит-Е»: кадр уходит напарнику — утром проявляют обе плёнки.
func share_photo(shot: Dictionary) -> void:
	if not (active() and in_session):
		return
	var img: Image = shot.get("img")
	var bytes := img.save_jpg_to_buffer(0.6) if img != null and not img.is_empty() else PackedByteArray()
	var tags := PackedStringArray()
	for t in shot["tags"]:
		tags.append(String(t))
	_photo.rpc(bytes, int(shot["min"]), tags, bool(shot["ghost"]), bool(shot["voice"]))


@rpc("any_peer", "call_remote", "reliable")
func _photo(bytes: PackedByteArray, minute: int, tags: PackedStringArray, ghost: bool, voice: bool) -> void:
	if Game.zenit == null:
		return
	var img: Image = null
	if not bytes.is_empty():
		img = Image.new()
		if img.load_jpg_from_buffer(bytes) != OK:
			img = null
	var t: Array[StringName] = []
	for s in tags:
		t.append(StringName(s))
		if Game.anomalies != null:
			Game.anomalies.photographed(StringName(s))
	Game.zenit.partner_photos.append({"img": img, "min": minute, "tags": t, "ghost": ghost, "voice": voice, "flash": false})
	if test_mode:
		print("[coop] кадр напарника: %d байт, метки %s" % [bytes.size(), tags])


## Аномалия станции — у напарника та же (снаружи видно двор, изнутри — дом).
func echo_anomaly(id: StringName) -> void:
	if active() and in_session:
		_anomaly.rpc(id)


@rpc("any_peer", "call_remote", "reliable")
func _anomaly(id: StringName) -> void:
	if in_session and Game.anomalies != null:
		Game.anomalies.apply(id, true)


## Запись в журнал — общая: один пишет, у обоих вещь возвращается на место.
func echo_anom_note(id: StringName) -> void:
	if active() and in_session:
		_anom_note.rpc(id)


@rpc("any_peer", "call_remote", "reliable")
func _anom_note(id: StringName) -> void:
	if in_session and Game.anomalies != null:
		Game.anomalies.note(id, true)


func _shared() -> bool:
	return active() and in_session and not _partner_dead


## Звук испуга слышен и напарнику — из той же точки мира (далеко — значит не слышно).
func echo_sound(path: String, pos: Vector3, db := 0.0, unit := 2.0) -> void:
	if _shared():
		_echo_sound.rpc(path, pos, db, unit)


@rpc("any_peer", "call_remote", "reliable")
func _echo_sound(path: String, pos: Vector3, db: float, unit: float) -> void:
	if not in_session or Game.audio == null or Game.dead:
		return
	Game.audio.play_3d(path, pos, db, unit)
	if Game.player != null and Game.player.global_position.distance_to(pos) < 14.0:
		Director.add_tension(5.0, "напарник что-то слышит — и мы тоже")


## Существо из испуга видно и напарнику — столько же, сколько у пугаемого (или dur с).
func echo_figure(kind: StringName, pos: Vector3, yaw: float, dur: float, rim := false) -> void:
	if _shared():
		_echo_figure.rpc(kind, pos, yaw, dur, rim)


@rpc("any_peer", "call_remote", "reliable")
func _echo_figure(kind: StringName, pos: Vector3, yaw: float, dur: float, rim: bool) -> void:
	if not in_session or Game.level == null or Game.dead:
		return
	var fig: Node3D
	match kind:
		&"zherdyai":
			fig = Creatures.make_zherdyai(0.0)
		&"zherdyai_bent":
			fig = Creatures.make_zherdyai(83.0)
		&"silhouette":
			fig = Creatures.make_silhouette()
		_:
			return
	Game.level.add_child(fig)
	fig.global_position = pos
	fig.rotation.y = yaw
	if rim:
		var l := OmniLight3D.new()
		l.omni_range = 2.6
		l.light_energy = 1.8
		l.light_color = Color(0.6, 0.7, 0.9)
		l.shadow_enabled = false
		fig.add_child(l)
		l.position = Vector3(0, 2.0, 0.6)
	get_tree().create_timer(dur, false).timeout.connect(func() -> void:
		if is_instance_valid(fig):
			fig.queue_free())


## Свет в доме мигает и гаснет у обоих (его видно и с улицы — окна тёмные).
func echo_lights(dur: float) -> void:
	if _shared():
		_echo_lights.rpc(dur)


@rpc("any_peer", "call_remote", "reliable")
func _echo_lights(dur: float) -> void:
	if not in_session or Game.level == null or not Game.level.lights_lit():
		return
	await Game.level.flicker(1.0)
	Game.level.set_lit(false)
	await get_tree().create_timer(dur, false).timeout
	if Game.level != null and is_instance_valid(Game.level) and Game.power_on:
		Game.level.set_lit(true)


## В эфир прорвался чужой визг — напарник слышит его в своей рации.
func echo_radio(path: String, db := -8.0) -> void:
	if _shared():
		_echo_radio.rpc(path, db)


@rpc("any_peer", "call_remote", "reliable")
func _echo_radio(path: String, db: float) -> void:
	if not in_session or Game.audio == null or Game.dead:
		return
	Game.audio.play_2d(SQUELCH, -6.0)
	var p := Game.audio.play_2d(path, db, 2.5)
	if p != null and AudioServer.get_bus_index(&"Radio") >= 0:
		p.bus = &"Radio"
	Game.hud.subtitle(Loc.t(&"coop.radio_scream"), 4.0, 2)
	Director.add_tension(8.0, "визг в рации напарника")


# --- Смерть в коопе: остаёмся в эфире -----------------------------------------------

## Можно ли после смерти остаться в эфире (напарник жив и на связи).
func can_ghost() -> bool:
	return active() and in_session and not _partner_dead


func partner_dead() -> bool:
	return _partner_dead


## Последняя передача напарника (для «голоса из леса»), пустая — если ещё не говорил.
func partner_clip() -> PackedFloat32Array:
	if _clips.is_empty():
		return PackedFloat32Array()
	return _clips[randi() % _clips.size()]


## Напарник под крышей: тогда его голос из леса — точно не он.
func partner_indoors() -> bool:
	if _partner == null or not is_instance_valid(_partner) or Game.level == null:
		return false
	return Game.level.is_pos_inside_house(_partner.global_position)


func enter_ghost() -> void:
	ghost = true
	Game.coop_ghost = true
	Game.clock_running = true   # у хоста время ночи идёт дальше — до рассвета или до гибели напарника
	_ghost_window = 0.0
	_ghost_next = 10.0
	talking = false
	if Game.level != null:
		_ghost_cam = Camera3D.new()
		_ghost_cam.name = "GhostCam"
		_ghost_cam.fov = 70.0
		_ghost_cam.near = 0.05
		Game.level.add_child(_ghost_cam)
		if Game.player != null and Game.player.camera != null:
			_ghost_cam.global_transform = Game.player.camera.global_transform
		_ghost_cam.make_current()


func _end_ghost() -> void:
	ghost = false
	if Game != null:
		Game.coop_ghost = false
	if _ghost_cam != null and is_instance_valid(_ghost_cam):
		_ghost_cam.queue_free()
	_ghost_cam = null


func _update_ghost(delta: float) -> void:
	if _ghost_window > 0.0:
		_ghost_window -= delta
		if _ghost_window <= 0.0 and Game.hud != null:
			Game.hud.subtitle(Loc.t(&"coop.ghost_lost"), 2.5)
	else:
		_ghost_next -= delta
		if _ghost_next <= 0.0:
			_ghost_window = randf_range(4.0, 7.0)
			_ghost_next = randf_range(25.0, 55.0)
			if Game.hud != null:
				Game.hud.subtitle(Loc.t(&"coop.ghost_open"), 3.0, 2)
			if Game.audio != null:
				Game.audio.play_2d(STATIC, -12.0, 1.2)
	# Камера — за плечом у напарника: смотрим его ночь.
	if _ghost_cam != null and is_instance_valid(_ghost_cam) and _partner != null and is_instance_valid(_partner):
		var yaw := _partner.rotation.y
		var back := Vector3(sin(yaw), 0.0, cos(yaw))
		var want := _partner.global_position + back * 1.8 + Vector3(0, 2.1, 0)
		_ghost_cam.global_position = _ghost_cam.global_position.lerp(want, minf(delta * 4.0, 1.0))
		var target := _partner.global_position + Vector3(0, 1.4, 0) - back * 2.0
		if _ghost_cam.global_position.distance_to(target) > 0.1:
			_ghost_cam.look_at(target, Vector3.UP)


## Ночь потеряна — оба погибли. Хост начинает её заново, клиент просит хоста.
func night_lost() -> void:
	if not active():
		return
	if role == "host":
		get_tree().create_timer(6.0).timeout.connect(start_night.bind(coop_night))
	else:
		get_tree().create_timer(6.0).timeout.connect(func() -> void:
			if active():
				_request_restart.rpc_id(1))


# --- Сводка на двоих ---------------------------------------------------------------

## Хосту нужен бланк с цифрами напарника (а не свои снятые показания).
func needs_coop_report() -> bool:
	return active() and in_session and role == "host" and not _partner_dead and not ghost


## Сверка цифр с приборами: &"ok", &"fever" (продиктовали +36,6) или &"wrong".
func check_report(temp: int, wind: int, snow: int) -> StringName:
	var sy := Game.synoptic
	if sy == null:
		return &"ok"
	if temp >= 35 and temp <= 38:
		return &"fever"
	if absi(temp - int(roundf(Game.air_temp().x))) > TOL[&"temp"]:
		return &"wrong"
	if absi(wind - int(roundf(sy.wind_speed))) > TOL[&"wind"]:
		return &"wrong"
	if absi(snow - int(sy.snow_depth_cm)) > TOL[&"snow"]:
		return &"wrong"
	return &"ok"


## Сводка ушла: у того, кто снимал приборы, отметки сбрасываются — к следующей снимать заново.
func on_report_sent() -> void:
	if active() and in_session:
		_readings_reset.rpc()


@rpc("any_peer", "call_remote", "reliable")
func _readings_reset() -> void:
	if not in_session:
		return
	Game.clear_readings()
	if Game.hud != null and not Game.dead:
		Game.hud.subtitle(Loc.t(&"coop.report_gone"), 4.0)
