class_name ExampleRangerData
extends RefCounted

## Example of a Pure Data-Driven Character
## Non-programmers only specify stats, visual colors, and assign ability scenes into slots!
## BasePlayer (player_base.gd) handles all instantiation, HUD, networking, and combat.

static func create() -> CharacterData:
	var data = CharacterData.new()
	
	# --- 1. Identity ---
	data.character_name = "Ranger"
	data.display_name = "Swift Ranger"
	data.archetype = "Sharpshooter"
	data.description = "Agile ranged skirmisher with high mobility and tactical abilities."
	
	# --- 2. Vitals & Combat ---
	data.max_health = 190.0
	data.max_shield = 50.0
	data.max_mana = 100.0
	data.crit_chance = 0.10
	data.crit_multiplier = 2.0
	
	# --- 3. Movement ---
	data.max_move_speed = 6.8
	data.ground_acceleration = 28.0
	data.ground_deceleration = 40.0
	data.air_acceleration = 8.5
	data.jump_velocity = 13.0
	
	# --- 4. Visuals ---
	data.body_color = Color(0.2, 0.75, 0.35, 1.0) # Forest green
	data.accent_color = Color(1.0, 0.85, 0.2, 1.0) # Gold
	data.capsule_radius = 0.38
	data.capsule_height = 1.75
	
	# --- 5. Ability Slots (Coupled to the Ability Pipeline) ---
	# Point each slot directly to an existing ability scene or custom configuration
	data.set_slot_ability("LMB", "res://ability/effects/projectile_effect.tscn")
	data.set_slot_ability("RMB", "res://ability/effects/melee_strike_effect.tscn")
	data.set_slot_ability("SHIFT", "res://ability/effects/dash_effect.tscn")
	data.set_slot_ability("Q", "res://ability/effects/buff_effect.tscn")
	data.set_slot_ability("E", "res://ability/effects/area_zone_effect.tscn")
	data.set_slot_ability("R", "res://ability/effects/aerial_crash_effect.tscn")
	
	return data
