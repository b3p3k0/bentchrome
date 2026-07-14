class_name VehicleLoadout
extends RefCounted
## Mods-garage composition seam (backend only — the garage UI comes later).
## compose() folds an ordered mod list over a base VehicleStats and returns a
## fresh resource; the base (a shipped .tres singleton) is never mutated.
## Apply the result between runs via Vehicle.set_stats; mid-run feel tweaks go
## through the Goliath pattern (StatCurves.apply(stats, ctrl, null)) instead —
## set_stats repaints and resets HP.
##
## Mod data shape (see docs/garage_seams.md):
## {
##   "id": "stage1_headers",
##   "stat_deltas": {"acceleration": +2, "handling": -1},  # 1-20 scale, clamped;
##                                                         # tradeoffs = negative deltas
##   "terrain_profile": Array[VehicleTerrainModifier],     # tire/drivetrain swap —
##                                                         # wholesale table replace
##   "capabilities": {"burn_taken": 0.8, "special_ammo_cap": 3},
##   "controller_overrides": {"boost_top_factor": 1.6},    # post-curve knob layer
##   "reserved": {...}  # radar_range_scale / mg_heat_scale / lock_time_scale /
##                      # detectability — electronics & weapon-systems seams, unwired
## }

const STAT_FIELDS := ["acceleration", "top_speed", "handling", "armor",
	"special_power", "mass", "launch"]
const CAPABILITY_FIELDS := ["burn_taken", "no_mines", "special", "special_b",
	"special_ammo_cap", "special_recharge_seconds"]

static func compose(base: VehicleStats, mods: Array) -> VehicleStats:
	var out: VehicleStats = base.duplicate()
	# duplicate() shares container properties — give the copy its own before
	# any mod writes into them.
	out.handling_overrides = base.handling_overrides.duplicate()
	out.terrain_modifiers = base.terrain_modifiers.duplicate()
	for mod in mods:
		if typeof(mod) != TYPE_DICTIONARY:
			continue
		var deltas: Dictionary = mod.get("stat_deltas", {})
		for stat_v in deltas:
			var stat := String(stat_v)
			if stat in STAT_FIELDS:
				var lo := 0 if stat == "launch" else 1  # launch 0 = mass-derived sentinel
				out.set(stat, clampi(int(out.get(stat)) + int(deltas[stat_v]), lo, StatCurves.SCALE_MAX))
		if mod.has("terrain_profile"):
			var swap: Array[VehicleTerrainModifier] = []
			for m in mod["terrain_profile"]:
				if m is VehicleTerrainModifier:
					swap.append(m)
			out.terrain_modifiers = swap
		var caps: Dictionary = mod.get("capabilities", {})
		for field_v in caps:
			if String(field_v) in CAPABILITY_FIELDS:
				out.set(String(field_v), caps[field_v])
		var knobs: Dictionary = mod.get("controller_overrides", {})
		for knob_v in knobs:
			out.handling_overrides[knob_v] = knobs[knob_v]
	return out
