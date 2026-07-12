class_name PortaPotty
extends StaticBody2D
## Light site prop with a small chance of releasing a startled worker. The
## worker stays a normal soft target; the cubicle never becomes tactical loot.

const Floors := preload("res://game/floors.gd")
const ActorScene := preload("res://environment/ambient_actor.tscn")
const ArenaState := preload("res://game/net/arena_state.gd")

const ESCAPE_CHANCE := 0.20
const ESCAPE_PANIC := 2.5

@export var floor_index := 1
@export var max_hp := 20.0
@export var seed_offset := 0
@export_range(0, 65535, 1) var arena_net_id := 0

var last_attacker: Node2D = null
var _dead := false
var _escaped := false
var _base_collision_layer := 0
var _forced_roll := -1.0  # deterministic fixture seam; negative = seeded RNG
@onready var _health: Health = $Health

func _ready() -> void:
	collision_layer = 4 | Floors.floor_bit(floor_index)
	_base_collision_layer = collision_layer
	collision_mask = 0
	if arena_net_id > 0:
		add_to_group(&"arena_net_entities")
	_health.max_hp = max_hp
	_health.hp = max_hp
	_health.died.connect(_die)
	queue_redraw()

func set_test_roll(value: float) -> void:
	_forced_roll = value

static func releases_worker(roll: float) -> bool:
	return roll >= 0.0 and roll < ESCAPE_CHANCE

func _die() -> void:
	if _dead:
		return
	_dead = true
	var rng := _rng()
	var roll := _forced_roll if _forced_roll >= 0.0 else rng.randf()
	_escaped = releases_worker(roll)
	collision_layer = 0
	set_deferred(&"collision_mask", 0)
	visible = false
	call_deferred(&"_finish_death")

func _finish_death() -> void:
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	if host:
		_spawn_blue_debris(host)
		var rng := _rng()
		if _escaped:
			_spawn_worker(host, rng)
	if arena_net_id <= 0:
		queue_free()

func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(global_position.x * 7.0 + global_position.y * 13.0)) + seed_offset * 7919 + 17
	return rng

func capture_arena_state(_actor_lookup: Array) -> Dictionary:
	var flags := 0 if _dead else ArenaState.ALIVE
	if _escaped:
		flags |= ArenaState.ESCAPE
	return {"flags": flags, "hp": clampf(_health.hp / maxf(max_hp, 0.001), 0.0, 1.0),
		"timer_ms": 0, "targets": 0}

func apply_arena_state(row: Dictionary, initial_state: bool) -> void:
	var alive := ArenaState.is_alive(row)
	_health.hp = clampf(float(row.get("hp", 0.0)), 0.0, 1.0) * max_hp
	_escaped = (ArenaState.flags(row) & ArenaState.ESCAPE) != 0
	if alive:
		_dead = false
		visible = true
		collision_layer = _base_collision_layer
	elif not _dead:
		_dead = true
		collision_layer = 0
		collision_mask = 0
		visible = false
		if not initial_state:
			var host := get_tree().current_scene
			if host == null:
				host = get_parent()
			if host:
				_spawn_blue_debris(host)
				if _escaped:
					_spawn_worker(host, _rng())

func _spawn_worker(host: Node, rng: RandomNumberGenerator) -> void:
	var actor := ActorScene.instantiate() as AmbientActor
	actor.kind = &"construction_worker"
	actor.palette_index = rng.randi_range(0, 2)
	actor.floor_index = floor_index
	actor.movement = AmbientActor.Movement.WANDER
	actor.move_speed = 72.0
	actor.actor_seed = int(rng.randi())
	actor.wander_rect = Rect2(-Vector2(180, 180), Vector2(360, 360))
	host.add_child(actor)
	var threat := last_attacker if is_instance_valid(last_attacker) else _nearest_vehicle()
	var away := (global_position - threat.global_position).normalized() if threat else Vector2.RIGHT
	actor.global_position = global_position + away * 48.0
	actor.panic_from(threat.global_position if threat else global_position - away, ESCAPE_PANIC)

func _nearest_vehicle() -> Node2D:
	var nearest: Node2D = null
	var distance := INF
	for candidate in get_tree().get_nodes_in_group(&"vehicles"):
		if candidate is Node2D and Floors.same_floor(self, candidate):
			var d := global_position.distance_squared_to(candidate.global_position)
			if d < distance:
				distance = d
				nearest = candidate
	return nearest

func _spawn_blue_debris(host: Node) -> void:
	var puff := CPUParticles2D.new()
	puff.one_shot = true
	puff.emitting = true
	puff.amount = 18
	puff.lifetime = 0.65
	puff.explosiveness = 1.0
	puff.spread = 180.0
	puff.initial_velocity_min = 100.0
	puff.initial_velocity_max = 260.0
	puff.damping_min = 160.0
	puff.damping_max = 300.0
	puff.scale_amount_min = 2.0
	puff.scale_amount_max = 5.0
	puff.color = Color(0.25, 0.58, 0.78, 0.9)
	puff.finished.connect(puff.queue_free)
	host.add_child(puff)
	puff.global_position = global_position

## The door lives on the local +X (east) face so a west-wall column reads as
## a proper service row: jamb band, proud leaf with hinge seam and handle, a
## threshold step onto the yard. One seeded unit per row hangs ajar.
func _draw() -> void:
	draw_rect(Rect2(Vector2(-32, -40) + Vector2(7, 9), Vector2(64, 80)), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(-32, -40, 64, 80), Color(0.18, 0.52, 0.72))
	draw_rect(Rect2(-28, -36, 48, 72), Color(0.22, 0.60, 0.80))
	draw_rect(Rect2(-24, -32, 12, 12), Color(0.14, 0.42, 0.60))
	draw_rect(Rect2(-24, -32, 12, 12), Color(0.08, 0.28, 0.42), false, 2.0)
	draw_rect(Rect2(22, -34, 10, 68), Color(0.12, 0.38, 0.55))
	if seed_offset % 8 == 3:
		draw_rect(Rect2(24, -28, 10, 56), Color(0.05, 0.10, 0.14))
		draw_set_transform(Vector2(28, -28), 0.5, Vector2.ONE)
		draw_rect(Rect2(0, 0, 8, 56), Color(0.30, 0.68, 0.86))
		draw_rect(Rect2(0, 0, 8, 56), Color(0.10, 0.34, 0.50), false, 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_rect(Rect2(26, -28, 8, 56), Color(0.30, 0.68, 0.86))
		draw_rect(Rect2(26, -28, 8, 56), Color(0.10, 0.34, 0.50), false, 2.0)
		draw_line(Vector2(27, -26), Vector2(27, 26), Color(0.10, 0.34, 0.50), 1.5)
		draw_circle(Vector2(31, 16), 3.0, Color(0.92, 0.82, 0.25))
	draw_rect(Rect2(34, -12, 6, 24), Color(0.45, 0.47, 0.50))
	for x in [-18.0, -8.0, 2.0, 12.0]:
		draw_line(Vector2(x, -33), Vector2(x, -27), Color(0.08, 0.28, 0.42), 2.0)
