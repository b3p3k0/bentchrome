extends RefCounted
## Garage catalog contract: the shipped JSON validates clean, every item
## composes through VehicleLoadout on a real car without mutating the base,
## stage chains resolve, and the validator actually rejects the mistakes it
## exists to catch.

const Catalog := preload("res://ui/garage/garage_catalog.gd")

var t

func _init(runner) -> void:
	t = runner

func test_shipped_catalog_validates_and_loads() -> void:
	var items := Catalog.load_catalog()
	t.check(items.size() >= 10, "catalog: shipped file loads (%d items)" % items.size())
	var ids := {}
	for item in items:
		ids[item.id] = item
	t.check(ids.has("engine_stage1") and ids.has("armor_plating"),
		"catalog: expected staples present")
	t.check(String(ids["engine_stage2"].requires) == "engine_stage1"
		and String(ids["engine_stage3"].requires) == "engine_stage2",
		"catalog: engine chain links stage by stage")
	t.check(String(ids["tires_offroad"].exclusive_slot) == "tires"
		and String(ids["tires_lowering"].exclusive_slot) == "tires",
		"catalog: tire swaps share an exclusive slot")

func test_every_item_composes_on_a_real_car() -> void:
	var base = load("res://data/vehicles/hornet.tres")  # the all-11s yardstick
	var base_armor: int = base.armor
	for item in Catalog.load_catalog():
		var modded = VehicleLoadout.compose(base, [Catalog.as_mod(item)])
		t.check(modded != null and modded != base,
			"catalog: %s composes to a fresh resource" % item.id)
		for stat_v in item.get("stat_deltas", {}):
			var want: int = clampi(int(base.get(String(stat_v))) + int(item.stat_deltas[stat_v]), 1, 20)
			t.check(int(modded.get(String(stat_v))) == want,
				"catalog: %s delta '%s' lands through compose" % [item.id, stat_v])
	t.check(base.armor == base_armor, "catalog: the base .tres is never mutated")

func test_as_mod_forwards_everything_compose_reads() -> void:
	var item := {"id": "x", "stat_deltas": {"armor": 1},
		"terrain_overlay": {"dirt": {"grip": 1.2}},
		"controller_overrides": {"boost_top_factor": 1.5},
		"capabilities": {"burn_taken": 0.8}, "reserved": {"dead": 1}}
	var mod := Catalog.as_mod(item)
	t.check(mod.has("terrain_overlay") and mod.has("controller_overrides"),
		"as_mod: terrain_overlay and controller_overrides pass through")
	t.check(not mod.has("reserved"), "as_mod: the retired reserved bag never rides along")
	t.check(not Catalog.as_mod({"id": "y"}).has("stat_deltas"),
		"as_mod: absent fields stay absent, not empty stubs")

func test_rival_mod_keeps_pace() -> void:
	# player positives: acc 1+1=2 (engine chain), top +1; bay's NEGATIVES ignored
	var rival := Catalog.rival_mod(["engine_stage1", "engine_stage2", "bay_expansion"])
	t.check(int(rival.stat_deltas.get("acceleration", 0)) == 1,
		"rival: half of the player's +2 acc")
	t.check(not rival.stat_deltas.has("top_speed"),
		"rival: floor(0.5 of +1 top) mirrors nothing")
	t.check(not rival.stat_deltas.has("handling") and not rival.stat_deltas.has("armor"),
		"rival: the player's tradeoffs are theirs alone")
	t.check(Catalog.rival_mod([]).is_empty(), "rival: stock player = stock rivals")
	t.check(Catalog.mods_for(["engine_stage1"]).size() == 1
		and Catalog.mods_for(["engine_stage1"])[0].id == "engine_stage1",
		"catalog: mods_for resolves owned ids to compose-ready mods")

## The shipped rewired items land through compose — every former no-op now
## moves a real knob, and co-owned electronics stack order-free.
func test_shipped_wiring_lands_through_compose() -> void:
	var base = load("res://data/vehicles/hornet.tres")
	var items := Catalog.load_catalog()
	var compose_one := func(id: String):
		for item in items:
			if String(item.id) == id:
				return VehicleLoadout.compose(base, [Catalog.as_mod(item)])
		return null
	t.check(is_equal_approx(compose_one.call("mg_cooling").mg_heat_scale, 0.7),
		"wiring: MG Cooling lands 0.7x heat")
	var lock = compose_one.call("improved_lock")
	t.check(is_equal_approx(lock.tracking_scale, 1.3) and is_equal_approx(lock.detectability, 1.5),
		"wiring: Improved Lock lands tracking 1.3 / detectability 1.5")
	t.check(is_equal_approx(compose_one.call("radar_jammer").detectability, 0.8),
		"wiring: Radar Jammer lands 0.8x signature")
	t.check(is_equal_approx(compose_one.call("extended_radar").radar_range_scale, 1.5),
		"wiring: Extended Radar lands 1.5x reach")
	t.check(compose_one.call("bay_expansion").special_ammo_cap == base.special_ammo_cap + 2,
		"wiring: Bay Expansion adds 2 to the authored special cap")
	var stacked = VehicleLoadout.compose(base, Catalog.mods_for(["improved_lock", "radar_jammer"]))
	t.check(is_equal_approx(stacked.detectability, 1.2),
		"wiring: lock + jammer stack to 1.2 signature")
	var swapped = VehicleLoadout.compose(base, Catalog.mods_for(["radar_jammer", "improved_lock"]))
	t.check(is_equal_approx(swapped.detectability, 1.2),
		"wiring: the stack is order-free")

