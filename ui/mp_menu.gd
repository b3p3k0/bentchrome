extends Control
## Multiplayer front door: callsign, host setup, LAN browser + direct dial.
## A session opening (host or join) routes straight to the garage lobby
## (ui/mp_lobby.tscn); this screen also displays the one-shot notice a dying
## session leaves behind (kick reason, host quit).

const IR := preload("res://game/input_router.gd")  # consts, not the autoload
const Proto := preload("res://game/net/net_protocol.gd")
const Discovery := preload("res://game/net/net_discovery.gd")

const AMBER := Color(1.0, 0.85, 0.2)
const DIM_TEXT := Color(0.55, 0.58, 0.62)
const ALERT := Color(1.0, 0.42, 0.32)
const BROWSE_POLL := 0.5

var _panels := {}
var _active := &""

var _name_edit: LineEdit
var _home_status: Label

var _garage_edit: LineEdit
var _port_edit: LineEdit
var _host_pass_edit: LineEdit
var _strict_check: CheckButton
var _host_status: Label

var _server_list: ItemList
var _server_entries: Array = []
var _browse: RefCounted = null
var _browse_clock := 0.0
var _ip_edit: LineEdit
var _join_port_edit: LineEdit
var _join_pass_edit: LineEdit
var _join_status: Label

func _ready() -> void:
	print("[boot] mp menu ready")
	_build_panels()
	var gs := get_node_or_null(^"/root/GameState")
	if gs:
		_name_edit.text = String(gs.player_name)
	Net.session_changed.connect(_on_session_changed)
	Net.join_failed.connect(_on_join_failed)
	_show(&"home")
	var notice: String = Net.take_notice()
	if not notice.is_empty():
		_alert(_home_status, notice)
	if Net.is_active():
		SceneFlow.to_mp_lobby.call_deferred()

func _exit_tree() -> void:
	_stop_browse()

func _process(delta: float) -> void:
	if _active != &"join" or _browse == null or not _browse.is_browsing():
		return
	_browse_clock += delta
	if _browse_clock < BROWSE_POLL:
		return
	_browse_clock = 0.0
	_refresh_server_list()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(IR.ACTION_PAUSE):
		return
	get_viewport().set_input_as_handled()
	match _active:
		&"home":
			SceneFlow.to_title()
		&"host", &"join":
			_show(&"home")

# ------------------------------------------------------------------- panels

func _show(panel: StringName) -> void:
	_active = panel
	for key in _panels:
		_panels[key].visible = key == panel
	if panel == &"join":
		_start_browse()
	else:
		_stop_browse()

func _build_panels() -> void:
	var center := $Center as CenterContainer
	_panels[&"home"] = _build_home()
	_panels[&"host"] = _build_host()
	_panels[&"join"] = _build_join()
	for key in _panels:
		center.add_child(_panels[key])
		_panels[key].visible = false

func _build_home() -> Control:
	var vbox := _panel_vbox("MULTIPLAYER — LAN")
	var name_row := _row(vbox, "CALLSIGN")
	_name_edit = _line_edit(name_row, "Wastelander", 220)
	_name_edit.max_length = 24
	_name_edit.focus_exited.connect(_persist_name)
	_button(vbox, "HOST A GAME", func() -> void: _show(&"host"))
	_button(vbox, "JOIN A GAME", func() -> void: _show(&"join"))
	_button(vbox, "BACK TO TITLE", func() -> void: SceneFlow.to_title())
	_home_status = _status_label(vbox)
	return _wrap(vbox)

func _build_host() -> Control:
	var vbox := _panel_vbox("OPEN YOUR GARAGE")
	_garage_edit = _line_edit(_row(vbox, "GARAGE NAME"), "", 220)
	_garage_edit.max_length = 32
	_port_edit = _line_edit(_row(vbox, "PORT"), str(Proto.default_game_port), 100)
	_host_pass_edit = _line_edit(_row(vbox, "PASSWORD"), "", 220)
	_host_pass_edit.secret = true
	var strict_row := _row(vbox, "MOD POLICY")
	_strict_check = CheckButton.new()
	_strict_check.text = "reject modded builds"
	_strict_check.add_theme_font_size_override("font_size", 16)
	strict_row.add_child(_strict_check)
	_button(vbox, "OPEN THE DOORS", _do_host)
	_button(vbox, "BACK", func() -> void: _show(&"home"))
	_host_status = _status_label(vbox)
	return _wrap(vbox)

func _build_join() -> Control:
	var vbox := _panel_vbox("FIND A GARAGE")
	_server_list = ItemList.new()
	_server_list.custom_minimum_size = Vector2(560, 170)
	_server_list.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_server_list)
	_join_status = _status_label(vbox)
	_ip_edit = _line_edit(_row(vbox, "DIRECT IP"), "", 220)
	_join_port_edit = _line_edit(_row(vbox, "PORT"), str(Proto.default_game_port), 100)
	_join_pass_edit = _line_edit(_row(vbox, "PASSWORD"), "", 220)
	_join_pass_edit.secret = true
	_ip_edit.text_submitted.connect(func(_t: String) -> void: _do_join())
	_button(vbox, "CONNECT", _do_join)
	_button(vbox, "BACK", func() -> void: _show(&"home"))
	return _wrap(vbox)

