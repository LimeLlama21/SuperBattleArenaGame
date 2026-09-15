class_name AbilityBuilder
extends RefCounted

const AbilityClass = preload("res://ability/ability.gd")
const AbilityScene = preload("res://ability/ability.tscn")

# Effects
const ProjectileScene = preload("res://ability/effects/projectile_effect.tscn")
const MeleeStrikeScene = preload("res://ability/effects/melee_strike_effect.tscn")
const DashScene = preload("res://ability/effects/dash_effect.tscn")
const BuffScene = preload("res://ability/effects/buff_effect.tscn")
const AreaZoneScene = preload("res://ability/effects/area_zone_effect.tscn")
const ChannelScene = preload("res://ability/effects/channel_effect.tscn")
const AerialCrashScene = preload("res://ability/effects/aerial_crash_effect.tscn")
const ChargeSlamScene = preload("res://ability/effects/charge_slam_effect.tscn")
const StanceBlockScene = preload("res://ability/effects/stance_block_effect.tscn")

# Hitboxes
const LineHitboxClass = preload("res://ability/hitboxes/line_hitbox.gd")
const SectorHitboxClass = preload("res://ability/hitboxes/sector_hitbox.gd")
const CircleHitboxClass = preload("res://ability/hitboxes/circle_hitbox.gd")
const CylinderHitboxClass = preload("res://ability/hitboxes/cylinder_hitbox.gd")
const BoxHitboxClass = preload("res://ability/hitboxes/box_hitbox.gd")
const DonutHitboxClass = preload("res://ability/hitboxes/donut_hitbox.gd")

# Triggers
const OnHitEnemyTriggerClass = preload("res://ability/triggers/on_hit_enemy_trigger.gd")
const OnCastTriggerClass = preload("res://ability/triggers/on_cast_trigger.gd")
const OnHitWallTriggerClass = preload("res://ability/triggers/on_hit_wall_trigger.gd")
const OnReachDestTriggerClass = preload("res://ability/triggers/on_reach_destination_trigger.gd")
const OnExpireTriggerClass = preload("res://ability/triggers/on_expire_trigger.gd")
const OnTickTriggerClass = preload("res://ability/triggers/on_tick_trigger.gd")
const OnChannelCompleteTriggerClass = preload("res://ability/triggers/on_channel_complete_trigger.gd")

# Riders
const DamageRiderClass = preload("res://ability/riders/damage_rider.gd")
const StunRiderClass = preload("res://ability/riders/stun_rider.gd")
const SlowRiderClass = preload("res://ability/riders/slow_rider.gd")
const KnockbackRiderClass = preload("res://ability/riders/knockback_rider.gd")
const ShieldRiderClass = preload("res://ability/riders/shield_rider.gd")
const SpeedBoostRiderClass = preload("res://ability/riders/speed_boost_rider.gd")
const StatusRiderClass = preload("res://ability/riders/status_rider.gd")
const EmpowerRiderClass = preload("res://ability/riders/empower_rider.gd")
const BoundRiderClass = preload("res://ability/riders/bound_rider.gd")
const HealRiderClass = preload("res://ability/riders/heal_rider.gd")

static func build_ability(cfg: Dictionary) -> Ability:
	var ab = AbilityScene.instantiate() as Ability
	ab.ability_id = cfg.get("id", "")
	ab.ability_name = cfg.get("name", ab.ability_id)
	ab.slot_key = cfg.get("slot_key", cfg.get("slot", "LMB"))
	ab.description = cfg.get("description", "")
	ab.icon_symbol = str(cfg.get("icon", ""))
	ab.cooldown = cfg.get("cooldown", 0.0)
	ab.max_charges = cfg.get("charges", 1)
	ab.charges = ab.max_charges
	ab.recharge_time = cfg.get("recharge_time", 0.0)
	ab.cast_on_press = cfg.get("cast_on_press", ab.slot_key == "LMB" or ab.slot_key == "SHIFT")
	ab.windup_time = cfg.get("windup_time", cfg.get("windup", 0.0))
	ab.windup_move_speed_multiplier = cfg.get("windup_move_speed_multiplier", 1.0)
	ab.cast_lockout = cfg.get("cast_lockout", true)
	ab.move_lockout = cfg.get("move_lockout", false)
	ab.bypass_lockout = cfg.get("bypass_lockout", false)

	# 1. Effect Property
	var effect_cfg = cfg.get("effect", {})
	var effect_node = _build_effect(effect_cfg)
	if effect_node:
		ab.effect_instance = effect_node
		effect_node.cast_lockout = ab.cast_lockout
		effect_node.move_lockout = ab.move_lockout
		effect_node.bypass_lockout = ab.bypass_lockout
		effect_node.windup_move_speed_multiplier = ab.windup_move_speed_multiplier

	# 2. Hitbox Property
	var hitbox_cfg = cfg.get("hitbox", {})
	if not hitbox_cfg.is_empty() and effect_node:
		var hitbox_node = _build_hitbox(hitbox_cfg)
		if hitbox_node:
			effect_node.hitbox_instance = hitbox_node

	# 3. Triggers & Riders Properties
	var riders_list = cfg.get("riders", [])
	var triggers_list = cfg.get("triggers", [])
	
	if effect_node:
		if not triggers_list.is_empty():
			for t_cfg in triggers_list:
				var t_node = _build_trigger(t_cfg)
				if t_node:
					effect_node.trigger_instances.append(t_node)
		elif not riders_list.is_empty():
			# Default trigger based on effect
			var def_trigger = null
			if effect_node is DashEffect or effect_node is BuffEffect:
				def_trigger = OnCastTriggerClass.new()
			else:
				def_trigger = OnHitEnemyTriggerClass.new()
			
			for r_cfg in riders_list:
				var r_node = _build_rider(r_cfg)
				if r_node:
					def_trigger.rider_instances.append(r_node)
			effect_node.trigger_instances.append(def_trigger)

	ab.setup()
	return ab

