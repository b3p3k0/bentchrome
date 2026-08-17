extends RefCounted
## Capital City Carnage's structural pins: the campaign profile, the baked
## eight-car field, three root-level stations, the eight-segment wrought-iron
## ring, Marine One wired to its crash site, three deep-water rects with two
## bridge gaps, both terrace ramps and the Monument knoll, the storm rig, and
## a unique arena_net_id ledger across every synced prop.

const CapitalScene := preload("res://levels/capital/capital_city_carnage.tscn")

var t

func _init(runner) -> void:
	t = runner

func test_campaign_profile_pins() -> void:
	var flow: Node = t.root.get_node(^"/root/SceneFlow")
	var profile: Dictionary = {}
	for p in flow.CAMPAIGN:
		if String(p.scene).ends_with("capital_city_carnage.tscn"):
			profile = p
	t.check(not profile.is_empty(), "capital: campaign slot exists")
	if profile.is_empty():
		return
	t.check(StringName(profile.encounter) == &"melee" and profile.size_class == &"large"
			and int(profile.target_cars) == 8 and int(profile.stations) == 3,
		"capital: authored as the eight-car, three-station large melee")
	t.check(profile.mp_ready == true, "capital: rides the versus pool")
	t.check(profile.get("optional", false) == true,
		"capital: STAY/DETOUR gated while in test")
	var mp_found := false
	for entry in flow.MP_MAPS:
		if String(entry.scene).ends_with("capital_city_carnage.tscn"):
			mp_found = int(entry.cars) == 8
	t.check(mp_found, "capital: MP_MAPS row agrees on eight cars")

func test_scene_structure() -> void:
	var arena: Node = CapitalScene.instantiate()
	var cars := 0
	var stations := 0
	var fences := 0
	var deep := 0
	for child in arena.get_children():
		if child is Vehicle:
			cars += 1
		if child.get("cooldown_seconds") != null:
			stations += 1
		if child.get("is_deep_water") != null:
			deep += 1
	for child in arena.find_children("*", "", true, false):
		if child.is_in_group(&"wh_fence"):
			fences += 1
	t.check(cars == 8, "capital: eight cars baked (player + seven)")
	t.check(stations == 3, "capital: Arlington, K Street, and Capitol-south stations")
	t.check(deep == 3, "capital: three deep-water rects leave exactly two bridge gaps")
	t.check(fences == 8, "capital: the wrought-iron ring closes in eight segments")
	var marine: Node = arena.get_node_or_null("MarineOne")
	t.check(marine != null and int(marine.get("arena_net_id")) == 1,
		"capital: Marine One sits on the lawn as signature id 1")
	if marine:
		t.check(arena.get_node_or_null(NodePath("CrashSite")) != null
				and marine.get_node_or_null(marine.crash_site_path) != null,
			"capital: the crash site resolves from the bird")
	t.check(arena.get_node_or_null("LincolnSteps") != null
			and arena.get_node_or_null("CapitolSteps") != null
			and arena.get_node_or_null("MonumentKnoll") != null,
		"capital: both terrace grades and the knoll are authored")
	t.check(arena.get_node_or_null("Storm") != null and arena.get_node_or_null("Rain") != null,
		"capital: the thunderstorm rig is mounted")
	arena.free()

func test_arena_net_ids_are_unique() -> void:
	var arena: Node = CapitalScene.instantiate()
	var seen := {}
	var dupes := 0
	var count := 0
	for child in arena.find_children("*", "", true, false):
		var id_v: Variant = child.get("arena_net_id")
		if id_v == null or int(id_v) <= 0:
			continue
		count += 1
		if seen.has(int(id_v)):
			dupes += 1
		seen[int(id_v)] = true
	t.check(dupes == 0, "capital: every arena_net_id is unique")
	t.check(count == 37,
		"capital: net ledger holds 37 synced props (got %d)" % count)
	arena.free()
