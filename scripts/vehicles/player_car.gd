extends CharacterBody2D

## PlayerCar with strict 4-direction arcade movement
## WASD moves strictly up/down/left/right with acceleration/deceleration for 16-bit arcade feel
## Last key pressed wins; no diagonal movement; instant rotation snapping to cardinal directions

## Debug flag for vehicle tuning instrumentation
const DEBUG_VEHICLE_TUNING: bool = true
## Debug flag for collision damage calculations
const DEBUG_COLLISION_DAMAGE: bool = true
## Debug flag for 8-way movement system
const DEBUG_8WAY_MOVEMENT: bool = false

const VehicleHealth = preload("res://scripts/vehicles/vehicle_health.gd")

## StatRanges resource caching
const STAT_RANGE_PATH := "res://data/balance/StatsRanges.tres"
static var _stat_ranges

@export var max_speed: float = 200.0
@export var acceleration: float = 800.0
@export var deceleration: float = 600.0
@export var brake_force: float = 1200.0  ## Strong deceleration when pressing opposite to current movement
@export var bullet_scene: PackedScene
@export var fire_rate: float = 20.0
@export var bounce_damp: float = 0.55
@export var bounce_push: float = 80.0
@export var min_bounce_velocity: float = 5.0

## Movement system configuration
@export var diagonal_speed_scale: float = 1.0  ## Speed multiplier for diagonal movement (1.0 = equal speed)

## Realistic vehicle physics configuration
@export var straightaway_lateral_friction: float = 0.95  ## High friction when driving straight (0.95 = minimal drift)
@export var turning_lateral_friction: float = 0.7  ## Lower friction when turning (allows controlled drift)
@export var drift_speed_threshold: float = 100.0  ## Speed above which drift physics engage
@export var turning_angle_threshold: float = 0.1  ## Minimum turning input to trigger drift physics

## Collision immunity system to prevent damage spam
@export var collision_immunity_duration: float = 0.15
var _collision_immunity_timer: float = 0.0

## Constants for stat scaling and terrain modifiers
const STAT_SCALE = {
	"max_speed": Vector2(170, 285),
	"acceleration": Vector2(450, 1200),
	"deceleration": Vector2(320, 800),
	"brake_force": Vector2(900, 1500),
	"handling_lock": Vector2(0.22, 0.05),
	"handling_drag": Vector2(1.25, 0.7),
	"handling_snap": Vector2(0.35, 0.9),
	"armor": Vector2(55, 155),
	"special_power": Vector2(0.8, 1.2)
}

## Enhanced drift factor constants for dramatic sliding physics
const DRIFT_FACTORS = {
	"low_speed": Vector2(0.05, 0.15),    # Min/max drift at low speeds (tight control)
	"high_speed": Vector2(0.15, 0.85),   # Min/max drift at high speeds (dramatic sliding)
	"high_speed_boost": Vector2(0.25, 1.2), # Extra drift multiplier above 70% speed
	"slip_angle_sensitivity": 2.5,       # How aggressively slip angle affects drift
	"terrain_multipliers": {
		"track": 0.7,        # Reduced drift on track
		"sand": 1.5,         # More drift on sand/grass
		"snow": 2.0,         # Much more drift on snow
		"ice": 2.5           # Extreme drift on ice/water
	}
}

const TERRAIN_MODIFIERS = {
	"terrain_track": {"accel": 1.0, "speed": 1.0, "handling": 1.0, "brake": 1.0},
	"terrain_sand": {"accel": 0.2, "speed": 0.5, "handling": 0.12, "brake": 0.35},
	"terrain_grass": {"accel": 0.5, "speed": 0.75, "handling": 0.45, "brake": 0.8},
	"terrain_ice": {"accel": 0.3, "speed": 1.3, "handling": 0.08, "brake": 0.25},
	"terrain_snow": {"accel": 0.25, "speed": 0.5, "handling": 0.2, "brake": 0.4},
	"terrain_water": {"accel": 0.25, "speed": 1.4, "handling": 0.05, "brake": 0.15}
}

# Missile spawn tuning
const MISSILE_FORWARD_OFFSET: float = 36.0

## Weapon damage profile constants (4× scaled from design)
const DAMAGE_PROFILE = {
	"MACHINE_GUN": 8,
	"HOMING_MISSILE": 40,
	"FIRE_MISSILE": 80,
	"POWER_MISSILE": 120,
	"BOUNCE_BOMB_DIRECT": 60,
	"BOUNCE_BOMB_BOUNCED": 160,
	"LAND_MINE": 80
}

## Debug logging helper for missile system
func _missile_debug_log(message: String):
	var timestamp = Time.get_ticks_msec() / 1000.0
	var log_entry = "[%.3f] %s\n" % [timestamp, message]
	var file = FileAccess.open("/tmp/missile_debug.log", FileAccess.WRITE_READ)
	if file:
		file.seek_end()  # Append to end of file
		file.store_string(log_entry)
		file.close()
	print("[%.3f] %s" % [timestamp, message])  # Fixed: removed strip() call

var _next_fire_time := 0.0
var current_direction := Vector2.ZERO  ## Active input direction (cardinal or diagonal)
var last_facing_direction := Vector2.UP  ## Persists for firing/visuals when no input
var selected_profile: Dictionary = {}  ## Selected character profile from roster

## Realistic vehicle physics state
var _previous_direction := Vector2.ZERO  ## Previous frame direction for turn detection
var _is_turning := false  ## Whether the vehicle is currently turning
var _turn_intensity := 0.0  ## How sharp the current turn is (0.0 = straight, 1.0 = sharp turn)


## Weapon selection system variables
var available_weapons: Array[String] = []  ## Available secondary weapons (excluding machine gun)
var selected_weapon_index: int = 0  ## Current weapon index
var selected_weapon_type: String = ""  ## Current selected weapon name

# Missile inventory & cooldown
var missile_count: int = 3
var missile_cooldown: float = 3.0
var _last_missile_time: float = -999.0
var _muzzle_last_primary: bool = false
var _muzzle_last_secondary: bool = false

## Health system variables
var vehicle_health
var _cached_armor_stat: int = 5  ## Cache 1-10 armor for collision calculations

## Enhanced handling variables
var _derived_stats: Dictionary = {}  ## Cached derived stats for armor/special_power
var _direction_lock_timer: float = 0.0  ## Timer preventing rapid direction changes
var _handling_lock_duration: float = 0.1  ## Duration to lock direction changes
var _lateral_drag_multiplier: float = 1.0  ## Handling-based drag on turns
var _snap_smoothing_factor: float = 0.5  ## Visual rotation smoothing factor

## Mass-based inertia variables
var _mass_scaled: bool = false  ## Guard against double-application of mass scaling
var _base_stats: Dictionary = {}  ## Cache base stats before mass scaling for debug

## Terrain tracking variables
var _current_terrain_modifiers: Dictionary = {"accel": 1.0, "speed": 1.0, "handling": 1.0, "brake": 1.0}
var _target_terrain_modifiers: Dictionary = {"accel": 1.0, "speed": 1.0, "handling": 1.0, "brake": 1.0}
var _start_terrain_modifiers: Dictionary = {"accel": 1.0, "speed": 1.0, "handling": 1.0, "brake": 1.0}
var _terrain_transition_time: float = 0.2  ## Dynamic time to interpolate terrain changes
var _terrain_transition_timer: float = 0.0
var _terrain_transition_elapsed: float = 0.0
var _effective_max_speed: float = 0.0  ## Cached speed cap after terrain modifiers
var _current_terrain_type: String = "terrain_track"  ## Track current terrain for smart transitions
var _previous_terrain_type: String = "terrain_track"  ## Track previous terrain for transition logic
var _transition_curve_type: String = "smooth"  ## Current transition curve type for asymmetric easing

const CORE_INPUT_BINDINGS := {
	"move_up": [
		{"type": "key", "code": Key.KEY_W},
		{"type": "key", "code": Key.KEY_UP},
		{"type": "joy_button", "button": JOY_BUTTON_DPAD_UP},
		{"type": "joy_axis", "axis": JOY_AXIS_LEFT_Y, "value": -1.0}
	],
	"move_down": [
		{"type": "key", "code": Key.KEY_S},
		{"type": "key", "code": Key.KEY_DOWN},
		{"type": "joy_button", "button": JOY_BUTTON_DPAD_DOWN},
		{"type": "joy_axis", "axis": JOY_AXIS_LEFT_Y, "value": 1.0}
	],
	"move_left": [
		{"type": "key", "code": Key.KEY_A},
		{"type": "key", "code": Key.KEY_LEFT},
		{"type": "joy_button", "button": JOY_BUTTON_DPAD_LEFT},
		{"type": "joy_axis", "axis": JOY_AXIS_LEFT_X, "value": -1.0}
	],
	"move_right": [
		{"type": "key", "code": Key.KEY_D},
		{"type": "key", "code": Key.KEY_RIGHT},
		{"type": "joy_button", "button": JOY_BUTTON_DPAD_RIGHT},
		{"type": "joy_axis", "axis": JOY_AXIS_LEFT_X, "value": 1.0}
	],
	"fire_primary": [
		{"type": "key", "code": Key.KEY_SPACE},
		{"type": "mouse_button", "button": MOUSE_BUTTON_LEFT}
	],
	"fire_special": [
		{"type": "mouse_button", "button": MOUSE_BUTTON_RIGHT},
		{"type": "key", "code": Key.KEY_K}
	]
}

