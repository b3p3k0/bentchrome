extends SceneTree
## Headless importer: assets/data/roster.json -> data/vehicles/<id>.tres
## (one VehicleStats each). roster.json stays the single source of truth —
## it also binds the special (special_def -> data/weapons/<name>.tres) and
## the AI archetype. Validation is strict: missing/unknown keys, out-of-band
## stats, duplicate ids, or an unloadable special fail the import instead of
## becoming dead data (same philosophy as the terrain checks).
## Schema v2 (required): design ints ride the 1-20 scale (see StatCurves),
## shared terrain tables live in top-level terrain_profiles, and the import
## log reads back engine values in US units (mph) plus net terrain factors.
## Run: godot --headless --path . -s res://tools/import_roster.gd

const Curves := preload("res://resources/stat_curves.gd")
const Controller := preload("res://vehicles/driving_controller.gd")
const TerrainTables := preload("res://resources/terrain_tables.gd")
const MPH_PER_PXS := 0.15  # ui/hud.gd display anchor

# Terrain vocabulary + composition live in resources/terrain_tables.gd (shared
# with the garage's tire overlays); these stay as delegating aliases so every
# existing call site and test keeps reading Importer.*.
const TERRAIN_NAMES := TerrainTables.TERRAIN_NAMES
const TERRAIN_FIELDS := TerrainTables.TERRAIN_FIELDS
# Vocabulary the level_loader shim maps onto EnemyDriver.mix weights.
const ARCHETYPES := ["aggressor", "ambusher", "opportunist", "defender", "mini_boss"]
const REQUIRED_KEYS := ["id", "car_name", "driver_name", "flavor", "special_weapon",
	"special_def", "ai_archetype", "stats", "colors", "portrait", "mass"]
const OPTIONAL_KEYS := ["special_ammo_cap", "special_recharge_seconds", "terrain_modifiers",
	"burn_taken", "terrain_profile", "whip_scale", "side_slide_bonus"]
const STAT_KEYS := ["acceleration", "top_speed", "handling", "armor", "special_power"]

func _init() -> void:
	var f := FileAccess.open("res://assets/data/roster.json", FileAccess.READ)
	if f == null:
		push_error("import_roster: roster.json not found")
		quit(1)
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()

	var errors := roster_errors(data)
	if not errors.is_empty():
		for issue in errors:
			printerr("import_roster: " + issue)
		quit(1)
		return

	var count := 0
	for c in data["characters"]:
		var vs := VehicleStats.new()
		vs.id = StringName(String(c["id"]))
		vs.car_name = String(c["car_name"])
		vs.driver_name = String(c["driver_name"])
		vs.flavor = String(c["flavor"])

		var sw := String(c["special_weapon"])
		var colon := sw.find(":")
		if colon > 0:
			vs.special_name = sw.substr(0, colon).strip_edges()
			vs.special_desc = sw.substr(colon + 1).strip_edges()
		else:
			vs.special_desc = sw

		var st: Dictionary = c["stats"]
		vs.acceleration = int(st["acceleration"])
		vs.top_speed = int(st["top_speed"])
		vs.handling = int(st["handling"])
		vs.armor = int(st["armor"])
		vs.special_power = int(st["special_power"])
		vs.launch = int(st.get("launch", 0))

		var cols: Dictionary = c["colors"]
		vs.primary_color = Color(String(cols["primary"]))
		vs.accent_color = Color(String(cols["accent"]))

		vs.special_ammo_cap = int(c.get("special_ammo_cap", 1))
		vs.special_recharge_seconds = float(c.get("special_recharge_seconds", 12.0))
		vs.burn_taken = float(c.get("burn_taken", 1.0))
		vs.whip_scale = float(c.get("whip_scale", 1.0))
		vs.side_slide_bonus = float(c.get("side_slide_bonus", 1.5))
		vs.mass = int(c["mass"])
		vs.terrain_modifiers = build_terrain_modifiers(
			merged_terrain(c, data.get("terrain_profiles", {})))

		vs.special = load(special_def_path(String(c["special_def"])))
		if vs.special == null:
			printerr("import_roster: %s: special_def '%s' failed to load" % [c["id"], c["special_def"]])
			quit(1)
			return

		var path := "res://data/vehicles/%s.tres" % c["id"]
		var err := ResourceSaver.save(vs, path)
		if err != OK:
			printerr("import_roster: save failed for %s (err %d)" % [path, err])
			quit(1)
			return
		print("import_roster: %s -> err %d" % [path, err])
		_print_engine_readback(vs)
		count += 1

	print("import_roster: wrote %d vehicles" % count)
	quit()

