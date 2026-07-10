extends Node2D
## Streams the pre-rolled course around the player: every chunk overlapping
## the window is live, everything far behind is freed (the free line sits past
## the horde wall's max gap, so geometry never vanishes under a live actor).
## Builds at most one chunk per frame — no hitch at 640 px/s.

const Builder := preload("res://levels/chase/chunk_builder.gd")

static var AHEAD := 4200.0
static var BEHIND := 2600.0

var course = null          # chase_course.gd instance, set by the host
var target: Node2D = null  # the player vehicle, set by the host

var _live: Dictionary = {}  # plan index -> chunk root node

func _physics_process(_delta: float) -> void:
	if course == null or target == null or not is_instance_valid(target):
		return
	var d: float = -target.global_position.y
	for i in _live.keys():
		var entry: Dictionary = course.plan[i]
		var def: Dictionary = entry["def"]
		var chunk_len: float = def["len"]
		var end_d: float = entry["start_d"] + chunk_len
		if end_d < d - BEHIND:
			_live[i].queue_free()
			_live.erase(i)
	var i: int = course.chunk_index_at(maxf(d - BEHIND, 0.0))
	while i < course.plan.size():
		var entry: Dictionary = course.plan[i]
		var start: float = entry["start_d"]
		if start > d + AHEAD:
			break
		if not _live.has(i):
			var node: Node2D = Builder.build(entry)
			add_child(node)
			_live[i] = node
			return  # one build per frame
		i += 1
