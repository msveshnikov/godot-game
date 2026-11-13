extends Node
## Autoload "Net": WebSocket link to the relay server (server/relay.js).
##
## Works the same in the web build, on Android and on desktop. Offline (no
## server, or still connecting) the game simply runs single-player and this
## client counts as the host, so it simulates the villager bots itself.
##
## Server override: desktop `-- --server=ws://127.0.0.1:8091`, web `?server=...`.
## Room: `-- --room=name` or `?room=name` (default "main").

signal message_received(from: int, data: Dictionary)
signal peer_left(id: int)
signal host_changed
signal connection_changed(is_online: bool)

const DEFAULT_SERVER := "wss://severance.lol/village-ws"
const RECONNECT_DELAY := 3.0
const SETTINGS_PATH := "user://settings.cfg"

var my_id := 0
var host_id := 0
var online := false
var peers: Array[int] = []
var player_name := ""

var _socket := WebSocketPeer.new()
var _url := ""
var _retry_timer := 0.0
var _socket_started := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_name()
	_url = _resolve_url()
	_open_socket()


func is_host() -> bool:
	return not online or host_id == my_id


func player_count() -> int:
	return peers.size() + 1 if online else 1


func send(data: Dictionary) -> void:
	if online:
		_socket.send_text(JSON.stringify(data))


func set_player_name(value: String) -> void:
	player_name = value.strip_edges().left(16)
	if player_name.is_empty():
		player_name = "Player %d" % randi_range(100, 999)
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("player", "name", player_name)
	config.save(SETTINGS_PATH)


func _load_name() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		player_name = str(config.get_value("player", "name", ""))
	if player_name.is_empty():
		player_name = "Player %d" % randi_range(100, 999)


func _resolve_url() -> String:
	var server := DEFAULT_SERVER
	var room := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--server="):
			server = arg.trim_prefix("--server=")
		elif arg.begins_with("--room="):
			room = arg.trim_prefix("--room=")
	if OS.has_feature("web"):
		var query_server: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('server') || ''", true)
		if query_server is String and not query_server.is_empty():
			server = query_server
		var query_room: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('room') || ''", true)
		if query_room is String and not query_room.is_empty():
			room = query_room
	if not room.is_empty():
		server += ("&" if "?" in server else "?") + "room=" + room.uri_encode()
	return server


func _open_socket() -> void:
	_socket = WebSocketPeer.new()
	var error := _socket.connect_to_url(_url)
	_socket_started = error == OK
	if not _socket_started:
		push_warning("Multiplayer: cannot connect to %s (%s)" % [_url, error_string(error)])
		_retry_timer = RECONNECT_DELAY


func _process(delta: float) -> void:
	if not _socket_started:
		_retry_timer -= delta
		if _retry_timer <= 0.0:
			_open_socket()
		return

	_socket.poll()
	match _socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			while _socket.get_available_packet_count() > 0:
				_handle_packet(_socket.get_packet().get_string_from_utf8())
		WebSocketPeer.STATE_CLOSED:
			_socket_started = false
			_retry_timer = RECONNECT_DELAY
			if online:
				print("Multiplayer: disconnected (%d)" % _socket.get_close_code())
				online = false
				peers.clear()
				connection_changed.emit(false)
				host_changed.emit()


func _handle_packet(text: String) -> void:
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return
	var data: Dictionary = parsed
	match str(data.get("t", "")):
		"welcome":
			my_id = int(data["id"])
			host_id = int(data["host"])
			peers.clear()
			for peer in data.get("peers", []):
				peers.append(int(peer))
			online = true
			print("Multiplayer: online as #%d, host #%d, %d other player(s)" % [my_id, host_id, peers.size()])
			connection_changed.emit(true)
			host_changed.emit()
		"join":
			var joined := int(data["id"])
			if not peers.has(joined):
				peers.append(joined)
		"leave":
			var left := int(data["id"])
			peers.erase(left)
			peer_left.emit(left)
		"host":
			host_id = int(data["id"])
			print("Multiplayer: host is now #%d%s" % [host_id, " (me)" if host_id == my_id else ""])
			host_changed.emit()
		_:
			if data.has("from"):
				message_received.emit(int(data["from"]), data)
