extends Area2D
## Ammo crate: grants missiles to a vehicle's WeaponRack on contact, then hides
## and respawns after a delay. Grabs nothing when the slot is full (crate stays).
## Any vehicle can collect; AI just doesn't use missiles yet.

@export_enum("standard", "homing") var kind := "standard"
@export var amount := 2
@export var respawn_seconds := 20.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var tag := get_node_or_null("Tag") as Label
	if tag:
		tag.text = "M" if kind == "standard" else "H"
	var vis := get_node_or_null("Vis") as Polygon2D
	if vis:
		vis.color = Color(0.25, 0.8, 0.35) if kind == "standard" else Color(0.25, 0.7, 0.9)

func _on_body_entered(body: Node) -> void:
	if not body.has_method("get_rack"):
		return
	var rack: WeaponRack = body.get_rack()
	if rack == null:
		return
	var slot := WeaponRack.Slot.STANDARD if kind == "standard" else WeaponRack.Slot.HOMING
	if rack.add_ammo(slot, amount) > 0:
		_collect()

func _collect() -> void:
	visible = false
	set_deferred("monitoring", false)
	get_tree().create_timer(respawn_seconds).timeout.connect(_respawn, CONNECT_ONE_SHOT)

func _respawn() -> void:
	visible = true
	set_deferred("monitoring", true)
