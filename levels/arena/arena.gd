extends Node2D
## Phase 1/2 test arena: grid floor, a drivable vehicle, terrain patches, a
## launch ramp, static blocks, target dummies, enemy cars, and a readout.
## The floor grid is drawn by the GridFloor child (levels/grid_floor.gd).

@onready var _player: Vehicle = $Vehicle

func _ready() -> void:
	for autoload_name in ["Dev", "GameState", "SceneFlow", "Spawner", "InputRouter", "AudioDirector"]:
		if get_node_or_null("/root/" + autoload_name) == null:
			push_warning("autoload MISSING: " + autoload_name)
	print("[boot] arena ready — WASD to drive, Space/LMB to fire")
	add_child(load("res://ui/pause_menu.tscn").instantiate())
	var dev := get_node_or_null(^"/root/Dev")
	if dev and dev.enabled:
		add_child(load("res://ui/dev_dashboard.tscn").instantiate())
