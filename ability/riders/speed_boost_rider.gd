class_name SpeedBoostRider
extends "res://ability/riders/ability_rider.gd"

@export var duration: float = 3.0
@export var percent: float = 0.30
@export var apply_to_self: bool = true

func apply(caster: Node, target: Node, hit_data: Dictionary = {}) -> void:
	if apply_to_self:
		apply_to_caster(caster, hit_data)
	elif is_instance_valid(target) and target.has_method("apply_speed_boost"):
		target.apply_speed_boost(duration, percent)

func apply_to_caster(caster: Node, _hit_data: Dictionary = {}) -> void:
	if is_instance_valid(caster) and caster.has_method("apply_speed_boost"):
		caster.apply_speed_boost(duration, percent)
