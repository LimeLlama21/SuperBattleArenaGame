extends Node3D

const PORT: int = 7000

const CHARACTERS: Dictionary = {
	"poke": preload("res://characters/poke/poke.tscn"),
	"crush": preload("res://characters/crush/crush.tscn"),
	"dive": preload("res://characters/dive/dive.tscn"),
	"reaper": preload("res://characters/reaper/reaper.tscn"),
	"morrigan": preload("res://characters/morrigan/morrigan.tscn"),
	"murder": preload("res://characters/morrigan/morrigan.tscn")
}

const CHARACTER_DISPLAY_NAMES: Dictionary = {
	"poke": "Arash",
	"crush": "Heracles",
	"dive": "Daughter of Gaia",
	"reaper": "Keres",
	"morrigan": "Morrigan",
	"murder": "Morrigan",
	"dummy": "Training Dummy"
}

static func get_character_display_name(char_key: String) -> String:
	return CHARACTER_DISPLAY_NAMES.get(char_key.to_lower(), char_key.capitalize())

@export var projectile_scene: PackedScene = preload("res://projectile.tscn")
@export var mortar_shell_scene: PackedScene = preload("res://characters/morrigan/mortar_shell.tscn")
@export var blood_wave_scene: PackedScene = preload("res://characters/morrigan/blood_wave.tscn")
@export var slowing_dot_zone_scene: PackedScene = preload("res://characters/morrigan/slowing_dot_zone.tscn")
@export var terrain_scene: PackedScene = preload("res://characters/crush/temporary_terrain.tscn")
@export var vision_flare_scene: PackedScene = preload("res://characters/poke/vision_flare.tscn")
@export var vision_reveal_zone_scene: PackedScene = preload("res://characters/poke/vision_reveal_zone.tscn")
@export var fence_zone_scene: PackedScene = preload("res://characters/poke/fence_zone.tscn")
@export var sticky_grenade_scene: PackedScene = preload("res://characters/poke/sticky_grenade.tscn")
@export var orbital_laser_zone_scene: PackedScene = preload("res://characters/poke/orbital_laser_zone.tscn")
@export var rail_trail_zone_scene: PackedScene = preload("res://characters/poke/rail_trail_zone.tscn")

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
@onready var match_over_sub_label: Label = get_node_or_null("UI/MatchOverPanel/VBox/SubLabel")

@onready var host_button: Button = $UI/MainMenu/VBox/HostButton
@onready var join_button: Button = $UI/MainMenu/VBox/JoinButton
@onready var training_button: Button = $UI/MainMenu/VBox/TrainingButton
@onready var main_settings_button: Button = $UI/MainMenu/VBox/SettingsButton
@onready var main_quit_button: Button = get_node_or_null("UI/MainMenu/VBox/QuitButton")

@onready var join_dialog: PanelContainer = $UI/JoinDialog
@onready var host_ip_input: LineEdit = $UI/JoinDialog/VBox/HostIPInput
@onready var join_status_label: Label = get_node_or_null("UI/JoinDialog/VBox/JoinStatusLabel")
@onready var cancel_join_button: Button = $UI/JoinDialog/VBox/HBox/CancelButton
@onready var confirm_join_button: Button = $UI/JoinDialog/VBox/HBox/ConfirmJoinButton

@onready var lobby_ip_label: Label = $UI/LobbyRoom/VBox/HBoxRoomCode/HostIPDisplay
@onready var copy_code_button: Button = get_node_or_null("UI/LobbyRoom/VBox/HBoxRoomCode/CopyCodeButton")
@onready var game_mode_option: OptionButton = get_node_or_null("UI/LobbyRoom/VBox/HBoxGameMode/GameModeOption")
@onready var select_poke_button: Button = $UI/LobbyRoom/VBox/HBoxSelect/SelectPoke
@onready var select_crush_button: Button = $UI/LobbyRoom/VBox/HBoxSelect/SelectCrush
@onready var select_dive_button: Button = $UI/LobbyRoom/VBox/HBoxSelect/SelectDive
@onready var select_reaper_button: Button = get_node_or_null("UI/LobbyRoom/VBox/HBoxSelect/SelectReaper")
@onready var select_morrigan_button: Button = get_node_or_null("UI/LobbyRoom/VBox/HBoxSelect/SelectMorrigan")
@onready var char_desc_label: Label = $UI/LobbyRoom/VBox/CharDescLabel
@onready var team_section: VBoxContainer = $UI/LobbyRoom/VBox/TeamSection
@onready var team_header: Label = get_node_or_null("UI/LobbyRoom/VBox/TeamSection/TeamHeader")
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
	$UI/LobbyRoom/VBox/TeamSection/HBoxTeams/VBoxTeam1/T1Slot2,
	$UI/LobbyRoom/VBox/TeamSection/HBoxTeams/VBoxTeam1/T1Slot3,
	$UI/LobbyRoom/VBox/TeamSection/HBoxTeams/VBoxTeam1/T1Slot4
]

@onready var t2_slots: Array[Button] = [
	$UI/LobbyRoom/VBox/TeamSection/HBoxTeams/VBoxTeam2/T2Slot0,
	$UI/LobbyRoom/VBox/TeamSection/HBoxTeams/VBoxTeam2/T2Slot1,
	$UI/LobbyRoom/VBox/TeamSection/HBoxTeams/VBoxTeam2/T2Slot2,
	$UI/LobbyRoom/VBox/TeamSection/HBoxTeams/VBoxTeam2/T2Slot3,
	$UI/LobbyRoom/VBox/TeamSection/HBoxTeams/VBoxTeam2/T2Slot4
]

var selected_character: String = "poke"
var connected_players: Dictionary = {}
var match_in_progress: bool = false
var is_training_mode: bool = false
var game_mode: String = "tdm" # "tdm" = Team Deathmatch, "dm" = Deathmatch (FFA), "bo5" = Best of Five
var current_room_code: String = ""

var bo5_score_t1: int = 0
var bo5_score_t2: int = 0
var _bo5_round_transition_active: bool = false

# --- Disconnection Failsafe System ---
var pending_disconnect_peers: Dictionary = {}

func _is_peer_pending_disconnect(peer_id: int) -> bool:
	return pending_disconnect_peers.has(peer_id)

func _process_pending_disconnects() -> void:
	if not multiplayer.is_server():
		return
	if pending_disconnect_peers.is_empty():
		return
	
	var changed = false
	for pid in pending_disconnect_peers.keys():
		var target_key = null
		for k in connected_players.keys():
			if str(k) == str(pid):
				target_key = k
				break
		if target_key != null:
			connected_players.erase(target_key)
			changed = true
		
		var p_node = players_container.get_node_or_null(str(pid))
		if p_node:
			p_node.queue_free()
		cleanup_player_entities(pid)
	
	pending_disconnect_peers.clear()
	if changed and multiplayer.has_multiplayer_peer():
		sync_lobby_state.rpc(connected_players, game_mode)
		sync_pending_disconnects.rpc([])

func _check_team_player_deficits() -> bool:
	if is_training_mode:
		return false
	if game_mode == "dm":
		var active_dm = 0
		for pid in connected_players.keys():
			if not _is_peer_pending_disconnect(int(pid)):
				active_dm += 1
		return active_dm < 2
	
	# Team-based modes (TDM, Best of Five)
	var t1_count = 0
	var t2_count = 0
	for pid in connected_players.keys():
		if _is_peer_pending_disconnect(int(pid)):
			continue
		var p = connected_players[pid]
		if p.get("team", 1) == 1:
			t1_count += 1
		elif p.get("team", 1) == 2:
			t2_count += 1
	return (t1_count == 0 or t2_count == 0)

@rpc("any_peer", "call_local", "reliable")
func sync_pending_disconnects(disconnected_ids: Array) -> void:
	pending_disconnect_peers.clear()
	for id in disconnected_ids:
		pending_disconnect_peers[int(id)] = true
	if scoreboard_panel and scoreboard_panel.visible:
		_update_scoreboard_content(false)

# --- K/D/A Tracking & Scoreboard System ---
var training_kills: int = 0
var training_deaths: int = 0
var training_assists: int = 0

func _sync_all_kda() -> void:
	if not multiplayer.is_server():
		return
	var kda_dict: Dictionary = {}
	for pid in connected_players.keys():
		kda_dict[pid] = {
			"kills": connected_players[pid].get("kills", 0),
			"deaths": connected_players[pid].get("deaths", 0),
			"assists": connected_players[pid].get("assists", 0)
		}
	sync_player_kda.rpc(kda_dict)

@rpc("any_peer", "call_local", "reliable")
func sync_player_kda(kda_dict: Dictionary) -> void:
	for pid in kda_dict.keys():
		for k in connected_players.keys():
			if str(k) == str(pid):
				connected_players[k]["kills"] = kda_dict[pid].get("kills", 0)
				connected_players[k]["deaths"] = kda_dict[pid].get("deaths", 0)
				connected_players[k]["assists"] = kda_dict[pid].get("assists", 0)
	if scoreboard_panel and scoreboard_panel.visible:
		_update_scoreboard_content(false)

var scoreboard_panel: PanelContainer = null
var scoreboard_score_container: VBoxContainer = null
var scoreboard_score_label: Label = null
var scoreboard_score_sublabel: Label = null
var scoreboard_status_label: Label = null

var scoreboard_team_container: HBoxContainer = null
var scoreboard_t1_list: VBoxContainer = null
var scoreboard_t2_list: VBoxContainer = null

var scoreboard_dm_container: VBoxContainer = null
var scoreboard_dm_scroll: ScrollContainer = null
var scoreboard_dm_list: VBoxContainer = null
var _scoreboard_refresh_timer: float = 0.0

# --- Multi-Map Architecture Variables ---
const MAP_CHASM_SCENE: PackedScene = preload("res://maps/map_chasm.tscn")
const MAP_ISLANDS_SCENE: PackedScene = preload("res://maps/map_islands.tscn")

var arena_maps: Array[Node3D] = []
var current_map_id: int = -1
const MAP_NAMES = ["Colosseum", "The Jagged Chasm", "Shattered Archipelago"]
var map_banner_label: Label = null

# --- Shop UI & Item System Variables ---
var shop_panel: PanelContainer = null
var shop_gold_label: Label = null
var shop_slot_label: Label = null
var shop_sell_btn: Button = null
var shop_tab_container: TabContainer = null
var shop_inspector_title: Label = null
var shop_inspector_cost: Label = null
var shop_inspector_stats: Label = null
var shop_inspector_effect: Label = null
var shop_inspector_buy_btn: Button = null
var current_inspected_item_id: String = "basic_damage"

# --- Deathmatch Timer Variables ---
var dm_match_timer: float = 300.0
var dm_timer_label: Label = null

var active_upnp: UPNP = null
var upnp_thread: Thread = null

var http_request_host: HTTPRequest = null
var http_request_join: HTTPRequest = null

func _ready() -> void:
	_setup_scoreboard_ui()
	_setup_shop_ui()
	_setup_dm_timer_ui()
	_setup_map_banner_ui()
	_setup_arena_maps()
	if game_mode_option:
		game_mode_option.clear()
		game_mode_option.add_item("Team Deathmatch (TDM)", 0)
		game_mode_option.add_item("Deathmatch (Free For All)", 1)
		game_mode_option.add_item("Best of Five", 2)
		game_mode_option.item_selected.connect(_on_game_mode_selected)
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	cancel_join_button.pressed.connect(func(): join_dialog.hide())
	confirm_join_button.pressed.connect(_on_confirm_join_pressed)
	host_ip_input.text_submitted.connect(func(_t): _on_confirm_join_pressed())
	training_button.pressed.connect(_on_training_pressed)
	main_settings_button.pressed.connect(_open_settings_menu)
	if main_quit_button:
		main_quit_button.pressed.connect(_on_quit_game_pressed)
	if copy_code_button:
		copy_code_button.pressed.connect(_on_copy_code_pressed)
	
	http_request_host = HTTPRequest.new()
	http_request_host.timeout = 20.0
	add_child(http_request_host)
	http_request_host.request_completed.connect(_on_backend_create_room_completed)

	http_request_join = HTTPRequest.new()
	http_request_join.timeout = 20.0
	add_child(http_request_join)
	http_request_join.request_completed.connect(_on_backend_join_room_completed)
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
	
	for i in range(t1_slots.size()):
		var s_idx = i
		t1_slots[i].pressed.connect(func(): _on_slot_clicked(1, s_idx))
		t2_slots[i].pressed.connect(func(): _on_slot_clicked(2, s_idx))
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	player_spawner.spawn_function = _custom_spawn_player
	projectile_spawner.spawn_function = _custom_spawn_projectile
	terrain_spawner.spawn_function = _custom_spawn_terrain
	vision_spawner.spawn_function = _custom_spawn_vision_zone
	hazard_spawner.spawn_function = _custom_spawn_hazard_zone
	
	match_over_panel.hide()
	_select_character("poke")

