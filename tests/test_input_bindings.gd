extends RefCounted
## Locks the July 2026 control map: mouse-first weapon cycling ("/" keyboard
## fallback, next-only), LCtrl handbrake, G-toggle overview, T/right-stick locate,
## E and Q unbound/reserved. InputRouter builds these actions at boot.

var t

func _init(runner) -> void:
	t = runner

func _keys(action: StringName) -> Array:
	var out := []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			out.append(ev.physical_keycode)
	return out

func _buttons(action: StringName) -> Array:
	var out := []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton:
			out.append(ev.button_index)
	return out

func test_remap_bindings() -> void:
	t.check(InputMap.has_action(&"zoom_toggle"), "remap: zoom_toggle action exists")
	t.check(KEY_G in _keys(&"zoom_toggle"), "remap: zoom on G")
	t.check(JOY_BUTTON_Y in _buttons(&"zoom_toggle"), "remap: overview on north face button")
	t.check(not KEY_CTRL in _keys(&"zoom_toggle"), "remap: zoom off Ctrl")
	t.check(InputMap.has_action(&"locate_player"), "remap: locate_player action exists")
	t.check(KEY_T in _keys(&"locate_player"), "remap: player locator on T")
	t.check(JOY_BUTTON_RIGHT_STICK in _buttons(&"locate_player"),
		"remap: player locator on right-stick click")
	t.check(KEY_CTRL in _keys(&"handbrake"), "remap: handbrake on LCtrl")
	t.check(not KEY_E in _keys(&"handbrake"), "remap: handbrake off E (retired)")
	t.check(KEY_SLASH in _keys(&"weapon_next"), "remap: '/' cycles next")
	t.check(not KEY_E in _keys(&"weapon_next"), "remap: E stays unbound")
	t.check(_keys(&"weapon_prev").is_empty(), "remap: weapon_prev is wheel-only (Q reserved)")
