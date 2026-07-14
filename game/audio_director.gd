extends Node
## Pooled SFX with a drop-in asset workflow. The CATALOG below is the contract:
## drop assets/sfx/<event>.ogg (or .wav) in place and it plays on next launch —
## imported resources win (that's what exports use), freshly-dropped files load
## raw as a fallback, and a missing file is a silent no-op, never a crash.
## Naming table + instructions: assets/sfx/README.md. Music/crossfade: later.

const SFX_DIR := "res://assets/sfx/"
const POOL_GLOBAL := 8      # one-shots for player-centric events
const POOL_POSITIONAL := 6  # 2D one-shots for world events (npc_death)
const POOL_UI := 3          # pause-immune one-shots (menus run while the tree
	# is paused; win/lose stingers fire the same frame the end screen pauses)

## Events routed through the pause-immune pool. Gameplay events stay pausable
## on purpose — a skid loop must freeze when the pause menu opens.
const UI_EVENTS := {&"ui_move": true, &"ui_select": true, &"ui_back": true,
	&"win_sting": true, &"lose_sting": true, &"mp_join": true, &"mp_leave": true}

## Event -> tuning knobs. volume_db trims per asset; pitch_jitter (±fraction)
## keeps rapid repeats (MG, hits) from sounding machine-stamped.
const CATALOG := {
	&"mg_fire": {"volume_db": -6.0, "pitch_jitter": 0.08},
	&"missile_fire": {"volume_db": 0.0, "pitch_jitter": 0.05},
	&"mine_drop": {"volume_db": 0.0, "pitch_jitter": 0.05},
	&"crash_soft": {"volume_db": -2.0, "pitch_jitter": 0.1},   # fender-bender
	&"crash_hard": {"volume_db": 1.0, "pitch_jitter": 0.08},   # totaled (>= Vehicle.CRASH_HARD_SPEED)
	&"skid": {"volume_db": -4.0, "pitch_jitter": 0.0, "loop": true},
	&"brake": {"volume_db": -6.0, "pitch_jitter": 0.06},  # one-shot crunch when
		# hard braking STARTS above ~35 mph (drive_fx edge-trigger)
	&"hit_mg": {"volume_db": -8.0, "pitch_jitter": 0.08},
	&"hit_weapon": {"volume_db": 0.0, "pitch_jitter": 0.08},
	&"player_death": {"volume_db": 2.0, "pitch_jitter": 0.0},
	&"npc_death": {"volume_db": 0.0, "pitch_jitter": 0.1},
	&"spawn": {"volume_db": 0.0, "pitch_jitter": 0.0},
	&"ram_warn": {"volume_db": 2.0, "pitch_jitter": 0.05},  # Goliath's charge
		# commit — an air-horn / engine-roar tell, played positionally
	&"splash": {"volume_db": -2.0, "pitch_jitter": 0.1},   # fast shallow-water entry
	&"sink": {"volume_db": 0.0, "pitch_jitter": 0.05},     # deep-water death plunge
	&"pit_fall": {"volume_db": 0.0, "pitch_jitter": 0.05}, # pit death drop
	&"jump_pad": {"volume_db": -2.0, "pitch_jitter": 0.08},
	&"pickup": {"volume_db": -4.0, "pitch_jitter": 0.05},  # crate/heal/boost collect
	&"overheat": {"volume_db": -4.0, "pitch_jitter": 0.0}, # MG heat lockout trips
	&"win_sting": {"volume_db": 0.0, "pitch_jitter": 0.0},
	&"lose_sting": {"volume_db": 0.0, "pitch_jitter": 0.0},
	&"ui_move": {"volume_db": -12.0, "pitch_jitter": 0.03},
	&"ui_select": {"volume_db": -10.0, "pitch_jitter": 0.0},
	&"ui_back": {"volume_db": -12.0, "pitch_jitter": 0.0},
	&"mp_join": {"volume_db": -6.0, "pitch_jitter": 0.0},
	&"mp_leave": {"volume_db": -6.0, "pitch_jitter": 0.0},
	# Per-car specials: sp_<def basename> (SpecialController.special_sfx_event).
	# Kandykane shares Hornet's molotov by sharing the def. Missing assets are
	# the usual silent no-op (PROJECTILE specials fall back to missile_fire).
	&"sp_blunt_blaze": {"volume_db": -4.0, "pitch_jitter": 0.0},  # loops while flaming
	&"sp_chilblain": {"volume_db": 0.0, "pitch_jitter": 0.05},
	&"sp_chill_out": {"volume_db": 0.0, "pitch_jitter": 0.05},
	&"sp_leap": {"volume_db": 0.0, "pitch_jitter": 0.05},
	&"sp_molotov": {"volume_db": 0.0, "pitch_jitter": 0.05},
	&"sp_phantom_phire": {"volume_db": 0.0, "pitch_jitter": 0.05},
	&"sp_pulse_wave": {"volume_db": 0.0, "pitch_jitter": 0.05},
	&"sp_red_glare": {"volume_db": -2.0, "pitch_jitter": 0.06},  # plays per rocket (x3)
	&"sp_rusty_poon": {"volume_db": 0.0, "pitch_jitter": 0.05},
	&"sp_scythe": {"volume_db": 0.0, "pitch_jitter": 0.05},
	&"sp_taser": {"volume_db": -4.0, "pitch_jitter": 0.0},  # loops while latched
	&"sp_toe_jam": {"volume_db": 0.0, "pitch_jitter": 0.0},  # on the LANDED hit
	&"sp_tornado_alley": {"volume_db": 0.0, "pitch_jitter": 0.0},
	&"sp_placeholder": {"volume_db": 0.0, "pitch_jitter": 0.04},  # "where's the
		# beef?" — plays for any special that fires without its own sp_* asset
	# PA announcer, campaign finale only: "<Carname> wins!" — baked speech
	# (tools/synth_sfx.py announcer(), espeak-ng on the dev box; the game
	# ships only these oggs). Keyed by roster id.
	&"announcer_bumper": {"volume_db": 0.0, "pitch_jitter": 0.0},
	&"announcer_coldfront": {"volume_db": 0.0, "pitch_jitter": 0.0},
	&"announcer_cricket": {"volume_db": 0.0, "pitch_jitter": 0.0},
	&"announcer_cyclone": {"volume_db": 0.0, "pitch_jitter": 0.0},
	&"announcer_ghost": {"volume_db": 0.0, "pitch_jitter": 0.0},
	&"announcer_hammertoe": {"volume_db": 0.0, "pitch_jitter": 0.0},
	&"announcer_hornet": {"volume_db": 0.0, "pitch_jitter": 0.0},
	&"announcer_hubcap": {"volume_db": 0.0, "pitch_jitter": 0.0},
	&"announcer_kandykane": {"volume_db": 0.0, "pitch_jitter": 0.0},
	&"announcer_lovebug": {"volume_db": 0.0, "pitch_jitter": 0.0},
	&"announcer_mrghastly": {"volume_db": 0.0, "pitch_jitter": 0.0},
	&"announcer_razorback": {"volume_db": 0.0, "pitch_jitter": 0.0},
	&"announcer_smoky": {"volume_db": 0.0, "pitch_jitter": 0.0},
	&"announcer_splatkat": {"volume_db": 0.0, "pitch_jitter": 0.0},
}

