class_name NorayClient
extends Node
## Клиент сервера комнат noray (https://github.com/foxssake/noray) — по мотивам netfox.noray
## (MIT, © 2023 Gálffy Tamás), без зависимостей от netfox. Протокол: строки «команда данные\n» по TCP,
## регистрация внешнего UDP-порта — пакетом с PID на порт 8809.

signal on_command(command: String, data: String)
signal on_oid(oid: String)
signal on_pid(pid: String)
signal on_connect_nat(address: String, port: int)
signal on_connect_relay(address: String, port: int)

var oid := ""
var pid := ""
var local_port := -1

var _peer := StreamPeerTCP.new()
var _buf := ""
var _address := ""


func connect_to_host(address: String, port: int = 8890) -> Error:
	if is_connected_to_host():
		disconnect_from_host()
	var ip := IP.resolve_hostname(address, IP.TYPE_IPV4)
	if ip == "":
		return ERR_CANT_RESOLVE
	var err := _peer.connect_to_host(ip, port)
	if err != OK:
		return err
	_peer.set_no_delay(true)
	_buf = ""
	var t := 0.0
	while _peer.get_status() == StreamPeerTCP.STATUS_CONNECTING and t < 6.0:
		_peer.poll()
		await get_tree().process_frame
		t += get_process_delta_time()
	if _peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		_address = ip
		return OK
	disconnect_from_host()
	return ERR_CONNECTION_ERROR


func is_connected_to_host() -> bool:
	return _peer.get_status() == StreamPeerTCP.STATUS_CONNECTED


func disconnect_from_host() -> void:
	_peer.disconnect_from_host()
	oid = ""
	pid = ""
	local_port = -1


func register_host() -> Error:
	return _put("register-host")


## Регистрирует наш внешний UDP-адрес: шлём PID с локального порта, пока noray не ответит OK.
func register_remote(registrar_port: int = 8809, timeout: float = 8.0, interval: float = 0.1) -> Error:
	if not is_connected_to_host():
		return ERR_CONNECTION_ERROR
	if pid == "":
		return ERR_UNAUTHORIZED
	var result := ERR_TIMEOUT
	var udp := PacketPeerUDP.new()
	udp.bind(0)
	udp.set_dest_address(_address, registrar_port)
	var packet := pid.to_utf8_buffer()
	while timeout > 0.0:
		udp.put_packet(packet)
		while udp.get_available_packet_count() > 0:
			var recv := udp.get_packet().get_string_from_utf8()
			result = OK if recv == "OK" else FAILED
			if result == OK:
				local_port = udp.get_local_port()
			timeout = 0.0
			break
		await get_tree().create_timer(interval).timeout
		timeout -= interval
	udp.close()
	return result


func connect_nat(host_oid: String) -> Error:
	return _put("connect", host_oid)


func connect_relay(host_oid: String) -> Error:
	return _put("connect-relay", host_oid)


func _process(_delta: float) -> void:
	if not is_connected_to_host():
		return
	_peer.poll()
	var n := _peer.get_available_bytes()
	if n <= 0:
		return
	_buf += _peer.get_utf8_string(n)
	if not _buf.contains("\n"):
		return
	var idx := _buf.rfind("\n")
	var lines := _buf.substr(0, idx).split("\n", false)
	_buf = _buf.substr(idx + 1)
	for line in lines:
		var cmd := line
		var data := ""
		if line.contains(" "):
			cmd = line.get_slice(" ", 0)
			data = line.get_slice(" ", 1)
		on_command.emit(cmd, data)
		_handle(cmd, data)


func _put(command: String, data := "") -> Error:
	if not is_connected_to_host():
		return ERR_CONNECTION_ERROR
	var line := command if data == "" else "%s %s" % [command, data]
	return _peer.put_data((line + "\n").to_utf8_buffer())


func _handle(cmd: String, data: String) -> void:
	match cmd:
		"set-oid":
			oid = data
			on_oid.emit(oid)
		"set-pid":
			pid = data
			on_pid.emit(pid)
		"connect":
			on_connect_nat.emit(data.get_slice(":", 0), data.get_slice(":", 1).to_int())
		"connect-relay":
			on_connect_relay.emit(_address, data.to_int())
