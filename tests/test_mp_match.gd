extends RefCounted
## The MP match shell, host side: arena instanced as pure geometry (baked cars
## -> spawn data, none simulating), the host seated with PlayerDriver + local
## mark, Grand Melee AI backfill to the map's car count, grudge = humans only,
## and the tree-pause hazards (pause_menu/end_screen) provably absent.
## Autoloads are LIVE under -s runs, so this hosts a real (portless-peer-free)
## session via net.host on a scratch port.

const MatchScene := preload("res://levels/mp/mp_match.tscn")
const VehiclesHelper := preload("res://vehicles/vehicles.gd")
const NetEvents := preload("res://game/net/net_events.gd")
const Snapshot := preload("res://game/net/net_snapshot.gd")

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

func test_hit_events_map_actor_pairs_and_reject_bad_indices() -> void:
	var shell := _boot_match({"map": 0, "mode": "melee"})
	await t.process_frame
	var attacker: Vehicle = shell._actor_cars[0]
	var victim: Vehicle = shell._actor_cars[1]
	var seen: Array = []
	victim.combat_hit.connect(func(source: Node2D) -> void: seen.append(source))
	shell._present_hit_event({"attacker_actor": 0, "victim_actor": 1})
	t.check(seen == [attacker], "shell: client hit event resolves actor pair")
	shell._present_hit_event({"attacker_actor": 99, "victim_actor": 1})
	t.check(seen.size() == 1, "shell: invalid hit actor index is ignored")
	NetEvents.queue = []
	NetEvents.hit_landed(attacker, victim)
	var drained: Array = shell._drain_events()
	t.check(drained.size() == 1 and int(drained[0].attacker_actor) == 0
		and int(drained[0].victim_actor) == 1 and drained[0].kind == &"hit",
		"shell: host hit refs drain as compact actor indices")
	t.check(Snapshot.EV_HIT == 2, "shell: hit wire kind stays stable")
	_teardown(shell)

func test_impact_events_map_and_retire_visual_shots() -> void:
	var shell := _boot_match({"map": 0, "mode": "melee"})
	await t.process_frame
	var spawn := {
		"shot_id": 77, "path": "res://weapons/projectile.tscn",
		"pos": Vector2(10, 12), "dir": Vector2.RIGHT, "speed": 200.0,
		"lifetime": 2.0, "turn_rate": 0.0, "target_actor": Snapshot.NO_TARGET,
	}
	shell._spawn_visual_projectile(spawn)
	t.check(shell._visual_shots.has(77), "shell: client maps visual projectile by host shot id")
	shell._present_impact_event({"shot_id": 77, "pos": Vector2(20, 22),
		"style": Projectile.ImpactStyle.SPARK, "terminal": true})
	t.check(not shell._visual_shots.has(77),
		"shell: terminal impact retires and forgets the mapped visual shot")
	var before := _impact_count(shell._arena)
	shell._present_impact_event({"shot_id": 9999, "pos": Vector2(30, 32),
		"style": Projectile.ImpactStyle.MISSILE, "terminal": true})
	t.check(_impact_count(shell._arena) == before + 1,
		"shell: missing shot id still presents the authoritative impact safely")
	t.check(Snapshot.EV_IMPACT == 3, "shell: impact wire kind follows projectile and hit")
	_teardown(shell)

func _impact_count(root: Node) -> int:
	var count := 0
	for child in root.get_children():
		if child is ImpactFX:
			count += 1
	return count

func _no_tree_pausers(root: Node) -> bool:
	for node in root.get_children():
		var script: Script = node.get_script()
		if script and (script.resource_path.contains("pause_menu")
				or script.resource_path.contains("end_screen")):
			return false
		if not _no_tree_pausers(node):
			return false
	return true
