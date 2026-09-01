class_name CrushAbilities
extends RefCounted

static func get_abilities() -> Dictionary:
	var dict: Dictionary = {}

	# Primary Fire (LMB): Slam
	var lmb = AbilityPipeline.AbilityDefinition.new()
	lmb.id = "crush_slam"
	lmb.name = "Slam"
	lmb.slot_key = "LMB"
	lmb.cooldown = 0.65
	lmb.effect = AbilityPipeline.AbilityEffect.new()
	lmb.effect.effect_type = AbilityPipeline.EffectType.MELEE_STRIKE
	lmb.effect.windup_time = 0.28
	lmb.hitbox = AbilityPipeline.AbilityHitbox.new()
	lmb.hitbox.shape = AbilityPipeline.HitboxShape.SECTOR
	lmb.hitbox.radius = 4.2
	lmb.hitbox.angle_deg = 120.0
	lmb.hitbox.height = 2.4
	var r_dmg = AbilityPipeline.AbilityRider.new()
	r_dmg.rider_type = AbilityPipeline.RiderType.DAMAGE
	r_dmg.amount = 40.0
	lmb.riders.append(r_dmg)
	dict["LMB"] = lmb
	dict[lmb.id] = lmb

	# Ability 1 (RMB): Fan Stun
	var rmb = AbilityPipeline.AbilityDefinition.new()
	rmb.id = "crush_fan_stun"
	rmb.name = "Fan Stun"
	rmb.slot_key = "RMB"
	rmb.cooldown = 7.5
	rmb.effect = AbilityPipeline.AbilityEffect.new()
	rmb.effect.effect_type = AbilityPipeline.EffectType.MELEE_STRIKE
	rmb.effect.windup_time = 0.16
	rmb.hitbox = AbilityPipeline.AbilityHitbox.new()
	rmb.hitbox.shape = AbilityPipeline.HitboxShape.SECTOR
	rmb.hitbox.radius = 5.2
	rmb.hitbox.angle_deg = 100.0
	rmb.hitbox.height = 2.4
	var rmb_dmg = AbilityPipeline.AbilityRider.new()
	rmb_dmg.rider_type = AbilityPipeline.RiderType.DAMAGE
	rmb_dmg.amount = 25.0
	rmb.riders.append(rmb_dmg)
	var rmb_stun = AbilityPipeline.AbilityRider.new()
	rmb_stun.rider_type = AbilityPipeline.RiderType.STUN
	rmb_stun.duration = 0.8
	rmb.riders.append(rmb_stun)
	var rmb_emp = AbilityPipeline.AbilityRider.new()
	rmb_emp.rider_type = AbilityPipeline.RiderType.EMPOWER
	rmb.riders.append(rmb_emp)
	dict["RMB"] = rmb
	dict[rmb.id] = rmb

	# Ability 2 (Q): Ground Stomp
	var q = AbilityPipeline.AbilityDefinition.new()
	q.id = "crush_ground_stomp"
	q.name = "Ground Stomp"
	q.slot_key = "Q"
	q.cooldown = 8.0
	q.effect = AbilityPipeline.AbilityEffect.new()
	q.effect.effect_type = AbilityPipeline.EffectType.AREA_ZONE
	q.effect.windup_time = 0.30
	q.hitbox = AbilityPipeline.AbilityHitbox.new()
	q.hitbox.shape = AbilityPipeline.HitboxShape.CYLINDER
	q.hitbox.radius = 6.5
	q.hitbox.height = 2.4
	var q_dmg = AbilityPipeline.AbilityRider.new()
	q_dmg.rider_type = AbilityPipeline.RiderType.DAMAGE
	q_dmg.amount = 20.0
	q.riders.append(q_dmg)
	var q_slow = AbilityPipeline.AbilityRider.new()
	q_slow.rider_type = AbilityPipeline.RiderType.SLOW
	q_slow.duration = 2.5
	q_slow.intensity = 0.30
	q.riders.append(q_slow)
	var q_shld = AbilityPipeline.AbilityRider.new()
	q_shld.rider_type = AbilityPipeline.RiderType.SHIELD
	q_shld.amount = 40.0
	q_shld.duration = 5.0
	q.riders.append(q_shld)
	dict["Q"] = q
	dict[q.id] = q

	# Ability 3 (E): Iron Barrier
	var e = AbilityPipeline.AbilityDefinition.new()
	e.id = "crush_iron_barrier"
	e.name = "Iron Barrier"
	e.slot_key = "E"
	e.cooldown = 10.0
	e.effect = AbilityPipeline.AbilityEffect.new()
	e.effect.effect_type = AbilityPipeline.EffectType.BUFF
	e.effect.duration = 5.0
	var e_shld = AbilityPipeline.AbilityRider.new()
	e_shld.rider_type = AbilityPipeline.RiderType.SHIELD
	e_shld.amount = 50.0
	e_shld.duration = 5.0
	e.riders.append(e_shld)
	dict["E"] = e
	dict[e.id] = e

	# Ultimate (R): Juggernaut Charge
	var r = AbilityPipeline.AbilityDefinition.new()
	r.id = "crush_juggernaut_charge"
	r.name = "Juggernaut Charge"
	r.slot_key = "R"
	r.cooldown = 26.0
	r.effect = AbilityPipeline.AbilityEffect.new()
	r.effect.effect_type = AbilityPipeline.EffectType.CHARGE_SLAM
	r.effect.speed = 28.0
	r.effect.duration = 1.0
	r.effect.windup_time = 0.45
	r.hitbox = AbilityPipeline.AbilityHitbox.new()
	r.hitbox.shape = AbilityPipeline.HitboxShape.CYLINDER
	r.hitbox.radius = 3.2
	r.hitbox.height = 3.0
	var r_slam_dmg = AbilityPipeline.AbilityRider.new()
	r_slam_dmg.rider_type = AbilityPipeline.RiderType.DAMAGE
	r_slam_dmg.amount = 120.0
	r.riders.append(r_slam_dmg)
	var r_stun = AbilityPipeline.AbilityRider.new()
	r_stun.rider_type = AbilityPipeline.RiderType.STUN
	r_stun.duration = 1.25
	r.riders.append(r_stun)
	var r_kb = AbilityPipeline.AbilityRider.new()
	r_kb.rider_type = AbilityPipeline.RiderType.KNOCKBACK
	r_kb.amount = 16.0
	r.riders.append(r_kb)
	dict["R"] = r
	dict[r.id] = r

	# Dash (SHIFT): Crush Dash
	var dash = AbilityPipeline.AbilityDefinition.new()
	dash.id = "crush_dash"
	dash.name = "Dash"
	dash.slot_key = "SHIFT"
	dash.cooldown = 8.0
	dash.effect = AbilityPipeline.AbilityEffect.new()
	dash.effect.effect_type = AbilityPipeline.EffectType.DASH
	dict["SHIFT"] = dash
	dict[dash.id] = dash

	return dict
