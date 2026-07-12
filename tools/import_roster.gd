extends SceneTree
## Headless importer: assets/data/roster.json -> data/vehicles/<id>.tres
## (one VehicleStats each). roster.json stays the single source of truth —
## it also binds the special (special_def -> data/weapons/<name>.tres) and
## the AI archetype. Validation is strict: missing/unknown keys, out-of-band
## stats, duplicate ids, or an unloadable special fail the import instead of
## becoming dead data (same philosophy as the terrain checks).
## Run: godot --headless --path . -s res://tools/import_roster.gd

const TERRAIN_NAMES := ["road", "grass", "snow", "dirt", "ice", "water"]
const TERRAIN_FIELDS := ["accel", "top", "grip", "steer", "dash_damage"]
# Vocabulary the level_loader shim maps onto EnemyDriver.mix weights.
const ARCHETYPES := ["aggressor", "ambusher", "opportunist", "defender", "mini_boss"]
const REQUIRED_KEYS := ["id", "car_name", "driver_name", "flavor", "special_weapon",
	"special_def", "ai_archetype", "stats", "colors", "portrait", "mass"]
const OPTIONAL_KEYS := ["special_ammo_cap", "special_recharge_seconds", "terrain_modifiers"]
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

		var cols: Dictionary = c["colors"]
		vs.primary_color = Color(String(cols["primary"]))
		vs.accent_color = Color(String(cols["accent"]))

		vs.special_ammo_cap = int(c.get("special_ammo_cap", 1))
		vs.special_recharge_seconds = float(c.get("special_recharge_seconds", 12.0))
		vs.mass = int(c["mass"])
		vs.terrain_modifiers = build_terrain_modifiers(c.get("terrain_modifiers", {}))

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
		count += 1

	print("import_roster: wrote %d vehicles" % count)
	quit()

static func special_def_path(name: String) -> String:
	return "res://data/weapons/%s.tres" % name

## Whole-file validation: shape, duplicate ids, then per-character checks.
## Pure on the JSON except for resource/portrait existence probes.
static func roster_errors(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("characters")) != TYPE_ARRAY:
		errors.append("malformed roster.json (need a dict with a 'characters' array)")
		return errors
	var seen := {}
	for c in data["characters"]:
		var car_id := String(c.get("id", "?")) if typeof(c) == TYPE_DICTIONARY else "?"
		if seen.has(car_id):
			errors.append("%s: duplicate id" % car_id)
		seen[car_id] = true
		for issue in character_errors(c):
			errors.append("%s: %s" % [car_id, issue])
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
			for stat_v in st:
				if String(stat_v) not in STAT_KEYS:
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

	if c.has("portrait") and not ResourceLoader.exists(String(c["portrait"])):
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

	errors.append_array(terrain_profile_errors(c.get("terrain_modifiers", {})))
	return errors

## Stats and mass share the 1-10 integer design scale.
static func _range_errors(label: String, value: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or float(value) != floorf(float(value)):
		errors.append("%s must be an integer" % label)
	elif int(value) < 1 or int(value) > 10:
		errors.append("%s must be 1-10 (got %d)" % [label, int(value)])
	return errors

static func terrain_profile_errors(raw: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if typeof(raw) != TYPE_DICTIONARY:
		errors.append("terrain_modifiers must be an object")
		return errors
	for surface_v in raw:
		var surface := String(surface_v)
		if surface not in TERRAIN_NAMES:
			errors.append("unknown terrain '%s'" % surface)
			continue
		var fields: Variant = raw[surface_v]
		if typeof(fields) != TYPE_DICTIONARY:
			errors.append("terrain '%s' must contain an object" % surface)
			continue
		for property_v in fields:
			var property := String(property_v)
			if property not in TERRAIN_FIELDS:
				errors.append("terrain '%s' has unknown property '%s'" % [surface, property])
			elif typeof(fields[property_v]) not in [TYPE_INT, TYPE_FLOAT] \
					or float(fields[property_v]) <= 0.0:
				errors.append("terrain '%s' property '%s' must be a positive number" % [surface, property])
	return errors

static func build_terrain_modifiers(raw: Dictionary) -> Array[VehicleTerrainModifier]:
	var out: Array[VehicleTerrainModifier] = []
	for surface_v in raw:
		var modifier := VehicleTerrainModifier.new()
		modifier.terrain = StringName(surface_v)
		var fields: Dictionary = raw[surface_v]
		for property_v in fields:
			modifier.set(String(property_v), float(fields[property_v]))
		out.append(modifier)
	return out