@onready var muzzle := $Muzzle
@onready var muzzle_flash := $Visuals/MuzzleFlash
@onready var visuals := $Visuals
@onready var collision_sensor := $CollisionSensor
@onready var vehicle_proximity_detector := $VehicleProximityDetector
@onready var body_color := $Visuals/BodyColor
@onready var accent_color := $Visuals/AccentColor

func _ready():
	print("PlayerCar initialized")
	collision_sensor.area_entered.connect(_on_collision_sensor_area_entered)
	collision_sensor.area_exited.connect(_on_collision_sensor_area_exited)

	# Initialize vehicle proximity detection for fallback separation
	vehicle_proximity_detector.body_entered.connect(_on_vehicle_proximity_entered)
	vehicle_proximity_detector.body_exited.connect(_on_vehicle_proximity_exited)

	# Initialize vehicle health component
	vehicle_health = VehicleHealth.new()
	add_child(vehicle_health)
	vehicle_health.died.connect(_on_vehicle_died)

	# Initialize weapon selection system
	_initialize_weapon_selection()

	# Clear any existing debug log and start fresh
	var file = FileAccess.open("/tmp/missile_debug.log", FileAccess.WRITE)
	if file:
		file.store_string("")  # Clear the file
		file.close()

	_missile_debug_log("PLAYER_CAR: Ready - weapon_type='%s', missile_count=%d" % [selected_weapon_type, missile_count])

	# Ensure critical input actions are present even if project settings were corrupted
	_ensure_core_input_bindings()

	# Quick health check for regression detection
	_quick_regression_check()

	if SelectionState.has_selection():
		selected_profile = SelectionState.get_selection()
		var car_name = selected_profile.get("car_name", "Unknown")
		var driver_name = selected_profile.get("driver_name", "Unknown")
		print("Selected car: ", car_name, " (driver: ", driver_name, ")")
		_apply_character_stats()
	else:
		print("No character selected, using fallback (Bumper)")
		_load_fallback_character()
		_apply_character_stats()

	if DEBUG_VEHICLE_TUNING:
		_verify_input_mappings()
	
	# Hook muzzle flash visibility changes so external effects (UI triggering muzzle) can drive missiles
	if muzzle_flash and muzzle_flash.has_signal("visibility_changed"):
		muzzle_flash.visibility_changed.connect(_on_muzzle_visibility_changed)


func _on_muzzle_visibility_changed():
	# Ignore muzzle flashes that were caused by primary fire
	if _muzzle_last_primary:
		return

	# When muzzle flash becomes visible, attempt to fire a missile if the selected weapon is a missile type
	print("[PlayerCar] muzzle visibility changed. visible=", muzzle_flash.visible, " selected=", selected_weapon_type)
	if muzzle_flash.visible and selected_weapon_type in ["POWER_MISSILE", "FIRE_MISSILE", "HOMING_MISSILE"]:
		if can_fire_missile():
			print("[PlayerCar] muzzle visibility triggered missile attempt")
			fire_missile()
		else:
			print("[PlayerCar] muzzle visibility: missile not ready or out of ammo")
## Load fallback character when SelectionState has no selection
func _load_fallback_character():
	var roster_path = "res://assets/data/roster.json"
	if not FileAccess.file_exists(roster_path):
		push_error("PlayerCar: Cannot load fallback - roster file not found")
		return

	var file = FileAccess.open(roster_path, FileAccess.READ)
	if file == null:
		push_error("PlayerCar: Cannot load fallback - failed to open roster file")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_text) != OK:
		push_error("PlayerCar: Cannot load fallback - invalid JSON in roster file")
		return

	var roster_data = json.data
	if not roster_data is Dictionary:
		push_error("PlayerCar: Cannot load fallback - invalid roster format")
		return

	var characters = roster_data.get("characters", [])
	if characters.size() > 0:
		selected_profile = characters[0]  # Use first character (Bumper)
		print("Loaded fallback character: ", selected_profile.get("car_name", "Unknown"))
	else:
		push_error("PlayerCar: Cannot load fallback - no characters in roster")

## Initialize weapon selection system with available secondary weapons
func _initialize_weapon_selection():
	# Load available weapons from DAMAGE_PROFILE (excluding MACHINE_GUN)
	available_weapons = ["HOMING_MISSILE", "FIRE_MISSILE", "POWER_MISSILE", "BOUNCE_BOMB_DIRECT", "LAND_MINE"]
	selected_weapon_index = 0
	if available_weapons.size() > 0:
		selected_weapon_type = available_weapons[selected_weapon_index]
		print("Weapon system initialized. Selected: ", selected_weapon_type)
	else:
		selected_weapon_type = ""

## Select next weapon in the list (scroll up)
func select_next_weapon():
	if available_weapons.size() == 0:
		return

	selected_weapon_index = (selected_weapon_index + 1) % available_weapons.size()
	selected_weapon_type = available_weapons[selected_weapon_index]
	print("Selected weapon: ", selected_weapon_type)

## Select previous weapon in the list (scroll down)
func select_prev_weapon():
	if available_weapons.size() == 0:
		return

	selected_weapon_index = (selected_weapon_index - 1) % available_weapons.size()
	if selected_weapon_index < 0:
		selected_weapon_index = available_weapons.size() - 1
	selected_weapon_type = available_weapons[selected_weapon_index]
	print("Selected weapon: ", selected_weapon_type)

## Verify input mappings are properly loaded (debug helper)
func _verify_input_mappings():
	print("=== INPUT MAPPING VERIFICATION ===")
	for action_name in CORE_INPUT_BINDINGS.keys():
		var events = InputMap.action_get_events(action_name)
		print(action_name, "has", events.size(), "events")
		for event in events:
			if event is InputEventKey:
				print("  - Key (physical): ", event.physical_keycode)
			elif event is InputEventJoypadButton:
				print("  - Joypad button: ", event.button_index)
			elif event is InputEventJoypadMotion:
				print("  - Joypad axis: ", event.axis, " value: ", event.axis_value)
			elif event is InputEventMouseButton:
				print("  - Mouse button: ", event.button_index)
	print("=== END VERIFICATION ===")

func _ensure_core_input_bindings():
	for action_name in CORE_INPUT_BINDINGS.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name, 0.5)

		for definition in CORE_INPUT_BINDINGS[action_name]:
			if not _action_has_binding(action_name, definition):
				var event = _create_input_event(definition)
				if event:
					InputMap.action_add_event(action_name, event)

func _action_has_binding(action_name: String, definition: Dictionary) -> bool:
	if not InputMap.has_action(action_name):
		return false

	for event in InputMap.action_get_events(action_name):
		match definition.get("type", ""):
			"key":
				if event is InputEventKey and event.physical_keycode == definition.get("code", -1):
					return true
			"joy_button":
				if event is InputEventJoypadButton and event.button_index == definition.get("button", -1):
					return true
			"joy_axis":
				if event is InputEventJoypadMotion \
						and event.axis == definition.get("axis", -1) \
						and is_equal_approx(event.axis_value, definition.get("value", 0.0)):
					return true
			"mouse_button":
				if event is InputEventMouseButton and event.button_index == definition.get("button", -1):
					return true
	return false

func _create_input_event(definition: Dictionary) -> InputEvent:
	match definition.get("type", ""):
		"key":
			var key_event := InputEventKey.new()
			key_event.physical_keycode = definition.get("code", 0)
			return key_event
		"joy_button":
			var joy_event := InputEventJoypadButton.new()
			joy_event.button_index = definition.get("button", 0)
			return joy_event
		"joy_axis":
			var axis_event := InputEventJoypadMotion.new()
			axis_event.axis = definition.get("axis", 0)
			axis_event.axis_value = definition.get("value", 0.0)
			return axis_event
		"mouse_button":
			var mouse_event := InputEventMouseButton.new()
			mouse_event.button_index = definition.get("button", 0)
			return mouse_event
	return null

## Quick regression check to catch common failure patterns early
func _quick_regression_check():
	if not OS.is_debug_build():
		return

	var issues = []

	# Check 1: Verify WASD input actions are working
	var wasd_actions = ["move_up", "move_down", "move_left", "move_right"]
	for action in wasd_actions:
		if not InputMap.has_action(action) or InputMap.action_get_events(action).size() == 0:
			issues.append("REGRESSION: Missing or empty input action: " + action)

	# Check 2: Verify we have a valid character selection (not falling back to red car)
	if not SelectionState.has_selection():
		var roster_path = "res://assets/data/roster.json"
		if not FileAccess.file_exists(roster_path):
			issues.append("REGRESSION: Missing roster file - will cause red car fallback")

	# Check 3: Verify missile system is accessible
	var missile_scene_path = "res://scenes/weapons/Missile.tscn"
	if not ResourceLoader.exists(missile_scene_path):
		issues.append("REGRESSION: Missing missile scene")

	if issues.size() > 0:
		print("🚨 QUICK REGRESSION CHECK FAILED 🚨")
		for issue in issues:
			print("  ❌ ", issue)
		print("🚨 This may cause 'red car + no WASD' behavior 🚨")
	else:
		print("✅ Quick regression check passed")

