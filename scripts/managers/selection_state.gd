extends Node

## SelectionState - Manages player character selection across scenes
## Autoloaded singleton that persists the chosen character roster entry

var roster := []
var selected_index := 0
var selected_entry: Dictionary = {}

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
		selected_entry = roster[0]
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
			selected_entry = roster[index]
		else:
			push_warning("Invalid selection index: " + str(index))
	elif index_or_dict is Dictionary:
		selected_entry = index_or_dict
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