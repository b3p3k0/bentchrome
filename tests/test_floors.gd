extends RefCounted
## Terraced-floor core. Locks the load-bearing contract: legacy (-1) mask math
## is bit-for-bit today's values, zones adopt, driving past a lower seam ledge-
## hops, 2+ floor landings bill fall damage, the size cue never touches the
## collision radius, and respawn resets to legacy for re-adoption.

const Floors := preload("res://game/floors.gd")
const VehicleScene := preload("res://vehicles/vehicle.tscn")
const FloorZoneScene := preload("res://environment/floor_zone.tscn")

var t

func _init(runner) -> void:
	t = runner

func test_mask_math_legacy_is_bit_for_bit() -> void:
	t.check(Floors.ground_layer(-1) == 1, "floors: legacy layer is exactly 1")
	t.check(Floors.ground_mask(-1) == 7, "floors: legacy mask is exactly 7")
	t.check(Floors.projectile_mask(-1, false) == 7, "floors: legacy straight shot mask 7")
	t.check(Floors.projectile_mask(-1, true) == 7, "floors: legacy tracking shot mask 7")
	t.check(Floors.los_mask(-1) == 7, "floors: legacy LoS mask 7")

func test_mask_math_floor_mode() -> void:
	t.check(Floors.floor_bit(1) == 8 and Floors.floor_bit(2) == 16 and Floors.floor_bit(3) == 32,
		"floors: floor bits are 8/16/32")
	t.check(Floors.ground_layer(2) == (1 | 16), "floors: floor-2 layer keeps the ground bit")
	t.check(Floors.ground_mask(2) == (2 | 16), "floors: floor-2 mask = wall + own floor")
	t.check(Floors.projectile_mask(2, false) == (2 | 16), "floors: straight shot never signals cross-floor cars")
	t.check(Floors.projectile_mask(2, true) == (1 | 2), "floors: tracking shot arcs over floor statics")
	t.check(Floors.los_mask(3) == (1 | 2 | 32), "floors: LoS blocks on own-floor statics")

func test_same_floor_duck_typing() -> void:
	var a := Node.new()
	var b := Node.new()
	t.check(Floors.floor_of(a) == -1, "floors: plain node reads as legacy")
	t.check(Floors.same_floor(a, b), "floors: legacy participants never gate")
	a.free()
	b.free()

func _fixture(zones: Array) -> Dictionary:
	# zones: [{floor, pos, size}] — abutting rects, pit_zone fixture pattern.
	var container := Node2D.new()
	t.root.add_child(container)
	for z in zones:
		var zone = FloorZoneScene.instantiate()
		zone.floor_index = z.floor
		zone.size = z.size
		zone.position = z.pos
		container.add_child(zone)
	var car = VehicleScene.instantiate()
	container.add_child(car)  # (0,0) — inside the first zone by convention
	return {"container": container, "car": car}

func _done(f: Dictionary) -> void:
	t.root.remove_child(f.container)
	f.container.free()

func _settle(frames: int) -> void:
	for i in frames:
		await t.physics_frame

func test_adopt_and_one_floor_drop_is_free() -> void:
	var f := _fixture([
		{"floor": 2, "pos": Vector2.ZERO, "size": Vector2(600, 600)},
		{"floor": 1, "pos": Vector2(900, 0), "size": Vector2(600, 600)},
	])
	await _settle(3)
	t.check(f.car.floor_index == 2, "floors: car adopts the zone under it")
	t.check(f.car.collision_layer == (1 | 16), "floors: adopted layer applied")
	t.check(f.car.collision_mask == (2 | 16), "floors: adopted mask applied")
	f.car.global_position = Vector2(900, 0)  # past the seam, over floor 1
	await _settle(3)
	t.check(f.car.height > 0.0 or f.car.vz > 0.0, "floors: lower seam ledge-hops airborne")
	await _settle(60)  # DROP_POP_VZ 240 lands in ~0.4s
	t.check(f.car.height == 0.0, "floors: ledge hop lands")
	t.check(f.car.floor_index == 1, "floors: landing adopts the lower floor")
	var health = f.car.get_node("Health")
	t.check(health.hp >= health.max_hp, "floors: one-floor drop is free")
	_done(f)

