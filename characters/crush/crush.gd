class_name Crush
extends BasePlayer

# Gray Health / Iron Blood
var gray_health: float = 0.0:
	set(value):
		if max_health > 0.0:
			var max_possible_gray = max(0.0, max_health - current_health)
			gray_health = clamp(value, 0.0, max_possible_gray)
		else:
			gray_health = max(0.0, value)
		update_health_bar()
var time_since_last_damage: float = 0.0

# Titan Surge Empowerment
var is_crush_empowered: bool = false

# Juggernaut Charge (Ultimate)
var is_crush_charging: bool = false
var crush_charge_timer: float = 0.0
var crush_charge_elapsed: float = 0.0
var crush_charge_duration: float = 2.5
var crush_charge_min_speed: float = 8.0
var crush_charge_max_speed: float = 28.0
var crush_charge_current_speed: float = 8.0
var crush_charge_dir: Vector3 = Vector3.FORWARD
const CRUSH_CHARGE_DURATION: float = 2.5
const CRUSH_CHARGE_MIN_SPEED: float = 8.0
const CRUSH_CHARGE_SPEED: float = 28.0
const CRUSH_CHARGE_ACCELERATION_TIME: float = 2.0
const CRUSH_CHARGE_TURN_SPEED: float = 1.8
const CHARGE_BASE_DAMAGE: float = 120.0
const CHARGE_MAX_ATTACK_RATIO: float = 0.50
const CHARGE_MAX_HP_RATIO: float = 0.30

# Thunderclap (LMB Primary Attack)
const CLAP_BASE_DAMAGE: float = 50.0
const CLAP_DAMAGE_RATIO: float = 0.75
const CLAP_SWEET_SPOT_MULTIPLIER: float = 1.5
const CLAP_SWEET_SPOT_MIN_DIST: float = 3.2
const CLAP_CHARGE_TIME: float = 0.5
const CLAP_WINDUP_TIME: float = 0.5
const CLAP_UNCHARGED_MULTIPLIER: float = 0.5

# Ground Stomp (Q)
const GROUND_STOMP_BASE_DAMAGE: float = 25.0
const GROUND_STOMP_DAMAGE_RATIO: float = 0.30

func is_clap_sweet_spot(dist: float) -> bool:
	return dist >= CLAP_SWEET_SPOT_MIN_DIST

func get_clap_damage(dist: float, charge_ratio: float = 1.0) -> float:
	var inside_dmg = CLAP_BASE_DAMAGE + (damage * CLAP_DAMAGE_RATIO)
	var full_dmg = inside_dmg * CLAP_SWEET_SPOT_MULTIPLIER if is_clap_sweet_spot(dist) else inside_dmg
	var charge_mult = lerp(CLAP_UNCHARGED_MULTIPLIER, 1.0, clamp(charge_ratio, 0.0, 1.0))
	return full_dmg * charge_mult

