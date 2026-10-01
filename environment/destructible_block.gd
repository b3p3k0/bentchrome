extends StaticBody2D
## A destructible obstacle: block semantics (layer 4 — airborne cars and
## cover-piercing shots ignore it) plus Health, so weapons fire and ramming
## can break it open. Death FLATTENS it in place: the node stays as visible,
## collisionless remains (seeded debris/scorch via remains_paint.gd) that cars
## drive over and shots pass through. Size and HP are per-instance exports;
## `deco` picks a paint style (house roof, crate, kiosk, barrier, guardrail,
## junk pile, gas pump, fuel barrel) — empty keeps the plain slab. Barrels are
## the fun ones: they detonate with a real blast.

signal flattened
signal restored

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
const IRON := Color(0.09, 0.09, 0.11)      # wrought iron — capital containment
const IRON_HI := Color(0.26, 0.26, 0.31)

# Food trucks: their own livery palette, separate from the harbor rainbow.
const TRUCK_PALETTES := [
	Color(0.85, 0.3, 0.25),   # taco red
	Color(0.93, 0.72, 0.2),   # empanada yellow
	Color(0.25, 0.55, 0.75),  # kebab blue
	Color(0.45, 0.65, 0.3),   # falafel green
]

# Road haulers share cab bones, but keep a work-truck palette of their own.
const ROAD_TRUCK_PALETTES := [
	Color(0.68, 0.16, 0.12),  # faded fleet red
	Color(0.16, 0.34, 0.52),  # interstate blue
	Color(0.30, 0.43, 0.20),  # farm green
	Color(0.78, 0.44, 0.10),  # construction orange
]
const ROAD_TRAILERS := [
	Color(0.76, 0.75, 0.69),  # weathered white
	Color(0.58, 0.61, 0.62),  # dull aluminium
]
const STOREFRONT_PALETTES := [
	Color(0.72, 0.18, 0.16),
	Color(0.18, 0.42, 0.66),
	Color(0.32, 0.56, 0.24),
	Color(0.86, 0.57, 0.12),
]
const STOREFRONT_ROOFS := [
	Color(0.43, 0.44, 0.45),
	Color(0.47, 0.46, 0.44),
	Color(0.39, 0.41, 0.42),
]
# Storefront roof furniture borrows these tones from levels/building_deco.gd.
const GRAVEL_DARK := Color(0.24, 0.24, 0.29)
const GRAVEL_LIGHT := Color(0.33, 0.33, 0.39)
const HVAC := Color(0.4, 0.4, 0.46)
const HVAC_SHADOW := Color(0.0, 0.0, 0.0, 0.25)
const HVAC_EDGE := Color(0.5, 0.5, 0.56)
const STRAW := Color(0.68, 0.52, 0.23)
const STRAW_DARK := Color(0.43, 0.31, 0.13)
const STRAW_TWINE := Color(0.84, 0.70, 0.37)

const BLASTS := {
	&"barrel": {"radius": 130.0, "damage": 25.0},
	&"tanker": {"radius": 200.0, "damage": 40.0},
}

const Floors := preload("res://game/floors.gd")  # terraced-floor gates
const HitTags := preload("res://game/hit_tags.gd")  # sticker-only hit identity (leaf)
const ArenaState := preload("res://game/net/arena_state.gd")
const RemainsPaint := preload("res://environment/remains_paint.gd")

## Remains language per deco: [flavor, base, dark]. Colors authored drab
## directly — never through _shade (a dead block's _wreck is 1.0, which would
## collapse every palette into one mud color). Containers resolve their base
## from the livery at draw time.
const REMAINS := {
	&"": [&"debris", WRECKED_COLOR, Color(0.13, 0.11, 0.09)],
	&"house": [&"debris", ROOF_DARK, ROOF_RIDGE],
	&"crate": [&"splinter", PLANK, PLANK_SEAM],
	&"kiosk": [&"crumple", AWNING_RED, PLANK_SEAM],
	&"barrier": [&"crumple", METAL, METAL_DARK],
	&"rail": [&"crumple", METAL, METAL_DARK],
	&"fan_rail": [&"crumple", FAN_BLUE, FAN_BLUE_DARK],
	&"log": [&"splinter", Color(0.4, 0.28, 0.17), Color(0.28, 0.19, 0.11)],
	&"junk": [&"debris", RUST, RUST_DARK],
	&"pump": [&"scorch", PUMP_RED, HAZARD_DARK],
	&"barrel": [&"scorch", BARREL_RED, BARREL_RIM],
	&"semi": [&"crumple", ROAD_TRAILERS[0], METAL_DARK],
	&"tanker": [&"scorch", ROAD_TRAILERS[1], HAZARD_DARK],
	&"hay": [&"splinter", STRAW, STRAW_DARK],
	&"storefront": [&"debris", STOREFRONT_ROOFS[0], METAL_DARK],
	&"fence": [&"splinter", Color(0.92, 0.9, 0.85), Color(0.68, 0.66, 0.6)],
	&"iron_fence": [&"crumple", IRON_HI, IRON],
	&"container": [&"crumple", Color.WHITE, METAL_DARK],  # base = livery, darkened
	&"food_truck": [&"crumple", Color.WHITE, Color(0.16, 0.14, 0.13)],  # base = livery
	&"chainlink": [&"crumple", LINK, LINK_DARK],
	&"forms": [&"splinter", Color(0.45, 0.34, 0.20), Color(0.30, 0.22, 0.13)],
	&"spool": [&"splinter", Color(0.48, 0.34, 0.19), Color(0.28, 0.20, 0.12)],
	&"pipes": [&"debris", Color(0.42, 0.45, 0.46), Color(0.14, 0.16, 0.17)],
	&"rebar": [&"debris", Color(0.42, 0.25, 0.16), Color(0.35, 0.21, 0.14)],
	&"pillar": [&"debris", Color(0.42, 0.42, 0.45), Color(0.2, 0.2, 0.22)],
	&"trailer": [&"crumple", Color(0.72, 0.7, 0.66), Color(0.3, 0.3, 0.32)],
	&"booth": [&"crumple", Color(0.62, 0.6, 0.55), Color(0.24, 0.22, 0.2)],
	&"tires": [&"scorch", TIRE_BLACK, Color(0.05, 0.05, 0.06)],
}

