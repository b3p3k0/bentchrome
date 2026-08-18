extends RefCounted
## The car deck (dev mode): per-car roster stats as runtime-mutable knobs,
## sibling of game/tuning_deck.gd. Kevin edits the car-tuner grid (Settings
## -> DEVELOPER OPTIONS -> CAR TUNER); values
## land on the loaded data/vehicles/<id>.tres singletons (process-wide — every
## future consumer sees them; Dev.reapply_car_stats pushes them onto live
## cars), persist in user://car_tuner.json (boot-applied in dev mode), and
## EXPORT writes the hand-back file for
## `python3 tools/migrate_roster_v2.py --fold` — the ONLY path to game truth
## (never writes roster.json or .tres itself).

const SAVE_PATH := "user://car_tuner.json"
const EXPORT_PATH := "user://car_tuner_export.json"
const ROSTER_PATH := "res://assets/data/roster.json"

# prop -> [min, max, step]; order = the tuner grid's column order. All ints on
# the 1-20 design scale except launch (0 = mass-derived sentinel) and the
# floats (fractional step = float prop: recharge + the slide-move pair).
const COLUMNS := {
	"acceleration": [1, 20, 1],
	"top_speed": [1, 20, 1],
	"handling": [1, 20, 1],
	"armor": [1, 20, 1],
	"special_power": [1, 20, 1],
	"mass": [1, 20, 1],
	"launch": [0, 20, 1],
	"special_ammo_cap": [1, 9, 1],
	"special_recharge_seconds": [1.0, 300.0, 0.5],
	"whip_scale": [0.5, 2.0, 0.05],
	"side_slide_bonus": [1.0, 3.0, 0.05],
}

## Fractional step = the prop stays a float end to end (set/export).
static func _is_float(prop: String) -> bool:
	return float(COLUMNS[prop][2]) < 1.0

var car_ids: Array[String] = []            # roster order = grid row order
var overrides := {}                        # id -> {prop: value}
var _baseline := {}                        # id -> {prop: roster-truth value}
var _cache := {}                           # id -> VehicleStats. STRONG refs on purpose:
										   # Godot's resource cache is weak — an edited
										   # .tres a car isn't holding would be freed and
										   # re-parsed pristine on the next load()

func _init() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROSTER_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return
	for c in data.get("characters", []):
		var id := String(c.get("id", ""))
		if id.is_empty():
			continue
		car_ids.append(id)
		var st: Dictionary = c.get("stats", {})
		_baseline[id] = {
			"acceleration": int(st.get("acceleration", 9)),
			"top_speed": int(st.get("top_speed", 9)),
			"handling": int(st.get("handling", 9)),
			"armor": int(st.get("armor", 9)),
			"special_power": int(st.get("special_power", 9)),
			"mass": int(c.get("mass", 9)),
			"launch": int(st.get("launch", 0)),
			"special_ammo_cap": int(c.get("special_ammo_cap", 1)),
			"special_recharge_seconds": float(c.get("special_recharge_seconds", 12.0)),
			"whip_scale": float(c.get("whip_scale", 1.0)),
			"side_slide_bonus": float(c.get("side_slide_bonus", 1.5)),
		}

static func tres_path(id: String) -> String:
	return "res://data/vehicles/%s.tres" % id

func _stats(id: String) -> Resource:
	if not car_ids.has(id):
		return null
	if not _cache.has(id):
		_cache[id] = load(tres_path(id))
	return _cache[id]

## --- read/write ---------------------------------------------------------------

## Present truth: the loaded singleton (includes boot-applied overrides).
func get_value(id: String, prop: String) -> float:
	var res := _stats(id)
	return float(res.get(prop)) if res and COLUMNS.has(prop) else 0.0

func set_value(id: String, prop: String, value: float) -> void:
	var res := _stats(id)
	if res == null or not COLUMNS.has(prop):
		return
	var r: Array = COLUMNS[prop]
	var clamped: Variant
	if _is_float(prop):
		clamped = clampf(value, float(r[0]), float(r[1]))
	else:
		clamped = clampi(int(round(value)), int(r[0]), int(r[1]))
	res.set(prop, clamped)
	overrides.get_or_add(id, {})[prop] = clamped

func baseline(id: String, prop: String) -> float:
	return float(_baseline.get(id, {}).get(prop, 0.0))

## --- reset --------------------------------------------------------------------

## Push roster-truth values onto every loaded singleton WITHOUT touching the
## overrides dict or the save file — MP standardization (Dev.suspend_data_tuning).
func restore_baselines() -> void:
	for id in car_ids:
		var res := _stats(id)
		if res == null:
			continue
		for prop in COLUMNS:
			res.set(prop, _baseline[id][prop])

## The tuner's RESET ALL button: pristine resources, cleared overrides, cleared file.
func reset_all() -> void:
	restore_baselines()
	overrides.clear()
	save()

## --- persistence --------------------------------------------------------------

func save(path := SAVE_PATH) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(overrides, "\t"))
		f.close()

func load_and_apply(path := SAVE_PATH) -> void:
	if not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return
	for id in data:
		for prop in data[id]:
			if COLUMNS.has(String(prop)):  # set_value clamps and validates the rest
				set_value(String(id), String(prop), float(data[id][prop]))

## The hand-back artifact: every car's CURRENT values, roster-shaped ints.
## Fold into game truth with tools/migrate_roster_v2.py --fold (updates
## roster.json surgically + re-runs the importer).
func export_file(path := EXPORT_PATH) -> String:
	var cars := {}
	for id in car_ids:
		var row := {}
		for prop in COLUMNS:
			var v := get_value(id, prop)
			row[prop] = v if _is_float(prop) else int(v)
		cars[id] = row
	var out := {
		"_readme": "Bent Chrome car-tuner export — fold into game truth with: python3 tools/migrate_roster_v2.py --fold <this file>",
		"schema_version": 2,
		"cars": cars,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out, "\t"))
		f.close()
	return ProjectSettings.globalize_path(path)
