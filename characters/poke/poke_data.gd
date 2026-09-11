class_name PokeData
extends RefCounted

static func create() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "Poke"
	data.display_name = "Arash"
	data.archetype = "Sharpshooter"
	data.max_health = 160.0
	data.max_move_speed = 6.9
	data.ground_acceleration = 30.0
	data.ground_deceleration = 40.0
	data.air_acceleration = 9.0
	data.air_drag = 16.0
	data.jump_velocity = 13.0
	data.jump_horizontal_impulse = 2.0
	data.passive_data = {
		"takedown_as_duration": 4.0,
		"takedown_as_percent": 0.60
	}
	return data
