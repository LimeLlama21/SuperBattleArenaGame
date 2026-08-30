class_name Poke
extends BasePlayer

# Ability Cooldowns & Timers
var shoot_timer: float = 0.0
var rmb_timer: float = 0.0
var q_timer: float = 0.0
var e_timer: float = 0.0
var r_timer: float = 0.0
var dash_timer: float = 0.0

# Passive & Buff State
var poke_speed_boost_timer: float = 0.0
var poke_speed_boost_percent: float = 0.0
var poke_ult_buff_timer: float = 0.0
const POKE_ULT_BUFF_DURATION: float = 12.0
const CAMERA_ZOOMED_OFFSET: Vector3 = Vector3(0, 30, 16.5)
var current_camera_offset: Vector3 = CAMERA_OFFSET

# Dash parameters
var dash_impulse: float = 28.0
var dash_cooldown: float = 4.0

# Hold-to-aim indicator state
var shoot_hold_timer: float = 0.0
const LMB_HOLD_THRESHOLD: float = 0.18
var is_holding_rmb: bool = false
var is_holding_q: bool = false
var is_holding_e: bool = false

var ind_attack: Node3D = null
var ind_rmb: Node3D = null
var ind_q: Node3D = null
var ind_e: Node3D = null

var abilities: Dictionary = {}

func _setup_character_kit() -> void:
	character_name = "Poke"
	var data = PokeData.create()
	max_health = data.max_health
	current_health = data.max_health
	max_move_speed = data.max_move_speed
	ground_acceleration = data.ground_acceleration
	ground_friction = data.ground_friction
	air_acceleration = data.air_acceleration
	air_drag = data.air_drag
	jump_velocity = data.jump_velocity

	dash_impulse = data.passive_data.get("dash_impulse", 28.0)
	dash_cooldown = data.passive_data.get("dash_cooldown", 4.0)

	abilities = PokeAbilities.get_abilities()
	_setup_local_indicators()

func _setup_local_indicators() -> void:
	if name.to_int() != multiplayer.get_unique_id():
		return
	
	ind_attack = AbilityIndicator.create_line_indicator(50.0, 0.35, AbilityIndicator.EMPTY_FILL, AbilityIndicator.WHITE_OUTLINE)
	add_child(ind_attack)
	ind_attack.hide()

	ind_rmb = AbilityIndicator.create_line_indicator(60.0, 0.7, AbilityIndicator.EMPTY_FILL, AbilityIndicator.WHITE_OUTLINE)
	add_child(ind_rmb)
	ind_rmb.hide()

	ind_q = AbilityIndicator.create_circle_indicator(2.2, AbilityIndicator.EMPTY_FILL, AbilityIndicator.WHITE_OUTLINE)
	ind_q.top_level = true
	add_child(ind_q)
	ind_q.hide()

	ind_e = AbilityIndicator.create_circle_indicator(12.0, AbilityIndicator.EMPTY_FILL, AbilityIndicator.WHITE_OUTLINE)
	ind_e.top_level = true
	add_child(ind_e)
	ind_e.hide()

func _exit_tree() -> void:
	if ind_q and is_instance_valid(ind_q): ind_q.queue_free()
	if ind_e and is_instance_valid(ind_e): ind_e.queue_free()

func _process_character_kit(delta: float) -> void:
	if poke_speed_boost_timer > 0.0:
		poke_speed_boost_timer -= delta
		if poke_speed_boost_timer <= 0.0:
			poke_speed_boost_timer = 0.0
			poke_speed_boost_percent = 0.0

	if poke_ult_buff_timer > 0.0:
		poke_ult_buff_timer -= delta
		if poke_ult_buff_timer <= 0.0:
			poke_ult_buff_timer = 0.0

	if name.to_int() == multiplayer.get_unique_id():
		if shoot_timer > 0.0: shoot_timer -= delta
		if rmb_timer > 0.0: rmb_timer -= delta
		if q_timer > 0.0: q_timer -= delta
		if e_timer > 0.0: e_timer -= delta
		if r_timer > 0.0: r_timer -= delta
		if dash_timer > 0.0: dash_timer -= delta

