class_name CharacterData
extends Resource

# --- Base Character Identification ---
@export_group("Identity")
@export var character_name: String = ""
@export var display_name: String = ""
@export var archetype: String = "" # e.g. "Sharpshooter", "Skirmisher", "Juggernaut", "Reaper"
@export_multiline var description: String = ""

# --- Core Vitals & Defense ---
@export_group("Vitals & Defense")
@export var max_health: float = 200.0
@export var max_shield: float = 100.0
@export var max_mana: float = 100.0
@export var mana_regen: float = 3.0

# --- Critical Strike Stats ---
@export_group("Combat Stats")
@export var crit_chance: float = 0.0
@export var crit_multiplier: float = 1.75

# --- Movement Mechanics ---
@export_group("Movement Mechanics")
@export var max_move_speed: float = 6.0
@export var ground_acceleration: float = 25.0
@export var ground_deceleration: float = 40.0
@export var intentional_movement_friction: float = 75.0
@export var air_acceleration: float = 7.5
@export var air_max_speed_mult: float = 0.3
@export var air_drag: float = 16.0
@export var jump_velocity: float = 13.0
@export var jump_horizontal_impulse: float = 2.0

var ground_friction: float:
	get: return ground_deceleration
	set(v): ground_deceleration = v

# --- Visual Styling & Models ---
@export_group("Visuals")
@export var body_color: Color = Color(0.2, 0.6, 1.0, 1.0)
@export var accent_color: Color = Color(1.0, 0.8, 0.2, 1.0)
@export var model_scene: PackedScene = null
@export var capsule_radius: float = 0.4
@export var capsule_height: float = 1.8
@export var custom_camera_offset: Vector3 = Vector3.ZERO

# --- Ability Slots (The Core Coupling) ---
@export_group("Abilities")
@export var ability_lmb: PackedScene = null
@export var ability_rmb: PackedScene = null
@export var ability_shift: PackedScene = null
@export var ability_q: PackedScene = null
@export var ability_e: PackedScene = null
@export var ability_r: PackedScene = null
@export var ability_passive: PackedScene = null

# Flexible dictionary for dynamic slot registration or custom slots
@export var abilities: Dictionary = {}

# Character Specific Passives & Tuning Data
@export_group("Passive & Tuning")
@export var passive_data: Dictionary = {}

func get_display_name() -> String:
	return display_name if not display_name.is_empty() else character_name

func get_ability_for_slot(slot_key: String) -> Variant:
	match slot_key.to_upper():
		"LMB":
			if ability_lmb != null: return ability_lmb
		"RMB":
			if ability_rmb != null: return ability_rmb
		"SHIFT":
			if ability_shift != null: return ability_shift
		"Q":
			if ability_q != null: return ability_q
		"E":
			if ability_e != null: return ability_e
		"R":
			if ability_r != null: return ability_r
		"PASSIVE":
			if ability_passive != null: return ability_passive
	
	if abilities.has(slot_key):
		return abilities[slot_key]
	if abilities.has(slot_key.to_upper()):
		return abilities[slot_key.to_upper()]
	if abilities.has(slot_key.to_lower()):
		return abilities[slot_key.to_lower()]
	return null

func set_slot_ability(slot_key: String, ability: Variant) -> void:
	match slot_key.to_upper():
		"LMB":
			if ability is PackedScene: ability_lmb = ability
		"RMB":
			if ability is PackedScene: ability_rmb = ability
		"SHIFT":
			if ability is PackedScene: ability_shift = ability
		"Q":
			if ability is PackedScene: ability_q = ability
		"E":
			if ability is PackedScene: ability_e = ability
		"R":
			if ability is PackedScene: ability_r = ability
		"PASSIVE":
			if ability is PackedScene: ability_passive = ability
	abilities[slot_key.to_upper()] = ability

func get_all_slotted_abilities() -> Dictionary:
	var result = {}
	for slot in ["LMB", "RMB", "SHIFT", "Q", "E", "R", "PASSIVE"]:
		var ab = get_ability_for_slot(slot)
		if ab != null:
			result[slot] = ab
	for k in abilities:
		if not result.has(k.to_upper()):
			result[k.to_upper()] = abilities[k]
	return result
