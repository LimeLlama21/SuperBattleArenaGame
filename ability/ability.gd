class_name Ability
extends Node

const AbilityHitboxClass = preload("res://ability/hitboxes/ability_hitbox.gd")

@export var effect: PackedScene = null
@export var slot_key: String = "LMB" # "LMB", "RMB", "SHIFT", "Q", "E", "R"
@export var ability_id: String = ""
@export var ability_name: String = ""
@export var description: String = ""
@export var icon_symbol: String = ""
@export var icon_texture: Texture2D = null
@export var cooldown: float = 0.0
@export var charges: int = 1:
	set(val):
		charges = val
		max_charges = val
@export var max_charges: int = 1
@export var recharge_time: float = 0.0
@export var cast_on_press: bool = true
@export var is_passive: bool = false
@export var windup_time: float = 0.0
@export var mana_cost: float = -1.0 # -1.0 uses default slot rules (LMB/SHIFT=0, R=30, others=10), >= 0 overrides
@export var cooldown_on_cast: bool = true

@export_group("Delay / Windup Settings")
@export var delay: float = 0.0
@export var telegraph: bool = true
@export var follow_caster: bool = false
@export var windup_move_speed_multiplier: float = 1.0

@export_group("Lockout Settings")
@export var cast_lockout: bool = true
@export var move_lockout: bool = false
@export var bypass_lockout: bool = false

@export_group("Charge Settings")
@export var charge_time: float = 0.0
@export var max_charge_time: float = 0.0
@export var min_charge_time: float = 0.0
@export var hold_to_charge: bool = false
@export var auto_release_on_max_charge: bool = false
@export var charge_move_speed_multiplier: float = 1.0
@export var min_damage: float = 0.0
@export var max_damage: float = 0.0

var effect_instance = null
var current_cooldown: float = 0.0
var current_charges: int = 1
var recharge_timer: float = 0.0
var is_holding: bool = false
var active_indicator: Node3D = null
var is_charging: bool = false
var current_charge_time: float = 0.0
var is_winding_up: bool = false
var current_windup_timer: float = 0.0
var active_telegraph: Node3D = null

var id: String:
	get: return ability_id

var name_text: String:
	get: return ability_name if not ability_name.is_empty() else ability_id

var hitbox:
	get:
		if effect_instance and effect_instance != self and "hitbox_instance" in effect_instance:
			return effect_instance.hitbox_instance
		if "hitbox_instance" in self:
			return self.hitbox_instance
		return null

func _ready() -> void:
	setup()

func setup() -> void:
	current_charges = max_charges
	if not effect_instance:
		if self.has_method("execute_effect_server") or "hitbox_instance" in self:
			effect_instance = self
		else:
			for child in get_children():
				if child.has_method("execute_effect_server") or "hitbox_instance" in child:
					effect_instance = child
					break
	if effect and not effect_instance:
		effect_instance = effect.instantiate()
	if effect_instance and effect_instance != self and effect_instance.has_method("setup"):
		effect_instance.setup()
	if delay > 0.0 and windup_time <= 0.0:
		windup_time = delay
	elif windup_time > 0.0 and delay <= 0.0:
		delay = windup_time
	if is_charge_ability():
		cast_on_press = false

func get_max_charge_time() -> float:
	if max_charge_time > 0.0:
		return max_charge_time
	if charge_time > 0.0:
		return charge_time
	if effect_instance and effect_instance != self and effect_instance.has_method("get_max_charge_time"):
		return effect_instance.get_max_charge_time()
	return 0.0

func is_charge_ability() -> bool:
	if hold_to_charge or get_max_charge_time() > 0.0:
		return true
	if effect_instance and effect_instance != self and effect_instance.has_method("is_charge_ability"):
		return effect_instance.is_charge_ability()
	return false

