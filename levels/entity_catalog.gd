class_name EntityCatalog
extends RefCounted
## The whitelist of everything a custom level may contain. The LevelLoader
## instantiates only what's registered here; the editor builds its palette,
## ghosts, and inspector fields from the same entries. Adding an entity type
## (ramp team: this is your hook) = one entry here + a list key and rules in
## LevelSchema + a loader branch if it isn't a self-contained scene.
##
## Entry fields:
##   id        — catalog key (palette/tool id)
##   list_key  — the LevelSchema top-level key it serializes into
##   display   — palette label
##   scene     — instanced by the loader ("builtin" entries are node-built instead)
##   preset    — JSON fields fixed by this palette entry (e.g. pickup kind)
##   props     — inspector-editable JSON fields with ranges (limits from LevelSchema)
##   single    — only one may exist (player spawn)
##   max_count — placement cap (enemy spawns)
##   ghost     — editor stand-in: color, half_size, tag letter

const Schema := preload("res://levels/level_schema.gd")

# Visuals lifted from the hand-built arena so ghosts and loader-built nodes
# match what the game already looks like.
const WALL_COLOR := Color(0.4, 0.4, 0.46, 1.0)
const BLOCK_COLOR := Color(0.3, 0.3, 0.36, 1.0)
const TERRAIN_COLORS := {
	"dirt": Color(0.5, 0.36, 0.2, 0.5),
	"grass": Color(0.25, 0.5, 0.22, 0.5),
	"ice": Color(0.6, 0.8, 0.95, 0.5),
	"snow": Color(0.82, 0.85, 0.92, 0.55),
	"water": Color(0.15, 0.3, 0.55, 0.6),
}
const PICKUP_COLORS := {
	"standard": Color(0.25, 0.8, 0.35),
	"homing": Color(0.25, 0.7, 0.9),
	"power": Color(0.9, 0.45, 0.2),
	"rear": Color(0.18, 0.5, 1.0),
	"mine": Color(0.75, 0.25, 0.2),
	"jump": Color(0.6, 0.4, 0.9),
}

