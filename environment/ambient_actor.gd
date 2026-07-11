class_name AmbientActor
extends Area2D
## Cosmetic pedestrian/animal/prop target. It is an Area rather than a body so
## no car, projectile, or AI feeler can use it as cover. Movement performs its
## own cheap shape probe against authored scenery.

const Floors := preload("res://game/floors.gd")
const SplatScene := preload("res://environment/ambient_splat.tscn")
const ProjectileScene := preload("res://weapons/projectile.tscn")
const FlashScene := preload("res://weapons/muzzle_flash.tscn")

const SOFT_TARGET_LAYER := 1 << 9
const RUN_OVER_SPEED := 90.0
const PANIC_RADIUS := 240.0
const POLICE_EVADE_RADIUS := 140.0
const PANIC_HOLD := 1.25
const PROBE_RADIUS := 7.0
const ANIM_STEP := 1.0 / 12.0
const POLICE_RANGE := 480.0
const POLICE_MIN_CADENCE := 1.4
const POLICE_MAX_CADENCE := 2.2
const POLICE_BULLET_SPEED := 900.0
const POLICE_BULLET_LIFE := 0.7

const DOWNTOWN_KINDS := [&"business_suit", &"business_dress", &"vagrant",
	&"police", &"vendor", &"hotdog_cart"]
const REGIONAL_KINDS := [&"jogger", &"cyclist", &"dog", &"skateboarder", &"mower",
	&"skier", &"deer", &"dock_worker"]
const SUIT_COLORS := [Color(0.38, 0.4, 0.44), Color(0.12, 0.24, 0.48), Color(0.08, 0.09, 0.11)]
const DRESS_COLORS := [Color(0.12, 0.32, 0.68), Color(0.12, 0.52, 0.25), Color(0.72, 0.12, 0.16)]
const SKIN_COLORS := [Color(0.78, 0.59, 0.43), Color(0.56, 0.36, 0.25), Color(0.88, 0.69, 0.52)]

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
var _police_cd := 0.0

@onready var _health: Health = $Health

func _ready() -> void:
	collision_layer = SOFT_TARGET_LAYER
	collision_mask = 1  # observe cars without ever becoming a physical obstacle
	_rng.seed = actor_seed
	_police_cd = _rng.randf_range(POLICE_MIN_CADENCE, POLICE_MAX_CADENCE)
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
	if kind == &"police" and _panic_t <= 0.0 and _police_tick(delta):
		_moving = false
		return
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
	params.collision_mask = Floors.ground_mask(floor_index)
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

func _police_tick(delta: float) -> bool:
	var target := police_target()
	if target == null:
		_police_cd = maxf(_police_cd - delta, 0.0)
		return false
	var direction := (target.global_position - global_position).normalized()
	rotation = direction.angle()
	_police_cd -= delta
	if _police_cd <= 0.0:
		_fire_police(direction)
		_police_cd = _rng.randf_range(POLICE_MIN_CADENCE, POLICE_MAX_CADENCE)
	return true

func police_target() -> Node2D:
	var nearest: Node2D = null
	var nearest_d := POLICE_RANGE
	for candidate in get_tree().get_nodes_in_group(&"player"):
		if not candidate is Node2D or not Floors.same_floor(self, candidate):
			continue
		var d := global_position.distance_to(candidate.global_position)
		if d < nearest_d and _police_los(candidate):
			nearest = candidate
			nearest_d = d
	return nearest

func _police_los(target: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position,
		2 | 4 | (Floors.floor_bit(floor_index) if floor_index >= 1 else 0))
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	for car in get_tree().get_nodes_in_group(&"vehicles"):
		if car is CollisionObject2D:
			query.exclude.append(car.get_rid())
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _fire_police(direction: Vector2) -> void:
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	if host == null:
		return
	var origin := global_position + direction * 12.0
	var shot := ProjectileScene.instantiate() as Projectile
	shot.harms_ambient = false
	shot.modulate = Color(1.0, 0.82, 0.28)
	shot.hit_sfx = &""
	shot.collision_mask = Floors.projectile_mask(floor_index, false)
	host.add_child(shot)
	shot.setup(origin, direction, POLICE_BULLET_SPEED, 0.0, POLICE_BULLET_LIFE, self)
	var flash = FlashScene.instantiate()
	host.add_child(flash)
	flash.setup(origin, direction, false)
	flash.scale *= 0.55

func _apply_floor_depth() -> void:
	z_index = 2 if floor_index >= 3 else 0

func _die() -> void:
	if _dead:
		return
	_dead = true
	set_deferred(&"monitoring", false)
	call_deferred(&"_finish_die")

