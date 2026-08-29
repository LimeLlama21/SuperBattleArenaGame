class_name CharacterData
extends RefCounted

# Base Character Identification
var character_name: String = ""
var display_name: String = ""
var archetype: String = "" # e.g. "Sharpshooter", "Brawler", "Juggernaut"

# Core Vitals & Defense
var max_health: float = 100.0
var max_shield: float = 100.0

# Movement Mechanics
var max_move_speed: float = 10.0
var ground_acceleration: float = 65.0
var ground_friction: float = 40.0
var air_acceleration: float = 25.0
var air_drag: float = 3.5
var jump_velocity: float = 9.5

# Dash Properties
var dash_impulse: float = 26.0
var max_dash_charges: int = 1
var dash_cooldown: float = 4.0
var dash_recharge_time: float = 4.0

# Combat Base Attributes
var is_melee: bool = false
var attack_cooldown: float = 0.3
var windup_time: float = 0.0
var melee_windup_time: float = 0.28
var projectile_size: float = 1.0
var projectile_damage: float = 50.0
var projectile_speed: float = 70.0
var melee_size: float = 4.2
var melee_height: float = 2.4
var melee_damage: float = 55.0
var melee_angle_deg: float = 120.0

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
