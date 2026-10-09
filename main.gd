extends Node3D

const PORT: int = 7000

const CharacterRegistry = preload("res://characters/character_registry.gd")
const CharacterData = preload("res://characters/character_data.gd")
const EnabledCharacters = preload("res://characters/enabled_characters.gd")
const LevelBadgeClass = preload("res://characters/leveling/level_badge.gd")

const CHARACTERS: Dictionary = {
	"poke": preload("res://characters/poke/poke.tscn"),
	"crush": preload("res://characters/crush/crush.tscn"),
	"aspara": preload("res://characters/aspara/aspara.tscn"),
	"asparsas": preload("res://characters/aspara/aspara.tscn"),
	"reaper": preload("res://characters/Disabled characters/reaper/reaper.tscn"),
	"morrigan": preload("res://characters/morrigan/morrigan.tscn"),
	"monkey": preload("res://characters/monkey/monkey.tscn"),
	"silene": preload("res://characters/silene/silene.tscn"),
	"artist": preload("res://characters/artist/artist.tscn"),
	"cleodolinda": preload("res://characters/cleodolinda/cleodolinda.tscn"),
	"cleo": preload("res://characters/cleodolinda/cleodolinda.tscn")
}

const CHARACTER_DISPLAY_NAMES: Dictionary = {
	"poke": "Aslan",
	"crush": "Gil",
	"aspara": "Uru",
	"asparsas": "Uru",
	"reaper": "Keres",
	"morrigan": "Saga",
	"monkey": "Sunny Kong",
	"silene": "Wynn Wyrmchilde",
	"artist": "Inky",
	"cleodolinda": "Cleo",
	"cleo": "Cleo",
	"dummy": "Training Dummy"
}

static func get_character_display_name(char_key: String) -> String:
	return CharacterRegistry.get_display_name(char_key)

@export var projectile_scene: PackedScene = preload("res://projectile.tscn")
@export var slowing_dot_zone_scene: PackedScene = preload("res://ability/zones/slowing_dot_zone.tscn")
@export var terrain_scene: PackedScene = preload("res://maps/temporary_terrain.tscn")
@export var vision_reveal_zone_scene: PackedScene = preload("res://ability/zones/vision_reveal_zone.tscn")
@export var fence_zone_scene: PackedScene = preload("res://ability/zones/fence_zone.tscn")
@export var orbital_laser_zone_scene: PackedScene = preload("res://ability/zones/orbital_laser_zone.tscn")
@export var rail_trail_zone_scene: PackedScene = preload("res://ability/zones/rail_trail_zone.tscn")
@export var battle_royale_zone_scene: PackedScene = preload("res://zones/battle_royale_zone.tscn")

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
@onready var join_local_button: Button = get_node_or_null("UI/JoinDialog/VBox/HBox/JoinLocalButton")
@onready var confirm_join_button: Button = $UI/JoinDialog/VBox/HBox/ConfirmJoinButton

@onready var lobby_ip_label: Label = $UI/LobbyRoom/VBox/HBoxRoomCode/HostIPDisplay
@onready var copy_code_button: Button = get_node_or_null("UI/LobbyRoom/VBox/HBoxRoomCode/CopyCodeButton")
@onready var game_mode_option: OptionButton = get_node_or_null("UI/LobbyRoom/VBox/HBoxGameMode/GameModeOption")
@onready var hbox_game_mode: HBoxContainer = get_node_or_null("UI/LobbyRoom/VBox/HBoxGameMode")
@onready var map_option: OptionButton = get_node_or_null("UI/LobbyRoom/VBox/HBoxMap/MapOption")
@onready var hbox_map: HBoxContainer = get_node_or_null("UI/LobbyRoom/VBox/HBoxMap")
@onready var origin_all_btn: Button = get_node_or_null("UI/LobbyRoom/VBox/CharSelectSection/OriginsBar/OriginAll")
@onready var origin_mortal_btn: Button = get_node_or_null("UI/LobbyRoom/VBox/CharSelectSection/OriginsBar/OriginMortal")
@onready var origin_divine_btn: Button = get_node_or_null("UI/LobbyRoom/VBox/CharSelectSection/OriginsBar/OriginDivine")
@onready var origin_monstrous_btn: Button = get_node_or_null("UI/LobbyRoom/VBox/CharSelectSection/OriginsBar/OriginMonstrous")

@onready var arch_all_btn: Button = get_node_or_null("UI/LobbyRoom/VBox/CharSelectSection/BodyHBox/ArchetypeSidebar/ArchAll")
@onready var arch_vanguard_btn: Button = get_node_or_null("UI/LobbyRoom/VBox/CharSelectSection/BodyHBox/ArchetypeSidebar/ArchVanguard")
@onready var arch_brawler_btn: Button = get_node_or_null("UI/LobbyRoom/VBox/CharSelectSection/BodyHBox/ArchetypeSidebar/ArchBrawler")
@onready var arch_striker_btn: Button = get_node_or_null("UI/LobbyRoom/VBox/CharSelectSection/BodyHBox/ArchetypeSidebar/ArchStriker")
@onready var arch_blaster_btn: Button = get_node_or_null("UI/LobbyRoom/VBox/CharSelectSection/BodyHBox/ArchetypeSidebar/ArchBlaster")

@onready var char_grid: GridContainer = get_node_or_null("UI/LobbyRoom/VBox/CharSelectSection/BodyHBox/CharGridScroll/CharGrid")

# Legacy button handles (safe fallbacks)
var select_poke_button: Button = null
var select_crush_button: Button = null
var select_asparsas_button: Button = null
var select_reaper_button: Button = null
var select_morrigan_button: Button = null
var select_monkey_button: Button = null
var select_silene_button: Button = null
var select_artist_button: Button = null
var select_cleo_button: Button = null
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
@onready var switch_asparsas_btn: Button = $"UI/EscapeMenu/VBox/EscapeTabContainer/Switch Character/SwitchAsparsas"
@onready var switch_reaper_btn: Button = get_node_or_null("UI/EscapeMenu/VBox/EscapeTabContainer/Switch Character/SwitchReaper")
@onready var switch_morrigan_btn: Button = get_node_or_null("UI/EscapeMenu/VBox/EscapeTabContainer/Switch Character/SwitchMorrigan")
@onready var switch_monkey_btn: Button = get_node_or_null("UI/EscapeMenu/VBox/EscapeTabContainer/Switch Character/SwitchMonkey")
@onready var switch_silene_btn: Button = get_node_or_null("UI/EscapeMenu/VBox/EscapeTabContainer/Switch Character/SwitchSilene")
@onready var switch_artist_btn: Button = get_node_or_null("UI/EscapeMenu/VBox/EscapeTabContainer/Switch Character/SwitchArtist")
@onready var switch_cleo_btn: Button = get_node_or_null("UI/EscapeMenu/VBox/EscapeTabContainer/Switch Character/SwitchCleo")

@onready var switch_map_standard: Button = get_node_or_null("UI/EscapeMenu/VBox/EscapeTabContainer/Switch Map/SwitchMapStandard")
@onready var switch_map_colosseum: Button = get_node_or_null("UI/EscapeMenu/VBox/EscapeTabContainer/Switch Map/SwitchMapColosseum")
@onready var switch_map_chasm: Button = get_node_or_null("UI/EscapeMenu/VBox/EscapeTabContainer/Switch Map/SwitchMapChasm")
@onready var switch_map_islands: Button = get_node_or_null("UI/EscapeMenu/VBox/EscapeTabContainer/Switch Map/SwitchMapIslands")
@onready var switch_map_expanse: Button = get_node_or_null("UI/EscapeMenu/VBox/EscapeTabContainer/Switch Map/SwitchMapExpanse")

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

@onready var t3_slots: Array[Button] = [
	$UI/LobbyRoom/VBox/TeamSection/HBoxTeams/VBoxTeam3/T3Slot0,
	$UI/LobbyRoom/VBox/TeamSection/HBoxTeams/VBoxTeam3/T3Slot1,
	$UI/LobbyRoom/VBox/TeamSection/HBoxTeams/VBoxTeam3/T3Slot2
]

var selected_character: String = "poke"
var connected_players: Dictionary = {}
var match_in_progress: bool = false
var is_training_mode: bool = false
var game_mode: String = "tdm" # "tdm" = Team Deathmatch (3v3v3), "dm" = Deathmatch (FFA), "bo5" = Best of Five
var current_room_code: String = ""

var bo5_score_t1: int = 0
var bo5_score_t2: int = 0
var bo5_score_t3: int = 0
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
	var current_mode = GameModes.get_mode(game_mode)
	return current_mode.check_player_deficits(connected_players, _is_peer_pending_disconnect)

func _is_network_active() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return false
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return false
	return multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED

func _is_sender_host() -> bool:
	if not _is_network_active():
		return true
	if multiplayer.is_server():
		return true
	return multiplayer.get_remote_sender_id() == 1

@rpc("any_peer", "call_local", "reliable")
func sync_pending_disconnects(disconnected_ids: Array) -> void:
	if not _is_sender_host():
		return
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
		var p_node = players_container.get_node_or_null(str(pid))
		var lvl = p_node.player_level if (p_node and "player_level" in p_node) else connected_players[pid].get("level", 1)
		connected_players[pid]["level"] = lvl
		kda_dict[pid] = {
			"kills": connected_players[pid].get("kills", 0),
			"deaths": connected_players[pid].get("deaths", 0),
			"assists": connected_players[pid].get("assists", 0),
			"level": lvl
		}
	sync_player_kda.rpc(kda_dict)

@rpc("any_peer", "call_local", "reliable")
func sync_player_kda(kda_dict: Dictionary) -> void:
	if not _is_sender_host():
		return
	for pid in kda_dict.keys():
		for k in connected_players.keys():
			if str(k) == str(pid):
				connected_players[k]["kills"] = kda_dict[pid].get("kills", 0)
				connected_players[k]["deaths"] = kda_dict[pid].get("deaths", 0)
				connected_players[k]["assists"] = kda_dict[pid].get("assists", 0)
				connected_players[k]["level"] = kda_dict[pid].get("level", 1)
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
var scoreboard_t3_list: VBoxContainer = null

var scoreboard_dm_container: VBoxContainer = null
var scoreboard_dm_scroll: ScrollContainer = null
var scoreboard_dm_list: VBoxContainer = null
var scoreboard_training_container: HBoxContainer = null
var scoreboard_training_scroll: ScrollContainer = null
var scoreboard_training_list: VBoxContainer = null
var scoreboard_training_status_label: Label = null
var scoreboard_training_count_label: Label = null
var scoreboard_training_code_box: Control = null
var scoreboard_training_code_label: Label = null
var scoreboard_training_copy_btn: Button = null
var scoreboard_training_toggle_btn: Button = null
var scoreboard_footer_label: Label = null
var _scoreboard_refresh_timer: float = 0.0

# --- Multi-Map Architecture Variables ---
const MAP_COLOSSEUM_SCENE: PackedScene = MapRegistry.MAP_COLOSSEUM_SCENE
const MAP_CHASM_SCENE: PackedScene = MapRegistry.MAP_CHASM_SCENE
const MAP_ISLANDS_SCENE: PackedScene = MapRegistry.MAP_ISLANDS_SCENE
const MAP_EXPANSE_SCENE: PackedScene = MapRegistry.MAP_EXPANSE_SCENE
const MAP_NAMES: Array[String] = MapRegistry.MAP_NAMES

var arena_maps: Array[Node3D] = []
var current_map_id: int = -1
var training_selected_map: int = -1 # -1: Standard Training Map, 0: Colosseum, 1: The Jagged Chasm, 2: Shattered Archipelago, 3: The Great Expanse
var selected_custom_map: int = -1 # -1: Random Map, 0: Colosseum, etc.
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

