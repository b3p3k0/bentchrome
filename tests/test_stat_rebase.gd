extends RefCounted
## Golden feel lock for the fleet. GOLDEN hard-codes every ride's AUTHORED
## design ints (1-20 scale + launch); each check asserts StatCurves applied
## to the LIVE .tres reproduces the curve tables EXACTLY (==, not approx) —
## so silent roster/.tres/curve drift fails loudly. Edit GOLDEN only as the
## deliberate re-pin of an intentional tuning change (docs/car_authoring.md).
## History: pinned at the 2026-07-14 feel-frozen 1-20 rebase (bit-exact to
## the legacy 1-10 ramp), re-pinned 2026-07-15 for the fleet balance pass
## (launch axis debut; anchors cyclone/hornet + bosses/buzzards unmoved),
## re-pinned 2026-07-16 for the car-tuner canonization (playtested stats
## folded into roster truth; bosses/buzzards still unmoved).

const CtrlScript := preload("res://vehicles/driving_controller.gd")
const Curves := preload("res://resources/stat_curves.gd")
const Importer := preload("res://tools/import_roster.gd")

## file basename -> [acceleration, top_speed, handling, armor, mass, launch]
## (authored 1-20 ints; launch 0 = mass-derived sentinel).
const GOLDEN := {
	"bumper": [10, 11, 9, 13, 11, 11],
	"buzz_bike": [17, 15, 15, 1, 1, 0],
	"buzz_sedan": [9, 11, 7, 3, 7, 0],
	"buzz_technical": [5, 3, 5, 5, 11, 0],
	"coldfront": [9, 10, 6, 14, 13, 11],
	"cricket": [13, 15, 6, 7, 4, 3],
	"cyclone": [17, 19, 14, 4, 4, 3],
	"ghost": [15, 17, 13, 5, 6, 11],
	"goliath": [5, 7, 3, 19, 19, 0],
	"goliath_ph2": [9, 11, 7, 7, 15, 0],
	"hammertoe": [12, 9, 5, 13, 15, 17],
	"hornet": [11, 11, 11, 11, 9, 3],
	"hubcap": [15, 7, 17, 9, 6, 3],
	"kandykane": [10, 11, 5, 14, 13, 5],
	"lackey": [13, 11, 11, 19, 17, 0],
	"lovebug": [10, 9, 11, 7, 7, 3],
	"mrghastly": [14, 17, 13, 3, 2, 15],
	"razorback": [9, 12, 8, 15, 13, 15],
	"smoky": [11, 13, 9, 11, 12, 13],
	"splatkat": [12, 15, 12, 9, 11, 3],
}

var t

class HealthStub:
	var max_hp := 0.0
	var hp := 0.0

func _init(runner) -> void:
	t = runner

## The pre-rebase StatCurves ramp, frozen here as the reference.
static func _legacy(v: int, lo: float, hi: float) -> float:
	return lerpf(lo, hi, clampf((float(v) - 1.0) / 9.0, 0.0, 1.0))

func test_golden_feel_lock() -> void:
	for file in GOLDEN:
		var g: Array = GOLDEN[file]
		var stats = load("res://data/vehicles/%s.tres" % file)
		t.check(stats != null, "fleet golden: %s.tres loads" % file)
		if stats == null:
			continue
		var ctrl = CtrlScript.new()
		var health := HealthStub.new()
		Curves.apply(stats, ctrl, health)
		t.check(ctrl.acceleration == Curves._slot(Curves.ACCELERATION, g[0]),
			"fleet golden %s: acceleration %s == slot %d" % [file, ctrl.acceleration, g[0]])
		t.check(ctrl.max_speed == Curves._slot(Curves.TOP_SPEED, g[1]),
			"fleet golden %s: max_speed %s == slot %d" % [file, ctrl.max_speed, g[1]])
		t.check(ctrl.turn_rate_deg == Curves._slot(Curves.TURN_RATE, g[2]),
			"fleet golden %s: turn_rate %s == slot %d" % [file, ctrl.turn_rate_deg, g[2]])
		t.check(ctrl.lateral_grip == Curves._slot(Curves.GRIP, g[2]),
			"fleet golden %s: grip %s == slot %d" % [file, ctrl.lateral_grip, g[2]])
		t.check(health.max_hp == Curves._slot(Curves.HP, g[3]),
			"fleet golden %s: hp %s == slot %d" % [file, health.max_hp, g[3]])
		t.check(health.hp == health.max_hp, "fleet golden %s: hp filled to max" % file)
		t.check(ctrl.mass == (float(g[4]) + 1.0) / 2.0,
			"fleet golden %s: engine mass %s == authored %d" % [file, ctrl.mass, g[4]])
		var want_launch: float = Curves._slot(Curves.LAUNCH, g[5]) if g[5] >= 1 else 0.0
		t.check(ctrl.launch_factor == want_launch,
			"fleet golden %s: launch_factor %s == slot %d" % [file, ctrl.launch_factor, g[5]])
		ctrl.free()