@export var size := Vector2(96, 96)
@export var max_hp := 80.0
@export var deco: StringName = &""  # paint style; "" = plain slab
@export var floor_index := -1       # ≥1 joins that terrace's collision world
@export var extra_floor := -1       # ≥1 adds a SECOND terrace bit — for guards
									# straddling a grade boundary (stadium slope
									# ends), where both floors must collide
@export var livery := -1            # style palette index; -1 = position-seeded
@export_enum("south", "north", "west", "east") var front := "south"
@export_range(0, 65535, 1) var arena_net_id := 0 # 0 = legacy/local destruction
## A status the prop passes to the car that smashes through it (Route 666's
## burning tire stacks hand out `&"burn"`): a StatusEffectSpec kind, or ""
## for none. Applied from the vehicle's smash seam (`on_smashed`) — the prop
## never knows who touched it otherwise.
@export var touch_effect: StringName = &""
@export var touch_magnitude := 3.0   # burn: damage per second; slow: speed factor
@export var touch_duration := 3.0

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
	_spawn_death_visual()
	if BLASTS.has(deco):
		# Deferred: death often lands mid-physics-flush (projectile Area2D
		# signal), and shape queries need the space unlocked.
		var blast: Dictionary = BLASTS[deco]
		call_deferred(&"_blast", float(blast.radius), float(blast.damage))
	_present_remains()

## The flatten-in-place death state: the node STAYS — visible, collisionless
## debris cars drive over and shots pass through. One path for legacy and
## arena-synced blocks alike (the tombstone contract keeps the node anyway;
## it just stops hiding it).
func _present_remains() -> void:
	_dead = true
	collision_layer = 0
	collision_mask = 0
	_vis.visible = false  # the plain slab's polygon would keep painting the box
	if is_in_group(&"tutorial_smash"):
		remove_from_group(&"tutorial_smash")  # the smash lesson counts live members
	queue_redraw()
	flattened.emit()

## The car that just smashed through this prop (Vehicle._smash_through calls
## it after the kill): hand it the authored touch effect, if any. Duck-typed
## on apply_effect; mild by authoring — a few seconds of light DoT, never a
## stop. The spec's `refresh` default means a second stack extends, not stacks.
func on_smashed(car: Node) -> void:
	if touch_effect == &"" or car == null or not car.has_method(&"apply_effect"):
		return
	var spec := StatusEffectSpec.new()
	spec.kind = touch_effect
	spec.magnitude = touch_magnitude
	spec.duration = touch_duration
	car.call(&"apply_effect", spec)

func _spawn_death_visual() -> void:
	var scene := get_tree().current_scene
	if scene:  # headless fixtures may not set one
		var boom := preload("res://environment/explosion.tscn").instantiate()
		boom.global_position = global_position
		boom.tint = _boom_tint()
		boom.size_scale = 1.4 if deco == &"tanker" else (1.0 if deco == &"barrel" else 0.6)
		scene.add_child(boom)

func capture_arena_state(_actor_lookup: Array) -> Dictionary:
	return {
		"flags": 0 if _dead else ArenaState.ALIVE,
		"hp": clampf(_health.hp / maxf(max_hp, 0.001), 0.0, 1.0),
		"timer_ms": 0, "targets": 0,
	}

func apply_arena_state(row: Dictionary, initial_state: bool) -> void:
	var alive := ArenaState.is_alive(row)
	var was_dead := _dead
	_health.hp = clampf(float(row.get("hp", 0.0)), 0.0, 1.0) * max_hp
	_wreck = 1.0 - _health.hp / maxf(max_hp, 0.001)
	if alive:
		_dead = false
		visible = true
		collision_layer = _base_collision_layer
		_vis.visible = deco == &""  # resurrect the plain slab's polygon too
		queue_redraw()
		if was_dead:
			restored.emit()
	elif not _dead:
		if not initial_state:
			_spawn_death_visual()  # late joiners get silent remains, no boom
		_present_remains()
	_net_initialized = true