func should_show_indicator() -> bool:
	var is_proj = false
	var eff = effect_instance if (effect_instance and effect_instance != self) else self
	if eff:
		var eff_name = eff.get("effect_name") if "effect_name" in eff else ""
		if eff_name == "Projectile":
			is_proj = true
		elif "speed" in eff and eff.speed > 0.0 and "max_range" in eff and eff.max_range > 0.0:
			is_proj = true

	# Non-projectile abilities retain their standard indicator behavior
	if not is_proj:
		return true

	# Keep indicators for charged projectile abilities
	if is_charge_ability():
		return true
	if hold_to_charge or charge_time > 0.0 or max_charge_time > 0.0:
		return true
	if eff and "charge_time" in eff and eff.charge_time > 0.0:
		return true

	# Keep indicators for lobbed mortars (e.g. Morrigan's Omen of Death)
	var custom_eff = ""
	if eff and "custom_effect_type" in eff:
		custom_eff = str(eff.custom_effect_type).to_lower()
	var ab_id = ability_id.to_lower()
	if custom_eff == "mortar_shell" or ab_id.contains("mortar") or ab_id.contains("omen"):
		return true

	# Keep indicators for very long range projectile abilities (>= 35.0m)
	var rng = 0.0
	if eff and "max_range" in eff:
		rng = max(rng, eff.max_range)
	if hitbox and "length" in hitbox:
		rng = max(rng, hitbox.length)
	if rng >= 35.0:
		return true

	# Keep indicators for long telegraph / windup attacks
	if telegraph and delay >= 1.0:
		return true

	# Regular projectile abilities have indicators removed
	return false

func can_start_charging(caster: Node = null) -> bool:
	if not is_charge_ability():
		return false
	if not caster:
		var parent_node = get_parent()
		if parent_node and (parent_node.has_method("has_mana") or "current_mana" in parent_node):
			caster = parent_node
		elif parent_node and parent_node.get_parent() and (parent_node.get_parent().has_method("has_mana") or "current_mana" in parent_node.get_parent()):
			caster = parent_node.get_parent()
	if is_instance_valid(caster):
		var cost = get_mana_cost(caster)
		if cost > 0.0 and caster.has_method("has_mana") and not caster.has_mana(cost):
			return false
		return can_cast(caster)
	return true

func start_charging(caster: Node = null) -> bool:
	if is_instance_valid(caster) and not can_start_charging(caster):
		return false
	is_charging = true
	current_charge_time = 0.0
	if effect_instance and effect_instance != self and effect_instance.has_method("start_charging"):
		effect_instance.start_charging()
	return true

func stop_charging() -> void:
	is_charging = false
	current_charge_time = 0.0
	if effect_instance and effect_instance != self and effect_instance.has_method("stop_charging"):
		effect_instance.stop_charging()

func process_charge(delta: float, caster: Node = null) -> float:
	if not is_charging:
		return 0.0
	if not caster:
		var parent_node = get_parent()
		if parent_node and (parent_node.has_method("has_mana") or "current_mana" in parent_node):
			caster = parent_node
		elif parent_node and parent_node.get_parent() and (parent_node.get_parent().has_method("has_mana") or "current_mana" in parent_node.get_parent()):
			caster = parent_node.get_parent()
	if is_instance_valid(caster):
		var cost = get_mana_cost(caster)
		if cost > 0.0 and caster.has_method("has_mana") and not caster.has_mana(cost):
			stop_charging()
			return 0.0
	current_charge_time += delta
	var max_ct = get_max_charge_time()
	if max_ct > 0.0:
		current_charge_time = min(current_charge_time, max_ct)
	if effect_instance and effect_instance != self and effect_instance.has_method("process_charge"):
		effect_instance.process_charge(delta)
	return get_charge_ratio()

func get_charge_ratio() -> float:
	var max_ct = get_max_charge_time()
	if max_ct <= 0.0:
		return 1.0 if is_charging else 0.0
	return clamp(current_charge_time / max_ct, 0.0, 1.0)

func get_windup_time() -> float:
	if windup_time > 0.0:
		return windup_time
	if delay > 0.0:
		return delay
	if effect_instance and effect_instance != self and effect_instance.has_method("get_windup_time"):
		return effect_instance.get_windup_time()
	return 0.0

func has_delay() -> bool:
	return get_windup_time() > 0.0

func start_windup(windup_dur: float = -1.0) -> void:
	is_winding_up = true
	current_windup_timer = windup_dur if windup_dur >= 0.0 else get_windup_time()
	if effect_instance and effect_instance != self and effect_instance.has_method("start_windup"):
		effect_instance.start_windup(windup_dur)

