class_name MatchConfig
extends RefCounted
## The match ruleset: defaults, bounds, and the normalize() every host edit
## runs through before broadcast. Pure — no sockets, no tree. The lobby edits
## it, the MatchDirector (host, Batch 3) plays it.

const MODES: Array[StringName] = [&"grudge", &"melee"]
const FORMATS: Array[StringName] = [&"brawl", &"frag", &"timed", &"lives"]

const MODE_NAMES := {
	&"grudge": "GRUDGE MATCH",
	&"melee": "GRAND MELEE",
}
const FORMAT_NAMES := {
	&"brawl": "ROTATION BRAWL",
	&"frag": "FRAG TARGET",
	&"timed": "TIMED MATCH",
	&"lives": "LIVES ELIMINATION",
}

const ROSTER_PATH := "res://assets/data/roster.json"

static var _car_ids: Array = []
static var _car_names := {}

static func defaults() -> Dictionary:
	return {
		"map": 0,             # index into SceneFlow.MP_MAPS
		"mode": &"melee",
		"format": &"brawl",
		"frag_target": 10,    # FRAG: first to N
		"time_limit": 300,    # TIMED: seconds, bound 3-10 min
		"lives": 3,           # LIVES: per-seat tank
		"brawl_frag_cap": 0,  # BRAWL: optional first-to-N cap (0 = off)
		"brawl_time_cap": 0,  # BRAWL: optional time cap seconds (0 = off)
		"observers": true,    # OFF caps admissions at the 4 seats — no bench
		"gotnext": true,      # only meaningful with observers ON
		"difficulty": 2,      # Difficulty.Tier — HARD is the 1.0 baseline
	}

## Rebuilds a trusted config from an untrusted patch: whitelisted keys only,
## every value clamped, junk shapes fall back to defaults.
static func normalize(cfg: Dictionary, map_count: int) -> Dictionary:
	var out := defaults()
	var mode := StringName(String(cfg.get("mode", out.mode)))
	if MODES.has(mode):
		out.mode = mode
	var format := StringName(String(cfg.get("format", out.format)))
	if FORMATS.has(format):
		out.format = format
	out.map = clampi(int(cfg.get("map", out.map)), 0, maxi(map_count - 1, 0))
	out.frag_target = clampi(int(cfg.get("frag_target", out.frag_target)), 1, 50)
	out.time_limit = clampi(int(cfg.get("time_limit", out.time_limit)), 180, 600)
	out.lives = clampi(int(cfg.get("lives", out.lives)), 1, 9)
	out.brawl_frag_cap = clampi(int(cfg.get("brawl_frag_cap", 0)), 0, 50)
	var time_cap := int(cfg.get("brawl_time_cap", 0))
	out.brawl_time_cap = 0 if time_cap <= 0 else clampi(time_cap, 180, 1200)
	out.observers = bool(cfg.get("observers", out.observers))
	out.gotnext = bool(cfg.get("gotnext", out.gotnext))
	out.difficulty = clampi(int(cfg.get("difficulty", out.difficulty)), 0, 2)
	return out

## Roster car slugs, cached once (the queue and garage validate picks here).
static func car_ids() -> Array:
	_load_roster()
	return _car_ids

static func car_name(id: String) -> String:
	_load_roster()
	return String(_car_names.get(id, id.to_upper()))

static func _load_roster() -> void:
	if not _car_ids.is_empty():
		return
	var f := FileAccess.open(ROSTER_PATH, FileAccess.READ)
	if f == null:
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		return
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return
	for entry in data.get("characters", []):
		if typeof(entry) == TYPE_DICTIONARY and entry.has("id"):
			var id := String(entry.id)
			_car_ids.append(id)
			_car_names[id] = String(entry.get("car_name", id.to_upper()))
