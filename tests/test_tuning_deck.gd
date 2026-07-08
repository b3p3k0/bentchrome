extends RefCounted
## Tuning deck: def/terrain overrides mutate the live singletons, resets
## restore them, and save/load round-trips through a throwaway path.
## DISCIPLINE: everything mutated here is process-global (shared resources,
## the TERRAIN dict) — every test MUST restore via reset before returning.

const DeckScript := preload("res://game/tuning_deck.gd")
const TMP := "user://_test_tuning.json"

var t

func _init(runner) -> void:
	t = runner

func test_def_override_and_reset() -> void:
	var deck = DeckScript.new()
	var scythe: Resource = load("res://data/weapons/scythe.tres")
	var base_dmg: float = scythe.damage
	deck.set_def("scythe", "damage", base_dmg + 15.0)
	t.check(is_equal_approx(scythe.damage, base_dmg + 15.0), "deck: def override hits the live resource")
	t.check(is_equal_approx(deck.get_def("scythe", "damage"), base_dmg + 15.0), "deck: reads back")
	deck.reset_defs()
	t.check(is_equal_approx(scythe.damage, base_dmg), "deck: reset restores the base value")

func test_int_props_stay_int() -> void:
	var deck = DeckScript.new()
	var glare: Resource = load("res://data/weapons/red_glare.tres")
	var base_pellets: int = glare.pellets
	deck.set_def("red_glare", "pellets", 6.4)
	t.check(glare.pellets == 6 and glare.pellets is int, "deck: pellet override rounds to int")
	deck.reset_defs()
	t.check(glare.pellets == base_pellets, "deck: int reset restores")

func test_terrain_override_and_reset() -> void:
	var deck = DeckScript.new()
	var base_grip: float = DrivingController.TERRAIN[&"grass"]["grip"]
	deck.set_terrain(&"grass", "grip", 1.2)
	t.check(is_equal_approx(DrivingController.TERRAIN[&"grass"]["grip"], 1.2), "deck: terrain override lands")
	deck.reset_terrain()
	t.check(is_equal_approx(DrivingController.TERRAIN[&"grass"]["grip"], base_grip), "deck: terrain reset restores")

func test_save_load_round_trip() -> void:
	var deck = DeckScript.new()
	var scythe: Resource = load("res://data/weapons/scythe.tres")
	var base_dmg: float = scythe.damage
	deck.set_def("scythe", "damage", 99.0)
	deck.set_terrain(&"ice", "grip", 0.5)
	deck.set_vehicle("ram_damage_scale", 0.1)
	deck.save(TMP)
	deck.reset_defs()
	deck.reset_terrain()
	t.check(is_equal_approx(scythe.damage, base_dmg), "deck: clean slate before load")

	var deck2 = DeckScript.new()
	deck2.load_and_apply(TMP)
	t.check(is_equal_approx(scythe.damage, 99.0), "deck: loaded def override re-applies")
	t.check(is_equal_approx(DrivingController.TERRAIN[&"ice"]["grip"], 0.5), "deck: loaded terrain re-applies")
	t.check(is_equal_approx(deck2.overrides.vehicle["ram_damage_scale"], 0.1), "deck: vehicle override survives")
	deck2.reset_defs()
	deck2.reset_terrain()
	DirAccess.remove_absolute(TMP)
	t.check(is_equal_approx(scythe.damage, base_dmg), "deck: restored after round trip")
