extends Area2D

@export var respawn_delay: float = 1.5
@export_range(1, 10) var max_hits: int = 3
@export var move_axis: Vector2 = Vector2.ZERO
@export var move_distance: float = 0.0
@export var move_speed: float = 100.0
@export var auto_move: bool = false

@onready var respawn_timer: Timer = $RespawnTimer
@onready var visual: Polygon2D = $Polygon2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var spawn_position: Vector2
var current_direction: float = 1.0
var is_alive: bool = true
var saved_move_position: float = 0.0
var current_hits: int

func reset_health():
	current_hits = max_hits

func _ready():
	if not respawn_timer:
		push_warning("ArenaTarget: Missing RespawnTimer child node")
		return

	if not visual:
		push_warning("ArenaTarget: Missing Polygon2D child node")

	if not collision:
		push_warning("ArenaTarget: Missing CollisionShape2D child node")

	if not animation_player:
		push_warning("ArenaTarget: Missing AnimationPlayer child node")

	add_to_group("targets")
	add_to_group("destructible")
	spawn_position = global_position
	reset_health()

	if auto_move and move_distance > 0:
		move_axis = move_axis.normalized()
		if move_axis.is_zero_approx():
			push_warning("ArenaTarget: move_axis is zero, disabling auto_move")
			auto_move = false

	respawn_timer.wait_time = respawn_delay
	respawn_timer.one_shot = true
	respawn_timer.timeout.connect(_on_respawn_timer_timeout)

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _process(delta):
	if not is_alive or not auto_move or move_distance <= 0:
		return

	var movement = move_axis * move_speed * current_direction * delta
	saved_move_position += movement.length() * current_direction

	if abs(saved_move_position) >= move_distance:
		saved_move_position = clampf(saved_move_position, -move_distance, move_distance)
		current_direction *= -1.0

	global_position = spawn_position + move_axis * saved_move_position

func apply_damage(amount: int = 1) -> bool:
	if amount <= 0:
		return false

	if not is_alive:
		return false

	current_hits -= amount
	if current_hits <= 0:
		_trigger_hit()
		return true
	return false

func apply_collision_damage(amount: int = 1) -> bool:
	return apply_damage(amount)

func _on_body_entered(body):
	if not is_alive:
		return

	if body.is_in_group("targets"):
		return

	apply_damage()

func _on_area_entered(area):
	if not is_alive:
		return

	if area.is_in_group("targets"):
		return

	apply_damage()

func _trigger_hit():
	if not is_alive:
		return

	is_alive = false

	# Play destroy animation if available, await completion BEFORE hiding visual
	if animation_player and animation_player.has_animation("destroy"):
		animation_player.play("destroy")
		await animation_player.animation_finished

	# Hide visual regardless of animation success/failure
	if visual:
		visual.visible = false

	if collision:
		collision.set_deferred("disabled", true)

	set_deferred("monitoring", false)
	set_physics_process(false)

	# Reset health before starting respawn timer for clean state
	reset_health()

	if respawn_timer:
		respawn_timer.start()

func _on_respawn_timer_timeout():
	is_alive = true

	# Reset health right before showing visual to prevent "dead" target appearance
	reset_health()

	# Show visual immediately for both animated and fallback cases
	if visual:
		visual.visible = true

	# Play respawn animation if available, await completion BEFORE re-enabling collisions
	if animation_player and animation_player.has_animation("respawn"):
		animation_player.play("respawn")
		await animation_player.animation_finished

	# Re-enable collision/monitoring regardless of animation success/failure
	if collision:
		collision.set_deferred("disabled", false)

	set_deferred("monitoring", true)
	set_physics_process(true)