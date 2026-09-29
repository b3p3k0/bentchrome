extends SceneTree
## Level screenshot probe: renders any PackedScene through an independent
## SubViewport that shares the game's World2D. CanvasLayer HUDs stay attached
## to the main viewport and are therefore absent from the capture.
## Run: xvfb-run -a godot --rendering-driver opengl3 --path . \
##   -s res://tools/probes/level_shot.gd -- \
##   --scene=res://levels/snowy/snowy.tscn --out=/tmp/snowy.png
## In fit mode (--zoom omitted or 0), --center defaults to the arena centre.

const DEFAULT_SIZE := Vector2i(1600, 1600)
const MAX_SIZE := 4096
const DEFAULT_FRAMES := 20

var _scene_path := ""
var _out_path := ""
var _center := Vector2.ZERO
var _center_was_passed := false
var _requested_zoom := 0.0
var _image_size := DEFAULT_SIZE
var _settle_frames := DEFAULT_FRAMES

var _effective_zoom := 1.0
var _frames_elapsed := 0
var _fit_fallback := false
var _capture_viewport: SubViewport

func _init() -> void:
	if not _parse_args():
		return
	process_frame.connect(_setup, CONNECT_ONE_SHOT)

func _parse_args() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene_path = arg.substr(8)
		elif arg.begins_with("--out="):
			_out_path = arg.substr(6)
		elif arg.begins_with("--center="):
			var value := arg.substr(9)
			var parts := value.split(",", false)
			if parts.size() != 2 or not parts[0].is_valid_float() \
					or not parts[1].is_valid_float():
				return _fail("invalid --center (expected X,Y): " + value)
			_center = Vector2(float(parts[0]), float(parts[1]))
			_center_was_passed = true
		elif arg.begins_with("--zoom="):
			var value := arg.substr(7)
			if not value.is_valid_float():
				return _fail("invalid --zoom: " + value)
			_requested_zoom = float(value)
			if _requested_zoom < 0.0:
				return _fail("--zoom must be 0 or greater")
		elif arg.begins_with("--size="):
			var value := arg.substr(7)
			var parts := value.split(",", false)
			if parts.size() != 2 or not parts[0].is_valid_int() \
					or not parts[1].is_valid_int():
				return _fail("invalid --size (expected W,H): " + value)
			_image_size = Vector2i(int(parts[0]), int(parts[1]))
			if _image_size.x <= 0 or _image_size.y <= 0:
				return _fail("--size dimensions must be greater than 0")
			if _image_size.x > MAX_SIZE or _image_size.y > MAX_SIZE:
				return _fail("--size dimensions must not exceed %d" % MAX_SIZE)
		elif arg.begins_with("--frames="):
			var value := arg.substr(9)
			if not value.is_valid_int():
				return _fail("invalid --frames: " + value)
			_settle_frames = int(value)
			if _settle_frames < 0:
				return _fail("--frames must be 0 or greater")
		else:
			return _fail("unknown argument: " + arg)

	if _scene_path.is_empty():
		return _fail("missing required --scene")
	if _out_path.is_empty():
		return _fail("missing required --out")
	if not _out_path.is_absolute_path():
		return _fail("--out must be an absolute path")
	return true

func _setup() -> void:
	var resource := load(_scene_path)
	var packed := resource as PackedScene
	if packed == null:
		_fail("scene is not a PackedScene: " + _scene_path)
		return

	var scene_root := packed.instantiate()
	if scene_root == null:
		_fail("failed to instantiate scene: " + _scene_path)
		return
	if "mp_managed" in scene_root:
		scene_root.set("mp_managed", true)
	root.add_child(scene_root)
	current_scene = scene_root

	_effective_zoom = _requested_zoom
	if _requested_zoom == 0.0:
		var scan := _boundary_bounds(scene_root)
		if bool(scan.found):
			var bounds: Rect2 = scan.bounds
			if not _center_was_passed:
				_center = bounds.get_center()
			_effective_zoom = minf(
				float(_image_size.x) / bounds.size.x,
				float(_image_size.y) / bounds.size.y)
		else:
			_effective_zoom = 1.0
			_fit_fallback = true

	_capture_viewport = SubViewport.new()
	_capture_viewport.size = _image_size
	_capture_viewport.world_2d = root.world_2d
	_capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_capture_viewport)

	var camera := Camera2D.new()
	camera.position = _center
	camera.zoom = Vector2(_effective_zoom, _effective_zoom)
	camera.enabled = true
	_capture_viewport.add_child(camera)
	camera.make_current()
	process_frame.connect(_tick)

## Match ui/radar.gd's _scan boundary derivation exactly: every rectangular
## CollisionShape2D directly beneath a layer-2 StaticBody2D contributes its
## axis-aligned global-position extent.
func _boundary_bounds(scene_root: Node) -> Dictionary:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var found_wall := false
	var stack: Array = [scene_root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.push_back(child)
		if node is StaticBody2D and node.collision_layer & 2:
			for child in node.get_children():
				if child is CollisionShape2D and child.shape is RectangleShape2D:
					found_wall = true
					var half: Vector2 = child.shape.size * 0.5
					lo = lo.min(child.global_position - half)
					hi = hi.max(child.global_position + half)
	return {"found": found_wall, "bounds": Rect2(lo, hi - lo)}

func _tick() -> void:
	_frames_elapsed += 1
	if _frames_elapsed <= _settle_frames:
		return

	var image := _capture_viewport.get_texture().get_image()
	if image.is_empty():
		_fail("SubViewport returned an empty image")
		return
	if image.get_width() != _image_size.x or image.get_height() != _image_size.y:
		_fail("capture size was %dx%d, expected %dx%d" % [
			image.get_width(), image.get_height(), _image_size.x, _image_size.y])
		return
	var err := image.save_png(_out_path)
	if err != OK:
		_fail("could not save PNG to %s (error %d)" % [_out_path, err])
		return

	var line := "[shot] wrote %s %dx%d zoom=%s center=%s,%s" % [
		_out_path, image.get_width(), image.get_height(), str(_effective_zoom),
		str(_center.x), str(_center.y)]
	if _fit_fallback:
		line += " fallback=no-boundary-walls"
	print(line)
	quit(0)

func _fail(reason: String) -> bool:
	printerr("[shot] ERROR: " + reason)
	quit(1)
	return false
