extends RefCounted
## MatchConfig: normalize() rebuilds a trusted ruleset from untrusted patches —
## whitelists, clamps, junk-shape tolerance — and the roster car list loads.

const Config := preload("res://game/net/match_config.gd")

var t

func _init(runner) -> void:
	t = runner

func test_defaults_pass_clean() -> void:
	var cfg: Dictionary = Config.normalize(Config.defaults(), 5)
	t.check(cfg.mode == &"melee" and cfg.format == &"brawl", "config: defaults hold")
	t.check(cfg.time_limit == 300 and cfg.frag_target == 10 and cfg.lives == 3,
		"config: default numbers hold")

func test_clamps() -> void:
	var cfg: Dictionary = Config.normalize({
		"time_limit": 60, "frag_target": 0, "lives": 99,
		"brawl_frag_cap": 999, "brawl_time_cap": 30, "map": 42, "difficulty": 9,
	}, 5)
	t.check(cfg.time_limit == 180, "config: timed floor is 3 minutes")
	t.check(Config.normalize({"time_limit": 9999}, 5).time_limit == 600,
		"config: timed ceiling is 10 minutes")
	t.check(cfg.frag_target == 1, "config: frag target floors at 1")
	t.check(cfg.lives == 9, "config: lives cap at 9")
	t.check(cfg.brawl_frag_cap == 50, "config: brawl frag cap clamps")
	t.check(cfg.brawl_time_cap == 180, "config: a nonzero brawl time cap floors at 3 min")
	t.check(Config.normalize({"brawl_time_cap": 0}, 5).brawl_time_cap == 0,
		"config: zero brawl time cap means off")
	t.check(cfg.map == 4, "config: map clamps to the pool")
	t.check(cfg.difficulty == 2, "config: difficulty clamps to the tier table")

func test_whitelists_and_junk() -> void:
	var cfg: Dictionary = Config.normalize({
		"mode": "nonsense", "format": "cheatmode",
		"speedhack": true, "gotnext": false,
	}, 5)
	t.check(cfg.mode == &"melee", "config: unknown mode falls to default")
	t.check(cfg.format == &"brawl", "config: unknown format falls to default")
	t.check(not cfg.has("speedhack"), "config: unknown keys are dropped")
	t.check(cfg.gotnext == false, "config: known bools pass")
	t.check(cfg.observers == true, "config: observers default to welcome")
	t.check(Config.normalize({"observers": false}, 5).observers == false,
		"config: observers toggle passes")
	var relay: Dictionary = Config.normalize({"mode": "grudge", "format": "lives"}, 5)
	t.check(relay.mode == &"grudge" and relay.format == &"lives",
		"config: String-typed names (RPC/JSON round-trips) still whitelist")

func test_car_roster() -> void:
	var ids: Array = Config.car_ids()
	t.check(ids.size() >= 8, "config: roster car list loads")
	t.check(ids.has("bumper"), "config: known slug present")
	t.check(Config.car_name("bumper") == "Bumper", "config: display name resolves")
	t.check(Config.car_name("nonsense") == "NONSENSE", "config: unknown id upper-cases")