# --- Deathmatch Timer & Unified Top-Center HUD Variables ---
var dm_match_timer: float = 300.0
var dm_timer_label: Label = null
var top_center_container: VBoxContainer = null
var top_hazard_container: VBoxContainer = null
var top_hazard_warning_label: Label = null
var top_hazard_arrow: Label = null

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
		for opt in GameModes.get_ui_options():
			game_mode_option.add_item(opt["label"], opt["index"])
		game_mode_option.item_selected.connect(_on_game_mode_selected)
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	cancel_join_button.pressed.connect(func():
		var uism = get_node_or_null("/root/UIStateMachine")
		if uism:
			uism.transition_to(uism.State.MAIN_MENU)
		else:
			join_dialog.hide()
	)
	if join_local_button:
		join_local_button.pressed.connect(func():
			current_room_code = ""
			_join_direct_ip("127.0.0.1")
		)
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
	_setup_character_filters_and_grid()
	lobby_back_button.pressed.connect(_on_lobby_back_pressed)
	start_match_button.pressed.connect(_on_start_match_pressed)
	
	resume_button.pressed.connect(func(): escape_panel.hide())
	escape_settings_button.pressed.connect(_open_settings_menu)
	exit_match_button.pressed.connect(_on_exit_match_pressed)
	leave_match_button.pressed.connect(_on_leave_match_pressed)
	
	switch_poke_btn.pressed.connect(func(): _switch_training_character("poke"))
	switch_crush_btn.pressed.connect(func(): _switch_training_character("crush"))
	switch_asparsas_btn.pressed.connect(func(): _switch_training_character("aspara"))
	if switch_reaper_btn:
		switch_reaper_btn.pressed.connect(func(): _switch_training_character("reaper"))
	if switch_morrigan_btn:
		switch_morrigan_btn.pressed.connect(func(): _switch_training_character("morrigan"))
	var switch_char_tab = get_node_or_null("UI/EscapeMenu/VBox/EscapeTabContainer/Switch Character")
	if switch_char_tab and not switch_monkey_btn:
		switch_monkey_btn = Button.new()
		switch_monkey_btn.name = "SwitchMonkey"
		switch_monkey_btn.text = "🐒 Sunny Kong (Trickster - 160 HP)"
		switch_monkey_btn.custom_minimum_size = Vector2(0, 34)
		switch_char_tab.add_child(switch_monkey_btn)
	if switch_monkey_btn:
		switch_monkey_btn.pressed.connect(func(): _switch_training_character("monkey"))
	if switch_char_tab and not switch_silene_btn:
		switch_silene_btn = Button.new()
		switch_silene_btn.name = "SwitchSilene"
		switch_silene_btn.text = "🐉 Wynn Wyrmchilde (Juggernaut - 320 HP)"
		switch_silene_btn.custom_minimum_size = Vector2(0, 34)
		switch_char_tab.add_child(switch_silene_btn)
	if switch_silene_btn:
		switch_silene_btn.pressed.connect(func(): _switch_training_character("silene"))
	if switch_char_tab and not switch_artist_btn:
		switch_artist_btn = Button.new()
		switch_artist_btn.name = "SwitchArtist"
		switch_artist_btn.text = "🖌️ Inky (Calligrapher - 200 HP)"
		switch_artist_btn.custom_minimum_size = Vector2(0, 34)
		switch_char_tab.add_child(switch_artist_btn)
	if switch_artist_btn:
		switch_artist_btn.pressed.connect(func(): _switch_training_character("artist"))
	if switch_char_tab and not switch_cleo_btn:
		switch_cleo_btn = Button.new()
		switch_cleo_btn.name = "SwitchCleo"
		switch_cleo_btn.text = "🛹 Cleo (Hoverboarder - 180 HP)"
		switch_cleo_btn.custom_minimum_size = Vector2(0, 34)
		switch_char_tab.add_child(switch_cleo_btn)
	if switch_cleo_btn:
		switch_cleo_btn.pressed.connect(func(): _switch_training_character("cleodolinda"))
	if switch_char_tab:
		var switch_info = switch_char_tab.get_node_or_null("SwitchInfo")
		if switch_info:
			switch_char_tab.move_child(switch_info, -1)
	
	if map_option:
		map_option.item_selected.connect(_on_map_option_selected)
	if switch_map_standard:
		switch_map_standard.pressed.connect(func(): _switch_training_map(-1))
	if switch_map_colosseum:
		switch_map_colosseum.pressed.connect(func(): _switch_training_map(0))
	if switch_map_chasm:
		switch_map_chasm.pressed.connect(func(): _switch_training_map(1))
	if switch_map_islands:
		switch_map_islands.pressed.connect(func(): _switch_training_map(2))
	if switch_map_expanse:
		switch_map_expanse.pressed.connect(func(): _switch_training_map(3))
	
	if settings_panel and settings_panel.has_signal("settings_closed"):
		settings_panel.settings_closed.connect(_on_settings_closed)
	
	for i in range(t1_slots.size()):
		var s_idx = i
		t1_slots[i].pressed.connect(func(): _on_slot_clicked(1, s_idx))
		t2_slots[i].pressed.connect(func(): _on_slot_clicked(2, s_idx))
		t3_slots[i].pressed.connect(func(): _on_slot_clicked(3, s_idx))
	
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
	
	var uism = get_node_or_null("/root/UIStateMachine")
	if uism:
		uism.register_element(menu_panel, uism.UICategory.NON_DIEGETIC, [uism.State.MAIN_MENU])
		uism.register_element(join_dialog, uism.UICategory.NON_DIEGETIC, [uism.State.JOIN_DIALOG])
		uism.register_element(lobby_panel, uism.UICategory.NON_DIEGETIC, [uism.State.LOBBY])
		uism.register_element(match_over_panel, uism.UICategory.NON_DIEGETIC, [uism.State.MATCH_OVER])
		uism.register_element(escape_panel, uism.UICategory.NON_DIEGETIC, [uism.State.PAUSED])
		if settings_panel:
			uism.register_element(settings_panel, uism.UICategory.NON_DIEGETIC, [uism.State.PAUSED])
		var fow_canvas = get_node_or_null("FogOfWarCanvas")
		if fow_canvas:
			uism.register_element(fow_canvas, uism.UICategory.NON_DIEGETIC, [uism.State.IN_MATCH])
		uism.transition_to(uism.State.MAIN_MENU)
	else:
		menu_panel.show()
		lobby_panel.hide()
		join_dialog.hide()
		match_over_panel.hide()
		escape_panel.hide()
		if settings_panel:
			settings_panel.hide()
	_refresh_character_selection_ui()
	var default_char = "poke"
	if not EnabledCharacters.is_character_enabled(default_char):
		var en = EnabledCharacters.get_enabled_characters()
		if not en.is_empty():
			default_char = en[0]
	_select_character(default_char)

var current_origin_filter: String = "all"
var current_archetype_filter: String = "all"
var _character_card_nodes: Dictionary = {}

func _setup_character_filters_and_grid() -> void:
	if origin_all_btn: origin_all_btn.pressed.connect(func(): _set_origin_filter("all"))
	if origin_mortal_btn: origin_mortal_btn.pressed.connect(func(): _set_origin_filter("mortal"))
	if origin_divine_btn: origin_divine_btn.pressed.connect(func(): _set_origin_filter("divine"))
	if origin_monstrous_btn: origin_monstrous_btn.pressed.connect(func(): _set_origin_filter("monstrous"))

	if arch_all_btn: arch_all_btn.pressed.connect(func(): _set_archetype_filter("all"))
	if arch_vanguard_btn: arch_vanguard_btn.pressed.connect(func(): _set_archetype_filter("vanguard"))
	if arch_brawler_btn: arch_brawler_btn.pressed.connect(func(): _set_archetype_filter("brawler"))
	if arch_striker_btn: arch_striker_btn.pressed.connect(func(): _set_archetype_filter("striker"))
	if arch_blaster_btn: arch_blaster_btn.pressed.connect(func(): _set_archetype_filter("blaster"))

	_update_filter_button_visuals()
	_rebuild_character_grid()

func _set_origin_filter(orig: String) -> void:
	current_origin_filter = orig
	_update_filter_button_visuals()
	_rebuild_character_grid()

func _set_archetype_filter(arch: String) -> void:
	current_archetype_filter = arch
	_update_filter_button_visuals()
	_rebuild_character_grid()

func _update_filter_button_visuals() -> void:
	var origin_buttons = {
		"all": origin_all_btn,
		"mortal": origin_mortal_btn,
		"divine": origin_divine_btn,
		"monstrous": origin_monstrous_btn
	}
	for key in origin_buttons:
		var btn: Button = origin_buttons[key]
		if btn:
			if current_origin_filter == key:
				btn.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0, 1.0))
			else:
				btn.remove_theme_color_override("font_color")

	var arch_buttons = {
		"all": arch_all_btn,
		"vanguard": arch_vanguard_btn,
		"brawler": arch_brawler_btn,
		"striker": arch_striker_btn,
		"blaster": arch_blaster_btn
	}
	for key in arch_buttons:
		var btn: Button = arch_buttons[key]
		if btn:
			if current_archetype_filter == key:
				btn.add_theme_color_override("font_color", Color(1.0, 0.82, 0.2, 1.0))
			else:
				btn.remove_theme_color_override("font_color")

func _rebuild_character_grid() -> void:
	if not char_grid:
		return
	for child in char_grid.get_children():
		child.queue_free()
	_character_card_nodes.clear()

	# 1. Gather all canonical enabled character keys
	var canonical_keys: Array[String] = []
	for k in CharacterRegistry.get_all_character_keys():
		if k == "cleo" or k == "asparsas": # Skip duplicate aliases
			continue
		if EnabledCharacters.is_character_enabled(k) and not canonical_keys.has(k):
			canonical_keys.append(k)

	# 2. Sort strictly in alphabetical order by ID (not display name)
	canonical_keys.sort()

	# 3. Filter characters
	var filtered_keys: Array[String] = []
	if current_archetype_filter != "all":
		# No characters assigned to archetypes: clicking one results in all characters disappearing
		filtered_keys = []
	else:
		for k in canonical_keys:
			if current_origin_filter == "all":
				filtered_keys.append(k)
			elif CharacterRegistry.character_has_origin(k, current_origin_filter):
				filtered_keys.append(k)

	if filtered_keys.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No characters match the selected filters."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75, 0.8))
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.custom_minimum_size = Vector2(300, 60)
		char_grid.add_child(empty_lbl)
		return

	# 4. Create blank portrait cards in alphabetical order
	for k in filtered_keys:
		var card = _create_character_card(k)
		char_grid.add_child(card)
		_character_card_nodes[k] = card

	_update_character_grid_selection()

func _create_character_card(char_id: String) -> Control:
	var btn = Button.new()
	btn.name = "CharCard_" + char_id
	btn.custom_minimum_size = Vector2(84, 106)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.flat = true

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	btn.add_child(vbox)

	# Blank portrait panel
	var portrait_panel = PanelContainer.new()
	portrait_panel.name = "PortraitPanel"
	portrait_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_panel.custom_minimum_size = Vector2(70, 70)
	portrait_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var portrait_box = StyleBoxFlat.new()
	portrait_box.bg_color = Color(0.12, 0.15, 0.20, 0.95)
	portrait_box.set_corner_radius_all(6)
	portrait_box.border_width_left = 2
	portrait_box.border_width_top = 2
	portrait_box.border_width_right = 2
	portrait_box.border_width_bottom = 2
	portrait_box.border_color = Color(0.28, 0.35, 0.45, 0.7)
	portrait_panel.add_theme_stylebox_override("panel", portrait_box)

	vbox.add_child(portrait_panel)

	# Name label underneath
	var name_lbl = Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.text = CharacterRegistry.get_display_name(char_id)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 1.0))
	name_lbl.clip_text = true
	name_lbl.custom_minimum_size = Vector2(80, 20)
	vbox.add_child(name_lbl)

	btn.pressed.connect(func(): _select_character(char_id))
	return btn

func _update_character_grid_selection() -> void:
	for cid in _character_card_nodes:
		var card: Button = _character_card_nodes[cid]
		if not is_instance_valid(card):
			continue
		var is_selected = (cid == selected_character) or (cid == "cleodolinda" and selected_character == "cleo")
		var p_panel = card.get_node_or_null("VBox/PortraitPanel") as PanelContainer
		var name_lbl = card.get_node_or_null("VBox/NameLabel") as Label
		
		if p_panel:
			var box = p_panel.get_theme_stylebox("panel") as StyleBoxFlat
			if box:
				var new_box = box.duplicate() as StyleBoxFlat
				if is_selected:
					new_box.border_color = Color(0.25, 0.85, 1.0, 1.0)
					new_box.border_width_left = 3
					new_box.border_width_top = 3
					new_box.border_width_right = 3
					new_box.border_width_bottom = 3
					new_box.bg_color = Color(0.16, 0.26, 0.38, 0.95)
				else:
					new_box.border_color = Color(0.28, 0.35, 0.45, 0.7)
					new_box.border_width_left = 2
					new_box.border_width_top = 2
					new_box.border_width_right = 2
					new_box.border_width_bottom = 2
					new_box.bg_color = Color(0.12, 0.15, 0.20, 0.95)
				p_panel.add_theme_stylebox_override("panel", new_box)
				
		if name_lbl:
			var base_name = CharacterRegistry.get_display_name(cid)
			if is_selected:
				name_lbl.text = "★ " + base_name
				name_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0, 1.0))
			else:
				name_lbl.text = base_name
				name_lbl.remove_theme_color_override("font_color")

func _refresh_character_selection_ui() -> void:
	_rebuild_character_grid()
	if switch_poke_btn: switch_poke_btn.visible = EnabledCharacters.is_character_enabled("poke")
	if switch_crush_btn: switch_crush_btn.visible = EnabledCharacters.is_character_enabled("crush")
	if switch_asparsas_btn: switch_asparsas_btn.visible = EnabledCharacters.is_character_enabled("aspara")
	if switch_reaper_btn: switch_reaper_btn.visible = EnabledCharacters.is_character_enabled("reaper")
	if switch_morrigan_btn: switch_morrigan_btn.visible = EnabledCharacters.is_character_enabled("morrigan")
	if switch_monkey_btn: switch_monkey_btn.visible = EnabledCharacters.is_character_enabled("monkey")
	if switch_silene_btn: switch_silene_btn.visible = EnabledCharacters.is_character_enabled("silene")
	if switch_artist_btn: switch_artist_btn.visible = EnabledCharacters.is_character_enabled("artist")
	if switch_cleo_btn: switch_cleo_btn.visible = EnabledCharacters.is_character_enabled("cleodolinda")

func _select_character(char_key: String) -> void:
	if not EnabledCharacters.is_character_enabled(char_key):
		var en = EnabledCharacters.get_enabled_characters()
		if not en.is_empty():
			char_key = en[0]
		else:
			return
	selected_character = char_key
	_update_character_grid_selection()

	if char_key == "poke":
		char_desc_label.text = "ASLAN: Sharpshooter (160 HP). Passive [Takedown Rush]: Dash resets on takedown. [LMB]: Rapid Pulse Shot. [RMB]: Sniper Stance (2s Charge). [Q]: Overcharged Rounds. [E]: Ion Fence. [R]: Orbital Hyperbeam (2s Channel, Piercing)."
	elif char_key == "crush":
		char_desc_label.text = "GIL: Juggernaut (160 HP). Passive [Titan's Surge]: Spells empower LMB (+25 dmg + heal). [LMB]: Slam. [RMB]: Fan stun. [Q]: Shockwave & Shield. [E]: Iron Blood (converts Gray Health to shield / regens)."
	elif char_key == "aspara" or char_key == "asparsas":
		char_desc_label.text = "URU: Skirmisher (240 HP). Passive [Rupture Marks]: Stacking burst marks detonated for damage and 11-15% missing HP heal. [LMB]: Slash. [RMB]: Cleave. [Q]: Earth Tremor. [E]: Deflecting Guard (75% frontal DR). [Shift]: Wall Bounce."
	elif char_key == "reaper":
		char_desc_label.text = "KERES: Assassin / Skirmisher (90 HP). Passive [Soul Harvest]: +15% MS steal on LMB. [RMB]: Spectral Tether (Charged throw: grounds + progressive slow -> roots & disables all movement). [Q]: Cull the Weak (sweet-spot donut sweep + cripple). [E]: Nightmare (Vlad pool invulnerability + slow). [R]: One with Death (+45% MS, +50% CDR, +30% DMG). [Shift]: Ethereal Dash."
	elif char_key == "morrigan":
		char_desc_label.text = "SAGA: Mage (90 HP). Passive [Harbinger of Doom]: Ability hits spawn orbiting crows that seek nearby enemies (20 dmg + 35% slow). [LMB]: Black Plumage (Chargeable up to 5 rapid burst feathers). [RMB]: Omen of Death (Parabolic mortar shell). [Q]: Inescapable Ends (Dual-cast magnetic tether). [E]: Cry of the Banshee (Large cone shriek + 1.4s silence). [R]: Born of Blood (1s channel -> massive 45m piercing wave + stun). [Shift]: Crowstorm (Steered flight + 60% MS + 50% DR)."
	elif char_key == "monkey":
		char_desc_label.text = "SUNNY KONG: Trickster (160 HP). Passive [Stone Monkey]: Critical health (30%) triggers 3s stone invulnerability + displacement immunity + 30% missing HP heal. [LMB]: Heavenly Pillar (Fast staff bonk). [RMB]: Enlarge (Chargeable dash & slam with sweet spot stun). [Q]: 72 Forms (Disguise wheel with Tree, Rock, Cancel). [E]: Sage's Mockery (Circular taunt & damage reduction). [R]: Shadow Rush Flurry (Stealth dash -> flurry rush recast)."
	elif char_key == "silene":
		char_desc_label.text = "WYNN WYRMCHILDE: The Dragon of Silene (320 HP). Passive [Draconic Ferocity]: Flat bonus damage on all abilities. [LMB]: Claw Swipe (Annulus Sector). [Shift]: Dragon Leap/Rush (Grab & Slam, Wall Stop, Unstoppable when Charged). [RMB]: Dragon Bite (Annulus Sector % Max HP DMG & Heal). [Q]: Tail Lash (Annulus Sector Stun & DMG). [E]: Dragonfire Breath (Height-scaling Cone DOT, Terrain raycast). [R]: Primal Roar (Annulus Sector Silence & Drag) + Persistent +10 Max HP per takedown."
	elif char_key == "artist":
		char_desc_label.text = "INKY: Calligrapher (200 HP). Passive [Ink]: Spell damage coats enemies in Ink, slowing them by 20% and amplifying his spell damage against them. [Shift]: Brush Step (Swift evasive dash). [R]: Ink Alchemy (Vancian talisman wheel: Inscribe Hanzi [火 Fire, 水 Water, 风 Air, 土 Earth] to prepare spells, or recast to unleash prepared elements)."
	elif char_key == "cleodolinda" or char_key == "cleo":
		char_desc_label.text = "CLEO: Hoverboarder (180 HP). Passive: High agility hoverboard riding. [LMB]: Semicircle strike scaling with relative velocity. [RMB]: Delayed full-circle spinning sweep + slow. [Shift]: Hover Surge dash. [E]: Hover Boost (+50% accel and max speed). [R]: Maximum Suction (Vacuum pull + damage)."
	
	if connected_players.has(1):
		connected_players[1]["character"] = selected_character

	if _is_network_active():
		if multiplayer.is_server():
			sync_lobby_state.rpc(connected_players, game_mode)
		else:
			update_player_character.rpc_id(1, selected_character)
	elif lobby_panel.visible:
		_refresh_lobby_ui()

