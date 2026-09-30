extends RefCounted
## Stall-probe bookkeeping tests stay pure: no arena or physics match is run.

const PROBE_PATH := "res://tools/probes/stall_probe.gd"
const Probe := preload(PROBE_PATH)

var t

func _init(runner) -> void:
	t = runner

func test_script_loads() -> void:
	var script := load(PROBE_PATH) as GDScript
	t.check(script != null and script.can_instantiate(), "stall probe: script loads and parses")

func test_stall_length() -> void:
	var events := _feed(_repeat(0.0, 75) + [30.0], _repeat(true, 76), false)
	t.check(events.size() == 1, "stall probe: one closed stall reported")
	t.check(events.size() == 1 and int(events[0].frames) == 75,
		"stall probe: closed stall keeps its exact frame length")

func test_short_dip_is_ignored() -> void:
	var events := _feed(_repeat(0.0, 54) + [30.0], _repeat(true, 55), false)
	t.check(events.is_empty(), "stall probe: 0.9 second dip is ignored")

func test_airborne_frames_are_ignored() -> void:
	var speeds := _repeat(0.0, 120)
	var grounded := _repeat(true, 30) + _repeat(false, 60) + _repeat(true, 30)
	var events := _feed(speeds, grounded, false)
	t.check(events.is_empty(), "stall probe: airborne frames neither count nor bridge dips")

func test_open_stall_closes_at_end() -> void:
	var events := _feed(_repeat(0.0, 90), _repeat(true, 90), true)
	t.check(events.size() == 1, "stall probe: running stall closes at the end")
	t.check(events.size() == 1 and int(events[0].frames) == 90,
		"stall probe: open stall keeps its exact frame length")
	t.check(events.size() == 1 and bool(events[0].open),
		"stall probe: end-closed stall carries the open flag")

func _feed(speeds: Array, grounded: Array, finish: bool) -> Array:
	var state := {}
	var events := []
	for frame in speeds.size():
		var result: Dictionary = Probe.stall_step(
			state, float(speeds[frame]), bool(grounded[frame]), frame)
		state = result.state
		if not (result.event as Dictionary).is_empty():
			events.append(result.event)
	if finish:
		var result: Dictionary = Probe.stall_step(state, 0.0, false, speeds.size(), {}, true)
		if not (result.event as Dictionary).is_empty():
			events.append(result.event)
	return events

func _repeat(value: Variant, count: int) -> Array:
	var values := []
	values.resize(count)
	values.fill(value)
	return values
