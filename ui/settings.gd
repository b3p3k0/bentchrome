extends Control
## Settings screen (title menu -> SETTINGS). Arrow-only rows: up/down selects,
## left/right adjusts, right enters submenu/action rows, ESC backs out.
## Developer-only settings live behind an in-screen master-breaker dialog.
## Every actual setting change persists immediately via GameState.save_settings().

const AMBER := Color(1.0, 0.85, 0.2)
const PANEL_BG := Color(0.07, 0.07, 0.09)
const DIM_TEXT := Color(0.55, 0.58, 0.62)
const ALIVE_TEXT := Color(0.8, 0.82, 0.86)
const WARN := Color(1.0, 0.35, 0.3)
const LOCKED_TEXT := Color(0.32, 0.34, 0.37)

const UpdaterScript := preload("res://game/updater.gd")

const ZOOM_MIN := 0.45
const ZOOM_MAX := 0.72
const ZOOM_STEP := 0.01
const VOL_STEP := 0.05

enum MenuKey { NONE, UP, DOWN, LEFT, RIGHT, BACK }

var _index := 0
var _rows: Array = []  # {name, adjust, value, kind: value|submenu|action, persist}
var _name_labels: Array = []
var _value_labels: Array = []
var _dev_dialog: Control
var _dev_index := 0
var _dev_rows: Array = []
var _dev_name_labels: Array = []
var _dev_value_labels: Array = []
var _sb_dialog: Control  # soundboard: third-level modal over the dev dialog
var _ct_dialog: Control  # car tuner: third-level modal, MOUSE-driven grid (the
	# one documented dev-tool exception to this screen's keyboard contract);
	# the funnel below still owns ESC-to-close
var _sb_index := 0
var _sb_events: Array = []
var _sb_name_labels: Array = []
var _sb_value_labels: Array = []
var _sb_scroll: ScrollContainer  # rows live in a capped-height scroll — the
	# catalog outgrew the viewport and will keep growing (car specials queued)
var _up_dialog: Control  # check-for-updates: second-level modal, state-driven
var _up_version_lbl: Label
var _up_status_lbl: Label
var _up_changelog_lbl: Label
var _up_action_lbl: Label
var _settings_path := "user://settings.json"  # overridden only by hermetic tests

@onready var _gs: Node = get_node(^"/root/GameState")
@onready var _flow: Node = get_node(^"/root/SceneFlow")
# Path-based per repo convention (bare autoload identifiers die on the test
# runner's -s chain); the SCRIPT is preloaded for compile-safe enum/const access.
@onready var _updater: Node = get_node_or_null(^"/root/Updater")

func _ready() -> void:
	_rows = [
		{"name": "ZOOM DEPTH", "adjust": _adj_zoom, "value": _val_zoom},
		{"name": "SCREEN SHAKE", "adjust": _adj_shake, "value": _val_shake},
		{"name": "MASTER VOLUME", "adjust": _adj_vol_master, "value": _val_vol_master},
		{"name": "MUSIC VOLUME", "adjust": _adj_vol_music, "value": _val_vol_music},
		{"name": "SFX VOLUME", "adjust": _adj_vol_sfx, "value": _val_vol_sfx},
		{"name": "CHECK FOR UPDATES", "adjust": _adj_check_updates, "value": _val_updates,
			"locked": _locked_updates, "kind": &"submenu", "persist": false},
		{"name": "DEVELOPER OPTIONS", "adjust": _adj_dev_options, "value": _val_open,
			"kind": &"submenu", "persist": false},
		{"name": "RESET TO DEFAULTS", "adjust": _adj_reset, "value": _val_blank,
			"kind": &"action", "persist": false},
	]
	_dev_rows = [
		{"name": "DEVELOPER MODE", "adjust": _adj_dev, "value": _val_dev},
		{"name": "DEVGOD", "adjust": _adj_devgod, "value": _val_devgod},
		{"name": "START LEVEL", "adjust": _adj_level, "value": _val_level},
		{"name": "SOUNDBOARD", "adjust": _adj_soundboard, "value": _val_open,
			"kind": &"submenu", "persist": false},
		{"name": "CAR TUNER", "adjust": _adj_car_tuner, "value": _val_open,
			"kind": &"submenu", "persist": false},
		{"name": "BACK", "adjust": _adj_close_dev, "value": _val_blank,
			"kind": &"action", "persist": false},
	]
	_build_ui()
	_refresh()

