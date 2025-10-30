extends Node

## SelectionState - Manages player character selection across scenes
## Autoloaded singleton that persists the chosen character roster entry

var roster := []
var selected_index := 0
var selected_entry: Dictionary = {}
var match_opponent_ids: Array = []

const CORE_INPUT_BINDINGS := {
	"move_up": [
		{"type": "key", "code": Key.KEY_W},
		{"type": "key", "code": Key.KEY_UP},
		{"type": "joy_button", "button": JOY_BUTTON_DPAD_UP},
		{"type": "joy_axis", "axis": JOY_AXIS_LEFT_Y, "value": -1.0}
	],
	"move_down": [
		{"type": "key", "code": Key.KEY_S},
		{"type": "key", "code": Key.KEY_DOWN},
		{"type": "joy_button", "button": JOY_BUTTON_DPAD_DOWN},
		{"type": "joy_axis", "axis": JOY_AXIS_LEFT_Y, "value": 1.0}
	],
	"move_left": [
		{"type": "key", "code": Key.KEY_A},
		{"type": "key", "code": Key.KEY_LEFT},
		{"type": "joy_button", "button": JOY_BUTTON_DPAD_LEFT},
		{"type": "joy_axis", "axis": JOY_AXIS_LEFT_X, "value": -1.0}
	],
	"move_right": [
		{"type": "key", "code": Key.KEY_D},
		{"type": "key", "code": Key.KEY_RIGHT},
		{"type": "joy_button", "button": JOY_BUTTON_DPAD_RIGHT},
		{"type": "joy_axis", "axis": JOY_AXIS_LEFT_X, "value": 1.0}
	],
	"fire_primary": [
		{"type": "key", "code": Key.KEY_SPACE},
		{"type": "mouse_button", "button": MOUSE_BUTTON_LEFT}
	],
	"fire_special": [
		{"type": "mouse_button", "button": MOUSE_BUTTON_RIGHT}
	],
	"select_prev_car": [
		{"type": "key", "code": Key.KEY_LEFT}
	],
	"select_next_car": [
		{"type": "key", "code": Key.KEY_RIGHT}
	],
	"select_confirm": [
		{"type": "key", "code": Key.KEY_ENTER},
		{"type": "key", "code": Key.KEY_KP_ENTER},
		{"type": "key", "code": Key.KEY_SPACE}
	]
}

func _ready():
	_ensure_core_input_actions()

func _strip_comments(text: String) -> String:
	var lines = text.split("\n")
	var cleaned_lines = []
	for line in lines:
		if not line.strip_edges().begins_with("//"):
			cleaned_lines.append(line)
	return "\n".join(cleaned_lines)

func _validate_roster_entry(entry: Dictionary, index: int) -> bool:
	var entry_id = entry.get("id", "entry_" + str(index))

	# Check required fields
	if not entry.has("id"):
		push_error("Roster entry missing 'id' field (index=" + str(index) + ")")
		return false
	if not entry.has("portrait"):
		push_error("Roster entry missing 'portrait' field (id=" + entry_id + ")")
		return false
	if not entry.has("stats") or not entry.stats is Dictionary:
		push_error("Roster entry missing 'stats' object (id=" + entry_id + ")")
		return false

	# Validate portrait path
	var portrait_path = entry.portrait
	if not portrait_path.begins_with("res://assets/img/bios/"):
		push_error("Invalid portrait path for " + entry_id + ": " + portrait_path)
		return false
	if not ResourceLoader.exists(portrait_path):
		push_error("Portrait file not found for " + entry_id + ": " + portrait_path)
		return false

	# Validate stats has all required numeric fields
	var stats = entry.stats
	var required_stats = ["acceleration", "top_speed", "handling", "armor", "special_power"]
	for stat_name in required_stats:
		if not stats.has(stat_name):
			push_error("Roster entry missing stats." + stat_name + " (id=" + entry_id + ")")
			return false
		if not stats[stat_name] is int and not stats[stat_name] is float:
			push_error("Invalid stats." + stat_name + " type for " + entry_id + " (expected number)")
			return false

	return true

func load_roster(path: String) -> bool:
	# Make idempotent - return early if already loaded
	if roster.size() > 0:
		return true

	if not FileAccess.file_exists(path):
		push_error("Roster file not found: " + path)
		return false

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open roster file: " + path)
		return false

	var json_string = file.get_as_text()
	file.close()

	# Strip comment lines before parsing
	json_string = _strip_comments(json_string)

	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse roster JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		return false

	var data = json.data
	var character_array: Array

	# Support both {"characters": [...]} and direct array formats
	if data is Array:
		character_array = data
	elif data is Dictionary and data.has("characters") and data.characters is Array:
		character_array = data.characters
	else:
		push_error("Roster must be either Array or {characters: Array}")
		return false

	# Validate each entry
	for i in range(character_array.size()):
		if not _validate_roster_entry(character_array[i], i):
			return false

	roster = character_array
	selected_index = 0

	if roster.size() > 0:
		selected_entry = _duplicate_entry(roster[0])
		print("Loaded roster with ", roster.size(), " characters")
		return true
	else:
		push_error("No characters found in roster")
		return false

