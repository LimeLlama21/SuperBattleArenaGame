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
var gray_health: float = 0.0
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
var is_holding_rmb: bool = false
var is_holding_q: bool = false

var ind_attack: Node3D = null
var ind_rmb: Node3D = null
var ind_q: Node3D = null

@onready var melee_visual: Node3D = get_node_or_null("MeleeVisual")
@onready var ability_one_visual: Node3D = get_node_or_null("AbilityOneVisual")
@onready var ability_two_visual: Node3D = get_node_or_null("AbilityTwoVisual")

var abilities: Dictionary = {}

func _setup_character_kit() -> void:
	character_name = "Crush"
	var data = CrushData.create()
	max_health = data.max_health
	current_health = data.max_health
	max_move_speed = data.max_move_speed
	ground_acceleration = data.ground_acceleration
	ground_friction = data.ground_friction
	air_acceleration = data.air_acceleration
	air_drag = data.air_drag
	jump_velocity = data.jump_velocity

	dash_impulse = data.passive_data.get("dash_impulse", 24.0)
	dash_cooldown = data.passive_data.get("dash_cooldown", 8.0)

	abilities = CrushAbilities.get_abilities()
	_setup_local_indicators()

func _setup_local_indicators() -> void:
	if name.to_int() != multiplayer.get_unique_id():
		return

	ind_attack = AbilityIndicator.create_sector_indicator(4.2, 120.0, AbilityIndicator.EMPTY_FILL, AbilityIndicator.WHITE_OUTLINE)
	add_child(ind_attack)
	ind_attack.hide()

	ind_rmb = AbilityIndicator.create_sector_indicator(5.2, 100.0, AbilityIndicator.EMPTY_FILL, AbilityIndicator.WHITE_OUTLINE)
	add_child(ind_rmb)
	ind_rmb.hide()

	ind_q = AbilityIndicator.create_circle_indicator(6.5, AbilityIndicator.EMPTY_FILL, AbilityIndicator.WHITE_OUTLINE)
	add_child(ind_q)
	ind_q.hide()

func _process_character_kit(delta: float) -> void:
	# Crush Gray Health Decay & Out-of-Combat Regen (Server-authoritative)
	time_since_last_damage += delta
	if multiplayer.is_server() and not is_dead:
		if time_since_last_damage >= 5.0 and gray_health > 0.0:
			var max_consume_rate = max_health * 0.1
			var consume = min(gray_health, max_consume_rate * delta)
			gray_health -= consume
			heal(consume * 0.5)
			sync_gray_health.rpc(gray_health)

	if name.to_int() == multiplayer.get_unique_id():
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
	if multiplayer.is_server():
		gray_health = min(max_health, gray_health + amount * 0.5)
		sync_gray_health.rpc(gray_health)

@rpc("authority", "call_local", "reliable")
func sync_gray_health(new_val: float) -> void:
	gray_health = new_val
	if gray_health_bar:
		gray_health_bar.max_value = max_health
		gray_health_bar.value = current_health + gray_health

func _handle_character_input(_delta: float) -> void:
	if is_crush_charging or is_channeling:
		return

	# --- Dash (SHIFT) ---
	if Input.is_action_just_pressed("dash") and dash_timer <= 0.0 and not is_rooted() and not is_grounded():
		_execute_crush_dash()

	# --- Primary Fire (LMB): Slam ---
	if Input.is_action_just_pressed("shoot"):
		shoot_hold_timer = 0.0
		if attack_timer <= 0.0:
			_perform_slam()
	elif Input.is_action_pressed("shoot"):
		shoot_hold_timer += _delta
		if shoot_hold_timer >= LMB_HOLD_THRESHOLD:
			if ind_attack and not ind_attack.visible:
				AbilityIndicator.reset_indicator(ind_attack)
				ind_attack.show()
	if Input.is_action_just_released("shoot"):
		if ind_attack and ind_attack.visible:
			ind_attack.hide()
			if attack_timer <= 0.0:
				_perform_slam()
		shoot_hold_timer = 0.0

	# --- Ability 1 (RMB): Fan Stun ---
	if Input.is_action_just_pressed("ability_one") and not is_silenced():
		is_holding_rmb = true
		if ind_rmb:
			AbilityIndicator.reset_indicator(ind_rmb)
			ind_rmb.show()
	if Input.is_action_just_released("ability_one") and is_holding_rmb:
		is_holding_rmb = false
		if ind_rmb: ind_rmb.hide()
		if rmb_timer <= 0.0 and not is_silenced():
			_perform_fan_stun()

	# --- Ability 2 (Q): Ground Stomp ---
	if Input.is_action_just_pressed("ability_two") and not is_silenced():
		is_holding_q = true
		if ind_q:
			AbilityIndicator.reset_indicator(ind_q)
			ind_q.show()
	if Input.is_action_just_released("ability_two") and is_holding_q:
		is_holding_q = false
		if ind_q: ind_q.hide()
		if q_timer <= 0.0 and not is_silenced():
			_perform_ground_stomp()

	# --- Ability 3 (E): Iron Barrier ---
	if Input.is_action_just_pressed("ability_three") and e_timer <= 0.0 and not is_silenced():
		_perform_iron_barrier()

	# --- Ultimate (R): Juggernaut Charge ---
	if Input.is_action_just_pressed("ability_four") and r_timer <= 0.0 and not is_silenced():
		_perform_juggernaut_charge()

