class_name SileneData
extends RefCounted

static func create() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "The Dragon of Silene"
	data.display_name = "Saint Silene"
	data.archetype = "Juggernaut"
	data.description = "Saint Silene, the Dragon of Silene. An immense draconic juggernaut who cleaves enemies with claw and fang, breaths terrain-occluded dragonfire, and grows permanently stronger with every takedown."
	data.max_health = 320.0
	data.max_move_speed = 5.5
	data.ground_acceleration = 22.0
	data.ground_deceleration = 40.0
	data.air_acceleration = 6.5
	data.air_drag = 16.0
	data.jump_velocity = 13.0
	data.jump_horizontal_impulse = 2.0
	data.body_color = Color(0.18, 0.45, 0.32, 1.0)
	data.accent_color = Color(0.85, 0.65, 0.15, 1.0)
	data.passive_data = {
		"bonus_damage": 10.0,
		"takedown_bonus_hp": 10.0
	}
	return data
