extends RefCounted
## The full-screen art card every between-things screen shares: letterboxed
## art over black, a caption strip pinned to the bottom edge, a hint line
## under the caption. One builder — the interstitial's loading cards and the
## robbery's splash are the same frame with different pictures.
##
## No class_name on purpose — consumers preload BY PATH (the ui_style.gd
## convention) so the headless -s test chain never trips on a global.

const PANEL_BG := Color(0.07, 0.07, 0.09)
const DIM_TEXT := Color(0.55, 0.58, 0.62)
const STRIP_HEIGHT := 84.0
const ART_NAME := "CardArt"

## Builds the card under `parent` and returns the hint Label (the caller owns
## its text and arming). The art node is named ART_NAME for callers that tint it.
static func build(parent: Node, card: Texture2D, caption: String, caption_color: Color) -> Label:
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)

	var art := TextureRect.new()
	art.name = ART_NAME
	art.texture = card
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(art)

	var strip := ColorRect.new()
	strip.color = Color(PANEL_BG.r, PANEL_BG.g, PANEL_BG.b, 0.85)
	strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_top = -STRIP_HEIGHT
	parent.add_child(strip)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	strip.add_child(vbox)

	var caption_lbl := Label.new()
	caption_lbl.text = caption
	caption_lbl.add_theme_font_size_override("font_size", 24)
	caption_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_lbl.modulate = caption_color
	vbox.add_child(caption_lbl)

	var hint := Label.new()
	hint.text = "..."
	hint.add_theme_font_size_override("font_size", 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = DIM_TEXT
	vbox.add_child(hint)
	return hint
