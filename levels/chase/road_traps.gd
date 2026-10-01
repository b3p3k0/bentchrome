extends RefCounted
## Route 666's traps: set pieces the Buzzardz left on the road ahead of you.
## chunk_builder hands each one a chunk root, the centreline x at the trap's
## station, the asphalt half-width and a seeded rng; everything here is a
## child of that root, in chunk-local space (child y = -(d into chunk)).
## The rule every trap keeps: nothing on the road ever stops the car (every
## solid is a smash-and-pass destructible) and there is always a clean line
## through for a driver who reads the tell in time.

const BlockScene := preload("res://environment/destructible_block.tscn")
const HighwayDecoScript := preload("res://levels/chase/highway_deco.gd")
const LightKit := preload("res://environment/light_kit.gd")

# --- the tire wall ----------------------------------------------------------
static var TIRE_WALL_D := 760.0    # d into the chunk the row stands at
static var TIRE_SIZE := 56.0       # a stack's footprint
static var TIRE_PITCH := 60.0      # px between stack centres along the row
static var TIRE_HP := 22.0         # a smash costs ~2.6 hull and keeps most of the momentum
static var GAP_STACKS := 4         # stacks left out of the row: 4 = a lane-wide gap (~244 px)
static var TIRE_BURN_DPS := 3.0    # the touch: a few seconds of light DoT (nitro blows it out)
static var TIRE_BURN_T := 3.0
static var TIRE_GLOW_R := 90.0

## A row of burning tire stacks across the asphalt with one lane-wide gap,
## dealt left / centre / right by the seed. Every stack is a 22-HP `tires`
## destructible that hands the car a burn on contact; each carries a
## wreck_fire (flame licks + smoke) and a glow that die with the stack. Skids
## run through the gap — somebody already found the line.
static func tire_wall(root: Node2D, c: float, half: float, rng: RandomNumberGenerator) -> void:
	var d := TIRE_WALL_D
	var slots := int(floorf((half * 2.0 - TIRE_SIZE) / TIRE_PITCH)) + 1
	var x0 := c - float(slots - 1) * TIRE_PITCH * 0.5
	var lane := rng.randi_range(-1, 1)
	var gap_x := c + float(lane) * half * 2.0 / 3.0
	# At least one stack stays on either flank: the gap is a hole in the wall,
	# never the wall stopping short of the verge.
	var gap_start := clampi(roundi((gap_x - x0) / TIRE_PITCH - float(GAP_STACKS - 1) * 0.5), 1, slots - GAP_STACKS - 1)
	# Soot and melted rubber under the row, before the stacks (z -1 paint): a
	# ragged band, never a ruled slab.
	var near := PackedVector2Array()
	var far := PackedVector2Array()
	for k in 13:
		var x := c - half + half * 2.0 * float(k) / 12.0
		near.append(Vector2(x, -(d - 40.0 - rng.randf_range(0.0, 36.0))))
		far.append(Vector2(x, -(d + 40.0 + rng.randf_range(0.0, 50.0))))
	var soot := Polygon2D.new()
	soot.name = "TireSoot"
	var soot_pts := PackedVector2Array()
	soot_pts.append_array(near)
	for k in range(far.size() - 1, -1, -1):
		soot_pts.append(far[k])
	soot.polygon = soot_pts
	soot.color = Color(0.04, 0.04, 0.04, 0.3)
	soot.z_index = -1
	root.add_child(soot)
	for i in slots:
		if i >= gap_start and i < gap_start + GAP_STACKS:
			continue
		var pos := Vector2(x0 + float(i) * TIRE_PITCH + rng.randf_range(-4.0, 4.0), -(d + rng.randf_range(-8.0, 8.0)))
		var stack := BlockScene.instantiate()
		stack.name = "Tires%d" % i
		stack.position = pos
		stack.rotation = rng.randf_range(-0.4, 0.4)
		stack.size = Vector2(TIRE_SIZE, TIRE_SIZE)
		stack.max_hp = TIRE_HP
		stack.deco = &"tires"
		stack.touch_effect = &"burn"
		stack.touch_magnitude = TIRE_BURN_DPS
		stack.touch_duration = TIRE_BURN_T
		root.add_child(stack)
		var fire := Node2D.new()
		fire.set_script(HighwayDecoScript)
		fire.name = "TireFire%d" % i
		fire.kind = &"wreck_fire"
		fire.position = pos + Vector2(rng.randf_range(-6.0, 6.0), -8.0)
		root.add_child(fire)
		var glow := LightKit.make_light(TIRE_GLOW_R, 0.45, Color(1.0, 0.5, 0.18))
		glow.name = "TireGlow%d" % i
		glow.position = pos
		root.add_child(glow)
		# The fire goes out with the stack: a smashed pile is scorch, not a torch.
		stack.flattened.connect(func() -> void:
			if is_instance_valid(fire):
				fire.queue_free()
			if is_instance_valid(glow):
				glow.queue_free())
	# Skids through the gap: the Buzzardz came this way.
	var gx := x0 + (float(gap_start) + float(GAP_STACKS - 1) * 0.5) * TIRE_PITCH
	for lane_off in [-16.0, 16.0]:
		var skid := Polygon2D.new()
		var a := Vector2(gx + lane_off + rng.randf_range(-10.0, 10.0), -(d - 220.0))
		var b := Vector2(gx + lane_off, -(d + 140.0))
		skid.polygon = PackedVector2Array([a + Vector2(-4, 0), a + Vector2(4, 0), b + Vector2(4, 0), b + Vector2(-4, 0)])
		skid.color = Color(0.07, 0.07, 0.08, 0.6)
		skid.z_index = -1
		root.add_child(skid)
