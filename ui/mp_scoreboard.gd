extends Control
## The post-match tally: winner banner, kills/deaths rows sorted by wreckage,
## THE WASTELAND's cut at the bottom. Nothing pauses; the session stays warm.
## The host sends everyone back to the garage; ESC slips any peer back early
## (the lobby is live state, this screen is just a view of the verdict).
## Autoloads by path — smoke cold-boots this scene.

const IR := preload("res://game/input_router.gd")

const AMBER := Color(1.0, 0.85, 0.2)
const DIM_TEXT := Color(0.55, 0.58, 0.62)

@onready var _net: Node = get_node(^"/root/Net")
@onready var _flow: Node = get_node(^"/root/SceneFlow")

func _ready() -> void:
	print("[boot] mp scoreboard ready")
	_net.session_changed.connect(_on_session_changed)
	_build()

func _on_session_changed() -> void:
	if not _net.is_active():
		_flow.to_mp_menu()  # host gone — the front door holds the notice

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(IR.ACTION_PAUSE):
		return
	get_viewport().set_input_as_handled()
	_to_lobby()

func _to_lobby() -> void:
	if _net.is_active():
		_flow.to_mp_lobby()
	else:
		_flow.to_mp_menu()

func _build() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)

	var result: Dictionary = _net.last_result
	var scores: Dictionary = result.get("scores", {})

	var banner := Label.new()
	banner.add_theme_font_size_override("font_size", 30)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.modulate = AMBER
	var winners: Array = result.get("winners", [])
	if result.is_empty():
		banner.text = "NO VERDICT ON RECORD"
	elif winners.is_empty():
		banner.text = "THE WASTELAND WINS"
	else:
		var names: Array = []
		for peer in winners:
			names.append(String(scores.get(int(peer), {}).get("name", "?")))
		banner.text = "%s TAKES IT" % ", ".join(names).to_upper()
	vbox.add_child(banner)

	var reason := Label.new()
	reason.text = String(result.get("reason", "the dust settles"))
	reason.add_theme_font_size_override("font_size", 16)
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason.modulate = DIM_TEXT
	vbox.add_child(reason)

	# Rows: humans by kills (deaths break ties, fewer first), wasteland last.
	var rows: Array = []
	for peer in scores:
		if int(peer) > 0:
			rows.append({"peer": int(peer), "row": scores[peer]})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.row.kills) != int(b.row.kills):
			return int(a.row.kills) > int(b.row.kills)
		return int(a.row.deaths) < int(b.row.deaths))
	var header := Label.new()
	header.text = "%-24s %8s %8s" % ["DRIVER", "WRECKS", "DEATHS"]
	header.add_theme_font_size_override("font_size", 15)
	header.modulate = DIM_TEXT
	vbox.add_child(header)
	for entry in rows:
		var line := Label.new()
		line.text = "%-24s %8d %8d" % [String(entry.row.name),
			int(entry.row.kills), int(entry.row.deaths)]
		line.add_theme_font_size_override("font_size", 16)
		line.modulate = AMBER if winners.has(int(entry.peer)) else Color.WHITE
		vbox.add_child(line)
	var wasteland: Dictionary = scores.get(0, {})
	if not wasteland.is_empty() and int(wasteland.get("kills", 0)) > 0:
		var wl := Label.new()
		wl.text = "%-24s %8d %8s" % ["THE WASTELAND", int(wasteland.kills), "—"]
		wl.add_theme_font_size_override("font_size", 15)
		wl.modulate = DIM_TEXT
		vbox.add_child(wl)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 24)
	if _net.is_active() and _net.is_host():
		footer.add_child(_button("BACK TO THE GARAGE", func() -> void:
			_net.return_to_lobby()))
	footer.add_child(_button("LOBBY" if _net.is_active() else "FRONT DOOR", _to_lobby))
	vbox.add_child(footer)

	var hint := Label.new()
	hint.text = "the host rolls everyone back; ESC slips out early"
	hint.add_theme_font_size_override("font_size", 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = DIM_TEXT
	vbox.add_child(hint)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.09)
	style.border_color = AMBER
	for side in ["left", "right", "top", "bottom"]:
		style.set("border_width_" + side, 6)
	panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	panel.add_child(margin)
	margin.add_child(vbox)
	($Center as CenterContainer).add_child(panel)

func _button(caption: String, action: Callable) -> Button:
	var btn := Button.new()
	btn.text = caption
	btn.add_theme_font_size_override("font_size", 17)
	btn.pressed.connect(action)
	return btn
