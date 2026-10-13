class_name MorriganData
extends RefCounted

static func create() -> CharacterData:
	var data = CharacterData.new()
	data.id = "morrigan"
	data.character_name = "Morrigan"
	data.display_name = "Saga"
	data.origins = [CharacterOrigin.ID_DIVINE]
	data.max_health = 180.0
	data.damage = 26.0
	data.max_move_speed = CharacterData.DEFAULT_MOVE_SPEED
	data.haste = 0.0
	data.ground_acceleration = 25.0
	data.ground_deceleration = 40.0
	data.air_acceleration = 7.5
	data.air_drag = 16.0
	data.jump_velocity = 13.0
	data.jump_horizontal_impulse = 2.0
	data.passive_data = {
		"max_crows": 1,
		"cooldown": 20.0,
		"cooldown_reduction_per_hit": 3.0,
		"empower_lmb_slow_base": 0.10,
		"empower_lmb_slow_per_feather": 0.05,
		"empower_lmb_duration": 5.0,
		"empower_rmb_bleed_ratio": 0.20,
		"empower_rmb_bleed_duration": 5.0,
		"empower_q_accel_multiplier": 1.50,
		"empower_q_stun_duration": 1.5,
		"empower_q_slow_percent": 0.40,
		"empower_q_slow_duration": 2.0,
		"empower_e_damage_multiplier": 1.20,
		"empower_e_silence_duration": 0.5,
		"e_slow_percent": 0.30,
		"e_slow_duration": 1.0,
		"ult_fear_duration": 1.5
	}
	return data
