extends Node2D
## Phase 1/2 test arena: grid floor, a drivable vehicle, terrain patches, a
## launch ramp, static blocks, target dummies, enemy cars, and a readout.

const GRID := 128
const EXTENT := 2400

@onready var _player: Vehicle = $Vehicle
@onready var _readout: Label = $HUD/Readout

func _ready() -> void:
	for autoload_name in ["Dev", "GameState", "SceneFlow", "Spawner", "InputRouter", "AudioDirector"]:
		if get_node_or_null("/root/" + autoload_name) == null:
			push_warning("autoload MISSING: " + autoload_name)
	print("[boot] arena ready — WASD to drive, Space/LMB to fire")
	queue_redraw()
	if Dev.enabled:
		add_child(load("res://ui/dev_dashboard.tscn").instantiate())

func _process(_delta: float) -> void:
	if _player and is_instance_valid(_player) and _readout:
		_readout.text = "speed %4.0f px/s\nheading %5.1f deg\nsurface %s\nheight %3.0f\nhp %3.0f" % [
			_player.get_speed(), rad_to_deg(_player.heading), _player.current_terrain,
			_player.height, _player.get_hp()
		]

func _draw() -> void:
	var c := Color(1, 1, 1, 0.08)
	for x in range(-EXTENT, EXTENT + 1, GRID):
		draw_line(Vector2(x, -EXTENT), Vector2(x, EXTENT), c, 1.0)
	for y in range(-EXTENT, EXTENT + 1, GRID):
		draw_line(Vector2(-EXTENT, y), Vector2(EXTENT, y), c, 1.0)
