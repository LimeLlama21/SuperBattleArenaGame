class_name DashEffect
extends "res://ability/effects/ability_effect.gd"

@export var impulse: float = 24.0

func _init() -> void:
	effect_name = "Dash"
	bypass_lockout = true
	cast_lockout = false
	move_lockout = false

func execute_effect_server(caster: Node, _origin: Vector3, direction: Vector3, _target_pos: Vector3, charge_ratio: float = 0.0) -> void:
	setup()
	fire_trigger("OnCast", caster, null, {"charge_ratio": charge_ratio})
	_apply_dash(caster, direction)

func execute_effect_client(caster: Node, _origin: Vector3, direction: Vector3, _target_pos: Vector3, _charge_ratio: float = 0.0) -> void:
	if not caster or not caster.is_multiplayer_authority():
		return
	_apply_dash(caster, direction)

func _apply_dash(caster: Node, direction: Vector3) -> void:
	if not is_instance_valid(caster) or not caster.has_method("apply_velocity_impulse"):
		return
	var dash_dir = direction
	dash_dir.y = 0.0
	if dash_dir.length_squared() < 0.001:
		dash_dir = -caster.global_transform.basis.z.normalized()
		dash_dir.y = 0.0
	dash_dir = dash_dir.normalized()
	
	var effective_impulse = impulse
	if caster.has_method("get_effective_dash_impulse"):
		effective_impulse = caster.get_effective_dash_impulse(impulse)
	
	caster.apply_velocity_impulse(Vector3(dash_dir.x * effective_impulse, 0, dash_dir.z * effective_impulse), true)
