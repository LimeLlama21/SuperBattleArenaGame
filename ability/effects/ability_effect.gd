class_name AbilityEffect
extends "res://ability/ability.gd"

const AbilityTriggerClass = preload("res://ability/triggers/ability_trigger.gd")
const AbilityRiderClass = preload("res://ability/riders/ability_rider.gd")

const SectorHitboxClass = preload("res://ability/hitboxes/sector_hitbox.gd")
const CylinderHitboxClass = preload("res://ability/hitboxes/cylinder_hitbox.gd")
const BoxHitboxClass = preload("res://ability/hitboxes/box_hitbox.gd")
const DonutHitboxClass = preload("res://ability/hitboxes/donut_hitbox.gd")
const LineHitboxClass = preload("res://ability/hitboxes/line_hitbox.gd")
const CircleHitboxClass = preload("res://ability/hitboxes/circle_hitbox.gd")

const DamageRiderClass = preload("res://ability/riders/damage_rider.gd")
const StunRiderClass = preload("res://ability/riders/stun_rider.gd")
const SlowRiderClass = preload("res://ability/riders/slow_rider.gd")
const ShieldRiderClass = preload("res://ability/riders/shield_rider.gd")
const KnockbackRiderClass = preload("res://ability/riders/knockback_rider.gd")
const EmpowerRiderClass = preload("res://ability/riders/empower_rider.gd")
const StatusRiderClass = preload("res://ability/riders/status_rider.gd")
const SpeedBoostRiderClass = preload("res://ability/riders/speed_boost_rider.gd")
const BoundRiderClass = preload("res://ability/riders/bound_rider.gd")
const HealRiderClass = preload("res://ability/riders/heal_rider.gd")

const OnHitEnemyTriggerClass = preload("res://ability/triggers/on_hit_enemy_trigger.gd")
const OnCastTriggerClass = preload("res://ability/triggers/on_cast_trigger.gd")

enum HitboxType {
	NONE,
	SECTOR,
	CYLINDER,
	BOX,
	DONUT,
	LINE,
	CIRCLE
}

@export_group("Pipeline Components")
@export var effect_name: String = "Effect"
@export var hitbox_type: HitboxType = HitboxType.NONE
@export var custom_hitbox: Variant = null
@export var triggers: Array = []
@export var riders: Array = []
@export var duration: float = 0.0

@export_group("Hitbox Settings")
@export var hitbox_radius: float = 0.0
@export var hitbox_length: float = 0.0
@export var hitbox_width: float = 0.0
@export var hitbox_height: float = 0.0
@export var hitbox_angle_deg: float = 0.0
@export var hitbox_inner_radius: float = 0.0
@export var hitbox_outer_radius: float = 0.0
@export var hitbox_annul: Variant = false

@export_group("Rider Settings")
@export var damage_amount: float = 0.0
@export var action_type: int = 0
@export var stun_duration: float = 0.0
@export var bound_duration: float = 0.0
@export var slow_duration: float = 0.0
@export var slow_intensity: float = 0.0
@export var shield_amount: float = 0.0
@export var shield_duration: float = 0.0
@export var shield_apply_to_self: bool = true
@export var knockback_amount: float = 0.0
@export var empower_bonus: float = 0.0
@export var status_type: String = ""
@export var status_duration: float = 0.0
@export var status_intensity: float = 0.0
@export var heal_amount: float = 0.0
@export var heal_percent: float = 0.0
@export var heal_missing_hp: bool = false
@export var heal_scale_with_marks: bool = false
@export var heal_min_missing_hp_pct: float = 0.11
@export var heal_max_missing_hp_pct: float = 0.15
@export var heal_apply_to_self: bool = true

var hitbox_instance = null
var trigger_instances: Array = []
var rider_instances: Array = []

func _ready() -> void:
	setup()

