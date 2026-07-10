extends Node
## Owns screen/level navigation. Plain scene swaps for now; a fade can layer on
## later. Scene paths live here so callers just say where they want to go.

const TITLE := "res://ui/title.tscn"
const SELECT := "res://ui/car_select.tscn"
const ARENA := "res://levels/arena/arena.tscn"
const CUSTOM := "res://levels/custom_level.tscn"
const INTERSTITIAL := "res://ui/interstitial.tscn"
const SETTINGS := "res://ui/settings.tscn"

## The campaign, in order. The fight rolls out of town: downtown brawl, up the
## freeway, through the suburbs, into the mountains, and down to the harbor.
const CAMPAIGN := [
	{"scene": "res://levels/arena/arena.tscn", "name": "Downtown"},
	{"scene": "res://levels/freeway/freeway.tscn", "name": "Freeway Loop"},
	{"scene": "res://levels/suburbs/suburbs.tscn", "name": "Suburbs"},
	{"scene": "res://levels/snowy/snowy.tscn", "name": "Snowy Pass"},
	{"scene": "res://levels/depot/depot.tscn", "name": "The Depot"},
	{"scene": "res://levels/dock/dock.tscn", "name": "The Docks"},
	{"scene": "res://levels/chase/buzzard_run.tscn", "name": "The Buzzard Run"},
]

func to_title() -> void:
	goto_scene(TITLE)

func to_select() -> void:
	goto_scene(SELECT)

func to_arena() -> void:
	goto_scene(ARENA)

## Enters a campaign level by index (clamped); keeps GameState in step.
func to_level(index: int) -> void:
	index = clampi(index, 0, CAMPAIGN.size() - 1)
	GameState.level_index = index
	goto_scene(CAMPAIGN[index].scene)

func to_interstitial() -> void:
	goto_scene(INTERSTITIAL)

func to_settings() -> void:
	goto_scene(SETTINGS)

func to_custom_level(path: String) -> void:
	GameState.pending_level_path = path
	goto_scene(CUSTOM)

func goto_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)
