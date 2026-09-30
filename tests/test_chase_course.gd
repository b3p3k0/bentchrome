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
		if def.has("river"):
			var r: Dictionary = def["river"]
			t.check(r["bank"] < r["brink"] and r["brink"] < r["deep_to"] and r["deep_to"] < r["shallow_to"]
				and r["shallow_to"] < def["len"], "course: %s's river runs bank < brink < deep < shallows < end" % name)
			t.check(r["pad_d"] > r["bank"] and r["pad_d"] + 112.0 <= r["brink"],
				"course: %s's launch lip sits on the deck, short of the brink" % name)
			t.check(not def.has("path") and is_zero_approx(def["exit_dx"]), "course: %s is dead straight (the channel is an axis-aligned rect)" % name)
			t.check(not ChunkDefs.WEIGHTS.has(name) and not (name in ChunkDefs.RARE) and not (name in ChunkDefs.NO_REPEAT),
				"course: %s is never rolled — the finale splices it in" % name)
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
	var pillars := 0
	var deck := false
	for child in over.get_children():
		if child is StaticBody2D and child.collision_layer == 2:
			statics += 1
		var script = child.get_script()
		if script and script.resource_path.ends_with("destructible_block.gd") and child.deco == &"pillar":
			pillars += 1
			t.check(child.max_hp >= 40.0, "builder: a pillar is the heaviest thing on the road")
		if child is Polygon2D and child.z_index == 1:
			deck = true
	t.check(statics == 2, "builder: overpass = 2 embankments (got %d)" % statics)
	t.check(pillars == 2, "builder: 2 pillars, smashable like everything else on the road (got %d)" % pillars)
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

## The bridge is out: a real deep channel the finale's numbers are measured
## against, shallows either side, the deck drawn OVER the water, and a launch
## lip that launches the birds but never the player.
func test_builder_bridge_out() -> void:
	var def: Dictionary = ChunkDefs.DEFS[&"bridge_out"]
	var r: Dictionary = def["river"]
	var chunk: Node2D = Builder.build(_entry_for(&"bridge_out"))
	var river: Node = null
	var deck_i := -1
	var river_i := -1
	var pad: Node = null
	var water := 0
	var walls := 0
	var kids := chunk.get_children()
	for i in kids.size():
		var child = kids[i]
		var script = child.get_script()
		var path: String = script.resource_path if script else ""
		if path.ends_with("deep_water_zone.gd"):
			river = child
			river_i = i
		elif path.ends_with("jump_pad.gd"):
			pad = child
		elif child is Area2D and child.collision_layer == 128 and child.terrain_type == &"water":
			water += 1
		elif child is StaticBody2D and child.collision_layer == 2:
			walls += 1
		if child.name == "Deck":
			deck_i = i
	t.check(river != null, "bridge: the channel is a real deep_water_zone")
	if river != null:
		t.check(is_equal_approx(river.size.y, float(r["deep_to"]) - float(r["brink"])),
			"bridge: the channel runs brink to deep_to (%d)" % int(river.size.y))
		t.check(is_equal_approx(river.position.y, -(float(r["brink"]) + float(r["deep_to"])) * 0.5),
			"bridge: and sits centred on it")
		t.check(river.size.x > (float(def["half_w"]) + 90.0 + 130.0) * 2.0, "bridge: the river spans the whole corridor")
		t.check(river.z_index == -1, "bridge: water paints under the cars")
	t.check(deck_i > river_i, "bridge: the deck draws over the water")
	t.check(water >= 3, "bridge: shallows on the far shore and either side of the deck (%d)" % water)
	t.check(walls == 2, "bridge: the valley sides still run the whole mile")
	t.check(pad != null and not pad.launch_player and pad.launch_rivals,
		"bridge: the lip launches the birds, never the player")
	if pad != null:
		t.check(is_equal_approx(pad.position.y, -float(r["pad_d"])) and not pad.visible,
			"bridge: the lip sits on the deck's last stretch and paints nothing of its own")
		var col := pad.get_node_or_null(^"Col") as CollisionShape2D
		t.check(col != null and col.shape is RectangleShape2D and float(r["pad_d"]) + col.shape.size.y * 0.5 < float(r["brink"]),
			"bridge: the lip's rect ends short of the brink")
	var flair := 0
	for child in kids:
		if child is Polygon2D and child.z_index == 0 and child.position == Vector2.ZERO:
			for p in child.polygon:
				if -p.y > float(r["bank"]) and -p.y < float(r["shallow_to"]):
					flair += 1
					break
	t.check(flair == 0, "bridge: no bushes grow out of the river")
	chunk.free()
	# The pad's new gate, the other way round: an arena pad still launches everyone.
	var stock: Node = load("res://environment/jump_pad.gd").new()
	t.check(stock.launch_player and stock.launch_rivals, "bridge: a stock pad launches player and rivals alike")
	stock.free()

