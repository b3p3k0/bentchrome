extends RefCounted
## Arena Assault: the campaign's true 1v1 opener. The derby pit bakes exactly
## two cars (no phantom MP spawns), the SP boot fields exactly one rival and
## the fight director's duel assignment arms, the health station sits dead
## center (grid 5), the five ammo crates ride the outer walls, and the
## CAMPAIGN profile pins the duel/mp_avail/optional authoring. Real-scene
## in-tree checks follow the test_final_duel precedent.

const ArenaScene := preload("res://levels/arena_assault/arena_assault.tscn")

var t

func _init(runner) -> void:
	t = runner

func test_bakes_a_true_one_v_one() -> void:
	var arena: Node = ArenaScene.instantiate()
	var cars: Array = []
	for child in arena.get_children():
		if child is Vehicle:
			cars.append(child)
	t.check(cars.size() == 2, "arena assault: exactly two baked cars — a true 1v1")
	var player: Node2D = arena.get_node_or_null("Vehicle")
	var enemy: Node2D = arena.get_node_or_null("Enemy1")
	t.check(player != null and enemy != null, "arena assault: Vehicle + Enemy1 baked")
	if player and enemy:
		t.check(player.position.distance_to(enemy.position) >= 700.0,
			"arena assault: spawns open across the pit, not in an ambush")
		t.check(not bool(enemy.get("fixed_loadout")),
			"arena assault: the rival is ordinary — re-roll and duel mode both apply")
	arena.free()

func test_center_station_and_wall_crates() -> void:
	var arena: Node = ArenaScene.instantiate()
	var stations: Array = []
	var kinds: Array = []
	for child in arena.get_children():
		if child.get("cooldown_seconds") != null:
			stations.append(child)
		elif child.get("respawn_seconds") != null and child.get("amount") != null:
			kinds.append(String(child.kind))
	t.check(stations.size() == 1 and (stations[0] as Node2D).position == Vector2.ZERO,
		"arena assault: one health station dead center (grid 5)")
	kinds.sort()
	t.check(kinds == ["homing", "mine", "power", "standard", "standard"],
		"arena assault: five wall crates — M, M, H, P, X")
	arena.free()

func test_sp_boot_fields_one_rival_and_arms_the_duel() -> void:
	var arena: Node = ArenaScene.instantiate()
	t.root.add_child(arena)
	await t.process_frame
	var rivals := 0
	for child in arena.get_children():
		if child.is_in_group(&"enemies"):
			rivals += 1
	t.check(rivals == 1, "arena assault: campaign fields exactly one rival")
	var director: Node = arena.get_node_or_null("AIFightDirector")
	t.check(director != null, "arena assault: fight director attached")
	if director:
		director.refresh_now()
		t.check(director._duel_car != null,
			"arena assault: duel assignment arms at one human + one ordinary rival")
	t.root.remove_child(arena)
	arena.free()

func test_campaign_profile_pins() -> void:
	var flow: Node = t.root.get_node(^"/root/SceneFlow")
	var profile: Dictionary = {}
	for p in flow.CAMPAIGN:
		if String(p.scene).ends_with("arena_assault.tscn"):
			profile = p
	t.check(not profile.is_empty(), "arena assault: campaign slot exists")
	if profile.is_empty():
		return
	t.check(StringName(profile.encounter) == &"duel" and int(profile.target_cars) == 2
			and int(profile.stations) == 1,
		"arena assault: authored as a two-car, one-station duel")
	t.check(profile.get("mp_avail", true) == false and profile.mp_ready == false,
		"arena assault: deliberately outside the versus pool")
	t.check(profile.get("optional", false) == true,
		"arena assault: STAY/DETOUR gated while in test")
