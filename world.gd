extends Node3D
## Main scene root: before anything in the scene is ready, give the District node
## the script of the location picked in the menu (Net.location), so the player,
## the bots and the traffic all find the right place.


func _ready() -> void:
	apply_settings()
	# The menu's loading screen came along over the build; the game is running now.
	for k in 3:
		await get_tree().process_frame
	LoadingScreen.finish_on(get_tree())


## Graphics quality from the settings (settings.gd calls this again when they change).
func apply_settings() -> void:
	get_tree().root.get_node("Settings").call("apply_scene", self)


func _enter_tree() -> void:
	var district := get_node_or_null("Diorama/District")
	if district == null:
		return
	var path := Net.location_script()
	var current := district.get_script() as Script
	if current == null or current.resource_path != path:
		district.set_script(load(path))
