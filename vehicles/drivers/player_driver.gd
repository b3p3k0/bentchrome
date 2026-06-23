class_name PlayerDriver
extends Driver
## Reads the player's keyboard/gamepad input (steer-to-drive) as intent.

func get_intent(_vehicle, _delta: float) -> Dictionary:
	return {
		"throttle": Input.get_axis(InputRouter.ACTION_MOVE_DOWN, InputRouter.ACTION_MOVE_UP),
		"steer": Input.get_axis(InputRouter.ACTION_MOVE_LEFT, InputRouter.ACTION_MOVE_RIGHT),
		"fire_mg": Input.is_action_pressed(InputRouter.ACTION_FIRE_MG),
		"fire_special": Input.is_action_pressed(InputRouter.ACTION_FIRE_SPECIAL),
	}
