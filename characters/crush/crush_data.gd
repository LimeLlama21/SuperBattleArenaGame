class_name CrushData
extends RefCounted

static func create() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "Crush"
	data.display_name = "Heracles"
	data.archetype = "Juggernaut"
	data.max_health = 320.0
	data.max_move_speed = 5.1
	data.ground_acceleration = 20.0
	data.ground_deceleration = 40.0
	data.air_acceleration = 6.0
	data.air_drag = 16.0
	data.jump_velocity = 13.0
	data.jump_horizontal_impulse = 2.0
	data.passive_data = {
		"titan_surge_damage_mult": 1.4,
		"gray_health_decay_delay": 5.0,
		"gray_health_heal_percent": 0.5
	}
	return data
