extends SceneTree
## Fields seeded stock rivals on any combat arena and records long stalls and
## pit falls. The shell runner collects only the stable, greppable event lines.

const EnemyScene := preload("res://vehicles/enemy_vehicle.tscn")
const Loader := preload("res://levels/level_loader.gd")

const FPS := 60
const STALL_SPEED := 25.0
const STALL_FRAMES := FPS
const AIR_WINDOW := 90
const HIT_WINDOW := 45

var _cars: Array = []
var _track: Dictionary = {}
var _frame := 0
var _frames_run := 0
var _seed := 1
var _scene_path := ""
var _seconds := 180.0
var _car_count := 5
var _cell_size := 128.0

func _init() -> void:
	if not _parse_args():
		return
	process_frame.connect(_run, CONNECT_ONE_SHOT)

## Pure stall-state transition. Callers own the state returned here; an event
## is emitted only when a qualifying span closes or finish closes it as open.
static func stall_step(previous: Dictionary, speed: float, grounded: bool, frame: int,
		context: Dictionary = {}, finish := false) -> Dictionary:
	var state := previous.duplicate(true)
	var event := {}
	if finish:
		if int(state.get("frames", 0)) >= STALL_FRAMES:
			event = _stall_event(state, true)
		return {"state": {}, "event": event}

	if speed < STALL_SPEED and grounded:
		if int(state.get("frames", 0)) == 0:
			state = context.duplicate(true)
			state["start_frame"] = frame
			state["frames"] = 0
		state["frames"] = int(state.frames) + 1
	elif int(state.get("frames", 0)) > 0:
		if int(state.frames) >= STALL_FRAMES:
			event = _stall_event(state, false)
		state = {}
	return {"state": state, "event": event}

static func _stall_event(state: Dictionary, open: bool) -> Dictionary:
	return {
		"frames": int(state.frames),
		"start_frame": int(state.start_frame),
		"pos": state.get("pos", Vector2.ZERO),
		"mode": String(state.get("mode", "UNKNOWN")),
		"guard": bool(state.get("guard", false)),
		"open": open,
	}

func _parse_args() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene_path = _normalize_scene_path(arg.substr(8))
		elif arg.begins_with("--seed="):
			var value := arg.substr(7)
			if not value.is_valid_int():
				return _fail("invalid --seed: " + value)
			_seed = int(value)
		elif arg.begins_with("--seconds="):
			var value := arg.substr(10)
			if not value.is_valid_float() or float(value) <= 0.0:
				return _fail("--seconds must be greater than 0")
			_seconds = float(value)
		elif arg.begins_with("--cars="):
			var value := arg.substr(7)
			if not value.is_valid_int() or int(value) <= 0:
				return _fail("--cars must be greater than 0")
			_car_count = int(value)
		elif arg.begins_with("--cell="):
			var value := arg.substr(7)
			if not value.is_valid_float() or float(value) <= 0.0:
				return _fail("--cell must be greater than 0")
			_cell_size = float(value)
		else:
			return _fail("unknown argument: " + arg)
	if _scene_path.is_empty():
		return _fail("missing required --scene")
	return true

func _normalize_scene_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return path
	if path.is_absolute_path():
		return ProjectSettings.localize_path(path)
	return "res://" + path.trim_prefix("./")

func _run() -> void:
	seed(_seed)
	var resource := load(_scene_path)
	var packed := resource as PackedScene
	if packed == null:
		_fail("scene is not a PackedScene: " + _scene_path)
		return
	var arena := packed.instantiate()
	if arena == null:
		_fail("failed to instantiate scene: " + _scene_path)
		return
	arena.set("mp_managed", true)
	root.add_child(arena)
	current_scene = arena

	var spawns_value: Variant = arena.get("mp_spawns")
	if not spawns_value is Array or (spawns_value as Array).is_empty():
		_fail("arena has no mp_spawns: " + _scene_path)
		return
	var spawns: Array = spawns_value
	_spawn_cars(arena, spawns)
	if _cars.is_empty():
		_fail("no stock rivals could be fielded")
		return

	var frame_cap := int(_seconds * FPS)
	for i in frame_cap:
		await physics_frame
		_frame = i
		_frames_run = i + 1
		if _sample_cars() <= 1:
			break
	_finalize_stalls()
	var car_frames := 0
	for value in _track.values():
		car_frames += int((value as Dictionary).observed_frames)
	print("[done] seed=%d frames=%d car_frames=%d" % [_seed, _frames_run, car_frames])
	quit(0)

