class_name ArtistData
extends RefCounted

static func create() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "The Painted Sage"
	data.display_name = "The Painted Sage"
	data.archetype = "Calligrapher"
	data.description = "The Painted Sage, master of ink alchemy and Vancian talismans. Prepares elemental Hanzi with celestial brushstrokes and unleashes prepared magic in battle."
	data.max_health = 200.0
	data.max_move_speed = 6.8
	data.ground_acceleration = 28.0
	data.ground_deceleration = 40.0
	data.air_acceleration = 8.0
	data.air_drag = 16.0
	data.jump_velocity = 13.0
	data.jump_horizontal_impulse = 2.0
	data.body_color = Color(0.12, 0.20, 0.18, 1.0)
	data.accent_color = Color(0.92, 0.82, 0.35, 1.0)
	data.passive_data = {}
	return data
