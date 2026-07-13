extends RefCounted
## Driver's Ed structural floor: the tutorial yard instantiates clean (never
## tree-entered — no physics, no _ready side effects), carries a player spawn
## and ZERO baked enemies, and rides the shared combat_level shell so the
## pause/end-screen/lives glue comes along for free.

const SCENE := "res://levels/tutorial/drivers_ed.tscn"

var t

func _init(runner) -> void:
	t = runner

func test_shell_structure() -> void:
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	t.check(scene.get_node_or_null("Vehicle") != null, "drivers_ed has a Vehicle spawn")
	t.check(scene.get_node_or_null("HUD") != null, "drivers_ed bakes the HUD")
	var enemies := 0
	for child in scene.get_children():
		if String(child.name).begins_with("Enemy"):
			enemies += 1
	t.check(enemies == 0, "drivers_ed bakes zero enemies")
	var script: Script = scene.get_script()
	var reaches_shell := false
	while script != null:
		if script.resource_path == "res://levels/combat_level.gd":
			reaches_shell = true
			break
		script = script.get_base_script()
	t.check(reaches_shell, "drivers_ed root extends combat_level.gd")
	scene.free()

func test_boundary_has_north_tunnel_gap() -> void:
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	var boundary: Node = scene.get_node_or_null("Boundary")
	t.check(boundary != null, "drivers_ed has a Boundary")
	if boundary != null:
		t.check(boundary.collision_layer == 2, "Boundary rides the wall layer")
		# North wall is split into two segments around the exit-tunnel mouth;
		# the throat is enclosed by jambs plus a back cap so the yard never
		# leaks into the void even with the gate (card 4) open.
		for wall_name in ["NorthWCol", "NorthECol", "JambWCol", "JambECol", "CapCol"]:
			t.check(boundary.get_node_or_null(wall_name) != null,
				"Boundary has %s" % wall_name)
	scene.free()

## The terrain sampler must cover the whole lesson-7 set — one lane per
## surface, so "drove on everything" is physically satisfiable.
func test_terrain_sampler_covers_lesson_set() -> void:
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	var sampled := {}
	for child in scene.get_children():
		if child is Area2D and child.collision_layer == 128:
			var terrain: Variant = child.get("terrain_type")
			if terrain != null:
				sampled[terrain] = true
	for surface in [&"grass", &"dirt", &"mud", &"snow", &"ice", &"water"]:
		t.check(sampled.has(surface), "sampler has a %s lane" % surface)
	scene.free()

func test_ramp_deck_geometry() -> void:
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	var deck: Node = scene.get_node_or_null("FZDeck")
	var ramp: Node = scene.get_node_or_null("DeckRamp")
	var walls: Node = scene.get_node_or_null("DeckWalls")
	t.check(deck != null and deck.floor_index == 2, "deck plate is floor 2")
	t.check(ramp != null and ramp.low_floor == 1 and ramp.high_floor == 2,
		"deck ramp grades floor 1 -> 2")
	if deck != null and ramp != null:
		# Ramp length runs along local y with the HIGH end at -y: its top edge
		# must land exactly on the deck's south edge or the grade has a seam.
		var ramp_high_y: float = ramp.position.y - ramp.size.y * 0.5
		var deck_south_y: float = deck.position.y + deck.size.y * 0.5
		t.check(is_equal_approx(ramp_high_y, deck_south_y),
			"ramp high end meets the deck south edge")
	t.check(walls != null and walls.collision_layer == 28,
		"deck walls carry obstacle + both floor bits")
	if walls != null:
		# The deck sits in the NE corner — the boundary owns its north and
		# east sides, the west edge stays open (the ledge-hop lesson), and
		# the south wall splits around the ramp mouth.
		for wall_name in ["SouthWCol", "SouthECol"]:
			t.check(walls.get_node_or_null(wall_name) != null,
				"deck has %s" % wall_name)
	scene.free()

func test_jump_pad_clear_of_deck() -> void:
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	var pad: Node = scene.get_node_or_null("JumpPad")
	t.check(pad != null and pad.floor_index == 1, "jump pad serves floor 1")
	if pad != null:
		var shape: RectangleShape2D = pad.get_node("Col").shape
		var pad_rect := Rect2(Vector2(pad.position) - shape.size * 0.5, shape.size)
		var deck: Node = scene.get_node_or_null("FZDeck")
		var ramp: Node = scene.get_node_or_null("DeckRamp")
		if deck != null:
			var deck_rect := Rect2(Vector2(deck.position) - Vector2(deck.size) * 0.5, deck.size)
			t.check(not pad_rect.intersects(deck_rect), "jump pad clear of the deck plate")
		if ramp != null:
			var ramp_rect := Rect2(Vector2(ramp.position) - Vector2(ramp.size) * 0.5, ramp.size)
			t.check(not pad_rect.intersects(ramp_rect), "jump pad clear of the ramp")
	scene.free()

