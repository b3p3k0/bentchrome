extends Node

## AI Profile Loader - Singleton for managing AI behavior configurations
## Loads and caches AI profiles from JSON, merges with defaults, provides lookup helpers
## Validates schema and provides fallback values when profiles are missing

## Debug flag for AI profile loading
const DEBUG_AI_PROFILES: bool = true

var _profiles := {}
var _defaults := {}
var _loaded := false

func _ready():
	_debug_log("AIProfileLoader initialized")
	# Auto-load profiles on startup
	load_profiles("res://assets/data/ai_profiles.json")

## Load and parse AI profiles from JSON file
func load_profiles(path: String) -> void:
	_debug_log("Loading AI profiles from: " + path)

	# Check if file exists
	if not FileAccess.file_exists(path):
		push_error("AIProfileLoader: Profile file not found: " + path)
		_provide_emergency_fallbacks()
		return

	# Load and parse JSON
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("AIProfileLoader: Could not open profile file: " + path)
		_provide_emergency_fallbacks()
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("AIProfileLoader: Invalid JSON in profile file: " + path)
		_provide_emergency_fallbacks()
		return

	var data = json.data
	if not data is Dictionary:
		push_error("AIProfileLoader: Profile file root is not a Dictionary")
		_provide_emergency_fallbacks()
		return

	# Extract defaults
	var defaults = data.get("defaults", {})
	set_defaults(defaults)

	# Extract and validate profiles
	var profiles_array = data.get("profiles", [])
	if not profiles_array is Array:
		push_error("AIProfileLoader: 'profiles' is not an Array")
		_provide_emergency_fallbacks()
		return

	# Process each profile
	_profiles.clear()
	var loaded_count = 0
	for profile_data in profiles_array:
		if not profile_data is Dictionary:
			push_warning("AIProfileLoader: Skipping non-Dictionary profile entry")
			continue

		var roster_id = profile_data.get("id", "")
		if roster_id.is_empty():
			push_warning("AIProfileLoader: Skipping profile with missing 'id'")
			continue

		# Validate against roster.json
		if not _validate_roster_id(roster_id):
			push_warning("AIProfileLoader: Profile ID '" + roster_id + "' not found in roster.json")
			continue

		# Store raw profile (will be merged with defaults on access)
		_profiles[roster_id] = profile_data
		loaded_count += 1
		_debug_log("Loaded profile for: " + roster_id)

	_loaded = true
	_debug_log("Successfully loaded " + str(loaded_count) + " AI profiles")

## Store default values for profile merging
func set_defaults(data: Dictionary) -> void:
	_defaults = data.duplicate(true)
	_debug_log("Set defaults with " + str(_defaults.size()) + " entries")

## Get merged profile for a specific roster ID
func get_profile(roster_id: String) -> Dictionary:
	if not _loaded:
		push_warning("AIProfileLoader: Profiles not loaded yet, returning empty profile for: " + roster_id)
		return _create_empty_profile(roster_id)

	# Check if profile exists
	if not _profiles.has(roster_id):
		push_warning("AIProfileLoader: No profile found for roster ID: " + roster_id + ", using defaults")
		return _create_empty_profile(roster_id)

	# Merge profile with defaults
	var profile = _profiles[roster_id].duplicate(true)
	var merged = _merge_with_defaults(profile)

	_debug_log("Retrieved profile for: " + roster_id + " (archetype: " + merged.get("archetype", "unknown") + ")")
	return merged

## Get all profiles matching a specific archetype
func get_profiles_by_archetype(archetype: String) -> Array:
	var matching_profiles = []

	if not _loaded:
		push_warning("AIProfileLoader: Profiles not loaded yet")
		return matching_profiles

	for roster_id in _profiles.keys():
		var profile = get_profile(roster_id)
		if profile.get("archetype", "") == archetype:
			matching_profiles.append(profile)

	_debug_log("Found " + str(matching_profiles.size()) + " profiles for archetype: " + archetype)
	return matching_profiles

## Get list of all loaded roster IDs
func get_loaded_roster_ids() -> Array:
	return _profiles.keys()

## Check if a profile exists for the given roster ID
func has_profile(roster_id: String) -> bool:
	return _profiles.has(roster_id)

## Validate that a roster ID exists in the roster.json file
func _validate_roster_id(roster_id: String) -> bool:
	# Load roster.json for validation
	var roster_path = "res://assets/data/roster.json"
	if not FileAccess.file_exists(roster_path):
		push_warning("AIProfileLoader: Could not validate roster ID - roster.json not found")
		return true  # Assume valid if we can't check

	var file = FileAccess.open(roster_path, FileAccess.READ)
	if file == null:
		push_warning("AIProfileLoader: Could not open roster.json for validation")
		return true

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_text) != OK:
		push_warning("AIProfileLoader: Could not parse roster.json for validation")
		return true

	var roster_data = json.data
	if not roster_data is Dictionary:
		return true

	var characters = roster_data.get("characters", [])
	if not characters is Array:
		return true

	# Check if roster_id exists in characters array
	for character in characters:
		if character is Dictionary and character.get("id", "") == roster_id:
			return true

	return false

## Merge profile data with defaults, handling nested dictionaries
func _merge_with_defaults(profile: Dictionary) -> Dictionary:
	var merged = _defaults.duplicate(true)

	# Merge top-level keys
	for key in profile.keys():
		if key in merged and merged[key] is Dictionary and profile[key] is Dictionary:
			# Recursive merge for nested dictionaries
			merged[key] = _merge_dictionaries(merged[key], profile[key])
		else:
			# Direct assignment for non-dictionary values
			merged[key] = profile[key]

	return merged

## Recursively merge two dictionaries
func _merge_dictionaries(base: Dictionary, override: Dictionary) -> Dictionary:
	var result = base.duplicate(true)

	for key in override.keys():
		if key in result and result[key] is Dictionary and override[key] is Dictionary:
			result[key] = _merge_dictionaries(result[key], override[key])
		else:
			result[key] = override[key]

	return result

## Create an empty profile with defaults for missing roster IDs
func _create_empty_profile(roster_id: String) -> Dictionary:
	var empty_profile = _defaults.duplicate(true)
	empty_profile["id"] = roster_id
	empty_profile["archetype"] = _defaults.get("archetype", "aggressor")
	return empty_profile

## Provide emergency fallback profiles when JSON loading fails
func _provide_emergency_fallbacks() -> void:
	push_warning("AIProfileLoader: Using emergency fallback profiles")

	# Set basic defaults
	_defaults = {
		"archetype": "aggressor",
		"reaction_time_sec": 0.35,
		"reaction_jitter_sec": 0.12,
		"aim_error_deg": {"min": 3.5, "max": 9.0},
		"burst_window_sec": {"fire": 1.4, "cooldown": 0.8},
		"retreat_threshold": 0.3,
		"pickup_scan_radius": 640.0
	}

	# Create basic profiles for all known roster IDs
	var known_roster_ids = ["bumper", "cricket", "ghost", "hammertoe", "kandykane", "mrghastly", "razorback", "smoky", "splatcat"]
	_profiles.clear()

	for roster_id in known_roster_ids:
		_profiles[roster_id] = {
			"id": roster_id,
			"archetype": "aggressor"
		}

	_loaded = true
	_debug_log("Emergency fallback profiles created for " + str(known_roster_ids.size()) + " roster IDs")

## Debug logging helper
func _debug_log(msg: String):
	if DEBUG_AI_PROFILES:
		print("[AIProfileLoader] ", msg)
