extends RefCounted
## The MP match shell, host side: arena instanced as pure geometry (baked cars
## -> spawn data, none simulating), the host seated with PlayerDriver + local
## mark, Grand Melee AI backfill to the map's car count, grudge = humans only,
## and the tree-pause hazards (pause_menu/end_screen) provably absent.
## Autoloads are LIVE under -s runs, so this hosts a real (portless-peer-free)
## session via net.host on a scratch port.

const MatchScene := preload("res://levels/mp/mp_match.tscn")
const VehiclesHelper := preload("res://vehicles/vehicles.gd")

var t
var net: Node

func _init(runner) -> void:
	t = runner
	net = runner.root.get_node("/root/Net")

func _boot_match(config_patch: Dictionary) -> Node:
	var err: String = net.host(43213, "", "test garage", false)
	t.check(err.is_empty(), "shell: test session hosts")
	net.set_match_config(config_patch)
	var shell: Node = MatchScene.instantiate()
	t.root.add_child(shell)
	return shell

func _teardown(shell: Node) -> void:
	var local: Node = VehiclesHelper.local(t.root.get_tree())
	if local:
		VehiclesHelper.unmark_local(local)
	t.root.remove_child(shell)
	shell.free()
	net.leave()

func test_melee_shell() -> void:
	var shell := _boot_match({"map": 0, "mode": "melee"})
	await t.process_frame
	var arena: Node = shell._arena
	t.check(arena != null, "shell: arena instanced")
	t.check(arena.mp_spawns.size() == 5, "shell: Downtown yields 5 derived spawns")
	var vehicles: Array = t.root.get_tree().get_nodes_in_group(&"vehicles")
	t.check(vehicles.size() == 5, "shell: melee backfills to the map's car count")
	var humans := 0
	var ais := 0
	for v in vehicles:
		if v.faction == &"player":
			humans += 1
		else:
			ais += 1
	t.check(humans == 1 and ais == 4, "shell: one seated host + four AI")
	var local: Node = VehiclesHelper.local(t.root.get_tree())
	t.check(local != null and local.faction == &"player",
		"shell: the host's car is the local one")
	t.check(local.get_node("Driver") is PlayerDriver,
		"shell: the host drives with the real PlayerDriver")
	t.check(shell.get_node_or_null("MatchDirector") != null, "shell: director seated")
	t.check(_no_tree_pausers(shell), "shell: no pause_menu/end_screen anywhere")
	t.check(not local.get("net_puppet"), "shell: host cars simulate, never mirror")
	_teardown(shell)

func test_grudge_spawns_no_ai() -> void:
	var shell := _boot_match({"map": 0, "mode": "grudge"})
	await t.process_frame
	var vehicles: Array = t.root.get_tree().get_nodes_in_group(&"vehicles")
	t.check(vehicles.size() == 1,
		"shell: grudge match seats humans only — no AI backfill")
	_teardown(shell)

func _no_tree_pausers(root: Node) -> bool:
	for node in root.get_children():
		var script: Script = node.get_script()
		if script and (script.resource_path.contains("pause_menu")
				or script.resource_path.contains("end_screen")):
			return false
		if not _no_tree_pausers(node):
			return false
	return true