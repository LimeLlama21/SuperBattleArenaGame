class_name NetworkManager
extends Node

## NetworkManager - Subsystem handling network peer lifecycle, matchmaking,
## client/server connection handshakes, disconnections, ping metrics, and peer replication.

signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal server_disconnected()
signal connection_failed()
signal connection_succeeded()
signal ping_updated(ping_ms: float)
signal connection_state_changed(state: String)

enum ConnectionState {
	DISCONNECTED,
	CONNECTING,
	CONNECTED,
	HOSTING,
	MATCHMAKING
}

var current_state: ConnectionState = ConnectionState.DISCONNECTED
var peer: ENetMultiplayerPeer = null
var current_port: int = 7000
var current_address: String = "127.0.0.1"

var ping: float = 0.0
var ping_timer: float = 0.0
var connected_peers: Array[int] = []

var main_game: Node = null

func _ready() -> void:
	if not main_game:
		var p = get_parent()
		if p and (p is Node3D or p.name == "Main"):
			main_game = p

func host_game(port: int = 7000, max_clients: int = 6) -> Error:
	current_port = port
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, max_clients)
	if err != OK:
		push_error("NetworkManager: Failed to host server on port %d, error %d" % [port, err])
		current_state = ConnectionState.DISCONNECTED
		connection_state_changed.emit("DISCONNECTED")
		return err

	multiplayer.multiplayer_peer = peer
	_setup_multiplayer_signals()
	current_state = ConnectionState.HOSTING
	connection_state_changed.emit("HOSTING")
	print("NetworkManager: Hosting server on port %d" % port)
	return OK

func join_game(address: String = "127.0.0.1", port: int = 7000) -> Error:
	current_address = address
	current_port = port
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(address, port)
	if err != OK:
		push_error("NetworkManager: Failed to connect to %s:%d, error %d" % [address, port, err])
		current_state = ConnectionState.DISCONNECTED
		connection_state_changed.emit("DISCONNECTED")
		return err

	multiplayer.multiplayer_peer = peer
	_setup_multiplayer_signals()
	current_state = ConnectionState.CONNECTING
	connection_state_changed.emit("CONNECTING")
	print("NetworkManager: Connecting to %s:%d..." % [address, port])
	return OK

func disconnect_game() -> void:
	if peer:
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = null
	connected_peers.clear()
	current_state = ConnectionState.DISCONNECTED
	connection_state_changed.emit("DISCONNECTED")
	server_disconnected.emit()

func _setup_multiplayer_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_peer_connected(id: int) -> void:
	if not connected_peers.has(id):
		connected_peers.append(id)
	print("NetworkManager: Peer connected: %d" % id)
	peer_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	connected_peers.erase(id)
	print("NetworkManager: Peer disconnected: %d" % id)
	peer_disconnected.emit(id)

func _on_connected_to_server() -> void:
	current_state = ConnectionState.CONNECTED
	connection_state_changed.emit("CONNECTED")
	print("NetworkManager: Connected to server successfully!")
	connection_succeeded.emit()

func _on_connection_failed() -> void:
	current_state = ConnectionState.DISCONNECTED
	connection_state_changed.emit("DISCONNECTED")
	print("NetworkManager: Connection failed!")
	connection_failed.emit()

func _on_server_disconnected() -> void:
	current_state = ConnectionState.DISCONNECTED
	connection_state_changed.emit("DISCONNECTED")
	print("NetworkManager: Server disconnected!")
	server_disconnected.emit()

func is_server() -> bool:
	return multiplayer and multiplayer.has_multiplayer_peer() and multiplayer.is_server()

func is_multiplayer_active() -> bool:
	return multiplayer and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0

func get_unique_id() -> int:
	return multiplayer.get_unique_id() if (multiplayer and multiplayer.has_multiplayer_peer()) else 1