## Fire the currently selected secondary weapon (placeholder implementation)
func fire_selected_weapon():
	_missile_debug_log("FIRE_SELECTED: Called - weapon_type='%s', missile_count=%d" % [selected_weapon_type, missile_count])

	if selected_weapon_type == "":
		_missile_debug_log("FIRE_SELECTED: No weapon selected")
		return

	# Route to specific weapon implementations
	# Handle all three missile types: POWER, FIRE, and HOMING
	if selected_weapon_type in ["POWER_MISSILE", "FIRE_MISSILE", "HOMING_MISSILE"]:
		_missile_debug_log("FIRE_SELECTED: Missile weapon detected - checking can_fire_missile()")
		if can_fire_missile():
			_missile_debug_log("FIRE_SELECTED: Can fire missile - calling fire_missile()")
			fire_missile()
		else:
			_missile_debug_log("FIRE_SELECTED: Cannot fire missile - count=%d, cooldown=%.2f" % [missile_count, (Time.get_ticks_msec() / 1000.0) - _last_missile_time])
		return

	# Fallback placeholder for other secondary weapons
	var damage = DAMAGE_PROFILE.get(selected_weapon_type, 0)
	print("Firing ", selected_weapon_type, " (damage: ", damage, ") - PLACEHOLDER")

	# Visual effect for non-missile secondaries
	_show_weapon_effect()

## Show placeholder visual effect for secondary weapon firing
func _show_weapon_effect():
	# Intentionally no-op for missile firing; muzzle visuals removed to avoid
	# interfering with input routing. If you want a visual later, add an
	# effect node and trigger it explicitly here.
	return

## Missile helpers
func can_fire_missile() -> bool:
	var now = Time.get_ticks_msec() / 1000.0
	return missile_count > 0 and (now - _last_missile_time) >= missile_cooldown

func _weapon_type_to_missile_type(weapon_name: String):
	# Convert weapon string names to safe missile type constants
	# These constants match the ones defined in missile.gd (TYPE_POWER=0, TYPE_FIRE=1, TYPE_HOMING=2)
	match weapon_name:
		"POWER_MISSILE":
			return 0  # TYPE_POWER
		"FIRE_MISSILE":
			return 1  # TYPE_FIRE
		"HOMING_MISSILE":
			return 2  # TYPE_HOMING
		_:
			return 1  # TYPE_FIRE default fallback

func fire_missile():
	# Guard
	if not can_fire_missile():
		_missile_debug_log("FIRE_MISSILE: Cannot fire - count=%d, cooldown=%.2f" % [missile_count, (Time.get_ticks_msec() / 1000.0) - _last_missile_time])
		return

	_missile_debug_log("FIRE_MISSILE: Starting fire sequence - count=%d->%d, weapon=%s" % [missile_count, missile_count - 1, selected_weapon_type])

	missile_count -= 1
	_last_missile_time = Time.get_ticks_msec() / 1000.0

	# Load missile scene
	var missile_scene = preload("res://scenes/weapons/Missile.tscn")

	# Calculate proper muzzle position (front of car)
	var muzzle_position = global_position
	if has_node("Muzzle"):
		muzzle_position = $Muzzle.global_position
	else:
		# Fallback: calculate front of car based on direction
		var forward_dir = current_direction if current_direction != Vector2.ZERO else last_facing_direction
		muzzle_position = global_position + forward_dir.normalized() * 35.0  # 35 pixels forward

	# Determine direction (like bullets do)
	var direction = current_direction if current_direction != Vector2.ZERO else last_facing_direction
	direction = direction.normalized()

	# Try to access GameManager directly (it's configured as autoload)
	var gm = null
	if Engine.has_singleton("GameManager"):
		gm = GameManager
	else:
		gm = get_node_or_null("/root/GameManager")

	if gm and gm.has_method("spawn_missile_simple"):
		var missile_type = _weapon_type_to_missile_type(selected_weapon_type)
		var missile = gm.spawn_missile_simple(missile_scene, muzzle_position, direction, self, missile_type)
		return

	# Fallback: simple instantiation like bullets
	var missile = missile_scene.instantiate()
	missile.owner_node = self
	missile.global_position = muzzle_position  # Use muzzle position, not car center
	missile.rotation = direction.angle()
	missile.velocity = direction * 1400.0
	missile.missile_type = _weapon_type_to_missile_type(selected_weapon_type)

	# Find the correct game root by traversing up from player
	var game_root = _find_game_root()
	if game_root:
		game_root.add_child(missile)
	else:
		push_error("Could not find game root for missile spawning")
		missile.queue_free()

## Find the proper game root by traversing up from player
func _find_game_root() -> Node2D:
	# Method 1: Try to find GameRoot by traversing up from player
	var current = self.get_parent()
	while current:
		if current.name == "GameRoot":
			return current
		current = current.get_parent()

	# Method 2: Try current scene
	var current_scene = get_tree().current_scene
	if current_scene:
		# Look for SubViewport structure
		var viewport = _find_subviewport(current_scene)
		if viewport:
			for child in viewport.get_children():
				if child.name == "GameRoot" and child is Node2D:
					return child

	# Method 3: Search in Main scene structure
	var main_scene = get_tree().get_root().get_node_or_null("Main")
	if main_scene:
		var game_root = main_scene.get_node_or_null("GameViewport/SubViewport/GameRoot")
		if game_root and game_root is Node2D:
			return game_root

	# Fallback to player's parent
	return self.get_parent()

## Find SubViewport in scene tree
func _find_subviewport(node: Node) -> SubViewport:
	if node is SubViewport:
		return node
	for child in node.get_children():
		var result = _find_subviewport(child)
		if result:
			return result
	return null

## Nudge spawned missile forward out of owner's collision if necessary
func _nudge_missile_clear(missile_node: Node2D) -> void:
	if not missile_node:
		return
	if not is_instance_valid(self):
		return
	# Cast a short segment forward and move missile until it's no longer overlapping owner's shape
	var forward = Vector2.UP.rotated(rotation)
	var check_pos = missile_node.global_position
	var max_attempts = 4
	var attempt = 0
	while attempt < max_attempts:
		# Use simple distance check against owner global position to heuristically nudge out
		var dist = check_pos.distance_to(self.global_position)
		# If missile is too close (< half vehicle width), nudge it forward
		if dist < MISSILE_FORWARD_OFFSET * 0.75:
			check_pos += forward * 8
			missile_node.global_position = check_pos
		else:
			break
		attempt += 1

## Debug logging helper with consistent prefix
func _debug_log(msg: String):
	if DEBUG_VEHICLE_TUNING:
		print("[VehicleTuning] ", msg)

## Load StatRanges resource with caching and fallback
func _get_stat_ranges():
	if _stat_ranges == null:
		var loaded_resource = load(STAT_RANGE_PATH)
		if loaded_resource is Resource:
			_stat_ranges = loaded_resource
		else:
			_debug_log("Failed to load StatRanges resource, using fallback")
			_stat_ranges = null
	return _stat_ranges

## Apply custom curve to stat values for enhanced low/high differences
func _apply_stat_curve(stat_value: float, curve_type: String) -> float:
	# Normalize stat_value from 1-10 scale to 0-1
	var normalized = (stat_value - 1) / 9.0
	normalized = clamp(normalized, 0.0, 1.0)

	match curve_type:
		"acceleration":
			# More responsive acceleration curve - still dramatic but not brutal
			return pow(normalized, 0.4)
		"deceleration":
			# Align with acceleration harshness
			return pow(normalized, 0.3)
		"brake":
			# Much more curved for extreme differences
			return pow(normalized, 0.35)
		"handling":
			# Catastrophically punishing for poor handling
			return pow(normalized, 0.2)
		"speed":
			# Massive speed gaps
			return pow(normalized, 0.35)
		_:
			# Default linear interpolation for armor/special
			return normalized

## Simple ease-out helper for throttle curves
func _ease_out(value: float, exponent: float = 0.5) -> float:
	value = clamp(value, 0.0, 1.0)
	return pow(value, exponent)

## Compute handling profile based on stat value and terrain factors
func _compute_handling_profile(stat_value: float, terrain_factor: float) -> void:
	# Apply stat curve to handling value
	var handling_curve = _apply_stat_curve(stat_value, "handling")

	# Get stat ranges
	var stat_ranges = _get_stat_ranges()

	# Apply terrain factor to handling curve
	var effective_handling = handling_curve * terrain_factor
	effective_handling = clamp(effective_handling, 0.0, 1.0)

	# Update handling variables with terrain consideration
	if stat_ranges:
		_handling_lock_duration = lerp(stat_ranges.handling_lock_min, stat_ranges.handling_lock_max, effective_handling)
		_lateral_drag_multiplier = lerp(stat_ranges.handling_drag_min, stat_ranges.handling_drag_max, effective_handling)
		_snap_smoothing_factor = lerp(stat_ranges.handling_snap_min, stat_ranges.handling_snap_max, effective_handling)
	else:
		# Fallback to STAT_SCALE
		_handling_lock_duration = lerp(STAT_SCALE.handling_lock.x, STAT_SCALE.handling_lock.y, effective_handling)
		_lateral_drag_multiplier = lerp(STAT_SCALE.handling_drag.x, STAT_SCALE.handling_drag.y, effective_handling)
		_snap_smoothing_factor = lerp(STAT_SCALE.handling_snap.x, STAT_SCALE.handling_snap.y, effective_handling)

	_debug_log("Handling profile updated - Lock: " + str(_handling_lock_duration) + ", Drag: " + str(_lateral_drag_multiplier) + ", Terrain: " + str(terrain_factor))

