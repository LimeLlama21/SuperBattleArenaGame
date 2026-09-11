class_name AreaZoneEffect
extends "res://ability/effects/ability_effect.gd"

@export var radius: float = 4.0
@export var zone_duration: float = 3.0
@export var tick_interval: float = 0.5
@export var zone_type: String = "general"

func _init() -> void:
	effect_name = "AreaZone"

func execute_effect_server(caster: Node, _origin: Vector3, _direction: Vector3, target_pos: Vector3, charge_ratio: float = 0.0) -> void:
	setup()
	fire_trigger("OnCast", caster, null, {"charge_ratio": charge_ratio, "target_pos": target_pos})
	
	var tree = caster.get_tree() if (is_instance_valid(caster) and caster.is_inside_tree()) else null
	var main_node = tree.root.get_node_or_null("Main") if (tree and tree.root) else null
	var shooter_id = caster.peer_id if (is_instance_valid(caster) and "peer_id" in caster) else 0
	var shooter_team = caster.team_id if (is_instance_valid(caster) and "team_id" in caster) else 0
	var ab_parent = get_parent()
	var ab_id = ability_id if not ability_id.is_empty() else (ab_parent.get("ability_id") if (ab_parent and "ability_id" in ab_parent) else "")

	if main_node:
		if zone_type == "fence" or ab_id == "poke_ion_fence" or ab_id.contains("fence"):
			var rot_y = caster.rotation.y if is_instance_valid(caster) else 0.0
			var fence_width = 8.0
			if hitbox_instance and "width" in hitbox_instance:
				fence_width = hitbox_instance.width
			main_node.spawn_fence_zone(target_pos, rot_y, fence_width, 2.6, 0.25, zone_duration, 2.5, shooter_id, shooter_team)
		elif zone_type == "slowing_dot" or ab_id.contains("mortar") or ab_id.contains("omen"):
			main_node.spawn_slowing_dot_zone(target_pos, radius, zone_duration, 15.0, 0.40, shooter_id, shooter_team)
		elif zone_type == "orbital_laser" or ab_id.contains("orbital"):
			main_node.spawn_orbital_laser_zone(target_pos, radius, 1.5, zone_duration, 85.0, 35.0, shooter_id, shooter_team)

	if hitbox_instance:
		var targets = hitbox_instance.get_targets_in_hitbox(caster, target_pos, Vector3.FORWARD, tree) if tree else []
		for target in targets:
			fire_trigger("OnHitEnemy", caster, target, {"target_pos": target_pos})
