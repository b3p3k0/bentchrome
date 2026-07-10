extends RefCounted
## The Buzzard Run course: seeded pre-roll determinism, socket continuity,
## meander bounds, pickup cadence, seam-tapered widths, and the chunk builder's
## structural output (asphalt, verge zones, embankment walls, props, pickups).

const CourseScript := preload("res://levels/chase/chase_course.gd")
const ChunkDefs := preload("res://levels/chase/chunk_defs.gd")
const Builder := preload("res://levels/chase/chunk_builder.gd")
const StreamerScript := preload("res://levels/chase/course_streamer.gd")
const HealScene := preload("res://environment/heal_pickup.tscn")
const HealthScript := preload("res://vehicles/health.gd")

var t

func _init(runner) -> void:
	t = runner

func _course(seed_val := 1234):
	var c = CourseScript.new()
	c.pre_roll(seed_val)
	return c

func test_defs_sane() -> void:
	for name in ChunkDefs.DEFS:
		var def: Dictionary = ChunkDefs.DEFS[name]
		t.check(def["len"] > 0.0 and def["half_w"] > 0.0, "course: %s has positive extents" % name)
		if def.has("path"):
			var last := 0.0
			for pt in def["path"]:
				t.check(pt[0] > last and pt[0] < def["len"], "course: %s path stations ascend inside the chunk" % name)
				last = pt[0]
		for key in ["props", "pickups"]:
			if def.has(key):
				for item in def[key]:
					var d: float = item["at"][0]
					var side: float = item["at"][1]
					t.check(d > 0.0 and d < def["len"], "course: %s %s inside the chunk" % [name, key])
					t.check(absf(side) <= def["half_w"] + 90.0, "course: %s %s inside the walls" % [name, key])
	for name in ChunkDefs.WEIGHTS:
		t.check(ChunkDefs.DEFS.has(name), "course: weight table names a real def (%s)" % name)

func test_preroll_deterministic_and_long_enough() -> void:
	var a = _course(77)
	var b = _course(77)
	t.check(a.plan.size() == b.plan.size(), "course: same seed, same chunk count")
	var same := true
	for i in a.plan.size():
		if a.plan[i]["name"] != b.plan[i]["name"] or a.plan[i]["exit_x"] != b.plan[i]["exit_x"]:
			same = false
	t.check(same, "course: same seed, identical plan")
	t.check(a.total_len >= CourseScript.TARGET_LEN, "course: outlasts a top-speed run (%d px)" % int(a.total_len))

func test_sockets_chain_and_meander_bounded() -> void:
	var c = _course()
	var ok_x := true
	var ok_d := true
	var ok_bound := true
	var ok_repeat := true
	for i in range(1, c.plan.size()):
		var prev: Dictionary = c.plan[i - 1]
		var cur: Dictionary = c.plan[i]
		var prev_def: Dictionary = prev["def"]
		if absf(cur["entry_x"] - prev["exit_x"]) > 0.01:
			ok_x = false
		if absf(cur["start_d"] - (prev["start_d"] + prev_def["len"])) > 0.01:
			ok_d = false
		if absf(cur["exit_x"]) > CourseScript.SPINE_BOUND + 461.0:
			ok_bound = false
		if cur["name"] == prev["name"] and cur["name"] in ChunkDefs.NO_REPEAT:
			ok_repeat = false
	t.check(ok_x, "course: entry sockets meet exit sockets")
	t.check(ok_d, "course: distances chain without gaps")
	t.check(ok_bound, "course: meander stays near the spine")
	t.check(ok_repeat, "course: no back-to-back technical chunks")

func test_pickup_cadence() -> void:
	var c = _course(9)
	var last_start := 0.0
	var worst := 0.0
	for entry in c.plan:
		if entry["name"] == &"pickup":
			worst = maxf(worst, entry["start_d"] - last_start)
			last_start = entry["start_d"]
	t.check(last_start > 0.0, "course: pickup chunks exist")
	t.check(worst <= 12000.0, "course: longest pickup drought %d px" % int(worst))

func test_sample_continuous_and_tapered() -> void:
	var c = _course()
	var ok := true
	for i in range(1, mini(c.plan.size(), 40)):
		var seam: float = c.plan[i]["start_d"]
		var before: Dictionary = c.sample(seam - 2.0)
		var after: Dictionary = c.sample(seam + 2.0)
		if absf(before["x"] - after["x"]) > 10.0:
			ok = false
	t.check(ok, "course: centerline continuous across seams")
	var narrow_i := -1
	for i in c.plan.size():
		if c.plan[i]["name"] == &"narrow":
			narrow_i = i
			break
	t.check(narrow_i > 0, "course: a narrow rolled")
	if narrow_i > 0:
		var start: float = c.plan[narrow_i]["start_d"]
		var at_seam: Dictionary = c.sample(start + 1.0)
		var past_taper: Dictionary = c.sample(start + 320.0)
		t.check(at_seam["half_w"] > 400.0, "course: narrow entry keeps the wide width")
		t.check(is_equal_approx(past_taper["half_w"], 260.0), "course: narrow reaches its width past the taper")

