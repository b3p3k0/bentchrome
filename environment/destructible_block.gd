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
# Shipping containers: position-seeded liveries off the harbor rainbow.
const CONTAINER_PALETTES := [
	Color(0.62, 0.22, 0.16),  # rust red
	Color(0.18, 0.35, 0.55),  # harbor blue
	Color(0.22, 0.45, 0.28),  # cargo green
	Color(0.8, 0.45, 0.12),   # safety orange
]
const LINK := Color(0.55, 0.6, 0.58)       # galvanized chain-link
const LINK_DARK := Color(0.36, 0.4, 0.39)
const FAN_BLUE := Color(0.2, 0.42, 0.7)    # stadium crowd-control rail
const FAN_BLUE_DARK := Color(0.12, 0.26, 0.46)

const BLAST_RADIUS := 130.0   # fuel barrels: everything Health-bearing inside cooks
const BLAST_DAMAGE := 25.0    # impartial — chains into other barrels, cars, you

const Floors := preload("res://game/floors.gd")  # terraced-floor gates
const ArenaState := preload("res://game/net/arena_state.gd")

@export var size := Vector2(96, 96)
@export var max_hp := 80.0
@export var deco: StringName = &""  # paint style; "" = plain slab
@export var floor_index := -1       # ≥1 joins that terrace's collision world
@export var extra_floor := -1       # ≥1 adds a SECOND terrace bit — for guards
									# straddling a grade boundary (stadium slope
									# ends), where both floors must collide
@export var livery := -1            # containers: CONTAINER_PALETTES index; -1 = seeded
@export_range(0, 65535, 1) var arena_net_id := 0 # 0 = legacy/local destruction

var _wreck := 0.0  # 0..1 battle damage, darkens the paint
var _dead := false
var _net_initialized := false
var _base_collision_layer := 4

@onready var _health: Health = $Health
@onready var _vis: Polygon2D = $Vis

func _ready() -> void:
	if floor_index >= 1:
		collision_layer |= Floors.floor_bit(floor_index)  # keeps bit 4 for the radar
	if extra_floor >= 1:
		collision_layer |= Floors.floor_bit(extra_floor)
	_base_collision_layer = collision_layer
	if arena_net_id > 0:
		add_to_group(&"arena_net_entities")
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
	if _dead:
		return
	_dead = true
	_spawn_death_visual()
	if deco == &"barrel":
		# Deferred: death often lands mid-physics-flush (projectile Area2D
		# signal), and shape queries need the space unlocked.
		call_deferred("_barrel_blast")
	if arena_net_id > 0:
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
		boom.tint = _boom_tint()
		boom.size_scale = 1.0 if deco == &"barrel" else 0.6
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
	_wreck = 1.0 - _health.hp / maxf(max_hp, 0.001)
	if alive:
		_dead = false
		visible = true
		collision_layer = _base_collision_layer
		queue_redraw()
	elif not _dead:
		_dead = true
		if not initial_state:
			_spawn_death_visual()
		visible = false
		collision_layer = 0
		collision_mask = 0
	_net_initialized = true

