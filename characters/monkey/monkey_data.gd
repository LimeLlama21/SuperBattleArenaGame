class_name MonkeyData
extends RefCounted

const MonkeyKingData = MonkeyData

static func create() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "Monkey"
	data.display_name = "The Great Sage"
	data.archetype = "Trickster"
	data.max_health = 160.0
	data.max_move_speed = 6.0
	data.ground_acceleration = 25.0
	data.ground_deceleration = 40.0
	data.air_acceleration = 7.5
	data.air_drag = 16.0
	data.jump_velocity = 13.0
	data.jump_horizontal_impulse = 2.0
	data.passive_data = {
		"stone_monkey_threshold": 0.30,
		"stone_monkey_duration": 3.0,
		"stone_monkey_heal_pct": 0.30,
		"stone_monkey_cooldown": 75.0
	}
	return data
