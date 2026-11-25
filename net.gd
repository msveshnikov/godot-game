extends Node
## Autoload "Net": WebSocket link to the relay server (server/relay.js).
##
## Works the same in the web build, on Android and on desktop. Offline (no
## server, or still connecting) the game simply runs single-player and this
## client counts as the host, so it simulates the villager bots itself.
##
## Server override: desktop `-- --server=ws://127.0.0.1:8091`, web `?server=...`.
## Room: `-- --room=name` or `?room=name` (default "main").
## Location: picked in the start menu and remembered; `-- --loc=omsk1` or `?loc=omsk1`
## overrides it. Every location has its own room on the relay ("main" stays
## Neratovice, the others get "-<id>" appended), so players only meet in the same place.

signal message_received(from: int, data: Dictionary)
signal peer_left(id: int)
signal host_changed
signal connection_changed(is_online: bool)
signal leaderboard_received(rows: Array)

const DEFAULT_SERVER := "wss://severance.lol/village-ws"
const RECONNECT_DELAY := 3.0
const SETTINGS_PATH := "user://settings.cfg"
const RANK_PATH := "user://leaderboard.cfg"
## Playable places: id, menu name, the district script that builds it.
const LOCATIONS := [
	{"id": "neratovice", "name": "Neratovice", "script": "res://district.gd"},
	{"id": "omsk1", "name": "Omsk 1", "script": "res://district_omsk1.gd"},
	{"id": "omsk2", "name": "Omsk 2", "script": "res://district_omsk2.gd"},
	{"id": "nyc", "name": "Times Square", "script": "res://district_nyc.gd"},
]

var my_id := 0
var host_id := 0
var online := false
var ranking_available := false
var peers: Array[int] = []
var player_name := ""
var location := "nyc" # new players start in Times Square

var _socket := WebSocketPeer.new()
var _url := ""
var _server := DEFAULT_SERVER
var _room := ""
var _retry_timer := 0.0
var _socket_started := false
var _rank_token := ""
var rocket_serial := 0


func _init() -> void:
	# Read the name, location and server now: the main scene enters the tree (and
	# picks its district, world.gd) before this autoload's _ready runs.
	_load_settings()
	_resolve_server()
	_url = _room_url()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_open_socket()


func is_host() -> bool:
	return not online or host_id == my_id


func player_count() -> int:
	return peers.size() + 1 if online else 1


func send(data: Dictionary) -> void:
	if online:
		_socket.send_text(JSON.stringify(data))


func request_leaderboard() -> void:
	if online and ranking_available:
		send({"t": "rank_top"})


func _join_ranking() -> void:
	if _rank_token.is_empty():
		var config := ConfigFile.new()
		config.load(RANK_PATH)
		_rank_token = str(config.get_value("player", "token", ""))
		if _rank_token.length() != 64:
			_rank_token = Crypto.new().generate_random_bytes(32).hex_encode()
			config.set_value("player", "token", _rank_token)
			if config.save(RANK_PATH) != OK:
				push_warning("Could not save leaderboard identity")
	send({"t": "rank_join", "token": _rank_token, "n": player_name})


func set_player_name(value: String) -> void:
	player_name = value.strip_edges().left(16)
	if player_name.is_empty():
		player_name = "Player %d" % randi_range(100, 999)
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("player", "name", player_name)
	config.save(SETTINGS_PATH)


## Menu name of the current location.
func location_name() -> String:
	for entry in LOCATIONS:
		if entry["id"] == location:
			return entry["name"]
	return location


## The district script that builds the current location.
func location_script() -> String:
	for entry in LOCATIONS:
		if entry["id"] == location:
			return entry["script"]
	return LOCATIONS[0]["script"]


## Switch to another location: remember it and move to that location's room.
## The caller reloads the scene so the new district gets built.
func set_location(id: String) -> void:
	if not _is_location(id) or id == location:
		return
	location = id
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("player", "location", location)
	config.save(SETTINGS_PATH)
	_url = _room_url()
	if _socket_started:
		_socket.close()
	_socket_started = false
	if online:
		online = false
		peers.clear()
		connection_changed.emit(false)
		host_changed.emit()
	_open_socket()


func _is_location(id: String) -> bool:
	for entry in LOCATIONS:
		if entry["id"] == id:
			return true
	return false


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		player_name = str(config.get_value("player", "name", ""))
		var saved := str(config.get_value("player", "location", location))
		if _is_location(saved):
			location = saved
	if player_name.is_empty():
		player_name = "Player %d" % randi_range(100, 999)


func _resolve_server() -> void:
	var forced_location := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--server="):
			_server = arg.trim_prefix("--server=")
		elif arg.begins_with("--room="):
			_room = arg.trim_prefix("--room=")
		elif arg.begins_with("--loc="):
			forced_location = arg.trim_prefix("--loc=")
	if OS.has_feature("web"):
		var query_server := _query("server")
		if not query_server.is_empty():
			_server = query_server
		var query_room := _query("room")
		if not query_room.is_empty():
			_room = query_room
		var query_location := _query("loc")
		if not query_location.is_empty():
			forced_location = query_location
	if _is_location(forced_location):
		location = forced_location


func _query(key: String) -> String:
	var value: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('%s') || ''" % key, true)
	return value if value is String else ""


## Relay URL for the current room: Neratovice keeps the plain room ("main" by default),
## other locations add their id, e.g. "omsk1" or "friends-omsk1".
## The platform and game version ride along for the relay's usage log.
func _room_url() -> String:
	var room := _room
	if location != LOCATIONS[0]["id"]:
		room = (room + "-" if not room.is_empty() else "") + location
	var server := _server
	if server.count("/") == 2: # "ws://host:port" -> "ws://host:port/", or the query isn't a valid URL
		server += "/"
	var query := "os=%s&v=%s" % [OS.get_name().uri_encode(),
			str(ProjectSettings.get_setting("application/config/version", "")).uri_encode()]
	if not room.is_empty():
		query = "room=" + room.uri_encode() + "&" + query
	return server + ("&" if "?" in server else "?") + query


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
			if data.has("from"):
				return
			my_id = int(data["id"])
			host_id = int(data["host"])
			peers.clear()
			for peer in data.get("peers", []):
				peers.append(int(peer))
			online = true
			ranking_available = data.get("ranking", false) == true
			if ranking_available:
				_join_ranking()
			print("Multiplayer: online as #%d, host #%d, %d other player(s)" % [my_id, host_id, peers.size()])
			connection_changed.emit(true)
			host_changed.emit()
		"rank_top":
			if not data.has("from") and data.get("rows") is Array:
				leaderboard_received.emit(data["rows"])
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
