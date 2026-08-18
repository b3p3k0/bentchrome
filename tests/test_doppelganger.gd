extends RefCounted
## The SP enemy re-roll must NEVER field the player's car. The old derivation
## read stats.resource_path — but a garage purchase routes stats through
## VehicleLoadout.compose(), whose duplicate() has an EMPTY resource_path, so
## the exclusion silently became "" and doppelgangers rolled. The id now rides
## VehicleStats.id (survives duplicate) with the picker selection as fallback.
## Driven by run_tests.gd.

const CombatLevel := preload("res://levels/combat_level.gd")

var t

func _init(runner) -> void:
	t = runner

## Locks the bug's premise: compose() really does strip resource_path, and the
## authored id really does survive the duplicate. If either engine behavior
## ever shifts, this points straight at the derivation contract.
func test_id_survives_garage_compose() -> void:
	var base := load("res://data/vehicles/ghost.tres") as VehicleStats
	var composed := VehicleLoadout.compose(base, [{"stat_deltas": {"armor": 2}}])
	t.check(composed.resource_path == "", "compose: duplicate carries no resource_path")
	t.check(composed.id == &"ghost", "compose: the authored id survives the duplicate")

func test_player_car_id_derivation() -> void:
	var base := load("res://data/vehicles/ghost.tres") as VehicleStats
	var composed := VehicleLoadout.compose(base, [{"stat_deltas": {"armor": 2}}])
	t.check(CombatLevel.player_car_id(composed, &"") == "ghost",
		"derivation: composed stats exclude by authored id (THE doppelganger fix)")
	t.check(CombatLevel.player_car_id(null, &"coldfront") == "coldfront",
		"derivation: no stats falls back to the picker's selection")
	# Fresh instance via CACHE_MODE_IGNORE — mutating a plain load() would
	# poison the cached resource for every later suite.
	var pathed := ResourceLoader.load("res://data/vehicles/ghost.tres", "",
		ResourceLoader.CACHE_MODE_IGNORE) as VehicleStats
	pathed.id = &""
	t.check(CombatLevel.player_car_id(pathed, &"") == "ghost",
		"derivation: id-less stats with a real path fall back to the basename")
	var blank := VehicleLoadout.compose(pathed, [])
	t.check(CombatLevel.player_car_id(blank, &"") == "",
		"derivation: nothing derivable returns empty (no exclusion, no crash)")
	t.check(CombatLevel.player_car_id(null, &"") == "", "derivation: all-empty is empty")