func _finish_die() -> void:
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	if host and leaves_splat:
		var splat := SplatScene.instantiate() as AmbientSplat
		splat.floor_index = floor_index
		host.add_child(splat)
		splat.global_position = global_position
	elif host:
		_spawn_prop_debris(host)
	queue_free()

func _spawn_prop_debris(host: Node) -> void:
	var puff := CPUParticles2D.new()
	puff.one_shot = true
	puff.emitting = true
	puff.amount = 12
	puff.lifetime = 0.55
	puff.explosiveness = 1.0
	puff.spread = 180.0
	puff.initial_velocity_min = 90.0
	puff.initial_velocity_max = 210.0
	puff.damping_min = 120.0
	puff.damping_max = 240.0
	puff.scale_amount_min = 1.5
	puff.scale_amount_max = 3.5
	puff.color = Color(0.72, 0.42, 0.2, 0.9)
	puff.finished.connect(puff.queue_free)
	host.add_child(puff)
	puff.global_position = global_position

func _draw() -> void:
	var stride := sin(_anim_t * 10.0 + float(actor_seed % 17)) * (3.0 if _moving else 0.5)
	match kind:
		&"business_suit":
			_draw_business(stride, false)
		&"business_dress":
			_draw_business(stride, true)
		&"vagrant":
			_draw_vagrant(stride)
		&"police":
			_draw_police(stride)
		&"vendor":
			_draw_vendor(stride)
		&"hotdog_cart":
			_draw_hotdog_cart()
		&"jogger":
			_draw_jogger(stride)
		&"cyclist":
			_draw_cyclist(stride)
		&"dog":
			_draw_dog(stride)
		&"skateboarder":
			_draw_skateboarder(stride)
		&"mower":
			_draw_mower(stride)
		&"skier":
			_draw_skier(stride)
		&"deer":
			_draw_deer(stride)
		&"dock_worker":
			_draw_dock_worker(stride)
		_:
			_draw_business(stride, false)

func _shadow(radius := 7.0) -> void:
	draw_circle(Vector2(2, 3), radius, Color(0, 0, 0, 0.25))

func _skin() -> Color:
	return SKIN_COLORS[palette_index % SKIN_COLORS.size()]

func _legs(stride: float, color := Color(0.1, 0.1, 0.12)) -> void:
	draw_line(Vector2(-5, -3), Vector2(-10, -5 + stride), color, 3.0)
	draw_line(Vector2(-5, 3), Vector2(-10, 5 - stride), color, 3.0)

func _draw_business(stride: float, dress: bool) -> void:
	_shadow()
	_legs(stride)
	var color: Color = DRESS_COLORS[palette_index % 3] if dress else SUIT_COLORS[palette_index % 3]
	if dress:
		draw_colored_polygon(PackedVector2Array([Vector2(-7, -6), Vector2(6, -4),
			Vector2(6, 4), Vector2(-7, 6)]), color)
	else:
		draw_rect(Rect2(-7, -5, 13, 10), color)
		draw_line(Vector2(-1, -4), Vector2(-1, 4), Color(0.82, 0.82, 0.78), 1.2)
		draw_rect(Rect2(-6, 6, 6, 4), Color(0.25, 0.14, 0.07))
	draw_circle(Vector2(7, 0), 4.5, _skin())

func _draw_vagrant(stride: float) -> void:
	_shadow(8.0)
	_legs(stride * 0.6, Color(0.2, 0.18, 0.16))
	draw_colored_polygon(PackedVector2Array([Vector2(-7, -6), Vector2(4, -5),
		Vector2(7, 0), Vector2(2, 6), Vector2(-8, 5)]), Color(0.3, 0.27, 0.22))
	draw_circle(Vector2(6, 0), 4.5, _skin())
	# Bent wire cart and wheels trail behind the hunched walker.
	draw_rect(Rect2(-19, -7, 9, 14), Color(0.42, 0.43, 0.4), false, 1.5)
	draw_circle(Vector2(-17, -8), 2.5, Color(0.08, 0.08, 0.09))
	draw_circle(Vector2(-17, 8), 2.5, Color(0.08, 0.08, 0.09))
	draw_line(Vector2(-10, -5), Vector2(-3, -4), Color(0.42, 0.43, 0.4), 1.5)

func _draw_police(stride: float) -> void:
	_shadow()
	_legs(stride, Color(0.06, 0.1, 0.22))
	draw_rect(Rect2(-7, -5, 13, 10), Color(0.08, 0.22, 0.5))
	draw_circle(Vector2(7, 0), 4.5, _skin())
	draw_rect(Rect2(7, -5, 4, 10), Color(0.04, 0.12, 0.32))  # cap
	draw_circle(Vector2(0, -2), 1.6, Color(0.95, 0.75, 0.15))  # badge
	draw_line(Vector2(1, 4), Vector2(11, 4), Color(0.1, 0.1, 0.12), 2.0)

