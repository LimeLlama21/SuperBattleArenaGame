class_name PokeData
extends RefCounted

static func create() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "Poke"
	data.display_name = "Poke"
	data.archetype = "Sharpshooter"
	data.max_health = 80.0
	data.max_move_speed = 11.5
	data.ground_acceleration = 70.0
	data.ground_friction = 40.0
	data.air_acceleration = 25.0
	data.air_drag = 3.5
	data.jump_velocity = 9.5
	data.ability_slots = {
		"LMB": "poke_rail_shot",
		"RMB": "poke_repulsor_bolt",
		"Q": "poke_ion_fence",
		"E": "poke_recon_flare",
		"R": "poke_overcharge",
		"SHIFT": "poke_dash"
	}
	data.passive_data = {
		"fleet_foot_duration": 2.5,
		"fleet_foot_ms_percent": 0.15,
		"dash_impulse": 28.0,
		"dash_cooldown": 4.0,
		"repulsor_knockback": 22.0,
		"repulsor_wall_stun_duration": 1.0
	}
	return data
