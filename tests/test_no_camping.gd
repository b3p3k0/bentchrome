extends RefCounted
## No-camping contract: every enemy must be moving from the opening bell. The
## city spawns everyone beyond scan range, and drivers HUNT when the scan is
## empty — parking is not a strategy. Runs the real arena and pumps ~2s of
## physics (the runner awaits test methods).

const ArenaScene := preload("res://levels/downtown/downtown.tscn")
const ENEMIES := ["Enemy1", "Enemy2", "Enemy3", "Enemy4"]
const FRAMES := 180           # 3 seconds — a heavy needs time to U-turn off the line
const MIN_DISPLACEMENT := 100.0

var t

func _init(runner) -> void:
	t = runner

func test_all_enemies_move_at_round_start() -> void:
	var arena = ArenaScene.instantiate()
	t.root.add_child(arena)
	t.current_scene = arena  # weapon mounts spawn projectiles into current_scene
	# Immunize everyone: armed free-for-all AI must not end the round mid-test
	# (the end screen would pause the tree and stall the frame pump). The player
	# is shielded via a LONG invuln effect, not just the Health flag — the
	# level-start blink shield expires mid-test and its status tick would sync
	# the bare flag back to false.
	arena.get_node("Vehicle").get_node("Health").invulnerable = true
	var forever := StatusEffectSpec.new()
	forever.kind = &"invuln"
	forever.duration = 9999.0
	arena.get_node("Vehicle").apply_effect(forever)
	# Pin every enemy to the worst launcher (mass-8 truck, pure aggressor) —
	# the arena re-rolls cars on boot and a lucky light-car draw would hide a
	# camping regression. Same input-pinning rule as test_corner_escape.
	var starts := {}
	for name in ENEMIES:
		var enemy = arena.get_node(name)
		enemy.set_stats(load("res://data/vehicles/hammertoe.tres"))
		enemy.get_node("Driver").mix = Vector3(1, 0, 0)
		enemy.get_node("Health").invulnerable = true
		starts[name] = enemy.global_position
	for i in FRAMES:
		await t.physics_frame
	for name in ENEMIES:
		var enemy = arena.get_node_or_null(name)
		var moved: float = enemy.global_position.distance_to(starts[name]) if enemy else 0.0
		t.check(moved > MIN_DISPLACEMENT, "%s hunts from the opening bell (moved %.0fpx)" % [name, moved])
	t.root.remove_child(arena)
	arena.free()
