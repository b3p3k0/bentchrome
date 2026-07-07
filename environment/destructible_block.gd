extends StaticBody2D
## A destructible obstacle: block semantics (layer 4 — airborne cars and
## cover-piercing shots ignore it) plus Health, so weapons fire and ramming
## can break it open. Frees itself on death. Size and HP are per-instance
## exports so one scene serves park kiosks, alley crates, and wall segments.

const BASE_COLOR := Color(0.45, 0.38, 0.28)     # crate-brown vs the cold gray of solid blocks
const WRECKED_COLOR := Color(0.22, 0.18, 0.14)  # battered toward rubble as HP falls

# House paint (deco = &"house"): top-down pitched roof — sun-lit and shaded
# shingle halves meeting at a ridge, seeded chimneys, drop shadow.
const ROOF_LIGHT := Color(0.52, 0.34, 0.26)
const ROOF_DARK := Color(0.40, 0.25, 0.19)
const ROOF_RIDGE := Color(0.24, 0.15, 0.11)
const EAVE := Color(0.30, 0.22, 0.16)
const CHIMNEY := Color(0.36, 0.31, 0.31)
const CHIMNEY_CAP := Color(0.16, 0.14, 0.14)
const SHADOW := Color(0.0, 0.0, 0.0, 0.32)
const SHADOW_OFFSET := Vector2(10, 14)

@export var size := Vector2(96, 96)
@export var max_hp := 80.0
@export var deco: StringName = &""  # &"house" = pitched-roof paint (suburbs)

var _wreck := 0.0  # 0..1 battle damage, darkens the paint

@onready var _health: Health = $Health
@onready var _vis: Polygon2D = $Vis

func _ready() -> void:
	var half := size * 0.5
	_vis.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	_vis.color = BASE_COLOR
	var shape := RectangleShape2D.new()
	shape.size = size
	($Col as CollisionShape2D).shape = shape
	# Health (child) readies before this node — set hp along with max_hp.
	_health.max_hp = max_hp
	_health.hp = max_hp
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_explode_and_free)
	if deco == &"house":
		_vis.visible = false  # roof paint replaces the plain slab
		queue_redraw()

func _on_damaged(_amount: float, hp: float) -> void:
	_wreck = 1.0 - hp / max_hp
	_vis.color = BASE_COLOR.lerp(WRECKED_COLOR, _wreck)
	if deco == &"house":
		queue_redraw()

func _explode_and_free() -> void:
	var scene := get_tree().current_scene
	if scene:  # headless fixtures may not set one
		var boom := preload("res://environment/explosion.tscn").instantiate()
		boom.global_position = global_position
		boom.tint = ROOF_DARK if deco == &"house" else BASE_COLOR
		boom.size_scale = 0.6
		scene.add_child(boom)
	queue_free()

func _draw() -> void:
	if deco != &"house":
		return
	var half := size * 0.5
	draw_rect(Rect2(-half + SHADOW_OFFSET, size), SHADOW)
	# Ridge runs along the long axis; the sun-side half reads lighter.
	if size.x >= size.y:
		draw_rect(Rect2(-half, Vector2(size.x, half.y)), _shade(ROOF_LIGHT))
		draw_rect(Rect2(Vector2(-half.x, 0), Vector2(size.x, half.y)), _shade(ROOF_DARK))
		draw_line(Vector2(-half.x, 0), Vector2(half.x, 0), _shade(ROOF_RIDGE), 3.0)
	else:
		draw_rect(Rect2(-half, Vector2(half.x, size.y)), _shade(ROOF_LIGHT))
		draw_rect(Rect2(Vector2(0, -half.y), Vector2(half.x, size.y)), _shade(ROOF_DARK))
		draw_line(Vector2(0, -half.y), Vector2(0, half.y), _shade(ROOF_RIDGE), 3.0)
	draw_rect(Rect2(-half, size), _shade(EAVE), false, 3.0)
	# Chimneys: 1-2 seeded stacks on the shaded half.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(position.x * 7.0 + position.y * 13.0))
	for i in 1 + rng.randi() % 2:
		var along := rng.randf_range(-0.3, 0.3)
		var c := Vector2(size.x * along, half.y * 0.5) if size.x >= size.y \
			else Vector2(half.x * 0.5, size.y * along)
		draw_rect(Rect2(c - Vector2(8, 8), Vector2(16, 16)), _shade(CHIMNEY))
		draw_rect(Rect2(c - Vector2(4, 4), Vector2(8, 8)), _shade(CHIMNEY_CAP))

func _shade(c: Color) -> Color:
	return c.lerp(WRECKED_COLOR, _wreck)
