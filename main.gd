extends Control
## TEMPORARY Phase 0 bootstrap. Confirms the project boots and the autoload
## services are live at runtime. Replaced by the arena scene in Phase 1.

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var label := Label.new()
	label.text = "BENT CHROME\nrebuild skeleton — Phase 0"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(label)

	for autoload_name in ["GameState", "SceneFlow", "Spawner", "InputRouter", "AudioDirector"]:
		var present := get_node_or_null("/root/" + autoload_name) != null
		print("[boot] autoload ", autoload_name, ": ", "OK" if present else "MISSING")
	print("[boot] Bent Chrome rebuild skeleton — Phase 0 — booted clean")