## Washout: dirt edge to edge except for the surviving paved ribbon — two
## dirt zones, one each side of it, and a line a lane-wheel car can hold.
func test_builder_washout() -> void:
	const Pedal := preload("res://levels/chase/chase_player_driver.gd")
	for name in [&"washout_l", &"washout_r"]:
		var def: Dictionary = ChunkDefs.DEFS[name]
		var w: Dictionary = def["washout"]
		var chunk: Node2D = Builder.build(_entry_for(name))
		var zones := {}
		for child in chunk.get_children():
			if child is Area2D and child.collision_layer == 128 and String(child.name).begins_with("Washout"):
				zones[String(child.name)] = child
		t.check(zones.size() == 2 and zones.has("WashoutL") and zones.has("WashoutR"),
			"washout: %s lays a dirt zone each side of the ribbon" % name)
		for zname in zones:
			t.check(zones[zname].terrain_type == &"dirt", "washout: %s is dirt" % zname)
		t.check(chunk.get_node_or_null(^"WashoutBedL") != null and chunk.get_node_or_null(^"WashoutBedR") != null,
			"washout: %s paints both beds" % name)
		chunk.free()
		# The ribbon: wide enough to hold, inside the road, and its crossover is
		# no steeper than the lane wheel can follow (give or take the ribbon's width).
		t.check(float(w["lane_w"]) >= 160.0, "washout: the ribbon is a lane and a half wide")
		var pts: Array = w["lane"]
		var lock := tan(deg_to_rad(Pedal.LANE_YAW_DEG))
		for i in pts.size() - 1:
			var run: float = float(pts[i + 1][0]) - float(pts[i][0])
			var rise: float = absf(float(pts[i + 1][1]) - float(pts[i][1]))
			t.check(maxf(rise / run - lock, 0.0) * run < float(w["lane_w"]) * 0.25,
				"washout: %s leg %d can be held at full lock" % [name, i])
		for pt in pts:
			t.check(absf(float(pt[1])) + float(w["lane_w"]) * 0.5 < float(def["half_w"]) - 20.0,
				"washout: the ribbon stays on the road")
		t.check(is_equal_approx(ChunkDefs.washout_lane(def, 0.0), float(pts[0][1]))
			and is_equal_approx(ChunkDefs.washout_lane(def, float(def["len"])), float(pts[pts.size() - 1][1])),
			"washout: the ribbon holds its first and last station past the ends")
		var mid: float = ChunkDefs.washout_lane(def, (float(pts[1][0]) + float(pts[2][0])) * 0.5)
		t.check(absf(mid) < 1.0, "washout: mid-crossover the ribbon is on the centreline (%.1f)" % mid)
	var l: Dictionary = ChunkDefs.DEFS[&"washout_l"]
	var r: Dictionary = ChunkDefs.DEFS[&"washout_r"]
	t.check(is_equal_approx(ChunkDefs.washout_lane(l, 1400.0), ChunkDefs.washout_lane(r, 0.0)),
		"washout: the pair chain — one ends on the side the other begins")
	t.check(&"washout_l" in ChunkDefs.NO_REPEAT and &"washout_r" in ChunkDefs.NO_REPEAT,
		"washout: never the same one twice running")

