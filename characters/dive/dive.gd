class_name Dive
extends BasePlayer

# Ability Timers & Cooldowns
var attack_timer: float = 0.0
var rmb_timer: float = 0.0
var q_timer: float = 0.0
var e_timer: float = 0.0
var r_timer: float = 0.0

# Dash Charges & Lockout
var current_dash_charges: int = 1
var max_dash_charges: int = 1
var dash_lockout_timer: float = 0.0
var dash_recharge_timer: float = 0.0
var dash_impulse: float = 26.0
var dash_lockout: float = 0.85
var dash_recharge_time: float = 5.0
var wall_bounce_ratio: float = 0.55
var dash_wall_bounce_timer: float = 0.0
var dive_dash_dir: Vector3 = Vector3.FORWARD
var is_wall_launched: bool = false
var wall_launch_air_time: float = 0.0

# Deflecting Guard (Block Stance)
var is_blocking: bool = false:
	set(value):
		is_blocking = value
		if block_visual:
			block_visual.visible = value
var block_timer: float = 0.0
const BLOCK_DURATION: float = 3.0
const BLOCK_MAX_TURN_SPEED: float = 2.2
const BLOCK_DR_PERCENT: float = 0.75

# Rupture Marks
var dive_marks_count: int = 0
var dive_mark_timer: float = 0.0
var dive_mark_attacker_id: int = 0
const DIVE_MARK_DURATION: float = 3.5
const DIVE_MARK_MAX: int = 5
const DIVE_MARK_BURST_PER_STACK: float = 18.0

# Tectonic Uprising (Ultimate Buff)
var dive_ult_buff_timer: float = 0.0
const DIVE_ULT_BUFF_DURATION: float = 6.0
const DIVE_ULT_SPEED_MULT: float = 0.35
const DIVE_ULT_ATTACK_SPEED_MULT: float = 0.40

# Aerial Crash Down
var is_crashing_down: bool = false:
	set(value):
		is_crashing_down = value
		if crash_visual:
			crash_visual.visible = value
var crash_target_pos: Vector3 = Vector3.ZERO
const CRASH_SPEED: float = 52.0
const CRASH_DAMAGE: float = 36.0
const CRASH_RADIUS: float = 6.0

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
var ind_crash_circle: Node3D = null

@onready var melee_visual: Node3D = get_node_or_null("MeleeVisual")
@onready var ability_one_visual: Node3D = get_node_or_null("AbilityOneVisual")
@onready var block_visual: Node3D = get_node_or_null("BlockVisual")
@onready var crash_visual: Node3D = get_node_or_null("CrashVisual")

