extends SceneTree
## Headless importer: assets/data/roster.json -> data/vehicles/<id>.tres
## (one VehicleStats each). roster.json stays the single source of truth.
## Run: godot --headless --path . -s res://tools/import_roster.gd

const SPECIALS := {
	"bumper": "res://data/weapons/blunt_blaze.tres",
	"cricket": "res://data/weapons/leap.tres",
	"ghost": "res://data/weapons/phantom_phire.tres",
	"hammertoe": "res://data/weapons/toe_jam.tres",
	"kandykane": "res://data/weapons/molotov.tres",
	"mrghastly": "res://data/weapons/scythe.tres",
	"razorback": "res://data/weapons/red_glare.tres",
	"smoky": "res://data/weapons/taser.tres",
	"splatcat": "res://data/weapons/splat_effect.tres",
}

const TERRAIN_NAMES := ["road", "grass", "snow", "dirt", "ice", "water"]
const TERRAIN_FIELDS := ["accel", "top", "grip", "steer", "dash_damage"]

func _init() -> void:
	var f := FileAccess.open("res://assets/data/roster.json", FileAccess.READ)
	if f == null:
		push_error("import_roster: roster.json not found")
		quit()
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY or not data.has("characters"):
		push_error("import_roster: malformed roster.json")
		quit()
		return
	var profile_errors := PackedStringArray()
	for c in data["characters"]:
		var car_id := String(c.get("id", "?"))
		for issue in terrain_profile_errors(c.get("terrain_modifiers", {})):
			profile_errors.append("%s: %s" % [car_id, issue])
	if not profile_errors.is_empty():
		for issue in profile_errors:
			printerr("import_roster: " + issue)
		quit(1)
		return

	var count := 0
	for c in data["characters"]:
		var vs := VehicleStats.new()
		vs.id = StringName(c.get("id", ""))
		vs.car_name = c.get("car_name", "")
		vs.driver_name = c.get("driver_name", "")
		vs.flavor = c.get("flavor", "")

		var sw: String = c.get("special_weapon", "")
		var colon := sw.find(":")
		if colon > 0:
			vs.special_name = sw.substr(0, colon).strip_edges()
			vs.special_desc = sw.substr(colon + 1).strip_edges()
		else:
			vs.special_desc = sw

		var st: Dictionary = c.get("stats", {})
		vs.acceleration = int(st.get("acceleration", 5))
		vs.top_speed = int(st.get("top_speed", 5))
		vs.handling = int(st.get("handling", 5))
		vs.armor = int(st.get("armor", 5))
		vs.special_power = int(st.get("special_power", 5))

		var cols: Dictionary = c.get("colors", {})
		vs.primary_color = Color(cols.get("primary", "#cccccc"))
		vs.accent_color = Color(cols.get("accent", "#ffffff"))

		vs.special_ammo_cap = int(c.get("special_ammo_cap", 1))
		vs.special_recharge_seconds = float(c.get("special_recharge_seconds", 12.0))
		vs.mass = int(c.get("mass", 5))
		vs.terrain_modifiers = build_terrain_modifiers(c.get("terrain_modifiers", {}))

		var sid := String(c.get("id", ""))
		if SPECIALS.has(sid):
			vs.special = load(SPECIALS[sid])

		var path := "res://data/vehicles/%s.tres" % c.get("id", "unknown")
		var err := ResourceSaver.save(vs, path)
		print("import_roster: %s -> err %d" % [path, err])
		count += 1

	print("import_roster: wrote %d vehicles" % count)
	quit()

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
