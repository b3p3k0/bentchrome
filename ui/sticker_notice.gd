extends RefCounted
## Shared copy and sound for bumper-sticker notices at natural breaks.
##
## No class_name on purpose — UI consumers preload this helper by path.


static func line(ids: Array, stickers: Node) -> String:
	if ids.is_empty():
		return ""
	if stickers == null:
		return ""
	if stickers.has_method(&"ensure_catalog"):
		stickers.ensure_catalog()
	var names_by_id: Dictionary = {}
	for row_v in stickers.catalog():
		if not row_v is Dictionary:
			continue
		var row: Dictionary = row_v
		var id := String(row.get("id", ""))
		if not id.is_empty():
			names_by_id[id] = String(row.get("name", id))
	var names: Array[String] = []
	for id_v in ids:
		var id := String(id_v)
		names.append(String(names_by_id.get(id, id)).to_upper())
	if names.size() == 1:
		return "NEW BUMPER STICKER: %s — view your collection from the main menu" \
			% names[0]
	return "%d NEW BUMPER STICKERS: %s — view your collection from the main menu" \
		% [names.size(), ", ".join(names)]


static func play_sound(node: Node) -> void:
	if node == null:
		return
	var audio := node.get_node_or_null(^"/root/AudioDirector")
	if audio == null:
		return
	var event := &"sticker_earned" if audio.has_asset(&"sticker_earned") else &"pickup"
	audio.play(event)
