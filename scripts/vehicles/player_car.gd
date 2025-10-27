extends CharacterBody2D

## PlayerCar with strict 4-direction arcade movement
## WASD moves strictly up/down/left/right with acceleration/deceleration for 16-bit arcade feel
## Last key pressed wins; no diagonal movement; instant rotation snapping to cardinal directions

@export var max_speed: float = 200.0
@export var acceleration: float = 800.0
@export var deceleration: float = 600.0
@export var brake_force: float = 1200.0  ## Strong deceleration when pressing opposite to current movement
@export var bullet_scene: PackedScene
@export var fire_rate: float = 5.0
@export var collision_damage: int = 1
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
	"terrain_track": {"accel": 1.0, "speed": 1.0, "handling": 1.0},
	"terrain_sand": {"accel": 0.6, "speed": 0.78, "handling": 0.6},
	"terrain_grass": {"accel": 0.85, "speed": 0.92, "handling": 0.8},
	"terrain_ice": {"accel": 0.65, "speed": 1.1, "handling": 0.35},
	"terrain_snow": {"accel": 0.6, "speed": 0.78, "handling": 0.6}
}

var _next_fire_time := 0.0
var current_direction := Vector2.ZERO  ## Active cardinal input direction
var last_facing_direction := Vector2.UP  ## Persists for firing/visuals when no input
var pressed_directions: Array[Vector2] = []  ## Stack of currently held directions
var selected_profile: Dictionary = {}  ## Selected character profile from roster

## Enhanced handling variables
var _derived_stats: Dictionary = {}  ## Cached derived stats for armor/special_power
var _direction_lock_timer: float = 0.0  ## Timer preventing rapid direction changes
var _handling_lock_duration: float = 0.1  ## Duration to lock direction changes
var _lateral_drag_multiplier: float = 1.0  ## Handling-based drag on turns
var _snap_smoothing_factor: float = 0.5  ## Visual rotation smoothing factor

## Terrain tracking variables
var _current_terrain_modifiers: Dictionary = {"accel": 1.0, "speed": 1.0, "handling": 1.0}
var _target_terrain_modifiers: Dictionary = {"accel": 1.0, "speed": 1.0, "handling": 1.0}
var _terrain_transition_time: float = 0.2  ## Time to interpolate terrain changes
var _terrain_transition_timer: float = 0.0

@onready var muzzle := $Muzzle
@onready var muzzle_flash := $Visuals/MuzzleFlash
@onready var visuals := $Visuals
@onready var collision_sensor := $CollisionSensor
@onready var body_color := $Visuals/BodyColor
@onready var accent_color := $Visuals/AccentColor

func _ready():
	print("PlayerCar initialized")
	collision_sensor.area_entered.connect(_on_collision_sensor_area_entered)

	if SelectionState.has_selection():
		selected_profile = SelectionState.get_selection()
		var car_name = selected_profile.get("car_name", "Unknown")
		var driver_name = selected_profile.get("driver_name", "Unknown")
		print("Selected car: ", car_name, " (driver: ", driver_name, ")")
		_apply_character_stats()
	else:
		print("No character selected, using default stats")

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

	# Convert 1-10 scale stats to actual gameplay values using STAT_SCALE ranges
	var accel_stat = stats.get("acceleration", 5)
	var speed_stat = stats.get("top_speed", 5)
	var handling_stat = stats.get("handling", 5)
	var armor_stat = stats.get("armor", 5)
	var special_stat = stats.get("special_power", 5)

	# Lerp stats from 1-10 scale to actual ranges (convert to 0-1 range first)
	var accel_norm = (accel_stat - 1) / 9.0
	var speed_norm = (speed_stat - 1) / 9.0
	var handling_norm = (handling_stat - 1) / 9.0
	var armor_norm = (armor_stat - 1) / 9.0
	var special_norm = (special_stat - 1) / 9.0

	# Apply stat scaling
	max_speed = lerp(STAT_SCALE.max_speed.x, STAT_SCALE.max_speed.y, speed_norm)
	acceleration = lerp(STAT_SCALE.acceleration.x, STAT_SCALE.acceleration.y, accel_norm)
	deceleration = lerp(STAT_SCALE.deceleration.x, STAT_SCALE.deceleration.y, accel_norm)
	brake_force = lerp(STAT_SCALE.brake_force.x, STAT_SCALE.brake_force.y, accel_norm)

	# Enhanced handling variables (lower handling stat = longer lock time, more drag, less smoothing)
	_handling_lock_duration = lerp(STAT_SCALE.handling_lock.x, STAT_SCALE.handling_lock.y, handling_norm)
	_lateral_drag_multiplier = lerp(STAT_SCALE.handling_drag.x, STAT_SCALE.handling_drag.y, handling_norm)
	_snap_smoothing_factor = lerp(STAT_SCALE.handling_snap.x, STAT_SCALE.handling_snap.y, handling_norm)

	# Cache derived stats for future systems
	_derived_stats = {
		"armor": lerp(STAT_SCALE.armor.x, STAT_SCALE.armor.y, armor_norm),
		"special_power": lerp(STAT_SCALE.special_power.x, STAT_SCALE.special_power.y, special_norm)
	}

	# Apply character colors
	_apply_character_colors()

	print("Applied stats - Max Speed: ", max_speed, ", Acceleration: ", acceleration, ", Handling Lock: ", _handling_lock_duration)
	print("Derived stats - Armor: ", _derived_stats.armor, ", Special Power: ", _derived_stats.special_power)

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
		var desired = current_direction * effective_max_speed

		# Determine if we're moving in the opposite direction (with guard for zero velocity)
		var opposite_direction = false
		if velocity.length() > 1.0:
			opposite_direction = current_direction.dot(velocity.normalized()) < 0

		# Choose acceleration rate based on direction with terrain modifiers
		var accel_rate: float
		var effective_accel_modifier = _current_terrain_modifiers.accel * _current_terrain_modifiers.handling
		if opposite_direction:
			accel_rate = brake_force * effective_accel_modifier
		else:
			accel_rate = acceleration * effective_accel_modifier

		# Apply lateral drag when turning (if velocity and direction aren't aligned)
		if velocity.length() > 1.0:
			var alignment = abs(current_direction.dot(velocity.normalized()))
			if alignment < 0.9:  # Not perfectly aligned (turning)
				accel_rate *= _lateral_drag_multiplier

		# Update velocity toward desired direction
		velocity = velocity.move_toward(desired, accel_rate * delta)

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

	# Create and configure bullet
	var bullet = bullet_scene.instantiate()
	bullet.global_position = muzzle.global_position
	bullet.direction = last_facing_direction.normalized()

	# Add bullet to scene tree at root level
	get_tree().current_scene.add_child(bullet)

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

		if collider.is_in_group("indestructible"):
			_apply_bounce(normal)
		elif collider.is_in_group("vehicles"):
			var target_destroyed = _deal_damage_to_body(collider)
			if not target_destroyed:
				_apply_bounce(normal)

