class_name Poke
extends BasePlayer

# Ability Cooldowns & Timers
var shoot_timer: float = 0.0
var rmb_timer: float = 0.0
var q_timer: float = 0.0
var e_timer: float = 0.0
var r_timer: float = 0.0
var dash_timer: float = 0.0

# Passive & Buff State (Attack Speed Steroid on Takedown + Dash Reset)
var poke_as_buff_timer: float = 0.0
var poke_as_buff_percent: float = 0.60
var poke_as_buff_duration: float = 4.0
var current_camera_offset: Vector3 = CAMERA_OFFSET

# Sniper Stance State (RMB)
var is_in_sniper_stance: bool = false
var sniper_charge_timer: float = 0.0
const SNIPER_MAX_CHARGE_TIME: float = 2.0 # 2.0s full charge
const SNIPER_ATTACK_COOLDOWN: float = 1.0
const SNIPER_CAMERA_OFFSET: Vector3 = Vector3(0, 26.0, 6.97) # 15 degrees zoomed out
const RMB_FLAT_COOLDOWN: float = 2.0
const SNIPER_CONE_RADIUS: float = 45.0
const SNIPER_CONE_HALF_ANGLE_DEG: float = 16.0

# Q Ability: Overcharged Rounds State
var is_overcharge_active: bool = false
const OVERCHARGE_COOLDOWN: float = 20.0
const OVERCHARGE_BONUS_DAMAGE: float = 30.0

# Primary Fire: Rapid Pulse Shot parameters
const RAPID_SHOT_COOLDOWN: float = 0.11
const RAPID_SHOT_DAMAGE: float = 3.2
const RAPID_SHOT_RANGE: float = 15.5
const RAPID_SHOT_SPEED: float = 85.0
const RAPID_SHOT_SIZE: float = 0.25

# Dash parameters
var dash_impulse: float = 28.0
var dash_cooldown: float = 4.0

# Hold-to-aim indicator state
var is_holding_shoot: bool = false
var is_holding_dash: bool = false
var is_holding_e: bool = false
var is_holding_r: bool = false

var ind_attack: Node3D = null
var ind_e: Node3D = null
var ind_r: Node3D = null

func _setup_character_kit() -> void:
	var data = PokeData.create()
	load_character_data(data)

	dash_impulse = data.passive_data.get("dash_impulse", 28.0)
	dash_cooldown = data.passive_data.get("dash_cooldown", 4.0)
	poke_as_buff_duration = data.passive_data.get("takedown_as_duration", 4.0)
	poke_as_buff_percent = data.passive_data.get("takedown_as_percent", 0.60)

	_setup_local_indicators()

func _setup_local_indicators() -> void:
	if not is_local_player():
		return
	
	ind_attack = AbilityIndicator.create_line_indicator(RAPID_SHOT_RANGE, RAPID_SHOT_SIZE * 2.0, AbilityIndicator.EMPTY_FILL, AbilityIndicator.WHITE_OUTLINE, false, 1.0, true)
	add_child(ind_attack)
	ind_attack.hide()

	# Ability 3 (E): Ion Fence Line Indicator
	ind_e = AbilityIndicator.create_line_indicator(8.0, 0.25, Color(0.15, 0.85, 1.0, 0.35), Color(0.2, 0.95, 1.0, 0.95), false, 1.0, true)
	ind_e.top_level = true
	add_child(ind_e)
	ind_e.hide()

	# Ultimate (R): Orbital Hyperbeam Line Indicator (70m x 3.2m corridor)
	ind_r = AbilityIndicator.create_line_indicator(70.0, 3.2, Color(0.2, 0.9, 1.0, 0.35), Color(0.3, 0.95, 1.0, 0.95), false, 1.0, true)
	ind_r.top_level = true
	add_child(ind_r)
	ind_r.hide()

func _exit_tree() -> void:
	if ind_attack and is_instance_valid(ind_attack): ind_attack.queue_free()
	if ind_e and is_instance_valid(ind_e): ind_e.queue_free()
	if ind_r and is_instance_valid(ind_r): ind_r.queue_free()

