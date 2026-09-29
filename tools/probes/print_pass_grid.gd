extends SceneTree
## Prints the signed-off Mountainside Mayhem pass grid and exits.
## Run: godot --headless --path . -s res://tools/probes/print_pass_grid.gd

const PassGrid := preload("res://levels/snowy/pass_grid.gd")

func _init() -> void:
	for line in PassGrid.render():
		print(line)
	quit(0)