func _apply_character_stats():
	if selected_profile.is_empty():
		print("Warning: No character profile selected, using default stats")
		_apply_default_colors()
		return

	var stats = selected_profile.get("stats", {})
	if stats.is_empty():
		print("Warning: Character profile missing stats, using default values")
		_apply_default_colors()
		return

	# Get StatRanges resource or fall back to STAT_SCALE
	var stat_ranges = _get_stat_ranges()

	# Extract 1-10 scale stats
	var accel_stat = stats.get("acceleration", 5)
	var speed_stat = stats.get("top_speed", 5)
	var handling_stat = stats.get("handling", 5)
	var armor_stat = stats.get("armor", 5)
	var special_stat = stats.get("special_power", 5)

	# Apply custom curves to normalize stats (0-1)
	var accel_curve = _apply_stat_curve(accel_stat, "acceleration")
	var speed_curve = _apply_stat_curve(speed_stat, "speed")
	var handling_curve = _apply_stat_curve(handling_stat, "handling")
	var armor_curve = _apply_stat_curve(armor_stat, "armor")
	var special_curve = _apply_stat_curve(special_stat, "special")
	var decel_curve = _apply_stat_curve(accel_stat, "deceleration")  # Use accel stat for decel
	var brake_curve = _apply_stat_curve(accel_stat, "brake")  # Use accel stat for brake

	# Apply stat scaling using resource or fallback
	if stat_ranges:
		max_speed = lerp(stat_ranges.max_speed_min, stat_ranges.max_speed_max, speed_curve)
		acceleration = lerp(stat_ranges.accel_min, stat_ranges.accel_max, accel_curve)
		deceleration = lerp(stat_ranges.decel_min, stat_ranges.decel_max, decel_curve)
		brake_force = lerp(stat_ranges.brake_min, stat_ranges.brake_max, brake_curve)

		# Enhanced handling variables using curves
		_handling_lock_duration = lerp(stat_ranges.handling_lock_min, stat_ranges.handling_lock_max, handling_curve)
		_lateral_drag_multiplier = lerp(stat_ranges.handling_drag_min, stat_ranges.handling_drag_max, handling_curve)
		_snap_smoothing_factor = lerp(stat_ranges.handling_snap_min, stat_ranges.handling_snap_max, handling_curve)

		# Cache derived stats
		_derived_stats = {
			"armor": lerp(stat_ranges.armor_min, stat_ranges.armor_max, armor_curve),
			"special_power": lerp(stat_ranges.special_min, stat_ranges.special_max, special_curve)
		}
	else:
		# Fallback to STAT_SCALE constants
		max_speed = lerp(STAT_SCALE.max_speed.x, STAT_SCALE.max_speed.y, speed_curve)
		acceleration = lerp(STAT_SCALE.acceleration.x, STAT_SCALE.acceleration.y, accel_curve)
		deceleration = lerp(STAT_SCALE.deceleration.x, STAT_SCALE.deceleration.y, decel_curve)
		brake_force = lerp(STAT_SCALE.brake_force.x, STAT_SCALE.brake_force.y, brake_curve)

		_handling_lock_duration = lerp(STAT_SCALE.handling_lock.x, STAT_SCALE.handling_lock.y, handling_curve)
		_lateral_drag_multiplier = lerp(STAT_SCALE.handling_drag.x, STAT_SCALE.handling_drag.y, handling_curve)
		_snap_smoothing_factor = lerp(STAT_SCALE.handling_snap.x, STAT_SCALE.handling_snap.y, handling_curve)

		_derived_stats = {
			"armor": lerp(STAT_SCALE.armor.x, STAT_SCALE.armor.y, armor_curve),
			"special_power": lerp(STAT_SCALE.special_power.x, STAT_SCALE.special_power.y, special_curve)
		}

	# Cache base stats before mass scaling for debug
	_base_stats = {
		"max_speed": max_speed,
		"acceleration": acceleration,
		"deceleration": deceleration,
		"brake_force": brake_force,
		"handling_lock": _handling_lock_duration
	}

	# Configure health system with armor stat and cache for collision calculations
	_cached_armor_stat = armor_stat
	if vehicle_health:
		vehicle_health.configure_from_stats(stats)

	# Apply mass-based inertia scaling (only once)
	if not _mass_scaled and vehicle_health:
		_apply_mass_scaling()

	# Apply character colors
	_apply_character_colors()

	_effective_max_speed = max_speed

	# Debug logging
	_debug_log("Applied stats - Max Speed: " + str(max_speed) + ", Acceleration: " + str(acceleration) + ", Handling Lock: " + str(_handling_lock_duration))
	_debug_log("Derived stats - Armor: " + str(_derived_stats.armor) + ", Special Power: " + str(_derived_stats.special_power))
	_debug_log("Stat curves - Accel: " + str(accel_curve) + ", Speed: " + str(speed_curve) + ", Handling: " + str(handling_curve))

	# Roster stat dump for tuning (temporary debug)
	if DEBUG_VEHICLE_TUNING:
		_debug_roster_stats()

## Apply mass-based inertia scaling to stats
func _apply_mass_scaling():
	if _mass_scaled:
		return

	var mass_scalar = vehicle_health.get_mass_scalar()

	# Scale dynamics - heavy vehicles approaching glacial speeds
	acceleration *= 1.0 / mass_scalar
	deceleration *= 1.0 / lerp(1.0, mass_scalar, 0.95)
	brake_force *= 1.0 / lerp(1.0, mass_scalar, 0.95)

	# Minimum values for safety but allowing more dramatic differences
	acceleration = max(acceleration, 80.0)
	deceleration = max(deceleration, 50.0)
	brake_force = max(brake_force, 150.0)

	# Handling resistance - heavy vehicles glacially slow turning
	_handling_lock_duration *= lerp(1.0, mass_scalar, 0.9)

	_mass_scaled = true

	_debug_log("Mass scaling applied - Mass scalar: " + str(mass_scalar) + ", Final accel: " + str(acceleration) + ", Final brake: " + str(brake_force))

## Debug function to dump all roster character stats (temporary for tuning)
func _debug_roster_stats():
	var roster_path = "res://assets/data/roster.json"
	if not FileAccess.file_exists(roster_path):
		return

	var file = FileAccess.open(roster_path, FileAccess.READ)
	if file == null:
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_text) != OK:
		return

	var roster_data = json.data
	if not roster_data is Dictionary:
		return

	var characters = roster_data.get("characters", [])
	print("\n=== ROSTER STAT ANALYSIS ===")

	for character in characters:
		var stats = character.get("stats", {})
		var car_name = character.get("car_name", "Unknown")
		var accel_stat = stats.get("acceleration", 5)
		var speed_stat = stats.get("top_speed", 5)
		var armor_stat = stats.get("armor", 5)

		# Calculate what this character's stats would be
		var accel_curve = _apply_stat_curve(accel_stat, "acceleration")
		var speed_curve = _apply_stat_curve(speed_stat, "speed")

		var stat_ranges = _get_stat_ranges()
		var computed_accel: float
		var computed_speed: float

		if stat_ranges:
			computed_accel = lerp(stat_ranges.accel_min, stat_ranges.accel_max, accel_curve)
			computed_speed = lerp(stat_ranges.max_speed_min, stat_ranges.max_speed_max, speed_curve)
		else:
			computed_accel = lerp(STAT_SCALE.acceleration.x, STAT_SCALE.acceleration.y, accel_curve)
			computed_speed = lerp(STAT_SCALE.max_speed.x, STAT_SCALE.max_speed.y, speed_curve)

		# Apply mass scaling
		var mass_scalar = lerp(0.8, 1.4, (armor_stat - 1) / 9.0)
		var final_accel = max(computed_accel / mass_scalar, 120.0)

		print("%s (accel:%d, speed:%d, armor:%d) -> Speed: %.0f, Accel: %.0f (base: %.0f), Mass: %.2f" % [
			car_name, accel_stat, speed_stat, armor_stat,
			computed_speed, final_accel, computed_accel, mass_scalar
		])

	print("=== END ROSTER ANALYSIS ===\n")

func get_effective_max_speed() -> float:
	return _effective_max_speed

func _apply_character_colors():
	var colors = selected_profile.get("colors", {})
	if colors.is_empty():
		print("Warning: Character profile missing colors, using default colors")
		_apply_default_colors()
		return

	var primary_hex = colors.get("primary", "")
	var accent_hex = colors.get("accent", "")

	if primary_hex.is_empty() or accent_hex.is_empty():
		print("Warning: Incomplete color data for character, using default colors")
		_apply_default_colors()
		return

	# Apply colors from hex strings
	body_color.color = Color.from_string(primary_hex, Color.RED)
	accent_color.color = Color.from_string(accent_hex, Color.CYAN)

	print("Applied colors - Primary: ", primary_hex, ", Accent: ", accent_hex)

func _apply_default_colors():
	# Fallback default colors when roster data is missing
	body_color.color = Color.RED
	accent_color.color = Color.CYAN
	print("Applied default colors due to missing roster data")

