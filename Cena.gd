extends Node3D

const ENEMY_SCENE = preload("res://Enemy.tscn")
const BASIC_TOWER_COST = 75
const FAST_TOWER_COST = 60

@export var enemy_count = 20
@export var spawn_interval = 0.7
@export var enemy_vertical_offset = 0.62
@export var player_health = 100
@export var player_energy: int = 100
@export var path_visual_width: float = 1.6
@export var path_surface_offset: float = 0.13

@onready var caminho: Path3D = $Path3D
@onready var vida_label: Label = $HUD/VidaLabel
@onready var energia_label: Label = $HUD/EnergiaLabel
@onready var menu_inicial: Control = $HUD/MenuInicial
@onready var menu_torres: Control = $HUD/MenuTorres
@onready var botao_jogo: Button = $HUD/MenuTorres/Painel/Conteudo/Comecar
@onready var status_ativacao: Label = $HUD/MenuTorres/Painel/Conteudo/Status
@onready var botao_gerenciar_torres: Button = $HUD/GerenciarTorres
@onready var botao_ativar_basica: Array[Button] = [
	$HUD/MenuTorres/Painel/Conteudo/Torre1/Linha/AtivarBasica,
	$HUD/MenuTorres/Painel/Conteudo/Torre2/Linha/AtivarBasica,
	$HUD/MenuTorres/Painel/Conteudo/Torre3/Linha/AtivarBasica,
	$HUD/MenuTorres/Painel/Conteudo/Torre4/Linha/AtivarBasica,
]
@onready var botao_ativar_rapida: Array[Button] = [
	$HUD/MenuTorres/Painel/Conteudo/Torre1/Linha/AtivarRapida,
	$HUD/MenuTorres/Painel/Conteudo/Torre2/Linha/AtivarRapida,
	$HUD/MenuTorres/Painel/Conteudo/Torre3/Linha/AtivarRapida,
	$HUD/MenuTorres/Painel/Conteudo/Torre4/Linha/AtivarRapida,
]
@onready var status_torres: Array[Label] = [
	$HUD/MenuTorres/Painel/Conteudo/Torre1/Estado,
	$HUD/MenuTorres/Painel/Conteudo/Torre2/Estado,
	$HUD/MenuTorres/Painel/Conteudo/Torre3/Estado,
	$HUD/MenuTorres/Painel/Conteudo/Torre4/Estado,
]
@onready var torres: Array[Node] = [
	$Torre1,
	$Torre2,
	$Torre3,
	$Torre4,
]
@onready var camera: Camera3D = $Camera3D
@onready var malha_chao: MeshInstance3D = $Chão/StaticBody3D/MeshInstance3D

var tipos_ativados: Array[String] = ["", "", "", ""]
var partida_iniciada := false

func _ready() -> void:
	get_tree().paused = true
	_configurar_camera()
	_update_health_label()
	_atualizar_economia()
	$HUD/MenuInicial/Centralizar/Conteudo/Play.pressed.connect(_on_menu_play_pressed)
	botao_jogo.pressed.connect(_on_game_play_pressed)
	botao_gerenciar_torres.pressed.connect(_on_gerenciar_torres_pressed)
	for indice in range(torres.size()):
		botao_ativar_basica[indice].pressed.connect(_ativar_torre.bind(indice, "basica"))
		botao_ativar_rapida[indice].pressed.connect(_ativar_torre.bind(indice, "rapida"))

	if caminho.curve == null or caminho.curve.get_baked_length() <= 0.0:
		push_error("O Path3D precisa ter uma curva com pelo menos dois pontos.")
		botao_jogo.disabled = true
	else:
		_criar_visual_do_caminho()

func spawn_queue() -> void:
	for i in range(enemy_count):
		var path_follow := PathFollow3D.new()
		path_follow.loop = false
		path_follow.rotation_mode = PathFollow3D.ROTATION_NONE
		caminho.add_child(path_follow)

		var enemy := ENEMY_SCENE.instantiate() as CharacterBody3D
		enemy.position.y = enemy_vertical_offset
		enemy.connect("reached_end", _on_enemy_reached_end)
		enemy.connect("defeated", _on_enemy_defeated)
		path_follow.add_child(enemy)

		if spawn_interval > 0.0 and i < enemy_count - 1:
			await get_tree().create_timer(spawn_interval).timeout

func _on_enemy_reached_end() -> void:
	player_health = maxi(0, player_health - 1)
	_update_health_label()

