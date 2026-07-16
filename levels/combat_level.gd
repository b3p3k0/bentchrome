extends Node2D
## Shared shell for every hand-authored combat level: autoload sanity check,
## pause/end-screen/dev glue, the random distinct-car enemy roll, and the
## campaign lives loop — death respawns the player at their start point with a
## brief blink-shield until the lives tank runs dry, then the end screen takes
## it. Level geometry is pure scene content; this script never assumes any.

const Loader := preload("res://levels/level_loader.gd")
const VehiclesHelper := preload("res://vehicles/vehicles.gd")
const FightDirectorScript := preload("res://ai/fight_director.gd")

const RESPAWN_DELAY := 1.6
const SHIELD_TIME := 2.0

## MP shell mode: the baked cars become spawn DATA and leave the tree before
## their first physics tick; pause/end screens, the enemy re-roll, and the
## lives loop all stand down — the shell (levels/mp/mp_match.gd) owns them.
@export var mp_managed := false
var mp_spawns: Array = []  # [{pos, heading, floor}] — player slot first, then Enemy1..N

@onready var _player: Vehicle = $Vehicle

var _spawn_point := Vector2.ZERO
var _spawn_heading := 0.0
var _respawning := false

func _ready() -> void:
	# The wheel keeps reading button/wheel events — hide the pointer so the
	# combat view stays clean and DOS-terminal-honest. Menus (and pause/end
	# overlays) put it back; SceneFlow.goto_scene resets it on the way out.
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	for autoload_name in ["Dev", "GameState", "SceneFlow", "Spawner", "InputRouter", "AudioDirector"]:
		if get_node_or_null("/root/" + autoload_name) == null:
			push_warning("autoload MISSING: " + autoload_name)
	if mp_managed:
		_collect_and_clear_for_mp()
		print("[boot] level ready — WASD to drive, Space/LMB to fire")
		set_process(false)
		return
	_randomize_enemies()
	_attach_ai_fight_director()
	print("[boot] level ready — WASD to drive, Space/LMB to fire")
	add_child(load("res://ui/pause_menu.tscn").instantiate())
	add_child(load("res://ui/end_screen.tscn").instantiate())
	var dev := get_node_or_null(^"/root/Dev")
	if dev and dev.enabled:
		add_child(load("res://ui/dev_dashboard.tscn").instantiate())
		add_child(load("res://ui/tuning_editor.tscn").instantiate())  # F2
	# This screen belongs to the solo player — presentation reads it via
	# Vehicles.local() from here on (the MP shell marks per-peer instead).
	VehiclesHelper.mark_local(_player)
	_spawn_point = _player.global_position
	_spawn_heading = _player.heading
	# Level-start gets the same blink shield as a respawn — no spawn ambushes.
	_player.respawn(_spawn_point, _spawn_heading, SHIELD_TIME)

## The lives loop. Dead + lives to spare = respawn after a beat; dead on the
## last life = zero the tank and let the end screen call it.
func _process(_delta: float) -> void:
	if _respawning or _player == null or not is_instance_valid(_player):
		return
	if _player.get_hp() > 0.0:
		return
	var gs := get_node_or_null(^"/root/GameState")
	if gs and gs.is_devgod_enabled():
		# DEVGOD died anyway (pits still kill) — comp the life, just respawn.
		_respawning = true
		get_tree().create_timer(RESPAWN_DELAY).timeout.connect(_respawn, CONNECT_ONE_SHOT)
		return
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

## The baked cars' transforms become the level's spawn set (player slot
## first, then Enemy1..N in tree order), then the cars leave synchronously —
## children _ready before the parent, but physics hasn't ticked, so nothing
## ever simulates. Zero .tscn edits: the baked positions ARE the authoring.
func _collect_and_clear_for_mp() -> void:
	mp_spawns.clear()
	var baked: Array = [_player]
	for child in get_children():
		if child != _player and child is Vehicle:
			baked.append(child)
	for car in baked:
		if car == null or not is_instance_valid(car):
			continue
		mp_spawns.append({
			"pos": car.global_position,
			"heading": car.heading,  # _ready already folded authored rotation in
			"floor": car.start_floor,
		})
		remove_child(car)
		car.free()
	_player = null

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

func _attach_ai_fight_director() -> void:
	var director = FightDirectorScript.new()
	director.name = "AIFightDirector"
	director.setup(self)
	add_child(director)
