class_name CrushData
extends RefCounted

static func create() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "Crush"
	data.display_name = "Crush"
	data.archetype = "Juggernaut"
	data.max_health = 160.0
	data.max_move_speed = 8.5
	data.ground_acceleration = 60.0
	data.ground_friction = 40.0
	data.air_acceleration = 20.0
	data.air_drag = 3.5
	data.jump_velocity = 9.5
	data.ability_slots = {
		"LMB": "crush_slam",
		"RMB": "crush_fan_stun",
		"Q": "crush_ground_stomp",
		"E": "crush_iron_barrier",
		"R": "crush_juggernaut_charge",
		"SHIFT": "crush_dash"
	}
	data.passive_data = {
		"dash_impulse": 40.0,
		"max_dash_charges": 1,
		"dash_cooldown": 8.0,
		"titan_surge_damage_mult": 1.4,
		"gray_health_decay_delay": 5.0,
		"gray_health_heal_percent": 0.5,
		"melee_size": 4.2,
		"melee_height": 2.4,
		"melee_angle_deg": 120.0,
		"melee_damage": 55.0,
		"melee_windup_time": 0.28,
		"fan_stun_damage": 25.0,
		"fan_stun_radius": 5.2,
		"fan_stun_height": 2.4,
		"fan_stun_angle_deg": 100.0,
		"fan_stun_duration": 0.8,
		"stomp_damage": 20.0,
		"stomp_radius": 6.5,
		"stomp_shield": 40.0,
		"barrier_shield": 50.0,
		"charge_damage": 120.0,
		"charge_speed": 28.0,
		"charge_duration": 1.0,
		"charge_stun": 1.25,
		"charge_knockup": 16.0
	}
	return data