static func _build_effect(cfg: Dictionary) -> Node:
	var raw_type = cfg.get("type", cfg.get("effect_type", AbilityPipeline.EffectType.PROJECTILE))
	var type_val = AbilityPipeline.parse_effect_type(raw_type)
	
	var eff: Node = null
	match type_val:
		AbilityPipeline.EffectType.PROJECTILE:
			var pe = ProjectileScene.instantiate() as ProjectileEffect
			pe.speed = cfg.get("speed", 70.0)
			pe.max_range = cfg.get("range", cfg.get("max_range", 25.0))
			pe.projectile_size = cfg.get("size", cfg.get("projectile_size", 0.5))
			pe.pierces = cfg.get("pierces", false)
			pe.custom_effect_type = cfg.get("custom_effect_type", cfg.get("eff_type", ""))
			eff = pe
		AbilityPipeline.EffectType.MELEE_STRIKE:
			var me = MeleeStrikeScene.instantiate() as MeleeStrikeEffect
			me.windup_time = cfg.get("windup", cfg.get("windup_time", 0.2))
			eff = me
		AbilityPipeline.EffectType.DASH:
			var de = DashScene.instantiate() as DashEffect
			de.impulse = cfg.get("impulse", 24.0)
			de.bypass_lockout = cfg.get("bypass_lockout", true)
			de.cast_lockout = cfg.get("cast_lockout", false)
			de.move_lockout = cfg.get("move_lockout", false)
			eff = de
		AbilityPipeline.EffectType.BUFF:
			var be = BuffScene.instantiate() as BuffEffect
			be.buff_name = cfg.get("buff_name", "Buff")
			eff = be
		AbilityPipeline.EffectType.AREA_ZONE:
			var ze = AreaZoneScene.instantiate() as AreaZoneEffect
			ze.radius = cfg.get("radius", 4.0)
			ze.zone_duration = cfg.get("duration", 3.0)
			eff = ze
		AbilityPipeline.EffectType.CHANNEL:
			var ce = ChannelScene.instantiate() as ChannelEffect
			ce.channel_duration = cfg.get("duration", cfg.get("channel_time", 2.0))
			eff = ce
		AbilityPipeline.EffectType.AERIAL_CRASH:
			eff = AerialCrashScene.instantiate()
		AbilityPipeline.EffectType.CHARGE_SLAM:
			eff = ChargeSlamScene.instantiate()
		AbilityPipeline.EffectType.STANCE_BLOCK:
			eff = StanceBlockScene.instantiate()
		_:
			eff = ProjectileScene.instantiate()
	return eff

static func _build_hitbox(cfg: Dictionary) -> Node:
	var raw_shape = cfg.get("shape", AbilityPipeline.HitboxShape.NONE)
	var shape_val = AbilityPipeline.parse_hitbox_shape(raw_shape)
	
	match shape_val:
		AbilityPipeline.HitboxShape.LINE:
			var hb = LineHitboxClass.new()
			hb.length = cfg.get("length", 20.0)
			hb.width = cfg.get("width", 1.0)
			return hb
		AbilityPipeline.HitboxShape.SECTOR:
			var hb = SectorHitboxClass.new()
			hb.radius = cfg.get("radius", 4.0)
			hb.angle_deg = cfg.get("angle", cfg.get("angle_deg", 90.0))
			hb.height = cfg.get("height", 2.5)
			hb.annul = cfg.get("annul", false)
			return hb
		AbilityPipeline.HitboxShape.CIRCLE:
			var hb = CircleHitboxClass.new()
			hb.radius = cfg.get("radius", 3.0)
			hb.height = cfg.get("height", 2.5)
			hb.angle_deg = cfg.get("angle_deg", cfg.get("angle", 360.0))
			hb.annul = cfg.get("annul", false)
			return hb
		AbilityPipeline.HitboxShape.CYLINDER:
			var hb = CylinderHitboxClass.new()
			hb.radius = cfg.get("radius", 4.0)
			hb.height = cfg.get("height", 3.0)
			return hb
		AbilityPipeline.HitboxShape.BOX:
			var hb = BoxHitboxClass.new()
			hb.width = cfg.get("width", 2.0)
			hb.length = cfg.get("length", 4.0)
			hb.height = cfg.get("height", 2.5)
			return hb
		AbilityPipeline.HitboxShape.DONUT:
			var hb = DonutHitboxClass.new()
			hb.inner_radius = cfg.get("inner_radius", 2.0)
			hb.outer_radius = cfg.get("outer_radius", 5.0)
			return hb
	return null

