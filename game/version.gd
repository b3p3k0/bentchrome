class_name BuildInfo
extends RefCounted
## Single runtime source of truth for "what build am I running".
##
## The tracked res://version.txt file holds the release tag (e.g. "v0.4.2");
## the release archive carries the bumped value, so applying an update updates
## the local version for free. A raw dev checkout that has never cut a release
## has no file and reports "dev" — which never equals a release tag, so the
## updater simply treats the latest release as newer.

const VERSION_PATH := "res://version.txt"
const DEV := "dev"

static func current() -> String:
	if not FileAccess.file_exists(VERSION_PATH):
		return DEV
	var f := FileAccess.open(VERSION_PATH, FileAccess.READ)
	if f == null:
		return DEV
	var text := f.get_as_text().strip_edges()
	return text if text != "" else DEV
