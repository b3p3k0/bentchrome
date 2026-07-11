class_name Vehicles
extends RefCounted
## The local-player indirection. Two different questions used to share one
## lookup: combat/AI ask "is this a human?" (the "player" faction group — ALL
## humans, so mercy rules and PvP damage keep working untouched) while
## presentation asks "whose screen is this?" — which stops being the same
## question the moment a second human exists. Presentation code calls local();
## whoever owns the viewpoint (combat_level in SP, the MP shell per peer)
## calls mark_local() on exactly one vehicle.

const GROUP_LOCAL := &"local_player"

static func mark_local(v: Node) -> void:
	if v and not v.is_in_group(GROUP_LOCAL):
		v.add_to_group(GROUP_LOCAL)

static func unmark_local(v: Node) -> void:
	if v and v.is_in_group(GROUP_LOCAL):
		v.remove_from_group(GROUP_LOCAL)

## The viewer's car. Falls back to the "player" faction group so unmarked
## scenes (direct .tscn dev boots, chase mode) keep working unchanged.
static func local(tree: SceneTree) -> Node:
	var v := tree.get_first_node_in_group(GROUP_LOCAL)
	return v if v else tree.get_first_node_in_group(&"player")

## Every combatant, for roster-style iteration.
static func all(tree: SceneTree) -> Array:
	return tree.get_nodes_in_group(&"vehicles")
