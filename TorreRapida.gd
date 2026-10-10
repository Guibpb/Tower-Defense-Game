extends CharacterBody3D

@export var speed = 0
@export var gravity = 9.8
@export var shot_range = 4
@export var shot_interval = 0.3
@export var damage = 10
@export var projectile_scene: PackedScene = preload("res://Projectile.tscn")
var health = 1
var shot_timer = 0.0

func _ready():
	add_to_group("torres")

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
		shoot_at_first_enemy()


func shoot_at_first_enemy():
	var target = null
	var furthest_progress = -1.0
	for enemy in get_tree().get_nodes_in_group("inimigos"):
		if enemy == self or not is_instance_valid(enemy):
			continue
		var path_follow := enemy.get_parent() as PathFollow3D
		if path_follow == null:
			continue

		var distance = global_position.distance_to(enemy.global_position)
		if distance <= shot_range and path_follow.progress > furthest_progress:
			furthest_progress = path_follow.progress
			target = enemy
	if target == null:
		return
	var direction = (target.global_position - global_position).normalized()
	var projectile = projectile_scene.instantiate()
	projectile.shooter = self
	projectile.damage = damage
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + direction * 0.8 + Vector3.UP * 0.2
	projectile.direction = direction
	shot_timer = shot_interval
