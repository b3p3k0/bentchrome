extends RefCounted
## Locks the July 2026 control remap (rev 2): mouse-first weapon cycling ("/"
## keyboard fallback, next-only), LCtrl handbrake, G zoom toggle, E and Q
## unbound/reserved. InputRouter (autoload, live under the -s runner) built
## these actions.

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
	t.check(KEY_G in _keys(&"zoom_toggle"), "remap: zoom on G")
	t.check(not KEY_CTRL in _keys(&"zoom_toggle"), "remap: zoom off Ctrl")
	t.check(KEY_CTRL in _keys(&"handbrake"), "remap: handbrake on LCtrl")
	t.check(not KEY_E in _keys(&"handbrake"), "remap: handbrake off E (retired)")
	t.check(KEY_SLASH in _keys(&"weapon_next"), "remap: '/' cycles next")
	t.check(not KEY_E in _keys(&"weapon_next"), "remap: E stays unbound")
	t.check(_keys(&"weapon_prev").is_empty(), "remap: weapon_prev is wheel-only (Q reserved)")
