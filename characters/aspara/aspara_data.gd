class_name AsparaData
extends RefCounted

const AsparsasData = AsparaData

static func create() -> CharacterData:
	var data = CharacterData.new()
	data.id = "aspara"
	data.character_name = "Aspara"
	data.display_name = "Uru"
	data.archetype = "Skirmisher"
	data.origins = [CharacterOrigin.ID_DIVINE]
	data.max_health = 240.0
	data.damage = 25.0
	data.max_move_speed = CharacterData.DEFAULT_MOVE_SPEED
	data.haste = 0.0
	data.ground_acceleration = 25.0
	data.ground_deceleration = 40.0
	data.air_acceleration = 7.5
	data.air_drag = 16.0
	data.jump_velocity = 13.0
	data.jump_horizontal_impulse = 2.0
	data.passive_data = {
		"wall_bounce_ratio": 0.55,
		"rupture_mark_duration": 3.5,
		"rupture_mark_max": 5,
		"rupture_damage_per_mark": 18.0,
		"rupture_heal_min_pct": 0.11,
		"rupture_heal_max_pct": 0.15
	}
	return data
