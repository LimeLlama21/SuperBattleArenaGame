class_name CleodolindaData
extends RefCounted

static func create() -> CharacterData:
	var data = CharacterData.new()
	data.id = "Cleodolinda"
	data.character_name = "Cleodolinda"
	data.display_name = "Cleo"
	data.archetype = "Hoverboarder"
	data.description = "Cleo, agile hoverboard rider with high mobility."
	data.max_health = 180.0
	data.max_move_speed = 7.0
	data.ground_acceleration = 28.0
	data.ground_deceleration = 40.0
	data.air_acceleration = 8.0
	data.air_drag = 16.0
	data.jump_velocity = 13.0
	data.jump_horizontal_impulse = 2.0
	data.body_color = Color(0.20, 0.70, 0.85, 1.0)
	data.accent_color = Color(0.95, 0.80, 0.20, 1.0)
	data.passive_data = {}
	return data
