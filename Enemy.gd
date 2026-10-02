extends CharacterBody3D

const SPEED = 1.0
var health = 100

func _physics_process(delta):
	velocity = Vector3(0, 0, SPEED)
	move_and_slide()
	print(position)
