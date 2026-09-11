class_name StanceBlockEffect
extends "res://ability/effects/ability_effect.gd"

@export var mitigation_percent: float = 0.75
@export var block_duration: float = 3.0

func _init() -> void:
	effect_name = "StanceBlock"

func execute_effect_server(caster: Node, _origin: Vector3, _direction: Vector3, _target_pos: Vector3, charge_ratio: float = 0.0) -> void:
	setup()
	fire_trigger("OnCast", caster, null, {"charge_ratio": charge_ratio, "mitigation": mitigation_percent})
	if is_instance_valid(caster):
		if "is_blocking" in caster:
			caster.is_blocking = true
		if caster.has_method("sync_block_state"):
			caster.sync_block_state(true)
		if caster.has_method("start_block_stance"):
			caster.start_block_stance(block_duration)

func execute_effect_client(caster: Node, _origin: Vector3, _direction: Vector3, _target_pos: Vector3, _charge_ratio: float = 0.0) -> void:
	if is_instance_valid(caster):
		if "is_blocking" in caster:
			caster.is_blocking = true
		if caster.has_method("sync_block_state"):
			caster.sync_block_state(true)
		if caster.has_method("start_block_stance"):
			caster.start_block_stance(block_duration)
