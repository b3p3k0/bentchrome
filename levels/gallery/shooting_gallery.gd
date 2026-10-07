extends "res://levels/combat_level.gd"
## Shooting Gallery: the weapon-testing range. combat_level's shell with ZERO
## baked enemies (the group win is latch-gated and never fires here, pinned off
## explicitly anyway — drivers_ed pattern), an invincible, never-depleting
## player (the DEVGOD precedent from vehicle.gd, applied unconditionally: the
## real 2s bay lock and MG overheat still bite, only the hull and the shelf are
## godded), and the north tunnel wired to the reusable exit prompt. Dummies,
## cover, and target cars come back on their own — see target_dummy /
## target_reset / target_lane. No lessons, no cards, no _process override.

const ConfirmScript := preload("res://levels/tutorial/exit_confirm.gd")

static var EXIT_PROMPT := "LEAVE THE GALLERY?"

var _confirm: CanvasLayer = null

func _ready() -> void:
	super()
	for child in get_children():
		if child is CanvasLayer and "suppress_group_win" in child:
			child.suppress_group_win = true
	if _player == null:
		return  # mp_managed shell (MP / the shot probe): the cars already left
	var health: Node = _player.get_node(^"Health")
	health.god = true
	var rack := _player.get_rack()
	rack.god = true
	rack.arm_all_once()
	var zone: Area2D = get_node_or_null(^"ExitZone")
	if zone:
		zone.body_entered.connect(_on_exit_zone_entered)

## The tunnel is always open here. Backing out and driving in again
## re-prompts — the zone refires on re-entry.
func _on_exit_zone_entered(body: Node) -> void:
	if _confirm != null or not body.is_in_group(&"player"):
		return
	_confirm = ConfirmScript.new()
	_confirm.name = "ExitConfirm"
	_confirm.prompt = EXIT_PROMPT
	_confirm.confirmed.connect(_leave_gallery)
	_confirm.cancelled.connect(_close_confirm)
	add_child(_confirm)  # its _ready freezes the tree

func _leave_gallery() -> void:
	# Pause survives scene swaps — every path OUT of the yard unpauses first.
	get_tree().paused = false
	var flow := get_node_or_null(^"/root/SceneFlow")
	if flow:
		flow.to_title()

func _close_confirm() -> void:
	get_tree().paused = false
	if _confirm:
		_confirm.queue_free()
		_confirm = null