func test_two_floor_fall_bills_max_hp_fraction() -> void:
	var f := _fixture([
		{"floor": 3, "pos": Vector2.ZERO, "size": Vector2(600, 600)},
		{"floor": 1, "pos": Vector2(900, 0), "size": Vector2(600, 600)},
	])
	await _settle(3)
	t.check(f.car.floor_index == 3, "floors: car adopts the roof")
	f.car.global_position = Vector2(900, 0)
	await _settle(90)  # two-floor pop (~480 vz) needs the longer arc
	t.check(f.car.floor_index == 1, "floors: two-floor drop lands on floor 1")
	var health = f.car.get_node("Health")
	var expected: float = health.max_hp * (1.0 - f.car.fall_damage_frac)
	t.check(absf(health.hp - expected) < 0.5,
		"floors: 2-floor fall costs fall_damage_frac of max HP (hp %.1f, want %.1f)" % [health.hp, expected])
	_done(f)

func test_size_cue_never_touches_the_radius() -> void:
	var f := _fixture([{"floor": 3, "pos": Vector2.ZERO, "size": Vector2(600, 600)}])
	var col: CollisionShape2D = f.car.get_node("CollisionShape2D")
	var radius_before: float = (col.shape as CircleShape2D).radius
	await _settle(30)  # adoption + the 0.25s scale tween
	var vis: Node2D = f.car.get_node("Visual")
	var want: float = f.car.body_scale * float(Floors.VISUAL_SCALE[3])
	t.check(absf(vis.scale.x - want) < 0.01, "floors: roof size cue reaches the visual")
	var radius_after: float = ((f.car.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D).radius
	t.check(is_equal_approx(radius_before, radius_after), "floors: collision radius untouched by the cue")
	_done(f)

func test_draw_order_tracks_floor_and_air() -> void:
	var f := _fixture([
		{"floor": 3, "pos": Vector2.ZERO, "size": Vector2(600, 600)},
		{"floor": 1, "pos": Vector2(900, 0), "size": Vector2(600, 600)},
	])
	await _settle(3)
	t.check(f.car.z_index == 2, "floors: roof car draws above overhead paint (z 2)")
	f.car.global_position = Vector2(900, 0)
	await _settle(3)
	t.check(f.car.z_index == 2, "floors: mid-drop stays above (airborne z 2)")
	await _settle(90)
	t.check(f.car.z_index == 0, "floors: landed low car returns to z 0")
	f.car.respawn(Vector2(900, 0), 0.0, 0.0)
	t.check(f.car.z_index == 0, "floors: respawn resets draw order")
	_done(f)

func test_respawn_resets_to_legacy_then_readopts() -> void:
	var f := _fixture([{"floor": 3, "pos": Vector2.ZERO, "size": Vector2(600, 600)}])
	await _settle(30)
	t.check(f.car.floor_index == 3, "floors: pre-respawn adoption")
	f.car.respawn(Vector2.ZERO, 0.0, 0.0)
	t.check(f.car.floor_index == -1, "floors: respawn resets to legacy")
	var vis: Node2D = f.car.get_node("Visual")
	t.check(is_equal_approx(vis.scale.x, f.car.body_scale), "floors: respawn resets the size cue")
	await _settle(3)
	t.check(f.car.floor_index == 3, "floors: respawned car re-adopts from the sensor")
	_done(f)

func test_ramp_launches_only_its_own_terrace() -> void:
	var f := _fixture([{"floor": 3, "pos": Vector2.ZERO, "size": Vector2(600, 600)}])
	await _settle(3)  # car adopts the roof
	var ramp = load("res://environment/ramp.gd").new()
	ramp.floor_index = 2
	f.container.add_child(ramp)
	f.car.velocity = Vector2(300, 0)
	ramp._on_body_entered(f.car)
	t.check(f.car.vz == 0.0, "floors: a street ramp ignores roof wheels")
	ramp.floor_index = 3
	ramp._on_body_entered(f.car)
	t.check(f.car.vz > 0.0, "floors: the same-terrace ramp launches")
	_done(f)

func test_no_zones_stays_legacy() -> void:
	var f := _fixture([])
	await _settle(3)
	t.check(f.car.floor_index == -1, "floors: zone-free level stays legacy")
	t.check(f.car.collision_mask == 7, "floors: zone-free mask stays 7")
	t.check(f.car.collision_layer == 1, "floors: zone-free layer stays 1")
	_done(f)
