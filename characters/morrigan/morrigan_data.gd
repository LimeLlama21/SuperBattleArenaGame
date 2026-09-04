class_name MorriganData
extends RefCounted

static func create() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "Murder"
	data.display_name = "Morrigan"
	data.archetype = "Mage"
	data.max_health = 180.0
	data.max_move_speed = 9.5
	data.ground_acceleration = 65.0
	data.ground_friction = 40.0
	data.air_acceleration = 8.0
	data.air_drag = 3.5
	data.jump_velocity = 9.5
	data.ability_slots = {
		"LMB": "morrigan_black_plumage",
		"RMB": "morrigan_omen_of_death",
		"Q": "morrigan_inescapable_ends",
		"E": "morrigan_banshee_cry",
		"R": "morrigan_born_of_blood",
		"SHIFT": "morrigan_crowstorm"
	}
	data.passive_data = {
		"max_crows": 3,
		"crow_detect_radius": 7.0,
		"crow_damage": 20.0,
		"crow_slow_percent": 0.35,
		"crow_slow_duration": 1.8,
		"dash_duration": 2.0,
		"dash_ms_mult": 0.60,
		"dash_dr_percent": 0.50,
		"dash_cooldown": 6.0,
		"lmb_max_charges": 5,
		"lmb_first_charge_time": 0.35,
		"lmb_subsequent_charge_time": 0.18,
		"lmb_damage_per_feather": 14.0,
		"mortar_charges": 1,
		"mortar_recharge_time": 6.0,
		"mortar_damage": 20.0,
		"mortar_speed": 38.0,
		"mortar_radius": 3.2,
		"mortar_min_range": 5.0,
		"mortar_max_range": 22.0,
		"tether_range": 15.0,
		"tether_duration": 3.0,
		"tether_pull_accel": 32.0,
		"banshee_damage": 38.0,
		"banshee_silence_duration": 1.4,
		"banshee_radius": 7.5,
		"banshee_height": 2.6,
		"banshee_angle_deg": 85.0,
		"ult_channel_time": 1.0,
		"ult_damage": 80.0,
		"ult_stun_duration": 1.2,
		"ult_range": 45.0
	}

	data.define_abilities([
		# Primary Fire (LMB): Black Plumage
		{
			"id": "morrigan_black_plumage",
			"name": "Black Plumage",
			"icon": "🪶",
			"description": "Fires a rapid stream of necrotic black feathers dealing 9 damage and applying lingering decay to targets.",
			"slot": "LMB",
			"cooldown": 0.25,
			"effect": {
				"type": AbilityPipeline.EffectType.PROJECTILE,
				"speed": 70.0,
				"range": 35.0,
				"chargeable": true
			},
			"hitbox": {
				"shape": AbilityPipeline.HitboxShape.LINE,
				"length": 35.0,
				"width": 0.4
			},
			"riders": [
				{"type": AbilityPipeline.RiderType.DAMAGE, "amount": 9.0}
			]
		},
		# Ability 1 (RMB): Omen of Death
		{
			"id": "morrigan_omen_of_death",
			"name": "Omen of Death",
			"icon": "💣",
			"description": "Lobs a necrotic mortar shell over obstacles that explodes into an area-denial pool dealing 20 damage and slowing enemies.",
			"slot": "RMB",
			"charges": 1,
			"recharge_time": 6.0,
			"cooldown": 6.0,
			"effect": {
				"type": AbilityPipeline.EffectType.PROJECTILE,
				"speed": 38.0,
				"range": 22.0,
				"chargeable": true
			},
			"hitbox": {
				"shape": AbilityPipeline.HitboxShape.CIRCLE,
				"radius": 3.2
			},
			"riders": [
				{"type": AbilityPipeline.RiderType.DAMAGE, "amount": 20.0}
			]
		},
		# Ability 2 (Q): Inescapable Ends
		{
			"id": "morrigan_inescapable_ends",
			"name": "Inescapable Ends",
			"icon": "🕸",
			"description": "Fires a soul-siphoning tether that attaches to an enemy or terrain. Recast to yank the target towards Morrigan or pull Morrigan to the anchor.",
			"slot": "Q",
			"cooldown": 9.0,
			"effect": {
				"type": AbilityPipeline.EffectType.PROJECTILE,
				"speed": 45.0,
				"range": 15.0
			},
			"hitbox": {
				"shape": AbilityPipeline.HitboxShape.LINE,
				"length": 15.0,
				"width": 0.6
			},
			"riders": [
				{"type": AbilityPipeline.RiderType.TETHER, "duration": 3.0}
			]
		},
		# Ability 3 (E): Cry of the Banshee
		{
			"id": "morrigan_banshee_cry",
			"name": "Cry of the Banshee",
			"icon": "🗣",
			"description": "Unleashes a blood-curdling sonic scream in an 85-degree arc, silencing and stunning foes for 1.4s while dealing 24 damage.",
			"slot": "E",
			"cooldown": 14.0,
			"effect": {
				"type": AbilityPipeline.EffectType.MELEE_STRIKE,
				"windup": 0.2
			},
			"hitbox": {
				"shape": AbilityPipeline.HitboxShape.SECTOR,
				"radius": 7.5,
				"angle": 85.0,
				"height": 2.6
			},
			"riders": [
				{"type": AbilityPipeline.RiderType.DAMAGE, "amount": 24.0},
				{"type": AbilityPipeline.RiderType.STUN, "duration": 1.4}
			]
		},
		# Ultimate (R): Born of Blood, Return to Blood
		{
			"id": "morrigan_born_of_blood",
			"name": "Born of Blood",
			"icon": "🩸",
			"description": "Channels a blood deluge for 1.0s, unleashing a colossal 45m tidal surge that crashes over all obstacles, stunning for 1.2s and dealing 50 damage.",
			"slot": "R",
			"cooldown": 30.0,
			"effect": {
				"type": AbilityPipeline.EffectType.CHANNEL,
				"duration": 1.0
			},
			"hitbox": {
				"shape": AbilityPipeline.HitboxShape.BOX,
				"length": 45.0,
				"width": 12.0,
				"height": 3.2
			},
			"riders": [
				{"type": AbilityPipeline.RiderType.DAMAGE, "amount": 50.0},
				{"type": AbilityPipeline.RiderType.STUN, "duration": 1.2}
			]
		},
		# Dash (SHIFT): Crowstorm
		{
			"id": "morrigan_crowstorm",
			"name": "Crowstorm",
			"icon": "🦅",
			"description": "Transforms into an agile flock of crows, granting unrestricted high-speed flight and steerable momentum.",
			"slot": "SHIFT",
			"cooldown": 6.0,
			"effect": {
				"type": AbilityPipeline.EffectType.BUFF,
				"duration": 2.0
			}
		}
	])

	return data
