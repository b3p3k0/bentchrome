extends SceneTree
## Regenerates the standalone Mountainside pass geometry scenes.
## Run: godot --headless --path . -s res://tools/carve_pass.gd [-- --check]

const PassBuilder := preload("res://levels/snowy/pass_builder.gd")
const SNOW_PATH := "res://levels/snowy/pass_snow.tscn"
const MOUNTAIN_PATH := "res://levels/snowy/pass_mountain.tscn"
const DROP_PATH := "res://levels/snowy/pass_drop.tscn"
const RAILS_PATH := "res://levels/snowy/pass_rails.tscn"
const FURNITURE_PATH := "res://levels/snowy/pass_furniture.tscn"

func _init() -> void:
	var roots: Array[Node2D] = [
		PassBuilder.build_snow(), PassBuilder.build_mountain(), PassBuilder.build_drop(),
		PassBuilder.build_rails(), PassBuilder.build_furniture(),
	]
	var paths := PackedStringArray([
		SNOW_PATH, MOUNTAIN_PATH, DROP_PATH, RAILS_PATH, FURNITURE_PATH,
	])
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
	return _node_signature(root)

func _node_signature(node: Node) -> Array:
	var script := node.get_script() as Script
	var script_path := script.resource_path if script != null else ""
	var result: Array = [node.name, node.get_class(), script_path]
	if node is Node2D:
		var node_2d := node as Node2D
		result.append_array([
			node_2d.position, node_2d.rotation, node_2d.scale, node_2d.z_index,
		])
	if node is CollisionObject2D:
		var collision := node as CollisionObject2D
		result.append_array([collision.collision_layer, collision.collision_mask])
	for property: StringName in [
			&"bounds", &"paint_seed", &"chamfer_exclusions", &"size", &"terrain_type",
			&"paint", &"deco", &"max_hp", &"floor_index", &"arena_net_id", &"kind",
			&"footprint",
		]:
		if _has_property(node, property):
			result.append([property, node.get(property)])
	if node is CollisionShape2D:
		var shape := (node as CollisionShape2D).shape
		result.append(shape.get_class() if shape != null else "")
		if shape is RectangleShape2D:
			result.append((shape as RectangleShape2D).size)
	for child: Node in node.get_children():
		result.append(_node_signature(child))
	return result

func _has_property(node: Node, property: StringName) -> bool:
	for info: Dictionary in node.get_property_list():
		if info["name"] == property:
			return true
	return false