func _spawn_cars(arena: Node, spawns: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var count := mini(_car_count, spawns.size())
	var picks: Array = Loader.pick_cars(count, "", rng)
	for i in picks.size():
		var car_id := String(picks[i])
		var car: Node2D = EnemyScene.instantiate()
		car.set("stats", load("res://data/vehicles/%s.tres" % car_id))
		var spot: Dictionary = spawns[i]
		car.position = spot.pos
		car.rotation = float(spot.heading)
		if int(spot.get("floor", -1)) >= 1:
			car.set("start_floor", int(spot.floor))
		arena.add_child(car)
		car.get_node("Driver").mix = Loader.mix_for_car(car_id)
		var key := car.get_instance_id()
		_cars.append({"car": car, "key": key})
		_track[key] = {
			"id": car_id,
			"air": -9999,
			"hit": -9999,
			"vel": Vector2.ZERO,
			"pos": car.global_position,
			"hp": 1.0,
			"done": false,
			"guard": false,
			"mode": "UNKNOWN",
			"stall": {},
			"observed_frames": 0,
		}

func _sample_cars() -> int:
	var alive := 0
	for entry in _cars:
		var key := int(entry.key)
		var tracked: Dictionary = _track[key]
		var car_value: Variant = entry.car
		if not is_instance_valid(car_value):
			if not bool(tracked.done):
				_close_stall(tracked, false)
				tracked.done = true
				_track[key] = tracked
			continue
		if bool(tracked.done):
			continue

		var car: Node2D = car_value
		tracked.observed_frames = int(tracked.observed_frames) + 1
		if bool(car.get("_falling")):
			_close_stall(tracked, false)
			_log_fall(tracked)
			tracked.done = true
			_track[key] = tracked
			continue

		alive += 1
		_update_tracking(car, tracked)
		var airborne := _is_airborne(car)
		var context := {
			"pos": car.global_position,
			"mode": tracked.mode,
			"guard": tracked.guard,
		}
		var result := stall_step(
			tracked.stall, Vector2(tracked.vel).length(), not airborne, _frame, context)
		tracked.stall = result.state
		if not (result.event as Dictionary).is_empty():
			_log_stall(tracked, result.event)
		_track[key] = tracked
	return alive

func _update_tracking(car: Node2D, tracked: Dictionary) -> void:
	var airborne := _is_airborne(car)
	if airborne:
		if _frame - int(tracked.air) > 5:
			tracked["air_from"] = car.global_position
			tracked["air_vel"] = tracked.vel
		tracked.air = _frame
	var hp := 1.0
	if car.has_method(&"get_hp_fraction"):
		hp = float(car.call(&"get_hp_fraction"))
	if hp < float(tracked.hp) - 0.0001:
		tracked.hit = _frame
	tracked.hp = hp
	if car.has_method(&"get_real_velocity"):
		tracked.vel = car.call(&"get_real_velocity")
	tracked.pos = car.global_position
	var driver := car.get_node_or_null("Driver")
	if driver:
		tracked.guard = bool(driver.get("_guard_active"))
		tracked.mode = _driver_mode_name(driver)

func _driver_mode_name(driver: Node) -> String:
	var mode_value: Variant = driver.get("_mode")
	if not mode_value is int:
		return "UNKNOWN"
	var driver_script := driver.get_script() as GDScript
	if driver_script == null:
		return "UNKNOWN"
	var constants := driver_script.get_script_constant_map()
	var modes: Variant = constants.get("Mode", {})
	if modes is Dictionary:
		for mode_name in modes:
			if int(modes[mode_name]) == int(mode_value):
				return String(mode_name)
	return "UNKNOWN"

func _is_airborne(car: Node) -> bool:
	var height: Variant = car.get("height")
	return (height is float or height is int) and float(height) > 0.0

func _close_stall(tracked: Dictionary, open: bool) -> void:
	var result := stall_step(tracked.stall, 0.0, false, _frame, {}, open)
	tracked.stall = result.state
	if not (result.event as Dictionary).is_empty():
		_log_stall(tracked, result.event)

func _finalize_stalls() -> void:
	for key in _track:
		var tracked: Dictionary = _track[key]
		if not bool(tracked.done):
			_close_stall(tracked, true)
		_track[key] = tracked

func _log_stall(tracked: Dictionary, event: Dictionary) -> void:
	var pos: Vector2 = event.pos
	var cell := _cell_for(pos)
	var line := (
		"[stall] seed=%d t=%.1f car=%s secs=%.1f pos=%s cell=(%d,%d) mode=%s guard=%s"
		% [
			_seed,
			float(event.start_frame) / FPS,
			tracked.id,
			float(event.frames) / FPS,
			_format_vector(pos),
			cell.x,
			cell.y,
			event.mode,
			str(event.guard),
		]
	)
	if bool(event.open):
		line += " open=true"
	print(line)

func _log_fall(tracked: Dictionary) -> void:
	var pos: Vector2 = tracked.pos
	var cell := _cell_for(pos)
	var why := "drove"
	if _frame - int(tracked.air) < AIR_WINDOW:
		why = "after-air"
	elif _frame - int(tracked.hit) < HIT_WINDOW:
		why = "after-hit"
	var line := (
		"[fall] seed=%d t=%.1f car=%s pos=%s cell=(%d,%d) speed=%.0f why=%s "
		+ "guard=%s mode=%s"
	) % [
		_seed,
		float(_frame) / FPS,
		tracked.id,
		_format_vector(pos),
		cell.x,
		cell.y,
		Vector2(tracked.vel).length(),
		why,
		str(tracked.guard),
		tracked.mode,
	]
	if why == "after-air":
		line += " launched_from=%s launch_vel=%s" % [
			_format_vector(tracked.get("air_from", pos)),
			_format_vector(tracked.get("air_vel", Vector2.ZERO)),
		]
	print(line)

func _cell_for(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / _cell_size)), int(floor(pos.y / _cell_size)))

func _format_vector(value: Vector2) -> String:
	return "(%.0f, %.0f)" % [value.x, value.y]

func _fail(reason: String) -> bool:
	printerr("[stall] ERROR: " + reason)
	quit(1)
	return false
