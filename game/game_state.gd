extends Node
## Global run/session state: selected vehicle, level progress, persistent
## HP/ammo/score. Pure data + signals; survives scene changes.
## Fields fill in as later phases need them.

signal vehicle_selected(vehicle_id: StringName)
signal level_changed(level_index: int)

var selected_vehicle_id: StringName = &""
var level_index: int = 0
var lives: int = 3  # campaign lives; reset at car select, spent by levels
var score: int = 0
# SP lane picked on the mode-select screen: &"campaign" (Road Trip),
# &"tutorial" (Driver's Ed lessons), or &"test_drive" (same yard, free roam).
# Run state, never persisted; mode select re-stamps it on every confirm.
var game_mode: StringName = &"campaign"

func reset_campaign() -> void:
	level_index = 0
	lives = 3

# Custom-level flow (levels/custom_level.tscn). The editor's playtest sets all
# three; a plain "--level=" debug launch uses none.
var pending_level_path: String = ""
var playtest_return_to_editor: bool = false
var editor_open_path: String = ""

# Player settings (exposed by ui/settings.gd; persisted to user://settings.json;
# they survive scene changes AND campaign resets, unlike run state).
var zoom_combat := 0.58    # default camera zoom (settings: ZOOM DEPTH 0.45-0.72)
var zoom_overview := 0.42  # Ctrl-toggled pull-back (see more board)
var overview := false      # the persisted zoom-toggle state
var devgod := false        # invincible, 1x every weapon, firing never depletes
var dev_mode := false      # dev tooling (F1 dashboard; Stage-2 tuning editor)
var start_level_index := 0 # level select: car select launches into this level
var screen_shake := true   # accessibility: gates Vehicle.add_shake
var player_name := ""      # LAN identity; empty = derived from the car's driver bio

# MP screen memory: last host entry + garage prefs, so a LAN night doesn't
# start with retyping. Passwords deliberately NEVER persist (plain-text file).
var mp_join_ip := ""
var mp_join_port := 0      # 0 = the protocol default
var mp_host_port := 0      # 0 = the protocol default
var mp_host_garage := ""
var mp_host_strict := false

## Developer Mode is the master breaker. The raw subordinate choices stay
## persisted so switching the breaker back on restores the developer's bench.
## DEVGOD stands down during Driver's Ed LESSONS (same policy as MP): the
## syllabus grades real actions, and god mode makes them uncompletable —
## no ammo depletion means the bay-fire latch can never land, no damage
## means there's nothing to repair. Test drives keep it: that's the bench.
func is_devgod_enabled() -> bool:
	return dev_mode and devgod and game_mode != &"tutorial"

func effective_start_level_index() -> int:
	return start_level_index if dev_mode else 0

const SETTINGS_PATH := "user://settings.json"
const SETTINGS_KEYS := ["zoom_combat", "zoom_overview", "overview", "devgod",
	"dev_mode", "start_level_index", "screen_shake", "player_name",
	"mp_join_ip", "mp_join_port", "mp_host_port", "mp_host_garage",
	"mp_host_strict"]

func _ready() -> void:
	# Headless runs (test/smoke gates) stay hermetic: Kevin's real settings —
	# devgod especially — must never leak into fixtures. Explicit
	# load_settings(path) calls in tests still work.
	if DisplayServer.get_name() != "headless":
		load_settings()

## Settings only — run state (lives, level_index, score) never touches disk.
func save_settings(path := SETTINGS_PATH) -> void:
	var out := {}
	for k in SETTINGS_KEYS:
		out[k] = get(k)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out, "\t"))
		f.close()

func load_settings(path := SETTINGS_PATH) -> void:
	if not FileAccess.file_exists(path):
		return
	# Instance parse: bad/hand-edited files degrade silently to defaults
	# (JSON.parse_string prints an engine ERROR that would trip the gates).
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return
	for k in SETTINGS_KEYS:
		if data.has(k) and typeof(data[k]) == typeof(get(k)):
			set(k, data[k])
		elif data.has(k) and get(k) is float and data[k] is int:
			set(k, float(data[k]))  # JSON round numbers come back as ints
		elif data.has(k) and get(k) is int and data[k] is float:
			set(k, int(data[k]))

func reset_settings() -> void:
	zoom_combat = 0.58
	zoom_overview = 0.42
	overview = false
	devgod = false
	dev_mode = false
	start_level_index = 0
	screen_shake = true
	player_name = ""
	mp_join_ip = ""
	mp_join_port = 0
	mp_host_port = 0
	mp_host_garage = ""
	mp_host_strict = false
	save_settings()