# --- row behaviors -----------------------------------------------------------

func _adj_devgod(_d: int) -> void:
	if not _gs.dev_mode:
		return
	_gs.devgod = not _gs.devgod

func _val_devgod() -> Array:
	return ["ON — INVINCIBLE" if _gs.devgod else "OFF", WARN if _gs.devgod else DIM_TEXT]

func _adj_zoom(d: int) -> void:
	_gs.zoom_combat = clampf(_gs.zoom_combat + d * ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)

func _val_zoom() -> Array:
	return ["%.2f  %s" % [_gs.zoom_combat, _bar(_gs.zoom_combat, ZOOM_MIN, ZOOM_MAX)], DIM_TEXT]

func _adj_level(d: int) -> void:
	if not _gs.dev_mode:
		return
	_gs.start_level_index = wrapi(_gs.start_level_index + (d if d != 0 else 1), 0, _flow.CAMPAIGN.size())

func _val_level() -> Array:
	return [String(_flow.CAMPAIGN[_gs.start_level_index].name).to_upper(), DIM_TEXT]

func _adj_vol(field: String, d: int) -> void:
	_gs.set(field, clampf(_gs.get(field) + d * VOL_STEP, 0.0, 1.0))
	_gs.apply_audio_settings()  # sliders move live audio; _adjust persists

func _val_vol(field: String) -> Array:
	var v: float = _gs.get(field)
	return ["%3d%%  %s" % [roundi(v * 100.0), _bar(v, 0.0, 1.0)], DIM_TEXT]

func _adj_vol_master(d: int) -> void: _adj_vol("volume_master", d)
func _adj_vol_music(d: int) -> void: _adj_vol("volume_music", d)
func _adj_vol_sfx(d: int) -> void: _adj_vol("volume_sfx", d)
func _val_vol_master() -> Array: return _val_vol("volume_master")
func _val_vol_music() -> Array: return _val_vol("volume_music")
func _val_vol_sfx() -> Array: return _val_vol("volume_sfx")

func _adj_shake(_d: int) -> void:
	_gs.screen_shake = not _gs.screen_shake

func _val_shake() -> Array:
	return ["ON" if _gs.screen_shake else "OFF", DIM_TEXT]

func _adj_dev_options(_d: int) -> void:
	_open_dev_dialog()

func _val_open() -> Array:
	return ["-->", DIM_TEXT]

func _adj_dev(_d: int) -> void:
	_gs.dev_mode = not _gs.dev_mode
	_sync_dev()

func _val_dev() -> Array:
	return ["ON" if _gs.dev_mode else "OFF", AMBER if _gs.dev_mode else DIM_TEXT]

func _adj_reset(_d: int) -> void:
	_gs.reset_settings()
	_sync_dev()

func _adj_close_dev(_d: int) -> void:
	_close_dev_dialog()

func _adj_soundboard(_d: int) -> void:
	_open_soundboard()

func _adj_car_tuner(_d: int) -> void:
	_open_car_tuner()

func _open_car_tuner() -> void:
	if _ct_dialog:
		return
	_ct_dialog = load("res://ui/car_tuner.tscn").instantiate()
	_ct_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_ct_dialog)

func _close_car_tuner() -> void:
	if not _ct_dialog:
		return
	_ct_dialog.queue_free()
	_ct_dialog = null
	_refresh_dev()

func _val_blank() -> Array:
	return ["", DIM_TEXT]

func _sync_dev() -> void:
	var dev := get_node_or_null(^"/root/Dev")
	if dev:
		dev.enabled = _gs.dev_mode
		if _gs.dev_mode and dev.has_method("_ensure_tuning"):
			dev._ensure_tuning()  # tuning deck boots the moment dev mode does

func _bar(v: float, lo: float, hi: float) -> String:
	var filled := int(round((v - lo) / (hi - lo) * 10.0))
	return "[" + "#".repeat(filled) + "-".repeat(10 - filled) + "]"

