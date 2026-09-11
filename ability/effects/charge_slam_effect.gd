class_name ChargeSlamEffect
extends "res://ability/effects/ability_effect.gd"

@export var charge_speed: float = 28.0
@export var charge_duration: float = 1.0

func _init() -> void:
	effect_name = "ChargeSlam"

func execute_effect_server(caster: Node, _origin: Vector3, direction: Vector3, _target_pos: Vector3, charge_ratio: float = 0.0) -> void:
	setup()
	fire_trigger("OnCast", caster, null, {"charge_ratio": charge_ratio})
	if is_instance_valid(caster):
		if "is_crush_charging" in caster:
			caster.is_crush_charging = true
			caster.crush_charge_timer = charge_duration
			caster.crush_charge_dir = direction
		if caster.has_method("start_juggernaut_charge"):
			caster.start_juggernaut_charge(direction, charge_duration, charge_speed)

func execute_effect_client(caster: Node, _origin: Vector3, direction: Vector3, _target_pos: Vector3, _charge_ratio: float = 0.0) -> void:
	if is_instance_valid(caster):
		if "is_crush_charging" in caster:
			caster.is_crush_charging = true
			caster.crush_charge_timer = charge_duration
			caster.crush_charge_dir = direction
		if caster.has_method("start_juggernaut_charge"):
			caster.start_juggernaut_charge(direction, charge_duration, charge_speed)
