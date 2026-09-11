class_name ProjectileEffect
extends "res://ability/effects/ability_effect.gd"

@export var speed: float = 70.0
@export var max_range: float = 25.0
@export var projectile_size: float = 0.5
@export var pierces: bool = false
@export var custom_effect_type: String = ""
@export var base_damage: float = 30.0

func _init() -> void:
	effect_name = "Projectile"

func execute_effect_server(caster: Node, origin: Vector3, direction: Vector3, _target_pos: Vector3, charge_ratio: float = 0.0) -> void:
	setup()
	fire_trigger("OnCast", caster, null, {"charge_ratio": charge_ratio})
	
	var tree = caster.get_tree() if caster else get_tree()
	var main_node = tree.root.get_node_or_null("Main") if (tree and tree.root) else null
	if not main_node or not main_node.has_method("spawn_projectile"):
		return
	
	var final_damage = damage_amount if damage_amount > 0.0 else base_damage
	var eff_type = custom_effect_type
	var eff_dur = 0.0
	var eff_int = 0.0
	var spawn_terr = false
	var act_type = 0

	var slot = slot_key
	var ab_id = ability_id
	var ab_parent = get_parent()
	if ab_parent:
		if slot.is_empty() and "slot_key" in ab_parent:
			slot = ab_parent.slot_key
		if ab_id.is_empty() and "ability_id" in ab_parent:
			ab_id = ab_parent.ability_id
	
	if slot == "R":
		act_type = 2
	elif slot != "LMB" and not slot.is_empty():
		act_type = 1
	
	if eff_type.is_empty():
		if ab_id == "poke_sniper_stance":
			eff_type = "poke_sniper_empowered" if (is_instance_valid(caster) and caster.get("is_overcharge_active") == true) else "poke_sniper_laser"
		elif ab_id == "poke_orbital_hyperbeam":
			eff_type = "poke_orbital_hyperbeam"
		elif ab_id == "dive_earth_tremor":
			eff_type = "dive_earth_tremor"
		elif ab_id == "reaper_tether":
			eff_type = "reaper_tether"
		elif ab_id == "morrigan_black_plumage":
			eff_type = "morrigan_feather"
		elif ab_id == "morrigan_omen_of_death":
			eff_type = "mortar_shell"
		elif ab_id == "morrigan_inescapable_ends":
			eff_type = "morrigan_tether_first"
		elif ab_id == "morrigan_born_of_blood":
			eff_type = "blood_wave"
		else:
			eff_type = ab_id
	elif eff_type == "poke_sniper_laser" and is_instance_valid(caster) and caster.get("is_overcharge_active") == true:
		eff_type = "poke_sniper_empowered"

	# If riders exist, extract damage and status parameters
	for trig in trigger_instances:
		if trig.trigger_name.to_upper() in ["ONHITENEMY", "ONHIT"]:
			for r in trig.rider_instances:
				if "amount" in r and r.amount > 0.0:
					final_damage = r.amount
				if "duration" in r and r.duration > 0.0:
					eff_dur = r.duration
				if "intensity" in r and r.intensity > 0.0:
					eff_int = r.intensity
				if "rider_name" in r and r.rider_name.to_upper() in ["SPAWNTERRAIN", "TERRAIN"]:
					spawn_terr = true
	
	if eff_type == "dive_earth_tremor":
		spawn_terr = true
		eff_dur = 2.0
		eff_int = 0.40

	if is_charge_ability() or min_damage > 0.0 or max_damage > 0.0:
		var min_dmg = min_damage if min_damage > 0.0 else (final_damage * 0.5)
		var max_dmg = max_damage if max_damage > 0.0 else final_damage
		final_damage = lerp(min_dmg, max_dmg, charge_ratio)
	elif charge_ratio > 0.0:
		final_damage = lerp(final_damage * 0.5, final_damage, charge_ratio)
	
	var shooter_id = caster.peer_id if (is_instance_valid(caster) and "peer_id" in caster) else 0
	var shooter_team = caster.team_id if (is_instance_valid(caster) and "team_id" in caster) else 0
	var lifetime = max_range / max(1.0, speed)
	
	main_node.spawn_projectile(
		origin,
		direction,
		shooter_id,
		final_damage,
		speed,
		projectile_size,
		lifetime,
		eff_type,
		eff_dur,
		eff_int,
		pierces,
		spawn_terr,
		shooter_team,
		act_type,
		max_range
	)
