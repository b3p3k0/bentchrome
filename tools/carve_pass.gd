extends SceneTree
## Regenerates the standalone Mountainside pass geometry scenes.
## Run: godot --headless --path . -s res://tools/carve_pass.gd [-- --check]

const PassBuilder := preload("res://levels/snowy/pass_builder.gd")
const MOUNTAIN_PATH := "res://levels/snowy/pass_mountain.tscn"
const DROP_PATH := "res://levels/snowy/pass_drop.tscn"

func _init() -> void:
	var roots: Array[Node2D] = [PassBuilder.build_mountain(), PassBuilder.build_drop()]
	var paths := PackedStringArray([MOUNTAIN_PATH, DROP_PATH])
	var checking := OS.get_cmdline_user_args().has("--check")
	var failed := false
	for i in roots.size():
		var root: Node2D = roots[i]
		var path: String = paths[i]
		if checking:
			if not _matches_saved(path, root):
				printerr("[carve] stale %s; run tools/carve_pass.gd" % path)
				failed = true
		else:
			failed = not _save_scene(path, root) or failed
		root.free()
	quit(1 if failed else 0)

func _save_scene(path: String, root: Node2D) -> bool:
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		_stabilize_node_ids(packed)
		err = ResourceSaver.save(packed, path)
	if err != OK:
		printerr("[carve] could not write %s (error %d)" % [path, err])
		return false
	print("[carve] wrote %s" % path)
	return true

func _stabilize_node_ids(packed: PackedScene) -> void:
	var bundled: Dictionary = packed._get_bundled_scene()
	var count: int = bundled["node_count"]
	var ids := PackedInt32Array()
	for i in count:
		ids.append(i + 1)
	bundled["node_ids"] = ids
	packed._set_bundled_scene(bundled)

func _matches_saved(path: String, expected: Node2D) -> bool:
	var resource: Resource = load(path)
	if not resource is PackedScene:
		return false
	var actual := (resource as PackedScene).instantiate() as Node2D
	if actual == null:
		return false
	var matches := _signature(actual) == _signature(expected)
	actual.free()
	return matches

func _signature(root: Node2D) -> Array:
	var script := root.get_script() as Script
	var result: Array = [root.name, root.get_class(), script.resource_path,
		root.get("bounds"), root.get("paint_seed")]
	if root.name == &"Mountain":
		result.append(root.get("chamfer_exclusions"))
	for child: Node in root.get_children():
		var node := child as Node2D
		var child_script := node.get_script() as Script
		var script_path := child_script.resource_path if child_script != null else ""
		var row: Array = [node.name, node.get_class(), node.position, node.scale, script_path]
		if node is CollisionObject2D:
			var collision := node as CollisionObject2D
			row.append_array([collision.collision_layer, collision.collision_mask])
		if node.name.begins_with("Block"):
			var col := node.get_node_or_null(^"Col") as CollisionShape2D
			var shape := col.shape as RectangleShape2D if col != null else null
			row.append(col.name if col != null else &"")
			row.append(shape.size if shape != null else Vector2.ZERO)
		else:
			row.append(node.get("size"))
			if node.name.begins_with("Pit"):
				row.append(node.get("paint"))
		result.append(row)
	return result