func _on_game_mode_selected(idx: int) -> void:
	if not _is_network_active() or not multiplayer.is_server():
		return
	var mode_str = GameModes.get_mode_id_from_index(idx)
	set_game_mode(mode_str)

func set_game_mode(mode_str: String) -> void:
	game_mode = mode_str
	bo5_score_t1 = 0
	bo5_score_t2 = 0
	bo5_score_t3 = 0
	call_deferred("_refresh_battle_royale_zones_for_mode")
	if _is_network_active() and multiplayer.is_server():
		sync_bo5_score.rpc(0, 0, 0)
		sync_lobby_state.rpc(connected_players, game_mode)

@rpc("authority", "call_local", "reliable")
func sync_bo5_score(s1: int, s2: int, s3: int = 0) -> void:
	bo5_score_t1 = s1
	bo5_score_t2 = s2
	bo5_score_t3 = s3
	if scoreboard_panel and scoreboard_panel.visible:
		_update_scoreboard_content()

func _on_slot_clicked(team: int, slot: int) -> void:
	if is_training_mode:
		return
	if not _is_network_active():
		return
	var mode = GameModes.get_mode(game_mode)
	if not mode.is_team_based:
		return # Slots are assigned per-player in non-team modes (FFA)
	if multiplayer.is_server():
		_assign_player_slot(1, team, slot)
	else:
		request_team_slot.rpc_id(1, team, slot)

func _find_first_available_slot() -> Dictionary:
	for s in range(3):
		for t in [1, 2, 3]:
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
	
	var uism = get_node_or_null("/root/UIStateMachine")
	if uism:
		uism.transition_to(uism.State.LOBBY)
	else:
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
	_select_character(selected_character)
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
	
	var uism_host = get_node_or_null("/root/UIStateMachine")
	if uism_host:
		uism_host.transition_to(uism_host.State.LOBBY)
	else:
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
	var body = JSON.stringify({"code": code, "ip": ip, "localIp": ip, "port": port})
	var err = http_request_host.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		print("Backend room registration failed: ", err)

func _on_backend_create_room_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	var code_display = current_room_code
	if not (result == HTTPRequest.RESULT_SUCCESS and response_code == 200):
		code_display = "%s (Local)" % current_room_code
	if lobby_panel and lobby_panel.visible:
		lobby_ip_label.text = "ROOM CODE: %s" % code_display
	if scoreboard_training_code_label:
		scoreboard_training_code_label.text = "ROOM CODE: %s" % code_display

func _on_join_pressed() -> void:
	var uism = get_node_or_null("/root/UIStateMachine")
	if uism:
		uism.transition_to(uism.State.JOIN_DIALOG)
	else:
		join_dialog.show()
	if join_status_label:
		join_status_label.hide()
	confirm_join_button.disabled = false
	if join_local_button:
		join_local_button.disabled = false
	host_ip_input.text = ""
	host_ip_input.grab_focus()

func _on_confirm_join_pressed() -> void:
	var raw_input = host_ip_input.text.strip_edges()
	if raw_input.is_empty():
		current_room_code = ""
		_join_direct_ip("127.0.0.1")
		return
	
	if NetworkUtils.is_direct_ip_or_localhost(raw_input):
		current_room_code = ""
		_join_direct_ip(raw_input)
		return
	
	# Query Render matchmaking backend
	if join_status_label:
		join_status_label.text = "Connecting to matchmaking server..."
		join_status_label.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
		join_status_label.show()
	confirm_join_button.disabled = true
	if join_local_button:
		join_local_button.disabled = true
	
	var clean_code = raw_input.to_upper()
	current_room_code = clean_code
	var url = "%s/api/join-room/%s" % [NetworkUtils.BACKEND_URL, clean_code]
	http_request_join.cancel_request()
	var err = http_request_join.request(url, ["Accept: application/json"], HTTPClient.METHOD_GET)
	if err != OK:
		if join_status_label:
			join_status_label.text = "Could not reach matchmaking server."
			join_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		confirm_join_button.disabled = false
		if join_local_button:
			join_local_button.disabled = false

func _on_backend_join_room_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	confirm_join_button.disabled = false
	if join_local_button:
		join_local_button.disabled = false
	if result != HTTPRequest.RESULT_SUCCESS:
		if join_status_label:
			join_status_label.text = "Lobby does not exist or server is unreachable."
			join_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
			join_status_label.show()
		return
	
	var body_str = body.get_string_from_utf8()
	var json = JSON.parse_string(body_str)
	if response_code == 200 and json is Dictionary and json.has("hostAddress"):
		var host_addr_str = str(json["hostAddress"])
		var parsed = NetworkUtils.parse_host_address(host_addr_str, PORT)
		var target_ip = parsed["ip"]
		var target_port = parsed["port"]
		var fallback_ip = ""
		
		if json.has("localAddress") and not str(json["localAddress"]).is_empty():
			var local_parsed = NetworkUtils.parse_host_address(str(json["localAddress"]), target_port)
			fallback_ip = local_parsed["ip"]
		elif json.has("localIp") and not str(json["localIp"]).is_empty():
			fallback_ip = str(json["localIp"])
			
		# If the room backend signaled isLocal, or if target_ip is an unroutable Render internal IP (10.x.x.x), use fallback
		if (json.get("isLocal", false) == true or target_ip.begins_with("10.")) and not fallback_ip.is_empty():
			var temp = target_ip
			target_ip = fallback_ip
			fallback_ip = temp
			
		_connect_client_to_host(target_ip, target_port, fallback_ip)
	else:
		var err_msg = "Lobby does not exist. Check code and try again."
		if json is Dictionary and json.has("error"):
			err_msg = "Lobby does not exist: %s" % str(json["error"])
		if join_status_label:
			join_status_label.text = err_msg
			join_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
			join_status_label.show()

func _join_direct_ip(raw_ip: String) -> void:
	var target_ip = NetworkUtils.clean_host_ip(raw_ip)
	_connect_client_to_host(target_ip, PORT)

func _connect_client_to_host(target_ip: String, target_port: int, fallback_ip: String = "") -> void:
	is_training_mode = false
	if join_status_label:
		join_status_label.text = "Connecting to %s:%d..." % [target_ip, target_port]
		join_status_label.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
		join_status_label.show()
	confirm_join_button.disabled = true
	if join_local_button:
		join_local_button.disabled = true
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(target_ip, target_port)
	if error != OK:
		if join_status_label:
			join_status_label.text = "Failed to initialize connection (Error %d)" % error
			join_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
			join_status_label.show()
		confirm_join_button.disabled = false
		if join_local_button:
			join_local_button.disabled = false
		print("Failed client connection: ", error)
		return

	multiplayer.multiplayer_peer = peer
	
	# Timeout timer if UDP handshake cannot reach the host
	var timer = get_tree().create_timer(4.5)
	timer.timeout.connect(func():
		if multiplayer.multiplayer_peer and not multiplayer.is_server() and not lobby_panel.visible:
			if not fallback_ip.is_empty() and fallback_ip != target_ip:
				print("Primary connection to ", target_ip, " timed out, attempting LAN fallback to ", fallback_ip)
				if join_status_label:
					join_status_label.text = "Retrying connection via LAN (%s)..." % fallback_ip
					join_status_label.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
				multiplayer.multiplayer_peer = null
				_connect_client_to_host(fallback_ip, target_port, "")
				return
				
			multiplayer.multiplayer_peer = null
			confirm_join_button.disabled = false
			if join_local_button:
				join_local_button.disabled = false
			if join_status_label:
				join_status_label.text = "Connection timed out. If testing on this PC, click 'Localhost'."
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
		if is_training_mode:
			if connected_players.size() >= 5:
				print("Training lobby full (cap 5). Disconnecting peer ", id)
				multiplayer.multiplayer_peer.disconnect_peer(id)
				return
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
				"team": id if is_training_mode else slot_info["team"],
				"slot": slot_info["slot"],
				"gold": 999999 if is_training_mode else 0,
				"items": []
			}
		if not is_training_mode:
			sync_lobby_state.rpc(connected_players, game_mode)
		else:
			if scoreboard_panel and scoreboard_panel.visible:
				_update_scoreboard_content(false)

func _on_server_disconnected() -> void:
	_leave_to_main_menu()

func _on_peer_disconnected(id: int) -> void:
	if id == 1:
		_leave_to_main_menu()
		return
	if multiplayer.is_server():
		if is_training_mode:
			var target_key = null
			for k in connected_players.keys():
				if str(k) == str(id):
					target_key = k
					break
			if target_key != null:
				connected_players.erase(target_key)
			var player_node = players_container.get_node_or_null(str(id))
			if player_node:
				player_node.queue_free()
			cleanup_player_entities(id)
			if scoreboard_panel and scoreboard_panel.visible:
				_update_scoreboard_content(false)
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
			
			if _check_team_player_deficits():
				terminate_match.rpc("Match terminated: Not enough players remaining.")
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
	if not EnabledCharacters.is_character_enabled(char_key):
		var en = EnabledCharacters.get_enabled_characters()
		char_key = en[0] if not en.is_empty() else "poke"
	var sender_id = multiplayer.get_remote_sender_id()
	
	if is_training_mode and connected_players.size() >= 5 and not connected_players.has(sender_id):
		multiplayer.multiplayer_peer.disconnect_peer(sender_id)
		return

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
			"team": sender_id if is_training_mode else slot_info["team"],
			"slot": slot_info["slot"],
			"gold": 999999 if is_training_mode else 0,
			"items": []
		}
	else:
		connected_players[target_key]["character"] = char_key
		if is_training_mode:
			connected_players[target_key]["team"] = sender_id
	
	if is_training_mode and match_in_progress:
		_spawn_joining_training_player(sender_id)
	else:
		sync_lobby_state.rpc(connected_players, game_mode)

@rpc("any_peer", "call_remote", "reliable")
func update_player_character(char_key: String) -> void:
	if not multiplayer.is_server():
		return
	if not EnabledCharacters.is_character_enabled(char_key):
		return
	var sender_id = multiplayer.get_remote_sender_id()
	for k in connected_players.keys():
		if str(k) == str(sender_id):
			connected_players[k]["character"] = char_key
			sync_lobby_state.rpc(connected_players, game_mode)
			break

@rpc("any_peer", "call_local", "reliable")
func sync_lobby_state(players_dict: Dictionary, mode_str: String = "tdm") -> void:
	if not _is_sender_host():
		return
	if not _is_network_active():
		return
	connected_players = players_dict
	game_mode = mode_str
	if not match_in_progress:
		menu_panel.hide()
		lobby_panel.show()
		_refresh_lobby_ui()

