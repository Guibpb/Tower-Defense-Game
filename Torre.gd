extends CharacterBody3D

@export var speed = 0
@export var gravity = 9.8
@export var shot_range = 10.0
@export var shot_interval = 0.3
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
	shot_timer -= delta
	if shot_timer <= 0.0:
		shoot_at_nearest_enemy()

func shoot_at_nearest_enemy():
	var target = null
	var nearest_distance = shot_range
	for enemy in get_tree().get_nodes_in_group("inimigos"):
		if enemy == self or not is_instance_valid(enemy):
			continue
		var distance = global_position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			target = enemy
	if target == null:
		return
	var direction = (target.global_position - global_position).normalized()
	var projectile = projectile_scene.instantiate()
	projectile.shooter = self
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + direction * 0.8 + Vector3.UP * 0.2
	projectile.direction = direction
	shot_timer = shot_interval
