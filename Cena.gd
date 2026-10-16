extends Node3D

const ENEMY_SCENE = preload("res://Enemy.tscn")
const TOWER_BASIC_SCENE = preload("res://TorreBasica.tscn")
const TOWER_FAST_SCENE = preload("res://TorreRapida.tscn")
const BASIC_TOWER_RANGE = 3.5
const FAST_TOWER_RANGE = 2.5
const BASIC_TOWER_COST = 75
const FAST_TOWER_COST = 60

@export var enemy_count = 20
@export var spawn_interval = 0.7
@export var enemy_vertical_offset = 0.62
@export var player_health = 100
@export var player_money: int = 100
@export var path_visual_width: float = 1.6
@export var path_surface_offset: float = 0.13
@export var path_placement_margin: float = 0.2

@onready var caminho: Path3D = $Path3D
@onready var vida_label: Label = $HUD/VidaLabel
@onready var dinheiro_label: Label = $HUD/DinheiroLabel
@onready var menu_inicial: Control = $HUD/MenuInicial
@onready var menu_jogo: Control = $HUD/MenuJogo
@onready var botao_menu_play: Button = $HUD/MenuInicial/Centralizar/Conteudo/Play
@onready var botao_jogo_play: Button = $HUD/MenuJogo/Painel/Conteudo/Comecar
@onready var botao_torre_basica: Button = $HUD/MenuJogo/Painel/Conteudo/TorreBasica
@onready var botao_torre_rapida: Button = $HUD/MenuJogo/Painel/Conteudo/TorreRapida
@onready var status_construcao: Label = $HUD/MenuJogo/Painel/Conteudo/Status
@onready var area_posicionamento: Button = $HUD/AreaPosicionamento
@onready var timer_previa_posicionamento: Timer = $HUD/TimerPreviaPosicionamento
@onready var camera: Camera3D = $Camera3D
@onready var chao: StaticBody3D = $Chão/StaticBody3D
@onready var malha_chao: MeshInstance3D = $Chão/StaticBody3D/MeshInstance3D

var tipo_torre_selecionada := ""
var previa_alcance: MeshInstance3D
var material_previa_alcance: StandardMaterial3D
var raio_previa_alcance := -1.0

func _ready():
	get_tree().paused = true
	_configurar_camera()
	_update_health_label()
	_atualizar_economia()
	botao_menu_play.pressed.connect(_on_menu_play_pressed)
	botao_jogo_play.pressed.connect(_on_game_play_pressed)
	botao_torre_basica.button_down.connect(_on_torre_basica_pressed)
	botao_torre_rapida.button_down.connect(_on_torre_rapida_pressed)
	botao_torre_basica.pressed.connect(_on_torre_basica_pressed)
	botao_torre_rapida.pressed.connect(_on_torre_rapida_pressed)
	botao_torre_basica.button_up.connect(_on_opcao_torre_button_up)
	botao_torre_rapida.button_up.connect(_on_opcao_torre_button_up)
	area_posicionamento.pressed.connect(_on_area_posicionamento_pressed)
	timer_previa_posicionamento.timeout.connect(_atualizar_previa_posicionamento)

	if caminho.curve == null or caminho.curve.get_baked_length() <= 0.0:
		push_error("O Path3D precisa ter uma curva com pelo menos dois pontos.")
		botao_jogo_play.disabled = true
	else:
		_criar_visual_do_caminho()

func spawn_queue():
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
	player_money += 1
	_atualizar_economia()

func _update_health_label() -> void:
	vida_label.text = "%d" % player_health

func _on_menu_play_pressed() -> void:
	menu_inicial.hide()
	menu_jogo.show()
	area_posicionamento.show()
	dinheiro_label.show()
	timer_previa_posicionamento.start()

func _on_torre_basica_pressed() -> void:
	_selecionar_torre("basica")

func _on_torre_rapida_pressed() -> void:
	_selecionar_torre("rapida")

func _selecionar_torre(tipo: String) -> void:
	if player_money < _custo_torre(tipo):
		status_construcao.text = "Saldo insuficiente para comprar essa torre."
		return
	tipo_torre_selecionada = tipo
	botao_torre_basica.button_pressed = tipo == "basica"
	botao_torre_rapida.button_pressed = tipo == "rapida"
	if tipo == "basica":
		status_construcao.text = "Torre básica selecionada. Segure e arraste até o terreno, ou clique para posicionar."
	else:
		status_construcao.text = "Torre rápida selecionada. Segure e arraste até o terreno, ou clique para posicionar."

