extends Node
## Owns screen/level navigation. Plain scene swaps for now; a fade can layer on
## later. Scene paths live here so callers just say where they want to go.

const TITLE := "res://ui/title.tscn"
const MODE_SELECT := "res://ui/mode_select.tscn"
const DIFFICULTY := "res://ui/difficulty_select.tscn"
const LEVEL_SELECT := "res://ui/level_select.tscn"
const SELECT := "res://ui/car_select.tscn"
const CUSTOM := "res://levels/custom_level.tscn"
const TUTORIAL := "res://levels/tutorial/drivers_ed.tscn"
const INTERSTITIAL := "res://ui/interstitial.tscn"
const SETTINGS := "res://ui/settings.tscn"
const MP_MENU := "res://ui/mp_menu.tscn"
const MP_LOBBY := "res://ui/mp_lobby.tscn"
const MP_MATCH := "res://levels/mp/mp_match.tscn"
const MP_SCOREBOARD := "res://ui/mp_scoreboard.tscn"

## The versus map pool: every MP-ready regular arena. Boss yards (Lackey's Arena,
## Goliath's Arena) join in a later batch once their boss scripting learns to
## stand down; the chase course and custom JSON levels stay campaign-side.
const MP_MAPS := [
	{"scene": "res://levels/downtown/downtown.tscn", "name": "Downtown Derby", "cars": 5},
	{"scene": "res://levels/freeway/freeway.tscn", "name": "Freeway Firefight", "cars": 7},
	{"scene": "res://levels/suburbs/suburbs.tscn", "name": "Suburban Savagery", "cars": 7},
	{"scene": "res://levels/snowy/snowy.tscn", "name": "Mountainside Mayhem", "cars": 7},
	{"scene": "res://levels/dock/dock.tscn", "name": "Piers of Pain", "cars": 8},
	{"scene": "res://levels/construction/ground_floor_gore.tscn", "name": "Ground Floor Gore", "cars": 8},
]

## The campaign, in order — thirteen pinned slots. Four are `placeholder`
## mode: unbuilt levels with no scene, held in place by an under-construction
## interstitial card that rolls the player past them. When one enters
## development it swaps to a real entry with `"optional": true` (Route 666's
## STAY/DETOUR chooser) so testers can try it while the tour stays stable.
## Optional/placeholder slots must never be last — their advance is a
## relative +1. Everything downstream is size()-driven.
const CAMPAIGN := [
	{"scene": "res://levels/arena_assault/arena_assault.tscn", "name": "Arena Assault",
		"mode": &"arena", "size_class": &"small", "encounter": &"duel",
		"arena_size": Vector2(2560, 2560), "target_cars": 2, "stations": 1,
		"mp_ready": false, "mp_avail": false, "optional": true},
	{"scene": "res://levels/dock/dock.tscn", "name": "Piers of Pain",
		"mode": &"arena", "size_class": &"large", "encounter": &"melee",
		"arena_size": Vector2(5120, 3584), "target_cars": 8, "stations": 2, "mp_ready": true},
	{"scene": "res://levels/downtown/downtown.tscn", "name": "Downtown Derby",
		"mode": &"arena", "size_class": &"medium", "encounter": &"melee",
		"arena_size": Vector2(3712, 3584), "target_cars": 5, "stations": 1, "mp_ready": true},
	{"scene": "res://levels/freeway/freeway.tscn", "name": "Freeway Firefight",
		"mode": &"arena", "size_class": &"large", "encounter": &"melee",
		"arena_size": Vector2(2176, 5376), "target_cars": 7, "stations": 3, "mp_ready": true},
	{"scene": "res://levels/depot/depot.tscn", "name": "Lackey's Arena",
		"mode": &"arena", "size_class": &"medium", "encounter": &"miniboss",
		"arena_size": Vector2(3072, 3072), "target_cars": 4, "stations": 1, "mp_ready": false,
		"mp_exception": "boss scene currently bakes only player + Lackey"},
	{"scene": "res://levels/suburbs/suburbs.tscn", "name": "Suburban Savagery",
		"mode": &"arena", "size_class": &"medium", "encounter": &"melee",
		"arena_size": Vector2(3584, 3456), "target_cars": 7, "stations": 2, "mp_ready": true},
	{"scene": "", "name": "Terminal Terror",
		"mode": &"placeholder", "size_class": &"", "encounter": &"",
		"arena_size": Vector2.ZERO, "target_cars": 0, "stations": 0, "mp_ready": false},
	{"scene": "", "name": "Slaughter on the Strip",
		"mode": &"placeholder", "size_class": &"", "encounter": &"",
		"arena_size": Vector2.ZERO, "target_cars": 0, "stations": 0, "mp_ready": false},
	{"scene": "res://levels/chase/buzzard_run.tscn", "name": "Route 666 Roulette",
		"mode": &"specialty", "size_class": &"", "encounter": &"chase",
		"arena_size": Vector2.ZERO, "target_cars": 0, "stations": 0, "mp_ready": false,
		"optional": true},
	{"scene": "res://levels/snowy/snowy.tscn", "name": "Mountainside Mayhem",
		"mode": &"arena", "size_class": &"medium", "encounter": &"melee",
		"arena_size": Vector2(3456, 3456), "target_cars": 7, "stations": 1, "mp_ready": true},
	{"scene": "res://levels/construction/ground_floor_gore.tscn", "name": "Ground Floor Gore",
		"mode": &"arena", "size_class": &"large", "encounter": &"melee",
		"arena_size": Vector2(4608, 3840), "target_cars": 8, "stations": 2, "mp_ready": true},
	{"scene": "", "name": "Capital City Carnage",
		"mode": &"placeholder", "size_class": &"", "encounter": &"",
		"arena_size": Vector2.ZERO, "target_cars": 0, "stations": 0, "mp_ready": false},
	{"scene": "res://levels/stadium/stadium.tscn", "name": "Goliath's Arena",
		"mode": &"arena", "size_class": &"large", "encounter": &"boss",
		"arena_size": Vector2(4608, 3584), "target_cars": 4, "stations": 1, "mp_ready": false,
		"mp_exception": "boss scene currently bakes only player + Goliath"},
]

