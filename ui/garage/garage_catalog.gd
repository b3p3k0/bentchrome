extends RefCounted
## Loader/validator for assets/data/garage_catalog.json — the roster-importer
## philosophy: unknown categories, dead prerequisite ids, bad prices, or
## deltas naming stats VehicleLoadout can't move all fail LOUDLY instead of
## becoming dead data. Pure static; the shop and tests are the consumers.

const PATH := "res://assets/data/garage_catalog.json"
const CATEGORIES := ["ENGINE", "SUSPENSION", "WEAPONS", "CPU", "ARMOR"]

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
		var deltas: Variant = item.get("stat_deltas", {})
		if typeof(deltas) != TYPE_DICTIONARY:
			errors.append("%s: stat_deltas must be an object" % id)
		else:
			for stat_v in deltas:
				if String(stat_v) not in VehicleLoadout.STAT_FIELDS:
					errors.append("%s: stat_deltas names unknown stat '%s'" % [id, stat_v])
				elif float(deltas[stat_v]) != floorf(float(deltas[stat_v])):
					errors.append("%s: stat delta '%s' must be an integer" % [id, stat_v])
	# prerequisite ids resolve (second pass — forward references are fine)
	for item in data["items"]:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var req := String(item.get("requires", ""))
		if not req.is_empty() and not ids.has(req):
			errors.append("%s: requires unknown item '%s'" % [item.get("id"), req])
	return errors

## The mod dict VehicleLoadout.compose consumes, from a catalog item.
static func as_mod(item: Dictionary) -> Dictionary:
	return {
		"id": item.get("id", ""),
		"stat_deltas": item.get("stat_deltas", {}),
		"capabilities": item.get("capabilities", {}),
		"reserved": item.get("reserved", {}),
	}
