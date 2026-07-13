extends StaticBody2D
## Abandoned roster car: the real CarPaint silhouette in a drab rusted palette,
## parked as smashable cover (block semantics, layer 4). Seeded per position so
## the same wreck greets you every boot. Explodes properly when killed.
## NEVER references Vehicle — CarPaint is dependency-free by design.

const CarPaintScript := preload("res://vehicles/car_paint.gd")
const Floors := preload("res://game/floors.gd")  # terraced-floor layer bit
const ArenaState := preload("res://game/net/arena_state.gd")
# Smoky excluded: his animated light bar reads "alive", wrong for a wreck.
const IDS := [&"ghost", &"splatkat", &"bumper", &"razorback", &"kandykane", &"cricket", &"hammertoe"]
const RUST := Color(0.35, 0.26, 0.2)
const WRECK_TINT := Color(0.55, 0.42, 0.35)

@export var max_hp := 50.0
@export var floor_index := -1  # ≥1 joins that terrace's collision world
@export var pool_override: Array[StringName] = []  # non-empty replaces IDS
	# (a themed lot — e.g. sedans only — without touching the shared pool)
@export_range(0, 65535, 1) var arena_net_id := 0  # >0 = MP-synced tombstone

@onready var _health: Health = $Health

var _paint: Node2D
var _dead := false
var _base_collision_layer := 4

func _ready() -> void:
	if floor_index >= 1:
		collision_layer |= Floors.floor_bit(floor_index)
	_base_collision_layer = collision_layer
	if arena_net_id > 0:
		add_to_group(&"arena_net_entities")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(position.x * 7.0 + position.y * 13.0))
	_paint = CarPaintScript.new()
	var primary := Color(0.42, 0.36, 0.3).lerp(Color(0.36, 0.38, 0.4), rng.randf())
	var accent := Color(0.55, 0.5, 0.44)
	var pool: Array = pool_override if not pool_override.is_empty() else IDS
	_paint.apply(pool[rng.randi() % pool.size()], primary, accent)
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
	_paint.modulate = Color.WHITE.lerp(WRECK_TINT, 1.0 - hp / max_hp)

func _explode_and_free() -> void:
	if _dead:
		return
	_dead = true
	_spawn_death_visual()
	if arena_net_id > 0:
		# Synced wreck: a hidden, noncolliding tombstone keeps replicating its
		# terminal state instead of ghosting on late/rejoining clients.
		collision_layer = 0
		collision_mask = 0
		visible = false
	else:
		queue_free()

func _spawn_death_visual() -> void:
	var scene := get_tree().current_scene
	if scene:  # headless fixtures may not set one
		var boom := preload("res://environment/explosion.tscn").instantiate()
		boom.global_position = global_position
		boom.tint = RUST
		boom.size_scale = 0.8
		scene.add_child(boom)

func capture_arena_state(_actor_lookup: Array) -> Dictionary:
	return {
		"flags": 0 if _dead else ArenaState.ALIVE,
		"hp": clampf(_health.hp / maxf(max_hp, 0.001), 0.0, 1.0),
		"timer_ms": 0, "targets": 0,
	}

func apply_arena_state(row: Dictionary, initial_state: bool) -> void:
	var alive := ArenaState.is_alive(row)
	_health.hp = clampf(float(row.get("hp", 0.0)), 0.0, 1.0) * max_hp
	if _paint:
		_paint.modulate = Color.WHITE.lerp(WRECK_TINT, 1.0 - _health.hp / maxf(max_hp, 0.001))
	if alive:
		_dead = false
		visible = true
		collision_layer = _base_collision_layer
	elif not _dead:
		_dead = true
		if not initial_state:
			_spawn_death_visual()
		visible = false
		collision_layer = 0
		collision_mask = 0
