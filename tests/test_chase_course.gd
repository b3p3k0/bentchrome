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
		if def.has("median"):
			for m in def["median"]:
				t.check(m["from"] >= 0.0 and m["to"] > m["from"] and m["to"] <= def["len"],
					"course: %s median run inside the chunk" % name)
				t.check(m["half_w"] < def["half_w"],
					"course: %s median leaves lanes both sides" % name)
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
		t.check(at_seam["half_w"] > 340.0, "course: narrow entry keeps the wide width")
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
		var boosts := 0
		var crates := 0
		for child in pchunk.get_children():
			var script = child.get_script()
			if script and script.resource_path.ends_with("heal_pickup.gd"):
				if child.kind == &"boost":
					boosts += 1
				else:
					heals += 1
			if script and script.resource_path.ends_with("ammo_pickup.gd"):
				crates += 1
		t.check(heals == 1 and crates == 1 and boosts == 1,
			"builder: pickup chunk carries medkit + crate + nitro")
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

## A standalone plan entry for a def (what chase_course._append builds), so
## builder tests don't depend on a def rolling in some seed.
func _entry_for(name: StringName) -> Dictionary:
	var def: Dictionary = ChunkDefs.DEFS[name]
	var stations: Array = [Vector2.ZERO]
	if def.has("path"):
		for pt in def["path"]:
			stations.append(Vector2(pt[0], pt[1]))
	stations.append(Vector2(def["len"], def["exit_dx"]))
	return {"name": name, "def": def, "start_d": 0.0, "entry_x": 0.0,
		"exit_x": def["exit_dx"], "entry_half_w": def["half_w"], "stations": stations}

func test_builder_medians() -> void:
	var divided: Node2D = Builder.build(_entry_for(&"divided"))
	var zones := 0
	var rails := 0
	for child in divided.get_children():
		if child is Area2D and child.collision_layer == 128:
			zones += 1
		var script = child.get_script()
		if script and script.resource_path.ends_with("destructible_block.gd") \
				and child.deco == &"rail":
			rails += 1
	t.check(zones == 3, "builder: divided = 2 shoulders + 1 grass median (got %d)" % zones)
	t.check(rails >= 2, "builder: divided caps its median with rails (got %d)" % rails)
	divided.free()
	var chicane: Node2D = Builder.build(_entry_for(&"chicane"))
	var weave_rails := 0
	var on_spine := true
	for child in chicane.get_children():
		var script = child.get_script()
		if script and script.resource_path.ends_with("destructible_block.gd") \
				and child.deco == &"rail":
			weave_rails += 1
			var cd: float = -child.position.y
			var want_x: float = Builder._center_x(_entry_for(&"chicane"), cd)
			if absf(child.position.x - want_x) > 5.0:
				on_spine = false
	t.check(weave_rails >= 5, "builder: chicane rails run the weave (got %d)" % weave_rails)
	t.check(on_spine, "builder: weave rails ride the centerline")
	chicane.free()

func test_rare_set_pieces_spaced() -> void:
	for seed_val in [11, 222, 3333]:
		var c = _course(seed_val)
		var last_rare := -CourseScript.RARE_SPACING
		var ok := true
		var seen := 0
		for entry in c.plan:
			if entry["name"] in ChunkDefs.RARE:
				seen += 1
				if entry["start_d"] - last_rare < CourseScript.RARE_SPACING:
					ok = false
				last_rare = entry["start_d"]
		t.check(ok, "course: landmarks spaced >= %dk (seed %d)" % [int(CourseScript.RARE_SPACING / 1000.0), seed_val])
		t.check(seen >= 3, "course: the run gets its landmarks (seed %d, %d)" % [seed_val, seen])

