extends Node3D

const ENEMY_SCENE = preload("res://Enemy.tscn")

@export var enemy_count = 10
@export var spawn_interval = 2.0
@export var spawn_position = Vector3(0, 0, -5)

func _ready():
	spawn_queue()

func spawn_queue():
	for i in range(enemy_count):
		var enemy = ENEMY_SCENE.instantiate()
		get_tree().current_scene.add_child(enemy)
		enemy.global_position = spawn_position

		await get_tree().create_timer(spawn_interval).timeout
