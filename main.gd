extends Node2D

const PORT := 7000
const MAX_CLIENTS := 1
const PLAYER_SCENE := preload("res://player.tscn")

@onready var players: Node2D = $Players
@onready var status_label: Label = $CanvasLayer/Interface/StatusLabel
@onready var host_button: Button = $CanvasLayer/Interface/HostButton
@onready var join_button: Button = $CanvasLayer/Interface/JoinButton
@onready var address_line_edit: LineEdit = $CanvasLayer/Interface/AddressLineEdit

var match_finished := false

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, MAX_CLIENTS)
	if error != OK:
		status_label.text = "Não foi possível criar o servidor"
		return
	multiplayer.multiplayer_peer = peer
	set_connection_controls_enabled(false)
	status_label.text = "Servidor criado. Aguardando jogador"
	spawn_player(1)

func join_game(address: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, PORT)
	if error != OK:
		status_label.text = "Erro ao iniciar conexão: %s" % error_string(error)
		print("Erro create_client: ", error_string(error))
		set_connection_controls_enabled(true)
		return
	
	multiplayer.multiplayer_peer = peer
	set_connection_controls_enabled(false)
	status_label.text = "Conectando a %s:%d" % [address, PORT]


func _on_host_button_pressed() -> void:
	host_game()
	

func _on_join_button_pressed() -> void:
	var address : String = $CanvasLayer/Interface/AddressLineEdit.text.strip_edges()
	print(address)
	if address.is_empty():
		address = "127.0.0.1"
	status_label.text = "Tentando conectar a %s:%d" % [address, PORT]
	print("Tentando conectar a ", address, ":", PORT)
	join_game(address)
#
func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		spawn_player(id)
		
func spawn_player(id: int) -> void:
	if not multiplayer.is_server():
		return
	
	var player := PLAYER_SCENE.instantiate()
	player.name = str(id)
	player.position = $spawnHost.position if id == 1 else $spawnClient.position
	players.add_child(player, true)

func _on_peer_disconnected(id: int) -> void:
	var player := players.get_node_or_null(str(id))
	if player != null:
		player.queue_free()
	

func _on_portal_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server() or match_finished:
		return
	if not body.is_in_group("players"):
		return
	
	match_finished = true
	var winner_id := body.name.to_int()
	announce_winner.rpc(winner_id)
	await get_tree().create_timer(5.0).timeout
	if multiplayer.is_server():
		reset_round.rpc()

@rpc("authority", "call_local", "reliable")
func announce_winner(winner_id: int) -> void:
	status_label.text = "Jogador %s venceu! Nova rodada se inicia em 5 segundos." % winner_id
	for player in players.get_children():
		player.set_physics_process(false)

@rpc("authority", "call_local", "reliable")
func reset_round() -> void:
	for player in players.get_children():
		var player_id: int = player.name.to_int()
	
		if player_id == 1:
			player.position = $spawnHost.position
		else:
			player.position = $spawnClient.position

		player.velocity = Vector2.ZERO
		player.set_physics_process(true)

		var sprite: AnimatedSprite2D = (
			player.get_node("AnimatedSprite2D")
		)
		sprite.play("idle")

	match_finished = false
	status_label.text = "Nova rodada iniciada!"

func _on_connected_to_server() -> void:
	status_label.text = "Conectado ao servidor"

func _on_connection_failed() -> void:
	status_label.text = "Falha na conexão"
	multiplayer.multiplayer_peer = null
	set_connection_controls_enabled(true)

func _on_server_disconnected() -> void:
	status_label.text = "Servidor desconectado"
	multiplayer.multiplayer_peer = null
	set_connection_controls_enabled(true)
	
func set_connection_controls_enabled(enabled: bool) -> void:
	host_button.disabled = not enabled
	join_button.disabled = not enabled
	address_line_edit.editable = enabled
	
	host_button.visible = enabled
	join_button.visible = enabled
	address_line_edit.visible = enabled

	if enabled:
		host_button.focus_mode = Control.FOCUS_ALL
		join_button.focus_mode = Control.FOCUS_ALL
		address_line_edit.focus_mode = Control.FOCUS_ALL
	else:
		host_button.focus_mode = Control.FOCUS_NONE
		join_button.focus_mode = Control.FOCUS_NONE
		address_line_edit.focus_mode = Control.FOCUS_NONE

		# Remove o foco de qualquer controle da interface.
		get_viewport().gui_release_focus()
