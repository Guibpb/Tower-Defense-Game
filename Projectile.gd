extends Area3D

@export var speed = 20.0
@export var damage = 25
var direction = Vector3.ZERO
var shooter: Node3D
var lifetime = 3.0

func _ready():
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body):
	if body == shooter:
		return
	if body.is_in_group("inimigos"):
		body.take_damage(damage)
		queue_free()
