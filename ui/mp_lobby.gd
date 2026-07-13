extends Control
## The garage lobby: four seats, the observer bench with the "I got Next!"
## queue, and the host's rule board (map/mode/format/caps/difficulty). Hosts
## step rules and kick/ban; everyone claims seats, picks rigs, and queues.
## Queue integrity is enforced by NetRoster — this screen just makes the cost
## honest: changing wheels while queued warns, then sends you to the back.
## START stays dark until the match shell lands (Batch 2).

const IR := preload("res://game/input_router.gd")  # consts, not the autoload
const Proto := preload("res://game/net/net_protocol.gd")
const Config := preload("res://game/net/match_config.gd")
const Difficulty := preload("res://game/difficulty.gd")

const AMBER := Color(1.0, 0.85, 0.2)
const DIM_TEXT := Color(0.55, 0.58, 0.62)
const ALERT := Color(1.0, 0.42, 0.32)

const FRAG_STEP := 5
const TIME_STEP := 60
const BRAWL_FRAG_CAPS := [0, 10, 15, 20, 25]
const BRAWL_TIME_CAPS := [0, 300, 600, 900]

## Headroom baked into the locked panel height: a few observer rows can join
## before the border has any reason to move.
const OBSERVER_RESERVE := 96.0

var _panel: PanelContainer
var _head: Label
var _deal: Label  # THE DEAL — the ruleset in plain language
var _seat_rows: VBoxContainer
var _rig_row: HBoxContainer
var _rig_value: Label
var _obs_rows: VBoxContainer
var _rule_rows := {}  # key -> {row, value}
var _start_btn: Button
var _status: Label
var _confirm: Control = null
var _my_car := ""  # my cycler position (pick when seated, queue car otherwise)
var _last_peer_count := -1  # join/leave cue diff; -1 = first refresh stays silent
	# (peers_changed also fires on name/mod syncs — the size diff dedupes)

func _ready() -> void:
	print("[boot] mp lobby ready")
	_build()
	Net.session_changed.connect(_on_session_changed)
	Net.peers_changed.connect(_refresh)
	Net.lobby_changed.connect(_refresh)
	var ids: Array = Config.car_ids()
	var gs := get_node_or_null(^"/root/GameState")
	_my_car = String(gs.selected_vehicle_id) if gs else ""
	if _my_car.is_empty() or not ids.has(_my_car):
		_my_car = String(ids[0]) if not ids.is_empty() else ""
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(IR.ACTION_PAUSE):
		return
	get_viewport().set_input_as_handled()
	UiSfx.back(self)
	if _confirm:
		_close_confirm()
		return
	# ESC backs out cleanly — but a live session deserves one honest question.
	if not Net.is_active():
		SceneFlow.to_mp_menu()
		return
	var prompt := "Close the garage and boot everyone?" if Net.is_host() \
		else "Leave the garage?"
	_open_confirm(prompt, "LEAVE", "STAY", _do_leave)

func _on_session_changed() -> void:
	if Net.mode == Net.Mode.OFF:
		SceneFlow.to_mp_menu()

# ------------------------------------------------------------------ build

