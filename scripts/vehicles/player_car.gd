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

var _next_fire_time := 0.0
var current_direction := Vector2.ZERO  ## Active cardinal input direction
var last_facing_direction := Vector2.UP  ## Persists for firing/visuals when no input
var pressed_directions: Array[Vector2] = []  ## Stack of currently held directions
var selected_profile: Dictionary = {}  ## Selected character profile from roster

@onready var muzzle := $Muzzle
@onready var muzzle_flash := $Visuals/MuzzleFlash
@onready var visuals := $Visuals
@onready var collision_sensor := $CollisionSensor

func _ready():
	print("PlayerCar initialized")
	collision_sensor.area_entered.connect(_on_collision_sensor_area_entered)

	# Check for selected character profile and apply stats
	if SelectionState.has_selection():
		selected_profile = SelectionState.get_selection()
		var car_name = selected_profile.get("car_name", "Unknown")
		var driver_name = selected_profile.get("driver_name", "Unknown")
		print("Selected car: ", car_name, " (driver: ", driver_name, ")")

		# Apply character stats to vehicle performance
		# TODO: These mappings are temporary until real handling model is finalized
		_apply_character_stats()
	else:
		print("No character selected, using default stats")

func _apply_character_stats():
	if selected_profile.is_empty():
		return

	var stats = selected_profile.get("stats", {})

	# TODO: Temporary stat mapping - replace with proper handling model
	# Base values + stat multipliers (1-5 scale)
	var base_speed = 150.0
	var base_accel = 600.0

	max_speed = base_speed + (stats.get("top_speed", 3) * 25.0)  # 175-275 range
	acceleration = base_accel + (stats.get("acceleration", 3) * 50.0)  # 650-850 range

	# TODO: Add handling, armor, and special power mappings when systems exist
	# var handling_modifier = stats.get("handling", 3)  # Affects turn rate/drift
	# var armor_modifier = stats.get("armor", 3)  # Affects collision damage resistance
	# var special_power = stats.get("special_power", 3)  # Affects special weapon effectiveness

	print("Applied stats - Max Speed: ", max_speed, ", Acceleration: ", acceleration)

func _physics_process(delta):
	handle_input(delta)
	move_and_slide()
	_handle_slide_collisions()

	# Snap visual rotation to cardinal directions when actively moving
	if current_direction != Vector2.ZERO:
		visuals.rotation = current_direction.angle() + PI / 2  # +PI/2 because front points up at 0 rotation

func handle_input(delta):
	# Handle direction priority - check for just-pressed actions first
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

	# Apply movement based on current direction
	if current_direction == Vector2.ZERO:
		# No input - apply coasting deceleration
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)
	else:
		# Calculate desired velocity from current direction
		var desired = current_direction * max_speed

		# Determine if we're moving in the opposite direction (with guard for zero velocity)
		var opposite_direction = false
		if velocity.length() > 1.0:
			opposite_direction = current_direction.dot(velocity.normalized()) < 0

		# Choose acceleration rate based on direction
		var accel_rate: float
		if opposite_direction:
			accel_rate = brake_force  # Quick braking when pressing opposite direction
		else:
			accel_rate = acceleration  # Normal acceleration

		# Update velocity toward desired direction
		velocity = velocity.move_toward(desired, accel_rate * delta)

		# Clamp velocity magnitude to prevent overspeed
		if velocity.length() > max_speed:
			velocity = velocity.normalized() * max_speed

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
	if not area.is_in_group("destructible"):
		return

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