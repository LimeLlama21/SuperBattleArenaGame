extends Node3D

const PORT: int = 7000

const CHARACTERS: Dictionary = {
	"poke": preload("res://characters/poke/poke.tscn"),
	"crush": preload("res://characters/crush/crush.tscn"),
	"dive": preload("res://characters/dive/dive.tscn"),
	"reaper": preload("res://characters/reaper/reaper.tscn"),
	"morrigan": preload("res://characters/morrigan/morrigan.tscn")
}

@export var projectile_scene: PackedScene = preload("res://projectile.tscn")
@export var terrain_scene: PackedScene = preload("res://temporary_terrain.tscn")
@export var vision_flare_scene: PackedScene = preload("res://vision_flare.tscn")
@export var vision_reveal_zone_scene: PackedScene = preload("res://vision_reveal_zone.tscn")
@export var slowing_dot_zone_scene: PackedScene = preload("res://slowing_dot_zone.tscn")
@export var fence_zone_scene: PackedScene = preload("res://fence_zone.tscn")

@export var training_dummy_scene: PackedScene = preload("res://training_dummy.tscn")

@onready var players_container: Node3D = $Players
@onready var projectiles_container: Node3D = $Projectiles
@onready var terrain_container: Node3D = $TerrainObjects
@onready var vision_container: Node3D = $VisionZones
@onready var hazard_container: Node3D = $HazardZones
@onready var spawn_points: Node3D = $SpawnPoints
@onready var default_map: Node3D = get_node_or_null("Arena/DefaultMap")
@onready var training_map: Node3D = get_node_or_null("Arena/TrainingMap")

@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var projectile_spawner: MultiplayerSpawner = $ProjectileSpawner
@onready var terrain_spawner: MultiplayerSpawner = $TerrainSpawner
@onready var vision_spawner: MultiplayerSpawner = $VisionSpawner
@onready var hazard_spawner: MultiplayerSpawner = $HazardSpawner

@onready var menu_panel: PanelContainer = $UI/MainMenu
@onready var lobby_panel: PanelContainer = $UI/LobbyRoom
@onready var match_over_panel: PanelContainer = $UI/MatchOverPanel
@onready var winner_label: Label = $UI/MatchOverPanel/VBox/WinnerLabel

@onready var host_button: Button = $UI/MainMenu/VBox/HostButton
@onready var join_button: Button = $UI/MainMenu/VBox/JoinButton
@onready var training_button: Button = $UI/MainMenu/VBox/TrainingButton
@onready var main_settings_button: Button = $UI/MainMenu/VBox/SettingsButton
@onready var main_quit_button: Button = get_node_or_null("UI/MainMenu/VBox/QuitButton")

@onready var join_dialog: PanelContainer = $UI/JoinDialog
@onready var host_ip_input: LineEdit = $UI/JoinDialog/VBox/HostIPInput
@onready var cancel_join_button: Button = $UI/JoinDialog/VBox/HBox/CancelButton
@onready var confirm_join_button: Button = $UI/JoinDialog/VBox/HBox/ConfirmJoinButton

@onready var lobby_ip_label: Label = $UI/LobbyRoom/VBox/HostIPDisplay
@onready var select_poke_button: Button = $UI/LobbyRoom/VBox/HBoxSelect/SelectPoke
@onready var select_crush_button: Button = $UI/LobbyRoom/VBox/HBoxSelect/SelectCrush
@onready var select_dive_button: Button = $UI/LobbyRoom/VBox/HBoxSelect/SelectDive
@onready var select_reaper_button: Button = get_node_or_null("UI/LobbyRoom/VBox/HBoxSelect/SelectReaper")
@onready var select_morrigan_button: Button = get_node_or_null("UI/LobbyRoom/VBox/HBoxSelect/SelectMorrigan")
@onready var char_desc_label: Label = $UI/LobbyRoom/VBox/CharDescLabel
@onready var team_section: VBoxContainer = $UI/LobbyRoom/VBox/TeamSection
@onready var lobby_back_button: Button = $UI/LobbyRoom/VBox/HBoxLobbyActions/LobbyBackButton
@onready var start_match_button: Button = $UI/LobbyRoom/VBox/HBoxLobbyActions/StartMatchButton

@onready var escape_panel: PanelContainer = $UI/EscapeMenu
@onready var escape_tab_container: TabContainer = $UI/EscapeMenu/VBox/EscapeTabContainer
@onready var escape_title_label: Label = $UI/EscapeMenu/VBox/EscapeTabContainer/Menu/Title
@onready var resume_button: Button = $UI/EscapeMenu/VBox/EscapeTabContainer/Menu/ResumeButton
@onready var escape_settings_button: Button = $UI/EscapeMenu/VBox/EscapeTabContainer/Menu/SettingsButton
@onready var exit_match_button: Button = $UI/EscapeMenu/VBox/EscapeTabContainer/Menu/ExitMatchButton
@onready var leave_match_button: Button = $UI/EscapeMenu/VBox/EscapeTabContainer/Menu/LeaveMatchButton

