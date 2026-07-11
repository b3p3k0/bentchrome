class_name AmbientPopulation
extends Node2D
## Compact level-authoring primitive: one node owns one safe wander zone,
## station cluster, or looped Curve2D route. Multiple nodes make multiple paths.

const ActorScene := preload("res://environment/ambient_actor.tscn")
const Floors := preload("res://game/floors.gd")

@export var kinds: Array[StringName] = [&"civilian"]
@export_range(0, 64) var count := 1
@export var movement := AmbientActor.Movement.WANDER
@export var bounds := Vector2(240, 160)
@export var route: Curve2D
@export var route_points := PackedVector2Array()
@export var floor_index := -1
@export var speed := 55.0
@export var speed_jitter := 0.15
@export var lane_spread := 12.0
@export var reacts_to_cars := true
@export var leaves_splat := true
@export var seed_offset := 0

func _ready() -> void:
	spawn_population()

func spawn_population() -> void:
	if kinds.is_empty() or count <= 0:
		return
	if route == null and route_points.size() >= 2:
		route = Curve2D.new()
		for point in route_points:
			route.add_point(point)
	var rng := RandomNumberGenerator.new()
	rng.seed = population_seed()
	var length := route.get_baked_length() if route else 0.0
	for i in count:
		var actor := ActorScene.instantiate() as AmbientActor
		actor.kind = kinds[i % kinds.size()]
		actor.palette_index = i % 3
		actor.floor_index = floor_index
		actor.movement = movement
		actor.move_speed = speed * rng.randf_range(1.0 - speed_jitter, 1.0 + speed_jitter)
		actor.reacts_to_cars = reacts_to_cars
		actor.leaves_splat = leaves_splat
		actor.actor_seed = int(rng.randi())
		actor.wander_rect = Rect2(-bounds * 0.5, bounds)
		actor.route = route
		actor.route_progress = length * float(i) / maxf(float(count), 1.0)
		actor.route_lane = rng.randf_range(-lane_spread, lane_spread)
		add_child(actor)
		actor.position = _spawn_point(actor, rng)

func population_seed() -> int:
	return int(absf(global_position.x * 7.0 + global_position.y * 13.0)) + seed_offset * 7919 + 1

func _spawn_point(actor: AmbientActor, rng: RandomNumberGenerator) -> Vector2:
	if movement == AmbientActor.Movement.ROUTE and route and route.get_baked_length() > 0.0:
		return actor._route_point(actor.route_progress)
	for attempt in 12:
		var point := Vector2(rng.randf_range(-bounds.x * 0.5, bounds.x * 0.5),
			rng.randf_range(-bounds.y * 0.5, bounds.y * 0.5))
		if not actor._position_blocked(to_global(point)):
			return point
	return Vector2.ZERO
