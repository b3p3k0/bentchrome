extends Control
## The live PIT STOP opened by the end screen: a keyboard-only shop whose
## state and purchase rules live here while its room and catalog views paint.
## The real VehicleLoadout.compose seam drives every highlighted preview.
##
## API: setup(stats, owned, next_level_name) — `owned` is the caller's array
## and is mutated in place. Raw physical arrows navigate, ENTER selects, and
## ESC backs out. Mouse, actions, gamepads, WASD, and Space never operate it.

signal left
signal bought(item_id: String)

const Economy := preload("res://game/economy.gd")
const Catalog := preload("res://ui/garage/garage_catalog.gd")
const ShopRoom := preload("res://ui/garage/shop_room.gd")
const ShopMenu := preload("res://ui/garage/shop_menu.gd")

enum Mode { ROOM, MENU, CONFIRM }

static var GUARD_SEC := 0.25
static var MO_LINES := {
	&"idle": "Take your time. I got all day.",
	&"confirm": "⚙ %s for the %s. Deal?    [ENTER] DEAL    [ESC] NAH",
	&"locked": "Bolt on the %s first, kid.",
	&"short": "You're ⚙ %s short. Go break somethin'.",
	&"owned": "Already on your ride. I don't sell twice.",
	&"bought": "Bolted on. Pleasure doin' business.",
}

var stats: VehicleStats
var owned: Array = []
var next_level_name := ""
var mode: Mode = Mode.ROOM
var category_index := 0
var item_index := 0
var mo_line: String = MO_LINES[&"idle"]
var items: Array = []
var by_id: Dictionary = {}
var categories: Array = []

var _room: Control
var _menu: Control
var _guard_left := 0.0
var _saved_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _cursor_claimed := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	items = Catalog.load_catalog()
	for item in items:
		by_id[String(item.id)] = item
	categories = _categories_from_hotspots()
	_room = ShopRoom.new()
	_room.set_anchors_preset(Control.PRESET_FULL_RECT)
	_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_room)
	_menu = ShopMenu.new()
	_menu.name = "ShopMenu"
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_menu)
	visibility_changed.connect(_sync_mouse_mode)
	_sync_mouse_mode()
	refresh()

func setup(ride: VehicleStats, owned_ref: Array, next_name: String) -> void:
	stats = ride
	owned = owned_ref
	next_level_name = next_name
	mode = Mode.ROOM
	category_index = 0
	item_index = 0
	mo_line = MO_LINES[&"idle"]
	if is_instance_valid(_room):
		_room.focus(0, true)
	_arm_guard()
	refresh()

func _process(delta: float) -> void:
	_guard_left = maxf(_guard_left - delta, 0.0)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or event is not InputEventKey or not event.pressed or event.echo:
		return
	var code: Key = (event as InputEventKey).physical_keycode
	if code not in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ENTER,
			KEY_KP_ENTER, KEY_ESCAPE]:
		return
	get_viewport().set_input_as_handled()
	if code in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE] and _guard_left > 0.0:
		return
	if mode == Mode.CONFIRM:
		_handle_confirm(code)
	elif mode == Mode.ROOM:
		_handle_room(code)
	else:
		_handle_menu(code)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		accept_event()

func _handle_room(code: Key) -> void:
	match code:
		KEY_LEFT:
			_move_category(-1)
		KEY_RIGHT:
			_move_category(1)
		KEY_ENTER, KEY_KP_ENTER:
			item_index = 0
			mo_line = MO_LINES[&"idle"]
			UiSfx.select(self)
			_set_mode(Mode.MENU)
			refresh()
		KEY_ESCAPE:
			UiSfx.back(self)
			left.emit()

func _handle_menu(code: Key) -> void:
	match code:
		KEY_UP:
			_move_item(-1)
		KEY_DOWN:
			_move_item(1)
		KEY_LEFT:
			_move_category(-1)
		KEY_RIGHT:
			_move_category(1)
		KEY_ENTER, KEY_KP_ENTER:
			_select_item()
		KEY_ESCAPE:
			UiSfx.back(self)
			mo_line = MO_LINES[&"idle"]
			_set_mode(Mode.ROOM)
			refresh()

func _handle_confirm(code: Key) -> void:
	match code:
		KEY_ENTER, KEY_KP_ENTER:
			_try_buy(selected_item())
		KEY_ESCAPE:
			UiSfx.back(self)
			mo_line = MO_LINES[&"idle"]
			_set_mode(Mode.MENU)
			refresh()

func _move_item(direction: int) -> void:
	var pool := category_items()
	if pool.is_empty():
		return
	item_index = wrapi(item_index + direction, 0, pool.size())
	UiSfx.move(self)
	refresh()

func _move_category(direction: int) -> void:
	if categories.is_empty():
		return
	category_index = wrapi(category_index + direction, 0, categories.size())
	item_index = 0
	UiSfx.move(self)
	refresh()