func _select_character(char_key: String) -> void:
	selected_character = char_key
	select_poke_button.text = "Arash (Select)"
	select_crush_button.text = "Heracles (Select)"
	select_dive_button.text = "Daughter of Gaia (Select)"
	if select_reaper_button:
		select_reaper_button.text = "Keres (Select)"
	if select_morrigan_button:
		select_morrigan_button.text = "Morrigan (Select)"

	if char_key == "poke":
		select_poke_button.text = "★ Arash (Selected)"
		char_desc_label.text = "ARASH: Sharpshooter (160 HP). Passive [Takedown Rush]: Dash resets on takedown. [LMB]: Rapid Pulse Shot. [RMB]: Sniper Stance (2s Charge). [Q]: Overcharged Rounds. [E]: Ion Fence. [R]: Orbital Hyperbeam (2s Channel, Piercing)."
	elif char_key == "crush":
		select_crush_button.text = "★ Heracles (Selected)"
		char_desc_label.text = "HERACLES: Juggernaut (160 HP). Passive [Titan's Surge]: Spells empower LMB (+25 dmg + heal). [LMB]: Slam. [RMB]: Fan stun. [Q]: Shockwave & Shield. [E]: Iron Blood (converts Gray Health to shield / regens)."
	elif char_key == "dive":
		select_dive_button.text = "★ Daughter of Gaia (Selected)"
		char_desc_label.text = "DAUGHTER OF GAIA: Striker (100 HP). Passive [Rupture Marks]: Stacking burst marks. [LMB]: Slash. [RMB]: Cleave. [Q]: Earth Tremor. [E]: Deflecting Guard (75% frontal DR). [Shift]: Wall Bounce."
	elif char_key == "reaper":
		if select_reaper_button:
			select_reaper_button.text = "★ Keres (Selected)"
		char_desc_label.text = "KERES: Assassin / Skirmisher (90 HP). Passive [Soul Harvest]: +15% MS steal on LMB. [RMB]: Spectral Tether (Charged throw: grounds + progressive slow -> roots & disables all movement). [Q]: Cull the Weak (sweet-spot donut sweep + cripple). [E]: Nightmare (Vlad pool invulnerability + slow). [R]: One with Death (+45% MS, +50% CDR, +30% DMG). [Shift]: Ethereal Dash."
	elif char_key == "morrigan" or char_key == "murder":
		if select_morrigan_button:
			select_morrigan_button.text = "★ Morrigan (Selected)"
		char_desc_label.text = "MORRIGAN: Mage (90 HP). Passive [Harbinger of Doom]: Ability hits spawn orbiting crows that seek nearby enemies (20 dmg + 35% slow). [LMB]: Black Plumage (Chargeable up to 5 rapid burst feathers). [RMB]: Omen of Death (Parabolic mortar shell). [Q]: Inescapable Ends (Dual-cast magnetic tether). [E]: Cry of the Banshee (Large cone shriek + 1.4s silence). [R]: Born of Blood (1s channel -> massive 45m piercing wave + stun). [Shift]: Crowstorm (Steered flight + 60% MS + 50% DR)."
	
	if multiplayer and multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			if connected_players.has(1):
				connected_players[1]["character"] = selected_character
				sync_lobby_state.rpc(connected_players, game_mode)
		else:
			update_player_character.rpc_id(1, selected_character)

func _on_game_mode_selected(idx: int) -> void:
	if not multiplayer.is_server():
		return
	var mode_str = "tdm"
	if idx == 1:
		mode_str = "dm"
	elif idx == 2:
		mode_str = "bo5"
	set_game_mode(mode_str)

func set_game_mode(mode_str: String) -> void:
	game_mode = mode_str
	bo5_score_t1 = 0
	bo5_score_t2 = 0
	if multiplayer.is_server():
		sync_bo5_score.rpc(0, 0)
		sync_lobby_state.rpc(connected_players, game_mode)

@rpc("authority", "call_local", "reliable")
func sync_bo5_score(s1: int, s2: int) -> void:
	bo5_score_t1 = s1
	bo5_score_t2 = s2
	if scoreboard_panel and scoreboard_panel.visible:
		_update_scoreboard_content()

func _on_slot_clicked(team: int, slot: int) -> void:
	if is_training_mode:
		return
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return
	if game_mode == "dm":
		return # Slots are assigned per-player in Deathmatch
	if multiplayer.is_server():
		_assign_player_slot(1, team, slot)
	else:
		request_team_slot.rpc_id(1, team, slot)

func _find_first_available_slot() -> Dictionary:
	for s in range(5):
		for t in [1, 2]:
			var occupied = false
			for pid in connected_players.keys():
				var p = connected_players[pid]
				if int(p.get("team", 1)) == t and int(p.get("slot", 0)) == s:
					occupied = true
					break
			if not occupied:
				return {"team": t, "slot": s}
	return {"team": 1, "slot": 0}

func _assign_player_slot(pid: int, team: int, slot: int) -> void:
	var target_key = null
	for k in connected_players.keys():
		if str(k) == str(pid):
			target_key = k
			break
	if target_key == null:
		var slot_info = _find_first_available_slot()
		connected_players[pid] = {
			"character": "poke",
			"name": "Host (P1)" if pid == 1 else "Player " + str(pid),
			"team": team,
			"slot": slot
		}
		target_key = pid
	
	for other_id in connected_players.keys():
		if str(other_id) != str(pid):
			var op = connected_players[other_id]
			if int(op.get("team", 1)) == team and int(op.get("slot", 0)) == slot:
				return # Slot already occupied
	
	connected_players[target_key]["team"] = team
	connected_players[target_key]["slot"] = slot
	sync_lobby_state.rpc(connected_players, game_mode)

@rpc("any_peer", "call_remote", "reliable")
func request_team_slot(team: int, slot: int) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_assign_player_slot(sender_id, team, slot)

func _on_copy_code_pressed() -> void:
	if not current_room_code.is_empty():
		DisplayServer.clipboard_set(current_room_code)
		if copy_code_button:
			copy_code_button.text = "✓ Copied!"
			get_tree().create_timer(1.5).timeout.connect(func():
				if copy_code_button:
					copy_code_button.text = "📋 Copy"
			)

func _on_training_pressed() -> void:
	is_training_mode = true
	current_room_code = ""
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer = null
	
	menu_panel.hide()
	lobby_panel.show()
	lobby_ip_label.text = "🎯 SOLO TRAINING SESSION"
	if copy_code_button:
		copy_code_button.visible = false
	start_match_button.visible = true

	connected_players.clear()
	connected_players[1] = {
		"character": selected_character,
		"name": "Player 1",
		"team": 1,
		"slot": 0,
		"gold": 999999,
		"items": []
	}
	_refresh_lobby_ui()

func _on_host_pressed() -> void:
	is_training_mode = false
	current_room_code = NetworkUtils.generate_room_code()

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
	if copy_code_button:
		copy_code_button.visible = true

	var local_ip = NetworkUtils.get_local_ipv4()
	lobby_ip_label.text = "ROOM CODE: %s (Registering...)" % current_room_code

	connected_players.clear()
	var slot_info = _find_first_available_slot()
	connected_players[1] = {
		"character": selected_character,
		"name": "Host (P1)",
		"team": slot_info["team"],
		"slot": slot_info["slot"]
	}
	_refresh_lobby_ui()
	_register_room_backend(current_room_code, local_ip, PORT)
	_start_upnp_discovery(PORT, local_ip)

func _register_room_backend(code: String, ip: String, port: int) -> void:
	if not http_request_host:
		return
	http_request_host.cancel_request()
	var url = "%s/api/create-room" % NetworkUtils.BACKEND_URL
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({"code": code, "ip": ip, "port": port})
	var err = http_request_host.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		print("Backend room registration failed: ", err)

func _on_backend_create_room_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if not lobby_panel.visible or is_training_mode:
		return
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		lobby_ip_label.text = "ROOM CODE: %s" % current_room_code
	else:
		lobby_ip_label.text = "ROOM CODE: %s (Local)" % current_room_code

func _on_join_pressed() -> void:
	join_dialog.show()
	if join_status_label:
		join_status_label.hide()
	confirm_join_button.disabled = false
	host_ip_input.text = ""
	host_ip_input.grab_focus()

func _on_confirm_join_pressed() -> void:
	var raw_input = host_ip_input.text.strip_edges()
	if raw_input.is_empty():
		if join_status_label:
			join_status_label.text = "Please enter a Room Code."
			join_status_label.show()
		return
	
	if NetworkUtils.is_direct_ip_or_localhost(raw_input):
		current_room_code = ""
		_join_direct_ip(raw_input)
		return
	
	# Query Render matchmaking backend
	if join_status_label:
		join_status_label.text = "Connecting to matchmaking server..."
		join_status_label.show()
	confirm_join_button.disabled = true
	
	var clean_code = raw_input.to_upper()
	current_room_code = clean_code
	var url = "%s/api/join-room/%s" % [NetworkUtils.BACKEND_URL, clean_code]
	http_request_join.cancel_request()
	var err = http_request_join.request(url, ["Accept: application/json"], HTTPClient.METHOD_GET)
	if err != OK:
		if join_status_label:
			join_status_label.text = "Could not reach matchmaking server."
		confirm_join_button.disabled = false

func _on_backend_join_room_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	confirm_join_button.disabled = false
	if result != HTTPRequest.RESULT_SUCCESS:
		if join_status_label:
			join_status_label.text = "Lobby does not exist or server is unreachable."
			join_status_label.show()
		return
	
	var body_str = body.get_string_from_utf8()
	var json = JSON.parse_string(body_str)
	if response_code == 200 and json is Dictionary and json.has("hostAddress"):
		var host_addr_str = str(json["hostAddress"])
		var parsed = NetworkUtils.parse_host_address(host_addr_str, PORT)
		var target_ip = parsed["ip"]
		var target_port = parsed["port"]
		_connect_client_to_host(target_ip, target_port)
	else:
		var err_msg = "Lobby does not exist. Check code and try again."
		if json is Dictionary and json.has("error"):
			err_msg = "Lobby does not exist: %s" % str(json["error"])
		if join_status_label:
			join_status_label.text = err_msg
			join_status_label.show()

func _join_direct_ip(raw_ip: String) -> void:
	var target_ip = NetworkUtils.clean_host_ip(raw_ip)
	_connect_client_to_host(target_ip, PORT)

func _connect_client_to_host(target_ip: String, target_port: int) -> void:
	is_training_mode = false
	if join_status_label:
		join_status_label.text = "Connecting to %s:%d..." % [target_ip, target_port]
		join_status_label.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
		join_status_label.show()
	confirm_join_button.disabled = true
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(target_ip, target_port)
	if error != OK:
		if join_status_label:
			join_status_label.text = "Failed to initialize connection (Error %d)" % error
			join_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
			join_status_label.show()
		confirm_join_button.disabled = false
		print("Failed client connection: ", error)
		return

	multiplayer.multiplayer_peer = peer
	
	# Timeout timer if UDP handshake cannot reach the host
	var timer = get_tree().create_timer(6.5)
	timer.timeout.connect(func():
		if multiplayer.multiplayer_peer and not multiplayer.is_server() and not lobby_panel.visible:
			multiplayer.multiplayer_peer = null
			confirm_join_button.disabled = false
			if join_status_label:
				join_status_label.text = "Connection timed out. If testing locally, join with 'localhost' or '127.0.0.1'. If across internet, ensure UDP port %d is forwarded." % target_port
				join_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
				join_status_label.show()
	)

func _on_connected_to_server() -> void:
	join_dialog.hide()
	menu_panel.hide()
	lobby_panel.show()
	confirm_join_button.disabled = false
	if copy_code_button:
		copy_code_button.visible = not current_room_code.is_empty()
	var disp = current_room_code if not current_room_code.is_empty() else "CONNECTED"
	lobby_ip_label.text = "ROOM CODE: %s" % disp
	start_match_button.visible = false
	register_player_to_server.rpc_id(1, selected_character)
	request_lobby_sync.rpc_id(1)

