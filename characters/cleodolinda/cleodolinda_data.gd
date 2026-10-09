class_name CleodolindaData
extends RefCounted

static func create() -> CharacterData:
	var data = CharacterData.new()
	data.id = "cleodolinda"
	data.character_name = "Cleodolinda"
	data.display_name = "Cleo"
	data.archetype = "Hoverboarder"
	data.origins = [CharacterOrigin.ID_MORTAL]
	data.description = "Cleo, agile hoverboard rider with high mobility."
	data.max_health = 180.0
	data.damage = 24.0
	data.max_move_speed = CharacterData.DEFAULT_MOVE_SPEED
	data.haste = 0.0
	data.ground_acceleration = 28.0
	data.ground_deceleration = 40.0
	data.air_acceleration = 8.0
	data.air_drag = 16.0
	data.jump_velocity = 13.0
	data.jump_horizontal_impulse = 2.0
	data.body_color = Color(0.20, 0.70, 0.85, 1.0)
	data.accent_color = Color(0.95, 0.80, 0.20, 1.0)
	data.model_scene = load("res://assets/characters/Cleodolinda.glb") as PackedScene
	data.passive_data = {}
	data.abilities["LMB"] = {
		"id": "cleo_spell_1",
		"name": "Spell 1",
		"slot": "LMB",
		"slot_key": "LMB",
		"icon": "✨",
		"description": "Semicircle strike with low base damage that scales with relative velocity.",
		"cooldown": 0.4,
		"cast_on_press": true,
		"windup_time": 0.0,
		"hitbox_type": 1,
		"hitbox_radius": 4.0,
		"hitbox_angle_deg": 180.0,
		"hitbox_height": 2.4,
		"damage_amount": 12.0
	}
	data.abilities["RMB"] = {
		"id": "cleo_rmb",
		"name": "Spell 2",
		"slot": "RMB",
		"slot_key": "RMB",
		"icon": "💫",
		"description": "A delayed full-circle spinning sweep that deals moderate damage and slows enemies.",
		"cooldown": 4.0,
		"cast_on_press": true,
		"windup_time": 2.29,
		"hitbox_type": 6,
		"hitbox_radius": 4.5,
		"hitbox_angle_deg": 360.0,
		"hitbox_height": 2.5,
		"damage_amount": 35.0,
		"slow_duration": 2.5,
		"slow_intensity": 0.35
	}
	data.abilities["SHIFT"] = {
		"id": "cleo_dash",
		"name": "Hover Surge",
		"slot": "SHIFT",
		"slot_key": "SHIFT",
		"icon": "💨",
		"description": "Swift hoverboard burst dash.",
		"cooldown": 4.0,
		"impulse": 26.0
	}
	data.abilities["Q"] = {
		"id": "cleo_spell_2",
		"name": "Spell 2",
		"slot": "Q",
		"slot_key": "Q",
		"icon": "💫",
		"description": "Cleo's second spell.",
		"cooldown": 2.0,
		"cast_on_press": true
	}
	data.abilities["E"] = {
		"id": "cleo_spell_3",
		"name": "Spell 3",
		"slot": "E",
		"slot_key": "E",
		"icon": "🚀",
		"description": "Continuous hover boost mode that increases normal movement acceleration and ms cap by 50% while active.",
		"cooldown": 0.0,
		"cast_on_press": false
	}
	data.abilities["R"] = {
		"id": "cleo_maximum_suction",
		"name": "Maximum Suction",
		"slot": "R",
		"slot_key": "R",
		"icon": "🌪️",
		"description": "Cleo wields her vacuum cleaner and pulls enemies in in a large area in front of her with acceleration greater than base movement speed.",
		"cooldown": 30.0,
		"duration": 3.5,
		"hitbox_type": 1,
		"hitbox_radius": 14.0,
		"hitbox_angle_deg": 80.0,
		"action_type": 2
	}
	return data
