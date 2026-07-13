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

## The ruleset in plain language — three sentences (mode, format, bench) for
## the lobby's THE DEAL block. Pure and unit-tested so the wording can't rot.
static func describe(cfg: Dictionary, map_name: String, tier_name: String) -> Array[String]:
	var lines: Array[String] = []
	if StringName(String(cfg.get("mode", &"melee"))) == &"grudge":
		lines.append("Humans only on %s — settle it among yourselves." % map_name)
	else:
		lines.append("Free-for-all on %s — empty seats fill with AI drivers (%s)."
			% [map_name, tier_name])
	match StringName(String(cfg.get("format", &"brawl"))):
		&"brawl":
			var frag_cap := int(cfg.get("brawl_frag_cap", 0))
			var time_cap := int(cfg.get("brawl_time_cap", 0))
			if frag_cap > 0 and time_cap > 0:
				lines.append("Rolling brawl to %d wrecks or %d minutes — whichever lands first."
					% [frag_cap, time_cap / 60])
			elif frag_cap > 0:
				lines.append("Rolling brawl to %d wrecks." % frag_cap)
			elif time_cap > 0:
				lines.append("Rolling brawl on a %d-minute clock." % (time_cap / 60))
			else:
				lines.append("Rolling brawl, no finish line — the host calls time.")
		&"frag":
			lines.append("First driver to %d wrecks takes it." % int(cfg.get("frag_target", 10)))
		&"timed":
			lines.append("%d minutes on the clock — most wrecks wins; ties share the crown."
				% (int(cfg.get("time_limit", 300)) / 60))
		&"lives":
			lines.append("Everyone gets %d lives; run dry and you're benched. Last one rolling wins."
				% int(cfg.get("lives", 3)))
	if not bool(cfg.get("observers", true)):
		lines.append("Seats only — no spectators this time.")
	elif bool(cfg.get("gotnext", true)):
		lines.append("Death rotates: whoever called NEXT takes the open wheel.")
	else:
		lines.append("Spectators welcome; seats hold until someone leaves.")
	return lines

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
