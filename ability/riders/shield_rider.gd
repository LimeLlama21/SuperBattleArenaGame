class_name ShieldRider
extends "res://ability/riders/ability_rider.gd"

@export var amount: float = 30.0
@export var duration: float = 4.0
@export var apply_to_self: bool = true

func apply(caster: Node, target: Node, hit_data: Dictionary = {}) -> void:
	if apply_to_self:
		apply_to_caster(caster, hit_data)
	elif is_instance_valid(target) and target.has_method("add_shield"):
		target.add_shield(amount, duration)

func apply_to_caster(caster: Node, _hit_data: Dictionary = {}) -> void:
	if is_instance_valid(caster) and caster.has_method("add_shield"):
		caster.add_shield(amount, duration)
