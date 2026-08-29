class_name AbilitiesLibrary
extends RefCounted

static var _registry: Dictionary = {}

static func _ensure_initialized() -> void:
	if not _registry.is_empty():
		return
	
	_register_poke_abilities()
	_register_dive_abilities()
	_register_crush_abilities()
	_register_reaper_abilities()
	_register_universal_abilities()

static func _register_poke_abilities() -> void:
	# Poke LMB: Rail Shot
	var lmb = AbilityPipeline.AbilityDefinition.new()
	lmb.id = "poke_rail_shot"
	lmb.name = "Rail Shot"
	lmb.slot_key = "LMB"
	lmb.cooldown = 0.9
	
	lmb.effect = AbilityPipeline.AbilityEffect.new()
	lmb.effect.effect_type = AbilityPipeline.EffectType.PROJECTILE
	lmb.effect.speed = 90.0
	lmb.effect.max_range = 50.0
	lmb.effect.projectile_size = 0.35
	
	lmb.hitbox = AbilityPipeline.AbilityHitbox.new()
	lmb.hitbox.shape = AbilityPipeline.HitboxShape.LINE
	lmb.hitbox.length = 50.0
	lmb.hitbox.width = 0.35
	
	var lmb_trigger = AbilityPipeline.AbilityTrigger.new()
	lmb_trigger.trigger_type = AbilityPipeline.TriggerType.ON_HIT_ENEMY
	lmb.triggers.append(lmb_trigger)
	
	var r_dmg = AbilityPipeline.AbilityRider.new()
	r_dmg.rider_type = AbilityPipeline.RiderType.DAMAGE
	r_dmg.amount = 18.0
	lmb.riders.append(r_dmg)
	
	var r_fleet = AbilityPipeline.AbilityRider.new()
	r_fleet.rider_type = AbilityPipeline.RiderType.SPEED_BOOST
	r_fleet.duration = 2.5
	r_fleet.intensity = 0.15
	lmb.riders.append(r_fleet)
	_registry[lmb.id] = lmb

	# Poke RMB: Repulsor Bolt
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
	
	var rmb_trigger = AbilityPipeline.AbilityTrigger.new()
	rmb_trigger.trigger_type = AbilityPipeline.TriggerType.ON_HIT_ENEMY
	rmb.triggers.append(rmb_trigger)
	
	var rmb_dmg = AbilityPipeline.AbilityRider.new()
	rmb_dmg.rider_type = AbilityPipeline.RiderType.DAMAGE
	rmb_dmg.amount = 20.0
	rmb.riders.append(rmb_dmg)
	
	var rmb_kb = AbilityPipeline.AbilityRider.new()
	rmb_kb.rider_type = AbilityPipeline.RiderType.KNOCKBACK
	rmb_kb.amount = 36.0 # Horizontal impulse
	rmb.riders.append(rmb_kb)
	
	var rmb_stun = AbilityPipeline.AbilityRider.new()
	rmb_stun.rider_type = AbilityPipeline.RiderType.STUN
	rmb_stun.duration = 1.0
	rmb.riders.append(rmb_stun)
	_registry[rmb.id] = rmb

	# Poke Q: Slipstream Field
	var q = AbilityPipeline.AbilityDefinition.new()
	q.id = "poke_slipstream_field"
	q.name = "Slipstream Field"
	q.slot_key = "Q"
	q.cooldown = 7.5
	
	q.effect = AbilityPipeline.AbilityEffect.new()
	q.effect.effect_type = AbilityPipeline.EffectType.AREA_ZONE
	q.effect.max_range = 6.0
	q.effect.duration = 4.5
	
	q.hitbox = AbilityPipeline.AbilityHitbox.new()
	q.hitbox.shape = AbilityPipeline.HitboxShape.CIRCLE
	q.hitbox.radius = 2.2
	
	var q_enter = AbilityPipeline.AbilityTrigger.new()
	q_enter.trigger_type = AbilityPipeline.TriggerType.ON_ENTER
	q.triggers.append(q_enter)
	
	var q_tick = AbilityPipeline.AbilityTrigger.new()
	q_tick.trigger_type = AbilityPipeline.TriggerType.ON_TICK
	q.triggers.append(q_tick)
	
	var q_ms = AbilityPipeline.AbilityRider.new()
	q_ms.rider_type = AbilityPipeline.RiderType.SPEED_BOOST
	q_ms.duration = 2.0
	q_ms.intensity = 0.30
	q.riders.append(q_ms)
	
	var q_slow = AbilityPipeline.AbilityRider.new()
	q_slow.rider_type = AbilityPipeline.RiderType.SLOW
	q_slow.duration = 1.5
	q_slow.intensity = 0.35
	q.riders.append(q_slow)
	_registry[q.id] = q

	# Poke E: Recon Flare
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
	
	var e_dest = AbilityPipeline.AbilityTrigger.new()
	e_dest.trigger_type = AbilityPipeline.TriggerType.ON_REACH_DESTINATION
	e.triggers.append(e_dest)
	
	var e_reveal = AbilityPipeline.AbilityRider.new()
	e_reveal.rider_type = AbilityPipeline.RiderType.VISION_REVEAL
	e_reveal.duration = 5.0
	e_reveal.amount = 12.0 # Radius
	e.riders.append(e_reveal)
	_registry[e.id] = e

	# Poke R: Overcharge
	var r = AbilityPipeline.AbilityDefinition.new()
	r.id = "poke_overcharge"
	r.name = "Overcharge"
	r.slot_key = "R"
	r.cooldown = 24.0
	
	r.effect = AbilityPipeline.AbilityEffect.new()
	r.effect.effect_type = AbilityPipeline.EffectType.BUFF
	r.effect.duration = 12.0
	r.hitbox = null # Skippable
	
	var r_cast = AbilityPipeline.AbilityTrigger.new()
	r_cast.trigger_type = AbilityPipeline.TriggerType.ON_CAST
	r.triggers.append(r_cast)
	
	var r_emp = AbilityPipeline.AbilityRider.new()
	r_emp.rider_type = AbilityPipeline.RiderType.EMPOWER
	r_emp.custom_params = {
		"empowered_range": 95.0,
		"empowered_speed": 95.0,
		"empowered_size": 1.3,
		"pierces": true,
		"execute_scaling": true
	}
	r.riders.append(r_emp)
	_registry[r.id] = r

