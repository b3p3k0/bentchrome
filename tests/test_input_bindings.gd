extends RefCounted
## Locks the July 2026 control remap: mouse-first weapon cycling ("/" keyboard
## fallback, next-only), E handbrake, Ctrl zoom toggle, Q reserved/unbound.
## InputRouter (autoload, live under the -s runner) built these actions.

var t

func _init(runner) -> void:
	t = runner

func _keys(action: StringName) -> Array:
	var out := []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			out.append(ev.physical_keycode)
	return out

func test_remap_bindings() -> void:
	t.check(InputMap.has_action(&"zoom_toggle"), "remap: zoom_toggle action exists")
	t.check(KEY_CTRL in _keys(&"zoom_toggle"), "remap: zoom on Ctrl")
	t.check(KEY_E in _keys(&"handbrake"), "remap: handbrake on E")
	t.check(not KEY_CTRL in _keys(&"handbrake"), "remap: handbrake off Ctrl")
	t.check(KEY_SLASH in _keys(&"weapon_next"), "remap: '/' cycles next")
	t.check(not KEY_E in _keys(&"weapon_next"), "remap: E freed from weapons")
	t.check(_keys(&"weapon_prev").is_empty(), "remap: weapon_prev is wheel-only (Q reserved)")