func test_builder_momentum_obstacles() -> void:
	var pchunk: Node2D = Builder.build(_entry_for(&"bad_road"))
	var pits := 0
	var oil := 0
	var holes := 0
	for child in pchunk.get_children():
		if child is Area2D and child.collision_layer == 128:
			for sub in child.get_children():
				if sub is CollisionShape2D and sub.shape is CircleShape2D:
					pits += 1  # shoulders are rect strips; only hazards are circles
					if child.terrain_type == &"ice":
						oil += 1
					elif child.terrain_type == &"dirt":
						holes += 1
					break
	t.check(pits == 5, "builder: the bad road spills five hazards (got %d)" % pits)
	t.check(oil == 2 and holes == 3, "builder: oil is ice and potholes are dirt — two reads, two feels (%d/%d)" % [oil, holes])
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
	# The splice: forget the built future from a cut, rewrite the plan there,
	# and the next frames rebuild the new entries — lowest index first.
	var cut: int = course.chunk_index_at(8000.0) + 2
	t.check(streamer._live.has(cut), "streamer: the cut lands inside the built window")
	var doomed: Node = streamer._live[cut]
	streamer.invalidate_from(cut)
	for i in streamer._live:
		t.check(i < cut, "streamer: nothing built past the cut survives")
	course.splice(cut, [&"washout_l", &"straight"])
	await t.physics_frame
	await t.physics_frame
	t.check(not is_instance_valid(doomed), "streamer: the old chunk at the cut is freed")
	t.check(streamer._live.has(cut) and course.plan[cut]["name"] == &"washout_l",
		"streamer: the spliced chunk is rebuilt first")
	await t.physics_frame
	t.check(streamer._live.has(cut + 1), "streamer: then the one after it")
	var stale := false
	for i in streamer._live:
		if i >= course.plan.size():
			stale = true
	t.check(not stale, "streamer: no live chunk outlives its plan entry")
	t.current_scene = null
	t.root.remove_child(container)
	container.free()

## The course can be rewritten from a chunk on (the finale's river): the cut
## keeps every continuity rule _append already enforces, and the plan reads
## sanely past its new end.
func test_splice_rewrites_the_future() -> void:
	var c = _course()
	var before: int = c.plan.size()
	var at: int = c.chunk_index_at(20000.0) + 1
	var prev: Dictionary = c.plan[at - 1]
	c.splice(at, [&"washout_l", &"straight", &"straight"])
	t.check(c.plan.size() == at + 3 and c.plan.size() < before, "course: the plan is the cut plus the new tail")
	var first: Dictionary = c.plan[at]
	t.check(first["name"] == &"washout_l", "course: the first new chunk is the one asked for")
	t.check(is_equal_approx(first["entry_x"], prev["exit_x"]), "course: the seam keeps the centreline")
	t.check(is_equal_approx(first["start_d"], float(prev["start_d"]) + float(prev["def"]["len"])),
		"course: the seam keeps the distance chain")
	t.check(is_equal_approx(first["entry_half_w"], prev["def"]["half_w"]), "course: and the width taper")
	var last: Dictionary = c.plan[c.plan.size() - 1]
	t.check(is_equal_approx(c.total_len, float(last["start_d"]) + float(last["def"]["len"])),
		"course: total_len is the new end")
	t.check(c.chunk_index_at(c.total_len - 1.0) == c.plan.size() - 1, "course: the index search finds the new last chunk")
	var past: Dictionary = c.sample(c.total_len + 500.0)
	t.check(past["half_w"] > 0.0, "course: sampling past the new end stays safe")
	c.splice(0, [&"straight"])
	t.check(c.plan.size() == 2 and c.plan[0]["start_d"] == 0.0, "course: a cut is never below the launch chunk")

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