func cancel_windup() -> void:
	is_winding_up = false
	current_windup_timer = 0.0
	if active_telegraph and is_instance_valid(active_telegraph):
		active_telegraph.queue_free()
		active_telegraph = null
	if effect_instance and effect_instance != self and effect_instance.has_method("cancel_windup"):
		effect_instance.cancel_windup()

func process_windup(delta: float) -> bool:
	if not is_winding_up:
		return false
	current_windup_timer -= delta
	if current_windup_timer <= 0.0:
		is_winding_up = false
		current_windup_timer = 0.0
		return true
	return false

func get_ui_config() -> Dictionary:
	var stats_parts: Array[String] = []
	var cost = get_mana_cost()
	if cost > 0.0:
		stats_parts.append("%d MP" % int(cost))
	if cooldown > 0.0:
		stats_parts.append("Cooldown: %.1fs" % cooldown)
	elif recharge_time > 0.0:
		stats_parts.append("Recharge: %.1fs" % recharge_time)
	if max_charges > 1:
		stats_parts.append("Charges: %d" % max_charges)
	if effect_instance:
		if "max_range" in effect_instance and effect_instance.max_range > 0.0:
			stats_parts.append("Range: %.1fm" % effect_instance.max_range)
		if "speed" in effect_instance and effect_instance.speed > 0.0:
			stats_parts.append("Speed: %.0fm/s" % effect_instance.speed)
		if "trigger_instances" in effect_instance and effect_instance.trigger_instances is Array:
			for trig in effect_instance.trigger_instances:
				if trig and "rider_instances" in trig and trig.rider_instances is Array:
					for r in trig.rider_instances:
						if "amount" in r and r.amount > 0.0:
							stats_parts.append("Damage: %.0f" % r.amount)
						elif "duration" in r and r.duration > 0.0:
							stats_parts.append("Duration: %.1fs" % r.duration)
						elif "intensity" in r and r.intensity > 0.0:
							stats_parts.append("Slow: %d%%" % int(r.intensity * 100))
	return {
		"name": name_text,
		"icon": icon_symbol if not icon_symbol.is_empty() else icon_texture,
		"description": description,
		"stats": "  •  ".join(stats_parts) if not stats_parts.is_empty() else ("Cooldown: %.1fs" % cooldown)
	}

func get_hitbox() -> Variant:
	return hitbox

func has_hitbox() -> bool:
	var hb = get_hitbox()
	return hb != null and "shape_type" in hb and hb.shape_type != AbilityPipeline.HitboxShape.NONE

func process_lifecycle(delta: float) -> void:
	if is_winding_up:
		process_windup(delta)
	if current_cooldown > 0.0:
		current_cooldown = max(0.0, current_cooldown - delta)
	
	if max_charges > 1 and recharge_time > 0.0 and current_charges < max_charges:
		recharge_timer -= delta
		if recharge_timer <= 0.0:
			current_charges = min(max_charges, current_charges + 1)
			if current_charges < max_charges:
				recharge_timer = recharge_time
			else:
				recharge_timer = 0.0

func get_mana_cost(caster: Node = null) -> float:
	if not caster:
		var parent_node = get_parent()
		if parent_node and (parent_node.has_method("get_custom_ability_mana_cost") or "current_mana" in parent_node):
			caster = parent_node
		elif parent_node and parent_node.get_parent() and (parent_node.get_parent().has_method("get_custom_ability_mana_cost") or "current_mana" in parent_node.get_parent()):
			caster = parent_node.get_parent()

	if is_instance_valid(caster) and caster.has_method("get_custom_ability_mana_cost"):
		var custom_cost = caster.get_custom_ability_mana_cost(slot_key, ability_id)
		if custom_cost >= 0.0:
			return custom_cost

	if mana_cost >= 0.0:
		return mana_cost

	match slot_key:
		"LMB":
			return 0.0
		"SHIFT":
			return 0.0
		"R":
			return 30.0
		_:
			return 10.0

func can_bypass_lockout() -> bool:
	if bypass_lockout:
		return true
	if effect_instance and effect_instance != self and "bypass_lockout" in effect_instance and effect_instance.bypass_lockout:
		return true
	return false

