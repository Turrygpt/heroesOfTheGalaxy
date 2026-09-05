extends Node

const HumanPlanetState := preload("res://scripts/human_planet_state.gd")


## StrategicMain is currently the new-game entry point. _enter_tree runs before
## the strategy-map child is initialized, so it cannot read an old campaign's
## buildings during its _ready method.
func _enter_tree() -> void:
	HumanPlanetState.reset_to_default()