# --- input / paint -----------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var key := _menu_key(event)
	if key == MenuKey.NONE:
		return
	get_viewport().set_input_as_handled()
	if _ct_dialog:
		if key == MenuKey.BACK:
			UiSfx.back(self)
			_close_car_tuner()
		return  # arrows no-op: the tuner grid is mouse-driven
	if _sb_dialog:
		_sb_input(key)
		return
	if _dev_dialog:
		_dev_input(key)
		return
	if _up_dialog:
		_up_input(key)
		return
	match key:
		MenuKey.UP:
			_index = wrapi(_index - 1, 0, _rows.size())
			UiSfx.move(self)
		MenuKey.DOWN:
			_index = wrapi(_index + 1, 0, _rows.size())
			UiSfx.move(self)
		MenuKey.LEFT:
			_adjust(-1)
			return
		MenuKey.RIGHT:
			_adjust(1)
			return
		MenuKey.BACK:
			UiSfx.back(self)
			_flow.to_title()
			return
	_refresh()

func _adjust(dir: int) -> void:
	var row: Dictionary = _rows[_index]
	if row.has("locked") and (row.locked as Callable).call():
		UiSfx.back(self)  # ghosted row: acknowledge, do nothing
		return
	if dir < 0 and StringName(row.get("kind", &"value")) != &"value":
		return
	UiSfx.select(self)
	(row.adjust as Callable).call(dir)
	if bool(row.get("persist", true)):
		_gs.save_settings(_settings_path)
	_refresh()

## Settings deliberately bypasses shared gameplay/menu actions: those actions
## also carry WASD, Enter, Space, stick, and face-button bindings. Raw physical
## arrows make this screen's contract narrow and reusable for nested rows.
func _menu_key(event: InputEvent) -> MenuKey:
	if not event is InputEventKey or not event.pressed:
		return MenuKey.NONE
	match event.physical_keycode:
		KEY_UP:
			return MenuKey.UP
		KEY_DOWN:
			return MenuKey.DOWN
		KEY_LEFT:
			return MenuKey.LEFT
		KEY_RIGHT:
			return MenuKey.RIGHT
		KEY_ESCAPE:
			return MenuKey.BACK
	return MenuKey.NONE

func _refresh() -> void:
	for i in _rows.size():
		var selected := i == _index
		var locked: bool = _rows[i].has("locked") and (_rows[i].locked as Callable).call()
		_name_labels[i].modulate = LOCKED_TEXT if locked else (AMBER if selected else ALIVE_TEXT)
		var v: Array = (_rows[i].value as Callable).call()
		_value_labels[i].text = v[0]
		_value_labels[i].modulate = v[1]

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = AMBER
	for side in ["left", "right", "top", "bottom"]:
		style.set("border_width_" + side, 6)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = AMBER
	vbox.add_child(title)

	for row in _rows:
		var hbox := HBoxContainer.new()
		var name_lbl := Label.new()
		name_lbl.text = row.name
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_lbl)
		var value_lbl := Label.new()
		value_lbl.add_theme_font_size_override("font_size", 22)
		value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(value_lbl)
		vbox.add_child(hbox)
		_name_labels.append(name_lbl)
		_value_labels.append(value_lbl)

	var hint := Label.new()
	hint.text = "UP/DOWN select    LEFT/RIGHT change    RIGHT opens -->    ESC back — autosaved"
	hint.add_theme_font_size_override("font_size", 13)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = DIM_TEXT
	vbox.add_child(hint)

# --- developer options dialog -----------------------------------------------

func _dev_input(key: MenuKey) -> void:
	match key:
		MenuKey.UP:
			_step_dev(-1)
			UiSfx.move(self)
		MenuKey.DOWN:
			_step_dev(1)
			UiSfx.move(self)
		MenuKey.LEFT:
			_adjust_dev(-1)
			return
		MenuKey.RIGHT:
			_adjust_dev(1)
			return
		MenuKey.BACK:
			UiSfx.back(self)
			_close_dev_dialog()
			return
	_refresh_dev()

func _step_dev(dir: int) -> void:
	var candidate: int = _dev_index
	for _i in _dev_rows.size():
		candidate = wrapi(candidate + dir, 0, _dev_rows.size())
		if _dev_row_enabled(candidate):
			_dev_index = candidate
			return

func _dev_row_enabled(index: int) -> bool:
	return index == 0 or index == _dev_rows.size() - 1 or _gs.dev_mode