func _on_area_posicionamento_pressed() -> void:
	_posicionar_torre_na_tela(get_viewport().get_mouse_position())

func _on_opcao_torre_button_up() -> void:
	# Segurar uma opção, arrastar até o terreno e soltar posiciona a torre.
	var posicao_tela := get_viewport().get_mouse_position()
	if not _painel_cobre_posicao(posicao_tela):
		_posicionar_torre_na_tela(posicao_tela)

func _posicionar_torre_na_tela(posicao_tela: Vector2) -> void:
	if tipo_torre_selecionada.is_empty():
		status_construcao.text = "Escolha uma torre antes de clicar no terreno."
		return
	var custo := _custo_torre(tipo_torre_selecionada)
	if player_money < custo:
		status_construcao.text = "Saldo insuficiente para comprar essa torre."
		_atualizar_economia()
		return

	if _painel_cobre_posicao(posicao_tela):
		return

	var origem := camera.project_ray_origin(posicao_tela)
	var direcao := camera.project_ray_normal(posicao_tela)
	var consulta := PhysicsRayQueryParameters3D.create(origem, origem + direcao * 1000.0)
	var resultado := get_world_3d().direct_space_state.intersect_ray(consulta)
	if resultado.is_empty() or resultado.collider != chao:
		status_construcao.text = "Clique em uma área livre do terreno para posicionar a torre."
		return

	var ponto_mundo: Vector3 = resultado.position
	if not _ponto_dentro_do_mapa(ponto_mundo):
		status_construcao.text = "Posicione a torre dentro do mapa."
		return
	if _esta_no_caminho(ponto_mundo):
		status_construcao.text = "Não é possível construir no caminho dos inimigos. Afaste a torre da rota."
		return

	var cena_torre: PackedScene = TOWER_BASIC_SCENE
	if tipo_torre_selecionada == "rapida":
		cena_torre = TOWER_FAST_SCENE
	var torre := cena_torre.instantiate() as CharacterBody3D

	add_child(torre)
	torre.global_position = ponto_mundo + Vector3.UP * 0.5
	var indicador_alcance := torre.get_node_or_null("IndicadorAlcance") as MeshInstance3D
	if indicador_alcance != null:
		indicador_alcance.position.y = malha_chao.global_position.y - ponto_mundo.y - 0.49
	player_money -= custo
	_atualizar_economia()
	status_construcao.text = "Torre posicionada por R$ %d. Saldo: R$ %d." % [custo, player_money]

func _custo_torre(tipo: String) -> int:
	return BASIC_TOWER_COST if tipo == "basica" else FAST_TOWER_COST

func _atualizar_economia() -> void:
	dinheiro_label.text = "R$ %d" % player_money
	botao_torre_basica.disabled = player_money < BASIC_TOWER_COST
	botao_torre_rapida.disabled = player_money < FAST_TOWER_COST
	if not tipo_torre_selecionada.is_empty() and player_money < _custo_torre(tipo_torre_selecionada):
		tipo_torre_selecionada = ""
		botao_torre_basica.button_pressed = false
		botao_torre_rapida.button_pressed = false
		if is_instance_valid(previa_alcance):
			previa_alcance.hide()

func _painel_cobre_posicao(posicao_tela: Vector2) -> bool:
	var painel := menu_jogo.get_node("Painel") as Control
	return menu_jogo.visible and painel.get_global_rect().has_point(posicao_tela)

func _ponto_dentro_do_mapa(posicao_mundo: Vector3) -> bool:
	var plano := malha_chao.mesh as PlaneMesh
	if plano == null:
		return true
	var ponto_local := malha_chao.to_local(posicao_mundo)
	return absf(ponto_local.x) <= plano.size.x * 0.5 and absf(ponto_local.z) <= plano.size.y * 0.5