func _boom_tint() -> Color:
	match deco:
		&"house":
			return ROOF_DARK
		&"barrel", &"pump":
			return Color(1.0, 0.45, 0.15)  # fuel fire
		&"fence":
			return Color(0.9, 0.88, 0.82)  # splinters fly white
		&"chainlink":
			return Color(0.7, 0.74, 0.72)  # mesh crumples gray
		&"fan_rail":
			return FAN_BLUE  # crowd-control blue shears off
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
	params.collision_mask = 1 | 4 | (1 << 9)  # cars + obstacles + soft targets
	params.collide_with_areas = true
	params.exclude = [get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(params):
		var body: Node = hit["collider"]
		if not Floors.same_floor(self, body):
			continue  # a dock-level fireball doesn't cook the roof
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
		&"fan_rail":
			_draw_fan_rail()
		&"log":
			_draw_log()
		&"junk":
			_draw_junk()
		&"pump":
			_draw_pump()
		&"barrel":
			_draw_barrel()
		&"fence":
			_draw_fence()
		&"container":
			_draw_container()
		&"chainlink":
			_draw_chainlink()
		&"forms":
			_draw_forms()
		&"spool":
			_draw_spool()
		&"pipes":
			_draw_pipes()
		&"rebar":
			_draw_rebar()

## Plywood concrete-form stack: boards, strap bands, heavy edge frame.
func _draw_forms() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half + Vector2(6, 9), size), SHADOW)
	draw_rect(Rect2(-half, size), _shade(Color(0.45, 0.34, 0.20)))
	var y := -half.y + 14.0
	while y < half.y:
		draw_line(Vector2(-half.x + 3.0, y), Vector2(half.x - 3.0, y),
			_shade(Color(0.36, 0.27, 0.15)), 2.0)
		y += 14.0
	for fx: float in [-half.x + size.x / 3.0, half.x - size.x / 3.0]:
		draw_line(Vector2(fx, -half.y), Vector2(fx, half.y), _shade(Color(0.28, 0.21, 0.12)), 4.0)
	draw_rect(Rect2(-half, size), _shade(Color(0.30, 0.22, 0.13)), false, 6.0)

## Wooden cable reel on its side: flange, spokes, coiled cable, hub bolts.
func _draw_spool() -> void:
	var r := minf(size.x, size.y)
	draw_circle(Vector2(8, 10), r * 0.44, SHADOW)
	draw_circle(Vector2.ZERO, r * 0.42, _shade(Color(0.48, 0.34, 0.19)))
	for a in range(0, 360, 45):
		draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(deg_to_rad(a)) * r * 0.38,
			_shade(Color(0.28, 0.20, 0.12)), 4.0)
	for i in 3:
		draw_arc(Vector2.ZERO, r * (0.24 + 0.05 * float(i)), 0.4 + float(i),
			5.0 + float(i), 20, _shade(Color(0.20, 0.15, 0.10)), 3.0)
	draw_circle(Vector2.ZERO, r * 0.20, _shade(Color(0.14, 0.14, 0.15)))
	for a in range(0, 360, 60):
		draw_circle(Vector2.RIGHT.rotated(deg_to_rad(a + 22)) * r * 0.36, 3.0,
			_shade(Color(0.30, 0.22, 0.13)))

## Stacked pipe bundle: 3x3 open ends with rim highlights, chock wedges.
func _draw_pipes() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half + Vector2(8, 10), size), SHADOW)
	var r := minf(size.x, size.y) * 0.13
	for row: float in [-0.22, 0.0, 0.22]:
		for col: float in [-0.29, 0.0, 0.29]:
			var at := Vector2(size.x * col, size.y * row)
			draw_circle(at, r, _shade(Color(0.42, 0.45, 0.46)))
			draw_arc(at, r * 0.76, PI * 0.9, PI * 1.6, 10, _shade(Color(0.60, 0.63, 0.64)), 3.0)
			draw_circle(at, r * 0.59, _shade(Color(0.14, 0.16, 0.17)))
	for s: float in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(s * half.x * 0.81, half.y * 0.72),
			Vector2(s * half.x * 0.98, half.y * 0.72),
			Vector2(s * half.x * 0.9, half.y * 0.47),
		]), _shade(Color(0.36, 0.27, 0.16)))