func _adjust_dev(dir: int) -> void:
	if not _dev_row_enabled(_dev_index):
		return
	var row: Dictionary = _dev_rows[_dev_index]
	if dir < 0 and StringName(row.get("kind", &"value")) != &"value":
		return
	UiSfx.select(self)
	(row.adjust as Callable).call(dir)
	if bool(row.get("persist", true)):
		_gs.save_settings(_settings_path)
	_refresh_dev()

func _open_dev_dialog() -> void:
	if _dev_dialog:
		return
	_dev_index = 0
	_dev_dialog = Control.new()
	_dev_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dev_dialog)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dev_dialog.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dev_dialog.add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = AMBER
	for side in ["left", "right", "top", "bottom"]:
		style.set("border_width_" + side, 6)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "DEVELOPER OPTIONS"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = AMBER
	vbox.add_child(title)

	for row in _dev_rows:
		var hbox := HBoxContainer.new()
		var name_lbl := Label.new()
		name_lbl.text = row.name
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_lbl)
		var value_lbl := Label.new()
		value_lbl.add_theme_font_size_override("font_size", 22)
		value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(value_lbl)
		vbox.add_child(hbox)
		_dev_name_labels.append(name_lbl)
		_dev_value_labels.append(value_lbl)

	var hint := Label.new()
	hint.text = "ARROWS select/change    ESC back — autosaved    DEVELOPER MODE powers the rows"
	hint.add_theme_font_size_override("font_size", 13)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = DIM_TEXT
	vbox.add_child(hint)
	_refresh_dev()

func _close_dev_dialog() -> void:
	if not _dev_dialog:
		return
	_dev_dialog.queue_free()
	_dev_dialog = null
	_dev_name_labels.clear()
	_dev_value_labels.clear()
	_refresh()

func _refresh_dev() -> void:
	if not _dev_dialog:
		return
	for i in _dev_rows.size():
		var enabled := _dev_row_enabled(i)
		var selected := enabled and i == _dev_index
		_dev_name_labels[i].modulate = AMBER if selected else (ALIVE_TEXT if enabled else LOCKED_TEXT)
		var v: Array = (_dev_rows[i].value as Callable).call()
		_dev_value_labels[i].text = v[0]
		_dev_value_labels[i].modulate = v[1] if enabled else LOCKED_TEXT

# --- soundboard dialog (dev options -> SOUNDBOARD) ----------------------------
## Third-level modal following the dev-dialog pattern: raw arrows, ESC closes
## this level only. RIGHT auditions the selected AudioDirector event exactly as
## the game would play it (volume trim + pitch jitter included).

func _sb_input(key: MenuKey) -> void:
	match key:
		MenuKey.UP:
			_sb_index = wrapi(_sb_index - 1, 0, _sb_events.size())
			UiSfx.move(self)
		MenuKey.DOWN:
			_sb_index = wrapi(_sb_index + 1, 0, _sb_events.size())
			UiSfx.move(self)
		MenuKey.RIGHT:
			var event: StringName = _sb_events[_sb_index]
			if String(event).begins_with("bgm_"):
				# Music rows TOGGLE (3-minute tracks) via the director's override
				# — the preview rides the real crossfade players.
				var music := get_node_or_null(^"/root/MusicDirector")
				if music:
					music.set_override(&"" if music.playing_event() == event else event)
				_refresh_soundboard()
				return
			var audio := get_node_or_null(^"/root/AudioDirector")
			if audio:
				audio.play(event)
			return
		MenuKey.LEFT:
			return
		MenuKey.BACK:
			UiSfx.back(self)
			_close_soundboard()
			return
	_refresh_soundboard()