func _process_camera(delta: float) -> void:
	if not camera:
		return
	var target_offset = CAMERA_ZOOMED_OFFSET if poke_ult_buff_timer > 0.0 else CAMERA_OFFSET
	current_camera_offset = current_camera_offset.lerp(target_offset, 5.0 * delta)
	camera.global_position = global_position + current_camera_offset
	camera.look_at(global_position, Vector3.UP)

func get_effective_max_speed(current_speed: float) -> float:
	if poke_speed_boost_timer > 0.0:
		return current_speed * (1.0 + poke_speed_boost_percent)
	return current_speed

func get_status_text() -> String:
	if poke_speed_boost_timer > 0.0:
		return "⚡ FLEET FOOT (+15%% MS) (%.1fs) ⚡" % poke_speed_boost_timer
	elif poke_ult_buff_timer > 0.0:
		return "✦ EMPOWERED PIERCING LANCE (%.1fs) ✦" % poke_ult_buff_timer
	return ""

func _handle_character_input(_delta: float) -> void:
	if is_channeling:
		return

	# Update targeting indicators positions
	var hit_pos = get_mouse_ground_intersection()
	if hit_pos != null:
		var target_pos = Vector3(hit_pos.x, 0.06, hit_pos.z)
		if is_holding_q and ind_q:
			var max_cast_dist = 18.0
			var dist = global_position.distance_to(target_pos)
			if dist > max_cast_dist:
				var dir = (target_pos - global_position).normalized()
				target_pos = global_position + dir * max_cast_dist
				target_pos.y = 0.06
			ind_q.global_position = target_pos

		if is_holding_e and ind_e:
			var max_cast_dist = 30.0
			var dist = global_position.distance_to(target_pos)
			if dist > max_cast_dist:
				var dir = (target_pos - global_position).normalized()
				target_pos = global_position + dir * max_cast_dist
				target_pos.y = 0.06
			ind_e.global_position = target_pos

	# --- Dash (SHIFT) ---
	if Input.is_action_just_pressed("dash") and dash_timer <= 0.0 and not is_rooted() and not is_grounded():
		_execute_dash()

	# --- Primary Fire (LMB): Rail Shot ---
	if Input.is_action_just_pressed("shoot"):
		shoot_hold_timer = 0.0
		if shoot_timer <= 0.0:
			_perform_rail_shot()
	elif Input.is_action_pressed("shoot"):
		shoot_hold_timer += _delta
		if shoot_hold_timer >= LMB_HOLD_THRESHOLD:
			if ind_attack and not ind_attack.visible:
				AbilityIndicator.reset_indicator(ind_attack)
				ind_attack.show()
	if Input.is_action_just_released("shoot"):
		if ind_attack and ind_attack.visible:
			ind_attack.hide()
			if shoot_timer <= 0.0:
				_perform_rail_shot()
		shoot_hold_timer = 0.0

	# --- Ability 1 (RMB): Repulsor Bolt ---
	if Input.is_action_just_pressed("ability_one") and not is_silenced():
		is_holding_rmb = true
		if ind_rmb:
			AbilityIndicator.reset_indicator(ind_rmb)
			ind_rmb.show()
	if Input.is_action_just_released("ability_one") and is_holding_rmb:
		is_holding_rmb = false
		if ind_rmb: ind_rmb.hide()
		if rmb_timer <= 0.0 and not is_silenced():
			_perform_repulsor_bolt()

	# --- Ability 2 (Q): Slipstream Field ---
	if Input.is_action_just_pressed("ability_two") and not is_silenced():
		is_holding_q = true
		if ind_q:
			AbilityIndicator.reset_indicator(ind_q)
			ind_q.show()
	if Input.is_action_just_released("ability_two") and is_holding_q:
		is_holding_q = false
		if ind_q: ind_q.hide()
		if q_timer <= 0.0 and not is_silenced():
			_perform_slipstream_field()

	# --- Ability 3 (E): Recon Flare ---
	if Input.is_action_just_pressed("ability_three") and not is_silenced():
		is_holding_e = true
		if ind_e:
			AbilityIndicator.reset_indicator(ind_e)
			ind_e.show()
	if Input.is_action_just_released("ability_three") and is_holding_e:
		is_holding_e = false
		if ind_e: ind_e.hide()
		if e_timer <= 0.0 and not is_silenced():
			_perform_recon_flare()

	# --- Ultimate (R): Overcharge ---
	if Input.is_action_just_pressed("ability_four") and r_timer <= 0.0 and not is_silenced():
		_perform_overcharge()

