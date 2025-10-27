extends CharacterBody2D

## PlayerCar with strict 4-direction arcade movement
## WASD moves strictly up/down/left/right with acceleration/deceleration for 16-bit arcade feel
## Last key pressed wins; no diagonal movement; instant rotation snapping to cardinal directions

## Debug flag for vehicle tuning instrumentation
const DEBUG_VEHICLE_TUNING: bool = false
## Debug flag for collision damage calculations
const DEBUG_COLLISION_DAMAGE: bool = true

const VehicleHealth = preload("res://scripts/vehicles/vehicle_health.gd")

## StatRanges resource caching
const STAT_RANGE_PATH := "res://data/balance/StatsRanges.tres"
static var _stat_ranges

@export var max_speed: float = 200.0
@export var acceleration: float = 800.0
@export var deceleration: float = 600.0
@export var brake_force: float = 1200.0  ## Strong deceleration when pressing opposite to current movement
@export var bullet_scene: PackedScene
@export var fire_rate: float = 5.0
@export var bounce_damp: float = 0.55
@export var bounce_push: float = 80.0
@export var min_bounce_velocity: float = 5.0

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

const TERRAIN_MODIFIERS = {
	"terrain_track": {"accel": 1.0, "speed": 1.0, "handling": 1.0, "brake": 1.0},
	"terrain_sand": {"accel": 0.2, "speed": 0.5, "handling": 0.12, "brake": 0.35},
	"terrain_grass": {"accel": 0.5, "speed": 0.75, "handling": 0.45, "brake": 0.8},
	"terrain_ice": {"accel": 0.3, "speed": 1.3, "handling": 0.08, "brake": 0.25},
	"terrain_snow": {"accel": 0.25, "speed": 0.5, "handling": 0.2, "brake": 0.4},
	"terrain_water": {"accel": 0.25, "speed": 1.4, "handling": 0.05, "brake": 0.15}
}

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

var _next_fire_time := 0.0
var current_direction := Vector2.ZERO  ## Active cardinal input direction
var last_facing_direction := Vector2.UP  ## Persists for firing/visuals when no input
var pressed_directions: Array[Vector2] = []  ## Stack of currently held directions
var selected_profile: Dictionary = {}  ## Selected character profile from roster

## Health system variables
var vehicle_health
var _cached_armor_stat: int = 5  ## Cache 1-10 armor for collision calculations

## Enhanced handling variables
var _derived_stats: Dictionary = {}  ## Cached derived stats for armor/special_power
var _direction_lock_timer: float = 0.0  ## Timer preventing rapid direction changes
var _handling_lock_duration: float = 0.1  ## Duration to lock direction changes
var _lateral_drag_multiplier: float = 1.0  ## Handling-based drag on turns
var _snap_smoothing_factor: float = 0.5  ## Visual rotation smoothing factor

## Terrain tracking variables
var _current_terrain_modifiers: Dictionary = {"accel": 1.0, "speed": 1.0, "handling": 1.0, "brake": 1.0}
var _target_terrain_modifiers: Dictionary = {"accel": 1.0, "speed": 1.0, "handling": 1.0, "brake": 1.0}
var _start_terrain_modifiers: Dictionary = {"accel": 1.0, "speed": 1.0, "handling": 1.0, "brake": 1.0}
var _terrain_transition_time: float = 0.2  ## Time to interpolate terrain changes
var _terrain_transition_timer: float = 0.0
var _terrain_transition_elapsed: float = 0.0
var _effective_max_speed: float = 0.0  ## Cached speed cap after terrain modifiers

@onready var muzzle := $Muzzle
@onready var muzzle_flash := $Visuals/MuzzleFlash
@onready var visuals := $Visuals
@onready var collision_sensor := $CollisionSensor
@onready var body_color := $Visuals/BodyColor
@onready var accent_color := $Visuals/AccentColor

