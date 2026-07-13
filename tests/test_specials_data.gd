extends RefCounted
## Guards the six signature-special WeaponDefs (no longer stubs) and the
## Toe Jam TRIGGER arm/payout logic. Kind numbers: PROJECTILE 0, BEAM 1,
## DASH 2, TRIGGER 3.

const ControllerScript := preload("res://vehicles/special_controller.gd")
const DefScript := preload("res://resources/weapon_def.gd")

var t

class DashShooter extends CharacterBody2D:
	var dash_terrain_factor := 1.0
	func terrain_factor(property: StringName, _surface: StringName = &"") -> float:
		return dash_terrain_factor if property == &"dash_damage" else 1.0

class SustainedShooter extends CharacterBody2D:
	var heading := 0.0
	func body_metrics() -> Dictionary:
		return {"half_len": 26.0}

func _init(runner) -> void:
	t = runner

func _def(path: String) -> Resource:
	return load(path)

func _first_effect(def) -> Resource:
	return def.on_hit_effects[0] if def.on_hit_effects.size() > 0 else null

func test_lackey_loadout() -> void:
	var stats: Variant = load("res://data/vehicles/lackey.tres")
	t.check(stats.special != null and stats.special.kind == 4, "lackey: main barrel is the FLAME torch")
	t.check(stats.special_b != null and stats.special_b.kind == 1, "lackey: twin barrel is the BEAM bolt")
	t.check(stats.no_mines, "lackey: never touches mines")
	t.check(stats.turret != null and stats.turret.kind == 0
		and is_equal_approx(stats.turret.damage, 45.0), "lackey: turret slings power-class shots")
	t.check(stats.special_ammo_cap == 2 and is_equal_approx(stats.special_recharge_seconds, 120.0),
		"lackey: shared pool 2 charges / 120s")

func test_sustained_vehicle_charge_economy() -> void:
	var bumper: VehicleStats = load("res://data/vehicles/bumper.tres")
	var smoky: VehicleStats = load("res://data/vehicles/smoky.tres")
	t.check(bumper.special_ammo_cap == 2 and is_equal_approx(bumper.special_recharge_seconds, 90.0),
		"sustained economy: Bumper keeps 2 charges at 90s each")
	t.check(smoky.special_ammo_cap == 3 and is_equal_approx(smoky.special_recharge_seconds, 90.0),
		"sustained economy: Smoky keeps 3 charges at 90s each")
	var file := FileAccess.open("res://assets/data/roster.json", FileAccess.READ)
	var roster: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	var authored := {}
	for car in roster.characters:
		if car.id in ["bumper", "smoky"]:
			authored[car.id] = car
	t.check(is_equal_approx(float(authored.bumper.special_recharge_seconds), 90.0)
		and is_equal_approx(float(authored.smoky.special_recharge_seconds), 90.0),
		"sustained economy: roster source and generated resources agree")

func test_twin_barrel_chooses_by_context() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var shooter := SustainedShooter.new()
	container.add_child(shooter)
	var ctrl = ControllerScript.new()
	shooter.add_child(ctrl)
	var blaze: Variant = load("res://data/weapons/blunt_blaze.tres")
	var taser: Variant = load("res://data/weapons/taser.tres")
	ctrl.set_weapon(blaze)
	ctrl.set_twin(taser)
	var prey := CharacterBody2D.new()
	prey.position = Vector2(300, 0)  # inside the taser's 400 latch
	prey.add_to_group(&"vehicles")
	container.add_child(prey)
	await t.physics_frame
	t.check(ctrl._active_def(shooter.global_position, shooter) == taser,
		"twin: latchable target at range -> the bolt")
	prey.position = Vector2(800, 0)  # out of latch reach
	await t.physics_frame
	t.check(ctrl._active_def(shooter.global_position, shooter) == blaze,
		"twin: nothing to latch -> the torch")
	t.root.remove_child(container)
	container.free()

func test_rusty_poon_def() -> void:
	var d := _def("res://data/weapons/rusty_poon.tres")
	t.check(not d.stub and d.kind == 0, "rusty 'poon: live projectile")
	var fx := _first_effect(d)
	t.check(fx != null and fx.kind == &"slow", "rusty 'poon: slow on hit")
	t.check_approx(fx.magnitude, 0.5, "rusty 'poon: half speed")
	t.check_approx(fx.duration, 3.0, "rusty 'poon: 3s")

func test_chill_out_disarm_duration() -> void:
	var d := _def("res://data/weapons/chill_out.tres")
	var fx := _first_effect(d)
	t.check_approx(d.damage, 0.0, "chill out: peace sign deals no damage")
	t.check(fx != null and fx.kind == &"disarm", "chill out: hit applies disarm")
	t.check_approx(fx.duration, 5.0, "chill out: guns return after five seconds")

