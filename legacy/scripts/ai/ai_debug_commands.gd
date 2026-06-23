extends Node

## AI Debug Commands - Lightweight debugging tools for AI system validation
## Provides console commands and helper functions for testing AI profiles and behavior

## Print all loaded AI profiles with their archetypes
static func debug_list_profiles():
	print("=== AI Profile Debug Listing ===")

	if not AIProfileLoader:
		print("ERROR: AIProfileLoader not available")
		return

	var roster_ids = AIProfileLoader.get_loaded_roster_ids()
	if roster_ids.is_empty():
		print("No AI profiles loaded")
		return

	print("Loaded profiles: " + str(roster_ids.size()))
	for roster_id in roster_ids:
		var profile = AIProfileLoader.get_profile(roster_id)
		var archetype = profile.get("archetype", "unknown")
		print("  " + roster_id + " -> " + archetype)

	print("=== End Profile Listing ===")

## Print detailed profile information for a specific roster ID
static func debug_profile_details(roster_id: String):
	print("=== AI Profile Details: " + roster_id + " ===")

	if not AIProfileLoader:
		print("ERROR: AIProfileLoader not available")
		return

	if not AIProfileLoader.has_profile(roster_id):
		print("ERROR: Profile not found for roster ID: " + roster_id)
		return

	var profile = AIProfileLoader.get_profile(roster_id)

	print("Archetype: " + profile.get("archetype", "unknown"))
	print("State Weights:")
	var weights = profile.get("state_weights", {})
	for state in weights.keys():
		print("  " + state + ": " + str(weights[state]))

	print("Weapon Usage:")
	var weapon_usage = profile.get("weapon_usage", {})
	for weapon_type in weapon_usage.keys():
		print("  " + weapon_type + ":")
		var weapon_config = weapon_usage[weapon_type]
		for setting in weapon_config.keys():
			print("    " + setting + ": " + str(weapon_config[setting]))

	print("Mobility:")
	var mobility = profile.get("mobility", {})
	for setting in mobility.keys():
		print("  " + setting + ": " + str(mobility[setting]))

	print("Triggers:")
	var triggers = profile.get("triggers", {})
	for trigger in triggers.keys():
		print("  " + trigger + ": " + str(triggers[trigger]))

	print("=== End Profile Details ===")

## Print all profiles grouped by archetype
static func debug_archetypes():
	print("=== AI Archetypes Debug ===")

	if not AIProfileLoader:
		print("ERROR: AIProfileLoader not available")
		return

	var archetypes = ["aggressor", "defender", "ambusher", "mini_boss", "boss"]

	for archetype in archetypes:
		var profiles = AIProfileLoader.get_profiles_by_archetype(archetype)
		print(archetype + " (" + str(profiles.size()) + "):")
		for profile in profiles:
			print("  " + profile.get("id", "unknown"))

	print("=== End Archetypes Debug ===")

## Validate AI profiles against roster.json
static func debug_validate_profiles():
	print("=== AI Profile Validation ===")

	if not AIProfileLoader:
		print("ERROR: AIProfileLoader not available")
		return

	# Load roster.json for comparison
	var roster_path = "res://assets/data/roster.json"
	if not FileAccess.file_exists(roster_path):
		print("ERROR: Could not find roster.json for validation")
		return

	var file = FileAccess.open(roster_path, FileAccess.READ)
	if file == null:
		print("ERROR: Could not open roster.json")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_text) != OK:
		print("ERROR: Could not parse roster.json")
		return

	var roster_data = json.data
	if not roster_data is Dictionary:
		print("ERROR: Invalid roster.json format")
		return

	var characters = roster_data.get("characters", [])
	var roster_ids = []
	for character in characters:
		if character is Dictionary:
			roster_ids.append(character.get("id", ""))

	# Check for missing profiles
	var ai_roster_ids = AIProfileLoader.get_loaded_roster_ids()
	var missing_profiles = []
	var extra_profiles = []

	for roster_id in roster_ids:
		if roster_id not in ai_roster_ids:
			missing_profiles.append(roster_id)

	for ai_id in ai_roster_ids:
		if ai_id not in roster_ids:
			extra_profiles.append(ai_id)

	print("Roster IDs in roster.json: " + str(roster_ids.size()))
	print("AI Profiles loaded: " + str(ai_roster_ids.size()))

	if missing_profiles.is_empty():
		print("✓ All roster IDs have AI profiles")
	else:
		print("✗ Missing AI profiles for: " + str(missing_profiles))

	if extra_profiles.is_empty():
		print("✓ No extra AI profiles")
	else:
		print("⚠ Extra AI profiles (not in roster): " + str(extra_profiles))

	print("=== End Validation ===")

