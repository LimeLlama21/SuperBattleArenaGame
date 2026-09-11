class_name StatusRider
extends "res://ability/riders/ability_rider.gd"

@export var status_type: String = "ROOT" # ROOT, SILENCE, GROUND, CRIPPLE, ETHEREAL, TETHER, MS_STEAL
@export var duration: float = 1.5
@export var intensity: float = 0.0

func apply(caster: Node, target: Node, _hit_data: Dictionary = {}) -> void:
	if not is_instance_valid(target):
		return
	
	match status_type.to_upper():
		"ROOT":
			if target.has_method("apply_root"): target.apply_root(duration)
		"SILENCE":
			if target.has_method("apply_silence"): target.apply_silence(duration)
		"GROUND", "GROUNDED":
			if target.has_method("apply_grounded"): target.apply_grounded(duration)
		"CRIPPLE":
			if target.has_method("apply_cripple"): target.apply_cripple(duration)
		"ETHEREAL":
			if target.has_method("apply_ethereal"): target.apply_ethereal(duration)
		"MS_STEAL":
			var steal_amount = intensity if intensity > 0.0 else 0.15
			if target.has_method("apply_slow"):
				target.apply_slow(duration, steal_amount)
			if is_instance_valid(caster) and caster.has_method("apply_speed_boost"):
				caster.apply_speed_boost(duration, steal_amount)
		"TETHER":
			if target.has_method("apply_grounded"): target.apply_grounded(duration)
			if target.has_method("apply_slow"): target.apply_slow(duration, 0.25)
			if target.has_method("apply_root"): target.apply_root(duration)
		"TAUNT":
			if target.has_method("apply_taunt"):
				var dr = intensity if intensity > 0.0 else 0.35
				target.apply_taunt(caster, duration, dr)
		"INVISIBILITY", "INVISIBLE":
			if target.has_method("apply_invisibility"): target.apply_invisibility(duration)
		"INVULNERABLE", "STONE_MONKEY":
			if target.has_method("apply_invulnerability"): target.apply_invulnerability(duration)
		"BOUND":
			if target.has_method("apply_bound"):
				target.apply_bound(caster, duration)

func apply_to_caster(caster: Node, _hit_data: Dictionary = {}) -> void:
	if not is_instance_valid(caster):
		return
	match status_type.to_upper():
		"ETHEREAL":
			if caster.has_method("apply_ethereal"): caster.apply_ethereal(duration)
		"SPEED_BOOST":
			if caster.has_method("apply_speed_boost"): caster.apply_speed_boost(duration, intensity)
		"CLEANSE":
			if caster.has_method("apply_cleanse"): caster.apply_cleanse()
		"INVISIBILITY", "INVISIBLE":
			if caster.has_method("apply_invisibility"): caster.apply_invisibility(duration)
		"INVULNERABLE", "STONE_MONKEY":
			if caster.has_method("apply_invulnerability"): caster.apply_invulnerability(duration)
		"TRANSFORMATION":
			if caster.has_method("apply_transformation"):
				caster.apply_transformation("tree", {"can_move": true, "can_dash": true, "break_on_attack": true, "break_on_damage": true})

