extends Node3D

const PORT: int = 7000

const CHARACTERS: Dictionary = {
	"poke": preload("res://hunters/poke.tscn"),
	"crush": preload("res://hunters/crush.tscn"),
	"dive": preload("res://hunters/dive.tscn")
}

@export var projectile_scene: PackedScene = preload("res://projectile.tscn")
@export var terrain_scene: PackedScene = preload("res://temporary_terrain.tscn")
@export var vision_flare_scene: PackedScene = preload("res://vision_flare.tscn")
@export var vision_reveal_zone_scene: PackedScene = preload("res://vision_reveal_zone.tscn")

@onready var players_container: Node3D = $Players
@onready var projectiles_container: Node3D = $Projectiles
@onready var terrain_container: Node3D = $TerrainObjects
@onready var vision_container: Node3D = $VisionZones
@onready var spawn_points: Node3D = $SpawnPoints
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var projectile_spawner: MultiplayerSpawner = $ProjectileSpawner
@onready var terrain_spawner: MultiplayerSpawner = $TerrainSpawner
@onready var vision_spawner: MultiplayerSpawner = $VisionSpawner

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
@onready var select_dive_button: Button = $UI/LobbyRoom/VBox/HBoxSelect/SelectDive
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
	select_dive_button.pressed.connect(func(): _select_character("dive"))
	start_match_button.pressed.connect(_on_start_match_pressed)
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	
	player_spawner.spawn_function = _custom_spawn_player
	projectile_spawner.spawn_function = _custom_spawn_projectile
	terrain_spawner.spawn_function = _custom_spawn_terrain
	vision_spawner.spawn_function = _custom_spawn_vision_zone
	
	match_over_panel.hide()
	_select_character("poke")

func _select_character(char_key: String) -> void:
	selected_character = char_key
	select_poke_button.text = "Poke (Select)"
	select_crush_button.text = "Crush (Select)"
	select_dive_button.text = "Dive (Select)"

	if char_key == "poke":
		select_poke_button.text = "★ Poke (Selected)"
		char_desc_label.text = "POKE: Sniper (80 HP). [LMB]: Rail shots (50 dmg). [RMB]: Repulsor bolt (knockback + stun). [Q]: Recon Flare (multi-screen vision dart + lingering reveal zone). Dash: 4s."
	elif char_key == "crush":
		select_crush_button.text = "★ Crush (Selected)"
		char_desc_label.text = "CRUSH: Juggernaut (160 HP). [LMB]: Slam (55 dmg). [RMB]: Fan ground stun. [Q]: Fortify shockwave (20 dmg, slow + 40 shield). Dash: 8s."
	elif char_key == "dive":
		select_dive_button.text = "★ Dive (Selected)"
		char_desc_label.text = "DIVE: Striker (100 HP). [LMB]: Melee thrust (65 dmg). [RMB]: Slow dart. [Q]: Channel -> Earth Tremor creating terrain pillar! Dash: 2 charges."
	
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
		for terr in terrain_container.get_children():
			terr.queue_free()
		for v in vision_container.get_children():
			v.queue_free()
			
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
		for terr in terrain_container.get_children():
			terr.queue_free()
		for v in vision_container.get_children():
			v.queue_free()

func spawn_projectile(pos: Vector3, dir: Vector3, shooter_id: int, dmg: float = 50.0, spd: float = 70.0, p_size: float = 1.0, life: float = 2.5, eff_type: String = "", eff_dur: float = 0.0, eff_int: float = 0.0, pierce: bool = false, spawn_terr: bool = false) -> void:
	if not multiplayer.is_server():
		return
	
	var spawn_data = {
		"pos": pos,
		"dir": dir,
		"shooter_id": shooter_id,
		"dmg": dmg,
		"spd": spd,
		"size": p_size,
		"life": life,
		"eff_type": eff_type,
		"eff_dur": eff_dur,
		"eff_int": eff_int,
		"pierce": pierce,
		"spawn_terr": spawn_terr
	}
	projectile_spawner.spawn(spawn_data)

func _custom_spawn_projectile(data: Variant) -> Node:
	var proj = projectile_scene.instantiate()
	proj.shooter_id = data["shooter_id"]
	proj.direction = data["dir"]
	proj.damage = data.get("dmg", 50.0)
	proj.speed = data.get("spd", 70.0)
	proj.size = data.get("size", 1.0)
	proj.lifetime = data.get("life", 2.5)
	proj.effect_type = data.get("eff_type", "")
	proj.effect_duration = data.get("eff_dur", 0.0)
	proj.effect_intensity = data.get("eff_int", 0.0)
	proj.pierces = data.get("pierce", false)
	proj.spawn_terrain_on_death = data.get("spawn_terr", false)
	proj.position = data["pos"]
	return proj

func spawn_temporary_terrain(pos: Vector3, lifetime: float = 5.0) -> void:
	if not multiplayer.is_server():
		return
	var data = {
		"pos": pos,
		"lifetime": lifetime
	}
	terrain_spawner.spawn(data)

func _custom_spawn_terrain(data: Variant) -> Node:
	var terrain = terrain_scene.instantiate()
	terrain.position = data["pos"]
	terrain.lifetime = data.get("lifetime", 5.0)
	return terrain

func spawn_vision_flare(pos: Vector3, dir: Vector3, target_dist: float, shooter_id: int = 0) -> void:
	if not multiplayer.is_server():
		return
	var flare = vision_flare_scene.instantiate()
	flare.position = pos
	flare.direction = dir
	flare.target_distance = target_dist
	flare.shooter_id = shooter_id
	projectiles_container.add_child(flare, true)

func spawn_vision_reveal_zone(pos: Vector3, rad: float = 12.0, lifetime: float = 5.5, owner_id: int = 0) -> void:
	if not multiplayer.is_server():
		return
	var data = {
		"pos": pos,
		"rad": rad,
		"life": lifetime,
		"owner_id": owner_id
	}
	vision_spawner.spawn(data)

func _custom_spawn_vision_zone(data: Variant) -> Node:
	var zone = vision_reveal_zone_scene.instantiate()
	zone.position = data["pos"]
	zone.radius = data.get("rad", 12.0)
	zone.lifetime = data.get("life", 5.5)
	zone.owner_id = data.get("owner_id", 0)
	return zone
