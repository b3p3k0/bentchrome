class_name PlayerDriver
extends Driver
## Reads the player's keyboard/gamepad input (steer-to-drive) as intent.
## Action names come from the InputRouter script's consts (not the autoload
## identifier) so this compiles under headless -s test runs, where project
## autoloads are never registered.

const IR := preload("res://game/input_router.gd")

## A fresh driver (level load, respawn) starts gated: Space/LMB is bound to both
## "press any key" dismiss AND fire, so a key still held from dismissing a card
## or loading screen would otherwise bleed a shot. Fire stays suppressed until
## both fire actions are seen released once, then live fire resumes.
var _fire_gate := true

## Re-arm the gate. Used when a tutorial lesson card is dismissed mid-level —
## same driver, so a fresh instance won't do it.
func arm_fire_gate() -> void:
	_fire_gate = true

func get_intent(_vehicle, _delta: float) -> Dictionary:
	var fire_mg: bool = Input.is_action_pressed(IR.ACTION_FIRE_MG)
	var fire_sec: bool = Input.is_action_pressed(IR.ACTION_FIRE_SELECTED)
	if _fire_gate:
		if not fire_mg and not fire_sec:
			_fire_gate = false  # both released — the dismiss press is spent
		else:
			fire_mg = false
			fire_sec = false
	return {
		"throttle": Input.get_axis(IR.ACTION_MOVE_DOWN, IR.ACTION_MOVE_UP),
		"steer": Input.get_axis(IR.ACTION_MOVE_LEFT, IR.ACTION_MOVE_RIGHT),
		"fire_mg": fire_mg,
		"fire_selected": fire_sec,
		"weapon_prev": Input.is_action_just_pressed(IR.ACTION_WEAPON_PREV),
		"weapon_next": Input.is_action_just_pressed(IR.ACTION_WEAPON_NEXT),
		"handbrake": Input.is_action_pressed(IR.ACTION_HANDBRAKE),
		"boost": Input.is_action_pressed(IR.ACTION_BOOST),
	}
