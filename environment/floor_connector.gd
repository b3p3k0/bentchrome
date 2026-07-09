class_name FloorConnector
extends Node2D
## An authored floor-route marker for the AI navigator: "this spot takes you
## from from_floor to to_floor, entered driving along approach_dir". kind
## &"ramp" gets a boost run-up (launching needs speed); &"edge" is just a lip
## to drive off. Runtime-invisible — pure navigation metadata in the
## floor_connectors group. The AI duck-types these (get()), never by class.

@export var from_floor := 2
@export var to_floor := 3
@export var approach_dir := Vector2.RIGHT  # normalized at ready
@export var kind: StringName = &"ramp"     # &"ramp" | &"edge"

func _ready() -> void:
	approach_dir = approach_dir.normalized() if approach_dir != Vector2.ZERO else Vector2.RIGHT
	add_to_group(&"floor_connectors")
