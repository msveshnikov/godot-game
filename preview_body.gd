extends CharacterBody3D
## Stands in for a player in the shop's preview (shop.gd): the model animator reads
## its velocity (none) and asks whether it is on the ground (always).


func net_grounded() -> bool:
	return true
