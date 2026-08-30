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
