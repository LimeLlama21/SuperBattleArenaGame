class_name CharacterData
extends Resource

# --- Base Character Identification ---
@export_group("Identity")
@export var id: String = "" # Canonical identifier matching folder name & code references (e.g. "poke", "asparsas")
@export var character_name: String = ""
@export var display_name: String = "" # Player-facing display name (e.g. "Arash", "Urvashi")
@export var archetype: String = "" # e.g. "Sharpshooter", "Skirmisher", "Juggernaut", "Reaper"
@export_multiline var description: String = ""

# --- Origins & Classification ---
@export_group("Origins")
## Origins assigned to character: "mortal", "divine", "monstrous" (supports multiple)
@export var origins: Array = []:
	set(val):
		origins.clear()
		for item in val:
			var s = CharacterOrigin.normalize_id(item)
			if not s.is_empty() and not origins.has(s):
				origins.append(s)

# --- Core Character Stats ---
# Characters have 4 core stats: Health, Damage, Movement Speed (same for all characters), and Haste (0 by default).
const DEFAULT_MOVE_SPEED: float = 6.0

@export_group("Core Stats")
@export var max_health: float = 200.0
@export var damage: float = 25.0
@export var max_move_speed: float = DEFAULT_MOVE_SPEED
@export var haste: float = 0.0

# Aliases for clean access and backward compatibility
var health: float:
	get: return max_health
	set(v): max_health = v

var base_health: float:
	get: return max_health
	set(v): max_health = v

var base_damage: float:
	get: return damage
	set(v): damage = v

var move_speed: float:
	get: return max_move_speed
	set(v): max_move_speed = v

var base_move_speed: float:
	get: return max_move_speed
	set(v): max_move_speed = v

var ability_haste: float:
	get: return haste
	set(v): haste = v

var base_haste: float:
	get: return haste
	set(v): haste = v

# --- Core Vitals & Defense ---
@export_group("Vitals & Defense")
@export var max_shield: float = 100.0
@export var max_mana: float = 100.0
@export var mana_regen: float = 3.0

# --- Critical Strike Stats ---
@export_group("Combat Stats")
@export var crit_chance: float = 0.0
@export var crit_multiplier: float = 1.75

# --- Movement Mechanics ---
@export_group("Movement Mechanics")
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
	if not display_name.is_empty():
		return display_name
	if not character_name.is_empty():
		return character_name
	return id.capitalize() if not id.is_empty() else "Character"

func get_id() -> String:
	if not id.is_empty():
		return id
	if not character_name.is_empty():
		return character_name.to_lower()
	return ""

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

# --- Origin Helper Methods ---
func add_origin(origin_val: Variant) -> void:
	var norm = CharacterOrigin.normalize_id(origin_val)
	if not norm.is_empty() and not origins.has(norm):
		origins.append(norm)

func remove_origin(origin_val: Variant) -> void:
	var norm = CharacterOrigin.normalize_id(origin_val)
	origins.erase(norm)

func has_origin(origin_val: Variant) -> bool:
	var norm = CharacterOrigin.normalize_id(origin_val)
	return origins.has(norm)

func get_origins() -> Array[String]:
	var result: Array[String] = []
	for item in origins:
		result.append(str(item))
	return result

func is_multi_origin() -> bool:
	return origins.size() > 1

func get_primary_origin() -> String:
	return origins[0] if origins.size() > 0 else ""

func get_origin_resources() -> Array[CharacterOrigin]:
	var result: Array[CharacterOrigin] = []
	for o_id in origins:
		var res = OriginRegistry.get_origin(o_id)
		if res:
			result.append(res)
	return result
