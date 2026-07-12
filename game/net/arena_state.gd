class_name ArenaState
extends RefCounted
## Compact flag vocabulary shared by opt-in arena entities and the snapshot
## codec. Level props remain duck-typed; this file names no environment class.

const ALIVE := 1
const ARMED := 2
const WARNING := 4
const ACTIVE := 8
const ESCAPE := 16

static func flags(row: Dictionary) -> int:
	return clampi(int(row.get("flags", 0)), 0, 255)

static func is_alive(row: Dictionary) -> bool:
	return (flags(row) & ALIVE) != 0
