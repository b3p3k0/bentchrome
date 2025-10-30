extends CharacterBody2D

## EnemyCar - AI-controlled vehicle based on player car physics
## Inherits all vehicle physics from player car but replaces input with AI decision making
## Uses roster ID to load both stats/colors and AI behavior profile

## Debug flag for AI vehicle behavior
const DEBUG_AI_VEHICLE: bool = true
## Debug flag for vehicle tuning instrumentation (matches PlayerCar)
const DEBUG_VEHICLE_TUNING: bool = false
## Debug flag for collision damage system (matches PlayerCar)
const DEBUG_COLLISION_DAMAGE: bool = false

const VehicleHealth = preload("res://scripts/vehicles/vehicle_health.gd")

## Load player car script for reusing physics constants
const PlayerCarScript = preload("res://scripts/vehicles/player_car.gd")

@export var max_speed: float = 200.0
@export var acceleration: float = 800.0
@export var deceleration: float = 600.0
@export var brake_force: float = 1200.0
@export var bullet_scene: PackedScene
@export var fire_rate: float = 20.0
@export var bounce_damp: float = 0.55
@export var bounce_push: float = 80.0
@export var min_bounce_velocity: float = 5.0

## Collision immunity system to prevent damage spam
@export var collision_immunity_duration: float = 0.15
var _collision_immunity_timer: float = 0.0

## AI-specific properties
var roster_id: String = ""
var ai_profile: Dictionary = {}
var archetype_config: Dictionary = {}
var selected_profile: Dictionary = {}
var _profile_initialized: bool = false

## AI state variables
var ai_target: Node = null
var ai_state: String = "hunt"  # hunt, flank, retreat, pickup_seek, opportunistic, defensive
var ai_decision_timer: float = 0.0
var ai_decision_interval: float = 0.5
var ai_reaction_timer: float = 0.0
var ai_fire_timer: float = 0.0
var ai_retarget_timer: float = 0.0
var ai_last_target_position: Vector2
var ai_patrol_center: Vector2
var ai_patrol_radius: float = 300.0

## Battle royale targeting system
var ai_threat_scores: Dictionary = {}  # target_node -> threat_score
var ai_last_attacker: Node = null  # For revenge targeting
var ai_last_damage_time: float = 0.0
var ai_targeting_config: Dictionary = {}
var ai_all_potential_targets: Array = []
var ai_retreat_timer: float = 0.0
var ai_retreat_min_duration: float = 1.4
var ai_retreat_reengage_distance: float = 360.0
var ai_retreat_grace_period: float = 2.5
var ai_no_retreat_timer: float = 0.0

## Copy constants from player car
var STAT_SCALE: Dictionary
var TERRAIN_MODIFIERS: Dictionary
var DAMAGE_PROFILE: Dictionary
var DRIFT_FACTORS: Dictionary

var _next_fire_time := 0.0
var current_direction := Vector2.ZERO
var last_facing_direction := Vector2.UP
var vehicle_health
var _cached_armor_stat: int = 5
var _derived_stats: Dictionary = {}
var _direction_lock_timer: float = 0.0
var _handling_lock_duration: float = 0.1
var _lateral_drag_multiplier: float = 1.0
var _snap_smoothing_factor: float = 0.5
var _current_terrain_modifiers: Dictionary = {"accel": 1.0, "speed": 1.0, "handling": 1.0, "brake": 1.0}
var _target_terrain_modifiers: Dictionary = {"accel": 1.0, "speed": 1.0, "handling": 1.0, "brake": 1.0}
var _start_terrain_modifiers: Dictionary = {"accel": 1.0, "speed": 1.0, "handling": 1.0, "brake": 1.0}
var _terrain_transition_time: float = 0.2  ## Dynamic time to interpolate terrain changes
var _terrain_transition_timer: float = 0.0
var _terrain_transition_elapsed: float = 0.0
var _effective_max_speed: float = 0.0
var _current_terrain_type: String = "terrain_track"  ## Track current terrain for smart transitions
var _previous_terrain_type: String = "terrain_track"  ## Track previous terrain for transition logic
var _transition_curve_type: String = "smooth"  ## Current transition curve type for asymmetric easing

## Mass-based inertia variables
var _mass_scaled: bool = false  ## Guard against double-application of mass scaling
var _base_stats: Dictionary = {}  ## Cache base stats before mass scaling for debug

@onready var muzzle := $Muzzle
@onready var muzzle_flash := $Visuals/MuzzleFlash
@onready var visuals := $Visuals
@onready var collision_sensor := $CollisionSensor
@onready var body_color := $Visuals/BodyColor
@onready var accent_color := $Visuals/AccentColor

func _ready():
	print("EnemyCar initialized")

	# Copy constants from player car
	_copy_player_car_constants()

	# Initialize collision handling
	collision_sensor.area_entered.connect(_on_collision_sensor_area_entered)
	collision_sensor.area_exited.connect(_on_collision_sensor_area_exited)

	# Initialize vehicle health component
	vehicle_health = VehicleHealth.new()
	add_child(vehicle_health)
	vehicle_health.died.connect(_on_vehicle_died)

	# Set patrol center to spawn position
	ai_patrol_center = global_position

	# Finalize roster-driven configuration once nodes are ready
	_initialize_from_roster()