const ENTRIES := [
	{
		"id": "player_spawn",
		"list_key": "player_spawn",
		"display": "Player Start",
		"scene": "res://vehicles/vehicle.tscn",
		"single": true,
		"props": [
			{"key": "heading_deg", "display": "Facing (deg)", "min": 0.0, "max": 360.0, "step": 15.0, "default": 0.0},
		],
		"ghost": {"color": Color(0.3, 0.9, 0.4, 0.9), "half_size": Vector2(28, 20), "tag": "P"},
	},
	{
		"id": "enemy_spawn",
		"list_key": "enemy_spawns",
		"display": "Enemy Start",
		"scene": "res://vehicles/enemy_vehicle.tscn",
		"max_count": 4,
		"props": [],
		"ghost": {"color": Color(0.9, 0.3, 0.3, 0.9), "half_size": Vector2(28, 20), "tag": "E"},
	},
	{
		"id": "block",
		"list_key": "blocks",
		"display": "Block",
		"builtin": "block",
		"props": [
			{"key": "size", "display": "Size", "min": Schema.BLOCK_SIDE_MIN, "max": Schema.BLOCK_SIDE_MAX, "step": 64.0, "default": [128.0, 128.0]},
		],
		"ghost": {"color": BLOCK_COLOR, "half_size": Vector2(64, 64), "tag": ""},
	},
	{
		"id": "pickup_standard",
		"list_key": "pickups",
		"display": "Missile Crate",
		"scene": "res://environment/ammo_pickup.tscn",
		"preset": {"kind": "standard"},
		"props": [
			{"key": "amount", "display": "Missiles", "min": Schema.AMOUNT_MIN, "max": Schema.AMOUNT_MAX, "step": 1.0, "default": 2.0},
			{"key": "respawn_seconds", "display": "Respawn (s)", "min": Schema.RESPAWN_MIN, "max": Schema.RESPAWN_MAX, "step": 5.0, "default": 20.0},
		],
		"ghost": {"color": PICKUP_COLORS["standard"], "half_size": Vector2(14, 14), "tag": "M"},
	},
	{
		"id": "pickup_homing",
		"list_key": "pickups",
		"display": "Homing Crate",
		"scene": "res://environment/ammo_pickup.tscn",
		"preset": {"kind": "homing"},
		"props": [
			{"key": "amount", "display": "Missiles", "min": Schema.AMOUNT_MIN, "max": Schema.AMOUNT_MAX, "step": 1.0, "default": 1.0},
			{"key": "respawn_seconds", "display": "Respawn (s)", "min": Schema.RESPAWN_MIN, "max": Schema.RESPAWN_MAX, "step": 5.0, "default": 20.0},
		],
		"ghost": {"color": PICKUP_COLORS["homing"], "half_size": Vector2(14, 14), "tag": "H"},
	},
	{
		"id": "pickup_power",
		"list_key": "pickups",
		"display": "Power Crate",
		"scene": "res://environment/ammo_pickup.tscn",
		"preset": {"kind": "power"},
		"props": [
			{"key": "amount", "display": "Missiles", "min": Schema.AMOUNT_MIN, "max": Schema.AMOUNT_MAX, "step": 1.0, "default": 1.0},
			{"key": "respawn_seconds", "display": "Respawn (s)", "min": Schema.RESPAWN_MIN, "max": Schema.RESPAWN_MAX, "step": 5.0, "default": 20.0},
		],
		"ghost": {"color": PICKUP_COLORS["power"], "half_size": Vector2(14, 14), "tag": "P"},
	},
	{
		"id": "pickup_rear",
		"list_key": "pickups",
		"display": "Rear-Missile Crate",
		"scene": "res://environment/ammo_pickup.tscn",
		"preset": {"kind": "rear"},
		"props": [
			{"key": "amount", "display": "Missiles", "min": Schema.AMOUNT_MIN, "max": Schema.AMOUNT_MAX, "step": 1.0, "default": 2.0},
			{"key": "respawn_seconds", "display": "Respawn (s)", "min": Schema.RESPAWN_MIN, "max": Schema.RESPAWN_MAX, "step": 5.0, "default": 20.0},
		],
		"ghost": {"color": PICKUP_COLORS["rear"], "half_size": Vector2(14, 14), "tag": "R"},
	},
	{
		"id": "pickup_mine",
		"list_key": "pickups",
		"display": "Mine Crate",
		"scene": "res://environment/ammo_pickup.tscn",
		"preset": {"kind": "mine"},
		"props": [
			{"key": "amount", "display": "Mines", "min": Schema.AMOUNT_MIN, "max": Schema.AMOUNT_MAX, "step": 1.0, "default": 2.0},
			{"key": "respawn_seconds", "display": "Respawn (s)", "min": Schema.RESPAWN_MIN, "max": Schema.RESPAWN_MAX, "step": 5.0, "default": 20.0},
		],
		"ghost": {"color": PICKUP_COLORS["mine"], "half_size": Vector2(14, 14), "tag": "X"},
	},
	{
		"id": "pickup_jump",
		"list_key": "pickups",
		"display": "Jump-Mine Crate",
		"scene": "res://environment/ammo_pickup.tscn",
		"preset": {"kind": "jump"},
		"props": [
			{"key": "amount", "display": "Mines", "min": Schema.AMOUNT_MIN, "max": Schema.AMOUNT_MAX, "step": 1.0, "default": 1.0},
			{"key": "respawn_seconds", "display": "Respawn (s)", "min": Schema.RESPAWN_MIN, "max": Schema.RESPAWN_MAX, "step": 5.0, "default": 20.0},
		],
		"ghost": {"color": PICKUP_COLORS["jump"], "half_size": Vector2(14, 14), "tag": "J"},
	},
	{
		"id": "dummy",
		"list_key": "dummies",
		"display": "Target Dummy",
		"scene": "res://environment/target_dummy.tscn",
		"props": [
			{"key": "max_hp", "display": "Hit Points", "min": Schema.HP_MIN, "max": Schema.HP_MAX, "step": 10.0, "default": 60.0},
		],
		"ghost": {"color": Color(0.75, 0.65, 0.3, 0.9), "half_size": Vector2(28, 28), "tag": "D"},
	},
	{
		"id": "terrain_dirt",
		"list_key": "terrain",
		"display": "Dirt",
		"builtin": "terrain",
		"preset": {"type": "dirt"},
		"props": [],
		"ghost": {"color": TERRAIN_COLORS["dirt"], "half_size": Vector2.ZERO, "tag": ""},
	},
	{
		"id": "terrain_grass",
		"list_key": "terrain",
		"display": "Grass",
		"builtin": "terrain",
		"preset": {"type": "grass"},
		"props": [],
		"ghost": {"color": TERRAIN_COLORS["grass"], "half_size": Vector2.ZERO, "tag": ""},
	},
	{
		"id": "terrain_snow",
		"list_key": "terrain",
		"display": "Snow",
		"builtin": "terrain",
		"preset": {"type": "snow"},
		"props": [],
		"ghost": {"color": TERRAIN_COLORS["snow"], "half_size": Vector2.ZERO, "tag": ""},
	},
	{
		"id": "terrain_ice",
		"list_key": "terrain",
		"display": "Ice",
		"builtin": "terrain",
		"preset": {"type": "ice"},
		"props": [],
		"ghost": {"color": TERRAIN_COLORS["ice"], "half_size": Vector2.ZERO, "tag": ""},
	},
	{
		"id": "terrain_water",
		"list_key": "terrain",
		"display": "Water",
		"builtin": "terrain",
		"preset": {"type": "water"},
		"props": [],
		"ghost": {"color": TERRAIN_COLORS["water"], "half_size": Vector2.ZERO, "tag": ""},
	},
]

static func by_id(id: String) -> Dictionary:
	for entry in ENTRIES:
		if entry.id == id:
			return entry
	return {}

## Catalog entry for an already-placed entity: matches list_key, and every
## preset field must agree (distinguishes standard vs homing crates, terrain
## types). Player spawn passes any entity because it has no preset.
static func for_entity(list_key: String, entity: Dictionary) -> Dictionary:
	for entry in ENTRIES:
		if entry.list_key != list_key:
			continue
		var preset: Dictionary = entry.get("preset", {})
		var matches := true
		for key in preset:
			if entity.get(key) != preset[key]:
				matches = false
		if matches:
			return entry
	return {}
