extends Area2D
## Ammo crate: grants missiles to a vehicle's WeaponRack on contact, then hides
## and respawns after a delay. Grabs nothing when the slot is full (crate stays).
## Any vehicle can collect; AI just doesn't use missiles yet.

@export_enum("standard", "homing", "power", "rear", "mine", "jump") var kind := "standard"
@export var amount := 2
@export var respawn_seconds := 20.0
@export var floor_index := -1

const Floors := preload("res://game/floors.gd")

const STYLE := {
	"standard": {"tag": "M", "color": Color(0.25, 0.8, 0.35), "slot": WeaponRack.Slot.STANDARD},
	"homing": {"tag": "H", "color": Color(0.25, 0.7, 0.9), "slot": WeaponRack.Slot.HOMING},
	"power": {"tag": "P", "color": Color(0.9, 0.45, 0.2), "slot": WeaponRack.Slot.POWER},
	"rear": {"tag": "R", "color": Color(0.18, 0.5, 1.0), "slot": WeaponRack.Slot.REAR},
	"mine": {"tag": "X", "color": Color(0.75, 0.25, 0.2), "slot": WeaponRack.Slot.MINE},
	"jump": {"tag": "J", "color": Color(0.6, 0.4, 0.9), "slot": WeaponRack.Slot.JUMP_MINE},
}

func _ready() -> void:
	add_to_group(&"pickups")  # AI scavenging scans this
	z_index = 2 if floor_index >= 3 else 0
	body_entered.connect(_on_body_entered)
	var style: Dictionary = STYLE.get(kind, STYLE["standard"])
	var tag := get_node_or_null("Tag") as Label
	if tag:
		tag.text = style["tag"]
	var vis := get_node_or_null("Vis") as Polygon2D
	if vis:
		vis.color = style["color"]

func _on_body_entered(body: Node) -> void:
	if not body.has_method("get_rack") or not Floors.same_floor(self, body):
		return
	var rack: WeaponRack = body.get_rack()
	if rack == null:
		return
	var slot: WeaponRack.Slot = STYLE.get(kind, STYLE["standard"])["slot"]
	if rack.add_ammo(slot, amount) > 0:
		if body.is_in_group(&"player"):  # cue is personal feedback; AI grabs stay silent
			var audio := get_node_or_null(^"/root/AudioDirector")
			if audio:
				audio.play(&"pickup")
		_collect()

func _collect() -> void:
	visible = false
	set_deferred("monitoring", false)
	get_tree().create_timer(respawn_seconds).timeout.connect(_respawn, CONNECT_ONE_SHOT)

func _respawn() -> void:
	visible = true
	set_deferred("monitoring", true)