func _physics_process(delta):
	_update_terrain_modifiers(delta)
	_update_direction_lock_timer(delta)
	_update_collision_immunity_timer(delta)
	handle_input(delta)

	# Apply emergency separation as fallback system
	_apply_emergency_separation(delta)

	move_and_slide()
	_handle_slide_collisions()

	# Snap visual rotation to match movement direction (supports both 4-way and 8-way)
	if current_direction != Vector2.ZERO:
		var target_rotation = _calculate_visual_rotation(current_direction)
		if _snap_smoothing_factor < 1.0:
			visuals.rotation = lerp_angle(visuals.rotation, target_rotation, _snap_smoothing_factor * delta * 10.0)
		else:
			visuals.rotation = target_rotation

## Calculate visual rotation for movement direction
func _calculate_visual_rotation(direction: Vector2) -> float:
	if direction == Vector2.ZERO:
		return visuals.rotation

	# Base rotation calculation (+PI/2 because front points up at 0 rotation)
	var target_rotation = direction.angle() + PI / 2

	# Snap to 8-way directions (45° increments) for cleaner visuals
	target_rotation = round(target_rotation / (PI / 4)) * (PI / 4)

	if DEBUG_8WAY_MOVEMENT:
		var degrees = rad_to_deg(target_rotation)
		print("[8-way] Visual rotation: ", degrees, "° for direction ", direction)

	return target_rotation

## Check if a direction vector represents diagonal movement
func _is_diagonal_movement(direction: Vector2) -> bool:
	# Diagonal movement has both x and y components above a threshold
	return abs(direction.x) > 0.1 and abs(direction.y) > 0.1

## Update turning state based on direction changes
func _update_turning_state(new_direction: Vector2, delta: float):
	# Calculate angle change from previous frame
	var angle_change = 0.0
	if _previous_direction != Vector2.ZERO:
		angle_change = abs(_previous_direction.angle_to(new_direction))

	# Determine if we're turning based on angle change and current speed
	var current_speed = velocity.length()
	var is_changing_direction = angle_change > turning_angle_threshold
	var above_drift_threshold = current_speed > drift_speed_threshold

	_is_turning = is_changing_direction and above_drift_threshold
	_turn_intensity = clamp(angle_change / PI, 0.0, 1.0)  # Normalize to 0-1

	# Store current direction for next frame
	_previous_direction = new_direction

	if DEBUG_8WAY_MOVEMENT and _is_turning:
		print("[Physics] Turning detected - angle_change: %.3f, intensity: %.3f, speed: %.1f" % [angle_change, _turn_intensity, current_speed])

## Calculate effective lateral friction based on driving context
func _calculate_effective_lateral_friction() -> float:
	# Start with base friction values
	var base_friction = straightaway_lateral_friction if not _is_turning else turning_lateral_friction

	# Apply car stats modulation (handling affects lateral grip)
	var handling_modifier = 1.0
	if not selected_profile.is_empty():
		var stats = selected_profile.get("stats", {})
		var handling_stat = stats.get("handling", 5)
		var handling_curve = _apply_stat_curve(handling_stat, "handling")
		handling_modifier = lerp(0.7, 1.0, handling_curve)  # Poor handling = less grip

	# Apply terrain modifiers (ice = less friction, tarmac = more friction)
	var terrain_modifier = _current_terrain_modifiers.handling

	# Combine all factors
	var effective_friction = base_friction * handling_modifier * terrain_modifier

	# Speed-based reduction at very high speeds (realistic loss of control)
	var current_speed = velocity.length()
	if current_speed > drift_speed_threshold:
		var speed_factor = (current_speed - drift_speed_threshold) / drift_speed_threshold
		var speed_reduction = lerp(1.0, 0.8, clamp(speed_factor, 0.0, 1.0))
		effective_friction *= speed_reduction

	# Turn intensity affects friction (sharper turns = less grip)
	if _is_turning:
		var turn_reduction = lerp(1.0, 0.6, _turn_intensity)
		effective_friction *= turn_reduction

	# Clamp to reasonable range
	effective_friction = clamp(effective_friction, 0.1, 0.98)

	return effective_friction


func handle_input(delta):
	# Simple 8-way movement using Godot's built-in input vector
	var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# Update direction and turning state
	if input_vector.length() > 0.1:
		var new_direction = input_vector.normalized()

		# Detect turning by comparing with previous direction
		_update_turning_state(new_direction, delta)

		# Apply centripetal force for direction changes at speed
		if velocity.length() > 50.0 and current_direction != Vector2.ZERO and current_direction != new_direction:
			_apply_direction_change_physics(current_direction, new_direction)

		current_direction = new_direction
		last_facing_direction = new_direction

		if DEBUG_8WAY_MOVEMENT:
			var is_diagonal = _is_diagonal_movement(new_direction)
			print("[8-way] Movement: ", new_direction, " (input: ", input_vector, ", diagonal: ", is_diagonal, ", turning: ", _is_turning, ")")
	else:
		current_direction = Vector2.ZERO
		_is_turning = false
		_turn_intensity = 0.0

	# Apply movement based on current direction with terrain modifiers
	if current_direction == Vector2.ZERO:
		# No input - apply speed + terrain aware coasting
		var mass_scalar = vehicle_health.get_mass_scalar() if vehicle_health else 1.0
		var current_speed = velocity.length()
		var speed_ratio = current_speed / _effective_max_speed if _effective_max_speed > 0 else 0.0

		# Base coasting varies by mass
		var base_coast_factor = lerp(0.995, 0.985, mass_scalar)

		# Terrain-specific coasting rates: ice/water coast longer, sand/grass brake naturally
		var terrain_coast_modifier = 1.0
		if _current_terrain_modifiers.handling < 0.3:  # Ice/water terrain
			terrain_coast_modifier = 1.002  # Coast slightly longer
		elif _current_terrain_modifiers.handling > 0.7:  # Good grip terrain
			terrain_coast_modifier = 0.995  # Natural braking

		# Speed affects coasting - high speeds maintain better, low speeds drop off faster
		var speed_coast_modifier = lerp(0.98, 1.0, speed_ratio)

		var final_coast_factor = base_coast_factor * terrain_coast_modifier * speed_coast_modifier
		velocity *= final_coast_factor
	else:
		# Calculate desired velocity from current direction with terrain speed modifiers
		var effective_max_speed = max_speed * _current_terrain_modifiers.speed

		# Apply diagonal speed scaling when moving diagonally
		if _is_diagonal_movement(current_direction):
			var original_speed = effective_max_speed
			effective_max_speed *= diagonal_speed_scale
			if DEBUG_8WAY_MOVEMENT:
				print("[8-way] Applied diagonal speed scale: %.3f to max speed (%.1f -> %.1f)" % [diagonal_speed_scale, original_speed, effective_max_speed])

		_effective_max_speed = effective_max_speed
		var desired = current_direction * effective_max_speed

		# Debug output for movement vector validation
		if DEBUG_8WAY_MOVEMENT:
			var is_diagonal = _is_diagonal_movement(current_direction)
			print("[8-way] Movement vector: dir=", current_direction, " desired_speed=%.1f diagonal=%s" % [desired.length(), is_diagonal])

		# Determine if we're moving in the opposite direction (with guard for zero velocity)
		var opposite_direction = false
		if velocity.length() > 1.0:
			opposite_direction = current_direction.dot(velocity.normalized()) < 0

		# Choose acceleration rate based on direction with terrain modifiers
		var accel_rate: float
		var effective_accel_modifier = _current_terrain_modifiers.accel * _current_terrain_modifiers.handling
		if opposite_direction:
			accel_rate = brake_force * effective_accel_modifier * _current_terrain_modifiers.brake
		else:
			accel_rate = acceleration * effective_accel_modifier * _current_terrain_modifiers.speed

			# Apply low-speed acceleration boost for responsive feel (1.5-2.0x boost under 30% top speed)
			var current_speed = velocity.length()
			var speed_ratio = current_speed / _effective_max_speed
			if speed_ratio < 0.3:  # Under 30% of top speed
				var boost_factor = lerp(2.0, 1.0, speed_ratio / 0.3)  # 2.0x at 0 speed, 1.0x at 30% speed
				accel_rate *= boost_factor

		# Apply lateral drag when turning (if velocity and direction aren't aligned)
		if velocity.length() > 1.0:
			var alignment = abs(current_direction.dot(velocity.normalized()))
			if alignment < 0.9:  # Not perfectly aligned (turning)
				accel_rate *= _lateral_drag_multiplier

				# Enhanced turn alignment penalty based on handling and mass
				if not selected_profile.is_empty():
					var stats = selected_profile.get("stats", {})
					var handling_stat = stats.get("handling", 5)
					var handling_curve = _apply_stat_curve(handling_stat, "handling")
					var mass_scalar = vehicle_health.get_mass_scalar() if vehicle_health else 1.0

					var turn_factor = lerp(0.15, 1.0, handling_curve) / mass_scalar
					var turn_penalty = lerp(0.25, 1.0, turn_factor)
					accel_rate *= turn_penalty

		# Apply throttle curve for non-linear acceleration (only when not braking)
		var step_distance = accel_rate * delta
		if not opposite_direction:
			# Calculate normalized gap between current and desired speed
			var current_speed = velocity.length()
			var desired_speed = desired.length()
			if desired_speed > 0.0:
				var speed_gap = 1.0 - (current_speed / desired_speed)
				speed_gap = clamp(speed_gap, 0.0, 1.0)
				# Apply easing curve with dynamic throttle floor based on acceleration curve
				var eased_gap = _ease_out(speed_gap)
				# Get acceleration curve for dynamic throttle floor
				var accel_curve = 0.5  # Default fallback
				if not selected_profile.is_empty():
					var stats = selected_profile.get("stats", {})
					var accel_stat = stats.get("acceleration", 5)
					accel_curve = _apply_stat_curve(accel_stat, "acceleration")
				var throttle_floor = lerp(0.05, 0.75, accel_curve)
				var throttle_range = 1.0 - throttle_floor
				step_distance *= (throttle_floor + (eased_gap * throttle_range))  # Dynamic range based on accel curve

		# Apply force-based acceleration instead of direct velocity change
		var force = current_direction * step_distance
		velocity += force

		# Realistic vehicle physics: KillOrthogonalVelocity with context-aware lateral friction
		var mass_scalar = vehicle_health.get_mass_scalar() if vehicle_health else 1.0
		var current_speed = velocity.length()

		if current_speed > 1.0:
			# Decompose velocity into forward and lateral components based on current facing direction
			var forward_direction = current_direction if current_direction != Vector2.ZERO else last_facing_direction
			var right_direction = Vector2(forward_direction.y, -forward_direction.x)  # Perpendicular to forward

			# Calculate forward and lateral velocity components
			var forward_velocity = forward_direction * velocity.dot(forward_direction)
			var lateral_velocity = right_direction * velocity.dot(right_direction)
			var lateral_speed = lateral_velocity.length()

			# Apply context-aware lateral friction based on driving state
			var effective_lateral_friction = _calculate_effective_lateral_friction()

			# Kill orthogonal velocity (lateral friction) - higher = less drift
			var preserved_lateral = lateral_velocity * (1.0 - effective_lateral_friction)

			# Debug visualization for lateral friction
			if DEBUG_8WAY_MOVEMENT and lateral_speed > 5.0:
				print("[Physics] Lateral friction: %.2f, Speed: %.1f, Lateral: %.1f, Turning: %s" % [effective_lateral_friction, current_speed, lateral_speed, _is_turning])

			# Reconstruct velocity with controlled lateral momentum
			velocity = forward_velocity + preserved_lateral

		# Apply realistic momentum decay (was general momentum factor)
		var speed_ratio = current_speed / _effective_max_speed if _effective_max_speed > 0 else 0.0
		var base_coast_factor = lerp(0.992, 0.987, mass_scalar)  # Mass affects coasting
		var terrain_coast_factor = _current_terrain_modifiers.handling  # Terrain affects coasting
		var speed_coast_modifier = lerp(0.98, 1.0, speed_ratio)  # High speeds coast better
		var final_momentum_factor = base_coast_factor * terrain_coast_factor * speed_coast_modifier
		velocity *= final_momentum_factor

		# Clamp velocity magnitude to prevent overspeed
		if velocity.length() > effective_max_speed:
			velocity = velocity.normalized() * effective_max_speed

	# Primary weapon firing with rate limiting (Mouse1)
	if Input.is_action_pressed("fire_primary"):
		fire_primary_weapon()

	# Secondary weapon firing (Mouse2)
	if Input.is_action_just_pressed("fire_special"):
		_missile_debug_log("INPUT: fire_special detected - calling fire_selected_weapon()")
		fire_selected_weapon()

	# Weapon selection (Mouse scroll)
	if Input.is_action_just_pressed("weapon_next"):
		select_next_weapon()

	if Input.is_action_just_pressed("weapon_prev"):
		select_prev_weapon()


