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

func test_describe_speaks_plainly() -> void:
	var tier := "REVOKED LICENSE"
	var melee_brawl: Array[String] = Config.describe(
		{"mode": "melee", "format": "brawl", "brawl_frag_cap": 15, "brawl_time_cap": 0,
			"observers": true, "gotnext": true, "difficulty": 2},
		"Piers of Pain", tier)
	t.check(melee_brawl.size() == 3, "deal: three sentences — mode, format, bench")
	t.check(melee_brawl[0].contains("Free-for-all on Piers of Pain")
			and melee_brawl[0].contains(tier), "deal: melee names the map and the AI tier")
	t.check(melee_brawl[1] == "Rolling brawl to 15 wrecks.", "deal: frag-capped brawl")
	t.check(melee_brawl[2].contains("called NEXT"), "deal: got-next bench line")

	var capless: Array[String] = Config.describe(
		{"mode": "grudge", "format": "brawl", "observers": false}, "Downtown Derby", tier)
	t.check(capless[0].contains("Humans only on Downtown Derby"), "deal: grudge line")
	t.check(capless[1].contains("the host calls time"), "deal: capless brawl line")
	t.check(capless[2] == "Seats only — no spectators this time.", "deal: seats-only bench")

	var both_caps: Array[String] = Config.describe(
		{"format": "brawl", "brawl_frag_cap": 20, "brawl_time_cap": 300}, "X", tier)
	t.check(both_caps[1].contains("20 wrecks or 5 minutes"), "deal: dual-cap brawl")

	t.check(Config.describe({"format": "frag", "frag_target": 10}, "X", tier)[1]
			== "First driver to 10 wrecks takes it.", "deal: frag line")
	t.check(Config.describe({"format": "timed", "time_limit": 300}, "X", tier)[1]
			.contains("5 minutes on the clock"), "deal: timed line names the minutes")
	t.check(Config.describe({"format": "lives", "lives": 3}, "X", tier)[1]
			.contains("3 lives"), "deal: lives line names the tank")
	t.check(Config.describe({"gotnext": false}, "X", tier)[2]
			.contains("Spectators welcome"), "deal: spectators-without-queue bench")
