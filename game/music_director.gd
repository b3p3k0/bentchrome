extends Node
## Background music with the same drop-in contract as AudioDirector: drop
## assets/bgm/<event>.ogg in place and it plays on the next launch — the name
## IS the wiring, a missing file is a silent no-op. Tracks are authored as
## seamless loops (tools/synth_bgm.py bakes the wrap-crossfade); this director
## stamps stream.loop and owns WHICH track plays: a per-frame poll of the
## current scene against TRACKS, two crossfading players, and a composed duck
## (tree pause is an implicit duck source — pause menu, frozen end screens,
## and the Goliath cutscene all dim the music for free). Table + instructions:
## assets/bgm/README.md.

const BGM_DIR := "res://assets/bgm/"
const CROSSFADE := 1.6        # scene-to-scene fade, seconds
const PHASE_CROSSFADE := 0.9  # in-level override (Goliath p1->p2): a gear change
const DUCK_DB := -10.0        # paused / end-screen dimming
const DUCK_RATE_DB := 40.0    # dB per second toward the duck target

## TRACKS sentinels: the interstitial plays the UPCOMING level's track (the
## loading card becomes the intro — same-event requests are no-ops, so the
## music rolls straight into the level), and mp_match resolves through its
## instanced arena CHILD so MP shares the SP table.
const UPCOMING := &"__upcoming__"
const RESOLVE_CHILD := &"__child__"

## Scene path -> track event. Unknown scenes fall back to bgm_menu.
const TRACKS := {
	"res://ui/title.tscn": &"bgm_menu",
	"res://ui/mode_select.tscn": &"bgm_menu",
	"res://ui/difficulty_select.tscn": &"bgm_menu",
	"res://ui/car_select.tscn": &"bgm_menu",
	"res://ui/settings.tscn": &"bgm_menu",
	"res://ui/mp_menu.tscn": &"bgm_menu",
	"res://ui/mp_lobby.tscn": &"bgm_menu",
	"res://ui/mp_scoreboard.tscn": &"bgm_menu",
	"res://levels/tutorial/drivers_ed.tscn": &"bgm_menu",
	"res://ui/interstitial.tscn": UPCOMING,
	"res://levels/arena_assault/arena_assault.tscn": &"bgm_arena",
	"res://levels/downtown/downtown.tscn": &"bgm_arena",
	"res://levels/freeway/freeway.tscn": &"bgm_freeway",
	"res://levels/suburbs/suburbs.tscn": &"bgm_suburbs",
	"res://levels/snowy/snowy.tscn": &"bgm_snowy",
	"res://levels/depot/depot.tscn": &"bgm_depot",
	"res://levels/chase/buzzard_run.tscn": &"bgm_buzzard_run",
	"res://levels/dock/dock.tscn": &"bgm_dock",
	"res://levels/construction/ground_floor_gore.tscn": &"bgm_ground_floor_gore",
	"res://levels/stadium/stadium.tscn": &"bgm_stadium_p1",  # p2 via set_override
	"res://levels/mp/mp_match.tscn": RESOLVE_CHILD,
	"res://levels/custom_level.tscn": &"bgm_arena",  # fan levels: house combat track
}

## Every asset name (bgm_stadium_p2 has no scene row — it arrives by override).
const TRACK_EVENTS: Array[StringName] = [&"bgm_menu", &"bgm_arena", &"bgm_freeway",
	&"bgm_suburbs", &"bgm_snowy", &"bgm_depot", &"bgm_buzzard_run", &"bgm_dock",
	&"bgm_ground_floor_gore", &"bgm_stadium_p1", &"bgm_stadium_p2"]

var _streams: Dictionary = {}  # event -> AudioStream (absent = no asset yet)
var _players: Array = []       # two crossfading AudioStreamPlayers
var _gain: Array = [0.0, 0.0]  # current linear fade weight per player
var _target: Array = [0.0, 0.0]
var _rate := 1.0 / CROSSFADE   # fade speed of the running crossfade
var _active := -1              # player index carrying _current, -1 = none
var _current := &""            # requested track (even while asset-less)
var _scene_track := &""        # what the scene table wants (override returns here)
var _override := &""           # in-level swap (Goliath p2, soundboard preview)
var _ducks: Dictionary = {}    # named duck sources (tree pause is implicit)
var _duck_db := 0.0
var _scene_id := 0             # instance id — catches reload_current_scene too
var _child_scan := false       # mp_match: resolving track through the arena child

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # music runs through tree pauses
	var missing: Array = []
	for event in TRACK_EVENTS:
		var stream := _resolve(String(event))
		if stream:
			_streams[event] = stream
		else:
			missing.append(String(event))
	for i in 2:
		var p := AudioStreamPlayer.new()
		# The Music bus when the layout is loaded, Master otherwise (hermetic
		# tests and bus-less contexts keep working without warnings).
		p.bus = &"Music" if AudioServer.get_bus_index(&"Music") >= 0 else &"Master"
		add_child(p)
		_players.append(p)
	# Same wording contract as AudioDirector: the smoke gate greps boot output
	# for /missing/i, so an empty bgm folder says "awaiting" — expected, no error.
	print("[bgm] loaded %d/%d tracks%s" % [_streams.size(), TRACK_EVENTS.size(),
		"" if missing.is_empty() else " — awaiting assets: " + ", ".join(missing)])

