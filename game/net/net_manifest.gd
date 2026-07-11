class_name NetManifest
extends RefCounted
## Mod-detection checksum: one platform-independent SHA-256 over the shipped
## gameplay scripts. Two peers on the same build produce the same string; a
## locally edited script flips it. Deliberately hashes SOURCE, never the
## binary (binaries differ per platform — export presets ship scripts as
## text), and deliberately NOT a security boundary: it flags casual mods,
## cross-build drift is caught by PROTOCOL_VERSION first.

const ROOTS := ["res://game", "res://vehicles", "res://weapons", "res://ai",
	"res://levels", "res://environment", "res://ui", "res://resources"]
const EXTENSION := "gd"

static var _cached := ""

## Boot-time value both handshake ends use; computed once per process.
static func cached() -> String:
	if _cached == "":
		_cached = compute()
	return _cached

## roots is injectable so tests can hash a throwaway user:// tree.
static func compute(roots: Array = ROOTS) -> String:
	var paths: Array[String] = []
	for root in roots:
		_walk(String(root), paths)
	paths.sort()  # DirAccess order is filesystem-dependent; the hash is not
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for path in paths:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		# \r stripped so a Windows checkout hashes like a Linux one.
		var text := f.get_buffer(f.get_length()).get_string_from_utf8().replace("\r", "")
		var line := path + ":" + _sha256_hex(text.to_utf8_buffer()) + "\n"
		ctx.update(line.to_utf8_buffer())
	return ctx.finish().hex_encode()

static func _walk(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := dir_path.path_join(entry)
			if dir.current_is_dir():
				_walk(full, out)
			elif entry.get_extension() == EXTENSION:
				out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()

static func _sha256_hex(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()
