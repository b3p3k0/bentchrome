extends RefCounted
## The remains contract: destroyed props flatten in place into deterministic,
## bounded, visual-only debris — plus the two cross-cutting seams that keep
## the world honest about it (radar liveness, the tutorial smash census).
## Driven by run_tests.gd.

const RemainsPaint := preload("res://environment/remains_paint.gd")
const RadarScript := preload("res://ui/radar.gd")
const BlockScene := preload("res://environment/destructible_block.tscn")

var t

func _init(runner) -> void:
	t = runner

func test_generate_deterministic() -> void:
	var a := RemainsPaint.generate(Vector2(48, 48), &"debris", Color.RED, Color.BLACK, 777)
	var b := RemainsPaint.generate(Vector2(48, 48), &"debris", Color.RED, Color.BLACK, 777)
	t.check(a.size() > 1 and a.size() == b.size(), "remains: same seed, same mark count")
	var identical := true
	for i in a.size():
		if a[i] != b[i]:
			identical = false
	t.check(identical, "remains: same inputs regenerate element-identical rubble")
	var other := RemainsPaint.generate(Vector2(48, 48), &"debris", Color.RED, Color.BLACK, 778)
	var differs := other.size() != a.size()
	for i in mini(other.size(), a.size()):
		if other[i] != a[i]:
			differs = true
	t.check(differs, "remains: a different seed rolls different rubble")

## Every flavor stays inside the spill bound at every footprint shape — the
## thin guardrail strip (75x6) is the degenerate case that matters.
func test_every_flavor_stays_in_bounds() -> void:
	for flavor in [&"debris", &"scorch", &"splinter", &"crumple"]:
		for half in [Vector2(24, 24), Vector2(48, 48), Vector2(75, 6), Vector2(96, 32)]:
			var marks := RemainsPaint.generate(half, flavor, Color.RED, Color.BLACK, 4242)
			t.check(not marks.is_empty(), "remains: %s %s has marks" % [flavor, half])
			var limit: Vector2 = half * RemainsPaint.SPILL + Vector2(0.01, 0.01)
			var inside := true
			for m in marks:
				if m.kind == &"blob":
					if absf(m.pos.x) + m.radius > limit.x or absf(m.pos.y) + m.radius > limit.y:
						inside = false
				else:
					for p in m.points:
						if absf(p.x) > limit.x or absf(p.y) > limit.y:
							inside = false
			t.check(inside, "remains: %s %s stays inside the spill bound" % [flavor, half])

## The smash lesson counts live tutorial_smash members — flattened remains
## must leave the group or the syllabus jams forever.
func test_dead_block_leaves_tutorial_smash() -> void:
	var block = BlockScene.instantiate()
	block.add_to_group(&"tutorial_smash")
	t.root.add_child(block)
	t.check(block.is_in_group(&"tutorial_smash"), "smash census: live block counted")
	block.get_node("Health").take_damage(999.0)
	t.check(not block.is_in_group(&"tutorial_smash"),
		"smash census: remains never count as standing targets")
	t.root.remove_child(block)
	block.free()

## The map paints only geometry that still blocks: alive -> painted, remains
## -> dropped, freed -> dropped. (Also the fix for hidden arena tombstones
## painting as live cover forever.)
func test_radar_drops_remains() -> void:
	var block = BlockScene.instantiate()
	t.root.add_child(block)
	t.check(RadarScript.breakable_alive(block), "radar: live breakable paints")
	block.get_node("Health").take_damage(999.0)
	t.check(not RadarScript.breakable_alive(block), "radar: remains drop off the map")
	t.root.remove_child(block)
	block.free()
	t.check(not RadarScript.breakable_alive(null), "radar: absent refs stay dropped")