func _execute_dash() -> void:
	dash_timer = dash_cooldown
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target_dir = Vector3(input_dir.x, 0, input_dir.y).normalized()
	var dash_dir = target_dir if target_dir != Vector3.ZERO else -global_transform.basis.z.normalized()
	velocity.x = dash_dir.x * dash_impulse
	velocity.z = dash_dir.z * dash_impulse

func _perform_rail_shot() -> void:
	var def = abilities.get("LMB")
	shoot_timer = def.cooldown if def else 0.9
	var facing_dir = -global_transform.basis.z.normalized()
	var spawn_pos = global_position + Vector3(0, 0.8, 0) + facing_dir * 1.0
	var is_empowered = (poke_ult_buff_timer > 0.0)
	if is_empowered:
		poke_ult_buff_timer = 0.0
		sync_poke_ult_buff.rpc(0.0)
	
	var dmg = 18.0
	var spd = 95.0 if is_empowered else 90.0
	var sz = 1.3 if is_empowered else 0.35
	var rng = 95.0 if is_empowered else 50.0
	var pierces = is_empowered
	var eff = "execute_scaling" if is_empowered else ""

	attack_performed.emit("Rail Shot")
	if multiplayer.is_server():
		_spawn_rail_shot(spawn_pos, facing_dir, 1, dmg, spd, sz, rng, pierces, eff)
	else:
		request_rail_shot.rpc_id(1, spawn_pos, facing_dir, dmg, spd, sz, rng, pierces, eff)

func _spawn_rail_shot(spawn_pos: Vector3, shoot_dir: Vector3, sender_id: int, dmg: float, spd: float, p_size: float, max_rng: float, pierces: bool, eff: String) -> void:
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node and main_node.has_method("spawn_projectile"):
		var life = max_rng / max(1.0, spd)
		main_node.spawn_projectile(
			spawn_pos,
			shoot_dir,
			sender_id,
			dmg,
			spd,
			p_size,
			life,
			eff,
			0.0,
			0.0,
			pierces,
			false,
			0,
			ActionType.ATTACK,
			max_rng
		)

