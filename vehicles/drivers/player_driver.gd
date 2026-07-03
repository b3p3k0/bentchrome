class_name PlayerDriver
extends Driver
## Reads the player's keyboard/gamepad input (steer-to-drive) as intent.
## Action names come from the InputRouter script's consts (not the autoload
## identifier) so this compiles under headless -s test runs, where project
## autoloads are never registered.

const IR := preload("res://game/input_router.gd")

func get_intent(_vehicle, _delta: float) -> Dictionary:
	return {
		"throttle": Input.get_axis(IR.ACTION_MOVE_DOWN, IR.ACTION_MOVE_UP),
		"steer": Input.get_axis(IR.ACTION_MOVE_LEFT, IR.ACTION_MOVE_RIGHT),
		"fire_mg": Input.is_action_pressed(IR.ACTION_FIRE_MG),
		"fire_selected": Input.is_action_pressed(IR.ACTION_FIRE_SELECTED),
		"weapon_prev": Input.is_action_just_pressed(IR.ACTION_WEAPON_PREV),
		"weapon_next": Input.is_action_just_pressed(IR.ACTION_WEAPON_NEXT),
	}
