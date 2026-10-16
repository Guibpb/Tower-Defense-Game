extends CharacterBody3D

@export var speed = 0
@export var gravity = 9.8
@export var shot_range = 3.5
@export var shot_interval = 1
@export var damage = 25
@export var projectile_scene: PackedScene = preload("res://Projectile.tscn")
var health = 1
var shot_timer = 0.0

func _ready():
	add_to_group("torres")
	_criar_visual_de_alcance()

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

func _criar_visual_de_alcance() -> void:
	var segmentos := 64
	var espessura := 0.055
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var raio_interno := maxf(0.0, shot_range - espessura)

	for i in range(segmentos):
		var angulo := TAU * float(i) / float(segmentos)
		var cosseno := cos(angulo)
		var seno := sin(angulo)
		vertices.append(Vector3(cosseno * shot_range, 0.0, seno * shot_range))
		vertices.append(Vector3(cosseno * raio_interno, 0.0, seno * raio_interno))
		var proximo := (i + 1) % segmentos
		var base := i * 2
		var base_proximo := proximo * 2
		indices.append_array(PackedInt32Array([base, base + 1, base_proximo, base + 1, base_proximo + 1, base_proximo]))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var anel := ArrayMesh.new()
	_anel_add_surface(anel, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(0.18, 0.82, 1.0, 0.8)
	anel.surface_set_material(0, material)

	var visual := MeshInstance3D.new()
	visual.name = "IndicadorAlcance"
	visual.position.y = -0.36
	visual.mesh = anel
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)

func _anel_add_surface(anel: ArrayMesh, arrays: Array) -> void:
	anel.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
