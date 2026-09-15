class_name CombatHitbox
extends Area3D

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

func take_damage(amount: float, attacker_id: int = 0, action_type: int = 0) -> void:
	var target = get_character()
	if is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(amount, attacker_id, action_type)

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

func apply_speed_boost(duration: float, percent: float) -> void:
	var target = get_character()
	if is_instance_valid(target) and target.has_method("apply_speed_boost"):
		target.apply_speed_boost(duration, percent)

func apply_rupture_mark(attacker_id: int) -> void:
	var target = get_character()
	if is_instance_valid(target) and target.has_method("apply_rupture_mark"):
		target.apply_rupture_mark(attacker_id)

func detonate_dive_marks(attacker: Node = null) -> int:
	var target = get_character()
	if is_instance_valid(target) and target.has_method("detonate_dive_marks"):
		return target.detonate_dive_marks(attacker)
	return 0
