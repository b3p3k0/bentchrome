extends StaticBody2D
## A destructible obstacle: block semantics (layer 4 — airborne cars and
## cover-piercing shots ignore it) plus Health, so weapons fire and ramming
## can break it open. Frees itself on death. Size and HP are per-instance
## exports; `deco` picks a paint style (house roof, crate, kiosk, barrier,
## guardrail, junk pile, gas pump, fuel barrel) — empty keeps the plain slab.
## Barrels are the fun ones: they detonate with a real blast.

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

const PLANK := Color(0.5, 0.4, 0.26)
const PLANK_SEAM := Color(0.32, 0.25, 0.16)
const METAL := Color(0.44, 0.46, 0.5)
const METAL_DARK := Color(0.3, 0.32, 0.36)
const HAZARD_YELLOW := Color(0.95, 0.8, 0.2)
const HAZARD_DARK := Color(0.12, 0.12, 0.14)
const AWNING_RED := Color(0.75, 0.2, 0.18)
const AWNING_CREAM := Color(0.93, 0.89, 0.8)
const RUST := Color(0.55, 0.32, 0.16)
const RUST_DARK := Color(0.38, 0.22, 0.12)
const TIRE_BLACK := Color(0.1, 0.1, 0.12)
const PUMP_RED := Color(0.72, 0.16, 0.14)
const PUMP_FACE := Color(0.9, 0.88, 0.84)
const BARREL_RED := Color(0.78, 0.15, 0.12)
const BARREL_RIM := Color(0.45, 0.09, 0.08)

const BLAST_RADIUS := 130.0   # fuel barrels: everything Health-bearing inside cooks
const BLAST_DAMAGE := 25.0    # impartial — chains into other barrels, cars, you

@export var size := Vector2(96, 96)
@export var max_hp := 80.0
@export var deco: StringName = &""  # paint style; "" = plain slab

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
	if deco != &"":
		_vis.visible = false  # style paint replaces the plain slab
		queue_redraw()

func _on_damaged(_amount: float, hp: float) -> void:
	_wreck = 1.0 - hp / max_hp
	_vis.color = BASE_COLOR.lerp(WRECKED_COLOR, _wreck)
	if deco != &"":
		queue_redraw()

func _explode_and_free() -> void:
	var scene := get_tree().current_scene
	if scene:  # headless fixtures may not set one
		var boom := preload("res://environment/explosion.tscn").instantiate()
		boom.global_position = global_position
		boom.tint = _boom_tint()
		boom.size_scale = 1.0 if deco == &"barrel" else 0.6
		scene.add_child(boom)
	if deco == &"barrel":
		# Deferred: death often lands mid-physics-flush (projectile Area2D
		# signal), and shape queries need the space unlocked.
		call_deferred("_barrel_blast")
	queue_free()

func _boom_tint() -> Color:
	match deco:
		&"house":
			return ROOF_DARK
		&"barrel", &"pump":
			return Color(1.0, 0.45, 0.15)  # fuel fire
		_:
			return BASE_COLOR

## Fuel-barrel detonation: flat damage to every Health-bearing body in range —
## vehicles, crates, other barrels (chain reactions welcome), and you.
func _barrel_blast() -> void:
	var shape := CircleShape2D.new()
	shape.radius = BLAST_RADIUS
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, global_position)
	params.collision_mask = 1 | 4  # ground (cars) + obstacles (blocks/barrels)
	params.exclude = [get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(params):
		var body: Node = hit["collider"]
		for child in body.get_children():
			if child is Health:
				child.take_damage(BLAST_DAMAGE)
				break

func _shade(c: Color) -> Color:
	return c.lerp(WRECKED_COLOR, _wreck)

func _seed_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(position.x * 7.0 + position.y * 13.0))
	return rng

func _draw() -> void:
	match deco:
		&"house":
			_draw_house()
		&"crate":
			_draw_crate()
		&"kiosk":
			_draw_kiosk()
		&"barrier":
			_draw_barrier()
		&"rail":
			_draw_rail()
		&"junk":
			_draw_junk()
		&"pump":
			_draw_pump()
		&"barrel":
			_draw_barrel()

func _draw_house() -> void:
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
	var rng := _seed_rng()
	for i in 1 + rng.randi() % 2:
		var along := rng.randf_range(-0.3, 0.3)
		var c := Vector2(size.x * along, half.y * 0.5) if size.x >= size.y \
			else Vector2(half.x * 0.5, size.y * along)
		draw_rect(Rect2(c - Vector2(8, 8), Vector2(16, 16)), _shade(CHIMNEY))
		draw_rect(Rect2(c - Vector2(4, 4), Vector2(8, 8)), _shade(CHIMNEY_CAP))

## Wooden crate: planks, seams, diagonal brace, corner nails.
func _draw_crate() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half, size), _shade(PLANK))
	var planks := 4
	for i in range(1, planks):
		var y := -half.y + size.y * i / planks
		draw_line(Vector2(-half.x, y), Vector2(half.x, y), _shade(PLANK_SEAM), 1.5)
	draw_line(-half, half, _shade(PLANK_SEAM), 3.0)  # cross brace
	draw_line(Vector2(-half.x, half.y), Vector2(half.x, -half.y), _shade(PLANK_SEAM), 3.0)
	draw_rect(Rect2(-half, size), _shade(PLANK_SEAM), false, 2.5)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		draw_circle(corner * (half - Vector2(6, 6)), 1.8, _shade(CHIMNEY_CAP))

