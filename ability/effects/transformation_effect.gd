class_name TransformationEffect
extends "res://ability/effects/ability_effect.gd"

@export var default_prop_type: String = "tree"
@export var can_move: bool = true
@export var can_dash: bool = true
@export var break_on_attack: bool = true
@export var break_on_damage: bool = true

func _init() -> void:
	effect_name = "Transformation"

func execute_effect_server(caster: Node, _origin: Vector3, _direction: Vector3, _target_pos: Vector3, charge_ratio: float = 0.0) -> void:
	setup()
	var props = {
		"can_move": can_move,
		"can_dash": can_dash,
		"break_on_attack": break_on_attack,
		"break_on_damage": break_on_damage
	}
	fire_trigger("OnCast", caster, null, {"charge_ratio": charge_ratio, "prop_type": default_prop_type, "properties": props})
	if is_instance_valid(caster) and caster.has_method("apply_transformation"):
		var selected_prop = default_prop_type
		if "pending_prop_type" in caster and not caster.pending_prop_type.is_empty():
			selected_prop = caster.pending_prop_type
		caster.apply_transformation(selected_prop, props)

func execute_effect_client(caster: Node, _origin: Vector3, _direction: Vector3, _target_pos: Vector3, _charge_ratio: float = 0.0) -> void:
	var props = {
		"can_move": can_move,
		"can_dash": can_dash,
		"break_on_attack": break_on_attack,
		"break_on_damage": break_on_damage
	}
	if is_instance_valid(caster) and caster.has_method("apply_transformation"):
		var selected_prop = default_prop_type
		if "pending_prop_type" in caster and not caster.pending_prop_type.is_empty():
			selected_prop = caster.pending_prop_type
		caster.apply_transformation(selected_prop, props)
