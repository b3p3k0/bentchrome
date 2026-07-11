extends RefCounted
## Level JSON schema tests: round-trip stability, defaults, and one passing +
## one failing case per validation rule. Driven by tests/run_tests.gd.

const Schema := preload("res://levels/level_schema.gd")
const FIXTURE := "res://tests/fixtures/sample_level.json"

var t  # the runner: check()/check_approx() helpers + root access

func _init(runner) -> void:
	t = runner

## Fresh valid level: make_empty() defaults plus the one required enemy spawn.
func _valid() -> Dictionary:
	var level := Schema.make_empty()
	level.enemy_spawns.append({"pos": [448.0, -256.0]})
	return level

## Asserts validate() reports at least one error mentioning `needle`.
func _expect_error(level: Dictionary, needle: String, label: String) -> void:
	var hit := false
	for err in Schema.validate(level):
		if needle in err:
			hit = true
	t.check(hit, "%s (no error containing '%s')" % [label, needle])

func test_make_empty_plus_enemy_is_valid() -> void:
	var errors := Schema.validate(_valid())
	t.check(errors.is_empty(), "valid base level has no errors: %s" % [errors])

func test_fixture_parses_and_validates() -> void:
	var text := FileAccess.get_file_as_string(FIXTURE)
	t.check(not text.is_empty(), "fixture file readable")
	var level := Schema.parse(text)
	t.check(not level.is_empty(), "fixture parses")
	var errors := Schema.validate(level)
	t.check(errors.is_empty(), "fixture validates clean: %s" % [errors])
	t.check(level.name == "Sample Bowl", "fixture: name read")
	t.check(level.enemy_spawns.size() == 2, "fixture: enemy spawn count")
	t.check(level.terrain.size() == 3, "fixture: terrain count")

func test_serialize_parse_is_stable() -> void:
	var level := _valid()
	level.blocks.append({"pos": [-448.0, -256.0], "size": [128.0, 128.0]})
	level.pickups.append({"pos": [640.0, -128.0], "kind": "homing", "amount": 1.0, "respawn_seconds": 25.0})
	level.dummies.append({"pos": [448.0, 128.0], "max_hp": 60.0})
	level.terrain.append({"type": "ice", "rect": [256.0, 256.0, 512.0, 384.0]})
	var s1 := Schema.serialize(level)
	var reparsed := Schema.parse(s1)
	t.check(Schema.serialize(reparsed) == s1, "serialize -> parse -> serialize is byte-stable")
	t.check(Schema.validate(reparsed).is_empty(), "round-tripped level still valid")
	t.check_approx(reparsed.bounds.width, 2944.0, "round-trip: bounds width")
	t.check(reparsed.pickups[0].kind == "homing", "round-trip: pickup kind")

func test_parse_rejects_malformed() -> void:
	t.check(Schema.parse("not json at all").is_empty(), "garbage text -> {}")
	t.check(Schema.parse("[1, 2, 3]").is_empty(), "non-object root -> {}")

func test_parse_fills_defaults() -> void:
	var level := Schema.parse("""
	{
		"format": "bentchrome-level", "version": 1,
		"bounds": {"width": 1280, "height": 1280},
		"enemy_spawns": [{"pos": [320, 0]}],
		"pickups": [{"pos": [0, -320]}]
	}
	""")
	t.check(level.grid == Schema.GRID, "defaults: grid")
	t.check(level.name == "Untitled", "defaults: name")
	t.check_approx(level.player_spawn.pos[0], 0.0, "defaults: player spawn at center")
	t.check(level.pickups[0].kind == "standard", "defaults: pickup kind")
	t.check_approx(level.pickups[0].respawn_seconds, 20.0, "defaults: pickup respawn")
	t.check(Schema.validate(level).is_empty(), "defaults-filled level validates: %s" % [Schema.validate(level)])

func test_unknown_keys_ignored() -> void:
	var level := _valid()
	var text := Schema.serialize(level).trim_suffix("\n").trim_suffix("}") + ',\n"ramps_v2": []\n}'
	var reparsed := Schema.parse(text)  # push_warning expected here
	t.check(not reparsed.has("ramps_v2"), "unknown key dropped")
	t.check(Schema.validate(reparsed).is_empty(), "unknown key is not a validation error")

