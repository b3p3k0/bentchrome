extends RefCounted
## The difficulty ledger: HARD is today's game byte-for-byte — the identity
## every other suite silently relies on — and the easier tiers only ever
## scale at the read sites (Combat.scale player branches, AI mount push,
## boss valves, Goliath pools). Every test here restores tier = HARD before
## returning: script statics leak across suites.

const Difficulty := preload("res://game/difficulty.gd")
const Combat := preload("res://game/combat.gd")
const EnemyDriverScript := preload("res://vehicles/drivers/enemy_driver.gd")
const BossScript := preload("res://vehicles/goliath/goliath_boss.gd")
const VehicleScene := preload("res://vehicles/vehicle.tscn")

## Combat.scale duck-types on groups + get_hp_fraction — no Vehicle needed.
class Stub extends Node:
	var hp_frac := 1.0
	func get_hp_fraction() -> float:
		return hp_frac

var t

func _init(runner) -> void:
	t = runner

func _combatant(group: StringName) -> Stub:
	var n := Stub.new()
	n.add_to_group(&"vehicles")
	n.add_to_group(group)
	return n

func test_default_is_hard_identity() -> void:
	t.check(Difficulty.tier == Difficulty.Tier.HARD,
		"difficulty: boots on HARD — the baseline the whole suite rides on")
	var hard: Dictionary = Difficulty.TIERS[Difficulty.Tier.HARD]
	for knob: StringName in hard:
		t.check_approx(hard[knob], 1.0, "difficulty: HARD %s is identity" % knob)
	for tier: int in [Difficulty.Tier.EASY, Difficulty.Tier.MEDIUM, Difficulty.Tier.HARD]:
		t.check(Difficulty.NAMES.has(tier) and not str(Difficulty.NAMES[tier]).is_empty(),
			"difficulty: tier %d carries a flavor title" % tier)
		var row: Dictionary = Difficulty.TIERS[tier]
		t.check(row.keys() == hard.keys(),
			"difficulty: tier %d row matches the HARD knob set (typo guard)" % tier)
	t.check_approx(Difficulty.knob(&"no_such_knob"), 1.0,
		"difficulty: unknown knob fails soft to identity")

func test_hard_combat_scale_unchanged() -> void:
	var player := _combatant(&"player")
	var ai_a := _combatant(&"enemies")
	var ai_b := _combatant(&"enemies")
	t.check_approx(Combat.scale(ai_a, player), 1.0, "hard: AI->player full strength")
	t.check_approx(Combat.scale(player, ai_a), 1.0, "hard: player->AI full strength")
	t.check_approx(Combat.scale(ai_a, ai_b), Combat.AI_VS_AI_DAMAGE,
		"hard: AI theater governor untouched")
	ai_b.hp_frac = Combat.AI_MERCY_HP * 0.5
	t.check_approx(Combat.scale(ai_a, ai_b), 0.0, "hard: AI mercy untouched")
	player.free()
	ai_a.free()
	ai_b.free()

func test_easy_softens_player_taken_only() -> void:
	Difficulty.tier = Difficulty.Tier.EASY
	var player := _combatant(&"player")
	var ai_a := _combatant(&"enemies")
	var ai_b := _combatant(&"enemies")
	var taken: float = Difficulty.knob(&"player_damage_taken")
	t.check(taken < 1.0, "easy: the taken knob actually softens")
	t.check_approx(Combat.scale(ai_a, player), taken, "easy: AI->player scaled down")
	t.check_approx(Combat.scale(player, ai_a), 1.0,
		"easy: player->AI stays full (dealt knob dormant at 1.0)")
	t.check_approx(Combat.scale(ai_a, ai_b), Combat.AI_VS_AI_DAMAGE,
		"easy: AI theater unaffected by tier")
	ai_b.hp_frac = Combat.AI_MERCY_HP * 0.5
	t.check_approx(Combat.scale(ai_a, ai_b), 0.0, "easy: AI mercy unaffected by tier")
	player.free()
	ai_a.free()
	ai_b.free()
	Difficulty.tier = Difficulty.Tier.HARD

func test_ai_mount_cooldown_scaled() -> void:
	Difficulty.tier = Difficulty.Tier.EASY
	var easy = VehicleScene.instantiate()
	easy.faction = &"enemies"  # fixture trap: default faction shadows player lookups
	t.root.add_child(easy)
	var want: float = easy.ai_cooldown_scale * Difficulty.knob(&"ai_fire_cooldown")
	t.check_approx(easy.get_node("MachineGunMount").cooldown_scale, want,
		"easy: AI trigger speed slowed by the tier knob")
	t.root.remove_child(easy)
	easy.free()
	Difficulty.tier = Difficulty.Tier.HARD
	var hard = VehicleScene.instantiate()
	hard.faction = &"enemies"
	t.root.add_child(hard)
	t.check_approx(hard.get_node("MachineGunMount").cooldown_scale, hard.ai_cooldown_scale,
		"hard: AI trigger speed is today's 3x, exactly")
	t.root.remove_child(hard)
	hard.free()

func test_boss_break_time_scaled() -> void:
	var drv := EnemyDriverScript.new()
	var vehicle := Stub.new()
	var target := Stub.new()
	var hard: float = drv._boss_break_time(vehicle, target)
	Difficulty.tier = Difficulty.Tier.EASY
	var easy: float = drv._boss_break_time(vehicle, target)
	Difficulty.tier = Difficulty.Tier.HARD
	var mult: float = Difficulty.TIERS[Difficulty.Tier.EASY][&"boss_break_time"]
	t.check_approx(easy, hard * mult, "easy: boss breather widened by the tier knob")
	drv.free()
	vehicle.free()
	target.free()

func test_goliath_pools_scaled() -> void:
	Difficulty.tier = Difficulty.Tier.EASY
	var container := Node2D.new()
	t.root.add_child(container)
	var cab = VehicleScene.instantiate()
	cab.faction = &"enemies"
	container.add_child(cab)
	var boss = BossScript.new()
	boss.name = "BossController"
	cab.add_child(boss)
	await t.physics_frame  # deferred setup: trailer spawn + pool override
	var health: Health = cab.get_node("Health")
	var mult: float = Difficulty.TIERS[Difficulty.Tier.EASY][&"goliath_hp"]
	t.check_approx(health.max_hp, BossScript.PHASE1_HP * mult,
		"easy: phase-1 pool trimmed at fight start")
	t.check_approx(health.hp, health.max_hp, "easy: pool starts full")
	boss.start_phase2()
	t.check_approx(health.max_hp, BossScript.PHASE2_HP * mult,
		"easy: phase-2 pool trimmed at the swap")
	t.root.remove_child(container)
	container.free()
	Difficulty.tier = Difficulty.Tier.HARD