func _boom_tint() -> Color:
	match deco:
		&"house":
			return ROOF_DARK
		&"barrel", &"tanker", &"pump":
			return Color(1.0, 0.45, 0.15)  # fuel fire
		&"semi":
			return ROAD_TRAILERS[1]
		&"hay":
			return STRAW
		&"storefront":
			return STOREFRONT_ROOFS[0]
		&"fence":
			return Color(0.9, 0.88, 0.82)  # splinters fly white
		&"iron_fence":
			return IRON_HI  # black iron shears dull
		&"food_truck":
			return Color(1.0, 0.45, 0.15)  # the propane griddle goes up
		&"chainlink":
			return Color(0.7, 0.74, 0.72)  # mesh crumples gray
		&"fan_rail":
			return FAN_BLUE  # crowd-control blue shears off
		_:
			return BASE_COLOR

## Fuel detonation: flat damage to every Health-bearing body in range —
## vehicles, pumps, other explosives (chain reactions welcome), and you.
func _blast(radius: float, damage: float) -> void:
	var shape: Shape2D
	var query_rotation := 0.0
	if deco == &"tanker" and not is_equal_approx(size.x, size.y):
		# Radius follows the tank's cylindrical spine; a long hull must not eat
		# most of its own blast reach. Square fixtures keep the legacy circle.
		var capsule := CapsuleShape2D.new()
		capsule.radius = radius
		capsule.height = radius * 2.0 + absf(size.x - size.y)
		shape = capsule
		query_rotation = PI * 0.5 if size.x > size.y else 0.0
	else:
		var circle := CircleShape2D.new()
		circle.radius = radius
		shape = circle
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(query_rotation, global_position)
	params.collision_mask = 1 | 4 | (1 << 9)  # cars + obstacles + soft targets
	params.collide_with_areas = true
	params.exclude = [get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(params):
		var body: Node = hit["collider"]
		if not Floors.same_floor(self, body):
			continue  # a dock-level fireball doesn't cook the roof
		for child in body.get_children():
			if child is Health:
				# Kind breadcrumb only — fuel kills stay deliberately creditless
				# (no last_attacker, no Combat.scale): shoot a barrel, walk away.
				if body.has_method(&"note_hit"):
					body.call(&"note_hit", HitTags.ENVIRONMENT)
				body.set_meta(&"bc_hit_kind", &"environment")
				child.take_damage(damage)
				break

func _shade(c: Color) -> Color:
	return c.lerp(WRECKED_COLOR, _wreck)

func _seed_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(position.x * 7.0 + position.y * 13.0))
	return rng

## The livery pick, shared by the live paint and the remains (both consume the
## seeded rng's FIRST roll, so a crumpled container keeps its harbor color).
func _container_livery(rng: RandomNumberGenerator) -> Color:
	if livery >= 0 and livery < CONTAINER_PALETTES.size():
		return CONTAINER_PALETTES[livery]
	return CONTAINER_PALETTES[rng.randi() % CONTAINER_PALETTES.size()]

## Same contract for the street-food fleet.
func _truck_livery(rng: RandomNumberGenerator) -> Color:
	if livery >= 0 and livery < TRUCK_PALETTES.size():
		return TRUCK_PALETTES[livery]
	return TRUCK_PALETTES[rng.randi() % TRUCK_PALETTES.size()]

## Livery seams for highway cabs and strip-mall awnings.
func _road_truck_livery(rng: RandomNumberGenerator) -> Color:
	if livery >= 0 and livery < ROAD_TRUCK_PALETTES.size():
		return ROAD_TRUCK_PALETTES[livery]
	return ROAD_TRUCK_PALETTES[rng.randi() % ROAD_TRUCK_PALETTES.size()]

func _storefront_livery(rng: RandomNumberGenerator) -> Color:
	if livery >= 0 and livery < STOREFRONT_PALETTES.size():
		return STOREFRONT_PALETTES[livery]
	return STOREFRONT_PALETTES[rng.randi() % STOREFRONT_PALETTES.size()]

func _draw() -> void:
	if _dead:
		var spec: Array = REMAINS.get(deco, REMAINS[&""])
		var base: Color = spec[1]
		if deco == &"container":
			base = _container_livery(_seed_rng()).darkened(0.55)
		elif deco == &"food_truck":
			base = _truck_livery(_seed_rng()).darkened(0.5)
		RemainsPaint.draw_marks(self, RemainsPaint.generate(size * 0.5, spec[0],
			base, spec[2], RemainsPaint.remains_seed(position)))
		return
	match deco:
		&"house":
			_draw_house()
		&"crate":
			_draw_crate()
		&"kiosk":
			_draw_kiosk()
		&"barrier":
			_draw_barrier()
		&"pillar":
			_draw_pillar()
		&"trailer":
			_draw_trailer()
		&"booth":
			_draw_booth()
		&"tires":
			_draw_tires()
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
		&"semi":
			_draw_semi()
		&"tanker":
			_draw_tanker()
		&"hay":
			_draw_hay()
		&"storefront":
			_draw_storefront()
		&"fence":
			_draw_fence()
		&"iron_fence":
			_draw_iron_fence()
		&"container":
			_draw_container()
		&"food_truck":
			_draw_food_truck()
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

