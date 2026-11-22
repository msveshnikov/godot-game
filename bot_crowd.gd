extends Node3D
## Armed villagers roaming the estate along its roads and footpaths, plus the
## unarmed civilians and children at the playground and in the supermarket.
##
## Exactly one client (Net.is_host(): the server-chosen host, or anyone playing
## offline) simulates them with real physics and streams their state; everyone
## else shows them as puppets. Shots are broadcast so every client sees the
## pellets, and each client only applies damage to its own player.

const BOT_SCENE: PackedScene = preload("res://villager_bot.tscn")
const FOAM_PELLET_SCENE: PackedScene = preload("res://foam_pellet.tscn")
const BOT_COUNT := 16
const SEND_INTERVAL := 0.1
const PELLET_SPEED := 18.0
const PELLET_DAMAGE := 20.0
const SAFE_RESPAWN_DISTANCE := 35.0
const CIVILIAN_SEED_BASE := 100
## Dead villagers stay lying around; past this many the oldest bodies go.
const MAX_CORPSES := 30

## Walkable graph over the roads and paths (game x, z), from the district's bot_graph().
var NODES: Array[Vector2] = []
## Nodes next to the busiest player spawn points; bots never (re)spawn there.
var NO_SPAWN: Array = []

var bots: Array = []
var civilians: Array = []
var _adjacency: Array = []
var _civilian_specs: Array = []
var _send_timer := 0.0
var _corpses: Array[Node3D] = []


func _ready() -> void:
	# The street graph comes from the district of the current location (district.gd and friends).
	var district := get_node_or_null("../Diorama/District")
	var graph: Dictionary = district.call("bot_graph") if district != null and district.has_method("bot_graph") else {}
	NODES.assign(graph.get("nodes", [Vector2.ZERO]))
	var edges: Array = graph.get("edges", [])
	NO_SPAWN = graph.get("no_spawn", [])
	_civilian_specs = graph.get("civilians", [])
	_adjacency.resize(NODES.size())
	for index in NODES.size():
		_adjacency[index] = []
	for edge in edges:
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

	for index in _civilian_specs.size():
		var spec: Array = _civilian_specs[index]
		var person := BOT_SCENE.instantiate() as CharacterBody3D
		person.name = "%s%d" % [str(spec[0]).capitalize(), index]
		person.set("role", spec[0])
		person.set("bot_index", CIVILIAN_SEED_BASE + index)
		person.set("crowd", self)
		person.set("walk_speed", rng.randf_range(1.0, 1.6))
		var half: float = spec[3]
		person.set("zone", Rect2(float(spec[1]) - half, float(spec[2]) - half, half * 2.0, half * 2.0))
		person.set("stay", spec[4])
		person.position = Vector3(spec[1], 0.1, spec[2])
		add_child(person)
		civilians.append(person)

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


## Playing players holding a weapon (pistol or bat): people run from these.
func armed_players() -> Array:
	var result := []
	for player in _active_players():
		if not player.has_method("is_armed") or player.call("is_armed"):
			result.append(player)
	return result


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


## A dead villager's body (villager_walk.gd builds it); it stays until the cap pushes it out.
func add_corpse(corpse: Node3D) -> void:
	add_child(corpse)
	_corpses.append(corpse)
	while _corpses.size() > MAX_CORPSES:
		var oldest: Node3D = _corpses.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()


## Puppet side: we shot a bot that someone else simulates.
func report_hit(bot_index: int, kind := "pistol") -> void:
	Net.send({"t": "hit", "i": bot_index, "k": kind})


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
				bots[index].call("receive_hit", str(data.get("k", "pistol")))


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
