extends RefCounted
## BOLTS economy math (game/economy.gd): kill/salvage rewards (post ×10
## inflation), the per-level salvage cap, %-of-current-funds penalties that
## floor at zero, difficulty knob application, the enabled master valve, and
## DEVGOD inertness. DISCIPLINE: Economy and Difficulty are process-global
## statics — every test restores tier=HARD, enabled=false, and reset_run().

const Economy := preload("res://game/economy.gd")
const Difficulty := preload("res://game/difficulty.gd")

var t

func _init(runner) -> void:
	t = runner

func _open() -> void:
	Difficulty.tier = Difficulty.Tier.HARD
	Economy.god = false
	Economy.enabled = true
	Economy.reset_run()

func _close() -> void:
	Difficulty.tier = Difficulty.Tier.HARD
	Economy.god = false
	Economy.enabled = false
	Economy.reset_run()

func test_master_valve() -> void:
	_close()  # enabled = false
	Economy.funds = 500
	t.check(Economy.award_kill(&"mook") == 0 and Economy.award_salvage(100.0) == 0
		and Economy.apply_penalty(&"fall") == 0 and Economy.funds == 500,
		"economy: the valve closed = no wallet effects anywhere")
	_close()

func test_kill_rewards() -> void:
	_open()
	t.check(Economy.award_kill(&"mook") == 1000, "economy: mook pays 1000")
	t.check(Economy.award_kill(&"mini_boss") == 2500, "economy: mini-boss pays 2500")
	t.check(Economy.award_kill(&"boss") == 5000, "economy: boss pays 5000")
	t.check(Economy.award_kill(&"chase") == 250, "economy: chase kill pays 250")
	t.check(Economy.award_kill(&"???") == 1000, "economy: unknown rank pays the mook rate")
	t.check(Economy.funds == 9750, "economy: wallet accumulates")
	_close()

func test_salvage_size_proportionate() -> void:
	_open()
	t.check(Economy.award_salvage(15.0) == 30, "economy: picket fence pays 30")
	t.check(Economy.award_salvage(140.0) == 280, "economy: container pays 280")
	t.check(Economy.award_salvage(220.0) == 300, "economy: generator caps at MAX_EACH 300")
	t.check(Economy.award_salvage(1.0) == 2, "economy: soft target pays hp x factor")
	_close()

func test_salvage_level_cap() -> void:
	_open()
	var total := 0
	for i in 20:
		total += Economy.award_salvage(220.0)  # 300 each, cap at 3000
	t.check(total == Economy.SALVAGE_CAP, "economy: level salvage stops at the cap")
	t.check(Economy.award_salvage(220.0) == 0, "economy: tapped level pays nothing")
	Economy.reset_level()
	t.check(Economy.award_salvage(220.0) == 300, "economy: next level reopens salvage")
	_close()

func test_penalties_are_percentages_flooring_at_zero() -> void:
	_open()
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
	_close()

func test_difficulty_scaling() -> void:
	_open()
	Difficulty.tier = Difficulty.Tier.EASY
	Economy.funds = 1000
	t.check(Economy.apply_penalty(&"destroyed") == 100,
		"economy: easy tier halves penalties (20% -> 10%)")
	t.check(Economy.award_kill(&"mook") == 1000, "economy: earning identical on every tier")
	t.check(Economy.price(4000) == 3000, "economy: easy shop at 0.75x")
	Difficulty.tier = Difficulty.Tier.MEDIUM
	t.check(Economy.price(4000) == 3600, "economy: medium shop at 0.9x")
	Difficulty.tier = Difficulty.Tier.HARD
	t.check(Economy.price(4000) == 4000, "economy: hard is the 1.0 baseline")
	_close()

func test_devgod_courtesy() -> void:
	_open()
	Economy.god = true
	Economy.funds = 1000
	t.check(Economy.apply_penalty(&"fall") == 0 and Economy.funds == 1000,
		"economy: DEVGOD penalties inert")
	t.check(Economy.award_kill(&"mook") == 1000, "economy: DEVGOD rewards stay fun")
	_close()

func test_snapshot_shape() -> void:
	_open()
	var snap := Economy.snapshot()
	t.check(int(snap.kill_rewards.mook) == 1000 and is_equal_approx(float(snap.penalty_fall), 0.3)
		and int(snap.salvage_cap) == 3000, "economy: snapshot carries the knob set")
	_close()
