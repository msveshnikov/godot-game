extends Node3D
## Ten armed villagers roaming the estate along its roads and footpaths.
##
## Exactly one client (Net.is_host(): the server-chosen host, or anyone playing
## offline) simulates them with real physics and streams their state; everyone
## else shows them as puppets. Shots are broadcast so every client sees the
## pellets, and each client only applies damage to its own player.

const BOT_SCENE: PackedScene = preload("res://villager_bot.tscn")
const FOAM_PELLET_SCENE: PackedScene = preload("res://foam_pellet.tscn")
const BOT_COUNT := 10
const SEND_INTERVAL := 0.1
const PELLET_SPEED := 18.0
const PELLET_DAMAGE := 20.0
const SAFE_RESPAWN_DISTANCE := 35.0

## Walkable graph over roads and paths, in district.gd's real (u, n) metres:
## u along the blocks towards the south-east, n towards the north-east.
const U0 := -5.0 # district.gd's game origin
const UN_NODES: Array[Vector2] = [
	Vector2(-105, -18.75), Vector2(-80, -18.75), Vector2(-65, -18.75), Vector2(-49.8, -18.75), Vector2(-30, -18.75), # 0-4 Na Skalkach
	Vector2(-14, -18.75), Vector2(3.9, -18.75), Vector2(21.8, -18.75), Vector2(39.6, -18.75), Vector2(44.5, -18.75), # 5-9
	Vector2(44.5, -45), Vector2(44.5, -70), Vector2(44.5, -100), # 10-12 branch south
	Vector2(-65, -12.6), Vector2(-49.8, -12.6), Vector2(-31.9, -12.6), Vector2(-14, -12.6), # 13-16 home sidewalk
	Vector2(3.9, -12.6), Vector2(21.8, -12.6), Vector2(39.6, -12.6), Vector2(56, -12.6), # 17-20
	Vector2(-49.8, -4), Vector2(-31.9, -4), Vector2(-14, -4), Vector2(3.9, -4), Vector2(21.8, -4), Vector2(39.6, -4), # 21-26 entrances
	Vector2(-65, 19.9), Vector2(-65, 59.8), Vector2(56, 19.9), Vector2(56, 59.8), # 27-30 paths round the ends
	Vector2(-40, 19.9), Vector2(-14, 19.9), Vector2(10, 19.9), Vector2(30, 19.9), # 31-34 yard
	Vector2(-70, 63.5), Vector2(-40, 63.5), Vector2(-11, 63.5), Vector2(24.7, 63.5), Vector2(50, 63.5), Vector2(62.7, 63.5), # 35-40 Za Jednotou
	Vector2(62.7, -18.75), Vector2(62.7, 20), Vector2(62.7, 40), # 41-43 east link
	Vector2(75, 2), Vector2(65, 8), # 44-45 playground
	Vector2(-78, -56), Vector2(-30, -56), Vector2(0, -56), Vector2(40, -56), Vector2(44.5, -56), # 46-50 walk behind the towers
	Vector2(-64.5, -26), # 51 tower W door
	Vector2(-9.55, 30), Vector2(26.2, 30), Vector2(-11, 77), Vector2(24.7, 77), # 52-55 middle / north block doors
]
const EDGES := [
	[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 7], [7, 8], [8, 9],
	[9, 10], [10, 50], [50, 11], [11, 12], [9, 41],
	[13, 14], [14, 15], [15, 16], [16, 17], [17, 18], [18, 19], [19, 20],
	[2, 13], [3, 14], [5, 16], [7, 18], [8, 19], [20, 41],
	[14, 21], [15, 22], [16, 23], [17, 24], [18, 25], [19, 26],
	[13, 27], [27, 28], [28, 35], [28, 36], [20, 29], [29, 30], [30, 39], [30, 40],
	[27, 31], [31, 32], [32, 33], [33, 34], [34, 29],
	[35, 36], [36, 37], [37, 38], [38, 39], [39, 40],
	[41, 42], [42, 43], [43, 40], [29, 42], [42, 45], [45, 44],
	[46, 47], [47, 48], [48, 49], [49, 50], [4, 47], [1, 46], [2, 51],
	[32, 52], [34, 53], [37, 54], [38, 55],
]
## Nodes next to the busiest player spawn points (see player_controller.gd); bots never (re)spawn there.
const NO_SPAWN := [6, 16, 17, 18, 24]

var NODES: Array[Vector2] = [] # game (x, z), built from UN_NODES

var bots: Array = []
var _adjacency: Array = []
var _send_timer := 0.0


