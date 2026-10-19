class_name StatusRider
extends "res://ability/riders/ability_rider.gd"

@export var status_type: String = "ROOT" # ROOT, SILENCE, GROUND, CRIPPLE, ETHEREAL, TETHER, MS_STEAL, TAUNT, FEAR, BLEED
@export var duration: float = 1.5
@export var intensity: float = 0.0

func apply(caster: Node, target: Node, _hit_data: Dictionary = {}) -> void:
	if not is_instance_valid(target):
		return

	# First try generic status API if supported
	var st = status_type.to_upper()
	if st == "MS_STEAL":
		var steal_amount = intensity if intensity > 0.0 else 0.15
		if target.has_method("apply_slow"):
			target.apply_slow(duration, steal_amount)
		if is_instance_valid(caster) and caster.has_method("apply_speed_boost"):
			caster.apply_speed_boost(duration, steal_amount)
		return
	elif st == "TETHER":
		if target.has_method("apply_grounded"): target.apply_grounded(duration)
		if target.has_method("apply_slow"): target.apply_slow(duration, 0.25)
		if target.has_method("apply_root"): target.apply_root(duration)
		return
	elif st == "TAUNT":
		if target.has_method("apply_taunt"):
			var dr = intensity if intensity > 0.0 else 0.35
			target.apply_taunt(caster, duration, dr)
		return
	elif st == "BOUND":
		if target.has_method("apply_bound"):
			target.apply_bound(caster, duration)
		return

	# Standard CC types
	match st:
		"ROOT":
			if target.has_method("apply_root"): target.apply_root(duration)
		"SILENCE":
			if target.has_method("apply_silence"): target.apply_silence(duration)
		"GROUND", "GROUNDED":
			if target.has_method("apply_grounded"): target.apply_grounded(duration)
		"CRIPPLE":
			if target.has_method("apply_cripple"): target.apply_cripple(duration, intensity if intensity > 0.0 else 0.35)
		"ETHEREAL":
			if target.has_method("apply_ethereal"): target.apply_ethereal(duration)
		"INVISIBILITY", "INVISIBLE":
			if target.has_method("apply_invisibility"): target.apply_invisibility(duration)
		"INVULNERABLE", "STONE_MONKEY":
			if target.has_method("apply_invulnerability"): target.apply_invulnerability(duration)
		"FEAR":
			if target.has_method("apply_fear") and is_instance_valid(caster):
				target.apply_fear(caster, caster.global_position, duration)
		"BLIND":
			if target.has_method("apply_blind"): target.apply_blind(duration)
		_:
			if target.has_method("apply_status_by_name"):
				target.apply_status_by_name(status_type.to_lower(), duration, intensity, caster)

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
			elif caster.has_method("cleanse_cc"): caster.cleanse_cc()
		"INVISIBILITY", "INVISIBLE":
			if caster.has_method("apply_invisibility"): caster.apply_invisibility(duration)
		"INVULNERABLE", "STONE_MONKEY":
			if caster.has_method("apply_invulnerability"): caster.apply_invulnerability(duration)
		"TRANSFORMATION":
			if caster.has_method("apply_transformation"):
				caster.apply_transformation("tree", {"can_move": true, "can_dash": true, "break_on_attack": true, "break_on_damage": true})
		_:
			if caster.has_method("apply_status_by_name"):
				caster.apply_status_by_name(status_type.to_lower(), duration, intensity, caster)
