extends SceneTree
## Botlab match runner: ONE headless match per process (hermetic; the shell
## script loops/parallelizes). Loads an arena with mp_managed so the baked
## cars become pure spawn data, fields the configured entrants (stock
## EnemyDriver mixes or custom Driver bots), steps real physics to a verdict,
## and writes one telemetry JSON. Run:
##
##   BOTLAB_CONFIG=res://tools/botlab/configs/duel_smoke.json \
##     godot --headless --fixed-fps 60 --path . -s res://tools/botlab/botlab_probe.gd
##
## Env overrides: BOTLAB_SEED, BOTLAB_OUT, BOTLAB_TAG (output filename suffix),
## BOTLAB_SWAP=1 (reverse entrant order — league spawn mirroring),
## BOTLAB_GIT_REV (stamped into metadata by the shell).
## Prints "[botlab] MATCH-OK" / "MATCH-FAIL" for the shell to scrape.

const Combat := preload("res://game/combat.gd")
const Difficulty := preload("res://game/difficulty.gd")
const Loader := preload("res://levels/level_loader.gd")
const RecorderScript := preload("res://tools/botlab/match_recorder.gd")
const EnemyScene := preload("res://vehicles/enemy_vehicle.tscn")

var cfg := {
	"arena": "res://levels/downtown/downtown.tscn",
	"seed": 1234,
	"max_seconds": 180.0,
	"governor": "lethal",
	"entrants": [],
	"fill_stock": 0,
	"fight_director": false,
	"output": "res://tools/botlab/out",
}
var recorder: Node = null
var _done := false

func _init() -> void:
	process_frame.connect(_go, CONNECT_ONE_SHOT)

func _go() -> void:
	if not _load_config():
		_fail("bad config")
		return
	seed(int(cfg.seed))  # global RNG: weapon spread, cosmetics
	Difficulty.tier = Difficulty.Tier.HARD  # every knob 1.0 — data on the real game
	if String(cfg.governor) == "lethal":
		# The shipping governor keeps AI brawls non-lethal (0.35x + a sub-10%-HP
		# mercy floor) so the player gets the kills. A playerless match can
		# never end under it — lethal mode is the data baseline.
		Combat.AI_VS_AI_DAMAGE = 1.0
		Combat.AI_MERCY_HP = 0.0
	var arena: Node = load(String(cfg.arena)).instantiate()
	arena.set("mp_managed", true)  # before add_child: _ready folds cars to spawn data
	root.add_child(arena)
	current_scene = arena  # projectiles/explosions/impact FX spawn into current_scene
	var spawns_v: Variant = arena.get("mp_spawns")
	if not spawns_v is Array or (spawns_v as Array).is_empty():
		_fail("arena has no mp_spawns — not a combat_level scene?")
		return
	var spawns: Array = spawns_v
	var entrants: Array = cfg.entrants.duplicate(true)
	if OS.get_environment("BOTLAB_SWAP") == "1":
		entrants.reverse()
	_fill_stock(entrants)
	if entrants.size() < 2:
		_fail("need at least 2 entrants (have %d)" % entrants.size())
		return
	if entrants.size() > spawns.size():
		push_warning("[botlab] %d entrants, %d spawns — extras dropped" % [entrants.size(), spawns.size()])
		entrants = entrants.slice(0, spawns.size())
	recorder = RecorderScript.new()
	recorder.name = "MatchRecorder"
	arena.add_child(recorder)
	var picked := _pick_spawns(spawns, entrants.size())
	var labels := {}
	for i in entrants.size():
		if not _spawn_entrant(arena, entrants[i], picked[i], labels):
			_fail("could not field entrant %s" % [entrants[i]])
			return
	if bool(cfg.fight_director):
		var fd: Node = preload("res://ai/fight_director.gd").new()
		fd.name = "AIFightDirector"
		fd.setup(arena)
		arena.add_child(fd)
	await _run_match()

func _run_match() -> void:
	var frame_cap := int(float(cfg.max_seconds) * 60.0)
	var end_reason := "cap"
	for i in frame_cap:
		await physics_frame
		if recorder.alive_count() <= 1:
			end_reason = "elimination"
			break
	# Let the last died-edge bookkeeping and in-flight frees settle.
	await physics_frame
	var result: Dictionary = recorder.to_dict()
	result["meta"] = {
		"arena": cfg.arena,
		"seed": int(cfg.seed),
		"governor": cfg.governor,
		"end_reason": end_reason,
		"max_seconds": float(cfg.max_seconds),
		"swap": OS.get_environment("BOTLAB_SWAP") == "1",
		# The engine consumes --fixed-fps before get_cmdline_args() sees it, so
		# the shell tells us explicitly; direct probe runs report "unknown".
		"fixed_fps": OS.get_environment("BOTLAB_FIXED_FPS") \
			if not OS.get_environment("BOTLAB_FIXED_FPS").is_empty() else "unknown",
		"engine": Engine.get_version_info().get("string", "?"),
		"git_rev": OS.get_environment("BOTLAB_GIT_REV"),
		"date": Time.get_datetime_string_from_system(),
	}
	_verdict(result)
	_sanity(result)
	if not _write_result(result):
		_fail("could not write result JSON")
		return
	_done = true
	print("[botlab] MATCH-OK reason=%s frames=%d winner=%s" %
		[end_reason, result.frames, result.verdict.winner])
	quit(0)

