class_name CrushData
extends RefCounted

static func create() -> CharacterData:
	var data = CharacterData.new()
	data.id = "crush"
	data.character_name = "Crush"
	data.display_name = "Gil"
	data.origins = [CharacterOrigin.ID_MORTAL, CharacterOrigin.ID_DIVINE]
	data.max_health = 320.0
	data.max_shield = 320.0
	data.damage = 20.0
	data.max_move_speed = CharacterData.DEFAULT_MOVE_SPEED
	data.haste = 0.0
	data.ground_acceleration = 20.0
	data.ground_deceleration = 40.0
	data.air_acceleration = 6.0
	data.air_drag = 16.0
	data.jump_velocity = 13.0
	data.jump_horizontal_impulse = 2.0
	data.passive_data = {
		"titan_surge_damage_mult": 1.4,
		"gray_health_decay_delay": 5.0,
		"gray_health_ratio": 0.5,
		"gray_health_heal_percent": 0.30,
		"out_of_combat_heal_ratio": 0.30,
		"gray_health_decay_rate": 0.1
	}
	data.abilities["LMB"] = {
		"id": "crush_clap",
		"name": "Thunderclap",
		"slot": "LMB",
		"slot_key": "LMB",
		"icon": "👏",
		"description": "Chargeable clap dealing damage in a frontal cone. Deals 50% damage if uncharged, scaling to full damage at 0.5s charge, with 0.5s delay before the hitbox emerges. Outer edge sweet spot deals 50% more damage than the inside.",
		"cooldown": 0.65,
		"cast_on_press": false,
		"hold_to_charge": true,
		"charge_time": 0.5,
		"windup_time": 0.5,
		"hitbox_type": 1,
		"hitbox_radius": 4.8,
		"hitbox_angle_deg": 100.0,
		"hitbox_height": 2.4,
		"damage_amount": 50.0,
		"damage_ratio": 0.75,
		"sweet_spot_damage_amount": 75.0,
		"sweet_spot_damage_ratio": 1.125,
		"sweet_spot_min_dist": 3.2,
		"uncharged_damage_multiplier": 0.5,
		"full_charge_time": 0.5
	}
	data.abilities["RMB"] = {
		"id": "crush_fan_stun",
		"name": "Seismic Arc",
		"slot": "RMB",
		"slot_key": "RMB",
		"icon": "⚡",
		"description": "Conical shockwave dealing 50.0 base damage + 30% attack ratio and stunning for 0.8s.",
		"cooldown": 6.0,
		"cast_on_press": false,
		"windup_time": 0.20,
		"hitbox_type": 1,
		"hitbox_radius": 5.2,
		"hitbox_angle_deg": 100.0,
		"hitbox_height": 2.4,
		"damage_amount": 50.0,
		"damage_ratio": 0.30,
		"stun_duration": 0.8
	}
	data.abilities["SHIFT"] = {
		"id": "crush_dash",
		"name": "Heavy Dash",
		"slot": "SHIFT",
		"slot_key": "SHIFT",
		"icon": "💨",
		"description": "Surges forward with unstoppable momentum.",
		"cooldown": 8.0,
		"impulse": 40.0
	}
	data.abilities["Q"] = {
		"id": "crush_ground_stomp",
		"name": "Ground Stomp",
		"slot": "Q",
		"slot_key": "Q",
		"icon": "💥",
		"description": "Stomps ground dealing 25.0 base damage + 30% attack ratio and granting 40.0 shield.",
		"cooldown": 7.0,
		"cast_on_press": false,
		"windup_time": 0.25,
		"hitbox_type": 6,
		"hitbox_radius": 6.5,
		"hitbox_height": 2.0,
		"damage_amount": 25.0,
		"damage_ratio": 0.30,
		"shield_amount": 40.0,
		"shield_duration": 4.0
	}
	data.abilities["E"] = {
		"id": "crush_iron_barrier",
		"name": "Iron Barrier",
		"slot": "E",
		"slot_key": "E",
		"icon": "🛡️",
		"description": "Fortifies defense gaining 50.0 temporary shield and consuming all gray health to bolster the barrier.",
		"cooldown": 10.0,
		"buff_name": "IronBarrier",
		"buff_duration": 4.0,
		"shield_amount": 50.0,
		"shield_duration": 5.0
	}
	data.abilities["R"] = {
		"id": "crush_juggernaut_charge",
		"name": "Juggernaut Charge",
		"slot": "R",
		"slot_key": "R",
		"icon": "🐗",
		"description": "Unstoppable charge that starts slow and accelerates to high speed, dealing 120.0 base damage plus up to 50% attack ratio and 30% max HP ratio at max speed, and stunning for 1.25s.",
		"cooldown": 45.0,
		"cast_on_press": false,
		"min_charge_speed": 8.0,
		"charge_speed": 28.0,
		"charge_duration": 2.5,
		"damage_amount": 120.0,
		"damage_ratio": 0.50,
		"max_hp_ratio": 0.30,
		"stun_duration": 1.25
	}
	return data
