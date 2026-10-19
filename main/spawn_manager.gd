class_name SpawnManager
extends Node

## SpawnManager - Subsystem handling player spawning, dummy instantiation,
## map respawn coordinate calculations, projectile spawning, and temporary terrain objects.

const TRAINING_MAP_PLAYER_RESPAWN = Vector3(-8.0, 0.1, 0.0)
const TRAINING_MAP_DUMMY_RESPAWN = Vector3(0.0, 0.1, 0.0)

var spawn_points: Node3D = null
var players_container: Node3D = null
var projectiles_container: Node3D = null
var terrain_container: Node3D = null
var vision_container: Node3D = null
var hazard_container: Node3D = null

var default_map: Node3D = null
var training_map: Node3D = null

var terrain_scene: PackedScene = preload("res://maps/temporary_terrain.tscn")
var projectile_scene: PackedScene = preload("res://projectile.tscn")
var training_dummy_scene: PackedScene = preload("res://training_dummy.tscn")

var main_game: Node = null

func _ready() -> void:
	if not main_game:
		var p = get_parent()
		if p and (p is Node3D or p.name == "Main"):
			main_game = p
	_bind_containers()

func _bind_containers() -> void:
	if not main_game:
		return
	players_container = main_game.get_node_or_null("Players")
	projectiles_container = main_game.get_node_or_null("Projectiles")
	terrain_container = main_game.get_node_or_null("TerrainObjects")
	vision_container = main_game.get_node_or_null("VisionZones")
	hazard_container = main_game.get_node_or_null("HazardZones")
	spawn_points = main_game.get_node_or_null("SpawnPoints")
	default_map = main_game.get_node_or_null("Arena/DefaultMap")
	training_map = main_game.get_node_or_null("Arena/TrainingMap")

func is_training_active() -> bool:
	if not main_game:
		return false
	if "is_training_mode" in main_game and main_game.is_training_mode:
		return true
	if "current_map_id" in main_game and main_game.current_map_id == -1:
		return true
	if "training_selected_map" in main_game and main_game.training_selected_map == -1:
		return true
	return false

func get_respawn_position(player_node: Node) -> Vector3:
	if is_training_active():
		if is_instance_valid(player_node) and (str(player_node.name).to_lower().contains("dummy") or player_node.name == "TrainingDummy"):
			return TRAINING_MAP_DUMMY_RESPAWN
		return TRAINING_MAP_PLAYER_RESPAWN

	var team_id = 1
	var slot_idx = 0
	if is_instance_valid(player_node):
		if "team_id" in player_node:
			team_id = player_node.team_id
		if "slot_index" in player_node:
			slot_idx = player_node.slot_index

	var team_spawns_name = "Team%d_Spawns" % team_id
	var team_spawns = null
	if spawn_points and is_instance_valid(spawn_points):
		team_spawns = spawn_points.get_node_or_null(team_spawns_name)

	if team_spawns and team_spawns.get_child_count() > 0:
		var spawn_child = team_spawns.get_child(slot_idx % team_spawns.get_child_count()) as Marker3D
		if spawn_child:
			return spawn_child.global_position

	# Fallback safe defaults based on team
	match team_id:
		1: return Vector3(-24.0, 0.1, 0.0)
		2: return Vector3(24.0, 0.1, 0.0)
		3: return Vector3(0.0, 0.1, -24.0)
		_: return Vector3(0.0, 0.1, 0.0)

func spawn_temporary_terrain(pos: Vector3, duration: float, owner_id: int = 0) -> Node:
	if not terrain_container:
		_bind_containers()
	if not terrain_scene:
		return null

	var terr = terrain_scene.instantiate() as Node3D
	if not terr:
		return null

	if "owner_id" in terr:
		terr.owner_id = owner_id
	if "duration" in terr:
		terr.duration = duration

	if terrain_container and is_instance_valid(terrain_container):
		terrain_container.add_child(terr, true)
	else:
		var root = get_tree().root
		root.add_child(terr, true)

	terr.global_position = pos
	return terr

func spawn_training_dummy() -> Node:
	if not players_container:
		_bind_containers()
	if not training_dummy_scene:
		return null

	var dummy = training_dummy_scene.instantiate()
	dummy.name = "TrainingDummy"
	if players_container and is_instance_valid(players_container):
		players_container.add_child(dummy, true)
	else:
		get_tree().root.add_child(dummy, true)

	dummy.global_position = get_respawn_position(dummy)
	return dummy
