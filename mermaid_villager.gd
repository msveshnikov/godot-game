extends StaticBody3D

func _ready() -> void:
	var model := get_node_or_null("Model")
	if model == null:
		push_error("Mermaid villager is missing its imported model.")
		return

	var animation_players := model.find_children("*", "AnimationPlayer", true, false)
	if animation_players.is_empty():
		push_error("Mermaid villager model has no imported AnimationPlayer.")
		return

	var animation_player := animation_players[0] as AnimationPlayer
	for animation_name: StringName in animation_player.get_animation_list():
		if "Hair Sway" not in String(animation_name):
			continue

		var hair_animation := animation_player.get_animation(animation_name)
		hair_animation.loop_mode = Animation.LOOP_LINEAR
		animation_player.play(animation_name)
		return

	push_error("Mermaid hair-sway animation is missing from the imported model.")
