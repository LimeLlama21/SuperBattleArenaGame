class_name MorriganAbilities
extends RefCounted

static func get_abilities() -> Dictionary:
	var dict: Dictionary = {}

	# Primary Fire (LMB): Black Plumage
	var lmb = AbilityPipeline.AbilityDefinition.new()
	lmb.id = "morrigan_black_plumage"
	lmb.name = "Black Plumage"
	lmb.slot_key = "LMB"
	lmb.cooldown = 0.25
	lmb.effect = AbilityPipeline.AbilityEffect.new()
	lmb.effect.effect_type = AbilityPipeline.EffectType.PROJECTILE
	lmb.effect.speed = 70.0
	lmb.effect.max_range = 35.0
	lmb.effect.chargeable = true
	lmb.hitbox = AbilityPipeline.AbilityHitbox.new()
	lmb.hitbox.shape = AbilityPipeline.HitboxShape.LINE
	lmb.hitbox.length = 35.0
	lmb.hitbox.width = 0.4
	var lmb_dmg = AbilityPipeline.AbilityRider.new()
	lmb_dmg.rider_type = AbilityPipeline.RiderType.DAMAGE
	lmb_dmg.amount = 14.0
	lmb.riders.append(lmb_dmg)
	dict["LMB"] = lmb
	dict[lmb.id] = lmb

	# Ability 1 (RMB): Omen of Death
	var rmb = AbilityPipeline.AbilityDefinition.new()
	rmb.id = "morrigan_omen_of_death"
	rmb.name = "Omen of Death"
	rmb.slot_key = "RMB"
	rmb.charges = 2
	rmb.recharge_time = 6.5
	rmb.cooldown = 0.8
	rmb.effect = AbilityPipeline.AbilityEffect.new()
	rmb.effect.effect_type = AbilityPipeline.EffectType.PROJECTILE
	rmb.effect.speed = 24.0
	rmb.effect.max_range = 22.0
	rmb.effect.chargeable = true
	rmb.hitbox = AbilityPipeline.AbilityHitbox.new()
	rmb.hitbox.shape = AbilityPipeline.HitboxShape.CIRCLE
	rmb.hitbox.radius = 3.2
	var rmb_dmg = AbilityPipeline.AbilityRider.new()
	rmb_dmg.rider_type = AbilityPipeline.RiderType.DAMAGE
	rmb_dmg.amount = 45.0
	rmb.riders.append(rmb_dmg)
	dict["RMB"] = rmb
	dict[rmb.id] = rmb

	# Ability 2 (Q): Inescapable Ends
	var q = AbilityPipeline.AbilityDefinition.new()
	q.id = "morrigan_inescapable_ends"
	q.name = "Inescapable Ends"
	q.slot_key = "Q"
	q.cooldown = 9.0
	q.effect = AbilityPipeline.AbilityEffect.new()
	q.effect.effect_type = AbilityPipeline.EffectType.PROJECTILE
	q.effect.speed = 45.0
	q.effect.max_range = 15.0
	q.hitbox = AbilityPipeline.AbilityHitbox.new()
	q.hitbox.shape = AbilityPipeline.HitboxShape.LINE
	q.hitbox.length = 15.0
	q.hitbox.width = 0.6
	var q_tether = AbilityPipeline.AbilityRider.new()
	q_tether.rider_type = AbilityPipeline.RiderType.TETHER
	q_tether.duration = 3.0
	q.riders.append(q_tether)
	dict["Q"] = q
	dict[q.id] = q

	# Ability 3 (E): Cry of the Banshee
	var e = AbilityPipeline.AbilityDefinition.new()
	e.id = "morrigan_banshee_cry"
	e.name = "Cry of the Banshee"
	e.slot_key = "E"
	e.cooldown = 14.0
	e.effect = AbilityPipeline.AbilityEffect.new()
	e.effect.effect_type = AbilityPipeline.EffectType.MELEE_STRIKE
	e.effect.windup_time = 0.2
	e.hitbox = AbilityPipeline.AbilityHitbox.new()
	e.hitbox.shape = AbilityPipeline.HitboxShape.SECTOR
	e.hitbox.radius = 7.5
	e.hitbox.angle_deg = 85.0
	e.hitbox.height = 2.6
	var e_dmg = AbilityPipeline.AbilityRider.new()
	e_dmg.rider_type = AbilityPipeline.RiderType.DAMAGE
	e_dmg.amount = 38.0
	e.riders.append(e_dmg)
	var e_silence = AbilityPipeline.AbilityRider.new()
	e_silence.rider_type = AbilityPipeline.RiderType.STUN # Or Silence handled in script
	e_silence.duration = 1.4
	e.riders.append(e_silence)
	dict["E"] = e
	dict[e.id] = e

	# Ultimate (R): Born of Blood, Return to Blood
	var r = AbilityPipeline.AbilityDefinition.new()
	r.id = "morrigan_born_of_blood"
	r.name = "Born of Blood"
	r.slot_key = "R"
	r.cooldown = 30.0
	r.effect = AbilityPipeline.AbilityEffect.new()
	r.effect.effect_type = AbilityPipeline.EffectType.CHANNEL
	r.effect.duration = 1.0
	r.hitbox = AbilityPipeline.AbilityHitbox.new()
	r.hitbox.shape = AbilityPipeline.HitboxShape.BOX
	r.hitbox.length = 45.0
	r.hitbox.width = 12.0
	r.hitbox.height = 3.2
	var r_dmg = AbilityPipeline.AbilityRider.new()
	r_dmg.rider_type = AbilityPipeline.RiderType.DAMAGE
	r_dmg.amount = 80.0
	r.riders.append(r_dmg)
	var r_stun = AbilityPipeline.AbilityRider.new()
	r_stun.rider_type = AbilityPipeline.RiderType.STUN
	r_stun.duration = 1.2
	r.riders.append(r_stun)
	dict["R"] = r
	dict[r.id] = r

	# Dash (SHIFT): Crowstorm
	var dash = AbilityPipeline.AbilityDefinition.new()
	dash.id = "morrigan_crowstorm"
	dash.name = "Crowstorm"
	dash.slot_key = "SHIFT"
	dash.cooldown = 6.0
	dash.effect = AbilityPipeline.AbilityEffect.new()
	dash.effect.effect_type = AbilityPipeline.EffectType.BUFF
	dash.effect.duration = 1.4
	dict["SHIFT"] = dash
	dict[dash.id] = dash

	return dict
