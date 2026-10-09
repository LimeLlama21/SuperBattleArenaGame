class_name MonkeyData
extends RefCounted

const MonkeyKingData = MonkeyData

static func create() -> CharacterData:
	var data = CharacterData.new()
	data.id = "monkey"
	data.character_name = "Monkey"
	data.display_name = "Sunny Kong"
	data.archetype = "Trickster"
	data.origins = [CharacterOrigin.ID_DIVINE, CharacterOrigin.ID_MONSTROUS]
	data.max_health = 160.0
	data.damage = 24.0
	data.max_move_speed = CharacterData.DEFAULT_MOVE_SPEED
	data.haste = 0.0
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
