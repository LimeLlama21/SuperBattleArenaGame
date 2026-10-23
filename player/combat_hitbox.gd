class_name CombatHitbox
extends Area3D

## CombatHitbox - Standardized hurtbox component attached to actors
## Receives incoming combat interactions (damage, knockback, status effects)
## and dispatches them uniformly to the parent entity.

var character: Node = null

func _ready() -> void:
	if not character:
		character = get_parent()

func get_character() -> Node:
	return character if is_instance_valid(character) else get_parent()

func get_hitbox_radius() -> float:
	var cs = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs and cs.shape and "radius" in cs.shape:
		return cs.shape.radius
	var target = get_character()
	if is_instance_valid(target) and target.has_method("get_hitbox_radius"):
		return target.get_hitbox_radius()
	return 0.4

# --- Damage Application ---

func take_damage(amount: float, attacker_id: int = 0, action_type: int = 0, is_projectile: bool = false, damage_type: int = 0) -> void:
	var target = get_character()
	if is_instance_valid(target) and target.has_method("take_damage"):
		if target is BasePlayer or ("is_neutral" in target and target.is_neutral):
			target.take_damage(amount, attacker_id, action_type, is_projectile, damage_type)
		else:
			target.take_damage(amount, attacker_id, action_type)

# --- Generic Status Effect Object API ---

func apply_status_effect(effect: StatusEffect) -> void:
	var target = get_character()
	if is_instance_valid(target):
		if target.has_method("apply_status_effect"):
			target.apply_status_effect(effect)
		elif target.has_method("apply_status"):
			target.apply_status(effect)

func apply_status_by_name(status_type: String, duration: float, intensity: float = 0.0, source: Node = null, params: Dictionary = {}) -> void:
	var target = get_character()
	if is_instance_valid(target):
		if target.has_method("apply_status_by_name"):
			target.apply_status_by_name(status_type, duration, intensity, source, params)
		else:
			var meth = "apply_" + status_type.to_lower()
			if target.has_method(meth):
				target.call(meth, duration)

# --- Concrete Status & Crowd Control Application ---

func apply_stun(duration: float) -> void:
	var target = get_character()
	if is_instance_valid(target) and target.has_method("apply_stun"):
		target.apply_stun(duration)

func apply_bound(caster: Node, duration: float, custom_relocate_pos: Variant = null, buffer_offset: float = 0.2) -> void:
	var target = get_character()
	if is_instance_valid(target) and target.has_method("apply_bound"):
		target.apply_bound(caster, duration, custom_relocate_pos, buffer_offset)

func apply_slow(duration: float, percent: float) -> void:
	var target = get_character()
	if is_instance_valid(target) and target.has_method("apply_slow"):
		target.apply_slow(duration, percent)

func apply_knockback(impulse: Vector3, is_external: bool = true, wall_stun: float = 0.0) -> void:
	var target = get_character()
	if is_instance_valid(target) and target.has_method("apply_knockback"):
		target.apply_knockback(impulse, is_external, wall_stun)

func apply_silence(duration: float) -> void:
	var target = get_character()
	if is_instance_valid(target) and target.has_method("apply_silence"):
		target.apply_silence(duration)

func apply_root(duration: float) -> void:
	var target = get_character()
	if is_instance_valid(target) and target.has_method("apply_root"):
		target.apply_root(duration)

func apply_grounded(duration: float) -> void:
	var target = get_character()
	if is_instance_valid(target) and target.has_method("apply_grounded"):
		target.apply_grounded(duration)

func apply_cripple(duration: float, intensity: float = 0.35) -> void:
	var target = get_character()
	if is_instance_valid(target) and target.has_method("apply_cripple"):
		target.apply_cripple(duration, intensity)

func apply_ethereal(duration: float) -> void:
	var target = get_character()
	if is_instance_valid(target) and target.has_method("apply_ethereal"):
		target.apply_ethereal(duration)

func apply_fear(arg1: Variant = 1.0, arg2: Variant = null, arg3: Variant = null) -> void:
	var target = get_character()
	if is_instance_valid(target) and target.has_method("apply_fear"):
		target.apply_fear(arg1, arg2, arg3)

func apply_blind(duration: float) -> void:
	var target = get_character()
	if is_instance_valid(target) and target.has_method("apply_blind"):
		target.apply_blind(duration)

func apply_bleed(arg1: Variant = 0.0, arg2: Variant = 5.0, arg3: Variant = 0) -> void:
	var target = get_character()
	if is_instance_valid(target) and target.has_method("apply_bleed"):
		target.apply_bleed(arg1, arg2, arg3)

func apply_speed_boost(duration: float, percent: float) -> void:
	var target = get_character()
	if is_instance_valid(target) and target.has_method("apply_speed_boost"):
		target.apply_speed_boost(duration, percent)

# --- Backward-Compatibility Character Passives Adapters ---

func apply_rupture_mark(attacker_id: int) -> void:
	var target = get_character()
	if is_instance_valid(target) and target.has_method("apply_rupture_mark"):
		target.apply_rupture_mark(attacker_id)

func detonate_dive_marks(attacker: Node = null) -> int:
	var target = get_character()
	if is_instance_valid(target) and target.has_method("detonate_dive_marks"):
		return target.detonate_dive_marks(attacker)
	return 0

func apply_ink(duration: float, slow_pct: float = 0.20, source_id: int = 0) -> void:
	var target = get_character()
	if is_instance_valid(target) and target.has_method("apply_ink"):
		target.apply_ink(duration, slow_pct, source_id)

func is_inked() -> bool:
	var target = get_character()
	if is_instance_valid(target) and target.has_method("is_inked"):
		return target.is_inked()
	return false