func _refresh_lobby_ui() -> void:
	var my_id = multiplayer.get_unique_id() if (multiplayer and multiplayer.has_multiplayer_peer()) else 1
	var is_server = multiplayer.is_server() if (multiplayer and multiplayer.has_multiplayer_peer()) else true
	
	if hbox_game_mode:
		hbox_game_mode.visible = not is_training_mode

	if game_mode_option:
		game_mode_option.disabled = not is_server or is_training_mode
		var sel_idx = GameModes.get_index_from_mode_id(game_mode)
		game_mode_option.select(sel_idx)

	if map_option:
		map_option.clear()
		if is_training_mode:
			map_option.disabled = false
			map_option.add_item("🎯 Standard Training Map", -1)
			for i in range(MAP_NAMES.size()):
				map_option.add_item("⚔ " + MAP_NAMES[i], i)
			var sel_idx = 0
			if training_selected_map >= 0 and training_selected_map < MAP_NAMES.size():
				sel_idx = training_selected_map + 1
			map_option.select(sel_idx)
		else:
			map_option.disabled = not is_server
			map_option.add_item("🎲 Random Map", -1)
			for i in range(MAP_NAMES.size()):
				map_option.add_item("⚔ " + MAP_NAMES[i], i)
			var sel_idx = 0
			if selected_custom_map >= 0 and selected_custom_map < MAP_NAMES.size():
				sel_idx = selected_custom_map + 1
			map_option.select(sel_idx)

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
			team_header.text = "2. Free For All Deathmatch (9 Max - Free For All):"
		
		var p_ids = connected_players.keys()
		for s in range(3):
			# Column 1: Fighters 1-3
			var btn1 = t1_slots[s]
			var idx1 = s
			if idx1 < p_ids.size():
				var pid = p_ids[idx1]
				var occupant = connected_players[pid]
				var char_name = get_character_display_name(occupant.get("character", "poke")).to_upper()
				var p_name = occupant.get("name", "Player")
				if str(pid) == str(my_id):
					btn1.text = "★ %s [%s] (YOU)" % [p_name, char_name]
				else:
					btn1.text = "• %s [%s]" % [p_name, char_name]
			else:
				btn1.text = "[ Fighter %d : Open ]" % (idx1 + 1)
			
			# Column 2: Fighters 4-6
			var btn2 = t2_slots[s]
			var idx2 = s + 3
			if idx2 < p_ids.size():
				var pid = p_ids[idx2]
				var occupant = connected_players[pid]
				var char_name = get_character_display_name(occupant.get("character", "poke")).to_upper()
				var p_name = occupant.get("name", "Player")
				if str(pid) == str(my_id):
					btn2.text = "★ %s [%s] (YOU)" % [p_name, char_name]
				else:
					btn2.text = "• %s [%s]" % [p_name, char_name]
			else:
				btn2.text = "[ Fighter %d : Open ]" % (idx2 + 1)

			# Column 3: Fighters 7-9
			var btn3 = t3_slots[s]
			var idx3 = s + 6
			if idx3 < p_ids.size():
				var pid = p_ids[idx3]
				var occupant = connected_players[pid]
				var char_name = get_character_display_name(occupant.get("character", "poke")).to_upper()
				var p_name = occupant.get("name", "Player")
				if str(pid) == str(my_id):
					btn3.text = "★ %s [%s] (YOU)" % [p_name, char_name]
				else:
					btn3.text = "• %s [%s]" % [p_name, char_name]
			else:
				btn3.text = "[ Fighter %d : Open ]" % (idx3 + 1)

		if is_server:
			var can_start = connected_players.size() >= 2 or (connected_players.size() >= 1 and OS.is_debug_build())
			start_match_button.disabled = not can_start
			if can_start:
				start_match_button.text = "START DEATHMATCH (%d Fighters)" % connected_players.size()
			else:
				start_match_button.text = "CANNOT START (Need 2+ players for Deathmatch)"
		return
	
	# TDM / Bo5 Mode (3v3v3)
	if team_header:
		if game_mode == "bo5":
			team_header.text = "2. Select Team & Slot (Best of Five 3v3v3 - 9 Max):"
		else:
			team_header.text = "2. Select Team & Slot (3v3v3 - 9 Max):"
	var t1_count = 0
	var t2_count = 0
	var t3_count = 0
	
	# Team 1 slots
	for s in range(3):
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
			var char_name = get_character_display_name(occupant.get("character", "poke")).to_upper()
			var p_name = occupant.get("name", "Player")
			if str(occ_id) == str(my_id):
				btn.text = "★ %s [%s] (YOU)" % [p_name, char_name]
			else:
				btn.text = "• %s [%s]" % [p_name, char_name]
		else:
			btn.text = "[ + Slot %d : Join Team 1 ]" % (s + 1)
			
	# Team 2 slots
	for s in range(3):
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
			var char_name = get_character_display_name(occupant.get("character", "poke")).to_upper()
			var p_name = occupant.get("name", "Player")
			if str(occ_id) == str(my_id):
				btn.text = "★ %s [%s] (YOU)" % [p_name, char_name]
			else:
				btn.text = "• %s [%s]" % [p_name, char_name]
		else:
			btn.text = "[ + Slot %d : Join Team 2 ]" % (s + 1)

	# Team 3 slots
	for s in range(3):
		var btn = t3_slots[s]
		var occupant = null
		var occ_id = null
		for pid in connected_players.keys():
			var p = connected_players[pid]
			if int(p.get("team", 1)) == 3 and int(p.get("slot", 0)) == s:
				occupant = p
				occ_id = pid
				t3_count += 1
				break
		
		if occupant != null:
			var char_name = get_character_display_name(occupant.get("character", "poke")).to_upper()
			var p_name = occupant.get("name", "Player")
			if str(occ_id) == str(my_id):
				btn.text = "★ %s [%s] (YOU)" % [p_name, char_name]
			else:
				btn.text = "• %s [%s]" % [p_name, char_name]
		else:
			btn.text = "[ + Slot %d : Join Team 3 ]" % (s + 1)

	if is_server:
		var can_start = (t1_count >= 1 and t2_count >= 1 and t3_count >= 1) or (OS.is_debug_build() and (t1_count + t2_count + t3_count) >= 1)
		start_match_button.disabled = not can_start
		if can_start:
			if game_mode == "bo5":
				start_match_button.text = "START BEST OF FIVE (%d vs %d vs %d)" % [t1_count, t2_count, t3_count]
			else:
				start_match_button.text = "START MATCH (%d vs %d vs %d)" % [t1_count, t2_count, t3_count]
		else:
			start_match_button.text = "CANNOT START (Need 1+ player on each team)"

func _on_map_option_selected(index: int) -> void:
	if not map_option:
		return
	var item_id = map_option.get_item_id(index)
	if is_training_mode:
		training_selected_map = item_id
	else:
		selected_custom_map = item_id
		if _is_network_active() and multiplayer.is_server():
			sync_lobby_map.rpc(selected_custom_map)

@rpc("any_peer", "call_local", "reliable")
func sync_lobby_map(map_id: int) -> void:
	if not _is_sender_host():
		return
	selected_custom_map = map_id
	if map_option and not is_training_mode:
		var sel_idx = 0
		if selected_custom_map >= 0 and selected_custom_map < MAP_NAMES.size():
			sel_idx = selected_custom_map + 1
		map_option.select(sel_idx)

func _on_start_match_pressed() -> void:
	if is_training_mode:
		start_game()
		return
	if not multiplayer.is_server():
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

	if not is_multiplayer_match():
		return

	var t1_count = 0
	var t2_count = 0
	var t3_count = 0
	for pid in connected_players.keys():
		var p = connected_players[pid]
		var t = int(p.get("team", 1))
		if t == 1:
			t1_count += 1
		elif t == 2:
			t2_count += 1
		elif t == 3:
			t3_count += 1
	if not OS.is_debug_build() and (t1_count < 1 or t2_count < 1 or t3_count < 1):
		return
	if (t1_count + t2_count + t3_count) < 1:
		return
	if game_mode == "bo5":
		bo5_score_t1 = 0
		bo5_score_t2 = 0
		bo5_score_t3 = 0
		sync_bo5_score.rpc(0, 0, 0)
	for k in connected_players.keys():
		connected_players[k]["kills"] = 0
		connected_players[k]["deaths"] = 0
		connected_players[k]["assists"] = 0
	_sync_all_kda()
	start_game.rpc()

func is_multiplayer_match() -> bool:
	if not _is_network_active():
		return false
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	if is_training_mode:
		return multiplayer.get_peers().size() > 0
	return connected_players.size() > 1 or multiplayer.get_peers().size() > 0 or (connected_players.size() >= 1 and (OS.is_debug_build() or game_mode == "dm"))

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
	if not _is_sender_host():
		return
	match_in_progress = true
	var uism = get_node_or_null("/root/UIStateMachine")
	if uism:
		uism.transition_to(uism.State.IN_MATCH)
	else:
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
			sync_active_map(training_selected_map)
	
	if not is_multiplayer_match() or multiplayer.is_server():
		# For Best of Five, compute round progression: 1 level per round, capped at 4 (round 5 doesn't change anything)
		if game_mode == "bo5":
			var current_round = bo5_score_t1 + bo5_score_t2 + bo5_score_t3 + 1
			var bo5_target_level = clamp(current_round, 1, 4)
			for pid in connected_players.keys():
				var prev_level = connected_players[pid].get("level", 1)
				if bo5_target_level > prev_level:
					var levels_gained = bo5_target_level - prev_level
					connected_players[pid]["level"] = bo5_target_level
					connected_players[pid]["upgrade_points"] = connected_players[pid].get("upgrade_points", 0) + levels_gained
				elif not connected_players[pid].has("level"):
					connected_players[pid]["level"] = bo5_target_level
					connected_players[pid]["upgrade_points"] = bo5_target_level - 1

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
			
			var dummy_pos = Vector3(0.0, 0.0, 0.0)
			var dummy_rot_y = 0.0
			var player_pos = Vector3(-8.0, 0.1, 0.0)
			var player_rot_y = 0.0
			
			if training_selected_map != -1:
				var t2_spawns = spawn_points.get_node_or_null("Team2_Spawns")
				if t2_spawns:
					var sp_center = t2_spawns.get_node_or_null("Spawn3")
					dummy_pos = sp_center.global_position if sp_center else (t2_spawns.get_child(0).global_position if t2_spawns.get_child_count() > 0 else Vector3(24.0, 0.1, 0.0))
				else:
					dummy_pos = Vector3(24.0, 0.1, 0.0)
				dummy_rot_y = PI
				
				var t1_spawns = spawn_points.get_node_or_null("Team1_Spawns")
				if t1_spawns:
					var sp_center = t1_spawns.get_node_or_null("Spawn3")
					player_pos = sp_center.global_position if sp_center else (t1_spawns.get_child(0).global_position if t1_spawns.get_child_count() > 0 else Vector3(-24.0, 0.1, 0.0))
				else:
					player_pos = Vector3(-24.0, 0.1, 0.0)
				player_rot_y = 0.0
			
			# Spawn Training Dummy (Free-For-All: Team 99)
			var dummy = training_dummy_scene.instantiate()
			dummy.name = "TrainingDummy"
			dummy.team_id = 99
			dummy.global_position = dummy_pos
			dummy.rotation.y = dummy_rot_y
			dummy.set("home_position", dummy_pos)
			players_container.add_child(dummy)
			
			# Spawn Local Player directly as child
			if connected_players.has(1):
				connected_players[1]["character"] = selected_character
			var p_info = connected_players.get(1, {"character": selected_character})
			var p_char = p_info.get("character", selected_character)
			var packed_scene = CHARACTERS.get(p_char, CHARACTERS["poke"])
			var player_instance = packed_scene.instantiate()
			player_instance.name = "1"
			player_instance.team_id = 1
			player_instance.position = player_pos
			player_instance.rotation.y = player_rot_y
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
			var t3_spawns = spawn_points.get_node_or_null("Team3_Spawns")
			if t1_spawns:
				for sp in t1_spawns.get_children():
					all_spawns.append(sp.global_position)
			if t2_spawns:
				for sp in t2_spawns.get_children():
					all_spawns.append(sp.global_position)
			if t3_spawns:
				for sp in t3_spawns.get_children():
					all_spawns.append(sp.global_position)
			if all_spawns.is_empty():
				all_spawns = [
					Vector3(-24.0, 0.1, -5.0), Vector3(-24.0, 0.1, 0.0), Vector3(-24.0, 0.1, 5.0),
					Vector3(24.0, 0.1, -5.0), Vector3(24.0, 0.1, 0.0), Vector3(24.0, 0.1, 5.0),
					Vector3(-5.0, 0.1, -24.0), Vector3(0.0, 0.1, -24.0), Vector3(5.0, 0.1, -24.0)
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
					"gold": p_info.get("gold", 0),
					"silene_bonus_hp": p_info.get("silene_bonus_hp", 0.0)
				}
				player_spawner.spawn(spawn_payload)
		else:
			# Team Deathmatch (3v3v3) and Best of Five
			for pid in connected_players.keys():
				var p_info = connected_players[pid]
				var char_choice = p_info.get("character", "poke")
				var p_team = int(p_info.get("team", 1))
				var p_slot = int(p_info.get("slot", 0))
				
				var spawn_pos = Vector3.ZERO
				var rot_facing = 0.0
				if p_team == 1:
					var t1_spawns = spawn_points.get_node_or_null("Team1_Spawns")
					if t1_spawns and t1_spawns.get_child_count() > p_slot:
						spawn_pos = t1_spawns.get_child(p_slot).global_position
					else:
						spawn_pos = Vector3(-24.0, 0.1, (p_slot - 1.0) * 5.0)
					rot_facing = 0.0
				elif p_team == 2:
					var t2_spawns = spawn_points.get_node_or_null("Team2_Spawns")
					if t2_spawns and t2_spawns.get_child_count() > p_slot:
						spawn_pos = t2_spawns.get_child(p_slot).global_position
					else:
						spawn_pos = Vector3(24.0, 0.1, (p_slot - 1.0) * 5.0)
					rot_facing = PI
				else:
					var t3_spawns = spawn_points.get_node_or_null("Team3_Spawns")
					if t3_spawns and t3_spawns.get_child_count() > p_slot:
						spawn_pos = t3_spawns.get_child(p_slot).global_position
					else:
						spawn_pos = Vector3((p_slot - 1.0) * 5.0, 0.1, -24.0)
					rot_facing = PI
				
				var spawn_payload = {
					"peer_id": pid,
					"character": char_choice,
					"team_id": p_team,
					"pos": spawn_pos,
					"rot_y": rot_facing,
					"items": p_info.get("items", []),
					"gold": p_info.get("gold", 0),
					"silene_bonus_hp": p_info.get("silene_bonus_hp", 0.0)
				}
				player_spawner.spawn(spawn_payload)
		call_deferred("_refresh_battle_royale_zones_for_mode")

func _custom_spawn_player(data: Variant) -> Node:
	var char_key = data.get("character", "poke")
	if char_key == "dummy":
		var dummy = training_dummy_scene.instantiate()
		dummy.name = "TrainingDummy"
		dummy.team_id = data.get("team_id", 99)
		dummy.position = data.get("pos", Vector3.ZERO)
		if data.has("rot_y"):
			dummy.rotation.y = data["rot_y"]
		dummy.set("home_position", dummy.position)
		call_deferred("_refresh_all_player_team_visuals")
		return dummy
	var packed_scene = CharacterRegistry.get_character_scene(char_key)
	if not packed_scene:
		packed_scene = CHARACTERS.get(char_key, CHARACTERS["poke"])
	var player_instance = packed_scene.instantiate()
	var char_data = CharacterRegistry.get_character_data(char_key)
	if char_data and player_instance.has_method("load_character_data"):
		player_instance.load_character_data(char_data)
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
	if player_instance.has_method("restore_saved_takedown_bonus_hp"):
		var saved_hp = data.get("silene_bonus_hp", 0.0)
		if saved_hp <= 0.0 and connected_players.has(data.get("peer_id", -1)):
			saved_hp = connected_players[data["peer_id"]].get("silene_bonus_hp", 0.0)
		if saved_hp > 0.0:
			player_instance.restore_saved_takedown_bonus_hp(saved_hp)
	# Restore / apply level and upgrade progression
	var pid_int = int(data.get("peer_id", -1))
	if connected_players.has(pid_int):
		var p_info = connected_players[pid_int]
		var p_lvl = p_info.get("level", 1)
		var p_pts = p_info.get("upgrade_points", 0)
		var p_ups = p_info.get("acquired_upgrades", [])
		player_instance.player_level = p_lvl
		player_instance.upgrade_points = p_pts
		player_instance.acquired_upgrades.clear()
		for u in p_ups:
			player_instance.acquired_upgrades.append(str(u))
			if player_instance.has_method("_activate_upgrade_effects"):
				player_instance._activate_upgrade_effects(str(u))
		if is_multiplayer_match() and multiplayer.is_server():
			player_instance.sync_progression.rpc(0.0, player_instance.xp_per_level, player_instance.player_level, player_instance.upgrade_points)

	call_deferred("_refresh_all_player_team_visuals")
	return player_instance