func test_identity_rules() -> void:
	var level := _valid()
	level.format = "quake-map"
	_expect_error(level, "format", "wrong format rejected")
	level = _valid()
	level.version = 99
	_expect_error(level, "version", "wrong version rejected")
	level = _valid()
	level.grid = 64
	_expect_error(level, "grid", "wrong grid rejected")
	level = _valid()
	level.erase("bounds")
	_expect_error(level, "bounds", "missing bounds rejected")

func test_bounds_rules() -> void:
	var level := _valid()
	level.bounds = {"width": 1300.0, "height": 2816.0}
	_expect_error(level, "multiple", "off-grid bounds rejected")
	level = _valid()
	level.bounds = {"width": 1152.0, "height": 1152.0}
	_expect_error(level, "between", "too-small bounds rejected")
	level = _valid()
	level.bounds = {"width": 4992.0, "height": 4992.0}
	_expect_error(level, "between", "too-large bounds rejected")

func test_spawn_rules() -> void:
	var level := _valid()
	level.enemy_spawns = []
	_expect_error(level, "1-4", "zero enemy spawns rejected")
	level = _valid()
	for i in 4:
		level.enemy_spawns.append({"pos": [-1000.0 + i * 300.0, 800.0]})
	_expect_error(level, "1-4", "five enemy spawns rejected")
	level = _valid()
	level.enemy_spawns = [{"pos": [5000.0, 0.0]}]
	_expect_error(level, "outside", "out-of-bounds enemy spawn rejected")
	level = _valid()
	level.player_spawn = {"pos": [0.0, -1400.0], "heading_deg": 0.0}
	_expect_error(level, "outside", "player spawn in the wall band rejected")
	level = _valid()
	level.enemy_spawns = [{"pos": [100.0, 0.0]}]
	_expect_error(level, "closer than", "spawns too close rejected")
	level = _valid()
	level.blocks.append({"pos": [448.0, -256.0], "size": [128.0, 128.0]})
	_expect_error(level, "on top of a block", "spawn on block rejected")
	level = _valid()
	level.enemy_spawns = ["not an object"]
	_expect_error(level, "pos", "malformed spawn entry rejected")

func test_block_rules() -> void:
	var level := _valid()
	level.blocks.append({"pos": [640.0, 512.0], "size": [32.0, 128.0]})
	_expect_error(level, "size", "undersized block rejected")
	level = _valid()
	level.blocks.append({"pos": [1440.0, 0.0], "size": [128.0, 128.0]})
	_expect_error(level, "inside the walls", "block poking through wall rejected")

func test_pickup_rules() -> void:
	var level := _valid()
	level.pickups.append({"pos": [640.0, -128.0], "kind": "rear", "amount": 2.0, "respawn_seconds": 20.0})
	t.check(Schema.validate(level).is_empty(), "rear pickup kind accepted")
	level = _valid()
	level.pickups.append({"pos": [640.0, -128.0], "kind": "nuke", "amount": 2.0, "respawn_seconds": 20.0})
	_expect_error(level, "kind", "unknown pickup kind rejected")
	level = _valid()
	level.pickups.append({"pos": [640.0, -128.0], "kind": "standard", "amount": 2.5, "respawn_seconds": 20.0})
	_expect_error(level, "amount", "fractional amount rejected")
	level = _valid()
	level.pickups.append({"pos": [640.0, -128.0], "kind": "standard", "amount": 2.0, "respawn_seconds": 500.0})
	_expect_error(level, "respawn_seconds", "out-of-range respawn rejected")

func test_dummy_rules() -> void:
	var level := _valid()
	level.dummies.append({"pos": [448.0, 128.0], "max_hp": 0.0})
	_expect_error(level, "max_hp", "zero-hp dummy rejected")

func test_terrain_rules() -> void:
	var level := _valid()
	level.terrain.append({"type": "lava", "rect": [256.0, 256.0, 512.0, 384.0]})
	_expect_error(level, "type", "unknown terrain type rejected")
	level = _valid()
	level.terrain.append({"type": "dirt", "rect": [10.0, 0.0, 128.0, 128.0]})
	_expect_error(level, "multiples", "off-grid terrain rect rejected")
	level = _valid()
	level.terrain.append({"type": "dirt", "rect": [1280.0, 0.0, 256.0, 128.0]})
	_expect_error(level, "inside the walls", "terrain overlapping wall rejected")
	level = _valid()
	level.terrain.append({"type": "dirt", "rect": [0.0, 0.0, 128.0]})
	_expect_error(level, "rect", "3-value terrain rect rejected")
