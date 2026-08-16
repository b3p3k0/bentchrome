extends RefCounted
## Loader/validator for assets/data/garage_catalog.json — the roster-importer
## philosophy: unknown categories, dead prerequisite ids, bad prices, or
## deltas naming stats VehicleLoadout can't move all fail LOUDLY instead of
## becoming dead data. Pure static; the shop and tests are the consumers.

const Economy := preload("res://game/economy.gd")
const TerrainTables := preload("res://resources/terrain_tables.gd")

const PATH := "res://assets/data/garage_catalog.json"
const CATEGORIES := ["ENGINE", "SUSPENSION", "WEAPONS", "CPU", "ARMOR"]

## Every key an item may carry — anything else errors, which is what killed
## the old free-form `reserved` bag (typo'd axis names were invisible).
const ITEM_KEYS := ["id", "category", "display_name", "blurb", "tradeoff_text",
	"effect_text", "price", "requires", "exclusive_slot", "stat_deltas",
	"capabilities", "terrain_overlay", "controller_overrides"]
const SCALE_CAP_MIN := 0.1
const SCALE_CAP_MAX := 5.0

## Ordered category list drives the shop's tab order.
static func categories() -> Array:
	return CATEGORIES

## Returns the validated item array, or [] after push_error on any issue.
static func load_catalog(path := PATH) -> Array:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var errors := catalog_errors(data)
	if not errors.is_empty():
		for issue in errors:
			push_error("garage_catalog: " + issue)
		return []
	return data["items"]

static func catalog_errors(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("items")) != TYPE_ARRAY:
		errors.append("malformed catalog (need a dict with an 'items' array)")
		return errors
	var ids := {}
	for item in data["items"]:
		if typeof(item) != TYPE_DICTIONARY:
			errors.append("item entries must be objects")
			continue
		var id := String(item.get("id", ""))
		if id.is_empty():
			errors.append("item missing id")
			continue
		if ids.has(id):
			errors.append("%s: duplicate id" % id)
		ids[id] = true
		if String(item.get("category", "")) not in CATEGORIES:
			errors.append("%s: unknown category '%s'" % [id, item.get("category")])
		if String(item.get("display_name", "")).is_empty():
			errors.append("%s: missing display_name" % id)
		var price: Variant = item.get("price")
		if typeof(price) not in [TYPE_INT, TYPE_FLOAT] or int(price) <= 0 \
				or float(price) != floorf(float(price)):
			errors.append("%s: price must be a positive integer" % id)
		for key_v in item:
			if String(key_v) not in ITEM_KEYS:
				errors.append("%s: unknown key '%s' (the reserved bag is retired — wire it or drop it)"
					% [id, key_v])
		for copy_key in ["blurb", "tradeoff_text", "effect_text"]:
			if item.has(copy_key) and typeof(item[copy_key]) != TYPE_STRING:
				errors.append("%s: %s must be a string" % [id, copy_key])
		var deltas: Variant = item.get("stat_deltas", {})
		if typeof(deltas) != TYPE_DICTIONARY:
			errors.append("%s: stat_deltas must be an object" % id)
		else:
			for stat_v in deltas:
				if String(stat_v) not in VehicleLoadout.STAT_FIELDS:
					errors.append("%s: stat_deltas names unknown stat '%s'" % [id, stat_v])
				elif float(deltas[stat_v]) != floorf(float(deltas[stat_v])):
					errors.append("%s: stat delta '%s' must be an integer" % [id, stat_v])
		errors.append_array(_capability_errors(id, item.get("capabilities", {})))
		if item.has("terrain_overlay"):
			for issue in TerrainTables.terrain_profile_errors(item["terrain_overlay"]):
				errors.append("%s: %s" % [id, issue])
		var knobs: Variant = item.get("controller_overrides", {})
		if typeof(knobs) != TYPE_DICTIONARY:
			errors.append("%s: controller_overrides must be an object" % id)
		else:
			for knob_v in knobs:
				if typeof(knobs[knob_v]) not in [TYPE_INT, TYPE_FLOAT]:
					errors.append("%s: controller override '%s' must be a number" % [id, knob_v])
		# The meaningfulness rule: dead data can never ship again.
		if typeof(deltas) == TYPE_DICTIONARY and (deltas as Dictionary).is_empty() \
				and typeof(item.get("capabilities", {})) == TYPE_DICTIONARY \
				and (item.get("capabilities", {}) as Dictionary).is_empty() \
				and not item.has("terrain_overlay") and not item.has("controller_overrides"):
			errors.append("%s: item changes nothing (dead data)" % id)
	# prerequisite ids resolve (second pass — forward references are fine)
	for item in data["items"]:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var req := String(item.get("requires", ""))
		if not req.is_empty() and not ids.has(req):
			errors.append("%s: requires unknown item '%s'" % [item.get("id"), req])
	return errors