func fire_primary_weapon():
	# Check for null bullet scene
	if bullet_scene == null:
		print("Warning: bullet_scene not assigned!")
		return

	# Check fire rate cooldown (convert milliseconds to seconds)
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time < _next_fire_time:
		return

	# Create and configure bullet via GameManager
	var bullet = GameManager.spawn_bullet(bullet_scene, global_position, last_facing_direction, self)

	# Show muzzle flash and auto-hide after brief duration
	# Mark this muzzle flash as primary-caused so missile hook ignores it
	_muzzle_last_primary = true
	muzzle_flash.visible = true
	# Clear primary marker shortly after flash
	get_tree().create_timer(0.12).timeout.connect(func(): _muzzle_last_primary = false)
	get_tree().create_timer(0.1).timeout.connect(func(): muzzle_flash.visible = false)

	# Update next fire time based on fire rate
	_next_fire_time = current_time + (1.0 / fire_rate)


func _handle_slide_collisions():
	if get_slide_collision_count() == 0:
		return

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		var normal = collision.get_normal()

		if collider == null:
			continue

		# Get other velocity for collision damage calculation
		var other_velocity = Vector2.ZERO
		if collider.has_method("get_velocity"):
			other_velocity = collider.get_velocity()
		elif collider is CharacterBody2D:
			other_velocity = collider.velocity

		# Enhanced vehicle-to-vehicle collision handling
		if collider.is_in_group("vehicles"):
			_handle_vehicle_collision(collider, normal, other_velocity)
		else:
			# Apply physics-based collision damage for non-vehicles
			var target_destroyed = _apply_collision_damage(collider, normal, other_velocity)

			# Apply bounce if target wasn't destroyed
			if not target_destroyed:
				_apply_bounce(normal, collider, other_velocity)

## Enhanced vehicle-to-vehicle collision handling
func _handle_vehicle_collision(other_vehicle: Node, normal: Vector2, other_velocity: Vector2):
	# Enhanced separation force for vehicles to prevent overlap
	var separation_force = 150.0  # Stronger than normal bounce_push for vehicles
	var relative_velocity = velocity - other_velocity
	var impact_speed = abs(relative_velocity.dot(normal))

	# Get mass information for physics-based response
	var self_mass = get_mass_scalar()
	var other_mass = 1.0
	if other_vehicle.has_method("get_mass_scalar"):
		other_mass = other_vehicle.get_mass_scalar()

	# Calculate separation based on mass ratio
	var mass_ratio = other_mass / (self_mass + other_mass)
	var separation_intensity = lerp(0.6, 1.4, mass_ratio)  # More aggressive than normal bounce

	# Apply vehicle collision damage (reduced compared to wall collisions)
	if impact_speed > 50.0:  # Lower threshold for vehicle-to-vehicle damage
		var target_destroyed = _apply_collision_damage(other_vehicle, normal, other_velocity)

	# Apply enhanced separation physics
	var speed_factor = clamp(impact_speed / 150.0, 0.5, 2.5)  # More responsive to speed
	var effective_separation = separation_force * speed_factor * separation_intensity

	# Apply separation with enhanced bounce physics
	velocity = velocity.bounce(normal) * 0.7 * separation_intensity  # Slightly more damping for vehicles
	velocity += normal * effective_separation

	# Prevent vehicles from getting stuck by ensuring minimum separation velocity
	if velocity.length() < 30.0:
		velocity += normal * 40.0  # Minimum separation push

func _on_collision_sensor_area_entered(area):
	# Check for terrain changes first
	_detect_terrain_change(area)

	# Handle destructible objects
	if area.is_in_group("destructible"):
		if velocity.length() < min_bounce_velocity:
			return

		# Calculate normal from collision direction
		var normal = (global_position - area.global_position).normalized()

		# Areas don't have velocity, so use zero
		var other_velocity = Vector2.ZERO

		# Apply physics-based collision damage
		var target_destroyed = _apply_collision_damage(area, normal, other_velocity)

		# Apply bounce if target wasn't destroyed
		if not target_destroyed:
			_apply_bounce(normal, area, other_velocity)

func _apply_bounce(normal: Vector2, target = null, other_velocity: Vector2 = Vector2.ZERO):
	if velocity.length() < min_bounce_velocity:
		return

	if normal.is_zero_approx():
		normal = -velocity.normalized()
	else:
		normal = normal.normalized()

	# Get mass information for physics-based bounce
	var self_mass = get_mass_scalar()
	var other_mass = 1.0
	if target != null and target.has_method("get_mass_scalar"):
		other_mass = target.get_mass_scalar()

	# Calculate relative velocity and impact speed for bounce scaling
	var relative_velocity = velocity - other_velocity
	var impact_speed = abs(relative_velocity.dot(normal))

	# Mass-based bounce calculation - lighter objects bounce more
	var mass_ratio = other_mass / (self_mass + other_mass)
	var bounce_intensity = lerp(0.4, 1.2, mass_ratio)  # Range from 40% to 120% bounce

	# Speed-scaled bounce force - stronger impacts create stronger separation
	var speed_factor = clamp(impact_speed / 200.0, 0.3, 2.0)
	var effective_bounce_push = bounce_push * speed_factor * bounce_intensity

	# Apply the bounce with enhanced physics
	velocity = velocity.bounce(normal) * bounce_damp * bounce_intensity
	velocity += normal * effective_bounce_push

