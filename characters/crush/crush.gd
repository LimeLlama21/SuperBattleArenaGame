class_name Crush
extends BasePlayer

# Ability Cooldowns & Timers
var attack_timer: float = 0.0
var rmb_timer: float = 0.0
var q_timer: float = 0.0
var e_timer: float = 0.0
var r_timer: float = 0.0
var dash_timer: float = 0.0

var dash_impulse: float = 24.0
var dash_cooldown: float = 8.0

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

# Hold-to-aim Indicators
var shoot_hold_timer: float = 0.0
const LMB_HOLD_THRESHOLD: float = 0.18
var is_holding_shoot: bool = false
var is_holding_dash: bool = false
var is_holding_rmb: bool = false
var is_holding_q: bool = false
var is_holding_e: bool = false
var is_holding_r: bool = false

var ind_attack: Node3D = null
var ind_rmb: Node3D = null
var ind_q: Node3D = null
var ind_e: Node3D = null
var ind_r: Node3D = null

@onready var melee_visual: Node3D = get_node_or_null("MeleeVisual")
@onready var ability_one_visual: Node3D = get_node_or_null("AbilityOneVisual")
@onready var ability_two_visual: Node3D = get_node_or_null("AbilityTwoVisual")

func _setup_character_kit() -> void:
	var data = CrushData.create()
	load_character_data(data)

	dash_impulse = data.passive_data.get("dash_impulse", 24.0)
	dash_cooldown = data.passive_data.get("dash_cooldown", 8.0)

	_setup_local_indicators()

	var sync = get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	if sync and sync.replication_config:
		_add_sync_property(sync.replication_config, NodePath(".:gray_health"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		_add_sync_property(sync.replication_config, NodePath(".:is_crush_charging"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)

func _setup_local_indicators() -> void:
	if not is_local_player():
		return

	var lmb_def = abilities.get("LMB")
	if lmb_def and lmb_def.hitbox:
		ind_attack = AbilityIndicator.create_emanating_indicator(lmb_def.hitbox, AbilityIndicator.EMPTY_FILL, AbilityIndicator.WHITE_OUTLINE)
		add_child(ind_attack)
		ind_attack.hide()

	var rmb_def = abilities.get("RMB")
	if rmb_def and rmb_def.hitbox:
		ind_rmb = AbilityIndicator.create_emanating_indicator(rmb_def.hitbox, AbilityIndicator.EMPTY_FILL, AbilityIndicator.WHITE_OUTLINE)
		add_child(ind_rmb)
		ind_rmb.hide()

	var q_def = abilities.get("Q")
	if q_def and q_def.hitbox:
		ind_q = AbilityIndicator.create_emanating_indicator(q_def.hitbox, AbilityIndicator.EMPTY_FILL, AbilityIndicator.WHITE_OUTLINE)
		add_child(ind_q)
		ind_q.hide()

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
		if attack_timer > 0.0: attack_timer -= delta
		if rmb_timer > 0.0: rmb_timer -= delta
		if q_timer > 0.0: q_timer -= delta
		if e_timer > 0.0: e_timer -= delta
		if r_timer > 0.0: r_timer -= delta
		if dash_timer > 0.0: dash_timer -= delta

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
	gray_health = new_val

func _handle_character_input(_delta: float) -> void:
	if is_crush_charging or is_channeling:
		return

	# --- Dash (SHIFT) ---
	if is_cast_on_press("dash"):
		if Input.is_action_just_pressed("dash") and dash_timer <= 0.0 and not is_rooted() and not is_grounded() and can_cast_ability_slot("SHIFT"):
			_execute_crush_dash()
	else:
		if Input.is_action_just_pressed("dash") and dash_timer <= 0.0 and not is_rooted() and not is_grounded() and can_cast_ability_slot("SHIFT"):
			is_holding_dash = true
		if Input.is_action_just_released("dash") and is_holding_dash:
			is_holding_dash = false
			if dash_timer <= 0.0 and not is_rooted() and not is_grounded() and can_cast_ability_slot("SHIFT"):
				_execute_crush_dash()

	# --- Primary Fire (LMB): Slam ---
	if is_cast_on_press("shoot"):
		if (Input.is_action_just_pressed("shoot") or Input.is_action_pressed("shoot")) and attack_timer <= 0.0 and can_cast_ability_slot("LMB"):
			_perform_slam()
	else:
		if Input.is_action_just_pressed("shoot") and can_cast_ability_slot("LMB"):
			is_holding_shoot = true
			if ind_attack:
				AbilityIndicator.reset_indicator(ind_attack)
				ind_attack.show()
		if Input.is_action_just_released("shoot") and is_holding_shoot:
			is_holding_shoot = false
			if ind_attack: ind_attack.hide()
			if attack_timer <= 0.0 and can_cast_ability_slot("LMB"):
				_perform_slam()

	# --- Ability 1 (RMB): Fan Stun ---
	if is_cast_on_press("ability_one"):
		if Input.is_action_just_pressed("ability_one") and rmb_timer <= 0.0 and not is_silenced() and can_cast_ability_slot("RMB"):
			_perform_fan_stun()
	else:
		if Input.is_action_just_pressed("ability_one") and not is_silenced() and can_cast_ability_slot("RMB"):
			if rmb_timer <= 0.0:
				is_holding_rmb = true
				if ind_rmb:
					AbilityIndicator.reset_indicator(ind_rmb)
					ind_rmb.show()
		if Input.is_action_just_released("ability_one") and is_holding_rmb:
			is_holding_rmb = false
			if ind_rmb: ind_rmb.hide()
			if rmb_timer <= 0.0 and not is_silenced() and can_cast_ability_slot("RMB"):
				_perform_fan_stun()

	# --- Ability 2 (Q): Ground Stomp ---
	if is_cast_on_press("ability_two"):
		if Input.is_action_just_pressed("ability_two") and q_timer <= 0.0 and not is_silenced() and can_cast_ability_slot("Q"):
			_perform_ground_stomp()
	else:
		if Input.is_action_just_pressed("ability_two") and not is_silenced() and can_cast_ability_slot("Q"):
			if q_timer <= 0.0:
				is_holding_q = true
				if ind_q:
					AbilityIndicator.reset_indicator(ind_q)
					ind_q.show()
		if Input.is_action_just_released("ability_two") and is_holding_q:
			is_holding_q = false
			if ind_q: ind_q.hide()
			if q_timer <= 0.0 and not is_silenced() and can_cast_ability_slot("Q"):
				_perform_ground_stomp()

	# --- Ability 3 (E): Iron Barrier ---
	if is_cast_on_press("ability_three"):
		if Input.is_action_just_pressed("ability_three") and e_timer <= 0.0 and not is_silenced() and can_cast_ability_slot("E"):
			_perform_iron_barrier()
	else:
		if Input.is_action_just_pressed("ability_three") and not is_silenced() and can_cast_ability_slot("E"):
			if e_timer <= 0.0:
				is_holding_e = true
				if ind_e:
					AbilityIndicator.reset_indicator(ind_e)
					ind_e.show()
		if Input.is_action_just_released("ability_three") and is_holding_e:
			is_holding_e = false
			if ind_e: ind_e.hide()
			if e_timer <= 0.0 and not is_silenced() and can_cast_ability_slot("E"):
				_perform_iron_barrier()

	# --- Ultimate (R): Juggernaut Charge ---
	if is_cast_on_press("ability_four"):
		if Input.is_action_just_pressed("ability_four") and r_timer <= 0.0 and not is_silenced() and can_cast_ability_slot("R"):
			_perform_juggernaut_charge()
	else:
		if Input.is_action_just_pressed("ability_four") and not is_silenced() and can_cast_ability_slot("R"):
			if r_timer <= 0.0:
				is_holding_r = true
				if ind_r:
					AbilityIndicator.reset_indicator(ind_r)
					ind_r.show()
		if Input.is_action_just_released("ability_four") and is_holding_r:
			is_holding_r = false
			if ind_r: ind_r.hide()
			if r_timer <= 0.0 and not is_silenced() and can_cast_ability_slot("R"):
				_perform_juggernaut_charge()

func _execute_crush_dash() -> void:
	dash_timer = dash_cooldown
	var dash_dir = get_dash_direction()
	var effective_impulse = get_effective_dash_impulse(dash_impulse)
	apply_velocity_impulse(Vector3(dash_dir.x * effective_impulse, 0, dash_dir.z * effective_impulse), true)

func _perform_slam() -> void:
	var def = abilities.get("LMB")
	attack_timer = def.cooldown if def else 0.65
	start_ability_cast("LMB")
	var facing_dir = -global_transform.basis.z.normalized()
	var dmg = 55.0 * (1.4 if is_crush_empowered else 1.0)
	is_crush_empowered = false
	attack_performed.emit("Slam")
	trigger_ability_hitbox("LMB", global_position, facing_dir)
	if not is_multiplayer_match() or multiplayer.is_server():
		_execute_slam_hit(global_position, facing_dir, 1, dmg)
	else:
		request_slam_hit.rpc_id(1, global_position, facing_dir, dmg)

func _execute_slam_hit(origin_pos: Vector3, forward_dir: Vector3, attacker_id: int, dmg: float) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	var def = abilities.get("LMB")
	var rad = def.hitbox.radius if (def and def.hitbox) else 4.2
	var angle_deg = def.hitbox.angle_deg if (def and def.hitbox) else 120.0
	var height = def.hitbox.height if (def and def.hitbox and def.hitbox.height > 0.0) else 2.4
	var half_angle_rad = deg_to_rad(angle_deg * 0.5)
	for body in players_container.get_children():
		if body is Node3D and body.name != str(attacker_id) and not body.get("is_dead") and is_enemy(body):
			var to_body = body.global_position - origin_pos
			var dy = to_body.y
			if dy < -2.0 or dy > height:
				continue
			to_body.y = 0.0
			var dist = to_body.length()
			if dist <= rad and dist > 0.001:
				if forward_dir.angle_to(to_body.normalized()) <= half_angle_rad:
					if body.has_method("take_damage"):
						body.take_damage(dmg, attacker_id, ActionType.ATTACK)

@rpc("any_peer", "call_remote", "reliable")
func request_slam_hit(origin_pos: Vector3, forward_dir: Vector3, dmg: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_execute_slam_hit(origin_pos, forward_dir, sender_id, dmg)

func _perform_fan_stun() -> void:
	var def = abilities.get("RMB")
	rmb_timer = def.cooldown if def else 7.5
	start_ability_cast("RMB")
	var facing_dir = -global_transform.basis.z.normalized()
	ability_cast.emit("Fan Stun", "RMB")
	trigger_ability_hitbox("RMB", global_position, facing_dir)
	if not is_multiplayer_match() or multiplayer.is_server():
		_execute_fan_stun(global_position, facing_dir, 1)
	else:
		request_fan_stun.rpc_id(1, global_position, facing_dir)

func _execute_fan_stun(origin_pos: Vector3, forward_dir: Vector3, attacker_id: int) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	var def = abilities.get("RMB")
	var rad = def.hitbox.radius if (def and def.hitbox) else 5.2
	var angle_deg = def.hitbox.angle_deg if (def and def.hitbox) else 100.0
	var height = def.hitbox.height if (def and def.hitbox and def.hitbox.height > 0.0) else 2.4
	var half_angle_rad = deg_to_rad(angle_deg * 0.5)
	var hit_anyone = false
	for body in players_container.get_children():
		if body is Node3D and body.name != str(attacker_id) and not body.get("is_dead") and is_enemy(body):
			var to_body = body.global_position - origin_pos
			var dy = to_body.y
			if dy < -2.0 or dy > height:
				continue
			to_body.y = 0.0
			var dist = to_body.length()
			if dist <= rad and dist > 0.001:
				if forward_dir.angle_to(to_body.normalized()) <= half_angle_rad:
					hit_anyone = true
					if body.has_method("take_damage"):
						body.take_damage(25.0, attacker_id, ActionType.ABILITY)
					if body.has_method("apply_stun"):
						body.apply_stun(0.8)
	if hit_anyone:
		var attacker = players_container.get_node_or_null(str(attacker_id))
		if attacker and attacker.has_method("empower_crush_slam"):
			attacker.empower_crush_slam()

@rpc("any_peer", "call_remote", "reliable")
func request_fan_stun(origin_pos: Vector3, forward_dir: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_execute_fan_stun(origin_pos, forward_dir, sender_id)

func empower_crush_slam() -> void:
	is_crush_empowered = true

func _perform_ground_stomp() -> void:
	var def = abilities.get("Q")
	q_timer = def.cooldown if def else 8.0
	start_ability_cast("Q")
	ability_cast.emit("Ground Stomp", "Q")
	trigger_ability_hitbox("Q", global_position, Vector3.ZERO)
	if not is_multiplayer_match() or multiplayer.is_server():
		_execute_ground_stomp(global_position, 1)
	else:
		request_ground_stomp.rpc_id(1, global_position)

func _execute_ground_stomp(origin_pos: Vector3, attacker_id: int) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	var def = abilities.get("Q")
	var rad = def.hitbox.radius if (def and def.hitbox) else 6.5
	for body in players_container.get_children():
		if body is Node3D and not body.get("is_dead"):
			if body.name == str(attacker_id):
				if body.has_method("apply_shield"):
					body.apply_shield(40.0, 5.0)
			elif is_enemy(body):
				if body.global_position.distance_to(origin_pos) <= rad:
					if body.has_method("take_damage"):
						body.take_damage(20.0, attacker_id, ActionType.ABILITY)
					if body.has_method("apply_slow"):
						body.apply_slow(2.5, 0.30)

@rpc("any_peer", "call_remote", "reliable")
func request_ground_stomp(origin_pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_execute_ground_stomp(origin_pos, sender_id)

func _perform_iron_barrier() -> void:
	var def = abilities.get("E")
	e_timer = def.cooldown if def else 10.0
	start_ability_cast("E")
	ability_cast.emit("Iron Barrier", "E")
	apply_shield(50.0, 5.0)

@rpc("any_peer", "call_remote", "reliable")
func request_iron_barrier() -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	var p = players_container.get_node_or_null(str(sender_id)) if players_container else null
	if p and p.has_method("apply_shield"):
		p.apply_shield(50.0, 5.0)

func _perform_juggernaut_charge() -> void:
	var def = abilities.get("R")
	r_timer = def.cooldown if def else 26.0
	start_ability_cast("R")
	is_crush_charging = true
	crush_charge_timer = CRUSH_CHARGE_DURATION
	crush_charge_dir = -global_transform.basis.z.normalized()
	is_cc_immune = true
	ability_cast.emit("Juggernaut Charge", "R")

func end_juggernaut_charge() -> void:
	is_crush_charging = false
	crush_charge_timer = 0.0
	is_cc_immune = false
	var facing_dir = -global_transform.basis.z.normalized()
	trigger_ability_hitbox("R", global_position, facing_dir)
	if not is_multiplayer_match() or multiplayer.is_server():
		_execute_charge_slam(global_position, facing_dir, 1)
	else:
		request_charge_slam.rpc_id(1, global_position, facing_dir)

func _execute_charge_slam(origin_pos: Vector3, forward_dir: Vector3, attacker_id: int) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	for body in players_container.get_children():
		if body is Node3D and body.name != str(attacker_id) and not body.get("is_dead") and is_enemy(body):
			if body.global_position.distance_to(origin_pos) <= 3.6:
				if body.has_method("take_damage"):
					body.take_damage(120.0, attacker_id, ActionType.ABILITY)
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

func _update_character_hud() -> void:
	var def_rmb = abilities.get("RMB")
	var def_q = abilities.get("Q")
	var def_e = abilities.get("E")
	var def_r = abilities.get("R")
	var def_shift = abilities.get("SHIFT")

	if slot_ability_one and def_rmb:
		slot_ability_one.update_cooldown(rmb_timer, def_rmb.cooldown, 1, 1, is_silenced())
	if slot_ability_two and def_q:
		slot_ability_two.update_cooldown(q_timer, def_q.cooldown, 1, 1, is_silenced())
	if slot_ability_three and def_e:
		slot_ability_three.update_cooldown(e_timer, def_e.cooldown, 1, 1, is_silenced())
	if slot_ability_four and def_r:
		slot_ability_four.update_cooldown(r_timer, def_r.cooldown, 1, 1, is_silenced())
		slot_ability_four.set_active_state(is_crush_charging)
	if slot_dash and def_shift:
		slot_dash.update_cooldown(dash_timer, dash_cooldown, 1, 1, is_rooted() or is_grounded())

func execute_ability_slot(slot_key: String) -> bool:
	if is_dead or is_stunned():
		return false
	match slot_key.to_upper():
		"LMB", "SHOOT":
			if attack_timer <= 0.0 and can_cast_ability_slot("LMB"):
				_perform_slam()
				return true
		"RMB", "ABILITY_ONE":
			if rmb_timer <= 0.0 and not is_silenced() and can_cast_ability_slot("RMB"):
				_perform_fan_stun()
				return true
		"Q", "ABILITY_TWO":
			if q_timer <= 0.0 and not is_silenced() and can_cast_ability_slot("Q"):
				_perform_ground_stomp()
				return true
		"E", "ABILITY_THREE":
			if e_timer <= 0.0 and not is_silenced() and can_cast_ability_slot("E"):
				_perform_iron_barrier()
				return true
		"R", "ABILITY_FOUR":
			if r_timer <= 0.0 and not is_silenced() and can_cast_ability_slot("R"):
				_perform_juggernaut_charge()
				return true
		"SHIFT", "DASH":
			if dash_timer <= 0.0 and not is_rooted() and not is_grounded() and can_cast_ability_slot("SHIFT"):
				_execute_crush_dash()
				return true
	return false