## Overpass pillar (deco = &"pillar"): a square concrete column with a hazard
## stripe at its foot — the Route 666 overpass supports, smashable so nothing
## on that road ever stops a car (the deck above stays up; theatrics win).
func _draw_pillar() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half, size), _shade(Color(0.42, 0.42, 0.45)))
	draw_rect(Rect2(-half + Vector2(4, 4), size - Vector2(8, 8)), _shade(Color(0.48, 0.48, 0.51)))
	draw_rect(Rect2(Vector2(-half.x, half.y - 10), Vector2(size.x, 10)), _shade(HAZARD_YELLOW))
	for i in 3:
		var x := -half.x + 6 + float(i) * (size.x / 3.0)
		draw_line(Vector2(x, half.y - 10), Vector2(x + 8, half.y), _shade(HAZARD_DARK), 3.0)

## Jackknifed trailer (deco = &"trailer"): a long box on its side across the
## road — corrugated flank, a faded livery band, the wheels in the air on
## the far edge, a torn rear door.
func _draw_trailer() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half, size), _shade(Color(0.72, 0.7, 0.66)))
	draw_rect(Rect2(-half + Vector2(3, 3), size - Vector2(6, 6)), _shade(Color(0.78, 0.76, 0.72)))
	var band := Rect2(Vector2(-half.x + 12, -half.y * 0.25), Vector2(size.x - 24, half.y * 0.5))
	draw_rect(band, _shade(Color(0.5, 0.18, 0.16)))
	for i in int(size.x / 14.0):
		var x := -half.x + 7 + float(i) * 14.0
		draw_line(Vector2(x, -half.y + 3), Vector2(x, half.y - 3), _shade(Color(0.6, 0.58, 0.54)), 1.0)
	for k in 4:   # the wheels, up in the air along the far flank
		var wx := -half.x + size.x * (0.2 + 0.2 * float(k))
		draw_circle(Vector2(wx, half.y - 4), 7.0, _shade(Color(0.12, 0.12, 0.13)))
		draw_circle(Vector2(wx, half.y - 4), 3.0, _shade(Color(0.5, 0.5, 0.52)))
	draw_rect(Rect2(Vector2(half.x - 10, -half.y), Vector2(10, size.y)), _shade(Color(0.3, 0.3, 0.32)))
	draw_line(Vector2(half.x - 10, -half.y + 6), Vector2(half.x - 2, half.y * 0.4), _shade(Color(0.16, 0.16, 0.17)), 2.0)

## Toll booth (deco = &"booth"): a little hut with a window, a striped
## fascia and a shut hatch — CASH ONLY, and nobody home.
func _draw_booth() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half, size), _shade(Color(0.62, 0.6, 0.55)))
	draw_rect(Rect2(-half + Vector2(3, 3), size - Vector2(6, 6)), _shade(Color(0.7, 0.68, 0.63)))
	draw_rect(Rect2(Vector2(-half.x, -half.y), Vector2(size.x, 8)), _shade(HAZARD_YELLOW))
	for i in int(size.x / 12.0):
		var x := -half.x + float(i) * 12.0
		draw_line(Vector2(x, -half.y), Vector2(x + 6, -half.y + 8), _shade(HAZARD_DARK), 3.0)
	draw_rect(Rect2(Vector2(-half.x * 0.5, -half.y * 0.2), Vector2(size.x * 0.5, half.y * 0.55)), _shade(Color(0.32, 0.4, 0.48)))
	draw_rect(Rect2(Vector2(-half.x * 0.5, -half.y * 0.2), Vector2(size.x * 0.5, half.y * 0.55)), _shade(Color(0.2, 0.2, 0.22)), false, 2.0)
	draw_rect(Rect2(Vector2(-half.x * 0.35, half.y * 0.5), Vector2(size.x * 0.35, 6)), _shade(Color(0.3, 0.28, 0.26)))

## Tire stack (deco = &"tires"): a pile of old tires from above — a fat black
## ring with a tread band and a dark hub hole, a second ring slumped off-axis
## on top, a stray tire leaning against the pile. Route 666's burning tire
## wall: 22 HP each, so a smash costs a nick and keeps most of the momentum.
func _draw_tires() -> void:
	var rng := _seed_rng()
	var r := minf(size.x, size.y) * 0.5
	draw_circle(Vector2(5, 7), r, Color(0, 0, 0, 0.3))
	var rubber := _shade(TIRE_BLACK)
	var tread := _shade(Color(0.18, 0.18, 0.2))
	var hole := _shade(Color(0.04, 0.04, 0.05))
	# The stray at the foot of the pile, seen edge-on: a dark lozenge.
	var lean := Vector2(r * 0.55, r * 0.55).rotated(rng.randf_range(-0.6, 0.6))
	draw_colored_polygon(PackedVector2Array([
		lean + Vector2(-r * 0.5, -r * 0.18), lean + Vector2(r * 0.5, -r * 0.18),
		lean + Vector2(r * 0.5, r * 0.18), lean + Vector2(-r * 0.5, r * 0.18),
	]), rubber)
	# The stack: bottom ring, then one slumped off-axis on top.
	draw_circle(Vector2.ZERO, r, rubber)
	draw_arc(Vector2.ZERO, r * 0.82, 0.0, TAU, 28, tread, 3.0)
	for i in 10:
		var a := TAU * float(i) / 10.0
		draw_line(Vector2.RIGHT.rotated(a) * r * 0.7, Vector2.RIGHT.rotated(a) * r * 0.96, tread, 2.0)
	var top := Vector2(rng.randf_range(-r * 0.2, r * 0.2), rng.randf_range(-r * 0.25, 0.0))
	draw_circle(top, r * 0.88, rubber)
	draw_arc(top, r * 0.72, 0.0, TAU, 28, tread, 2.5)
	draw_circle(top, r * 0.42, hole)
	draw_arc(top, r * 0.46, 0.0, TAU, 20, _shade(Color(0.26, 0.26, 0.28)), 1.5)

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
	_draw_picket_bar(_shade(Color(0.92, 0.9, 0.85)), _shade(Color(0.68, 0.66, 0.6)), 8.0, 6.0)