func _on_connection_failed() -> void:
	lobby_panel.hide()
	menu_panel.show()
	join_dialog.show()
	confirm_join_button.disabled = false
	multiplayer.multiplayer_peer = null
	if join_status_label:
		join_status_label.text = "Failed to connect to host. Ensure room code is valid and port 8910 UDP is accessible."
		join_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		join_status_label.show()

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		var has_player = false
		for k in connected_players.keys():
			if str(k) == str(id):
				has_player = true
				break
		if not has_player:
			var slot_info = _find_first_available_slot()
			connected_players[id] = {
				"character": "poke",
				"name": "Player " + str(id),
				"team": slot_info["team"],
				"slot": slot_info["slot"]
			}
		sync_lobby_state.rpc(connected_players, game_mode)

func _on_server_disconnected() -> void:
	_leave_to_main_menu()

func _on_peer_disconnected(id: int) -> void:
	if id == 1:
		_leave_to_main_menu()
		return
	if multiplayer.is_server():
		if is_training_mode:
			return
		
		# If a match or round transition is active, defer removal until next round start
		# or upon returning to the lobby if it's the last round.
		if match_in_progress or _bo5_round_transition_active:
			pending_disconnect_peers[id] = true
			sync_pending_disconnects.rpc(pending_disconnect_peers.keys())
			var player_node = players_container.get_node_or_null(str(id))
			if player_node:
				if player_node.has_method("die") and not player_node.get("is_dead"):
					player_node.die()
			cleanup_player_entities(id)
			
			if game_mode == "dm":
				var active_dm_count = 0
				for pid in connected_players.keys():
					if not _is_peer_pending_disconnect(int(pid)):
						active_dm_count += 1
				if active_dm_count < 2:
					terminate_match.rpc("Match terminated: Not enough players remaining for Deathmatch.")
					return
			
			if match_in_progress:
				_check_match_status()
		else:
			# In lobby: remove immediately
			var target_key = null
			for k in connected_players.keys():
				if str(k) == str(id):
					target_key = k
					break
			if target_key != null:
				connected_players.erase(target_key)
			sync_lobby_state.rpc(connected_players, game_mode)
			var player_node = players_container.get_node_or_null(str(id))
			if player_node:
				player_node.queue_free()
			cleanup_player_entities(id)
			_refresh_lobby_ui()

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
func request_lobby_sync() -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	sync_lobby_state.rpc_id(sender_id, connected_players, game_mode)

