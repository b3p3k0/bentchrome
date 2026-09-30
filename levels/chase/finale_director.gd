extends Node
## The bridge is out — the show that plays when Route 666's clock runs out.
## Owned by buzzard_run for the last seconds of the run: it rewrites the
## road ahead with the river mile, hands the car to the locked-in driver,
## tells the pack where the bank is, casts every live bird (brakers at the
## brink, two jumpers into the river), takes the camera at the pop and holds
## it at the bank while the car speeds off the top, and calls `finished`
## after the last splash — the host pays out and shows the card from there.
## The world never pauses: the win card does that.
##
## Siblings are preloaded by path (no bare class_name in the chase stack);
## everything else is duck-typed off the host.

const ChunkDefs := preload("res://levels/chase/chunk_defs.gd")
const FinaleDriver := preload("res://levels/chase/finale_driver.gd")
const BirdDriver := preload("res://levels/chase/finale_bird_driver.gd")

static var FINALE_LEAD := 900.0     # px ahead of the car the cut lands (just past the top of the frame)
static var JUMPERS := 2             # bikes that try the jump
static var FINALE_CAM_D := 1250.0   # chunk-local d the held camera centres on: the bank at the bottom, the river low, the landing in frame
static var FINALE_CAM_ZOOM := 0.45  # the held camera's zoom (wider than the chase's 0.55)
static var FINALE_CAM_TIME := 0.6   # seconds the hand-off tween takes
static var FINALE_BEAT := 1.5       # seconds after the last splash before the card
static var FINALE_MAX := 10.0       # seconds after the pop the card comes regardless

signal finished

var host = null        # buzzard_run
var player = null
var course = null
var wall = null
var director = null
var streamer = null

var entry: Dictionary = {}   # the river's plan entry
var jumpers: Array = []
var running := false
var _remaining := 0
var _cam: Camera2D = null
var _pcam: Camera2D = null
var _done := false

## Rewrite the road, lock the car in, halt the pack, cast the birds.
func start() -> void:
	running = true
	var d: float = -player.global_position.y
	var cut: int = course.chunk_index_at(d + FINALE_LEAD) + 1
	streamer.invalidate_from(cut)   # BEFORE the splice: no built chunk may outlive its entry
	course.splice(cut, [&"bridge_out", &"straight", &"straight", &"straight"])
	entry = course.plan[cut]
	var bank_y := ChunkDefs.river_y(entry, "bank")
	var brink_y := ChunkDefs.river_y(entry, "brink")
	var deck_y := bank_y   # the player is forced from the bank on
	if wall != null:
		wall.halt_at(bank_y)
	if director != null:
		director.finale_mode()
	var driver = FinaleDriver.new()
	driver.setup(course, deck_y, brink_y)
	driver.popped.connect(_on_pop, CONNECT_ONE_SHOT)
	player.set_driver(driver)
	_cast(bank_y, deck_y)

## Every live bird brakes at the bank; JUMPERS bikes try the jump (spawned
## if too few are alive — the show always has its fools).
func _cast(bank_y: float, deck_y: float) -> void:
	var birds: Array = get_tree().get_nodes_in_group(&"enemies")
	var picked: Array = []
	for b in birds:
		if picked.size() >= JUMPERS:
			break
		var old = b.get_driver() if b.has_method(&"get_driver") else null
		if old != null and old.get("role") == &"bike" and b.global_position.y > player.global_position.y:
			picked.append(b)
	while picked.size() < JUMPERS and director != null and director.has_method(&"spawn"):
		var fresh = director.spawn(&"bike")
		if fresh == null:
			break
		picked.append(fresh)
		birds.append(fresh)
	var side := 1.0
	for b in birds:
		if not is_instance_valid(b) or not b.has_method(&"set_driver"):
			continue
		var bird = BirdDriver.new()
		if b in picked:
			bird.setup(course, bank_y, deck_y, &"jump")
		else:
			bird.setup(course, bank_y, deck_y, &"brake", side)
			side = -side
		b.set_driver(bird)
	jumpers = picked
	_remaining = jumpers.size()
	for j in jumpers:
		# A sunk bird is freed (tree_exited); so is one wrecked any other way.
		j.tree_exited.connect(_on_splash, CONNECT_ONE_SHOT)
	if _remaining == 0:
		_end_after(FINALE_BEAT)

## The pop: the camera is ours now, held at the bank while the car leaves.
func _on_pop() -> void:
	_pcam = player.get_node_or_null(^"Camera2D") as Camera2D
	_cam = Camera2D.new()
	_cam.name = "FinaleCam"
	_cam.position_smoothing_enabled = false
	if _pcam != null:
		_cam.global_position = _pcam.get_screen_center_position()
		_cam.zoom = _pcam.zoom
	else:
		_cam.global_position = player.global_position
		_cam.zoom = Vector2(0.55, 0.55)
	host.add_child(_cam)
	_cam.make_current()
	var hold_y: float = -(float(entry["start_d"]) + FINALE_CAM_D)
	var hold_x: float = course.sample(-hold_y)["x"]
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_cam, "global_position", Vector2(hold_x, hold_y), FINALE_CAM_TIME)
	tw.parallel().tween_property(_cam, "zoom", Vector2(FINALE_CAM_ZOOM, FINALE_CAM_ZOOM), FINALE_CAM_TIME)
	get_tree().create_timer(FINALE_MAX).timeout.connect(_finish, CONNECT_ONE_SHOT)

## A jumper is gone (sunk, or otherwise): the show ends a beat after the last.
func _on_splash() -> void:
	if _done or not is_inside_tree():
		return   # the scene is being torn down — the birds leave with it
	_remaining -= 1
	if _remaining <= 0:
		_end_after(FINALE_BEAT)

func _end_after(seconds: float) -> void:
	if not is_inside_tree():
		return
	get_tree().create_timer(seconds).timeout.connect(_finish, CONNECT_ONE_SHOT)

func _finish() -> void:
	if _done:
		return
	_done = true
	running = false
	finished.emit()

## The card pauses the tree and the scene is freed from there; giving the
## player camera back is hygiene for any other exit.
func _exit_tree() -> void:
	if _pcam != null and is_instance_valid(_pcam) and _cam != null and is_instance_valid(_cam) and _cam.is_current():
		_pcam.make_current()
