extends CharacterBody3D

signal reached_end

@export var speed = 3
@export var gravity = 9.8
@export var shot_range = 10.0
@export var shot_interval = 1.5
@export var projectile_scene: PackedScene = preload("res://Projectile.tscn")
var health = 25
var shot_timer = 0.0
var caminho: PathFollow3D

func _ready():
	add_to_group("inimigos")
	caminho = get_parent() as PathFollow3D

func _physics_process(delta) -> void:
	if not is_instance_valid(caminho):
		return

	var path := caminho.get_parent() as Path3D
	if path == null or path.curve == null:
		queue_free()
		return

	caminho.progress += speed * delta
	if caminho.progress >= path.curve.get_baked_length():
		reached_end.emit()
		queue_free()

func take_damage(amount):
	health -= amount
	print(name, " recebeu ", amount, " de dano. Vida: ", health)
	if health <= 0:
		queue_free()
