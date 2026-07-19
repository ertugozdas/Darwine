class_name SteamP2PPeer extends MultiplayerPeerExtension

## Godot 4.7 MultiplayerPeer implementation backed by Steam Networking
## Messages. Darwine remains authoritative on peer 1; Steam only replaces the
## transport and provides relay/NAT traversal.

signal transport_error(message: String)

const SERVER_PEER_ID := 1
const CLIENT_PEER_ID := 2
const RESULT_OK := 1
const NETWORKING_SEND_UNRELIABLE := 0
const NETWORKING_SEND_RELIABLE := 8
const MAX_CHANNELS := 4
const MAX_MESSAGES_PER_POLL := 64
const MAX_PAYLOAD_BYTES := (512 * 1024) - 10
const MAX_QUEUED_PACKETS := 256
const FRAME_MAGIC_D := 0x44
const FRAME_MAGIC_W := 0x57
const FRAME_VERSION := 1
const FRAME_HEADER_BYTES := 10

var _steam: Object = null
var _lobby_id := 0
var _local_steam_id := 0
var _unique_id := 0
var _is_host := false
var _connection_status := MultiplayerPeer.CONNECTION_DISCONNECTED
var _target_peer := 0
var _transfer_channel := 0
var _transfer_mode := MultiplayerPeer.TRANSFER_MODE_RELIABLE
var _refuse_new_connections := false
var _pending_client_connect := false
var _remote_steam_by_peer: Dictionary = {}
var _peer_by_remote_steam: Dictionary = {}
var _incoming_packets: Array[Dictionary] = []
var _last_packet_metadata: Dictionary = {}
var _outgoing_sequences: Dictionary = {}
var _incoming_sequences: Dictionary = {}


func setup_host(steam: Object, lobby_id: int, local_steam_id: int) -> Error:
	if not _validate_setup(steam, lobby_id, local_steam_id):
		return ERR_INVALID_PARAMETER
	_reset_transport()
	_steam = steam
	_lobby_id = lobby_id
	_local_steam_id = local_steam_id
	_unique_id = SERVER_PEER_ID
	_is_host = true
	_connection_status = MultiplayerPeer.CONNECTION_CONNECTED
	return OK


func setup_client(steam: Object, lobby_id: int, local_steam_id: int, host_steam_id: int) -> Error:
	if not _validate_setup(steam, lobby_id, local_steam_id) or host_steam_id <= 0 or host_steam_id == local_steam_id:
		return ERR_INVALID_PARAMETER
	_reset_transport()
	_steam = steam
	_lobby_id = lobby_id
	_local_steam_id = local_steam_id
	_unique_id = CLIENT_PEER_ID
	_is_host = false
	_connection_status = MultiplayerPeer.CONNECTION_CONNECTING
	_register_remote(SERVER_PEER_ID, host_steam_id)
	_pending_client_connect = true
	return OK


func add_lobby_member(remote_steam_id: int) -> Error:
	if not _is_host or _connection_status != MultiplayerPeer.CONNECTION_CONNECTED:
		return ERR_UNCONFIGURED
	if remote_steam_id <= 0 or remote_steam_id == _local_steam_id:
		return ERR_INVALID_PARAMETER
	if _refuse_new_connections and not _peer_by_remote_steam.has(remote_steam_id):
		return ERR_UNAVAILABLE
	if _peer_by_remote_steam.has(remote_steam_id):
		return OK
	if not _remote_steam_by_peer.is_empty():
		return ERR_ALREADY_IN_USE
	_register_remote(CLIENT_PEER_ID, remote_steam_id)
	peer_connected.emit(CLIENT_PEER_ID)
	return OK


func remove_lobby_member(remote_steam_id: int) -> void:
	var peer_id := int(_peer_by_remote_steam.get(remote_steam_id, 0))
	if peer_id <= 0:
		return
	_remove_remote(peer_id, true)


func has_steam_member(remote_steam_id: int) -> bool:
	return _peer_by_remote_steam.has(remote_steam_id)


func get_steam_id_for_peer(peer_id: int) -> int:
	if peer_id == _unique_id:
		return _local_steam_id
	return int(_remote_steam_by_peer.get(peer_id, 0))


func get_lobby_id() -> int:
	return _lobby_id


func notify_session_failed(remote_steam_id: int, message: String) -> void:
	if not _peer_by_remote_steam.has(remote_steam_id):
		return
	transport_error.emit(message)
	var peer_id := int(_peer_by_remote_steam[remote_steam_id])
	_remove_remote(peer_id, true)
	if not _is_host:
		_connection_status = MultiplayerPeer.CONNECTION_DISCONNECTED


