class_name Driver
extends Node
## Supplies driving intent to a Vehicle. Subclasses (player input, AI) override
## get_intent(). The Vehicle and DrivingController never read input or AI
## directly — that is the split that keeps player and enemy logic from forking.

func get_intent(_vehicle, _delta: float) -> Dictionary:
	return {"throttle": 0.0, "steer": 0.0, "fire_mg": false, "fire_selected": false, "weapon_prev": false, "weapon_next": false}