func _build() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	_head = Label.new()
	_head.add_theme_font_size_override("font_size", 22)
	_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_head.modulate = AMBER
	vbox.add_child(_head)

	# Two columns: the floor (seats + bench) left, the rule board right — the
	# whole worst case fits the 720 viewport with room to breathe.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 36)
	vbox.add_child(columns)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.custom_minimum_size = Vector2(470, 0)
	columns.add_child(left)

	left.add_child(_section("SEATS"))
	_seat_rows = VBoxContainer.new()
	_seat_rows.add_theme_constant_override("separation", 4)
	left.add_child(_seat_rows)

	_rig_row = HBoxContainer.new()
	_rig_row.add_theme_constant_override("separation", 10)
	var rig_label := Label.new()
	rig_label.text = "MY RIG"
	rig_label.add_theme_font_size_override("font_size", 15)
	rig_label.modulate = DIM_TEXT
	rig_label.custom_minimum_size = Vector2(110, 0)
	_rig_row.add_child(rig_label)
	_rig_value = Label.new()
	_rig_value.add_theme_font_size_override("font_size", 16)
	_rig_value.modulate = AMBER
	_rig_value.custom_minimum_size = Vector2(180, 0)
	_rig_row.add_child(_rig_value)
	_rig_row.add_child(_small_button("CHANGE RIDE", _change_ride))
	left.add_child(_rig_row)

	left.add_child(_section("OBSERVERS + QUEUE"))
	_obs_rows = VBoxContainer.new()
	_obs_rows.add_theme_constant_override("separation", 4)
	left.add_child(_obs_rows)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	columns.add_child(right)

	right.add_child(_section("RULES"))
	_add_rule(right, "map", "MAP")
	_add_rule(right, "mode", "MODE")
	_add_rule(right, "format", "FORMAT")
	_add_rule(right, "observers", "OBSERVERS")
	_add_rule(right, "gotnext", "I GOT NEXT")
	_add_rule(right, "frag_target", "FRAG TARGET")
	_add_rule(right, "time_limit", "TIME LIMIT")
	_add_rule(right, "lives", "LIVES")
	_add_rule(right, "brawl_frag_cap", "BRAWL FRAG CAP")
	_add_rule(right, "brawl_time_cap", "BRAWL TIME CAP")
	_add_rule(right, "difficulty", "AI DIFFICULTY")

	# THE DEAL: the ruleset in plain language, live for every peer. Height is
	# RESERVED (worst-case lines) so the locked border never moves.
	right.add_child(_section("THE DEAL"))
	_deal = Label.new()
	_deal.add_theme_font_size_override("font_size", 14)
	_deal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_deal.custom_minimum_size = Vector2(470, 108)
	_deal.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_deal.modulate = Color(0.8, 0.82, 0.86)
	right.add_child(_deal)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 24)
	_start_btn = Button.new()
	_start_btn.text = "START MATCH"
	_start_btn.add_theme_font_size_override("font_size", 18)
	_start_btn.pressed.connect(_do_start)
	footer.add_child(_start_btn)
	var leave_btn := Button.new()
	leave_btn.text = "LEAVE GARAGE"
	leave_btn.add_theme_font_size_override("font_size", 18)
	leave_btn.pressed.connect(_do_leave)
	footer.add_child(leave_btn)
	vbox.add_child(footer)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 13)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.modulate = DIM_TEXT
	vbox.add_child(_status)

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.09)
	style.border_color = AMBER
	for side in ["left", "right", "top", "bottom"]:
		style.set("border_width_" + side, 6)
	_panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	_panel.add_child(margin)
	margin.add_child(vbox)
	($Center as CenterContainer).add_child(_panel)
	# Lock the amber border to the worst case: every rule row is still visible
	# right now, so this measurement IS the maximum the rules board ever needs.
	# Row visibility changes then shrink the content from the top, never the
	# frame — no jump when the host steps mode or format. Clamped to the
	# viewport so the frame can never outgrow the screen again.
	var worst := _panel.get_combined_minimum_size()
	var view := get_viewport_rect().size
	_panel.custom_minimum_size = Vector2(
		minf(worst.x, view.x - 40.0),
		minf(worst.y + OBSERVER_RESERVE, view.y - 40.0))

# ---------------------------------------------------------------- refresh

func _refresh() -> void:
	if not Net.is_active() or Net.roster == null:
		_head.text = "NO SESSION"
		_status.text = "the garage is dark — head back"
		return
	var peer_count: int = Net.peers.size()
	if _last_peer_count >= 0 and peer_count != _last_peer_count:
		var audio := get_node_or_null(^"/root/AudioDirector")
		if audio:
			audio.play(&"mp_join" if peer_count > _last_peer_count else &"mp_leave")
	_last_peer_count = peer_count
	var cfg: Dictionary = Net.match_config
	_head.text = ("HOSTING on port %d" % Net.game_port) if Net.is_host() \
		else "GARAGE FLOOR — peer %d" % Net.my_id()

	var me := Net.my_id()
	var seated: bool = Net.roster.seated(me)
	if seated:
		var pick: String = Net.roster.pick_of(me)
		if not pick.is_empty():
			_my_car = pick
	elif Net.roster.queue_position(me) >= 0:
		_my_car = Net.roster.queue_car(me)
	elif Net.taken_cars(me).has(_my_car):
		_my_car = _shift_car(_my_car, 1)  # browsing a claimed ride — slide off it

	_refresh_seats()
	_rig_row.visible = seated
	_rig_value.text = Config.car_name(_my_car)
	_refresh_observers()
	_refresh_rules(cfg)
	var maps: Array = SceneFlow.MP_MAPS
	var map_idx := clampi(int(cfg.get("map", 0)), 0, maps.size() - 1)
	_deal.text = " ".join(Config.describe(cfg, String(maps[map_idx].name),
		String(Difficulty.NAMES.get(int(cfg.get("difficulty", 2)), "?"))))

	var seats_filled: int = Net.roster.seated_ids().size()
	var mode := StringName(String(cfg.get("mode", &"melee")))
	var need := 2 if mode == &"grudge" else 1
	_start_btn.visible = Net.is_host()
	_start_btn.disabled = seats_filled < need
	var tail := "" if Net.is_host() else "  (the host calls the start)"
	var result_line := ""
	var last: Dictionary = Net.last_result
	if not last.is_empty():
		var names: Array = []
		for peer in last.get("winners", []):
			names.append(String(last.scores.get(int(peer), {}).get("name", "?")))
		var who := ", ".join(names) if not names.is_empty() else "THE WASTELAND"
		result_line = "last match: %s — %s\n" % [who, String(last.get("reason", ""))]
	_status.text = result_line + "%d/%d seated — %s rolls with %d+ driver%s%s" % [
		seats_filled, Proto.MAX_PLAYERS,
		String(Config.MODE_NAMES.get(mode, "?")), need, "s" if need > 1 else "", tail]
	UiSfx.wire(self)  # rows rebuild each refresh; wire() is idempotent per button

