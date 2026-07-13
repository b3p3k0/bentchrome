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

## Presentation roster shared by the radar and edge tracker: every other live
## combatant, regardless of faction. LAN humans and AI read identically here.
static func live_others(tree: SceneTree, viewer: Node) -> Array:
	var out: Array = []
	for candidate_v in all(tree):
		var candidate := candidate_v as Node
		if candidate == null or candidate == viewer or not is_instance_valid(candidate):
			continue
		if candidate.has_method(&"get_hp") and float(candidate.call(&"get_hp")) <= 0.0:
			continue
		out.append(candidate)
	return out

## One tactical identity across presentation surfaces. Vehicle.body_color is
## duck-typed so this helper stays safe for lightweight fixtures and puppets.
static func paint_color(vehicle: Node, fallback: Color = Color.WHITE) -> Color:
	if vehicle == null or not is_instance_valid(vehicle):
		return fallback
	var paint: Variant = vehicle.get("body_color")
	return paint if paint is Color else fallback

static func contrast_outline(color: Color) -> Color:
	var luminance := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
	return Color(0.92, 0.94, 0.98, 0.95) if luminance < 0.38 \
		else Color(0.04, 0.04, 0.06, 0.95)