## Tied rebar cage: bar mat with proud corner posts and end dowels.
func _draw_rebar() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half + Vector2(4, 6), size), Color(0, 0, 0, 0.18))
	for x in range(int(-half.x), int(half.x) + 1, 18):
		draw_line(Vector2(x, -half.y), Vector2(x, half.y), _shade(Color(0.42, 0.25, 0.16)), 2.0)
	for y in range(int(-half.y), int(half.y) + 1, 18):
		draw_line(Vector2(-half.x, y), Vector2(half.x, y), _shade(Color(0.35, 0.21, 0.14)), 1.5)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var p := corner * (half - Vector2(8, 8))
		draw_circle(p + Vector2(2, 3), 4.5, Color(0, 0, 0, 0.25))
		draw_circle(p, 4.0, _shade(Color(0.50, 0.32, 0.20)))
	for x in range(int(-half.x), int(half.x) + 1, 36):
		draw_circle(Vector2(x, -half.y), 2.5, _shade(Color(0.50, 0.32, 0.20)))
		draw_circle(Vector2(x, half.y), 2.5, _shade(Color(0.50, 0.32, 0.20)))

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
	_draw_rail_bar(METAL, METAL_DARK)

## Stadium fan rail: the same guardrail bones in event-crew blue — built to
## keep fans back, never to keep a car in.
func _draw_fan_rail() -> void:
	_draw_rail_bar(FAN_BLUE, FAN_BLUE_DARK)

func _draw_rail_bar(steel: Color, dark: Color) -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half, size), _shade(steel))
	var tall := size.y > size.x
	if tall:
		draw_line(Vector2(-half.x * 0.4, -half.y + 2), Vector2(-half.x * 0.4, half.y - 2), _shade(dark), 2.5)
		draw_line(Vector2(half.x * 0.4, -half.y + 2), Vector2(half.x * 0.4, half.y - 2), _shade(dark), 2.5)
		draw_circle(Vector2(0, -half.y + 8), 3.0, _shade(dark))
		draw_circle(Vector2(0, half.y - 8), 3.0, _shade(dark))
	else:
		draw_line(Vector2(-half.x + 2, -half.y * 0.4), Vector2(half.x - 2, -half.y * 0.4), _shade(dark), 2.5)
		draw_line(Vector2(-half.x + 2, half.y * 0.4), Vector2(half.x - 2, half.y * 0.4), _shade(dark), 2.5)
		draw_circle(Vector2(-half.x + 8, 0), 3.0, _shade(dark))
		draw_circle(Vector2(half.x - 8, 0), 3.0, _shade(dark))

## Junk pile: rusty blobs, a dead tire, a pipe poking out.
## Fallen trunk (deco = &"log"): bark seams along the long axis, pale sawn
## ends. Low HP by authoring intent — blow through it, pay in momentum.
func _draw_log() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half + SHADOW_OFFSET * 0.5, size), SHADOW)
	var trunk := _shade(Color(0.4, 0.28, 0.17))
	var bark := _shade(Color(0.28, 0.19, 0.11))
	var cut := _shade(Color(0.72, 0.6, 0.42))
	draw_rect(Rect2(-half, size), trunk)
	for i in 3:
		var y := -half.y + size.y * (0.25 + 0.25 * float(i))
		draw_line(Vector2(-half.x + 4, y), Vector2(half.x - 4, y), bark, 1.5)
	draw_circle(Vector2(-half.x + 4, 0), size.y * 0.34, cut)
	draw_circle(Vector2(half.x - 4, 0), size.y * 0.34, cut)
	draw_circle(Vector2(half.x - 4, 0), size.y * 0.14, bark)

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

## Picket fence (top-down strip): white slats across the run + a shaded rail
## along it. 15 HP — mowing one down is a fender-tap, as intended.
func _draw_fence() -> void:
	var half := size * 0.5
	var tall := size.y > size.x
	var length := size.y if tall else size.x
	var white := _shade(Color(0.92, 0.9, 0.85))
	var rail := _shade(Color(0.68, 0.66, 0.6))
	var picket := 8.0
	var gap := 6.0
	var n := int(length / (picket + gap))
	for i in n:
		var t := -length * 0.5 + i * (picket + gap) + gap * 0.5
		if tall:
			draw_rect(Rect2(-half.x, t, size.x, picket), white)
		else:
			draw_rect(Rect2(t, -half.y, picket, size.y), white)
	if tall:
		draw_rect(Rect2(-2.0, -half.y, 4.0, size.y), rail)
	else:
		draw_rect(Rect2(-half.x, -2.0, size.x, 4.0), rail)