static func _register_dive_abilities() -> void:
	# Dive LMB: Slash
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
	
	var lmb_trig = AbilityPipeline.AbilityTrigger.new()
	lmb_trig.trigger_type = AbilityPipeline.TriggerType.ON_HIT_ENEMY
	lmb.triggers.append(lmb_trig)
	
	var r_dmg = AbilityPipeline.AbilityRider.new()
	r_dmg.rider_type = AbilityPipeline.RiderType.DAMAGE
	r_dmg.amount = 32.0
	lmb.riders.append(r_dmg)
	
	var r_mark = AbilityPipeline.AbilityRider.new()
	r_mark.rider_type = AbilityPipeline.RiderType.DIVE_MARK
	r_mark.duration = 3.5
	lmb.riders.append(r_mark)
	_registry[lmb.id] = lmb

	# Dive RMB: Heavy Cleave
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
	
	var rmb_trig = AbilityPipeline.AbilityTrigger.new()
	rmb_trig.trigger_type = AbilityPipeline.TriggerType.ON_HIT_ENEMY
	rmb.triggers.append(rmb_trig)
	
	var rmb_dmg = AbilityPipeline.AbilityRider.new()
	rmb_dmg.rider_type = AbilityPipeline.RiderType.DAMAGE
	rmb_dmg.amount = 65.0
	rmb.riders.append(rmb_dmg)
	
	var rmb_mark = AbilityPipeline.AbilityRider.new()
	rmb_mark.rider_type = AbilityPipeline.RiderType.DIVE_MARK
	rmb_mark.duration = 3.5
	rmb.riders.append(rmb_mark)
	_registry[rmb.id] = rmb

	# Dive Q: Earth Tremor
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
	q.effect.windup_time = 0.35 # Channel delay
	
	q.hitbox = AbilityPipeline.AbilityHitbox.new()
	q.hitbox.shape = AbilityPipeline.HitboxShape.LINE
	q.hitbox.length = 14.0
	q.hitbox.width = 1.5
	
	var q_hit = AbilityPipeline.AbilityTrigger.new()
	q_hit.trigger_type = AbilityPipeline.TriggerType.ON_HIT_ENEMY
	q.triggers.append(q_hit)
	
	var q_exp = AbilityPipeline.AbilityTrigger.new()
	q_exp.trigger_type = AbilityPipeline.TriggerType.ON_EXPIRE
	q.triggers.append(q_exp)
	
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
	_registry[q.id] = q

	# Dive E: Deflecting Guard
	var e = AbilityPipeline.AbilityDefinition.new()
	e.id = "dive_deflecting_guard"
	e.name = "Deflecting Guard"
	e.slot_key = "E"
	e.cooldown = 10.0
	
	e.effect = AbilityPipeline.AbilityEffect.new()
	e.effect.effect_type = AbilityPipeline.EffectType.STANCE_BLOCK
	e.effect.duration = 1.75
	e.hitbox = null
	
	var e_cast = AbilityPipeline.AbilityTrigger.new()
	e_cast.trigger_type = AbilityPipeline.TriggerType.ON_CAST
	e.triggers.append(e_cast)
	
	var e_cleanse = AbilityPipeline.AbilityRider.new()
	e_cleanse.rider_type = AbilityPipeline.RiderType.CLEANSE
	e.riders.append(e_cleanse)
	_registry[e.id] = e

	# Dive R: Tectonic Uprising
	var r = AbilityPipeline.AbilityDefinition.new()
	r.id = "dive_tectonic_uprising"
	r.name = "Tectonic Uprising"
	r.slot_key = "R"
	r.cooldown = 24.0
	r.can_cast_while_stunned = true
	
	r.effect = AbilityPipeline.AbilityEffect.new()
	r.effect.effect_type = AbilityPipeline.EffectType.BUFF
	r.effect.duration = 6.0
	r.hitbox = null
	
	var r_cast = AbilityPipeline.AbilityTrigger.new()
	r_cast.trigger_type = AbilityPipeline.TriggerType.ON_CAST
	r.triggers.append(r_cast)
	
	var r_cleanse = AbilityPipeline.AbilityRider.new()
	r_cleanse.rider_type = AbilityPipeline.RiderType.CLEANSE
	r.riders.append(r_cleanse)
	
	var r_buff = AbilityPipeline.AbilityRider.new()
	r_buff.rider_type = AbilityPipeline.RiderType.SPEED_BOOST
	r_buff.duration = 6.0
	r_buff.intensity = 0.35 # 35% MS, 40% AS
	r.riders.append(r_buff)
	_registry[r.id] = r

	# Dive Crash Down
	var crash = AbilityPipeline.AbilityDefinition.new()
	crash.id = "dive_aerial_crash"
	crash.name = "Aerial Crash"
	crash.slot_key = "SHIFT"
	crash.cooldown = 0.0
	
	crash.effect = AbilityPipeline.AbilityEffect.new()
	crash.effect.effect_type = AbilityPipeline.EffectType.AERIAL_CRASH
	crash.effect.speed = 52.0
	
	crash.hitbox = AbilityPipeline.AbilityHitbox.new()
	crash.hitbox.shape = AbilityPipeline.HitboxShape.CIRCLE
	crash.hitbox.radius = 6.0
	crash.hitbox.height = 4.0
	
	var cr_trig = AbilityPipeline.AbilityTrigger.new()
	cr_trig.trigger_type = AbilityPipeline.TriggerType.ON_HIT_ENEMY
	crash.triggers.append(cr_trig)
	
	var cr_dmg = AbilityPipeline.AbilityRider.new()
	cr_dmg.rider_type = AbilityPipeline.RiderType.DAMAGE
	cr_dmg.amount = 48.0
	crash.riders.append(cr_dmg)
	_registry[crash.id] = crash