func _refresh_seats() -> void:
	for child in _seat_rows.get_children():
		child.queue_free()
	var me := Net.my_id()
	for idx in Net.roster.seats.size():
		var id: int = int(Net.roster.seats[idx])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var tag := Label.new()
		tag.text = "SEAT %d" % (idx + 1)
		tag.add_theme_font_size_override("font_size", 15)
		tag.modulate = DIM_TEXT
		tag.custom_minimum_size = Vector2(140, 0)
		row.add_child(tag)
		if id == 0:
			row.add_child(_small_button("TAKE SEAT", func() -> void:
				Net.request_claim_seat(idx)))
		else:
			var who := Label.new()
			who.add_theme_font_size_override("font_size", 16)
			who.text = "%s  —  %s" % [_peer_name(id), Config.car_name(Net.roster.pick_of(id))]
			who.modulate = AMBER if id == me else Color.WHITE
			who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(who)
			if _peer_modded(id):
				row.add_child(_badge("MODDED"))
			if id == me:
				row.add_child(_small_button("LEAVE SEAT", func() -> void:
					Net.request_leave_seat()))
			elif Net.is_host():
				row.add_child(_small_button("KICK", func() -> void: Net.kick(id)))
				row.add_child(_small_button("BAN", func() -> void: Net.ban(id)))
		_seat_rows.add_child(row)

func _refresh_observers() -> void:
	for child in _obs_rows.get_children():
		child.queue_free()
	var me := Net.my_id()
	var ids: Array = Net.peers.keys()
	ids.sort()
	var any := false
	for pid_v in ids:
		var pid := int(pid_v)
		if Net.roster.seated(pid):
			continue
		any = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var who := Label.new()
		who.add_theme_font_size_override("font_size", 15)
		who.text = _peer_name(pid)
		who.modulate = AMBER if pid == me else Color.WHITE
		who.custom_minimum_size = Vector2(200, 0)
		row.add_child(who)
		if _peer_modded(pid):
			row.add_child(_badge("MODDED"))
		var pos: int = Net.roster.queue_position(pid)
		if pid == me:
			_build_my_queue_controls(row, pos)
		elif pos >= 0:
			var mark := Label.new()
			mark.add_theme_font_size_override("font_size", 14)
			mark.text = "#%d in line — %s" % [pos + 1, Config.car_name(Net.roster.queue_car(pid))]
			mark.modulate = DIM_TEXT
			row.add_child(mark)
		if Net.is_host() and pid != 1:
			var spacer := Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(spacer)
			row.add_child(_small_button("KICK", func() -> void: Net.kick(pid)))
			row.add_child(_small_button("BAN", func() -> void: Net.ban(pid)))
		_obs_rows.add_child(row)
	if not any:
		var none := Label.new()
		none.text = "(everyone's got a seat)"
		none.add_theme_font_size_override("font_size", 14)
		none.modulate = DIM_TEXT
		_obs_rows.add_child(none)

## My observer row: queue toggle + car cycler. Queued + cycling = the warned
## re-queue; unqueued cycling is free browsing until you opt in.
func _build_my_queue_controls(row: HBoxContainer, pos: int) -> void:
	row.add_child(_arrow("<", _cycle_queue_car.bind(-1, pos >= 0)))
	var car := Label.new()
	car.add_theme_font_size_override("font_size", 15)
	car.text = Config.car_name(_my_car)
	car.modulate = AMBER
	car.custom_minimum_size = Vector2(170, 0)
	car.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(car)
	row.add_child(_arrow(">", _cycle_queue_car.bind(1, pos >= 0)))
	if pos >= 0:
		var mark := Label.new()
		mark.text = "#%d in line" % (pos + 1)
		mark.add_theme_font_size_override("font_size", 14)
		mark.modulate = DIM_TEXT
		row.add_child(mark)
		row.add_child(_small_button("BAIL OUT", func() -> void:
			Net.request_opt_next(false, "")))
	else:
		row.add_child(_small_button("I GOT NEXT", func() -> void:
			Net.request_opt_next(true, _my_car)))

