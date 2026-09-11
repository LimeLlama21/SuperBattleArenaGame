class_name BoundRider
extends "res://ability/riders/ability_rider.gd"

@export var duration: float = 1.0
@export var custom_position: Vector3 = Vector3.ZERO
@export var use_custom_position: bool = false
@export var buffer_offset: float = 0.2

func _init() -> void:
	rider_name = "Bound"

func apply(caster: Node, target: Node, hit_data: Dictionary = {}) -> void:
	if not is_instance_valid(target) or not is_instance_valid(caster):
		return
	var relocate_pos = null
	if hit_data.has("relocate_pos"):
		relocate_pos = hit_data["relocate_pos"]
	elif use_custom_position:
		relocate_pos = custom_position

	var offset_val = buffer_offset
	if hit_data.has("buffer_offset"):
		offset_val = float(hit_data["buffer_offset"])

	if target.has_method("apply_bound"):
		target.apply_bound(caster, duration, relocate_pos, offset_val)
