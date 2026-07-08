extends Node
## Dev mode — toggled from the settings menu (DEVELOPER MODE row) and persisted
## with the other settings; the old `--dev` cmdline flag is retired. Gates
## dev-only tools: the F1 handling dashboard, the F2 tuning editor, and the
## tuning deck (user://tuning.json overrides, boot-applied here).

const TuningDeck := preload("res://game/tuning_deck.gd")

var enabled := false
var tuning = null  # TuningDeck instance while dev mode is on

func _ready() -> void:
	# Dev sits BEFORE GameState in the autoload order, so its settings haven't
	# loaded yet — sync after the boot frame settles.
	_sync_from_settings.call_deferred()

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
	# Same hermetic rule as settings: live tuning overrides never leak into
	# headless gate runs (they mutate shared weapon resources process-wide).
	if DisplayServer.get_name() != "headless":
		tuning.load_and_apply()
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