## Black wrought iron (top-down strip): thin frequent bars, a highlight rail,
## finial dots at the span ends. Authored heavier (~30 HP) — the White House
## ring is containment you have to EARN through, not a fender-tap.
func _draw_iron_fence() -> void:
	_draw_picket_bar(_shade(IRON), _shade(IRON_HI), 4.0, 10.0)
	var half := size * 0.5
	var tall := size.y > size.x
	var ends: Array = [Vector2(0.0, -half.y + 3.0), Vector2(0.0, half.y - 3.0)] if tall \
		else [Vector2(-half.x + 3.0, 0.0), Vector2(half.x - 3.0, 0.0)]
	for p: Vector2 in ends:
		draw_circle(p, 3.0, _shade(IRON_HI))

## Shared picket geometry: slats across the run + a rail along it. Fence
## variants are palette + pitch swaps over these bones (the fan_rail idiom).
func _draw_picket_bar(slat: Color, rail: Color, picket: float, gap: float) -> void:
	var half := size * 0.5
	var tall := size.y > size.x
	var length := size.y if tall else size.x
	var n := int(length / (picket + gap))
	for i in n:
		var t := -length * 0.5 + i * (picket + gap) + gap * 0.5
		if tall:
			draw_rect(Rect2(-half.x, t, size.x, picket), slat)
		else:
			draw_rect(Rect2(t, -half.y, picket, size.y), slat)
	if tall:
		draw_rect(Rect2(-2.0, -half.y, 4.0, size.y), rail)
	else:
		draw_rect(Rect2(-half.x, -2.0, size.x, 4.0), rail)

## Street food truck (top-down box truck): livery body, cab quarter, awning
## over the serving window, roof vents, tail menu board, wheels on both sides.
## Drawn long-axis-horizontal; tall instances ride a 90-degree canvas turn.
func _draw_food_truck() -> void:
	var rng := _seed_rng()
	var base := _truck_livery(rng)
	var dark := base.darkened(0.45)
	var tall := size.y > size.x
	var run := size.y if tall else size.x
	var wide := size.x if tall else size.y
	var h := Vector2(run, wide) * 0.5
	if tall:
		draw_set_transform(Vector2.ZERO, PI * 0.5, Vector2.ONE)
	draw_rect(Rect2(-h + Vector2(6, 9), Vector2(run, wide)), SHADOW)
	draw_rect(Rect2(-h, Vector2(run, wide)), _shade(base))
	# Cab quarter at the +run end: steel + a windshield band.
	var cab_w := run * 0.22
	draw_rect(Rect2(Vector2(h.x - cab_w, -h.y), Vector2(cab_w, wide)), _shade(dark))
	draw_rect(Rect2(Vector2(h.x - cab_w + 4.0, -h.y + 3.0), Vector2(5.0, wide - 6.0)),
		_shade(Color(0.6, 0.72, 0.78)))
	# Serving window along the -wide side, striped awning proud of the body.
	var win_x := -h.x + run * 0.12
	var win_w := run * 0.45
	draw_rect(Rect2(Vector2(win_x, -h.y + 2.0), Vector2(win_w, 7.0)), _shade(Color(0.12, 0.1, 0.1)))
	var stripes := maxi(int(win_w / 12.0), 4)
	for i in stripes:
		var sx := win_x + win_w * float(i) / float(stripes)
		var c := Color(0.9, 0.88, 0.84) if i % 2 == 0 else base.lightened(0.2)
		draw_rect(Rect2(Vector2(sx, -h.y - 5.0), Vector2(win_w / float(stripes), 6.0)), _shade(c))
	# Roof furniture: vent hood + fan, tail menu board.
	draw_rect(Rect2(Vector2(-h.x + run * 0.62, -wide * 0.2), Vector2(14.0, 10.0)), _shade(dark))
	draw_circle(Vector2(-h.x + run * 0.56, wide * 0.14), 4.0, _shade(dark))
	draw_rect(Rect2(Vector2(-h.x + 2.0, h.y - 9.0), Vector2(10.0, 7.0)), _shade(Color(0.2, 0.18, 0.16)))
	# Wheels peeking past both long sides.
	for wx: float in [-h.x + run * 0.18, h.x - cab_w * 0.5]:
		draw_rect(Rect2(Vector2(wx - 7.0, -h.y - 1.0), Vector2(14.0, 4.0)), Color(0.08, 0.08, 0.09))
		draw_rect(Rect2(Vector2(wx - 7.0, h.y - 3.0), Vector2(14.0, 4.0)), Color(0.08, 0.08, 0.09))
	draw_rect(Rect2(-h, Vector2(run, wide)), _shade(dark), false, 2.5)
	if tall:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Shipping container (top-down): seeded livery, corrugation ribs across the