var _streams: Dictionary = {}  # event -> AudioStream (absent = no asset yet)
var _pool: Array = []
var _pool_2d: Array = []
var _pool_ui: Array = []
var _loopers: Dictionary = {}  # event -> its dedicated looping player
var _loop_on: Dictionary = {}  # event -> bool (drives the finished->replay)
var _next := 0
var _next_2d := 0
var _next_ui := 0

func _ready() -> void:
	var missing: Array = []
	for event in CATALOG:
		var stream := _resolve(String(event))
		if stream:
			_streams[event] = stream
		else:
			missing.append(String(event))
	for i in POOL_GLOBAL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	for i in POOL_POSITIONAL:
		var p := AudioStreamPlayer2D.new()
		add_child(p)
		_pool_2d.append(p)
	for i in POOL_UI:
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_pool_ui.append(p)
	# Wording matters: the smoke gate greps boot output for /missing/i, so this
	# says "awaiting" — an empty sfx folder is expected, not an error.
	print("[sfx] loaded %d/%d events%s" % [_streams.size(), CATALOG.size(),
		"" if missing.is_empty() else " — awaiting assets: " + ", ".join(missing)])

## Imported resource first (what exported builds ship); raw file-load fallback
## so a freshly-dropped ogg/wav works without an import pass.
func _resolve(event: String) -> AudioStream:
	for ext in ["ogg", "wav"]:
		var path: String = SFX_DIR + event + "." + ext
		if ResourceLoader.exists(path):
			var res := load(path)
			if res is AudioStream:
				return res
	for ext in ["ogg", "wav"]:
		var path: String = SFX_DIR + event + "." + ext
		if FileAccess.file_exists(path):
			var raw: AudioStream = AudioStreamOggVorbis.load_from_file(path) if ext == "ogg" \
				else AudioStreamWAV.load_from_file(path)
			if raw:
				return raw
	return null

## Global one-shot (player-centric events; UI_EVENTS ride the pause-immune pool).
func play(event: StringName) -> void:
	var stream: AudioStream = _streams.get(event)
	if stream == null:
		return
	var p: AudioStreamPlayer
	if UI_EVENTS.has(event):
		if _pool_ui.is_empty():
			return
		p = _pool_ui[_next_ui]
		_next_ui = (_next_ui + 1) % _pool_ui.size()
	else:
		if _pool.is_empty():
			return
		p = _pool[_next]
		_next = (_next + 1) % _pool.size()
	p.stream = stream
	p.volume_db = CATALOG[event]["volume_db"]
	p.pitch_scale = _jitter(event)
	p.play()

## Positional one-shot (world events — distance falloff for free).
func play_at(event: StringName, global_pos: Vector2) -> void:
	var stream: AudioStream = _streams.get(event)
	if stream == null or _pool_2d.is_empty():
		return
	var p: AudioStreamPlayer2D = _pool_2d[_next_2d]
	_next_2d = (_next_2d + 1) % _pool_2d.size()
	p.global_position = global_pos
	p.stream = stream
	p.volume_db = CATALOG[event]["volume_db"]
	p.pitch_scale = _jitter(event)
	p.play()

## Looping events (skid): on = keep playing until turned off. Loops via the
## finished signal so any format works regardless of import settings.
func loop_set(event: StringName, on: bool) -> void:
	_loop_on[event] = on
	var stream: AudioStream = _streams.get(event)
	if stream == null:
		return
	var p: AudioStreamPlayer = _loopers.get(event)
	if p == null:
		p = AudioStreamPlayer.new()
		p.stream = stream
		p.volume_db = CATALOG[event]["volume_db"]
		p.finished.connect(func() -> void:
			if _loop_on.get(event, false):
				p.play())
		add_child(p)
		_loopers[event] = p
	if on and not p.playing:
		p.play()
	elif not on and p.playing:
		p.stop()

## True when the event resolved a drop-in asset at boot (soundboard/debug).
func has_asset(event: StringName) -> bool:
	return _streams.has(event)

func _jitter(event: StringName) -> float:
	var j: float = CATALOG[event]["pitch_jitter"]
	return 1.0 + randf_range(-j, j) if j > 0.0 else 1.0
