class_name LobbyController
extends Node

## LobbyController - Subsystem managing character selection, archetype/origin filters,
## player slot balancing, ready checks, and pre-match lobby coordination.

const CharacterRegistry = preload("res://characters/character_registry.gd")
const EnabledCharacters = preload("res://characters/enabled_characters.gd")

signal character_selected(peer_id: int, character_name: String)
signal player_ready_changed(peer_id: int, is_ready: bool)
signal team_changed(peer_id: int, team_id: int)
signal slot_assigned(peer_id: int, slot_idx: int)
signal all_players_ready()

# peer_id -> {"character": String, "team": int, "slot": int, "ready": bool, "skin": int}
var player_lobby_states: Dictionary = {}

var selected_origin_filter: String = "ALL"
var selected_archetype_filter: String = "ALL"

var main_game: Node = null

func _ready() -> void:
	if not main_game:
		var p = get_parent()
		if p and (p is Node3D or p.name == "Main"):
			main_game = p

func register_player(peer_id: int, default_team: int = 1, default_slot: int = 0) -> void:
	if not player_lobby_states.has(peer_id):
		player_lobby_states[peer_id] = {
			"character": "crush",
			"team": default_team,
			"slot": default_slot,
			"ready": false,
			"skin": 0
		}

func unregister_player(peer_id: int) -> void:
	player_lobby_states.erase(peer_id)

func select_character(peer_id: int, char_name: String) -> void:
	if not player_lobby_states.has(peer_id):
		register_player(peer_id)
	player_lobby_states[peer_id]["character"] = char_name
	character_selected.emit(peer_id, char_name)

func set_player_ready(peer_id: int, is_ready: bool) -> void:
	if not player_lobby_states.has(peer_id):
		register_player(peer_id)
	player_lobby_states[peer_id]["ready"] = is_ready
	player_ready_changed.emit(peer_id, is_ready)
	_check_all_ready()

func set_player_team(peer_id: int, team_id: int) -> void:
	if not player_lobby_states.has(peer_id):
		register_player(peer_id)
	player_lobby_states[peer_id]["team"] = team_id
	team_changed.emit(peer_id, team_id)

func get_player_character(peer_id: int) -> String:
	if player_lobby_states.has(peer_id):
		return player_lobby_states[peer_id]["character"]
	return "crush"

func get_player_team(peer_id: int) -> int:
	if player_lobby_states.has(peer_id):
		return player_lobby_states[peer_id]["team"]
	return 1

func is_player_ready(peer_id: int) -> bool:
	if player_lobby_states.has(peer_id):
		return player_lobby_states[peer_id]["ready"]
	return false

func _check_all_ready() -> void:
	if player_lobby_states.is_empty():
		return
	for pid in player_lobby_states:
		if not player_lobby_states[pid]["ready"]:
			return
	all_players_ready.emit()

func get_filtered_characters(origin: String = "ALL", archetype: String = "ALL") -> Array[String]:
	var results: Array[String] = []
	for char_key in EnabledCharacters.get_enabled_characters():
		var data = CharacterRegistry.get_character_data(char_key)
		var orig = data.origin if (data and "origin" in data) else ""
		var arch = data.archetype if (data and "archetype" in data) else ""
		var match_origin = (origin == "ALL" or orig == origin)
		var match_arch = (archetype == "ALL" or arch == archetype)
		if match_origin and match_arch:
			results.append(char_key)
	return results

