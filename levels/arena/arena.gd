extends Node2D
## Phase 1 test arena: a grid floor for motion reference, a drivable vehicle, a
## few static blocks for collision feel, and a speed/heading readout for tuning.

const GRID := 128
const EXTENT := 2400

@onready var _player: Vehicle = $Vehicle
@onready var _readout: Label = $HUD/Readout

func _ready() -> void:
	for autoload_name in ["GameState", "SceneFlow", "Spawner", "InputRouter", "AudioDirector"]:
		if get_node_or_null("/root/" + autoload_name) == null:
			push_warning("autoload MISSING: " + autoload_name)
	print("[boot] arena ready — drive with WASD (W gas, S brake/reverse, A/D steer)")
	queue_redraw()

func _process(_delta: float) -> void:
	if _player and _readout:
		_readout.text = "speed %4.0f px/s\nheading %5.1f deg" % [
			_player.get_speed(), rad_to_deg(_player.heading)
		]

func _draw() -> void:
	var c := Color(1, 1, 1, 0.08)
	for x in range(-EXTENT, EXTENT + 1, GRID):
		draw_line(Vector2(x, -EXTENT), Vector2(x, EXTENT), c, 1.0)
	for y in range(-EXTENT, EXTENT + 1, GRID):
		draw_line(Vector2(-EXTENT, y), Vector2(EXTENT, y), c, 1.0)
