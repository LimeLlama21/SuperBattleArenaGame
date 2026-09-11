class_name ReaperData
extends RefCounted

static func create() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "Reaper"
	data.display_name = "Keres"
	data.archetype = "Reaper"
	data.max_health = 200.0
	data.max_move_speed = 6.0
	data.ground_acceleration = 40.0
	data.ground_deceleration = 40.0
	data.air_acceleration = 12.0
	data.air_drag = 16.0
	data.jump_velocity = 13.0
	data.jump_horizontal_impulse = 2.0
	data.passive_data = {
		"ms_steal_pct": 0.15,
		"ms_steal_duration": 2.5
	}
	return data
