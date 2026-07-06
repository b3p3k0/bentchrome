extends Node2D
## Test arena, city edition: streets carved by building blocks around a central
## park (grass/pond/dirt), destructible crates and wall segments (some hiding
## goodies), a ramp that jumps the secret courtyard's wall, and enemy cars.
## The floor grid is drawn by the GridFloor child (levels/grid_floor.gd).

const Loader := preload("res://levels/level_loader.gd")

@onready var _player: Vehicle = $Vehicle

func _ready() -> void:
	for autoload_name in ["Dev", "GameState", "SceneFlow", "Spawner", "InputRouter", "AudioDirector"]:
		if get_node_or_null("/root/" + autoload_name) == null:
			push_warning("autoload MISSING: " + autoload_name)
	_randomize_enemies()
	print("[boot] arena ready — WASD to drive, Space/LMB to fire")
	add_child(load("res://ui/pause_menu.tscn").instantiate())
	add_child(load("res://ui/end_screen.tscn").instantiate())
	var dev := get_node_or_null(^"/root/Dev")
	if dev and dev.enabled:
		add_child(load("res://ui/dev_dashboard.tscn").instantiate())

## Reassigns the scene's baked enemy cars at runtime: random, all distinct,
## never the player's car. Children ready before the parent, so _player.stats
## already reflects the real car (selected or default-fallback) and the swap
## lands before the first physics tick. Baked .tscn stats are editor previews.
func _randomize_enemies() -> void:
	var enemies := []
	for child in get_children():
		if child.is_in_group(&"enemies"):
			enemies.append(child)
	if enemies.is_empty():
		return
	var player_id := ""
	if _player.stats:
		player_id = _player.stats.resource_path.get_file().get_basename()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var picks: Array = Loader.pick_cars(enemies.size(), player_id, rng)
	for i in picks.size():
		enemies[i].set_stats(load("res://data/vehicles/%s.tres" % picks[i]))
		enemies[i].get_node("Driver").mix = Loader.mix_for_car(picks[i])