func _esta_no_caminho(posicao_mundo: Vector3) -> bool:
	var pontos := caminho.curve.get_baked_points()
	var posicao_local := caminho.to_local(posicao_mundo)
	var ponto_2d := Vector2(posicao_local.x, posicao_local.z)
	var menor_distancia_quadrada := INF

	for i in range(pontos.size() - 1):
		var inicio := Vector2(pontos[i].x, pontos[i].z)
		var fim := Vector2(pontos[i + 1].x, pontos[i + 1].z)
		var segmento := fim - inicio
		var proporcao := 0.0
		if segmento.length_squared() > 0.000001:
			proporcao = clampf((ponto_2d - inicio).dot(segmento) / segmento.length_squared(), 0.0, 1.0)
		var ponto_mais_proximo := inicio + segmento * proporcao
		menor_distancia_quadrada = minf(menor_distancia_quadrada, ponto_2d.distance_squared_to(ponto_mais_proximo))

	var raio_livre: float = path_visual_width * 0.5 + 0.72 + path_placement_margin
	return menor_distancia_quadrada < raio_livre * raio_livre

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
	material.albedo_color = Color(0.78, 0.48, 0.22, 1.0)
	faixa.surface_set_material(0, material)

	var visual := MeshInstance3D.new()
	visual.name = "VisualCaminho"
	visual.mesh = faixa
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	caminho.add_child(visual)

func _on_game_play_pressed() -> void:
	menu_jogo.hide()
	area_posicionamento.hide()
	if is_instance_valid(previa_alcance):
		previa_alcance.hide()
	for torre in get_tree().get_nodes_in_group("torres"):
		var indicador := torre.get_node_or_null("IndicadorAlcance") as MeshInstance3D
		if indicador != null:
			indicador.hide()
	timer_previa_posicionamento.stop()
	get_tree().paused = false
	spawn_queue()

func _configurar_camera() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 18.0
	var centro_mapa := Vector3(-1.5, malha_chao.global_position.y, 5.0)
	camera.global_position = centro_mapa + Vector3(0.0, 20.0, 21.0)
	camera.look_at(centro_mapa, Vector3.UP)

func _atualizar_previa_posicionamento() -> void:
	if not menu_jogo.visible or tipo_torre_selecionada.is_empty():
		if is_instance_valid(previa_alcance):
			previa_alcance.hide()
		return

	var posicao_tela := get_viewport().get_mouse_position()
	if _painel_cobre_posicao(posicao_tela):
		if is_instance_valid(previa_alcance):
			previa_alcance.hide()
		return

	var origem := camera.project_ray_origin(posicao_tela)
	var direcao := camera.project_ray_normal(posicao_tela)
	var consulta := PhysicsRayQueryParameters3D.create(origem, origem + direcao * 1000.0)
	var resultado := get_world_3d().direct_space_state.intersect_ray(consulta)
	if resultado.is_empty() or resultado.collider != chao:
		if is_instance_valid(previa_alcance):
			previa_alcance.hide()
		return

	var ponto_mundo: Vector3 = resultado.position
	if not _ponto_dentro_do_mapa(ponto_mundo):
		if is_instance_valid(previa_alcance):
			previa_alcance.hide()
		return

	var alcance := BASIC_TOWER_RANGE if tipo_torre_selecionada == "basica" else FAST_TOWER_RANGE
	if not is_instance_valid(previa_alcance):
		previa_alcance = MeshInstance3D.new()
		previa_alcance.name = "PreviaAlcanceTorre"
		add_child(previa_alcance)
	if not is_equal_approx(raio_previa_alcance, alcance):
		previa_alcance.mesh = _criar_anel_alcance(alcance)
		raio_previa_alcance = alcance
	if material_previa_alcance == null:
		material_previa_alcance = StandardMaterial3D.new()
		material_previa_alcance.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material_previa_alcance.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material_previa_alcance.cull_mode = BaseMaterial3D.CULL_DISABLED
	previa_alcance.material_override = material_previa_alcance
	material_previa_alcance.albedo_color = Color(0.18, 0.82, 1.0, 0.8) if not _esta_no_caminho(ponto_mundo) else Color(1.0, 0.18, 0.14, 0.85)
	previa_alcance.global_position = Vector3(ponto_mundo.x, malha_chao.global_position.y + 0.01, ponto_mundo.z)
	previa_alcance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	previa_alcance.show()

func _criar_anel_alcance(alcance: float) -> ArrayMesh:
	var segmentos := 64
	var espessura := 0.055
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var raio_interno := maxf(0.0, alcance - espessura)
	for i in range(segmentos):
		var angulo := TAU * float(i) / float(segmentos)
		var cosseno := cos(angulo)
		var seno := sin(angulo)
		vertices.append(Vector3(cosseno * alcance, 0.0, seno * alcance))
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
	anel.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return anel