func setup() -> void:
	if not effect_instance:
		effect_instance = self
	current_charges = max_charges

	# Setup hitbox
	if not hitbox_instance:
		for child in get_children():
			if child is AbilityHitboxClass:
				hitbox_instance = child
				break
	if not hitbox_instance and custom_hitbox:
		if custom_hitbox is Node:
			hitbox_instance = custom_hitbox
		elif custom_hitbox is Script:
			hitbox_instance = custom_hitbox.new()
		elif custom_hitbox is PackedScene:
			hitbox_instance = custom_hitbox.instantiate()
	if not hitbox_instance:
		var effective_shape = hitbox_type
		if effective_shape == HitboxType.NONE:
			if effect_name == "MeleeStrike":
				effective_shape = HitboxType.SECTOR
			elif effect_name == "AreaZone":
				effective_shape = HitboxType.CYLINDER
			elif effect_name == "AerialCrash":
				effective_shape = HitboxType.CIRCLE
			elif effect_name == "ChargeSlam":
				effective_shape = HitboxType.BOX
			elif effect_name == "Projectile" and (delay > 0.0 or windup_time > 0.0 or hitbox_length > 0.0 or ("max_range" in self and self.max_range > 0.0)):
				effective_shape = HitboxType.LINE

		match effective_shape:
			HitboxType.SECTOR:
				hitbox_instance = SectorHitboxClass.new()
			HitboxType.CYLINDER:
				hitbox_instance = CylinderHitboxClass.new()
			HitboxType.BOX:
				hitbox_instance = BoxHitboxClass.new()
			HitboxType.DONUT:
				hitbox_instance = DonutHitboxClass.new()
			HitboxType.LINE:
				hitbox_instance = LineHitboxClass.new()
			HitboxType.CIRCLE:
				hitbox_instance = CircleHitboxClass.new()

	if hitbox_instance:
		if hitbox_radius > 0.0 and "radius" in hitbox_instance:
			hitbox_instance.radius = hitbox_radius
		elif "radius" in hitbox_instance and hitbox_instance.radius <= 0.0:
			if "radius" in self and self.radius > 0.0:
				hitbox_instance.radius = self.radius
			elif "crash_radius" in self and self.crash_radius > 0.0:
				hitbox_instance.radius = self.crash_radius
			else:
				hitbox_instance.radius = 4.0
		if hitbox_length > 0.0 and "length" in hitbox_instance:
			hitbox_instance.length = hitbox_length
		elif "length" in hitbox_instance and hitbox_instance.length <= 0.0:
			if "max_range" in self and self.max_range > 0.0:
				hitbox_instance.length = self.max_range
			else:
				hitbox_instance.length = 20.0
		if hitbox_width > 0.0 and "width" in hitbox_instance:
			hitbox_instance.width = hitbox_width
		elif "width" in hitbox_instance and hitbox_instance.width <= 0.0:
			if "projectile_size" in self and self.projectile_size > 0.0:
				hitbox_instance.width = max(1.0, self.projectile_size)
			else:
				hitbox_instance.width = 1.6
		if hitbox_height > 0.0 and "height" in hitbox_instance:
			hitbox_instance.height = hitbox_height
		elif "height" in hitbox_instance and hitbox_instance.height <= 0.0:
			hitbox_instance.height = 2.4
		if hitbox_angle_deg > 0.0 and "angle_deg" in hitbox_instance:
			hitbox_instance.angle_deg = hitbox_angle_deg
		elif "angle_deg" in hitbox_instance and hitbox_instance.angle_deg <= 0.0:
			hitbox_instance.angle_deg = 360.0 if hitbox_instance.shape_type == AbilityPipeline.HitboxShape.CIRCLE else 90.0
		if hitbox_inner_radius > 0.0 and "inner_radius" in hitbox_instance:
			hitbox_instance.inner_radius = hitbox_inner_radius
		if hitbox_outer_radius > 0.0 and "outer_radius" in hitbox_instance:
			hitbox_instance.outer_radius = hitbox_outer_radius
		if "annul" in hitbox_instance:
			hitbox_instance.annul = hitbox_annul
		if hitbox_instance.has_method("setup"):
			hitbox_instance.setup()

	# Setup riders
	if rider_instances.is_empty():
		for child in get_children():
			if child is AbilityRiderClass and not rider_instances.has(child):
				_apply_rider_overrides(child)
				rider_instances.append(child)
	if rider_instances.is_empty() and not riders.is_empty():
		for r_item in riders:
			var r_inst: Node = null
			if r_item is Node:
				r_inst = r_item
			elif r_item is Script:
				r_inst = r_item.new()
			elif r_item is PackedScene:
				r_inst = r_item.instantiate()
			if r_inst:
				_apply_rider_overrides(r_inst)
				rider_instances.append(r_inst)
	if rider_instances.is_empty():
		if damage_amount > 0.0:
			var dmg = DamageRiderClass.new()
			dmg.amount = damage_amount
			dmg.action_type = action_type
			rider_instances.append(dmg)
		if stun_duration > 0.0:
			var st = StunRiderClass.new()
			st.duration = stun_duration
			rider_instances.append(st)
		if bound_duration > 0.0:
			var bd = BoundRiderClass.new()
			bd.duration = bound_duration
			rider_instances.append(bd)
		if slow_duration > 0.0 or slow_intensity > 0.0:
			var sl = SlowRiderClass.new()
			sl.duration = slow_duration
			sl.intensity = slow_intensity
			rider_instances.append(sl)
		if shield_amount > 0.0:
			var sh = ShieldRiderClass.new()
			sh.amount = shield_amount
			sh.duration = shield_duration
			sh.apply_to_self = shield_apply_to_self
			rider_instances.append(sh)
		if knockback_amount > 0.0:
			var kb = KnockbackRiderClass.new()
			kb.amount = knockback_amount
			rider_instances.append(kb)
		if empower_bonus > 0.0:
			var emp = EmpowerRiderClass.new()
			emp.bonus_damage = empower_bonus
			rider_instances.append(emp)
		if not status_type.is_empty():
			var stt = StatusRiderClass.new()
			stt.status_type = status_type
			stt.duration = status_duration
			stt.intensity = status_intensity
			rider_instances.append(stt)
		if heal_amount > 0.0 or heal_percent > 0.0 or heal_scale_with_marks:
			var hl = HealRiderClass.new()
			hl.amount = heal_amount
			hl.percent = heal_percent
			hl.heal_missing_hp = heal_missing_hp
			hl.scale_with_marks = heal_scale_with_marks
			hl.min_missing_hp_percent = heal_min_missing_hp_pct
			hl.max_missing_hp_percent = heal_max_missing_hp_pct
			hl.apply_to_self = heal_apply_to_self
			rider_instances.append(hl)

	# Setup triggers
	if trigger_instances.is_empty():
		for child in get_children():
			if child is AbilityTriggerClass and not trigger_instances.has(child):
				trigger_instances.append(child)
	if trigger_instances.is_empty() and not triggers.is_empty():
		for t_item in triggers:
			var t_inst: Node = null
			if t_item is Node:
				t_inst = t_item
			elif t_item is Script:
				t_inst = t_item.new()
			elif t_item is PackedScene:
				t_inst = t_item.instantiate()
			if t_inst:
				trigger_instances.append(t_inst)
	if trigger_instances.is_empty():
		var def_trigger: Node = null
		if effect_name == "Dash" or effect_name == "Buff" or effect_name == "Crowstorm" or (hitbox_instance == null and hitbox_type == HitboxType.NONE):
			def_trigger = OnCastTriggerClass.new()
		else:
			def_trigger = OnHitEnemyTriggerClass.new()
		trigger_instances.append(def_trigger)

	# Wire riders into triggers
	for trig in trigger_instances:
		if trig and "rider_instances" in trig:
			if trig.rider_instances.is_empty():
				for r_inst in rider_instances:
					if not trig.rider_instances.has(r_inst):
						trig.rider_instances.append(r_inst)
		if trig and trig.has_method("setup"):
			trig.setup()

