extends RefCounted
## BOLTS economy math (game/economy.gd): kill/salvage rewards, the per-level
## salvage cap, %-of-current-funds penalties that floor at zero, difficulty
## knob application, and DEVGOD inertness. DISCIPLINE: Economy and Difficulty
## are process-global statics — every test restores tier=HARD and reset_run().

const Economy := preload("res://game/economy.gd")
const Difficulty := preload("res://game/difficulty.gd")

var t

func _init(runner) -> void:
	t = runner

func _clean() -> void:
	Difficulty.tier = Difficulty.Tier.HARD
	Economy.god = false
	Economy.reset_run()

func test_kill_rewards() -> void:
	_clean()
	t.check(Economy.award_kill(&"mook") == 100, "economy: mook pays 100")
	t.check(Economy.award_kill(&"mini_boss") == 250, "economy: mini-boss pays 250")
	t.check(Economy.award_kill(&"boss") == 500, "economy: boss pays 500")
	t.check(Economy.award_kill(&"chase") == 25, "economy: chase kill pays 25")
	t.check(Economy.award_kill(&"???") == 100, "economy: unknown rank pays the mook rate")
	t.check(Economy.funds == 975, "economy: wallet accumulates")
	_clean()

func test_salvage_size_proportionate() -> void:
	_clean()
	t.check(Economy.award_salvage(15.0) == 3, "economy: picket fence pays 3")
	t.check(Economy.award_salvage(140.0) == 28, "economy: container pays 28")
	t.check(Economy.award_salvage(220.0) == 30, "economy: generator caps at MAX_EACH 30")
	t.check(Economy.award_salvage(1.0) == 1, "economy: soft target pays the 1-bolt floor")
	_clean()

func test_salvage_level_cap() -> void:
	_clean()
	var total := 0
	for i in 20:
		total += Economy.award_salvage(220.0)  # 30 each, cap at 300
	t.check(total == Economy.SALVAGE_CAP, "economy: level salvage stops at the cap")
	t.check(Economy.award_salvage(220.0) == 0, "economy: tapped level pays nothing")
	Economy.reset_level()
	t.check(Economy.award_salvage(220.0) == 30, "economy: next level reopens salvage")
	_clean()

func test_penalties_are_percentages_flooring_at_zero() -> void:
	_clean()
	Economy.funds = 1000
	t.check(Economy.apply_penalty(&"destroyed") == 200, "economy: destroyed takes 20%")
	t.check(Economy.funds == 800, "economy: wallet reflects the hit")
	t.check(Economy.apply_penalty(&"fall") == 240, "economy: falls take 30% — harsher than dying")
	t.check(Economy.apply_penalty(&"station") == 56, "economy: station takes 10%, floori'd")
	Economy.funds = 1
	t.check(Economy.apply_penalty(&"destroyed") == 0 and Economy.funds == 1,
		"economy: floori keeps a poor wallet whole")
	Economy.funds = 0
	t.check(Economy.apply_penalty(&"fall") == 0 and Economy.funds == 0,
		"economy: broke is the floor, never negative")
	_clean()

func test_difficulty_scaling() -> void:
	_clean()
	Difficulty.tier = Difficulty.Tier.EASY
	Economy.funds = 1000
	t.check(Economy.apply_penalty(&"destroyed") == 100,
		"economy: easy tier halves penalties (20% -> 10%)")
	t.check(Economy.award_kill(&"mook") == 100, "economy: earning identical on every tier")
	t.check(Economy.price(400) == 300, "economy: easy shop at 0.75x")
	Difficulty.tier = Difficulty.Tier.MEDIUM
	t.check(Economy.price(400) == 360, "economy: medium shop at 0.9x")
	Difficulty.tier = Difficulty.Tier.HARD
	t.check(Economy.price(400) == 400, "economy: hard is the 1.0 baseline")
	_clean()

func test_devgod_courtesy() -> void:
	_clean()
	Economy.god = true
	Economy.funds = 1000
	t.check(Economy.apply_penalty(&"fall") == 0 and Economy.funds == 1000,
		"economy: DEVGOD penalties inert")
	t.check(Economy.award_kill(&"mook") == 100, "economy: DEVGOD rewards stay fun")
	_clean()

func test_snapshot_shape() -> void:
	_clean()
	var snap := Economy.snapshot()
	t.check(int(snap.kill_rewards.mook) == 100 and is_equal_approx(float(snap.penalty_fall), 0.3)
		and int(snap.salvage_cap) == 300, "economy: snapshot carries the knob set")
	_clean()
