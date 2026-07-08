extends RefCounted
## Guards the six signature-special WeaponDefs (no longer stubs) and the
## Toe Jam TRIGGER arm/payout logic. Kind numbers: PROJECTILE 0, BEAM 1,
## DASH 2, TRIGGER 3.

const ControllerScript := preload("res://vehicles/special_controller.gd")
const DefScript := preload("res://resources/weapon_def.gd")

var t

func _init(runner) -> void:
	t = runner

func _def(path: String) -> Resource:
	return load(path)

func _first_effect(def) -> Resource:
	return def.on_hit_effects[0] if def.on_hit_effects.size() > 0 else null

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
