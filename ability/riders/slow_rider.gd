class_name SlowRider
extends "res://ability/riders/ability_rider.gd"

@export var duration: float = 2.0
@export var intensity: float = 0.30

func apply(_caster: Node, target: Node, _hit_data: Dictionary = {}) -> void:
	if not is_instance_valid(target):
		return
	if target.has_method("apply_slow"):
		target.apply_slow(duration, intensity)
