class_name PlayerAuthority
extends Node

## PlayerAuthority - Sibling component handling multiplayer authority, peer IDs,
## and synchronization registration.

var player: CharacterBody3D = null

func _get_player() -> CharacterBody3D:
	if is_instance_valid(player):
		return player
	var parent = get_parent()
	if parent is CharacterBody3D:
		return parent as CharacterBody3D
	return null

# --- Authority & Replication Queries ---

func is_multiplayer_match() -> bool:
	var p = _get_player()
	var mp = p.multiplayer if p else multiplayer
	if not mp or not mp.has_multiplayer_peer():
		return false
	var tree = p.get_tree() if p else get_tree()
	var main_node = tree.root.get_node_or_null("Main") if tree else null
	if main_node:
		if main_node.get("is_training_mode") == true:
			return mp.get_peers().size() > 0
		if main_node.has_method("is_multiplayer_match"):
			return main_node.is_multiplayer_match()
		if "connected_players" in main_node and main_node.connected_players is Dictionary:
			return main_node.connected_players.size() > 1
	return mp.get_peers().size() > 0

func get_my_player_id() -> int:
	var p = _get_player()
	var mp = p.multiplayer if p else multiplayer
	if not mp or not mp.has_multiplayer_peer():
		return 1
	var uid = mp.get_unique_id()
	return uid if uid > 0 else 1

func is_server_authoritative() -> bool:
	if not is_multiplayer_match():
		return true
	var p = _get_player()
	var mp = p.multiplayer if p else multiplayer
	return mp.is_server() if mp else true

func is_local_player() -> bool:
	var p = _get_player()
	var my_id = get_my_player_id()
	var node_name = p.name if p else name
	if not is_multiplayer_match():
		if node_name.begins_with("TrainingDummy") or node_name.begins_with("Dummy") or node_name.begins_with("Bot"):
			return false
		return node_name == str(my_id) or node_name == "1" or node_name == "Player" or (node_name.is_valid_int() and node_name.to_int() == my_id)
	return node_name.is_valid_int() and node_name.to_int() == my_id and my_id > 0

# --- Synchronizer Configuration ---

func _setup_synchronizer() -> void:
	var p = _get_player()
	if not p:
		return
	var peer_id = p.name.to_int()
	if peer_id <= 0:
		peer_id = 1

	# Host (Peer 1) is the multiplayer authority over the player node and authoritative state
	p.set_multiplayer_authority(1, false)

	# 1. Client Synchronizer (Authority = owning peer_id):
	# Responsible ONLY for movement transform prediction & aiming visual facing
	var client_sync = p.get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	if not client_sync:
		client_sync = MultiplayerSynchronizer.new()
		client_sync.name = "MultiplayerSynchronizer"
		p.add_child(client_sync)

	client_sync.set_multiplayer_authority(peer_id)
	var client_config = client_sync.replication_config
	if not client_config:
		client_config = SceneReplicationConfig.new()
		client_sync.replication_config = client_config

	_add_sync_property(client_config, NodePath(".:position"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	_add_sync_property(client_config, NodePath(".:rotation"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	_add_sync_property(client_config, NodePath(".:active_windup_facing"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)

	# 2. Server Synchronizer (Authority = 1 / Host):
	# Authoritatively replicates health, shields, death state, and team assignment from host to all clients
	var server_sync = p.get_node_or_null("ServerSynchronizer") as MultiplayerSynchronizer
	if not server_sync:
		server_sync = MultiplayerSynchronizer.new()
		server_sync.name = "ServerSynchronizer"
		p.add_child(server_sync)

	server_sync.set_multiplayer_authority(1)
	var server_config = server_sync.replication_config
	if not server_config:
		server_config = SceneReplicationConfig.new()
		server_sync.replication_config = server_config

	_add_sync_property(server_config, NodePath(".:team_id"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(server_config, NodePath(".:current_health"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(server_config, NodePath(".:current_shield"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(server_config, NodePath(".:is_dead"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(server_config, NodePath(".:active_windup_id"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(server_config, NodePath(".:player_level"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)

func _add_sync_property(config: SceneReplicationConfig, prop_path: NodePath, mode: int) -> void:
	if not config.has_property(prop_path):
		config.add_property(prop_path)
		config.property_set_replication_mode(prop_path, mode)