func _refresh_all_player_team_visuals() -> void:
	if players_container:
		for p in players_container.get_children():
			if p.has_method("_update_team_visuals"):
				p._update_team_visuals()

func get_all_spawn_positions() -> Array[Vector3]:
	var result: Array[Vector3] = []
	if not spawn_points:
		spawn_points = get_node_or_null("SpawnPoints")
	if spawn_points:
		var t1 = spawn_points.get_node_or_null("Team1_Spawns")
		var t2 = spawn_points.get_node_or_null("Team2_Spawns")
		var t3 = spawn_points.get_node_or_null("Team3_Spawns")
		if t1:
			for sp in t1.get_children():
				if sp is Node3D:
					result.append(sp.global_position)
		if t2:
			for sp in t2.get_children():
				if sp is Node3D:
					result.append(sp.global_position)
		if t3:
			for sp in t3.get_children():
				if sp is Node3D:
					result.append(sp.global_position)
	if result.is_empty():
		result = [
			Vector3(-24.0, 0.1, -5.0), Vector3(-24.0, 0.1, 0.0), Vector3(-24.0, 0.1, 5.0),
			Vector3(24.0, 0.1, -5.0), Vector3(24.0, 0.1, 0.0), Vector3(24.0, 0.1, 5.0),
			Vector3(-5.0, 0.1, -24.0), Vector3(0.0, 0.1, -24.0), Vector3(5.0, 0.1, -24.0)
		]
	return result

func get_respawn_position(player_node: Node) -> Vector3:
	var mode = GameModes.get_mode(game_mode)
	var spawns: Array[Vector3] = []
	if mode and not mode.is_team_based:
		# Free For All: all spawn points
		spawns = get_all_spawn_positions()
	else:
		# Team-based: pick team spawns
		var p_team = int(player_node.get("team_id")) if player_node and player_node.get("team_id") != null else 1
		var team_container_name = "Team1_Spawns" if p_team == 1 else ("Team2_Spawns" if p_team == 2 else "Team3_Spawns")
		var t_spawns = spawn_points.get_node_or_null(team_container_name) if spawn_points else null
		if t_spawns:
			for sp in t_spawns.get_children():
				if sp is Node3D:
					spawns.append(sp.global_position)
		if spawns.is_empty():
			if p_team == 1:
				for z in [-5.0, 0.0, 5.0]:
					spawns.append(Vector3(-24.0, 0.1, z))
			elif p_team == 2:
				for z in [-5.0, 0.0, 5.0]:
					spawns.append(Vector3(24.0, 0.1, z))
			else:
				for x in [-5.0, 0.0, 5.0]:
					spawns.append(Vector3(x, 0.1, -24.0))

	if spawns.is_empty():
		return Vector3(-24.0, 0.1, 0.0)

	# Find a spawn position safely distanced from alive enemies
	var alive_enemies: Array[Node3D] = []
	if players_container:
		for p in players_container.get_children():
			if p is Node3D and p != player_node and is_instance_valid(p) and not p.get("is_dead"):
				alive_enemies.append(p)

	if alive_enemies.is_empty():
		return spawns[randi() % spawns.size()]

	# Score spawns by distance to closest alive enemy (pick among the safest)
	var best_spawns: Array[Vector3] = []
	var max_min_dist = -1.0
	for pos in spawns:
		var min_dist_to_enemy = 999999.0
		for enemy in alive_enemies:
			var d = pos.distance_to(enemy.global_position)
			if d < min_dist_to_enemy:
				min_dist_to_enemy = d
		if min_dist_to_enemy > max_min_dist:
			max_min_dist = min_dist_to_enemy
			best_spawns = [pos]
		elif abs(min_dist_to_enemy - max_min_dist) < 1.0:
			best_spawns.append(pos)

	if not best_spawns.is_empty():
		return best_spawns[randi() % best_spawns.size()]
	return spawns[randi() % spawns.size()]

func on_player_died(peer_id: int) -> void:
	if is_training_mode:
		if peer_id == 0 or peer_id == 99:
			training_kills += 1
			var dummy_node = players_container.get_node_or_null("TrainingDummy")
			if dummy_node:
				get_tree().create_timer(2.0).timeout.connect(func():
					if is_instance_valid(dummy_node) and dummy_node.get("is_dead"):
						dummy_node.respawn()
				)
		else:
			if peer_id == 1:
				training_deaths += 1
			if connected_players.has(peer_id):
				connected_players[peer_id]["deaths"] = connected_players[peer_id].get("deaths", 0) + 1
			var victim = players_container.get_node_or_null(str(peer_id))
			if victim and victim.has_method("sync_death_state"):
				victim.sync_death_state.rpc(true, 3.0)
			get_tree().create_timer(3.0).timeout.connect(func():
				if match_in_progress and is_instance_valid(victim) and victim.get("is_dead"):
					var spawn_pos = get_respawn_position(victim)
					victim.respawn(spawn_pos)
			)
		if scoreboard_panel and scoreboard_panel.visible:
			_update_scoreboard_content(false)
		return

	if not is_multiplayer_match() or not multiplayer.is_server() or not match_in_progress:
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
		if killer_node and killer_node.has_method("on_kill_scored"):
			killer_node.on_kill_scored(victim)
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
						if assister_node and assister_node.has_method("on_assist_scored"):
							assister_node.on_assist_scored(victim)
						if assister_node and assister_node.has_method("sync_inventory"):
							assister_node.sync_inventory.rpc(assister_node.item_slots, connected_players[a_id]["gold"])
	
	_sync_all_kda()
	
	var active_mode = GameModes.get_mode(game_mode)
	if active_mode and active_mode.respawn_delay > 0.0:
		if victim and victim.has_method("sync_death_state"):
			victim.sync_death_state.rpc(true, active_mode.respawn_delay)
		# Respawn after configured delay (e.g. 5.0 seconds in Deathmatch)
		get_tree().create_timer(active_mode.respawn_delay).timeout.connect(func():
			if match_in_progress and is_instance_valid(victim) and victim.get("is_dead") == true:
				if not _is_peer_pending_disconnect(peer_id):
					var spawn_pos = get_respawn_position(victim)
					victim.respawn(spawn_pos)
		)
		return

	_check_match_status()

func _check_match_status() -> void:
	if not is_multiplayer_match() or not multiplayer.is_server() or not match_in_progress or is_training_mode:
		return
	
	if players_container.get_child_count() == 0:
		return

	var current_mode = GameModes.get_mode(game_mode)
	var combat_status = current_mode.evaluate_combat_status(players_container, connected_players)
	if combat_status["over"]:
		if combat_status["is_round_only"]:
			_handle_bo5_round_end(combat_status["winner"])
		else:
			end_match.rpc(combat_status["winner"])

func _handle_bo5_round_end(round_winner: String) -> void:
	match_in_progress = false
	if round_winner == "TEAM 1":
		bo5_score_t1 += 1
	elif round_winner == "TEAM 2":
		bo5_score_t2 += 1
	elif round_winner == "TEAM 3":
		bo5_score_t3 += 1
	
	var mode = GameModes.get_mode(game_mode)
	var round_gold = mode.gold_per_round if mode else 100
	for pid in connected_players.keys():
		connected_players[pid]["gold"] = connected_players[pid].get("gold", 0) + round_gold
		var p_node = players_container.get_node_or_null(str(pid))
		if p_node and p_node.has_method("sync_inventory"):
			p_node.sync_inventory.rpc(p_node.item_slots, connected_players[pid]["gold"])
	
	sync_bo5_score.rpc(bo5_score_t1, bo5_score_t2, bo5_score_t3)
	
	var bo5_mode: BestOfFiveMode = mode as BestOfFiveMode
	var match_winner = bo5_mode.check_match_winner(bo5_score_t1, bo5_score_t2, bo5_score_t3) if bo5_mode else ("TEAM 1" if bo5_score_t1 >= 3 else ("TEAM 2" if bo5_score_t2 >= 3 else ("TEAM 3" if bo5_score_t3 >= 3 else "")))
	if not match_winner.is_empty():
		end_match.rpc(match_winner)
	else:
		end_round.rpc(round_winner, bo5_score_t1, bo5_score_t2, bo5_score_t3)

@rpc("any_peer", "call_local", "reliable")
func end_round(round_winner: String, score1: int, score2: int, score3: int = 0) -> void:
	if not _is_sender_host():
		return
	match_in_progress = false
	bo5_score_t1 = score1
	bo5_score_t2 = score2
	bo5_score_t3 = score3
	_bo5_round_transition_active = true
	
	if scoreboard_panel and scoreboard_panel.visible:
		_update_scoreboard_content()
	
	if round_winner == "DRAW":
		winner_label.text = "ROUND OVER!\nDRAW!"
		if match_over_sub_label:
			match_over_sub_label.text = "Score: Team 1 [%d] - [%d] Team 2 - [%d] Team 3\nReplaying round in 3 seconds..." % [score1, score2, score3]
	else:
		winner_label.text = "ROUND OVER!\n%s WINS THE ROUND!" % round_winner.to_upper()
		if match_over_sub_label:
			match_over_sub_label.text = "Score: Team 1 [%d] - [%d] Team 2 - [%d] Team 3\nNext round starting in 3 seconds..." % [score1, score2, score3]
	
	match_over_panel.show()
	
	await get_tree().create_timer(3.0).timeout
	
	if not _bo5_round_transition_active:
		return
	_bo5_round_transition_active = false
	
	match_over_panel.hide()
	
	if multiplayer.is_server():
		# Save players' level, upgrade points, and acquired upgrades across rounds
		for c in players_container.get_children():
			var c_id = c.name.to_int()
			if c_id > 0 and connected_players.has(c_id):
				connected_players[c_id]["level"] = c.player_level if ("player_level" in c) else 1
				connected_players[c_id]["upgrade_points"] = c.upgrade_points if ("upgrade_points" in c) else 0
				connected_players[c_id]["acquired_upgrades"] = c.acquired_upgrades.duplicate() if ("acquired_upgrades" in c) else []
		
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
	if not _is_sender_host():
		return
	match_in_progress = false
	_bo5_round_transition_active = false
	var mode = GameModes.get_mode(game_mode)
	if mode.has_rounds and winner_name != "DRAW":
		winner_label.text = "%s OVER!\n%s WINS THE MATCH!" % [mode.display_name.to_upper(), winner_name.to_upper()]
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
		for pid in connected_players.keys():
			connected_players[pid]["level"] = 1
			connected_players[pid]["upgrade_points"] = 0
			connected_players[pid]["acquired_upgrades"] = []
		_process_pending_disconnects()
		bo5_score_t1 = 0
		bo5_score_t2 = 0
		sync_bo5_score.rpc(0, 0)

@rpc("any_peer", "call_local", "reliable")
func terminate_match(reason: String = "A team has no remaining players.") -> void:
	if not _is_sender_host():
		return
	match_in_progress = false
	_bo5_round_transition_active = false
	bo5_score_t1 = 0
	bo5_score_t2 = 0
	for pid in connected_players.keys():
		connected_players[pid]["level"] = 1
		connected_players[pid]["upgrade_points"] = 0
		connected_players[pid]["acquired_upgrades"] = []
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
	var proj = projectile_scene.instantiate()
	proj.shooter_id = data.get("shooter_id", 0)
	proj.shooter_team = data.get("shooter_team", 0)
	proj.action_type = data.get("action_type", 0)

	if p_type == "mortar_shell":
		proj.position = data.get("start_pos", data.get("pos", Vector3.ZERO))
		var end_p = data.get("end_pos", proj.position)
		var delta_pos = end_p - proj.position
		proj.target_distance = delta_pos.length()
		proj.direction = delta_pos.normalized() if proj.target_distance > 0.001 else Vector3.FORWARD
		proj.speed = data.get("speed", 24.0)
		proj.damage = data.get("damage", 45.0)
		proj.max_range = proj.target_distance
		proj.classification = 1 # TARGET_LOCATION
		proj.effect_type = "mortar_shell"
		return proj
	elif p_type == "blood_wave":
		proj.position = data.get("pos", Vector3.ZERO)
		proj.direction = data.get("dir", Vector3.FORWARD)
		proj.speed = data.get("speed", 22.0)
		proj.max_range = data.get("max_range", 45.0)
		proj.damage = data.get("damage", 80.0)
		proj.size = 2.4
		proj.pierces = true
		proj.effect_type = "blood_wave"
		return proj
	elif p_type == "vision_flare":
		proj.position = data.get("pos", Vector3.ZERO)
		proj.direction = data.get("dir", Vector3.FORWARD)
		proj.speed = data.get("speed", 60.0)
		proj.target_distance = data.get("target_dist", 65.0)
		proj.max_range = proj.target_distance
		proj.classification = 1 # TARGET_LOCATION
		proj.effect_type = "vision_flare"
		return proj
	elif p_type == "sticky_grenade":
		proj.position = data.get("pos", Vector3.ZERO)
		proj.direction = data.get("dir", Vector3.FORWARD)
		proj.speed = data.get("speed", 42.0)
		proj.max_range = data.get("max_range", 17.5)
		proj.damage = data.get("damage", 70.0)
		proj.effect_type = "sticky_grenade"
		return proj

	var projectile = projectile_scene.instantiate()
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