func _ready():
	print("PlayerCar initialized")
	collision_sensor.area_entered.connect(_on_collision_sensor_area_entered)
	collision_sensor.area_exited.connect(_on_collision_sensor_area_exited)

	# Initialize vehicle health component
	vehicle_health = VehicleHealth.new()
	add_child(vehicle_health)
	vehicle_health.died.connect(_on_vehicle_died)

	if SelectionState.has_selection():
		selected_profile = SelectionState.get_selection()
		var car_name = selected_profile.get("car_name", "Unknown")
		var driver_name = selected_profile.get("driver_name", "Unknown")
		print("Selected car: ", car_name, " (driver: ", driver_name, ")")
		_apply_character_stats()
	else:
		print("No character selected, using default stats")

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
			# Gentle slope for low stats, stronger payoff for high stats
			return pow(normalized, 0.55)
		"deceleration":
			# Similar to acceleration but slightly different curve
			return pow(normalized, 0.75)
		"brake":
			# Linear for brake force to maintain predictable feel
			return normalized
		"handling":
			# Strong curve for handling - low handling should be very punishing
			return pow(normalized, 0.45)
		"speed":
			# Moderate curve for top speed
			return pow(normalized, 0.6)
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

	# Configure health system with armor stat and cache for collision calculations
	_cached_armor_stat = armor_stat
	if vehicle_health:
		vehicle_health.configure_from_stats(stats)

	# Apply character colors
	_apply_character_colors()

	_effective_max_speed = max_speed

	# Debug logging
	_debug_log("Applied stats - Max Speed: " + str(max_speed) + ", Acceleration: " + str(acceleration) + ", Handling Lock: " + str(_handling_lock_duration))
	_debug_log("Derived stats - Armor: " + str(_derived_stats.armor) + ", Special Power: " + str(_derived_stats.special_power))
	_debug_log("Stat curves - Accel: " + str(accel_curve) + ", Speed: " + str(speed_curve) + ", Handling: " + str(handling_curve))

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
	handle_input(delta)
	move_and_slide()
	_handle_slide_collisions()

	# Snap visual rotation to cardinal directions when actively moving with enhanced smoothing
	if current_direction != Vector2.ZERO:
		var target_rotation = current_direction.angle() + PI / 2  # +PI/2 because front points up at 0 rotation
		if _snap_smoothing_factor < 1.0:
			visuals.rotation = lerp_angle(visuals.rotation, target_rotation, _snap_smoothing_factor * delta * 10.0)
		else:
			visuals.rotation = target_rotation

func handle_input(delta):
	# Handle direction priority - check for just-pressed actions first (with direction lock)
	if _direction_lock_timer <= 0.0:
		if Input.is_action_just_pressed("move_up"):
			add_direction(Vector2.UP)
		elif Input.is_action_just_pressed("move_down"):
			add_direction(Vector2.DOWN)
		elif Input.is_action_just_pressed("move_left"):
			add_direction(Vector2.LEFT)
		elif Input.is_action_just_pressed("move_right"):
			add_direction(Vector2.RIGHT)

	# Handle direction releases
	if Input.is_action_just_released("move_up"):
		remove_direction(Vector2.UP)
	if Input.is_action_just_released("move_down"):
		remove_direction(Vector2.DOWN)
	if Input.is_action_just_released("move_left"):
		remove_direction(Vector2.LEFT)
	if Input.is_action_just_released("move_right"):
		remove_direction(Vector2.RIGHT)

	# Apply movement based on current direction with terrain modifiers
	if current_direction == Vector2.ZERO:
		# No input - apply coasting deceleration with terrain/handling modifiers
		var effective_deceleration = deceleration * _current_terrain_modifiers.accel * _lateral_drag_multiplier
		velocity = velocity.move_toward(Vector2.ZERO, effective_deceleration * delta)
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

		# Apply lateral drag when turning (if velocity and direction aren't aligned)
		if velocity.length() > 1.0:
			var alignment = abs(current_direction.dot(velocity.normalized()))
			if alignment < 0.9:  # Not perfectly aligned (turning)
				accel_rate *= _lateral_drag_multiplier

		# Apply throttle curve for non-linear acceleration (only when not braking)
		var step_distance = accel_rate * delta
		if not opposite_direction:
			# Calculate normalized gap between current and desired speed
			var current_speed = velocity.length()
			var desired_speed = desired.length()
			if desired_speed > 0.0:
				var speed_gap = 1.0 - (current_speed / desired_speed)
				speed_gap = clamp(speed_gap, 0.0, 1.0)
				# Apply easing curve - fast cars reach ~60% quickly, slow cars ramp gradually
				var eased_gap = _ease_out(speed_gap)
				step_distance *= (0.4 + (eased_gap * 0.6))  # Scale between 40% and 100% of normal step

		# Update velocity toward desired direction
		velocity = velocity.move_toward(desired, step_distance)

		# Clamp velocity magnitude to prevent overspeed
		if velocity.length() > effective_max_speed:
			velocity = velocity.normalized() * effective_max_speed

	# Primary weapon firing with rate limiting
	if Input.is_action_pressed("fire_primary"):
		fire_primary_weapon()

	if Input.is_action_just_pressed("fire_special"):
		print("Special weapon fired")

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
	# Timer signal connection ensures flash automatically disappears
	muzzle_flash.visible = true
	get_tree().create_timer(0.1).timeout.connect(func(): muzzle_flash.visible = false)

	# Update next fire time based on fire rate
	_next_fire_time = current_time + (1.0 / fire_rate)

func add_direction(dir: Vector2):
	# Add direction to stack if not already present
	if dir not in pressed_directions:
		pressed_directions.append(dir)
	# Set as current direction and update facing
	current_direction = dir
	last_facing_direction = dir
	# Start direction lock timer to prevent rapid changes
	_direction_lock_timer = _handling_lock_duration