func _open_soundboard() -> void:
	if _sb_dialog:
		return
	var audio := get_node_or_null(^"/root/AudioDirector")
	if audio == null:
		return
	_sb_index = 0
	_sb_events = audio.CATALOG.keys()
	var music := get_node_or_null(^"/root/MusicDirector")
	if music:  # music tracks audition after the SFX catalog
		for event in music.TRACK_EVENTS:
			_sb_events.append(event)
	_sb_dialog = Control.new()
	_sb_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_sb_dialog)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sb_dialog.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sb_dialog.add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = AMBER
	for side in ["left", "right", "top", "bottom"]:
		style.set("border_width_" + side, 6)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(620, 0)  # match the dev dialog's width
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "SOUNDBOARD"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = AMBER
	vbox.add_child(title)

	# Rows scroll inside a capped viewport; title/hint stay pinned outside it,
	# so the amber border always closes no matter how long the catalog gets.
	_sb_scroll = ScrollContainer.new()
	_sb_scroll.custom_minimum_size = Vector2(0, 440)
	_sb_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_sb_scroll)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 3)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sb_scroll.add_child(rows)

	for event in _sb_events:
		var hbox := HBoxContainer.new()
		var name_lbl := Label.new()
		name_lbl.text = String(event)
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_lbl)
		var value_lbl := Label.new()
		value_lbl.add_theme_font_size_override("font_size", 15)
		value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(value_lbl)
		rows.add_child(hbox)
		_sb_name_labels.append(name_lbl)
		_sb_value_labels.append(value_lbl)

	var hint := Label.new()
	hint.text = "UP/DOWN select    RIGHT play    ESC back"
	hint.add_theme_font_size_override("font_size", 13)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = DIM_TEXT
	vbox.add_child(hint)
	_refresh_soundboard()

func _close_soundboard() -> void:
	if not _sb_dialog:
		return
	var music := get_node_or_null(^"/root/MusicDirector")
	if music:  # leaving the bench stops any track preview
		music.set_override(&"")
	_sb_dialog.queue_free()
	_sb_dialog = null
	_sb_scroll = null
	_sb_name_labels.clear()
	_sb_value_labels.clear()
	_refresh_dev()

func _refresh_soundboard() -> void:
	if not _sb_dialog:
		return
	var audio := get_node_or_null(^"/root/AudioDirector")
	var music := get_node_or_null(^"/root/MusicDirector")
	for i in _sb_events.size():
		_sb_name_labels[i].modulate = AMBER if i == _sb_index else ALIVE_TEXT
		var event: StringName = _sb_events[i]
		var is_bgm := String(event).begins_with("bgm_")
		var loaded: bool
		if is_bgm:
			loaded = music != null and music.has_asset(event)
		else:
			loaded = audio != null and audio.has_asset(event)
		if is_bgm and loaded and music.playing_event() == event:
			_sb_value_labels[i].text = "STOP"
			_sb_value_labels[i].modulate = AMBER
		else:
			_sb_value_labels[i].text = "PLAY ->" if loaded else "NO FILE"
			_sb_value_labels[i].modulate = DIM_TEXT if loaded else WARN
	if _sb_scroll and _sb_index < _sb_name_labels.size():
		var row := _sb_name_labels[_sb_index].get_parent() as Control
		if row:
			_sb_scroll.ensure_control_visible(row)

# --- check-for-updates dialog (SETTINGS -> CHECK FOR UPDATES) -----------------
## Second-level modal following the dev-dialog shell, but state-driven off the
## Updater autoload rather than a fixed row list: RIGHT runs the one action that
## makes sense for the current state (download / restart / re-check), ESC closes.
## The game only checks + downloads here; the PLAY launcher applies on restart.

func _adj_check_updates(_d: int) -> void:
	if not UpdaterScript.RELEASES_LIVE:
		return  # defensive: _adjust already blocks locked rows
	_open_update_dialog()

func _val_updates() -> Array:
	if not UpdaterScript.RELEASES_LIVE:
		return ["COMING SOON", LOCKED_TEXT]
	return ["-->", DIM_TEXT]

func _locked_updates() -> bool:
	return not UpdaterScript.RELEASES_LIVE

func _up_input(key: MenuKey) -> void:
	match key:
		MenuKey.RIGHT:
			UiSfx.select(self)
			_up_primary()
		MenuKey.BACK:
			UiSfx.back(self)
			_close_update_dialog()

func _up_primary() -> void:
	match _updater.state:
		UpdaterScript.State.AVAILABLE:
			_updater.download()
		UpdaterScript.State.DOWNLOADED:
			if not _updater.relaunch():
				_up_status_lbl.text = "Update ready — close and reopen with PLAY to finish."
				_up_status_lbl.modulate = AMBER
				_up_action_lbl.text = ""
		UpdaterScript.State.UP_TO_DATE, UpdaterScript.State.ERROR:
			_updater.check()

