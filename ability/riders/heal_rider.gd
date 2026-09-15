class_name HealRider
extends "res://ability/riders/ability_rider.gd"

@export var amount: float = 0.0
@export var percent: float = 0.0
@export var heal_missing_hp: bool = false
@export var scale_with_marks: bool = false
@export var min_missing_hp_percent: float = 0.11
@export var max_missing_hp_percent: float = 0.15
@export var apply_to_self: bool = true

func apply(caster: Node, target: Node, hit_data: Dictionary = {}) -> void:
	if apply_to_self:
		apply_to_caster(caster, hit_data, target)
	elif is_instance_valid(target):
		_execute_heal(target, 0, hit_data)

func apply_to_caster(caster: Node, hit_data: Dictionary = {}, target: Node = null) -> void:
	if not is_instance_valid(caster):
		return
	
	if scale_with_marks and hit_data.get("marks_healed", false):
		return
		
	var marks: int = 0
	if scale_with_marks:
		if hit_data.has("marks"):
			marks = int(hit_data["marks"])
		elif is_instance_valid(target) and "dive_marks_count" in target:
			marks = int(target.dive_marks_count)
		elif "dive_marks_count" in caster:
			marks = int(caster.dive_marks_count)
			
	var healed = _execute_heal(caster, marks, hit_data)
	if healed > 0.0 and scale_with_marks:
		hit_data["marks_healed"] = true

func _execute_heal(receiver: Node, marks: int = 0, _hit_data: Dictionary = {}) -> float:
	if not is_instance_valid(receiver) or not receiver.has_method("heal"):
		return 0.0
	if "is_dead" in receiver and receiver.is_dead:
		return 0.0
	
	var heal_val: float = amount
	var max_hp: float = float(receiver.get("max_health")) if "max_health" in receiver else 100.0
	var cur_hp: float = float(receiver.get("current_health")) if "current_health" in receiver else max_hp
	var missing_hp: float = max(0.0, max_hp - cur_hp)
	
	if scale_with_marks:
		if marks <= 0:
			return 0.0
		var pct = clamp(0.10 + float(marks) * 0.01, min_missing_hp_percent, max_missing_hp_percent)
		heal_val += missing_hp * pct
	elif heal_missing_hp:
		heal_val += missing_hp * percent
	elif percent > 0.0:
		heal_val += max_hp * percent
	
	if heal_val > 0.0:
		receiver.heal(heal_val)
	return heal_val