func _execute_crush_dash() -> void:
	dash_timer = dash_cooldown
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target_dir = Vector3(input_dir.x, 0, input_dir.y).normalized()
	var dash_dir = target_dir if target_dir != Vector3.ZERO else -global_transform.basis.z.normalized()
	velocity.x = dash_dir.x * dash_impulse
	velocity.z = dash_dir.z * dash_impulse

func _perform_slam() -> void:
	var def = abilities.get("LMB")
	attack_timer = def.cooldown if def else 0.65
	var facing_dir = -global_transform.basis.z.normalized()
	var dmg = 55.0 * (1.4 if is_crush_empowered else 1.0)
	is_crush_empowered = false
	attack_performed.emit("Slam")
	_show_melee_visual()
	if multiplayer.is_server():
		_execute_slam_hit(global_position, facing_dir, 1, dmg)
	else:
		request_slam_hit.rpc_id(1, global_position, facing_dir, dmg)

func _execute_slam_hit(origin_pos: Vector3, forward_dir: Vector3, attacker_id: int, dmg: float) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	var half_angle_rad = deg_to_rad(60.0)
	for body in players_container.get_children():
		if body is Node3D and body.name != str(attacker_id) and not body.get("is_dead"):
			var to_body = body.global_position - origin_pos
			to_body.y = 0.0
			var dist = to_body.length()
			if dist <= 4.2 and dist > 0.001:
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
	var facing_dir = -global_transform.basis.z.normalized()
	ability_cast.emit("Fan Stun", "RMB")
	_show_fan_stun_visual()
	if multiplayer.is_server():
		_execute_fan_stun(global_position, facing_dir, 1)
	else:
		request_fan_stun.rpc_id(1, global_position, facing_dir)

func _execute_fan_stun(origin_pos: Vector3, forward_dir: Vector3, attacker_id: int) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	var half_angle_rad = deg_to_rad(50.0)
	var hit_anyone = false
	for body in players_container.get_children():
		if body is Node3D and body.name != str(attacker_id) and not body.get("is_dead"):
			var to_body = body.global_position - origin_pos
			to_body.y = 0.0
			var dist = to_body.length()
			if dist <= 5.2 and dist > 0.001:
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
	ability_cast.emit("Ground Stomp", "Q")
	_show_stomp_visual()
	if multiplayer.is_server():
		_execute_ground_stomp(global_position, 1)
	else:
		request_ground_stomp.rpc_id(1, global_position)

func _execute_ground_stomp(origin_pos: Vector3, attacker_id: int) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	for body in players_container.get_children():
		if body is Node3D and not body.get("is_dead"):
			if body.name == str(attacker_id):
				if body.has_method("apply_shield"):
					body.apply_shield(40.0, 5.0)
			else:
				if body.global_position.distance_to(origin_pos) <= 6.5:
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
	apply_shield(50.0, 5.0)
	ability_cast.emit("Iron Barrier", "E")

func _perform_juggernaut_charge() -> void:
	var def = abilities.get("R")
	r_timer = def.cooldown if def else 26.0
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
	if multiplayer.is_server():
		_execute_charge_slam(global_position, facing_dir, 1)
	else:
		request_charge_slam.rpc_id(1, global_position, facing_dir)

func _execute_charge_slam(origin_pos: Vector3, forward_dir: Vector3, attacker_id: int) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	for body in players_container.get_children():
		if body is Node3D and body.name != str(attacker_id) and not body.get("is_dead"):
			if body.global_position.distance_to(origin_pos) <= 3.6:
				if body.has_method("take_damage"):
					body.take_damage(120.0, attacker_id, ActionType.ABILITY)
				if body.has_method("apply_stun"):
					body.apply_stun(1.25)
				if body.has_method("apply_knockback"):
					body.apply_knockback(Vector3.UP * 16.0, true)

@rpc("any_peer", "call_remote", "reliable")
func request_charge_slam(origin_pos: Vector3, forward_dir: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_execute_charge_slam(origin_pos, forward_dir, sender_id)

func _show_melee_visual() -> void:
	if melee_visual:
		melee_visual.visible = true
		get_tree().create_timer(0.16).timeout.connect(func(): if melee_visual: melee_visual.visible = false)

func _show_fan_stun_visual() -> void:
	if ability_one_visual:
		ability_one_visual.visible = true
		get_tree().create_timer(0.20).timeout.connect(func(): if ability_one_visual: ability_one_visual.visible = false)

func _show_stomp_visual() -> void:
	if ability_two_visual:
		ability_two_visual.visible = true
		get_tree().create_timer(0.25).timeout.connect(func(): if ability_two_visual: ability_two_visual.visible = false)

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