@rpc("any_peer", "call_remote", "reliable")
func request_rail_shot(spawn_pos: Vector3, shoot_dir: Vector3, dmg: float, spd: float, p_size: float, max_rng: float, pierces: bool, eff: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_spawn_rail_shot(spawn_pos, shoot_dir, sender_id, dmg, spd, p_size, max_rng, pierces, eff)

func _perform_repulsor_bolt() -> void:
	var def = abilities.get("RMB")
	rmb_timer = def.cooldown if def else 6.5
	var facing_dir = -global_transform.basis.z.normalized()
	facing_dir.y = 0.0
	facing_dir = facing_dir.normalized()
	var spawn_pos = global_position + Vector3(0, 0.8, 0) + facing_dir * 1.0
	ability_cast.emit("Repulsor Bolt", "RMB")
	if multiplayer.is_server():
		_spawn_repulsor_bolt(spawn_pos, facing_dir, 1)
	else:
		request_repulsor_bolt.rpc_id(1, spawn_pos, facing_dir)

func _spawn_repulsor_bolt(spawn_pos: Vector3, shoot_dir: Vector3, sender_id: int) -> void:
	shoot_dir.y = 0.0
	shoot_dir = shoot_dir.normalized()
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node and main_node.has_method("spawn_projectile"):
		main_node.spawn_projectile(
			spawn_pos,
			shoot_dir,
			sender_id,
			0.0,
			85.0,
			0.35,
			60.0 / 85.0,
			"knockback_stun",
			1.0,
			36.0,
			false,
			false,
			0,
			ActionType.ABILITY,
			60.0
		)

@rpc("any_peer", "call_remote", "reliable")
func request_repulsor_bolt(spawn_pos: Vector3, shoot_dir: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_spawn_repulsor_bolt(spawn_pos, shoot_dir, sender_id)

func _perform_slipstream_field() -> void:
	var def = abilities.get("Q")
	q_timer = def.cooldown if def else 7.5
	var hit_pos = get_mouse_ground_intersection()
	var target_pos = global_position - global_transform.basis.z * 6.0
	if hit_pos != null:
		var raw_pos = Vector3(hit_pos.x, 0.0, hit_pos.z)
		var max_cast_dist = 18.0
		if global_position.distance_to(raw_pos) > max_cast_dist:
			target_pos = global_position + (raw_pos - global_position).normalized() * max_cast_dist
		else:
			target_pos = raw_pos
	target_pos.y = 0.05
	ability_cast.emit("Slipstream Field", "Q")
	if multiplayer.is_server():
		_spawn_slipstream(target_pos, 1)
	else:
		request_slipstream.rpc_id(1, target_pos)

func _spawn_slipstream(target_pos: Vector3, sender_id: int) -> void:
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node and main_node.has_method("spawn_slowing_dot_zone"):
		main_node.spawn_slowing_dot_zone(target_pos, 4.5, sender_id, 0.0, 0.35, 2.2, 0.30)

@rpc("any_peer", "call_remote", "reliable")
func request_slipstream(target_pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_spawn_slipstream(target_pos, sender_id)

func _perform_recon_flare() -> void:
	var def = abilities.get("E")
	e_timer = def.cooldown if def else 11.0
	var hit_pos = get_mouse_ground_intersection()
	var target_pos = global_position - global_transform.basis.z * 15.0
	if hit_pos != null:
		var raw_pos = Vector3(hit_pos.x, 0.0, hit_pos.z)
		var max_cast_dist = 30.0
		if global_position.distance_to(raw_pos) > max_cast_dist:
			target_pos = global_position + (raw_pos - global_position).normalized() * max_cast_dist
		else:
			target_pos = raw_pos
	
	var facing_dir = (target_pos - global_position).normalized()
	var spawn_pos = global_position + Vector3(0, 0.8, 0) + facing_dir * 1.0
	var target_distance = global_position.distance_to(target_pos)
	ability_cast.emit("Recon Flare", "E")
	if multiplayer.is_server():
		_spawn_recon_flare(spawn_pos, facing_dir, 1, target_distance)
	else:
		request_recon_flare.rpc_id(1, spawn_pos, facing_dir, target_distance)

func _spawn_recon_flare(spawn_pos: Vector3, shoot_dir: Vector3, sender_id: int, target_dist: float) -> void:
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node and main_node.has_method("spawn_vision_flare"):
		main_node.spawn_vision_flare(spawn_pos, shoot_dir, sender_id, target_dist)

@rpc("any_peer", "call_remote", "reliable")
func request_recon_flare(spawn_pos: Vector3, shoot_dir: Vector3, target_dist: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_spawn_recon_flare(spawn_pos, shoot_dir, sender_id, target_dist)

func _perform_overcharge() -> void:
	var def = abilities.get("R")
	r_timer = def.cooldown if def else 24.0
	poke_ult_buff_timer = POKE_ULT_BUFF_DURATION
	ability_cast.emit("Overcharge", "R")
	sync_poke_ult_buff.rpc(POKE_ULT_BUFF_DURATION)

@rpc("any_peer", "call_local", "reliable")
func sync_poke_ult_buff(duration: float) -> void:
	poke_ult_buff_timer = duration

func _on_character_damage_dealt(_target: Node, _amount: float, _action_type: int) -> void:
	# Trigger Fleet Foot speed boost on hit
	poke_speed_boost_timer = 2.5
	poke_speed_boost_percent = 0.15

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
		slot_ability_four.set_active_state(poke_ult_buff_timer > 0.0)
	if slot_dash and def_shift:
		slot_dash.update_cooldown(dash_timer, dash_cooldown, 1, 1, is_rooted() or is_grounded())
