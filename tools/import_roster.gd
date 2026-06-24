extends SceneTree
## Headless importer: assets/data/roster.json -> data/vehicles/<id>.tres
## (one VehicleStats each). roster.json stays the single source of truth.
## Run: godot --headless --path . -s res://tools/import_roster.gd

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

		var path := "res://data/vehicles/%s.tres" % c.get("id", "unknown")
		var err := ResourceSaver.save(vs, path)
		print("import_roster: %s -> err %d" % [path, err])
		count += 1

	print("import_roster: wrote %d vehicles" % count)
	quit()
