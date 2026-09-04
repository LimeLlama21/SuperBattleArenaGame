class_name DefaultPlayer
extends BasePlayer

# Base Prototype Shooting & Dash Parameters
@export var dash_impulse: float = 26.0
@export var dash_cooldown: float = 0.75
@export var shoot_cooldown: float = 0.25
@export var projectile_damage: float = 50.0
@export var projectile_speed: float = 70.0
@export var projectile_size: float = 1.0

var dash_timer: float = 0.0
var shoot_timer: float = 0.0

func _setup_character_kit() -> void:
	character_name = "Player"

func _process_character_kit(delta: float) -> void:
	if dash_timer > 0.0:
		dash_timer -= delta
	if shoot_timer > 0.0:
		shoot_timer -= delta

func _handle_character_input(_delta: float) -> void:
	# Dash Impulse Injection (Momentum-based, reduced by slows)
	if Input.is_action_just_pressed("dash") and dash_timer <= 0.0 and not is_rooted() and not is_grounded():
		dash_timer = dash_cooldown
		var dash_dir = get_dash_direction()
		var effective_impulse = get_effective_dash_impulse(dash_impulse)
		apply_velocity_impulse(dash_dir * effective_impulse, true)

	# Shooting
	if Input.is_action_pressed("shoot") and shoot_timer <= 0.0 and not is_silenced():
		shoot_timer = shoot_cooldown
		var facing_dir = -global_transform.basis.z.normalized()
		facing_dir.y = 0.0
		facing_dir = facing_dir.normalized()
		var spawn_pos = global_position + Vector3(0, 0.8, 0) + facing_dir * 1.0
		var shoot_dir = get_ranged_aim_direction(spawn_pos)
		
		if is_server_authoritative():
			var main_node = get_tree().root.get_node_or_null("Main")
			if main_node and main_node.has_method("spawn_projectile"):
				main_node.spawn_projectile(spawn_pos, shoot_dir, name.to_int(), projectile_damage, projectile_speed, projectile_size)
		else:
			request_fire.rpc_id(1, spawn_pos, shoot_dir, projectile_damage, projectile_speed, projectile_size)

@rpc("any_peer", "call_remote", "reliable")
func request_fire(spawn_pos: Vector3, shoot_dir: Vector3, dmg: float, spd: float, p_size: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node and main_node.has_method("spawn_projectile"):
		main_node.spawn_projectile(spawn_pos, shoot_dir, sender_id, dmg, spd, p_size)