func _draw_vendor(stride: float) -> void:
	_shadow()
	_legs(stride * 0.4)
	draw_rect(Rect2(-7, -5, 13, 10), Color(0.88, 0.82, 0.66))
	draw_rect(Rect2(-4, -4, 8, 8), Color(0.75, 0.12, 0.12))
	draw_circle(Vector2(7, 0), 4.5, _skin())
	draw_rect(Rect2(6, -5, 5, 10), Color(0.92, 0.92, 0.86))

func _draw_hotdog_cart() -> void:
	draw_rect(Rect2(-14, -10, 28, 20), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(-13, -9, 24, 18), Color(0.82, 0.18, 0.12))
	draw_rect(Rect2(-10, -7, 18, 14), Color(0.92, 0.82, 0.42))
	draw_line(Vector2(-8, -6), Vector2(7, 6), Color(0.85, 0.12, 0.1), 3.0)
	draw_circle(Vector2(-10, -11), 3.5, Color(0.08, 0.08, 0.09))
	draw_circle(Vector2(-10, 11), 3.5, Color(0.08, 0.08, 0.09))

func _draw_jogger(stride: float) -> void:
	_shadow()
	var suits := [Color(0.75, 0.14, 0.18), Color(0.12, 0.38, 0.75), Color(0.18, 0.62, 0.28)]
	var suit: Color = suits[palette_index % 3]
	_legs(stride * 1.35, suit.darkened(0.25))
	draw_rect(Rect2(-6, -4.5, 12, 9), suit)
	draw_line(Vector2(-1, -4), Vector2(-1, 4), Color(0.9, 0.9, 0.86), 1.0)
	draw_line(Vector2(-1, -4), Vector2(4, -8 - stride), _skin(), 2.0)
	draw_line(Vector2(-1, 4), Vector2(4, 8 + stride), _skin(), 2.0)
	draw_circle(Vector2(7, 0), 4.0, _skin())

func _draw_cyclist(stride: float) -> void:
	_shadow(8.0)
	var frame: Color = [Color(0.15, 0.55, 0.8), Color(0.85, 0.2, 0.15), Color(0.25, 0.7, 0.32)][palette_index % 3]
	for x in [-9.0, 9.0]:
		draw_arc(Vector2(x, 0), 5.0, 0.0, TAU, 12, Color(0.06, 0.06, 0.07), 1.8)
	draw_line(Vector2(-9, 0), Vector2(1, -4), frame, 2.0)
	draw_line(Vector2(1, -4), Vector2(9, 0), frame, 2.0)
	draw_line(Vector2(-9, 0), Vector2(1, 4), frame, 2.0)
	draw_circle(Vector2(1 + stride * 0.15, 0), 4.5, _skin())
	draw_rect(Rect2(-4, -4, 9, 8), frame.darkened(0.15))

func _draw_dog(stride: float) -> void:
	_shadow(6.5)
	var fur: Color = [Color(0.55, 0.33, 0.17), Color(0.72, 0.62, 0.46), Color(0.2, 0.18, 0.16)][palette_index % 3]
	draw_colored_polygon(PackedVector2Array([Vector2(-8, -5), Vector2(5, -4),
		Vector2(7, 4), Vector2(-8, 5)]), fur)
	draw_circle(Vector2(8, 0), 4.0, fur.lightened(0.08))
	draw_colored_polygon(PackedVector2Array([Vector2(8, -3), Vector2(5, -8), Vector2(11, -5)]), fur.darkened(0.2))
	draw_line(Vector2(-7, -3), Vector2(-10, -7 + stride), fur.darkened(0.25), 2.0)
	draw_line(Vector2(-7, 3), Vector2(-10, 7 - stride), fur.darkened(0.25), 2.0)
	draw_line(Vector2(-8, 0), Vector2(-14, sin(_anim_t * 8.0) * 4.0), fur, 2.0)

