extends Area2D

@export var speed := 600.0
@export var lifetime := 1.5

var direction := Vector2.ZERO

func _ready():
	var timer = get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta):
	position += direction * speed * delta

func _on_body_entered(body):
	if body.is_in_group("player"):
		return
	print("Bullet hit")
	queue_free()

func _on_area_entered(area):
	if area.is_in_group("player"):
		return
	print("Bullet hit")
	queue_free()