extends RefCounted
## Integration repro for the corner trap: an enemy pinned in the arena's
## top-right corner (walls meet at 1876, -1812; the city map keeps this pocket
## building-free) while fleeing the player must back out and get clear instead
## of grinding into the walls. Runs the real arena scene and pumps physics
## frames (the runner awaits test methods).

const ArenaScene := preload("res://levels/downtown/downtown.tscn")

const CORNER := Vector2(1876.0, -1812.0)
const UNPIN_DIST := 250.0   # out of the corner pocket
const UNPIN_FRAMES := 330   # ...within 5.5s (mass-7 truck 3-point turn; never stationary)
const ESCAPE_DIST := 500.0  # fully clear and re-engaging
const MAX_FRAMES := 540     # ...within 9s (mass-7 truck: slow is correct now)

var t

func _init(runner) -> void:
	t = runner

func test_pinned_enemy_escapes_top_right_corner() -> void:
	var arena = ArenaScene.instantiate()
	t.root.add_child(arena)
	t.current_scene = arena  # weapon mounts spawn projectiles into current_scene
	var enemy = arena.get_node("Enemy1")
	var player = arena.get_node("Vehicle")
	# The arena re-rolls enemy cars/mixes on boot (_randomize_enemies), so pin
	# the historical worst case explicitly: mass-7 truck, pure-aggressor mix.
	enemy.set_stats(load("res://data/vehicles/kandykane.tres"))
	enemy.get_node("Driver").mix = Vector3(1, 0, 0)
	# Recreate the report: enemy tucked into the corner nose-first, player
	# pressuring from the open arena so "away from threat" points into the walls.
	enemy.global_position = Vector2(1796.0, -1732.0)
	enemy.heading = -PI / 4
	player.global_position = Vector2(1376.0, -1312.0)
	# Force flee mode (HP under the aggressor threshold) but keep it unkillable
	# so a stray shot can't end the test early.
	var health = enemy.get_node("Health")
	health.hp = 5.0
	health.invulnerable = true
	# Enemies shoot now: an unkillable player keeps stray fire from ending the
	# round (the end screen would pause the tree and stall the frame pump).
	# Long invuln EFFECT, not just the flag — the level-start blink shield
	# expires mid-test and its status tick would sync the bare flag to false.
	player.get_node("Health").invulnerable = true
	var forever := StatusEffectSpec.new()
	forever.kind = &"invuln"
	forever.duration = 9999.0
	player.apply_effect(forever)
	# Remove the other combatants entirely — the AI hunts map-wide now, so a
	# "parked far away" car would charge back in and contaminate the budgets.
	for name in ["Enemy2", "Enemy3", "Enemy4"]:
		arena.get_node(name).queue_free()

	var unpinned_at := -1
	var escaped_at := -1
	for i in MAX_FRAMES:
		await t.physics_frame
		var d: float = enemy.global_position.distance_to(CORNER)
		if unpinned_at < 0 and d > UNPIN_DIST:
			unpinned_at = i
		if d > ESCAPE_DIST:
			escaped_at = i
			break
	t.check(unpinned_at >= 0 and unpinned_at <= UNPIN_FRAMES,
		"corner: out of the pocket within 5.5s (unpinned_at=%d)" % unpinned_at)
	t.check(escaped_at >= 0,
		"corner: fully clear (500px) within 9s (escaped_at=%d)" % escaped_at)

	t.current_scene = null
	t.root.remove_child(arena)
	arena.free()
