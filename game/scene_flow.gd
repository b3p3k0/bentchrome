extends Node
## Owns screen/level navigation. Plain scene swaps for now; a fade can layer on
## later. Scene paths live here so callers just say where they want to go.

const TITLE := "res://ui/title.tscn"
const DIFFICULTY := "res://ui/difficulty_select.tscn"
const SELECT := "res://ui/car_select.tscn"
const ARENA := "res://levels/arena/arena.tscn"
const CUSTOM := "res://levels/custom_level.tscn"
const INTERSTITIAL := "res://ui/interstitial.tscn"
const SETTINGS := "res://ui/settings.tscn"
const MP_MENU := "res://ui/mp_menu.tscn"
const MP_LOBBY := "res://ui/mp_lobby.tscn"
const MP_MATCH := "res://levels/mp/mp_match.tscn"
const MP_SCOREBOARD := "res://ui/mp_scoreboard.tscn"

## The versus map pool: the five standard arenas. Boss yards (Depot, Coliseum)
## join in a later batch once their boss scripting learns to stand down; the
## chase course and custom JSON levels stay campaign-side.
const MP_MAPS := [
	{"scene": "res://levels/arena/arena.tscn", "name": "Downtown", "cars": 5},
	{"scene": "res://levels/freeway/freeway.tscn", "name": "Freeway Loop", "cars": 7},
	{"scene": "res://levels/suburbs/suburbs.tscn", "name": "Suburbs", "cars": 7},
	{"scene": "res://levels/snowy/snowy.tscn", "name": "Snowy Pass", "cars": 7},
	{"scene": "res://levels/dock/dock.tscn", "name": "The Docks", "cars": 8},
]

## The campaign, in order. The fight rolls out of town: downtown brawl, up the
## freeway, through the suburbs, into the mountains, down to the harbor, and
## finally into the coliseum where Goliath waits. (Junkyard and Central Park
## slot in before the finale when they're built — everything is size()-driven.)
const CAMPAIGN := [
	{"scene": "res://levels/arena/arena.tscn", "name": "Downtown"},
	{"scene": "res://levels/freeway/freeway.tscn", "name": "Freeway Loop"},
	{"scene": "res://levels/suburbs/suburbs.tscn", "name": "Suburbs"},
	{"scene": "res://levels/snowy/snowy.tscn", "name": "Snowy Pass"},
	{"scene": "res://levels/depot/depot.tscn", "name": "The Depot"},
	{"scene": "res://levels/dock/dock.tscn", "name": "The Docks"},
	{"scene": "res://levels/chase/buzzard_run.tscn", "name": "The Buzzard Run"},
	{"scene": "res://levels/stadium/stadium.tscn", "name": "The Coliseum"},
]

func to_title() -> void:
	goto_scene(TITLE)

func to_difficulty() -> void:
	goto_scene(DIFFICULTY)

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

func to_mp_menu() -> void:
	goto_scene(MP_MENU)

func to_mp_lobby() -> void:
	goto_scene(MP_LOBBY)

func to_mp_match() -> void:
	goto_scene(MP_MATCH)

func to_mp_scoreboard() -> void:
	goto_scene(MP_SCOREBOARD)

func to_custom_level(path: String) -> void:
	GameState.pending_level_path = path
	goto_scene(CUSTOM)

func goto_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)