## Imported resource first (what exported builds ship); raw file-load fallback
## so a freshly-rendered ogg works without an import pass. Loop is stamped in
## code — the drop-in contract stays free of .import fiddling.
func _resolve(event: String) -> AudioStream:
	for ext in ["ogg", "wav"]:
		var path: String = BGM_DIR + event + "." + ext
		if ResourceLoader.exists(path):
			var res := load(path)
			if res is AudioStream:
				return _looped(res)
	for ext in ["ogg", "wav"]:
		var path: String = BGM_DIR + event + "." + ext
		if FileAccess.file_exists(path):
			var raw: AudioStream = AudioStreamOggVorbis.load_from_file(path) if ext == "ogg" \
				else AudioStreamWAV.load_from_file(path)
			if raw:
				return _looped(raw)
	return null

func _looped(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = stream.data.size() / 4  # 16-bit stereo frames
	return stream

func _process(delta: float) -> void:
	_poll_scene()
	if _child_scan:
		_resolve_child_track()
	_update(delta)

func _poll_scene() -> void:
	var cs := get_tree().current_scene
	if cs == null:  # mid-swap frame — hold the current track
		return
	if cs.get_instance_id() == _scene_id:  # instance id, not path — a reload
		return  # of the same scene must still clear in-level state below
	_scene_id = cs.get_instance_id()
	_scene_changed(cs.scene_file_path)

func _scene_changed(path: String) -> void:
	# New scene (or a reload): in-level state resets. Same-track requests below
	# are no-ops, so continuity (interstitial->level, restart) survives this.
	_ducks.clear()
	_override = &""
	_child_scan = false
	var want: StringName = TRACKS.get(path, &"bgm_menu")
	if want == RESOLVE_CHILD:
		_child_scan = true  # keep the lobby's menu track as the bridge
		return
	if want == UPCOMING:
		want = _upcoming_track()
		if want == &"":
			return  # can't resolve (headless / no campaign state) — hold
	_scene_track = want
	_request(want, CROSSFADE)

## The interstitial plays the NEXT level's track — end_screen already advanced
## GameState.level_index before to_interstitial().
func _upcoming_track() -> StringName:
	var gs := get_node_or_null(^"/root/GameState")
	var flow := get_node_or_null(^"/root/SceneFlow")
	if gs == null or flow == null:
		return &""
	var idx: int = clampi(gs.level_index, 0, flow.CAMPAIGN.size() - 1)
	# Placeholder slots are sceneless — their card plays the next real stop's
	# track (the finale is never a placeholder, so the walk always lands).
	while idx < flow.CAMPAIGN.size() - 1 and StringName(flow.CAMPAIGN[idx].mode) == &"placeholder":
		idx += 1
	var want: StringName = TRACKS.get(flow.CAMPAIGN[idx].scene, &"")
	return want if not want in [UPCOMING, RESOLVE_CHILD] else &""

## mp_match instances its arena as a direct child (the PackedScene keeps its
## path) — scan until a TRACKS hit lands, then play the same track SP would.
func _resolve_child_track() -> void:
	var cs := get_tree().current_scene
	if cs == null:
		return
	for child in cs.get_children():
		var want: StringName = TRACKS.get(child.scene_file_path, &"")
		if want != &"" and not want in [UPCOMING, RESOLVE_CHILD]:
			_child_scan = false
			_scene_track = want
			_request(want, CROSSFADE)
			return

## In-level track swap: Goliath's start_phase2 (bgm_stadium_p2) and the
## soundboard preview. Empty event returns to the scene's own track.
func set_override(event: StringName, xfade := PHASE_CROSSFADE) -> void:
	_override = event
	if event != &"":
		_request(event, xfade)
	elif _scene_track != &"":
		_request(_scene_track, CROSSFADE)

## Named duck sources compose with the implicit tree-pause duck. The one
## shipped caller: end_screen's rolling win (unpaused stadium victory lap).
func duck(tag: StringName, on: bool) -> void:
	if on:
		_ducks[tag] = true
	else:
		_ducks.erase(tag)

## True when the event resolved a drop-in asset at boot (soundboard/debug).
func has_asset(event: StringName) -> bool:
	return _streams.has(event)

func playing_event() -> StringName:
	return _current if _active >= 0 else &""

## Same event = no-op — the rule that gives interstitial->level, pause-Restart,
## and respawn continuity for free. Missing asset = fade to silence.
func _request(event: StringName, xfade: float) -> void:
	if event == _current:
		return
	_current = event
	_rate = 1.0 / maxf(xfade, 0.05)
	if _active >= 0:
		_target[_active] = 0.0
	var stream: AudioStream = _streams.get(event)
	if stream == null:
		_active = -1
		return
	var idx := 0 if _active != 0 else 1  # the free (or outgoing) player
	var p: AudioStreamPlayer = _players[idx]
	p.stream = stream
	p.play()
	_gain[idx] = 0.0
	_target[idx] = 1.0
	_active = idx

func _update(delta: float) -> void:
	var duck_target := DUCK_DB if (get_tree().paused or not _ducks.is_empty()) else 0.0
	_duck_db = move_toward(_duck_db, duck_target, DUCK_RATE_DB * delta)
	for i in _players.size():
		_gain[i] = move_toward(_gain[i], _target[i], _rate * delta)
		var p: AudioStreamPlayer = _players[i]
		if _gain[i] <= 0.0 and _target[i] <= 0.0:
			if p.playing:
				p.stop()  # never leave a muted looping decode alive
			continue
		p.volume_db = linear_to_db(maxf(_gain[i], 0.0001)) + _duck_db

## Quit etiquette: ogg playbacks release on the AudioServer's NEXT mix pass,
## so a same-frame quit reads as "leaked instances" at exit. SceneFlow's
## graceful quit calls this, waits one frame, then leaves.
func stop_all() -> void:
	for p in _players:
		if p is AudioStreamPlayer and p.playing:
			p.stop()