func _on_collision_sensor_area_entered(area):
	# Check for terrain changes first
	_detect_terrain_change(area)

	# Handle destructible objects
	if area.is_in_group("destructible"):
		if velocity.length() < min_bounce_velocity:
			return

		var target_destroyed = _deal_damage_to_area(area)
		if not target_destroyed:
			var normal = (global_position - area.global_position).normalized()
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

func _deal_damage_to_body(body) -> bool:
	if body.has_method("apply_collision_damage"):
		return body.apply_collision_damage(collision_damage)
	elif body.has_method("apply_damage"):
		return body.apply_damage(collision_damage)
	return false

func _deal_damage_to_area(area) -> bool:
	if area.has_method("apply_collision_damage"):
		return area.apply_collision_damage(collision_damage)
	elif area.has_method("apply_damage"):
		return area.apply_damage(collision_damage)
	return false

## New helper functions for enhanced systems

func _update_direction_lock_timer(delta: float):
	if _direction_lock_timer > 0.0:
		_direction_lock_timer -= delta

func _update_terrain_modifiers(delta: float):
	# Smoothly interpolate toward target terrain modifiers
	if _terrain_transition_timer > 0.0:
		_terrain_transition_timer -= delta
		var progress = 1.0 - (_terrain_transition_timer / _terrain_transition_time)
		progress = clamp(progress, 0.0, 1.0)

		# Interpolate each modifier
		_current_terrain_modifiers.accel = lerp(_current_terrain_modifiers.accel, _target_terrain_modifiers.accel, progress)
		_current_terrain_modifiers.speed = lerp(_current_terrain_modifiers.speed, _target_terrain_modifiers.speed, progress)
		_current_terrain_modifiers.handling = lerp(_current_terrain_modifiers.handling, _target_terrain_modifiers.handling, progress)

func _detect_terrain_change(area: Area2D):
	# Check if this area represents a terrain type
	for terrain_name in TERRAIN_MODIFIERS.keys():
		if area.is_in_group(terrain_name):
			var new_modifiers = TERRAIN_MODIFIERS[terrain_name]
			# Only start transition if modifiers actually changed
			if (_target_terrain_modifiers.accel != new_modifiers.accel or
				_target_terrain_modifiers.speed != new_modifiers.speed or
				_target_terrain_modifiers.handling != new_modifiers.handling):

				_target_terrain_modifiers = new_modifiers.duplicate()
				_terrain_transition_timer = _terrain_transition_time
				print("Terrain change detected: ", terrain_name)
			return

	# No terrain detected - default to track (if not already)
	var track_modifiers = TERRAIN_MODIFIERS.terrain_track
	if (_target_terrain_modifiers.accel != track_modifiers.accel or
		_target_terrain_modifiers.speed != track_modifiers.speed or
		_target_terrain_modifiers.handling != track_modifiers.handling):

		_target_terrain_modifiers = track_modifiers.duplicate()
		_terrain_transition_timer = _terrain_transition_time
		print("Terrain change detected: terrain_track (default)")