func get_hitbox() -> Variant:
	if hitbox_instance != null:
		return hitbox_instance
	return hitbox

func _apply_rider_overrides(r_inst: Node) -> void:
	if r_inst is DamageRiderClass:
		if damage_amount > 0.0:
			r_inst.amount = damage_amount
		if action_type > 0:
			r_inst.action_type = action_type
	elif r_inst is StunRiderClass:
		if stun_duration > 0.0:
			r_inst.duration = stun_duration
	elif r_inst is BoundRiderClass:
		if bound_duration > 0.0:
			r_inst.duration = bound_duration
	elif r_inst is SlowRiderClass:
		if slow_duration > 0.0:
			r_inst.duration = slow_duration
		if slow_intensity > 0.0:
			r_inst.intensity = slow_intensity
	elif r_inst is ShieldRiderClass:
		if shield_amount > 0.0:
			r_inst.amount = shield_amount
		if shield_duration > 0.0:
			r_inst.duration = shield_duration
		r_inst.apply_to_self = shield_apply_to_self
	elif r_inst is KnockbackRiderClass:
		if knockback_amount > 0.0:
			r_inst.amount = knockback_amount
	elif r_inst is EmpowerRiderClass:
		if empower_bonus > 0.0:
			r_inst.bonus_damage = empower_bonus
	elif r_inst is StatusRiderClass:
		if not status_type.is_empty():
			r_inst.status_type = status_type
		if status_duration > 0.0:
			r_inst.duration = status_duration
		if status_intensity > 0.0:
			r_inst.intensity = status_intensity
	elif r_inst is HealRiderClass:
		if heal_amount > 0.0:
			r_inst.amount = heal_amount
		if heal_percent > 0.0:
			r_inst.percent = heal_percent
		if heal_missing_hp:
			r_inst.heal_missing_hp = true
		if heal_scale_with_marks:
			r_inst.scale_with_marks = true
			r_inst.min_missing_hp_percent = heal_min_missing_hp_pct
			r_inst.max_missing_hp_percent = heal_max_missing_hp_pct
		r_inst.apply_to_self = heal_apply_to_self

