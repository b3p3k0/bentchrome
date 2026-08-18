extends Node
## Global run/session state: selected vehicle, level progress, persistent
## HP/ammo/score. Pure data + signals; survives scene changes.
## Fields fill in as later phases need them.

signal vehicle_selected(vehicle_id: StringName)
signal level_changed(level_index: int)

const Economy := preload("res://game/economy.gd")

var selected_vehicle_id: StringName = &""
var level_index: int = 0
var lives: int = 3  # campaign lives; reset at car select, spent by levels
var score: int = 0
# Garage build (item ids from assets/data/garage_catalog.json). Run state like
# lives: bought at PIT STOPs, applied at level spawn via VehicleLoadout.compose,
# never persisted.
var owned_mods: Array = []
# Campaign rack carry (WeaponRack.Slot order, 7 ints; empty = no carry).
# Captured at the end screen's continue funnel, applied at the next level's
# first player spawn (death respawns reset to the defined load instead).
# Run state like lives: overwritten at each win, never persisted.
var carry_ammo: Array = []
# SP lane picked on the mode-select screen: &"campaign" (Road Trip),
# &"tutorial" (Driver's Ed lessons), &"test_drive" (same yard, free roam), or
# &"single_battle" (one arena off the fight card, no tour).
# Run state, never persisted; mode select re-stamps it on every confirm.
var game_mode: StringName = &"campaign"
# SINGLE BATTLE: the campaign slot picked on the level-select screen. Run
# state like game_mode — car select launches into it when the lane says so.
var battle_level_index: int = 0

func reset_campaign() -> void:
	level_index = 0
	lives = 3
	owned_mods.clear()
	carry_ammo.clear()
	Economy.reset_run()  # fresh run, empty wallet — BOLTS are the tournament's

# Custom-level flow (levels/custom_level.tscn). The editor's playtest sets all
# three; a plain "--level=" debug launch uses none.
var pending_level_path: String = ""
var playtest_return_to_editor: bool = false
var editor_open_path: String = ""

# Player settings (exposed by ui/settings.gd; persisted to user://settings.json;
# they survive scene changes AND campaign resets, unlike run state).
const DEFAULT_COMBAT_ZOOM := 0.55
const DEFAULT_OVERVIEW_ZOOM := 0.42
const DEFAULT_CAMERA_LOOK_AHEAD_DISTANCE := 140.0
var zoom_combat := DEFAULT_COMBAT_ZOOM  # settings: COMBAT ZOOM 0.45-0.72
var zoom_overview := DEFAULT_OVERVIEW_ZOOM  # toggled tactical pull-back
var overview := false       # G/Y toggle; persisted across levels and launches
var camera_look_ahead_enabled := true
var camera_look_ahead_distance := DEFAULT_CAMERA_LOOK_AHEAD_DISTANCE
var devgod := false        # invincible, 1x every weapon, firing never depletes
var dev_mode := false      # dev tooling (F1 dashboard; Stage-2 tuning editor)
var screen_shake := true   # accessibility: gates Vehicle.add_shake
var player_name := ""      # LAN identity; empty = derived from the car's driver bio
var volume_master := 0.80  # settings sliders, 0-1 linear; applied to the
var volume_music := 0.30   # Master/Music/SFX buses via apply_audio_settings()
var volume_sfx := 0.55

# MP screen memory: last host entry + garage prefs, so a LAN night doesn't
# start with retyping. Passwords deliberately NEVER persist (plain-text file).
var mp_join_ip := ""
var mp_join_port := 0      # 0 = the protocol default
var mp_host_port := 0      # 0 = the protocol default
var mp_host_garage := ""
var mp_host_strict := false

## Developer Mode is the master breaker. The raw subordinate choices stay
## persisted so switching the breaker back on restores the developer's bench.
## DEVGOD stands down during Driver's Ed LESSONS (same policy as MP): the
## syllabus grades real actions, and god mode makes them uncompletable —
## no ammo depletion means the bay-fire latch can never land, no damage
## means there's nothing to repair. Test drives keep it: that's the bench.
func is_devgod_enabled() -> bool:
	return dev_mode and devgod and game_mode != &"tutorial"

