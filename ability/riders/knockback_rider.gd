class_name KnockbackRider
extends "res://ability/riders/ability_rider.gd"

@export var amount: float = 12.0
@export var is_radial: bool = false

func apply(caster: Node, target: Node, hit_data: Dictionary = {}) -> void:
	if not is_instance_valid(target) or not target.has_method("apply_knockback"):
		return
	
	var dir = hit_data.get("direction", Vector3.ZERO)
	if is_radial or dir == Vector3.ZERO:
		if is_instance_valid(caster):
			dir = (target.global_position - caster.global_position).normalized()
	dir.y = 0.0
	if dir.length_squared() > 0.001:
		dir = dir.normalized()
	else:
		dir = Vector3.FORWARD
	
	target.apply_knockback(dir, amount)
