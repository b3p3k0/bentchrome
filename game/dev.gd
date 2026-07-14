extends Node
## Dev mode — toggled from the settings menu (DEVELOPER MODE row) and persisted
## with the other settings; the old `--dev` cmdline flag is retired. Gates
## dev-only tools: the F1 handling dashboard, the F2 tuning editor, the car
## tuner (Settings -> DEVELOPER OPTIONS), and their decks (user://tuning.json
## + user://car_tuner.json overrides, boot-applied here).

const TuningDeck := preload("res://game/tuning_deck.gd")
const CarDeck := preload("res://game/car_deck.gd")

var enabled := false
var tuning = null    # TuningDeck instance while dev mode is on
var car_deck = null  # CarDeck instance while dev mode is on

func _ready() -> void:
	_apply_windowed_flag()
	# Dev sits BEFORE GameState in the autoload order, so its settings haven't
	# loaded yet — sync after the boot frame settles.
	_sync_from_settings.call_deferred()

## Net playtests: `-- --windowed` (or `--win`) drops the project's fullscreen
## setting to a plain 1280x720 window so two instances fit on one box.
func _apply_windowed_flag() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var args := OS.get_cmdline_user_args()
	if "--windowed" in args or "--win" in args:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))

func _sync_from_settings() -> void:
	var gs := get_node_or_null(^"/root/GameState")
	enabled = gs.dev_mode if gs else false
	if enabled:
		print("[dev] on")
		_ensure_tuning()

## Lazily boots the tuning deck (also called by the settings screen when the
## toggle flips mid-session).
func _ensure_tuning() -> void:
	if tuning != null:
		return
	tuning = TuningDeck.new()
	car_deck = CarDeck.new()
	# Same hermetic rule as settings: live tuning overrides never leak into
	# headless gate runs (they mutate shared weapon resources process-wide).
	if DisplayServer.get_name() != "headless":
		tuning.load_and_apply()
		car_deck.load_and_apply()
	get_tree().node_added.connect(_on_node_added)
	for v in get_tree().get_nodes_in_group(&"vehicles"):
		_apply_vehicle_overrides(v)

## Spawn hook: vehicle/controller overrides reach every future vehicle.
## Deferred so it lands after the vehicle's _ready/stat application (stats
## never touch these exports, but order discipline is free).
func _on_node_added(node: Node) -> void:
	if enabled and node is CharacterBody2D and node.has_method(&"get_controller"):
		_apply_vehicle_overrides.call_deferred(node)

func _apply_vehicle_overrides(vehicle) -> void:
	if tuning == null or vehicle == null or not is_instance_valid(vehicle):
		return
	for prop in tuning.overrides.vehicle:
		vehicle.set(prop, tuning.overrides.vehicle[prop])
	var ctrl = vehicle.get_controller() if vehicle.has_method(&"get_controller") else null
	if ctrl:
		for prop in tuning.overrides.controller:
			ctrl.set(prop, tuning.overrides.controller[prop])

## Live re-apply after an editor change (existing vehicles get the new value).
func apply_combat_overrides_now() -> void:
	for v in get_tree().get_nodes_in_group(&"vehicles"):
		_apply_vehicle_overrides(v)

## Car-tuner edit landed on a .tres singleton: any live car of that id
## re-reads it (no-op on the settings screen — no vehicles there; kept for
## any future in-game host). set_stats is a full re-init (repaint + HP
## refill) — accepted dev behavior, same as F1's car picker.
func reapply_car_stats(id: String) -> void:
	for v in get_tree().get_nodes_in_group(&"vehicles"):
		if v.get("stats") != null and String(v.stats.id) == id and v.has_method(&"set_stats"):
			v.set_stats(v.stats)

## MP standardization hook (see docs/net_dev_request_data_tuning.md): pushes
## roster-truth values back onto every car .tres WITHOUT touching the player's
## saved tuning file — net dev calls this at session start for both roles so
## matches always run pristine data. Overrides re-apply on next boot (SP).
func suspend_data_tuning() -> void:
	if car_deck != null:
		car_deck.restore_baselines()
