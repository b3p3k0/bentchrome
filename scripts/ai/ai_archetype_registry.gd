extends Resource
class_name AIArchetypeRegistry

## AI Archetype Registry - Central hub for archetype-level tuning
## Provides baseline configurations for each AI archetype with editor-friendly properties
## Supports blending archetype defaults with per-car overrides from AI profiles

## Debug flag for archetype registry
const DEBUG_ARCHETYPES: bool = true

## Exported archetype configurations for editor tweaking
@export var aggressor_config: Dictionary = {
	"reaction_time_sec": 0.25,
	"reaction_jitter_sec": 0.08,
	"aim_error_deg": {"min": 2.0, "max": 6.0},
	"burst_window_sec": {"fire": 1.0, "cooldown": 0.6},
	"aggression_multiplier": 1.3,
	"chase_distance": 800.0,
	"engagement_range": {"min": 150.0, "max": 500.0},
	"retreat_threshold": 0.15,
	"pickup_scan_radius": 500.0,
	"movement_aggression": 0.8,
	"targeting": {
		"player_bias": 0.7,
		"wounded_target_bonus": 0.5,
		"revenge_bonus": 0.6,
		"retarget_interval_sec": 1.5
	}
}

@export var defender_config: Dictionary = {
	"reaction_time_sec": 0.4,
	"reaction_jitter_sec": 0.15,
	"aim_error_deg": {"min": 4.0, "max": 8.0},
	"burst_window_sec": {"fire": 1.8, "cooldown": 1.0},
	"aggression_multiplier": 0.7,
	"chase_distance": 600.0,
	"engagement_range": {"min": 200.0, "max": 450.0},
	"retreat_threshold": 0.25,
	"pickup_scan_radius": 700.0,
	"movement_aggression": 0.4,
	"targeting": {
		"player_bias": 0.4,
		"closest_enemy_weight": 0.9,
		"retarget_interval_sec": 3.0,
		"revenge_bonus": 0.3
	}
}

@export var ambusher_config: Dictionary = {
	"reaction_time_sec": 0.3,
	"reaction_jitter_sec": 0.12,
	"aim_error_deg": {"min": 3.0, "max": 7.0},
	"burst_window_sec": {"fire": 1.3, "cooldown": 0.8},
	"aggression_multiplier": 1.0,
	"chase_distance": 650.0,
	"engagement_range": {"min": 120.0, "max": 400.0},
	"retreat_threshold": 0.2,
	"pickup_scan_radius": 600.0,
	"movement_aggression": 0.6,
	"targeting": {
		"player_bias": 0.5,
		"closest_enemy_weight": 0.6,
		"wounded_target_bonus": 0.4,
		"retarget_interval_sec": 2.5
	}
}

@export var mini_boss_config: Dictionary = {
	"reaction_time_sec": 0.35,
	"reaction_jitter_sec": 0.1,
	"aim_error_deg": {"min": 2.5, "max": 5.5},
	"burst_window_sec": {"fire": 2.0, "cooldown": 1.2},
	"aggression_multiplier": 1.1,
	"chase_distance": 750.0,
	"engagement_range": {"min": 180.0, "max": 550.0},
	"retreat_threshold": 0.15,
	"pickup_scan_radius": 800.0,
	"movement_aggression": 0.7,
	"targeting": {
		"player_bias": 0.6,
		"wounded_target_bonus": 0.4,
		"max_engagement_distance": 850.0,
		"retarget_interval_sec": 1.8,
		"revenge_bonus": 0.5
	}
}

@export var boss_config: Dictionary = {
	"reaction_time_sec": 0.2,
	"reaction_jitter_sec": 0.05,
	"aim_error_deg": {"min": 1.0, "max": 3.0},
	"burst_window_sec": {"fire": 2.5, "cooldown": 1.5},
	"aggression_multiplier": 1.5,
	"chase_distance": 1000.0,
	"engagement_range": {"min": 250.0, "max": 700.0},
	"retreat_threshold": 0.1,
	"pickup_scan_radius": 900.0,
	"movement_aggression": 0.9
}

var _archetype_cache := {}

func _init():
	_populate_archetype_cache()
	_debug_log("AIArchetypeRegistry initialized with " + str(_archetype_cache.size()) + " archetypes")

