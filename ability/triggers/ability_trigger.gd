class_name AbilityTrigger
extends RefCounted

const AbilityRiderClass = preload("res://ability/riders/ability_rider.gd")

var trigger_name: String = "Trigger"
var riders: Array = []
var rider_instances: Array = []

func setup() -> void:
	if rider_instances.is_empty() and not riders.is_empty():
		for rider_item in riders:
			if rider_item is AbilityRiderClass or rider_item is RefCounted or rider_item is Node:
				rider_instances.append(rider_item)
			elif rider_item is Script:
				rider_instances.append(rider_item.new())
			elif rider_item is PackedScene:
				var inst = rider_item.instantiate()
				if inst:
					rider_instances.append(inst)

func fire(caster: Node, target: Node = null, hit_data: Dictionary = {}) -> void:
	setup()
	for rider in rider_instances:
		if is_instance_valid(target):
			rider.apply(caster, target, hit_data)
		else:
			rider.apply_to_caster(caster, hit_data)
