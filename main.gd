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
@onready var match_over_panel: PanelContainer = $UI/MatchOverPanel
@onready var winner_label: Label = $UI/MatchOverPanel/VBox/WinnerLabel

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
var match_in_progress: bool = false

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
	
	match_over_panel.hide()
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
	
	if multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		if multiplayer.is_server():
			if connected_players.has(1):
				connected_players[1]["character"] = selected_character
				sync_lobby_state.rpc(connected_players)
		else:
			update_player_character.rpc_id(1, selected_character)

func _on_host_pressed() -> void:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT)
	if error != OK:
		print("Server host creation failed: ", error)
		return

	multiplayer.multiplayer_peer = peer
	
	menu_panel.hide()
	lobby_panel.show()
	lobby_code_label.text = "ROOM CODE: LOCAL-01\n(Port: %d)" % PORT
	start_match_button.visible = true

	connected_players.clear()
	connected_players[1] = {"character": selected_character, "name": "Host (P1)"}
	_refresh_lobby_ui()

func _on_join_pressed() -> void:
	var raw_code = room_code_input.text.strip_edges()
	var target_ip = NetworkUtils.room_code_to_ip(raw_code)
	if target_ip.is_empty():
		target_ip = "127.0.0.1"

	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(target_ip, PORT)
	if error != OK:
		print("Failed client connection: ", error)
		return

	multiplayer.multiplayer_peer = peer
	menu_panel.hide()
	lobby_panel.show()
	lobby_code_label.text = "Connecting to %s..." % target_ip
	start_match_button.visible = false

func _on_connected_to_server() -> void:
	lobby_code_label.text = "Connected to Lobby!"
	register_player_to_server.rpc_id(1, selected_character)

func _on_connection_failed() -> void:
	lobby_panel.hide()
	menu_panel.show()
	multiplayer.multiplayer_peer = null

func _on_peer_connected(id: int) -> void:
	pass

func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		connected_players.erase(id)
		sync_lobby_state.rpc(connected_players)
		var player_node = players_container.get_node_or_null(str(id))
		if player_node:
			player_node.queue_free()
		if match_in_progress:
			_check_match_status()

@rpc("any_peer", "call_remote", "reliable")
func register_player_to_server(char_key: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	connected_players[sender_id] = {
		"character": char_key,
		"name": "Player " + str(sender_id)
	}
	sync_lobby_state.rpc(connected_players)

@rpc("any_peer", "call_remote", "reliable")
func update_player_character(char_key: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	if connected_players.has(sender_id):
		connected_players[sender_id]["character"] = char_key
		sync_lobby_state.rpc(connected_players)

@rpc("any_peer", "call_local", "reliable")
func sync_lobby_state(players_dict: Dictionary) -> void:
	connected_players = players_dict
	if not match_in_progress:
		menu_panel.hide()
		lobby_panel.show()
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

@rpc("any_peer", "call_local", "reliable")
func start_game() -> void:
	match_in_progress = true
	lobby_panel.hide()
	match_over_panel.hide()
	
	if multiplayer.is_server():
		for c in players_container.get_children():
			c.queue_free()
		for proj in projectiles_container.get_children():
			proj.queue_free()
			
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

func on_player_died(peer_id: int) -> void:
	if not multiplayer.is_server() or not match_in_progress:
		return
	_check_match_status()

func _check_match_status() -> void:
	var alive_players = []
	for p in players_container.get_children():
		if not p.get("is_dead"):
			alive_players.append(p)
	
	if alive_players.size() <= 1:
		var winner_str = "NO ONE"
		if alive_players.size() == 1:
			var w_node = alive_players[0]
			winner_str = "Host (P1)" if w_node.name == "1" else ("Player " + w_node.name)
		end_match.rpc(winner_str)

@rpc("any_peer", "call_local", "reliable")
func end_match(winner_name: String) -> void:
	match_in_progress = false
	winner_label.text = "MATCH OVER!\n%s WINS!" % winner_name.to_upper()
	match_over_panel.show()
	
	await get_tree().create_timer(3.5).timeout
	
	match_over_panel.hide()
	lobby_panel.show()
	_refresh_lobby_ui()
	
	if multiplayer.is_server():
		for c in players_container.get_children():
			c.queue_free()
		for proj in projectiles_container.get_children():
			proj.queue_free()

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
