extends RefCounted
## Builds the pass geometry as packable, standalone node trees.

const PassGrid := preload("res://levels/snowy/pass_grid.gd")
const MountainWall := preload("res://environment/mountain_wall.gd")
const DropField := preload("res://environment/drop_field.gd")
const PitScene := preload("res://environment/pit_zone.tscn")
const CurbScene := preload("res://environment/hazard_curb.tscn")
const DestructibleBlockScene := preload("res://environment/destructible_block.tscn")

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
