extends RefCounted
## Sticker-only weapon identities and their broader achievement families.
## Dependency-free leaf: consumers preload this path; nothing names them back.

const MG := &"mg"
const RAM := &"ram"
const SIDE_SLIDE := &"side_slide"
const ENVIRONMENT := &"environment"
const FALL := &"fall"
const UNKNOWN := &"unknown"

const KIND_DASH := 2
const KIND_TRIGGER := 3

static var _defs := {}

static func id_for_def(def: Resource) -> StringName:
	if def == null or def.resource_path.is_empty():
		return UNKNOWN
	return StringName(def.resource_path.get_file().get_basename())

static func families(id: StringName) -> Array[StringName]:
	var result: Array[StringName] = [id]
	var def := _weapon_def(id)
	if id == RAM or id == SIDE_SLIDE \
			or (def != null and int(def.get("kind")) in [KIND_DASH, KIND_TRIGGER]):
		_add_unique(result, RAM)
	if def != null:
		var element: StringName = def.get("element")
		if element != &"":
			_add_unique(result, element)
	return result

static func _weapon_def(id: StringName) -> Resource:
	if _defs.has(id):
		return _defs[id]
	var path := "res://data/weapons/%s.tres" % id
	if not ResourceLoader.exists(path):
		return null
	var def := ResourceLoader.load(path)
	if def != null:
		_defs[id] = def
	return def

static func _add_unique(values: Array[StringName], value: StringName) -> void:
	if value not in values:
		values.append(value)