func can_cast(caster: Node) -> bool:
	if is_passive or is_winding_up:
		return false
	if is_instance_valid(caster) and "is_dead" in caster and caster.is_dead:
		return false
	if current_cooldown > 0.0:
		return false
	if max_charges > 1 and current_charges <= 0:
		return false
	
	if is_instance_valid(caster):
		if caster.has_method("is_stunned") and caster.is_stunned():
			return false
		if caster.has_method("is_bound") and caster.is_bound():
			return false
		if caster.has_method("is_silenced") and caster.is_silenced():
			return false
		if slot_key == "SHIFT":
			if caster.has_method("is_rooted") and caster.is_rooted():
				return false
			if caster.has_method("is_grounded") and caster.is_grounded():
				return false
		if caster.has_method("has_mana"):
			var cost = get_mana_cost(caster)
			if not caster.has_mana(cost):
				return false
		if caster.has_method("is_in_cast_lockout") and caster.is_in_cast_lockout():
			if not can_bypass_lockout():
				return false
	return true

func consume_resources(caster: Node = null) -> void:
	stop_charging()
	if not caster:
		var parent_node = get_parent()
		if parent_node and (parent_node.has_method("consume_mana") or "current_mana" in parent_node):
			caster = parent_node
		elif parent_node and parent_node.get_parent() and (parent_node.get_parent().has_method("consume_mana") or "current_mana" in parent_node.get_parent()):
			caster = parent_node.get_parent()
	if is_instance_valid(caster) and caster.has_method("consume_mana"):
		var cost = get_mana_cost(caster)
		if cost > 0.0:
			caster.consume_mana(cost)

	var apply_cd: bool = cooldown_on_cast
	if is_instance_valid(caster) and caster.has_method("should_ability_start_cooldown_on_cast"):
		apply_cd = caster.should_ability_start_cooldown_on_cast(slot_key, ability_id)

	if apply_cd:
		var cd_duration = cooldown
		if is_instance_valid(caster) and caster.has_method("get_cooldown_multiplier"):
			cd_duration *= caster.get_cooldown_multiplier()
		if max_charges > 1:
			current_charges = max(0, current_charges - 1)
			if recharge_timer <= 0.0 and current_charges < max_charges:
				recharge_timer = recharge_time
			if current_charges == 0:
				current_cooldown = cd_duration if cd_duration > 0.0 else recharge_time
		else:
			current_cooldown = cd_duration

func execute_server(caster: Node, origin: Vector3, direction: Vector3, target_pos: Vector3, charge_ratio: float = 0.0) -> void:
	setup()
	if not is_winding_up:
		consume_resources(caster)
	is_winding_up = false
	if is_instance_valid(caster) and caster.has_method("custom_execute_ability_server"):
		if caster.custom_execute_ability_server(slot_key, origin, direction, target_pos, charge_ratio):
			return
	if effect_instance and effect_instance != self and effect_instance.has_method("execute_server"):
		effect_instance.execute_server(caster, origin, direction, target_pos, charge_ratio)
	else:
		_execute_server_effect(caster, origin, direction, target_pos, charge_ratio)

func _execute_server_effect(_caster: Node, _origin: Vector3, _direction: Vector3, _target_pos: Vector3, _charge_ratio: float = 0.0) -> void:
	pass

func execute_client(caster: Node, origin: Vector3, direction: Vector3, target_pos: Vector3, charge_ratio: float = 0.0) -> void:
	setup()
	if is_instance_valid(caster) and caster.has_method("custom_execute_ability_client"):
		if caster.custom_execute_ability_client(slot_key, origin, direction, target_pos, charge_ratio):
			return
	if effect_instance and effect_instance != self and effect_instance.has_method("execute_client"):
		effect_instance.execute_client(caster, origin, direction, target_pos, charge_ratio)
	else:
		_execute_client_effect(caster, origin, direction, target_pos, charge_ratio)

func _execute_client_effect(_caster: Node, _origin: Vector3, _direction: Vector3, _target_pos: Vector3, _charge_ratio: float = 0.0) -> void:
	pass

