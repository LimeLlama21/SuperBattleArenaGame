class_name Crush
extends BasePlayer

# Gray Health / Iron Blood
var gray_health: float = 0.0:
	set(value):
		gray_health = max(0.0, value)
		update_health_bar()
var time_since_last_damage: float = 0.0

# Titan Surge Empowerment
var is_crush_empowered: bool = false

# Juggernaut Charge (Ultimate)
var is_crush_charging: bool = false
var crush_charge_timer: float = 0.0
var crush_charge_dir: Vector3 = Vector3.FORWARD
const CRUSH_CHARGE_DURATION: float = 1.0
const CRUSH_CHARGE_SPEED: float = 28.0
const CRUSH_CHARGE_TURN_SPEED: float = 1.8

func _setup_character_kit() -> void:
	var data = CrushData.create()
	load_character_data(data)

	var sync = get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	if sync and sync.replication_config:
		_add_sync_property(sync.replication_config, NodePath(".:gray_health"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		_add_sync_property(sync.replication_config, NodePath(".:is_crush_charging"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)

func _process_character_kit(delta: float) -> void:
	# Crush Gray Health Decay & Out-of-Combat Regen (Server-authoritative)
	time_since_last_damage += delta
	if (not is_multiplayer_match() or multiplayer.is_server()) and not is_dead:
		if time_since_last_damage >= 5.0 and gray_health > 0.0:
			var max_consume_rate = max_health * 0.1
			var consume = min(gray_health, max_consume_rate * delta)
			gray_health -= consume
			heal(consume)
			if is_multiplayer_match() and multiplayer.is_server():
				sync_gray_health.rpc(gray_health)

	if is_local_player():
		# Process Juggernaut Charge
		if is_crush_charging:
			crush_charge_timer -= delta
			var hit_pos = get_mouse_ground_intersection()
			if hit_pos != null:
				var desired_dir = (Vector3(hit_pos.x, global_position.y, hit_pos.z) - global_position).normalized()
				desired_dir.y = 0.0
				if desired_dir != Vector3.ZERO:
					crush_charge_dir = crush_charge_dir.slerp(desired_dir, CRUSH_CHARGE_TURN_SPEED * delta).normalized()
			
			look_at(global_position + crush_charge_dir, Vector3.UP)
			velocity.x = crush_charge_dir.x * CRUSH_CHARGE_SPEED
			velocity.z = crush_charge_dir.z * CRUSH_CHARGE_SPEED
			
			if crush_charge_timer <= 0.0:
				end_juggernaut_charge()

func start_juggernaut_charge(direction: Vector3, duration: float = 1.0, _speed: float = 28.0) -> void:
	is_crush_charging = true
	crush_charge_timer = duration
	crush_charge_dir = direction
	is_cc_immune = true

func end_juggernaut_charge() -> void:
	if not is_crush_charging:
		return
	is_crush_charging = false
	crush_charge_timer = 0.0
	is_cc_immune = false
	velocity = Vector3.ZERO
	
	var facing_dir = -global_transform.basis.z.normalized()
	facing_dir.y = 0.0
	facing_dir = facing_dir.normalized()
	
	if is_server_authoritative():
		_execute_charge_slam(global_position, facing_dir, peer_id)
	elif is_local_player():
		request_charge_slam.rpc_id(1, global_position, facing_dir)

func _execute_charge_slam(origin_pos: Vector3, forward_dir: Vector3, attacker_id: int) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	for body in players_container.get_children():
		if body is Node3D and body.name != str(attacker_id) and not body.get("is_dead") and is_enemy(body):
			var diff = body.global_position - origin_pos
			diff.y = 0.0
			if diff.length() <= 3.8:
				if body.has_method("take_damage"):
					body.take_damage(120.0, attacker_id, 2)
				if body.has_method("apply_stun"):
					body.apply_stun(1.25)
				if body.has_method("apply_knockback"):
					body.apply_knockback(Vector3.UP * 6.5 + forward_dir * 8.0, true)

@rpc("any_peer", "call_remote", "reliable")
func request_charge_slam(origin_pos: Vector3, forward_dir: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_execute_charge_slam(origin_pos, forward_dir, sender_id)

func on_buff_activated(buff_name: String, _duration: float) -> void:
	if buff_name == "IronBarrier":
		var converted = gray_health
		gray_health = 0.0
		add_shield(converted + 50.0, 5.0)

func on_melee_strike_hit(target: Node, hit_data: Dictionary) -> void:
	if is_crush_empowered:
		is_crush_empowered = false
		if is_instance_valid(target) and target.has_method("take_damage"):
			target.take_damage(25.0, peer_id, 0)
		heal(25.0)
	
	# If this hit was from Fan Stun (RMB), empower next slam
	var ab_id = hit_data.get("ability_id", "")
	if ab_id == "crush_fan_stun":
		is_crush_empowered = true

func custom_execute_ability_server(slot_key: String, _origin: Vector3, _dir: Vector3, _target_pos: Vector3, _charge: float) -> bool:
	if slot_key == "RMB":
		is_crush_empowered = true
	return false

func get_status_text() -> String:
	if is_crush_charging:
		return "✦ JUGGERNAUT CHARGE (UNSTOPPABLE) ✦"
	elif is_crush_empowered:
		return "✦ TITAN'S SURGE (+40% SLAM DAMAGE) ✦"
	return ""

func _on_damage_taken_hook(amount: float, _attacker_id: int, _action_type: int) -> void:
	time_since_last_damage = 0.0
	if is_server_authoritative() and amount > 0.0:
		var max_possible_gray = max(0.0, max_health - current_health)
		gray_health = clamp(gray_health + amount * 0.5, 0.0, max_possible_gray)
		if is_multiplayer_match() and multiplayer.is_server():
			sync_gray_health.rpc(gray_health)

@rpc("any_peer", "call_local", "reliable")
func sync_gray_health(new_val: float) -> void:
	if not _is_sender_host():
		return
	gray_health = new_val