## Newsstand kiosk: warm box under a striped awning, counter slot.
func _draw_kiosk() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half, size), _shade(BASE_COLOR))
	var stripes := 6
	for i in stripes:
		var x := -half.x + size.x * i / stripes
		var c := AWNING_RED if i % 2 == 0 else AWNING_CREAM
		draw_rect(Rect2(x, -half.y, size.x / stripes, size.y * 0.45), _shade(c))
	draw_rect(Rect2(-half.x + 6, half.y - 14, size.x - 12, 7), _shade(CHIMNEY_CAP))  # counter
	draw_rect(Rect2(-half, size), _shade(PLANK_SEAM), false, 2.0)

## Metal barrier (gates, doors): slats along the long axis, hazard tags.
func _draw_barrier() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half, size), _shade(METAL))
	var tall := size.y > size.x
	var slats := int((size.y if tall else size.x) / 24.0)
	for i in range(1, slats):
		var t := -(size.y if tall else size.x) * 0.5 + (size.y if tall else size.x) * i / slats
		if tall:
			draw_line(Vector2(-half.x + 3, t), Vector2(half.x - 3, t), _shade(METAL_DARK), 2.0)
		else:
			draw_line(Vector2(t, -half.y + 3), Vector2(t, half.y - 3), _shade(METAL_DARK), 2.0)
	# Hazard tags on both ends of the long axis.
	var tag := Vector2(12, 12)
	var ends := [Vector2(0, -half.y + 8), Vector2(0, half.y - 8)] if tall \
		else [Vector2(-half.x + 8, 0), Vector2(half.x - 8, 0)]
	for e in ends:
		draw_rect(Rect2(e - tag * 0.5, tag), _shade(HAZARD_YELLOW))
		draw_line(e - tag * 0.4, e + tag * 0.4, _shade(HAZARD_DARK), 2.5)
	draw_rect(Rect2(-half, size), _shade(METAL_DARK), false, 2.5)

## Guardrail segment: W-beam channels along the long axis, post dots.
func _draw_rail() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half, size), _shade(METAL))
	var tall := size.y > size.x
	if tall:
		draw_line(Vector2(-half.x * 0.4, -half.y + 2), Vector2(-half.x * 0.4, half.y - 2), _shade(METAL_DARK), 2.5)
		draw_line(Vector2(half.x * 0.4, -half.y + 2), Vector2(half.x * 0.4, half.y - 2), _shade(METAL_DARK), 2.5)
		draw_circle(Vector2(0, -half.y + 8), 3.0, _shade(METAL_DARK))
		draw_circle(Vector2(0, half.y - 8), 3.0, _shade(METAL_DARK))
	else:
		draw_line(Vector2(-half.x + 2, -half.y * 0.4), Vector2(half.x - 2, -half.y * 0.4), _shade(METAL_DARK), 2.5)
		draw_line(Vector2(-half.x + 2, half.y * 0.4), Vector2(half.x - 2, half.y * 0.4), _shade(METAL_DARK), 2.5)
		draw_circle(Vector2(-half.x + 8, 0), 3.0, _shade(METAL_DARK))
		draw_circle(Vector2(half.x - 8, 0), 3.0, _shade(METAL_DARK))

## Junk pile: rusty blobs, a dead tire, a pipe poking out.
func _draw_junk() -> void:
	var half := size * 0.5
	var rng := _seed_rng()
	var reach := minf(half.x, half.y)
	for i in 6 + rng.randi() % 3:
		var at := Vector2(rng.randf_range(-reach, reach), rng.randf_range(-reach, reach)) * 0.7
		var r := rng.randf_range(reach * 0.25, reach * 0.5)
		draw_circle(at, r, _shade(RUST_DARK if rng.randf() < 0.4 else RUST))
	var tire_at := Vector2(reach * 0.35, -reach * 0.3)
	draw_circle(tire_at, reach * 0.32, _shade(TIRE_BLACK))
	draw_circle(tire_at, reach * 0.14, _shade(RUST_DARK))
	draw_line(Vector2(-reach * 0.7, reach * 0.5), Vector2(reach * 0.1, reach * 0.15), _shade(METAL_DARK), 4.0)

## Gas pump: red body, pale face with a dark meter, hose to a nozzle.
func _draw_pump() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half * 0.9, size * 0.9), _shade(PUMP_RED))
	draw_rect(Rect2(-half.x * 0.55, -half.y * 0.65, size.x * 0.55, size.y * 0.4), _shade(PUMP_FACE))
	draw_rect(Rect2(-half.x * 0.4, -half.y * 0.5, size.x * 0.3, size.y * 0.18), _shade(HAZARD_DARK))
	var nozzle := Vector2(half.x * 0.75, half.y * 0.55)
	draw_line(Vector2(half.x * 0.35, 0), nozzle, _shade(HAZARD_DARK), 2.5)
	draw_rect(Rect2(nozzle - Vector2(3, 3), Vector2(7, 6)), _shade(METAL_DARK))
	draw_rect(Rect2(-half * 0.9, size * 0.9), _shade(BARREL_RIM), false, 2.0)

## Fuel barrel (top-down drum): red disc, rim ring, cap, hazard diamond.
func _draw_barrel() -> void:
	var r := minf(size.x, size.y) * 0.5
	draw_circle(Vector2.ZERO, r, _shade(BARREL_RIM))
	draw_circle(Vector2.ZERO, r * 0.85, _shade(BARREL_RED))
	draw_arc(Vector2.ZERO, r * 0.55, 0.0, TAU, 24, _shade(BARREL_RIM), 2.0)
	draw_circle(Vector2(r * 0.35, -r * 0.3), r * 0.12, _shade(METAL_DARK))  # bung cap
	var d := r * 0.32
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -d), Vector2(d, 0), Vector2(0, d), Vector2(-d, 0),
	]), _shade(HAZARD_YELLOW))
	draw_line(Vector2(0, -d * 0.5), Vector2(0, d * 0.5), _shade(HAZARD_DARK), 2.0)
