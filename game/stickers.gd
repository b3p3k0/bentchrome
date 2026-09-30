extends Node
## Persistent bumper-sticker achievements. Gameplay reports only sticker-sized
## facts here; catalog rules own the thresholds and roster-wide requirements.

signal unlocked_sticker(id: StringName)

const HitTags := preload("res://game/hit_tags.gd")
const Difficulty := preload("res://game/difficulty.gd")

const PROFILE_PATH := "user://stickers.json"
const CATALOG_PATH := "res://assets/data/stickers.json"
const ATTRIBUTION_MS := 10000
const SCHEMA_VERSION := 1
const ROSTER_PATH := "res://assets/data/roster.json"
const RULE_TYPES := [&"count", &"set_covers_roster", &"set_covers_specials"]

var counters: Dictionary = {}
var sets: Dictionary = {}
var unlocked: Dictionary = {}
var seen: Array = []
var roster_path := ROSTER_PATH:
	set(v):
		roster_path = v
		_required_cache.clear()

var _catalog_rows: Array = []
var _catalog_by_id: Dictionary = {}
var _fresh: Array[StringName] = []
var _profile_path := PROFILE_PATH
var _warned_events: Dictionary = {}
var _warned_rule_types: Dictionary = {}
var _required_cache: Dictionary = {}  # rule type -> Array[String]; roster is static at runtime


func _ready() -> void:
	# Headless tests explicitly inject their catalog/profile paths. Never let a
	# developer's real profile leak into a fixture.
	if DisplayServer.get_name() == "headless":
		return
	load_catalog()
	load_profile()


func can_earn() -> bool:
	var gs := get_node_or_null(^"/root/GameState")
	if gs == null:
		return false
	var mode := StringName(gs.get("game_mode"))
	if mode not in [&"campaign", &"single_battle"]:
		return false
	if _net_active():
		return false
	if String(gs.get("pending_level_path")) != "":
		return false
	return not _devgod_enabled(gs)


func record_kill(_victim: Node, hit_id: StringName) -> void:
	if not can_earn():
		return
	var changed := false
	for family in HitTags.families(hit_id):
		changed = _increment("kills.%s" % String(family)) or changed
	changed = _add_to_set("kill_ids", String(hit_id)) or changed
	_finish_mutation(changed)


func record_death(cause: StringName) -> void:
	if not can_earn():
		return
	var changed := _increment("deaths")
	if cause in [&"fall", &"drown", &"enemy_fire"]:
		changed = _increment("deaths.%s" % String(cause)) or changed
	_finish_mutation(changed)


func record_event(name: StringName, data: Dictionary = {}) -> void:
	match name:
		&"campaign_won":
			_record_campaign_won(data)
		&"tutorial_done":
			var gs := get_node_or_null(^"/root/GameState")
			if gs == null or StringName(gs.get("game_mode")) != &"tutorial" or _net_active():
				return
			_finish_mutation(_increment("tutorial_done"))
		&"splat":
			if can_earn():
				_finish_mutation(_increment("splats"))
		_:
			if not _warned_events.has(name):
				_warned_events[name] = true
				push_warning("Stickers: unknown event '%s'" % String(name))


func progress(id: StringName) -> Vector2i:
	var row: Variant = _catalog_by_id.get(String(id))
	if not row is Dictionary:
		return Vector2i.ZERO
	var rule: Variant = row.get("rule", {})
	if not rule is Dictionary:
		return Vector2i.ZERO
	var rule_type := StringName(rule.get("type", ""))
	var stat := String(rule.get("stat", ""))
	match rule_type:
		&"count":
			return Vector2i(int(counters.get(stat, 0)), int(rule.get("goal", 0)))
		&"set_covers_roster", &"set_covers_specials":
			var required := _required_values(rule_type)
			var values: Variant = sets.get(stat, [])
			var covered := 0
			if values is Array:
				for value in required:
					if value in values:
						covered += 1
			return Vector2i(covered, required.size())
		_:
			_warn_unknown_rule(rule_type)
			return Vector2i.ZERO


func is_unlocked(id: StringName) -> bool:
	return unlocked.has(String(id))


func catalog() -> Array:
	return _catalog_rows.duplicate(true)


func unseen() -> Array:
	var result: Array = []
	for row_v in _catalog_rows:
		if not row_v is Dictionary:
			continue
		var id := String(row_v.get("id", ""))
		if unlocked.has(id) and id not in seen:
			result.append(StringName(id))
	# Preserve unlocked ids from an older catalog instead of making them
	# impossible to acknowledge after content changes.
	for id_v in unlocked:
		var id := String(id_v)
		if not _catalog_by_id.has(id) and id not in seen:
			result.append(StringName(id))
	return result