func _draw_skateboarder(stride: float) -> void:
	_shadow()
	draw_line(Vector2(-11, 5), Vector2(10, 5), Color(0.62, 0.25, 0.12), 3.0)
	draw_circle(Vector2(-8, 7), 1.8, Color(0.05, 0.05, 0.06))
	draw_circle(Vector2(8, 7), 1.8, Color(0.05, 0.05, 0.06))
	var shirt: Color = [Color(0.65, 0.2, 0.7), Color(0.15, 0.62, 0.7), Color(0.85, 0.5, 0.12)][palette_index % 3]
	draw_rect(Rect2(-4, -5, 10, 9), shirt)
	draw_line(Vector2(-3, -2), Vector2(-9, -6 + stride), Color(0.15, 0.16, 0.18), 2.5)
	draw_line(Vector2(-2, 2), Vector2(-10, 4 - stride), Color(0.15, 0.16, 0.18), 2.5)
	draw_circle(Vector2(7, -1), 4.0, _skin())

func _draw_mower(stride: float) -> void:
	_shadow(9.0)
	draw_rect(Rect2(-13, -8, 15, 16), Color(0.12, 0.5, 0.18))
	draw_circle(Vector2(-9, -9), 3.0, Color(0.05, 0.06, 0.05))
	draw_circle(Vector2(-9, 9), 3.0, Color(0.05, 0.06, 0.05))
	draw_line(Vector2(0, -6), Vector2(7, -5), Color(0.25, 0.25, 0.22), 2.0)
	draw_line(Vector2(0, 6), Vector2(7, 5), Color(0.25, 0.25, 0.22), 2.0)
	draw_rect(Rect2(4, -5, 9, 10), Color(0.42, 0.34, 0.2))
	draw_circle(Vector2(13 + stride * 0.08, 0), 4.0, _skin())
	draw_circle(Vector2(-5, 0), 4.0 + sin(_anim_t * 18.0) * 0.5, Color(0.75, 0.78, 0.68, 0.45))

func _draw_skier(stride: float) -> void:
	_shadow()
	var coat: Color = [Color(0.75, 0.18, 0.16), Color(0.12, 0.42, 0.7), Color(0.65, 0.58, 0.16)][palette_index % 3]
	draw_line(Vector2(-12, -6), Vector2(12, -6), Color(0.78, 0.82, 0.88), 1.7)
	draw_line(Vector2(-12, 6), Vector2(12, 6), Color(0.78, 0.82, 0.88), 1.7)
	draw_rect(Rect2(-6, -4, 12, 8), coat)
	draw_circle(Vector2(7, 0), 4.0, _skin())
	draw_line(Vector2(0, -4), Vector2(-5 + stride, -11), Color(0.28, 0.25, 0.2), 1.3)
	draw_line(Vector2(0, 4), Vector2(-5 - stride, 11), Color(0.28, 0.25, 0.2), 1.3)

func _draw_deer(stride: float) -> void:
	_shadow(8.0)
	var hide: Color = [Color(0.48, 0.28, 0.14), Color(0.58, 0.38, 0.2), Color(0.38, 0.25, 0.16)][palette_index % 3]
	draw_colored_polygon(PackedVector2Array([Vector2(-9, -6), Vector2(5, -5),
		Vector2(9, 0), Vector2(5, 5), Vector2(-9, 6)]), hide)
	draw_line(Vector2(-6, -4), Vector2(-11, -8 + stride), hide.darkened(0.25), 2.0)
	draw_line(Vector2(-6, 4), Vector2(-11, 8 - stride), hide.darkened(0.25), 2.0)
	draw_line(Vector2(4, -4), Vector2(0, -9 - stride), hide.darkened(0.25), 2.0)
	draw_line(Vector2(4, 4), Vector2(0, 9 + stride), hide.darkened(0.25), 2.0)
	draw_circle(Vector2(10, 0), 4.0, hide.lightened(0.08))
	draw_line(Vector2(11, -2), Vector2(15, -6), hide.darkened(0.2), 1.5)
	draw_line(Vector2(11, 2), Vector2(15, 6), hide.darkened(0.2), 1.5)

func _draw_dock_worker(stride: float) -> void:
	_shadow()
	_legs(stride, Color(0.12, 0.12, 0.13))
	var jump: Color = [Color(0.38, 0.4, 0.42), Color(0.12, 0.3, 0.58), Color(0.55, 0.46, 0.3)][palette_index % 3]
	draw_rect(Rect2(-7, -5, 13, 10), jump)
	draw_line(Vector2(-1, -5), Vector2(-1, 5), jump.lightened(0.25), 1.0)
	draw_circle(Vector2(7, 0), 4.2, _skin())
	draw_rect(Rect2(7, -5, 5, 10), Color(0.85, 0.68, 0.16))
	if palette_index % 2 == 0:
		draw_line(Vector2(-2, 5), Vector2(7, 9), Color(0.25, 0.2, 0.14), 2.0)
	else:
		draw_rect(Rect2(-5, 6, 7, 5), Color(0.75, 0.72, 0.58))