@rpc("any_peer", "call_remote", "reliable")
func register_player_to_server(char_key: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var target_key = null
	for k in connected_players.keys():
		if str(k) == str(sender_id):
			target_key = k
			break
	if target_key == null:
		var slot_info = _find_first_available_slot()
		connected_players[sender_id] = {
			"character": char_key,
			"name": "Player " + str(sender_id),
			"team": slot_info["team"],
			"slot": slot_info["slot"]
		}
	else:
		connected_players[target_key]["character"] = char_key
	sync_lobby_state.rpc(connected_players, game_mode)

@rpc("any_peer", "call_remote", "reliable")
func update_player_character(char_key: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	for k in connected_players.keys():
		if str(k) == str(sender_id):
			connected_players[k]["character"] = char_key
			sync_lobby_state.rpc(connected_players, game_mode)
			break

@rpc("any_peer", "call_local", "reliable")
func sync_lobby_state(players_dict: Dictionary, mode_str: String = "tdm") -> void:
	connected_players = players_dict
	game_mode = mode_str
	if not match_in_progress:
		menu_panel.hide()
		lobby_panel.show()
		_refresh_lobby_ui()

func _refresh_lobby_ui() -> void:
	var my_id = multiplayer.get_unique_id() if (multiplayer and multiplayer.has_multiplayer_peer()) else 1
	var is_server = multiplayer.is_server() if (multiplayer and multiplayer.has_multiplayer_peer()) else true
	
	if game_mode_option:
		game_mode_option.disabled = not is_server or is_training_mode
		var sel_idx = 0
		if game_mode == "dm":
			sel_idx = 1
		elif game_mode == "bo5":
			sel_idx = 2
		game_mode_option.select(sel_idx)

	if is_training_mode:
		if team_section:
			team_section.hide()
		start_match_button.disabled = false
		start_match_button.text = "ENTER TRAINING ARENA"
		return
		
	if team_section:
		team_section.show()

	if game_mode == "dm":
		if team_header:
			team_header.text = "2. Free For All Deathmatch (10 Max - Free For All):"
		
		var p_ids = connected_players.keys()
		for s in range(5):
			var btn1 = t1_slots[s]
			var idx1 = s
			if idx1 < p_ids.size():
				var pid = p_ids[idx1]
				var occupant = connected_players[pid]
				var char_name = occupant.get("character", "poke").to_upper()
				var p_name = occupant.get("name", "Player")
				if str(pid) == str(my_id):
					btn1.text = "★ %s [%s] (YOU)" % [p_name, char_name]
				else:
					btn1.text = "• %s [%s]" % [p_name, char_name]
			else:
				btn1.text = "[ Fighter %d : Open ]" % (idx1 + 1)
			
			var btn2 = t2_slots[s]
			var idx2 = s + 5
			if idx2 < p_ids.size():
				var pid = p_ids[idx2]
				var occupant = connected_players[pid]
				var char_name = occupant.get("character", "poke").to_upper()
				var p_name = occupant.get("name", "Player")
				if str(pid) == str(my_id):
					btn2.text = "★ %s [%s] (YOU)" % [p_name, char_name]
				else:
					btn2.text = "• %s [%s]" % [p_name, char_name]
			else:
				btn2.text = "[ Fighter %d : Open ]" % (idx2 + 1)

		if is_server:
			var can_start = connected_players.size() >= 2 or (connected_players.size() >= 1 and OS.is_debug_build())
			start_match_button.disabled = not can_start
			if can_start:
				start_match_button.text = "START DEATHMATCH (%d Fighters)" % connected_players.size()
			else:
				start_match_button.text = "CANNOT START (Need 2+ players for Deathmatch)"
		return
	
	# TDM / Bo5 Mode
	if team_header:
		if game_mode == "bo5":
			team_header.text = "2. Select Team & Slot (Best of Five - 5v5 Max):"
		else:
			team_header.text = "2. Select Team & Slot (5v5 Max):"
	var t1_count = 0
	var t2_count = 0
	
	# Team 1 slots
	for s in range(5):
		var btn = t1_slots[s]
		var occupant = null
		var occ_id = null
		for pid in connected_players.keys():
			var p = connected_players[pid]
			if int(p.get("team", 1)) == 1 and int(p.get("slot", 0)) == s:
				occupant = p
				occ_id = pid
				t1_count += 1
				break
		
		if occupant != null:
			var char_name = occupant.get("character", "poke").to_upper()
			var p_name = occupant.get("name", "Player")
			if str(occ_id) == str(my_id):
				btn.text = "★ %s [%s] (YOU)" % [p_name, char_name]
			else:
				btn.text = "• %s [%s]" % [p_name, char_name]
		else:
			btn.text = "[ + Slot %d : Join Team 1 ]" % (s + 1)
			
	# Team 2 slots
	for s in range(5):
		var btn = t2_slots[s]
		var occupant = null
		var occ_id = null
		for pid in connected_players.keys():
			var p = connected_players[pid]
			if int(p.get("team", 1)) == 2 and int(p.get("slot", 0)) == s:
				occupant = p
				occ_id = pid
				t2_count += 1
				break
		
		if occupant != null:
			var char_name = occupant.get("character", "poke").to_upper()
			var p_name = occupant.get("name", "Player")
			if str(occ_id) == str(my_id):
				btn.text = "★ %s [%s] (YOU)" % [p_name, char_name]
			else:
				btn.text = "• %s [%s]" % [p_name, char_name]
		else:
			btn.text = "[ + Slot %d : Join Team 2 ]" % (s + 1)

	if is_server:
		var can_start = (t1_count >= 1 and t2_count >= 1)
		start_match_button.disabled = not can_start
		if can_start:
			if game_mode == "bo5":
				start_match_button.text = "START BEST OF FIVE (%d vs %d)" % [t1_count, t2_count]
			else:
				start_match_button.text = "START MATCH (%d vs %d)" % [t1_count, t2_count]
		else:
			start_match_button.text = "CANNOT START (Need 1+ player on each team)"

func _on_start_match_pressed() -> void:
	if is_training_mode:
		start_game()
		return
	if not is_multiplayer_match() or not multiplayer.is_server():
		return
	if game_mode == "dm":
		var can_start_dm = connected_players.size() >= 2 or (connected_players.size() >= 1 and OS.is_debug_build())
		if not can_start_dm:
			return
		for k in connected_players.keys():
			connected_players[k]["kills"] = 0
			connected_players[k]["deaths"] = 0
			connected_players[k]["assists"] = 0
		_sync_all_kda()
		start_game.rpc()
		return

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
	if game_mode == "bo5":
		bo5_score_t1 = 0
		bo5_score_t2 = 0
		sync_bo5_score.rpc(0, 0)
	for k in connected_players.keys():
		connected_players[k]["kills"] = 0
		connected_players[k]["deaths"] = 0
		connected_players[k]["assists"] = 0
	_sync_all_kda()
	start_game.rpc()

func is_multiplayer_match() -> bool:
	if is_training_mode:
		return false
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return false
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	return connected_players.size() > 1 or multiplayer.get_peers().size() > 0

func get_player_team(peer_id: int) -> int:
	for k in connected_players.keys():
		if str(k) == str(peer_id):
			return int(connected_players[k].get("team", 1))
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
	
	if not is_multiplayer_match() or multiplayer.is_server():
		_process_pending_disconnects()
		if not is_training_mode and _check_team_player_deficits():
			terminate_match.rpc("Match terminated: A team has no remaining players.")
			return
		
		if not is_training_mode:
			var next_map = _pick_next_random_map()
			if is_multiplayer_match() and multiplayer.has_multiplayer_peer():
				sync_active_map.rpc(next_map)
			else:
				sync_active_map(next_map)
		else:
			sync_active_map(0)
	
	if not is_multiplayer_match() or multiplayer.is_server():
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
			training_kills = 0
			training_deaths = 0
			training_assists = 0
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
			player_instance.gold = p_info.get("gold", 999999)
			var raw_training_items = p_info.get("items", [])
			player_instance.item_slots.clear()
			for it in raw_training_items:
				player_instance.item_slots.append(str(it))
			player_instance.apply_all_items()
			players_container.add_child(player_instance)
		elif game_mode == "dm":
			dm_match_timer = 300.0
			for k in connected_players.keys():
				connected_players[k]["kills"] = 0
				connected_players[k]["deaths"] = 0
				connected_players[k]["assists"] = 0
			_sync_all_kda()
			# Free-For-All Deathmatch: unique team ID per player
			var all_spawns: Array = []
			var t1_spawns = spawn_points.get_node_or_null("Team1_Spawns")
			var t2_spawns = spawn_points.get_node_or_null("Team2_Spawns")
			if t1_spawns:
				for sp in t1_spawns.get_children():
					all_spawns.append(sp.global_position)
			if t2_spawns:
				for sp in t2_spawns.get_children():
					all_spawns.append(sp.global_position)
			if all_spawns.is_empty():
				all_spawns = [
					Vector3(-24.0, 0.1, -10.0), Vector3(-24.0, 0.1, -5.0), Vector3(-24.0, 0.1, 0.0), Vector3(-24.0, 0.1, 5.0), Vector3(-24.0, 0.1, 10.0),
					Vector3(24.0, 0.1, -10.0), Vector3(24.0, 0.1, -5.0), Vector3(24.0, 0.1, 0.0), Vector3(24.0, 0.1, 5.0), Vector3(24.0, 0.1, 10.0)
				]

			var p_idx = 0
			for pid in connected_players.keys():
				var p_info = connected_players[pid]
				var char_choice = p_info.get("character", "poke")
				var p_team = pid # Unique team_id per player so everyone is an enemy
				p_info["team"] = p_team
				
				var spawn_pos = all_spawns[p_idx % all_spawns.size()]
				p_idx += 1
				
				var spawn_payload = {
					"peer_id": pid,
					"character": char_choice,
					"team_id": p_team,
					"pos": spawn_pos,
					"rot_y": randf_range(0.0, TAU),
					"items": p_info.get("items", []),
					"gold": p_info.get("gold", 0)
				}
				player_spawner.spawn(spawn_payload)
		else:
			# Team Deathmatch (TDM - 5v5) and Best of Five
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
						spawn_pos = Vector3(-24.0, 0.1, (p_slot - 2.0) * 5.0)
				else:
					var t2_spawns = spawn_points.get_node_or_null("Team2_Spawns")
					if t2_spawns and t2_spawns.get_child_count() > p_slot:
						spawn_pos = t2_spawns.get_child(p_slot).global_position
					else:
						spawn_pos = Vector3(24.0, 0.1, (p_slot - 2.0) * 5.0)
				
				var spawn_payload = {
					"peer_id": pid,
					"character": char_choice,
					"team_id": p_team,
					"pos": spawn_pos,
					"rot_y": 0.0 if p_team == 1 else PI,
					"items": p_info.get("items", []),
					"gold": p_info.get("gold", 0)
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
	player_instance.gold = data.get("gold", 0)
	var raw_items = data.get("items", [])
	player_instance.item_slots.clear()
	for it in raw_items:
		player_instance.item_slots.append(str(it))
	player_instance.apply_all_items()
	call_deferred("_refresh_all_player_team_visuals")
	return player_instance

func _refresh_all_player_team_visuals() -> void:
	if players_container:
		for p in players_container.get_children():
			if p.has_method("_update_team_visuals"):
				p._update_team_visuals()

func on_player_died(peer_id: int) -> void:
	if not is_multiplayer_match() or not multiplayer.is_server() or not match_in_progress or is_training_mode:
		if is_training_mode:
			if peer_id == 0 or peer_id == 2:
				training_kills += 1
			else:
				training_deaths += 1
			if scoreboard_panel and scoreboard_panel.visible:
				_update_scoreboard_content(false)
		return
	
	# 1. Update Deaths for the victim
	if connected_players.has(peer_id):
		connected_players[peer_id]["deaths"] = connected_players[peer_id].get("deaths", 0) + 1
	
	# 2. Find Killer and Assisters from recent_damage_dealers
	var victim = players_container.get_node_or_null(str(peer_id))
	var killer_id = 0
	var newest_time = -1.0
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if victim and "recent_damage_dealers" in victim:
		for att_id in victim.recent_damage_dealers.keys():
			if str(att_id) != str(peer_id):
				var t = victim.recent_damage_dealers[att_id]
				if t > newest_time:
					newest_time = t
					killer_id = int(att_id)
	
	if killer_id > 0 and connected_players.has(killer_id):
		connected_players[killer_id]["kills"] = connected_players[killer_id].get("kills", 0) + 1
		connected_players[killer_id]["gold"] = connected_players[killer_id].get("gold", 0) + 50
		var killer_node = players_container.get_node_or_null(str(killer_id))
		if killer_node and killer_node.has_method("sync_inventory"):
			killer_node.sync_inventory.rpc(killer_node.item_slots, connected_players[killer_id]["gold"])
	
	# 3. Assists: any other attacker who damaged victim within 10 seconds prior to death
	if victim and "recent_damage_dealers" in victim:
		for att_id in victim.recent_damage_dealers.keys():
			var a_id = int(att_id)
			if str(a_id) != str(peer_id) and a_id != killer_id:
				var t = victim.recent_damage_dealers[att_id]
				if current_time - t <= 10.0:
					if connected_players.has(a_id):
						connected_players[a_id]["assists"] = connected_players[a_id].get("assists", 0) + 1
						connected_players[a_id]["gold"] = connected_players[a_id].get("gold", 0) + 25
						var assister_node = players_container.get_node_or_null(str(a_id))
						if assister_node and assister_node.has_method("sync_inventory"):
							assister_node.sync_inventory.rpc(assister_node.item_slots, connected_players[a_id]["gold"])
	
	_sync_all_kda()
	
	if game_mode == "dm":
		# Respawn after 5 seconds in Deathmatch (if not disconnected)
		get_tree().create_timer(5.0).timeout.connect(func():
			if match_in_progress and is_instance_valid(victim) and victim.get("is_dead") == true:
				if not _is_peer_pending_disconnect(peer_id):
					victim.respawn()
		)
		return

	_check_match_status()

func _check_match_status() -> void:
	if not is_multiplayer_match() or not multiplayer.is_server() or not match_in_progress or is_training_mode:
		return
	
	if players_container.get_child_count() == 0:
		return

	if game_mode == "dm":
		# Deathmatch is timed (5 minutes) and uses 5-second respawns, not last-man-standing
		return
	
	var total_t1 = 0
	var total_t2 = 0
	var alive_t1 = 0
	var alive_t2 = 0
	var alive_players: Array = []
	
	for p in players_container.get_children():
		if p is Node3D:
			var t = p.get("team_id")
			var dead = p.get("is_dead") == true or (p.get("current_health") != null and p.current_health <= 0.0)
			if t == 1:
				total_t1 += 1
				if not dead:
					alive_t1 += 1
					alive_players.append(p)
			elif t == 2:
				total_t2 += 1
				if not dead:
					alive_t2 += 1
					alive_players.append(p)
			else:
				if not dead:
					alive_players.append(p)
	
	# If both teams are participating in match
	if total_t1 > 0 and total_t2 > 0:
		if alive_t1 == 0 and alive_t2 == 0:
			if game_mode == "bo5":
				_handle_bo5_round_end("DRAW")
			else:
				end_match.rpc("DRAW")
		elif alive_t1 == 0 and alive_t2 > 0:
			if game_mode == "bo5":
				_handle_bo5_round_end("TEAM 2")
			else:
				end_match.rpc("TEAM 2")
		elif alive_t2 == 0 and alive_t1 > 0:
			if game_mode == "bo5":
				_handle_bo5_round_end("TEAM 1")
			else:
				end_match.rpc("TEAM 1")
	# If only one team
	elif total_t1 > 0 or total_t2 > 0:
		var total_active = total_t1 + total_t2
		var total_alive = alive_t1 + alive_t2
		if total_alive == 0:
			end_match.rpc("DRAW")
		elif total_active > 1 and total_alive <= 1:
			if alive_players.size() == 1:
				var winner = alive_players[0]
				var winner_id = winner.name.to_int()
				var p_info = connected_players.get(winner_id, {})
				var p_name = p_info.get("name", "Player " + str(winner_id))
				var char_name = winner.get_display_name() if winner.has_method("get_display_name") else winner.get("display_name")
				if not char_name or str(char_name).is_empty():
					char_name = get_character_display_name(p_info.get("character", "Hero"))
				end_match.rpc("%s (%s)" % [p_name, char_name])
			else:
				end_match.rpc("DRAW")

func _handle_bo5_round_end(round_winner: String) -> void:
	match_in_progress = false
	if round_winner == "TEAM 1":
		bo5_score_t1 += 1
	elif round_winner == "TEAM 2":
		bo5_score_t2 += 1
	
	# Award 100 gold to each player after each round of combat in Best of Five
	for pid in connected_players.keys():
		connected_players[pid]["gold"] = connected_players[pid].get("gold", 0) + 100
		var p_node = players_container.get_node_or_null(str(pid))
		if p_node and p_node.has_method("sync_inventory"):
			p_node.sync_inventory.rpc(p_node.item_slots, connected_players[pid]["gold"])
	
	sync_bo5_score.rpc(bo5_score_t1, bo5_score_t2)
	
	if bo5_score_t1 >= 3:
		end_match.rpc("TEAM 1")
	elif bo5_score_t2 >= 3:
		end_match.rpc("TEAM 2")
	else:
		end_round.rpc(round_winner, bo5_score_t1, bo5_score_t2)

@rpc("any_peer", "call_local", "reliable")
func end_round(round_winner: String, score1: int, score2: int) -> void:
	match_in_progress = false
	bo5_score_t1 = score1
	bo5_score_t2 = score2
	_bo5_round_transition_active = true
	
	if scoreboard_panel and scoreboard_panel.visible:
		_update_scoreboard_content()
	
	if round_winner == "DRAW":
		winner_label.text = "ROUND OVER!\nDRAW!"
		if match_over_sub_label:
			match_over_sub_label.text = "Score: Team 1 [%d] - [%d] Team 2\nReplaying round in 3 seconds..." % [score1, score2]
	else:
		winner_label.text = "ROUND OVER!\n%s WINS THE ROUND!" % round_winner.to_upper()
		if match_over_sub_label:
			match_over_sub_label.text = "Score: Team 1 [%d] - [%d] Team 2\nNext round starting in 3 seconds..." % [score1, score2]
	
	match_over_panel.show()
	
	await get_tree().create_timer(3.0).timeout
	
	if not _bo5_round_transition_active:
		return
	_bo5_round_transition_active = false
	
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
		for h in hazard_container.get_children():
			h.queue_free()
		
		await get_tree().process_frame
		
		# Next round start: remove disconnected players and check team deficits
		_process_pending_disconnects()
		if _check_team_player_deficits():
			terminate_match.rpc("Match terminated: A team has no remaining players.")
			return
		
		if lobby_panel.visible or not multiplayer.has_multiplayer_peer():
			return
		
		start_game.rpc()

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
	_bo5_round_transition_active = false
	if game_mode == "bo5" and winner_name != "DRAW":
		winner_label.text = "BEST OF FIVE OVER!\n%s WINS THE MATCH!" % winner_name.to_upper()
		if match_over_sub_label:
			match_over_sub_label.text = "Final Score: Team 1 [%d] - [%d] Team 2\nReturning to lobby in 3 seconds..." % [bo5_score_t1, bo5_score_t2]
	elif winner_name == "DRAW":
		winner_label.text = "MATCH OVER!\nDRAW!"
		if match_over_sub_label:
			match_over_sub_label.text = "Returning to lobby in 3 seconds..."
	else:
		winner_label.text = "MATCH OVER!\n%s WINS!" % winner_name.to_upper()
		if match_over_sub_label:
			match_over_sub_label.text = "Returning to lobby in 3 seconds..."
	match_over_panel.show()
	
	await get_tree().create_timer(3.0).timeout
	
	match_over_panel.hide()
	escape_panel.hide()
	settings_panel.hide()
	if scoreboard_panel:
		scoreboard_panel.hide()
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
		_process_pending_disconnects()
		bo5_score_t1 = 0
		bo5_score_t2 = 0
		sync_bo5_score.rpc(0, 0)

@rpc("any_peer", "call_local", "reliable")
func terminate_match(reason: String = "A team has no remaining players.") -> void:
	match_in_progress = false
	_bo5_round_transition_active = false
	bo5_score_t1 = 0
	bo5_score_t2 = 0
	_show_shop(false)
	if dm_timer_label:
		dm_timer_label.hide()
	if scoreboard_panel and scoreboard_panel.visible:
		scoreboard_panel.hide()
	
	winner_label.text = "MATCH TERMINATED!"
	if match_over_sub_label:
		match_over_sub_label.text = reason + "\nReturning to lobby in 3 seconds..."
	match_over_panel.show()
	
	await get_tree().create_timer(3.0).timeout
	
	match_over_panel.hide()
	escape_panel.hide()
	settings_panel.hide()
	if scoreboard_panel:
		scoreboard_panel.hide()
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
		_process_pending_disconnects()
		sync_lobby_state.rpc(connected_players, game_mode)

func spawn_projectile(pos: Vector3, dir: Vector3, shooter_id: int, dmg: float = 50.0, spd: float = 70.0, p_size: float = 1.0, life: float = 2.5, eff_type: String = "", eff_dur: float = 0.0, eff_int: float = 0.0, pierce: bool = false, spawn_terr: bool = false, shooter_team: int = 0, action_type: int = 0, max_rng: float = 0.0) -> void:
	if is_multiplayer_match() and not multiplayer.is_server():
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
	if not is_multiplayer_match():
		var proj = _custom_spawn_projectile(spawn_data)
		projectiles_container.add_child(proj, true)
		return
	projectile_spawner.spawn(spawn_data)

func _custom_spawn_projectile(data: Variant) -> Node:
	var p_type = data.get("type", "projectile")
	if p_type == "mortar_shell":
		var shell = mortar_shell_scene.instantiate()
		shell.start_pos = data["start_pos"]
		shell.end_pos = data["end_pos"]
		shell.speed = data.get("speed", 24.0)
		shell.aoe_radius = data.get("aoe_radius", 3.2)
		shell.damage = data.get("damage", 45.0)
		shell.shooter_id = data.get("shooter_id", 0)
		shell.shooter_team = data.get("shooter_team", 0)
		return shell
	elif p_type == "blood_wave":
		var wave = blood_wave_scene.instantiate()
		wave.position = data["pos"]
		wave.direction = data["dir"]
		wave.speed = data.get("speed", 22.0)
		wave.max_range = data.get("max_range", 45.0)
		wave.wave_width = data.get("wave_width", 12.0)
		wave.damage = data.get("damage", 80.0)
		wave.shooter_id = data.get("shooter_id", 0)
		wave.shooter_team = data.get("shooter_team", 0)
		return wave
	elif p_type == "vision_flare":
		var flare = vision_flare_scene.instantiate()
		flare.position = data["pos"]
		flare.direction = data["dir"]
		flare.target_distance = data.get("target_dist", 65.0)
		flare.shooter_id = data.get("shooter_id", 0)
		flare.shooter_team = data.get("shooter_team", 0)
		return flare
	elif p_type == "sticky_grenade":
		var grenade = sticky_grenade_scene.instantiate()
		grenade.position = data["pos"]
		grenade.direction = data["dir"]
		grenade.speed = data.get("speed", 42.0)
		grenade.max_range = data.get("max_range", 17.5)
		grenade.aoe_radius = data.get("aoe_radius", 3.5)
		grenade.damage = data.get("damage", 70.0)
		grenade.fuse_duration = data.get("fuse_duration", 1.2)
		grenade.shooter_id = data.get("shooter_id", 0)
		grenade.shooter_team = data.get("shooter_team", 0)
		return grenade

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

func spawn_sticky_grenade(pos: Vector3, dir: Vector3, shooter_id: int = 0, shooter_team: int = 0, spd: float = 42.0, max_rng: float = 17.5, rad: float = 3.5, dmg: float = 70.0, fuse: float = 1.2) -> void:
	if is_multiplayer_match() and not multiplayer.is_server():
		return
	if shooter_team == 0 and shooter_id > 0:
		shooter_team = get_player_team(shooter_id)
	var spawn_data = {
		"type": "sticky_grenade",
		"pos": pos,
		"dir": dir,
		"speed": spd,
		"max_range": max_rng,
		"aoe_radius": rad,
		"damage": dmg,
		"fuse_duration": fuse,
		"shooter_id": shooter_id,
		"shooter_team": shooter_team
	}
	if not is_multiplayer_match():
		var grenade = _custom_spawn_projectile(spawn_data)
		projectiles_container.add_child(grenade, true)
		return
	projectile_spawner.spawn(spawn_data)

func spawn_temporary_terrain(pos: Vector3, lifetime: float = 5.0, owner_id: int = 0) -> void:
	if is_multiplayer_match() and not multiplayer.is_server():
		return
	var terr_pos = pos
	terr_pos.y = 0.0
	var data = {
		"pos": terr_pos,
		"lifetime": lifetime,
		"owner_id": owner_id
	}
	if not is_multiplayer_match():
		var terr = _custom_spawn_terrain(data)
		terrain_container.add_child(terr, true)
		return
	terrain_spawner.spawn(data)

func _custom_spawn_terrain(data: Variant) -> Node:
	var terrain = terrain_scene.instantiate()
	terrain.position = data["pos"]
	terrain.lifetime = data.get("lifetime", 5.0)
	terrain.owner_id = data.get("owner_id", 0)
	return terrain

func spawn_vision_flare(pos: Vector3, dir: Vector3, target_dist: float, shooter_id: int = 0, shooter_team: int = 0) -> void:
	if is_multiplayer_match() and not multiplayer.is_server():
		return
	if shooter_team == 0 and shooter_id > 0:
		shooter_team = get_player_team(shooter_id)
	var spawn_data = {
		"type": "vision_flare",
		"pos": pos,
		"dir": dir,
		"target_dist": target_dist,
		"shooter_id": shooter_id,
		"shooter_team": shooter_team
	}
	if not is_multiplayer_match():
		var flare = _custom_spawn_projectile(spawn_data)
		projectiles_container.add_child(flare, true)
		return
	projectile_spawner.spawn(spawn_data)

func spawn_mortar_shell(start_p: Vector3, end_p: Vector3, shooter_id: int = 0, shooter_team: int = 0, spd: float = 24.0, rad: float = 3.2, dmg: float = 45.0) -> void:
	if is_multiplayer_match() and not multiplayer.is_server():
		return
	if shooter_team == 0 and shooter_id > 0:
		shooter_team = get_player_team(shooter_id)
	var spawn_data = {
		"type": "mortar_shell",
		"start_pos": start_p,
		"end_pos": end_p,
		"speed": spd,
		"aoe_radius": rad,
		"damage": dmg,
		"shooter_id": shooter_id,
		"shooter_team": shooter_team
	}
	if not is_multiplayer_match():
		var shell = _custom_spawn_projectile(spawn_data)
		projectiles_container.add_child(shell, true)
		return
	projectile_spawner.spawn(spawn_data)

func spawn_blood_wave(pos: Vector3, dir: Vector3, shooter_id: int = 0, shooter_team: int = 0, spd: float = 22.0, max_rng: float = 45.0, width: float = 12.0, dmg: float = 80.0) -> void:
	if is_multiplayer_match() and not multiplayer.is_server():
		return
	if shooter_team == 0 and shooter_id > 0:
		shooter_team = get_player_team(shooter_id)
	var spawn_data = {
		"type": "blood_wave",
		"pos": pos,
		"dir": dir,
		"speed": spd,
		"max_range": max_rng,
		"wave_width": width,
		"damage": dmg,
		"shooter_id": shooter_id,
		"shooter_team": shooter_team
	}
	if not is_multiplayer_match():
		var wave = _custom_spawn_projectile(spawn_data)
		projectiles_container.add_child(wave, true)
		return
	projectile_spawner.spawn(spawn_data)

func spawn_vision_reveal_zone(pos: Vector3, rad: float = 12.0, lifetime: float = 5.5, owner_id: int = 0, owner_team: int = 0) -> void:
	if is_multiplayer_match() and not multiplayer.is_server():
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
	if not is_multiplayer_match():
		var zone = _custom_spawn_vision_zone(data)
		vision_container.add_child(zone, true)
		return
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
	if is_multiplayer_match() and not multiplayer.is_server():
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
	if not is_multiplayer_match():
		var zone = _custom_spawn_hazard_zone(data)
		hazard_container.add_child(zone, true)
		return
	hazard_spawner.spawn(data)

func spawn_fence_zone(pos: Vector3, rot_y: float, width: float = 8.0, height: float = 2.6, depth: float = 0.25, dur: float = 6.0, grounded_dur: float = 2.5, shooter_id: int = 0, shooter_team: int = 0) -> void:
	if is_multiplayer_match() and not multiplayer.is_server():
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
	if not is_multiplayer_match():
		var fence = _custom_spawn_hazard_zone(data)
		hazard_container.add_child(fence, true)
		return
	hazard_spawner.spawn(data)

func spawn_orbital_laser_zone(pos: Vector3, rad: float = 3.8, delay: float = 1.5, dur: float = 3.5, init_dmg: float = 85.0, dps_val: float = 35.0, shooter_id: int = 0, shooter_team: int = 0) -> void:
	if is_multiplayer_match() and not multiplayer.is_server():
		return
	if shooter_team == 0 and shooter_id > 0:
		shooter_team = get_player_team(shooter_id)
	var data = {
		"type": "orbital_laser",
		"pos": pos,
		"rad": rad,
		"delay": delay,
		"dur": dur,
		"init_dmg": init_dmg,
		"dps": dps_val,
		"shooter_id": shooter_id,
		"shooter_team": shooter_team
	}
	if not is_multiplayer_match():
		var laser = _custom_spawn_hazard_zone(data)
		hazard_container.add_child(laser, true)
		return
	hazard_spawner.spawn(data)

func spawn_rail_trail_zone(pos: Vector3, rot_y: float, length: float = 70.0, width: float = 3.2, dur: float = 5.0, dps_val: float = 30.0, slow_pct: float = 0.20, shooter_id: int = 0, shooter_team: int = 0) -> void:
	if is_multiplayer_match() and not multiplayer.is_server():
		return
	if shooter_team == 0 and shooter_id > 0:
		shooter_team = get_player_team(shooter_id)
	var data = {
		"type": "rail_trail",
		"pos": pos,
		"rot_y": rot_y,
		"length": length,
		"width": width,
		"dur": dur,
		"dps": dps_val,
		"slow_pct": slow_pct,
		"shooter_id": shooter_id,
		"shooter_team": shooter_team
	}
	if not is_multiplayer_match():
		var trail = _custom_spawn_hazard_zone(data)
		hazard_container.add_child(trail, true)
		return
	hazard_spawner.spawn(data)

func _custom_spawn_hazard_zone(data: Variant) -> Node:
	if data.get("type") == "orbital_laser":
		var laser = orbital_laser_zone_scene.instantiate()
		laser.position = data["pos"]
		laser.radius = data.get("rad", 3.8)
		laser.initial_delay = data.get("delay", 1.5)
		laser.strike_duration = data.get("dur", 3.5)
		laser.initial_damage = data.get("init_dmg", 85.0)
		laser.dps = data.get("dps", 35.0)
		laser.shooter_id = data.get("shooter_id", 0)
		laser.shooter_team = data.get("shooter_team", 0)
		return laser
	elif data.get("type") == "fence":
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
	elif data.get("type") == "rail_trail":
		var trail = rail_trail_zone_scene.instantiate()
		trail.position = data["pos"]
		if data.has("rot_y"):
			trail.rotation.y = data["rot_y"]
		trail.length = data.get("length", 70.0)
		trail.width = data.get("width", 3.2)
		trail.duration = data.get("dur", 5.0)
		trail.dps = data.get("dps", 30.0)
		trail.slow_percent = data.get("slow_pct", 0.20)
		trail.shooter_id = data.get("shooter_id", 0)
		trail.shooter_team = data.get("shooter_team", 0)
		return trail

	var zone = slowing_dot_zone_scene.instantiate()
	zone.position = data["pos"]
	zone.radius = data.get("rad", 2.2)
	zone.duration = data.get("dur", 4.5)
	zone.damage_per_second = data.get("dmg_ps", 0.0)
	zone.slow_percent = data.get("slow_pct", 0.35)
	zone.shooter_id = data.get("shooter_id", 0)
	zone.shooter_team = data.get("shooter_team", 0)
	return zone

func _process(delta: float) -> void:
	if is_multiplayer_match() and multiplayer.is_server() and match_in_progress and not is_training_mode:
		_check_match_status()

	if match_in_progress and game_mode == "dm":
		dm_match_timer -= delta
		if dm_timer_label:
			var mins = int(max(0.0, dm_match_timer)) / 60
			var secs = int(max(0.0, dm_match_timer)) % 60
			dm_timer_label.text = "⏱ DEATHMATCH: %02d:%02d" % [mins, secs]
			dm_timer_label.show()
		
		if multiplayer.is_server() and dm_match_timer <= 0.0:
			dm_match_timer = 0.0
			match_in_progress = false
			var top_kills = -1
			var top_winner = "NOBODY"
			for pid in connected_players.keys():
				var k = connected_players[pid].get("kills", 0)
				if k > top_kills:
					top_kills = k
					var p_info = connected_players[pid]
					var p_name = p_info.get("name", "Player " + str(pid))
					top_winner = "%s (%d KILLS)" % [p_name, k]
			end_match.rpc(top_winner)
	elif dm_timer_label and dm_timer_label.visible:
		dm_timer_label.hide()

	if Input.is_key_pressed(KEY_TAB):
		if not scoreboard_panel.visible:
			_show_scoreboard(true)
			_scoreboard_refresh_timer = 0.25
		else:
			_scoreboard_refresh_timer -= delta
			if _scoreboard_refresh_timer <= 0.0:
				_scoreboard_refresh_timer = 0.25
				_update_scoreboard_content(false)
	else:
		if scoreboard_panel and scoreboard_panel.visible:
			_show_scoreboard(false)

func _setup_scoreboard_ui() -> void:
	var ui_node = get_node_or_null("UI")
	if not ui_node:
		return
	
	scoreboard_panel = PanelContainer.new()
	scoreboard_panel.name = "ScoreboardPanel"
	scoreboard_panel.visible = false
	scoreboard_panel.anchors_preset = Control.PRESET_CENTER
	scoreboard_panel.anchor_left = 0.5
	scoreboard_panel.anchor_top = 0.5
	scoreboard_panel.anchor_right = 0.5
	scoreboard_panel.anchor_bottom = 0.5
	scoreboard_panel.offset_left = -380.0
	scoreboard_panel.offset_top = -250.0
	scoreboard_panel.offset_right = 380.0
	scoreboard_panel.offset_bottom = 250.0
	scoreboard_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	scoreboard_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	scoreboard_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.13, 0.95)
	style.border_color = Color(0.25, 0.45, 0.75, 0.85)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 20
	style.content_margin_top = 16
	style.content_margin_right = 20
	style.content_margin_bottom = 16
	scoreboard_panel.add_theme_stylebox_override("panel", style)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 8)
	scoreboard_panel.add_child(main_vbox)
	
	var header_lbl = Label.new()
	header_lbl.text = "MATCH ROSTER & STATUS"
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_lbl.add_theme_font_size_override("font_size", 18)
	header_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	main_vbox.add_child(header_lbl)
	
	scoreboard_score_container = VBoxContainer.new()
	scoreboard_score_container.name = "ScoreboardScoreContainer"
	scoreboard_score_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scoreboard_score_container.add_theme_constant_override("separation", 2)
	scoreboard_score_container.visible = false
	main_vbox.add_child(scoreboard_score_container)
	
	scoreboard_score_label = Label.new()
	scoreboard_score_label.name = "ScoreboardScoreLabel"
	scoreboard_score_label.text = "TEAM 1  [ 0 ]   —   [ 0 ]  TEAM 2"
	scoreboard_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scoreboard_score_label.add_theme_font_size_override("font_size", 20)
	scoreboard_score_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	scoreboard_score_container.add_child(scoreboard_score_label)
	
	scoreboard_score_sublabel = Label.new()
	scoreboard_score_sublabel.name = "ScoreboardScoreSublabel"
	scoreboard_score_sublabel.text = "BEST OF FIVE • FIRST TO 3 WINS"
	scoreboard_score_sublabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scoreboard_score_sublabel.add_theme_font_size_override("font_size", 11)
	scoreboard_score_sublabel.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	scoreboard_score_container.add_child(scoreboard_score_sublabel)
	
	scoreboard_status_label = Label.new()
	scoreboard_status_label.text = "TEAM 1: 0/0 ALIVE    |    TEAM 2: 0/0 ALIVE"
	scoreboard_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scoreboard_status_label.add_theme_font_size_override("font_size", 13)
	scoreboard_status_label.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	main_vbox.add_child(scoreboard_status_label)
	
	var sep1 = HSeparator.new()
	main_vbox.add_child(sep1)
	
	# 1. Team-based 2-column container (TDM, Bo5, Training)
	scoreboard_team_container = HBoxContainer.new()
	scoreboard_team_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scoreboard_team_container.add_theme_constant_override("separation", 16)
	main_vbox.add_child(scoreboard_team_container)
	
	# Team 1 Column
	var t1_vbox = VBoxContainer.new()
	t1_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t1_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t1_vbox.add_theme_constant_override("separation", 4)
	scoreboard_team_container.add_child(t1_vbox)
	
	var t1_header = Label.new()
	t1_header.text = "TEAM 1 (BLUE)"
	t1_header.add_theme_font_size_override("font_size", 14)
	t1_header.add_theme_color_override("font_color", Color(0.3, 0.65, 1.0))
	t1_vbox.add_child(t1_header)
	
	var t1_sub_hdr = HBoxContainer.new()
	t1_sub_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t1_lbl_p = Label.new()
	t1_lbl_p.text = "PLAYER"
	t1_lbl_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t1_lbl_p.add_theme_font_size_override("font_size", 11)
	t1_lbl_p.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	t1_sub_hdr.add_child(t1_lbl_p)
	var t1_lbl_s = Label.new()
	t1_lbl_s.text = "STATUS"
	t1_lbl_s.custom_minimum_size = Vector2(85, 0)
	t1_lbl_s.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	t1_lbl_s.add_theme_font_size_override("font_size", 11)
	t1_lbl_s.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	t1_sub_hdr.add_child(t1_lbl_s)
	var t1_lbl_k = Label.new()
	t1_lbl_k.text = "K / D / A"
	t1_lbl_k.custom_minimum_size = Vector2(75, 0)
	t1_lbl_k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	t1_lbl_k.add_theme_font_size_override("font_size", 11)
	t1_lbl_k.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	t1_sub_hdr.add_child(t1_lbl_k)
	t1_vbox.add_child(t1_sub_hdr)
	
	var t1_scroll = ScrollContainer.new()
	t1_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t1_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t1_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	t1_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	t1_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	t1_vbox.add_child(t1_scroll)
	
	scoreboard_t1_list = VBoxContainer.new()
	scoreboard_t1_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scoreboard_t1_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scoreboard_t1_list.add_theme_constant_override("separation", 4)
	t1_scroll.add_child(scoreboard_t1_list)
	
	var v_sep = VSeparator.new()
	scoreboard_team_container.add_child(v_sep)
	
	# Team 2 Column
	var t2_vbox = VBoxContainer.new()
	t2_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t2_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t2_vbox.add_theme_constant_override("separation", 4)
	scoreboard_team_container.add_child(t2_vbox)
	
	var t2_header = Label.new()
	t2_header.text = "TEAM 2 (RED)"
	t2_header.add_theme_font_size_override("font_size", 14)
	t2_header.add_theme_color_override("font_color", Color(1.0, 0.35, 0.4))
	t2_vbox.add_child(t2_header)
	
	var t2_sub_hdr = HBoxContainer.new()
	t2_sub_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t2_lbl_p = Label.new()
	t2_lbl_p.text = "PLAYER"
	t2_lbl_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t2_lbl_p.add_theme_font_size_override("font_size", 11)
	t2_lbl_p.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	t2_sub_hdr.add_child(t2_lbl_p)
	var t2_lbl_s = Label.new()
	t2_lbl_s.text = "STATUS"
	t2_lbl_s.custom_minimum_size = Vector2(85, 0)
	t2_lbl_s.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	t2_lbl_s.add_theme_font_size_override("font_size", 11)
	t2_lbl_s.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	t2_sub_hdr.add_child(t2_lbl_s)
	var t2_lbl_k = Label.new()
	t2_lbl_k.text = "K / D / A"
	t2_lbl_k.custom_minimum_size = Vector2(75, 0)
	t2_lbl_k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	t2_lbl_k.add_theme_font_size_override("font_size", 11)
	t2_lbl_k.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	t2_sub_hdr.add_child(t2_lbl_k)
	t2_vbox.add_child(t2_sub_hdr)
	
	var t2_scroll = ScrollContainer.new()
	t2_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t2_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t2_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	t2_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	t2_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	t2_vbox.add_child(t2_scroll)
	
	scoreboard_t2_list = VBoxContainer.new()
	scoreboard_t2_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scoreboard_t2_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scoreboard_t2_list.add_theme_constant_override("separation", 4)
	t2_scroll.add_child(scoreboard_t2_list)
	
	# 2. Deathmatch Single-List Scrollable Container (DM)
	scoreboard_dm_container = VBoxContainer.new()
	scoreboard_dm_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scoreboard_dm_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scoreboard_dm_container.add_theme_constant_override("separation", 6)
	scoreboard_dm_container.visible = false
	main_vbox.add_child(scoreboard_dm_container)
	
	# Deathmatch Column Header Row
	var dm_hdr_row = HBoxContainer.new()
	dm_hdr_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var dm_hdr_player = Label.new()
	dm_hdr_player.text = "FIGHTER / HERO"
	dm_hdr_player.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dm_hdr_player.add_theme_font_size_override("font_size", 12)
	dm_hdr_player.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	dm_hdr_row.add_child(dm_hdr_player)
	
	var dm_hdr_status = Label.new()
	dm_hdr_status.text = "STATUS"
	dm_hdr_status.custom_minimum_size = Vector2(130, 0)
	dm_hdr_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dm_hdr_status.add_theme_font_size_override("font_size", 12)
	dm_hdr_status.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	dm_hdr_row.add_child(dm_hdr_status)
	
	var dm_hdr_kda = Label.new()
	dm_hdr_kda.text = "K / D / A"
	dm_hdr_kda.custom_minimum_size = Vector2(110, 0)
	dm_hdr_kda.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dm_hdr_kda.add_theme_font_size_override("font_size", 12)
	dm_hdr_kda.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	dm_hdr_row.add_child(dm_hdr_kda)
	
	scoreboard_dm_container.add_child(dm_hdr_row)
	
	scoreboard_dm_scroll = ScrollContainer.new()
	scoreboard_dm_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scoreboard_dm_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scoreboard_dm_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scoreboard_dm_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scoreboard_dm_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	scoreboard_dm_container.add_child(scoreboard_dm_scroll)
	
	scoreboard_dm_list = VBoxContainer.new()
	scoreboard_dm_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scoreboard_dm_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scoreboard_dm_list.add_theme_constant_override("separation", 4)
	scoreboard_dm_scroll.add_child(scoreboard_dm_list)
	
	var sep2 = HSeparator.new()
	main_vbox.add_child(sep2)
	
	var footer_lbl = Label.new()
	footer_lbl.text = "[ Hold TAB to view • Scroll wheel to view more ]"
	footer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_lbl.add_theme_font_size_override("font_size", 11)
	footer_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	main_vbox.add_child(footer_lbl)
	
	ui_node.add_child(scoreboard_panel)

func _show_scoreboard(show: bool) -> void:
	if not scoreboard_panel:
		return
	if show:
		_update_scoreboard_content(true)
		scoreboard_panel.show()
	else:
		scoreboard_panel.hide()

func _update_scoreboard_content(reset_scroll: bool = true) -> void:
	if not scoreboard_panel or not scoreboard_panel.visible:
		return
	
	var dm_scroll_pos = 0
	if scoreboard_dm_scroll and not reset_scroll:
		dm_scroll_pos = scoreboard_dm_scroll.scroll_vertical
	
	var my_id = multiplayer.get_unique_id() if (multiplayer and multiplayer.has_multiplayer_peer()) else 1
	
	if scoreboard_t1_list:
		for c in scoreboard_t1_list.get_children():
			c.queue_free()
	if scoreboard_t2_list:
		for c in scoreboard_t2_list.get_children():
			c.queue_free()
	if scoreboard_dm_list:
		for c in scoreboard_dm_list.get_children():
			c.queue_free()
	
	if scoreboard_score_container:
		if game_mode == "bo5" and not is_training_mode:
			scoreboard_score_container.visible = true
			scoreboard_score_label.text = "TEAM 1  [ %d ]   —   [ %d ]  TEAM 2" % [bo5_score_t1, bo5_score_t2]
			if match_in_progress:
				var current_round = bo5_score_t1 + bo5_score_t2 + 1
				scoreboard_score_sublabel.text = "BEST OF FIVE • FIRST TO 3 WINS (ROUND %d)" % current_round
			else:
				scoreboard_score_sublabel.text = "BEST OF FIVE • FIRST TO 3 WINS"
		else:
			scoreboard_score_container.visible = false
	
	if is_training_mode:
		if scoreboard_team_container: scoreboard_team_container.visible = true
		if scoreboard_dm_container: scoreboard_dm_container.visible = false
		scoreboard_status_label.text = "TRAINING ARENA SESSION"
		var p_node = players_container.get_node_or_null(str(my_id))
		var row = _create_scoreboard_player_row(my_id, "Player (YOU)", selected_character, p_node, true, training_kills, training_deaths, training_assists, false)
		if scoreboard_t1_list:
			scoreboard_t1_list.add_child(row)
		var dummy_node = players_container.get_node_or_null("TrainingDummy")
		if dummy_node:
			var dummy_row = _create_scoreboard_player_row(0, "Training Dummy", "dummy", dummy_node, not dummy_node.get("is_dead"), training_deaths, training_kills, 0, false)
			if scoreboard_t2_list:
				scoreboard_t2_list.add_child(dummy_row)
		return

	if game_mode == "dm":
		if scoreboard_team_container: scoreboard_team_container.visible = false
		if scoreboard_dm_container: scoreboard_dm_container.visible = true
		
		var total_alive = 0
		var p_keys = connected_players.keys()
		
		# Sort Deathmatch players by Kills descending, then lowest Deaths, then Assists
		p_keys.sort_custom(func(a, b):
			var ka = connected_players[a].get("kills", 0)
			var kb = connected_players[b].get("kills", 0)
			if ka != kb:
				return ka > kb
			var da = connected_players[a].get("deaths", 0)
			var db = connected_players[b].get("deaths", 0)
			if da != db:
				return da < db
			return connected_players[a].get("assists", 0) > connected_players[b].get("assists", 0)
		)
		
		for pid in p_keys:
			var p_data = connected_players[pid]
			var p_name = p_data.get("name", "Player " + str(pid))
			var char_key = p_data.get("character", "poke")
			var p_node = players_container.get_node_or_null(str(pid))
			var k = p_data.get("kills", 0)
			var d = p_data.get("deaths", 0)
			var a = p_data.get("assists", 0)
			
			var is_alive = true
			if match_in_progress:
				is_alive = (p_node != null and not p_node.get("is_dead"))
			if is_alive:
				total_alive += 1
			
			var row = _create_scoreboard_player_row(pid, p_name, char_key, p_node, is_alive, k, d, a, true)
			if scoreboard_dm_list:
				scoreboard_dm_list.add_child(row)
		
		if match_in_progress:
			var map_str = ("  •  MAP: " + MAP_NAMES[current_map_id].to_upper()) if (current_map_id >= 0 and current_map_id < MAP_NAMES.size()) else ""
			scoreboard_status_label.text = ("DEATHMATCH (FREE FOR ALL) — %d/%d ALIVE" % [total_alive, connected_players.size()]) + map_str
		else:
			scoreboard_status_label.text = "DEATHMATCH LOBBY (%d Connected Players)" % connected_players.size()
		
		if scoreboard_dm_scroll and not reset_scroll:
			scoreboard_dm_scroll.scroll_vertical = dm_scroll_pos
		return
	
	# Team Deathmatch / Best of Five Layout
	if scoreboard_team_container: scoreboard_team_container.visible = true
	if scoreboard_dm_container: scoreboard_dm_container.visible = false
	if scoreboard_score_container:
		scoreboard_score_container.visible = (game_mode == "bo5")
	
	var t1_alive = 0
	var t1_total = 0
	var t2_alive = 0
	var t2_total = 0
	
	for pid in connected_players.keys():
		var p_data = connected_players[pid]
		var team = p_data.get("team", 1)
		var p_name = p_data.get("name", "Player " + str(pid))
		var char_key = p_data.get("character", "poke")
		var p_node = players_container.get_node_or_null(str(pid))
		var k = p_data.get("kills", 0)
		var d = p_data.get("deaths", 0)
		var a = p_data.get("assists", 0)
		
		var is_alive = true
		if match_in_progress:
			is_alive = (p_node != null and not p_node.get("is_dead"))
		
		if team == 1:
			t1_total += 1
			if is_alive: t1_alive += 1
			var row = _create_scoreboard_player_row(pid, p_name, char_key, p_node, is_alive, k, d, a, false)
			if scoreboard_t1_list:
				scoreboard_t1_list.add_child(row)
		elif team == 2:
			t2_total += 1
			if is_alive: t2_alive += 1
			var row = _create_scoreboard_player_row(pid, p_name, char_key, p_node, is_alive, k, d, a, false)
			if scoreboard_t2_list:
				scoreboard_t2_list.add_child(row)
	
	if match_in_progress:
		var map_str = ("  •  MAP: " + MAP_NAMES[current_map_id].to_upper()) if (current_map_id >= 0 and current_map_id < MAP_NAMES.size()) else ""
		scoreboard_status_label.text = ("TEAM 1: %d/%d ALIVE    |    TEAM 2: %d/%d ALIVE" % [t1_alive, t1_total, t2_alive, t2_total]) + map_str
	else:
		scoreboard_status_label.text = "LOBBY ROSTER (%d Connected Players)" % connected_players.size()

func _create_scoreboard_player_row(pid: int, p_name: String, char_key: String, p_node: Node, is_alive: bool, kills: int = 0, deaths: int = 0, assists: int = 0, is_dm: bool = false) -> Control:
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0, 26)
	
	var my_id = multiplayer.get_unique_id() if (multiplayer and multiplayer.has_multiplayer_peer()) else 1
	var is_me = (pid == my_id)
	
	# 1. Left side: Name and Hero
	var left_box = HBoxContainer.new()
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_box.add_theme_constant_override("separation", 6)
	row.add_child(left_box)
	
	var name_lbl = Label.new()
	name_lbl.text = ("★ " if is_me else "• ") + p_name
	name_lbl.add_theme_font_size_override("font_size", 13)
	if is_me:
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	else:
		name_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	left_box.add_child(name_lbl)
	
	var char_lbl = Label.new()
	char_lbl.text = "[" + get_character_display_name(char_key).to_upper() + "]"
	char_lbl.add_theme_font_size_override("font_size", 11)
	char_lbl.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	left_box.add_child(char_lbl)
	
	# 2. Status Label
	var status_lbl = Label.new()
	status_lbl.custom_minimum_size = Vector2(130 if is_dm else 85, 0)
	status_lbl.add_theme_font_size_override("font_size", 12)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if is_dm else HORIZONTAL_ALIGNMENT_RIGHT
	
	if match_in_progress:
		if _is_peer_pending_disconnect(pid):
			status_lbl.text = "✖ DC"
			status_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
		elif is_alive:
			var hp_text = ""
			if p_node and p_node.get("current_health") != null:
				hp_text = " (%d HP)" % int(p_node.current_health)
			status_lbl.text = "● ALIVE" + hp_text
			status_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		else:
			status_lbl.text = "✖ DEAD"
			status_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	else:
		status_lbl.text = "READY"
		status_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	row.add_child(status_lbl)
	
	# 3. Right side: K/D/A Score
	var kda_lbl = Label.new()
	kda_lbl.custom_minimum_size = Vector2(110 if is_dm else 75, 0)
	kda_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kda_lbl.add_theme_font_size_override("font_size", 12)
	kda_lbl.text = "%d / %d / %d" % [kills, deaths, assists]
	kda_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4) if is_me else Color(0.9, 0.9, 0.95))
	row.add_child(kda_lbl)
	
	return row