func _execute_server_effect(caster: Node, origin: Vector3, direction: Vector3, target_pos: Vector3, charge_ratio: float = 0.0) -> void:
	execute_effect_server(caster, origin, direction, target_pos, charge_ratio)

func _execute_client_effect(caster: Node, origin: Vector3, direction: Vector3, target_pos: Vector3, charge_ratio: float = 0.0) -> void:
	execute_effect_client(caster, origin, direction, target_pos, charge_ratio)

func execute_effect_server(_caster: Node, _origin: Vector3, _direction: Vector3, _target_pos: Vector3, _charge_ratio: float = 0.0) -> void:
	pass

func execute_effect_client(_caster: Node, _origin: Vector3, _direction: Vector3, _target_pos: Vector3, _charge_ratio: float = 0.0) -> void:
	pass

func execute_server(caster: Node, origin: Vector3, direction: Vector3, target_pos: Vector3, charge_ratio: float = 0.0) -> void:
	super.execute_server(caster, origin, direction, target_pos, charge_ratio)

func execute_client(caster: Node, origin: Vector3, direction: Vector3, target_pos: Vector3, charge_ratio: float = 0.0) -> void:
	super.execute_client(caster, origin, direction, target_pos, charge_ratio)

func fire_trigger(type_name: String, caster: Node, target: Node = null, hit_data: Dictionary = {}) -> void:
	setup()
	if not hit_data.has("ability_id") and not ability_id.is_empty():
		hit_data["ability_id"] = ability_id
	if not hit_data.has("slot_key") and not slot_key.is_empty():
		hit_data["slot_key"] = slot_key
	if not hit_data.has("min_damage") and min_damage > 0.0:
		hit_data["min_damage"] = min_damage
	if not hit_data.has("max_damage") and max_damage > 0.0:
		hit_data["max_damage"] = max_damage
	for trig in trigger_instances:
		if trig and trig.trigger_name.to_upper() == type_name.to_upper():
			trig.fire(caster, target, hit_data)
