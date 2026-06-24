extends Node
## Owns screen/level navigation. Plain scene swaps for now; a fade can layer on
## later. Scene paths live here so callers just say where they want to go.

const TITLE := "res://ui/title.tscn"
const SELECT := "res://ui/car_select.tscn"
const ARENA := "res://levels/arena/arena.tscn"

func to_title() -> void:
	goto_scene(TITLE)

func to_select() -> void:
	goto_scene(SELECT)

func to_arena() -> void:
	goto_scene(ARENA)

func goto_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)