func _select_item() -> void:
	var item := selected_item()
	var state := item_state(item)
	if state == &"buyable":
		mo_line = MO_LINES[&"confirm"] % [fmt(price_for(item)), item.display_name]
		UiSfx.select(self)
		_set_mode(Mode.CONFIRM)
		refresh()
	else:
		mo_line = rejection_line(item, state)
		UiSfx.back(self)
	refresh()

func category_items() -> Array:
	if categories.is_empty():
		return []
	var category: String = categories[category_index]
	return items.filter(func(item): return String(item.category) == category)

func selected_item() -> Dictionary:
	var pool := category_items()
	return pool[item_index] if item_index >= 0 and item_index < pool.size() else {}

## Purchase state is public because the live flow and the paint-only view use
## the same source of truth.
func item_state(item: Dictionary) -> StringName:
	if item.is_empty():
		return &"none"
	if String(item.id) in owned:
		return &"owned"
	var required := String(item.get("requires", ""))
	if not required.is_empty() and required not in owned:
		return &"locked"
	if price_for(item) > Economy.funds:
		return &"short"
	return &"buyable"

func price_for(item: Dictionary) -> int:
	return Economy.price(int(item.get("price", 0)))

func wallet() -> int:
	return Economy.funds

func is_confirming() -> bool:
	return mode == Mode.CONFIRM

func is_room() -> bool:
	return mode == Mode.ROOM

func rejection_line(item: Dictionary, state: StringName) -> String:
	match state:
		&"locked":
			var required: Dictionary = by_id.get(String(item.get("requires", "")), {})
			return MO_LINES[&"locked"] % String(required.get("display_name", "that part"))
		&"short":
			return MO_LINES[&"short"] % fmt(price_for(item) - Economy.funds)
		&"owned":
			return MO_LINES[&"owned"]
	return MO_LINES[&"idle"]

func _try_buy(item: Dictionary) -> void:
	if item_state(item) != &"buyable":
		mo_line = rejection_line(item, item_state(item))
		UiSfx.back(self)
		_set_mode(Mode.MENU)
		refresh()
		return
	Economy.funds -= price_for(item)
	var slot := String(item.get("exclusive_slot", ""))
	if not slot.is_empty():
		for other in items:
			if String(other.get("exclusive_slot", "")) == slot \
					and String(other.id) in owned:
				owned.erase(String(other.id))
	var item_id := String(item.id)
	owned.append(item_id)
	mo_line = MO_LINES[&"bought"]
	UiSfx.select(self)
	_set_mode(Mode.MENU)
	refresh()
	bought.emit(item_id)

func _owned_mods() -> Array:
	var mods: Array = []
	for id in owned:
		if by_id.has(id):
			mods.append(Catalog.as_mod(by_id[id]))
	return mods

func composed(with_item: Dictionary = {}) -> VehicleStats:
	var mods := _owned_mods()
	if not with_item.is_empty() and item_state(with_item) in [&"buyable", &"short", &"locked"]:
		mods.append(Catalog.as_mod(with_item))
	return VehicleLoadout.compose(stats, mods)

func fmt(number: int) -> String:
	var source := str(number)
	var output := ""
	for index in source.length():
		if index > 0 and (source.length() - index) % 3 == 0:
			output += ","
		output += source[index]
	return output

func refresh() -> void:
	if is_instance_valid(_menu):
		_menu.visible = mode != Mode.ROOM
	if stats == null:
		return
	if is_instance_valid(_room):
		_room.refresh(self)
	if is_instance_valid(_menu):
		_menu.refresh(self)

func _set_mode(next_mode: Mode) -> void:
	if mode == next_mode:
		return
	mode = next_mode
	_arm_guard()

func _arm_guard() -> void:
	_guard_left = GUARD_SEC

func _categories_from_hotspots() -> Array:
	var catalog: Array = Catalog.categories()
	var spatial: Array = []
	var counts: Dictionary = {}
	for hotspot in ShopRoom.HOTSPOTS:
		var category := String(hotspot.get("category", ""))
		spatial.append(category)
		counts[category] = int(counts.get(category, 0)) + 1
	var valid := spatial.size() == catalog.size()
	for category in catalog:
		valid = valid and int(counts.get(category, 0)) == 1
	for category in spatial:
		valid = valid and category in catalog
	if not valid:
		push_error("garage: ShopRoom.HOTSPOTS must contain every catalog category exactly once")
		return catalog.duplicate()
	return spatial

func _sync_mouse_mode() -> void:
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	if visible and not _cursor_claimed:
		_saved_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		_cursor_claimed = true
	elif not visible:
		_restore_mouse_mode()

func _restore_mouse_mode() -> void:
	if not _cursor_claimed:
		return
	Input.mouse_mode = _saved_mouse_mode
	_cursor_claimed = false

func _exit_tree() -> void:
	_restore_mouse_mode()
