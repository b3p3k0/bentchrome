extends RefCounted
## Builds the pass geometry as packable, standalone node trees.

const PassGrid := preload("res://levels/snowy/pass_grid.gd")
const MountainWall := preload("res://environment/mountain_wall.gd")
const DropField := preload("res://environment/drop_field.gd")
const TerrainFieldScript := preload("res://environment/terrain_field.gd")
const TerrainZoneScript := preload("res://environment/terrain_zone.gd")
const PitScene := preload("res://environment/pit_zone.tscn")
const CurbScene := preload("res://environment/hazard_curb.tscn")
const DestructibleBlockScene := preload("res://environment/destructible_block.tscn")
const BoulderScript := preload("res://environment/boulder.gd")
const ClutterScene := preload("res://environment/clutter.tscn")
const DerelictCarScene := preload("res://environment/derelict_car.tscn")

static func build_snow() -> Node2D:
	var root := TerrainFieldScript.new() as Node2D
	root.name = "SnowCover"
	root.set("bounds", PassGrid.ARENA_RECT)
	root.set("paint_seed", 4096)
	var tiles := PassGrid.snow_tiles()
	for i in tiles.size():
		var rect: Rect2 = tiles[i]
		var zone := TerrainZoneScript.new() as Area2D
		zone.name = "Snow%02d" % (i + 1)
		zone.position = rect.get_center()
		zone.collision_layer = 128
		zone.collision_mask = 0
		zone.set("terrain_type", &"snow")
		root.add_child(zone)
		zone.owner = root
		var col := CollisionShape2D.new()
		col.name = "Col"
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		col.shape = shape
		zone.add_child(col)
		col.owner = root
	return root

static func build_mountain() -> Node2D:
	var root := Node2D.new()
	root.name = "Mountain"
	root.set_script(MountainWall)
	root.set("bounds", PassGrid.ARENA_RECT)
	root.set("paint_seed", 4096)
	var ledge: Rect2i = PassGrid.LEDGE_DATA["cells"]
	var spur: Rect2i = PassGrid.SPUR_DATA["cells"]
	var notch_cells := ledge.merge(spur)
	var notch := Rect2(
		PassGrid.ORIGIN + Vector2(notch_cells.position) * PassGrid.CELL,
		Vector2(notch_cells.size) * PassGrid.CELL)
	var exclusions: Array[Rect2] = [notch]
	root.set("chamfer_exclusions", exclusions)
	var blocks := PassGrid.mountain_blocks()
	for i in blocks.size():
		var rect: Rect2 = blocks[i]
		var body := StaticBody2D.new()
		body.name = "Block%02d" % (i + 1)
		body.position = rect.get_center()
		body.collision_layer = 54
		body.collision_mask = 0
		root.add_child(body)
		body.owner = root
		var col := CollisionShape2D.new()
		col.name = "Col"
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		col.shape = shape
		body.add_child(col)
		col.owner = root
	return root

static func build_drop() -> Node2D:
	var root := Node2D.new()
	root.name = "Drop"
	root.set_script(DropField)
	root.set("bounds", PassGrid.ARENA_RECT)
	root.set("paint_seed", 4096)
	var pits := PassGrid.drop_bands()
	for i in pits.size():
		var rect: Rect2 = pits[i]
		var pit := PitScene.instantiate() as Node2D
		pit.name = "Pit%02d" % (i + 1)
		pit.position = rect.get_center()
		pit.set("size", rect.size)
		pit.set("paint", false)
		root.add_child(pit)
		pit.owner = root
	var curbs := PassGrid.rim_curbs()
	for i in curbs.size():
		var rect: Rect2 = curbs[i]
		var curb := CurbScene.instantiate() as Node2D
		curb.name = "Curb%02d" % (i + 1)
		curb.position = rect.get_center()
		curb.set("size", rect.size)
		root.add_child(curb)
		curb.owner = root
	return root

static func build_rails() -> Node2D:
	var root := Node2D.new()
	root.name = "Rails"
	var rails := PassGrid.rail_segments()
	for i in rails.size():
		var rect: Rect2 = rails[i]
		var rail := DestructibleBlockScene.instantiate() as Node2D
		rail.name = "Rail%03d" % (i + 1)
		rail.position = rect.get_center()
		rail.set("size", rect.size)
		rail.set("deco", &"rail")
		rail.set("max_hp", 12.0)
		rail.set("floor_index", 2)
		rail.set("arena_net_id", 100 + i)
		root.add_child(rail)
		rail.owner = root
	return root

static func build_furniture() -> Node2D:
	var root := Node2D.new()
	root.name = "Furniture"
	var boulders := _add_group(root, &"Boulders")
	var wrecks := _add_group(root, &"Wrecks")
	var pines := _add_group(root, &"PineGroves")
	var drifts := _add_group(root, &"Drifts")
	var markers := _add_group(root, &"Markers")
	for entry: Dictionary in PassGrid.FURNITURE[&"boulder"]:
		var rock := StaticBody2D.new()
		rock.name = entry["name"]
		rock.position = entry["center"]
		rock.collision_layer = 4
		rock.collision_mask = 0
		rock.set_script(BoulderScript)
		rock.set("size", entry["size"])
		rock.set("floor_index", entry["floor"])
		rock.set("paint_seed", entry["paint_seed"])
		boulders.add_child(rock)
		rock.owner = root
		var col := CollisionShape2D.new()
		col.name = "Col"
		var shape := RectangleShape2D.new()
		shape.size = entry["size"]
		col.shape = shape
		rock.add_child(col)
		col.owner = root
	for entry: Dictionary in PassGrid.FURNITURE[&"wreck"]:
		var wreck := DerelictCarScene.instantiate() as Node2D
		wreck.name = entry["name"]
		wreck.position = entry["center"]
		wreck.rotation = entry["rotation"]
		wreck.set("max_hp", entry["max_hp"])
		wreck.set("floor_index", entry["floor"])
		wreck.set("arena_net_id", entry["arena_net_id"])
		wrecks.add_child(wreck)
		wreck.owner = root
	for entry: Dictionary in PassGrid.FURNITURE[&"pine"]:
		_add_clutter(pines, root, entry, &"pine")
	for entry: Dictionary in PassGrid.FURNITURE[&"drift"]:
		_add_clutter(drifts, root, entry, &"drift")
	for entry: Dictionary in PassGrid.FURNITURE[&"cone"]:
		_add_clutter(markers, root, entry, &"cone")
	for entry: Dictionary in PassGrid.FURNITURE[&"sign"]:
		_add_clutter(markers, root, entry, &"sign")
	return root

static func _add_group(root: Node2D, group_name: StringName) -> Node2D:
	var group := Node2D.new()
	group.name = group_name
	root.add_child(group)
	group.owner = root
	return group

static func _add_clutter(group: Node2D, root: Node2D, entry: Dictionary,
		kind: StringName) -> void:
	var clutter := ClutterScene.instantiate() as Node2D
	clutter.name = entry["name"]
	clutter.position = entry["center"]
	clutter.set("kind", kind)
	clutter.set("footprint", entry["footprint"])
	clutter.set("floor_index", entry["floor"])
	group.add_child(clutter)
	clutter.owner = root
