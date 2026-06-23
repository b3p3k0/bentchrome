extends Node

## Code Validator for Regression Prevention
## Scans for dangerous patterns that historically cause issues

# Patterns that have caused regressions in the past
const BANNED_PATTERNS = [
	{
		"pattern": r"class_name\s+\w+",
		"file_types": ["*.gd"],
		"severity": "CRITICAL",
		"reason": "class_name declarations cause script dependency issues",
		"alternative": "Use enums or constants within the script instead",
		"example_fix": "Replace 'class_name BaseMissile' with 'const TYPE_POWER = 0'"
	},
	{
		"pattern": r"#\w+.*=\s*\{",
		"file_types": ["project.godot"],
		"severity": "CRITICAL",
		"reason": "Inline comments corrupt input action definitions",
		"alternative": "Put comments on separate lines",
		"example_fix": "Replace '#Commentaction_name={' with '# Comment\\naction_name={'"
	},
	{
		"pattern": r"BaseMissile\.MissileType\.",
		"file_types": ["*.gd"],
		"severity": "HIGH",
		"reason": "Cross-script enum references cause compilation failures",
		"alternative": "Use integer constants instead",
		"example_fix": "Replace 'BaseMissile.MissileType.POWER' with '0 # TYPE_POWER'"
	}
]

# High-risk file patterns to monitor closely
const HIGH_RISK_FILES = [
	"project.godot",
	"scripts/vehicles/player_car.gd",
	"scripts/vehicles/enemy_car.gd",
	"scripts/weapons/missile.gd",
	"scripts/managers/game_manager.gd"
]

func validate_project() -> Dictionary:
	var results = {
		"violations": [],
		"warnings": [],
		"files_scanned": 0,
		"patterns_checked": BANNED_PATTERNS.size()
	}

	print("🔍 Running code validation for banned patterns...")

	# Scan all relevant files
	var files_to_scan = _get_files_to_scan()
	results.files_scanned = files_to_scan.size()

	for file_path in files_to_scan:
		var file_violations = _scan_file_for_patterns(file_path)
		results.violations.append_array(file_violations)

	# Check high-risk files specifically
	for risk_file in HIGH_RISK_FILES:
		var full_path = "res://" + risk_file
		if FileAccess.file_exists(full_path):
			var risk_violations = _scan_high_risk_file(full_path)
			results.violations.append_array(risk_violations)

	_print_results(results)
	return results

func _get_files_to_scan() -> Array:
	var files = []

	# Scan scripts directory
	_scan_directory_recursive("res://scripts", files, ["*.gd"])

	# Add project.godot
	files.append("res://project.godot")

	return files

func _scan_directory_recursive(path: String, files: Array, extensions: Array):
	var dir = DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		var full_path = path + "/" + file_name

		if dir.current_is_dir() and not file_name.begins_with("."):
			_scan_directory_recursive(full_path, files, extensions)
		else:
			for ext in extensions:
				if file_name.ends_with(ext.substr(1)):  # Remove * from pattern
					files.append(full_path)
					break

		file_name = dir.get_next()

func _scan_file_for_patterns(file_path: String) -> Array:
	var violations = []

	if not FileAccess.file_exists(file_path):
		return violations

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return violations

	var content = file.get_as_text()
	file.close()

	# Check each banned pattern
	for pattern_def in BANNED_PATTERNS:
		if _file_matches_type(file_path, pattern_def.file_types):
			var matches = _find_pattern_matches(content, pattern_def.pattern)
			for match_info in matches:
				violations.append({
					"file": file_path,
					"line": match_info.line,
					"severity": pattern_def.severity,
					"reason": pattern_def.reason,
					"alternative": pattern_def.alternative,
					"example_fix": pattern_def.example_fix,
					"matched_text": match_info.text
				})

	return violations

func _scan_high_risk_file(file_path: String) -> Array:
	var violations = []

	# Additional checks for high-risk files
	if file_path.ends_with("project.godot"):
		violations.append_array(_check_project_godot_integrity(file_path))
	elif file_path.ends_with("player_car.gd"):
		violations.append_array(_check_player_car_integrity(file_path))

	return violations

func _check_project_godot_integrity(file_path: String) -> Array:
	var violations = []

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return violations

	var lines = file.get_as_text().split("\n")
	file.close()

	for i in range(lines.size()):
		var line = lines[i].strip_edges()

		# Check for corrupted input actions (historical problem)
		if line.contains("#") and line.contains("={") and not line.starts_with("#"):
			violations.append({
				"file": file_path,
				"line": i + 1,
				"severity": "CRITICAL",
				"reason": "Inline comment corruption detected in input action",
				"alternative": "Move comment to separate line",
				"matched_text": line
			})

	return violations

func _check_player_car_integrity(file_path: String) -> Array:
	var violations = []

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return violations

	var content = file.get_as_text()
	file.close()

	# Check for problematic cross-script references
	if content.contains("BaseMissile."):
		violations.append({
			"file": file_path,
			"line": -1,
			"severity": "HIGH",
			"reason": "Cross-script reference to BaseMissile detected",
			"alternative": "Use integer constants instead of class references"
		})

	return violations

func _file_matches_type(file_path: String, file_types: Array) -> bool:
	for type_pattern in file_types:
		if type_pattern == "*.gd" and file_path.ends_with(".gd"):
			return true
		elif type_pattern == "project.godot" and file_path.ends_with("project.godot"):
			return true
	return false

func _find_pattern_matches(content: String, pattern: String) -> Array:
	var matches = []
	var regex = RegEx.new()

	if regex.compile(pattern) != OK:
		print("Warning: Failed to compile regex pattern: ", pattern)
		return matches

	var lines = content.split("\n")
	for i in range(lines.size()):
		var result = regex.search(lines[i])
		if result:
			matches.append({
				"line": i + 1,
				"text": result.get_string()
			})

	return matches

func _print_results(results: Dictionary):
	print("📊 Code validation results:")
	print("  Files scanned: ", results.files_scanned)
	print("  Patterns checked: ", results.patterns_checked)
	print("  Violations found: ", results.violations.size())

	if results.violations.size() > 0:
		print("🚨 VIOLATIONS DETECTED:")
		for violation in results.violations:
			print("  ❌ [", violation.severity, "] ", violation.file, ":", violation.get("line", "?"))
			print("     Reason: ", violation.reason)
			print("     Fix: ", violation.alternative)
			if violation.has("example_fix"):
				print("     Example: ", violation.example_fix)
	else:
		print("✅ No banned patterns detected")

## Manual validation trigger
func validate_specific_file(file_path: String) -> Array:
	return _scan_file_for_patterns(file_path)

## Check if a specific pattern exists in project
func check_pattern(pattern: String, file_types: Array = ["*.gd"]) -> Array:
	var violations = []
	var files = _get_files_to_scan()

	for file_path in files:
		if _file_matches_type(file_path, file_types):
			var matches = _find_pattern_matches(FileAccess.open(file_path, FileAccess.READ).get_as_text(), pattern)
			for match_info in matches:
				violations.append({
					"file": file_path,
					"line": match_info.line,
					"matched_text": match_info.text
				})

	return violations