const SETTINGS_PATH := "user://settings.json"
const SETTINGS_SCHEMA_VERSION := 3
const LEGACY_DEFAULT_COMBAT_ZOOM := 0.58
const SCHEMA2_DEFAULT_COMBAT_ZOOM := 0.66
# start_level_index (the retired dev START LEVEL picker) may linger in old
# files — unknown keys load as no-ops, so stale settings degrade silently.
const SETTINGS_KEYS := ["zoom_combat", "zoom_overview", "overview",
	"camera_look_ahead_enabled", "camera_look_ahead_distance", "devgod",
	"dev_mode", "screen_shake", "player_name",
	"volume_master", "volume_music", "volume_sfx",
	"mp_join_ip", "mp_join_port", "mp_host_port", "mp_host_garage",
	"mp_host_strict"]

func _ready() -> void:
	# Headless runs (test/smoke gates) stay hermetic: Kevin's real settings —
	# devgod especially — must never leak into fixtures. Explicit
	# load_settings(path) calls in tests still work.
	if DisplayServer.get_name() != "headless":
		load_settings()

## Settings only — run state (lives, level_index, score) never touches disk.
func save_settings(path := SETTINGS_PATH) -> void:
	var out := {"schema_version": SETTINGS_SCHEMA_VERSION}
	for k in SETTINGS_KEYS:
		out[k] = get(k)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out, "\t"))
		f.close()

func load_settings(path := SETTINGS_PATH) -> void:
	if not FileAccess.file_exists(path):
		return
	# Instance parse: bad/hand-edited files degrade silently to defaults
	# (JSON.parse_string prints an engine ERROR that would trip the gates).
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return
	var schema := int(data.get("schema_version", 0))
	for k in SETTINGS_KEYS:
		if data.has(k) and typeof(data[k]) == typeof(get(k)):
			set(k, data[k])
		elif data.has(k) and get(k) is float and data[k] is int:
			set(k, float(data[k]))  # JSON round numbers come back as ints
		elif data.has(k) and get(k) is int and data[k] is float:
			set(k, int(data[k]))
	# Each shipped stock close-up advances once; hand-tuned values remain theirs.
	# Schema 2 deliberately omitted overview state and look-ahead controls, so
	# supply their new defaults only when the fields are genuinely absent.
	if schema < SETTINGS_SCHEMA_VERSION:
		if data.has("zoom_combat"):
			if schema < 2 and zoom_combat == LEGACY_DEFAULT_COMBAT_ZOOM:
				zoom_combat = DEFAULT_COMBAT_ZOOM
			elif schema == 2 and zoom_combat == SCHEMA2_DEFAULT_COMBAT_ZOOM:
				zoom_combat = DEFAULT_COMBAT_ZOOM
		if not data.has("overview"):
			overview = false
		if not data.has("camera_look_ahead_enabled"):
			camera_look_ahead_enabled = true
		if not data.has("camera_look_ahead_distance"):
			camera_look_ahead_distance = DEFAULT_CAMERA_LOOK_AHEAD_DISTANCE
		save_settings(path)
	apply_audio_settings()

## Gameplay toggle. Production presses save immediately; headless fixtures stay
## hermetic and explicitly round-trip through their throwaway paths instead.
func toggle_overview() -> void:
	overview = not overview
	if DisplayServer.get_name() != "headless":
		save_settings()

func reset_settings(path := SETTINGS_PATH) -> void:
	zoom_combat = DEFAULT_COMBAT_ZOOM
	zoom_overview = DEFAULT_OVERVIEW_ZOOM
	overview = false
	camera_look_ahead_enabled = true
	camera_look_ahead_distance = DEFAULT_CAMERA_LOOK_AHEAD_DISTANCE
	devgod = false
	dev_mode = false
	screen_shake = true
	player_name = ""
	mp_join_ip = ""
	mp_join_port = 0
	mp_host_port = 0
	mp_host_garage = ""
	mp_host_strict = false
	volume_master = 0.80
	volume_music = 0.30
	volume_sfx = 0.55
	apply_audio_settings()
	save_settings(path)

## Push the persisted sliders onto the audio buses (default_bus_layout.tres:
## Master + Music + SFX). Bus-less contexts (hermetic tests) no-op per bus.
func apply_audio_settings() -> void:
	_apply_bus(&"Master", volume_master)
	_apply_bus(&"Music", volume_music)
	_apply_bus(&"SFX", volume_sfx)

func _apply_bus(bus_name: StringName, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(idx, v <= 0.0)
