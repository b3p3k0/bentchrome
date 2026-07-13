class_name WorkLight
extends StaticBody2D
## Shootable tripod worklight: solid 30-HP fixture whose PointLight2D dies
## with it — kill one and that corner of the site goes dark. Host-synced
## tombstone on MP maps: a dead unit stays visible as a toppled dark mast.
## Node rotation aims the wash (paint and lamp both face local +y).

const Floors := preload("res://game/floors.gd")
const ArenaState := preload("res://game/net/arena_state.gd")
const LightKit := preload("res://environment/light_kit.gd")

const MAX_HP := 8.0  # portable fixture: one sideswipe or a short MG pepper
const LAMP_WARM := Color(1.0, 0.92, 0.72)

@export var floor_index := 1
@export_range(0, 65535, 1) var arena_net_id := 0

var _dead := false
var _base_collision_layer := 4
var _lamp: PointLight2D

func _ready() -> void:
	collision_layer = 4 | Floors.floor_bit(floor_index)
	collision_mask = 0
	_base_collision_layer = collision_layer
	if arena_net_id > 0:
		add_to_group(&"arena_net_entities")
	var col := CollisionShape2D.new()
	col.name = "Col"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(36, 36)
	col.shape = shape
	add_child(col)
	var hp := Health.new()
	hp.name = "Health"
	hp.max_hp = MAX_HP
	hp.hp = MAX_HP
	hp.died.connect(_on_died)
	add_child(hp)
	_lamp = LightKit.make_light(420.0, 0.75, LAMP_WARM)
	_lamp.position = Vector2(0, 80)
	add_child(_lamp)
	queue_redraw()

func _on_died() -> void:
	if not _dead:
		_present_death(true)

func _present_death(sparks: bool) -> void:
	_dead = true
	collision_layer = 0
	collision_mask = 0
	if _lamp:
		_lamp.visible = false
	if sparks:
		_spark_shower()
	queue_redraw()

## The stadium floodlight's dying spark rain, one-shot and self-freeing.
func _spark_shower() -> void:
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	if host == null:
		return
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 46
	burst.lifetime = 0.8
	burst.explosiveness = 0.9
	burst.spread = 180.0
	burst.initial_velocity_min = 90.0
	burst.initial_velocity_max = 240.0
	burst.gravity = Vector2(0, 260)
	burst.scale_amount_min = 1.5
	burst.scale_amount_max = 3.5
	burst.color = Color(1.0, 0.9, 0.55)
	burst.finished.connect(burst.queue_free)
	host.add_child(burst)
	burst.global_position = global_position

func capture_arena_state(_actor_lookup: Array) -> Dictionary:
	var hp := get_node_or_null(^"Health") as Health
	var f := 0.0
	if hp:
		f = clampf(hp.hp / MAX_HP, 0.0, 1.0)
	return {"flags": 0 if _dead else ArenaState.ALIVE, "hp": f, "timer_ms": 0, "targets": 0}

func apply_arena_state(row: Dictionary, initial_state: bool) -> void:
	var alive := ArenaState.is_alive(row)
	var hp := get_node_or_null(^"Health") as Health
	if hp:
		hp.hp = clampf(float(row.get("hp", 0.0)), 0.0, 1.0) * MAX_HP
	if alive:
		_dead = false
		collision_layer = _base_collision_layer
		if _lamp:
			_lamp.visible = true
		queue_redraw()
	elif not _dead:
		if initial_state:
			_dead = true
			collision_layer = 0
			collision_mask = 0
			if _lamp:
				_lamp.visible = false
			queue_redraw()
		else:
			_present_death(false)

func _draw() -> void:
	if _dead:
		draw_circle(Vector2(2, 4), 10.0, Color(0, 0, 0, 0.25))
		for leg: Vector2 in [Vector2(-26, 20), Vector2(26, 20), Vector2(0, -30)]:
			draw_line(Vector2.ZERO, leg, Color(0.18, 0.19, 0.21), 5.0)
		draw_line(Vector2.ZERO, Vector2(14, 46), Color(0.20, 0.21, 0.24), 6.0)
		draw_rect(Rect2(Vector2(6, 42), Vector2(16, 14)), Color(0.16, 0.17, 0.19))
		draw_rect(Rect2(Vector2(24, 46), Vector2(16, 14)), Color(0.16, 0.17, 0.19))
		return
	draw_rect(Rect2(Vector2(-22, -14), Vector2(60, 48)), Color(0, 0, 0, 0.22))
	for leg: Vector2 in [Vector2(-26, 20), Vector2(26, 20), Vector2(0, -30)]:
		draw_line(Vector2.ZERO, leg, Color(0.30, 0.31, 0.34), 5.0)
		draw_circle(leg, 5.0, Color(0.22, 0.23, 0.26))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-16, 10), Vector2(16, 10), Vector2(64, 150), Vector2(-64, 150),
	]), Color(1.0, 0.9, 0.65, 0.08))
	draw_circle(Vector2(0, 90), 52.0, Color(1.0, 0.9, 0.65, 0.07))
	draw_circle(Vector2.ZERO, 7.0, Color(0.38, 0.40, 0.44))
	draw_line(Vector2(-18, 4), Vector2(18, 4), Color(0.34, 0.36, 0.40), 6.0)
	for lx: float in [-11.0, 11.0]:
		draw_rect(Rect2(Vector2(lx - 8.0, 4.0), Vector2(16, 14)), Color(0.85, 0.87, 0.88))
		draw_rect(Rect2(Vector2(lx - 8.0, 4.0), Vector2(16, 14)), Color(0.25, 0.26, 0.30), false, 2.0)
		draw_circle(Vector2(lx, 14.0), 5.0, Color(1.0, 0.95, 0.80, 0.9))
