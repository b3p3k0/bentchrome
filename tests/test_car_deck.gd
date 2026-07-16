extends RefCounted
## Car deck (car-tuner backend): edits mutate the loaded VehicleStats
## singletons, resets restore roster truth, save/load and export round-trip.
## DISCIPLINE: data/vehicles/*.tres are process-global — every test MUST end
## restored (test_stat_rebase's golden lock runs later in SUITES and audits
## exactly these values).

const DeckScript := preload("res://game/car_deck.gd")
const TMP := "user://_test_car_tuner.json"
const TMP_EXPORT := "user://_test_car_tuner_export.json"

var t

func _init(runner) -> void:
	t = runner

func test_roster_rows_and_baselines() -> void:
	var deck = DeckScript.new()
	t.check(deck.car_ids.size() >= 9 and not deck.car_ids.has("goliath")
		and not deck.car_ids.has("lackey") and not deck.car_ids.has("buzz_bike"),
		"car deck: rows are the roster only — bosses/buzzards excluded")
	t.check(deck.baseline("razorback", "top_speed") == 12.0
		and deck.baseline("razorback", "launch") == 15.0
		and deck.baseline("hornet", "launch") == 3.0,
		"car deck: baselines read roster truth incl. defaults")

func test_set_value_mutates_singleton_and_clamps() -> void:
	var deck = DeckScript.new()
	var stats: Resource = load("res://data/vehicles/razorback.tres")
	var base_top: int = stats.top_speed
	deck.set_value("razorback", "top_speed", 13)
	t.check(stats.top_speed == 13, "car deck: edit lands on the loaded singleton")
	t.check(deck.get_value("razorback", "top_speed") == 13.0, "car deck: reads back")
	deck.set_value("razorback", "top_speed", 99)
	t.check(stats.top_speed == 20, "car deck: clamps to the 1-20 ceiling")
	deck.set_value("razorback", "launch", -5)
	t.check(stats.launch == 0, "car deck: launch floors at the 0 sentinel")
	deck.set_value("razorback", "special_recharge_seconds", 45.5)
	t.check(is_equal_approx(stats.special_recharge_seconds, 45.5),
		"car deck: recharge stays a float")
	deck.reset_all()
	t.check(stats.top_speed == base_top and stats.launch == 15
		and is_equal_approx(stats.special_recharge_seconds, 45.0),
		"car deck: reset_all restores roster truth")
	DirAccess.remove_absolute(DeckScript.SAVE_PATH)

func test_save_load_round_trip() -> void:
	var deck = DeckScript.new()
	var stats: Resource = load("res://data/vehicles/cricket.tres")
	var base_accel: int = stats.acceleration
	deck.set_value("cricket", "acceleration", base_accel + 2)
	deck.save(TMP)
	deck.restore_baselines()
	t.check(stats.acceleration == base_accel, "car deck: clean slate before load")

	var deck2 = DeckScript.new()
	deck2.load_and_apply(TMP)
	t.check(stats.acceleration == base_accel + 2, "car deck: loaded override re-applies")
	deck2.reset_all()
	DirAccess.remove_absolute(TMP)
	DirAccess.remove_absolute(DeckScript.SAVE_PATH)
	t.check(stats.acceleration == base_accel, "car deck: restored after round trip")

func test_export_shape() -> void:
	var deck = DeckScript.new()
	deck.set_value("lovebug", "armor", 9)
	var path := deck.export_file(TMP_EXPORT)
	t.check(path.ends_with("_test_car_tuner_export.json"), "car deck: export returns the path")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(TMP_EXPORT))
	t.check(typeof(data) == TYPE_DICTIONARY and int(data.get("schema_version", 0)) == 2,
		"car deck: export carries schema_version 2")
	t.check(int(data.cars.lovebug.armor) == 9, "car deck: export carries the edited value")
	t.check(int(data.cars.razorback.top_speed) == 12, "car deck: export carries untouched cars too")
	deck.reset_all()
	DirAccess.remove_absolute(TMP_EXPORT)
	DirAccess.remove_absolute(DeckScript.SAVE_PATH)
	var lovebug: Resource = load("res://data/vehicles/lovebug.tres")
	t.check(lovebug.armor == 7, "car deck: lovebug restored (golden-lock hygiene)")

func test_restore_baselines_keeps_overrides_and_file() -> void:
	var deck = DeckScript.new()
	var stats: Resource = load("res://data/vehicles/smoky.tres")
	var base_hand: int = stats.handling
	deck.set_value("smoky", "handling", base_hand + 2)
	deck.restore_baselines()  # MP standardization: pristine data...
	t.check(stats.handling == base_hand, "car deck: restore_baselines standardizes the singleton")
	t.check(int(deck.overrides.smoky.handling) == base_hand + 2,
		"car deck: ...while the session overrides survive for later")
	deck.overrides.clear()
