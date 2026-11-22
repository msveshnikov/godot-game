extends Node3D
## Main scene root: before anything in the scene is ready, give the District node
## the script of the location picked in the menu (Net.location), so the player,
## the bots and the traffic all find the right place.


func _enter_tree() -> void:
	var district := get_node_or_null("Diorama/District")
	if district == null:
		return
	var path := Net.location_script()
	var current := district.get_script() as Script
	if current == null or current.resource_path != path:
		district.set_script(load(path))
