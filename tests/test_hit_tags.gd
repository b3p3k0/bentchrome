extends RefCounted
## Sticker hit identities stay local and never disturb combat attribution.

const HitTags := preload("res://game/hit_tags.gd")
const VehicleScene := preload("res://vehicles/vehicle.tscn")
const ProjectileScene := preload("res://weapons/projectile.tscn")
const NetEvents := preload("res://game/net/net_events.gd")

var t

func _init(runner) -> void:
	t = runner

func _car(parent: Node, pos := Vector2.ZERO) -> Vehicle:
	var car := VehicleScene.instantiate() as Vehicle
	car.faction = &"enemies"
	car.stats = (load("res://data/vehicles/ghost.tres") as VehicleStats).duplicate()
	car.position = pos
	parent.add_child(car)
	return car

func _container() -> Node2D:
	var container := Node2D.new()
	t.root.add_child(container)
	return container

func _done(container: Node) -> void:
	t.root.remove_child(container)
	container.free()

func test_weapon_ids_and_burn_elements() -> void:
	var count := 0
	for file in DirAccess.get_files_at("res://data/weapons"):
		if not file.ends_with(".tres"):
			continue
		count += 1
		var def: WeaponDef = load("res://data/weapons/" + file)
		var expected := StringName(file.get_basename())
		t.check(HitTags.id_for_def(def) == expected,
			"hit tags: %s resolves to its basename" % file)
		for effect in def.on_hit_effects:
			if effect.kind == &"burn":
				t.check(def.element == &"fire",
					"hit tags: burn weapon %s belongs to fire" % expected)
	t.check(count > 0, "hit tags: weapon lint found authored defs")

func test_families() -> void:
	t.check(&"fire" in HitTags.families(&"molotov"), "families: molotov is fire")
	t.check(&"fire" in HitTags.families(&"blunt_blaze"), "families: Blunt Blaze is fire")
	t.check(&"electric" in HitTags.families(&"taser"), "families: taser is electric")
	t.check(HitTags.RAM in HitTags.families(&"leap"), "families: DASH belongs to ram")
	t.check(HitTags.RAM in HitTags.families(&"toe_jam"), "families: TRIGGER belongs to ram")
	t.check(HitTags.RAM in HitTags.families(HitTags.SIDE_SLIDE),
		"families: side slide belongs to ram")
	t.check(HitTags.families(&"missile_rear") == [&"missile_rear"],
		"families: rear missile has only its own identity")

func test_projectile_stamps_weapon_id() -> void:
	NetEvents.reset()
	var container := _container()
	var victim := _car(container)
	var shooter := Node2D.new()
	container.add_child(shooter)
	var shot := ProjectileScene.instantiate() as Projectile
	container.add_child(shot)
	shot.hit_id = &"missile_homing"
	shot.setup(victim.global_position, Vector2.RIGHT, 100.0, 2.0, 1.0, shooter)
	shot._on_body_entered(victim)
	t.check(victim.last_hit_id == &"missile_homing",
		"projectile: weapon id reaches the victim")
	t.check(victim.last_attacker == shooter,
		"projectile: combat attacker stays the shooter")
	NetEvents.reset()
	_done(container)

func test_ram_and_side_slide_ids() -> void:
	t.check(await _ram_id(true) == HitTags.SIDE_SLIDE,
		"ram: a side-sliding rammer stamps side_slide")
	t.check(await _ram_id(false) == HitTags.RAM,
		"ram: a plain rammer stamps ram")

func _ram_id(sliding: bool) -> StringName:
	var container := _container()
	var attacker := _car(container, Vector2.ZERO)
	var victim := _car(container, Vector2(-80, 0))
	await t.physics_frame
	attacker.heading = PI / 2.0 if sliding else PI
	attacker._hb_recent_t = 1.0 if sliding else 0.0
	for i in 30:
		attacker.velocity = Vector2(-900, 0)
		attacker._ram_cd = 0.0
		if sliding:
			attacker._hb_recent_t = 1.0
		attacker._physics_process(1.0 / 60.0)
		if victim.last_hit_id != &"":
			break
	var id: StringName = victim.last_hit_id
	_done(container)
	return id

func test_taser_beam_stamps_taser_not_ram() -> void:
	var container := _container()
	var shooter := _car(container, Vector2.ZERO)
	var victim := _car(container, Vector2(200, 0))
	await t.physics_frame
	var controller: SpecialController = shooter.get_node("SpecialController")
	controller.set_physics_process(false)
	controller._beam_def = load("res://data/weapons/taser.tres")
	controller._beam_target = victim
	controller._beam_t = 1.0
	controller._beam_tick(0.01)
	t.check(victim.last_hit_id == &"taser", "taser: beam tick stamps taser")
	t.check(victim.last_hit_id != HitTags.RAM, "taser: beam tick is not a ram")
	_done(container)

func test_burn_refreshes_sticker_only_for_its_attacker() -> void:
	NetEvents.reset()
	var container := _container()
	var victim := _car(container)
	var shooter := Node2D.new()
	var later_attacker := Node2D.new()
	container.add_child(shooter)
	container.add_child(later_attacker)
	var status: StatusReceiver = victim.get_node("Status")
	status.set_physics_process(false)
	var molotov: WeaponDef = load("res://data/weapons/molotov.tres")
	var shot := ProjectileScene.instantiate() as Projectile
	container.add_child(shot)
	shot.hit_id = &"molotov"
	shot.on_hit_effects = molotov.on_hit_effects
	shot.setup(victim.global_position, Vector2.RIGHT, 100.0, 2.0, 1.0, shooter)
	shot._on_body_entered(victim)
	victim.last_attacker_ms = 101
	var attacker_ms: int = victim.last_attacker_ms
	victim.last_hit_ms = 0
	status.tick(0.01)
	t.check(victim.last_hit_id == &"molotov" and victim.last_hit_ms > 0,
		"burn: owning burn refreshes the molotov sticker")
	t.check(victim.last_attacker_ms == attacker_ms,
		"burn: sticker refresh leaves MP attribution time untouched")

	victim.stamp_hit(later_attacker, &"missile_power")
	victim.last_attacker_ms = 202
	victim.last_hit_ms = 17
	var later_attacker_ms: int = victim.last_attacker_ms
	status.tick(0.01)
	t.check(victim.last_hit_id == &"missile_power" and victim.last_hit_ms == 17,
		"burn: an old source cannot refresh past a newer attacker")
	t.check(victim.last_attacker == later_attacker
		and victim.last_attacker_ms == later_attacker_ms,
		"burn: old ticks never reclaim combat attribution")
	NetEvents.reset()
	_done(container)

func test_stale_clear_and_note_hit_isolation() -> void:
	var container := _container()
	var victim := _car(container)
	var attacker := Node2D.new()
	container.add_child(attacker)
	victim.stamp_hit(attacker, &"missile_homing")
	victim.last_attacker = null
	t.check(victim.last_hit_id == &"", "stale clear: plain attacker clear drops the hit id")

	victim.last_attacker = attacker
	victim.last_attacker_ms = 303
	var attacker_ms: int = victim.last_attacker_ms
	victim.note_hit(HitTags.ENVIRONMENT)
	t.check(victim.last_attacker == attacker,
		"note_hit: sticker-only note keeps the attacker")
	t.check(victim.last_attacker_ms == attacker_ms,
		"note_hit: sticker-only note keeps MP attribution time")
	_done(container)