## Copy constants from PlayerCar script to avoid duplication
func _copy_player_car_constants():
	# This is a workaround since we can't directly inherit static constants
	STAT_SCALE = {
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

	TERRAIN_MODIFIERS = {
		"terrain_track": {"accel": 1.0, "speed": 1.0, "handling": 1.0, "brake": 1.0},
		"terrain_sand": {"accel": 0.2, "speed": 0.5, "handling": 0.12, "brake": 0.35},
		"terrain_grass": {"accel": 0.5, "speed": 0.75, "handling": 0.45, "brake": 0.8},
		"terrain_ice": {"accel": 0.3, "speed": 1.3, "handling": 0.08, "brake": 0.25},
		"terrain_snow": {"accel": 0.25, "speed": 0.5, "handling": 0.2, "brake": 0.4},
		"terrain_water": {"accel": 0.25, "speed": 1.4, "handling": 0.05, "brake": 0.15}
	}

	DAMAGE_PROFILE = {
		"MACHINE_GUN": 8,
		"HOMING_MISSILE": 40,
		"FIRE_MISSILE": 80,
		"POWER_MISSILE": 120,
		"BOUNCE_BOMB_DIRECT": 60,
		"BOUNCE_BOMB_BOUNCED": 160,
		"LAND_MINE": 80
	}

	DRIFT_FACTORS = {
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

## Initialize AI with roster ID and load behavior profile
func set_roster_id(new_roster_id: String) -> void:
	roster_id = new_roster_id
	selected_profile.clear()
	ai_profile.clear()
	_profile_initialized = false
	_debug_log("Setting roster ID: " + roster_id)

	if is_inside_tree():
		_initialize_from_roster()

## Load roster profile for stats/colors (reused from player car logic)
func _load_roster_profile() -> bool:
	var roster_path = "res://assets/data/roster.json"
	if not FileAccess.file_exists(roster_path):
		push_error("EnemyCar: Roster file not found")
		return false

	var file = FileAccess.open(roster_path, FileAccess.READ)
	if file == null:
		push_error("EnemyCar: Could not open roster file")
		return false

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_text) != OK:
		push_error("EnemyCar: Invalid JSON in roster file")
		return false

	var roster_data = json.data
	if not roster_data is Dictionary:
		return false

	var characters = roster_data.get("characters", [])
	for character in characters:
		if character is Dictionary and character.get("id", "") == roster_id:
			selected_profile = character
			_debug_log("Loaded roster profile for: " + roster_id)
			return true

	push_error("EnemyCar: Roster ID '" + roster_id + "' not found in roster.json")
	return false

## Initialize stats, colors, and AI profile once nodes are ready
func _initialize_from_roster() -> void:
	if roster_id.is_empty():
		# Apply fallback only if SelectionState has no match opponents
		if not SelectionState.has_match_opponents():
			roster_id = "bumper"
			_debug_log("No roster ID set, using fallback: " + roster_id)
		else:
			return

	if _profile_initialized:
		return

	if _load_roster_profile():
		_apply_character_stats()
		_apply_character_colors()
	else:
		_apply_default_colors()

	if AIProfileLoader:
		ai_profile = AIProfileLoader.get_profile(roster_id)
		_debug_log("Loaded AI profile for " + roster_id + " (archetype: " + ai_profile.get("archetype", "unknown") + ")")
		_update_ai_tuning_from_profile()
		_setup_targeting_config()
	else:
		push_error("EnemyCar: AIProfileLoader not available")

	_profile_initialized = true

## Setup targeting configuration from AI profile and archetype
func _setup_targeting_config():
	# Get default targeting config
	var defaults = {
		"player_bias": 0.6,
		"closest_enemy_weight": 0.8,
		"wounded_target_bonus": 0.3,
		"max_engagement_distance": 800.0,
		"retarget_interval_sec": 2.0,
		"revenge_bonus": 0.4,
		"health_threshold_bonus": 0.2
	}

	# Override with profile-specific settings
	ai_targeting_config = defaults.duplicate()
	var profile_targeting = ai_profile.get("targeting", {})
	for key in profile_targeting.keys():
		ai_targeting_config[key] = profile_targeting[key]

	# Set retarget timer
	ai_retarget_timer = ai_targeting_config.get("retarget_interval_sec", 2.0)

	_debug_log("Targeting config setup - player_bias: " + str(ai_targeting_config.player_bias))

func _update_ai_tuning_from_profile():
	var reaction_time = ai_profile.get("reaction_time_sec", 0.35)
	var jitter = ai_profile.get("reaction_jitter_sec", 0.12)
	ai_decision_interval = reaction_time + randf_range(-jitter, jitter)

	var retreat_behavior = ai_profile.get("retreat_behavior", {})
	ai_retreat_min_duration = retreat_behavior.get("min_duration_sec", ai_retreat_min_duration)
	ai_retreat_reengage_distance = retreat_behavior.get("reengage_distance", ai_retreat_reengage_distance)
	ai_retreat_grace_period = retreat_behavior.get("grace_period_sec", ai_retreat_grace_period)
	ai_retreat_timer = 0.0

## Apply character stats (copied from player car with minor adjustments)
func _apply_character_stats():
	if selected_profile.is_empty():
		_debug_log("Warning: No character profile selected, using default stats")
		return

	var stats = selected_profile.get("stats", {})
	if stats.is_empty():
		_debug_log("Warning: Character profile missing stats, using default values")
		return

	# Extract 1-10 scale stats
	var accel_stat = stats.get("acceleration", 5)
	var speed_stat = stats.get("top_speed", 5)
	var handling_stat = stats.get("handling", 5)
	var armor_stat = stats.get("armor", 5)
	var special_stat = stats.get("special_power", 5)

	# Apply curves and scaling (using same logic as player car)
	var accel_curve = _apply_stat_curve(accel_stat, "acceleration")
	var speed_curve = _apply_stat_curve(speed_stat, "speed")
	var handling_curve = _apply_stat_curve(handling_stat, "handling")

	max_speed = lerp(STAT_SCALE.max_speed.x, STAT_SCALE.max_speed.y, speed_curve)
	acceleration = lerp(STAT_SCALE.acceleration.x, STAT_SCALE.acceleration.y, accel_curve)
	deceleration = lerp(STAT_SCALE.deceleration.x, STAT_SCALE.deceleration.y, accel_curve)
	brake_force = lerp(STAT_SCALE.brake_force.x, STAT_SCALE.brake_force.y, accel_curve)

	_handling_lock_duration = lerp(STAT_SCALE.handling_lock.x, STAT_SCALE.handling_lock.y, handling_curve)
	_lateral_drag_multiplier = lerp(STAT_SCALE.handling_drag.x, STAT_SCALE.handling_drag.y, handling_curve)
	_snap_smoothing_factor = lerp(STAT_SCALE.handling_snap.x, STAT_SCALE.handling_snap.y, handling_curve)

	# Cache base stats before mass scaling for debug
	_base_stats = {
		"max_speed": max_speed,
		"acceleration": acceleration,
		"deceleration": deceleration,
		"brake_force": brake_force,
		"handling_lock": _handling_lock_duration
	}

	# Configure health system
	_cached_armor_stat = armor_stat
	if vehicle_health:
		vehicle_health.configure_from_stats(stats)

	# Apply mass-based inertia scaling (only once)
	if not _mass_scaled and vehicle_health:
		_apply_mass_scaling()

	_effective_max_speed = max_speed
	_debug_log("Applied stats for " + roster_id + " - Max Speed: " + str(max_speed) + ", Acceleration: " + str(acceleration))

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

## Apply stat curve (copied from player car)
func _apply_stat_curve(stat_value: float, curve_type: String) -> float:
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
			return normalized

## Simple ease-out helper for throttle curves
func _ease_out(value: float, exponent: float = 0.5) -> float:
	value = clamp(value, 0.0, 1.0)
	return pow(value, exponent)

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

## Calculate drift factor with enhanced slip angle physics for dramatic sliding (mirrors player car)
func _calculate_drift_factor(current_speed: float, mass_scalar: float) -> float:
	# Base drift calculation with slip angle physics
	var speed_ratio = current_speed / _effective_max_speed if _effective_max_speed > 0 else 0.0

	# Calculate slip angle between vehicle heading and velocity direction
	var slip_angle = 0.0
	if current_speed > 5.0 and current_direction != Vector2.ZERO:
		var velocity_direction = velocity.normalized()
		var vehicle_heading = current_direction.normalized()
		# Calculate angle difference (slip angle) - key to realistic drift physics
		slip_angle = abs(velocity_direction.angle_to(vehicle_heading))
		slip_angle = min(slip_angle, PI/2)  # Cap at 90 degrees

	# Enhanced speed-dependent base drift with high-speed boost
	var base_drift: float
	if speed_ratio < 0.7:
		# Below 70% speed: use normal speed-dependent drift
		base_drift = lerp(DRIFT_FACTORS.low_speed.x, DRIFT_FACTORS.high_speed.y, speed_ratio)
	else:
		# Above 70% speed: dramatic boost for "laying rubber down" feel
		var high_speed_factor = (speed_ratio - 0.7) / 0.3  # 0-1 for the top 30% speed range
		var boosted_drift = lerp(DRIFT_FACTORS.high_speed.y, DRIFT_FACTORS.high_speed_boost.y, high_speed_factor)
		base_drift = boosted_drift

	# Slip angle amplifies drift dramatically (based on FOSS racing research)
	var slip_angle_multiplier = 1.0 + (slip_angle * DRIFT_FACTORS.slip_angle_sensitivity)

	# Enhanced terrain-specific drift multipliers (more aggressive)
	var terrain_multiplier = 1.0
	if _current_terrain_modifiers.handling < 0.4:  # Ice/water terrain
		terrain_multiplier = DRIFT_FACTORS.terrain_multipliers.ice  # Extreme drift
	elif _current_terrain_modifiers.handling < 0.6:  # Snow terrain
		terrain_multiplier = DRIFT_FACTORS.terrain_multipliers.snow  # Much more drift
	elif _current_terrain_modifiers.handling < 0.8:  # Sand/grass terrain
		terrain_multiplier = DRIFT_FACTORS.terrain_multipliers.sand  # More drift
	else:  # Track terrain
		terrain_multiplier = DRIFT_FACTORS.terrain_multipliers.track  # Reduced but still driftable

	# Vehicle handling affects drift: poor handling = much more sliding
	var handling_drift_modifier = 1.0
	if not selected_profile.is_empty():
		var stats = selected_profile.get("stats", {})
		var handling_stat = stats.get("handling", 5)
		var handling_curve = _apply_stat_curve(handling_stat, "handling")
		handling_drift_modifier = lerp(1.8, 0.6, handling_curve)  # More dramatic handling differences

	# Mass affects drift: heavier vehicles have more momentum, slide dramatically more
	var mass_drift_modifier = lerp(0.7, 1.6, (mass_scalar - 0.8) / 0.6)

	# Combine all factors for dramatic sliding physics
	var final_drift = base_drift * slip_angle_multiplier * terrain_multiplier * handling_drift_modifier * mass_drift_modifier
	final_drift = clamp(final_drift, 0.03, 0.95)  # Allow dramatic sliding while maintaining some control

	# Enhanced debug output for slip angle and drift factor breakdown (AI version)
	if DEBUG_VEHICLE_TUNING and current_speed > 30.0:
		var slip_degrees = rad_to_deg(slip_angle)
		_debug_log("Enhanced drift: Speed=%.0f%%, Slip=%.1f°, Base=%.2f, SlipMult=%.2f×, Final=%.2f" % [speed_ratio * 100, slip_degrees, base_drift, slip_angle_multiplier, final_drift])

	return final_drift

## Apply character colors (copied from player car)
func _apply_character_colors():
	if not body_color or not accent_color:
		push_warning("EnemyCar: Visual color nodes not ready for roster " + roster_id)
		return

	var colors = selected_profile.get("colors", {})
	if colors.is_empty():
		_apply_default_colors()
		return

	var primary_hex = colors.get("primary", "")
	var accent_hex = colors.get("accent", "")

	if primary_hex.is_empty() or accent_hex.is_empty():
		_apply_default_colors()
		return

	body_color.color = Color.from_string(primary_hex, Color.RED)
	accent_color.color = Color.from_string(accent_hex, Color.CYAN)
	_debug_log("Applied colors for " + roster_id + " - Primary: " + primary_hex + ", Accent: " + accent_hex)

func _apply_default_colors():
	if body_color:
		body_color.color = Color.ORANGE_RED
	if accent_color:
		accent_color.color = Color.DARK_ORANGE

## Main AI processing function
func _physics_process(delta):
	_update_terrain_modifiers(delta)
	_update_direction_lock_timer(delta)
	_update_collision_immunity_timer(delta)

	# AI decision making
	_process_ai_logic(delta)

	# Apply movement and physics (reuses player car logic)
	_apply_ai_movement(delta)
	move_and_slide()
	_handle_slide_collisions()

	# Visual rotation
	if current_direction != Vector2.ZERO:
		var target_rotation = current_direction.angle() + PI / 2
		if _snap_smoothing_factor < 1.0:
			visuals.rotation = lerp_angle(visuals.rotation, target_rotation, _snap_smoothing_factor * delta * 10.0)
		else:
			visuals.rotation = target_rotation

## Process AI decision making
func _process_ai_logic(delta):
	ai_decision_timer -= delta
	ai_reaction_timer -= delta
	ai_fire_timer -= delta
	ai_retarget_timer -= delta
	if ai_no_retreat_timer > 0.0:
		ai_no_retreat_timer = max(ai_no_retreat_timer - delta, 0.0)

	# Check for retargeting opportunities
	if ai_retarget_timer <= 0.0:
		_update_threat_assessment()
		ai_retarget_timer = ai_targeting_config.get("retarget_interval_sec", 2.0)

	# Make decisions at intervals
	if ai_decision_timer <= 0.0:
		_make_ai_decision()
		ai_decision_timer = ai_decision_interval

	# Execute current behavior
	_execute_ai_behavior(delta)

## Make high-level AI decision about state and target
func _make_ai_decision():
	# Find best target using threat assessment
	_find_best_target()

	# Decide on state based on profile and situation
	_decide_state()

	_debug_log("AI Decision: state=" + ai_state + ", target=" + (ai_target.name if ai_target else "none"))

## Battle Royale Multi-Target Selection System
func _find_best_target():
	# Get all potential targets (players + other enemies)
	ai_all_potential_targets = _get_all_potential_targets()

	if ai_all_potential_targets.is_empty():
		ai_target = null
		return

	# Calculate threat scores for all targets
	ai_threat_scores.clear()
	for target in ai_all_potential_targets:
		if is_instance_valid(target) and target != self:
			ai_threat_scores[target] = _calculate_threat_score(target)

	# Find highest scoring target
	var best_target = null
	var best_score = -1.0

	for target in ai_threat_scores.keys():
		var score = ai_threat_scores[target]
		if score > best_score:
			best_score = score
			best_target = target

	# Update target if we found a better one or current target is invalid
	if best_target and (not ai_target or not is_instance_valid(ai_target) or _should_retarget(best_target)):
		ai_target = best_target
		ai_last_target_position = ai_target.global_position
		_debug_log("Retargeted to: " + ai_target.name + " (score: " + str(best_score) + ")")

## Get all potential targets in range (players + enemies)
func _get_all_potential_targets() -> Array:
	var targets = []
	var max_distance = ai_targeting_config.get("max_engagement_distance", 800.0)

	# Add players
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		if is_instance_valid(player) and global_position.distance_to(player.global_position) <= max_distance:
			targets.append(player)

	# Add other enemies
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if (is_instance_valid(enemy) and enemy != self and
			global_position.distance_to(enemy.global_position) <= max_distance):
			targets.append(enemy)

	return targets

## Calculate threat score for a potential target
func _calculate_threat_score(target: Node) -> float:
	if not is_instance_valid(target):
		return 0.0

	var score = 0.0
	var distance = global_position.distance_to(target.global_position)
	var max_distance = ai_targeting_config.get("max_engagement_distance", 800.0)

	# Base score starts high and decreases with distance
	score = 1.0 - (distance / max_distance)
	score = max(score, 0.1)  # Minimum base score

	# Player bias - prefer players over other AIs
	if target.is_in_group("player"):
		var player_bias = ai_targeting_config.get("player_bias", 0.6)
		score *= (1.0 + player_bias)
		_debug_log("Player bias applied: " + str(player_bias) + " to " + target.name)

	# Closest enemy weight - prefer nearby threats
	var closest_weight = ai_targeting_config.get("closest_enemy_weight", 0.8)
	var distance_factor = 1.0 - (distance / max_distance)
	score += distance_factor * closest_weight

	# Wounded target bonus - prefer low-health enemies
	if target.has_method("get_current_hp") and target.has_method("get_max_hp"):
		var current_hp = target.get_current_hp()
		var max_hp = target.get_max_hp()
		if max_hp > 0:
			var health_percentage = current_hp / max_hp
			var wounded_bonus = ai_targeting_config.get("wounded_target_bonus", 0.3)
			var health_bonus_threshold = ai_targeting_config.get("health_threshold_bonus", 0.2)

			# Bonus for targets below 50% health
			if health_percentage < 0.5:
				score += wounded_bonus * (1.0 - health_percentage)

			# Extra bonus for very low health targets
			if health_percentage < health_bonus_threshold:
				score += wounded_bonus

	# Revenge bonus - prioritize whoever damaged us recently
	if target == ai_last_attacker and (Time.get_ticks_msec() / 1000.0) - ai_last_damage_time < 10.0:
		var revenge_bonus = ai_targeting_config.get("revenge_bonus", 0.4)
		score += revenge_bonus
		_debug_log("Revenge bonus applied: " + str(revenge_bonus) + " against " + target.name)

	return score

## Check if we should switch to a new target
func _should_retarget(potential_target: Node) -> bool:
	if not ai_target or not is_instance_valid(ai_target):
		return true

	# Don't retarget if current target is still good
	var current_score = ai_threat_scores.get(ai_target, 0.0)
	var new_score = ai_threat_scores.get(potential_target, 0.0)

	# Switch if new target is significantly better (25% threshold to prevent flipping)
	return new_score > (current_score * 1.25)

## Update threat assessment for all targets
func _update_threat_assessment():
	# Refresh potential targets
	ai_all_potential_targets = _get_all_potential_targets()

	# Recalculate threat scores
	ai_threat_scores.clear()
	for target in ai_all_potential_targets:
		if is_instance_valid(target) and target != self:
			ai_threat_scores[target] = _calculate_threat_score(target)

	# Check if we should retarget
	var best_target = null
	var best_score = -1.0
	for target in ai_threat_scores.keys():
		var score = ai_threat_scores[target]
		if score > best_score:
			best_score = score
			best_target = target

	if best_target and _should_retarget(best_target):
		var old_target_name = ai_target.name if ai_target else "none"
		ai_target = best_target
		ai_last_target_position = ai_target.global_position
		_debug_log("Threat assessment retarget: " + old_target_name + " -> " + ai_target.name)

## Decide on AI state based on profile weights and situation
func _decide_state():
	if not ai_target:
		_set_state("hunt")
		return

	var distance_to_target = global_position.distance_to(ai_target.global_position)
	var health_percentage = get_current_hp() / get_max_hp() if get_max_hp() > 0 else 1.0

	# Check retreat condition
	var retreat_threshold = ai_profile.get("triggers", {}).get("retreat_hp", 0.3)
	if health_percentage <= retreat_threshold and ai_no_retreat_timer <= 0.0:
		_set_state("retreat")
		return

	# Check for special targeting situations
	if ai_last_attacker and ai_last_attacker == ai_target and (Time.get_ticks_msec() / 1000.0) - ai_last_damage_time < 5.0:
		# Revenge mode - hunt down whoever attacked us
		_set_state("hunt")
		return

	# Check for opportunistic behavior (wounded targets nearby)
	var has_wounded_nearby = false
	for target in ai_all_potential_targets:
		if (is_instance_valid(target) and target.has_method("get_current_hp") and target.has_method("get_max_hp")):
			var hp_ratio = target.get_current_hp() / target.get_max_hp() if target.get_max_hp() > 0 else 1.0
			if hp_ratio < 0.3 and global_position.distance_to(target.global_position) < 400.0:
				has_wounded_nearby = true
				break

	if has_wounded_nearby and randf() < 0.3:
		_set_state("opportunistic")
		return

	# Use state weights to make decision
	var weights = ai_profile.get("state_weights", {"hunt": 0.5, "flank": 0.3, "retreat": 0.2})
	var hunt_weight = weights.get("hunt", 0.5)
	var flank_weight = weights.get("flank", 0.3)

	# Bias toward hunt if close, flank if far
	if distance_to_target < 300.0:
		if randf() < hunt_weight * 1.5:
			_set_state("hunt")
		else:
			_set_state("flank")
	else:
		if randf() < flank_weight * 1.5:
			_set_state("flank")
		else:
			_set_state("hunt")

## Execute current AI behavior
func _execute_ai_behavior(delta):
	match ai_state:
		"hunt":
			_behavior_hunt(delta)
		"flank":
			_behavior_flank(delta)
		"retreat":
			_behavior_retreat(delta)
		"pickup_seek":
			_behavior_pickup_seek(delta)
		"opportunistic":
			_behavior_opportunistic(delta)
		"defensive":
			_behavior_defensive(delta)
		_:
			_behavior_hunt(delta)

## Hunt behavior - direct approach to target
func _behavior_hunt(delta):
	if not ai_target:
		current_direction = Vector2.ZERO
		return

	var direction_to_target = (ai_target.global_position - global_position).normalized()
	current_direction = _get_cardinal_direction(direction_to_target)
	last_facing_direction = current_direction

	# Fire if in range and has reaction time passed
	_try_fire_at_target()

## Flank behavior - approach from angles
func _behavior_flank(delta):
	if not ai_target:
		current_direction = Vector2.ZERO
		return

	var to_target = ai_target.global_position - global_position
	var distance = to_target.length()

	# Move to flanking position (perpendicular to target)
	var flank_direction: Vector2
	if distance > 400.0:
		# Get closer first
		flank_direction = to_target.normalized()
	else:
		# Move perpendicular
		flank_direction = Vector2(-to_target.y, to_target.x).normalized()
		if randf() < 0.5:
			flank_direction = -flank_direction

	current_direction = _get_cardinal_direction(flank_direction)
	last_facing_direction = (ai_target.global_position - global_position).normalized()

	_try_fire_at_target()

## Retreat behavior - move away from target
func _behavior_retreat(delta):
	if not ai_target:
		current_direction = Vector2.ZERO
		return

	ai_retreat_timer += delta

	var away_from_target = (global_position - ai_target.global_position).normalized()
	current_direction = _get_cardinal_direction(away_from_target)
	last_facing_direction = (ai_target.global_position - global_position).normalized()

	# Still fire while retreating
	_try_fire_at_target()

	var distance_to_target = global_position.distance_to(ai_target.global_position)
	var min_time_met = ai_retreat_timer >= ai_retreat_min_duration
	var distance_met = distance_to_target >= ai_retreat_reengage_distance

	if min_time_met and (distance_met or ai_retreat_timer >= ai_retreat_min_duration * 2.0):
		_force_reengage(distance_to_target)

## Pickup seek behavior - move toward health/ammo pickups
func _behavior_pickup_seek(delta):
	# TODO: Implement pickup detection and pathfinding
	# For now, fall back to hunt behavior
	_behavior_hunt(delta)

## Opportunistic behavior - target wounded enemies aggressively
func _behavior_opportunistic(delta):
	if not ai_target:
		current_direction = Vector2.ZERO
		return

	# Find the most wounded target in range
	var best_wounded_target = null
	var lowest_hp_ratio = 1.0

	for target in ai_all_potential_targets:
		if (is_instance_valid(target) and target != self and
			target.has_method("get_current_hp") and target.has_method("get_max_hp")):
			var hp_ratio = target.get_current_hp() / target.get_max_hp() if target.get_max_hp() > 0 else 1.0
			var distance = global_position.distance_to(target.global_position)

			if hp_ratio < lowest_hp_ratio and distance < 500.0:
				lowest_hp_ratio = hp_ratio
				best_wounded_target = target

	# Switch to wounded target if found
	if best_wounded_target and best_wounded_target != ai_target:
		ai_target = best_wounded_target
		ai_last_target_position = ai_target.global_position
		_debug_log("Opportunistic retarget to wounded: " + ai_target.name + " (HP: " + str(lowest_hp_ratio) + ")")

	# Aggressive direct approach
	var direction_to_target = (ai_target.global_position - global_position).normalized()
	current_direction = _get_cardinal_direction(direction_to_target)
	last_facing_direction = current_direction

	# Fire more aggressively at wounded targets
	_try_fire_at_target()

## Defensive behavior - react to nearby threats
func _behavior_defensive(delta):
	if not ai_target:
		current_direction = Vector2.ZERO
		return

	# Check for immediate threats (enemies within 200 units)
	var immediate_threats = []
	for target in ai_all_potential_targets:
		if (is_instance_valid(target) and target != self and
			global_position.distance_to(target.global_position) < 200.0):
			immediate_threats.append(target)

	if immediate_threats.size() > 1:
		# Multiple threats - try to back away while facing the primary target
		var away_from_threats = Vector2.ZERO
		for threat in immediate_threats:
			away_from_threats += (global_position - threat.global_position).normalized()

		current_direction = _get_cardinal_direction(away_from_threats.normalized())
		last_facing_direction = (ai_target.global_position - global_position).normalized()
	else:
		# Single threat - fight normally but with more caution
		var direction_to_target = (ai_target.global_position - global_position).normalized()
		current_direction = _get_cardinal_direction(direction_to_target)
		last_facing_direction = current_direction

	_try_fire_at_target()

func _force_reengage(distance_to_target: float) -> void:
	var next_state = "flank"
	if distance_to_target > 320.0:
		next_state = "hunt"
	ai_decision_timer = 0.0
	_set_state(next_state)

## Convert arbitrary direction to cardinal direction
func _get_cardinal_direction(direction: Vector2) -> Vector2:
	if direction.length_squared() < 0.1:
		return Vector2.ZERO

	var abs_x = abs(direction.x)
	var abs_y = abs(direction.y)

	if abs_x > abs_y:
		return Vector2.RIGHT if direction.x > 0 else Vector2.LEFT
	else:
		return Vector2.DOWN if direction.y > 0 else Vector2.UP

## Try to fire at target based on AI profile timing
func _try_fire_at_target():
	if not ai_target or ai_reaction_timer > 0.0:
		return

	var distance_to_target = global_position.distance_to(ai_target.global_position)
	var weapon_config = ai_profile.get("weapon_usage", {}).get("machine_gun", {})
	var min_range = weapon_config.get("preferred_range_min", 120.0)
	var max_range = weapon_config.get("preferred_range_max", 480.0)

	# Check if target is in preferred range
	if distance_to_target >= min_range and distance_to_target <= max_range:
		fire_primary_weapon()

		# Set reaction timer based on burst timing
		var burst_config = ai_profile.get("weapon_usage", {}).get("machine_gun", {})
		ai_reaction_timer = burst_config.get("burst_cooldown_sec", 0.6)

## Apply AI movement with same physics as player car
func _apply_ai_movement(delta):
	# Apply movement based on AI direction with terrain modifiers (mirrors player_car physics)
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
		_effective_max_speed = effective_max_speed
		var desired = current_direction * effective_max_speed

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

		# Realistic vehicle physics: Velocity decomposition with lateral friction (mirrors player car)
		var mass_scalar = vehicle_health.get_mass_scalar() if vehicle_health else 1.0
		var current_speed = velocity.length()

		if current_speed > 1.0:
			# Decompose velocity into forward and lateral components based on current facing direction
			var forward_direction = current_direction if current_direction != Vector2.ZERO else Vector2.UP
			var right_direction = Vector2(forward_direction.y, -forward_direction.x)  # Perpendicular to forward

			# Calculate forward and lateral velocity components
			var forward_velocity = forward_direction * velocity.dot(forward_direction)
			var lateral_velocity = right_direction * velocity.dot(right_direction)

			# Calculate drift factor for natural sliding physics
			var drift_factor = _calculate_drift_factor(current_speed, mass_scalar)

			# Apply drift factor - preserves controlled lateral momentum for natural sliding
			var preserved_lateral = lateral_velocity * drift_factor

			# Reconstruct velocity with preserved lateral momentum (creates natural sliding)
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

## Fire primary weapon (reuses player car logic)
func fire_primary_weapon():
	if bullet_scene == null:
		return

	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time < _next_fire_time:
		return

	var bullet = GameManager.spawn_bullet(bullet_scene, global_position, last_facing_direction, self)

	muzzle_flash.visible = true
	get_tree().create_timer(0.1).timeout.connect(func(): muzzle_flash.visible = false)

	_next_fire_time = current_time + (1.0 / fire_rate)

## Public health system interface (copied from player car)
func apply_damage(amount: float, source = null) -> void:
	if vehicle_health:
		vehicle_health.apply_damage(amount, source)

	# Track attacker for revenge targeting
	if source and is_instance_valid(source) and source != self:
		ai_last_attacker = source
		ai_last_damage_time = Time.get_ticks_msec() / 1000.0
		_debug_log("Revenge target set: " + source.name + " (damage: " + str(amount) + ")")

func get_current_hp() -> float:
	if vehicle_health:
		return vehicle_health.current_hp
	return 0.0

func get_max_hp() -> float:
	if vehicle_health:
		return vehicle_health.max_hp
	return 0.0

func is_dead() -> bool:
	if vehicle_health:
		return vehicle_health.is_dead()
	return false

func get_mass_scalar() -> float:
	if vehicle_health:
		return vehicle_health.get_mass_scalar()
	return 1.0

func _on_vehicle_died():
	_debug_log("EnemyCar died! HP: " + str(get_current_hp()) + "/" + str(get_max_hp()))
	# TODO: Add death effects, cleanup, etc.

## Terrain and collision handling (copied from player car)
func _update_direction_lock_timer(delta: float):
	if _direction_lock_timer > 0.0:
		_direction_lock_timer -= delta

## Update collision immunity timer
func _update_collision_immunity_timer(delta: float):
	if _collision_immunity_timer > 0.0:
		_collision_immunity_timer -= delta

func _update_terrain_modifiers(delta: float):
	if _terrain_transition_timer > 0.0:
		_terrain_transition_timer -= delta
		_terrain_transition_elapsed += delta
		var progress = clamp(_terrain_transition_elapsed / _terrain_transition_time, 0.0, 1.0)
		var eased_progress = _apply_transition_curve(progress, _transition_curve_type)

		_current_terrain_modifiers.accel = lerp(_start_terrain_modifiers.accel, _target_terrain_modifiers.accel, eased_progress)
		_current_terrain_modifiers.speed = lerp(_start_terrain_modifiers.speed, _target_terrain_modifiers.speed, eased_progress)
		_current_terrain_modifiers.handling = lerp(_start_terrain_modifiers.handling, _target_terrain_modifiers.handling, eased_progress)
		_current_terrain_modifiers.brake = lerp(_start_terrain_modifiers.brake, _target_terrain_modifiers.brake, eased_progress)
		_effective_max_speed = max_speed * _current_terrain_modifiers.speed
	else:
		if _current_terrain_modifiers != _target_terrain_modifiers:
			_current_terrain_modifiers = _target_terrain_modifiers.duplicate(true)
		_effective_max_speed = max_speed * _current_terrain_modifiers.speed

func _on_collision_sensor_area_entered(area):
	_detect_terrain_change(area)

	if area.is_in_group("destructible"):
		if velocity.length() < min_bounce_velocity:
			return

		var normal = (global_position - area.global_position).normalized()
		var other_velocity = Vector2.ZERO
		var target_destroyed = _apply_collision_damage(area, normal, other_velocity)

		if not target_destroyed:
			_apply_bounce(normal, area, other_velocity)

func _on_collision_sensor_area_exited(area):
	var overlapping_areas = collision_sensor.get_overlapping_areas()
	var found_terrain = false

	for overlapping_area in overlapping_areas:
		if overlapping_area == area:
			continue

		for terrain_name in TERRAIN_MODIFIERS.keys():
			if overlapping_area.is_in_group(terrain_name):
				var new_modifiers = TERRAIN_MODIFIERS[terrain_name]
				_set_target_surface(new_modifiers, "AI terrain change: " + terrain_name, terrain_name)
				found_terrain = true
				break

		if found_terrain:
			break

	if not found_terrain:
		var track_modifiers = TERRAIN_MODIFIERS.terrain_track
		_set_target_surface(track_modifiers, "AI terrain reverted to track", "terrain_track")

func _detect_terrain_change(area: Area2D):
	for terrain_name in TERRAIN_MODIFIERS.keys():
		if area.is_in_group(terrain_name):
			var new_modifiers = TERRAIN_MODIFIERS[terrain_name]
			_set_target_surface(new_modifiers, "AI terrain change: " + terrain_name, terrain_name)
			return

	var track_modifiers = TERRAIN_MODIFIERS.terrain_track
	_set_target_surface(track_modifiers, "AI terrain default: track", "terrain_track")

func _set_target_surface(modifiers: Dictionary, debug_message: String = "", new_terrain_type: String = ""):
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

		# Immediately clamp velocity to new speed cap for noticeable feedback
		var surface_speed_cap = max_speed * modifiers.speed
		if velocity.length() > surface_speed_cap:
			if surface_speed_cap <= 0.0:
				velocity = Vector2.ZERO
			else:
				velocity = velocity.normalized() * surface_speed_cap

func _handle_slide_collisions():
	if get_slide_collision_count() == 0:
		return

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		var normal = collision.get_normal()

		if collider == null:
			continue

		var other_velocity = Vector2.ZERO
		if collider.has_method("get_velocity"):
			other_velocity = collider.get_velocity()
		elif collider is CharacterBody2D:
			other_velocity = collider.velocity

		var target_destroyed = _apply_collision_damage(collider, normal, other_velocity)

		if not target_destroyed:
			_apply_bounce(normal, collider, other_velocity)

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

## TODO: Mirror any future collision tuning changes from player car
func _apply_collision_damage(target, normal: Vector2, other_velocity: Vector2) -> bool:
	# Check collision immunity first
	if _collision_immunity_timer > 0.0:
		if DEBUG_COLLISION_DAMAGE:
			print("[EnemyCar:%s] Still immune (%.2fs remaining), ignoring collision" % [roster_id, _collision_immunity_timer])
		return false

	var relative_velocity = velocity - other_velocity
	var impact_speed = abs(relative_velocity.dot(normal))

	if DEBUG_COLLISION_DAMAGE:
		print("[EnemyCar:%s] Impact with %s - Speed: %.1f" % [roster_id, target.name, impact_speed])

	if impact_speed <= 95.0:
		if DEBUG_COLLISION_DAMAGE:
			print("[EnemyCar:%s] Impact too low (%.1f <= 95), ignoring" % [roster_id, impact_speed])
		return false

	var forward_direction = last_facing_direction.normalized()
	var aggressor_dot = forward_direction.dot(-normal)
	var is_aggressor = aggressor_dot >= 0.86

	var self_mass_scalar = get_mass_scalar()
	var base_damage_factor = max(impact_speed - 95.0, 0.0)
	var target_damage: float
	var self_damage: float

	if DEBUG_COLLISION_DAMAGE:
		print("[EnemyCar:%s] Aggressor: %s, Mass: %.2f, BaseDmg: %.1f" % [roster_id, is_aggressor, self_mass_scalar, base_damage_factor])

	if is_aggressor:
		target_damage = base_damage_factor * 0.22 * self_mass_scalar
		self_damage = base_damage_factor * 0.12 * self_mass_scalar
	else:
		target_damage = base_damage_factor * 0.22 * self_mass_scalar * 0.3
		self_damage = base_damage_factor * 0.12 * self_mass_scalar * 0.5

	if target.is_in_group("indestructible"):
		self_damage = base_damage_factor * 0.25 * self_mass_scalar
		if DEBUG_COLLISION_DAMAGE:
			print("[EnemyCar:%s] Indestructible target - enhanced self-damage: %.1f" % [roster_id, self_damage])

	var target_destroyed := false

	if target_damage > 0:
		if target.is_in_group("vehicles") and target.has_method("apply_damage"):
			var max_target_damage = target.get_max_hp() * 0.20
			target_damage = min(target_damage, max_target_damage)
			if DEBUG_COLLISION_DAMAGE:
				print("[EnemyCar:%s] Vehicle target damage: %.1f (capped at %.1f)" % [roster_id, target_damage, max_target_damage])
			target.apply_damage(target_damage, self)
			if target.has_method("is_dead") and target.is_dead():
				target_destroyed = true
		elif target.is_in_group("destructible") and target.has_method("apply_damage"):
			var int_damage = int(ceil(target_damage))
			if DEBUG_COLLISION_DAMAGE:
				print("[EnemyCar:%s] Destructible target damage: %d (from %.1f)" % [roster_id, int_damage, target_damage])
			target_destroyed = target.apply_damage(int_damage)

	if self_damage > 0:
		if DEBUG_COLLISION_DAMAGE:
			print("[EnemyCar:%s] Self-damage: %.1f" % [roster_id, self_damage])
		apply_damage(self_damage, target)

	# Set collision immunity to prevent damage spam
	_collision_immunity_timer = collision_immunity_duration
	if DEBUG_COLLISION_DAMAGE:
		print("[EnemyCar:%s] Collision immunity set for %.2fs" % [roster_id, collision_immunity_duration])

	return target_destroyed

## HUD helper: expose friendly display name based on roster data
func get_display_name() -> String:
	if not selected_profile.is_empty():
		var car_name = selected_profile.get("car_name", "")
		if not car_name.is_empty():
			return car_name

		var driver_name = selected_profile.get("driver_name", "")
		if not driver_name.is_empty():
			return driver_name

	if not roster_id.is_empty():
		return roster_id.capitalize()

	return name

## HUD helper: expose health component reference
func get_vehicle_health() -> VehicleHealth:
	return vehicle_health

## Debug logging helper
func _debug_log(msg: String):
	if DEBUG_AI_VEHICLE:
		print("[EnemyCar:" + roster_id + "] ", msg)
func _set_state(new_state: String) -> void:
	if ai_state == new_state:
		return

	var previous = ai_state
	ai_state = new_state
	_on_state_changed(new_state, previous)

func _on_state_changed(new_state: String, previous_state: String) -> void:
	if new_state == "retreat":
		ai_retreat_timer = 0.0
	elif previous_state == "retreat":
		ai_retreat_timer = 0.0
		ai_no_retreat_timer = max(ai_no_retreat_timer, ai_retreat_grace_period)
