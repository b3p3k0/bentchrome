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
		# Three closed sides (west edge stays open — that's the ledge-hop
		# lesson); the south wall splits around the ramp mouth.
		for wall_name in ["NorthCol", "EastCol", "SouthWCol", "SouthECol"]:
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

func test_scene_flow_destination() -> void:
	var flow_script: Script = load("res://game/scene_flow.gd")
	var tutorial_path: String = flow_script.get_script_constant_map().get("TUTORIAL", "")
	t.check(tutorial_path == SCENE, "SceneFlow.TUTORIAL points at drivers_ed")
	var in_campaign := false
	for entry in flow_script.get_script_constant_map().get("CAMPAIGN", []):
		if entry.get("scene", "") == SCENE:
			in_campaign = true
	t.check(not in_campaign, "drivers_ed stays out of CAMPAIGN (no contract, no auto-advance)")
