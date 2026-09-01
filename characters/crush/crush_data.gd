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

	data.define_abilities([
		# Primary Fire (LMB): Slam
		{
			"id": "crush_slam",
			"name": "Slam",
			"slot": "LMB",
			"cooldown": 0.65,
			"effect": {
				"type": AbilityPipeline.EffectType.MELEE_STRIKE,
				"windup": 0.28
			},
			"hitbox": {
				"shape": AbilityPipeline.HitboxShape.SECTOR,
				"radius": 4.2,
				"angle": 120.0,
				"height": 2.4
			},
			"riders": [
				{"type": AbilityPipeline.RiderType.DAMAGE, "amount": 40.0}
			]
		},
		# Ability 1 (RMB): Fan Stun
		{
			"id": "crush_fan_stun",
			"name": "Fan Stun",
			"slot": "RMB",
			"cooldown": 7.5,
			"effect": {
				"type": AbilityPipeline.EffectType.MELEE_STRIKE,
				"windup": 0.16
			},
			"hitbox": {
				"shape": AbilityPipeline.HitboxShape.SECTOR,
				"radius": 5.2,
				"angle": 100.0,
				"height": 2.4
			},
			"riders": [
				{"type": AbilityPipeline.RiderType.DAMAGE, "amount": 25.0},
				{"type": AbilityPipeline.RiderType.STUN, "duration": 0.8},
				{"type": AbilityPipeline.RiderType.EMPOWER}
			]
		},
		# Ability 2 (Q): Ground Stomp
		{
			"id": "crush_ground_stomp",
			"name": "Ground Stomp",
			"slot": "Q",
			"cooldown": 8.0,
			"effect": {
				"type": AbilityPipeline.EffectType.AREA_ZONE,
				"windup": 0.30
			},
			"hitbox": {
				"shape": AbilityPipeline.HitboxShape.CYLINDER,
				"radius": 6.5,
				"height": 2.4
			},
			"riders": [
				{"type": AbilityPipeline.RiderType.DAMAGE, "amount": 20.0},
				{"type": AbilityPipeline.RiderType.SLOW, "duration": 2.5, "intensity": 0.30},
				{"type": AbilityPipeline.RiderType.SHIELD, "amount": 40.0, "duration": 5.0}
			]
		},
		# Ability 3 (E): Iron Barrier
		{
			"id": "crush_iron_barrier",
			"name": "Iron Barrier",
			"slot": "E",
			"cooldown": 10.0,
			"effect": {
				"type": AbilityPipeline.EffectType.BUFF,
				"duration": 5.0
			},
			"riders": [
				{"type": AbilityPipeline.RiderType.SHIELD, "amount": 50.0, "duration": 5.0}
			]
		},
		# Ultimate (R): Juggernaut Charge
		{
			"id": "crush_juggernaut_charge",
			"name": "Juggernaut Charge",
			"slot": "R",
			"cooldown": 26.0,
			"effect": {
				"type": AbilityPipeline.EffectType.CHARGE_SLAM,
				"speed": 28.0,
				"duration": 1.0,
				"windup": 0.45
			},
			"hitbox": {
				"shape": AbilityPipeline.HitboxShape.CYLINDER,
				"radius": 3.2,
				"height": 3.0
			},
			"riders": [
				{"type": AbilityPipeline.RiderType.DAMAGE, "amount": 120.0},
				{"type": AbilityPipeline.RiderType.STUN, "duration": 1.25},
				{"type": AbilityPipeline.RiderType.KNOCKBACK, "amount": 16.0}
			]
		},
		# Dash (SHIFT): Crush Dash
		{
			"id": "crush_dash",
			"name": "Dash",
			"slot": "SHIFT",
			"cooldown": 8.0,
			"effect": {
				"type": AbilityPipeline.EffectType.DASH
			}
		}
	])

	return data