@onready var switch_poke_btn: Button = $"UI/EscapeMenu/VBox/EscapeTabContainer/Switch Character/SwitchPoke"
@onready var switch_crush_btn: Button = $"UI/EscapeMenu/VBox/EscapeTabContainer/Switch Character/SwitchCrush"
@onready var switch_dive_btn: Button = $"UI/EscapeMenu/VBox/EscapeTabContainer/Switch Character/SwitchDive"
@onready var switch_reaper_btn: Button = get_node_or_null("UI/EscapeMenu/VBox/EscapeTabContainer/Switch Character/SwitchReaper")
@onready var switch_morrigan_btn: Button = get_node_or_null("UI/EscapeMenu/VBox/EscapeTabContainer/Switch Character/SwitchMorrigan")

@onready var settings_panel: PanelContainer = $UI/SettingsMenu

@onready var t1_slots: Array[Button] = [
	$UI/LobbyRoom/VBox/TeamSection/HBoxTeams/VBoxTeam1/T1Slot0,
	$UI/LobbyRoom/VBox/TeamSection/HBoxTeams/VBoxTeam1/T1Slot1,
	$UI/LobbyRoom/VBox/TeamSection/HBoxTeams/VBoxTeam1/T1Slot2
]

@onready var t2_slots: Array[Button] = [
	$UI/LobbyRoom/VBox/TeamSection/HBoxTeams/VBoxTeam2/T2Slot0,
	$UI/LobbyRoom/VBox/TeamSection/HBoxTeams/VBoxTeam2/T2Slot1,
	$UI/LobbyRoom/VBox/TeamSection/HBoxTeams/VBoxTeam2/T2Slot2
]

var selected_character: String = "poke"
var connected_players: Dictionary = {}
var match_in_progress: bool = false
var is_training_mode: bool = false

var active_upnp: UPNP = null
var upnp_thread: Thread = null

func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	cancel_join_button.pressed.connect(func(): join_dialog.hide())
	confirm_join_button.pressed.connect(_on_confirm_join_pressed)
	host_ip_input.text_submitted.connect(func(_t): _on_confirm_join_pressed())
	training_button.pressed.connect(_on_training_pressed)
	main_settings_button.pressed.connect(_open_settings_menu)
	if main_quit_button:
		main_quit_button.pressed.connect(_on_quit_game_pressed)
	select_poke_button.pressed.connect(func(): _select_character("poke"))
	select_crush_button.pressed.connect(func(): _select_character("crush"))
	select_dive_button.pressed.connect(func(): _select_character("dive"))
	if select_reaper_button:
		select_reaper_button.pressed.connect(func(): _select_character("reaper"))
	if select_morrigan_button:
		select_morrigan_button.pressed.connect(func(): _select_character("morrigan"))
	lobby_back_button.pressed.connect(_on_lobby_back_pressed)
	start_match_button.pressed.connect(_on_start_match_pressed)
	
	resume_button.pressed.connect(func(): escape_panel.hide())
	escape_settings_button.pressed.connect(_open_settings_menu)
	exit_match_button.pressed.connect(_on_exit_match_pressed)
	leave_match_button.pressed.connect(_on_leave_match_pressed)
	
	switch_poke_btn.pressed.connect(func(): _switch_training_character("poke"))
	switch_crush_btn.pressed.connect(func(): _switch_training_character("crush"))
	switch_dive_btn.pressed.connect(func(): _switch_training_character("dive"))
	if switch_reaper_btn:
		switch_reaper_btn.pressed.connect(func(): _switch_training_character("reaper"))
	if switch_morrigan_btn:
		switch_morrigan_btn.pressed.connect(func(): _switch_training_character("morrigan"))
	
	if settings_panel and settings_panel.has_signal("settings_closed"):
		settings_panel.settings_closed.connect(_on_settings_closed)
	
	for i in range(3):
		var s_idx = i
		t1_slots[i].pressed.connect(func(): _on_slot_clicked(1, s_idx))
		t2_slots[i].pressed.connect(func(): _on_slot_clicked(2, s_idx))
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	
	player_spawner.spawn_function = _custom_spawn_player
	projectile_spawner.spawn_function = _custom_spawn_projectile
	terrain_spawner.spawn_function = _custom_spawn_terrain
	vision_spawner.spawn_function = _custom_spawn_vision_zone
	hazard_spawner.spawn_function = _custom_spawn_hazard_zone
	
	match_over_panel.hide()
	_select_character("poke")

