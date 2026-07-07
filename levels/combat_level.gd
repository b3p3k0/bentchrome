extends Node2D
## Shared shell for every hand-authored combat level: autoload sanity check,
## pause/end-screen/dev glue, the random distinct-car enemy roll, and the
## campaign lives loop — death respawns the player at their start point with a
## brief blink-shield until the lives tank runs dry, then the end screen takes
## it. Level geometry is pure scene content; this script never assumes any.

const Loader := preload("res://levels/level_loader.gd")

const RESPAWN_DELAY := 1.6
const SHIELD_TIME := 2.0

@onready var _player: Vehicle = $Vehicle

var _spawn_point := Vector2.ZERO
var _spawn_heading := 0.0
var _respawning := false

func _ready() -> void:
	for autoload_name in ["Dev", "GameState", "SceneFlow", "Spawner", "InputRouter", "AudioDirector"]:
		if get_node_or_null("/root/" + autoload_name) == null:
			push_warning("autoload MISSING: " + autoload_name)
	_randomize_enemies()
	print("[boot] level ready — WASD to drive, Space/LMB to fire")
	add_child(load("res://ui/pause_menu.tscn").instantiate())
	add_child(load("res://ui/end_screen.tscn").instantiate())
	var dev := get_node_or_null(^"/root/Dev")
	if dev and dev.enabled:
		add_child(load("res://ui/dev_dashboard.tscn").instantiate())
	_spawn_point = _player.global_position
	_spawn_heading = _player.heading

## The lives loop. Dead + lives to spare = respawn after a beat; dead on the
## last life = zero the tank and let the end screen call it.
func _process(_delta: float) -> void:
	if _respawning or _player == null or not is_instance_valid(_player):
		return
	if _player.get_hp() > 0.0:
		return
	var gs := get_node_or_null(^"/root/GameState")
	if gs == null or gs.lives <= 1:
		if gs:
			gs.lives = 0
		set_process(false)
		return
	gs.lives -= 1
	_respawning = true
	get_tree().create_timer(RESPAWN_DELAY).timeout.connect(_respawn, CONNECT_ONE_SHOT)

func _respawn() -> void:
	_respawning = false
	if _player and is_instance_valid(_player):
		_player.respawn(_spawn_point, _spawn_heading, SHIELD_TIME)

## Reassigns the scene's baked enemy cars at runtime: random, all distinct,
## never the player's car. Children ready before the parent, so _player.stats
## already reflects the real car (selected or default-fallback) and the swap
## lands before the first physics tick. Baked .tscn stats are editor previews.
func _randomize_enemies() -> void:
	var enemies := []
	for child in get_children():
		if child.is_in_group(&"enemies") and not child.get("fixed_loadout"):
			enemies.append(child)  # bosses keep their authored car
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
