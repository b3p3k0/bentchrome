extends Node2D

@onready var game_root := $GameViewport/SubViewport/GameRoot

func _ready():
	if game_root:
		GameManager.register_scene_root(game_root)
	else:
		push_error("Main: GameRoot not found at expected path")

	# Validate AI system on startup (can be disabled for production)
	call_deferred("_validate_ai_system")

func _validate_ai_system():
	print("\n=== AI System Startup Validation ===")

	# Wait a frame for all autoloads to initialize
	await get_tree().process_frame

	if AIDebug:
		AIDebug.debug_system_status()
		AIDebug.debug_validate_profiles()
		AIDebug.debug_archetypes()
	else:
		print("AIDebug not available for validation")

	print("=== AI Validation Complete ===\n")