func test_blunt_blaze_def() -> void:
	var d := _def("res://data/weapons/blunt_blaze.tres")
	t.check(not d.stub and d.kind == 4, "blaze: live FLAME column")
	t.check_approx(d.active_duration, 2.0, "blaze: two-second active burst")
	t.check_approx(d.cooldown, 15.0, "blaze: fifteen-second post-fire lockout")
	t.check_approx(d.damage, 34.0, "blaze: middle-ground 34 dps")
	var fx := _first_effect(d)
	t.check(fx != null and fx.kind == &"burn", "blaze: burn on hit")
	t.check_approx(fx.duration, 10.0, "blaze: 10s ignite")

func test_molotov_def() -> void:
	var d := _def("res://data/weapons/molotov.tres")
	var fx := _first_effect(d)
	t.check(fx != null and fx.kind == &"burn", "molotov: burn on hit")
	t.check_approx(fx.duration, 15.0, "molotov: lore 15s burn")

func test_red_glare_def() -> void:
	var d := _def("res://data/weapons/red_glare.tres")
	t.check(not d.stub and d.kind == 0, "red glare: live projectile volley")
	t.check(d.pellets == 4 and d.bursts == 3, "red glare: 3 waves x 4 rockets")
	t.check_approx(d.spread_deg, 10.0, "red glare: shotgun-choke cone")

func test_taser_def() -> void:
	var d := _def("res://data/weapons/taser.tres")
	t.check(not d.stub and d.kind == 1, "taser: live BEAM")
	t.check_approx(d.active_duration, 2.0, "taser: two-second active burst")
	t.check_approx(d.cooldown, 15.0, "taser: fifteen-second post-fire lockout")
	t.check_approx(d.damage, 18.0, "taser: middle-ground 18 dps")
	t.check_approx(d.acquisition_radius, 400.0, "taser: doubled reach (break at 800 via hold factor)")

func test_sustained_cooldown_starts_after_flame_finishes() -> void:
	var shooter := SustainedShooter.new()
	t.root.add_child(shooter)
	var sc = ControllerScript.new()
	shooter.add_child(sc)
	var blaze: WeaponDef = load("res://data/weapons/blunt_blaze.tres")
	sc.set_weapon(blaze)
	t.check(sc.activate(true, Vector2.ZERO, Vector2.RIGHT, shooter),
		"sustained cooldown: flame activation succeeds")
	sc._physics_process(blaze.active_duration - 0.2)
	t.check_approx(sc.sustained_cooldown_remaining(), 0.0,
		"sustained cooldown: firing duration pays none of the lockout")
	sc._physics_process(0.21)
	t.check_approx(sc.sustained_cooldown_remaining(), 15.0,
		"sustained cooldown: full clock arms when flame ends")
	t.check(not sc.activate(true, Vector2.ZERO, Vector2.RIGHT, shooter),
		"sustained cooldown: immediate repeat is rejected")
	sc._physics_process(14.9)
	t.check(not sc.activate(true, Vector2.ZERO, Vector2.RIGHT, shooter),
		"sustained cooldown: repeat stays locked before fifteen seconds")
	sc._physics_process(0.1)
	t.check(sc.activate(true, Vector2.ZERO, Vector2.RIGHT, shooter),
		"sustained cooldown: repeat opens exactly after fifteen seconds")
	t.root.remove_child(shooter)
	shooter.free()

func test_twin_sustained_barrels_share_early_end_lockout() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container
	var shooter := CharacterBody2D.new()
	container.add_child(shooter)
	var sc = ControllerScript.new()
	shooter.add_child(sc)
	var blaze: WeaponDef = load("res://data/weapons/blunt_blaze.tres")
	var taser: WeaponDef = load("res://data/weapons/taser.tres")
	sc.set_weapon(blaze)
	sc.set_twin(taser)
	var prey := CharacterBody2D.new()
	prey.position = Vector2(300, 0)
	prey.add_to_group(&"vehicles")
	container.add_child(prey)
	t.check(sc.activate(true, shooter.global_position, Vector2.RIGHT, shooter),
		"sustained cooldown: Lackey twin chooses and starts the beam")
	t.check_approx(sc._beam_t, 2.0,
		"sustained cooldown: data-authored beam is a true two-second burst")
	sc._end_beam()  # LoS/range/target loss all converge on this early-end seam
	t.check_approx(sc.sustained_cooldown_remaining(), 15.0,
		"sustained cooldown: interrupted beam starts a fresh full clock")
	prey.position = Vector2(900, 0)  # context now chooses the flame barrel
	t.check(not sc.activate(true, shooter.global_position, Vector2.RIGHT, shooter),
		"sustained cooldown: ending one twin locks the other")
	sc._physics_process(15.0)
	t.check(sc.activate(true, shooter.global_position, Vector2.RIGHT, shooter),
		"sustained cooldown: shared twin gate reopens after fifteen seconds")
	t.current_scene = null
	t.root.remove_child(container)
	container.free()