## short axis, corner castings, door bars on the +long end.
func _draw_container() -> void:
	var half := size * 0.5
	var rng := _seed_rng()
	var base := _container_livery(rng)
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

## Parked highway semi: a weathered box trailer behind a bright fleet cab.
## Like the food truck, its drawing space always runs left-to-right.
func _draw_semi() -> void:
	var rng := _seed_rng()
	var trailer: Color = ROAD_TRAILERS[rng.randi() % ROAD_TRAILERS.size()]
	var cab := _road_truck_livery(rng)
	var tall := size.y > size.x
	var run := size.y if tall else size.x
	var wide := size.x if tall else size.y
	var h := Vector2(run, wide) * 0.5
	if tall:
		draw_set_transform(Vector2.ZERO, PI * 0.5, Vector2.ONE)
	draw_rect(Rect2(-h + Vector2(6, 9), Vector2(run, wide)), SHADOW)
	draw_line(Vector2(-h.x + 3.0, 0.0), Vector2(h.x - 3.0, 0.0),
		_shade(METAL_DARK), 7.0)
	var trailer_w := run * 0.60
	var trailer_rect := Rect2(Vector2(-h.x, -h.y * 0.9), Vector2(trailer_w, wide * 0.9))
	draw_rect(trailer_rect, _shade(trailer))
	draw_rect(trailer_rect, _shade(trailer.darkened(0.38)), false, 2.5)
	# Roof seam and a few deterministic road-grime scratches.
	draw_line(Vector2(-h.x + 5.0, 0.0), Vector2(-h.x + trailer_w - 5.0, 0.0),
		_shade(trailer.darkened(0.22)), 2.0)
	for i in 2:
		var x := rng.randf_range(-h.x + trailer_w * 0.18, -h.x + trailer_w * 0.82)
		var y := rng.randf_range(-wide * 0.28, wide * 0.28)
		draw_line(Vector2(x - 5.0, y), Vector2(x + 7.0, y + 1.0),
			_shade(trailer.darkened(0.3)), 1.2)
	# Twin hinges at the -run doors.
	for y: float in [-wide * 0.23, wide * 0.23]:
		draw_line(Vector2(-h.x + 2.0, y), Vector2(-h.x + 11.0, y),
			_shade(METAL_DARK), 3.0)
		draw_circle(Vector2(-h.x + 5.0, y), 2.0, _shade(HAZARD_DARK))
	_draw_road_cab(h, run, wide, cab)
	_draw_road_wheels(h, run, wide)
	if tall:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Fuel tanker: the semi cab pulling a rounded, banded aluminium cylinder.
func _draw_tanker() -> void:
	var rng := _seed_rng()
	var tank: Color = ROAD_TRAILERS[rng.randi() % ROAD_TRAILERS.size()]
	var cab := _road_truck_livery(rng)
	var tall := size.y > size.x
	var run := size.y if tall else size.x
	var wide := size.x if tall else size.y
	var h := Vector2(run, wide) * 0.5
	if tall:
		draw_set_transform(Vector2.ZERO, PI * 0.5, Vector2.ONE)
	draw_rect(Rect2(-h + Vector2(6, 9), Vector2(run, wide)), SHADOW)
	draw_line(Vector2(-h.x + 3.0, 0.0), Vector2(h.x - 3.0, 0.0),
		_shade(METAL_DARK), 7.0)
	var tank_left := -h.x
	var tank_length := run * 0.60
	var tank_right := tank_left + tank_length
	var tank_r := minf(wide * 0.36, tank_length * 0.28)
	var left_cap := Vector2(tank_left + tank_r, 0.0)
	var right_cap := Vector2(tank_right - tank_r, 0.0)
	draw_circle(left_cap, tank_r, _shade(tank))
	draw_circle(right_cap, tank_r, _shade(tank))
	draw_rect(Rect2(Vector2(left_cap.x, -tank_r),
		Vector2(right_cap.x - left_cap.x, tank_r * 2.0)), _shade(tank))
	var tank_dark := _shade(tank.darkened(0.4))
	draw_arc(left_cap, tank_r, PI * 0.5, PI * 1.5, 16, tank_dark, 2.5)
	draw_arc(right_cap, tank_r, -PI * 0.5, PI * 0.5, 16, tank_dark, 2.5)
	draw_line(Vector2(left_cap.x, -tank_r), Vector2(right_cap.x, -tank_r), tank_dark, 2.5)
	draw_line(Vector2(left_cap.x, tank_r), Vector2(right_cap.x, tank_r), tank_dark, 2.5)
	# Sun strip, three hoops, placard, and a seeded manhole on the tank crown.
	draw_line(Vector2(left_cap.x, -tank_r * 0.42),
		Vector2(right_cap.x, -tank_r * 0.42), _shade(tank.lightened(0.34)), 3.0)
	for fraction: float in [0.23, 0.50, 0.77]:
		var x := tank_left + tank_length * fraction
		draw_line(Vector2(x, -tank_r), Vector2(x, tank_r), tank_dark, 3.0)
	var placard := Vector2(tank_left + tank_r * 0.85, tank_r * 0.22)
	draw_rect(Rect2(placard - Vector2(5, 5), Vector2(10, 10)), _shade(HAZARD_YELLOW))
	draw_rect(Rect2(placard - Vector2(5, 5), Vector2(10, 10)),
		_shade(HAZARD_DARK), false, 1.5)
	var hatch_x := lerpf(left_cap.x, right_cap.x, rng.randf_range(0.42, 0.58))
	draw_circle(Vector2(hatch_x, -tank_r * 0.08), 5.0, tank_dark)
	draw_circle(Vector2(hatch_x, -tank_r * 0.08), 2.5, _shade(tank.lightened(0.2)))
	_draw_road_cab(h, run, wide, cab)
	_draw_road_wheels(h, run, wide)
	if tall:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Shared tractor nose: livery cab, windshield band, stack, and front bumper.
