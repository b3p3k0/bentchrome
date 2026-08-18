extends SceneTree
## Botlab sweep aggregator: folds every match_*.json in a results directory
## into one summary.json — a per-car balance table (win rate, K/D, damage
## economy, accuracy, survival) across the sweep. Run by tools/botlab.sh after
## the match loop:
##
##   BOTLAB_AGGREGATE=res://tools/botlab/out \
##     godot --headless --path . -s res://tools/botlab/aggregate.gd

func _init() -> void:
	process_frame.connect(_go, CONNECT_ONE_SHOT)

func _go() -> void:
	var dir_path := OS.get_environment("BOTLAB_AGGREGATE")
	if dir_path.is_empty():
		dir_path = "res://tools/botlab/out"
	var dir := DirAccess.open(dir_path)
	if dir == null:
		print("[botlab] AGGREGATE-FAIL: cannot open %s" % dir_path)
		quit(1)
		return
	var rows := {}  # label -> accumulator
	var matches := 0
	for fname in dir.get_files():
		if not (fname.begins_with("match_") and fname.ends_with(".json")):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(fname)))
		if not parsed is Dictionary or not parsed.has("cars"):
			push_warning("[botlab] skipping unreadable %s" % fname)
			continue
		matches += 1
		_fold_match(rows, parsed)
	if matches == 0:
		print("[botlab] AGGREGATE-FAIL: no match files in %s" % dir_path)
		quit(1)
		return
	var summary := {"matches": matches, "cars": _summarize(rows)}
	var f := FileAccess.open(dir_path.path_join("summary.json"), FileAccess.WRITE)
	if f == null:
		print("[botlab] AGGREGATE-FAIL: cannot write summary.json")
		quit(1)
		return
	f.store_string(JSON.stringify(summary, "\t"))
	f.close()
	print("[botlab] AGGREGATE-OK matches=%d cars=%d -> %s" %
		[matches, rows.size(), dir_path.path_join("summary.json")])
	quit(0)

func _fold_match(rows: Dictionary, match_data: Dictionary) -> void:
	var winners: Array = String(match_data.get("verdict", {}).get("winner", "")).split(" & ")
	var first_blood := String(match_data.get("first_blood", ""))
	for car in match_data.cars:
		var label := String(car.label)
		if not rows.has(label):
			rows[label] = {
				"car": car.car, "driver": car.driver, "matches": 0, "wins": 0,
				"kills": 0, "deaths": 0, "first_deaths": 0,
				"dealt": 0.0, "taken": 0.0, "taken_by_kind": {},
				"shots": 0, "hits": 0, "frames_alive": 0,
				"range_sum": 0.0, "range_weight": 0.0,
				"death_causes": {},
			}
		var r: Dictionary = rows[label]
		r.matches += 1
		if label in winners:
			r.wins += 1
		r.kills += int(car.kills)
		if not bool(car.alive):
			r.deaths += 1
			r.death_causes[car.death_cause] = int(r.death_causes.get(car.death_cause, 0)) + 1
		if first_blood == label:
			r.first_deaths += 1
		for v in car.damage_dealt.values():
			r.dealt += v
		for k in car.damage_taken:
			r.taken += car.damage_taken[k]
			r.taken_by_kind[k] = float(r.taken_by_kind.get(k, 0.0)) + car.damage_taken[k]
		r.shots += int(car.shots_fired)
		r.hits += int(car.vehicle_hits)
		r.frames_alive += int(car.frames_alive)
		r.range_sum += float(car.avg_engage_range) * float(car.get("shots_fired", 0))
		r.range_weight += float(car.get("shots_fired", 0))

func _summarize(rows: Dictionary) -> Array:
	var out: Array = []
	for label in rows:
		var r: Dictionary = rows[label]
		var m := maxi(int(r.matches), 1)
		out.append({
			"label": label,
			"car": r.car,
			"driver": r.driver,
			"matches": r.matches,
			"win_rate": snappedf(float(r.wins) / m, 0.001),
			"avg_kills": snappedf(float(r.kills) / m, 0.01),
			"death_rate": snappedf(float(r.deaths) / m, 0.001),
			"kd": snappedf(float(r.kills) / maxi(int(r.deaths), 1), 0.01),
			"first_death_rate": snappedf(float(r.first_deaths) / m, 0.001),
			"avg_dealt": snappedf(r.dealt / m, 0.1),
			"avg_taken": snappedf(r.taken / m, 0.1),
			"damage_economy": snappedf(r.dealt / maxf(r.taken, 1.0), 0.01),
			"accuracy": snappedf(float(r.hits) / maxi(int(r.shots), 1), 0.001),
			"avg_frames_alive": int(float(r.frames_alive) / m),
			"avg_engage_range": snappedf(r.range_sum / maxf(r.range_weight, 1.0), 0.1),
			"taken_by_kind": _rounded(r.taken_by_kind),
			"death_causes": r.death_causes,
		})
	out.sort_custom(func(a, b): return a.win_rate > b.win_rate)
	return out

func _rounded(dict: Dictionary) -> Dictionary:
	var out := {}
	for k in dict:
		out[k] = snappedf(float(dict[k]), 0.1)
	return out
