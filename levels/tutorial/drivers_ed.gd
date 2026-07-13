extends "res://levels/combat_level.gd"
## Driver's Ed: the tutorial yard / quick test area. combat_level's shell with
## ZERO baked enemies — the end screen's group win is latch-gated and never
## fires here, but we pin it off explicitly anyway (buzzard_run pattern).
## Lesson flow arrives via a TutorialDirector composed in a later card; the
## same yard also serves free-roam test drives with the exit open from boot.

func _ready() -> void:
	super()
	for child in get_children():
		if child is CanvasLayer and "suppress_group_win" in child:
			child.suppress_group_win = true
