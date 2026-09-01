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

	data.define_abilities([
		# Primary Fire (LMB): Rail Shot
		{
			"id": "poke_rail_shot",
			"name": "Rail Shot",
			"slot": "LMB",
			"cooldown": 0.6,
			"effect": {
				"type": AbilityPipeline.EffectType.PROJECTILE,
				"speed": 90.0,
				"range": 50.0,
				"size": 0.35
			},
			"hitbox": {
				"shape": AbilityPipeline.HitboxShape.LINE,
				"length": 50.0,
				"width": 0.35
			},
			"riders": [
				{"type": AbilityPipeline.RiderType.DAMAGE, "amount": 20.0},
				{"type": AbilityPipeline.RiderType.SPEED_BOOST, "duration": 2.5, "intensity": 0.15}
			]
		},
		# Ability 1 (RMB): Repulsor Bolt
		{
			"id": "poke_repulsor_bolt",
			"name": "Repulsor Bolt",
			"slot": "RMB",
			"cooldown": 6.5,
			"effect": {
				"type": AbilityPipeline.EffectType.PROJECTILE,
				"speed": 85.0,
				"range": 60.0,
				"size": 0.35
			},
			"hitbox": {
				"shape": AbilityPipeline.HitboxShape.LINE,
				"length": 60.0,
				"width": 0.7
			},
			"riders": [
				{"type": AbilityPipeline.RiderType.DAMAGE, "amount": 0.0},
				{"type": AbilityPipeline.RiderType.KNOCKBACK, "amount": 36.0},
				{"type": AbilityPipeline.RiderType.STUN, "duration": 1.0}
			]
		},
		# Ability 2 (Q): Ion Fence
		{
			"id": "poke_ion_fence",
			"name": "Ion Fence",
			"slot": "Q",
			"cooldown": 8.0,
			"effect": {
				"type": AbilityPipeline.EffectType.AREA_ZONE,
				"range": 6.5,
				"duration": 6.0
			},
			"hitbox": {
				"shape": AbilityPipeline.HitboxShape.LINE,
				"length": 8.0,
				"width": 0.25,
				"height": 2.6
			},
			"riders": [
				{"type": AbilityPipeline.RiderType.GROUND, "duration": 2.5},
				{"type": AbilityPipeline.RiderType.SLOW, "duration": 1.5, "intensity": 0.70}
			]
		},
		# Ability 3 (E): Recon Flare
		{
			"id": "poke_recon_flare",
			"name": "Recon Flare",
			"slot": "E",
			"cooldown": 11.0,
			"effect": {
				"type": AbilityPipeline.EffectType.PROJECTILE,
				"speed": 45.0,
				"range": 65.0,
				"size": 0.8
			},
			"hitbox": {
				"shape": AbilityPipeline.HitboxShape.CIRCLE,
				"radius": 12.0
			},
			"riders": [
				{"type": AbilityPipeline.RiderType.VISION_REVEAL, "duration": 5.0, "amount": 12.0}
			]
		},
		# Ultimate (R): Overcharge
		{
			"id": "poke_overcharge",
			"name": "Overcharge",
			"slot": "R",
			"cooldown": 24.0,
			"effect": {
				"type": AbilityPipeline.EffectType.PROJECTILE,
				"speed": 110.0,
				"range": 95.0,
				"size": 1.3
			},
			"hitbox": {
				"shape": AbilityPipeline.HitboxShape.LINE,
				"length": 95.0,
				"width": 1.3
			},
			"riders": [
				{"type": AbilityPipeline.RiderType.DAMAGE, "amount": 50.0}
			]
		},
		# Dash (SHIFT): Poke Dash
		{
			"id": "poke_dash",
			"name": "Dash",
			"slot": "SHIFT",
			"cooldown": 4.0,
			"effect": {
				"type": AbilityPipeline.EffectType.DASH
			}
		}
	])

	return data