static func _register_crush_abilities() -> void:
	# Crush LMB: Slam
	var lmb = AbilityPipeline.AbilityDefinition.new()
	lmb.id = "crush_slam"
	lmb.name = "Slam"
	lmb.slot_key = "LMB"
	lmb.cooldown = 0.65
	
	lmb.effect = AbilityPipeline.AbilityEffect.new()
	lmb.effect.effect_type = AbilityPipeline.EffectType.MELEE_STRIKE
	lmb.effect.windup_time = 0.28
	
	lmb.hitbox = AbilityPipeline.AbilityHitbox.new()
	lmb.hitbox.shape = AbilityPipeline.HitboxShape.BOX
	lmb.hitbox.radius = 4.2
	lmb.hitbox.angle_deg = 120.0
	lmb.hitbox.height = 2.4
	
	var lmb_trig = AbilityPipeline.AbilityTrigger.new()
	lmb_trig.trigger_type = AbilityPipeline.TriggerType.ON_HIT_ENEMY
	lmb.triggers.append(lmb_trig)
	
	var r_dmg = AbilityPipeline.AbilityRider.new()
	r_dmg.rider_type = AbilityPipeline.RiderType.DAMAGE
	r_dmg.amount = 55.0
	lmb.riders.append(r_dmg)
	_registry[lmb.id] = lmb

	# Crush RMB: Fan Stun
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
	
	var rmb_trig = AbilityPipeline.AbilityTrigger.new()
	rmb_trig.trigger_type = AbilityPipeline.TriggerType.ON_HIT_ENEMY
	rmb.triggers.append(rmb_trig)
	
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
	_registry[rmb.id] = rmb

	# Crush Q: Ground Stomp
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
	
	var q_hit = AbilityPipeline.AbilityTrigger.new()
	q_hit.trigger_type = AbilityPipeline.TriggerType.ON_HIT_ENEMY
	q.triggers.append(q_hit)
	
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
	_registry[q.id] = q

	# Crush E: Iron Barrier
	var e = AbilityPipeline.AbilityDefinition.new()
	e.id = "crush_iron_barrier"
	e.name = "Iron Barrier"
	e.slot_key = "E"
	e.cooldown = 10.0
	
	e.effect = AbilityPipeline.AbilityEffect.new()
	e.effect.effect_type = AbilityPipeline.EffectType.BUFF
	e.effect.duration = 5.0
	e.hitbox = null
	
	var e_cast = AbilityPipeline.AbilityTrigger.new()
	e_cast.trigger_type = AbilityPipeline.TriggerType.ON_CAST
	e.triggers.append(e_cast)
	
	var e_shld = AbilityPipeline.AbilityRider.new()
	e_shld.rider_type = AbilityPipeline.RiderType.SHIELD
	e_shld.amount = 50.0
	e_shld.duration = 5.0
	e.riders.append(e_shld)
	_registry[e.id] = e

	# Crush R: Juggernaut Charge & Slam
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
	
	var r_hit = AbilityPipeline.AbilityTrigger.new()
	r_hit.trigger_type = AbilityPipeline.TriggerType.ON_HIT_ENEMY
	r.triggers.append(r_hit)
	
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
	r_kb.amount = 16.0 # Knockup
	r.riders.append(r_kb)
	_registry[r.id] = r

