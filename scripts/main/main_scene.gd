extends Node2D

@onready var game_root := $GameViewport/SubViewport/GameRoot

func _ready():
	if game_root:
		GameManager.register_scene_root(game_root)
	else:
		push_error("Main: GameRoot not found at expected path")