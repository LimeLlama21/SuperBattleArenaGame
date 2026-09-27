extends Node3D

var damage_received: float = 0.0
var last_attacker_id: int = -1
var last_action_type: int = -1
var is_dead: bool = false

func take_damage(amount: float, attacker_id: int = 0, action_type: int = 0) -> void:
	damage_received += amount
	last_attacker_id = attacker_id
	last_action_type = action_type
