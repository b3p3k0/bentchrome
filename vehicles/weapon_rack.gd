class_name WeaponRack
extends Node
## Owns the selectable weapon slots (special / standard / homing): what each
## holds, how much ammo, which is selected, and the special's recharge. Pure
## bookkeeping — firing physics stays in WeaponMount/SpecialController; the
## Vehicle asks the rack before firing and consumes on an actual shot.

signal selection_changed(index: int)
signal ammo_changed(index: int, ammo: int)

enum Slot { SPECIAL, STANDARD, HOMING }

const STANDARD_DEF := preload("res://data/weapons/missile_standard.tres")
const HOMING_DEF := preload("res://data/weapons/missile_homing.tres")

@export var start_standard := 2
@export var start_homing := 1

var _slots: Array = []  # each: {def: WeaponDef, ammo: int, cap: int, recharge: float}
var _selected := 0
var _recharge_t := 0.0

func configure(special_def: WeaponDef, special_cap: int, special_recharge_seconds: float) -> void:
	_slots = [
		{"def": special_def, "ammo": special_cap, "cap": special_cap, "recharge": special_recharge_seconds},
		{"def": STANDARD_DEF, "ammo": start_standard, "cap": 6, "recharge": 0.0},
		{"def": HOMING_DEF, "ammo": start_homing, "cap": 3, "recharge": 0.0},
	]
	_selected = Slot.SPECIAL
	_recharge_t = 0.0
	selection_changed.emit(_selected)
	for i in _slots.size():
		ammo_changed.emit(i, _slots[i].ammo)

func _physics_process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if _slots.is_empty():
		return
	var s: Dictionary = _slots[Slot.SPECIAL]
	if s.recharge > 0.0 and s.ammo < s.cap:
		_recharge_t += delta
		if _recharge_t >= s.recharge:
			_recharge_t = 0.0
			s.ammo += 1
			ammo_changed.emit(Slot.SPECIAL, s.ammo)

func select_next() -> void:
	_select((_selected + 1) % _slots.size())

func select_prev() -> void:
	_select((_selected - 1 + _slots.size()) % _slots.size())

func _select(index: int) -> void:
	if index == _selected or _slots.is_empty():
		return
	_selected = index
	selection_changed.emit(_selected)

func selected_index() -> int:
	return _selected

func selected_def() -> WeaponDef:
	return _slots[_selected].def if not _slots.is_empty() else null

func ammo(index: int) -> int:
	return _slots[index].ammo if index < _slots.size() else 0

func cap(index: int) -> int:
	return _slots[index].cap if index < _slots.size() else 0

func can_consume() -> bool:
	return not _slots.is_empty() and _slots[_selected].ammo > 0

func consume() -> void:
	if not can_consume():
		return
	_slots[_selected].ammo -= 1
	ammo_changed.emit(_selected, _slots[_selected].ammo)
	if _slots[_selected].ammo == 0:
		_auto_cycle()

## Depleted slot: advance to the next slot holding ammo (a recharging special
## at 0 counts as dry). All dry = stay put; the special recharges back.
func _auto_cycle() -> void:
	for step in range(1, _slots.size()):
		var i: int = (_selected + step) % _slots.size()
		if _slots[i].ammo > 0:
			_select(i)
			return

## Adds ammo to a slot (pickups). Returns how much was actually accepted.
func add_ammo(index: int, amount: int) -> int:
	if _slots.is_empty() or index >= _slots.size():
		return 0
	var s: Dictionary = _slots[index]
	var accepted: int = mini(amount, s.cap - s.ammo)
	if accepted > 0:
		s.ammo += accepted
		ammo_changed.emit(index, s.ammo)
	return accepted

## Recharge progress toward the special's next round, 0..1 (1 = full or n/a).
func recharge_fraction() -> float:
	if _slots.is_empty():
		return 1.0
	var s: Dictionary = _slots[Slot.SPECIAL]
	if s.recharge <= 0.0 or s.ammo >= s.cap:
		return 1.0
	return clampf(_recharge_t / s.recharge, 0.0, 1.0)
