extends RefCounted
## The car contract, enforced: every roster.json id must arrive with a paint
## bay (STYLE_SCRIPTS), a unique collision radius ranked in the size canon,
## a bios portrait, a fresh imported .tres carrying a live special, and a
## known AI archetype — plus the importer's validators must actually reject
## the mistakes this suite guards against (docs/car_authoring.md is the
## human-readable checklist). Driven by tests/run_tests.gd.

const PaintScript := preload("res://vehicles/car_paint.gd")
const CanonSuite := preload("res://tests/test_car_paint.gd")
const Importer := preload("res://tools/import_roster.gd")
const WeaponDefScript := preload("res://resources/weapon_def.gd")

var t
var _cars: Array = []

func _init(runner) -> void:
	t = runner
	var data: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/data/roster.json"))
	if typeof(data) == TYPE_DICTIONARY:
		_cars = data.get("characters", [])

func test_roster_parses_and_is_populated() -> void:
	t.check(_cars.size() >= 9, "roster holds the fleet (%d cars)" % _cars.size())

## The live roster must pass the importer's own strict validation — this one
## check covers required keys, stat bands, portraits on disk, loadable
## special_defs, archetype vocabulary, and terrain profiles in a single sweep.
func test_live_roster_passes_importer_validation() -> void:
	var data: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/data/roster.json"))
	var errors := Importer.roster_errors(data)
	t.check(errors.is_empty(), "roster.json validates clean (issues: %s)" % ", ".join(errors))

func test_every_car_has_a_paint_bay() -> void:
	for c in _cars:
		var id := StringName(String(c.id))
		t.check(PaintScript.STYLE_SCRIPTS.has(id), "paint file registered: %s" % id)
		t.check(PaintScript.STYLES.has(id), "style metrics present: %s" % id)

func test_radii_unique_and_canon_covers_roster() -> void:
	var seen := {}
	for c in _cars:
		var id := StringName(String(c.id))
		if not PaintScript.STYLES.has(id):
			continue
		var r: float = PaintScript.STYLES[id].radius
		t.check(not seen.has(r), "collision radius %.1f unique to %s (also %s)" % [r, id, seen.get(r, "")])
		seen[r] = id
	var canon := {}
	for id in CanonSuite.ORDER:
		canon[id] = true
	for c in _cars:
		var id := StringName(String(c.id))
		t.check(canon.has(id), "size canon (test_car_paint ORDER) ranks %s" % id)
	t.check(canon.size() == _cars.size(),
		"size canon holds exactly the roster (%d vs %d cars)" % [canon.size(), _cars.size()])

## "Edited roster.json, forgot the importer" — the generated .tres must exist,
## carry the same id, and hold a live special of a known Kind.
func test_generated_tres_fresh_and_armed() -> void:
	for c in _cars:
		var id := String(c.id)
		var path := "res://data/vehicles/%s.tres" % id
		t.check(ResourceLoader.exists(path), "imported stats exist: %s" % id)
		if not ResourceLoader.exists(path):
			continue
		var vs: VehicleStats = load(path)
		t.check(String(vs.id) == id, "imported id matches: %s" % id)
		t.check(vs.special != null, "special is bound: %s" % id)
		if vs.special != null:
			t.check(vs.special.kind in WeaponDefScript.Kind.values(),
				"special kind is a known Kind: %s" % id)
			var authored := Importer.special_def_path(String(c.special_def))
			t.check(vs.special.resource_path == authored,
				"imported special matches roster special_def: %s" % id)

## The validators themselves: feed the importer's static checks the exact
## mistakes this contract exists to catch.
func test_importer_rejects_bad_entries() -> void:
	t.check(Importer.character_errors(_fixture()).is_empty(), "fixture entry validates clean")
	t.check(_has_error(_fixture({}, ["mass"]), "mass"), "missing key rejected")
	t.check(_has_error(_fixture({"specail_def": "leap"}), "unknown key"), "typo key rejected")
	t.check(_has_error(_fixture({"ai_archetype": "camper"}), "ai_archetype"), "unknown archetype rejected")
	t.check(_has_error(_fixture({"special_def": "not_a_weapon"}), "special_def"), "dead special rejected")
	t.check(_has_error(_fixture({"portrait": "res://assets/img/bios/nobody.png"}), "portrait"), "missing portrait rejected")
	var hot := _fixture()
	hot.stats = {"acceleration": 11, "top_speed": 8, "handling": 4, "armor": 4, "special_power": 8}
	t.check(_has_error(hot, "acceleration"), "out-of-band stat rejected")
	var dup := {"characters": [_fixture(), _fixture()]}
	var dup_errors := Importer.roster_errors(dup)
	t.check(", ".join(dup_errors).contains("duplicate"), "duplicate id rejected")

func _fixture(overrides: Dictionary = {}, drop: Array = []) -> Dictionary:
	var entry := {
		"id": "testcar",
		"car_name": "Test Car",
		"driver_name": "Nobody",
		"flavor": "A fixture.",
		"special_weapon": "Leap: a fixture special.",
		"special_def": "leap",
		"ai_archetype": "aggressor",
		"stats": {"acceleration": 8, "top_speed": 8, "handling": 4, "armor": 4, "special_power": 8},
		"colors": {"primary": "#31ff57", "accent": "#0a8a2c"},
		"portrait": "res://assets/img/bios/cricket.png",
		"mass": 2,
	}
	for key in overrides:
		entry[key] = overrides[key]
	for key in drop:
		entry.erase(key)
	return entry

func _has_error(entry: Dictionary, needle: String) -> bool:
	return ", ".join(Importer.character_errors(entry)).contains(needle)