func _setup_dm_timer_ui() -> void:
	var ui_node = get_node_or_null("UI")
	if not ui_node:
		return
	dm_timer_label = Label.new()
	dm_timer_label.name = "DMTimerLabel"
	dm_timer_label.anchors_preset = Control.PRESET_CENTER_TOP
	dm_timer_label.anchor_left = 0.5
	dm_timer_label.anchor_right = 0.5
	dm_timer_label.offset_left = -170.0
	dm_timer_label.offset_top = 16.0
	dm_timer_label.offset_right = 170.0
	dm_timer_label.offset_bottom = 48.0
	dm_timer_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dm_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dm_timer_label.add_theme_font_size_override("font_size", 16)
	dm_timer_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.14, 0.88)
	style.border_color = Color(0.85, 0.68, 0.22, 0.9)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	dm_timer_label.add_theme_stylebox_override("panel", style)
	dm_timer_label.visible = false
	ui_node.add_child(dm_timer_label)

func _setup_arena_maps() -> void:
	var arena_node = get_node_or_null("Arena")
	if not arena_node:
		return
	
	arena_maps.clear()
	if default_map:
		arena_maps.append(default_map)
	
	var chasm = MAP_CHASM_SCENE.instantiate()
	chasm.name = "MapChasm"
	chasm.visible = false
	chasm.process_mode = Node.PROCESS_MODE_DISABLED
	arena_node.add_child(chasm)
	arena_maps.append(chasm)
	
	var islands = MAP_ISLANDS_SCENE.instantiate()
	islands.name = "MapIslands"
	islands.visible = false
	islands.process_mode = Node.PROCESS_MODE_DISABLED
	arena_node.add_child(islands)
	arena_maps.append(islands)