static func special_def_path(name: String) -> String:
	return "res://data/weapons/%s.tres" % name

## Engine-unit readback (US units): what the authored ints become through
## StatCurves, plus each surface's NET factors (car ratio x global terrain
## table) — the number the driver actually feels, so the roster's raw ratios
## stop being opaque.
static func _print_engine_readback(vs: VehicleStats) -> void:
	print("  %s: top %.1f mph (%.1f px/s)  accel %.1f  turn %.1f  grip %.2f  hp %.1f  mass %.1f  launch %s" % [
		vs.id, Curves._slot(Curves.TOP_SPEED, vs.top_speed) * MPH_PER_PXS,
		Curves._slot(Curves.TOP_SPEED, vs.top_speed),
		Curves._slot(Curves.ACCELERATION, vs.acceleration),
		Curves._slot(Curves.TURN_RATE, vs.handling),
		Curves._slot(Curves.GRIP, vs.handling),
		Curves._slot(Curves.HP, vs.armor),
		(float(vs.mass) + 1.0) / 2.0,
		("%.2f" % Curves._slot(Curves.LAUNCH, vs.launch)) if vs.launch >= 1 else "derived"])
	for m in vs.terrain_modifiers:
		var base: Dictionary = Controller.TERRAIN.get(m.terrain, Controller.TERRAIN[&"road"])
		print("    net %s: accel %.2f  top %.2f  grip %.2f  steer %.2f" % [
			m.terrain, m.accel * float(base["accel"]), m.top * float(base["top"]),
			m.grip * float(base["grip"]), m.steer * float(base["steer"])])

## Whole-file validation: shape, duplicate ids, then per-character checks.
## Pure on the JSON except for resource/portrait existence probes.
static func roster_errors(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("characters")) != TYPE_ARRAY:
		errors.append("malformed roster.json (need a dict with a 'characters' array)")
		return errors
	if int(data.get("schema_version", 0)) != 2:
		errors.append("schema_version must be 2 (1-20 design scale — run tools/migrate_roster_v2.py)")
	var profiles: Variant = data.get("terrain_profiles", {})
	if typeof(profiles) != TYPE_DICTIONARY:
		errors.append("terrain_profiles must be an object")
		profiles = {}
	for name_v in profiles:
		for issue in terrain_profile_errors(profiles[name_v]):
			errors.append("terrain_profiles.%s: %s" % [name_v, issue])
	var seen := {}
	for c in data["characters"]:
		var car_id := String(c.get("id", "?")) if typeof(c) == TYPE_DICTIONARY else "?"
		if seen.has(car_id):
			errors.append("%s: duplicate id" % car_id)
		seen[car_id] = true
		for issue in character_errors(c):
			errors.append("%s: %s" % [car_id, issue])
		if typeof(c) == TYPE_DICTIONARY and c.has("terrain_profile") \
				and not profiles.has(String(c["terrain_profile"])):
			errors.append("%s: terrain_profile '%s' not in terrain_profiles" % [car_id, c["terrain_profile"]])
	return errors

