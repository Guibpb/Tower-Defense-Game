extends CharacterBody3D

@export var speed = 1
@export var gravity = 9.8
@export var shot_range = 10.0
@export var shot_interval = 1.5
@export var projectile_scene: PackedScene = preload("res://Projectile.tscn")
var health = 100
var shot_timer = 0.0

func _ready():
	add_to_group("inimigos")

func _physics_process(delta):
	velocity.x = 0.0
	velocity.z = speed
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()

func take_damage(amount):
	health -= amount
	print(name, " recebeu ", amount, " de dano. Vida: ", health)
	if health <= 0:
		queue_free()
