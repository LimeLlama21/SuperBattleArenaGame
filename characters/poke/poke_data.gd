class_name PokeData
extends RefCounted

static func create() -> CharacterData:
	var data = CharacterData.new()
	data.id = "poke"
	data.character_name = "Poke"
	data.display_name = "Aslan"
	data.archetype = "Sharpshooter"
	data.origins = [CharacterOrigin.ID_MORTAL]
	data.max_health = 160.0
	data.damage = 30.0
	data.max_move_speed = CharacterData.DEFAULT_MOVE_SPEED
	data.haste = 0.0
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