## Shipping container (top-down): seeded livery, corrugation ribs across the
## short axis, corner castings, door bars on the +long end.
func _draw_container() -> void:
	var half := size * 0.5
	var rng := _seed_rng()
	var base: Color = CONTAINER_PALETTES[livery] if livery >= 0 and livery < CONTAINER_PALETTES.size() \
		else CONTAINER_PALETTES[rng.randi() % CONTAINER_PALETTES.size()]
	var dark := base.darkened(0.4)
	draw_rect(Rect2(-half + Vector2(6, 9), size), SHADOW)  # stacked-steel height
	draw_rect(Rect2(-half, size), _shade(base))
	var tall := size.y > size.x
	var run := size.y if tall else size.x
	var ribs := maxi(int(run / 14.0), 3)
	for i in range(1, ribs):
		var t := -run * 0.5 + run * i / ribs
		if tall:
			draw_line(Vector2(-half.x + 2, t), Vector2(half.x - 2, t), _shade(dark), 1.5)
		else:
			draw_line(Vector2(t, -half.y + 2), Vector2(t, half.y - 2), _shade(dark), 1.5)
	# Door end: twin lock bars along the +long end.
	if tall:
		draw_line(Vector2(-half.x * 0.45, half.y - 3), Vector2(-half.x * 0.45, half.y - 12), _shade(HAZARD_DARK), 2.5)
		draw_line(Vector2(half.x * 0.45, half.y - 3), Vector2(half.x * 0.45, half.y - 12), _shade(HAZARD_DARK), 2.5)
	else:
		draw_line(Vector2(half.x - 3, -half.y * 0.45), Vector2(half.x - 12, -half.y * 0.45), _shade(HAZARD_DARK), 2.5)
		draw_line(Vector2(half.x - 3, half.y * 0.45), Vector2(half.x - 12, half.y * 0.45), _shade(HAZARD_DARK), 2.5)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		draw_rect(Rect2(corner * (half - Vector2(7, 7)) - Vector2(3, 3), Vector2(6, 6)), _shade(HAZARD_DARK))
	draw_rect(Rect2(-half, size), _shade(dark), false, 2.5)

## Harbor chain-link (top-down strip): top rail, post dots, sparse diamond-
## mesh ticks. 12 HP class — crumples on a fender tap.
func _draw_chainlink() -> void:
	var half := size * 0.5
	var tall := size.y > size.x
	var run := size.y if tall else size.x
	if tall:
		draw_rect(Rect2(-1.5, -half.y, 3.0, size.y), _shade(LINK))
	else:
		draw_rect(Rect2(-half.x, -1.5, size.x, 3.0), _shade(LINK))
	var ticks := maxi(int(run / 12.0), 2)
	for i in ticks:
		var tt := -run * 0.5 + run * (i + 0.5) / ticks
		var d := 4.0 if i % 2 == 0 else -4.0
		if tall:
			draw_line(Vector2(-d, tt - 4.0), Vector2(d, tt + 4.0), _shade(LINK_DARK), 1.2)
		else:
			draw_line(Vector2(tt - 4.0, -d), Vector2(tt + 4.0, d), _shade(LINK_DARK), 1.2)
	var posts := maxi(int(run / 64.0), 2)
	for i in posts + 1:
		var tt := clampf(-run * 0.5 + run * i / posts, -run * 0.5 + 3.0, run * 0.5 - 3.0)
		draw_circle(Vector2(0.0, tt) if tall else Vector2(tt, 0.0), 3.0, _shade(LINK_DARK))

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