func _select_character(char_key: String) -> void:
	selected_character = char_key
	select_poke_button.text = "Poke (Select)"
	select_crush_button.text = "Crush (Select)"
	select_dive_button.text = "Dive (Select)"
	if select_reaper_button:
		select_reaper_button.text = "Reaper (Select)"
	if select_morrigan_button:
		select_morrigan_button.text = "Morrigan (Select)"

	if char_key == "poke":
		select_poke_button.text = "★ Poke (Selected)"
		char_desc_label.text = "POKE: Sniper (80 HP). Passive [Fleet Foot]: +15% MS on hit. [LMB]: Rail shot. [RMB]: Repulsor. [Q]: Ion Fence (thin line + 2.5s ground). [E]: Recon Flare."
	elif char_key == "crush":
		select_crush_button.text = "★ Crush (Selected)"
		char_desc_label.text = "CRUSH: Juggernaut (160 HP). Passive [Titan's Surge]: Spells empower LMB (+25 dmg + heal). [LMB]: Slam. [RMB]: Fan stun. [Q]: Shockwave & Shield. [E]: Iron Blood (converts Gray Health to shield / regens)."
	elif char_key == "dive":
		select_dive_button.text = "★ Dive (Selected)"
		char_desc_label.text = "DIVE: Striker (100 HP). Passive [Rupture Marks]: Stacking burst marks. [LMB]: Slash. [RMB]: Cleave. [Q]: Earth Tremor. [E]: Deflecting Guard (75% frontal DR). [Shift]: Wall Bounce."
	elif char_key == "reaper":
		if select_reaper_button:
			select_reaper_button.text = "★ Reaper (Selected)"
		char_desc_label.text = "REAPER: Assassin / Skirmisher (90 HP). Passive [Soul Harvest]: +15% MS steal on LMB. [RMB]: Spectral Tether (Charged throw: grounds + progressive slow -> roots & disables all movement). [Q]: Cull the Weak (sweet-spot donut sweep + cripple). [E]: Nightmare (Vlad pool invulnerability + slow). [R]: One with Death (+45% MS, +50% CDR, +30% DMG). [Shift]: Ethereal Dash."
	elif char_key == "morrigan":
		if select_morrigan_button:
			select_morrigan_button.text = "★ Morrigan (Selected)"
		char_desc_label.text = "MORRIGAN: Mage (90 HP). Passive [Harbinger of Doom]: Ability hits spawn orbiting crows that seek nearby enemies (20 dmg + 35% slow). [LMB]: Black Plumage (Chargeable up to 5 rapid burst feathers). [RMB]: Omen of Death (Parabolic mortar shell). [Q]: Inescapable Ends (Dual-cast magnetic tether). [E]: Cry of the Banshee (Large cone shriek + 1.4s silence). [R]: Born of Blood (1s channel -> massive 45m piercing wave + stun). [Shift]: Crowstorm (Steered flight + 60% MS + 50% DR)."
	
	if multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		if multiplayer.is_server():
			if connected_players.has(1):
				connected_players[1]["character"] = selected_character
				sync_lobby_state.rpc(connected_players)
		else:
			update_player_character.rpc_id(1, selected_character)

func _on_slot_clicked(team: int, slot: int) -> void:
	if not multiplayer.multiplayer_peer or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	if multiplayer.is_server():
		_assign_player_slot(1, team, slot)
	else:
		request_team_slot.rpc_id(1, team, slot)

func _find_first_available_slot() -> Dictionary:
	for s in range(3):
		for t in [1, 2]:
			var occupied = false
			for pid in connected_players.keys():
				var p = connected_players[pid]
				if p.get("team", 1) == t and p.get("slot", 0) == s:
					occupied = true
					break
			if not occupied:
				return {"team": t, "slot": s}
	return {"team": 1, "slot": 0}

func _assign_player_slot(pid: int, team: int, slot: int) -> void:
	if not connected_players.has(pid):
		return
	for other_id in connected_players.keys():
		if other_id != pid:
			var op = connected_players[other_id]
			if op.get("team", 1) == team and op.get("slot", 0) == slot:
				return # Slot already occupied
	
	connected_players[pid]["team"] = team
	connected_players[pid]["slot"] = slot
	sync_lobby_state.rpc(connected_players)

@rpc("any_peer", "call_remote", "reliable")
func request_team_slot(team: int, slot: int) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_assign_player_slot(sender_id, team, slot)

func _on_training_pressed() -> void:
	is_training_mode = true
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT)
	if error != OK:
		print("Local training session peer init: ", error)
	multiplayer.multiplayer_peer = peer
	
	menu_panel.hide()
	lobby_panel.show()
	lobby_ip_label.text = "🎯 SOLO TRAINING SESSION"
	start_match_button.visible = true

	connected_players.clear()
	connected_players[1] = {
		"character": selected_character,
		"name": "Player 1",
		"team": 1,
		"slot": 0
	}
	_refresh_lobby_ui()

func _on_host_pressed() -> void:
	is_training_mode = false
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT)
	if error != OK:
		print("Server host creation failed: ", error)
		return

	multiplayer.multiplayer_peer = peer
	
	menu_panel.hide()
	join_dialog.hide()
	lobby_panel.show()
	start_match_button.visible = true

	var local_ip = NetworkUtils.get_local_ipv4()
	lobby_ip_label.text = "HOST IP: %s" % local_ip

	connected_players.clear()
	var slot_info = _find_first_available_slot()
	connected_players[1] = {
		"character": selected_character,
		"name": "Host (P1)",
		"team": slot_info["team"],
		"slot": slot_info["slot"]
	}
	_refresh_lobby_ui()
	_start_upnp_discovery(PORT, local_ip)

