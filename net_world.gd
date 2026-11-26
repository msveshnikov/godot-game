extends Node
## Puts the other players into this world: streams the local player's state,
## spawns/updates/removes remote avatars, replays their shots, carries the damage
## players deal each other, shows who killed whom, and the online status.
##
## Hits are decided by the shooter (like the villagers' hits): the shooter sends
## "dmg" to the victim's id, the victim applies it to itself and, if that killed
## it, tells everyone with "kill".

const REMOTE_PLAYER_SCRIPT = preload("res://remote_player.gd")
const SEND_INTERVAL := 1.0 / 15.0
const REMOTE_TIMEOUT_MSEC := 10000
const FEED_TIME := 6.0
## Older Paris builds have different moving cars at the same local indices.
## Keep their damage events separate while sharing the rest of the room.
const PARIS_TRAFFIC_INDEX_BASE := 1000

var _remotes := {} # peer id -> remote player body
var _rockets := {} # peer id -> their rockets in flight (harmless copies), oldest first
var _send_timer := 0.0
var _status_label: Label
var _feed: VBoxContainer


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
	_status_label.offset_left = -480.0
	_status_label.offset_right = -24.0
	_status_label.offset_top = 20.0
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.add_theme_font_size_override("font_size", 20)
	_status_label.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.04))
	_status_label.add_theme_constant_override("outline_size", 5)
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_status_label)
	_feed = VBoxContainer.new()
	_feed.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_feed.offset_left = -480.0
	_feed.offset_right = -24.0
	_feed.offset_top = 52.0
	_feed.alignment = BoxContainer.ALIGNMENT_BEGIN
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_feed)


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
		"w": player.get("weapon"),
		"n": Net.player_name,
		"lk": Game.look_code(),
	})


## Called by the local player when it swings the bat, so others see the swing.
func broadcast_swing() -> void:
	Net.send({"t": "sw"})


## Called by the local player whenever it fires: others hear the shot and see the
## tracer, and blood or a bullet hole where it ended.
func broadcast_shot(origin: Vector3, end: Vector3, flesh: bool, normal: Vector3) -> void:
	Net.send({"t": "ps", "o": _vec(origin), "e": _vec(end), "f": flesh, "nm": _vec(normal)})


## The local player blew up a car: "parked" (spot index) or "traffic" (car index and
## where it was along its lane).
func broadcast_car(kind: String, index: int, s: float) -> void:
	Net.send({"t": "cx", "w": kind, "i": index + _car_index_base(kind), "s": snappedf(s, 0.01)})


## The local player dented a car with the bat: where and which way (car space),
## and whether it was a window.
func broadcast_dent(kind: String, index: int, point: Vector3, dir: Vector3, glass: bool, first: bool) -> void:
	Net.send({"t": "dn", "w": kind, "i": index + _car_index_base(kind), "p": _vec3(point), "d": _vec3(dir), "g": glass, "first": first})


func _car_index_base(kind: String) -> int:
	return PARIS_TRAFFIC_INDEX_BASE if kind == "traffic" and Net.location == "paris" else 0


## The local player fired the bazooka: others see the rocket fly (harmless) until
## its blast arrives (broadcast_blast).
func broadcast_rocket(origin: Vector3, direction: Vector3, rocket_id: int) -> void:
	Net.send({"t": "rf", "rocket": rocket_id, "o": _vec(origin), "d": _vec3(direction)})


## The local player's rocket blew up at `at`. Include the position along the
## rail when it wrecked the Dublin shuttle so peers use the same position.
func broadcast_blast(at: Vector3, normal: Vector3, surface: String, rocket_id: int, tram_progress := -1.0) -> void:
	var packet := {"t": "rx", "rocket": rocket_id, "p": _vec(at), "nm": _vec3(normal), "s": surface}
	if tram_progress >= 0.0:
		packet["tp"] = snappedf(tram_progress, 0.01)
	Net.send(packet)


## The local player cracked or smashed a shop window at `point`.
func broadcast_window(point: Vector3) -> void:
	Net.send({"t": "gw", "p": _vec3(point)})


## The local player hit another player for `amount` ("head", "chest", "belly", "legs", "bat").
func send_damage(peer: int, amount: int, zone: String) -> void:
	Net.send({"t": "dmg", "to": peer, "a": amount, "z": zone})


## The local player was just killed by `killer` (peer id): tell everyone, for the feed.
func report_death(killer: int, zone: String) -> void:
	Net.send({"t": "kill", "by": killer, "z": zone, "n": Net.player_name})
	_add_feed(peer_name(killer), Net.player_name, zone)


