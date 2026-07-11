extends RefCounted
## The versus map pool, proven: every MP_MAPS arena hosts through the real
## shell headless — derived spawn count matches the authored car count, every
## spawn is a distinct spot, melee fields the full car count, and the Docks'
## multi-floor start_floor data survives derivation onto the spawned cars.

const MatchScene := preload("res://levels/mp/mp_match.tscn")
const VehiclesHelper := preload("res://vehicles/vehicles.gd")

var t
var net: Node
var flow: Node

func _init(runner) -> void:
	t = runner
	net = runner.root.get_node("/root/Net")
	flow = runner.root.get_node("/root/SceneFlow")

func test_every_map_hosts() -> void:
	var maps: Array = flow.MP_MAPS
	for i in maps.size():
		var map_name := String(maps[i].name)
		var want := int(maps[i].cars)
		var err: String = net.host(43230 + i, "", "map probe", false)
		t.check(err.is_empty(), "%s: session hosts" % map_name)
		net.set_match_config({"map": i, "mode": "melee"})
		var shell: Node = MatchScene.instantiate()
		t.root.add_child(shell)
		await t.process_frame

		var spawns: Array = shell._arena.mp_spawns
		t.check(spawns.size() == want,
			"%s: %d baked cars derive %d spawns" % [map_name, want, want])
		var spots := {}
		var floors_ok := true
		for spot in spawns:
			spots[spot.pos] = true
			var f := int(spot.floor)
			if f != -1 and f < 1:
				floors_ok = false
		t.check(spots.size() == spawns.size(), "%s: every spawn is a distinct spot" % map_name)
		t.check(floors_ok, "%s: floor values are sane" % map_name)
		var fielded: int = t.root.get_tree().get_nodes_in_group(&"vehicles").size()
		t.check(fielded == want, "%s: melee fields the full car count" % map_name)

		if map_name == "The Docks":
			var roof_spawns := 0
			for spot in spawns:
				if int(spot.floor) == 3:
					roof_spawns += 1
			t.check(roof_spawns == 2, "docks: both roof spawns derive with floor 3")
			var lifted := 0
			for car in shell._actor_cars:
				if is_instance_valid(car) and int(car.start_floor) == 3:
					lifted += 1
			t.check(lifted == 2, "docks: spawned cars carry their terrace")

		var local: Node = VehiclesHelper.local(t.root.get_tree())
		if local:
			VehiclesHelper.unmark_local(local)
		t.root.remove_child(shell)
		shell.free()
		net.leave()