class_name DamageRider
extends "res://ability/riders/ability_rider.gd"

@export var amount: float = 0.0
@export var min_damage: float = -1.0
@export var max_damage: float = -1.0
@export var can_crit: bool = true
@export var crit_multiplier: float = AbilityPipeline.CRIT_DAMAGE_MULTIPLIER
@export var action_type: int = 0 # 0 = ATTACK, 1 = ABILITY, 2 = ULTIMATE

func apply(caster: Node, target: Node, hit_data: Dictionary = {}) -> void:
	if not is_instance_valid(target):
		return
	
	var final_damage = amount
	var charge_ratio = hit_data.get("charge_ratio", 0.0)
	var min_dmg = hit_data.get("min_damage", min_damage)
	var max_dmg = hit_data.get("max_damage", max_damage)
	if min_dmg >= 0.0 and max_dmg >= 0.0:
		final_damage = lerp(min_dmg, max_dmg, charge_ratio)
	
	var bonus_dmg = hit_data.get("bonus_damage", 0.0)
	final_damage += bonus_dmg
	
	if is_instance_valid(caster) and caster.has_method("deal_damage"):
		caster.deal_damage(target, final_damage, action_type)
	elif target.has_method("take_damage"):
		var caster_id = 0
		if is_instance_valid(caster):
			if "peer_id" in caster:
				caster_id = caster.peer_id
			elif str(caster.name).is_valid_int():
				caster_id = str(caster.name).to_int()
		target.take_damage(final_damage, caster_id, action_type)