func _process_character_kit(delta: float) -> void:
	if poke_as_buff_timer > 0.0:
		poke_as_buff_timer = max(0.0, poke_as_buff_timer - delta)

	if is_local_player():
		if shoot_timer > 0.0: shoot_timer -= delta
		if rmb_timer > 0.0: rmb_timer -= delta
		if q_timer > 0.0: q_timer -= delta
		if e_timer > 0.0: e_timer -= delta
		if r_timer > 0.0: r_timer -= delta
		if dash_timer > 0.0: dash_timer -= delta

		_handle_character_input(delta)
		_update_character_hud()

	# Smooth camera transition when zooming in/out of Sniper Stance
	var target_offset = SNIPER_CAMERA_OFFSET if is_in_sniper_stance else CAMERA_OFFSET
	current_camera_offset = current_camera_offset.lerp(target_offset, 8.0 * delta)
	if camera:
		camera.position = current_camera_offset

	# Dynamic Sniper Stance vision geometry
	if is_in_sniper_stance:
		forward_vision_range = SNIPER_CONE_RADIUS
		forward_vision_angle = SNIPER_CONE_HALF_ANGLE_DEG
	else:
		forward_vision_range = PlayerVision.CONE_RADIUS_M
		forward_vision_angle = PlayerVision.CONE_HALF_ANGLE_DEG

func get_attack_speed_bonus() -> float:
	var bonus = 0.0
	if poke_as_buff_timer > 0.0:
		bonus += poke_as_buff_percent
	return bonus

func _get_status_text() -> String:
	if is_channeling:
		return "✦ CHARGING HYPERBEAM (%.1fs) ✦" % max(0.0, channel_timer)
	if is_overcharge_active:
		return "✦ OVERCHARGED SNIPER (+%.0f DMG) ✦" % OVERCHARGE_BONUS_DAMAGE
	if is_in_sniper_stance:
		var charge_pct = clamp(sniper_charge_timer / SNIPER_MAX_CHARGE_TIME, 0.0, 1.0) * 100.0
		return "✦ SNIPER STANCE (%.0f%%) ✦" % charge_pct
	if poke_as_buff_timer > 0.0:
		return "✦ HYPERDRIVE (+%.0f%% AS) ✦" % (poke_as_buff_percent * 100.0)
	return ""

func _on_character_takedown(_victim: Node) -> void:
	# Large attack speed steroid and DASH RESET on takedown
	poke_as_buff_timer = poke_as_buff_duration
	dash_timer = 0.0

