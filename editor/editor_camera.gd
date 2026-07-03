extends Camera2D
## Editor viewport camera: middle-mouse (or Space + left) drag to pan, wheel
## to zoom toward the cursor. Raw input only — the editor never defines
## InputMap actions, so it can't clash with the game's InputRouter bindings.

const ZOOM_MIN := 0.2
const ZOOM_MAX := 2.0
const ZOOM_STEP := 1.1

var _panning := false
var _space_held := false

func _ready() -> void:
	make_current()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_SPACE and not event.echo:
		_space_held = event.pressed
	elif event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE:
				_panning = event.pressed
			MOUSE_BUTTON_LEFT:
				if _space_held:
					_panning = event.pressed
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_zoom_at(get_global_mouse_position(), ZOOM_STEP)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom_at(get_global_mouse_position(), 1.0 / ZOOM_STEP)
	elif event is InputEventMouseMotion and _panning:
		position -= event.relative / zoom.x

func _zoom_at(anchor: Vector2, factor: float) -> void:
	var new_zoom := clampf(zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(new_zoom, zoom.x):
		return
	# Keep the world point under the cursor fixed while zooming.
	position = anchor + (position - anchor) * (zoom.x / new_zoom)
	zoom = Vector2(new_zoom, new_zoom)
