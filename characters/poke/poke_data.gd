class_name PokeData
extends RefCounted

static func create() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "Poke"
	data.display_name = "Arash"
	data.archetype = "Sharpshooter"
	data.max_health = 160.0
	data.max_move_speed = 11.5
	data.ground_acceleration = 70.0
	data.ground_friction = 40.0
	data.air_acceleration = 8.0
	data.air_drag = 3.5
	data.jump_velocity = 9.5
	data.ability_slots = {
		"LMB": "poke_rail_shot",
		"RMB": "poke_sniper_stance",
		"Q": "poke_overcharge",
		"E": "poke_ion_fence",
		"R": "poke_orbital_hyperbeam",
		"SHIFT": "poke_dash"
	}
	data.passive_data = {
		"takedown_as_duration": 4.0,
		"takedown_as_percent": 0.60,
		"dash_impulse": 28.0,
		"dash_cooldown": 4.0,
		"rapid_shot_damage": 3.2,
		"rapid_shot_cooldown": 0.11,
		"rapid_shot_range": 15.5,
		"rapid_shot_speed": 85.0,
		"sniper_base_damage": 35.0,
		"sniper_max_damage": 70.0,
		"sniper_charge_time": 2.0,
		"sniper_range": 70.0,
		"sniper_speed": 120.0,
		"sniper_attack_cooldown": 1.0,
		"sniper_ms_penalty": 0.30,
		"rmb_flat_cooldown": 2.0,
		"overcharge_bonus_damage": 30.0,
		"overcharge_cooldown": 20.0,
		"hyperbeam_channel_time": 2.0,
		"hyperbeam_damage": 70.0,
		"hyperbeam_speed": 120.0,
		"hyperbeam_range": 70.0,
		"hyperbeam_cooldown": 25.0,
		"hyperbeam_trail_dps": 30.0,
		"hyperbeam_trail_slow_percent": 0.20,
		"hyperbeam_trail_duration": 5.0
	}

	data.define_abilities([
		# Primary Fire (LMB): Rapid Pulse Shot (High firerate, low damage, subpar DPS)
		{
			"id": "poke_rail_shot",
			"name": "Rapid Pulse Shot",
			"icon": "⚡",
			"description": "Fires a continuous stream of high-velocity pulse rounds with rapid cadence (9 shots/sec). Tight spread with subpar overall DPS.",
			"slot": "LMB",
			"cooldown": 0.11,
			"effect": {
				"type": AbilityPipeline.EffectType.PROJECTILE,
				"speed": 85.0,
				"range": 15.5,
				"size": 0.25
			},
			"hitbox": {
				"shape": AbilityPipeline.HitboxShape.LINE,
				"length": 15.5,
				"width": 0.25
			},
			"riders": [
				{"type": AbilityPipeline.RiderType.DAMAGE, "amount": 3.2}
			]
		},
		# Ability 1 (RMB): Sniper Stance (2-Second Full Charge)
		{
			"id": "poke_sniper_stance",
			"name": "Sniper Stance",
			"icon": "🎯",
			"description": "Hold RMB to enter an elevated sniper zoom stance. Hold LMB to charge up to 2.0s, unleashing a piercing laser beam dealing 35.0 to 70.0 damage across 70m.",
			"slot": "RMB",
			"cooldown": 2.0,
			"effect": {
				"type": AbilityPipeline.EffectType.PROJECTILE,
				"speed": 120.0,
				"range": 70.0,
				"size": 0.45,
				"chargeable": true
			},
			"hitbox": {
				"shape": AbilityPipeline.HitboxShape.LINE,
				"length": 70.0,
				"width": 0.45
			},
			"riders": [
				{"type": AbilityPipeline.RiderType.DAMAGE, "amount": 70.0}
			]
		},
		# Ability 2 (Q): Overcharged Rounds (Empowers RMB, only during Sniper Stance)
		{
			"id": "poke_overcharge",
			"name": "Overcharged Rounds",
			"icon": "🔮",
			"description": "Can only be cast while in Sniper Stance. Empowers sniper shots with +30.0 flat bonus damage and electric magenta bolts. Persists until a shot misses or stance is released (20s CD).",
			"slot": "Q",
			"cooldown": 20.0,
			"effect": {
				"type": AbilityPipeline.EffectType.BUFF,
				"duration": 999.0
			}
		},
		# Ability 3 (E): Ion Fence (Moved from Q to E)
		{
			"id": "poke_ion_fence",
			"name": "Ion Fence",
			"icon": "🚧",
			"description": "Deploys an 8m stationary energy barrier that blocks passage, grounds targets, and applies a heavy 70% slow for 1.5s.",
			"slot": "E",
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
		# Ultimate (R): Orbital Hyperbeam (2-Second Channel, Pierces Terrain & Enemies)
		{
			"id": "poke_orbital_hyperbeam",
			"name": "Orbital Hyperbeam",
			"icon": "☄",
			"description": "Channels for 2.0s, then fires a colossal orbital beam that pierces walls and enemies for 70.0 damage. Leaves behind a 5.0s corridor zone that deals 30 DPS, slows by 20%, and reveals vision.",
			"slot": "R",
			"cooldown": 25.0,
			"effect": {
				"type": AbilityPipeline.EffectType.PROJECTILE,
				"speed": 120.0,
				"range": 70.0,
				"size": 1.6
			},
			"hitbox": {
				"shape": AbilityPipeline.HitboxShape.LINE,
				"length": 70.0,
				"width": 1.6
			},
			"riders": [
				{"type": AbilityPipeline.RiderType.DAMAGE, "amount": 70.0}
			]
		},
		# Dash (SHIFT): Poke Dash (Resets on takedown)
		{
			"id": "poke_dash",
			"name": "Dash",
			"icon": "💨",
			"description": "Tactical slide in your movement direction. Cooldown resets to 0 instantly upon scoring a takedown!",
			"slot": "SHIFT",
			"cooldown": 4.0,
			"effect": {
				"type": AbilityPipeline.EffectType.DASH
			}
		}
	])

	return data
