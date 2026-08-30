class_name DiveAbilities
extends RefCounted

static func get_abilities() -> Dictionary:
	var dict: Dictionary = {}

	# Primary Fire (LMB): Slash
	var lmb = AbilityPipeline.AbilityDefinition.new()
	lmb.id = "dive_slash"
	lmb.name = "Slash"
	lmb.slot_key = "LMB"
	lmb.cooldown = 0.45
	lmb.effect = AbilityPipeline.AbilityEffect.new()
	lmb.effect.effect_type = AbilityPipeline.EffectType.MELEE_STRIKE
	lmb.effect.windup_time = 0.18
	lmb.hitbox = AbilityPipeline.AbilityHitbox.new()
	lmb.hitbox.shape = AbilityPipeline.HitboxShape.SECTOR
	lmb.hitbox.radius = 3.4
	lmb.hitbox.angle_deg = 100.0
	lmb.hitbox.height = 2.4
	var r_dmg = AbilityPipeline.AbilityRider.new()
	r_dmg.rider_type = AbilityPipeline.RiderType.DAMAGE
	r_dmg.amount = 32.0
	lmb.riders.append(r_dmg)
	var r_mark = AbilityPipeline.AbilityRider.new()
	r_mark.rider_type = AbilityPipeline.RiderType.DIVE_MARK
	r_mark.duration = 3.5
	lmb.riders.append(r_mark)
	dict["LMB"] = lmb
	dict[lmb.id] = lmb

	# Ability 1 (RMB): Heavy Cleave
	var rmb = AbilityPipeline.AbilityDefinition.new()
	rmb.id = "dive_heavy_cleave"
	rmb.name = "Heavy Cleave"
	rmb.slot_key = "RMB"
	rmb.cooldown = 6.0
	rmb.effect = AbilityPipeline.AbilityEffect.new()
	rmb.effect.effect_type = AbilityPipeline.EffectType.MELEE_STRIKE
	rmb.effect.windup_time = 0.18
	rmb.hitbox = AbilityPipeline.AbilityHitbox.new()
	rmb.hitbox.shape = AbilityPipeline.HitboxShape.SECTOR
	rmb.hitbox.radius = 3.0
	rmb.hitbox.angle_deg = 135.0
	rmb.hitbox.height = 2.4
	var rmb_dmg = AbilityPipeline.AbilityRider.new()
	rmb_dmg.rider_type = AbilityPipeline.RiderType.DAMAGE
	rmb_dmg.amount = 65.0
	rmb.riders.append(rmb_dmg)
	var rmb_mark = AbilityPipeline.AbilityRider.new()
	rmb_mark.rider_type = AbilityPipeline.RiderType.DIVE_MARK
	rmb_mark.duration = 3.5
	rmb.riders.append(rmb_mark)
	dict["RMB"] = rmb
	dict[rmb.id] = rmb

	# Ability 2 (Q): Earth Tremor
	var q = AbilityPipeline.AbilityDefinition.new()
	q.id = "dive_earth_tremor"
	q.name = "Earth Tremor"
	q.slot_key = "Q"
	q.cooldown = 8.0
	q.effect = AbilityPipeline.AbilityEffect.new()
	q.effect.effect_type = AbilityPipeline.EffectType.PROJECTILE
	q.effect.speed = 28.0
	q.effect.max_range = 14.0
	q.effect.projectile_size = 1.5
	q.effect.pierces = true
	q.effect.windup_time = 0.35
	q.hitbox = AbilityPipeline.AbilityHitbox.new()
	q.hitbox.shape = AbilityPipeline.HitboxShape.LINE
	q.hitbox.length = 14.0
	q.hitbox.width = 1.5
	var q_dmg = AbilityPipeline.AbilityRider.new()
	q_dmg.rider_type = AbilityPipeline.RiderType.DAMAGE
	q_dmg.amount = 18.0
	q.riders.append(q_dmg)
	var q_slow = AbilityPipeline.AbilityRider.new()
	q_slow.rider_type = AbilityPipeline.RiderType.SLOW
	q_slow.duration = 2.0
	q_slow.intensity = 0.40
	q.riders.append(q_slow)
	var q_terr = AbilityPipeline.AbilityRider.new()
	q_terr.rider_type = AbilityPipeline.RiderType.SPAWN_TERRAIN
	q_terr.duration = 5.0
	q.riders.append(q_terr)
	dict["Q"] = q
	dict[q.id] = q

	# Ability 3 (E): Deflecting Guard
	var e = AbilityPipeline.AbilityDefinition.new()
	e.id = "dive_deflecting_guard"
	e.name = "Deflecting Guard"
	e.slot_key = "E"
	e.cooldown = 10.0
	e.effect = AbilityPipeline.AbilityEffect.new()
	e.effect.effect_type = AbilityPipeline.EffectType.STANCE_BLOCK
	e.effect.duration = 1.75
	dict["E"] = e
	dict[e.id] = e

	# Ultimate (R): Tectonic Uprising
	var r = AbilityPipeline.AbilityDefinition.new()
	r.id = "dive_tectonic_uprising"
	r.name = "Tectonic Uprising"
	r.slot_key = "R"
	r.cooldown = 24.0
	r.can_cast_while_stunned = true
	r.effect = AbilityPipeline.AbilityEffect.new()
	r.effect.effect_type = AbilityPipeline.EffectType.BUFF
	r.effect.duration = 6.0
	dict["R"] = r
	dict[r.id] = r

	# Dash & Aerial Crash (SHIFT)
	var dash = AbilityPipeline.AbilityDefinition.new()
	dash.id = "dive_dash_or_crash"
	dash.name = "Dash / Crash"
	dash.slot_key = "SHIFT"
	dash.charges = 2
	dash.recharge_time = 5.0
	dash.cooldown = 0.85
	dict["SHIFT"] = dash
	dict[dash.id] = dash

	return dict
