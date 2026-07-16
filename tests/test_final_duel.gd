extends RefCounted
## Real-arena final-duel regression: a wounded last mook must perform a pass,
## establish separation, and come back instead of entering the old endless
## EVADE/circle finish. Also locks assignment off/on across player respawn.

const ArenaScene := preload("res://levels/arena/arena.tscn")
const DriverScript := preload("res://vehicles/drivers/enemy_driver.gd")

const MAX_FRAMES := 900
const MIN_SEPARATION := 300.0
const RETURN_GAIN := 100.0

var t

class FakeCar extends Node2D:
	var hpf := 0.05
	func get_hp_fraction() -> float:
		return hpf

func _init(runner) -> void:
	t = runner

func _immunize(car: Node) -> void:
	car.get_node("Health").invulnerable = true
	var forever := StatusEffectSpec.new()
	forever.kind = &"invuln"
	forever.duration = 9999.0
	car.apply_effect(forever)

func test_low_health_flee_is_an_episode() -> void:
	var driver = DriverScript.new()
	var car := FakeCar.new()
	driver._apply_mix()
	t.check(driver._update_evade_mode(car, 0.0), "evade: low-health rival starts a getaway")
	t.check(not driver._update_evade_mode(car, DriverScript.EVADE_TIME + 0.01),
		"evade: getaway ends after its timebox")
	t.check(driver._mode == DriverScript.Mode.PURSUE and driver._evade_cd == DriverScript.EVADE_COOLDOWN,
		"evade: completed getaway owes a re-engagement cooldown")
	t.check(not driver._update_evade_mode(car, 0.0), "evade: low HP cannot bypass the cooldown")
	driver._evade_cd = 0.0
	t.check(driver._update_evade_mode(car, 0.0), "evade: a later low-health episode may begin")
	car.free()
	driver.free()

func test_wounded_final_rival_drives_by_and_returns() -> void:
	var arena = ArenaScene.instantiate()
	t.root.add_child(arena)
	t.current_scene = arena
	var player = arena.get_node("Vehicle")
	var enemy = arena.get_node("Enemy1")
	for name in ["Enemy2", "Enemy3", "Enemy4"]:
		var retired: Node = arena.get_node(name)
		arena.remove_child(retired)
		retired.free()
	enemy.set_stats(load("res://data/vehicles/cricket.tres"))
	var driver = enemy.get_node("Driver")
	driver.mix = Vector3(1, 0, 0)
	player.global_position = Vector2(500, 1500)
	player.velocity = Vector2.ZERO
	player.heading = PI
	enemy.global_position = Vector2(-300, 1500)
	enemy.velocity = Vector2.RIGHT * 260.0
	enemy.heading = 0.0
	enemy.get_node("Health").hp = 5.0
	_immunize(player)
	_immunize(enemy)
	var director = arena.get_node("AIFightDirector")
	director.refresh_now()
	t.check(driver.get_duel_target() == player, "duel: sole living mook is assigned to the player")

	# Death/respawn gate: a dead player is not a duel participant; restoring HP
	# reissues the assignment on the same refresh seam used by campaign respawn.
	var saved_hp: float = player.get_node("Health").hp
	player.get_node("Health").hp = 0.0
	director.refresh_now()
	t.check(driver.get_duel_target() == null, "duel: player death clears the assignment")
	player.get_node("Health").hp = saved_hp
	director.refresh_now()
	t.check(driver.get_duel_target() == player, "duel: respawn restores the assignment")

	var entered_break := false
	var left_break := false
	var returned := false
	var ever_evaded := false
	var peak := 0.0
	for i in MAX_FRAMES:
		await t.physics_frame
		var dist: float = enemy.global_position.distance_to(player.global_position)
		ever_evaded = ever_evaded or driver._mode == DriverScript.Mode.EVADE
		if driver._mode == DriverScript.Mode.BREAK:
			entered_break = true
			peak = maxf(peak, dist)
		elif entered_break:
			left_break = true
			peak = maxf(peak, dist)
			if peak >= MIN_SEPARATION and dist <= peak - RETURN_GAIN:
				returned = true
				break
	t.check(entered_break, "duel: wounded final rival enters a committed attack run")
	t.check(left_break and peak >= MIN_SEPARATION,
		"duel: attack run opens real separation (peak %.0fpx)" % peak)
	t.check(returned, "duel: rival turns back toward the player after the pass")
	t.check(not ever_evaded, "duel: wounded final rival never falls into EVADE")

	t.current_scene = null
	t.root.remove_child(arena)
	arena.free()
