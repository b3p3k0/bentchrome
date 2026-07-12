extends RefCounted
## The versus map pool, proven: every MP_MAPS arena hosts through the real
## shell headless — derived spawn count matches the authored car count, every
## spawn is a distinct spot, melee fields the full car count, and the Docks'
## multi-floor start_floor data survives derivation onto the spawned cars.

const MatchScene := preload("res://levels/mp/mp_match.tscn")
const VehiclesHelper := preload("res://vehicles/vehicles.gd")
const Contract := preload("res://levels/arena_contract.gd")

var t
var net: Node
var flow: Node

func _init(runner) -> void:
	t = runner
	net = runner.root.get_node("/root/Net")
	flow = runner.root.get_node("/root/SceneFlow")

func test_campaign_arena_profiles_are_complete() -> void:
	var specialty := 0
	for profile_v in flow.CAMPAIGN:
		var profile: Dictionary = profile_v
		var errors := Contract.validate(profile)
		t.check(errors.is_empty(), "%s: arena profile valid (%s)" %
			[profile.name, "; ".join(errors)])
		if not Contract.is_regular(profile):
			specialty += 1
			continue
		t.check(int(profile.target_cars) >= Contract.MIN_CARS,
			"%s: four-player floor is structural" % profile.name)
		t.check(Contract.area_per_car(profile) >= Contract.MIN_AREA_PER_CAR,
			"%s: aquarium area-per-car floor holds" % profile.name)
		var arena := (load(String(profile.scene)) as PackedScene).instantiate()
		var script := arena.get_script() as Script
		t.check(Contract.script_inherits(script, "res://levels/combat_level.gd"),
			"%s: root inherits the shared combat shell" % profile.name)
		t.check(arena.get("mp_managed") != null,
			"%s: shared scene exposes mp_managed" % profile.name)
		var cars: Array = []
		var stations := 0
		for child in arena.get_children():
			if child is Vehicle:
				cars.append(child)
			elif child.get("cooldown_seconds") != null:
				stations += 1
		t.check(stations == int(profile.stations),
			"%s: profile station count matches scene" % profile.name)
		var spots := {}
		for car in cars:
			spots[(car as Node2D).position] = true
		t.check(spots.size() == cars.size(), "%s: baked spawn positions are unique" % profile.name)
		if profile.mp_ready == true:
			t.check(cars.size() == int(profile.target_cars),
				"%s: baked cars supply the full MP field" % profile.name)
		for object_v in arena.find_children("*", "CollisionObject2D", true, false):
			var object := object_v as CollisionObject2D
			t.check(object.scale.is_equal_approx(Vector2.ONE),
				"%s: %s physics owner is unscaled" % [profile.name, object.name])
			t.check((object.collision_layer & ~Contract.NAMED_COLLISION_MASK) == 0,
				"%s: %s uses named collision bits" % [profile.name, object.name])
		arena.free()
	t.check(specialty == 1, "arena contract: Buzzard Run is the sole specialty exclusion")

func test_campaign_and_mp_profiles_match_exactly() -> void:
	var mp_by_scene := {}
	for entry_v in flow.MP_MAPS:
		var entry: Dictionary = entry_v
		mp_by_scene[String(entry.scene)] = entry
	for profile_v in flow.CAMPAIGN:
		var profile: Dictionary = profile_v
		if not Contract.is_regular(profile):
			continue
		var path := String(profile.scene)
		if profile.mp_ready == true:
			t.check(mp_by_scene.has(path), "%s: MP-ready campaign arena is in MP_MAPS" % profile.name)
			if mp_by_scene.has(path):
				var mp: Dictionary = mp_by_scene[path]
				t.check(String(mp.name) == String(profile.name)
						and int(mp.cars) == int(profile.target_cars),
					"%s: campaign/MP name and field size agree" % profile.name)
		else:
			t.check(Contract.LEGACY_MP_EXCEPTIONS.has(path),
				"%s: campaign-only status is a named legacy exception" % profile.name)

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
