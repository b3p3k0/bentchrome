extends CharacterBody2D

@export var max_speed: float = 200.0
@export var acceleration: float = 800.0
@export var deceleration: float = 600.0
@export var bullet_scene: PackedScene
@export var fire_rate: float = 5.0

var _next_fire_time := 0.0
var _aim_dir := Vector2.UP

@onready var muzzle := $Muzzle

func _ready():
	print("PlayerCar initialized")

func _physics_process(delta):
	handle_input(delta)
	move_and_slide()

func handle_input(delta):
	var input_dir = Vector2.ZERO

	if Input.is_action_pressed("move_up"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_down"):
		input_dir.y += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1

	# Normalize diagonal movement
	if input_dir.length() > 0:
		input_dir = input_dir.normalized()
		velocity = velocity.move_toward(input_dir * max_speed, acceleration * delta)
		# Update aim direction when moving
		_aim_dir = input_dir.normalized()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)

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

	# Check aim direction is valid
	if _aim_dir == Vector2.ZERO:
		return

	# Check fire rate cooldown (convert milliseconds to seconds)
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time < _next_fire_time:
		return

	# Create and configure bullet
	var bullet = bullet_scene.instantiate()
	bullet.global_position = muzzle.global_position
	bullet.direction = _aim_dir.normalized()

	# Add bullet to scene tree at root level
	get_tree().current_scene.add_child(bullet)

	# Update next fire time based on fire rate
	_next_fire_time = current_time + (1.0 / fire_rate)