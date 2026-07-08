extends Node
## Pooled SFX with a drop-in asset workflow. The CATALOG below is the contract:
## drop assets/sfx/<event>.ogg (or .wav) in place and it plays on next launch —
## imported resources win (that's what exports use), freshly-dropped files load
## raw as a fallback, and a missing file is a silent no-op, never a crash.
## Naming table + instructions: assets/sfx/README.md. Music/crossfade: later.

const SFX_DIR := "res://assets/sfx/"
const POOL_GLOBAL := 8      # one-shots for player-centric events
const POOL_POSITIONAL := 6  # 2D one-shots for world events (npc_death)

## Event -> tuning knobs. volume_db trims per asset; pitch_jitter (±fraction)
## keeps rapid repeats (MG, hits) from sounding machine-stamped.
const CATALOG := {
	&"mg_fire": {"volume_db": -6.0, "pitch_jitter": 0.08},
	&"missile_fire": {"volume_db": 0.0, "pitch_jitter": 0.05},
	&"mine_drop": {"volume_db": 0.0, "pitch_jitter": 0.05},
	&"crash": {"volume_db": 0.0, "pitch_jitter": 0.1},
	&"skid": {"volume_db": -4.0, "pitch_jitter": 0.0, "loop": true},
	&"hit_mg": {"volume_db": -8.0, "pitch_jitter": 0.08},
	&"hit_weapon": {"volume_db": 0.0, "pitch_jitter": 0.08},
	&"player_death": {"volume_db": 2.0, "pitch_jitter": 0.0},
	&"npc_death": {"volume_db": 0.0, "pitch_jitter": 0.1},
	&"spawn": {"volume_db": 0.0, "pitch_jitter": 0.0},
}

var _streams: Dictionary = {}  # event -> AudioStream (absent = no asset yet)
var _pool: Array = []
var _pool_2d: Array = []
var _loopers: Dictionary = {}  # event -> its dedicated looping player
var _loop_on: Dictionary = {}  # event -> bool (drives the finished->replay)
var _next := 0
var _next_2d := 0

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
	print("[sfx] loaded %d/%d events%s" % [_streams.size(), CATALOG.size(),
		"" if missing.is_empty() else " — missing: " + ", ".join(missing)])

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

## Global one-shot (player-centric events).
func play(event: StringName) -> void:
	var stream: AudioStream = _streams.get(event)
	if stream == null or _pool.is_empty():
		return
	var p: AudioStreamPlayer = _pool[_next]
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

func _jitter(event: StringName) -> float:
	var j: float = CATALOG[event]["pitch_jitter"]
	return 1.0 + randf_range(-j, j) if j > 0.0 else 1.0