## Populate internal cache with exported configurations
func _populate_archetype_cache():
	_archetype_cache = {
		"aggressor": aggressor_config,
		"defender": defender_config,
		"ambusher": ambusher_config,
		"mini_boss": mini_boss_config,
		"boss": boss_config
	}

## Get archetype configuration by name
func get_archetype(name: String) -> Dictionary:
	if not _archetype_cache.has(name):
		push_warning("AIArchetypeRegistry: Unknown archetype '" + name + "', using aggressor defaults")
		return aggressor_config.duplicate(true)

	var config = _archetype_cache[name].duplicate(true)
	_debug_log("Retrieved archetype config for: " + name)
	return config

## Get all available archetype names
func get_archetype_names() -> Array:
	return _archetype_cache.keys()

## Blend archetype defaults with per-car profile overrides
func blend_with_profile(archetype_name: String, profile_overrides: Dictionary) -> Dictionary:
	var base_config = get_archetype(archetype_name)
	var blended = base_config.duplicate(true)

	# Apply profile overrides to archetype base
	for key in profile_overrides.keys():
		if key in blended:
			# Handle nested dictionaries (like aim_error_deg, burst_window_sec)
			if blended[key] is Dictionary and profile_overrides[key] is Dictionary:
				var nested_blend = blended[key].duplicate(true)
				for nested_key in profile_overrides[key].keys():
					nested_blend[nested_key] = profile_overrides[key][nested_key]
				blended[key] = nested_blend
			else:
				blended[key] = profile_overrides[key]
		else:
			# Add new keys from profile
			blended[key] = profile_overrides[key]

	_debug_log("Blended archetype '" + archetype_name + "' with profile overrides")
	return blended

## Get reaction time with jitter applied
func get_reaction_time(archetype_name: String) -> float:
	var config = get_archetype(archetype_name)
	var base_time = config.get("reaction_time_sec", 0.35)
	var jitter = config.get("reaction_jitter_sec", 0.12)
	return base_time + randf_range(-jitter, jitter)

## Get random aim error within archetype bounds
func get_aim_error(archetype_name: String) -> float:
	var config = get_archetype(archetype_name)
	var error_range = config.get("aim_error_deg", {"min": 3.5, "max": 9.0})
	return randf_range(error_range.get("min", 3.5), error_range.get("max", 9.0))

## Get burst timing for weapon firing
func get_burst_timing(archetype_name: String) -> Dictionary:
	var config = get_archetype(archetype_name)
	return config.get("burst_window_sec", {"fire": 1.4, "cooldown": 0.8})

## Check if archetype should retreat at given health percentage
func should_retreat(archetype_name: String, health_percentage: float) -> bool:
	var config = get_archetype(archetype_name)
	var threshold = config.get("retreat_threshold", 0.3)
	return health_percentage <= threshold

## Get engagement range for this archetype
func get_engagement_range(archetype_name: String) -> Dictionary:
	var config = get_archetype(archetype_name)
	return config.get("engagement_range", {"min": 150.0, "max": 500.0})

## Get chase distance for target pursuit
func get_chase_distance(archetype_name: String) -> float:
	var config = get_archetype(archetype_name)
	return config.get("chase_distance", 600.0)

## Get pickup scanning radius
func get_pickup_scan_radius(archetype_name: String) -> float:
	var config = get_archetype(archetype_name)
	return config.get("pickup_scan_radius", 640.0)

## Get movement aggression factor (affects speed/maneuver choices)
func get_movement_aggression(archetype_name: String) -> float:
	var config = get_archetype(archetype_name)
	return config.get("movement_aggression", 0.6)

## Get aggression multiplier for damage/weapon usage scaling
func get_aggression_multiplier(archetype_name: String) -> float:
	var config = get_archetype(archetype_name)
	return config.get("aggression_multiplier", 1.0)

## Refresh archetype cache from exported properties (for editor changes)
func refresh_cache():
	_populate_archetype_cache()
	_debug_log("Archetype cache refreshed")

## Debug logging helper
func _debug_log(msg: String):
	if DEBUG_ARCHETYPES:
		print("[AIArchetypeRegistry] ", msg)