func test_leap_def() -> void:
	var d := _def("res://data/weapons/leap.tres")
	t.check(not d.stub and d.kind == 2, "leap: live DASH")

func test_dash_snapshots_terrain_damage_until_impact() -> void:
	var shooter := DashShooter.new()
	shooter.dash_terrain_factor = 1.15
	t.root.add_child(shooter)
	var sc = ControllerScript.new()
	shooter.add_child(sc)
	var def = DefScript.new()
	def.kind = 2  # DASH
	sc.set_weapon(def)
	t.check(sc.activate(true, Vector2.ZERO, Vector2.RIGHT, shooter),
		"dash terrain: activation consumes on configured surface")
	t.check_approx(sc.dash_damage_multiplier(), 1.15,
		"dash terrain: activation snapshots the surface factor")
	shooter.dash_terrain_factor = 1.0
	t.check_approx(sc.dash_damage_multiplier(), 1.15,
		"dash terrain: crossing surfaces does not re-price a live dash")
	t.check_approx(sc.take_dash_ram_multiplier(), 1.15,
		"dash terrain: first landed ram receives the snapshot")
	t.check_approx(sc.take_dash_ram_multiplier(), 1.0,
		"dash terrain: snapshot pays out only once")
	t.root.remove_child(shooter)
	shooter.free()

func test_dash_terrain_snapshot_resets_on_miss_and_cancel() -> void:
	var shooter := DashShooter.new()
	shooter.dash_terrain_factor = 1.15
	t.root.add_child(shooter)
	var sc = ControllerScript.new()
	shooter.add_child(sc)
	var def = DefScript.new()
	def.kind = 2  # DASH
	sc.set_weapon(def)
	sc.activate(true, Vector2.ZERO, Vector2.RIGHT, shooter)
	sc._physics_process(ControllerScript.DASH_DURATION + 0.1)
	t.check(not sc.is_dashing() and is_equal_approx(sc.dash_damage_multiplier(), 1.0),
		"dash terrain: a missed dash expires back to neutral")
	sc.activate(true, Vector2.ZERO, Vector2.RIGHT, shooter)
	sc.cancel_dash()
	t.check(not sc.is_dashing() and is_equal_approx(sc.take_dash_ram_multiplier(), 1.0),
		"dash terrain: cancellation clears the snapshot")
	t.root.remove_child(shooter)
	shooter.free()

func test_toe_jam_def() -> void:
	var d := _def("res://data/weapons/toe_jam.tres")
	t.check(not d.stub and d.kind == 3, "toe jam: live TRIGGER")
	t.check_approx(d.damage, 60.0, "toe jam: 60 charged hit")

func test_trigger_arms_once_and_pays_once() -> void:
	var sc = ControllerScript.new()
	var def = DefScript.new()
	def.kind = 3  # TRIGGER
	def.damage = 60.0
	sc.set_weapon(def)
	var shooter := Node2D.new()
	t.check(sc.activate(true, Vector2.ZERO, Vector2.RIGHT, shooter), "trigger: arming consumes")
	t.check(not sc.activate(true, Vector2.ZERO, Vector2.RIGHT, shooter), "trigger: can't double-arm")
	t.check_approx(sc.take_armed_hit(), 60.0, "trigger: charged hit pays out")
	t.check_approx(sc.take_armed_hit(), 0.0, "trigger: pays out exactly once")
	t.check(sc.activate(true, Vector2.ZERO, Vector2.RIGHT, shooter), "trigger: re-arms after payout")
	shooter.free()
	sc.free()

func test_trigger_window_expires_unspent() -> void:
	var sc = ControllerScript.new()
	var def = DefScript.new()
	def.kind = 3  # TRIGGER
	def.damage = 60.0
	sc.set_weapon(def)
	var shooter := Node2D.new()
	sc.activate(true, Vector2.ZERO, Vector2.RIGHT, shooter)
	sc._physics_process(ControllerScript.TRIGGER_WINDOW * 0.5)
	t.check_approx(sc.take_armed_hit(), 60.0, "trigger window: still armed mid-window")
	sc.activate(true, Vector2.ZERO, Vector2.RIGHT, shooter)
	sc._physics_process(ControllerScript.TRIGGER_WINDOW + 0.5)
	t.check_approx(sc.take_armed_hit(), 0.0, "trigger window: expired charge pays nothing")
	t.check(sc.activate(true, Vector2.ZERO, Vector2.RIGHT, shooter), "trigger window: can re-arm after expiry")
	shooter.free()
	sc.free()
