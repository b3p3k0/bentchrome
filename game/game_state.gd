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

# Player settings (proto-settings surface — a future options menu exposes
# these; they survive scene changes AND campaign resets, unlike run state).
var zoom_combat := 0.62    # default camera zoom (cars readable)
var zoom_overview := 0.42  # Ctrl-toggled pull-back (see more board)
var overview := false      # the persisted zoom-toggle state
