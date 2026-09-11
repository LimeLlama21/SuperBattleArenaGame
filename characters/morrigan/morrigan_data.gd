class_name MorriganData
extends RefCounted

static func create() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "Morrigan"
	data.display_name = "Morrigan"
	data.archetype = "Mage"
	data.max_health = 180.0
	data.max_move_speed = 5.7
	data.ground_acceleration = 25.0
	data.ground_deceleration = 40.0
	data.air_acceleration = 7.5
	data.air_drag = 16.0
	data.jump_velocity = 13.0
	data.jump_horizontal_impulse = 2.0
	data.passive_data = {
		"max_crows": 3,
		"crow_detect_radius": 7.0,
		"crow_damage": 20.0,
		"crow_slow_percent": 0.35,
		"crow_slow_duration": 1.8
	}
	return data