func _handle_character_input(_delta: float) -> void:
	if is_dead:
		if ind_attack: ind_attack.hide()
		if ind_e: ind_e.hide()
		if ind_r: ind_r.hide()
		if is_overcharge_active:
			_end_overcharge_buff()
		return

	# Indicator updates
	var hit_pos = get_mouse_ground_intersection()
	if hit_pos != null:
		var target_pos = Vector3(hit_pos.x, 0.05, hit_pos.z)
		if is_holding_e and ind_e:
			var max_cast_dist = 6.5
			var dist = global_position.distance_to(target_pos)
			if dist > max_cast_dist:
				var dir = (target_pos - global_position).normalized()
				target_pos = global_position + dir * max_cast_dist
			AbilityIndicator.update_line_indicator(ind_e, target_pos, rotation.y)

		if is_holding_r and ind_r:
			var aim_dir = (target_pos - global_position).normalized()
			aim_dir.y = 0.0
			var rot_y = atan2(-aim_dir.x, -aim_dir.z)
			AbilityIndicator.update_line_indicator(ind_r, global_position + aim_dir * 35.0, rot_y)

	# --- Secondary (RMB): Hold-to-Enter Sniper Stance ---
	if not is_silenced() and not is_channeling:
		if Input.is_action_pressed("ability_one"):
			if not is_in_sniper_stance and rmb_timer <= 0.0:
				_enter_sniper_stance()
		elif is_in_sniper_stance:
			_exit_sniper_stance()
	elif is_in_sniper_stance:
		_exit_sniper_stance()

	# --- IN SNIPER STANCE ---
	if is_in_sniper_stance:
		var as_mult = 1.0 + get_attack_speed_bonus()

		# Ability 2 (Q): Overcharged Rounds buff activation
		if Input.is_action_just_pressed("ability_two") and q_timer <= 0.0 and not is_overcharge_active and not is_silenced():
			_activate_overcharge_buff()

		# Hold LMB to charge sniper shot (takes full 2.0s)
		if Input.is_action_pressed("shoot"):
			is_holding_shoot = true
			sniper_charge_timer = min(SNIPER_MAX_CHARGE_TIME, sniper_charge_timer + _delta * as_mult)

		# Release LMB to fire charged sniper laser
		if Input.is_action_just_released("shoot") and is_holding_shoot:
			is_holding_shoot = false
			if shoot_timer <= 0.0:
				var charge_ratio = clamp(sniper_charge_timer / SNIPER_MAX_CHARGE_TIME, 0.0, 1.0)
				var base_dmg = lerp(35.0, 70.0, charge_ratio)
				var final_dmg = base_dmg + (OVERCHARGE_BONUS_DAMAGE if is_overcharge_active else 0.0)
				_perform_sniper_laser(final_dmg, is_overcharge_active)
				shoot_timer = SNIPER_ATTACK_COOLDOWN / as_mult
			sniper_charge_timer = 0.0
		elif not Input.is_action_pressed("shoot"):
			is_holding_shoot = false
			sniper_charge_timer = 0.0
		return

	# If channeling ultimate, lock other actions
	if is_channeling:
		return

	# --- NORMAL STANCE: Standard Abilities ---

	# --- Dash (SHIFT) ---
	if is_cast_on_press("dash"):
		if Input.is_action_just_pressed("dash") and dash_timer <= 0.0 and not is_rooted() and not is_grounded():
			_execute_dash()
	else:
		if Input.is_action_just_pressed("dash") and dash_timer <= 0.0 and not is_rooted() and not is_grounded():
			is_holding_dash = true
		if Input.is_action_just_released("dash") and is_holding_dash:
			is_holding_dash = false
			if dash_timer <= 0.0 and not is_rooted() and not is_grounded():
				_execute_dash()

	# --- Primary Fire (LMB): Rapid Pulse Shot (Auto-fire, high firerate, low damage) ---
	if Input.is_action_pressed("shoot"):
		if shoot_timer <= 0.0 and not is_silenced():
			_perform_rapid_shot()

	# --- Ability 3 (E): Ion Fence (Moved from Q to E) ---
	if is_cast_on_press("ability_three"):
		if Input.is_action_just_pressed("ability_three") and e_timer <= 0.0 and not is_silenced():
			_perform_ion_fence()
	else:
		if Input.is_action_just_pressed("ability_three") and not is_silenced():
			if e_timer <= 0.0:
				is_holding_e = true
				if ind_e:
					AbilityIndicator.reset_indicator(ind_e)
					ind_e.show()
		if Input.is_action_just_released("ability_three") and is_holding_e:
			is_holding_e = false
			if ind_e: ind_e.hide()
			if e_timer <= 0.0 and not is_silenced():
				_perform_ion_fence()

	# --- Ultimate (R): Orbital Hyperbeam (2-Second Channel, Piercing) ---
	if is_cast_on_press("ability_four"):
		if Input.is_action_just_pressed("ability_four") and r_timer <= 0.0 and not is_silenced():
			_start_orbital_hyperbeam_channel()
	else:
		if Input.is_action_just_pressed("ability_four") and not is_silenced():
			if r_timer <= 0.0:
				is_holding_r = true
				if ind_r:
					AbilityIndicator.reset_indicator(ind_r)
					ind_r.show()
		if Input.is_action_just_released("ability_four") and is_holding_r:
			is_holding_r = false
			if ind_r: ind_r.hide()
			if r_timer <= 0.0 and not is_silenced():
				_start_orbital_hyperbeam_channel()

func _enter_sniper_stance() -> void:
	is_in_sniper_stance = true
	sniper_charge_timer = 0.0
	if ind_attack:
		ind_attack.hide()

func _exit_sniper_stance() -> void:
	is_in_sniper_stance = false
	sniper_charge_timer = 0.0
	rmb_timer = RMB_FLAT_COOLDOWN
	if is_overcharge_active:
		_end_overcharge_buff()

func _activate_overcharge_buff() -> void:
	is_overcharge_active = true
	ability_cast.emit("Overcharged Rounds", "Q")

func _end_overcharge_buff() -> void:
	if not is_overcharge_active:
		return
	is_overcharge_active = false
	q_timer = OVERCHARGE_COOLDOWN