static func _build_trigger(cfg: Dictionary) -> Node:
	var raw_type = cfg.get("type", AbilityPipeline.TriggerType.ON_HIT_ENEMY)
	var type_val = AbilityPipeline.parse_trigger_type(raw_type)
	
	var trig: Node = null
	match type_val:
		AbilityPipeline.TriggerType.ON_CAST:
			trig = OnCastTriggerClass.new()
		AbilityPipeline.TriggerType.ON_HIT_ENEMY:
			trig = OnHitEnemyTriggerClass.new()
		AbilityPipeline.TriggerType.ON_HIT_WALL:
			trig = OnHitWallTriggerClass.new()
		AbilityPipeline.TriggerType.ON_REACH_DESTINATION:
			trig = OnReachDestTriggerClass.new()
		AbilityPipeline.TriggerType.ON_EXPIRE:
			trig = OnExpireTriggerClass.new()
		AbilityPipeline.TriggerType.ON_TICK:
			trig = OnTickTriggerClass.new()
		AbilityPipeline.TriggerType.ON_CHANNEL_COMPLETE:
			trig = OnChannelCompleteTriggerClass.new()
		_:
			trig = OnHitEnemyTriggerClass.new()
	
	var riders = cfg.get("riders", [])
	for r_cfg in riders:
		var r_node = _build_rider(r_cfg)
		if r_node and trig:
			trig.rider_instances.append(r_node)
	return trig

static func _build_rider(cfg: Dictionary) -> Node:
	var raw_type = cfg.get("type", AbilityPipeline.RiderType.DAMAGE)
	var type_val = AbilityPipeline.parse_rider_type(raw_type)
	
	match type_val:
		AbilityPipeline.RiderType.DAMAGE:
			var r = DamageRiderClass.new()
			r.amount = cfg.get("amount", cfg.get("damage", 0.0))
			return r
		AbilityPipeline.RiderType.STUN:
			var r = StunRiderClass.new()
			r.duration = cfg.get("duration", 0.5)
			return r
		AbilityPipeline.RiderType.BOUND:
			var r = BoundRiderClass.new()
			r.duration = cfg.get("duration", 1.0)
			if cfg.has("custom_position"):
				r.custom_position = cfg["custom_position"]
				r.use_custom_position = true
			if cfg.has("buffer_offset"):
				r.buffer_offset = cfg["buffer_offset"]
			return r
		AbilityPipeline.RiderType.SLOW:
			var r = SlowRiderClass.new()
			r.duration = cfg.get("duration", 2.0)
			r.intensity = cfg.get("intensity", 0.30)
			return r
		AbilityPipeline.RiderType.KNOCKBACK:
			var r = KnockbackRiderClass.new()
			r.amount = cfg.get("amount", 12.0)
			return r
		AbilityPipeline.RiderType.SHIELD:
			var r = ShieldRiderClass.new()
			r.amount = cfg.get("amount", 30.0)
			r.duration = cfg.get("duration", 4.0)
			return r
		AbilityPipeline.RiderType.SPEED_BOOST:
			var r = SpeedBoostRiderClass.new()
			r.duration = cfg.get("duration", 3.0)
			r.percent = cfg.get("intensity", cfg.get("percent", 0.30))
			return r
		AbilityPipeline.RiderType.EMPOWER:
			var r = EmpowerRiderClass.new()
			r.bonus_damage = cfg.get("amount", cfg.get("bonus_damage", 0.0))
			return r
		AbilityPipeline.RiderType.ROOT, AbilityPipeline.RiderType.GROUND, AbilityPipeline.RiderType.SILENCE, \
		AbilityPipeline.RiderType.CRIPPLE, AbilityPipeline.RiderType.ETHEREAL, AbilityPipeline.RiderType.TETHER, \
		AbilityPipeline.RiderType.MS_STEAL:
			var r = StatusRiderClass.new()
			r.status_type = str(raw_type)
			r.duration = cfg.get("duration", 1.5)
			r.intensity = cfg.get("intensity", 0.0)
			return r
		AbilityPipeline.RiderType.HEAL:
			var r = HealRiderClass.new()
			r.amount = cfg.get("amount", cfg.get("heal_amount", 0.0))
			r.percent = cfg.get("percent", 0.0)
			r.heal_missing_hp = cfg.get("heal_missing_hp", false)
			r.scale_with_marks = cfg.get("scale_with_marks", false)
			r.min_missing_hp_percent = cfg.get("min_percent", 0.11)
			r.max_missing_hp_percent = cfg.get("max_percent", 0.15)
			r.apply_to_self = cfg.get("apply_to_self", true)
			return r
	return null
