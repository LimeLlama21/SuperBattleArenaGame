class_name CharacterData
extends RefCounted

# Base Character Identification
var character_name: String = ""
var display_name: String = ""
var archetype: String = "" # e.g. "Sharpshooter", "Skirmisher", "Juggernaut", "Reaper"

# Core Vitals & Defense
var max_health: float = 100.0
var max_shield: float = 100.0

# Movement Mechanics
var max_move_speed: float = 10.0
var ground_acceleration: float = 65.0
var ground_friction: float = 40.0
var intentional_movement_friction: float = 110.0
var air_acceleration: float = 25.0
var air_drag: float = 3.5
var jump_velocity: float = 9.5

# Assigned Abilities Pipeline IDs
var ability_slots: Dictionary = {
	"LMB": "",
	"RMB": "",
	"Q": "",
	"E": "",
	"R": "",
	"SHIFT": ""
}

# Character Specific Passives & Tuning Data
var passive_data: Dictionary = {}

# Parsed Ability Definitions (keyed by slot_key e.g. "LMB" and ability id)
var abilities: Dictionary = {}

func add_ability(config_or_def: Variant) -> CharacterData:
	var def: AbilityPipeline.AbilityDefinition = null
	if config_or_def is AbilityPipeline.AbilityDefinition:
		def = config_or_def
	elif config_or_def is Dictionary:
		def = AbilityPipeline.create_ability(config_or_def)
	
	if def != null:
		if def.slot_key != "":
			abilities[def.slot_key] = def
			ability_slots[def.slot_key] = def.id
		if def.id != "":
			abilities[def.id] = def
	return self

func define_abilities(list: Array) -> CharacterData:
	for item in list:
		add_ability(item)
	return self

func get_ability(key: String) -> AbilityPipeline.AbilityDefinition:
	return abilities.get(key, null)