# Called by projectile when an empowered sniper shot hits an enemy
func on_empowered_sniper_hit(_target: Node) -> void:
	# Continues buff as long as shots hit!
	pass

# Called by projectile when an empowered sniper shot hits a wall or expires without hitting an enemy
func on_empowered_sniper_miss(_reason: String = "") -> void:
	if is_overcharge_active:
		_end_overcharge_buff()

func _execute_dash() -> void:
	dash_timer = dash_cooldown
	var dash_dir = get_dash_direction()
	var effective_impulse = get_effective_dash_impulse(dash_impulse)
	apply_velocity_impulse(Vector3(dash_dir.x * effective_impulse, 0, dash_dir.z * effective_impulse), true)

func _perform_rapid_shot() -> void:
	var as_mult = 1.0 + get_attack_speed_bonus()
	shoot_timer = RAPID_SHOT_COOLDOWN / as_mult
	var facing_dir = -global_transform.basis.z.normalized()
	facing_dir.y = 0.0
	facing_dir = facing_dir.normalized()
	var spawn_pos = global_position + Vector3(0, 0.8, 0) + facing_dir * 1.0
	var shoot_dir = get_ranged_aim_direction(spawn_pos)

	attack_performed.emit("Rapid Pulse Shot")
	if not is_multiplayer_match() or multiplayer.is_server():
		_spawn_rail_shot(spawn_pos, shoot_dir, 1, RAPID_SHOT_DAMAGE, RAPID_SHOT_SPEED, RAPID_SHOT_SIZE, RAPID_SHOT_RANGE, false, "")
	else:
		request_rail_shot.rpc_id(1, spawn_pos, shoot_dir, RAPID_SHOT_DAMAGE, RAPID_SHOT_SPEED, RAPID_SHOT_SIZE, RAPID_SHOT_RANGE, false, "")

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
			team_id,
			ActionType.ATTACK,
			max_rng
		)