func test_builder_set_pieces_and_flair() -> void:
	var over: Node2D = Builder.build(_entry_for(&"overpass"))
	var statics := 0
	var deck := false
	for child in over.get_children():
		if child is StaticBody2D and child.collision_layer == 2:
			statics += 1
		if child is Polygon2D and child.z_index == 1:
			deck = true
	t.check(statics == 4, "builder: overpass = 2 embankments + 2 pillars (got %d)" % statics)
	t.check(deck, "builder: the deck rides z 1 — drive under it")
	over.free()
	var stop: Node2D = Builder.build(_entry_for(&"truckstop"))
	var pumps := 0
	var deco := 0
	for child in stop.get_children():
		var script = child.get_script()
		if script and script.resource_path.ends_with("destructible_block.gd") and child.deco == &"pump":
			pumps += 1
		if script and script.resource_path.ends_with("street_deco.gd"):
			deco += 1
	t.check(pumps == 2, "builder: truckstop pumps in (got %d)" % pumps)
	t.check(deco >= 3, "builder: neon + light pools dress the stop (got %d)" % deco)
	stop.free()
	var convoy: Node2D = Builder.build(_entry_for(&"convoy"))
	var wrecks := 0
	var loot := 0
	for child in convoy.get_children():
		var script = child.get_script()
		if script and script.resource_path.ends_with("derelict_car.gd"):
			wrecks += 1
		if script and (script.resource_path.ends_with("heal_pickup.gd")
				or script.resource_path.ends_with("ammo_pickup.gd")):
			loot += 1
	t.check(wrecks == 4 and loot == 2, "builder: convoy wreckage pays out (%d wrecks, %d loot)" % [wrecks, loot])
	convoy.free()
	var plain: Node2D = Builder.build(_entry_for(&"straight"))
	var flair := 0
	for child in plain.get_children():
		if child is Polygon2D and child.z_index == 0:
			flair += 1
	t.check(flair >= 4, "builder: roadside flair streams every chunk (got %d)" % flair)
	plain.free()

func test_builder_momentum_obstacles() -> void:
	var pchunk: Node2D = Builder.build(_entry_for(&"potholes"))
	var pits := 0
	for child in pchunk.get_children():
		if child is Area2D and child.collision_layer == 128:
			for sub in child.get_children():
				if sub is CollisionShape2D and sub.shape is CircleShape2D:
					pits += 1  # shoulders are rect strips; only pits are circles
					break
	t.check(pits == 5, "builder: potholes chunk pits the asphalt (got %d)" % pits)
	pchunk.free()
	var lchunk: Node2D = Builder.build(_entry_for(&"log_run"))
	var logs := 0
	var junk := 0
	for child in lchunk.get_children():
		var script = child.get_script()
		if script and script.resource_path.ends_with("destructible_block.gd"):
			if child.deco == &"log":
				logs += 1
			elif child.deco == &"junk":
				junk += 1
	t.check(logs == 3 and junk == 1, "builder: log run drops its timber (%d logs, %d junk)" % [logs, junk])
	lchunk.free()
	var jchunk: Node2D = Builder.build(_entry_for(&"launch"))
	var pad: Node = null
	for child in jchunk.get_children():
		var script = child.get_script()
		if script and script.resource_path.ends_with("jump_pad.gd"):
			pad = child
	t.check(pad != null, "builder: launch chunk carries a jump pad")
	if pad != null:
		t.check(pad.collision_mask == 1, "builder: pad senses ground vehicles")
		var col := pad.get_node_or_null(^"Col") as CollisionShape2D
		t.check(col != null and col.shape is RectangleShape2D \
			and (col.shape as RectangleShape2D).size == Vector2(224, 224),
			"builder: pad footprint is the canon 224 square")
	jchunk.free()

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

class FakeCtrl:
	var boost_fuel := 100.0

class FakeBooster extends Node2D:
	var ctrl = FakeCtrl.new()
	func get_controller():
		return ctrl

func test_boost_pickup_refills_nitro() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var pickup = load("res://environment/boost_pickup.tscn").instantiate()
	container.add_child(pickup)
	var player := FakeBooster.new()
	player.add_to_group(&"player")
	container.add_child(player)
	pickup._on_body_entered(player)
	t.check(not pickup.is_queued_for_deletion(), "boost: full tank banks the bottle")
	player.ctrl.boost_fuel = 80.0
	pickup._on_body_entered(player)
	t.check(is_equal_approx(player.ctrl.boost_fuel, 100.0), "boost: +35 caps at the tank (got %d)" % int(player.ctrl.boost_fuel))
	t.check(pickup.is_queued_for_deletion(), "boost: one shot, gone")
	t.root.remove_child(container)
	container.free()