func test_builder_structure() -> void:
	var c = _course()
	var chunk: Node2D = Builder.build(c.plan[0])
	var asphalt := chunk.get_node_or_null(^"Asphalt") as Polygon2D
	t.check(asphalt != null and asphalt.polygon.size() >= 8, "builder: asphalt strip painted")
	var walls := 0
	var zones := 0
	for child in chunk.get_children():
		if child is StaticBody2D and child.collision_layer == 2:
			var poly := 0
			for sub in child.get_children():
				if sub is CollisionPolygon2D:
					poly += 1
			if poly == 1:
				walls += 1
		if child is Area2D and child.collision_layer == 128:
			zones += 1
	t.check(walls == 2, "builder: two embankment walls on layer 2 (got %d)" % walls)
	t.check(zones == 2, "builder: two verge terrain zones (got %d)" % zones)
	chunk.free()
	var pickup_i := -1
	var slalom_i := -1
	for i in c.plan.size():
		if pickup_i < 0 and c.plan[i]["name"] == &"pickup":
			pickup_i = i
		if slalom_i < 0 and c.plan[i]["name"] == &"slalom":
			slalom_i = i
	if pickup_i >= 0:
		var pchunk: Node2D = Builder.build(c.plan[pickup_i])
		var heals := 0
		var crates := 0
		for child in pchunk.get_children():
			var script = child.get_script()
			if script and script.resource_path.ends_with("heal_pickup.gd"):
				heals += 1
			if script and script.resource_path.ends_with("ammo_pickup.gd"):
				crates += 1
		t.check(heals == 1 and crates == 1, "builder: pickup chunk carries medkit + crate")
		pchunk.free()
	if slalom_i >= 0:
		var schunk: Node2D = Builder.build(c.plan[slalom_i])
		var wrecks := 0
		for child in schunk.get_children():
			var script = child.get_script()
			if script and script.resource_path.ends_with("derelict_car.gd"):
				wrecks += 1
		t.check(wrecks == 3, "builder: slalom seeds its derelicts (got %d)" % wrecks)
		schunk.free()

func test_streamer_builds_window_and_frees_behind() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container
	var course = _course()
	var target := Node2D.new()
	target.position = Vector2(0, 0)
	container.add_child(target)
	var streamer = StreamerScript.new()
	streamer.course = course
	streamer.target = target
	container.add_child(streamer)
	for i in 8:
		await t.physics_frame
	var live_at_start: int = streamer._live.size()
	t.check(live_at_start >= 3, "streamer: window builds ahead (got %d chunks)" % live_at_start)
	t.check(streamer._live.has(0), "streamer: launch chunk live")
	target.position = Vector2(0, -8000)  # drive 8000 px north
	for i in 16:
		await t.physics_frame
	t.check(not streamer._live.has(0), "streamer: far-behind chunk freed")
	var min_i := 99999
	var max_i := -1
	for i in streamer._live:
		min_i = mini(min_i, i)
		max_i = maxi(max_i, i)
	var min_start: float = course.plan[min_i]["start_d"]
	var max_start: float = course.plan[max_i]["start_d"]
	t.check(min_start >= 8000.0 - StreamerScript.BEHIND - 1600.0, "streamer: trail keeps the wall corridor")
	t.check(max_start <= 8000.0 + StreamerScript.AHEAD, "streamer: build horizon bounded")
	t.current_scene = null
	t.root.remove_child(container)
	container.free()

func test_heal_pickup_heals_player_only() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var pickup = HealScene.instantiate()
	container.add_child(pickup)
	var stranger := Node2D.new()
	container.add_child(stranger)
	pickup._on_body_entered(stranger)
	t.check(is_instance_valid(pickup) and not pickup.is_queued_for_deletion(),
		"heal: ignores non-players")
	var player := Node2D.new()
	player.add_to_group(&"player")
	var health = HealthScript.new()
	health.name = "Health"
	player.add_child(health)
	container.add_child(player)
	health.max_hp = 100.0
	health.hp = 100.0
	pickup._on_body_entered(player)
	t.check(not pickup.is_queued_for_deletion(), "heal: full tank banks the medkit")
	health.hp = 50.0
	pickup._on_body_entered(player)
	t.check(is_equal_approx(health.hp, 75.0), "heal: +25 on the damaged player")
	t.check(pickup.is_queued_for_deletion(), "heal: one shot, gone")
	t.root.remove_child(container)
	container.free()
