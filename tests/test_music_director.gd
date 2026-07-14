extends RefCounted
## MusicDirector contracts: zero assets never crash (missing music can never
## take the game down); the TRACKS table covers every shipped flow; and the
## crossfade / duck / override state machines behave. Tests drive _update and
## _scene_changed by hand (set_process(false)) so no frames or audio device
## are needed.

const MusicScript := preload("res://game/music_director.gd")

var t
var flow: Node

func _init(runner) -> void:
	t = runner
	flow = runner.root.get_node("/root/SceneFlow")

func _fresh():
	var d = MusicScript.new()
	t.root.add_child(d)
	d.set_process(false)  # deterministic: tests call _update(delta) themselves
	return d

func _done(d) -> void:
	t.root.remove_child(d)
	d.free()

func _fake_stream() -> AudioStream:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = 44100
	s.data = PackedByteArray()
	s.data.resize(200)  # 100 silent frames — enough to be a playable stream
	return s

func test_zero_assets_never_crash() -> void:
	var d = _fresh()
	d._streams.clear()  # simulate an empty assets/bgm even after tracks ship
	for event in MusicScript.TRACK_EVENTS:
		d._request(event, 1.6)
		d._update(0.1)
	d._scene_changed("res://ui/title.tscn")
	d._scene_changed("res://not/a/real/scene.tscn")  # unknown -> menu fallback
	d.set_override(&"bgm_stadium_p2")
	d.set_override(&"")
	d.duck(&"pain", true)
	d._update(0.1)
	d.duck(&"pain", false)
	d._update(0.1)
	t.check(true, "bgm: full track set no-ops cleanly with zero assets")
	t.check(d.playing_event() == &"", "bgm: nothing reports playing without assets")
	_done(d)

func test_tracks_cover_flows() -> void:
	for entry in flow.CAMPAIGN:
		t.check(MusicScript.TRACKS.has(entry.scene),
			"bgm: campaign scene mapped: " + str(entry.scene))
	for entry in flow.MP_MAPS:
		t.check(MusicScript.TRACKS.has(entry.scene),
			"bgm: MP map mapped: " + str(entry.scene))
	for path in [flow.TITLE, flow.MODE_SELECT, flow.DIFFICULTY,
			flow.SELECT, flow.SETTINGS, flow.MP_MENU,
			flow.MP_LOBBY, flow.MP_SCOREBOARD, flow.TUTORIAL,
			flow.CUSTOM, flow.INTERSTITIAL, flow.MP_MATCH]:
		t.check(MusicScript.TRACKS.has(path), "bgm: flow scene mapped: " + path)
	for path in MusicScript.TRACKS:
		var want: StringName = MusicScript.TRACKS[path]
		if want in [MusicScript.UPCOMING, MusicScript.RESOLVE_CHILD]:
			continue
		t.check(String(want).begins_with("bgm_"),
			"bgm: track name shape: " + String(want))
		t.check(MusicScript.TRACK_EVENTS.has(want),
			"bgm: mapped track is a real asset name: " + String(want))
	t.check(MusicScript.TRACKS["res://levels/stadium/stadium.tscn"] == &"bgm_stadium_p1",
		"bgm: stadium opens on phase 1")
	t.check(MusicScript.TRACK_EVENTS.has(&"bgm_stadium_p2"),
		"bgm: phase 2 track exists in the asset name space")

func test_crossfade_state_machine() -> void:
	var d = _fresh()
	d._streams[&"bgm_a"] = _fake_stream()
	d._streams[&"bgm_b"] = _fake_stream()
	d._request(&"bgm_a", 1.0)
	t.check(d._active >= 0 and d._players[d._active].playing,
		"bgm: request starts the free player")
	var a_idx: int = d._active
	d._update(0.3)
	t.check(d._gain[a_idx] > 0.0 and d._gain[a_idx] < 1.0, "bgm: fade ramps in")
	var mid_gain: float = d._gain[a_idx]
	d._request(&"bgm_a", 1.0)  # the continuity rule
	t.check(d._active == a_idx and d._gain[a_idx] == mid_gain,
		"bgm: same-event request is a structural no-op")
	d._request(&"bgm_b", 1.0)
	t.check(d._active == 1 - a_idx, "bgm: new track takes the other player")
	t.check(d._target[a_idx] == 0.0 and d._target[d._active] == 1.0,
		"bgm: crossfade targets set")
	for i in 30:
		d._update(0.1)
	t.check(d._gain[a_idx] == 0.0 and not d._players[a_idx].playing,
		"bgm: faded-out player is stopped, not muted")
	t.check(d._gain[d._active] == 1.0, "bgm: incoming track lands at full")
	d._request(&"bgm_zzz", 1.0)  # no such asset
	t.check(d._active == -1, "bgm: missing asset fades to silence")
	for i in 30:
		d._update(0.1)
	t.check(not d._players[0].playing and not d._players[1].playing,
		"bgm: silence means both players stopped")
	_done(d)

func test_duck_and_override() -> void:
	var d = _fresh()
	d._streams[&"bgm_a"] = _fake_stream()
	d._streams[&"bgm_b"] = _fake_stream()
	d._scene_track = &"bgm_a"
	d._request(&"bgm_a", 0.1)
	for i in 5:
		d._update(0.1)
	d.duck(&"pain", true)
	for i in 20:
		d._update(0.1)
	t.check(is_equal_approx(d._duck_db, MusicScript.DUCK_DB),
		"bgm: named duck reaches DUCK_DB")
	d.duck(&"pain", false)
	for i in 20:
		d._update(0.1)
	t.check(is_equal_approx(d._duck_db, 0.0), "bgm: duck releases to unity")
	d.set_override(&"bgm_b")
	t.check(d._current == &"bgm_b", "bgm: override swaps the track")
	d.set_override(&"")
	t.check(d._current == &"bgm_a", "bgm: cleared override returns to the scene track")
	d.set_override(&"bgm_b")
	d.duck(&"pain", true)
	d._scene_changed("res://ui/title.tscn")
	t.check(d._override == &"" and d._ducks.is_empty(),
		"bgm: scene change clears override and ducks")
	t.check(d._current == &"bgm_menu", "bgm: unknown/menu scene requests bgm_menu")
	_done(d)