## Winner: last car standing; at the cap, best HP fraction, then kills, then
## total damage dealt. Ties become joint winners, matching the MP rule.
func _verdict(result: Dictionary) -> void:
	var best: Array = []
	var best_key: Array = [-1.0, -1, -1.0]
	for car in result.cars:
		var dealt := 0.0
		for v in car.damage_dealt.values():
			dealt += v
		var key: Array = [car.hp_frac if car.alive else -1.0, car.kills, dealt]
		if key > best_key:
			best_key = key
			best = [car.label]
		elif key == best_key:
			best.append(car.label)
	result["verdict"] = {"winner": " & ".join(best), "joint": best.size() > 1}

## Cross-checks printed as warnings — a failed invariant means the recorder
## (or a new damage path) went wrong, not the match.
func _sanity(result: Dictionary) -> void:
	var dealt := 0.0
	var taken_attributed := 0.0
	for car in result.cars:
		for v in car.damage_dealt.values():
			dealt += v
		for k in car.damage_taken:
			if k != "environment":
				taken_attributed += car.damage_taken[k]
		if car.accuracy < 0.0 or car.accuracy > 1.0:
			push_warning("[botlab] SANITY accuracy out of range for %s" % car.label)
		if car.frames_alive > result.frames:
			push_warning("[botlab] SANITY frames_alive > match frames for %s" % car.label)
	if absf(dealt - taken_attributed) > maxf(taken_attributed * 0.02, 5.0):
		push_warning("[botlab] SANITY dealt %.1f != attributed taken %.1f" % [dealt, taken_attributed])

# ---------------------------------------------------------------- spawning

func _spawn_entrant(arena: Node, entrant: Dictionary, spot: Dictionary, labels: Dictionary) -> bool:
	var car_id := String(entrant.get("car", ""))
	var stats_path := "res://data/vehicles/%s.tres" % car_id
	if car_id.is_empty() or not ResourceLoader.exists(stats_path):
		push_error("[botlab] unknown car id '%s'" % car_id)
		return false
	var car: Node2D = EnemyScene.instantiate()
	car.set("stats", load(stats_path))  # before add_child — _ready applies them
	car.position = spot.pos
	car.rotation = float(spot.heading)
	if int(spot.get("floor", -1)) >= 1:
		car.set("start_floor", int(spot.floor))
	arena.add_child(car)
	var driver := String(entrant.get("driver", "stock"))
	if driver == "stock":
		var mix: Variant = entrant.get("mix")
		car.get_node("Driver").mix = Vector3(mix[0], mix[1], mix[2]) if mix is Array \
			else Loader.mix_for_car(car_id)
	else:
		if not ResourceLoader.exists(driver):
			push_error("[botlab] bot script not found: %s" % driver)
			return false
		var bot: Node = (load(driver) as GDScript).new()
		car.call("set_driver", bot)
	var label := car_id
	var n := 2
	while labels.has(label):
		label = "%s#%d" % [car_id, n]
		n += 1
	labels[label] = true
	recorder.register_car(car, label, car_id,
		driver if driver != "stock" else "stock")
	return true

func _fill_stock(entrants: Array) -> void:
	var extra := int(cfg.fill_stock)
	if extra <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg.seed)
	var taken: Array = []
	for e in entrants:
		taken.append(String(e.get("car", "")))
	for id in Loader.pick_cars(extra, "", rng, taken):
		entrants.append({"car": id, "driver": "stock"})

## Two entrants duel from the farthest spawn pair; bigger fields take the
## authored order (player slot first, then Enemy1..N).
func _pick_spawns(spawns: Array, n: int) -> Array:
	if n != 2:
		return spawns.slice(0, n)
	var best_a := 0
	var best_b := 1
	var best_d := -1.0
	for i in spawns.size():
		for j in range(i + 1, spawns.size()):
			var d: float = spawns[i].pos.distance_squared_to(spawns[j].pos)
			if d > best_d:
				best_d = d
				best_a = i
				best_b = j
	return [spawns[best_a], spawns[best_b]]

# ------------------------------------------------------------------ config

func _load_config() -> bool:
	var path := OS.get_environment("BOTLAB_CONFIG")
	if path.is_empty():
		push_error("[botlab] BOTLAB_CONFIG not set")
		return false
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("[botlab] cannot read config: %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("[botlab] config is not a JSON object: %s" % path)
		return false
	for k in parsed:
		cfg[k] = parsed[k]
	var env_seed := OS.get_environment("BOTLAB_SEED")
	if not env_seed.is_empty():
		cfg.seed = env_seed.to_int()
	var env_out := OS.get_environment("BOTLAB_OUT")
	if not env_out.is_empty():
		cfg.output = env_out
	return cfg.entrants is Array

func _write_result(result: Dictionary) -> bool:
	var dir := String(cfg.output)
	var abs := ProjectSettings.globalize_path(dir)
	DirAccess.make_dir_recursive_absolute(abs)
	var tag := OS.get_environment("BOTLAB_TAG")
	var fname := "match_%d%s.json" % [int(cfg.seed), ("_" + tag) if not tag.is_empty() else ""]
	var f := FileAccess.open(dir.path_join(fname), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(result, "\t"))
	f.close()
	print("[botlab] wrote %s" % dir.path_join(fname))
	return true

func _fail(why: String) -> void:
	if _done:
		return
	_done = true
	print("[botlab] MATCH-FAIL: %s" % why)
	quit(1)
