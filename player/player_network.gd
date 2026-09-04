class_name PlayerNetwork
extends CharacterBody3D

# --- Authority & Network Queries ---

func is_multiplayer_match() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return false
	var main_node = get_tree().root.get_node_or_null("Main") if get_tree() else null
	if main_node:
		if main_node.get("is_training_mode") == true:
			return false
		if main_node.has_method("is_multiplayer_match"):
			return main_node.is_multiplayer_match()
		if "connected_players" in main_node and main_node.connected_players is Dictionary:
			return main_node.connected_players.size() > 1
	return multiplayer.get_peers().size() > 0

func get_my_player_id() -> int:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return 1
	var uid = multiplayer.get_unique_id()
	return uid if uid > 0 else 1

func is_server_authoritative() -> bool:
	if not is_multiplayer_match():
		return true
	return multiplayer.is_server()

func is_local_player() -> bool:
	var my_id = get_my_player_id()
	if not is_multiplayer_match():
		return name.to_int() == my_id or name == "1" or name.to_int() == 0 or name == "Player"
	return name.to_int() == my_id

# --- Synchronizer Configuration ---

func _setup_synchronizer() -> void:
	if not is_multiplayer_match():
		return
	var sync = get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	if not sync:
		sync = MultiplayerSynchronizer.new()
		sync.name = "MultiplayerSynchronizer"
		add_child(sync)

	var peer_id = name.to_int()
	if peer_id > 0:
		set_multiplayer_authority(peer_id)
		sync.set_multiplayer_authority(peer_id)

	var config = sync.replication_config
	if not config:
		config = SceneReplicationConfig.new()
		sync.replication_config = config

	_add_sync_property(config, NodePath(".:position"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	_add_sync_property(config, NodePath(".:rotation"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	_add_sync_property(config, NodePath(".:team_id"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, NodePath(".:current_health"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, NodePath(".:current_shield"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, NodePath(".:is_dead"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, NodePath(".:active_windup_id"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, NodePath(".:active_windup_facing"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)

func _add_sync_property(config: SceneReplicationConfig, prop_path: NodePath, mode: int) -> void:
	if not config.has_property(prop_path):
		config.add_property(prop_path)
		config.property_set_replication_mode(prop_path, mode)