# ------------------------------------------------------------------ rules

func _add_rule(vbox: VBoxContainer, key: String, caption: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 15)
	label.modulate = DIM_TEXT
	label.custom_minimum_size = Vector2(180, 0)
	row.add_child(label)
	var prev := _arrow("<", _step_rule.bind(key, -1))
	var value := Label.new()
	value.add_theme_font_size_override("font_size", 16)
	value.modulate = AMBER
	value.custom_minimum_size = Vector2(260, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var next := _arrow(">", _step_rule.bind(key, 1))
	row.add_child(prev)
	row.add_child(value)
	row.add_child(next)
	vbox.add_child(row)
	_rule_rows[key] = {"row": row, "value": value, "prev": prev, "next": next}

func _refresh_rules(cfg: Dictionary) -> void:
	var format := StringName(String(cfg.get("format", &"brawl")))
	var mode := StringName(String(cfg.get("mode", &"melee")))
	var visible_keys := {
		"map": true, "mode": true, "format": true,
		"observers": true,
		"gotnext": bool(cfg.get("observers", true)),  # no bench, no queue
		"frag_target": format == &"frag",
		"time_limit": format == &"timed",
		"lives": format == &"lives",
		"brawl_frag_cap": format == &"brawl",
		"brawl_time_cap": format == &"brawl",
		"difficulty": mode == &"melee",
	}
	for key in _rule_rows:
		var parts: Dictionary = _rule_rows[key]
		(parts.row as HBoxContainer).visible = bool(visible_keys.get(key, true))
		(parts.prev as Button).visible = Net.is_host()
		(parts.next as Button).visible = Net.is_host()
		(parts.value as Label).text = _rule_text(String(key), cfg)

func _rule_text(key: String, cfg: Dictionary) -> String:
	match key:
		"map":
			var idx := int(cfg.get("map", 0))
			return String(SceneFlow.MP_MAPS[idx].name) if idx < SceneFlow.MP_MAPS.size() else "?"
		"mode":
			return String(Config.MODE_NAMES.get(StringName(String(cfg.get("mode", &"melee"))), "?"))
		"format":
			return String(Config.FORMAT_NAMES.get(StringName(String(cfg.get("format", &"brawl"))), "?"))
		"frag_target":
			return "first to %d" % int(cfg.get("frag_target", 10))
		"time_limit":
			return "%d min" % (int(cfg.get("time_limit", 300)) / 60)
		"lives":
			return "%d lives" % int(cfg.get("lives", 3))
		"brawl_frag_cap":
			var cap := int(cfg.get("brawl_frag_cap", 0))
			return "off" if cap == 0 else "first to %d" % cap
		"brawl_time_cap":
			var tcap := int(cfg.get("brawl_time_cap", 0))
			return "off" if tcap == 0 else "%d min" % (tcap / 60)
		"observers":
			return "WELCOME" if bool(cfg.get("observers", true)) else "SEATS ONLY"
		"gotnext":
			return "ON" if bool(cfg.get("gotnext", true)) else "OFF"
		"difficulty":
			return String(Difficulty.NAMES.get(int(cfg.get("difficulty", 2)), "?"))
	return "?"

func _step_rule(key: String, dir: int) -> void:
	if not Net.is_host():
		return
	var cfg: Dictionary = Net.match_config
	var patch := {}
	match key:
		"map":
			patch.map = wrapi(int(cfg.map) + dir, 0, SceneFlow.MP_MAPS.size())
		"mode":
			var mi := Config.MODES.find(StringName(String(cfg.mode)))
			patch.mode = Config.MODES[wrapi(mi + dir, 0, Config.MODES.size())]
		"format":
			var fi := Config.FORMATS.find(StringName(String(cfg.format)))
			patch.format = Config.FORMATS[wrapi(fi + dir, 0, Config.FORMATS.size())]
		"frag_target":
			patch.frag_target = clampi(int(cfg.frag_target) + dir * FRAG_STEP, 5, 30)
		"time_limit":
			patch.time_limit = clampi(int(cfg.time_limit) + dir * TIME_STEP, 180, 600)
		"lives":
			patch.lives = clampi(int(cfg.lives) + dir, 1, 9)
		"brawl_frag_cap":
			patch.brawl_frag_cap = _cycle_list(BRAWL_FRAG_CAPS, int(cfg.brawl_frag_cap), dir)
		"brawl_time_cap":
			patch.brawl_time_cap = _cycle_list(BRAWL_TIME_CAPS, int(cfg.brawl_time_cap), dir)
		"observers":
			patch.observers = not bool(cfg.observers)
		"gotnext":
			patch.gotnext = not bool(cfg.gotnext)
		"difficulty":
			patch.difficulty = wrapi(int(cfg.difficulty) + dir, 0, 3)
	Net.set_match_config(patch)

func _cycle_list(values: Array, current: int, dir: int) -> int:
	var idx := values.find(current)
	if idx < 0:
		idx = 0
	return int(values[wrapi(idx + dir, 0, values.size())])

# ----------------------------------------------------------------- actions

## Seated players change rides through the real carousel — it confirms with
## request_set_pick and routes back here (session state lives on Net).
func _change_ride() -> void:
	SceneFlow.to_select()

func _cycle_queue_car(dir: int, queued: bool) -> void:
	var next_car := _shift_car(_my_car, dir)
	if not queued:
		_my_car = next_car
		_refresh()
		return
	# Changing wheels while queued: the warned trip to the back of the line.
	_open_confirm(
		"Hey %s — changing wheels mid-queue\nsends you to the back. You sure?" % Net.display_name(),
		"SEND ME BACK", "KEEP MY SPOT",
		func() -> void:
			_my_car = next_car
			Net.request_opt_next(true, _my_car))

## Next ride in dir, skipping every claimed one — one of each on the floor.
func _shift_car(car: String, dir: int) -> String:
	var ids: Array = Config.car_ids()
	if ids.is_empty():
		return car
	var taken: Array = Net.taken_cars(Net.my_id())
	var idx := ids.find(car)
	if idx < 0:
		idx = 0
	for step in range(1, ids.size() + 1):
		var cand := String(ids[wrapi(idx + dir * step, 0, ids.size())])
		if not taken.has(cand):
			return cand
	return car  # everything's claimed — more chassis are on the way

## Host's finger is the clock: broadcast the locked table, everyone rolls.
func _do_start() -> void:
	if not Net.is_host() or Net.roster == null:
		return
	var mode := StringName(String(Net.match_config.get("mode", &"melee")))
	var need := 2 if mode == &"grudge" else 1
	if Net.roster.seated_ids().size() < need:
		return
	Net.start_match()

func _do_leave() -> void:
	Net.leave()  # session_changed(OFF) routes everyone home

# ----------------------------------------------------------------- widgets

func _section(caption: String) -> Label:
	var label := Label.new()
	label.text = "— %s —" % caption
	label.add_theme_font_size_override("font_size", 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = DIM_TEXT
	return label

func _arrow(caption: String, action: Callable) -> Button:
	var btn := Button.new()
	btn.text = caption
	btn.add_theme_font_size_override("font_size", 15)
	btn.custom_minimum_size = Vector2(34, 0)
	btn.pressed.connect(action)
	return btn

func _small_button(caption: String, action: Callable) -> Button:
	var btn := Button.new()
	btn.text = caption
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(action)
	return btn

func _badge(caption: String) -> Label:
	var badge := Label.new()
	badge.text = caption
	badge.add_theme_font_size_override("font_size", 13)
	badge.modulate = ALERT
	return badge

func _peer_name(id: int) -> String:
	return String(Net.peers[id].name) if Net.peers.has(id) else "peer %d" % id

func _peer_modded(id: int) -> bool:
	return bool(Net.peers[id].modded) if Net.peers.has(id) else false

# The house confirm overlay (title.gd's quit-confirm pattern, mouse-driven).
func _open_confirm(text: String, yes_label: String, no_label: String, on_yes: Callable) -> void:
	_close_confirm()
	_confirm = Control.new()
	_confirm.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_confirm)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.09)
	style.border_color = AMBER
	for side in ["left", "right", "top", "bottom"]:
		style.set("border_width_" + side, 6)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)
	var caption := Label.new()
	caption.text = text
	caption.add_theme_font_size_override("font_size", 20)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.modulate = AMBER
	vbox.add_child(caption)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	vbox.add_child(row)
	var yes := Button.new()
	yes.text = yes_label
	yes.add_theme_font_size_override("font_size", 16)
	yes.pressed.connect(func() -> void:
		_close_confirm()
		on_yes.call())
	row.add_child(yes)
	var no := Button.new()
	no.text = no_label
	no.add_theme_font_size_override("font_size", 16)
	no.pressed.connect(_close_confirm)
	row.add_child(no)

func _close_confirm() -> void:
	if _confirm:
		_confirm.queue_free()
		_confirm = null