func set_selection(index_or_dict) -> void:
	if index_or_dict is int:
		var index = index_or_dict as int
		if index >= 0 and index < roster.size():
			selected_index = index
			selected_entry = _duplicate_entry(roster[index])
		else:
			push_warning("Invalid selection index: " + str(index))
	elif index_or_dict is Dictionary:
		selected_entry = _duplicate_entry(index_or_dict)
		# Find matching index in roster
		for i in range(roster.size()):
			if roster[i].get("id", "") == selected_entry.get("id", ""):
				selected_index = i
				break
	else:
		push_warning("Invalid selection type, expected int or Dictionary")

func get_selection() -> Dictionary:
	return selected_entry

func has_selection() -> bool:
	return not selected_entry.is_empty()

func get_roster() -> Array:
	return roster

func get_selected_index() -> int:
	return selected_index

func has_match_opponents() -> bool:
	return match_opponent_ids.size() > 0

func get_match_opponents() -> Array:
	return match_opponent_ids.duplicate()

func set_match_opponents(opponent_ids: Array) -> void:
	match_opponent_ids = opponent_ids.duplicate()

func clear_match_opponents() -> void:
	match_opponent_ids.clear()

func prepare_match_opponents(desired_count: int) -> Array:
	if desired_count <= 0:
		clear_match_opponents()
		return []

	var candidate_ids := _build_candidate_opponent_ids()
	if candidate_ids.is_empty():
		clear_match_opponents()
		return []

	match_opponent_ids = _select_unique_roster_ids(candidate_ids, desired_count)
	return get_match_opponents()

func _build_candidate_opponent_ids() -> Array:
	var ids: Array = []

	if Engine.has_singleton("AIProfileLoader") and AIProfileLoader:
		ids = AIProfileLoader.get_loaded_roster_ids().duplicate()
	elif roster.size() > 0:
		for entry in roster:
			if entry is Dictionary and entry.has("id"):
				ids.append(entry.get("id"))
	else:
		ids = _load_roster_ids_from_file()

	var player_id := _get_player_roster_id()
	if player_id != "":
		ids.erase(player_id)

	return ids

func _select_unique_roster_ids(candidate_ids: Array, desired_count: int) -> Array:
	var selection: Array = []
	if candidate_ids.is_empty() or desired_count <= 0:
		return selection

	var pool := candidate_ids.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	while selection.size() < desired_count and not pool.is_empty():
		var index := rng.randi_range(0, pool.size() - 1)
		selection.append(pool[index])
		pool.remove_at(index)

	if selection.size() < desired_count and not candidate_ids.is_empty():
		while selection.size() < desired_count:
			var index := rng.randi_range(0, candidate_ids.size() - 1)
			selection.append(candidate_ids[index])

	return selection

func _duplicate_entry(entry: Dictionary) -> Dictionary:
	return entry.duplicate(true)

func _ensure_core_input_actions():
	for action_name in CORE_INPUT_BINDINGS.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name, 0.5)

		for definition in CORE_INPUT_BINDINGS[action_name]:
			if not _action_has_binding(action_name, definition):
				var event = _create_input_event(definition)
				if event:
					InputMap.action_add_event(action_name, event)

func _action_has_binding(action_name: String, definition: Dictionary) -> bool:
	if not InputMap.has_action(action_name):
		return false

	for event in InputMap.action_get_events(action_name):
		match definition.get("type", ""):
			"key":
				if event is InputEventKey and event.physical_keycode == definition.get("code", -1):
					return true
			"joy_button":
				if event is InputEventJoypadButton and event.button_index == definition.get("button", -1):
					return true
			"joy_axis":
				if event is InputEventJoypadMotion \
						and event.axis == definition.get("axis", -1) \
						and is_equal_approx(event.axis_value, definition.get("value", 0.0)):
					return true
			"mouse_button":
				if event is InputEventMouseButton and event.button_index == definition.get("button", -1):
					return true
	return false

func _create_input_event(definition: Dictionary) -> InputEvent:
	match definition.get("type", ""):
		"key":
			var key_event := InputEventKey.new()
			key_event.physical_keycode = definition.get("code", 0)
			return key_event
		"joy_button":
			var joy_event := InputEventJoypadButton.new()
			joy_event.button_index = definition.get("button", 0)
			return joy_event
		"joy_axis":
			var axis_event := InputEventJoypadMotion.new()
			axis_event.axis = definition.get("axis", 0)
			axis_event.axis_value = definition.get("value", 0.0)
			return axis_event
		"mouse_button":
			var mouse_event := InputEventMouseButton.new()
			mouse_event.button_index = definition.get("button", 0)
			return mouse_event
	return null

func _get_player_roster_id() -> String:
	if has_selection():
		return selected_entry.get("id", "")
	return ""

func _load_roster_ids_from_file() -> Array:
	var ids: Array = []
	var roster_path := "res://assets/data/roster.json"

	if not FileAccess.file_exists(roster_path):
		return ids

	var file := FileAccess.open(roster_path, FileAccess.READ)
	if file == null:
		return ids

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_text) != OK:
		return ids

	var data = json.data
	if data is Dictionary:
		var characters = data.get("characters", [])
		for character in characters:
			if character is Dictionary and character.has("id"):
				ids.append(character.get("id"))

	return ids
