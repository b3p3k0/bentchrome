extends Node
## Global run/session state: selected vehicle, level progress, persistent
## HP/ammo/score. Pure data + signals; survives scene changes.
## Fields fill in as later phases need them.

signal vehicle_selected(vehicle_id: StringName)
signal level_changed(level_index: int)

var selected_vehicle_id: StringName = &""
var level_index: int = 0
var score: int = 0

# Custom-level flow (levels/custom_level.tscn). The editor's playtest sets all
# three; a plain "--level=" debug launch uses none.
var pending_level_path: String = ""
var playtest_return_to_editor: bool = false
var editor_open_path: String = ""
