class_name EmpowerRider
extends "res://ability/riders/ability_rider.gd"

@export var empower_name: String = "empower"
@export var bonus_damage: float = 0.0

func apply(caster: Node, _target: Node, hit_data: Dictionary = {}) -> void:
	apply_to_caster(caster, hit_data)

func apply_to_caster(caster: Node, _hit_data: Dictionary = {}) -> void:
	if not is_instance_valid(caster):
		return
	if "is_crush_empowered" in caster:
		caster.is_crush_empowered = true
	elif "is_overcharge_active" in caster:
		caster.is_overcharge_active = true
	elif caster.has_method("set_empowered"):
		caster.set_empowered(true)