## --- The 1-20 scale flip (rebase step 4) -----------------------------------

class DriveStub:
	var heading := 0.0
	var velocity := Vector2.ZERO
	var current_terrain: StringName = &"road"
	func get_speed_scale() -> float:
		return 1.0

## Seconds of full throttle from rest until frac of the controller's own top.
func _time_to_frac(c, frac: float) -> float:
	var stub := DriveStub.new()
	var intent := {"throttle": 1.0, "steer": 0.0}
	var elapsed := 0.0
	while stub.velocity.dot(Vector2.RIGHT.rotated(stub.heading)) < c.max_speed * frac \
			and elapsed < 20.0:
		c.apply(stub, intent, 1.0 / 60.0)
		elapsed += 1.0 / 60.0
	return elapsed

## Locks the migration math itself: every odd slot sits bit-exactly on the
## legacy 1-10 ramp — the invariant the golden lock above rides on.
func test_odd_slots_reproduce_legacy_ramp() -> void:
	var axes := {
		"TOP_SPEED": [Curves.TOP_SPEED, 360.0, 640.0],
		"ACCELERATION": [Curves.ACCELERATION, 80.0, 365.0],
		"TURN_RATE": [Curves.TURN_RATE, 130.0, 250.0],
		"GRIP": [Curves.GRIP, 4.5, 10.0],
		"HP": [Curves.HP, 70.0, 180.0],
	}
	for axis_name in axes:
		var table: PackedFloat64Array = axes[axis_name][0]
		var exact := true
		for v in range(1, 11):
			if table[2 * v - 1] != _legacy(v, axes[axis_name][1], axes[axis_name][2]):
				exact = false
		t.check(exact, "scale flip: %s odd slots == legacy ramp, bit-exact" % axis_name)

func test_tables_monotone_with_real_headroom() -> void:
	for entry in [["TOP_SPEED", Curves.TOP_SPEED], ["ACCELERATION", Curves.ACCELERATION],
			["TURN_RATE", Curves.TURN_RATE], ["GRIP", Curves.GRIP], ["HP", Curves.HP],
			["LAUNCH", Curves.LAUNCH]]:
		var table: PackedFloat64Array = entry[1]
		var ascending := true
		for s in range(2, Curves.SCALE_MAX + 1):
			if table[s] <= table[s - 1]:
				ascending = false
		t.check(ascending, "scale flip: %s strictly ascending across 1-20" % entry[0])
	t.check(Curves.TOP_SPEED[20] > Curves.TOP_SPEED[19], "scale flip: slot 20 headroom is real")

func test_mph_anchors() -> void:
	var mph: float = preload("res://ui/hud.gd").MPH_PER_PXS
	t.check(mph == 0.15, "mph anchor: hud constant is 0.15")
	t.check(Curves.TOP_SPEED[1] * mph == 54.0, "mph anchor: top-speed slot 1 = 54 mph")
	t.check(Curves.TOP_SPEED[19] * mph == 96.0, "mph anchor: top-speed slot 19 = 96 mph")

func test_launch_stat_seam() -> void:
	var stats := VehicleStats.new()
	stats.mass = 9  # engine mass 5
	var ctrl = CtrlScript.new()
	Curves.apply(stats, ctrl, null)
	t.check(ctrl.launch_factor == 0.0, "launch: authored 0 keeps the mass-derived sentinel")
	stats.launch = 19
	Curves.apply(stats, ctrl, null)
	t.check(ctrl.launch_factor == 1.4, "launch: slot 19 = 1.4, the old mass-1 shove")
	# Derived-equivalence for the tuning pass: authoring slot 21-2m reproduces
	# engine mass m's legacy shove (approx — different fp op order is fine here;
	# migrated cars keep the sentinel path, which is exact by construction).
	for m in range(1, 11):
		t.check(is_equal_approx(Curves.LAUNCH[21 - 2 * m], lerpf(1.4, 0.7, (float(m) - 1.0) / 9.0)),
			"launch: slot %d ~= engine mass %d's derived shove" % [21 - 2 * m, m])
	ctrl.free()
	var quick = CtrlScript.new()
	quick.launch_factor = 1.4
	quick.mass = 8.0
	var weak = CtrlScript.new()
	weak.launch_factor = 0.7
	weak.mass = 8.0
	t.check(_time_to_frac(quick, 0.3) < _time_to_frac(weak, 0.3),
		"launch: high launch_factor wins the standing start at equal mass")
	quick.free()
	weak.free()

## --- Mod composition seam (rebase step 5) ----------------------------------

