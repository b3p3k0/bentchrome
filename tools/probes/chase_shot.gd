extends SceneTree
## Route 666 picture probe: boots the run with the pedal down, jumps the clock
## to each requested second, and saves what the player sees — the sky's act,
## the headlights, the roadside's long shadows. With --signs it instead lines
## up every sign kind on a bare stage (daylight and sunset-with-shadows) at
## the chase's 0.55 and close up. Needs a GL window:
##   xvfb-run -a godot --rendering-driver opengl3 --path . \
##     -s res://tools/probes/chase_shot.gd -- --out=/tmp/shots [--clock=10,50,100] [--signs]

const RUN_SCENE := "res://levels/chase/buzzard_run.tscn"
const IR := preload("res://game/input_router.gd")
const Deco := preload("res://levels/chase/highway_deco.gd")
const RunScript := preload("res://levels/chase/buzzard_run.gd")
const SETTLE := 70   # frames after the clock jump: the streamer builds, the pop flickers out

var _out := "/tmp"
var _clocks: Array = [10.0, 50.0, 100.0]
var _signs := false
var _scene: Node = null
var _stage: Node2D = null
var _frame := 0
var _index := 0
var _shots: Array = []   # {name, zoom, center, sky, shadow}

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--clock="):
			_clocks.clear()
			for s in arg.substr(8).split(",", false):
				_clocks.append(float(s))
		elif arg == "--signs":
			_signs = true
	DirAccess.make_dir_recursive_absolute(_out)
	process_frame.connect(_setup, CONNECT_ONE_SHOT)

func _setup() -> void:
	if _signs:
		_setup_signs()
		return
	_scene = load(RUN_SCENE).instantiate()
	_scene.auto_advance = false
	_scene.catch_enabled = false
	root.add_child(_scene)
	current_scene = _scene
	var health = _scene.get_node(^"Vehicle").get_node_or_null(^"Health")
	if health:
		health.god = true
	Input.action_press(IR.ACTION_MOVE_UP)
	_scene.clock = float(_clocks[0])
	process_frame.connect(_tick_run)

func _tick_run() -> void:
	_frame += 1
	if _frame < SETTLE:
		return
	var image := root.get_texture().get_image()
	var at: float = float(_clocks[_index])
	var path := "%s/act%d_t%03d.png" % [_out, RunScript.act_at(at / RunScript.RUN_SECONDS) + 1, int(at)]
	image.save_png(path)
	print("[shot] %s  clock %.1f  act %d  sky %s  headlights %.2f  shadows %.2f  mile %.1f" % [
		path, _scene.clock, RunScript.act_at(_scene.clock / RunScript.RUN_SECONDS) + 1,
		str(_scene.get_node(^"SkyTint").color), RunScript.headlights_at(_scene.clock / RunScript.RUN_SECONDS),
		RunScript.shadows_at(_scene.clock / RunScript.RUN_SECONDS), _scene.mile()])
	_index += 1
	if _index >= _clocks.size():
		quit(0)
		return
	_scene.clock = float(_clocks[_index])
	_frame = 0

## Every sign kind on a stage, twice: daylight, then the sunset act with the
## long shadows on; each at the chase zoom and close up.
func _setup_signs() -> void:
	_stage = Node2D.new()
	var ground := Polygon2D.new()
	ground.polygon = PackedVector2Array([Vector2(-900, -700), Vector2(900, -700), Vector2(900, 300), Vector2(-900, 300)])
	ground.color = Color(0.3, 0.42, 0.22)
	_stage.add_child(ground)
	var road := Polygon2D.new()
	road.polygon = PackedVector2Array([Vector2(-900, -40), Vector2(900, -40), Vector2(900, 240), Vector2(-900, 240)])
	road.color = Color(0.17, 0.17, 0.19)
	_stage.add_child(road)
	var x := -620.0
	var i := 0
	for kind in [&"highway_sign", &"speed_sign", &"mile_marker", &"billboard"]:
		var node := Node2D.new()
		node.set_script(Deco)
		node.kind = kind
		node.side = 1.0
		node.copy_seed = 101 + i
		node.mile_number = 98
		node.position = Vector2(x, -60.0)
		_stage.add_child(node)
		x += 240.0 if kind != &"mile_marker" else 300.0
		i += 1
	var sky := CanvasModulate.new()
	sky.name = "Sky"
	sky.color = Color.WHITE
	_stage.add_child(sky)
	root.add_child(_stage)
	current_scene = _stage
	var cam := Camera2D.new()
	cam.name = "Cam"
	cam.position = Vector2(-200.0, -120.0)
	_stage.add_child(cam)
	cam.make_current()
	_shots = [
		{"name": "signs_day_055", "zoom": 0.55, "sky": Color.WHITE, "shadow": 0.0},
		{"name": "signs_day_close", "zoom": 1.1, "sky": Color.WHITE, "shadow": 0.0},
		{"name": "signs_sunset_055", "zoom": 0.55, "sky": RunScript.ACTS[1], "shadow": 1.0},
		{"name": "signs_sunset_close", "zoom": 1.1, "sky": RunScript.ACTS[1], "shadow": 1.0},
		{"name": "signs_night_055", "zoom": 0.55, "sky": RunScript.ACTS[2], "shadow": RunScript.NIGHT_SHADOW},
	]
	_apply_shot(0)
	process_frame.connect(_tick_signs)

func _apply_shot(i: int) -> void:
	var shot: Dictionary = _shots[i]
	var cam := _stage.get_node(^"Cam") as Camera2D
	cam.zoom = Vector2(shot["zoom"], shot["zoom"])
	(_stage.get_node(^"Sky") as CanvasModulate).color = shot["sky"]
	for node in _stage.get_children():
		if node.get_script() == Deco:
			node.shadow_strength = float(shot["shadow"])
	_frame = 0

func _tick_signs() -> void:
	_frame += 1
	if _frame < 6:
		return
	var path := "%s/%s.png" % [_out, _shots[_index]["name"]]
	root.get_texture().get_image().save_png(path)
	print("[shot] " + path)
	_index += 1
	if _index >= _shots.size():
		quit(0)
		return
	_apply_shot(_index)