@rpc("any_peer", "call_remote", "reliable")
func request_rail_shot(spawn_pos: Vector3, shoot_dir: Vector3, dmg: float, spd: float, p_size: float, max_rng: float, pierces: bool, eff: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_spawn_rail_shot(spawn_pos, shoot_dir, sender_id, dmg, spd, p_size, max_rng, pierces, eff)

func _perform_sniper_laser(final_damage: float, is_empowered: bool = false) -> void:
	var facing_dir = -global_transform.basis.z.normalized()
	facing_dir.y = 0.0
	facing_dir = facing_dir.normalized()
	var spawn_pos = global_position + Vector3(0, 0.8, 0) + facing_dir * 1.0
	var shoot_dir = get_ranged_aim_direction(spawn_pos)
	
	var spd = 120.0
	var sz = 0.45
	var rng = 70.0
	var pierces = true
	var eff = "poke_sniper_empowered" if is_empowered else "poke_sniper_laser"

	attack_performed.emit("Sniper Laser")
	if not is_multiplayer_match() or multiplayer.is_server():
		_spawn_rail_shot(spawn_pos, shoot_dir, 1, final_damage, spd, sz, rng, pierces, eff)
	else:
		request_rail_shot.rpc_id(1, spawn_pos, shoot_dir, final_damage, spd, sz, rng, pierces, eff)

func _perform_ion_fence() -> void:
	var def = abilities.get("E")
	e_timer = def.cooldown if def else 8.0
	var hit_pos = get_mouse_ground_intersection()
	var target_pos = global_position - global_transform.basis.z * 3.5
	var max_cast_dist = 6.5
	if hit_pos != null:
		var raw_pos = Vector3(hit_pos.x, 0.0, hit_pos.z)
		if global_position.distance_to(raw_pos) > max_cast_dist:
			target_pos = global_position + (raw_pos - global_position).normalized() * max_cast_dist
		else:
			target_pos = raw_pos
	target_pos.y = 0.05
	var fence_rot_y = rotation.y
	ability_cast.emit("Ion Fence", "E")
	if not is_multiplayer_match() or multiplayer.is_server():
		_spawn_ion_fence(target_pos, fence_rot_y, 1)
	else:
		request_ion_fence.rpc_id(1, target_pos, fence_rot_y)

func _spawn_ion_fence(target_pos: Vector3, fence_rot_y: float, sender_id: int) -> void:
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node and main_node.has_method("spawn_fence_zone"):
		main_node.spawn_fence_zone(target_pos, fence_rot_y, 8.0, 2.6, 0.25, 6.0, 2.5, sender_id)

@rpc("any_peer", "call_remote", "reliable")
func request_ion_fence(target_pos: Vector3, fence_rot_y: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_spawn_ion_fence(target_pos, fence_rot_y, sender_id)

var hyperbeam_charging_visual: Node3D = null

func _start_orbital_hyperbeam_channel() -> void:
	start_channel(2.0, _fire_orbital_hyperbeam)
	ability_cast.emit("Orbital Hyperbeam", "R")
	if is_multiplayer_match():
		sync_hyperbeam_charge_visual.rpc(true)
	else:
		_show_hyperbeam_charging_visual(true)

func _cleanup_hyperbeam_charging_visual() -> void:
	if hyperbeam_charging_visual and is_instance_valid(hyperbeam_charging_visual):
		hyperbeam_charging_visual.queue_free()
	hyperbeam_charging_visual = null

func _show_hyperbeam_charging_visual(show: bool) -> void:
	_cleanup_hyperbeam_charging_visual()
	if not show:
		return
	
	hyperbeam_charging_visual = Node3D.new()
	hyperbeam_charging_visual.name = "HyperbeamChargingVisual"
	# Position in front of Poke along local -Z axis (chest height Y=0.8, Z=-3.0)
	hyperbeam_charging_visual.position = Vector3(0.0, 0.8, -3.0)
	
	# Pure visual preview of the orbital hyperbeam projectile - NO hitbox / collision shape
	var mesh_inst = MeshInstance3D.new()
	var cap = CapsuleMesh.new()
	cap.radius = 1.4
	cap.height = 6.0
	mesh_inst.mesh = cap
	mesh_inst.rotation.x = deg_to_rad(90.0)
	
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.95, 1.0, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.95, 1.0, 1.0)
	mat.emission_energy_multiplier = 8.0
	mesh_inst.material_override = mat
	
	hyperbeam_charging_visual.add_child(mesh_inst)
	add_child(hyperbeam_charging_visual)
	
	# Scale-up / charging energy animation over 2.0s channel
	hyperbeam_charging_visual.scale = Vector3(0.15, 0.15, 0.15)
	var tween = create_tween()
	tween.tween_property(hyperbeam_charging_visual, "scale", Vector3(1.0, 1.0, 1.0), 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

@rpc("any_peer", "call_local", "reliable")
func sync_hyperbeam_charge_visual(active: bool) -> void:
	_show_hyperbeam_charging_visual(active)

func _on_channel_cancelled() -> void:
	super._on_channel_cancelled()
	if is_multiplayer_match():
		sync_hyperbeam_charge_visual.rpc(false)
	else:
		_show_hyperbeam_charging_visual(false)

func _fire_orbital_hyperbeam() -> void:
	if is_multiplayer_match():
		sync_hyperbeam_charge_visual.rpc(false)
	else:
		_show_hyperbeam_charging_visual(false)

	var def = abilities.get("R")
	r_timer = def.cooldown if def else 25.0

	var facing_dir = -global_transform.basis.z.normalized()
	facing_dir.y = 0.0
	facing_dir = facing_dir.normalized()
	var spawn_pos = global_position + Vector3(0, 0.8, 0) + facing_dir * 1.5
	var shoot_dir = get_ranged_aim_direction(spawn_pos)

	var dmg = 70.0
	var spd = 120.0
	var sz = 1.6
	var rng = 70.0
	var pierces = true
	var eff = "poke_orbital_hyperbeam"

	# Calculate trail corridor midpoint and orientation
	var trail_mid = global_position + facing_dir * (rng * 0.5)
	var trail_rot_y = atan2(-facing_dir.x, -facing_dir.z)

	if not is_multiplayer_match() or multiplayer.is_server():
		_spawn_rail_shot(spawn_pos, shoot_dir, 1, dmg, spd, sz, rng, pierces, eff)
		_spawn_trail_zone(trail_mid, trail_rot_y, rng, 3.2, 5.0, 30.0, 0.20, 1)
	else:
		request_hyperbeam.rpc_id(1, spawn_pos, shoot_dir, trail_mid, trail_rot_y, dmg, spd, sz, rng, pierces, eff)

func _spawn_trail_zone(pos: Vector3, rot_y: float, length: float, width: float, dur: float, dps_val: float, slow_pct: float, sender_id: int) -> void:
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node and main_node.has_method("spawn_rail_trail_zone"):
		main_node.spawn_rail_trail_zone(pos, rot_y, length, width, dur, dps_val, slow_pct, sender_id, team_id)

@rpc("any_peer", "call_remote", "reliable")
func request_hyperbeam(spawn_pos: Vector3, shoot_dir: Vector3, trail_pos: Vector3, trail_rot_y: float, dmg: float, spd: float, sz: float, rng: float, pierces: bool, eff: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_spawn_rail_shot(spawn_pos, shoot_dir, sender_id, dmg, spd, sz, rng, pierces, eff)
	_spawn_trail_zone(trail_pos, trail_rot_y, rng, 3.2, 5.0, 30.0, 0.20, sender_id)

func _on_character_damage_dealt(_target: Node, _amount: float, _action_type: int) -> void:
	pass

func _update_character_hud() -> void:
	var def_rmb = abilities.get("RMB")
	var def_q = abilities.get("Q")
	var def_e = abilities.get("E")
	var def_r = abilities.get("R")
	var def_shift = abilities.get("SHIFT")

	if slot_ability_one and def_rmb:
		slot_ability_one.update_cooldown(rmb_timer, RMB_FLAT_COOLDOWN, 1, 1, is_silenced() or is_channeling)
	if slot_ability_two and def_q:
		# Q Overcharge can only be cast while in Sniper Stance
		var q_locked = is_silenced() or not is_in_sniper_stance or is_overcharge_active or is_channeling
		slot_ability_two.update_cooldown(q_timer, OVERCHARGE_COOLDOWN, 1, 1, q_locked)
	if slot_ability_three and def_e:
		slot_ability_three.update_cooldown(e_timer, def_e.cooldown, 1, 1, is_silenced() or is_in_sniper_stance or is_channeling)
	if slot_ability_four and def_r:
		slot_ability_four.update_cooldown(r_timer, def_r.cooldown, 1, 1, is_silenced() or is_in_sniper_stance or is_channeling)
	if slot_dash and def_shift:
		slot_dash.update_cooldown(dash_timer, dash_cooldown, 1, 1, is_rooted() or is_grounded() or is_in_sniper_stance or is_channeling)

func execute_ability_slot(slot_key: String) -> bool:
	if is_dead or is_stunned():
		return false
	match slot_key.to_upper():
		"LMB", "SHOOT":
			if is_in_sniper_stance:
				if shoot_timer <= 0.0:
					var as_mult = 1.0 + get_attack_speed_bonus()
					var final_dmg = 70.0 + (OVERCHARGE_BONUS_DAMAGE if is_overcharge_active else 0.0)
					_perform_sniper_laser(final_dmg, is_overcharge_active)
					shoot_timer = SNIPER_ATTACK_COOLDOWN / as_mult
					return true
			elif shoot_timer <= 0.0 and not is_silenced() and can_cast_ability_slot("LMB"):
				_perform_rapid_shot()
				return true
		"RMB", "ABILITY_ONE":
			if not is_in_sniper_stance and rmb_timer <= 0.0 and not is_silenced() and can_cast_ability_slot("RMB"):
				_enter_sniper_stance()
				return true
		"Q", "ABILITY_TWO":
			if is_in_sniper_stance and q_timer <= 0.0 and not is_overcharge_active and not is_silenced() and can_cast_ability_slot("Q"):
				_activate_overcharge_buff()
				return true
		"E", "ABILITY_THREE":
			if e_timer <= 0.0 and not is_silenced() and not is_in_sniper_stance and can_cast_ability_slot("E"):
				_perform_ion_fence()
				return true
		"R", "ABILITY_FOUR":
			if r_timer <= 0.0 and not is_silenced() and not is_in_sniper_stance and can_cast_ability_slot("R"):
				_start_orbital_hyperbeam_channel()
				return true
		"SHIFT", "DASH":
			if dash_timer <= 0.0 and not is_rooted() and not is_grounded() and not is_in_sniper_stance and can_cast_ability_slot("SHIFT"):
				_execute_dash()
				return true
	return false