## Tires cut both ways on a real identity car: the overlay's spoken surfaces
## move, the silent signature traits survive, the base .tres never mutates.
func test_tire_overlays_on_cricket() -> void:
	var base = load("res://data/vehicles/cricket.tres")
	var base_dirt_grip: float = base.terrain_factor(&"dirt", &"grip")
	var lowered = VehicleLoadout.compose(base, Catalog.mods_for(["tires_lowering"]))
	t.check(is_equal_approx(lowered.terrain_factor(&"dirt", &"grip"), 0.8),
		"tires: the lowering kit costs Cricket her dirt grab")
	t.check(is_equal_approx(lowered.terrain_factor(&"dirt", &"dash_damage"), 1.15),
		"tires: her dirt Leap premium survives — the overlay never spoke to it")
	t.check(is_equal_approx(lowered.terrain_factor(&"road", &"grip"), 1.12),
		"tires: street manners sharpen")
	var knobby = VehicleLoadout.compose(base, Catalog.mods_for(["tires_offroad"]))
	t.check(is_equal_approx(knobby.terrain_factor(&"mud", &"grip"), 1.3),
		"tires: knobbies dig into the mud")
	t.check(is_equal_approx(base.terrain_factor(&"dirt", &"grip"), base_dirt_grip),
		"tires: the shipped .tres is never mutated")

## Every shipped overlay factor must leave a drivable surface: net value vs the
## global table stays >= 0.2 (ice grip exempt — the global 0.08 IS the design).
func test_shipped_overlays_never_degenerate() -> void:
	var TERRAIN: Dictionary = preload("res://vehicles/driving_controller.gd").TERRAIN
	for item in Catalog.load_catalog():
		if not item.has("terrain_overlay"):
			continue
		for surface_v in item.terrain_overlay:
			var surface := StringName(String(surface_v))
			for prop_v in item.terrain_overlay[surface_v]:
				var prop := String(prop_v)
				if prop == "dash_damage" or (surface == &"ice" and prop == "grip"):
					continue
				var net: float = float(TERRAIN[surface][prop]) \
					* float(item.terrain_overlay[surface_v][prop_v])
				t.check(net >= 0.2, "overlay floor: %s %s.%s nets %.3f" % [item.id, surface, prop, net])

func test_validator_rejects_the_new_classes() -> void:
	var bad := {"items": [
		{"id": "a", "category": "ENGINE", "display_name": "A", "price": 100,
			"stat_deltas": {"armor": 1}, "reserved": {"anything": 1}},
		{"id": "b", "category": "ENGINE", "display_name": "B", "price": 100,
			"capabilities": {"lock_time_scale": 0.7}},
		{"id": "c", "category": "ENGINE", "display_name": "C", "price": 100,
			"capabilities": {"mg_heat_scale": 0.0}},
		{"id": "d", "category": "ENGINE", "display_name": "D", "price": 100,
			"terrain_overlay": {"lava": {"grip": 1.2}}},
		{"id": "e", "category": "ENGINE", "display_name": "E", "price": 100,
			"terrain_overlay": {"dirt": {"bounce": 1.2}}},
		{"id": "f", "category": "ENGINE", "display_name": "F", "price": 100,
			"stat_deltas": {}, "capabilities": {}},
	]}
	var errors := ", ".join(Catalog.catalog_errors(bad))
	t.check(errors.contains("a: unknown key 'reserved'"), "validator: the reserved bag is dead")
	t.check(errors.contains("b: unknown capability 'lock_time_scale'"),
		"validator: retired axis names can't sneak back in")
	t.check(errors.contains("c: capability 'mg_heat_scale' must be a number in"),
		"validator: out-of-band scales rejected")
	t.check(errors.contains("d: unknown terrain 'lava'"), "validator: bad overlay surface rejected")
	t.check(errors.contains("e: terrain 'dirt' has unknown property 'bounce'"),
		"validator: bad overlay property rejected")
	t.check(errors.contains("f: item changes nothing (dead data)"),
		"validator: the meaningfulness rule guards against future no-op items")

func test_validator_rejects_the_classics() -> void:
	var bad := {"items": [
		{"id": "a", "category": "SNACKS", "display_name": "?", "price": 100, "stat_deltas": {}},
		{"id": "b", "category": "ENGINE", "display_name": "B", "price": -5, "stat_deltas": {}},
		{"id": "c", "category": "ENGINE", "display_name": "C", "price": 100,
			"stat_deltas": {"top_speed_mph": 3}},
		{"id": "c", "category": "ENGINE", "display_name": "C2", "price": 100, "stat_deltas": {}},
		{"id": "d", "category": "ENGINE", "display_name": "D", "price": 100,
			"stat_deltas": {}, "requires": "ghost_part"},
	]}
	var errors := ", ".join(Catalog.catalog_errors(bad))
	t.check(errors.contains("unknown category"), "catalog: unknown category rejected")
	t.check(errors.contains("positive integer"), "catalog: bad price rejected")
	t.check(errors.contains("unknown stat"), "catalog: unknown stat delta rejected")
	t.check(errors.contains("duplicate id"), "catalog: duplicate id rejected")
	t.check(errors.contains("unknown item 'ghost_part'"), "catalog: dead prerequisite rejected")
	t.check(Catalog.catalog_errors("nope").size() == 1, "catalog: malformed shape rejected")
