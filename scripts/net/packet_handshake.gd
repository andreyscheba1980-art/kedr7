class_name PacketHandshake
extends Node
## UDP-рукопожатие для пробивки NAT (по мотивам netfox.noray, MIT): обе стороны шлют друг другу своё
## состояние «$rwx», пока не увидят, что другая сторона их прочитала.


func over_packet_peer(peer: PacketPeer, timeout: float = 8.0, frequency: float = 0.1) -> Error:
	var result := ERR_TIMEOUT
	var did_read := false
	var did_write := true
	var did_hs := false
	while timeout >= 0.0:
		while peer.get_available_packet_count() > 0:
			var st := peer.get_packet().get_string_from_ascii()
			did_read = true
			if st.contains("r"):
				did_hs = true
			if st.contains("x") and did_hs:
				result = OK
				timeout = 0.0
		peer.put_packet(("$" + ("r" if did_read else "-") + ("w" if did_write else "-") + ("x" if did_hs else "-")).to_ascii_buffer())
		await get_tree().create_timer(frequency).timeout
		timeout -= frequency
	if did_read and did_write and not did_hs:
		result = ERR_BUSY
	return result


## Хост не может читать сокет ENet — просто шлёт «всё хорошо» клиенту, пробивая свой NAT.
func over_enet_peer(peer: ENetMultiplayerPeer, address: String, port: int, timeout: float = 8.0, frequency: float = 0.1) -> Error:
	while timeout >= 0.0:
		if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			return ERR_CONNECTION_ERROR
		peer.host.socket_send(address, port, "$rwx".to_ascii_buffer())
		await get_tree().create_timer(frequency).timeout
		timeout -= frequency
	return OK