static func character_errors(c: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if typeof(c) != TYPE_DICTIONARY:
		errors.append("character entry must be an object")
		return errors
	for key in REQUIRED_KEYS:
		if not c.has(key):
			errors.append("missing required key '%s'" % key)
	for key_v in c:
		var key := String(key_v)
		if key not in REQUIRED_KEYS and key not in OPTIONAL_KEYS:
			errors.append("unknown key '%s'" % key)
	if c.has("id") and String(c["id"]).is_empty():
		errors.append("id must be a non-empty string")

	if c.has("stats"):
		if typeof(c["stats"]) != TYPE_DICTIONARY:
			errors.append("stats must be an object")
		else:
			var st: Dictionary = c["stats"]
			for stat in STAT_KEYS:
				if not st.has(stat):
					errors.append("stats missing '%s'" % stat)
				else:
					errors.append_array(_range_errors("stats.%s" % stat, st[stat]))
			if st.has("launch"):  # optional standing-start torque; omit = mass-derived
				errors.append_array(_range_errors("stats.launch", st["launch"]))
			for stat_v in st:
				if String(stat_v) not in STAT_KEYS and String(stat_v) != "launch":
					errors.append("stats has unknown key '%s'" % stat_v)
	if c.has("mass"):
		errors.append_array(_range_errors("mass", c["mass"]))

	if c.has("colors"):
		if typeof(c["colors"]) != TYPE_DICTIONARY:
			errors.append("colors must be an object")
		else:
			for slot in ["primary", "accent"]:
				var raw: Variant = c["colors"].get(slot)
				if typeof(raw) != TYPE_STRING or not Color.html_is_valid(raw):
					errors.append("colors.%s must be a valid html color" % slot)

	if c.has("portrait") and not FileAccess.file_exists(String(c["portrait"])):
		errors.append("portrait '%s' not found" % c["portrait"])
	if c.has("special_def") and not ResourceLoader.exists(special_def_path(String(c["special_def"]))):
		errors.append("special_def '%s' has no %s" % [c["special_def"], special_def_path(String(c["special_def"]))])
	if c.has("ai_archetype") and String(c["ai_archetype"]) not in ARCHETYPES:
		errors.append("ai_archetype '%s' not in %s" % [c["ai_archetype"], ARCHETYPES])

	if c.has("special_ammo_cap") and (typeof(c["special_ammo_cap"]) not in [TYPE_INT, TYPE_FLOAT]
			or int(c["special_ammo_cap"]) < 1):
		errors.append("special_ammo_cap must be a positive integer")
	if c.has("special_recharge_seconds") and (typeof(c["special_recharge_seconds"]) not in [TYPE_INT, TYPE_FLOAT]
			or float(c["special_recharge_seconds"]) <= 0.0):
		errors.append("special_recharge_seconds must be a positive number")
	if c.has("burn_taken") and (typeof(c["burn_taken"]) not in [TYPE_INT, TYPE_FLOAT]
			or float(c["burn_taken"]) <= 0.0):
		errors.append("burn_taken must be a positive number")
	if c.has("whip_scale") and (typeof(c["whip_scale"]) not in [TYPE_INT, TYPE_FLOAT]
			or float(c["whip_scale"]) < 0.5 or float(c["whip_scale"]) > 2.0):
		errors.append("whip_scale must be a number in [0.5, 2.0]")
	if c.has("side_slide_bonus") and (typeof(c["side_slide_bonus"]) not in [TYPE_INT, TYPE_FLOAT]
			or float(c["side_slide_bonus"]) < 1.0 or float(c["side_slide_bonus"]) > 3.0):
		errors.append("side_slide_bonus must be a number in [1.0, 3.0]")

	if c.has("terrain_profile") and typeof(c["terrain_profile"]) != TYPE_STRING:
		errors.append("terrain_profile must be a profile-name string")

	errors.append_array(terrain_profile_errors(c.get("terrain_modifiers", {})))
	return errors

## Stats, mass, and launch share the 1-20 integer design scale (schema v2;
## odd values are the migrated legacy 1-10 line).
static func _range_errors(label: String, value: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or float(value) != floorf(float(value)):
		errors.append("%s must be an integer" % label)
	elif int(value) < 1 or int(value) > 20:
		errors.append("%s must be 1-20 (got %d)" % [label, int(value)])
	return errors

# Delegating wrappers — the implementations moved to resources/terrain_tables.gd
# (shared with garage tire overlays); tests and call sites keep Importer.*.
static func terrain_profile_errors(raw: Variant) -> PackedStringArray:
	return TerrainTables.terrain_profile_errors(raw)

static func merged_terrain(c: Dictionary, profiles: Dictionary) -> Dictionary:
	return TerrainTables.merged_terrain(c, profiles)

static func build_terrain_modifiers(raw: Dictionary) -> Array[VehicleTerrainModifier]:
	return TerrainTables.build_terrain_modifiers(raw)
