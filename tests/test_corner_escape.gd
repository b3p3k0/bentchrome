extends RefCounted
## Integration repro for the corner trap: an enemy pinned in the arena's
## top-right corner (walls meet at 1500, -1300) while fleeing the player must
## back out and get clear instead of grinding into the walls. Runs the real
## arena scene and pumps physics frames (the runner awaits test methods).

const ArenaScene := preload("res://levels/arena/arena.tscn")

const CORNER := Vector2(1500.0, -1300.0)
const ESCAPE_DIST := 500.0
const MAX_FRAMES := 360  # 6s at 60 Hz; a working escape takes ~2-3s

var t

func _init(runner) -> void:
	t = runner

func test_pinned_enemy_escapes_top_right_corner() -> void:
	var arena = ArenaScene.instantiate()
	t.root.add_child(arena)
	t.current_scene = arena  # weapon mounts spawn projectiles into current_scene
	var enemy = arena.get_node("Enemy1")
	var player = arena.get_node("Vehicle")
	# Recreate the report: enemy tucked into the corner nose-first, player
	# pressuring from the open arena so "away from threat" points into the walls.
	enemy.global_position = Vector2(1420.0, -1220.0)
	enemy.heading = -PI / 4
	player.global_position = Vector2(1000.0, -800.0)
	# Force flee mode (HP under the aggressor threshold) but keep it unkillable
	# so a stray shot can't end the test early.
	var health = enemy.get_node("Health")
	health.hp = 5.0
	health.invulnerable = true
	# Park the other combatants out of scan range so nothing rams it free.
	for name in ["Enemy2", "Enemy3", "Enemy4"]:
		arena.get_node(name).global_position = Vector2(-1300.0, 1400.0)

	var escaped_at := -1
	for i in MAX_FRAMES:
		await t.physics_frame
		if enemy.global_position.distance_to(CORNER) > ESCAPE_DIST:
			escaped_at = i
			break
	t.check(escaped_at >= 0, "corner: pinned enemy gets 500px clear within 6s (escaped_at=%d)" % escaped_at)

	t.current_scene = null
	t.root.remove_child(arena)
	arena.free()
