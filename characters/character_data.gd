class_name CharacterData
extends RefCounted

# Base Character Identification
var character_name: String = ""
var display_name: String = ""
var archetype: String = "" # e.g. "Sharpshooter", "Skirmisher", "Juggernaut", "Reaper"

# Core Vitals & Defense
var max_health: float = 200.0
var max_shield: float = 100.0

# Critical Strike Stats
var crit_chance: float = 0.0
var crit_multiplier: float = AbilityPipeline.CRIT_DAMAGE_MULTIPLIER

# Movement Mechanics
var max_move_speed: float = 10.0
var ground_acceleration: float = 65.0
var ground_friction: float = 40.0
var intentional_movement_friction: float = 110.0
var air_acceleration: float = 8.0
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

func get_display_name() -> String:
	return display_name if not display_name.is_empty() else character_name

func get_ability_ui_configs() -> Dictionary:
	var configs: Dictionary = {}
	for slot_key in ["LMB", "RMB", "SHIFT", "Q", "E", "R"]:
		var def = get_ability(slot_key)
		if def:
			configs[slot_key] = {
				"name": def.name,
				"icon": def.icon,
				"description": def.description,
				"stats": _format_ability_stats(def)
			}
		else:
			configs[slot_key] = {
				"name": slot_key,
				"icon": "⚔" if slot_key == "LMB" else null,
				"description": "",
				"stats": ""
			}
	return configs

static func _format_ability_stats(def: AbilityPipeline.AbilityDefinition) -> String:
	var parts: Array[String] = []
	if def.cooldown > 0.0:
		parts.append("Cooldown: %.1fs" % def.cooldown)
	elif def.recharge_time > 0.0:
		parts.append("Recharge: %.1fs" % def.recharge_time)
	if def.charges > 1:
		parts.append("Charges: %d" % def.charges)
	if def.effect:
		if def.effect.max_range > 0.0:
			parts.append("Range: %.1fm" % def.effect.max_range)
		if def.effect.speed > 0.0:
			parts.append("Speed: %.0fm/s" % def.effect.speed)
	for r in def.riders:
		if r.rider_type == AbilityPipeline.RiderType.DAMAGE and r.amount > 0.0:
			parts.append("Damage: %.0f" % r.amount)
		elif r.rider_type == AbilityPipeline.RiderType.STUN and r.duration > 0.0:
			parts.append("Stun: %.1fs" % r.duration)
		elif r.rider_type == AbilityPipeline.RiderType.SLOW and r.intensity > 0.0:
			parts.append("Slow: %d%%" % int(r.intensity * 100))
	return "  •  ".join(parts)