## Test spawning an enemy with specific roster ID (requires enemy scene)
static func debug_test_spawn(roster_id: String, position: Vector2 = Vector2(100, 100)):
	print("=== AI Spawn Test: " + roster_id + " ===")

	if not GameManager:
		print("ERROR: GameManager not available")
		return

	if not AIProfileLoader or not AIProfileLoader.has_profile(roster_id):
		print("ERROR: No AI profile found for: " + roster_id)
		return

	# Try to load enemy scene
	var enemy_scene_path = "res://scenes/vehicles/EnemyCar.tscn"
	if not FileAccess.file_exists(enemy_scene_path):
		print("ERROR: Enemy scene not found at: " + enemy_scene_path)
		return

	var enemy_scene = load(enemy_scene_path)
	if not enemy_scene:
		print("ERROR: Could not load enemy scene")
		return

	var enemy = GameManager.spawn_enemy(enemy_scene, position, roster_id)
	if enemy:
		print("✓ Successfully spawned enemy: " + roster_id + " at " + str(position))
		print("  Enemy name: " + enemy.name)
		print("  AI archetype: " + enemy.ai_profile.get("archetype", "unknown"))
	else:
		print("✗ Failed to spawn enemy")

	print("=== End Spawn Test ===")

## Test spawning enemies by archetype
static func debug_test_archetype_spawn(archetype: String, count: int = 1):
	print("=== AI Archetype Spawn Test: " + archetype + " ===")

	if not GameManager:
		print("ERROR: GameManager not available")
		return

	var enemy_scene_path = "res://scenes/vehicles/EnemyCar.tscn"
	if not FileAccess.file_exists(enemy_scene_path):
		print("ERROR: Enemy scene not found")
		return

	var enemy_scene = load(enemy_scene_path)
	if not enemy_scene:
		print("ERROR: Could not load enemy scene")
		return

	print("Spawning " + str(count) + " enemies of archetype: " + archetype)
	for i in range(count):
		var position = Vector2(100 + i * 100, 100)
		var enemy = GameManager.spawn_enemy_by_archetype(enemy_scene, position, archetype)
		if enemy:
			print("  Spawned #" + str(i + 1) + ": " + enemy.roster_id + " at " + str(position))
		else:
			print("  Failed to spawn #" + str(i + 1))

	print("=== End Archetype Spawn Test ===")

## Print summary of AI system status
static func debug_system_status():
	print("=== AI System Status ===")

	# Check AIProfileLoader
	if AIProfileLoader:
		print("✓ AIProfileLoader: Available")
		print("  Loaded profiles: " + str(AIProfileLoader.get_loaded_roster_ids().size()))
	else:
		print("✗ AIProfileLoader: Not available")

	# Check GameManager
	if GameManager:
		print("✓ GameManager: Available")
		var counts = GameManager.get_active_object_counts()
		print("  Active enemies: " + str(counts.get("enemies", 0)))
	else:
		print("✗ GameManager: Not available")

	# Check enemy scene
	var enemy_scene_path = "res://scenes/vehicles/EnemyCar.tscn"
	if FileAccess.file_exists(enemy_scene_path):
		print("✓ Enemy scene: Found")
	else:
		print("✗ Enemy scene: Not found")

	# Check available archetypes
	if GameManager:
		var archetypes = GameManager.get_available_archetypes()
		print("Available archetypes: " + str(archetypes))

	print("=== End System Status ===")

## Debug targeting behavior - show who each AI is targeting and why
static func debug_targeting_behavior():
	print("=== AI Targeting Behavior Analysis ===")

	var enemies = Engine.get_main_loop().get_nodes_in_group("enemies")
	var players = Engine.get_main_loop().get_nodes_in_group("player")

	if enemies.is_empty():
		print("No active enemies found")
		return

	if players.is_empty():
		print("No players found")

	print("Active vehicles: " + str(enemies.size()) + " enemies, " + str(players.size()) + " players")
	print("")

	for enemy in enemies:
		if not enemy.has_method("get") or not enemy.roster_id:
			continue

		var target_name = "none"
		var target_type = "none"
		var state = enemy.ai_state if enemy.has_property("ai_state") else "unknown"

		if enemy.ai_target and is_instance_valid(enemy.ai_target):
			target_name = enemy.ai_target.name
			if enemy.ai_target.is_in_group("player"):
				target_type = "player"
			elif enemy.ai_target.is_in_group("enemies"):
				target_type = "enemy"
			else:
				target_type = "other"

		var distance = "N/A"
		if enemy.ai_target and is_instance_valid(enemy.ai_target):
			distance = str(int(enemy.global_position.distance_to(enemy.ai_target.global_position))) + "u"

		print(enemy.roster_id + " (" + state + ") -> " + target_name + " (" + target_type + ") [" + distance + "]")

	print("=== End Targeting Analysis ===")

