extends RefCounted
## Leap's ram bill is ONE-WAY: a victim's own ram loop never prices the
## body-check back onto a mid-dash caster, and connecting grants the caster a
## same-frame shield (Status syncs invuln a tick late — the bridge closes that
## one-frame billing hole). Driven by run_tests.gd.

const VehicleScene := preload("res://vehicles/vehicle.tscn")

var t

func _init(runner) -> void:
	t = runner

## Stats authored BEFORE add_child (the level_loader pattern); enemies faction
## so fixtures never shadow player-group lookups.
func _car(pos: Vector2) -> Node:
	var car = VehicleScene.instantiate()
	car.faction = &"enemies"
	car.stats = (load("res://data/vehicles/ghost.tres") as VehicleStats).duplicate()
	car.position = pos
	t.root.add_child(car)
	return car

func _done(cars: Array) -> void:
	for car in cars:
		t.root.remove_child(car)
		car.free()

## Rams the victim into the caster while the caster is mid-dash: no bill. Then
## the control leg with the dash off proves the same rig DOES bill — the first
## check can't pass vacuously.
func test_victim_never_bills_a_dasher() -> void:
	var caster = _car(Vector2.ZERO)
	var victim = _car(Vector2(80, 0))
	await t.physics_frame  # space sync after add; dash state not pinned yet
	var ctrl = caster.get_node("SpecialController")
	var caster_health = caster.get_node("Health")
	ctrl._dash_t = 5.0  # pin mid-dash; only the victim is stepped manually
	var contact := false
	for i in 30:
		victim.velocity = Vector2(-900, 0)
		victim._ram_cd = 0.0
		victim._physics_process(1.0 / 60.0)
		if victim.get_slide_collision_count() > 0:
			contact = true
			break
	t.check(contact, "dash ram rig: the victim reaches the caster")
	t.check(caster_health.hp == caster_health.max_hp,
		"mid-dash: the victim's ram loop bills the caster nothing (hp %.1f)" % caster_health.hp)
	# Control leg: same rig, dash off — the bill lands (AI-on-AI governor and
	# all), proving the skip above is what protected the caster.
	ctrl._dash_t = 0.0
	caster.position = Vector2.ZERO
	victim.position = Vector2(80, 0)
	var billed := false
	for i in 30:
		victim.velocity = Vector2(-900, 0)
		victim._ram_cd = 0.0
		victim._physics_process(1.0 / 60.0)
		if caster_health.hp < caster_health.max_hp:
			billed = true
			break
	t.check(billed, "control: with the dash off, the same ram DOES bill the caster")
	_done([caster, victim])

## The connect: caster's own loop bills the victim, the dash tick slows the
## victim and shields the caster THE SAME FRAME (no Status tick in between),
## and the victim's immediate return ram bills nothing.
func test_dash_connect_grants_same_frame_invuln() -> void:
	var caster = _car(Vector2.ZERO)
	var victim = _car(Vector2(60, 0))
	await t.physics_frame
	var ctrl = caster.get_node("SpecialController")
	ctrl._dash_t = 5.0
	ctrl._dash_dir = Vector2.RIGHT
	var victim_health = victim.get_node("Health")
	var hp0: float = victim_health.hp
	for i in 30:
		caster.velocity = Vector2(1400, 0)
		caster._ram_cd = 0.0
		caster._physics_process(1.0 / 60.0)
		if caster.get_slide_collision_count() > 0:
			break
	t.check(victim_health.hp < hp0, "dash connect: the victim takes the ram bill")
	ctrl._dash_tick(1.0 / 60.0)  # the connect frame, driven directly
	var caster_health = caster.get_node("Health")
	t.check(caster_health.invulnerable,
		"dash connect: caster shield lands same-frame, before any Status tick")
	t.check(victim.get_node("Status").has_effect(&"slow"), "dash connect: victim slowed")
	t.check(not ctrl.is_dashing(), "dash connect: the dash ends on contact")
	# The post-connect hole: victim rams back before its next Status tick would
	# ever have synced a bare invuln — the bridge already blocks the bill.
	var chp: float = caster_health.hp
	victim.velocity = Vector2(-900, 0)
	victim._ram_cd = 0.0
	victim._physics_process(1.0 / 60.0)
	t.check(caster_health.hp == chp,
		"post-connect frame: the victim's return ram bills nothing")
	await t.physics_frame  # flush _end_dash's set_deferred mask against live nodes
	_done([caster, victim])
