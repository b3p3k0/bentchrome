extends "res://levels/combat_level.gd"
## Driver's Ed: the tutorial yard / quick test area. combat_level's shell with
## ZERO baked enemies — the end screen's group win is latch-gated and never
## fires here, but we pin it off explicitly anyway (buzzard_run pattern).
## A composed TutorialDirector runs the lesson syllabus; test drives
## (GameState.game_mode &"test_drive") boot the same director pre-completed
## so the yard is pure free roam with the exit already open.

const DirectorScript := preload("res://levels/tutorial/tutorial_director.gd")

func _ready() -> void:
	super()
	for child in get_children():
		if child is CanvasLayer and "suppress_group_win" in child:
			child.suppress_group_win = true
	var director: Node = DirectorScript.new()
	director.name = "TutorialDirector"
	director.player = _player
	director.gate = get_node_or_null(^"ExitGate")
	director.exit_zone = get_node_or_null(^"ExitZone")
	add_child(director)
	var gs := get_node_or_null(^"/root/GameState")
	director.begin(gs == null or gs.game_mode != &"test_drive")