func _draw_road_cab(h: Vector2, run: float, wide: float, cab: Color) -> void:
	var cab_w := run * 0.24
	var cab_x := h.x - cab_w
	var cab_rect := Rect2(Vector2(cab_x, -h.y), Vector2(cab_w, wide))
	draw_rect(cab_rect, _shade(cab))
	draw_rect(cab_rect, _shade(cab.darkened(0.42)), false, 2.5)
	draw_rect(Rect2(Vector2(cab_x + 4.0, -h.y + 4.0), Vector2(6.0, wide - 8.0)),
		_shade(Color(0.58, 0.72, 0.79)))
	draw_circle(Vector2(cab_x - 5.0, -wide * 0.28), 3.5, _shade(METAL_DARK))
	draw_rect(Rect2(Vector2(h.x - 4.0, -h.y + 3.0), Vector2(4.0, wide - 6.0)),
		_shade(Color(0.65, 0.66, 0.65)))

func _draw_road_wheels(h: Vector2, run: float, wide: float) -> void:
	var cab_w := run * 0.24
	for wx: float in [-h.x + run * 0.18, -h.x + run * 0.48, h.x - cab_w * 0.5]:
		draw_rect(Rect2(Vector2(wx - 6.0, -wide * 0.5 - 1.0), Vector2(12.0, 4.0)),
			_shade(TIRE_BLACK))
		draw_rect(Rect2(Vector2(wx - 6.0, wide * 0.5 - 3.0), Vector2(12.0, 4.0)),
			_shade(TIRE_BLACK))

## Round bale from above: layered straw coils, crossed twine, loose whiskers.
func _draw_hay() -> void:
	var rng := _seed_rng()
	var r := minf(size.x, size.y) * 0.5
	draw_circle(Vector2(6, 9), r, SHADOW)
	draw_circle(Vector2.ZERO, r, _shade(STRAW_DARK))
	draw_circle(Vector2.ZERO, r * 0.94, _shade(STRAW))
	for fraction: float in [0.28, 0.52, 0.76]:
		draw_arc(Vector2.ZERO, r * fraction, 0.0, TAU, 28, _shade(STRAW_DARK), 1.5)
	draw_line(Vector2(-r * 0.84, 0.0), Vector2(r * 0.84, 0.0),
		_shade(STRAW_TWINE), 2.5)
	draw_line(Vector2(0.0, -r * 0.84), Vector2(0.0, r * 0.84),
		_shade(STRAW_TWINE), 2.5)
	for i in 10:
		var angle := TAU * float(i) / 10.0 + rng.randf_range(-0.18, 0.18)
		var start := Vector2.RIGHT.rotated(angle) * r * rng.randf_range(0.78, 0.94)
		var finish := Vector2.RIGHT.rotated(angle + rng.randf_range(-0.12, 0.12)) \
			* r * rng.randf_range(1.02, 1.14)
		draw_line(start, finish, _shade(STRAW_DARK), 1.4)

## Strip-mall unit: seeded flat roof and one explicitly authored shop front.
## Signage remains a level-owned child; this paint supplies no words.
func storefront_hvac_count() -> int:
	if minf(size.x, size.y) < 192.0:
		return 0
	return 2 if maxf(size.x, size.y) >= 320.0 else 1