func _on_join_pressed() -> void:
	join_dialog.show()
	host_ip_input.text = ""
	host_ip_input.grab_focus()

func _on_confirm_join_pressed() -> void:
	var raw_ip = host_ip_input.text.strip_edges()
	if raw_ip.is_empty():
		raw_ip = "127.0.0.1"

	is_training_mode = false
	var target_ip = NetworkUtils.clean_host_ip(raw_ip)

	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(target_ip, PORT)
	if error != OK:
		print("Failed client connection: ", error)
		return

	multiplayer.multiplayer_peer = peer
	join_dialog.hide()
	menu_panel.hide()
	lobby_panel.show()
	lobby_ip_label.text = "HOST IP: %s (Connecting...)" % target_ip
	start_match_button.visible = false

func _on_connected_to_server() -> void:
	var raw_ip = host_ip_input.text.strip_edges()
	var target_ip = NetworkUtils.clean_host_ip(raw_ip)
	lobby_ip_label.text = "HOST IP: %s" % target_ip
	register_player_to_server.rpc_id(1, selected_character)

func _on_connection_failed() -> void:
	lobby_panel.hide()
	join_dialog.hide()
	menu_panel.show()
	multiplayer.multiplayer_peer = null

func _on_peer_connected(_id: int) -> void:
	pass

func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		connected_players.erase(id)
		sync_lobby_state.rpc(connected_players)
		var player_node = players_container.get_node_or_null(str(id))
		if player_node:
			player_node.queue_free()
		cleanup_player_entities(id)
		if match_in_progress:
			_check_match_status()

