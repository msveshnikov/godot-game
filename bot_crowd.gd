extends Node3D
## Armed villagers on district routes, plus unarmed civilians in local zones.
##
## The host simulates the armed villagers and streams their state to other clients.
## Waterfront villagers are simulated locally while an older client hosts.
## Shots are broadcast so every client sees the pellets, and each client only
## applies damage to its own player.

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
var _waterfront_route := PackedVector2Array()
var _waterfront_spawns := PackedInt32Array()
var _puppet_count := 0
var _send_timer := 0.0
var _corpses: Array[Node3D] = []


func _ready() -> void:
	# The street graph comes from the district of the current location (district.gd and friends).
	var district := get_node_or_null("../Diorama/District")
	var graph: Dictionary = district.call("bot_graph") if district != null and district.has_method("bot_graph") else {}
	NODES.assign(graph.get("nodes", [Vector2.ZERO]))
	var edges: Array = graph.get("edges", [])
	NO_SPAWN = graph.get("no_spawn", [])
	var waterfront: Dictionary = graph.get("waterfront", {})
	_waterfront_route = waterfront.get("route", PackedVector2Array())
	_waterfront_spawns = waterfront.get("spawns", PackedInt32Array())
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
	for _index in BOT_COUNT:
		var speed := rng.randf_range(1.6, 2.5)
		var node: int = spawn_nodes[rng.randi() % spawn_nodes.size()]
		var spawn := node_position(node) + Vector3(rng.randf_range(-1, 1), 0.1, rng.randf_range(-1, 1))
		_add_villager(spawn, speed)

	for spec in graph.get("civilians", []):
		var person := _make_civilian(Vector2(spec[1], spec[2]), rng, spec[0])
		var half: float = spec[3]
		person.set("zone", Rect2(float(spec[1]) - half, float(spec[2]) - half, half * 2.0, half * 2.0))
		person.set("stay", spec[4])
		add_child(person)
		civilians.append(person)

	# Append these after the original villagers so their network indices stay stable.
	for node in _waterfront_spawns:
		_add_villager(node_position(node, true) + Vector3.UP * 0.1, rng.randf_range(1.7, 2.1), true)

	Net.message_received.connect(_on_message)
	Net.host_changed.connect(_on_host_changed)
	_on_host_changed()


func _add_villager(spawn: Vector3, speed: float, waterfront := false) -> void:
	var bot := BOT_SCENE.instantiate() as CharacterBody3D
	bot.name = "Villager%d" % bots.size()
	bot.set("bot_index", bots.size())
	bot.set("crowd", self)
	bot.set("walk_speed", speed)
	bot.set("waterfront", waterfront)
	bot.position = spawn
	add_child(bot)
	bots.append(bot)


func _make_civilian(spawn: Vector2, rng: RandomNumberGenerator, role: String) -> CharacterBody3D:
	var person := BOT_SCENE.instantiate() as CharacterBody3D
	var index := civilians.size()
	person.name = "%s%d" % [role.capitalize(), index]
	person.set("role", role)
	person.set("bot_index", CIVILIAN_SEED_BASE + index)
	person.set("crowd", self)
	person.set("walk_speed", rng.randf_range(1.0, 1.6))
	person.position = Vector3(spawn.x, 0.1, spawn.y)
	return person


func node_position(node: int, waterfront := false) -> Vector3:
	var point := _waterfront_route[node] if waterfront else NODES[node]
	return Vector3(point.x, 0.0, point.y)


func nearest_node(position_3d: Vector3, waterfront := false) -> int:
	var best := 0
	var best_distance := INF
	var flat := Vector2(position_3d.x, position_3d.z)
	var route = _waterfront_route if waterfront else NODES
	for index in route.size():
		var distance := flat.distance_squared_to(route[index])
		if distance < best_distance:
			best_distance = distance
			best = index
	return best


## Next node to walk to: any neighbour except the one we came from, unless it's a dead end.
func pick_next(current: int, previous: int, rng: RandomNumberGenerator, waterfront := false) -> int:
	if waterfront:
		return (current + 1) % _waterfront_route.size()
	var options: Array = _adjacency[current].duplicate()
	if options.size() > 1:
		options.erase(previous)
	return options[rng.randi() % options.size()]


## Shortest walk over the street graph from node `from` to node `to` (Dijkstra),
## both ends included; empty if they aren't connected.
func path_between(from: int, to: int) -> Array[int]:
	var result: Array[int] = []
	if from < 0 or to < 0 or from >= NODES.size() or to >= NODES.size():
		return result
	var distance := {from: 0.0}
	var previous := {}
	var open: Array[int] = [from]
	var done := {}
	while not open.is_empty():
		var best := 0
		for k in open.size():
			if float(distance[open[k]]) < float(distance[open[best]]):
				best = k
		var node: int = open[best]
		open.remove_at(best)
		if node == to:
			break
		done[node] = true
		for next in _adjacency[node]:
			if done.has(next):
				continue
			var through := float(distance[node]) + NODES[node].distance_to(NODES[next])
			if not distance.has(next) or through < float(distance[next]):
				if not distance.has(next):
					open.append(next)
				distance[next] = through
				previous[next] = node
	if not distance.has(to):
		return result
	var at := to
	while at != from:
		result.push_front(at)
		at = previous[at]
	result.push_front(from)
	return result


## Graph nodes in a distance band around `around` (game xz), for picking where a police car comes from.
func nodes_between(around: Vector3, near: float, far: float) -> Array[int]:
	var result: Array[int] = []
	var flat := Vector2(around.x, around.z)
	for index in NODES.size():
		var d := NODES[index].distance_to(flat)
		if d >= near and d <= far:
			result.append(index)
	return result


## A random node well away from every player, so respawns don't happen in someone's face.
func respawn_position(rng: RandomNumberGenerator, waterfront := false) -> Vector3:
	var players := _active_players()
	var candidates: Array[int] = []
	var spawn_nodes = _waterfront_spawns if waterfront else range(NODES.size())
	for index in spawn_nodes:
		if not waterfront and NO_SPAWN.has(index):
			continue
		var far := true
		var position := node_position(index, waterfront)
		for player in players:
			if (player as Node3D).global_position.distance_to(position) < SAFE_RESPAWN_DISTANCE:
				far = false
				break
		if far:
			candidates.append(index)
	if candidates.is_empty():
		candidates.append(spawn_nodes[rng.randi_range(0, spawn_nodes.size() - 1)])
	return node_position(candidates[rng.randi() % candidates.size()], waterfront) + Vector3.UP * 0.1


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
			var count := mini(states.size(), bots.size())
			_set_puppet_count(maxi(count, BOT_COUNT))
			for index in count:
				bots[index].call("apply_net_state", states[index])
		"bs":
			var index := int(data.get("i", -1))
			if index < 0 or index >= bots.size():
				return
			_spawn_bot_pellet(bots[index], _to_vec(data.get("o")), _to_vec(data.get("d")))
		"hit":
			var index := int(data.get("i", -1))
			if Net.is_host() and index >= 0 and index < bots.size():
				bots[index].call("receive_hit", str(data.get("k", "pistol")), from)


func _on_host_changed() -> void:
	# Older hosts stream only the original villagers. Simulate the extra ones
	# locally until a host sends their states.
	_set_puppet_count(0 if Net.is_host() else BOT_COUNT)


func _set_puppet_count(count: int) -> void:
	for index in range(mini(_puppet_count, count), maxi(_puppet_count, count)):
		bots[index].call("set_puppet", index < count)
	_puppet_count = count


static func _vec(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]


static func _to_vec(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(value[0], value[1], value[2])
	return Vector3.ZERO
