extends Node
## Puts the other players into this world: streams the local player's state,
## spawns/updates/removes remote avatars, replays their foam shots, and shows
## the online status in the corner.

const REMOTE_PLAYER_SCRIPT = preload("res://remote_player.gd")
const FOAM_PELLET_SCENE: PackedScene = preload("res://foam_pellet.tscn")
const FOAM_FIRE_SOUND: AudioStream = preload("res://addons/cogito/Assets/Audio/Spray.ogg")
const SEND_INTERVAL := 1.0 / 15.0
const REMOTE_TIMEOUT_MSEC := 10000

var _remotes := {} # peer id -> remote player body
var _send_timer := 0.0
var _status_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Net.message_received.connect(_on_message)
	Net.peer_left.connect(_remove_remote)
	Net.connection_changed.connect(_on_connection_changed)

	var layer := CanvasLayer.new()
	layer.layer = 19
	add_child(layer)
	_status_label = Label.new()
	_status_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_status_label.offset_left = -360.0
	_status_label.offset_right = -24.0
	_status_label.offset_top = 20.0
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.add_theme_font_size_override("font_size", 20)
	_status_label.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.04))
	_status_label.add_theme_constant_override("outline_size", 5)
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_status_label)


func _process(delta: float) -> void:
	_update_status()
	if OS.get_cmdline_user_args().has("--net-debug"):
		_debug_report(delta)
	var now := Time.get_ticks_msec()
	for id in _remotes.keys():
		if now - int(_remotes[id].last_update_msec) > REMOTE_TIMEOUT_MSEC:
			_remove_remote(id)

	if not Net.online:
		return
	_send_timer -= delta
	if _send_timer > 0.0:
		return
	_send_timer = SEND_INTERVAL
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null:
		return
	var pos := player.global_position
	var vel := player.velocity
	Net.send({
		"t": "p",
		"p": [snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(pos.z, 0.01)],
		"v": [snappedf(vel.x, 0.01), snappedf(vel.y, 0.01), snappedf(vel.z, 0.01)],
		"r": snappedf(player.rotation.y, 0.01),
		"g": player.is_on_floor(),
		"a": player.call("is_playing"),
		"n": Net.player_name,
	})


## Called by the local player whenever it fires, so others see the pellet.
func broadcast_shot(origin: Vector3, direction: Vector3) -> void:
	Net.send({"t": "ps", "o": [origin.x, origin.y, origin.z], "d": [direction.x, direction.y, direction.z]})


func _on_message(from: int, data: Dictionary) -> void:
	match str(data.get("t", "")):
		"p":
			var remote = _remotes.get(from)
			if remote == null:
				remote = CharacterBody3D.new()
				remote.set_script(REMOTE_PLAYER_SCRIPT)
				remote.name = "RemotePlayer%d" % from
				remote.peer_id = from
				get_parent().add_child(remote)
				_remotes[from] = remote
			remote.apply_state(data)
		"ps":
			var shooter = _remotes.get(from)
			if shooter == null:
				return
			var o: Array = data.get("o", [])
			var d: Array = data.get("d", [])
			if o.size() < 3 or d.size() < 3:
				return
			# Visual only: the shooter's own client decides what the pellet hits.
			var pellet := FOAM_PELLET_SCENE.instantiate() as FoamPellet
			get_tree().current_scene.add_child(pellet)
			pellet.global_position = Vector3(o[0], o[1], o[2])
			pellet.launch(shooter, Vector3(d[0], d[1], d[2]), 0.0, &"")
			_play_remote_shot(shooter)


func _play_remote_shot(shooter: Node3D) -> void:
	var sound := shooter.get_node_or_null("ShotSound") as AudioStreamPlayer3D
	if sound == null:
		sound = AudioStreamPlayer3D.new()
		sound.name = "ShotSound"
		sound.stream = FOAM_FIRE_SOUND
		sound.volume_db = -6.0
		shooter.add_child(sound)
	sound.play()


func _remove_remote(id: int) -> void:
	var remote = _remotes.get(id)
	if remote != null:
		remote.queue_free()
		_remotes.erase(id)


func _on_connection_changed(is_online: bool) -> void:
	if not is_online:
		for id in _remotes.keys():
			_remove_remote(id)


var _debug_timer := 0.0


## `-- --net-debug`: auto-start the game and print the network picture every 2 s (for headless tests).
func _debug_report(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and not player.call("is_playing") and not player.get("_game_over"):
		player.call("_start_game")
	_debug_timer -= delta
	if _debug_timer > 0.0:
		return
	_debug_timer = 2.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--net-shot="):
			get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--net-shot="))
	var crowd := get_parent().get_node_or_null("BotCrowd")
	var bot_text := ""
	if crowd != null and not crowd.bots.is_empty():
		var bot: Node3D = crowd.bots[0]
		bot_text = "bot0 %s puppet=%s alive=%s" % [bot.global_position.snapped(Vector3.ONE * 0.1), bot.get("puppet"), bot.get("alive")]
	var remote_text := []
	for id in _remotes:
		remote_text.append("#%d %s %s" % [id, _remotes[id].get_node("NameLabel").text, _remotes[id].global_position.snapped(Vector3.ONE * 0.1)])
	print("[net] me #%d host #%d online=%s players=%d remotes=%s %s" % [Net.my_id, Net.host_id, Net.online, Net.player_count(), remote_text, bot_text])


func _update_status() -> void:
	if not Net.online:
		_status_label.text = "Offline (connecting...)"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.5))
		return
	var text := "Online: %d player%s" % [Net.player_count(), "" if Net.player_count() == 1 else "s"]
	if Net.is_host():
		text += "  (host)"
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", Color(0.65, 1.0, 0.65))
