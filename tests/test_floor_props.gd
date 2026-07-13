extends RefCounted
## The ghost-mode guard, repo-wide (third strike ends it). In any scene that
## authors a FloorZone, cars carry floor bits in their masks — so a bit-4
## solid left at floor_index -1 keeps bare obstacle layer 4 and intersects
## NOTHING: floor-N cars drive straight through it and floor-N shots pass
## over it (game/floors.gd ground_mask / projectile_mask both omit bit 4).
## This sweep RECURSES every level in the master list (reuses
## test_spawn_distance's CAMPAIGN — one list to maintain), fires only on
## FloorZone-bearing scenes (legacy single-plane levels mask 1|2|4 and are
## correct at -1), and checks SOLIDS ONLY: Area2D pickups/stations key on
## ground bit 1 by design and work unfloored — linting them would
## false-positive four shipped arenas. The sweep covers bit-4 obstacles AND
## bit-1 ground solids (GFG's machines/columns/lights stamp 4|floor_bit at
## ready off an exposed floor_index — the lint mirrors that contract). A
## scripted solid with NO floor_index property at all (the legacy
## target_dummy shape, layer 1) fails outright: it can never be authored
## onto a terrace, so it doesn't belong in one.

const SpawnList := preload("res://tests/test_spawn_distance.gd")
const FLOOR_BITS := 8 | 16 | 32

var t

func _init(runner) -> void:
	t = runner

func _script_path(n: Node) -> String:
	var sc: Script = n.get_script() as Script
	return sc.resource_path if sc else ""

func _walk(node: Node, out: Array) -> void:
	out.append(node)
	for child in node.get_children():
		_walk(child, out)

func _has_floor_zone(nodes: Array) -> bool:
	for n in nodes:
		if n is Area2D and (n.scene_file_path.ends_with("floor_zone.tscn")
				or _script_path(n).ends_with("floor_zone.gd")):
			return true
	return false

func test_solids_author_floors_in_floor_tagged_scenes() -> void:
	var tagged := 0
	for path in SpawnList.CAMPAIGN:
		var tag: String = String(path).get_file()
		var lvl: Node = (load(path) as PackedScene).instantiate()
		var nodes: Array = []
		_walk(lvl, nodes)
		if not _has_floor_zone(nodes):
			lvl.free()
			continue
		tagged += 1
		for n in nodes:
			if not (n is StaticBody2D) or (n.collision_layer & (1 | 4)) == 0:
				continue
			var fi: Variant = n.get("floor_index")
			if fi == null:
				# Raw statics prove themselves by floor bits in-layer; a
				# scripted solid without the export has no way to comply.
				t.check((n.collision_layer & FLOOR_BITS) != 0,
					"%s: %s needs a floor bit in its layer or a floor_index export (layer %d)" %
					[tag, n.name, n.collision_layer])
			else:
				t.check(int(fi) >= 1,
					"%s: %s authors floor_index (got %s)" % [tag, n.name, fi])
		lvl.free()
	t.check(tagged >= 6, "sweep saw %d floor-tagged levels (>=6)" % tagged)
