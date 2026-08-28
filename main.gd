extends Node3D

const PORT: int = 7000
const DEFAULT_IP: String = "127.0.0.1"

@export var player_scene: PackedScene = preload("res://player.tscn")
@export var projectile_scene: PackedScene = preload("res://projectile.tscn")

@onready var players_container: Node3D = $Players
@onready var projectiles_container: Node3D = $Projectiles
@onready var spawn_points: Node3D = $SpawnPoints
@onready var ui: CanvasLayer = $UI
@onready var host_button: Button = $UI/Menu/VBox/HostButton
@onready var address_input: LineEdit = $UI/Menu/VBox/AddressInput
@onready var join_button: Button = $UI/Menu/VBox/JoinButton
@onready var projectile_spawner: MultiplayerSpawner = $ProjectileSpawner

func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	
	projectile_spawner.spawn_function = _custom_spawn_projectile

func _on_host_pressed() -> void:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT)
	if error != OK:
		print("Failed to host server: ", error)
		return

	multiplayer.multiplayer_peer = peer
	ui.hide()
	spawn_player(1)

func _on_join_pressed() -> void:
	var ip = address_input.text.strip_edges()
	if ip.is_empty():
		ip = DEFAULT_IP

	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, PORT)
	if error != OK:
		print("Failed to start client connection: ", error)
		return

	multiplayer.multiplayer_peer = peer

func _on_connected_to_server() -> void:
	ui.hide()

func _on_connection_failed() -> void:
	print("Connection to server failed.")
	multiplayer.multiplayer_peer = null

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		spawn_player(id)

func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		var player_node = players_container.get_node_or_null(str(id))
		if player_node:
			player_node.queue_free()

func spawn_player(id: int) -> void:
	var player = player_scene.instantiate()
	player.name = str(id)

	var spawn_index = 0
	if id != 1 and spawn_points.get_child_count() > 1:
		spawn_index = 1
	
	var spawn_pos = Vector3.ZERO
	if spawn_points.get_child_count() > 0:
		spawn_pos = spawn_points.get_child(spawn_index).global_position
	
	player.position = spawn_pos
	player.velocity = Vector3.ZERO
	players_container.add_child(player, true)

func spawn_projectile(pos: Vector3, dir: Vector3, shooter_id: int) -> void:
	if not multiplayer.is_server():
		return
	
	var spawn_data = {
		"pos": pos,
		"dir": dir,
		"shooter_id": shooter_id
	}
	projectile_spawner.spawn(spawn_data)

func _custom_spawn_projectile(data: Variant) -> Node:
	var proj = projectile_scene.instantiate()
	proj.shooter_id = data["shooter_id"]
	proj.direction = data["dir"]
	proj.position = data["pos"]
	return proj