func _setup_map_banner_ui() -> void:
	var ui_node = get_node_or_null("UI")
	if not ui_node:
		return
	map_banner_label = Label.new()
	map_banner_label.name = "MapBannerLabel"
	map_banner_label.anchors_preset = Control.PRESET_CENTER_TOP
	map_banner_label.anchor_left = 0.5
	map_banner_label.anchor_right = 0.5
	map_banner_label.offset_left = -220.0
	map_banner_label.offset_top = 54.0
	map_banner_label.offset_right = 220.0
	map_banner_label.offset_bottom = 86.0
	map_banner_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	map_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_banner_label.add_theme_font_size_override("font_size", 15)
	map_banner_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.16, 0.90)
	style.border_color = Color(0.35, 0.65, 0.95, 0.8)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	map_banner_label.add_theme_stylebox_override("panel", style)
	map_banner_label.visible = false
	ui_node.add_child(map_banner_label)

func _pick_next_random_map() -> int:
	if arena_maps.is_empty():
		return 0
	var choices: Array[int] = []
	for i in range(arena_maps.size()):
		if i != current_map_id:
			choices.append(i)
	if choices.is_empty():
		return 0
	return choices[randi() % choices.size()]

@rpc("authority", "call_local", "reliable")
func sync_active_map(map_id: int) -> void:
	current_map_id = map_id
	for i in range(arena_maps.size()):
		var m = arena_maps[i]
		if is_instance_valid(m):
			var active = (i == map_id) and not is_training_mode
			m.visible = active
			m.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	
	if training_map:
		training_map.visible = is_training_mode
		training_map.process_mode = Node.PROCESS_MODE_INHERIT if is_training_mode else Node.PROCESS_MODE_DISABLED
	
	if map_banner_label and not is_training_mode and map_id >= 0 and map_id < MAP_NAMES.size():
		map_banner_label.text = "⚔ ARENA: %s ⚔" % MAP_NAMES[map_id].to_upper()
		map_banner_label.modulate.a = 1.0
		map_banner_label.visible = true
		var tween = create_tween()
		tween.tween_interval(3.0)
		tween.tween_property(map_banner_label, "modulate:a", 0.0, 0.8)
		tween.tween_callback(func(): if map_banner_label: map_banner_label.visible = false)