func _setup_character_kit() -> void:
	if id.is_empty():
		id = "crush"
	var data = CrushData.create()
	load_character_data(data)

	var lmb_ab = abilities.get("LMB")
	if lmb_ab:
		lmb_ab.ability_id = "crush_clap"
		lmb_ab.ability_name = "Thunderclap"
		lmb_ab.hold_to_charge = true
		lmb_ab.charge_time = CLAP_CHARGE_TIME
		lmb_ab.windup_time = CLAP_WINDUP_TIME
		lmb_ab.cast_on_press = false
		lmb_ab.hitbox_type = 1
		lmb_ab.hitbox_radius = 4.8
		lmb_ab.hitbox_angle_deg = 100.0
		lmb_ab.damage_amount = CLAP_BASE_DAMAGE
		lmb_ab.damage_ratio = CLAP_DAMAGE_RATIO

	var rmb_ab = abilities.get("RMB")
	if rmb_ab:
		rmb_ab.damage_amount = 50.0
		rmb_ab.damage_ratio = 0.30

	var q_ab = abilities.get("Q")
	if q_ab:
		q_ab.damage_amount = GROUND_STOMP_BASE_DAMAGE
		q_ab.damage_ratio = GROUND_STOMP_DAMAGE_RATIO

	var r_ab = abilities.get("R")
	if r_ab:
		r_ab.damage_amount = CHARGE_BASE_DAMAGE
		r_ab.damage_ratio = CHARGE_MAX_ATTACK_RATIO
		if "max_hp_ratio" in r_ab:
			r_ab.max_hp_ratio = CHARGE_MAX_HP_RATIO
		if "charge_duration" in r_ab:
			r_ab.charge_duration = CRUSH_CHARGE_DURATION
		if "charge_speed" in r_ab:
			r_ab.charge_speed = CRUSH_CHARGE_SPEED
		if "min_charge_speed" in r_ab:
			r_ab.min_charge_speed = CRUSH_CHARGE_MIN_SPEED

	var sync = get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	if sync and sync.replication_config:
		_add_sync_property(sync.replication_config, NodePath(".:is_crush_charging"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var server_sync = get_node_or_null("ServerSynchronizer") as MultiplayerSynchronizer
	if server_sync and server_sync.replication_config:
		_add_sync_property(server_sync.replication_config, NodePath(".:gray_health"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)

func _process_character_kit(delta: float) -> void:
	# Crush Gray Health Decay & Out-of-Combat Regen (Server-authoritative)
	time_since_last_damage += delta
	if (not is_multiplayer_match() or multiplayer.is_server()) and not is_dead:
		var decay_delay = 5.0
		var decay_rate = 0.1
		var heal_ratio = 0.30
		if character_data and "passive_data" in character_data:
			decay_delay = float(character_data.passive_data.get("gray_health_decay_delay", 5.0))
			decay_rate = float(character_data.passive_data.get("gray_health_decay_rate", 0.1))
			heal_ratio = float(character_data.passive_data.get("out_of_combat_heal_ratio", character_data.passive_data.get("gray_health_heal_percent", 0.30)))
		if time_since_last_damage >= decay_delay and gray_health > 0.0:
			var max_consume_rate = max_health * decay_rate
			var consume = min(gray_health, max_consume_rate * delta)
			gray_health -= consume
			heal(consume * heal_ratio)
			if is_multiplayer_match() and multiplayer.is_server():
				sync_gray_health.rpc(gray_health)

	if is_local_player():
		# Process Juggernaut Charge
		if is_crush_charging:
			crush_charge_timer -= delta
			crush_charge_elapsed += delta
			
			# Accelerate slowly from min_speed to max_speed
			var accel_progress = clamp(crush_charge_elapsed / CRUSH_CHARGE_ACCELERATION_TIME, 0.0, 1.0)
			crush_charge_current_speed = lerp(crush_charge_min_speed, crush_charge_max_speed, accel_progress)
			
			var hit_pos = get_mouse_ground_intersection()
			if hit_pos != null:
				var desired_dir = (Vector3(hit_pos.x, global_position.y, hit_pos.z) - global_position).normalized()
				desired_dir.y = 0.0
				if desired_dir != Vector3.ZERO:
					crush_charge_dir = crush_charge_dir.slerp(desired_dir, CRUSH_CHARGE_TURN_SPEED * delta).normalized()
			
			look_at(global_position + crush_charge_dir, Vector3.UP)
			velocity.x = crush_charge_dir.x * crush_charge_current_speed
			velocity.z = crush_charge_dir.z * crush_charge_current_speed
			
			if is_on_wall():
				end_juggernaut_charge()
			else:
				var players_container = get_tree().root.get_node_or_null("Main/Players")
				if players_container:
					for body in players_container.get_children():
						if body is Node3D and body != self and body.name != str(peer_id) and not body.get("is_dead") and is_enemy(body):
							var diff = body.global_position - global_position
							diff.y = 0.0
							if diff.length() <= 2.2:
								end_juggernaut_charge()
								break

			if crush_charge_timer <= 0.0:
				end_juggernaut_charge()

func get_current_charge_speed_ratio() -> float:
	if crush_charge_max_speed <= crush_charge_min_speed:
		return 1.0
	return clamp((crush_charge_current_speed - crush_charge_min_speed) / (crush_charge_max_speed - crush_charge_min_speed), 0.0, 1.0)

func get_charge_damage(speed_ratio: float = 1.0) -> float:
	var ratio_factor = clamp(speed_ratio, 0.0, 1.0)
	var atk_ratio = CHARGE_MAX_ATTACK_RATIO * ratio_factor
	var hp_ratio = CHARGE_MAX_HP_RATIO * ratio_factor
	return CHARGE_BASE_DAMAGE + (damage * atk_ratio) + (max_health * hp_ratio)

func start_juggernaut_charge(direction: Vector3, duration: float = CRUSH_CHARGE_DURATION, max_speed: float = CRUSH_CHARGE_SPEED, min_speed: float = CRUSH_CHARGE_MIN_SPEED) -> void:
	is_crush_charging = true
	crush_charge_duration = duration
	crush_charge_timer = duration
	crush_charge_elapsed = 0.0
	crush_charge_max_speed = max_speed
	crush_charge_min_speed = min_speed
	crush_charge_current_speed = min_speed
	crush_charge_dir = direction
	is_cc_immune = true

func end_juggernaut_charge() -> void:
	if not is_crush_charging:
		return
	is_crush_charging = false
	var final_speed_ratio = get_current_charge_speed_ratio()
	crush_charge_timer = 0.0
	crush_charge_elapsed = 0.0
	crush_charge_current_speed = crush_charge_min_speed
	is_cc_immune = false
	velocity = Vector3.ZERO
	
	var facing_dir = -global_transform.basis.z.normalized()
	facing_dir.y = 0.0
	facing_dir = facing_dir.normalized()
	
	if is_server_authoritative():
		_execute_charge_slam(global_position, facing_dir, peer_id, final_speed_ratio)
	elif is_local_player():
		request_charge_slam.rpc_id(1, global_position, facing_dir, final_speed_ratio)

func _execute_charge_slam(origin_pos: Vector3, forward_dir: Vector3, attacker_id: int, speed_ratio: float = 1.0) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		players_container = get_parent()
	if not players_container:
		return
	
	var attacker_node = self if (attacker_id == peer_id or attacker_id == 0) else players_container.get_node_or_null(str(attacker_id))
	var attacker_atk = float(attacker_node.damage) if (attacker_node and "damage" in attacker_node) else damage
	var attacker_max_hp = float(attacker_node.max_health) if (attacker_node and "max_health" in attacker_node) else max_health
	
	var ratio_factor = clamp(speed_ratio, 0.0, 1.0)
	var atk_ratio = CHARGE_MAX_ATTACK_RATIO * ratio_factor
	var hp_ratio = CHARGE_MAX_HP_RATIO * ratio_factor
	var total_damage = CHARGE_BASE_DAMAGE + (attacker_atk * atk_ratio) + (attacker_max_hp * hp_ratio)
	
	for body in players_container.get_children():
		if body is Node3D and body != self and body.name != str(attacker_id) and not body.get("is_dead") and is_enemy(body):
			var diff = body.global_position - origin_pos
			diff.y = 0.0
			if diff.length() <= 3.8:
				if body.has_method("take_damage"):
					body.take_damage(total_damage, attacker_id, 2)
				if body.has_method("apply_stun"):
					body.apply_stun(1.25)
				if body.has_method("apply_knockback"):
					body.apply_knockback(Vector3.UP * 6.5 + forward_dir * 8.0, true)

@rpc("any_peer", "call_remote", "reliable")
func request_charge_slam(origin_pos: Vector3, forward_dir: Vector3, speed_ratio: float = 1.0) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_execute_charge_slam(origin_pos, forward_dir, sender_id, speed_ratio)

func activate_iron_barrier() -> void:
	var converted = gray_health
	gray_health = 0.0
	add_shield(converted + 50.0, 5.0)
	if is_multiplayer_match() and multiplayer.is_server():
		sync_gray_health.rpc(0.0)
	update_health_bar()

func on_buff_activated(buff_name: String, _duration: float) -> void:
	if buff_name == "IronBarrier":
		activate_iron_barrier()

func on_melee_strike_hit(target: Node, hit_data: Dictionary) -> void:
	var ab_id = hit_data.get("ability_id", "")
	var slot = hit_data.get("slot_key", "")
	
	if slot == "LMB" or ab_id == "crush_clap" or ab_id == "crush_slam":
		var origin_pos = hit_data.get("origin", global_position)
		var target_pos = target.global_position if "global_position" in target else global_position
		var diff = target_pos - origin_pos
		diff.y = 0.0
		var dist = diff.length()
		var is_sweet = is_clap_sweet_spot(dist)
		hit_data["is_sweet_spot"] = is_sweet
		
		var charge_ratio = hit_data.get("charge_ratio", 0.0)
		var charge_mult = lerp(CLAP_UNCHARGED_MULTIPLIER, 1.0, clamp(charge_ratio, 0.0, 1.0))
		
		var base_amount = (CLAP_BASE_DAMAGE * CLAP_SWEET_SPOT_MULTIPLIER) if is_sweet else CLAP_BASE_DAMAGE
		var ratio_amount = (CLAP_DAMAGE_RATIO * CLAP_SWEET_SPOT_MULTIPLIER) if is_sweet else CLAP_DAMAGE_RATIO
		
		hit_data["damage_amount"] = base_amount * charge_mult
		hit_data["damage_ratio"] = ratio_amount * charge_mult

	if (slot == "LMB" or ab_id == "crush_clap" or ab_id == "crush_slam") and is_crush_empowered:
		is_crush_empowered = false
		if is_instance_valid(target) and target.has_method("take_damage"):
			target.take_damage(25.0, peer_id, 0)
		heal(25.0)
	
	# If this hit was from Fan Stun (RMB), empower next slam
	if ab_id == "crush_fan_stun" or slot == "RMB":
		is_crush_empowered = true

func custom_execute_ability_server(slot_key: String, _origin: Vector3, _dir: Vector3, _target_pos: Vector3, _charge: float) -> bool:
	if slot_key == "RMB":
		is_crush_empowered = true
	elif slot_key == "E":
		activate_iron_barrier()
		return true
	elif slot_key == "R" and is_crush_charging:
		end_juggernaut_charge()
		return true
	return false

func custom_execute_ability_client(slot_key: String, _origin: Vector3, _dir: Vector3, _target_pos: Vector3, _charge: float) -> bool:
	if slot_key == "E":
		gray_health = 0.0
		update_health_bar()
		return true
	elif slot_key == "R" and is_crush_charging:
		end_juggernaut_charge()
		return true
	return false

func get_status_text() -> String:
	if is_crush_charging:
		return "✦ JUGGERNAUT CHARGE (UNSTOPPABLE) ✦"
	elif is_crush_empowered:
		return "✦ TITAN'S SURGE (+40% SLAM DAMAGE) ✦"
	return ""

func take_damage(amount: float, attacker_id: int = 0, action_type: int = ActionType.ATTACK, is_projectile: bool = false, damage_type: int = DamageType.DAMAGE) -> void:
	var prev_health = current_health
	super.take_damage(amount, attacker_id, action_type, is_projectile, damage_type)
	time_since_last_damage = 0.0
	var health_lost = max(0.0, prev_health - current_health)
	if is_server_authoritative() and health_lost > 0.0:
		var gray_ratio = 0.5
		if character_data and "passive_data" in character_data:
			gray_ratio = float(character_data.passive_data.get("gray_health_ratio", 0.5))
		var max_possible_gray = max(0.0, max_health - current_health)
		gray_health = clamp(gray_health + health_lost * gray_ratio, 0.0, max_possible_gray)
		if is_multiplayer_match() and multiplayer.is_server():
			sync_gray_health.rpc(gray_health)

func _on_damage_taken_hook(_amount: float, _attacker_id: int, _action_type: int) -> void:
	time_since_last_damage = 0.0

func _on_damage_dealt(target: Node, amount: float, action_type: int = ActionType.ATTACK, damage_type: int = DamageType.DAMAGE) -> void:
	super._on_damage_dealt(target, amount, action_type, damage_type)
	time_since_last_damage = 0.0

func die() -> void:
	gray_health = 0.0
	time_since_last_damage = 0.0
	super.die()

@rpc("any_peer", "call_local", "reliable")
func sync_gray_health(new_val: float) -> void:
	if not _is_sender_host():
		return
	gray_health = new_val
