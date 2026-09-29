extends Control
## Boot sequence: the two parody startup cards, played once per launch ahead
## of the title — the white FONY publisher card, then the black FanStation
## card, crossing through black under one original sting. Art and sting are
## drop-in (assets/boot/ — contract in its README): a card without art falls
## back to its text lines on the matte, a sting without a file runs silent.
## Any key/button/click skips once INPUT_LOCK passes; Settings -> Graphics ->
## BOOT INTRO (GameState.boot_intro) turns the cards off for good. Headless
## runs hand straight to the title, so the smoke gate's boot stage still
## cold-boots it.

signal finished

const BOOT_DIR := "res://assets/boot/"
const STING := "boot_sting"
const FONY_BLUE := Color(0.05, 0.2, 0.62)
const WORDMARK_GREY := Color(0.62, 0.62, 0.64)

## The cards, in play order. `lines` is the fallback copy AND the letter-for-
## letter spec the art is reviewed against: [text, font size, color]; an empty
## text is a spacer where the emblem sits.
const CARDS := [
	{"art": "card_fony.png", "matte": Color.WHITE, "lines": [
		["FONY", 84, FONY_BLUE],
		["", 150, FONY_BLUE],
		["COMPUTER", 40, FONY_BLUE],
		["ENTERTAINMENT", 26, FONY_BLUE]]},
	{"art": "card_fanstation.png", "matte": Color.BLACK, "lines": [
		["", 170, Color.WHITE],
		["FanStation", 56, WORDMARK_GREY],
		["", 12, Color.WHITE],
		["not Licensed by Anyone", 22, Color.WHITE],
		["", 12, Color.WHITE],
		["IPACRAO", 22, Color.WHITE]]},
]

## Per-card curtain timing, cut to the sting: the publisher card rides the
## swell, the console card rides the chimes.
static var TIMING := [
	{"fade_in": 1.2, "hold": 4.8, "fade_out": 0.8},
	{"fade_in": 0.5, "hold": 5.4, "fade_out": 1.2},
]
static var LEAD_IN := 0.3      # black before the first card
static var GAP := 0.3          # black between cards
static var INPUT_LOCK := 0.5   # a launch keypress can't skip by accident
static var SKIP_FADE := 0.3    # curtain + sting fade on a skip
static var STING_DB := 0.0     # sting trim on top of the SFX bus slider
static var ART_FILTER := CanvasItem.TEXTURE_FILTER_LINEAR  # soft, not crunchy

var autoplay := true  # tests flip both off before add_child and drive the
var handoff := true   # steps by hand — the scene swap stays untested (house rule)

var _index := -1
var _armed := false
var _skipping := false
var _finished := false
var _tween: Tween
var _matte: ColorRect
var _art: TextureRect
var _fallback: VBoxContainer
var _curtain: ColorRect
var _player: AudioStreamPlayer

func _ready() -> void:
	_build()
	if not autoplay:
		return
	var gs := get_node_or_null(^"/root/GameState")
	if not wants_intro(DisplayServer.get_name() == "headless", gs == null or gs.boot_intro):
		_finish.call_deferred()  # deferred: the tree is still adding this scene
		return
	begin()

## Pure gate — the launch decides once whether the cards play at all.
static func wants_intro(headless: bool, enabled: bool) -> bool:
	return enabled and not headless

## Wall-clock length of an unskipped run; the sting is rendered to match.
static func total_duration() -> float:
	var total: float = LEAD_IN + GAP * float(maxi(TIMING.size() - 1, 0))
	for tm in TIMING:
		total += float(tm.fade_in) + float(tm.hold) + float(tm.fade_out)
	return total