func _open_update_dialog() -> void:
	if _up_dialog or _updater == null:
		return
	_up_dialog = Control.new()
	_up_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_up_dialog)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_up_dialog.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_up_dialog.add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = AMBER
	for side in ["left", "right", "top", "bottom"]:
		style.set("border_width_" + side, 6)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "CHECK FOR UPDATES"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = AMBER
	vbox.add_child(title)

	_up_version_lbl = Label.new()
	_up_version_lbl.add_theme_font_size_override("font_size", 18)
	_up_version_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_up_version_lbl.modulate = DIM_TEXT
	vbox.add_child(_up_version_lbl)

	_up_status_lbl = Label.new()
	_up_status_lbl.add_theme_font_size_override("font_size", 22)
	_up_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_up_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_up_status_lbl.custom_minimum_size = Vector2(560, 0)
	vbox.add_child(_up_status_lbl)

	# Changelog scrolls inside a capped viewport so the amber border always
	# closes no matter how long the release notes run.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	_up_changelog_lbl = Label.new()
	_up_changelog_lbl.add_theme_font_size_override("font_size", 15)
	_up_changelog_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_up_changelog_lbl.custom_minimum_size = Vector2(560, 0)
	_up_changelog_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_up_changelog_lbl.modulate = ALIVE_TEXT
	scroll.add_child(_up_changelog_lbl)

	_up_action_lbl = Label.new()
	_up_action_lbl.add_theme_font_size_override("font_size", 22)
	_up_action_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_up_action_lbl.modulate = AMBER
	vbox.add_child(_up_action_lbl)

	var hint := Label.new()
	hint.text = "RIGHT does the action    ESC back"
	hint.add_theme_font_size_override("font_size", 13)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = DIM_TEXT
	vbox.add_child(hint)

	_updater.state_changed.connect(_on_update_state)
	_updater.progress_changed.connect(_on_update_progress)
	_updater.check()  # auto-check the moment the panel opens
	_refresh_update()

func _close_update_dialog() -> void:
	if not _up_dialog:
		return
	if _updater and _updater.state_changed.is_connected(_on_update_state):
		_updater.state_changed.disconnect(_on_update_state)
	if _updater and _updater.progress_changed.is_connected(_on_update_progress):
		_updater.progress_changed.disconnect(_on_update_progress)
	_up_dialog.queue_free()
	_up_dialog = null
	_up_version_lbl = null
	_up_status_lbl = null
	_up_changelog_lbl = null
	_up_action_lbl = null
	_refresh()

func _on_update_state(_s: int) -> void:
	_refresh_update()

func _on_update_progress(_f: float) -> void:
	_refresh_update()

func _refresh_update() -> void:
	if not _up_dialog:
		return
	var cur: String = _updater.current_version()
	var latest: String = _updater.latest_version
	_up_version_lbl.text = "Current: %s" % cur if latest == "" \
		else "Current: %s    Latest: %s" % [cur, latest]
	_up_changelog_lbl.text = _updater.changelog
	match _updater.state:
		UpdaterScript.State.CHECKING:
			_up_status_lbl.text = "Checking…"
			_up_status_lbl.modulate = DIM_TEXT
			_up_action_lbl.text = ""
		UpdaterScript.State.UP_TO_DATE:
			_up_status_lbl.text = "You're on the latest — no updates yet."
			_up_status_lbl.modulate = ALIVE_TEXT
			_up_action_lbl.text = "CHECK AGAIN -->"
		UpdaterScript.State.AVAILABLE:
			_up_status_lbl.text = "Update available: %s" % _updater.latest_version
			_up_status_lbl.modulate = AMBER
			_up_action_lbl.text = "DOWNLOAD -->"
		UpdaterScript.State.DOWNLOADING:
			_up_status_lbl.text = "Downloading… %d%%" % int(round(_updater.download_fraction * 100.0))
			_up_status_lbl.modulate = ALIVE_TEXT
			_up_action_lbl.text = ""
		UpdaterScript.State.DOWNLOADED:
			_up_status_lbl.text = "Downloaded — restart to finish."
			_up_status_lbl.modulate = AMBER
			_up_action_lbl.text = "RESTART NOW -->"
		UpdaterScript.State.ERROR:
			_up_status_lbl.text = _updater.error_text
			_up_status_lbl.modulate = WARN
			_up_action_lbl.text = "TRY AGAIN -->"
		_:
			_up_status_lbl.text = ""
			_up_action_lbl.text = ""