func remove_direction(dir: Vector2):
	# Remove direction from stack
	pressed_directions.erase(dir)
	# Fall back to most recent remaining direction or zero
	if pressed_directions.size() > 0:
		current_direction = pressed_directions[-1]
	else:
		current_direction = Vector2.ZERO

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

		# Apply physics-based collision damage
		var target_destroyed = _apply_collision_damage(collider, normal, other_velocity)

		# Apply bounce if target wasn't destroyed
		if not target_destroyed:
			_apply_bounce(normal)

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
			_apply_bounce(normal)

func _apply_bounce(normal: Vector2):
	if velocity.length() < min_bounce_velocity:
		return

	if normal.is_zero_approx():
		normal = -velocity.normalized()
	else:
		normal = normal.normalized()

	velocity = velocity.bounce(normal) * bounce_damp
	velocity += normal * bounce_push

## Apply physics-based collision damage with aggressor/victim calculation
func _apply_collision_damage(target, normal: Vector2, other_velocity: Vector2) -> bool:
	# Calculate relative impact speed along collision normal
	var relative_velocity = velocity - other_velocity
	var impact_speed = abs(relative_velocity.dot(normal))

	if DEBUG_COLLISION_DAMAGE:
		print("[CollisionDamage] Impact with %s - Speed: %.1f" % [target.name, impact_speed])

	# Ignore trivial bumps
	if impact_speed <= 50.0:
		if DEBUG_COLLISION_DAMAGE:
			print("[CollisionDamage] Impact too low (%.1f <= 50), ignoring" % impact_speed)
		return false

	# Determine if we're the aggressor (forward vector within ~30° of -normal)
	var forward_direction = last_facing_direction.normalized()
	var aggressor_dot = forward_direction.dot(-normal)
	var is_aggressor = aggressor_dot >= 0.86  # cos(30°) ≈ 0.866

	# Get our mass scalar for damage calculations
	var self_mass_scalar = get_mass_scalar()

	if DEBUG_COLLISION_DAMAGE:
		print("[CollisionDamage] Aggressor check: dot=%.3f, is_aggressor=%s, mass_scalar=%.2f" % [aggressor_dot, is_aggressor, self_mass_scalar])

	# Calculate base damage values
	var base_damage_factor = (impact_speed - 50.0)
	var target_damage: float
	var self_damage: float

	if is_aggressor:
		# Head-on collision - full damage
		target_damage = base_damage_factor * 0.6 * self_mass_scalar
		self_damage = base_damage_factor * 0.25 * self_mass_scalar
	else:
		# Glancing/rear-end collision - reduced damage
		target_damage = base_damage_factor * 0.6 * self_mass_scalar * 0.3
		self_damage = base_damage_factor * 0.25 * self_mass_scalar * 0.5

	# Enhanced self-damage for indestructible targets (walls, etc.)
	if target.is_in_group("indestructible"):
		self_damage = base_damage_factor * 0.4 * self_mass_scalar
		if DEBUG_COLLISION_DAMAGE:
			print("[CollisionDamage] Indestructible target - enhanced self-damage: %.1f" % self_damage)

	var target_destroyed := false

	# Apply damage to target
	if target_damage > 0:
		if target.is_in_group("vehicles") and target.has_method("apply_damage"):
			# Cap vehicle damage at 70% of max HP
			var max_target_damage = target.get_max_hp() * 0.7
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

	return target_destroyed

## New helper functions for enhanced systems

func _update_direction_lock_timer(delta: float):
	if _direction_lock_timer > 0.0:
		_direction_lock_timer -= delta

func _update_terrain_modifiers(delta: float):
	# Smoothly interpolate toward target terrain modifiers
	if _terrain_transition_timer > 0.0:
		_terrain_transition_timer -= delta
		_terrain_transition_elapsed += delta
		var progress = clamp(_terrain_transition_elapsed / _terrain_transition_time, 0.0, 1.0)
		var eased_progress = _ease_out(progress, 0.65)

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
			_set_target_surface(new_modifiers, "Terrain change detected: " + terrain_name)
			return

	# No terrain detected - default to track (if not already)
	var track_modifiers = TERRAIN_MODIFIERS.terrain_track
	_set_target_surface(track_modifiers, "Terrain change detected: terrain_track (default)")

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
				_set_target_surface(new_modifiers, "Terrain exit - switched to: " + terrain_name)

				found_terrain = true
				break

		if found_terrain:
			break

	# If no terrain found, default back to track
	if not found_terrain:
		var track_modifiers = TERRAIN_MODIFIERS.terrain_track
		_set_target_surface(track_modifiers, "Terrain exit - reverted to track")

## Set target surface with enhanced transition smoothing
func _set_target_surface(modifiers: Dictionary, debug_message: String = ""):
	# Check if modifiers actually changed
	if (_target_terrain_modifiers.accel != modifiers.accel or
		_target_terrain_modifiers.speed != modifiers.speed or
		_target_terrain_modifiers.handling != modifiers.handling or
		_target_terrain_modifiers.brake != modifiers.brake):

		_start_terrain_modifiers = _current_terrain_modifiers.duplicate(true)
		_target_terrain_modifiers = modifiers.duplicate(true)
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
