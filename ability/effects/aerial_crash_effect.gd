class_name AerialCrashEffect
extends "res://ability/effects/ability_effect.gd"

@export var leap_height: float = 8.0
@export var crash_radius: float = 4.0

func _init() -> void:
	effect_name = "AerialCrash"

func execute_effect_server(caster: Node, _origin: Vector3, _direction: Vector3, target_pos: Vector3, charge_ratio: float = 0.0) -> void:
	setup()
	fire_trigger("OnCast", caster, null, {"charge_ratio": charge_ratio, "target_pos": target_pos})
	if is_instance_valid(caster) and caster.has_method("execute_crash_down"):
		caster.execute_crash_down(target_pos)
	elif is_instance_valid(caster):
		caster.global_position = target_pos + Vector3(0, 0.2, 0)
	
	if hitbox_instance:
		var tree = caster.get_tree() if (is_instance_valid(caster) and caster.is_inside_tree()) else null
		var targets = hitbox_instance.get_targets_in_hitbox(caster, target_pos, Vector3.FORWARD, tree) if tree else []
		for t in targets:
			fire_trigger("OnHitEnemy", caster, t, {"target_pos": target_pos})

func execute_effect_client(caster: Node, _origin: Vector3, _direction: Vector3, target_pos: Vector3, _charge_ratio: float = 0.0) -> void:
	if is_instance_valid(caster) and caster.has_method("execute_crash_down"):
		caster.execute_crash_down(target_pos)
