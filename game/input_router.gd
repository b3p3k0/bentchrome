extends Node
## Central input action names + boot-time creation/validation of the InputMap.
## Defining bindings in code (not in project.godot) sidesteps the
## [input]-section corruption that plagued the old build.
##
## Steer-to-drive mapping: move_up = throttle, move_down = brake/reverse,
## move_left/right = steer.

const ACTION_MOVE_UP := &"move_up"
const ACTION_MOVE_DOWN := &"move_down"
const ACTION_MOVE_LEFT := &"move_left"
const ACTION_MOVE_RIGHT := &"move_right"
const ACTION_FIRE_MG := &"fire_mg"
const ACTION_FIRE_SPECIAL := &"fire_special"

func _ready() -> void:
	_ensure_action(ACTION_MOVE_UP, [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_ensure_action(ACTION_MOVE_DOWN, [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_ensure_action(ACTION_MOVE_LEFT, [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_ensure_action(ACTION_MOVE_RIGHT, [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_ensure_action(ACTION_FIRE_MG, [_mouse(MOUSE_BUTTON_LEFT), _key(KEY_SPACE)])
	_ensure_action(ACTION_FIRE_SPECIAL, [_mouse(MOUSE_BUTTON_RIGHT), _key(KEY_K)])

func _ensure_action(action: StringName, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.5)
	else:
		InputMap.action_set_deadzone(action, 0.5)
		InputMap.action_erase_events(action)
	for ev in events:
		InputMap.action_add_event(action, ev)

func _key(physical: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = physical
	return e

func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	return e

func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e
