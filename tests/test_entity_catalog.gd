extends RefCounted
## EntityCatalog integrity: every entry names a real scene (or a builtin),
## serializes into a key LevelSchema knows, and carries the fields the editor
## and loader rely on. Catches scene renames and half-registered entities.

const Catalog := preload("res://levels/entity_catalog.gd")
const Schema := preload("res://levels/level_schema.gd")

var t  # the runner: check()/check_approx() helpers + root access

func _init(runner) -> void:
	t = runner

func test_entries_well_formed() -> void:
	var known_keys := Schema.make_empty().keys()
	var seen_ids := []
	for entry in Catalog.ENTRIES:
		var id: String = entry.get("id", "")
		t.check(id != "" and id not in seen_ids, "entry has a unique id (%s)" % id)
		seen_ids.append(id)
		t.check(entry.get("list_key", "") in known_keys, "%s: list_key exists in schema" % id)
		t.check(entry.get("display", "") != "", "%s: has a display name" % id)
		t.check(entry.has("scene") != entry.has("builtin"), "%s: exactly one of scene/builtin" % id)
		if entry.has("scene"):
			t.check(ResourceLoader.exists(entry.scene, "PackedScene"), "%s: scene file exists" % id)
		var ghost: Dictionary = entry.get("ghost", {})
		t.check(ghost.has("color") and ghost.has("half_size") and ghost.has("tag"), "%s: ghost complete" % id)
		for prop in entry.get("props", []):
			t.check(prop.has("key") and prop.has("display") and prop.has("default"), "%s: prop %s complete" % [id, prop.get("key", "?")])

func test_presets_pass_schema_whitelists() -> void:
	for entry in Catalog.ENTRIES:
		var preset: Dictionary = entry.get("preset", {})
		if preset.has("kind"):
			t.check(preset.kind in Schema.PICKUP_KINDS, "%s: preset kind whitelisted" % entry.id)
		if preset.has("type"):
			t.check(preset.type in Schema.TERRAIN_TYPES, "%s: preset type whitelisted" % entry.id)

func test_terrain_types_all_covered() -> void:
	for terrain_type in Schema.TERRAIN_TYPES:
		var found := false
		for entry in Catalog.ENTRIES:
			if entry.get("preset", {}).get("type", "") == terrain_type:
				found = true
		t.check(found, "terrain type '%s' has a palette entry" % terrain_type)

func test_by_id() -> void:
	t.check(Catalog.by_id("block").list_key == "blocks", "by_id finds block")
	t.check(Catalog.by_id("no_such_thing").is_empty(), "by_id misses cleanly")
