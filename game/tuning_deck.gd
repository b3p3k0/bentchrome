extends RefCounted
## The tuning deck (dev mode): a declarative registry of runtime-mutable
## gameplay knobs plus override persistence. Kevin dials values in by feel
## (F2 editor), overrides live in user://tuning.json (boot-applied in dev
## mode), and EXPORT writes the hand-back file that gets folded into base.
##
## Sections and their write targets:
##   defs     — data/weapons/*.tres properties. Loaded resources are process-
##              wide singletons (resource cache), so mutating one changes every
##              mount live.
##   terrain  — DrivingController.TERRAIN[type][prop]. Keyed (terrain, prop) so
##              a future per-vehicle affinity layer can compose on top.
##   vehicle  — Vehicle @exports (ram/bounce). Applied to live vehicles and
##              future spawns by the Dev autoload's spawn hook.
##   controller — DrivingController boost exports, same spawn-hook path.

const SAVE_PATH := "user://tuning.json"
const EXPORT_PATH := "user://tuning_export.json"

const DEF_DIR := "res://data/weapons"
const DEF_FILES := ["blunt_blaze", "goliath_turret", "lackey_cannon", "leap", "mine_jump",
	"mine_land", "missile_homing", "missile_power", "missile_standard", "molotov",
	"phantom_phire", "red_glare", "scythe", "splat_effect", "taser", "toe_jam"]

# prop -> [min, max, step]
const DEF_PROPS := {
	"damage": [0.0, 200.0, 1.0],
	"projectile_speed": [200.0, 2000.0, 25.0],
	"cooldown": [0.1, 10.0, 0.1],
	"projectile_lifetime": [0.2, 10.0, 0.1],
	"spread_deg": [0.0, 60.0, 1.0],
	"pellets": [1, 24, 1],
	"bursts": [1, 6, 1],
	"burst_interval": [0.05, 0.5, 0.01],
	"turn_rate_deg": [0.0, 400.0, 5.0],
	"acquisition_radius": [0.0, 3200.0, 50.0],
}
const TERRAIN_TYPES := [&"road", &"grass", &"snow", &"dirt", &"ice", &"water"]
const TERRAIN_PROPS := {
	"accel": [0.05, 1.5, 0.05],
	"top": [0.05, 1.5, 0.05],
	"grip": [0.05, 1.5, 0.05],
}
const VEHICLE_PROPS := {
	"ram_damage_scale": [0.01, 0.2, 0.005],
	"ram_min_speed": [50.0, 400.0, 10.0],
	"bounce_factor": [0.0, 1.0, 0.05],
	"bounce_min_speed": [20.0, 300.0, 10.0],
	"fall_damage_frac": [0.0, 0.6, 0.05],
}
const CONTROLLER_PROPS := {
	"boost_top_factor": [1.0, 2.5, 0.05],
	"boost_accel_factor": [1.0, 4.0, 0.1],
	"boost_burn_rate": [1.0, 20.0, 0.5],
}

var overrides := {"defs": {}, "terrain": {}, "vehicle": {}, "controller": {}}
var _base := {"defs": {}, "terrain": {}}  # snapshots for reset

static func def_path(name: String) -> String:
	return "%s/%s.tres" % [DEF_DIR, name]

## --- write paths -------------------------------------------------------------

func set_def(def_name: String, prop: String, value: float) -> void:
	var path := def_path(def_name)
	var res: Resource = load(path)
	if res == null:
		return
	_snapshot("defs", path + ":" + prop, res.get(prop))
	var current: Variant = res.get(prop)
	res.set(prop, int(round(value)) if current is int else value)
	overrides.defs.get_or_add(path, {})[prop] = res.get(prop)

func set_terrain(terrain: StringName, prop: String, value: float) -> void:
	var table: Dictionary = DrivingController.TERRAIN
	if not table.has(terrain):
		return
	_snapshot("terrain", "%s:%s" % [terrain, prop], table[terrain][prop])
	table[terrain][prop] = value
	overrides.terrain.get_or_add(String(terrain), {})[prop] = value

func set_vehicle(prop: String, value: float) -> void:
	overrides.vehicle[prop] = value  # applied by the Dev spawn hook / live pass

func set_controller(prop: String, value: float) -> void:
	overrides.controller[prop] = value

func get_def(def_name: String, prop: String) -> float:
	var res: Resource = load(def_path(def_name))
	return float(res.get(prop)) if res else 0.0

func get_terrain(terrain: StringName, prop: String) -> float:
	return float(DrivingController.TERRAIN[terrain][prop])

## --- reset -------------------------------------------------------------------

func reset_defs() -> void:
	for key in _base.defs:
		# rsplit: the def path itself contains "://" — only the LAST colon splits.
		var parts: PackedStringArray = key.rsplit(":", true, 1)
		var res: Resource = load(parts[0])
		if res:
			res.set(parts[1], _base.defs[key])
	_base.defs.clear()
	overrides.defs.clear()

func reset_terrain() -> void:
	for key in _base.terrain:
		var parts: PackedStringArray = key.rsplit(":", true, 1)
		DrivingController.TERRAIN[StringName(parts[0])][parts[1]] = _base.terrain[key]
	_base.terrain.clear()
	overrides.terrain.clear()

func reset_combat() -> void:
	overrides.vehicle.clear()
	overrides.controller.clear()
	# Live vehicles keep their current values until next spawn/level — combat
	# resets are best followed by a restart (noted in the editor status line).

func _snapshot(section: String, key: String, value: Variant) -> void:
	if not _base[section].has(key):
		_base[section][key] = value

## --- persistence -------------------------------------------------------------

func save(path := SAVE_PATH) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(overrides, "\t"))
		f.close()

## Loads overrides from disk and applies the def/terrain sections immediately.
## vehicle/controller sections apply through the Dev spawn hook.
func load_and_apply(path := SAVE_PATH) -> void:
	if not FileAccess.file_exists(path):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return
	for def_path_key in data.get("defs", {}):
		var def_name: String = String(def_path_key).get_file().get_basename()
		for prop in data.defs[def_path_key]:
			if DEF_PROPS.has(prop):
				set_def(def_name, prop, float(data.defs[def_path_key][prop]))
	for terrain in data.get("terrain", {}):
		for prop in data.terrain[terrain]:
			if TERRAIN_PROPS.has(prop):
				set_terrain(StringName(terrain), prop, float(data.terrain[terrain][prop]))
	for prop in data.get("vehicle", {}):
		if VEHICLE_PROPS.has(prop):
			overrides.vehicle[prop] = float(data.vehicle[prop])
	for prop in data.get("controller", {}):
		if CONTROLLER_PROPS.has(prop):
			overrides.controller[prop] = float(data.controller[prop])

## The hand-back artifact: pretty JSON with source hints, for folding tuned
## values into the base .tres files / exports.
func export_tuning(path := EXPORT_PATH) -> String:
	var out := {
		"_readme": "Bent Chrome tuning export — hand this file back to fold values into base. defs -> data/weapons/*.tres; terrain -> driving_controller.gd TERRAIN; vehicle -> vehicle.gd exports; controller -> driving_controller.gd exports.",
		"defs": overrides.defs,
		"terrain": overrides.terrain,
		"vehicle": overrides.vehicle,
		"controller": overrides.controller,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out, "\t"))
		f.close()
	return ProjectSettings.globalize_path(path)
