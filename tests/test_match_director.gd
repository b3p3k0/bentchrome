extends RefCounted
## MatchDirector.end_check — the four formats' pure truth table. Every locked
## edge-case policy that fits in data lives here: caps, joint winners, draws,
## THE WASTELAND, and the solo-melee elimination.

const Director := preload("res://game/net/match_director.gd")

var t

func _init(runner) -> void:
	t = runner

func _scores(kills: Dictionary) -> Dictionary:
	var out := {0: {"kills": 0, "deaths": 0, "name": "THE WASTELAND"}}
	for peer in kills:
		out[peer] = {"kills": kills[peer], "deaths": 0, "name": "P%d" % peer}
	return out

func test_frag_target() -> void:
	var cfg := {"format": "frag", "frag_target": 10}
	t.check(Director.end_check(cfg, _scores({1: 9, 2: 4}), 2, 2, [], 100.0).is_empty(),
		"frag: nine is not ten")
	var win: Dictionary = Director.end_check(cfg, _scores({1: 10, 2: 4}), 2, 2, [], 100.0)
	t.check(win.winners == [1] and String(win.reason) == "first to 10",
		"frag: first to the target takes it")

func test_brawl_caps() -> void:
	var capless := {"format": "brawl", "brawl_frag_cap": 0, "brawl_time_cap": 0}
	t.check(Director.end_check(capless, _scores({1: 99}), 2, 2, [], 99999.0).is_empty(),
		"brawl: capless runs until the host calls it")
	var fcap := {"format": "brawl", "brawl_frag_cap": 15, "brawl_time_cap": 0}
	t.check(not Director.end_check(fcap, _scores({2: 15}), 2, 2, [], 10.0).is_empty(),
		"brawl: frag cap ends it")
	var tcap := {"format": "brawl", "brawl_frag_cap": 0, "brawl_time_cap": 300}
	t.check(Director.end_check(tcap, _scores({1: 3}), 2, 2, [], 299.0).is_empty(),
		"brawl: clock still running")
	var timed_out: Dictionary = Director.end_check(tcap, _scores({1: 3, 2: 1}), 2, 2, [], 300.0)
	t.check(timed_out.winners == [1], "brawl: time cap crowns the leader")

func test_timed_and_joint_winners() -> void:
	var cfg := {"format": "timed", "time_limit": 180}
	t.check(Director.end_check(cfg, _scores({1: 2}), 2, 2, [], 179.9).is_empty(),
		"timed: not before the horn")
	var joint: Dictionary = Director.end_check(cfg, _scores({1: 4, 2: 4, 3: 1}), 3, 3, [], 180.0)
	var winners: Array = joint.winners
	winners.sort()
	t.check(winners == [1, 2], "timed: a tie at the horn is joint winners — no sudden death")

func test_lives_elimination() -> void:
	var cfg := {"format": "lives", "lives": 3}
	t.check(Director.end_check(cfg, _scores({1: 0, 2: 0}), 2, 2, [], 50.0).is_empty(),
		"lives: two standing keeps rolling")
	var last: Dictionary = Director.end_check(cfg, _scores({1: 0, 2: 0}), 1, 2, [2], 50.0)
	t.check(bool(last.get("resolve_survivor", false)),
		"lives: one left standing ends it (survivor resolved by the instance)")
	var draw: Dictionary = Director.end_check(cfg, _scores({1: 0, 2: 0}), 0, 2, [1, 2], 50.0)
	var draw_winners: Array = draw.winners
	draw_winners.sort()
	t.check(draw_winners == [1, 2] and String(draw.reason) == "mutual destruction",
		"lives: simultaneous final deaths = a draw among them")
	var wasteland: Dictionary = Director.end_check(cfg, _scores({1: 0}), 0, 1, [1], 50.0)
	t.check((wasteland.winners as Array).is_empty()
		and String(wasteland.reason) == "THE WASTELAND WINS",
		"lives: solo melee wipe — the wasteland takes it")
	t.check(Director.end_check(cfg, _scores({1: 0}), 1, 1, [], 50.0).is_empty(),
		"lives: a solo driver alive is not a win — nobody to outlast")

func test_end_beats_everything() -> void:
	# The killing blow that hits a cap must end the match in the same tick the
	# tallies land — end_check consumes updated scores BEFORE any rotation.
	var cfg := {"format": "frag", "frag_target": 5}
	var verdict: Dictionary = Director.end_check(cfg, _scores({1: 5}), 2, 2, [], 1.0)
	t.check(not verdict.is_empty(), "order: the cap-hitting kill ends it immediately")