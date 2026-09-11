class_name DrakainaData
extends RefCounted

static func create() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "Drakaina"
	data.display_name = "Kampé"
	data.archetype = "Bruiser"
	data.description = "Kampé the Drakaina."
	data.max_health = 200.0
	data.max_move_speed = 6.0
	data.ground_acceleration = 25.0
	data.ground_deceleration = 40.0
	data.air_acceleration = 7.5
	data.air_drag = 16.0
	data.jump_velocity = 13.0
	data.jump_horizontal_impulse = 2.0
	data.body_color = Color(0.18, 0.45, 0.32, 1.0)
	data.accent_color = Color(0.85, 0.65, 0.15, 1.0)
	return data
