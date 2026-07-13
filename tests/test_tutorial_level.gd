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

func test_scene_flow_destination() -> void:
	var flow_script: Script = load("res://game/scene_flow.gd")
	var tutorial_path: String = flow_script.get_script_constant_map().get("TUTORIAL", "")
	t.check(tutorial_path == SCENE, "SceneFlow.TUTORIAL points at drivers_ed")
	var in_campaign := false
	for entry in flow_script.get_script_constant_map().get("CAMPAIGN", []):
		if entry.get("scene", "") == SCENE:
			in_campaign = true
	t.check(not in_campaign, "drivers_ed stays out of CAMPAIGN (no contract, no auto-advance)")
