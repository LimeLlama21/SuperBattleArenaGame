class_name MorriganData
extends RefCounted

static func create() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "Morrigan"
	data.display_name = "Morrigan"
	data.archetype = "Mage"
	data.max_health = 90.0
	data.max_move_speed = 9.5
	data.ground_acceleration = 65.0
	data.ground_friction = 40.0
	data.air_acceleration = 25.0
	data.air_drag = 3.5
	data.jump_velocity = 9.5
	data.ability_slots = {
		"LMB": "morrigan_black_plumage",
		"RMB": "morrigan_omen_of_death",
		"Q": "morrigan_inescapable_ends",
		"E": "morrigan_banshee_cry",
		"R": "morrigan_born_of_blood",
		"SHIFT": "morrigan_crowstorm"
	}
	data.passive_data = {
		"max_crows": 3,
		"crow_detect_radius": 7.0,
		"crow_damage": 20.0,
		"crow_slow_percent": 0.35,
		"crow_slow_duration": 1.8,
		"dash_duration": 1.4,
		"dash_ms_mult": 0.60,
		"dash_dr_percent": 0.50,
		"dash_cooldown": 6.0,
		"lmb_max_charges": 5,
		"lmb_first_charge_time": 0.35,
		"lmb_subsequent_charge_time": 0.18,
		"lmb_damage_per_feather": 14.0,
		"mortar_charges": 2,
		"mortar_recharge_time": 6.5,
		"mortar_damage": 45.0,
		"mortar_radius": 3.2,
		"mortar_min_range": 5.0,
		"mortar_max_range": 22.0,
		"tether_range": 15.0,
		"tether_duration": 3.0,
		"tether_pull_accel": 32.0,
		"banshee_damage": 38.0,
		"banshee_silence_duration": 1.4,
		"banshee_radius": 7.5,
		"banshee_angle_deg": 85.0,
		"ult_channel_time": 1.0,
		"ult_damage": 80.0,
		"ult_stun_duration": 1.2,
		"ult_range": 45.0
	}
	return data