func mark_seen() -> void:
	var changed := false
	for id_v in unlocked:
		var id := String(id_v)
		if id not in seen:
			seen.append(id)
			changed = true
	if changed:
		save_profile(_profile_path)


func drain_fresh() -> Array:
	var result: Array = _fresh.duplicate()
	_fresh.clear()
	return result


func reset_profile() -> void:
	counters.clear()
	sets.clear()
	unlocked.clear()
	seen.clear()
	_fresh.clear()
	save_profile(_profile_path)


func unlock_all() -> void:
	var now := int(Time.get_unix_time_from_system())
	var changed := false
	for row_v in _catalog_rows:
		if not row_v is Dictionary:
			continue
		var id := String(row_v.get("id", ""))
		if id.is_empty() or unlocked.has(id):
			continue
		unlocked[id] = now
		_fresh.append(StringName(id))
		unlocked_sticker.emit(StringName(id))
		changed = true
	if changed:
		save_profile(_profile_path)


func load_profile(path := PROFILE_PATH) -> void:
	_profile_path = path
	counters.clear()
	sets.clear()
	unlocked.clear()
	seen.clear()
	_fresh.clear()
	if not FileAccess.file_exists(path):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return
	var data: Variant = json.data
	if not data is Dictionary:
		return
	var loaded_counters: Variant = data.get("counters", {})
	if loaded_counters is Dictionary:
		for key in loaded_counters:
			var value: Variant = loaded_counters[key]
			if value is int or value is float:
				counters[String(key)] = int(value)
	var loaded_sets: Variant = data.get("sets", {})
	if loaded_sets is Dictionary:
		for key in loaded_sets:
			var values: Variant = loaded_sets[key]
			if not values is Array:
				continue
			var unique: Array = []
			for value in values:
				var text := String(value)
				if text not in unique:
					unique.append(text)
			sets[String(key)] = unique
	var loaded_unlocked: Variant = data.get("unlocked", {})
	if loaded_unlocked is Dictionary:
		for key in loaded_unlocked:
			var value: Variant = loaded_unlocked[key]
			if value is int or value is float:
				unlocked[String(key)] = int(value)
	var loaded_seen: Variant = data.get("seen", [])
	if loaded_seen is Array:
		for value in loaded_seen:
			var id := String(value)
			if id not in seen:
				seen.append(id)


func save_profile(path := PROFILE_PATH) -> void:
	var out := {
		"schema_version": SCHEMA_VERSION,
		"counters": counters,
		"sets": sets,
		"unlocked": unlocked,
		"seen": seen,
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(out, "\t"))
		file.close()


func load_catalog(path := CATALOG_PATH) -> void:
	_catalog_rows.clear()
	_catalog_by_id.clear()
	if not FileAccess.file_exists(path):
		push_error("Stickers catalog missing: %s" % path)
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_error("Stickers catalog JSON is invalid: %s" % path)
		return
	var data: Variant = json.data
	if not data is Dictionary or not data.get("stickers", []) is Array:
		push_error("Stickers catalog must contain a stickers array: %s" % path)
		return
	var ids: Dictionary = {}
	for row_v in data.get("stickers", []):
		if not row_v is Dictionary:
			push_error("Stickers catalog row is not an object")
			continue
		var row: Dictionary = row_v
		_catalog_rows.append(row.duplicate(true))
		var id := String(row.get("id", ""))
		if id.is_empty():
			push_error("Stickers catalog row is missing id")
		elif ids.has(id):
			push_error("Stickers catalog has duplicate id '%s'" % id)
		else:
			ids[id] = true
			_catalog_by_id[id] = _catalog_rows.back()
		if String(row.get("name", "")).strip_edges().is_empty():
			push_error("Sticker '%s' is missing name" % id)
		if String(row.get("blurb", "")).strip_edges().is_empty():
			push_error("Sticker '%s' is missing blurb" % id)
		var rule: Variant = row.get("rule", {})
		if not rule is Dictionary:
			push_error("Sticker '%s' is missing rule" % id)
			continue
		var rule_type := StringName(rule.get("type", ""))
		if rule_type not in RULE_TYPES:
			push_error("Sticker '%s' has unknown rule type '%s'" % [id, String(rule_type)])
		if String(rule.get("stat", "")).is_empty():
			push_error("Sticker '%s' rule is missing stat" % id)
		if rule_type == &"count" and int(rule.get("goal", 0)) <= 0:
			push_error("Sticker '%s' count goal must be positive" % id)