func _setup_shop_ui() -> void:
	var ui_node = get_node_or_null("UI")
	if not ui_node:
		return
	
	shop_panel = PanelContainer.new()
	shop_panel.name = "ShopPanel"
	shop_panel.visible = false
	shop_panel.anchors_preset = Control.PRESET_CENTER
	shop_panel.anchor_left = 0.5
	shop_panel.anchor_top = 0.5
	shop_panel.anchor_right = 0.5
	shop_panel.anchor_bottom = 0.5
	shop_panel.offset_left = -390.0
	shop_panel.offset_top = -250.0
	shop_panel.offset_right = 390.0
	shop_panel.offset_bottom = 250.0
	shop_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	shop_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	shop_panel.z_index = 20
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.14, 0.96)
	panel_style.border_color = Color(0.28, 0.52, 0.88, 0.9)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 14
	panel_style.content_margin_bottom = 14
	shop_panel.add_theme_stylebox_override("panel", panel_style)
	
	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	shop_panel.add_child(root_vbox)
	
	# 1. Header Bar: Title, Gold Display, Close Button
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 12)
	root_vbox.add_child(header_hbox)
	
	var title_lbl = Label.new()
	title_lbl.text = "🛒 ARMORY SHOP"
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	header_hbox.add_child(title_lbl)
	
	var header_spacer = Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header_spacer)
	
	shop_gold_label = Label.new()
	shop_gold_label.text = "🪙 0 GOLD"
	shop_gold_label.add_theme_font_size_override("font_size", 16)
	shop_gold_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.28))
	header_hbox.add_child(shop_gold_label)
	
	var close_btn = Button.new()
	close_btn.text = " ✕ "
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.pressed.connect(func(): _show_shop(false))
	header_hbox.add_child(close_btn)
	
	# 2. Equipped Inventory Slot Bar
	var slot_hbox = HBoxContainer.new()
	slot_hbox.add_theme_constant_override("separation", 10)
	root_vbox.add_child(slot_hbox)
	
	shop_slot_label = Label.new()
	shop_slot_label.text = "Item Slot (0/1): Empty"
	shop_slot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_slot_label.add_theme_font_size_override("font_size", 13)
	shop_slot_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.98))
	slot_hbox.add_child(shop_slot_label)
	
	shop_sell_btn = Button.new()
	shop_sell_btn.text = "SELL ITEM (+50G)"
	shop_sell_btn.custom_minimum_size = Vector2(140, 28)
	shop_sell_btn.visible = false
	shop_sell_btn.pressed.connect(_on_shop_sell_pressed)
	slot_hbox.add_child(shop_sell_btn)
	
	root_vbox.add_child(HSeparator.new())
	
	# 3. Main Two-Column Layout
	var cols_hbox = HBoxContainer.new()
	cols_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols_hbox.add_theme_constant_override("separation", 14)
	root_vbox.add_child(cols_hbox)
	
	# Left Column: Tabs and Item Lists
	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols_hbox.add_child(left_vbox)
	
	shop_tab_container = TabContainer.new()
	shop_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(shop_tab_container)
	
	var tabs_info = [
		{"name": "All Items", "cat": ItemPipeline.ItemCategory.ALL},
		{"name": "Damage", "cat": ItemPipeline.ItemCategory.DAMAGE},
		{"name": "Tankiness", "cat": ItemPipeline.ItemCategory.TANKINESS},
		{"name": "Utility", "cat": ItemPipeline.ItemCategory.UTILITY}
	]
	
	for tab in tabs_info:
		var scroll = ScrollContainer.new()
		scroll.name = tab["name"]
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		var items_vbox = VBoxContainer.new()
		items_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		items_vbox.add_theme_constant_override("separation", 6)
		scroll.add_child(items_vbox)
		
		var cat_items = ItemPipeline.get_items_by_category(tab["cat"])
		for item in cat_items:
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(0, 44)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.text = "  %s   •   %s   •   🪙 %dG" % [item.name, item.get_stats_description().replace("\n", ", "), item.cost]
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var item_id = item.id
			btn.pressed.connect(func(): _select_inspected_item(item_id))
			items_vbox.add_child(btn)
			
		shop_tab_container.add_child(scroll)
		
	# Vertical separator between columns
	var v_sep = VSeparator.new()
	cols_hbox.add_child(v_sep)
	
	# Right Column: Item Inspector
	var right_vbox = VBoxContainer.new()
	right_vbox.custom_minimum_size = Vector2(270, 0)
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 8)
	cols_hbox.add_child(right_vbox)
	
	# Top of Right Column: Artwork Box (Blank for now)
	var art_panel = PanelContainer.new()
	art_panel.custom_minimum_size = Vector2(0, 110)
	var art_style = StyleBoxFlat.new()
	art_style.bg_color = Color(0.04, 0.05, 0.09, 0.95)
	art_style.border_color = Color(0.24, 0.36, 0.55, 0.75)
	art_style.border_width_left = 1
	art_style.border_width_top = 1
	art_style.border_width_right = 1
	art_style.border_width_bottom = 1
	art_style.corner_radius_top_left = 6
	art_style.corner_radius_top_right = 6
	art_style.corner_radius_bottom_left = 6
	art_style.corner_radius_bottom_right = 6
	art_panel.add_theme_stylebox_override("panel", art_style)
	
	var art_center = CenterContainer.new()
	art_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var art_label = Label.new()
	art_label.text = "🖼\n[ ITEM ARTWORK ]\n(Blank for now)"
	art_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art_label.add_theme_font_size_override("font_size", 11)
	art_label.add_theme_color_override("font_color", Color(0.48, 0.58, 0.72))
	art_center.add_child(art_label)
	art_panel.add_child(art_center)
	right_vbox.add_child(art_panel)
	
	# Item Name and Cost
	shop_inspector_title = Label.new()
	shop_inspector_title.text = "IRON BLADE"
	shop_inspector_title.add_theme_font_size_override("font_size", 15)
	shop_inspector_title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	right_vbox.add_child(shop_inspector_title)
	
	shop_inspector_cost = Label.new()
	shop_inspector_cost.text = "Cost: 100 Gold   •   Sell: 50 Gold"
	shop_inspector_cost.add_theme_font_size_override("font_size", 12)
	shop_inspector_cost.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	right_vbox.add_child(shop_inspector_cost)
	
	right_vbox.add_child(HSeparator.new())
	
	# Stats Section
	var stats_header = Label.new()
	stats_header.text = "STATS GRANTED:"
	stats_header.add_theme_font_size_override("font_size", 11)
	stats_header.add_theme_color_override("font_color", Color(0.65, 0.78, 0.95))
	right_vbox.add_child(stats_header)
	
	shop_inspector_stats = Label.new()
	shop_inspector_stats.text = "+20% Damage Dealt"
	shop_inspector_stats.add_theme_font_size_override("font_size", 13)
	shop_inspector_stats.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55))
	right_vbox.add_child(shop_inspector_stats)
	
	right_vbox.add_child(HSeparator.new())
	
	# Unique Effect Section (blank for now)
	var effect_header = Label.new()
	effect_header.text = "UNIQUE EFFECT:"
	effect_header.add_theme_font_size_override("font_size", 11)
	effect_header.add_theme_color_override("font_color", Color(0.65, 0.78, 0.95))
	right_vbox.add_child(effect_header)
	
	shop_inspector_effect = Label.new()
	shop_inspector_effect.text = "None (Stats only)"
	shop_inspector_effect.add_theme_font_size_override("font_size", 12)
	shop_inspector_effect.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72))
	right_vbox.add_child(shop_inspector_effect)
	
	var r_spacer = Control.new()
	r_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(r_spacer)
	
	shop_inspector_buy_btn = Button.new()
	shop_inspector_buy_btn.text = "BUY ITEM (100G)"
	shop_inspector_buy_btn.custom_minimum_size = Vector2(0, 38)
	shop_inspector_buy_btn.pressed.connect(_on_shop_buy_pressed)
	right_vbox.add_child(shop_inspector_buy_btn)
	
	root_vbox.add_child(HSeparator.new())
	
	var footer_lbl = Label.new()
	footer_lbl.text = "[ Press B or ESC to close shop ]"
	footer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_lbl.add_theme_font_size_override("font_size", 11)
	footer_lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 0.78))
	root_vbox.add_child(footer_lbl)
	
	ui_node.add_child(shop_panel)

