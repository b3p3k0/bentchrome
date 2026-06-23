extends Node
## Global run/session state: selected vehicle, level progress, persistent
## HP/ammo/score. Pure data + signals; survives scene changes.
## Fields fill in as later phases need them.

signal vehicle_selected(vehicle_id: StringName)
signal level_changed(level_index: int)

var selected_vehicle_id: StringName = &""
var level_index: int = 0
var score: int = 0