func _draw_storefront() -> void:
	var rng := _seed_rng()
	var roof: Color = STOREFRONT_ROOFS[rng.randi() % STOREFRONT_ROOFS.size()]
	var stripe := _storefront_livery(rng)
	var half := size * 0.5
	draw_rect(Rect2(-half + SHADOW_OFFSET, size), SHADOW)
	draw_rect(Rect2(-half, size), _shade(roof))
	# Old tar repairs interrupt the gravel field differently on every unit.
	for i in 2 + rng.randi() % 2:
		var patch_size := Vector2(rng.randf_range(12.0, 28.0),
			rng.randf_range(12.0, 28.0))
		var inset := patch_size * 0.5 + Vector2(9, 9)
		var center := Vector2(rng.randf_range(-half.x + inset.x, half.x - inset.x),
			rng.randf_range(-half.y + inset.y, half.y - inset.y))
		draw_rect(Rect2(center - patch_size * 0.5, patch_size),
			_shade(roof.darkened(rng.randf_range(0.12, 0.22))))
	# Sparse two-tone grit keeps the broad roof plane from reading as a slab.
	for i in int(size.x * size.y / 3500.0):
		var grit := Vector2(rng.randf_range(-half.x + 8.0, half.x - 11.0),
			rng.randf_range(-half.y + 8.0, half.y - 11.0))
		var grit_color := GRAVEL_DARK if rng.randf() < 0.6 else GRAVEL_LIGHT
		draw_rect(Rect2(grit, Vector2(3, 3)), _shade(grit_color))
	var hvac_count := storefront_hvac_count()
	for i in hvac_count:
		var unit_size := Vector2(rng.randf_range(42.0, 58.0), rng.randf_range(36.0, 48.0))
		var lane := 0.0 if hvac_count == 1 else lerpf(-0.22, 0.22, float(i))
		var center := Vector2(size.x * lane, rng.randf_range(-size.y * 0.18, size.y * 0.18)) \
			if size.x >= size.y else \
			Vector2(rng.randf_range(-size.x * 0.18, size.x * 0.18), size.y * lane)
		var unit := Rect2(center - unit_size * 0.5, unit_size)
		draw_rect(Rect2(unit.position + Vector2(3, 4), unit.size), HVAC_SHADOW)
		draw_rect(unit, _shade(HVAC))
		draw_rect(unit, _shade(HVAC_EDGE), false, 1.5)
		var fan_radius := minf(unit_size.x, unit_size.y) * 0.28
		draw_circle(center, fan_radius, _shade(METAL_DARK))
		draw_line(center - Vector2(fan_radius * 0.75, 0),
			center + Vector2(fan_radius * 0.75, 0), _shade(HVAC_EDGE), 1.5)
		draw_line(center - Vector2(0, fan_radius * 0.75),
			center + Vector2(0, fan_radius * 0.75), _shade(HVAC_EDGE), 1.5)
	# Little vent stacks, each with a soot-dark opening.
	for i in 2 + rng.randi() % 2:
		var vent := Vector2(rng.randf_range(-half.x + 24.0, half.x - 24.0),
			rng.randf_range(-half.y + 24.0, half.y - 24.0))
		draw_rect(Rect2(vent - Vector2(5, 4), Vector2(10, 8)),
			_shade(roof.darkened(0.24)))
		draw_circle(vent, 2.0, _shade(roof.darkened(0.55)))
	var corner: Vector2 = [Vector2(-1, -1), Vector2(1, -1),
		Vector2(1, 1), Vector2(-1, 1)][rng.randi() % 4]
	var drain := corner * (half - Vector2(rng.randf_range(15.0, 23.0),
		rng.randf_range(15.0, 23.0)))
	draw_rect(Rect2(drain - Vector2(4, 4), Vector2(8, 8)), _shade(roof.darkened(0.48)))
	# Bright outside lip plus the dark inner tar seam gives the parapet its height.
	draw_rect(Rect2(-half, size), _shade(roof.lightened(0.12)), false, 5.0)
	draw_rect(Rect2(-half + Vector2(7, 7), size - Vector2(14, 14)),
		_shade(roof.darkened(0.32)), false, 2.0)
	_draw_storefront_front(stripe)

func _draw_storefront_front(stripe: Color) -> void:
	var cream := _shade(AWNING_CREAM)
	var accent := _shade(stripe)
	var mat := _shade(Color(0.22, 0.16, 0.12))
	var edge := _shade(METAL_DARK)
	var glass := _shade(Color(0.13, 0.20, 0.24))
	var glint := _shade(Color(0.42, 0.55, 0.62))
	var front_width := size.x if front == "north" or front == "south" else size.y
	var wall_distance := size.y * 0.5 if front == "north" or front == "south" \
		else size.x * 0.5
	var angle := 0.0
	match front:
		"north":
			angle = PI
		"west":
			angle = PI * 0.5
		"east":
			angle = -PI * 0.5
	draw_set_transform(Vector2.ZERO, angle, Vector2.ONE)
	var depth := 18.0
	var length := front_width - 32.0
	var stripes := clampi(roundi(length / 32.0), 6, 10)
	var stripe_width := length / float(stripes)
	for i in stripes:
		var color := accent if i % 2 == 0 else cream
		draw_rect(Rect2(Vector2(-length * 0.5 + stripe_width * i, wall_distance),
			Vector2(stripe_width, depth)), color)
	draw_rect(Rect2(Vector2(-length * 0.5, wall_distance), Vector2(length, depth)),
		edge, false, 1.5)
	var window_width := front_width * 0.4
	var shopfront_y := wall_distance + depth
	draw_rect(Rect2(Vector2(-window_width * 0.5, shopfront_y),
		Vector2(window_width, 8.0)), glass)
	draw_line(Vector2(-window_width * 0.36, shopfront_y + 2.0),
		Vector2(-window_width * 0.08, shopfront_y + 2.0), glint, 1.5)
	draw_line(Vector2(window_width * 0.08, shopfront_y + 5.0),
		Vector2(window_width * 0.34, shopfront_y + 5.0), glint, 1.5)
	var mat_width := minf(24.0, maxf(length * 0.5 - window_width * 0.5 - 8.0, 8.0))
	draw_rect(Rect2(Vector2(window_width * 0.5 + 4.0, shopfront_y),
		Vector2(mat_width, 8.0)), mat)
	draw_line(Vector2(-length * 0.5, wall_distance),
		Vector2(length * 0.5, wall_distance), edge, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
