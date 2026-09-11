class_name BuffEffect
extends "res://ability/effects/ability_effect.gd"

@export var buff_name: String = "Buff"
@export var buff_duration: float = 3.0

func _init() -> void:
	effect_name = "Buff"

func execute_effect_server(caster: Node, _origin: Vector3, _direction: Vector3, _target_pos: Vector3, charge_ratio: float = 0.0) -> void:
	setup()
	fire_trigger("OnCast", caster, null, {"charge_ratio": charge_ratio, "buff_name": buff_name, "duration": buff_duration})
	if is_instance_valid(caster) and caster.has_method("on_buff_activated"):
		caster.on_buff_activated(buff_name, buff_duration)

func execute_effect_client(caster: Node, _origin: Vector3, _direction: Vector3, _target_pos: Vector3, _charge_ratio: float = 0.0) -> void:
	if is_instance_valid(caster) and caster.has_method("on_buff_activated"):
		caster.on_buff_activated(buff_name, buff_duration)