static func _register_reaper_abilities() -> void:
	# Reaper LMB: Reaper's Scythe (MS Steal on hit)
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
	
	var lmb_trig = AbilityPipeline.AbilityTrigger.new()
	lmb_trig.trigger_type = AbilityPipeline.TriggerType.ON_HIT_ENEMY
	lmb.triggers.append(lmb_trig)
	
	var r_dmg = AbilityPipeline.AbilityRider.new()
	r_dmg.rider_type = AbilityPipeline.RiderType.DAMAGE
	r_dmg.amount = 36.0
	lmb.riders.append(r_dmg)
	
	var r_steal = AbilityPipeline.AbilityRider.new()
	r_steal.rider_type = AbilityPipeline.RiderType.MS_STEAL
	r_steal.duration = 2.5
	r_steal.intensity = 0.15
	lmb.riders.append(r_steal)
	_registry[lmb.id] = lmb

	# Reaper RMB: Spectral Tether (Skillshot ground, ramp slow, root on completion)
	var rmb = AbilityPipeline.AbilityDefinition.new()
	rmb.id = "reaper_tether"
	rmb.name = "Spectral Tether"
	rmb.slot_key = "RMB"
	rmb.cooldown = 7.0
	
	rmb.effect = AbilityPipeline.AbilityEffect.new()
	rmb.effect.effect_type = AbilityPipeline.EffectType.PROJECTILE
	rmb.effect.speed = 48.0
	rmb.effect.max_range = 16.0
	rmb.effect.projectile_size = 0.6
	
	rmb.hitbox = AbilityPipeline.AbilityHitbox.new()
	rmb.hitbox.shape = AbilityPipeline.HitboxShape.LINE
	rmb.hitbox.length = 16.0
	rmb.hitbox.width = 0.8
	
	var rmb_trig = AbilityPipeline.AbilityTrigger.new()
	rmb_trig.trigger_type = AbilityPipeline.TriggerType.ON_HIT_ENEMY
	rmb.triggers.append(rmb_trig)
	
	var rmb_dmg = AbilityPipeline.AbilityRider.new()
	rmb_dmg.rider_type = AbilityPipeline.RiderType.DAMAGE
	rmb_dmg.amount = 25.0
	rmb.riders.append(rmb_dmg)
	
	var rmb_tether = AbilityPipeline.AbilityRider.new()
	rmb_tether.rider_type = AbilityPipeline.RiderType.TETHER
	rmb_tether.duration = 1.75
	rmb_tether.custom_params = {
		"break_distance": 18.0,
		"ramp_slow": 0.50,
		"root_duration": 1.25
	}
	rmb.riders.append(rmb_tether)
	_registry[rmb.id] = rmb

	# Reaper Q: Cull the Weak (Sweet-spot scythe spin with cripple)
	var q = AbilityPipeline.AbilityDefinition.new()
	q.id = "reaper_cull_the_weak"
	q.name = "Cull the Weak"
	q.slot_key = "Q"
	q.cooldown = 7.5
	
	q.effect = AbilityPipeline.AbilityEffect.new()
	q.effect.effect_type = AbilityPipeline.EffectType.AREA_ZONE
	q.effect.windup_time = 0.40
	
	q.hitbox = AbilityPipeline.AbilityHitbox.new()
	q.hitbox.shape = AbilityPipeline.HitboxShape.DONUT
	q.hitbox.radius = 5.5
	q.hitbox.width = 3.2 # inner radius
	q.hitbox.height = 2.4
	
	var q_hit = AbilityPipeline.AbilityTrigger.new()
	q_hit.trigger_type = AbilityPipeline.TriggerType.ON_HIT_ENEMY
	q.triggers.append(q_hit)
	
	var q_outer_dmg = AbilityPipeline.AbilityRider.new()
	q_outer_dmg.rider_type = AbilityPipeline.RiderType.DAMAGE
	q_outer_dmg.amount = 65.0
	q_outer_dmg.custom_params = {"inner_damage": 30.0, "inner_radius": 3.2, "outer_radius": 5.5}
	q.riders.append(q_outer_dmg)
	
	var q_cripple = AbilityPipeline.AbilityRider.new()
	q_cripple.rider_type = AbilityPipeline.RiderType.CRIPPLE
	q_cripple.duration = 2.5
	q_cripple.intensity = 0.35
	q.riders.append(q_cripple)
	_registry[q.id] = q

	# Reaper E: Nightmare (Vlad pool - invulnerable, AoE damage cast/end, slow)
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
	
	var e_cast = AbilityPipeline.AbilityTrigger.new()
	e_cast.trigger_type = AbilityPipeline.TriggerType.ON_CAST
	e.triggers.append(e_cast)
	
	var e_dmg = AbilityPipeline.AbilityRider.new()
	e_dmg.rider_type = AbilityPipeline.RiderType.DAMAGE
	e_dmg.amount = 35.0
	e_dmg.custom_params = {"end_damage": 45.0, "radius": 4.5}
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
	_registry[e.id] = e

	# Reaper R: One with Death (Steroid: MS, CDR, +30% rider potency)
	var r = AbilityPipeline.AbilityDefinition.new()
	r.id = "reaper_one_with_death"
	r.name = "One with Death"
	r.slot_key = "R"
	r.cooldown = 25.0
	
	r.effect = AbilityPipeline.AbilityEffect.new()
	r.effect.effect_type = AbilityPipeline.EffectType.BUFF
	r.effect.duration = 8.0
	r.hitbox = null
	
	var r_cast = AbilityPipeline.AbilityTrigger.new()
	r_cast.trigger_type = AbilityPipeline.TriggerType.ON_CAST
	r.triggers.append(r_cast)
	
	var r_ms = AbilityPipeline.AbilityRider.new()
	r_ms.rider_type = AbilityPipeline.RiderType.SPEED_BOOST
	r_ms.duration = 8.0
	r_ms.intensity = 0.45
	r.riders.append(r_ms)
	
	var r_emp = AbilityPipeline.AbilityRider.new()
	r_emp.rider_type = AbilityPipeline.RiderType.EMPOWER
	r_emp.duration = 8.0
	r_emp.custom_params = {
		"cdr_mult": 0.50,
		"damage_mult": 1.30,
		"rider_mult": 1.30
	}
	r.riders.append(r_emp)
	_registry[r.id] = r

	# Reaper Shift: Ethereal Dash
	var dash = AbilityPipeline.AbilityDefinition.new()
	dash.id = "ethereal_dash"
	dash.name = "Ethereal Dash"
	dash.slot_key = "SHIFT"
	dash.cooldown = 5.0
	
	dash.effect = AbilityPipeline.AbilityEffect.new()
	dash.effect.effect_type = AbilityPipeline.EffectType.DASH
	dash.hitbox = null
	
	var dash_cast = AbilityPipeline.AbilityTrigger.new()
	dash_cast.trigger_type = AbilityPipeline.TriggerType.ON_CAST
	dash.triggers.append(dash_cast)
	
	var dash_eth = AbilityPipeline.AbilityRider.new()
	dash_eth.rider_type = AbilityPipeline.RiderType.ETHEREAL
	dash_eth.duration = 0.45
	dash.riders.append(dash_eth)
	_registry[dash.id] = dash