func spawn_battle_royale_zone(pos: Vector3 = Vector3.ZERO, radius: float = 35.0, initial_wait: float = 60.0, wait_t: float = 60.0, dps_val: float = 10.0, min_dist: float = 40.0) -> Node:
	if is_multiplayer_match() and not multiplayer.is_server():
		return null
	var data = {
		"type": "battle_royale_zone",
		"pos": pos,
		"radius": radius,
		"initial_wait_time": initial_wait,
		"wait_time": wait_t,
		"dps": dps_val,
		"min_dist": min_dist
	}
	if not is_multiplayer_match():
		var zone = _custom_spawn_hazard_zone(data)
		hazard_container.add_child(zone, true)
		return zone
	return hazard_spawner.spawn(data)

func _refresh_battle_royale_zones_for_mode() -> void:
	var mode = GameModes.get_mode(game_mode)
	var mode_has_zone = (mode.has_zone if "has_zone" in mode else mode.has_battle_royale_zone) if mode else false
	var is_main_mode = (mode_has_zone and not is_training_mode)
	
	# Update all existing zones in the scene tree (e.g. embedded in maps or hazards)
	var active_zone_found = false
	for zone in get_tree().get_nodes_in_group("battle_royale_zone"):
		if is_instance_valid(zone):
			if zone.has_method("_detect_arena_bounds"):
				zone._detect_arena_bounds()
			if zone.has_method("evaluate_mode_activity"):
				zone.evaluate_mode_activity()
			if zone.visible and zone.get("current_state") != 0:
				active_zone_found = true
	
	# If in main game mode (TDM), match is in progress, and no embedded zone is active, spawn one!
	if is_main_mode and match_in_progress and not active_zone_found:
		if not is_multiplayer_match() or multiplayer.is_server():
			var map_r = 35.0
			var map_min_dist = 45.0
			if current_map_id == 0 or current_map_id == 1 or current_map_id == 2:
				map_r = 17.5
				map_min_dist = 12.0
			spawn_battle_royale_zone(Vector3.ZERO, map_r, 60.0, 60.0, 10.0, map_min_dist)
	elif not is_main_mode:
		# Ensure any dynamically spawned battle royale zone in hazard container is cleaned up
		for h in hazard_container.get_children():
			if h.is_in_group("battle_royale_zone") or h.name.begins_with("BattleRoyaleZone"):
				h.queue_free()

func _custom_spawn_hazard_zone(data: Variant) -> Node:
	if data.get("type") == "battle_royale_zone":
		var br_zone = battle_royale_zone_scene.instantiate()
		br_zone.position = data.get("pos", Vector3.ZERO)
		if data.has("radius"):
			br_zone.zone_radius = data["radius"]
		if data.has("initial_wait_time"):
			br_zone.initial_wait_time = data["initial_wait_time"]
		if data.has("wait_time"):
			br_zone.wait_time = data["wait_time"]
		if data.has("dps"):
			br_zone.damage_per_second = data["dps"]
		if data.has("min_dist"):
			br_zone.min_relocation_distance = data["min_dist"]
		return br_zone
	elif data.get("type") == "orbital_laser":
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

	var active_mode = GameModes.get_mode(game_mode)
	if match_in_progress and not active_mode.is_team_based:
		dm_match_timer -= delta
		var timer_str = active_mode.format_timer(dm_match_timer)
		if dm_timer_label:
			dm_timer_label.text = timer_str
			dm_timer_label.show()
		var uism = get_node_or_null("/root/UIStateMachine")
		if uism:
			uism.update_match_status(timer_str, Color(1.0, 0.85, 0.25))
		
		if multiplayer.is_server() and dm_match_timer <= 0.0:
			dm_match_timer = 0.0
			match_in_progress = false
			var top_winner = active_mode.evaluate_timed_winner(connected_players)
			end_match.rpc(top_winner)
	elif dm_timer_label and dm_timer_label.visible and not (active_mode and ("has_zone" in active_mode and active_mode.has_zone)):
		dm_timer_label.hide()

	if is_training_mode:
		if scoreboard_panel and scoreboard_panel.visible:
			_scoreboard_refresh_timer -= delta
			if _scoreboard_refresh_timer <= 0.0:
				_scoreboard_refresh_timer = 0.25
				_update_scoreboard_content(false)
	else:
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
	scoreboard_panel.offset_left = -420.0
	scoreboard_panel.offset_top = -260.0
	scoreboard_panel.offset_right = 420.0
	scoreboard_panel.offset_bottom = 260.0
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
	scoreboard_status_label.text = "TEAM 1: 0/0 ALIVE    |    TEAM 2: 0/0 ALIVE    |    TEAM 3: 0/0 ALIVE"
	scoreboard_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scoreboard_status_label.add_theme_font_size_override("font_size", 13)
	scoreboard_status_label.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	main_vbox.add_child(scoreboard_status_label)
	
	var sep1 = HSeparator.new()
	main_vbox.add_child(sep1)
	
	# 1. Team-based 3-column container (TDM, Bo5, Training)
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
	t1_lbl_p.text = "PLAYER / HERO"
	t1_lbl_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t1_lbl_p.add_theme_font_size_override("font_size", 11)
	t1_lbl_p.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	t1_sub_hdr.add_child(t1_lbl_p)
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
	t2_lbl_p.text = "PLAYER / HERO"
	t2_lbl_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t2_lbl_p.add_theme_font_size_override("font_size", 11)
	t2_lbl_p.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	t2_sub_hdr.add_child(t2_lbl_p)
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

	var v_sep2 = VSeparator.new()
	scoreboard_team_container.add_child(v_sep2)
	
	# Team 3 Column
	var t3_vbox = VBoxContainer.new()
	t3_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t3_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t3_vbox.add_theme_constant_override("separation", 4)
	scoreboard_team_container.add_child(t3_vbox)
	
	var t3_header = Label.new()
	t3_header.text = "TEAM 3 (GREEN)"
	t3_header.add_theme_font_size_override("font_size", 14)
	t3_header.add_theme_color_override("font_color", Color(0.25, 0.9, 0.45))
	t3_vbox.add_child(t3_header)
	
	var t3_sub_hdr = HBoxContainer.new()
	t3_sub_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t3_lbl_p = Label.new()
	t3_lbl_p.text = "PLAYER / HERO"
	t3_lbl_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t3_lbl_p.add_theme_font_size_override("font_size", 11)
	t3_lbl_p.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	t3_sub_hdr.add_child(t3_lbl_p)
	var t3_lbl_k = Label.new()
	t3_lbl_k.text = "K / D / A"
	t3_lbl_k.custom_minimum_size = Vector2(75, 0)
	t3_lbl_k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	t3_lbl_k.add_theme_font_size_override("font_size", 11)
	t3_lbl_k.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	t3_sub_hdr.add_child(t3_lbl_k)
	t3_vbox.add_child(t3_sub_hdr)
	
	var t3_scroll = ScrollContainer.new()
	t3_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t3_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t3_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	t3_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	t3_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	t3_vbox.add_child(t3_scroll)
	
	scoreboard_t3_list = VBoxContainer.new()
	scoreboard_t3_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scoreboard_t3_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scoreboard_t3_list.add_theme_constant_override("separation", 4)
	t3_scroll.add_child(scoreboard_t3_list)
	
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
	
	# 3. Training Free-For-All Container (Training Mode)
	scoreboard_training_container = HBoxContainer.new()
	scoreboard_training_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scoreboard_training_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scoreboard_training_container.add_theme_constant_override("separation", 16)
	scoreboard_training_container.visible = false
	main_vbox.add_child(scoreboard_training_container)

	# Left Column: FFA Fighters Roster (Up to 5 players + Dummy)
	var tr_left_vbox = VBoxContainer.new()
	tr_left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tr_left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tr_left_vbox.add_theme_constant_override("separation", 6)
	scoreboard_training_container.add_child(tr_left_vbox)

	var tr_hdr_row = HBoxContainer.new()
	tr_hdr_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var tr_hdr_player = Label.new()
	tr_hdr_player.text = "FIGHTER / HERO"
	tr_hdr_player.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tr_hdr_player.add_theme_font_size_override("font_size", 12)
	tr_hdr_player.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	tr_hdr_row.add_child(tr_hdr_player)

	var tr_hdr_status = Label.new()
	tr_hdr_status.text = "STATUS"
	tr_hdr_status.custom_minimum_size = Vector2(130, 0)
	tr_hdr_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tr_hdr_status.add_theme_font_size_override("font_size", 12)
	tr_hdr_status.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	tr_hdr_row.add_child(tr_hdr_status)

	var tr_hdr_kda = Label.new()
	tr_hdr_kda.text = "K / D / A"
	tr_hdr_kda.custom_minimum_size = Vector2(110, 0)
	tr_hdr_kda.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr_hdr_kda.add_theme_font_size_override("font_size", 12)
	tr_hdr_kda.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	tr_hdr_row.add_child(tr_hdr_kda)

	tr_left_vbox.add_child(tr_hdr_row)

	scoreboard_training_scroll = ScrollContainer.new()
	scoreboard_training_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scoreboard_training_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scoreboard_training_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scoreboard_training_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scoreboard_training_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	tr_left_vbox.add_child(scoreboard_training_scroll)

	scoreboard_training_list = VBoxContainer.new()
	scoreboard_training_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scoreboard_training_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scoreboard_training_list.add_theme_constant_override("separation", 4)
	scoreboard_training_scroll.add_child(scoreboard_training_list)

	# Vertical separator between roster list and lobby management column
	var tr_vsep = VSeparator.new()
	scoreboard_training_container.add_child(tr_vsep)

	# Right Column: Lobby Management (small column)
	var tr_right_vbox = VBoxContainer.new()
	tr_right_vbox.custom_minimum_size = Vector2(240, 0)
	tr_right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tr_right_vbox.add_theme_constant_override("separation", 10)
	scoreboard_training_container.add_child(tr_right_vbox)

	var tr_panel = PanelContainer.new()
	tr_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tr_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tr_box_style = StyleBoxFlat.new()
	tr_box_style.bg_color = Color(0.04, 0.06, 0.10, 0.85)
	tr_box_style.border_color = Color(0.2, 0.3, 0.45, 0.7)
	tr_box_style.border_width_left = 1
	tr_box_style.border_width_top = 1
	tr_box_style.border_width_right = 1
	tr_box_style.border_width_bottom = 1
	tr_box_style.corner_radius_top_left = 8
	tr_box_style.corner_radius_top_right = 8
	tr_box_style.corner_radius_bottom_left = 8
	tr_box_style.corner_radius_bottom_right = 8
	tr_box_style.content_margin_left = 12
	tr_box_style.content_margin_top = 12
	tr_box_style.content_margin_right = 12
	tr_box_style.content_margin_bottom = 12
	tr_panel.add_theme_stylebox_override("panel", tr_box_style)
	tr_right_vbox.add_child(tr_panel)

	var tr_inner_vbox = VBoxContainer.new()
	tr_inner_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tr_inner_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tr_inner_vbox.add_theme_constant_override("separation", 10)
	tr_panel.add_child(tr_inner_vbox)

	var tr_lbl_title = Label.new()
	tr_lbl_title.text = "SESSION LOBBY"
	tr_lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tr_lbl_title.add_theme_font_size_override("font_size", 14)
	tr_lbl_title.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	tr_inner_vbox.add_child(tr_lbl_title)

	scoreboard_training_status_label = Label.new()
	scoreboard_training_status_label.text = "🔒 LOCAL (SOLO)"
	scoreboard_training_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scoreboard_training_status_label.add_theme_font_size_override("font_size", 12)
	scoreboard_training_status_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
	tr_inner_vbox.add_child(scoreboard_training_status_label)

	scoreboard_training_count_label = Label.new()
	scoreboard_training_count_label.text = "Players: 1 / 5"
	scoreboard_training_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scoreboard_training_count_label.add_theme_font_size_override("font_size", 12)
	scoreboard_training_count_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	tr_inner_vbox.add_child(scoreboard_training_count_label)

	var tr_div = HSeparator.new()
	tr_inner_vbox.add_child(tr_div)

	var tr_spacer = Control.new()
	tr_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tr_inner_vbox.add_child(tr_spacer)

	# Main Toggle Button (Open / Close Lobby)
	scoreboard_training_toggle_btn = Button.new()
	scoreboard_training_toggle_btn.text = "🌐 Open Lobby (Online)"
	scoreboard_training_toggle_btn.custom_minimum_size = Vector2(0, 38)
	scoreboard_training_toggle_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tr_inner_vbox.add_child(scoreboard_training_toggle_btn)
	scoreboard_training_toggle_btn.pressed.connect(_on_training_lobby_toggle_pressed)

	# Room Code Container (shown directly below the button when online)
	var code_card = PanelContainer.new()
	code_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var code_style = StyleBoxFlat.new()
	code_style.bg_color = Color(0.02, 0.04, 0.07, 0.9)
	code_style.border_color = Color(0.18, 0.5, 0.35, 0.8)
	code_style.border_width_left = 1
	code_style.border_width_top = 1
	code_style.border_width_right = 1
	code_style.border_width_bottom = 1
	code_style.corner_radius_top_left = 6
	code_style.corner_radius_top_right = 6
	code_style.corner_radius_bottom_left = 6
	code_style.corner_radius_bottom_right = 6
	code_style.content_margin_left = 8
	code_style.content_margin_top = 8
	code_style.content_margin_right = 8
	code_style.content_margin_bottom = 8
	code_card.add_theme_stylebox_override("panel", code_style)
	scoreboard_training_code_box = code_card
	scoreboard_training_code_box.visible = false
	tr_inner_vbox.add_child(scoreboard_training_code_box)

	var code_inner_vbox = VBoxContainer.new()
	code_inner_vbox.add_theme_constant_override("separation", 6)
	code_card.add_child(code_inner_vbox)

	scoreboard_training_code_label = Label.new()
	scoreboard_training_code_label.text = "ROOM CODE: ----"
	scoreboard_training_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scoreboard_training_code_label.add_theme_font_size_override("font_size", 14)
	scoreboard_training_code_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.6))
	code_inner_vbox.add_child(scoreboard_training_code_label)

	scoreboard_training_copy_btn = Button.new()
	scoreboard_training_copy_btn.text = "📋 Copy Room Code"
	scoreboard_training_copy_btn.custom_minimum_size = Vector2(0, 32)
	scoreboard_training_copy_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	code_inner_vbox.add_child(scoreboard_training_copy_btn)
	scoreboard_training_copy_btn.pressed.connect(_on_training_copy_code_pressed)
	
	var sep2 = HSeparator.new()
	main_vbox.add_child(sep2)
	
	var footer_lbl = Label.new()
	footer_lbl.text = "[ Hold TAB to view • Scroll wheel to view more ]"
	footer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_lbl.add_theme_font_size_override("font_size", 11)
	footer_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	main_vbox.add_child(footer_lbl)
	scoreboard_footer_label = footer_lbl
	
	ui_node.add_child(scoreboard_panel)

