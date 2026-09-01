class_name DiveData
extends RefCounted

static func create() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "Dive"
	data.display_name = "Dive"
	data.archetype = "Skirmisher"
	data.max_health = 120.0
	data.max_move_speed = 9.5
	data.ground_acceleration = 65.0
	data.ground_friction = 40.0
	data.air_acceleration = 25.0
	data.air_drag = 3.5
	data.jump_velocity = 9.5
	data.ability_slots = {
		"LMB": "dive_slash",
		"RMB": "dive_heavy_cleave",
		"Q": "dive_earth_tremor",
		"E": "dive_deflecting_guard",
		"R": "dive_tectonic_uprising",
		"SHIFT": "dive_dash_or_crash"
	}
	data.passive_data = {
		"dash_impulse": 26.0,
		"max_dash_charges": 1,
		"dash_lockout": 0.85,
		"dash_recharge_time": 5.0,
		"rupture_mark_duration": 3.5,
		"rupture_mark_max": 5,
		"rupture_damage_per_mark": 18.0,
		"melee_size": 3.4,
		"melee_height": 2.4,
		"melee_angle_deg": 100.0,
		"melee_damage": 32.0,
		"melee_windup_time": 0.18,
		"heavy_melee_size": 3.0,
		"heavy_melee_height": 2.4,
		"heavy_melee_angle_deg": 135.0,
		"heavy_melee_damage": 65.0,
		"crash_damage": 36.0,
		"crash_radius": 6.0
	}
	return data