func cleanup_player_entities(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	for proj in projectiles_container.get_children():
		if proj.get("shooter_id") == peer_id:
			proj.queue_free()
	for terr in terrain_container.get_children():
		if terr.get("owner_id") == peer_id:
			terr.queue_free()
	for v in vision_container.get_children():
		if v.get("owner_id") == peer_id or v.get("shooter_id") == peer_id:
			v.queue_free()
	for h in hazard_container.get_children():
		if h.get("shooter_id") == peer_id:
			h.queue_free()

@rpc("any_peer", "call_remote", "reliable")
func register_player_to_server(char_key: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var slot_info = _find_first_available_slot()
	connected_players[sender_id] = {
		"character": char_key,
		"name": "Player " + str(sender_id),
		"team": slot_info["team"],
		"slot": slot_info["slot"]
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
	var my_id = multiplayer.get_unique_id()
	
	if is_training_mode:
		if team_section:
			team_section.hide()
		start_match_button.disabled = false
		start_match_button.text = "ENTER TRAINING ARENA"
		return
		
	if team_section:
		team_section.show()
	
	var t1_count = 0
	var t2_count = 0
	
	# Team 1 slots
	for s in range(3):
		var btn = t1_slots[s]
		var occupant = null
		var occ_id = 0
		for pid in connected_players.keys():
			var p = connected_players[pid]
			if p.get("team", 1) == 1 and p.get("slot", 0) == s:
				occupant = p
				occ_id = pid
				t1_count += 1
				break
		
		if occupant != null:
			var char_name = occupant.get("character", "poke").to_upper()
			var p_name = occupant.get("name", "Player")
			if occ_id == my_id:
				btn.text = "★ %s [%s] (YOU)" % [p_name, char_name]
			else:
				btn.text = "• %s [%s]" % [p_name, char_name]
		else:
			btn.text = "[ + Slot %d : Open ]" % (s + 1)
			
	# Team 2 slots
	for s in range(3):
		var btn = t2_slots[s]
		var occupant = null
		var occ_id = 0
		for pid in connected_players.keys():
			var p = connected_players[pid]
			if p.get("team", 1) == 2 and p.get("slot", 0) == s:
				occupant = p
				occ_id = pid
				t2_count += 1
				break
		
		if occupant != null:
			var char_name = occupant.get("character", "poke").to_upper()
			var p_name = occupant.get("name", "Player")
			if occ_id == my_id:
				btn.text = "★ %s [%s] (YOU)" % [p_name, char_name]
			else:
				btn.text = "• %s [%s]" % [p_name, char_name]
		else:
			btn.text = "[ + Slot %d : Open ]" % (s + 1)

	if multiplayer.is_server():
		var can_start = (t1_count >= 1 and t2_count >= 1)
		start_match_button.disabled = not can_start
		if can_start:
			start_match_button.text = "START MATCH (%d vs %d)" % [t1_count, t2_count]
		else:
			start_match_button.text = "CANNOT START (Need 1+ player on each team)"

func _on_start_match_pressed() -> void:
	if not multiplayer.is_server():
		return
	if not is_training_mode:
		var t1_count = 0
		var t2_count = 0
		for pid in connected_players.keys():
			var p = connected_players[pid]
			if p.get("team", 1) == 1:
				t1_count += 1
			elif p.get("team", 1) == 2:
				t2_count += 1
		if t1_count < 1 or t2_count < 1:
			return
	start_game.rpc()

func get_player_team(peer_id: int) -> int:
	if connected_players.has(peer_id):
		return connected_players[peer_id].get("team", 1)
	var p = players_container.get_node_or_null(str(peer_id))
	if p and p.get("team_id") != null:
		return p.team_id
	return 1

@rpc("any_peer", "call_local", "reliable")
func start_game() -> void:
	match_in_progress = true
	lobby_panel.hide()
	match_over_panel.hide()
	escape_panel.hide()
	settings_panel.hide()
	
	if default_map and training_map:
		default_map.visible = not is_training_mode
		default_map.process_mode = Node.PROCESS_MODE_INHERIT if not is_training_mode else Node.PROCESS_MODE_DISABLED
		training_map.visible = is_training_mode
		training_map.process_mode = Node.PROCESS_MODE_INHERIT if is_training_mode else Node.PROCESS_MODE_DISABLED
	
	if multiplayer.is_server():
		for c in players_container.get_children():
			c.queue_free()
		for proj in projectiles_container.get_children():
			proj.queue_free()
		for terr in terrain_container.get_children():
			terr.queue_free()
		for v in vision_container.get_children():
			v.queue_free()
		for h in hazard_container.get_children():
			h.queue_free()
			
		if is_training_mode:
			# Spawn Training Dummy in center (Team 2)
			var dummy = training_dummy_scene.instantiate()
			dummy.name = "TrainingDummy"
			dummy.team_id = 2
			dummy.global_position = Vector3(0.0, 0.0, 0.0)
			players_container.add_child(dummy)
			
			# Spawn Local Player directly as child
			var p_info = connected_players.get(1, {"character": selected_character})
			var packed_scene = CHARACTERS.get(p_info.get("character", selected_character), CHARACTERS["poke"])
			var player_instance = packed_scene.instantiate()
			player_instance.name = "1"
			player_instance.team_id = 1
			player_instance.position = Vector3(-8.0, 0.1, 0.0)
			player_instance.rotation.y = 0.0
			players_container.add_child(player_instance)
		else:
			for pid in connected_players.keys():
				var p_info = connected_players[pid]
				var char_choice = p_info.get("character", "poke")
				var p_team = p_info.get("team", 1)
				var p_slot = p_info.get("slot", 0)
				
				var spawn_pos = Vector3.ZERO
				if p_team == 1:
					var t1_spawns = spawn_points.get_node_or_null("Team1_Spawns")
					if t1_spawns and t1_spawns.get_child_count() > p_slot:
						spawn_pos = t1_spawns.get_child(p_slot).global_position
					else:
						spawn_pos = Vector3(-24.0, 0.1, (p_slot - 1) * 6.0)
				else:
					var t2_spawns = spawn_points.get_node_or_null("Team2_Spawns")
					if t2_spawns and t2_spawns.get_child_count() > p_slot:
						spawn_pos = t2_spawns.get_child(p_slot).global_position
					else:
						spawn_pos = Vector3(24.0, 0.1, (p_slot - 1) * 6.0)
				
				var spawn_payload = {
					"peer_id": pid,
					"character": char_choice,
					"team_id": p_team,
					"pos": spawn_pos,
					"rot_y": 0.0 if p_team == 1 else PI
				}
				player_spawner.spawn(spawn_payload)

func _custom_spawn_player(data: Variant) -> Node:
	var char_key = data.get("character", "poke")
	var packed_scene = CHARACTERS.get(char_key, CHARACTERS["poke"])
	var player_instance = packed_scene.instantiate()
	player_instance.name = str(data["peer_id"])
	player_instance.team_id = data.get("team_id", 1)
	player_instance.position = data["pos"]
	if data.has("rot_y"):
		player_instance.rotation.y = data["rot_y"]
	return player_instance

func on_player_died(_peer_id: int) -> void:
	if not multiplayer.is_server() or not match_in_progress or is_training_mode:
		return
	_check_match_status()

func _check_match_status() -> void:
	if is_training_mode:
		return
	var alive_team1 = 0
	var alive_team2 = 0
	for p in players_container.get_children():
		if not p.get("is_dead"):
			var t = p.get("team_id")
			if t == 1:
				alive_team1 += 1
			elif t == 2:
				alive_team2 += 1
	
	if alive_team1 == 0 and alive_team2 == 0:
		end_match.rpc("DRAW")
	elif alive_team1 > 0 and alive_team2 == 0:
		end_match.rpc("TEAM 1")
	elif alive_team2 > 0 and alive_team1 == 0:
		end_match.rpc("TEAM 2")

@rpc("any_peer", "call_local", "reliable")
func display_damage_number(amount: float, pos: Vector3, action_type: int = 0) -> void:
	if amount <= 0.0:
		return
	var dmg_lbl = Label3D.new()
	dmg_lbl.text = str(round(amount))
	dmg_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	dmg_lbl.no_depth_test = true
	dmg_lbl.font_size = 50
	dmg_lbl.outline_size = 14
	dmg_lbl.outline_modulate = Color(0, 0, 0, 0.95)
	
	if amount >= 75.0:
		dmg_lbl.modulate = Color(1.0, 0.35, 0.15, 1.0) # Execute / Critical
		dmg_lbl.font_size = 62
	elif action_type == 1:
		dmg_lbl.modulate = Color(1.0, 0.85, 0.2, 1.0) # Ability
	else:
		dmg_lbl.modulate = Color(0.95, 0.95, 1.0, 1.0) # Attack
		
	var spawn_p = pos + Vector3(randf_range(-0.35, 0.35), 1.6 + randf_range(0.0, 0.25), randf_range(-0.35, 0.35))
	dmg_lbl.global_position = spawn_p
	dmg_lbl.scale = Vector3(0.4, 0.4, 0.4)
	add_child(dmg_lbl)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(dmg_lbl, "scale", Vector3(1.15, 1.15, 1.15), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(dmg_lbl, "global_position:y", spawn_p.y + 1.25, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(dmg_lbl, "modulate:a", 0.0, 0.35).set_delay(0.2)
	tween.chain().tween_callback(dmg_lbl.queue_free)

@rpc("any_peer", "call_local", "reliable")
func end_match(winner_name: String) -> void:
	match_in_progress = false
	if winner_name == "DRAW":
		winner_label.text = "MATCH OVER!\nDRAW!"
	else:
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
		for h in hazard_container.get_children():
			h.queue_free()

func spawn_projectile(pos: Vector3, dir: Vector3, shooter_id: int, dmg: float = 50.0, spd: float = 70.0, p_size: float = 1.0, life: float = 2.5, eff_type: String = "", eff_dur: float = 0.0, eff_int: float = 0.0, pierce: bool = false, spawn_terr: bool = false, shooter_team: int = 0, action_type: int = 0, max_rng: float = 0.0) -> void:
	if not multiplayer.is_server():
		return
	if shooter_team == 0 and shooter_id > 0:
		shooter_team = get_player_team(shooter_id)
	
	var actual_max_range = max_rng if max_rng > 0.0 else (spd * life)
	
	var spawn_data = {
		"pos": pos,
		"dir": dir,
		"shooter_id": shooter_id,
		"shooter_team": shooter_team,
		"action_type": action_type,
		"dmg": dmg,
		"spd": spd,
		"size": p_size,
		"life": life,
		"max_range": actual_max_range,
		"eff_type": eff_type,
		"eff_dur": eff_dur,
		"eff_int": eff_int,
		"pierce": pierce,
		"spawn_terr": spawn_terr
	}
	projectile_spawner.spawn(spawn_data)

func _custom_spawn_projectile(data: Variant) -> Node:
	var proj = projectile_scene.instantiate()
	proj.shooter_id = data.get("shooter_id", 0)
	proj.shooter_team = data.get("shooter_team", 0)
	proj.action_type = data.get("action_type", 0)
	proj.direction = data["dir"]
	proj.damage = data.get("dmg", 50.0)
	proj.speed = data.get("spd", 70.0)
	proj.size = data.get("size", 1.0)
	proj.lifetime = data.get("life", 2.5)
	proj.max_range = data.get("max_range", proj.speed * proj.lifetime)
	proj.effect_type = data.get("eff_type", "")
	proj.effect_duration = data.get("eff_dur", 0.0)
	proj.effect_intensity = data.get("eff_int", 0.0)
	proj.pierces = data.get("pierce", false)
	proj.spawn_terrain_on_death = data.get("spawn_terr", false)
	proj.position = data["pos"]
	return proj

func spawn_temporary_terrain(pos: Vector3, lifetime: float = 5.0, owner_id: int = 0) -> void:
	if not multiplayer.is_server():
		return
	var terr_pos = pos
	terr_pos.y = 0.0
	var data = {
		"pos": terr_pos,
		"lifetime": lifetime,
		"owner_id": owner_id
	}
	terrain_spawner.spawn(data)

func _custom_spawn_terrain(data: Variant) -> Node:
	var terrain = terrain_scene.instantiate()
	terrain.position = data["pos"]
	terrain.lifetime = data.get("lifetime", 5.0)
	terrain.owner_id = data.get("owner_id", 0)
	return terrain

func spawn_vision_flare(pos: Vector3, dir: Vector3, target_dist: float, shooter_id: int = 0, shooter_team: int = 0) -> void:
	if not multiplayer.is_server():
		return
	if shooter_team == 0 and shooter_id > 0:
		shooter_team = get_player_team(shooter_id)
	var flare = vision_flare_scene.instantiate()
	flare.position = pos
	flare.direction = dir
	flare.target_distance = target_dist
	flare.shooter_id = shooter_id
	flare.shooter_team = shooter_team
	projectiles_container.add_child(flare, true)

func spawn_vision_reveal_zone(pos: Vector3, rad: float = 12.0, lifetime: float = 5.5, owner_id: int = 0, owner_team: int = 0) -> void:
	if not multiplayer.is_server():
		return
	if owner_team == 0 and owner_id > 0:
		owner_team = get_player_team(owner_id)
	var data = {
		"pos": pos,
		"rad": rad,
		"life": lifetime,
		"owner_id": owner_id,
		"owner_team": owner_team
	}
	vision_spawner.spawn(data)

func _custom_spawn_vision_zone(data: Variant) -> Node:
	var zone = vision_reveal_zone_scene.instantiate()
	zone.position = data["pos"]
	zone.radius = data.get("rad", 12.0)
	zone.lifetime = data.get("life", 5.5)
	zone.owner_id = data.get("owner_id", 0)
	zone.owner_team = data.get("owner_team", 0)
	return zone

func spawn_slowing_dot_zone(pos: Vector3, rad: float = 2.2, dur: float = 4.5, dmg_ps: float = 0.0, slow_pct: float = 0.35, shooter_id: int = 0, shooter_team: int = 0) -> void:
	if not multiplayer.is_server():
		return
	if shooter_team == 0 and shooter_id > 0:
		shooter_team = get_player_team(shooter_id)
	var data = {
		"type": "slowing_dot",
		"pos": pos,
		"rad": rad,
		"dur": dur,
		"dmg_ps": dmg_ps,
		"slow_pct": slow_pct,
		"shooter_id": shooter_id,
		"shooter_team": shooter_team
	}
	hazard_spawner.spawn(data)

func spawn_fence_zone(pos: Vector3, rot_y: float, width: float = 8.0, height: float = 2.6, depth: float = 0.25, dur: float = 6.0, grounded_dur: float = 2.5, shooter_id: int = 0, shooter_team: int = 0) -> void:
	if not multiplayer.is_server():
		return
	if shooter_team == 0 and shooter_id > 0:
		shooter_team = get_player_team(shooter_id)
	var data = {
		"type": "fence",
		"pos": pos,
		"rot_y": rot_y,
		"width": width,
		"height": height,
		"depth": depth,
		"dur": dur,
		"grounded_dur": grounded_dur,
		"shooter_id": shooter_id,
		"shooter_team": shooter_team
	}
	hazard_spawner.spawn(data)

func _custom_spawn_hazard_zone(data: Variant) -> Node:
	if data.get("type") == "fence":
		var fence = fence_zone_scene.instantiate()
		fence.position = data["pos"]
		if data.has("rot_y"):
			fence.rotation.y = data["rot_y"]
		fence.fence_width = data.get("width", 8.0)
		fence.fence_height = data.get("height", 2.6)
		fence.fence_depth = data.get("depth", 0.25)
		fence.duration = data.get("dur", 6.0)
		fence.grounded_duration = data.get("grounded_dur", 2.5)
		fence.shooter_id = data.get("shooter_id", 0)
		fence.shooter_team = data.get("shooter_team", 0)
		return fence

	var zone = slowing_dot_zone_scene.instantiate()
	zone.position = data["pos"]
	zone.radius = data.get("rad", 2.2)
	zone.duration = data.get("dur", 4.5)
	zone.damage_per_second = data.get("dmg_ps", 0.0)
	zone.slow_percent = data.get("slow_pct", 0.35)
	zone.shooter_id = data.get("shooter_id", 0)
	zone.shooter_team = data.get("shooter_team", 0)
	return zone

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if settings_panel.visible:
			settings_panel.hide()
			_on_settings_closed()
			get_viewport().set_input_as_handled()
		elif escape_panel.visible:
			escape_panel.hide()
			get_viewport().set_input_as_handled()
		elif match_in_progress:
			_open_escape_menu()
			get_viewport().set_input_as_handled()
		elif lobby_panel.visible:
			_on_lobby_back_pressed()
			get_viewport().set_input_as_handled()

func _open_escape_menu() -> void:
	escape_panel.show()
	if escape_tab_container:
		escape_tab_container.set_tab_hidden(1, not is_training_mode)
		escape_tab_container.current_tab = 0
	if is_training_mode:
		escape_title_label.text = "TRAINING SESSION"
	else:
		escape_title_label.text = "MATCH PAUSED"

func _switch_training_character(new_char_key: String) -> void:
	if not is_training_mode:
		return
	selected_character = new_char_key
	
	var current_pos = Vector3(-8.0, 0.1, 0.0)
	var current_rot_y = 0.0
	
	# Find and remove old player node immediately from tree
	for p in players_container.get_children():
		if p.name != "TrainingDummy":
			current_pos = p.global_position
			current_rot_y = p.rotation.y
			players_container.remove_child(p)
			p.queue_free()
			break

	# Directly instantiate new character
	var packed_scene = CHARACTERS.get(new_char_key, CHARACTERS["poke"])
	var player_instance = packed_scene.instantiate()
	player_instance.name = "1"
	player_instance.team_id = 1
	player_instance.position = current_pos
	player_instance.rotation.y = current_rot_y
	players_container.add_child(player_instance)
	
	cleanup_player_entities(1)
	
	escape_panel.hide()
	display_damage_number(0, current_pos + Vector3(0, 0.5, 0), 1)

func _open_settings_menu() -> void:
	if escape_panel:
		escape_panel.hide()
	if settings_panel:
		settings_panel.show()
		if settings_panel.has_method("_refresh_ui_from_settings"):
			settings_panel._refresh_ui_from_settings()

func _on_settings_closed() -> void:
	if match_in_progress:
		escape_panel.show()
	elif lobby_panel.visible:
		lobby_panel.show()
	else:
		menu_panel.show()

func _on_lobby_back_pressed() -> void:
	_leave_to_main_menu()

func _on_quit_game_pressed() -> void:
	get_tree().quit()

func _on_exit_match_pressed() -> void:
	if is_training_mode:
		return_to_lobby()
	else:
		if multiplayer.is_server():
			return_to_lobby.rpc()
		else:
			request_return_to_lobby.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func request_return_to_lobby() -> void:
	if not multiplayer.is_server():
		return
	return_to_lobby.rpc()

@rpc("any_peer", "call_local", "reliable")
func return_to_lobby() -> void:
	match_in_progress = false
	escape_panel.hide()
	settings_panel.hide()
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
		for h in hazard_container.get_children():
			h.queue_free()
	
	if default_map:
		default_map.visible = not is_training_mode
		default_map.process_mode = Node.PROCESS_MODE_INHERIT if not is_training_mode else Node.PROCESS_MODE_DISABLED
	if training_map:
		training_map.visible = is_training_mode
		training_map.process_mode = Node.PROCESS_MODE_INHERIT if is_training_mode else Node.PROCESS_MODE_DISABLED

func _on_leave_match_pressed() -> void:
	_leave_to_main_menu()

func _leave_to_main_menu() -> void:
	_cleanup_upnp()
	
	escape_panel.hide()
	join_dialog.hide()
	settings_panel.hide()
	match_over_panel.hide()
	lobby_panel.hide()
	menu_panel.show()
	
	match_in_progress = false
	is_training_mode = false
	multiplayer.multiplayer_peer = null
	connected_players.clear()
	
	for c in players_container.get_children():
		c.queue_free()
	for proj in projectiles_container.get_children():
		proj.queue_free()
	for terr in terrain_container.get_children():
		terr.queue_free()
	for v in vision_container.get_children():
		v.queue_free()
	for h in hazard_container.get_children():
		h.queue_free()
	
	if default_map:
		default_map.visible = true
		default_map.process_mode = Node.PROCESS_MODE_INHERIT
	if training_map:
		training_map.visible = false
		training_map.process_mode = Node.PROCESS_MODE_DISABLED

func _start_upnp_discovery(port: int, local_ip: String) -> void:
	_cleanup_upnp()
	upnp_thread = Thread.new()
	upnp_thread.start(_thread_setup_upnp.bind(port, local_ip))

func _thread_setup_upnp(port: int, local_ip: String) -> void:
	var upnp = UPNP.new()
	var discover_result = upnp.discover(2000, 2, "InternetGatewayDevice")
	
	if discover_result == UPNP.UPNP_RESULT_SUCCESS and upnp.get_gateway() and upnp.get_gateway().is_valid_gateway():
		var map_udp = upnp.add_port_mapping(port, port, "SuperBattleArena_UDP", "UDP")
		var map_tcp = upnp.add_port_mapping(port, port, "SuperBattleArena_TCP", "TCP")
		var ext_ip = upnp.query_external_address()
		
		if map_udp == UPNP.UPNP_RESULT_SUCCESS and not ext_ip.is_empty() and ext_ip != "0.0.0.0":
			active_upnp = upnp
			_update_host_lobby_info.call_deferred(ext_ip, local_ip, port, true)
			return
	
	_update_host_lobby_info.call_deferred(local_ip, local_ip, port, false)

func _update_host_lobby_info(ip_str: String, _local_ip: String, _port: int, _upnp_success: bool) -> void:
	if not lobby_panel.visible or is_training_mode:
		return
	lobby_ip_label.text = "HOST IP: %s" % ip_str

func _cleanup_upnp() -> void:
	if upnp_thread:
		if upnp_thread.is_alive():
			upnp_thread.wait_to_finish()
		upnp_thread = null
	
	if active_upnp:
		var u = active_upnp
		active_upnp = null
		WorkerThreadPool.add_task(func():
			u.delete_port_mapping(PORT, "UDP")
			u.delete_port_mapping(PORT, "TCP")
		)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_cleanup_upnp()