func _setup_character_kit() -> void:
	var data = DiveData.create()
	load_character_data(data)

	dash_impulse = data.passive_data.get("dash_impulse", 26.0)
	max_dash_charges = data.passive_data.get("max_dash_charges", 1)
	current_dash_charges = max_dash_charges
	dash_lockout = data.passive_data.get("dash_lockout", 0.85)
	dash_recharge_time = data.passive_data.get("dash_recharge_time", 5.0)
	wall_bounce_ratio = data.passive_data.get("wall_bounce_ratio", 0.55)

	_setup_local_indicators()

	var sync = get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	if sync and sync.replication_config:
		_add_sync_property(sync.replication_config, NodePath(".:is_blocking"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		_add_sync_property(sync.replication_config, NodePath(".:is_crashing_down"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		_add_sync_property(sync.replication_config, NodePath(".:dive_ult_buff_timer"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)

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

	# Discrete location indicator for Aerial Crash Down
	var crash_hitbox = AbilityPipeline.AbilityHitbox.new()
	crash_hitbox.shape = AbilityPipeline.HitboxShape.CIRCLE
	crash_hitbox.radius = CRASH_RADIUS
	ind_crash_circle = AbilityIndicator.create_discrete_location_indicator(crash_hitbox, AbilityIndicator.EMPTY_FILL, AbilityIndicator.WHITE_OUTLINE)
	add_child(ind_crash_circle)
	ind_crash_circle.hide()

func _exit_tree() -> void:
	if ind_crash_circle and is_instance_valid(ind_crash_circle):
		ind_crash_circle.queue_free()

func _process_character_kit(delta: float) -> void:
	# Dive Rupture Marks tick (Server-authoritative)
	if (not is_multiplayer_match() or multiplayer.is_server()) and not is_dead and dive_marks_count > 0:
		dive_mark_timer -= delta
		if dive_mark_timer <= 0.0:
			detonate_dive_marks()

	# Dive Block Duration
	if is_blocking:
		block_timer -= delta
		if block_timer <= 0.0:
			end_block_stance()

	if dive_ult_buff_timer > 0.0:
		dive_ult_buff_timer -= delta
		if dive_ult_buff_timer <= 0.0:
			dive_ult_buff_timer = 0.0

	if is_local_player():
		if dash_lockout_timer > 0.0:
			dash_lockout_timer -= delta

		if current_dash_charges < max_dash_charges:
			dash_recharge_timer += delta
			if dash_recharge_timer >= dash_recharge_time:
				current_dash_charges += 1
				dash_recharge_timer = 0.0 if current_dash_charges == max_dash_charges else (dash_recharge_timer - dash_recharge_time)
		else:
			dash_recharge_timer = 0.0

		var cd_mult = 1.4 if dive_ult_buff_timer > 0.0 else 1.0
		if attack_timer > 0.0: attack_timer -= delta * cd_mult
		if rmb_timer > 0.0: rmb_timer -= delta * cd_mult
		if q_timer > 0.0: q_timer -= delta
		if e_timer > 0.0: e_timer -= delta
		if r_timer > 0.0: r_timer -= delta

		# Dive Wall Bounce detection
		if dash_wall_bounce_timer > 0.0:
			dash_wall_bounce_timer -= delta
			_check_dive_wall_bounce()

		# Aerial Crash Movement
		if is_crashing_down:
			var to_target = crash_target_pos - global_position
			to_target.y = 0.0
			var horizontal_dist = to_target.length()
			if horizontal_dist > 0.5:
				var move_dir = to_target.normalized()
				velocity.x = move_dir.x * 24.0
				velocity.z = move_dir.z * 24.0
			else:
				velocity.x = 0.0
				velocity.z = 0.0
			velocity.y = -CRASH_SPEED

			if is_on_floor():
				_execute_crash_impact()
		elif is_wall_launched:
			wall_launch_air_time += delta
			if wall_launch_air_time > 0.30 and is_on_floor() and velocity.y <= 0.0 and not is_crashing_down:
				is_wall_launched = false
				wall_launch_air_time = 0.0
				end_float_state()
				_try_resolve_buffered_ability()

func get_effective_max_speed(current_speed: float) -> float:
	if dive_ult_buff_timer > 0.0:
		return current_speed * (1.0 + DIVE_ULT_SPEED_MULT)
	return current_speed

func is_in_airborne_state() -> bool:
	return is_wall_launched or is_crashing_down

func get_status_text() -> String:
	if is_blocking:
		return "✦ DEFLECTING GUARD (75%% DR) (%.1fs) ✦" % block_timer
	elif dive_ult_buff_timer > 0.0:
		return "✦ TECTONIC UPRISING (+35%% MS / +40%% AS) (%.1fs) ✦" % dive_ult_buff_timer
	elif is_in_airborne_state():
		if is_crashing_down:
			return "✦ CRASHING DOWN ✦"
		elif can_crash_down():
			return "✦ WALL LAUNCHED (SHIFT: CRASH) ✦"
	return ""

func can_crash_down() -> bool:
	return is_wall_launched and not is_crashing_down

func _handle_character_input(_delta: float) -> void:
	if is_channeling:
		return

	# Update indicators
	var can_crash = can_crash_down()
	if ind_crash_circle:
		if can_crash and not is_stunned():
			var hit_pos = get_mouse_ground_intersection()
			if hit_pos != null:
				AbilityIndicator.update_discrete_location(ind_crash_circle, hit_pos)
				ind_crash_circle.show()
			else:
				ind_crash_circle.hide()
		else:
			ind_crash_circle.hide()

	# --- Airborne State: Only Crash Down via Dash (SHIFT) is permitted ---
	if is_in_airborne_state():
		if is_holding_shoot:
			is_holding_shoot = false
			if ind_attack: ind_attack.hide()
		if is_holding_rmb:
			is_holding_rmb = false
			if ind_rmb: ind_rmb.hide()
		if is_holding_q:
			is_holding_q = false
			if ind_q: ind_q.hide()
		if is_holding_e:
			is_holding_e = false
			if ind_e: ind_e.hide()
		if is_holding_r:
			is_holding_r = false
			if ind_r: ind_r.hide()

		if can_crash and not is_rooted() and not is_grounded():
			if Input.is_action_just_pressed("dash"):
				_perform_crash_down()
		return

	# --- Normal Dash (SHIFT) ---
	if is_cast_on_press("dash"):
		if Input.is_action_just_pressed("dash") and not is_rooted() and not is_grounded():
			if current_dash_charges > 0 and dash_lockout_timer <= 0.0:
				_execute_dive_dash()
	else:
		if Input.is_action_just_pressed("dash") and not is_rooted() and not is_grounded():
			if current_dash_charges > 0 and dash_lockout_timer <= 0.0:
				is_holding_dash = true
		if Input.is_action_just_released("dash") and is_holding_dash:
			is_holding_dash = false
			if current_dash_charges > 0 and dash_lockout_timer <= 0.0 and not is_rooted() and not is_grounded():
				_execute_dive_dash()

	# --- Primary Fire (LMB): Slash ---
	if is_cast_on_press("shoot"):
		if Input.is_action_just_pressed("shoot") or (Input.is_action_pressed("shoot") and attack_timer <= 0.0):
			if attack_timer <= 0.0:
				_perform_slash()
	else:
		if Input.is_action_just_pressed("shoot"):
			is_holding_shoot = true
			if ind_attack:
				AbilityIndicator.reset_indicator(ind_attack)
				ind_attack.show()
		if Input.is_action_just_released("shoot") and is_holding_shoot:
			is_holding_shoot = false
			if ind_attack: ind_attack.hide()
			if attack_timer <= 0.0:
				_perform_slash()

	# --- Ability 1 (RMB): Heavy Cleave ---
	if is_cast_on_press("ability_one"):
		if Input.is_action_just_pressed("ability_one") and rmb_timer <= 0.0 and not is_silenced():
			_perform_heavy_cleave()
	else:
		if Input.is_action_just_pressed("ability_one") and not is_silenced():
			if rmb_timer <= 0.0:
				is_holding_rmb = true
				if ind_rmb:
					AbilityIndicator.reset_indicator(ind_rmb)
					ind_rmb.show()
		if Input.is_action_just_released("ability_one") and is_holding_rmb:
			is_holding_rmb = false
			if ind_rmb: ind_rmb.hide()
			if rmb_timer <= 0.0 and not is_silenced():
				_perform_heavy_cleave()

	# --- Ability 2 (Q): Earth Tremor ---
	if is_cast_on_press("ability_two"):
		if Input.is_action_just_pressed("ability_two") and q_timer <= 0.0 and not is_silenced():
			_perform_earth_tremor()
	else:
		if Input.is_action_just_pressed("ability_two") and not is_silenced():
			if q_timer <= 0.0:
				is_holding_q = true
				if ind_q:
					AbilityIndicator.reset_indicator(ind_q)
					ind_q.show()
		if Input.is_action_just_released("ability_two") and is_holding_q:
			is_holding_q = false
			if q_timer <= 0.0 and not is_silenced():
				_perform_earth_tremor()
			else:
				if ind_q: ind_q.hide()

	# --- Ability 3 (E): Deflecting Guard ---
	if is_cast_on_press("ability_three"):
		if Input.is_action_just_pressed("ability_three") and e_timer <= 0.0 and not is_silenced():
			_perform_deflecting_guard()
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
				_perform_deflecting_guard()

	# --- Ultimate (R): Tectonic Uprising ---
	if is_cast_on_press("ability_four"):
		if Input.is_action_just_pressed("ability_four") and r_timer <= 0.0:
			_perform_tectonic_uprising()
	else:
		if Input.is_action_just_pressed("ability_four"):
			if r_timer <= 0.0:
				is_holding_r = true
				if ind_r:
					AbilityIndicator.reset_indicator(ind_r)
					ind_r.show()
		if Input.is_action_just_released("ability_four") and is_holding_r:
			is_holding_r = false
			if ind_r: ind_r.hide()
			if r_timer <= 0.0:
				_perform_tectonic_uprising()

func _execute_dive_dash() -> void:
	current_dash_charges -= 1
	dash_lockout_timer = dash_lockout
	var dash_dir = get_dash_direction()
	dive_dash_dir = dash_dir
	dash_wall_bounce_timer = 0.65
	var effective_impulse = get_effective_dash_impulse(dash_impulse)
	apply_velocity_impulse(Vector3(dash_dir.x * effective_impulse, 0, dash_dir.z * effective_impulse), true)
	_check_dive_wall_bounce()

func _check_dive_wall_bounce() -> void:
	if dash_wall_bounce_timer <= 0.0:
		return
	var hit_wall = is_on_wall()
	if not hit_wall:
		for i in range(get_slide_collision_count()):
			var col = get_slide_collision(i)
			var norm = col.get_normal()
			if abs(norm.y) < 0.70: # Vertical surface / wall
				hit_wall = true
				break
	if not hit_wall:
		var space_state = get_world_3d().direct_space_state
		if space_state:
			for y_off in [0.4, 1.1]:
				var start_p = global_position + Vector3(0, y_off, 0)
				var end_p = start_p + dive_dash_dir * 2.2
				var query = PhysicsRayQueryParameters3D.create(start_p, end_p, 1)
				query.collide_with_areas = false
				query.collide_with_bodies = true
				query.exclude = [self.get_rid()]
				var res = space_state.intersect_ray(query)
				if not res.is_empty():
					var norm = res.normal
					if abs(norm.y) < 0.70:
						hit_wall = true
						break

	if hit_wall:
		_trigger_wall_bounce()

func _trigger_wall_bounce() -> void:
	dash_wall_bounce_timer = 0.0
	dash_lockout_timer = 0.0
	is_wall_launched = true
	wall_launch_air_time = 0.0
	# Convert horizontal momentum to vertical momentum with the reduced ratio
	var horiz_speed = Vector2(velocity.x, velocity.z).length()
	var base_speed = max(horiz_speed, get_effective_dash_impulse(dash_impulse) * 0.8)
	velocity.x = 0.0
	velocity.z = 0.0
	velocity.y = base_speed * wall_bounce_ratio
	start_float_state()

	# Clear any active holding state or indicators upon launching airborne
	is_holding_shoot = false
	is_holding_rmb = false
	is_holding_q = false
	is_holding_e = false
	is_holding_r = false
	if ind_attack: ind_attack.hide()
	if ind_rmb: ind_rmb.hide()
	if ind_q: ind_q.hide()
	if ind_e: ind_e.hide()
	if ind_r: ind_r.hide()

func _perform_crash_down() -> void:
	var hit_pos = get_mouse_ground_intersection()
	var target = Vector3(hit_pos.x, 0.0, hit_pos.z) if hit_pos != null else (global_position - global_transform.basis.z * 5.0)
	var max_range = 18.0
	var horizontal_offset = target - Vector3(global_position.x, 0.0, global_position.z)
	if horizontal_offset.length() > max_range:
		target = Vector3(global_position.x, 0.0, global_position.z) + horizontal_offset.normalized() * max_range

	end_float_state()
	is_crashing_down = true
	crash_target_pos = target
	velocity.x = 0.0
	velocity.z = 0.0
	velocity.y = -CRASH_SPEED
	ability_cast.emit("Aerial Crash", "SHIFT")
	sync_crash_state.rpc(true)

@rpc("any_peer", "call_local", "reliable")
func sync_crash_state(crashing: bool) -> void:
	is_crashing_down = crashing
	if not crashing:
		is_wall_launched = false
	if crash_visual:
		crash_visual.visible = crashing

func _execute_crash_impact() -> void:
	is_crashing_down = false
	is_wall_launched = false
	sync_crash_state.rpc(false)
	if ind_crash_circle and is_instance_valid(ind_crash_circle):
		AbilityIndicator.flash_and_fade(ind_crash_circle, get_tree(), 0.15)
	var impact_pos = global_position
	if not is_multiplayer_match() or multiplayer.is_server():
		_execute_crash_damage(impact_pos, 1)
	else:
		request_crash_impact.rpc_id(1, impact_pos)
	_try_resolve_buffered_ability()

func _execute_crash_damage(impact_pos: Vector3, attacker_id: int) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if players_container:
		for player in players_container.get_children():
			if player is Node3D and player.name != str(attacker_id) and not player.get("is_dead") and is_enemy(player):
				if player.global_position.distance_to(impact_pos) <= CRASH_RADIUS:
					if player.has_method("take_damage"):
						player.take_damage(CRASH_DAMAGE, attacker_id, ActionType.ABILITY)
					if player.has_method("apply_knockback"):
						var kb_dir = (player.global_position - impact_pos).normalized()
						kb_dir.y = 0.0
						player.apply_knockback(Vector3.UP * 4.5 + kb_dir * 7.5, true)

@rpc("any_peer", "call_remote", "reliable")
func request_crash_impact(impact_pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_execute_crash_damage(impact_pos, sender_id)

func _perform_slash() -> void:
	var def = abilities.get("LMB")
	attack_timer = def.cooldown if def else 0.45
	var dmg = def.riders[0].amount if (def and not def.riders.is_empty()) else 32.0
	var rad = def.hitbox.radius if (def and def.hitbox) else 3.4
	var angle_deg = def.hitbox.angle_deg if (def and def.hitbox) else 100.0
	var height = def.hitbox.height if (def and def.hitbox and def.hitbox.height > 0.0) else 2.4
	var facing_dir = -global_transform.basis.z.normalized()
	attack_performed.emit("Slash")
	trigger_ability_hitbox("LMB", global_position, facing_dir)
	if not is_multiplayer_match() or multiplayer.is_server():
		_execute_melee_strike(global_position, facing_dir, 1, dmg, rad, angle_deg, true, height)
	else:
		request_melee_strike.rpc_id(1, global_position, facing_dir, dmg, rad, angle_deg, true, height)

func _perform_heavy_cleave() -> void:
	var def = abilities.get("RMB")
	rmb_timer = def.cooldown if def else 6.0
	var dmg = def.riders[0].amount if (def and not def.riders.is_empty()) else 65.0
	var rad = def.hitbox.radius if (def and def.hitbox) else 3.0
	var angle_deg = def.hitbox.angle_deg if (def and def.hitbox) else 135.0
	var height = def.hitbox.height if (def and def.hitbox and def.hitbox.height > 0.0) else 2.4
	var facing_dir = -global_transform.basis.z.normalized()
	ability_cast.emit("Heavy Cleave", "RMB")
	trigger_ability_hitbox("RMB", global_position, facing_dir)
	if not is_multiplayer_match() or multiplayer.is_server():
		_execute_melee_strike(global_position, facing_dir, 1, dmg, rad, angle_deg, true, height)
	else:
		request_melee_strike.rpc_id(1, global_position, facing_dir, dmg, rad, angle_deg, true, height)

func _execute_melee_strike(origin_pos: Vector3, forward_dir: Vector3, attacker_id: int, dmg: float, radius: float, angle_deg: float, apply_mark: bool, height: float = 2.4) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	var half_angle_rad = deg_to_rad(angle_deg * 0.5)
	for body in players_container.get_children():
		if body is Node3D and body.name != str(attacker_id) and not body.get("is_dead") and is_enemy(body):
			var to_body = body.global_position - origin_pos
			var dy = to_body.y
			if dy < -2.0 or dy > height:
				continue
			to_body.y = 0.0
			var dist = to_body.length()
			if dist <= radius and dist > 0.001:
				var angle = forward_dir.angle_to(to_body.normalized())
				if angle <= half_angle_rad:
					if body.has_method("take_damage"):
						body.take_damage(dmg, attacker_id, ActionType.ATTACK)
					if apply_mark and body.has_method("apply_rupture_mark"):
						body.apply_rupture_mark(attacker_id)

@rpc("any_peer", "call_remote", "reliable")
func request_melee_strike(origin_pos: Vector3, forward_dir: Vector3, dmg: float, radius: float, angle_deg: float, apply_mark: bool, height: float = 2.4) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_execute_melee_strike(origin_pos, forward_dir, sender_id, dmg, radius, angle_deg, apply_mark, height)

func apply_rupture_mark(attacker_id: int) -> void:
	if (is_multiplayer_match() and not multiplayer.is_server()) or is_dead:
		return
	dive_mark_attacker_id = attacker_id
	dive_marks_count = min(DIVE_MARK_MAX, dive_marks_count + 1)
	dive_mark_timer = DIVE_MARK_DURATION
	if dive_marks_count >= DIVE_MARK_MAX:
		detonate_dive_marks()

func detonate_dive_marks() -> void:
	if dive_marks_count <= 0:
		return
	var total_burst = dive_marks_count * DIVE_MARK_BURST_PER_STACK
	var att_id = dive_mark_attacker_id
	dive_marks_count = 0
	dive_mark_timer = 0.0
	take_damage(total_burst, att_id, ActionType.ABILITY)

func _perform_earth_tremor() -> void:
	var def = abilities.get("Q")
	q_timer = def.cooldown if def else 8.0
	if ind_q:
		AbilityIndicator.reset_indicator(ind_q)
		ind_q.show()
	start_channel(0.35, _on_q_channel_finished)
	ability_cast.emit("Earth Tremor", "Q")

func _on_q_channel_finished() -> void:
	if ind_q:
		AbilityIndicator.flash_and_fade(ind_q, get_tree(), 0.14)
	var facing_dir = -global_transform.basis.z.normalized()
	var spawn_pos = global_position + Vector3(0, 0.4, 0) + facing_dir * 1.5
	if not is_multiplayer_match() or multiplayer.is_server():
		_spawn_earth_tremor(spawn_pos, facing_dir, 1)
	else:
		request_earth_tremor.rpc_id(1, spawn_pos, facing_dir)

func _spawn_earth_tremor(spawn_pos: Vector3, shoot_dir: Vector3, sender_id: int) -> void:
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node and main_node.has_method("spawn_projectile"):
		main_node.spawn_projectile(
			spawn_pos,
			shoot_dir,
			sender_id,
			18.0,
			28.0,
			1.5,
			14.0 / 28.0,
			"slow",
			2.0,
			0.40,
			true,
			true,
			0,
			ActionType.ABILITY,
			14.0
		)

@rpc("any_peer", "call_remote", "reliable")
func request_earth_tremor(spawn_pos: Vector3, shoot_dir: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_spawn_earth_tremor(spawn_pos, shoot_dir, sender_id)

func _perform_deflecting_guard() -> void:
	var def = abilities.get("E")
	e_timer = def.cooldown if def else 10.0
	cleanse_cc()
	is_blocking = true
	block_timer = BLOCK_DURATION
	ability_cast.emit("Deflecting Guard", "E")
	sync_block_state.rpc(true)

func end_block_stance() -> void:
	is_blocking = false
	block_timer = 0.0
	sync_block_state.rpc(false)

@rpc("any_peer", "call_local", "reliable")
func sync_block_state(blocking: bool) -> void:
	is_blocking = blocking
	if block_visual:
		block_visual.visible = blocking

func modify_incoming_damage(amount: float, attacker_id: int, action_type: int) -> float:
	if is_blocking:
		var attacker = get_tree().root.get_node_or_null("Main/Players/" + str(attacker_id))
		if attacker:
			var to_attacker = (attacker.global_position - global_position).normalized()
			to_attacker.y = 0.0
			var forward_dir = -global_transform.basis.z.normalized()
			forward_dir.y = 0.0
			var angle_deg = rad_to_deg(forward_dir.angle_to(to_attacker))
			if angle_deg <= 70.0:
				return amount * (1.0 - BLOCK_DR_PERCENT)
	return amount

func _perform_tectonic_uprising() -> void:
	var def = abilities.get("R")
	r_timer = def.cooldown if def else 24.0
	cleanse_cc()
	dive_ult_buff_timer = DIVE_ULT_BUFF_DURATION
	ability_cast.emit("Tectonic Uprising", "R")
	sync_dive_ult.rpc(DIVE_ULT_BUFF_DURATION)

@rpc("any_peer", "call_local", "reliable")
func sync_dive_ult(duration: float) -> void:
	dive_ult_buff_timer = duration

func _update_character_hud() -> void:
	var def_lmb = abilities.get("LMB")
	var def_rmb = abilities.get("RMB")
	var def_q = abilities.get("Q")
	var def_e = abilities.get("E")
	var def_r = abilities.get("R")

	var airborne = is_in_airborne_state()

	if slot_lmb and def_lmb:
		slot_lmb.update_cooldown(attack_timer, def_lmb.cooldown, 1, 1, airborne)
	if slot_ability_one and def_rmb:
		slot_ability_one.update_cooldown(rmb_timer, def_rmb.cooldown, 1, 1, is_silenced() or airborne)
	if slot_ability_two and def_q:
		slot_ability_two.update_cooldown(q_timer, def_q.cooldown, 1, 1, is_silenced() or airborne)
	if slot_ability_three and def_e:
		slot_ability_three.update_cooldown(e_timer, def_e.cooldown, 1, 1, is_silenced() or airborne)
		slot_ability_three.set_active_state(is_blocking)
	if slot_ability_four and def_r:
		slot_ability_four.update_cooldown(r_timer, def_r.cooldown, 1, 1, airborne)
		slot_ability_four.set_active_state(dive_ult_buff_timer > 0.0)
	if slot_dash:
		var can_crash = can_crash_down()
		if can_crash:
			slot_dash.slot_name = "Crash"
			slot_dash.update_cooldown(0.0, 1.0, 1, 1, is_rooted() or is_grounded())
		else:
			slot_dash.slot_name = "Dash"
			var cd_ratio = (dash_recharge_time - dash_recharge_timer) if current_dash_charges < max_dash_charges else dash_lockout_timer
			slot_dash.update_cooldown(cd_ratio, dash_recharge_time, current_dash_charges, max_dash_charges, is_rooted() or is_grounded() or (airborne and not can_crash))

func is_in_cast_lockout() -> bool:
	return super.is_in_cast_lockout() or dash_lockout_timer > 0.0 or is_in_airborne_state()

func can_cast_ability_slot(slot_key: String, char_abilities: Dictionary = {}) -> bool:
	var key = slot_key.to_upper()
	if is_in_airborne_state():
		if key == "SHIFT" or key == "DASH":
			return can_crash_down() and not is_rooted() and not is_grounded() and not is_stunned()
		return false
	return super.can_cast_ability_slot(slot_key, char_abilities)

func execute_ability_slot(slot_key: String) -> bool:
	if is_dead:
		return false
	var key = slot_key.to_upper()
	if is_stunned() and key != "R" and key != "ABILITY_FOUR":
		return false
	match key:
		"LMB", "SHOOT":
			if attack_timer <= 0.0 and can_cast_ability_slot("LMB"):
				_perform_slash()
				return true
		"RMB", "ABILITY_ONE":
			if rmb_timer <= 0.0 and not is_silenced() and can_cast_ability_slot("RMB"):
				_perform_heavy_cleave()
				return true
		"Q", "ABILITY_TWO":
			if q_timer <= 0.0 and not is_silenced() and can_cast_ability_slot("Q"):
				_perform_earth_tremor()
				return true
		"E", "ABILITY_THREE":
			if e_timer <= 0.0 and not is_silenced() and can_cast_ability_slot("E"):
				_perform_deflecting_guard()
				return true
		"R", "ABILITY_FOUR":
			if r_timer <= 0.0 and can_cast_ability_slot("R"):
				_perform_tectonic_uprising()
				return true
		"SHIFT", "DASH":
			if can_crash_down() and not is_rooted() and not is_grounded() and can_cast_ability_slot("SHIFT"):
				_perform_crash_down()
				return true
			elif current_dash_charges > 0 and dash_lockout_timer <= 0.0 and not is_rooted() and not is_grounded() and can_cast_ability_slot("SHIFT"):
				_execute_dive_dash()
				return true
	return false
