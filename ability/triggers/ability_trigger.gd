class_name AbilityTrigger
extends Node

const AbilityRiderClass = preload("res://ability/riders/ability_rider.gd")

@export var trigger_name: String = "Trigger"
@export var riders: Array = []

var rider_instances: Array = []

func _ready() -> void:
	setup()

func setup() -> void:
	if rider_instances.is_empty():
		for child in get_children():
			if child is AbilityRiderClass and not rider_instances.has(child):
				rider_instances.append(child)
	if rider_instances.is_empty() and not riders.is_empty():
		for rider_item in riders:
			if rider_item is Node:
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
