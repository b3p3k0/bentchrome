class_name SpectatorRig
extends Node2D
## The observer's eyes: FOLLOW cycles live cars with the weapon prev/next
## keys; touching WASD breaks into FREE ROAM from wherever the camera sits;
## cycling snaps back to FOLLOW. G rides the same overview zoom as driving.
## Autoloads by path only — this script rides the shell's preload chain.

const IR := preload("res://game/input_router.gd")  # consts, not the autoload

static var PAN_SPEED := 900.0
static var PAN_BOOST := 2.0  # hold boost to sprint the camera

var targets: Array = []      # shared with the shell's _actor_cars
var actor_names: Array = []  # parallel names for the hint line

var _follow := 0
var _free := false
var _cam: Camera2D
var _hint: Label

func _ready() -> void:
	_cam = Camera2D.new()
	_cam.position_smoothing_enabled = true
	add_child(_cam)
	_cam.make_current()
	var gs := get_node_or_null(^"/root/GameState")
	if gs:
		_cam.zoom = Vector2.ONE * (gs.zoom_overview if gs.overview else gs.zoom_combat)
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -34.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.modulate = Color(1.0, 0.85, 0.2)
	layer.add_child(_hint)
	cycle(0)

func _process(delta: float) -> void:
	# Zoom: same toggle, same persisted depths as driving.
	var gs := get_node_or_null(^"/root/GameState")
	if gs:
		if Input.is_action_just_pressed(&"zoom_toggle"):
			gs.overview = not gs.overview
		var target_zoom: float = gs.zoom_overview if gs.overview else gs.zoom_combat
		_cam.zoom = _cam.zoom.lerp(Vector2.ONE * target_zoom, minf(6.0 * delta, 1.0))
	# Cycle keys snap back to FOLLOW.
	if Input.is_action_just_pressed(IR.ACTION_WEAPON_NEXT):
		cycle(1)
	elif Input.is_action_just_pressed(IR.ACTION_WEAPON_PREV):
		cycle(-1)
	# Any stick input breaks into FREE ROAM.
	var axis := Input.get_vector(IR.ACTION_MOVE_LEFT, IR.ACTION_MOVE_RIGHT,
		IR.ACTION_MOVE_UP, IR.ACTION_MOVE_DOWN)
	if axis != Vector2.ZERO:
		pan(axis, delta, Input.is_action_pressed(IR.ACTION_BOOST))
	if not _free:
		var car := _current()
		if car:
			global_position = car.global_position
		else:
			cycle(1)  # my subject got wrecked/freed — find another
	_update_hint()

## FREE ROAM movement; public so tests can drive it without Input.
func pan(axis: Vector2, delta: float, sprint := false) -> void:
	_free = true
	global_position += axis * PAN_SPEED * (PAN_BOOST if sprint else 1.0) * delta

## FOLLOW the next watchable car in dir (skips freed/hidden); dir 0 = validate
## the current pick. Cycling always leaves FREE ROAM.
func cycle(dir: int) -> void:
	_free = false
	if targets.is_empty():
		return
	var n := targets.size()
	var start := wrapi(_follow + dir, 0, n)
	for step in n:
		var idx := wrapi(start + step * (dir if dir != 0 else 1), 0, n)
		if _watchable(idx):
			_follow = idx
			return
	_free = true  # nobody left to watch — hover where we are

func _watchable(idx: int) -> bool:
	var car: Node = targets[idx] if idx < targets.size() else null
	return car != null and is_instance_valid(car) and (car as Node2D).visible

func _current() -> Node2D:
	if _watchable(_follow):
		return targets[_follow]
	return null

func _update_hint() -> void:
	if _free:
		_hint.text = "FREE ROAM — WASD pan (hold boost to sprint), %s/%s follow, G zoom" \
			% ["wheel", "keys"]
	else:
		var name := "?"
		if _follow < actor_names.size():
			name = String(actor_names[_follow])
		_hint.text = "OBSERVING %s — cycle to switch, WASD to roam, G zoom" % name