func _show_scoreboard(show: bool) -> void:
	if not scoreboard_panel:
		return
	if show:
		_update_scoreboard_content(true)
		scoreboard_panel.show()
	else:
		scoreboard_panel.hide()
	var uism = get_node_or_null("/root/UIStateMachine")
	if uism:
		uism.set_overlay("scoreboard", show)

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
	if scoreboard_t3_list:
		for c in scoreboard_t3_list.get_children():
			c.queue_free()
	if scoreboard_dm_list:
		for c in scoreboard_dm_list.get_children():
			c.queue_free()
	if scoreboard_training_list:
		for c in scoreboard_training_list.get_children():
			c.queue_free()

	if scoreboard_footer_label:
		if is_training_mode:
			scoreboard_footer_label.text = "[ Press TAB or ESC to close • Training Session Roster & Lobby ]"
		else:
			scoreboard_footer_label.text = "[ Hold TAB to view • Scroll wheel to view more ]"

	var current_scoreboard_mode = GameModes.get_mode(game_mode)
	if scoreboard_score_container:
		if current_scoreboard_mode.has_rounds and not is_training_mode:
			scoreboard_score_container.visible = true
			scoreboard_score_label.text = current_scoreboard_mode.format_scoreboard_header(bo5_score_t1, bo5_score_t2, bo5_score_t3)
			if match_in_progress:
				var current_round = bo5_score_t1 + bo5_score_t2 + bo5_score_t3 + 1
				scoreboard_score_sublabel.text = "%s • FIRST TO %d WINS (ROUND %d)" % [current_scoreboard_mode.display_name.to_upper(), current_scoreboard_mode.round_win_target, current_round]
			else:
				scoreboard_score_sublabel.text = "%s • FIRST TO %d WINS" % [current_scoreboard_mode.display_name.to_upper(), current_scoreboard_mode.round_win_target]
		else:
			scoreboard_score_container.visible = false
	
	if is_training_mode:
		if scoreboard_team_container: scoreboard_team_container.visible = false
		if scoreboard_dm_container: scoreboard_dm_container.visible = false
		if scoreboard_training_container: scoreboard_training_container.visible = true
		
		var map_str = ("  •  MAP: " + MAP_NAMES[current_map_id].to_upper()) if (current_map_id >= 0 and current_map_id < MAP_NAMES.size()) else "  •  MAP: STANDARD TRAINING"
		scoreboard_status_label.text = "TRAINING ARENA (FREE FOR ALL • CAP: 5 PLAYERS)" + map_str
		
		# Populate FFA Roster on Left (up to 5 players + dummy)
		if scoreboard_training_list:
			var p_keys = connected_players.keys()
			for pid in p_keys:
				var p_info = connected_players[pid]
				var p_name = p_info.get("name", "Player %s" % str(pid))
				var p_char = p_info.get("character", "poke")
				var p_node = players_container.get_node_or_null(str(pid))
				var is_alive = true
				if match_in_progress and p_node != null:
					is_alive = not p_node.get("is_dead")
				var k = p_info.get("kills", training_kills if pid == my_id else 0)
				var d = p_info.get("deaths", training_deaths if pid == my_id else 0)
				var a = p_info.get("assists", training_assists if pid == my_id else 0)
				var row = _create_scoreboard_player_row(pid, p_name + (" (YOU)" if pid == my_id else ""), p_char, p_node, is_alive, k, d, a, true)
				scoreboard_training_list.add_child(row)
			
			# Training Dummy row
			var dummy_node = players_container.get_node_or_null("TrainingDummy")
			if dummy_node:
				var dummy_row = _create_scoreboard_player_row(0, "Training Dummy", "dummy", dummy_node, not dummy_node.get("is_dead"), training_deaths, training_kills, 0, true)
				scoreboard_training_list.add_child(dummy_row)
		
		# Update Right Column Controls
		var is_online = _is_network_active() and multiplayer.is_server()
		if scoreboard_training_status_label:
			scoreboard_training_status_label.text = "🟢 ONLINE LOBBY" if is_online else "🔒 LOCAL (SOLO)"
			scoreboard_training_status_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5) if is_online else Color(0.65, 0.75, 0.85))
		if scoreboard_training_count_label:
			scoreboard_training_count_label.text = "Players: %d / 5" % connected_players.size()
		if scoreboard_training_code_box:
			scoreboard_training_code_box.visible = is_online and not current_room_code.is_empty()
		if scoreboard_training_code_label:
			scoreboard_training_code_label.text = "ROOM CODE: %s" % current_room_code
		if scoreboard_training_toggle_btn:
			if is_online:
				scoreboard_training_toggle_btn.text = "🔒 Close Lobby (Go Offline)"
			else:
				scoreboard_training_toggle_btn.text = "🌐 Open Lobby (Go Online)"
		return

	if scoreboard_training_container:
		scoreboard_training_container.visible = false

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
	
	# Team Deathmatch / Best of Five Layout (3v3v3)
	if scoreboard_team_container: scoreboard_team_container.visible = true
	if scoreboard_dm_container: scoreboard_dm_container.visible = false
	if scoreboard_score_container:
		scoreboard_score_container.visible = current_scoreboard_mode.has_rounds
	
	var t1_alive = 0
	var t1_total = 0
	var t2_alive = 0
	var t2_total = 0
	var t3_alive = 0
	var t3_total = 0
	
	for pid in connected_players.keys():
		var p_data = connected_players[pid]
		var team = int(p_data.get("team", 1))
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
		elif team == 3:
			t3_total += 1
			if is_alive: t3_alive += 1
			var row = _create_scoreboard_player_row(pid, p_name, char_key, p_node, is_alive, k, d, a, false)
			if scoreboard_t3_list:
				scoreboard_t3_list.add_child(row)
	
	if match_in_progress:
		var map_str = ("  •  MAP: " + MAP_NAMES[current_map_id].to_upper()) if (current_map_id >= 0 and current_map_id < MAP_NAMES.size()) else ""
		scoreboard_status_label.text = ("TEAM 1: %d/%d ALIVE    |    TEAM 2: %d/%d ALIVE    |    TEAM 3: %d/%d ALIVE" % [t1_alive, t1_total, t2_alive, t2_total, t3_alive, t3_total]) + map_str
	else:
		scoreboard_status_label.text = "LOBBY ROSTER (%d Connected Players)" % connected_players.size()

func _create_scoreboard_player_row(pid: int, p_name: String, char_key: String, p_node: Node, is_alive: bool, kills: int = 0, deaths: int = 0, assists: int = 0, is_dm: bool = false) -> Control:
	var row = PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0, 38)
	
	var row_style = StyleBoxFlat.new()
	row_style.bg_color = Color(0.08, 0.10, 0.15, 0.75)
	row_style.border_color = Color(0.18, 0.24, 0.35, 0.6)
	row_style.border_width_left = 1
	row_style.border_width_top = 1
	row_style.border_width_right = 1
	row_style.border_width_bottom = 1
	row_style.corner_radius_top_left = 6
	row_style.corner_radius_top_right = 6
	row_style.corner_radius_bottom_left = 6
	row_style.corner_radius_bottom_right = 6
	row_style.content_margin_left = 6
	row_style.content_margin_top = 3
	row_style.content_margin_right = 8
	row_style.content_margin_bottom = 3
	row.add_theme_stylebox_override("panel", row_style)
	
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 8)
	row.add_child(hbox)
	
	var my_id = multiplayer.get_unique_id() if (multiplayer and multiplayer.has_multiplayer_peer()) else 1
	var is_me = (pid == my_id)
	
	# Determine level and origin
	var p_level = 1
	var p_origin = "mortal"
	if p_node:
		if "player_level" in p_node:
			p_level = p_node.player_level
		if "character_origin" in p_node:
			p_origin = p_node.character_origin
	elif connected_players.has(pid):
		p_level = connected_players[pid].get("level", 1)
	
	# 1. Left side: Portrait box with circular level badge on the bottom left
	var portrait_container = Control.new()
	portrait_container.custom_minimum_size = Vector2(34, 34)
	portrait_container.size = Vector2(34, 34)
	hbox.add_child(portrait_container)
	
	var portrait_panel = PanelContainer.new()
	portrait_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var port_style = StyleBoxFlat.new()
	port_style.bg_color = Color(0.12, 0.15, 0.22, 0.95)
	port_style.border_color = Color(0.35, 0.45, 0.65, 0.8)
	port_style.border_width_left = 1
	port_style.border_width_top = 1
	port_style.border_width_right = 1
	port_style.border_width_bottom = 1
	port_style.corner_radius_top_left = 4
	port_style.corner_radius_top_right = 4
	port_style.corner_radius_bottom_left = 4
	port_style.corner_radius_bottom_right = 4
	portrait_panel.add_theme_stylebox_override("panel", port_style)
	portrait_container.add_child(portrait_panel)
	
	var port_initials = Label.new()
	port_initials.set_anchors_preset(Control.PRESET_FULL_RECT)
	port_initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	port_initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	port_initials.text = char_key.substr(0, 3).to_upper()
	port_initials.add_theme_font_size_override("font_size", 10)
	port_initials.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	portrait_panel.add_child(port_initials)
	
	# Circular level badge placed on the bottom left of the portrait
	var level_badge = LevelBadgeClass.create_badge(p_origin, p_level, Vector2(18, 18), 10)
	level_badge.position = Vector2(-3, 17)
	portrait_container.add_child(level_badge)
	
	# 2. Player info (Name on top, Hero + Status underneath)
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_vbox.add_theme_constant_override("separation", 0)
	hbox.add_child(info_vbox)
	
	var name_lbl = Label.new()
	name_lbl.text = ("★ " if is_me else "• ") + p_name
	name_lbl.add_theme_font_size_override("font_size", 12)
	if is_me:
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	else:
		name_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	info_vbox.add_child(name_lbl)
	
	var sub_lbl = Label.new()
	var char_title = get_character_display_name(char_key).to_upper()
	var status_str = ""
	var status_color = Color(0.6, 0.8, 1.0)
	if match_in_progress:
		if _is_peer_pending_disconnect(pid):
			status_str = " • ✖ DC"
			status_color = Color(0.65, 0.65, 0.65)
		elif is_alive:
			status_str = " • ● ALIVE"
			status_color = Color(0.3, 1.0, 0.4)
		else:
			status_str = " • ✖ DEAD"
			status_color = Color(1.0, 0.35, 0.35)
	else:
		status_str = " • READY"
		status_color = Color(0.6, 0.8, 1.0)
	sub_lbl.text = char_title + status_str
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.add_theme_color_override("font_color", status_color)
	info_vbox.add_child(sub_lbl)
	
	# 3. Right side: K/D/A Score
	var kda_lbl = Label.new()
	kda_lbl.custom_minimum_size = Vector2(110 if is_dm else 75, 0)
	kda_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kda_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	kda_lbl.add_theme_font_size_override("font_size", 12)
	kda_lbl.text = "%d / %d / %d" % [kills, deaths, assists]
	kda_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4) if is_me else Color(0.9, 0.9, 0.95))
	hbox.add_child(kda_lbl)
	
	return row

func _setup_top_center_hud() -> void:
	if top_center_container != null:
		return
	var ui_node = get_node_or_null("UI")
	if not ui_node:
		return
	
	top_center_container = VBoxContainer.new()
	top_center_container.name = "TopCenterHUD"
	top_center_container.anchors_preset = Control.PRESET_CENTER_TOP
	top_center_container.anchor_left = 0.5
	top_center_container.anchor_right = 0.5
	top_center_container.offset_left = -220.0
	top_center_container.offset_top = 16.0
	top_center_container.offset_right = 220.0
	top_center_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top_center_container.alignment = BoxContainer.ALIGNMENT_CENTER
	top_center_container.add_theme_constant_override("separation", 6)
	top_center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_center_container.visible = false
	ui_node.add_child(top_center_container)
	
	# 1. Match / Zone Status Timer Label
	dm_timer_label = Label.new()
	dm_timer_label.name = "DMTimerLabel"
	dm_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dm_timer_label.add_theme_font_size_override("font_size", 15)
	dm_timer_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	
	var style_timer = StyleBoxFlat.new()
	style_timer.bg_color = Color(0.06, 0.08, 0.14, 0.88)
	style_timer.border_color = Color(0.85, 0.68, 0.22, 0.9)
	style_timer.border_width_left = 1
	style_timer.border_width_top = 1
	style_timer.border_width_right = 1
	style_timer.border_width_bottom = 1
	style_timer.corner_radius_top_left = 6
	style_timer.corner_radius_top_right = 6
	style_timer.corner_radius_bottom_left = 6
	style_timer.corner_radius_bottom_right = 6
	style_timer.content_margin_left = 16
	style_timer.content_margin_right = 16
	style_timer.content_margin_top = 5
	style_timer.content_margin_bottom = 5
	dm_timer_label.add_theme_stylebox_override("panel", style_timer)
	dm_timer_label.visible = false
	top_center_container.add_child(dm_timer_label)
	
	# 2. Map Announcement Banner Label
	map_banner_label = Label.new()
	map_banner_label.name = "MapBannerLabel"
	map_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_banner_label.add_theme_font_size_override("font_size", 14)
	map_banner_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	
	var style_banner = StyleBoxFlat.new()
	style_banner.bg_color = Color(0.06, 0.09, 0.16, 0.90)
	style_banner.border_color = Color(0.35, 0.65, 0.95, 0.8)
	style_banner.border_width_left = 1
	style_banner.border_width_top = 1
	style_banner.border_width_right = 1
	style_banner.border_width_bottom = 1
	style_banner.corner_radius_top_left = 6
	style_banner.corner_radius_top_right = 6
	style_banner.corner_radius_bottom_left = 6
	style_banner.corner_radius_bottom_right = 6
	style_banner.content_margin_left = 14
	style_banner.content_margin_right = 14
	style_banner.content_margin_top = 4
	style_banner.content_margin_bottom = 4
	map_banner_label.add_theme_stylebox_override("panel", style_banner)
	map_banner_label.visible = false
	top_center_container.add_child(map_banner_label)
	
	# 3. Hazard Warning Container
	top_hazard_container = VBoxContainer.new()
	top_hazard_container.name = "TopHazardContainer"
	top_hazard_container.alignment = BoxContainer.ALIGNMENT_CENTER
	top_hazard_container.add_theme_constant_override("separation", 2)
	top_hazard_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_hazard_container.visible = false
	
	top_hazard_warning_label = Label.new()
	top_hazard_warning_label.name = "HazardWarningLabel"
	top_hazard_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_hazard_warning_label.add_theme_color_override("font_color", Color(1, 0.25, 0.25, 1))
	top_hazard_warning_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	top_hazard_warning_label.add_theme_constant_override("shadow_offset_x", 2)
	top_hazard_warning_label.add_theme_constant_override("shadow_offset_y", 2)
	top_hazard_warning_label.add_theme_font_size_override("font_size", 15)
	
	var style_warn = StyleBoxFlat.new()
	style_warn.bg_color = Color(0.12, 0.03, 0.03, 0.92)
	style_warn.border_color = Color(0.95, 0.25, 0.25, 0.9)
	style_warn.border_width_left = 1
	style_warn.border_width_top = 1
	style_warn.border_width_right = 1
	style_warn.border_width_bottom = 1
	style_warn.corner_radius_top_left = 6
	style_warn.corner_radius_top_right = 6
	style_warn.corner_radius_bottom_left = 6
	style_warn.corner_radius_bottom_right = 6
	style_warn.content_margin_left = 14
	style_warn.content_margin_right = 14
	style_warn.content_margin_top = 4
	style_warn.content_margin_bottom = 4
	top_hazard_warning_label.add_theme_stylebox_override("panel", style_warn)
	top_hazard_container.add_child(top_hazard_warning_label)
	
	top_hazard_arrow = Label.new()
	top_hazard_arrow.name = "HazardArrow"
	top_hazard_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_hazard_arrow.text = "⬆"
	top_hazard_arrow.add_theme_color_override("font_color", Color(1, 0.45, 0.2, 1))
	top_hazard_arrow.add_theme_font_size_override("font_size", 18)
	top_hazard_container.add_child(top_hazard_arrow)
	
	top_center_container.add_child(top_hazard_container)
	
	var uism = get_node_or_null("/root/UIStateMachine")
	if uism:
		uism.setup_top_center_hud(top_center_container, dm_timer_label, top_hazard_container, top_hazard_warning_label, top_hazard_arrow, map_banner_label)
		uism.register_element(top_center_container, uism.UICategory.NON_DIEGETIC, [uism.State.IN_MATCH])