func test_loadout_compose() -> void:
	var Loadout := preload("res://resources/vehicle_loadout.gd")
	var base = load("res://data/vehicles/razorback.tres")
	var base_armor: int = base.armor
	var base_surfaces: int = base.terrain_modifiers.size()
	var knobby := VehicleTerrainModifier.new()
	knobby.terrain = &"dirt"
	knobby.accel = 1.3
	var modded = Loadout.compose(base, [
		{"id": "plating", "stat_deltas": {"armor": 99, "launch": 3, "bogus": 5}},
		{"id": "tires", "terrain_profile": [knobby]},
		{"id": "coolant", "capabilities": {"burn_taken": 0.8, "bogus": 1.0},
			"controller_overrides": {"boost_top_factor": 1.6}},
	])
	t.check(modded.armor == 20, "loadout: stat deltas clamp to the 1-20 ceiling")
	t.check(modded.launch == 18, "loadout: launch delta adds on the authored value (15+3)")
	t.check(modded.terrain_modifiers.size() == 1
		and modded.terrain_modifiers[0].terrain == &"dirt",
		"loadout: terrain_profile swap replaces the whole table")
	t.check(is_equal_approx(modded.burn_taken, 0.8), "loadout: capability grant lands")
	t.check(is_equal_approx(float(modded.handling_overrides.get("boost_top_factor", 0.0)), 1.6),
		"loadout: controller override joins handling_overrides")
	t.check(Loadout.compose(base, [{"stat_deltas": {"armor": -99}}]).armor == 1,
		"loadout: negative deltas floor at 1")
	t.check(base.armor == base_armor and base.terrain_modifiers.size() == base_surfaces
		and base.handling_overrides.is_empty() and is_equal_approx(base.burn_taken, 1.0),
		"loadout: the base resource is never mutated")

## --- Terrain profile extraction (rebase step 3) ---------------------------

func test_terrain_profile_merge() -> void:
	var profiles := {"knobby": {"dirt": {"accel": 1.2, "grip": 1.1}}}
	var car := {"terrain_profile": "knobby"}
	var merged := Importer.merged_terrain(car, profiles)
	t.check(merged.has("dirt") and is_equal_approx(float(merged["dirt"]["accel"]), 1.2),
		"terrain merge: named profile resolves")
	car = {"terrain_profile": "knobby",
		"terrain_modifiers": {"dirt": {"accel": 1.5}, "mud": {"top": 0.8}}}
	merged = Importer.merged_terrain(car, profiles)
	t.check(is_equal_approx(float(merged["dirt"]["accel"]), 1.5),
		"terrain merge: inline overlay wins per property")
	t.check(is_equal_approx(float(merged["dirt"]["grip"]), 1.1),
		"terrain merge: profile fills properties the overlay omits")
	t.check(merged.has("mud") and is_equal_approx(float(merged["mud"]["top"]), 0.8),
		"terrain merge: overlay-only surfaces join the table")
	t.check(is_equal_approx(float(profiles["knobby"]["dirt"]["accel"]), 1.2),
		"terrain merge: the shared profile is never mutated")

func test_terrain_profile_validation() -> void:
	var roster := {
		"terrain_profiles": {"bad": {"lava": {"accel": 1.2}}},
		"characters": [{"id": "wanderer", "terrain_profile": "nope"}],
	}
	var errors := Importer.roster_errors(roster)
	var saw_bad_surface := false
	var saw_dead_ref := false
	for e in errors:
		if String(e).contains("terrain_profiles.bad") and String(e).contains("lava"):
			saw_bad_surface = true
		if String(e).contains("terrain_profile 'nope'"):
			saw_dead_ref = true
	t.check(saw_bad_surface, "terrain profiles: unknown surface in a profile fails import")
	t.check(saw_dead_ref, "terrain profiles: dangling profile reference fails import")

## Smoky and razorback share the awd_utility profile; the 2026-07 balance
## pass gave razorback an inline dirt/mud ACCEL overlay (military 4WD
## out-grunts the cop SUV). Everything else must stay element-equal — this
## is the overlay seam's live contract.
func test_awd_utility_shared_by_smoky_and_razorback() -> void:
	var smoky = load("res://data/vehicles/smoky.tres")
	var razor = load("res://data/vehicles/razorback.tres")
	t.check(smoky.terrain_modifiers.size() == razor.terrain_modifiers.size()
		and smoky.terrain_modifiers.size() > 0, "awd_utility: both carry the same surface count")
	for m in smoky.terrain_modifiers:
		var overlaid: bool = m.terrain in [&"dirt", &"mud"]
		var factor_match := true
		for prop in [&"accel", &"top", &"grip", &"steer", &"dash_damage"]:
			if prop == &"accel" and overlaid:
				continue
			if razor.terrain_factor(m.terrain, prop) != m.factor(prop):
				factor_match = false
		t.check(factor_match, "awd_utility: %s shared factors element-equal across smoky/razorback" % m.terrain)
		if overlaid:
			t.check(razor.terrain_factor(m.terrain, &"accel") > m.factor(&"accel"),
				"awd_utility: razorback's %s accel overlay out-grunts smoky" % m.terrain)