# ------------------------------------------------------------------ actions

func _do_host() -> void:
	_persist_name()
	var port := _to_port(_port_edit.text)
	var err: String = Net.host(port, _host_pass_edit.text, _garage_edit.text,
		_strict_check.button_pressed)
	if not err.is_empty():
		_alert(_host_status, err)
		return
	# The host drives by default (SEAT 1 is already theirs) — pick the ride
	# first, then the car-select confirm routes into the lobby.
	SceneFlow.to_select()

func _do_join() -> void:
	_persist_name()
	var ip := _ip_edit.text.strip_edges()
	var port := _to_port(_join_port_edit.text)
	var picked := _server_list.get_selected_items()
	if not picked.is_empty() and picked[0] < _server_entries.size():
		var entry: Dictionary = _server_entries[picked[0]]
		ip = String(entry.ip)
		port = int(entry.info.get("game_port", port))
	if ip.is_empty():
		_alert(_join_status, "pick a garage or type an address")
		return
	var err: String = Net.join(ip, port, _join_pass_edit.text)
	if err.is_empty():
		_join_status.modulate = DIM_TEXT
		_join_status.text = "dialing %s:%d ..." % [ip, port]
	else:
		_alert(_join_status, err)

func _persist_name() -> void:
	var gs := get_node_or_null(^"/root/GameState")
	if gs and String(gs.player_name) != _name_edit.text:
		gs.player_name = _name_edit.text
		gs.save_settings()

# ------------------------------------------------------------------ net cbs

func _on_session_changed() -> void:
	if not is_inside_tree():
		return
	# Clients route straight to the lobby; a fresh HOST detours through the
	# ride picker first (_do_host owns that hop).
	if Net.mode == Net.Mode.JOINED:
		SceneFlow.to_mp_lobby()

func _on_join_failed(reason: String) -> void:
	if _active == &"join":
		_alert(_join_status, "no dice: " + reason)

# ---------------------------------------------------------------- discovery

func _start_browse() -> void:
	if _browse == null:
		_browse = Discovery.new()
	if _browse.is_browsing():
		return
	if _browse.start_browse():
		_join_status.modulate = DIM_TEXT
		_join_status.text = "scanning the wasteland ..."
	else:
		_alert(_join_status, "discovery port busy (another instance listening) — direct IP still works")

func _stop_browse() -> void:
	if _browse:
		_browse.stop()

func _refresh_server_list() -> void:
	var picked_ip := ""
	var picked := _server_list.get_selected_items()
	if not picked.is_empty() and picked[0] < _server_entries.size():
		picked_ip = String(_server_entries[picked[0]].ip)
	_server_entries = _browse.browse_poll()
	_server_list.clear()
	for entry in _server_entries:
		var info: Dictionary = entry.info
		var lock := "  [locked]" if bool(info.get("has_password", false)) else ""
		var line := "%s  —  %s:%d  (%d/%d)%s" % [String(info.get("name", "?")),
			String(entry.ip), int(info.get("game_port", 0)),
			int(info.get("players", 0)), int(info.get("max", 0)), lock]
		var idx := _server_list.add_item(line)
		if int(info.get("proto", -1)) != Proto.PROTOCOL_VERSION:
			_server_list.set_item_custom_fg_color(idx, ALERT)
			_server_list.set_item_text(idx, line + "  [other version]")
		if String(entry.ip) == picked_ip:
			_server_list.select(idx)
	if _server_entries.is_empty():
		_join_status.modulate = DIM_TEXT
		_join_status.text = "scanning the wasteland ..."
	elif _join_status.text.begins_with("scanning"):
		_join_status.text = ""

# ----------------------------------------------------------------- widgets

func _wrap(vbox: VBoxContainer) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.09)
	style.border_color = AMBER
	for side in ["left", "right", "top", "bottom"]:
		style.set("border_width_" + side, 6)
	panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	margin.add_child(vbox)
	return panel

func _panel_vbox(title: String) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	var head := Label.new()
	head.text = title
	head.add_theme_font_size_override("font_size", 26)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.modulate = AMBER
	vbox.add_child(head)
	return vbox

func _row(vbox: VBoxContainer, caption: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 16)
	label.modulate = DIM_TEXT
	label.custom_minimum_size = Vector2(150, 0)
	row.add_child(label)
	vbox.add_child(row)
	return row

func _line_edit(row: HBoxContainer, placeholder: String, width: int) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.custom_minimum_size = Vector2(width, 0)
	edit.add_theme_font_size_override("font_size", 16)
	row.add_child(edit)
	return edit

func _button(vbox: VBoxContainer, caption: String, action: Callable) -> Button:
	var btn := Button.new()
	btn.text = caption
	btn.add_theme_font_size_override("font_size", 18)
	btn.pressed.connect(action)
	vbox.add_child(btn)
	return btn

func _status_label(vbox: VBoxContainer) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = DIM_TEXT
	vbox.add_child(label)
	return label

func _alert(label: Label, text: String) -> void:
	label.modulate = ALERT
	label.text = text

func _to_port(text: String) -> int:
	var port := text.strip_edges().to_int()
	return port if port > 1023 and port < 65536 else Proto.default_game_port
