extends Node3D

const ENEMY_SCENE = preload("res://Enemy.tscn")
const TOWER_BASIC_SCENE = preload("res://TorreBasica.tscn")
const TOWER_FAST_SCENE = preload("res://TorreRapida.tscn")

@export var enemy_count = 20
@export var spawn_interval = 0.7
@export var enemy_vertical_offset = 0.62
@export var player_health = 100

@onready var caminho: Path3D = $Path3D
@onready var vida_label: Label = $HUD/VidaLabel
@onready var menu_inicial: Control = $HUD/MenuInicial
@onready var menu_jogo: Control = $HUD/MenuJogo
@onready var botao_menu_play: Button = $HUD/MenuInicial/Centralizar/Conteudo/Play
@onready var botao_jogo_play: Button = $HUD/MenuJogo/Painel/Conteudo/Comecar
@onready var botao_torre_basica: Button = $HUD/MenuJogo/Painel/Conteudo/TorreBasica
@onready var botao_torre_rapida: Button = $HUD/MenuJogo/Painel/Conteudo/TorreRapida
@onready var status_construcao: Label = $HUD/MenuJogo/Painel/Conteudo/Status
@onready var area_posicionamento: Button = $HUD/AreaPosicionamento
@onready var camera: Camera3D = $Camera3D
@onready var chao: StaticBody3D = $Chão/StaticBody3D
@onready var malha_chao: MeshInstance3D = $Chão/StaticBody3D/MeshInstance3D

var tipo_torre_selecionada := ""

func _ready():
	get_tree().paused = true
	_update_health_label()
	botao_menu_play.pressed.connect(_on_menu_play_pressed)
	botao_jogo_play.pressed.connect(_on_game_play_pressed)
	botao_torre_basica.pressed.connect(_on_torre_basica_pressed)
	botao_torre_rapida.pressed.connect(_on_torre_rapida_pressed)
	area_posicionamento.pressed.connect(_on_area_posicionamento_pressed)

	if caminho.curve == null or caminho.curve.get_baked_length() <= 0.0:
		push_error("O Path3D precisa ter uma curva com pelo menos dois pontos.")
		botao_jogo_play.disabled = true

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

func _on_menu_play_pressed() -> void:
	menu_inicial.hide()
	menu_jogo.show()
	area_posicionamento.show()

func _on_torre_basica_pressed() -> void:
	_selecionar_torre("basica")

func _on_torre_rapida_pressed() -> void:
	_selecionar_torre("rapida")

func _selecionar_torre(tipo: String) -> void:
	tipo_torre_selecionada = tipo
	botao_torre_basica.button_pressed = tipo == "basica"
	botao_torre_rapida.button_pressed = tipo == "rapida"
	if tipo == "basica":
		status_construcao.text = "Torre básica selecionada. Clique no terreno para posicioná-la."
	else:
		status_construcao.text = "Torre rápida selecionada. Clique no terreno para posicioná-la."

func _on_area_posicionamento_pressed() -> void:
	if tipo_torre_selecionada.is_empty():
		status_construcao.text = "Escolha uma torre antes de clicar no terreno."
		return

	var origem := camera.project_ray_origin(get_viewport().get_mouse_position())
	var direcao := camera.project_ray_normal(get_viewport().get_mouse_position())
	var consulta := PhysicsRayQueryParameters3D.create(origem, origem + direcao * 1000.0)
	var resultado := get_world_3d().direct_space_state.intersect_ray(consulta)
	if resultado.is_empty() or resultado.collider != chao:
		status_construcao.text = "Clique em uma área livre do terreno para posicionar a torre."
		return

	var ponto_mundo: Vector3 = resultado.position
	var plano := malha_chao.mesh as PlaneMesh
	if plano != null:
		var ponto_local := malha_chao.to_local(ponto_mundo)
		if absf(ponto_local.x) > plano.size.x * 0.5 or absf(ponto_local.z) > plano.size.y * 0.5:
			status_construcao.text = "Posicione a torre dentro do mapa."
			return

	var cena_torre: PackedScene = TOWER_BASIC_SCENE
	if tipo_torre_selecionada == "rapida":
		cena_torre = TOWER_FAST_SCENE
	var torre := cena_torre.instantiate() as CharacterBody3D

	add_child(torre)
	torre.global_position = ponto_mundo + Vector3.UP * 0.5
	status_construcao.text = "Torre posicionada. Escolha outra ou continue colocando esta."

func _on_game_play_pressed() -> void:
	menu_jogo.hide()
	area_posicionamento.hide()
	get_tree().paused = false
	spawn_queue()