static func _register_universal_abilities() -> void:
	var dash = AbilityPipeline.AbilityDefinition.new()
	dash.id = "universal_dash"
	dash.name = "Dash"
	dash.slot_key = "SHIFT"
	dash.cooldown = 4.0
	
	dash.effect = AbilityPipeline.AbilityEffect.new()
	dash.effect.effect_type = AbilityPipeline.EffectType.DASH
	dash.hitbox = null
	
	var dash_cast = AbilityPipeline.AbilityTrigger.new()
	dash_cast.trigger_type = AbilityPipeline.TriggerType.ON_CAST
	dash.triggers.append(dash_cast)
	_registry[dash.id] = dash

static func get_ability(ability_id: String) -> AbilityPipeline.AbilityDefinition:
	_ensure_initialized()
	return _registry.get(ability_id, null)

static func get_all_abilities() -> Dictionary:
	_ensure_initialized()
	return _registry

func _register_disruptor_abilities() -> void:
	# Disruptor LMB: Burst Fire
	var lmb = AbilityPipeline.AbilityDefinition.new()
	lmb.id = "disruptor_burst_fire"
	lmb.name = "Burst fire"
	lmb.slot_key = "LMB"
	lmb.cooldown = 1
	
	lmb.effect = AbilityPipeline.AbilityEffect.new()
	lmb.effect.effect_type = AbilityPipeline.EffectType.PROJECTILE
	lmb.effect.speed = 60.0
	lmb.effect.max_range = 50.0
	lmb.effect.projectile_size = 0.35
	lmb.effect.count = 3
	lmb.effect.chargeable = true
	
	lmb.hitbox = AbilityPipeline.AbilityHitbox.new()
	lmb.hitbox.shape = AbilityPipeline.HitboxShape.LINE
	lmb.hitbox.length = 50.0
	lmb.hitbox.width = 0.35
	
	var lmb_trigger = AbilityPipeline.AbilityTrigger.new()
	lmb_trigger.trigger_type = AbilityPipeline.TriggerType.ON_HIT_ENEMY
	lmb.triggers.append(lmb_trigger)
	
	var r_dmg = AbilityPipeline.AbilityRider.new()
	r_dmg.rider_type = AbilityPipeline.RiderType.DAMAGE
	r_dmg.amount = 18.0
	lmb.riders.append(r_dmg)
	
	var r_fleet = AbilityPipeline.AbilityRider.new()
	r_fleet.rider_type = AbilityPipeline.RiderType.SPEED_BOOST
	r_fleet.duration = 2.5
	r_fleet.intensity = 0.15
	lmb.riders.append(r_fleet)
	_registry[lmb.id] = lmb
