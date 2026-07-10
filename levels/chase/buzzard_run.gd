extends "res://levels/combat_level.gd"
## The Buzzard Run host: combat_level's lives loop under a 180-second survival
## clock. Wires the seeded course + streamer + horde wall around the player,
## suppresses the end screen's arena-style group win (runtime hordes would
## fake a cleared arena), and drives the timed win itself. Respawn is a
## ROLLING START: in place on the road, already moving at ~45 mph, wall reset
## a fair distance back, clock still running.

const CourseScript := preload("res://levels/chase/chase_course.gd")
const StreamerScript := preload("res://levels/chase/course_streamer.gd")
const WallScript := preload("res://levels/chase/horde_wall.gd")
const DirectorScript := preload("res://levels/chase/chase_director.gd")

static var RUN_SECONDS := 180.0
static var ROLL_SPEED := 300.0     # respawn rolling start (300 px/s = 45 mph)
static var SCATTER_RADIUS := 550.0 # buzzards this close get shoved off a respawn

var course = null
var clock := 0.0
var kills := 0   # director bumps this; the chase HUD reads it

var _wall = null
var _streamer = null
var _director = null
var _end_screen = null
var _won := false

func _ready() -> void:
	super()
	add_to_group(&"chase_host")
	var seed_val := randi() & 0x7FFFFFFF
	course = CourseScript.new()
	course.pre_roll(seed_val)
	print("[chase] course seed %d, %d chunks" % [seed_val, course.plan.size()])
	_streamer = StreamerScript.new()
	_streamer.name = "CourseStreamer"
	_streamer.course = course
	_streamer.target = _player
	add_child(_streamer)
	_wall = WallScript.new()
	_wall.name = "HordeWall"
	_wall.target = _player
	_wall.course = course
	_wall.front_y = _player.global_position.y + WallScript.RESPAWN_GAP
	add_child(_wall)
	_director = DirectorScript.new()
	_director.name = "ChaseDirector"
	_director.host = self
	_director.target = _player
	_director.wall = _wall
	add_child(_director)
	for child in get_children():
		if child is CanvasLayer and "suppress_group_win" in child:
			_end_screen = child
			child.suppress_group_win = true

func _process(delta: float) -> void:
	super(delta)
	if _won:
		return
	clock += delta
	if clock >= RUN_SECONDS and _end_screen != null:
		_won = true
		if _director:
			_director.frozen = true
		_end_screen._show(true)

## Duck-typed HUD/director surface (group &"chase_host").
func time_left() -> float:
	return maxf(RUN_SECONDS - clock, 0.0)

func wall_gap() -> float:
	return _wall.gap() if _wall else WallScript.MAX_GAP

## Rolling-start respawn: same course position (x clamped onto the asphalt),
## nose north, shield up, already rolling — the run never stops. Nearby
## Buzzardz get shoved back so the first seconds aren't a re-kill.
func _respawn() -> void:
	_respawning = false
	if _player == null or not is_instance_valid(_player):
		return
	var pos := _player.global_position
	var s: Dictionary = course.sample(-pos.y)
	var road_x: float = s["x"]
	var half: float = s["half_w"]
	var x := clampf(pos.x, road_x - half + 70.0, road_x + half - 70.0)
	_player.respawn(Vector2(x, pos.y), -PI / 2.0, SHIELD_TIME)
	_player.velocity = Vector2(0.0, -ROLL_SPEED)  # respawn() zeroes it — set after
	_scatter_buzzards()
	if _wall:
		_wall.reset_behind(pos.y + WallScript.RESPAWN_GAP)
	if _director:
		_director.on_player_respawn()

func _scatter_buzzards() -> void:
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		if not (enemy is Node2D) or not is_instance_valid(enemy):
			continue
		var away: Vector2 = enemy.global_position - _player.global_position
		if away.length() > SCATTER_RADIUS:
			continue
		# Drop them back south and toward the verge they were already nearer.
		var side := 1.0 if away.x >= 0.0 else -1.0
		enemy.global_position += Vector2(side * 260.0, 520.0)
