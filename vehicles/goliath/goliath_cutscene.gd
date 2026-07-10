extends Node2D
## The phase flip, staged: a PROCESS_MODE_ALWAYS director that pauses the
## whole battlefield (every DoT, cooldown, and timer in the game is
## physics-delta driven, so the freeze is total — a burning player stops
## burning), walks a borrowed camera onto Goliath, cooks off the trailer in
## staggered explosions, revs the stacks in a wall of diesel smoke, then
## hands the view back and lets phase 2 loose. FX spawn as CHILDREN of this
## node so they inherit ALWAYS and animate through the pause; the timers use
## create_timer(t, true) for the same reason. Duck-typed throughout.

const ExplosionScene := preload("res://environment/explosion.tscn")
const CarPaintScript := preload("res://vehicles/car_paint.gd")  # FLEET_SCALE only

static var CAM_ZOOM := 0.55           # the close-up on the king
static var CAM_TIME := 0.7            # pan/zoom onto him
static var EXPLOSION_COUNT := 4       # trailer cook-off booms
static var EXPLOSION_GAP := 0.35      # seconds between them
static var REV_TIME := 1.3            # stack smoke / menace beat
static var STACK_OFFSETS := [Vector2(-8, -14), Vector2(-8, 14)]  # paint-local

var _boss: Node = null
var _cab: Node2D = null
var _trailer: Node2D = null
var _cam: Camera2D = null

## Freeze, stage, hand back. Call after adding this node to the level.
func run(boss: Node, cab: Node2D, trailer: Node2D) -> void:
	_boss = boss
	_cab = cab
	_trailer = trailer
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_cam = Camera2D.new()
	var pcam := _player_camera()
	if pcam:  # start from the player's view so the cut doesn't jump
		_cam.global_position = pcam.global_position
		_cam.zoom = pcam.zoom
	else:
		_cam.global_position = _cab.global_position
		_cam.zoom = Vector2(CAM_ZOOM, CAM_ZOOM)
	add_child(_cam)
	_cam.make_current()
	_play()

func _play() -> void:
	var tw := create_tween()  # bound to an ALWAYS node: runs through the pause
	tw.tween_property(_cam, "global_position", _cab.global_position, CAM_TIME)
	tw.parallel().tween_property(_cam, "zoom", Vector2(CAM_ZOOM, CAM_ZOOM), CAM_TIME)
	await tw.finished
	for i in EXPLOSION_COUNT:
		_boom_on_trailer()
		await get_tree().create_timer(EXPLOSION_GAP, true).timeout
	if _trailer and is_instance_valid(_trailer):
		_trailer.queue_free()
	_rev_stacks()
	await get_tree().create_timer(REV_TIME, true).timeout
	var pcam := _player_camera()
	if pcam:
		pcam.make_current()
	get_tree().paused = false
	if _boss and is_instance_valid(_boss) and _boss.has_method(&"start_phase2"):
		_boss.start_phase2()
	queue_free()

func _player_camera() -> Camera2D:
	var player := get_tree().get_first_node_in_group(&"player")
	if player == null or not is_instance_valid(player):
		return null
	return player.get_node_or_null(^"Camera2D") as Camera2D

## One boom somewhere along the trailer footprint — a child of the director,
## so it inherits ALWAYS and animates while the world holds its breath.
func _boom_on_trailer() -> void:
	if _trailer == null or not is_instance_valid(_trailer):
		return
	var boom := ExplosionScene.instantiate()
	add_child(boom)
	var yaw: float = float(_trailer.get("yaw"))
	var center: Vector2 = _trailer.get("main_center")
	var along := Vector2.RIGHT.rotated(yaw) * randf_range(-90.0, 110.0)
	var across := Vector2.DOWN.rotated(yaw) * randf_range(-24.0, 24.0)
	boom.global_position = center + along + across
	boom.tint = Color(1.0, 0.45, 0.15)  # fuel fire
	boom.size_scale = randf_range(1.0, 1.4)

## The Hammertoe stack recipe (special_controller's armed FX), pumped up for
## a rev: dark diesel one-shots off both exhaust stacks, blown backward.
func _rev_stacks() -> void:
	if _cab == null or not is_instance_valid(_cab):
		return
	var vis_scale := 1.6
	var bs: Variant = _cab.get("body_scale")
	if bs is float:
		vis_scale = bs
	var heading: float = float(_cab.get("heading"))
	for off in STACK_OFFSETS:
		var smoke := CPUParticles2D.new()
		smoke.amount = 40
		smoke.lifetime = 0.7
		smoke.one_shot = true
		smoke.explosiveness = 0.35
		smoke.local_coords = false  # smoke hangs in the world
		smoke.direction = Vector2(-1, 0).rotated(heading)
		smoke.spread = 24.0
		smoke.initial_velocity_min = 60.0
		smoke.initial_velocity_max = 160.0
		smoke.scale_amount_min = 2.5
		smoke.scale_amount_max = 5.0
		smoke.gravity = Vector2.ZERO
		smoke.color = Color(0.18, 0.17, 0.16, 0.85)
		add_child(smoke)
		smoke.global_position = _cab.global_position \
			+ ((off as Vector2) * CarPaintScript.FLEET_SCALE * vis_scale).rotated(heading)
		smoke.emitting = true
