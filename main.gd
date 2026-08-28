extends Node3D

const PORT: int = 7000

const CHARACTERS: Dictionary = {
	"poke": preload("res://hunter_poke.tscn"),
	"crush": preload("res://hunter_crush.tscn")
}

@export var projectile_scene: PackedScene = preload("res://projectile.tscn")

@onready var players_container: Node3D = $Players
@onready var projectiles_container: Node3D = $Projectiles
@onready var spawn_points: Node3D = $SpawnPoints
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var projectile_spawner: MultiplayerSpawner = $ProjectileSpawner

@onready var menu_panel: PanelContainer = $UI/MainMenu
@onready var lobby_panel: PanelContainer = $UI/LobbyRoom
@onready var host_button: Button = $UI/MainMenu/VBox/HostButton
@onready var room_code_input: LineEdit = $UI/MainMenu/VBox/RoomCodeInput
@onready var join_button: Button = $UI/MainMenu/VBox/JoinButton

@onready var lobby_code_label: Label = $UI/LobbyRoom/VBox/RoomCodeDisplay
@onready var player_list_label: Label = $UI/LobbyRoom/VBox/PlayerListLabel
@onready var select_poke_button: Button = $UI/LobbyRoom/VBox/HBoxSelect/SelectPoke
@onready var select_crush_button: Button = $UI/LobbyRoom/VBox/HBoxSelect/SelectCrush
@onready var char_desc_label: Label = $UI/LobbyRoom/VBox/CharDescLabel
@onready var start_match_button: Button = $UI/LobbyRoom/VBox/StartMatchButton

var selected_character: String = "poke"
var connected_players: Dictionary = {}
var upnp: UPNP

func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	select_poke_button.pressed.connect(func(): _select_character("poke"))
	select_crush_button.pressed.connect(func(): _select_character("crush"))
	start_match_button.pressed.connect(_on_start_match_pressed)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	
	player_spawner.spawn_function = _custom_spawn_player
	projectile_spawner.spawn_function = _custom_spawn_projectile
	
	_select_character("poke")

func _select_character(char_key: String) -> void:
	selected_character = char_key
	if char_key == "poke":
		select_poke_button.text = "★ Poke (Selected)"
		select_crush_button.text = "Crush (Select)"
		char_desc_label.text = "POKE: Agile Ranged Scout. Fast skillshot blasters (22 dmg), Dash Cooldown: 4.0s (80 HP)."
	else:
		select_poke_button.text = "Poke (Select)"
		select_crush_button.text = "★ Crush (Selected)"
		char_desc_label.text = "CRUSH: Heavy Melee Juggernaut. Area Slam (55 dmg, 0.28s cast), Dash Cooldown: 8.0s (160 HP)."
	
	if multiplayer.multiplayer_peer:
		update_player_character.rpc_id(1, multiplayer.get_unique_id(), selected_character)

func _on_host_pressed() -> void:
	upnp = UPNP.new()
	var external_ip = "127.0.0.1"
	var upnp_res = upnp.discover()
	if upnp_res == UPNP.UPNP_RESULT_SUCCESS and upnp.get_gateway() and upnp.get_gateway().is_valid_gateway():
		upnp.add_port_mapping(PORT, PORT, "SuperviveRoom", "UDP")
		external_ip = upnp.query_external_address()
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT)
	if error != OK:
		print("Server host creation failed: ", error)
		return

	multiplayer.multiplayer_peer = peer
	var room_code = NetworkUtils.ip_to_room_code(external_ip)
	
	menu_panel.hide()
	lobby_panel.show()
	lobby_code_label.text = "ROOM CODE: %s\n(Direct IP: %s)" % [room_code, external_ip]
	start_match_button.visible = true

	connected_players[1] = {"character": selected_character, "name": "Host (P1)"}
	_refresh_lobby_ui()

func _on_join_pressed() -> void:
	var raw_code = room_code_input.text.strip_edges()
	var target_ip = NetworkUtils.room_code_to_ip(raw_code)

	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(target_ip, PORT)
	if error != OK:
		print("Failed client connection: ", error)
		return

	multiplayer.multiplayer_peer = peer
	menu_panel.hide()
	lobby_panel.show()
	lobby_code_label.text = "Connecting to: %s..." % raw_code.to_upper()
	start_match_button.visible = false

func _on_connected_to_server() -> void:
	lobby_code_label.text = "Connected to Lobby!"
	update_player_character.rpc_id(1, multiplayer.get_unique_id(), selected_character)

func _on_connection_failed() -> void:
	lobby_panel.hide()
	menu_panel.show()
	multiplayer.multiplayer_peer = null

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		connected_players[id] = {"character": "poke", "name": "Player " + str(id)}
		sync_lobby_state.rpc(connected_players)

func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		connected_players.erase(id)
		sync_lobby_state.rpc(connected_players)
		var player_node = players_container.get_node_or_null(str(id))
		if player_node:
			player_node.queue_free()

@rpc("any_peer", "call_local", "reliable")
func update_player_character(peer_id: int, char_key: String) -> void:
	if multiplayer.is_server():
		if not connected_players.has(peer_id):
			connected_players[peer_id] = {"name": "Player " + str(peer_id)}
		connected_players[peer_id]["character"] = char_key
		sync_lobby_state.rpc(connected_players)

@rpc("authority", "call_local", "reliable")
func sync_lobby_state(players_dict: Dictionary) -> void:
	connected_players = players_dict
	_refresh_lobby_ui()

func _refresh_lobby_ui() -> void:
	var list_text = "Players in Lobby:\n"
	for pid in connected_players.keys():
		var pinfo = connected_players[pid]
		list_text += "• %s — Selected: [%s]\n" % [pinfo.get("name", str(pid)), pinfo.get("character", "poke").to_upper()]
	player_list_label.text = list_text

func _on_start_match_pressed() -> void:
	if not multiplayer.is_server():
		return
	start_game.rpc()

@rpc("authority", "call_local", "reliable")
func start_game() -> void:
	lobby_panel.hide()
	
	if multiplayer.is_server():
		var p_ids = connected_players.keys()
		for i in range(p_ids.size()):
			var pid = p_ids[i]
			var char_choice = connected_players[pid].get("character", "poke")
			var spawn_pos = Vector3.ZERO
			if spawn_points.get_child_count() > i:
				spawn_pos = spawn_points.get_child(i).global_position
			
			var spawn_payload = {
				"peer_id": pid,
				"character": char_choice,
				"pos": spawn_pos
			}
			player_spawner.spawn(spawn_payload)

func _custom_spawn_player(data: Variant) -> Node:
	var char_key = data.get("character", "poke")
	var packed_scene = CHARACTERS.get(char_key, CHARACTERS["poke"])
	var player_instance = packed_scene.instantiate()
	player_instance.name = str(data["peer_id"])
	player_instance.position = data["pos"]
	return player_instance

func spawn_projectile(pos: Vector3, dir: Vector3, shooter_id: int, dmg: float = 22.0, spd: float = 34.0) -> void:
	if not multiplayer.is_server():
		return
	
	var spawn_data = {
		"pos": pos,
		"dir": dir,
		"shooter_id": shooter_id,
		"dmg": dmg,
		"spd": spd
	}
	projectile_spawner.spawn(spawn_data)

func _custom_spawn_projectile(data: Variant) -> Node:
	var proj = projectile_scene.instantiate()
	proj.shooter_id = data["shooter_id"]
	proj.direction = data["dir"]
	proj.damage = data.get("dmg", 22.0)
	proj.speed = data.get("spd", 34.0)
	proj.position = data["pos"]
	return proj
