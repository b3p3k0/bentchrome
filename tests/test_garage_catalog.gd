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
