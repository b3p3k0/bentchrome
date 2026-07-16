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