static func create_from_config(cfg: Dictionary) -> Ability:
	var ab_scene = load("res://ability/ability.tscn") as PackedScene
	var ab = ab_scene.instantiate() as Ability
	ab.ability_id = cfg.get("id", "")
	ab.ability_name = cfg.get("name", ab.ability_id)
	ab.slot_key = cfg.get("slot_key", cfg.get("slot", "LMB"))
	ab.description = cfg.get("description", "")
	ab.icon_symbol = str(cfg.get("icon", ""))
	ab.cooldown = cfg.get("cooldown", 0.0)
	ab.max_charges = cfg.get("charges", 1)
	ab.charges = ab.max_charges
	ab.recharge_time = cfg.get("recharge_time", 0.0)
	ab.charge_time = cfg.get("charge_time", 0.0)
	ab.max_charge_time = cfg.get("max_charge_time", ab.charge_time)
	ab.min_charge_time = cfg.get("min_charge_time", 0.0)
	ab.hold_to_charge = cfg.get("hold_to_charge", ab.max_charge_time > 0.0)
	ab.auto_release_on_max_charge = cfg.get("auto_release_on_max_charge", false)
	ab.charge_move_speed_multiplier = cfg.get("charge_move_speed_multiplier", 1.0)
	ab.min_damage = cfg.get("min_damage", 0.0)
	ab.max_damage = cfg.get("max_damage", 0.0)
	ab.cast_on_press = cfg.get("cast_on_press", (ab.slot_key == "LMB" or ab.slot_key == "SHIFT") and not ab.is_charge_ability())
	ab.windup_time = cfg.get("windup_time", cfg.get("windup", cfg.get("delay", 0.0)))
	ab.delay = ab.windup_time
	ab.telegraph = cfg.get("telegraph", true)
	ab.follow_caster = cfg.get("follow_caster", false)
	ab.windup_move_speed_multiplier = cfg.get("windup_move_speed_multiplier", 1.0)
	ab.cast_lockout = cfg.get("cast_lockout", true)
	ab.move_lockout = cfg.get("move_lockout", false)
	ab.bypass_lockout = cfg.get("bypass_lockout", false)
	ab.mana_cost = cfg.get("mana_cost", cfg.get("mana", -1.0))

	var effect_cfg = cfg.get("effect", {})
	var effect_node = _build_effect(effect_cfg)
	if effect_node:
		ab.effect_instance = effect_node
		if ab.charge_time > 0.0:
			effect_node.charge_time = ab.charge_time
		if ab.max_charge_time > 0.0:
			effect_node.max_charge_time = ab.max_charge_time
		if ab.min_charge_time > 0.0:
			effect_node.min_charge_time = ab.min_charge_time
		if ab.hold_to_charge:
			effect_node.hold_to_charge = ab.hold_to_charge
		if ab.auto_release_on_max_charge:
			effect_node.auto_release_on_max_charge = ab.auto_release_on_max_charge
		if ab.charge_move_speed_multiplier != 1.0:
			effect_node.charge_move_speed_multiplier = ab.charge_move_speed_multiplier
		if ab.min_damage > 0.0:
			effect_node.min_damage = ab.min_damage
		if ab.max_damage > 0.0:
			effect_node.max_damage = ab.max_damage
		effect_node.windup_time = ab.windup_time
		effect_node.delay = ab.delay
		effect_node.telegraph = ab.telegraph
		effect_node.follow_caster = ab.follow_caster
		effect_node.windup_move_speed_multiplier = ab.windup_move_speed_multiplier
		effect_node.cast_lockout = ab.cast_lockout
		effect_node.move_lockout = ab.move_lockout
		effect_node.bypass_lockout = ab.bypass_lockout

	var hitbox_cfg = cfg.get("hitbox", {})
	if not hitbox_cfg.is_empty() and effect_node:
		var hitbox_node = _build_hitbox(hitbox_cfg)
		if hitbox_node:
			effect_node.hitbox_instance = hitbox_node

	var riders_list = cfg.get("riders", [])
	var triggers_list = cfg.get("triggers", [])
	
	if effect_node:
		if not triggers_list.is_empty():
			for t_cfg in triggers_list:
				var t_node = _build_trigger(t_cfg)
				if t_node:
					effect_node.trigger_instances.append(t_node)
		elif not riders_list.is_empty():
			var def_trigger = null
			var effect_name_str = effect_node.get("effect_name") if "effect_name" in effect_node else ""
			if effect_name_str in ["Dash", "Buff"]:
				def_trigger = (load("res://ability/triggers/on_cast_trigger.gd") as GDScript).new()
			else:
				def_trigger = (load("res://ability/triggers/on_hit_enemy_trigger.gd") as GDScript).new()
			
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
	
	match type_val:
		AbilityPipeline.EffectType.PROJECTILE:
			var pe = (load("res://ability/effects/projectile_effect.tscn") as PackedScene).instantiate()
			pe.speed = cfg.get("speed", 70.0)
			pe.max_range = cfg.get("range", cfg.get("max_range", 25.0))
			pe.projectile_size = cfg.get("size", cfg.get("projectile_size", 0.5))
			pe.pierces = cfg.get("pierces", false)
			pe.custom_effect_type = cfg.get("custom_effect_type", cfg.get("eff_type", ""))
			return pe
		AbilityPipeline.EffectType.MELEE_STRIKE:
			var me = (load("res://ability/effects/melee_strike_effect.tscn") as PackedScene).instantiate()
			me.windup_time = cfg.get("windup", cfg.get("windup_time", 0.2))
			return me
		AbilityPipeline.EffectType.DASH:
			var de = (load("res://ability/effects/dash_effect.tscn") as PackedScene).instantiate()
			de.impulse = cfg.get("impulse", 24.0)
			de.bypass_lockout = cfg.get("bypass_lockout", true)
			de.cast_lockout = cfg.get("cast_lockout", false)
			de.move_lockout = cfg.get("move_lockout", false)
			return de
		AbilityPipeline.EffectType.BUFF:
			var be = (load("res://ability/effects/buff_effect.tscn") as PackedScene).instantiate()
			be.buff_name = cfg.get("buff_name", "Buff")
			return be
		AbilityPipeline.EffectType.AREA_ZONE:
			var ze = (load("res://ability/effects/area_zone_effect.tscn") as PackedScene).instantiate()
			ze.radius = cfg.get("radius", 4.0)
			ze.zone_duration = cfg.get("duration", 3.0)
			return ze
		AbilityPipeline.EffectType.CHANNEL:
			var ce = (load("res://ability/effects/channel_effect.tscn") as PackedScene).instantiate()
			ce.channel_duration = cfg.get("duration", cfg.get("channel_time", 2.0))
			return ce
		AbilityPipeline.EffectType.AERIAL_CRASH:
			return (load("res://ability/effects/aerial_crash_effect.tscn") as PackedScene).instantiate()
		AbilityPipeline.EffectType.CHARGE_SLAM:
			return (load("res://ability/effects/charge_slam_effect.tscn") as PackedScene).instantiate()
		AbilityPipeline.EffectType.STANCE_BLOCK:
			return (load("res://ability/effects/stance_block_effect.tscn") as PackedScene).instantiate()
		_:
			return (load("res://ability/effects/projectile_effect.tscn") as PackedScene).instantiate()

