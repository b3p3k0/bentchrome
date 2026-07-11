class_name AmbientActor
extends Area2D
## Cosmetic pedestrian/animal/prop target. It is an Area rather than a body so
## no car, projectile, or AI feeler can use it as cover. Movement performs its
## own cheap shape probe against authored scenery.

const Floors := preload("res://game/floors.gd")
const SplatScene := preload("res://environment/ambient_splat.tscn")

const SOFT_TARGET_LAYER := 1 << 9
const RUN_OVER_SPEED := 90.0
const PANIC_RADIUS := 240.0
const POLICE_EVADE_RADIUS := 140.0
const PANIC_HOLD := 1.25
const PROBE_RADIUS := 7.0
const ANIM_STEP := 1.0 / 12.0

enum Movement { WANDER, ROUTE, STATIONARY }

@export var kind: StringName = &"civilian"
@export var palette_index := 0
@export var floor_index := -1
@export var movement := Movement.WANDER
@export var move_speed := 55.0
@export var reacts_to_cars := true
@export var leaves_splat := true

var wander_rect := Rect2(-Vector2(100, 100), Vector2(200, 200))
var route: Curve2D = null
var route_progress := 0.0
var route_lane := 0.0
var actor_seed := 1

var _wander_target := Vector2.ZERO
var _route_dir := 1.0
var _panic_t := 0.0
var _panic_dir := Vector2.ZERO
var _idle_t := 0.0
var _anim_t := 0.0
var _anim_accum := 0.0
var _moving := false
var _dead := false
var _rng := RandomNumberGenerator.new()

@onready var _health: Health = $Health

func _ready() -> void:
	collision_layer = SOFT_TARGET_LAYER
	collision_mask = 1  # observe cars without ever becoming a physical obstacle
	_rng.seed = actor_seed
	_health.max_hp = 1.0
	_health.hp = 1.0
	_health.died.connect(_die)
	body_entered.connect(_on_body_entered)
	if movement == Movement.WANDER:
		_pick_wander_target()
	_apply_floor_depth()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_anim_accum += delta
	if _anim_accum >= ANIM_STEP:
		_anim_t += _anim_accum
		_anim_accum = 0.0
		queue_redraw()
	_update_panic(delta)
	if _idle_t > 0.0 and _panic_t <= 0.0:
		_idle_t -= delta
		_moving = false
		return
	var desired := _desired_direction(delta)
	_moving = desired.length_squared() > 0.01
	if not _moving:
		return
	rotation = desired.angle()
	var step := desired * move_speed * delta
	if _position_blocked(global_position + step):
		_on_blocked()
		return
	position += step.rotated(-get_parent().global_rotation if get_parent() is Node2D else 0.0)

func _desired_direction(delta: float) -> Vector2:
	if _panic_t > 0.0:
		return _panic_dir
	match movement:
		Movement.STATIONARY:
			return Vector2.ZERO
		Movement.ROUTE:
			if route == null or route.get_baked_length() <= 0.0:
				return Vector2.ZERO
			var length := route.get_baked_length()
			route_progress = wrapf(route_progress + move_speed * _route_dir * delta, 0.0, length)
			var target := _route_point(route_progress + 12.0 * _route_dir)
			return (get_parent().to_global(target) - global_position).normalized()
		_:
			if position.distance_to(_wander_target) < 12.0:
				_idle_t = _rng.randf_range(0.25, 1.1)
				_pick_wander_target()
			return (_wander_target - position).normalized()

func _route_point(offset: float) -> Vector2:
	var length := route.get_baked_length()
	var p := route.sample_baked(wrapf(offset, 0.0, length), true)
	var before := route.sample_baked(wrapf(offset - 5.0, 0.0, length), true)
	var after := route.sample_baked(wrapf(offset + 5.0, 0.0, length), true)
	var tangent := (after - before).normalized()
	return p + tangent.orthogonal() * route_lane

func _pick_wander_target() -> void:
	_wander_target = Vector2(
		_rng.randf_range(wander_rect.position.x, wander_rect.end.x),
		_rng.randf_range(wander_rect.position.y, wander_rect.end.y))

func _update_panic(delta: float) -> void:
	_panic_t = maxf(_panic_t - delta, 0.0)
	if not reacts_to_cars:
		return
	var radius := POLICE_EVADE_RADIUS if kind == &"police" else PANIC_RADIUS
	var nearest: Node2D = null
	var nearest_d := radius
	for candidate in get_tree().get_nodes_in_group(&"vehicles"):
		if not candidate is Node2D or not Floors.same_floor(self, candidate):
			continue
		var d := global_position.distance_to(candidate.global_position)
		if d < nearest_d:
			nearest_d = d
			nearest = candidate
	if nearest:
		_panic_dir = (global_position - nearest.global_position).normalized()
		if _panic_dir == Vector2.ZERO:
			_panic_dir = Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU))
		_panic_t = PANIC_HOLD
	elif _panic_t <= 0.0 and movement == Movement.ROUTE and route:
		route_progress = route.get_closest_offset(get_parent().to_local(global_position))

func _on_body_entered(body: Node2D) -> void:
	if _dead or not body.is_in_group(&"vehicles") or not Floors.same_floor(self, body):
		return
	var speed: float = body.velocity.length() if "velocity" in body else 0.0
	if speed >= RUN_OVER_SPEED:
		_health.take_damage(1.0)
	elif reacts_to_cars:
		_panic_dir = (global_position - body.global_position).normalized()
		_panic_t = PANIC_HOLD

func _position_blocked(at: Vector2) -> bool:
	if not is_inside_tree():
		return false
	var shape := CircleShape2D.new()
	shape.radius = PROBE_RADIUS
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, at)
	params.collision_mask = 2 | 4 | (Floors.floor_bit(floor_index) if floor_index >= 1 else 0)
	params.collide_with_areas = false
	for hit in get_world_2d().direct_space_state.intersect_shape(params, 32):
		var collider: Node = hit.collider
		if collider == self or collider.is_in_group(&"vehicles"):
			continue
		return true
	return false

func _on_blocked() -> void:
	if movement == Movement.ROUTE:
		_route_dir *= -1.0
	elif movement == Movement.WANDER:
		_pick_wander_target()
	_panic_t = 0.0

func _apply_floor_depth() -> void:
	z_index = 2 if floor_index >= 3 else 0

func _die() -> void:
	if _dead:
		return
	_dead = true
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	if host and leaves_splat:
		var splat := SplatScene.instantiate() as AmbientSplat
		splat.floor_index = floor_index
		host.add_child(splat)
		splat.global_position = global_position
	queue_free()

func _draw() -> void:
	# Card 1's common readable body. District cards add bespoke silhouettes.
	var stride := sin(_anim_t * 10.0 + float(actor_seed % 17)) * (3.0 if _moving else 0.5)
	draw_circle(Vector2(2, 3), 7.0, Color(0, 0, 0, 0.25))
	draw_line(Vector2(-5, -3), Vector2(-10, -5 + stride), Color(0.12, 0.12, 0.15), 3.0)
	draw_line(Vector2(-5, 3), Vector2(-10, 5 - stride), Color(0.12, 0.12, 0.15), 3.0)
	var coats := [Color(0.35, 0.38, 0.44), Color(0.18, 0.3, 0.52), Color(0.2, 0.45, 0.28)]
	draw_rect(Rect2(-7, -5, 13, 10), coats[palette_index % coats.size()])
	draw_circle(Vector2(7, 0), 4.5, Color(0.72, 0.54, 0.42))