func _poll() -> void:
	if _connection_status == MultiplayerPeer.CONNECTION_DISCONNECTED or not is_instance_valid(_steam):
		return
	if _pending_client_connect:
		_pending_client_connect = false
		_connection_status = MultiplayerPeer.CONNECTION_CONNECTED
		peer_connected.emit(SERVER_PEER_ID)
	for channel in range(MAX_CHANNELS):
		var received_variant: Variant = _steam.call(
			"receiveMessagesOnChannel",
			channel,
			MAX_MESSAGES_PER_POLL
		)
		if not received_variant is Array:
			continue
		for message_variant in received_variant as Array:
			if message_variant is Dictionary:
				_queue_steam_message(message_variant as Dictionary, channel)


func _put_packet_script(buffer: PackedByteArray) -> Error:
	if _connection_status != MultiplayerPeer.CONNECTION_CONNECTED or not is_instance_valid(_steam):
		return ERR_UNCONFIGURED
	if buffer.is_empty() or buffer.size() > MAX_PAYLOAD_BYTES:
		return ERR_INVALID_DATA
	var recipients := _resolve_recipients()
	if recipients.is_empty():
		return ERR_DOES_NOT_EXIST
	var channel := clampi(_transfer_channel, 0, MAX_CHANNELS - 1)
	var sequence := int(_outgoing_sequences.get(channel, 0)) + 1
	_outgoing_sequences[channel] = sequence
	var framed := _build_frame(buffer, _transfer_mode, channel, sequence)
	var flags := (
		NETWORKING_SEND_RELIABLE
		if _transfer_mode == MultiplayerPeer.TRANSFER_MODE_RELIABLE
		else NETWORKING_SEND_UNRELIABLE
	)
	for remote_steam_id in recipients:
		var result := int(_steam.call("sendMessageToUser", remote_steam_id, framed, flags, channel))
		if result != RESULT_OK:
			transport_error.emit("Steam P2P paketi gönderilemedi (sonuç %d)." % result)
			return ERR_CANT_CONNECT
	return OK


func _get_packet_script() -> PackedByteArray:
	if _incoming_packets.is_empty():
		return PackedByteArray()
	_last_packet_metadata = _incoming_packets.pop_front()
	return (_last_packet_metadata.get("payload", PackedByteArray()) as PackedByteArray).duplicate()


func _get_available_packet_count() -> int:
	return _incoming_packets.size()


func _get_max_packet_size() -> int:
	return MAX_PAYLOAD_BYTES


func _get_packet_peer() -> int:
	return int(_peek_packet_metadata().get("peer_id", 0))


func _get_packet_channel() -> int:
	return int(_peek_packet_metadata().get("channel", 0))


func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	return int(
		_peek_packet_metadata().get("mode", MultiplayerPeer.TRANSFER_MODE_RELIABLE)
	) as MultiplayerPeer.TransferMode


func _set_transfer_channel(channel: int) -> void:
	_transfer_channel = clampi(channel, 0, MAX_CHANNELS - 1)


func _get_transfer_channel() -> int:
	return _transfer_channel


func _set_transfer_mode(mode: MultiplayerPeer.TransferMode) -> void:
	_transfer_mode = mode


func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return _transfer_mode


func _set_target_peer(peer: int) -> void:
	_target_peer = peer


func _is_server() -> bool:
	return _is_host


func _close() -> void:
	if is_instance_valid(_steam):
		for remote_steam_id_variant in _peer_by_remote_steam.keys():
			_steam.call("closeSessionWithUser", int(remote_steam_id_variant))
	var peers: Array = _remote_steam_by_peer.keys()
	_remote_steam_by_peer.clear()
	_peer_by_remote_steam.clear()
	for peer_id_variant in peers:
		peer_disconnected.emit(int(peer_id_variant))
	_connection_status = MultiplayerPeer.CONNECTION_DISCONNECTED
	_pending_client_connect = false
	_incoming_packets.clear()
	_last_packet_metadata.clear()


func _disconnect_peer(peer: int, _force: bool) -> void:
	_remove_remote(peer, true)
	if not _is_host and peer == SERVER_PEER_ID:
		_connection_status = MultiplayerPeer.CONNECTION_DISCONNECTED


func _get_unique_id() -> int:
	return _unique_id


