class_name NetBanlist
extends RefCounted
## Host-side IP bans, persisted as a sorted JSON array. Path-injectable so
## tests use a throwaway file; a missing or corrupt file degrades silently to
## "nobody banned" (same hand-edited-file etiquette as GameState settings).

const DEFAULT_PATH := "user://banlist.json"

var path: String
var _ips := {}  # ip -> true (set semantics)

func _init(file_path := DEFAULT_PATH) -> void:
	path = file_path
	_load()

func is_banned(ip: String) -> bool:
	return _ips.has(ip)

func ban(ip: String) -> void:
	if ip.is_empty():
		return
	_ips[ip] = true
	_save()

func unban(ip: String) -> void:
	_ips.erase(ip)
	_save()

func all() -> Array:
	var out := _ips.keys()
	out.sort()
	return out

func _load() -> void:
	if not FileAccess.file_exists(path):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return
	var data: Variant = json.data
	if typeof(data) != TYPE_ARRAY:
		return
	for ip in data:
		if typeof(ip) == TYPE_STRING and not String(ip).is_empty():
			_ips[ip] = true

func _save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(all(), "\t"))
		f.close()