## Apply physics-based collision damage with aggressor/victim calculation
## TODO: Consider tuning collision multipliers based on playtest feedback for balance
func _apply_collision_damage(target, normal: Vector2, other_velocity: Vector2) -> bool:
	# Check collision immunity first
	if _collision_immunity_timer > 0.0:
		if DEBUG_COLLISION_DAMAGE:
			print("[PlayerCar] Still immune (%.2fs remaining), ignoring collision" % _collision_immunity_timer)
		return false

	# Calculate relative impact speed along collision normal
	var relative_velocity = velocity - other_velocity
	var impact_speed = abs(relative_velocity.dot(normal))

	if DEBUG_COLLISION_DAMAGE:
		print("[CollisionDamage] Impact with %s - Speed: %.1f" % [target.name, impact_speed])

	# Ignore trivial bumps - moderate threshold to reduce minor collision damage
	if impact_speed <= 95.0:
		if DEBUG_COLLISION_DAMAGE:
			print("[CollisionDamage] Impact too low (%.1f <= 95), ignoring" % impact_speed)
		return false

	# Determine if we're the aggressor (forward vector within ~30° of -normal)
	var forward_direction = last_facing_direction.normalized()
	var aggressor_dot = forward_direction.dot(-normal)
	var is_aggressor = aggressor_dot >= 0.86  # cos(30°) ≈ 0.866

	# Get our mass scalar for damage calculations
	var self_mass_scalar = get_mass_scalar()

	if DEBUG_COLLISION_DAMAGE:
		print("[CollisionDamage] Aggressor check: dot=%.3f, is_aggressor=%s, mass_scalar=%.2f" % [aggressor_dot, is_aggressor, self_mass_scalar])

	# Calculate base damage values - moderate damage factors for balanced gameplay
	var base_damage_factor = max(impact_speed - 95.0, 0.0)
	var target_damage: float
	var self_damage: float

	if is_aggressor:
		# Head-on collision - moderate damage multipliers
		target_damage = base_damage_factor * 0.22 * self_mass_scalar
		self_damage = base_damage_factor * 0.12 * self_mass_scalar
	else:
		# Glancing/rear-end collision - reduced damage
		target_damage = base_damage_factor * 0.22 * self_mass_scalar * 0.3
		self_damage = base_damage_factor * 0.12 * self_mass_scalar * 0.5

	# Enhanced self-damage for indestructible targets (walls, etc.)
	if target.is_in_group("indestructible"):
		self_damage = base_damage_factor * 0.25 * self_mass_scalar
		if DEBUG_COLLISION_DAMAGE:
			print("[CollisionDamage] Indestructible target - enhanced self-damage: %.1f" % self_damage)

	var target_destroyed := false

	# Apply damage to target
	if target_damage > 0:
		if target.is_in_group("vehicles") and target.has_method("apply_damage"):
			# Cap vehicle damage at 20% of max HP per collision for more noticeable effect
			var max_target_damage = target.get_max_hp() * 0.20
			target_damage = min(target_damage, max_target_damage)
			if DEBUG_COLLISION_DAMAGE:
				print("[CollisionDamage] Vehicle target damage: %.1f (capped at %.1f)" % [target_damage, max_target_damage])
			target.apply_damage(target_damage, self)
			if target.has_method("is_dead") and target.is_dead():
				target_destroyed = true
		elif target.is_in_group("destructible") and target.has_method("apply_damage"):
			# Round up float damage for destructible integer systems
			var int_damage = int(ceil(target_damage))
			if DEBUG_COLLISION_DAMAGE:
				print("[CollisionDamage] Destructible target damage: %d (from %.1f)" % [int_damage, target_damage])
			target_destroyed = target.apply_damage(int_damage)

	# Apply self-damage
	if self_damage > 0:
		if DEBUG_COLLISION_DAMAGE:
			print("[CollisionDamage] Self-damage: %.1f" % self_damage)
		apply_damage(self_damage, target)

	# Set collision immunity to prevent damage spam
	_collision_immunity_timer = collision_immunity_duration
	if DEBUG_COLLISION_DAMAGE:
		print("[PlayerCar] Collision immunity set for %.2fs" % collision_immunity_duration)

	return target_destroyed

## Calculate smart transition time based on terrain pair and current speed
func _calculate_transition_time(from_terrain: String, to_terrain: String) -> float:
	var current_speed = velocity.length()
	var speed_ratio = current_speed / _effective_max_speed if _effective_max_speed > 0 else 0.0

	# Base transition times for different terrain pairs
	var base_time = 0.2  # Default fallback

	# Context-aware transition timing
	if from_terrain == "terrain_track":
		if to_terrain in ["terrain_sand", "terrain_grass"]:
			base_time = 1.0  # Road → Sand/Grass: gradual deceleration feel
		elif to_terrain in ["terrain_ice", "terrain_water"]:
			base_time = 0.4  # Road → Ice/Water: sudden loss of control
		elif to_terrain == "terrain_snow":
			base_time = 0.6  # Road → Snow: medium transition
	elif from_terrain in ["terrain_sand", "terrain_grass"]:
		if to_terrain == "terrain_track":
			base_time = 0.5  # Sand/Grass → Road: quicker grip recovery
		elif to_terrain in ["terrain_ice", "terrain_water"]:
			base_time = 0.4  # Sand/Grass → Ice/Water: moderate change
	elif from_terrain in ["terrain_ice", "terrain_water"]:
		if to_terrain == "terrain_track":
			base_time = 1.2  # Ice/Water → Road: gradual grip recovery
		elif to_terrain in ["terrain_sand", "terrain_grass"]:
			base_time = 0.8  # Ice/Water → Sand/Grass: moderate recovery
	elif from_terrain == "terrain_snow":
		if to_terrain == "terrain_track":
			base_time = 0.8  # Snow → Road: moderate recovery
		elif to_terrain in ["terrain_ice", "terrain_water"]:
			base_time = 0.5  # Snow → Ice/Water: moderate change
		elif to_terrain in ["terrain_sand", "terrain_grass"]:
			base_time = 0.6  # Snow → Sand/Grass: similar surfaces

	# Speed-dependent modifier: high speed transitions are more dramatic
	var speed_modifier = 1.0 + (speed_ratio * 0.5)  # Up to 50% longer at full speed

	return base_time * speed_modifier

## Get asymmetric curve type based on terrain transition
func _get_transition_curve_type(from_terrain: String, to_terrain: String) -> String:
	# Losing grip transitions - sharp initial drop, gradual completion
	if from_terrain == "terrain_track" and to_terrain in ["terrain_sand", "terrain_grass", "terrain_ice", "terrain_water"]:
		return "losing_grip"
	# Gaining grip transitions - gradual start, sharp final recovery
	elif to_terrain == "terrain_track" and from_terrain in ["terrain_sand", "terrain_grass", "terrain_ice", "terrain_water"]:
		return "gaining_grip"
	# Ice transitions - immediate effect with long tail
	elif to_terrain in ["terrain_ice", "terrain_water"] or from_terrain in ["terrain_ice", "terrain_water"]:
		return "ice_transition"
	# Default smooth transition
	else:
		return "smooth"

## Apply asymmetric easing curve based on transition type
func _apply_transition_curve(progress: float, curve_type: String) -> float:
	progress = clamp(progress, 0.0, 1.0)
	match curve_type:
		"losing_grip":
			# Sharp initial drop (immediate effect), gradual completion
			return 1.0 - pow(1.0 - progress, 0.3)
		"gaining_grip":
			# Gradual start, sharp final recovery
			return pow(progress, 0.3)
		"ice_transition":
			# Immediate effect with long tail
			return 1.0 - pow(1.0 - progress, 2.0)
		"smooth":
			# Default ease-out curve
			return _ease_out(progress, 0.65)
		_:
			return progress


## Apply enhanced progressive sliding physics during direction changes for dramatic drifting
func _apply_direction_change_physics(old_direction: Vector2, new_direction: Vector2):
	var current_speed = velocity.length()
	var speed_ratio = current_speed / _effective_max_speed if _effective_max_speed > 0 else 0.0

	# Calculate direction change severity (0 = no change, 1 = opposite direction)
	var direction_change_severity = (1.0 - old_direction.dot(new_direction)) / 2.0

	# Apply enhanced progressive sliding for meaningful direction changes (lower threshold)
	if direction_change_severity > 0.02 and current_speed > 20.0:  # More sensitive, lower speed threshold
		var mass_scalar = vehicle_health.get_mass_scalar() if vehicle_health else 1.0

		# Calculate vehicle capabilities for this turn
		var handling_capability = 1.0
		if not selected_profile.is_empty():
			var stats = selected_profile.get("stats", {})
			var handling_stat = stats.get("handling", 5)
			var handling_curve = _apply_stat_curve(handling_stat, "handling")
			handling_capability = lerp(0.3, 1.0, handling_curve)  # Wider capability range

		# Terrain affects turn grip more dramatically
		var terrain_turn_grip = _current_terrain_modifiers.handling

		# Enhanced progressive slide calculation
		var turn_demand = direction_change_severity * speed_ratio * mass_scalar
		var turn_capability = handling_capability * terrain_turn_grip

		# More aggressive slide factor calculation
		var slide_factor = turn_demand / max(turn_capability, 0.05)
		slide_factor = clamp(slide_factor, 0.2, 4.0)  # Higher minimum, much higher maximum

		# High-speed dramatic drift boost (above 60% speed)
		if speed_ratio > 0.6:
			var high_speed_boost = 1.0 + ((speed_ratio - 0.6) * 2.5)  # Up to 2.5x boost at full speed
			slide_factor *= high_speed_boost

		# Create more dramatic lateral momentum
		var lateral_direction = Vector2(old_direction.y, -old_direction.x)
		var base_slide_strength = direction_change_severity * speed_ratio * slide_factor

		# Enhanced slide strength with terrain-specific multipliers
		var terrain_slide_multiplier = 1.0
		if _current_terrain_modifiers.handling < 0.4:  # Ice/water
			terrain_slide_multiplier = 0.35  # Extreme sliding
		elif _current_terrain_modifiers.handling < 0.6:  # Snow
			terrain_slide_multiplier = 0.25  # Dramatic sliding
		elif _current_terrain_modifiers.handling < 0.8:  # Sand/grass
			terrain_slide_multiplier = 0.18  # Enhanced sliding
		else:  # Track
			terrain_slide_multiplier = 0.12  # Baseline sliding

		var slide_strength = base_slide_strength * terrain_slide_multiplier
		var slide_velocity = lateral_direction * slide_strength * current_speed

		# Add dramatic sliding momentum
		velocity += slide_velocity

		# Enhanced debug output for dramatic sliding
		if DEBUG_VEHICLE_TUNING and slide_factor > 1.0:
			_debug_log("DRAMATIC SLIDE: severity=%.2f, factor=%.2f, strength=%.2f, speed=%.0f%%" % [direction_change_severity, slide_factor, slide_strength, speed_ratio * 100])
			if speed_ratio > 0.6:
				_debug_log("HIGH SPEED DRIFT: Laying rubber down!")

