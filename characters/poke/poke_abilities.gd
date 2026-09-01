class_name PokeAbilities
extends RefCounted

static func get_abilities() -> Dictionary:
	var dict: Dictionary = {}
	
	# Primary Fire (LMB): Rail Shot
	var lmb = AbilityPipeline.AbilityDefinition.new()
	lmb.id = "poke_rail_shot"
	lmb.name = "Rail Shot"
	lmb.slot_key = "LMB"
	lmb.cooldown = 0.6
	lmb.effect = AbilityPipeline.AbilityEffect.new()
	lmb.effect.effect_type = AbilityPipeline.EffectType.PROJECTILE
	lmb.effect.speed = 90.0
	lmb.effect.max_range = 50.0
	lmb.effect.projectile_size = 0.35
	lmb.hitbox = AbilityPipeline.AbilityHitbox.new()
	lmb.hitbox.shape = AbilityPipeline.HitboxShape.LINE
	lmb.hitbox.length = 50.0
	lmb.hitbox.width = 0.35
	var lmb_dmg = AbilityPipeline.AbilityRider.new()
	lmb_dmg.rider_type = AbilityPipeline.RiderType.DAMAGE
	lmb_dmg.amount = 20.0
	lmb.riders.append(lmb_dmg)
	var r_fleet = AbilityPipeline.AbilityRider.new()
	r_fleet.rider_type = AbilityPipeline.RiderType.SPEED_BOOST
	r_fleet.duration = 2.5
	r_fleet.intensity = 0.15
	lmb.riders.append(r_fleet)
	dict["LMB"] = lmb
	dict[lmb.id] = lmb

	# Ability 1 (RMB): Repulsor Bolt
	var rmb = AbilityPipeline.AbilityDefinition.new()
	rmb.id = "poke_repulsor_bolt"
	rmb.name = "Repulsor Bolt"
	rmb.slot_key = "RMB"
	rmb.cooldown = 6.5
	rmb.effect = AbilityPipeline.AbilityEffect.new()
	rmb.effect.effect_type = AbilityPipeline.EffectType.PROJECTILE
	rmb.effect.speed = 85.0
	rmb.effect.max_range = 60.0
	rmb.effect.projectile_size = 0.35
	rmb.hitbox = AbilityPipeline.AbilityHitbox.new()
	rmb.hitbox.shape = AbilityPipeline.HitboxShape.LINE
	rmb.hitbox.length = 60.0
	rmb.hitbox.width = 0.7
	var rmb_dmg = AbilityPipeline.AbilityRider.new()
	rmb_dmg.rider_type = AbilityPipeline.RiderType.DAMAGE
	rmb_dmg.amount = 0.0
	rmb.riders.append(rmb_dmg)
	var rmb_kb = AbilityPipeline.AbilityRider.new()
	rmb_kb.rider_type = AbilityPipeline.RiderType.KNOCKBACK
	rmb_kb.amount = 36.0
	rmb.riders.append(rmb_kb)
	var rmb_stun = AbilityPipeline.AbilityRider.new()
	rmb_stun.rider_type = AbilityPipeline.RiderType.STUN
	rmb_stun.duration = 1.0
	rmb.riders.append(rmb_stun)
	dict["RMB"] = rmb
	dict[rmb.id] = rmb

	# Ability 2 (Q): Ion Fence
	var q = AbilityPipeline.AbilityDefinition.new()
	q.id = "poke_ion_fence"
	q.name = "Ion Fence"
	q.slot_key = "Q"
	q.cooldown = 8.0
	q.effect = AbilityPipeline.AbilityEffect.new()
	q.effect.effect_type = AbilityPipeline.EffectType.AREA_ZONE
	q.effect.max_range = 6.5
	q.effect.duration = 6.0
	q.hitbox = AbilityPipeline.AbilityHitbox.new()
	q.hitbox.shape = AbilityPipeline.HitboxShape.LINE
	q.hitbox.length = 8.0
	q.hitbox.width = 0.25
	q.hitbox.height = 2.6
	var q_ground = AbilityPipeline.AbilityRider.new()
	q_ground.rider_type = AbilityPipeline.RiderType.GROUND
	q_ground.duration = 2.5
	q.riders.append(q_ground)
	var q_slow = AbilityPipeline.AbilityRider.new()
	q_slow.rider_type = AbilityPipeline.RiderType.SLOW
	q_slow.duration = 1.5
	q_slow.intensity = 0.70
	q.riders.append(q_slow)
	dict["Q"] = q
	dict[q.id] = q

	# Ability 3 (E): Recon Flare
	var e = AbilityPipeline.AbilityDefinition.new()
	e.id = "poke_recon_flare"
	e.name = "Recon Flare"
	e.slot_key = "E"
	e.cooldown = 11.0
	e.effect = AbilityPipeline.AbilityEffect.new()
	e.effect.effect_type = AbilityPipeline.EffectType.PROJECTILE
	e.effect.speed = 45.0
	e.effect.max_range = 65.0
	e.effect.projectile_size = 0.8
	e.hitbox = AbilityPipeline.AbilityHitbox.new()
	e.hitbox.shape = AbilityPipeline.HitboxShape.CIRCLE
	e.hitbox.radius = 12.0
	var e_reveal = AbilityPipeline.AbilityRider.new()
	e_reveal.rider_type = AbilityPipeline.RiderType.VISION_REVEAL
	e_reveal.duration = 5.0
	e_reveal.amount = 12.0
	e.riders.append(e_reveal)
	dict["E"] = e
	dict[e.id] = e

	# Ultimate (R): Overcharge
	var r = AbilityPipeline.AbilityDefinition.new()
	r.id = "poke_overcharge"
	r.name = "Overcharge"
	r.slot_key = "R"
	r.cooldown = 24.0
	r.effect = AbilityPipeline.AbilityEffect.new()
	r.effect.effect_type = AbilityPipeline.EffectType.PROJECTILE
	r.effect.speed = 110.0
	r.effect.max_range = 95.0
	r.effect.projectile_size = 1.3
	r.hitbox = AbilityPipeline.AbilityHitbox.new()
	r.hitbox.shape = AbilityPipeline.HitboxShape.LINE
	r.hitbox.length = 95.0
	r.hitbox.width = 1.3
	var ult_dmg = AbilityPipeline.AbilityRider.new()
	ult_dmg.rider_type = AbilityPipeline.RiderType.DAMAGE
	ult_dmg.amount = 50.0
	r.riders.append(ult_dmg)
	dict["R"] = r
	dict[r.id] = r

	# Dash (SHIFT): Poke Dash
	var dash = AbilityPipeline.AbilityDefinition.new()
	dash.id = "poke_dash"
	dash.name = "Dash"
	dash.slot_key = "SHIFT"
	dash.cooldown = 4.0
	dash.effect = AbilityPipeline.AbilityEffect.new()
	dash.effect.effect_type = AbilityPipeline.EffectType.DASH
	dict["SHIFT"] = dash
	dict[dash.id] = dash

	return dict
