extends Node

## Health Check System for Regression Prevention
## Validates critical systems to prevent common failures like "red car + no WASD"

signal health_check_failed(issues: Array)
signal health_check_passed()

var _validation_results: Array = []

func _ready():
	# Only run health checks in debug builds to avoid performance impact in release
	if OS.is_debug_build():
		call_deferred("run_health_check")

func run_health_check() -> bool:
	_validation_results.clear()
	print("🔍 Running health check for regression prevention...")

	var all_passed = true

	# Critical Check 1: Input mapping validation
	if not _validate_input_system():
		all_passed = false

	# Critical Check 2: Script compilation validation
	if not _validate_critical_scripts():
		all_passed = false

	# Critical Check 3: Character loading system
	if not _validate_character_system():
		all_passed = false

	if all_passed:
		print("✅ Health check passed - no regressions detected")
		health_check_passed.emit()
	else:
		print("🚨 HEALTH CHECK FAILED - REGRESSION DETECTED 🚨")
		for issue in _validation_results:
			print("  ❌ ", issue)
		print("🚨 " + "="*50 + " 🚨")
		health_check_failed.emit(_validation_results)

	return all_passed

func _validate_input_system() -> bool:
	var passed = true
	var critical_actions = ["move_up", "move_down", "move_left", "move_right", "fire_primary", "fire_special"]

	for action in critical_actions:
		if not InputMap.has_action(action):
			_validation_results.append("CRITICAL: Missing input action: " + action)
			passed = false
		else:
			var events = InputMap.action_get_events(action)
			if events.size() == 0:
				_validation_results.append("CRITICAL: Input action has no events: " + action)
				passed = false
			else:
				# Check for corrupted input actions (common regression pattern)
				for event in events:
					if event == null:
						_validation_results.append("CRITICAL: Null event in input action: " + action)
						passed = false

	if passed:
		print("  ✅ Input system validation passed")

	return passed

func _validate_critical_scripts() -> bool:
	var passed = true
	var critical_scripts = [
		"res://scripts/vehicles/player_car.gd",
		"res://scripts/vehicles/enemy_car.gd",
		"res://scripts/weapons/missile.gd",
		"res://scripts/managers/game_manager.gd"
	]

	for script_path in critical_scripts:
		if not ResourceLoader.exists(script_path):
			_validation_results.append("CRITICAL: Missing critical script: " + script_path)
			passed = false
		else:
			# Try to load the script to check for compilation errors
			var script_resource = load(script_path)
			if script_resource == null:
				_validation_results.append("CRITICAL: Failed to load script: " + script_path)
				passed = false

	if passed:
		print("  ✅ Critical scripts validation passed")

	return passed

func _validate_character_system() -> bool:
	var passed = true

	# Check that roster file exists and is accessible
	var roster_path = "res://assets/data/roster.json"
	if not FileAccess.file_exists(roster_path):
		_validation_results.append("CRITICAL: Missing roster file: " + roster_path)
		passed = false
	else:
		# Try to load roster data
		var file = FileAccess.open(roster_path, FileAccess.READ)
		if file == null:
			_validation_results.append("CRITICAL: Cannot open roster file: " + roster_path)
			passed = false
		else:
			var json_text = file.get_as_text()
			file.close()

			var json = JSON.new()
			if json.parse(json_text) != OK:
				_validation_results.append("CRITICAL: Invalid JSON in roster file")
				passed = false
			else:
				var roster_data = json.data
				if not roster_data is Dictionary:
					_validation_results.append("CRITICAL: Invalid roster format - not a dictionary")
					passed = false
				else:
					var characters = roster_data.get("characters", [])
					if characters.size() == 0:
						_validation_results.append("CRITICAL: No characters in roster file")
						passed = false

	if passed:
		print("  ✅ Character system validation passed")

	return passed

## Manual health check trigger for debugging
func force_health_check() -> bool:
	return run_health_check()

## Get last validation results for external inspection
func get_last_results() -> Array:
	return _validation_results.duplicate()

## Check for specific banned patterns that cause regressions
func validate_project_files() -> Array:
	var violations = []

	# Check for class_name declarations in scripts (historical problem)
	var script_files = _get_all_script_files()
	for script_path in script_files:
		violations.append_array(_check_script_for_banned_patterns(script_path))

	# Check project.godot for inline comment corruption
	violations.append_array(_check_project_godot_patterns())

	return violations

func _get_all_script_files() -> Array:
	var script_files = []
	_scan_directory_for_scripts("res://scripts", script_files)
	return script_files

func _scan_directory_for_scripts(path: String, script_files: Array):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var full_path = path + "/" + file_name
			if dir.current_is_dir() and not file_name.begins_with("."):
				_scan_directory_for_scripts(full_path, script_files)
			elif file_name.ends_with(".gd"):
				script_files.append(full_path)
			file_name = dir.get_next()

func _check_script_for_banned_patterns(script_path: String) -> Array:
	var violations = []

	if not FileAccess.file_exists(script_path):
		return violations

	var file = FileAccess.open(script_path, FileAccess.READ)
	if file == null:
		return violations

	var content = file.get_as_text()
	file.close()

	# Check for class_name declarations (causes script dependency issues)
	var regex = RegEx.new()
	regex.compile(r"class_name\s+\w+")
	var result = regex.search(content)
	if result:
		violations.append("BANNED PATTERN: class_name declaration in " + script_path + " - use constants instead")

	return violations

func _check_project_godot_patterns() -> Array:
	var violations = []
	var project_path = "res://project.godot"

	if not FileAccess.file_exists(project_path):
		return violations

	var file = FileAccess.open(project_path, FileAccess.READ)
	if file == null:
		return violations

	var content = file.get_as_text()
	file.close()

	# Check for inline comments that corrupt input actions
	var lines = content.split("\n")
	for i in range(lines.size()):
		var line = lines[i]
		# Look for patterns like "#SomeCommentaction_name={"
		if line.contains("#") and line.contains("={") and not line.strip_edges().starts_with("#"):
			violations.append("BANNED PATTERN: Inline comment corruption in project.godot line " + str(i + 1))

	return violations