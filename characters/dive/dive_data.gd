class_name DiveData
extends RefCounted

static func create() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "Dive"
	data.display_name = "Daughter of Gaia"
	data.archetype = "Skirmisher"
	data.max_health = 240.0
	data.max_move_speed = 9.5
	data.ground_acceleration = 65.0
	data.ground_friction = 40.0
	data.air_acceleration = 8.0
	data.air_drag = 3.5
	data.jump_velocity = 9.5
	data.ability_slots = {
		"LMB": "dive_slash",
		"RMB": "dive_heavy_cleave",
		"Q": "dive_earth_tremor",
		"E": "dive_deflecting_guard",
		"R": "dive_tectonic_uprising",
		"SHIFT": "dive_dash_or_crash"
	}
	data.passive_data = {
		"dash_impulse": 26.0,
		"max_dash_charges": 1,
		"dash_lockout": 0.85,
		"dash_recharge_time": 5.0,
		"wall_bounce_ratio": 0.55,
		"rupture_mark_duration": 3.5,
		"rupture_mark_max": 5,
		"rupture_damage_per_mark": 18.0,
		"melee_size": 3.4,
		"melee_height": 2.4,
		"melee_angle_deg": 100.0,
		"melee_damage": 32.0,
		"melee_windup_time": 0.18,
		"heavy_melee_size": 3.0,
		"heavy_melee_height": 2.4,
		"heavy_melee_angle_deg": 135.0,
		"heavy_melee_damage": 65.0,
		"crash_damage": 36.0,
		"crash_radius": 6.0
	}

	data.define_abilities([
		# Primary Fire (LMB): Slash
		{
			"id": "dive_slash",
			"name": "Slash",
			"icon": "⚔",
			"description": "Quick dual blade strike dealing 32.0 damage and applying Rupture Marks to enemies hit.",
			"slot": "LMB",
			"cooldown": 0.45,
			"effect": {
				"type": AbilityPipeline.EffectType.MELEE_STRIKE,
				"windup": 0.18
			},
			"hitbox": {
				"shape": AbilityPipeline.HitboxShape.SECTOR,
				"radius": 3.4,
				"angle": 100.0,
				"height": 2.4
			},
			"riders": [
				{"type": AbilityPipeline.RiderType.DAMAGE, "amount": 32.0},
				{"type": AbilityPipeline.RiderType.DIVE_MARK, "duration": 3.5}
			]
		},
		# Ability 1 (RMB): Heavy Cleave
		{
			"id": "dive_heavy_cleave",
			"name": "Heavy Cleave",
			"icon": "🪓",
			"description": "Sweeping heavy arc dealing 65.0 damage and detonating Rupture Marks for explosive critical burst.",
			"slot": "RMB",
			"cooldown": 6.0,
			"effect": {
				"type": AbilityPipeline.EffectType.MELEE_STRIKE,
				"windup": 0.18
			},
			"hitbox": {
				"shape": AbilityPipeline.HitboxShape.SECTOR,
				"radius": 3.0,
				"angle": 135.0,
				"height": 2.4
			},
			"riders": [
				{"type": AbilityPipeline.RiderType.DAMAGE, "amount": 65.0},
				{"type": AbilityPipeline.RiderType.DIVE_MARK, "duration": 3.5}
			]
		},
		# Ability 2 (Q): Earth Tremor
		{
			"id": "dive_earth_tremor",
			"name": "Earth Tremor",
			"icon": "🌋",
			"description": "Fractures the ground forward with an erupting earth fissure, slowing foes by 40% and spawning temporary terrain.",
			"slot": "Q",
			"cooldown": 8.0,
			"effect": {
				"type": AbilityPipeline.EffectType.PROJECTILE,
				"speed": 28.0,
				"range": 14.0,
				"size": 1.5,
				"pierces": true,
				"windup": 0.35
			},
			"hitbox": {
				"shape": AbilityPipeline.HitboxShape.LINE,
				"length": 14.0,
				"width": 1.5
			},
			"riders": [
				{"type": AbilityPipeline.RiderType.DAMAGE, "amount": 18.0},
				{"type": AbilityPipeline.RiderType.SLOW, "duration": 2.0, "intensity": 0.40},
				{"type": AbilityPipeline.RiderType.SPAWN_TERRAIN, "duration": 5.0}
			]
		},
		# Ability 3 (E): Deflecting Guard
		{
			"id": "dive_deflecting_guard",
			"name": "Deflecting Guard",
			"icon": "🛡",
			"description": "Raises blades in a defensive guard, mitigating 75% of incoming frontal damage and parrying incoming strikes.",
			"slot": "E",
			"cooldown": 4.0,
			"effect": {
				"type": AbilityPipeline.EffectType.STANCE_BLOCK,
				"duration": 3.0
			}
		},
		# Ultimate (R): Tectonic Uprising
		{
			"id": "dive_tectonic_uprising",
			"name": "Tectonic Uprising",
			"icon": "⛰",
			"description": "Erupts the arena in an airborne seismic shockwave, launching all nearby enemies into the air.",
			"slot": "R",
			"cooldown": 24.0,
			"can_cast_while_stunned": true,
			"effect": {
				"type": AbilityPipeline.EffectType.BUFF,
				"duration": 6.0
			}
		},
		# Dash & Aerial Crash (SHIFT)
		{
			"id": "dive_dash_or_crash",
			"name": "Dash / Crash",
			"icon": "🚀",
			"description": "Jet-propelled dash. Hitting a wall bounces Dive high into the sky, allowing a targeted ground Crash Down!",
			"slot": "SHIFT",
			"charges": 1,
			"recharge_time": 5.0,
			"cooldown": 0.85,
			"effect": {
				"type": AbilityPipeline.EffectType.DASH
			}
		}
	])

	return data
