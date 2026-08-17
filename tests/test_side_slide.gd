extends RefCounted
## The side slam: a handbrake-born lateral slide is a one-way wrecking ball —
## the victim takes the (boosted) ram bill, the slider takes nothing back.
## Locks the is_side_sliding truth table (slip window, speed floor, handbrake
## recency — the icy-AI exclusion) and both halves of the one-way bill.
## Driven by run_tests.gd; fixture idioms mirror test_dash_ram.gd.

const VehicleScene := preload("res://vehicles/vehicle.tscn")
const StubDriver := preload("res://tests/stub_driver.gd")

var t

func _init(runner) -> void:
	t = runner

func _car(pos: Vector2) -> Node:
	var car = VehicleScene.instantiate()
	car.faction = &"enemies"  # never shadow player-group lookups in fixtures
	car.stats = (load("res://data/vehicles/ghost.tres") as VehicleStats).duplicate()
	car.position = pos
	t.root.add_child(car)
	return car

func _done(cars: Array) -> void:
	for car in cars:
		t.root.remove_child(car)
		car.free()

func test_side_slide_truth_table() -> void:
	var car = _car(Vector2.ZERO)
	car.heading = 0.0
	car._hb_recent_t = 1.0
	car.velocity = Vector2(0, 400)  # pure lateral to the +X nose
	t.check(car.is_side_sliding(), "slide: recent brake + fast + sideways = sliding")
	car._hb_recent_t = 0.0
	t.check(not car.is_side_sliding(),
		"slide: high slip WITHOUT the brake never counts (the icy-AI exclusion)")
	car._hb_recent_t = 1.0
	car.velocity = Vector2(0, 200)
	t.check(not car.is_side_sliding(), "slide: below the speed floor is a shuffle")
	car.velocity = Vector2(400, 0)
	t.check(not car.is_side_sliding(), "slide: nose-aligned travel is just driving")
	car.velocity = Vector2(400, 400) * 0.707  # 45 deg slip — under the ~53 deg floor
	t.check(not car.is_side_sliding(), "slide: 45-degree drift is not yet a slam")
	car.velocity = Vector2(0.35, 0.94).normalized() * 400.0  # ~70 deg slip
	t.check(car.is_side_sliding(), "slide: deep slip past the floor reads as a slam")
	_done([car])

## The grace window rides real handbrake intent through the controller: primed
## while held, alive shortly after release, gone past SLIDE_GRACE.
func test_grace_window_follows_the_brake() -> void:
	var car = _car(Vector2.ZERO)
	var driver = StubDriver.new()
	car.set_driver(driver)  # set_driver parents it AND re-points the cached ref
	driver.intent = {"throttle": 0.0, "steer": 0.0, "handbrake": true}
	car.velocity = Vector2(0, 400)
	car._physics_process(1.0 / 60.0)
	t.check(car._hb_recent_t > 0.0, "grace: a held handbrake primes the window")
	driver.intent = {"throttle": 0.0, "steer": 0.0, "handbrake": false}
	for i in 18:  # 0.3s after release
		car._physics_process(1.0 / 60.0)
	t.check(car._hb_recent_t > 0.0, "grace: the window survives a fresh release")
	for i in 30:  # well past SLIDE_GRACE
		car._physics_process(1.0 / 60.0)
	t.check(car._hb_recent_t <= 0.0, "grace: the window expires")
	_done([car])

## Mirrors test_dash_ram: the victim's own ram loop never bills a side-slider,
## with a control leg proving the same rig bills when the slide is off.
func test_victim_never_bills_a_slider() -> void:
	var slider = _car(Vector2.ZERO)
	var victim = _car(Vector2(80, 0))
	await t.physics_frame  # space sync
	var slider_health = slider.get_node("Health")
	# Pin the slide state; the slider itself is never stepped.
	slider.heading = 0.0
	slider.velocity = Vector2(0, 400)
	slider._hb_recent_t = 1.0
	var contact := false
	for i in 30:
		victim.velocity = Vector2(-900, 0)
		victim._ram_cd = 0.0
		victim._physics_process(1.0 / 60.0)
		if victim.get_slide_collision_count() > 0:
			contact = true
			break
	t.check(contact, "side slam rig: the victim reaches the slider")
	t.check(slider_health.hp == slider_health.max_hp,
		"side slam: the slider's broadside costs it nothing (hp %.1f)" % slider_health.hp)
	# Control leg: slide off — the same ram DOES bill.
	slider._hb_recent_t = 0.0
	slider.velocity = Vector2.ZERO
	slider.position = Vector2.ZERO
	victim.position = Vector2(80, 0)
	var billed := false
	for i in 30:
		victim.velocity = Vector2(-900, 0)
		victim._ram_cd = 0.0
		victim._physics_process(1.0 / 60.0)
		if slider_health.hp < slider_health.max_hp:
			billed = true
			break
	t.check(billed, "control: with the slide off, the same ram bills the car")
	_done([slider, victim])

## The slider's own bill lands boosted: same entry velocity, side-on vs
## nose-on. (The legs clamp differently — nose-on pays the top-speed cap,
## the slide doesn't — so the check is a direction band, not an exact ratio.)
func test_slider_bill_lands_with_the_bonus() -> void:
	var slam_dmg := _slam_damage(true)
	var plain_dmg := _slam_damage(false)
	t.check(slam_dmg > 0.0 and plain_dmg > 0.0, "slam rig: both legs land a bill")
	t.check(slam_dmg > plain_dmg * 1.3,
		"slam: the broadside out-hits the plain ram (%.1f vs %.1f)" % [slam_dmg, plain_dmg])
	_done([])

func _slam_damage(sliding: bool) -> float:
	var attacker = _car(Vector2.ZERO)
	var victim = _car(Vector2(-80, 0))
	var victim_health = victim.get_node("Health")
	var hp0: float = victim_health.hp
	# Same travel both legs (-X at 900); the slam leg turns the nose 90 deg off
	# travel and primes the brake window, the plain leg drives nose-first.
	attacker.heading = PI / 2.0 if sliding else PI
	attacker._hb_recent_t = 1.0 if sliding else 0.0
	for i in 30:
		attacker.velocity = Vector2(-900, 0)
		attacker._ram_cd = 0.0
		if sliding:
			attacker._hb_recent_t = 1.0  # re-pin: no controller runs to decay it
		attacker._physics_process(1.0 / 60.0)
		if victim_health.hp < hp0:
			break
	var dealt: float = hp0 - victim_health.hp
	_done([attacker, victim])
	return dealt
