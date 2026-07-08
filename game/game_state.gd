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

const SETTINGS_PATH := "user://settings.json"
const SETTINGS_KEYS := ["zoom_combat", "zoom_overview", "overview", "devgod",
	"dev_mode", "start_level_index", "screen_shake"]

func _ready() -> void:
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
	save_settings()
