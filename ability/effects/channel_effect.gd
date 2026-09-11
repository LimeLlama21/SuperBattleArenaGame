class_name ChannelEffect
extends "res://ability/effects/ability_effect.gd"

@export var channel_duration: float = 2.0

func _init() -> void:
	effect_name = "Channel"

func execute_effect_server(caster: Node, origin: Vector3, direction: Vector3, target_pos: Vector3, charge_ratio: float = 0.0) -> void:
	setup()
	fire_trigger("OnCast", caster, null, {"charge_ratio": charge_ratio})
	if is_instance_valid(caster):
		if "is_channeling" in caster:
			caster.is_channeling = true
			caster.channel_timer = channel_duration
		var slot = slot_key if not slot_key.is_empty() else (get_parent().slot_key if get_parent() and "slot_key" in get_parent() else "R")
		if caster.has_method("start_channel"):
			caster.start_channel(slot, channel_duration, origin, direction, target_pos)

func execute_effect_client(caster: Node, origin: Vector3, direction: Vector3, target_pos: Vector3, _charge_ratio: float = 0.0) -> void:
	if is_instance_valid(caster):
		if "is_channeling" in caster:
			caster.is_channeling = true
			caster.channel_timer = channel_duration
		var slot = slot_key if not slot_key.is_empty() else (get_parent().slot_key if get_parent() and "slot_key" in get_parent() else "R")
		if caster.has_method("start_channel"):
			caster.start_channel(slot, channel_duration, origin, direction, target_pos)
