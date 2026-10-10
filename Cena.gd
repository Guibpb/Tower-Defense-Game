extends Node3D

const ENEMY_SCENE = preload("res://Enemy.tscn")

@export var enemy_count = 20
@export var spawn_interval = 0.7
@export var enemy_vertical_offset = 0.62
@export var player_health = 100

@onready var caminho: Path3D = $Path3D
@onready var vida_label: Label = $HUD/VidaLabel

func _ready():
	_update_health_label()
	if caminho.curve == null or caminho.curve.get_baked_length() <= 0.0:
		push_error("O Path3D precisa ter uma curva com pelo menos dois pontos.")
		return

	spawn_queue()

func spawn_queue():
	for i in range(enemy_count):
		var path_follow := PathFollow3D.new()
		path_follow.loop = false
		path_follow.rotation_mode = PathFollow3D.ROTATION_NONE
		caminho.add_child(path_follow)

		var enemy := ENEMY_SCENE.instantiate() as CharacterBody3D
		enemy.position.y = enemy_vertical_offset
		enemy.connect("reached_end", _on_enemy_reached_end)
		path_follow.add_child(enemy)

		if spawn_interval > 0.0 and i < enemy_count - 1:
			await get_tree().create_timer(spawn_interval).timeout

func _on_enemy_reached_end() -> void:
	player_health = maxi(0, player_health - 1)
	_update_health_label()

func _update_health_label() -> void:
	vida_label.text = "%d" % player_health