func to_title() -> void:
	goto_scene(TITLE)

func to_mode_select() -> void:
	goto_scene(MODE_SELECT)

func to_difficulty() -> void:
	goto_scene(DIFFICULTY)

func to_select() -> void:
	goto_scene(SELECT)

func to_level_select() -> void:
	goto_scene(LEVEL_SELECT)

## Enters a campaign level by index (clamped); keeps GameState in step.
## Placeholder slots have no scene — every entry point routes them to the
## interstitial, whose under-construction card rolls the player onward.
func to_level(index: int) -> void:
	index = clampi(index, 0, CAMPAIGN.size() - 1)
	GameState.level_index = index
	if StringName(CAMPAIGN[index].mode) == &"placeholder":
		goto_scene(INTERSTITIAL)
		return
	goto_scene(CAMPAIGN[index].scene)

## Driver's Ed / test drive — a one-off outside CAMPAIGN, so the end screen
## never auto-advances and the arena contract never applies.
func to_tutorial() -> void:
	goto_scene(TUTORIAL)

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

## The one process-exit for menus (title QUIT GAME, pause/end-screen Quit
## Desktop). Ogg playbacks release on the AudioServer's next MIX pass — a
## wall-clock interval, not a frame — so a same-frame quit prints "leaked
## instances" at exit. Stop every player, give the mixer a 0.1s real-time
## beat (pause-immune; imperceptible on a quit), then leave. Closing the
## window directly still quits same-frame and may print the cosmetic lines.
func quit_gracefully() -> void:
	var audio := get_node_or_null(^"/root/AudioDirector")
	if audio and audio.has_method(&"stop_all"):
		audio.stop_all()
	var music := get_node_or_null(^"/root/MusicDirector")
	if music and music.has_method(&"stop_all"):
		music.stop_all()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()

func goto_scene(path: String) -> void:
	# Every screen change funnels here — the single reset that undoes gameplay's
	# hidden cursor. Combat/MP levels re-hide it in their own _ready.
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file(path)