static func _build_hitbox(cfg: Dictionary) -> Node:
	var raw_shape = cfg.get("shape", AbilityPipeline.HitboxShape.NONE)
	var shape_val = AbilityPipeline.parse_hitbox_shape(raw_shape)
	
	match shape_val:
		AbilityPipeline.HitboxShape.LINE:
			var hb = (load("res://ability/hitboxes/line_hitbox.gd") as GDScript).new()
			hb.length = cfg.get("length", 20.0)
			hb.width = cfg.get("width", 1.0)
			return hb
		AbilityPipeline.HitboxShape.SECTOR:
			var hb = (load("res://ability/hitboxes/sector_hitbox.gd") as GDScript).new()
			hb.radius = cfg.get("radius", 4.0)
			hb.angle_deg = cfg.get("angle", cfg.get("angle_deg", 90.0))
			hb.height = cfg.get("height", 2.5)
			return hb
		AbilityPipeline.HitboxShape.CIRCLE:
			var hb = (load("res://ability/hitboxes/circle_hitbox.gd") as GDScript).new()
			hb.radius = cfg.get("radius", 3.0)
			return hb
		AbilityPipeline.HitboxShape.CYLINDER:
			var hb = (load("res://ability/hitboxes/cylinder_hitbox.gd") as GDScript).new()
			hb.radius = cfg.get("radius", 4.0)
			hb.height = cfg.get("height", 3.0)
			return hb
		AbilityPipeline.HitboxShape.BOX:
			var hb = (load("res://ability/hitboxes/box_hitbox.gd") as GDScript).new()
			hb.width = cfg.get("width", 2.0)
			hb.length = cfg.get("length", 4.0)
			hb.height = cfg.get("height", 2.5)
			return hb
		AbilityPipeline.HitboxShape.DONUT:
			var hb = (load("res://ability/hitboxes/donut_hitbox.gd") as GDScript).new()
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
			trig = (load("res://ability/triggers/on_cast_trigger.gd") as GDScript).new()
		AbilityPipeline.TriggerType.ON_HIT_ENEMY:
			trig = (load("res://ability/triggers/on_hit_enemy_trigger.gd") as GDScript).new()
		AbilityPipeline.TriggerType.ON_HIT_WALL:
			trig = (load("res://ability/triggers/on_hit_wall_trigger.gd") as GDScript).new()
		AbilityPipeline.TriggerType.ON_REACH_DESTINATION:
			trig = (load("res://ability/triggers/on_reach_destination_trigger.gd") as GDScript).new()
		AbilityPipeline.TriggerType.ON_EXPIRE:
			trig = (load("res://ability/triggers/on_expire_trigger.gd") as GDScript).new()
		AbilityPipeline.TriggerType.ON_TICK:
			trig = (load("res://ability/triggers/on_tick_trigger.gd") as GDScript).new()
		AbilityPipeline.TriggerType.ON_CHANNEL_COMPLETE:
			trig = (load("res://ability/triggers/on_channel_complete_trigger.gd") as GDScript).new()
		_:
			trig = (load("res://ability/triggers/on_hit_enemy_trigger.gd") as GDScript).new()
	
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
			var r = (load("res://ability/riders/damage_rider.gd") as GDScript).new()
			r.amount = cfg.get("amount", cfg.get("damage", 0.0))
			return r
		AbilityPipeline.RiderType.STUN:
			var r = (load("res://ability/riders/stun_rider.gd") as GDScript).new()
			r.duration = cfg.get("duration", 0.5)
			return r
		AbilityPipeline.RiderType.BOUND:
			var r = (load("res://ability/riders/bound_rider.gd") as GDScript).new()
			r.duration = cfg.get("duration", 1.0)
			if cfg.has("custom_position"):
				r.custom_position = cfg["custom_position"]
				r.use_custom_position = true
			if cfg.has("buffer_offset"):
				r.buffer_offset = cfg["buffer_offset"]
			return r
		AbilityPipeline.RiderType.SLOW:
			var r = (load("res://ability/riders/slow_rider.gd") as GDScript).new()
			r.duration = cfg.get("duration", 2.0)
			r.intensity = cfg.get("intensity", 0.30)
			return r
		AbilityPipeline.RiderType.KNOCKBACK:
			var r = (load("res://ability/riders/knockback_rider.gd") as GDScript).new()
			r.amount = cfg.get("amount", 12.0)
			return r
		AbilityPipeline.RiderType.SHIELD:
			var r = (load("res://ability/riders/shield_rider.gd") as GDScript).new()
			r.amount = cfg.get("amount", 30.0)
			r.duration = cfg.get("duration", 4.0)
			return r
		AbilityPipeline.RiderType.SPEED_BOOST:
			var r = (load("res://ability/riders/speed_boost_rider.gd") as GDScript).new()
			r.duration = cfg.get("duration", 3.0)
			r.percent = cfg.get("intensity", cfg.get("percent", 0.30))
			return r
		AbilityPipeline.RiderType.EMPOWER:
			var r = (load("res://ability/riders/empower_rider.gd") as GDScript).new()
			r.bonus_damage = cfg.get("amount", cfg.get("bonus_damage", 0.0))
			return r
		AbilityPipeline.RiderType.ROOT, AbilityPipeline.RiderType.GROUND, AbilityPipeline.RiderType.SILENCE, \
		AbilityPipeline.RiderType.CRIPPLE, AbilityPipeline.RiderType.ETHEREAL, AbilityPipeline.RiderType.TETHER, \
		AbilityPipeline.RiderType.MS_STEAL:
			var r = (load("res://ability/riders/status_rider.gd") as GDScript).new()
			r.status_type = str(raw_type)
			r.duration = cfg.get("duration", 1.5)
			r.intensity = cfg.get("intensity", 0.0)
			return r
	return null
