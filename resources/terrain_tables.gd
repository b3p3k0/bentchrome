extends RefCounted
## Shared terrain-table vocabulary and composition statics — the single home
## for surface/property names, validation, profile merging, and typed-resource
## construction. Consumers: tools/import_roster.gd (roster import, via thin
## delegating wrappers), VehicleLoadout (garage tire overlays), and
## GarageCatalog (catalog validation). No class_name — preload by path.

const TERRAIN_NAMES := ["road", "grass", "snow", "dirt", "mud", "ice", "water"]
const TERRAIN_FIELDS := ["accel", "top", "grip", "steer", "dash_damage"]

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

## Composes the car's effective terrain table: the named shared profile (if
## any) first, then the car's inline terrain_modifiers overlaid per surface
## and property — inline always wins. Same seam the garage tire overlay uses.
static func merged_terrain(c: Dictionary, profiles: Dictionary) -> Dictionary:
	var out := {}
	var pname := String(c.get("terrain_profile", ""))
	if not pname.is_empty() and profiles.has(pname):
		for surface_v in profiles[pname]:
			out[surface_v] = (profiles[pname][surface_v] as Dictionary).duplicate()
	for surface_v in c.get("terrain_modifiers", {}):
		var over: Dictionary = c["terrain_modifiers"][surface_v]
		var dst: Dictionary = out.get(surface_v, {})
		for property_v in over:
			dst[property_v] = over[property_v]
		out[surface_v] = dst
	return out

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

## Per-property overlay over an already-typed modifier table (garage tires):
## where the overlay speaks, its factor replaces the existing one; everything
## it stays silent on keeps the car's authored identity (Cricket's dirt
## dash_damage survives a dirt-grip patch). Patched entries are duplicated —
## the inputs may be shipped .tres resources and must NEVER mutate; untouched
## entries ride by reference. Overlay-only surfaces join as fresh modifiers.
static func overlay_modifiers(existing: Array[VehicleTerrainModifier],
		overlay: Dictionary) -> Array[VehicleTerrainModifier]:
	var out: Array[VehicleTerrainModifier] = []
	var patched := {}
	for m in existing:
		if m == null:
			continue
		var key := String(m.terrain)
		if overlay.has(key):
			var copy := m.duplicate() as VehicleTerrainModifier
			for property_v in overlay[key]:
				copy.set(String(property_v), float(overlay[key][property_v]))
			patched[key] = true
			out.append(copy)
		else:
			out.append(m)
	for surface_v in overlay:
		if not patched.has(String(surface_v)):
			out.append_array(build_terrain_modifiers({surface_v: overlay[surface_v]}))
	return out
