class_name MapRegistry
extends RefCounted

## Map Identifiers
const ID_TRAINING: int = -1
const ID_COLOSSEUM: int = 0
const ID_CHASM: int = 1
const ID_ISLANDS: int = 2

## Arena map display names
const MAP_NAMES: Array[String] = [
	"Colosseum",
	"The Jagged Chasm",
	"Shattered Archipelago"
]

## Preloaded map scenes
const MAP_COLOSSEUM_SCENE: PackedScene = preload("res://maps/map_colosseum.tscn")
const MAP_CHASM_SCENE: PackedScene = preload("res://maps/map_chasm.tscn")
const MAP_ISLANDS_SCENE: PackedScene = preload("res://maps/map_islands.tscn")
const MAP_TRAINING_SCENE: PackedScene = preload("res://maps/map_training.tscn")

## Array of standard competitive arena scenes indexed by map ID (0, 1, 2)
const ARENA_SCENES: Array[PackedScene] = [
	MAP_COLOSSEUM_SCENE,
	MAP_CHASM_SCENE,
	MAP_ISLANDS_SCENE
]

static func get_map_name(map_id: int) -> String:
	if map_id >= 0 and map_id < MAP_NAMES.size():
		return MAP_NAMES[map_id]
	elif map_id == ID_TRAINING:
		return "Standard Training Map"
	return "Random Map"

static func get_map_scene(map_id: int) -> PackedScene:
	if map_id == ID_TRAINING:
		return MAP_TRAINING_SCENE
	elif map_id >= 0 and map_id < ARENA_SCENES.size():
		return ARENA_SCENES[map_id]
	return null

static func get_arena_count() -> int:
	return ARENA_SCENES.size()