func _record_campaign_won(data: Dictionary) -> void:
	var gs := get_node_or_null(^"/root/GameState")
	if gs == null or StringName(gs.get("game_mode")) != &"campaign" \
			or _net_active() or _devgod_enabled(gs):
		return
	var changed := false
	match int(data.get("tier", -1)):
		Difficulty.Tier.HARD:
			changed = _increment("campaign_won.hard") or changed
			changed = _increment("campaign_won.medium") or changed
			changed = _increment("campaign_won.easy") or changed
		Difficulty.Tier.MEDIUM:
			changed = _increment("campaign_won.medium") or changed
			changed = _increment("campaign_won.easy") or changed
		Difficulty.Tier.EASY:
			changed = _increment("campaign_won.easy") or changed
		_:
			return
	changed = _add_to_set("campaign_cars", String(data.get("car", ""))) or changed
	_finish_mutation(changed)


func _finish_mutation(changed: bool) -> void:
	if not changed:
		return
	_evaluate()
	save_profile(_profile_path)


func _increment(stat: String) -> bool:
	counters[stat] = int(counters.get(stat, 0)) + 1
	return true


func _add_to_set(stat: String, value: String) -> bool:
	var values: Variant = sets.get(stat, [])
	if not values is Array:
		values = []
	if value in values:
		return false
	values.append(value)
	sets[stat] = values
	return true


func _evaluate() -> void:
	var now := int(Time.get_unix_time_from_system())
	for row_v in _catalog_rows:
		if not row_v is Dictionary:
			continue
		var id := String(row_v.get("id", ""))
		if id.is_empty() or unlocked.has(id):
			continue
		var rule: Variant = row_v.get("rule", {})
		if not rule is Dictionary or not _rule_met(rule):
			continue
		unlocked[id] = now
		_fresh.append(StringName(id))
		unlocked_sticker.emit(StringName(id))


func _rule_met(rule: Dictionary) -> bool:
	var rule_type := StringName(rule.get("type", ""))
	var stat := String(rule.get("stat", ""))
	match rule_type:
		&"count":
			return int(counters.get(stat, 0)) >= int(rule.get("goal", 0))
		&"set_covers_roster", &"set_covers_specials":
			var required := _required_values(rule_type)
			var values: Variant = sets.get(stat, [])
			if not values is Array:
				return false
			for value in required:
				if value not in values:
					return false
			return not required.is_empty()
		_:
			_warn_unknown_rule(rule_type)
			return false


func _required_values(rule_type: StringName) -> Array[String]:
	if _required_cache.has(rule_type):
		return _required_cache[rule_type]
	var required: Array[String] = []
	for character_v in _roster_characters():
		if not character_v is Dictionary:
			continue
		var character: Dictionary = character_v
		if rule_type == &"set_covers_roster":
			var car_id := String(character.get("id", ""))
			if not car_id.is_empty() and car_id not in required:
				required.append(car_id)
		else:
			var authored := String(character.get("special_def", ""))
			var special_id := authored.get_file().get_basename()
			var path := authored if authored.begins_with("res://") \
				else "res://data/weapons/%s.tres" % special_id
			if special_id.is_empty() or not ResourceLoader.exists(path):
				continue
			var def := ResourceLoader.load(path)
			if def != null and float(def.get("damage")) > 0.0 and special_id not in required:
				required.append(special_id)
	_required_cache[rule_type] = required
	return required


func _roster_characters() -> Array:
	if not FileAccess.file_exists(roster_path):
		return []
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(roster_path)) != OK:
		return []
	var data: Variant = json.data
	if not data is Dictionary:
		return []
	var characters: Variant = data.get("characters", [])
	return characters if characters is Array else []


func _net_active() -> bool:
	var net := get_node_or_null(^"/root/Net")
	return net != null and net.has_method(&"is_active") and bool(net.call(&"is_active"))


func _devgod_enabled(gs: Node) -> bool:
	return gs.has_method(&"is_devgod_enabled") and bool(gs.call(&"is_devgod_enabled"))


func _warn_unknown_rule(rule_type: StringName) -> void:
	if _warned_rule_types.has(rule_type):
		return
	_warned_rule_types[rule_type] = true
	push_warning("Stickers: unknown rule type '%s'" % String(rule_type))
