class_name StunRider
extends "res://ability/riders/ability_rider.gd"

@export var duration: float = 0.5

func apply(_caster: Node, target: Node, _hit_data: Dictionary = {}) -> void:
	if not is_instance_valid(target):
		return
	if target.has_method("apply_stun"):
		target.apply_stun(duration)
