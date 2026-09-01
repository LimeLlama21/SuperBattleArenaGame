class_name ReaperData
extends RefCounted

static func create() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "Reaper"
	data.display_name = "Reaper"
	data.archetype = "Reaper"
	data.max_health = 100.0
	data.max_move_speed = 10.0
	data.ground_acceleration = 80.0
	data.ground_friction = 40.0
	data.air_acceleration = 25.0
	data.air_drag = 3.5
	data.jump_velocity = 9.5
	data.ability_slots = {
		"LMB": "reaper_slash",
		"RMB": "reaper_tether",
		"Q": "reaper_cull_the_weak",
		"E": "reaper_nightmare",
		"R": "reaper_one_with_death",
		"SHIFT": "ethereal_dash"
	}
	data.passive_data = {
		"dash_impulse": 28.0,
		"dash_cooldown": 5.0,
		"ethereal_dash_duration": 0.45,
		"ms_steal_pct": 0.15,
		"ms_steal_duration": 2.5,
		"melee_size": 3.6,
		"melee_height": 2.0,
		"melee_angle_deg": 110.0,
		"melee_damage": 36.0,
		"melee_windup_time": 0.18,
		"tether_min_range": 6.0,
		"tether_max_range": 24.0,
		"tether_charge_duration": 1.0,
		"tether_duration": 1.75,
		"tether_break_dist": 22.0,
		"tether_root_duration": 1.50,
		"cull_inner_damage": 30.0,
		"cull_outer_damage": 65.0,
		"cull_outer_radius": 5.5,
		"cull_inner_radius": 3.2,
		"cull_cripple_duration": 2.5,
		"nightmare_duration": 1.8,
		"nightmare_radius": 4.5,
		"nightmare_cast_damage": 35.0,
		"nightmare_end_damage": 45.0,
		"ult_duration": 8.0,
		"ult_ms_bonus": 0.45,
		"ult_cdr_mult": 0.50,
		"ult_damage_mult": 1.30
	}
	return data
