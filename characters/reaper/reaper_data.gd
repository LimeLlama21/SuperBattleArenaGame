class_name ReaperData
extends RefCounted

static func create() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "Reaper"
	data.display_name = "Reaper"
	data.archetype = "Reaper"
	data.max_health = 100.0
	data.max_move_speed = 10.0
	data.ground_acceleration = 80.0
	data.ground_friction = 40.0
	data.air_acceleration = 25.0
	data.air_drag = 3.5
	data.jump_velocity = 9.5
	data.ability_slots = {
		"LMB": "reaper_slash",
		"RMB": "reaper_tether",
		"Q": "reaper_cull_the_weak",
		"E": "reaper_nightmare",
		"R": "reaper_one_with_death",
		"SHIFT": "ethereal_dash"
	}
	data.passive_data = {
		"dash_impulse": 28.0,
		"dash_cooldown": 5.0,
		"ethereal_dash_duration": 0.45,
		"ms_steal_pct": 0.15,
		"ms_steal_duration": 2.5,
		"melee_size": 3.6,
		"melee_height": 2.0,
		"melee_angle_deg": 110.0,
		"melee_damage": 36.0,
		"melee_windup_time": 0.18,
		"tether_min_range": 6.0,
		"tether_max_range": 24.0,
		"tether_charge_duration": 1.0,
		"tether_duration": 1.75,
		"tether_break_dist": 22.0,
		"tether_root_duration": 1.50,
		"cull_inner_damage": 30.0,
		"cull_outer_damage": 65.0,
		"cull_outer_radius": 5.5,
		"cull_inner_radius": 3.2,
		"cull_cripple_duration": 2.5,
		"nightmare_duration": 1.8,
		"nightmare_radius": 4.5,
		"nightmare_cast_damage": 35.0,
		"nightmare_end_damage": 45.0,
		"ult_duration": 8.0,
		"ult_ms_bonus": 0.45,
		"ult_cdr_mult": 0.50,
		"ult_damage_mult": 1.30
	}

	data.define_abilities([
		# Primary Fire (LMB): Reaper's Scythe
		{
			"id": "reaper_slash",
			"name": "Reaper's Scythe",
			"slot": "LMB",
			"cooldown": 0.45,
			"effect": {
				"type": AbilityPipeline.EffectType.MELEE_STRIKE,
				"windup": 0.18
			},
			"hitbox": {
				"shape": AbilityPipeline.HitboxShape.SECTOR,
				"radius": 3.6,
				"angle": 110.0,
				"height": 2.4
			},
			"riders": [
				{"type": AbilityPipeline.RiderType.DAMAGE, "amount": 36.0},
				{"type": AbilityPipeline.RiderType.MS_STEAL, "duration": 2.5, "intensity": 0.15}
			]
		},
		# Ability 1 (RMB): Spectral Tether
		{
			"id": "reaper_tether",
			"name": "Spectral Tether",
			"slot": "RMB",
			"cooldown": 7.0,
			"effect": {
				"type": AbilityPipeline.EffectType.PROJECTILE,
				"speed": 52.0,
				"range": 24.0,
				"size": 0.6
			},
			"hitbox": {
				"shape": AbilityPipeline.HitboxShape.LINE,
				"length": 24.0,
				"width": 0.8
			},
			"riders": [
				{"type": AbilityPipeline.RiderType.DAMAGE, "amount": 25.0},
				{"type": AbilityPipeline.RiderType.TETHER, "duration": 1.75}
			]
		},
		# Ability 2 (Q): Cull the Weak
		{
			"id": "reaper_cull_the_weak",
			"name": "Cull the Weak",
			"slot": "Q",
			"cooldown": 7.5,
			"effect": {
				"type": AbilityPipeline.EffectType.AREA_ZONE,
				"windup": 0.75,
				"follow_caster": true
			},
			"hitbox": {
				"shape": AbilityPipeline.HitboxShape.DONUT,
				"radius": 5.5,
				"width": 3.2,
				"height": 2.4
			},
			"riders": [
				{"type": AbilityPipeline.RiderType.DAMAGE, "amount": 65.0},
				{"type": AbilityPipeline.RiderType.CRIPPLE, "duration": 2.5, "intensity": 0.35}
			]
		},
		# Ability 3 (E): Nightmare
		{
			"id": "reaper_nightmare",
			"name": "Nightmare",
			"slot": "E",
			"cooldown": 12.0,
			"effect": {
				"type": AbilityPipeline.EffectType.BUFF,
				"duration": 1.8
			},
			"hitbox": {
				"shape": AbilityPipeline.HitboxShape.CIRCLE,
				"radius": 4.5
			},
			"riders": [
				{"type": AbilityPipeline.RiderType.DAMAGE, "amount": 35.0},
				{"type": AbilityPipeline.RiderType.SLOW, "duration": 1.8, "intensity": 0.40},
				{"type": AbilityPipeline.RiderType.ETHEREAL, "duration": 1.8}
			]
		},
		# Ultimate (R): One with Death
		{
			"id": "reaper_one_with_death",
			"name": "One with Death",
			"slot": "R",
			"cooldown": 25.0,
			"effect": {
				"type": AbilityPipeline.EffectType.BUFF,
				"duration": 8.0
			},
			"riders": [
				{"type": AbilityPipeline.RiderType.SPEED_BOOST, "duration": 8.0, "intensity": 0.45},
				{"type": AbilityPipeline.RiderType.EMPOWER, "duration": 8.0}
			]
		},
		# Dash (SHIFT): Ethereal Dash
		{
			"id": "ethereal_dash",
			"name": "Ethereal Dash",
			"slot": "SHIFT",
			"cooldown": 5.0,
			"effect": {
				"type": AbilityPipeline.EffectType.DASH
			},
			"riders": [
				{"type": AbilityPipeline.RiderType.ETHEREAL, "duration": 0.45}
			]
		}
	])

	return data