func _ready() -> void:
	for point in UN_NODES:
		NODES.append(Vector2(-(point.x - U0), point.y))
	_adjacency.resize(NODES.size())
	for index in NODES.size():
		_adjacency[index] = []
	for edge in EDGES:
		_adjacency[edge[0]].append(edge[1])
		_adjacency[edge[1]].append(edge[0])

	# Same seed everywhere, so every client starts with the same crowd layout.
	var rng := RandomNumberGenerator.new()
	rng.seed = 2611
	var spawn_nodes := range(NODES.size()).filter(func(n): return not NO_SPAWN.has(n))
	for index in BOT_COUNT:
		var bot := BOT_SCENE.instantiate() as CharacterBody3D
		bot.name = "Villager%d" % index
		bot.set("bot_index", index)
		bot.set("crowd", self)
		bot.set("walk_speed", rng.randf_range(1.6, 2.5))
		var node: int = spawn_nodes[rng.randi() % spawn_nodes.size()]
		bot.position = node_position(node) + Vector3(rng.randf_range(-1, 1), 0.1, rng.randf_range(-1, 1))
		add_child(bot)
		bots.append(bot)

	Net.message_received.connect(_on_message)
	Net.host_changed.connect(_on_host_changed)
	_on_host_changed()


func node_position(node: int) -> Vector3:
	return Vector3(NODES[node].x, 0.0, NODES[node].y)


func nearest_node(position_3d: Vector3) -> int:
	var best := 0
	var best_distance := INF
	var flat := Vector2(position_3d.x, position_3d.z)
	for index in NODES.size():
		var distance := flat.distance_squared_to(NODES[index])
		if distance < best_distance:
			best_distance = distance
			best = index
	return best


## Next node to walk to: any neighbour except the one we came from, unless it's a dead end.
func pick_next(current: int, previous: int, rng: RandomNumberGenerator) -> int:
	var options: Array = _adjacency[current].duplicate()
	if options.size() > 1:
		options.erase(previous)
	return options[rng.randi() % options.size()]


## A random node well away from every player, so respawns don't happen in someone's face.
func respawn_position(rng: RandomNumberGenerator) -> Vector3:
	var players := _active_players()
	var candidates: Array[int] = []
	for index in NODES.size():
		if NO_SPAWN.has(index):
			continue
		var far := true
		for player in players:
			if (player as Node3D).global_position.distance_to(node_position(index)) < SAFE_RESPAWN_DISTANCE:
				far = false
				break
		if far:
			candidates.append(index)
	if candidates.is_empty():
		candidates.append(rng.randi_range(0, NODES.size() - 1))
	return node_position(candidates[rng.randi() % candidates.size()]) + Vector3(0, 0.1, 0)


## Nearest playing player (local or remote) within range, or null.
func pick_target(from: Vector3, max_range: float) -> Node3D:
	var best: Node3D = null
	var best_distance := max_range
	for player in _active_players():
		var distance := from.distance_to((player as Node3D).global_position)
		if distance < best_distance:
			best_distance = distance
			best = player
	return best


func _active_players() -> Array:
	var result := []
	for player in get_tree().get_nodes_in_group("player"):
		if player.has_method("is_playing") and player.call("is_playing"):
			result.append(player)
	for remote in get_tree().get_nodes_in_group("remote_players"):
		if remote.get("active") and (remote as Node3D).visible:
			result.append(remote)
	return result


## Host side: a bot fires; spawn the pellet here and tell everyone else.
func fire(bot: CharacterBody3D, origin: Vector3, direction: Vector3) -> void:
	_spawn_bot_pellet(bot, origin, direction)
	Net.send({"t": "bs", "i": bot.get("bot_index"), "o": _vec(origin), "d": _vec(direction)})


## Puppet side: we shot a bot that someone else simulates.
func report_hit(bot_index: int) -> void:
	Net.send({"t": "hit", "i": bot_index})


func _spawn_bot_pellet(bot: CharacterBody3D, origin: Vector3, direction: Vector3) -> void:
	var pellet := FOAM_PELLET_SCENE.instantiate() as FoamPellet
	get_tree().current_scene.add_child(pellet)
	pellet.global_position = origin
	pellet.launch(bot, direction, PELLET_DAMAGE, &"player", PELLET_SPEED)
	bot.call("play_fire_sound")


func _physics_process(delta: float) -> void:
	if not Net.online or not Net.is_host():
		return
	_send_timer -= delta
	if _send_timer > 0.0:
		return
	_send_timer = SEND_INTERVAL
	var states := []
	for bot in bots:
		states.append(bot.call("net_state"))
	Net.send({"t": "b", "s": states})


func _on_message(from: int, data: Dictionary) -> void:
	match str(data.get("t", "")):
		"b":
			if from != Net.host_id or Net.is_host():
				return
			var states: Array = data.get("s", [])
			for index in mini(states.size(), bots.size()):
				bots[index].call("apply_net_state", states[index])
		"bs":
			var index := int(data.get("i", -1))
			if index < 0 or index >= bots.size():
				return
			_spawn_bot_pellet(bots[index], _to_vec(data.get("o")), _to_vec(data.get("d")))
		"hit":
			var index := int(data.get("i", -1))
			if Net.is_host() and index >= 0 and index < bots.size():
				bots[index].call("receive_hit")


func _on_host_changed() -> void:
	var puppet := not Net.is_host()
	for bot in bots:
		bot.call("set_puppet", puppet)


static func _vec(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]


static func _to_vec(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(value[0], value[1], value[2])
	return Vector3.ZERO
