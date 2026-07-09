extends StaticBody2D
## Abandoned roster car: the real CarPaint silhouette in a drab rusted palette,
## parked as smashable cover (block semantics, layer 4). Seeded per position so
## the same wreck greets you every boot. Explodes properly when killed.
## NEVER references Vehicle — CarPaint is dependency-free by design.

const CarPaintScript := preload("res://vehicles/car_paint.gd")
const Floors := preload("res://game/floors.gd")  # terraced-floor layer bit
# Smoky excluded: his animated light bar reads "alive", wrong for a wreck.
const IDS := [&"ghost", &"splatcat", &"bumper", &"razorback", &"kandykane", &"cricket", &"hammertoe"]
const RUST := Color(0.35, 0.26, 0.2)

@export var max_hp := 50.0
@export var floor_index := -1  # ≥1 joins that terrace's collision world

@onready var _health: Health = $Health

var _paint: Node2D

func _ready() -> void:
	if floor_index >= 1:
		collision_layer |= Floors.floor_bit(floor_index)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(position.x * 7.0 + position.y * 13.0))
	_paint = CarPaintScript.new()
	var primary := Color(0.42, 0.36, 0.3).lerp(Color(0.36, 0.38, 0.4), rng.randf())
	var accent := Color(0.55, 0.5, 0.44)
	_paint.apply(IDS[rng.randi() % IDS.size()], primary, accent)
	_paint.set_process(false)  # no steering twitch, no live lights — it's dead
	add_child(_paint)
	var m: Dictionary = _paint.metrics()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(float(m.half_len), float(m.half_wid)) * 2.0 * 0.9
	($Col as CollisionShape2D).shape = shape
	_health.max_hp = max_hp
	_health.hp = max_hp
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_explode_and_free)

func _on_damaged(_amount: float, hp: float) -> void:
	_paint.modulate = Color.WHITE.lerp(Color(0.55, 0.42, 0.35), 1.0 - hp / max_hp)

func _explode_and_free() -> void:
	var scene := get_tree().current_scene
	if scene:  # headless fixtures may not set one
		var boom := preload("res://environment/explosion.tscn").instantiate()
		boom.global_position = global_position
		boom.tint = RUST
		boom.size_scale = 0.8
		scene.add_child(boom)
	queue_free()