## New helper functions for enhanced systems

func _update_direction_lock_timer(delta: float):
	if _direction_lock_timer > 0.0:
		_direction_lock_timer -= delta

## Update collision immunity timer
func _update_collision_immunity_timer(delta: float):
	if _collision_immunity_timer > 0.0:
		_collision_immunity_timer -= delta

func _update_terrain_modifiers(delta: float):
	# Smoothly interpolate toward target terrain modifiers with asymmetric curves
	if _terrain_transition_timer > 0.0:
		_terrain_transition_timer -= delta
		_terrain_transition_elapsed += delta
		var progress = clamp(_terrain_transition_elapsed / _terrain_transition_time, 0.0, 1.0)
		var eased_progress = _apply_transition_curve(progress, _transition_curve_type)

		# Interpolate each modifier including brake using stored start values
		_current_terrain_modifiers.accel = lerp(_start_terrain_modifiers.accel, _target_terrain_modifiers.accel, eased_progress)
		_current_terrain_modifiers.speed = lerp(_start_terrain_modifiers.speed, _target_terrain_modifiers.speed, eased_progress)
		_current_terrain_modifiers.handling = lerp(_start_terrain_modifiers.handling, _target_terrain_modifiers.handling, eased_progress)
		_current_terrain_modifiers.brake = lerp(_start_terrain_modifiers.brake, _target_terrain_modifiers.brake, eased_progress)
		_effective_max_speed = max_speed * _current_terrain_modifiers.speed
	else:
		# Ensure we snap to target when transition completes
		if _current_terrain_modifiers != _target_terrain_modifiers:
			_current_terrain_modifiers = _target_terrain_modifiers.duplicate(true)
		_effective_max_speed = max_speed * _current_terrain_modifiers.speed

func _detect_terrain_change(area: Area2D):
	# Check if this area represents a terrain type
	for terrain_name in TERRAIN_MODIFIERS.keys():
		if area.is_in_group(terrain_name):
			var new_modifiers = TERRAIN_MODIFIERS[terrain_name]
			_set_target_surface(new_modifiers, "Terrain change detected: " + terrain_name, terrain_name)
			return

	# No terrain detected - default to track (if not already)
	var track_modifiers = TERRAIN_MODIFIERS.terrain_track
	_set_target_surface(track_modifiers, "Terrain change detected: terrain_track (default)", "terrain_track")

## Handle terrain area exit events
func _on_collision_sensor_area_exited(area):
	# When exiting a terrain area, check if we're still overlapping any other terrain
	var overlapping_areas = collision_sensor.get_overlapping_areas()
	var found_terrain = false

	# Check all remaining overlapping areas for terrain types
	for overlapping_area in overlapping_areas:
		if overlapping_area == area:
			continue  # Skip the area we just exited

		for terrain_name in TERRAIN_MODIFIERS.keys():
			if overlapping_area.is_in_group(terrain_name):
				# Found another terrain type, transition to it
				var new_modifiers = TERRAIN_MODIFIERS[terrain_name]
				_set_target_surface(new_modifiers, "Terrain exit - switched to: " + terrain_name, terrain_name)

				found_terrain = true
				break

		if found_terrain:
			break

	# If no terrain found, default back to track
	if not found_terrain:
		var track_modifiers = TERRAIN_MODIFIERS.terrain_track
		_set_target_surface(track_modifiers, "Terrain exit - reverted to track", "terrain_track")

## Set target surface with smart transition timing and asymmetric curves
func _set_target_surface(modifiers: Dictionary, debug_message: String = "", new_terrain_type: String = ""):
	# Check if modifiers actually changed
	if (_target_terrain_modifiers.accel != modifiers.accel or
		_target_terrain_modifiers.speed != modifiers.speed or
		_target_terrain_modifiers.handling != modifiers.handling or
		_target_terrain_modifiers.brake != modifiers.brake):

		# Update terrain type tracking
		_previous_terrain_type = _current_terrain_type
		if new_terrain_type != "":
			_current_terrain_type = new_terrain_type

		_start_terrain_modifiers = _current_terrain_modifiers.duplicate(true)
		_target_terrain_modifiers = modifiers.duplicate(true)

		# Calculate smart transition time and curve type based on terrain pair and speed
		_terrain_transition_time = _calculate_transition_time(_previous_terrain_type, _current_terrain_type)
		_transition_curve_type = _get_transition_curve_type(_previous_terrain_type, _current_terrain_type)
		_terrain_transition_timer = _terrain_transition_time
		_terrain_transition_elapsed = 0.0

		if debug_message != "":
			_debug_log(debug_message)

		# Update handling profile if we have character stats
		if not selected_profile.is_empty():
			var stats = selected_profile.get("stats", {})
			var handling_stat = stats.get("handling", 5)
			_compute_handling_profile(handling_stat, modifiers.handling)

		# Immediately clamp velocity to new speed cap for noticeable feedback
		var surface_speed_cap = max_speed * modifiers.speed
		if velocity.length() > surface_speed_cap:
			if surface_speed_cap <= 0.0:
				velocity = Vector2.ZERO
			else:
				velocity = velocity.normalized() * surface_speed_cap
	else:
		if debug_message != "":
			_debug_log(debug_message + " (no change)")

## Public health system interface

## Apply damage through health component - public entry point for weapons
func apply_damage(amount: float, source = null) -> void:
	if vehicle_health:
		vehicle_health.apply_damage(amount, source)

## Get current HP for UI/debugging
func get_current_hp() -> float:
	if vehicle_health:
		return vehicle_health.current_hp
	return 0.0

## Get max HP for calculations
func get_max_hp() -> float:
	if vehicle_health:
		return vehicle_health.max_hp
	return 0.0

## Check if vehicle is dead
func is_dead() -> bool:
	if vehicle_health:
		return vehicle_health.is_dead()
	return false

## Get mass scalar for collision damage
func get_mass_scalar() -> float:
	if vehicle_health:
		return vehicle_health.get_mass_scalar()
	return 1.0

## Handle vehicle death
func _on_vehicle_died():
	print("PlayerCar died! HP: %.0f/%.0f" % [get_current_hp(), get_max_hp()])
	# TODO: Add death effects, respawn logic, etc.

## Fallback vehicle separation system
var _nearby_vehicles: Array = []

func _on_vehicle_proximity_entered(vehicle: Node2D):
	if vehicle.is_in_group("vehicles") and vehicle != self:
		_nearby_vehicles.append(vehicle)
		if DEBUG_COLLISION_DAMAGE:
			print("[PlayerCar] Vehicle entered proximity: " + vehicle.name)

func _on_vehicle_proximity_exited(vehicle: Node2D):
	if vehicle in _nearby_vehicles:
		_nearby_vehicles.erase(vehicle)
		if DEBUG_COLLISION_DAMAGE:
			print("[PlayerCar] Vehicle exited proximity: " + vehicle.name)

## Apply emergency separation forces for overlapping vehicles
func _apply_emergency_separation(delta: float):
	if _nearby_vehicles.is_empty():
		return

	var separation_force = Vector2.ZERO
	var separation_applied = false

	for vehicle in _nearby_vehicles:
		if not is_instance_valid(vehicle):
			continue

		var distance = global_position.distance_to(vehicle.global_position)
		var minimum_distance = 80.0  # Emergency separation distance

		if distance < minimum_distance and distance > 0:
			# Calculate separation direction
			var separation_direction = (global_position - vehicle.global_position).normalized()
			var separation_strength = (minimum_distance - distance) / minimum_distance

			# Apply quadratic falloff for stronger effect when very close
			separation_strength = pow(separation_strength, 2) * 100.0

			separation_force += separation_direction * separation_strength
			separation_applied = true

	# Apply the separation force
	if separation_applied:
		velocity += separation_force * delta
		if DEBUG_COLLISION_DAMAGE:
			print("[PlayerCar] Emergency separation applied: force magnitude %.1f" % separation_force.length())