## Typed/ranged capability vocabulary (JSON numbers arrive as floats). special/
## special_b are Resource-valued — reachable from code-authored mods only, so
## the JSON catalog legally can't name them.
static func _capability_errors(id: String, caps: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if typeof(caps) != TYPE_DICTIONARY:
		errors.append("%s: capabilities must be an object" % id)
		return errors
	for key_v in caps:
		var key := String(key_v)
		var value: Variant = caps[key_v]
		var numeric := typeof(value) in [TYPE_INT, TYPE_FLOAT]
		if key in VehicleLoadout.SCALE_FIELDS:
			if not numeric or float(value) < SCALE_CAP_MIN or float(value) > SCALE_CAP_MAX:
				errors.append("%s: capability '%s' must be a number in [%s, %s]"
					% [id, key, SCALE_CAP_MIN, SCALE_CAP_MAX])
		elif key == "special_ammo_cap_bonus":
			if not numeric or float(value) != floorf(float(value)) or int(value) == 0:
				errors.append("%s: capability '%s' must be a nonzero integer" % [id, key])
		elif key == "special_ammo_cap":
			if not numeric or float(value) != floorf(float(value)) or int(value) < 1:
				errors.append("%s: capability '%s' must be an integer >= 1" % [id, key])
		elif key in ["burn_taken", "special_recharge_seconds"]:
			if not numeric or float(value) <= 0.0:
				errors.append("%s: capability '%s' must be a positive number" % [id, key])
		elif key == "no_mines":
			if typeof(value) != TYPE_BOOL:
				errors.append("%s: capability '%s' must be a bool" % [id, key])
		else:
			errors.append("%s: unknown capability '%s'" % [id, key])
	return errors

## Compose-ready mod list for a set of owned item ids (level-spawn helper).
static func mods_for(owned_ids: Array, items: Array = []) -> Array:
	if items.is_empty():
		items = load_catalog()
	var mods: Array = []
	for item in items:
		if String(item.id) in owned_ids:
			mods.append(as_mod(item))
	return mods

## The field keeps pace: one compose-ready mod giving rivals a fraction
## (Economy.RIVAL_KEEPUP) of the player's POSITIVE stat deltas — the player's
## tradeoffs are theirs alone. {} when the player is stock (or the fraction
## floors everything away).
static func rival_mod(owned_ids: Array, items: Array = []) -> Dictionary:
	if items.is_empty():
		items = load_catalog()
	var totals := {}
	for item in items:
		if String(item.id) not in owned_ids:
			continue
		for stat_v in item.get("stat_deltas", {}):
			var d := int(item.stat_deltas[stat_v])
			if d > 0:
				totals[stat_v] = int(totals.get(stat_v, 0)) + d
	var deltas := {}
	for stat_v in totals:
		var scaled := floori(int(totals[stat_v]) * Economy.RIVAL_KEEPUP)
		if scaled > 0:
			deltas[stat_v] = scaled
	return {} if deltas.is_empty() else {"id": "rival_keepup", "stat_deltas": deltas}

## The mod dict VehicleLoadout.compose consumes, from a catalog item — a dumb
## pass-through of every field compose reads. (An earlier hand-built version
## silently dropped terrain fields; enumerate compose's inputs, nothing else.)
static func as_mod(item: Dictionary) -> Dictionary:
	var mod := {"id": item.get("id", "")}
	for key in ["stat_deltas", "capabilities", "terrain_overlay",
			"terrain_profile", "controller_overrides"]:
		if item.has(key):
			mod[key] = item[key]
	return mod