## Debug threat scores - show threat calculations for all targets
static func debug_threat_scores():
	print("=== AI Threat Score Analysis ===")

	var enemies = Engine.get_main_loop().get_nodes_in_group("enemies")

	if enemies.is_empty():
		print("No active enemies found")
		return

	for enemy in enemies:
		if not enemy.has_method("get") or not enemy.roster_id:
			continue

		print("\n" + enemy.roster_id + " threat scores:")

		if enemy.ai_threat_scores.is_empty():
			print("  No threat scores calculated")
			continue

		# Sort targets by threat score
		var sorted_targets = []
		for target in enemy.ai_threat_scores.keys():
			if is_instance_valid(target):
				sorted_targets.append({
					"target": target,
					"score": enemy.ai_threat_scores[target]
				})

		# Sort by score (highest first)
		sorted_targets.sort_custom(func(a, b): return a.score > b.score)

		for target_data in sorted_targets:
			var target = target_data.target
			var score = target_data.score
			var target_type = "other"

			if target.is_in_group("player"):
				target_type = "player"
			elif target.is_in_group("enemies"):
				target_type = "enemy"

			var distance = int(enemy.global_position.distance_to(target.global_position))
			var current_marker = " <- CURRENT" if target == enemy.ai_target else ""

			print("  " + target.name + " (" + target_type + "): " + str(score).pad_decimals(2) + " [" + str(distance) + "u]" + current_marker)

	print("=== End Threat Score Analysis ===")

## Debug battle royale statistics - show combat engagement patterns
static func debug_battle_royale_stats():
	print("=== Battle Royale Combat Statistics ===")

	var enemies = Engine.get_main_loop().get_nodes_in_group("enemies")
	var players = Engine.get_main_loop().get_nodes_in_group("player")

	if enemies.is_empty():
		print("No active enemies found")
		return

	var player_targeted_count = 0
	var enemy_targeted_count = 0
	var no_target_count = 0
	var archetype_stats = {}

	# Analyze targeting patterns
	for enemy in enemies:
		if not enemy.has_method("get") or not enemy.roster_id:
			continue

		var archetype = "unknown"
		if enemy.ai_profile and enemy.ai_profile.has("archetype"):
			archetype = enemy.ai_profile.archetype

		if not archetype_stats.has(archetype):
			archetype_stats[archetype] = {"total": 0, "targeting_players": 0, "targeting_enemies": 0}

		archetype_stats[archetype].total += 1

		if enemy.ai_target and is_instance_valid(enemy.ai_target):
			if enemy.ai_target.is_in_group("player"):
				player_targeted_count += 1
				archetype_stats[archetype].targeting_players += 1
			elif enemy.ai_target.is_in_group("enemies"):
				enemy_targeted_count += 1
				archetype_stats[archetype].targeting_enemies += 1
		else:
			no_target_count += 1

	var total_enemies = enemies.size()
	print("Total active enemies: " + str(total_enemies))
	print("Targeting players: " + str(player_targeted_count) + " (" + str(int(float(player_targeted_count) / total_enemies * 100)) + "%)")
	print("Targeting other enemies: " + str(enemy_targeted_count) + " (" + str(int(float(enemy_targeted_count) / total_enemies * 100)) + "%)")
	print("No target: " + str(no_target_count) + " (" + str(int(float(no_target_count) / total_enemies * 100)) + "%)")

	print("\nArchetype breakdown:")
	for archetype in archetype_stats.keys():
		var stats = archetype_stats[archetype]
		var player_pct = int(float(stats.targeting_players) / stats.total * 100) if stats.total > 0 else 0
		var enemy_pct = int(float(stats.targeting_enemies) / stats.total * 100) if stats.total > 0 else 0
		print("  " + archetype + " (" + str(stats.total) + "): " + str(player_pct) + "% players, " + str(enemy_pct) + "% enemies")

	# Battle royale health assessment
	var wounded_count = 0
	var healthy_count = 0
	for enemy in enemies:
		if enemy.has_method("get_current_hp") and enemy.has_method("get_max_hp"):
			var hp_ratio = enemy.get_current_hp() / enemy.get_max_hp() if enemy.get_max_hp() > 0 else 1.0
			if hp_ratio < 0.5:
				wounded_count += 1
			else:
				healthy_count += 1

	print("\nHealth status:")
	print("  Healthy (>50% HP): " + str(healthy_count))
	print("  Wounded (<50% HP): " + str(wounded_count))

	print("=== End Battle Royale Stats ===")