func _select_inspected_item(item_id: String) -> void:
	current_inspected_item_id = item_id
	_refresh_shop_ui()

func _on_shop_buy_pressed() -> void:
	var my_id = multiplayer.get_unique_id() if (multiplayer and multiplayer.has_multiplayer_peer()) else 1
	var my_p = players_container.get_node_or_null(str(my_id))
	if my_p and my_p.has_method("buy_item"):
		my_p.buy_item(current_inspected_item_id)
	_refresh_shop_ui()

func _on_shop_sell_pressed() -> void:
	var my_id = multiplayer.get_unique_id() if (multiplayer and multiplayer.has_multiplayer_peer()) else 1
	var my_p = players_container.get_node_or_null(str(my_id))
	if my_p and my_p.has_method("sell_item") and my_p.item_slots.size() > 0:
		my_p.sell_item(my_p.item_slots[0])
	_refresh_shop_ui()

func _show_shop(show: bool) -> void:
	if not shop_panel:
		return
	if show:
		_refresh_shop_ui()
		shop_panel.show()
		shop_panel.move_to_front()
	else:
		shop_panel.hide()

func _refresh_shop_ui() -> void:
	if not shop_panel:
		return
	var my_id = multiplayer.get_unique_id() if (multiplayer and multiplayer.has_multiplayer_peer()) else 1
	var my_p = players_container.get_node_or_null(str(my_id))
	
	var cur_gold = 0
	var cur_items: Array = []
	if my_p:
		cur_gold = my_p.gold
		cur_items = my_p.item_slots
	elif connected_players.has(my_id):
		cur_gold = connected_players[my_id].get("gold", 0)
		cur_items = connected_players[my_id].get("items", [])
	
	if shop_gold_label:
		if is_training_mode:
			shop_gold_label.text = "🪙 ∞ GOLD"
		else:
			shop_gold_label.text = "🪙 %d GOLD" % cur_gold
	
	if shop_slot_label:
		if cur_items.size() > 0:
			var it_def = ItemPipeline.get_item(cur_items[0])
			var it_name = it_def.name if it_def else str(cur_items[0])
			var it_stats = it_def.get_stats_description().replace("\n", ", ") if it_def else ""
			shop_slot_label.text = "Item Slot (1/1): [%s] (%s)" % [it_name, it_stats]
			if shop_sell_btn:
				shop_sell_btn.visible = true
				shop_sell_btn.text = "SELL ITEM (+50G)"
		else:
			shop_slot_label.text = "Item Slot (0/1): Empty"
			if shop_sell_btn:
				shop_sell_btn.visible = false
	
	# Update inspector on right
	var inspect_def = ItemPipeline.get_item(current_inspected_item_id)
	if inspect_def and shop_inspector_title:
		shop_inspector_title.text = inspect_def.name.to_upper()
		shop_inspector_cost.text = "Cost: %d Gold   •   Sell: %d Gold" % [inspect_def.cost, int(inspect_def.cost * 0.5)]
		shop_inspector_stats.text = inspect_def.get_stats_description()
		shop_inspector_effect.text = inspect_def.get_unique_feature_description()
		
		if cur_items.has(inspect_def.id):
			shop_inspector_buy_btn.text = "ALREADY EQUIPPED"
			shop_inspector_buy_btn.disabled = true
		elif cur_items.size() >= 1:
			shop_inspector_buy_btn.text = "SLOT FULL (Sell item first)"
			shop_inspector_buy_btn.disabled = true
		elif not is_training_mode and cur_gold < inspect_def.cost:
			shop_inspector_buy_btn.text = "NEED %d GOLD" % inspect_def.cost
			shop_inspector_buy_btn.disabled = true
		else:
			shop_inspector_buy_btn.text = "BUY ITEM (%dG)" % inspect_def.cost
			shop_inspector_buy_btn.disabled = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_B or event.physical_keycode == KEY_B):
		if shop_panel and shop_panel.visible:
			_show_shop(false)
			get_viewport().set_input_as_handled()
			return
		elif is_training_mode or (match_in_progress and game_mode != "tdm"):
			_show_shop(true)
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("ui_cancel"):
		if shop_panel and shop_panel.visible:
			_show_shop(false)
			get_viewport().set_input_as_handled()
			return
		elif settings_panel.visible:
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
	_bo5_round_transition_active = false
	bo5_score_t1 = 0
	bo5_score_t2 = 0
	training_kills = 0
	training_deaths = 0
	training_assists = 0
	_show_shop(false)
	if dm_timer_label:
		dm_timer_label.hide()
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
		_process_pending_disconnects()
		sync_bo5_score.rpc(0, 0)
	
	current_map_id = -1
	if map_banner_label:
		map_banner_label.hide()
	for i in range(arena_maps.size()):
		var m = arena_maps[i]
		if is_instance_valid(m):
			var active = (i == 0) and not is_training_mode
			m.visible = active
			m.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if training_map:
		training_map.visible = is_training_mode
		training_map.process_mode = Node.PROCESS_MODE_INHERIT if is_training_mode else Node.PROCESS_MODE_DISABLED

func _on_leave_match_pressed() -> void:
	_leave_to_main_menu()

@rpc("authority", "call_local", "reliable")
func host_ended_session() -> void:
	_leave_to_main_menu()

func _leave_to_main_menu() -> void:
	_cleanup_upnp()
	if http_request_host:
		http_request_host.cancel_request()
	if http_request_join:
		http_request_join.cancel_request()
	current_room_code = ""
	_show_shop(false)
	if dm_timer_label:
		dm_timer_label.hide()
	if map_banner_label:
		map_banner_label.hide()
	current_map_id = -1
	
	if multiplayer.multiplayer_peer and multiplayer.is_server() and connected_players.size() > 1:
		host_ended_session.rpc()
	
	escape_panel.hide()
	join_dialog.hide()
	settings_panel.hide()
	match_over_panel.hide()
	lobby_panel.hide()
	menu_panel.show()
	if join_status_label:
		join_status_label.hide()
	
	match_in_progress = false
	is_training_mode = false
	_bo5_round_transition_active = false
	pending_disconnect_peers.clear()
	bo5_score_t1 = 0
	bo5_score_t2 = 0
	training_kills = 0
	training_deaths = 0
	training_assists = 0
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
	
	for i in range(arena_maps.size()):
		var m = arena_maps[i]
		if is_instance_valid(m):
			var active = (i == 0)
			m.visible = active
			m.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
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

func _update_host_lobby_info(ip_str: String, _local_ip: String, port: int, upnp_success: bool) -> void:
	if not lobby_panel.visible or is_training_mode:
		return
	if upnp_success and not current_room_code.is_empty():
		_register_room_backend(current_room_code, ip_str, port)
	lobby_ip_label.text = "ROOM CODE: %s" % current_room_code

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