func _set_refuse_new_connections(enable: bool) -> void:
	_refuse_new_connections = enable


func _is_refusing_new_connections() -> bool:
	return _refuse_new_connections


func _is_server_relay_supported() -> bool:
	return true


func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return _connection_status


func _queue_steam_message(message: Dictionary, steam_channel: int) -> void:
	var remote_steam_id := int(message.get("identity", 0))
	var peer_id := int(_peer_by_remote_steam.get(remote_steam_id, 0))
	if peer_id <= 0:
		return
	var frame_variant: Variant = message.get("payload", PackedByteArray())
	if not frame_variant is PackedByteArray:
		return
	var frame := frame_variant as PackedByteArray
	if frame.size() < FRAME_HEADER_BYTES or frame.size() > MAX_PAYLOAD_BYTES + FRAME_HEADER_BYTES:
		return
	if frame[0] != FRAME_MAGIC_D or frame[1] != FRAME_MAGIC_W or frame[2] != FRAME_VERSION:
		return
	var mode_value := clampi(
		int(frame[3]),
		MultiplayerPeer.TRANSFER_MODE_UNRELIABLE,
		MultiplayerPeer.TRANSFER_MODE_RELIABLE
	)
	var channel := clampi(int(frame[4]), 0, MAX_CHANNELS - 1)
	if channel != steam_channel:
		return
	var sequence := int(frame.decode_u32(6))
	if mode_value == MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED:
		var sequence_key := "%d:%d" % [remote_steam_id, channel]
		var last_sequence := int(_incoming_sequences.get(sequence_key, 0))
		if sequence <= last_sequence:
			return
		_incoming_sequences[sequence_key] = sequence
	if _incoming_packets.size() >= MAX_QUEUED_PACKETS:
		_incoming_packets.pop_front()
	_incoming_packets.append({
		"peer_id": peer_id,
		"channel": channel,
		"mode": mode_value,
		"payload": frame.slice(FRAME_HEADER_BYTES),
	})


func _build_frame(buffer: PackedByteArray, mode: int, channel: int, sequence: int) -> PackedByteArray:
	var frame := PackedByteArray()
	frame.resize(FRAME_HEADER_BYTES)
	frame[0] = FRAME_MAGIC_D
	frame[1] = FRAME_MAGIC_W
	frame[2] = FRAME_VERSION
	frame[3] = mode
	frame[4] = channel
	frame[5] = 0
	frame.encode_u32(6, sequence)
	frame.append_array(buffer)
	return frame


func _resolve_recipients() -> Array[int]:
	var recipients: Array[int] = []
	for peer_id_variant in _remote_steam_by_peer.keys():
		var peer_id := int(peer_id_variant)
		if _target_peer > 0 and peer_id != _target_peer:
			continue
		if _target_peer < 0 and peer_id == abs(_target_peer):
			continue
		recipients.append(int(_remote_steam_by_peer[peer_id]))
	return recipients


func _peek_packet_metadata() -> Dictionary:
	if not _incoming_packets.is_empty():
		return _incoming_packets.front()
	return _last_packet_metadata


func _register_remote(peer_id: int, remote_steam_id: int) -> void:
	_remote_steam_by_peer[peer_id] = remote_steam_id
	_peer_by_remote_steam[remote_steam_id] = peer_id


func _remove_remote(peer_id: int, emit_signal: bool) -> void:
	var remote_steam_id := int(_remote_steam_by_peer.get(peer_id, 0))
	if remote_steam_id <= 0:
		return
	if is_instance_valid(_steam):
		_steam.call("closeSessionWithUser", remote_steam_id)
	_remote_steam_by_peer.erase(peer_id)
	_peer_by_remote_steam.erase(remote_steam_id)
	if emit_signal:
		peer_disconnected.emit(peer_id)


func _reset_transport() -> void:
	_close()
	_steam = null
	_lobby_id = 0
	_local_steam_id = 0
	_unique_id = 0
	_is_host = false
	_target_peer = 0
	_transfer_channel = 0
	_transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	_refuse_new_connections = false
	_outgoing_sequences.clear()
	_incoming_sequences.clear()


func _validate_setup(steam: Object, lobby_id: int, local_steam_id: int) -> bool:
	return (
		is_instance_valid(steam)
		and lobby_id > 0
		and local_steam_id > 0
		and steam.has_method("sendMessageToUser")
		and steam.has_method("receiveMessagesOnChannel")
	)