func _setup_dm_timer_ui() -> void:
	_setup_top_center_hud()

func _setup_map_banner_ui() -> void:
	_setup_top_center_hud()

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
	
	var expanse = MAP_EXPANSE_SCENE.instantiate()
	expanse.name = "MapExpanse"
	expanse.visible = false
	expanse.process_mode = Node.PROCESS_MODE_DISABLED
	arena_node.add_child(expanse)

func _pick_next_random_map() -> int:
	if selected_custom_map >= 0 and selected_custom_map < arena_maps.size():
		return selected_custom_map
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
	var show_training_arena = is_training_mode and (map_id == -1)

	for i in range(arena_maps.size()):
		var m = arena_maps[i]
		if is_instance_valid(m):
			var active = (i == map_id) and not show_training_arena
			m.visible = active
			m.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	
	if training_map:
		training_map.visible = show_training_arena
		training_map.process_mode = Node.PROCESS_MODE_INHERIT if show_training_arena else Node.PROCESS_MODE_DISABLED
	
	call_deferred("_refresh_battle_royale_zones_for_mode")
	
	if map_banner_label:
		if map_id >= 0 and map_id < MAP_NAMES.size():
			map_banner_label.text = "⚔ ARENA: %s ⚔" % MAP_NAMES[map_id].to_upper()
			map_banner_label.modulate.a = 1.0
			map_banner_label.visible = true
			var tween = create_tween()
			tween.tween_interval(3.0)
			tween.tween_property(map_banner_label, "modulate:a", 0.0, 0.8)
			tween.tween_callback(func(): if map_banner_label: map_banner_label.visible = false)
		elif show_training_arena:
			map_banner_label.text = "🎯 ARENA: STANDARD TRAINING 🎯"
			map_banner_label.modulate.a = 1.0
			map_banner_label.visible = true
			var tween = create_tween()
			tween.tween_interval(2.5)
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
	var uism = get_node_or_null("/root/UIStateMachine")
	if uism:
		uism.set_overlay("shop", show)

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
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_TAB or event.physical_keycode == KEY_TAB):
		if is_training_mode and match_in_progress:
			if scoreboard_panel and scoreboard_panel.visible:
				_show_scoreboard(false)
			else:
				_show_scoreboard(true)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_B or event.physical_keycode == KEY_B):
		if shop_panel and shop_panel.visible:
			_show_shop(false)
			get_viewport().set_input_as_handled()
			return
		elif is_training_mode or (match_in_progress and game_mode != GameModes.MODE_TDM):
			_show_shop(true)
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("ui_cancel"):
		if scoreboard_panel and scoreboard_panel.visible and is_training_mode:
			_show_scoreboard(false)
			get_viewport().set_input_as_handled()
			return
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
		escape_tab_container.set_tab_hidden(2, not is_training_mode)
		escape_tab_container.current_tab = 0
	if is_training_mode:
		escape_title_label.text = "TRAINING SESSION"
	else:
		escape_title_label.text = "MATCH PAUSED"

func _switch_training_character(new_char_key: String) -> void:
	if not is_training_mode:
		return
	if not EnabledCharacters.is_character_enabled(new_char_key):
		return
	selected_character = new_char_key
	
	var current_pos = Vector3(-8.0, 0.1, 0.0)
	var current_rot_y = 0.0
	
	# Find and remove old player node immediately from tree
	for p in players_container.get_children():
		if p.name == "1" or (p.name != "TrainingDummy" and p.name.to_int() == 1):
			current_pos = p.global_position
			current_rot_y = p.rotation.y
			players_container.remove_child(p)
			p.queue_free()
			break

	if _is_network_active() and multiplayer.is_server():
		var spawn_payload = {
			"peer_id": 1,
			"character": new_char_key,
			"team_id": 1,
			"pos": current_pos,
			"rot_y": current_rot_y,
			"gold": 999999,
			"items": []
		}
		player_spawner.spawn(spawn_payload)
	else:
		# Directly instantiate new character
		var packed_scene = CHARACTERS.get(new_char_key, CHARACTERS["poke"])
		var player_instance = packed_scene.instantiate()
		player_instance.name = "1"
		player_instance.team_id = 1
		player_instance.position = current_pos
		player_instance.rotation.y = current_rot_y
		player_instance.gold = 999999
		players_container.add_child(player_instance)
	
	cleanup_player_entities(1)
	
	escape_panel.hide()
	display_damage_number(0, current_pos + Vector3(0, 0.5, 0), 1)

func _switch_training_map(new_map_id: int) -> void:
	if not is_training_mode:
		return
	training_selected_map = new_map_id
	if _is_network_active() and multiplayer.is_server():
		sync_active_map.rpc(new_map_id)
	else:
		sync_active_map(new_map_id)
	
	for proj in projectiles_container.get_children():
		proj.queue_free()
	for terr in terrain_container.get_children():
		terr.queue_free()
	for v in vision_container.get_children():
		v.queue_free()
	for h in hazard_container.get_children():
		h.queue_free()

	var dummy_pos = Vector3(0.0, 0.0, 0.0)
	var dummy_rot_y = 0.0
	var player_pos = Vector3(-8.0, 0.1, 0.0)
	var player_rot_y = 0.0

	if new_map_id != -1:
		var t2_spawns = spawn_points.get_node_or_null("Team2_Spawns")
		if t2_spawns:
			var sp_center = t2_spawns.get_node_or_null("Spawn3")
			dummy_pos = sp_center.global_position if sp_center else (t2_spawns.get_child(0).global_position if t2_spawns.get_child_count() > 0 else Vector3(24.0, 0.1, 0.0))
		else:
			dummy_pos = Vector3(24.0, 0.1, 0.0)
		dummy_rot_y = PI

		var t1_spawns = spawn_points.get_node_or_null("Team1_Spawns")
		if t1_spawns:
			var sp_center = t1_spawns.get_node_or_null("Spawn3")
			player_pos = sp_center.global_position if sp_center else (t1_spawns.get_child(0).global_position if t1_spawns.get_child_count() > 0 else Vector3(-24.0, 0.1, 0.0))
		else:
			player_pos = Vector3(-24.0, 0.1, 0.0)
		player_rot_y = 0.0

	var dummy_node = players_container.get_node_or_null("TrainingDummy")
	if dummy_node:
		dummy_node.global_position = dummy_pos
		dummy_node.rotation.y = dummy_rot_y
		dummy_node.set("home_position", dummy_pos)
		dummy_node.respawn()

	var player_node = players_container.get_node_or_null("1")
	if player_node:
		player_node.global_position = player_pos
		player_node.rotation.y = player_rot_y
		player_node.velocity = Vector3.ZERO
		player_node.knockback_velocity = Vector3.ZERO

	escape_panel.hide()

func _on_training_lobby_toggle_pressed() -> void:
	if not is_training_mode:
		return
	if _is_network_active() and multiplayer.is_server():
		_close_training_lobby_online()
	else:
		_open_training_lobby_online()

func _on_training_copy_code_pressed() -> void:
	if not current_room_code.is_empty():
		DisplayServer.clipboard_set(current_room_code)
		if scoreboard_training_copy_btn:
			scoreboard_training_copy_btn.text = "✓ Copied!"
			get_tree().create_timer(1.5).timeout.connect(func():
				if is_instance_valid(scoreboard_training_copy_btn):
					scoreboard_training_copy_btn.text = "📋 Copy Room Code"
			)

func _open_training_lobby_online() -> void:
	if _is_network_active():
		return
	
	randomize()
	current_room_code = NetworkUtils.generate_room_code()
	var peer = ENetMultiplayerPeer.new()
	# Max clients: 4 remote peers + 1 host = 5 player cap
	var err = peer.create_server(PORT, 4)
	if err != OK:
		print("Server host creation failed for training session: ", err)
		return
	
	multiplayer.multiplayer_peer = peer
	
	var local_ip = NetworkUtils.get_local_ipv4()
	if scoreboard_training_code_label:
		scoreboard_training_code_label.text = "ROOM CODE: %s (Registering...)" % current_room_code
	if scoreboard_training_copy_btn:
		scoreboard_training_copy_btn.text = "📋 Copy Room Code"
	
	_register_room_backend(current_room_code, local_ip, PORT)
	_start_upnp_discovery(PORT, local_ip)
	
	if match_in_progress:
		_rebind_training_entities_to_spawner()
	
	_update_scoreboard_content(false)

func _close_training_lobby_online() -> void:
	if not _is_network_active():
		return
	
	if multiplayer.is_server():
		for pid in multiplayer.get_peers():
			cleanup_player_entities(pid)
			var p_node = players_container.get_node_or_null(str(pid))
			if p_node:
				p_node.queue_free()
	
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	current_room_code = ""
	connected_players.clear()
	connected_players[1] = {
		"character": selected_character,
		"name": "Player 1",
		"team": 1,
		"slot": 0,
		"gold": 999999,
		"items": []
	}
	
	_update_scoreboard_content(false)

func _rebind_training_entities_to_spawner() -> void:
	var dummy_node = players_container.get_node_or_null("TrainingDummy")
	var dummy_pos = dummy_node.global_position if dummy_node else Vector3(0.0, 0.0, 0.0)
	var dummy_rot = dummy_node.rotation.y if dummy_node else 0.0
	
	var host_node = players_container.get_node_or_null("1")
	var host_pos = host_node.global_position if host_node else Vector3(-8.0, 0.1, 0.0)
	var host_rot = host_node.rotation.y if host_node else 0.0
	var host_gold = host_node.gold if host_node else 999999
	var host_items = host_node.item_slots if host_node else []
	
	if dummy_node:
		players_container.remove_child(dummy_node)
		dummy_node.queue_free()
	if host_node:
		players_container.remove_child(host_node)
		host_node.queue_free()
	
	# Spawn dummy via PlayerSpawner with FFA team 99
	player_spawner.spawn({
		"character": "dummy",
		"peer_id": 0,
		"team_id": 99,
		"pos": dummy_pos,
		"rot_y": dummy_rot
	})
	
	# Spawn host via PlayerSpawner with team 1
	player_spawner.spawn({
		"character": selected_character,
		"peer_id": 1,
		"team_id": 1,
		"pos": host_pos,
		"rot_y": host_rot,
		"gold": host_gold,
		"items": host_items
	})

func _spawn_joining_training_player(peer_id: int) -> void:
	if not multiplayer.is_server() or not is_training_mode or not match_in_progress:
		return
	
	sync_active_map.rpc_id(peer_id, training_selected_map)
	client_start_training_match.rpc_id(peer_id)
	
	var spawn_pos = Vector3(-8.0 + randf_range(-3.0, 3.0), 0.1, randf_range(-3.0, 3.0))
	if training_selected_map != -1:
		var t1_spawns = spawn_points.get_node_or_null("Team1_Spawns")
		if t1_spawns and t1_spawns.get_child_count() > 0:
			var rand_idx = randi() % t1_spawns.get_child_count()
			spawn_pos = t1_spawns.get_child(rand_idx).global_position
	
	var p_info = connected_players.get(peer_id, {})
	var p_char = p_info.get("character", "poke")
	
	var spawn_payload = {
		"peer_id": peer_id,
		"character": p_char,
		"team_id": peer_id,
		"pos": spawn_pos,
		"rot_y": 0.0,
		"items": [],
		"gold": 999999,
		"silene_bonus_hp": 0.0
	}
	player_spawner.spawn(spawn_payload)
	_sync_all_kda()
	if scoreboard_panel and scoreboard_panel.visible:
		_update_scoreboard_content(false)

@rpc("any_peer", "call_remote", "reliable")
func client_start_training_match() -> void:
	is_training_mode = true
	match_in_progress = true
	var uism = get_node_or_null("/root/UIStateMachine")
	if uism:
		uism.transition_to(uism.State.IN_MATCH)
	else:
		lobby_panel.hide()
		menu_panel.hide()
		join_dialog.hide()
		match_over_panel.hide()
		escape_panel.hide()
		if settings_panel:
			settings_panel.hide()

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
	if not _is_sender_host():
		return
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
		var show_tr = is_training_mode and (training_selected_map == -1)
		training_map.visible = show_tr
		training_map.process_mode = Node.PROCESS_MODE_INHERIT if show_tr else Node.PROCESS_MODE_DISABLED

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
	
	var uism = get_node_or_null("/root/UIStateMachine")
	if uism:
		uism.transition_to(uism.State.MAIN_MENU)
	else:
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