## The pickup row is the lesson-4 syllabus: every ammo kind (rear and mines
## start at 0 — the crates ARE the lesson) plus the repair bay, and NOTHING
## that isn't a real arena item — drive-over heal/boost are chase-exclusive.
func test_pickup_row_complete() -> void:
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	var ammo_kinds := {}
	var drive_over_kinds := {}
	var station := false
	for child in scene.get_children():
		if child.get("respawn_seconds") != null:
			ammo_kinds[child.get("kind")] = true
		elif child.get("cooldown_seconds") != null:
			station = true
		elif child is Area2D and child.get("kind") != null and child.get("amount") != null:
			drive_over_kinds[child.get("kind")] = true
	for kind in ["standard", "homing", "power", "rear", "mine", "jump"]:
		t.check(ammo_kinds.has(kind), "pickup row has %s ammo" % kind)
	t.check(drive_over_kinds.is_empty(),
		"no drive-over heal/boost — chase-exclusive items stay in chase")
	t.check(station, "yard has a repair bay")
	scene.free()

## The ghost-mode regression, third strike: every solid in this FloorZone-
## tagged yard MUST author floor_index or floor-1 cars and shots pass through
## it (repo-wide sweep lives in test_floor_props.gd; this is the local lock).
func test_yard_solids_author_floors() -> void:
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	var solids := 0
	for child in scene.get_children():
		if child is StaticBody2D and (child.collision_layer & 4):
			solids += 1
			var fi: Variant = child.get("floor_index")
			if fi == null:
				# Raw static: proves itself by carrying floor bits in-layer.
				t.check((child.collision_layer & (8 | 16 | 32)) != 0,
					"%s (raw) carries floor bits in its layer" % child.name)
			else:
				t.check(int(fi) >= 1,
					"%s authors floor_index (ghost-mode guard)" % child.name)
	t.check(solids >= 18, "yard fields %d floored solids (>=18)" % solids)
	scene.free()

func test_smash_yard_group() -> void:
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	var members := 0
	var barrels := 0
	for child in scene.get_children():
		if child.is_in_group(&"tutorial_smash"):
			members += 1
			if child.get("deco") == &"barrel":
				barrels += 1
	t.check(members >= 12, "smash yard fields %d targets (>=12)" % members)
	t.check(barrels >= 3, "smash yard has a barrel chain")
	scene.free()

func test_exit_anatomy() -> void:
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	var gate: Node = scene.get_node_or_null("ExitGate")
	var zone: Node = scene.get_node_or_null("ExitZone")
	t.check(gate != null and gate.collision_layer == 2, "exit gate is a wall-layer body")
	t.check(gate != null and gate.visible, "exit gate authored CLOSED")
	if gate != null:
		var col: CollisionShape2D = gate.get_node("Col")
		t.check(not col.disabled, "exit gate collision authored live")
		t.check(gate.get_node_or_null("Vis") != null, "exit gate carries its stripe paint")
	t.check(zone != null and zone.collision_mask == 1, "exit zone listens for cars")
	if gate != null and zone != null:
		t.check(zone.position.y < gate.position.y,
			"exit zone sits in the throat BEHIND the gate")
	for deco_name in ["TunnelDeco", "ExitText", "ExitSign"]:
		t.check(scene.get_node_or_null(deco_name) != null, "yard has %s" % deco_name)
	var sign: Node2D = scene.get_node_or_null("ExitSign")
	t.check(sign != null and sign.z_index == 1, "EXIT sign rides the overhead layer")
	scene.free()

func test_scene_flow_destination() -> void:
	var flow_script: Script = load("res://game/scene_flow.gd")
	var tutorial_path: String = flow_script.get_script_constant_map().get("TUTORIAL", "")
	t.check(tutorial_path == SCENE, "SceneFlow.TUTORIAL points at drivers_ed")
	var in_campaign := false
	for entry in flow_script.get_script_constant_map().get("CAMPAIGN", []):
		if entry.get("scene", "") == SCENE:
			in_campaign = true
	t.check(not in_campaign, "drivers_ed stays out of CAMPAIGN (no contract, no auto-advance)")
