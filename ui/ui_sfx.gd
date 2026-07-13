class_name UiSfx
extends RefCounted
## Menu feedback cues — the one place UI screens fetch the AudioDirector.
## Three verbs: move (selection changed), select (confirmed), back (escaped).
## All three ride the pause-immune UI pool, so the pause menu clicks too.
## Static + null-guarded: safe from any screen, silent in bare fixtures.

static func move(from: Node) -> void:
	_play(from, &"ui_move")

static func select(from: Node) -> void:
	_play(from, &"ui_select")

static func back(from: Node) -> void:
	_play(from, &"ui_back")

## Button-focus screens (pause menu, end screen, MP screens): one call wires
## every BaseButton under root — pressed = select, focus arrival = move.
## Idempotent via meta, so rebuild-heavy screens can call it per refresh.
static func wire(root: Node) -> void:
	for node in root.find_children("*", "BaseButton", true, false):
		if node.has_meta(&"ui_sfx_wired"):
			continue
		node.set_meta(&"ui_sfx_wired", true)
		var btn := node as BaseButton
		btn.pressed.connect(func() -> void: _play(btn, &"ui_select"))
		btn.focus_entered.connect(func() -> void: _play(btn, &"ui_move"))

static func _play(from: Node, event: StringName) -> void:
	var audio := from.get_node_or_null(^"/root/AudioDirector")
	if audio:
		audio.play(event)