func _on_enemy_defeated() -> void:
	player_energy += 1
	_atualizar_economia()

func _update_health_label() -> void:
	vida_label.text = "VIDA: %d" % player_health

func _on_menu_play_pressed() -> void:
	menu_inicial.hide()
	menu_torres.show()
	energia_label.show()
	_atualizar_economia()

func _on_gerenciar_torres_pressed() -> void:
	if not partida_iniciada:
		return
	botao_jogo.text = "Voltar ao jogo"
	menu_torres.show()
	get_tree().paused = true

func _ativar_torre(indice: int, tipo: String) -> void:
	if indice < 0 or indice >= torres.size() or not tipos_ativados[indice].is_empty():
		return

	var custo := BASIC_TOWER_COST if tipo == "basica" else FAST_TOWER_COST
	if player_energy < custo:
		status_ativacao.text = "Energia insuficiente. Você precisa de %d E." % custo
		return

	torres[indice].call("ativar", tipo == "rapida")
	player_energy -= custo
	tipos_ativados[indice] = tipo
	if partida_iniciada:
		var indicador := torres[indice].get_node_or_null("IndicadorAlcance") as MeshInstance3D
		if indicador != null:
			indicador.hide()

	var nome_tipo := "rápida" if tipo == "rapida" else "normal"
	status_ativacao.text = "Torre %d ativada como %s por %d E." % [indice + 1, nome_tipo, custo]
	_atualizar_economia()

func _atualizar_economia() -> void:
	energia_label.text = "%d E" % player_energy
	var quantidade_ativas := 0
	for indice in range(tipos_ativados.size()):
		var tipo := tipos_ativados[indice]
		if tipo.is_empty():
			status_torres[indice].text = "Torre %d — desligada" % (indice + 1)
		else:
			quantidade_ativas += 1
			var nome_tipo := "rápida" if tipo == "rapida" else "normal"
			status_torres[indice].text = "Torre %d — %s ativa" % [indice + 1, nome_tipo]
		botao_ativar_basica[indice].disabled = not tipo.is_empty() or player_energy < BASIC_TOWER_COST
		botao_ativar_rapida[indice].disabled = not tipo.is_empty() or player_energy < FAST_TOWER_COST

	if partida_iniciada:
		botao_jogo.text = "Voltar ao jogo"
		botao_jogo.disabled = false
	else:
		botao_jogo.text = "Começar jogo"
		botao_jogo.disabled = quantidade_ativas == 0

func _on_game_play_pressed() -> void:
	if partida_iniciada:
		menu_torres.hide()
		get_tree().paused = false
		return

	menu_torres.hide()
	for torre in torres:
		var indicador := torre.get_node_or_null("IndicadorAlcance") as MeshInstance3D
		if indicador != null:
			indicador.hide()
	partida_iniciada = true
	_atualizar_economia()
	botao_gerenciar_torres.show()
	get_tree().paused = false
	spawn_queue()

func _configurar_camera() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 18.0
	var centro_mapa := Vector3(-1.5, malha_chao.global_position.y, 5.0)
	camera.global_position = centro_mapa + Vector3(0.0, 20.0, 21.0)
	camera.look_at(centro_mapa, Vector3.UP)

func _criar_visual_do_caminho() -> void:
	var pontos := caminho.curve.get_baked_points()
	if pontos.size() < 2:
		return

	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in range(pontos.size()):
		var anterior := pontos[maxi(i - 1, 0)]
		var proximo := pontos[mini(i + 1, pontos.size() - 1)]
		var tangente := proximo - anterior
		tangente.y = 0.0
		var lateral := Vector3(tangente.z, 0.0, -tangente.x)
		if lateral.length_squared() < 0.000001:
			lateral = Vector3.RIGHT
		else:
			lateral = lateral.normalized()

		var centro := pontos[i] + Vector3.UP * path_surface_offset
		vertices.append(centro + lateral * path_visual_width * 0.5)
		vertices.append(centro - lateral * path_visual_width * 0.5)
		if i < pontos.size() - 1:
			var base := i * 2
			indices.append_array(PackedInt32Array([base, base + 1, base + 2, base + 1, base + 3, base + 2]))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var faixa := ArrayMesh.new()
	faixa.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(0.65, 0.69, 0.73, 1.0)
	faixa.surface_set_material(0, material)

	var visual := MeshInstance3D.new()
	visual.name = "VisualCaminho"
	visual.mesh = faixa
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	caminho.add_child(visual)