func begin() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)  # goto_scene puts it back
	get_tree().create_timer(INPUT_LOCK).timeout.connect(_arm, CONNECT_ONE_SHOT)
	_play_sting()
	_tween = create_tween()
	_tween.tween_interval(LEAD_IN)
	for i in CARDS.size():
		var tm: Dictionary = TIMING[i]
		_tween.tween_callback(_show_card.bind(i))
		_tween.tween_property(_curtain, "modulate:a", 0.0, float(tm.fade_in))
		_tween.tween_interval(float(tm.hold))
		_tween.tween_property(_curtain, "modulate:a", 1.0, float(tm.fade_out))
		if i < CARDS.size() - 1:
			_tween.tween_interval(GAP)
	_tween.tween_callback(_finish)

func _arm() -> void:
	_armed = true

func _unhandled_input(event: InputEvent) -> void:
	if not _armed or _skipping or _finished:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if not pressed:
		return
	get_viewport().set_input_as_handled()  # the title never sees this press
	skip()

## Drop the curtain and the sting together, then hand off.
func skip() -> void:
	if _skipping or _finished:
		return
	_skipping = true
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_curtain, "modulate:a", 1.0, SKIP_FADE)
	if _player.playing:
		_tween.tween_property(_player, "volume_db", -60.0, SKIP_FADE)
	_tween.chain().tween_callback(_finish)

func _finish() -> void:
	if _finished:
		return
	_finished = true
	_player.stop()
	finished.emit()
	if not handoff:
		return
	# Autoload fetched by path: bare identifiers fail to compile when this
	# script rides a test's -s preload chain (house rule — see vehicle.gd).
	var flow := get_node_or_null(^"/root/SceneFlow")
	if flow:
		flow.to_title()

func _show_card(i: int) -> void:
	_index = i
	var card: Dictionary = CARDS[i]
	_matte.color = card.matte
	var tex := _art_for(card)
	_art.texture = tex
	_art.visible = tex != null
	_fallback.visible = tex == null
	for child in _fallback.get_children():
		_fallback.remove_child(child)
		child.queue_free()
	if tex:
		return
	for line in card.lines:
		var lbl := Label.new()
		lbl.text = line[0]
		lbl.add_theme_font_size_override("font_size", line[1])
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.modulate = line[2]
		_fallback.add_child(lbl)

## The card's art, or null while it has none — checked before loading so an
## absent drop-in never prints a load error.
func _art_for(card: Dictionary) -> Texture2D:
	var path: String = BOOT_DIR + String(card.art)
	if not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		return null
	return TextureLoader.load_texture(path)

func _play_sting() -> void:
	var stream := _resolve_sting()
	if stream == null:
		return
	_player.stream = stream
	_player.volume_db = STING_DB
	_player.play()

## Imported resource first (what exported builds ship); raw file-load fallback
## so a freshly-rendered ogg works without an import pass.
func _resolve_sting() -> AudioStream:
	for ext in ["ogg", "wav"]:
		var path: String = BOOT_DIR + STING + "." + ext
		if ResourceLoader.exists(path):
			var res := load(path)
			if res is AudioStream:
				return res
	for ext in ["ogg", "wav"]:
		var path: String = BOOT_DIR + STING + "." + ext
		if FileAccess.file_exists(path):
			var raw: AudioStream = AudioStreamOggVorbis.load_from_file(path) if ext == "ogg" \
				else AudioStreamWAV.load_from_file(path)
			if raw:
				return raw
	return null

func _build() -> void:
	_matte = ColorRect.new()
	_matte.color = Color.BLACK
	_matte.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_matte)

	# Letterboxed over a matte of the card's own color: art of any aspect
	# sits seamlessly in the 16:9 frame.
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.texture_filter = ART_FILTER
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_art)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_fallback = VBoxContainer.new()
	_fallback.alignment = BoxContainer.ALIGNMENT_CENTER
	_fallback.add_theme_constant_override("separation", 0)
	center.add_child(_fallback)

	_curtain = ColorRect.new()
	_curtain.color = Color.BLACK
	_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_curtain)

	_player = AudioStreamPlayer.new()
	# The SFX bus when the layout is loaded, Master otherwise (hermetic tests
	# and bus-less contexts keep working without warnings).
	_player.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	add_child(_player)
