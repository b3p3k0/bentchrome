extends Node2D

## Test Arena Controller
## Spawns a trio of AI opponents at designated markers using roster-driven selection.
## Relies on AIProfileLoader for roster data and GameManager for instantiation.

const ENEMY_SCENE_PATH := "res://scenes/vehicles/EnemyCar.tscn"
const EnemyScene := preload(ENEMY_SCENE_PATH)

@export var ai_spawn_parent_path: NodePath = NodePath("SpawnPoints")
@export var ai_marker_names: Array[StringName] = [
	&"AIStartPoint1",
	&"AIStartPoint2",
	&"AIStartPoint3"
]
@export var spawn_on_ready: bool = true

var _has_spawned := false

func _ready():
	if spawn_on_ready:
		# Delay one frame so Main.gd can register the GameRoot before we spawn.
		call_deferred("_spawn_ai_wave")

func _spawn_ai_wave():
	if _has_spawned:
		return

	var markers := _collect_spawn_markers()
	if markers.is_empty():
		push_warning("TestArena: No AI spawn markers found")
		return

	var selected_ids: Array = []
	if SelectionState:
		if SelectionState.has_match_opponents():
			selected_ids = SelectionState.get_match_opponents()
		else:
			selected_ids = SelectionState.prepare_match_opponents(markers.size())

	if selected_ids.is_empty():
		push_warning("TestArena: No roster IDs available for AI spawn")
		return

	if not GameManager:
		push_error("TestArena: GameManager autoload not available")
		return

	for i in range(min(markers.size(), selected_ids.size())):
		var marker := markers[i] as Marker2D
		var roster_id := String(selected_ids[i])
		if marker:
			GameManager.spawn_enemy(EnemyScene, marker.global_position, roster_id)

	_has_spawned = true

func _collect_spawn_markers() -> Array:
	var markers: Array = []
	var parent := get_node_or_null(ai_spawn_parent_path)
	if not parent:
		push_warning("TestArena: Spawn parent path '" + str(ai_spawn_parent_path) + "' not found")
		return markers

	for marker_name in ai_marker_names:
		var node := parent.get_node_or_null(NodePath(str(marker_name)))
		if node and node is Marker2D:
			markers.append(node)
		else:
			push_warning("TestArena: Missing spawn marker '" + str(marker_name) + "'")

	return markers