## The name another player goes by, as last streamed.
func peer_name(id: int) -> String:
	if id == Net.my_id:
		return Net.player_name
	var remote = _remotes.get(id)
	if remote == null:
		return "Player #%d" % id
	return remote.get_node("NameLabel").text


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
		"sw":
			var swinger = _remotes.get(from)
			if swinger != null:
				swinger.show_swing()
		"ps":
			var shooter = _remotes.get(from)
			if shooter == null:
				return
			var o: Array = data.get("o", [])
			var e: Array = data.get("e", [])
			if o.size() < 3 or e.size() < 3:
				return
			var origin := Vector3(o[0], o[1], o[2])
			var end := Vector3(e[0], e[1], e[2])
			var scene := get_tree().current_scene
			shooter.show_shot(origin, end - origin)
			ShotFx.tracer(scene, origin, end)
			if bool(data.get("f", false)):
				ShotFx.blood(scene, end, origin.direction_to(end))
			else:
				var n: Array = data.get("nm", [])
				if n.size() >= 3:
					ShotFx.impact(scene, end, Vector3(n[0], n[1], n[2]))
			ShotFx.shot_sound(scene, origin)
		"cx":
			var district := get_tree().current_scene.get_node_or_null("Diorama/District")
			if district == null:
				return
			var kind := str(data.get("w", ""))
			var cars: Node = district.get_node_or_null("Traffic") if kind == "traffic" else district
			if cars != null and cars.has_method("blow_up_car"):
				cars.call("blow_up_car", int(data.get("i", -1)) - _car_index_base(kind), float(data.get("s", -1.0)), from)
		"dn":
			var district_d := get_tree().current_scene.get_node_or_null("Diorama/District")
			var p: Array = data.get("p", [])
			var d: Array = data.get("d", [])
			if district_d == null or p.size() < 3 or d.size() < 3:
				return
			var kind := str(data.get("w", ""))
			var dented: Node = district_d.get_node_or_null("Traffic") if kind == "traffic" else district_d
			if dented != null and dented.has_method("dent_car"):
				dented.call("dent_car", int(data.get("i", -1)) - _car_index_base(kind),
					Vector3(p[0], p[1], p[2]), Vector3(d[0], d[1], d[2]), bool(data.get("g", false)))
		"rf":
			var ro: Array = data.get("o", [])
			var rd: Array = data.get("d", [])
			if ro.size() < 3 or rd.size() < 3:
				return
			var rocket_from := Vector3(ro[0], ro[1], ro[2])
			var direction := Vector3(rd[0], rd[1], rd[2])
			var launcher = _remotes.get(from)
			if launcher != null:
				launcher.show_shot(rocket_from, direction)
			var flying: Array = _rockets.get(from, [])
			flying.append(Rocket.launch(get_parent(), rocket_from, direction, from, false))
			_rockets[from] = flying
		"rx":
			var bp: Array = data.get("p", [])
			var bn: Array = data.get("nm", [])
			if bp.size() < 3 or bn.size() < 3:
				return
			var in_flight: Array = _rockets.get(from, [])
			while not in_flight.is_empty():
				var rocket = in_flight.pop_front()
				if is_instance_valid(rocket):
					rocket.fizzle()
					break
			var surface := str(data.get("s", "air"))
			if surface == "tram" and float(data.get("tp", -1.0)) >= 0.0:
				var tram := get_tree().current_scene.get_node_or_null("Diorama/District/Tram") as DublinTram
				if tram != null:
					tram.wreck_by_rocket(float(data["tp"]))
			Rocket.explode(get_parent(), Vector3(bp[0], bp[1], bp[2]), Vector3(bn[0], bn[1], bn[2]), surface, from)
		"gw":
			var district_w := get_tree().current_scene.get_node_or_null("Diorama/District")
			var at: Array = data.get("p", [])
			if district_w != null and district_w.has_method("smash_window") and at.size() >= 3:
				district_w.call("smash_window", Vector3(at[0], at[1], at[2]))
		"dmg":
			if int(data.get("to", -1)) != Net.my_id:
				return
			var player := get_tree().get_first_node_in_group("player")
			if player != null:
				player.call("receive_damage", float(data.get("a", 0)), from, str(data.get("z", "")))
		"kill":
			var killer := int(data.get("by", 0))
			var victim := str(data.get("n", peer_name(from)))
			_add_feed(peer_name(killer), victim, str(data.get("z", "")))
			if killer == Net.my_id:
				var me := get_tree().get_first_node_in_group("player")
				var crosshair = me.get("_crosshair") if me != null else null
				if crosshair != null:
					crosshair.call("show_hit", true)


## One line in the kill feed under the status: "Killer > Victim (headshot)", gone after a while.
func _add_feed(killer: String, victim: String, zone: String) -> void:
	var line := Label.new()
	var how: String = {"head": "  (headshot)", "bat": "  (bat)", "blast": "  (car bomb)", "rocket": "  (bazooka)"}.get(zone, "")
	line.text = "%s  >  %s%s" % [killer, victim, how]
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_theme_font_size_override("font_size", 18)
	var mine := killer == Net.player_name or victim == Net.player_name
	line.add_theme_color_override("font_color", Color(1.0, 0.55, 0.4) if mine else Color(0.95, 0.95, 0.9))
	line.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	line.add_theme_constant_override("outline_size", 5)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed.add_child(line)
	while _feed.get_child_count() > 5:
		_feed.get_child(0).free()
	var tween := line.create_tween()
	tween.tween_interval(FEED_TIME)
	tween.tween_property(line, "modulate:a", 0.0, 0.6)
	tween.tween_callback(line.queue_free)


## Millimetres, for points that pick one window or one dent.
static func _vec3(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]


static func _vec(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]


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
		_status_label.text = "%s  |  Offline (connecting...)" % Net.location_name()
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.5))
		return
	var text := "%s  |  Online: %d player%s" % [Net.location_name(), Net.player_count(), "" if Net.player_count() == 1 else "s"]
	if Net.is_host():
		text += "  (host)"
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", Color(0.65, 1.0, 0.65))
