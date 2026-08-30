class_name ReaperAbilities
extends RefCounted

static func get_abilities() -> Dictionary:
	var dict: Dictionary = {}

	# Primary Fire (LMB): Reaper's Scythe
	var lmb = AbilityPipeline.AbilityDefinition.new()
	lmb.id = "reaper_slash"
	lmb.name = "Reaper's Scythe"
	lmb.slot_key = "LMB"
	lmb.cooldown = 0.45
	lmb.effect = AbilityPipeline.AbilityEffect.new()
	lmb.effect.effect_type = AbilityPipeline.EffectType.MELEE_STRIKE
	lmb.effect.windup_time = 0.18
	lmb.hitbox = AbilityPipeline.AbilityHitbox.new()
	lmb.hitbox.shape = AbilityPipeline.HitboxShape.SECTOR
	lmb.hitbox.radius = 3.6
	lmb.hitbox.angle_deg = 110.0
	lmb.hitbox.height = 2.4
	var r_dmg = AbilityPipeline.AbilityRider.new()
	r_dmg.rider_type = AbilityPipeline.RiderType.DAMAGE
	r_dmg.amount = 36.0
	lmb.riders.append(r_dmg)
	var r_steal = AbilityPipeline.AbilityRider.new()
	r_steal.rider_type = AbilityPipeline.RiderType.MS_STEAL
	r_steal.duration = 2.5
	r_steal.intensity = 0.15
	lmb.riders.append(r_steal)
	dict["LMB"] = lmb
	dict[lmb.id] = lmb

	# Ability 1 (RMB): Spectral Tether
	var rmb = AbilityPipeline.AbilityDefinition.new()
	rmb.id = "reaper_tether"
	rmb.name = "Spectral Tether"
	rmb.slot_key = "RMB"
	rmb.cooldown = 7.0
	rmb.effect = AbilityPipeline.AbilityEffect.new()
	rmb.effect.effect_type = AbilityPipeline.EffectType.PROJECTILE
	rmb.effect.speed = 52.0
	rmb.effect.max_range = 24.0
	rmb.effect.projectile_size = 0.6
	rmb.hitbox = AbilityPipeline.AbilityHitbox.new()
	rmb.hitbox.shape = AbilityPipeline.HitboxShape.LINE
	rmb.hitbox.length = 24.0
	rmb.hitbox.width = 0.8
	var rmb_dmg = AbilityPipeline.AbilityRider.new()
	rmb_dmg.rider_type = AbilityPipeline.RiderType.DAMAGE
	rmb_dmg.amount = 25.0
	rmb.riders.append(rmb_dmg)
	var rmb_tether = AbilityPipeline.AbilityRider.new()
	rmb_tether.rider_type = AbilityPipeline.RiderType.TETHER
	rmb_tether.duration = 1.75
	rmb.riders.append(rmb_tether)
	dict["RMB"] = rmb
	dict[rmb.id] = rmb

	# Ability 2 (Q): Cull the Weak
	var q = AbilityPipeline.AbilityDefinition.new()
	q.id = "reaper_cull_the_weak"
	q.name = "Cull the Weak"
	q.slot_key = "Q"
	q.cooldown = 7.5
	q.effect = AbilityPipeline.AbilityEffect.new()
	q.effect.effect_type = AbilityPipeline.EffectType.AREA_ZONE
	q.effect.windup_time = 0.75
	q.hitbox = AbilityPipeline.AbilityHitbox.new()
	q.hitbox.shape = AbilityPipeline.HitboxShape.DONUT
	q.hitbox.radius = 5.5
	q.hitbox.width = 3.2
	q.hitbox.height = 2.4
	var q_outer_dmg = AbilityPipeline.AbilityRider.new()
	q_outer_dmg.rider_type = AbilityPipeline.RiderType.DAMAGE
	q_outer_dmg.amount = 65.0
	q.riders.append(q_outer_dmg)
	var q_cripple = AbilityPipeline.AbilityRider.new()
	q_cripple.rider_type = AbilityPipeline.RiderType.CRIPPLE
	q_cripple.duration = 2.5
	q_cripple.intensity = 0.35
	q.riders.append(q_cripple)
	dict["Q"] = q
	dict[q.id] = q

	# Ability 3 (E): Nightmare
	var e = AbilityPipeline.AbilityDefinition.new()
	e.id = "reaper_nightmare"
	e.name = "Nightmare"
	e.slot_key = "E"
	e.cooldown = 12.0
	e.effect = AbilityPipeline.AbilityEffect.new()
	e.effect.effect_type = AbilityPipeline.EffectType.BUFF
	e.effect.duration = 1.8
	e.hitbox = AbilityPipeline.AbilityHitbox.new()
	e.hitbox.shape = AbilityPipeline.HitboxShape.CIRCLE
	e.hitbox.radius = 4.5
	var e_dmg = AbilityPipeline.AbilityRider.new()
	e_dmg.rider_type = AbilityPipeline.RiderType.DAMAGE
	e_dmg.amount = 35.0
	e.riders.append(e_dmg)
	var e_slow = AbilityPipeline.AbilityRider.new()
	e_slow.rider_type = AbilityPipeline.RiderType.SLOW
	e_slow.duration = 1.8
	e_slow.intensity = 0.40
	e.riders.append(e_slow)
	var e_eth = AbilityPipeline.AbilityRider.new()
	e_eth.rider_type = AbilityPipeline.RiderType.ETHEREAL
	e_eth.duration = 1.8
	e.riders.append(e_eth)
	dict["E"] = e
	dict[e.id] = e

	# Ultimate (R): One with Death
	var r = AbilityPipeline.AbilityDefinition.new()
	r.id = "reaper_one_with_death"
	r.name = "One with Death"
	r.slot_key = "R"
	r.cooldown = 25.0
	r.effect = AbilityPipeline.AbilityEffect.new()
	r.effect.effect_type = AbilityPipeline.EffectType.BUFF
	r.effect.duration = 8.0
	var r_ms = AbilityPipeline.AbilityRider.new()
	r_ms.rider_type = AbilityPipeline.RiderType.SPEED_BOOST
	r_ms.duration = 8.0
	r_ms.intensity = 0.45
	r.riders.append(r_ms)
	var r_emp = AbilityPipeline.AbilityRider.new()
	r_emp.rider_type = AbilityPipeline.RiderType.EMPOWER
	r_emp.duration = 8.0
	r.riders.append(r_emp)
	dict["R"] = r
	dict[r.id] = r

	# Dash (SHIFT): Ethereal Dash
	var dash = AbilityPipeline.AbilityDefinition.new()
	dash.id = "ethereal_dash"
	dash.name = "Ethereal Dash"
	dash.slot_key = "SHIFT"
	dash.cooldown = 5.0
	dash.effect = AbilityPipeline.AbilityEffect.new()
	dash.effect.effect_type = AbilityPipeline.EffectType.DASH
	var dash_eth = AbilityPipeline.AbilityRider.new()
	dash_eth.rider_type = AbilityPipeline.RiderType.ETHEREAL
	dash_eth.duration = 0.45
	dash.riders.append(dash_eth)
	dict["SHIFT"] = dash
	dict[dash.id] = dash

	return dict
