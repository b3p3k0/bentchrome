extends RefCounted
## NetManifest: the mod-detection checksum is stable, order-independent,
## newline-agnostic (Windows == Linux), and flips on any script edit.
## Uses a throwaway user:// tree; the real res:// roots get a sanity pass.

const TMP_DIR := "user://_test_manifest"
const Manifest := preload("res://game/net/net_manifest.gd")

var t

func _init(runner) -> void:
	t = runner

func _write(rel: String, body: String) -> void:
	var f := FileAccess.open(TMP_DIR + "/" + rel, FileAccess.WRITE)
	f.store_string(body)
	f.close()

func _cleanup() -> void:
	for rel in ["a.gd", "sub/b.gd", "note.txt"]:
		DirAccess.remove_absolute(TMP_DIR + "/" + rel)
	DirAccess.remove_absolute(TMP_DIR + "/sub")
	DirAccess.remove_absolute(TMP_DIR)

func test_manifest_behaviour() -> void:
	DirAccess.make_dir_recursive_absolute(TMP_DIR + "/sub")
	_write("a.gd", "extends Node\nvar speed := 10\n")
	_write("sub/b.gd", "extends Node\nvar armor := 3\n")

	var base := Manifest.compute([TMP_DIR])
	t.check(base.length() == 64, "manifest: SHA-256 hex string")
	t.check(base == Manifest.compute([TMP_DIR]), "manifest: stable across runs")

	_write("note.txt", "not a script")
	t.check(base == Manifest.compute([TMP_DIR]), "manifest: non-gd files invisible")

	_write("sub/b.gd", "extends Node\r\nvar armor := 3\r\n")
	t.check(base == Manifest.compute([TMP_DIR]),
		"manifest: CRLF checkout hashes like LF (Windows == Linux)")

	_write("sub/b.gd", "extends Node\nvar armor := 9\n")
	t.check(base != Manifest.compute([TMP_DIR]), "manifest: a script edit flips the hash")

	_cleanup()
	t.check(Manifest.compute([TMP_DIR]).length() == 64,
		"manifest: missing root still yields a hash (empty tree)")

func test_manifest_real_tree() -> void:
	var real := Manifest.cached()
	t.check(real.length() == 64, "manifest: real gameplay tree hashes")
	t.check(real == Manifest.cached(), "manifest: cached() computes once and sticks")
