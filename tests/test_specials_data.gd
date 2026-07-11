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
	t.check(stats.special_ammo_cap == 2 and is_equal_approx(stats.special_recharge_seconds, 10.0),
		"lackey: shared pool 2 charges / 10s")

func test_twin_barrel_chooses_by_context() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var shooter := CharacterBody2D.new()
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

func test_splat_effect_def() -> void:
	var d := _def("res://data/weapons/splat_effect.tres")
	t.check(not d.stub and d.kind == 0, "splat: live projectile")
	var fx := _first_effect(d)
	t.check(fx != null and fx.kind == &"slow", "splat: slow on hit")
	t.check_approx(fx.magnitude, 0.5, "splat: half speed")
	t.check_approx(fx.duration, 3.0, "splat: 3s")

func test_blunt_blaze_def() -> void:
	var d := _def("res://data/weapons/blunt_blaze.tres")
	t.check(not d.stub and d.kind == 4, "blaze: live FLAME column")
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
	t.check_approx(d.acquisition_radius, 400.0, "taser: doubled reach (break at 800 via hold factor)")

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
