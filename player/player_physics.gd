class_name PlayerPhysics
extends PlayerStatus

# --- Movement Parameters ---
@export var max_move_speed: float = 6.0
@export var ground_acceleration: float = 25.0
@export var ground_deceleration: float = 40.0
@export var intentional_movement_friction: float = 75.0
var air_acceleration: float = 7.5
var air_max_speed_mult: float = 0.3
var air_drag: float = 16.0
var jump_velocity: float = 13.0
var jump_horizontal_impulse: float = 2.0

var is_mouse_hijacked: bool = false

var ground_friction: float:
	get: return ground_deceleration
	set(v): ground_deceleration = v

var is_intentional_movement: bool = false
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 28.0)

# --- External Knockback & Wall Impact ---
var knockback_velocity: Vector3 = Vector3.ZERO
var knockback_wall_stun: float = 0.0
var wall_impact_cooldown_timer: float = 0.0
const WALL_IMPACT_MIN_SPEED: float = 6.0
const WALL_IMPACT_DAMAGE_FACTOR: float = 1.8

# --- Virtual hooks for subclass overrides ---
func modify_incoming_damage(amount: float, _attacker_id: int, _action_type: int) -> float:
	return amount

func get_effective_max_speed(current_calculated_speed: float) -> float:
	return current_calculated_speed

func has_custom_movement_control() -> bool:
	return false

func is_sliding_down_slope() -> bool:
	if not is_on_floor():
		return false
	var floor_angle = get_floor_angle()
	if floor_angle > floor_max_angle:
		var floor_normal = get_floor_normal()
		if velocity.dot(floor_normal) < 0.1 and velocity.length_squared() > 0.2:
			return true
	return false

func is_enemy(_other: Node) -> bool:
	return true

# --- Knockback & Impulse Application ---
func apply_knockback(impulse_vec: Vector3, _is_external: bool = true, wall_stun: float = 0.0) -> void:
	if is_cc_immune or is_displacement_immune() or is_invulnerable() or is_bound():
		return
	if is_multiplayer_match():
		if not is_server_authoritative():
			return
		sync_knockback.rpc(impulse_vec, _is_external, wall_stun)
	else:
		_process_apply_knockback(impulse_vec, wall_stun)

@rpc("any_peer", "call_local", "reliable")
func sync_knockback(impulse_vec: Vector3, _is_external: bool = true, wall_stun: float = 0.0) -> void:
	if not _is_sender_host():
		return
	_process_apply_knockback(impulse_vec, wall_stun)

func _process_apply_knockback(impulse_vec: Vector3, wall_stun: float = 0.0) -> void:
	velocity += impulse_vec
	knockback_velocity += impulse_vec
	if wall_stun > knockback_wall_stun:
		knockback_wall_stun = wall_stun

func apply_velocity_impulse(impulse_vec: Vector3, is_intentional: bool = true) -> void:
	velocity.x = impulse_vec.x
	velocity.z = impulse_vec.z
	if impulse_vec.y != 0.0:
		velocity.y = impulse_vec.y
	if is_intentional:
		is_intentional_movement = true

# --- Aiming & Targeting Helpers ---
func aim_at_mouse() -> void:
	if is_mouse_hijacked:
		return
	if is_taunted():
		var taunter = get_taunt_target()
		if is_instance_valid(taunter):
			var target := Vector3(taunter.global_position.x, global_position.y, taunter.global_position.z)
			if global_position.distance_squared_to(target) > 0.3:
				look_at(target, Vector3.UP)
				rotation.x = 0.0
				rotation.z = 0.0
		return
	var hit_pos = get_mouse_ground_intersection()
	if hit_pos != null:
		var target := Vector3(hit_pos.x, global_position.y, hit_pos.z)
		if global_position.distance_squared_to(target) > 0.3:
			look_at(target, Vector3.UP)
			rotation.x = 0.0
			rotation.z = 0.0

func get_mouse_ground_intersection():
	var viewport = get_viewport()
	var cam = get_viewport().get_camera_3d() if viewport else null
	if not viewport or not cam:
		return null
	var mouse_pos = viewport.get_mouse_position()
	var ray_origin = cam.project_ray_origin(mouse_pos)
	var ray_dir = cam.project_ray_normal(mouse_pos)
	var ground_plane = Plane(Vector3.UP, global_position.y)
	return ground_plane.intersects_ray(ray_origin, ray_dir)

func get_ranged_aim_direction(spawn_pos: Vector3) -> Vector3:
	var default_fwd = -global_transform.basis.z.normalized()
	default_fwd.y = 0.0
	if default_fwd.length_squared() < 0.0001:
		default_fwd = Vector3.FORWARD
	default_fwd = default_fwd.normalized()
	
	if not is_local_player():
		return default_fwd
	
	if is_taunted():
		var taunter = get_taunt_target()
		if is_instance_valid(taunter):
			var dir = (taunter.global_position - spawn_pos)
			dir.y = 0.0
			if dir.length_squared() > 0.0001:
				return dir.normalized()
		return default_fwd
	
	var hit_pos = get_mouse_ground_intersection()
	if hit_pos != null:
		var target_pos = Vector3(hit_pos.x, spawn_pos.y, hit_pos.z)
		var shoot_dir = target_pos - spawn_pos
		shoot_dir.y = 0.0
		if shoot_dir.length_squared() > 0.0001:
			return shoot_dir.normalized()
	
	return default_fwd

func get_dash_direction() -> Vector3:
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move_dir = Vector3(input_dir.x, 0, input_dir.y).normalized()
	
	var mouse_dir = Vector3.ZERO
	var mouse_pos = get_mouse_ground_intersection()
	if mouse_pos != null:
		mouse_dir = mouse_pos - global_position
		mouse_dir.y = 0.0
		if mouse_dir.length_squared() > 0.001:
			mouse_dir = mouse_dir.normalized()
	if mouse_dir == Vector3.ZERO:
		mouse_dir = -global_transform.basis.z
		mouse_dir.y = 0.0
		mouse_dir = mouse_dir.normalized()
		if mouse_dir == Vector3.ZERO:
			mouse_dir = Vector3.FORWARD
	
	var mode = "smart"
	var sm = get_node_or_null("/root/SettingsManager")
	if sm and sm.has_method("get_dash_direction_mode"):
		mode = sm.get_dash_direction_mode()
	
	match mode:
		"mouse":
			return mouse_dir
		"movement":
			return move_dir if move_dir != Vector3.ZERO else mouse_dir
		"smart", _:
			if move_dir != Vector3.ZERO:
				var angle = move_dir.angle_to(mouse_dir)
				if angle <= deg_to_rad(30.0):
					return mouse_dir
				return move_dir
			return mouse_dir

func get_effective_dash_impulse(base_impulse: float) -> float:
	return base_impulse * get_slow_multiplier()

func is_cast_on_press(action: String) -> bool:
	var sm = get_node_or_null("/root/SettingsManager")
	if sm and sm.has_method("is_cast_on_press"):
		return sm.is_cast_on_press(action)
	return action in ["shoot", "dash"]

func is_cast_on_release(action: String) -> bool:
	return not is_cast_on_press(action)

# --- Process Timers & Movement Physics ---
func _process_physics_timers(delta: float) -> void:
	_process_status_timers(delta)

	if wall_impact_cooldown_timer > 0.0:
		wall_impact_cooldown_timer = max(0.0, wall_impact_cooldown_timer - delta)

	if knockback_velocity != Vector3.ZERO:
		var on_floor_check = is_on_floor()
		var drag_rate = ground_deceleration if on_floor_check else air_drag
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, drag_rate * delta)
		if knockback_velocity.length_squared() <= 0.001 or knockback_velocity.is_zero_approx():
			knockback_velocity = Vector3.ZERO
			knockback_wall_stun = 0.0
	else:
		knockback_wall_stun = 0.0

func _process_bound_physics(_delta: float) -> void:
	if not is_instance_valid(bound_caster_node) or (bound_caster_node.get("is_dead") == true):
		bound_timer = 0.0
		bound_caster_node = null
		bound_relative_offset = Vector3.ZERO
		return
	knockback_velocity = Vector3.ZERO
	var target_pos = bound_caster_node.global_position + bound_relative_offset
	global_position = target_pos
	velocity = Vector3.ZERO

func _process_dummy_physics(delta: float) -> void:
	if is_bound():
		_process_bound_physics(delta)
		return
	var on_floor_dummy = is_on_floor()
	if not on_floor_dummy:
		# Gravity applied as continuous acceleration: a * delta
		velocity.y -= gravity * delta
		velocity.x = move_toward(velocity.x, 0.0, air_drag * delta)
		velocity.z = move_toward(velocity.z, 0.0, air_drag * delta)
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0
		velocity.x = move_toward(velocity.x, 0.0, ground_deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, ground_deceleration * delta)
	var pre_move_vel_dummy = velocity
	move_and_slide()
	_check_wall_impact(pre_move_vel_dummy)

func _process_player_movement_physics(delta: float, is_channeling_active: bool) -> void:
	if is_bound():
		_process_bound_physics(delta)
		return
	if has_custom_movement_control():
		var pre_move_vel = velocity
		move_and_slide()
		_check_wall_impact(pre_move_vel)
		return

	var on_floor = is_on_floor()
	if not on_floor:
		# Gravity applied as continuous acceleration: a * delta
		var effective_gravity = gravity * (current_gravity_mult if is_floating else 1.0)
		velocity.y -= effective_gravity * delta
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0
		if is_floating and float_timer > 0.4:
			is_floating = false
			float_timer = 0.0
			current_gravity_mult = 1.0

	var stunned = is_stunned()
	var rooted = is_rooted()
	var grounded = is_grounded()
	var slow_mult = get_slow_multiplier()

	# Jump
	if not stunned and not rooted and not grounded and not is_channeling_active:
		if Input.is_action_just_pressed("jump") and on_floor:
			velocity.y = jump_velocity
			
			var jump_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
			var jump_h_dir := Vector3.ZERO
			if jump_input.length_squared() > 0.001:
				jump_h_dir = Vector3(jump_input.x, 0.0, jump_input.y).normalized()
			elif Vector2(velocity.x, velocity.z).length_squared() > 0.001:
				jump_h_dir = Vector3(velocity.x, 0.0, velocity.z).normalized()
			else:
				jump_h_dir = -global_transform.basis.z
				jump_h_dir.y = 0.0
				if jump_h_dir.length_squared() > 0.001:
					jump_h_dir = jump_h_dir.normalized()
				else:
					jump_h_dir = Vector3.FORWARD
			
			velocity.x += jump_h_dir.x * jump_horizontal_impulse
			velocity.z += jump_h_dir.z * jump_horizontal_impulse

	# Movement Vector: natural movement works under any circumstance unless immobilized (rooted) or stunned
	var input_dir := Vector2.ZERO
	if not stunned and not rooted:
		if is_taunted():
			var taunter = get_taunt_target()
			if is_instance_valid(taunter):
				var to_taunter = taunter.global_position - global_position
				to_taunter.y = 0.0
				if to_taunter.length_squared() > 0.01:
					var norm = to_taunter.normalized()
					input_dir = Vector2(norm.x, norm.z)
		else:
			input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target_dir := Vector3(input_dir.x, 0, input_dir.y).normalized()

	var effective_max_speed = max_move_speed * slow_mult
	if speed_boost_timer > 0.0:
		effective_max_speed *= (1.0 + speed_boost_percent)
	effective_max_speed = get_effective_max_speed(effective_max_speed)

	# Directional Acceleration Handling
	var current_horizontal = Vector2(velocity.x, velocity.z)
	var cur_speed = current_horizontal.length()

	# Intentional movement friction resets once speed drops to or below max movement speed
	if is_intentional_movement and cur_speed <= effective_max_speed:
		is_intentional_movement = false

	var wish_dir = Vector2(target_dir.x, target_dir.z)

	if wish_dir.length_squared() > 0.001:
		wish_dir = wish_dir.normalized()
		var accel_rate = ground_acceleration if on_floor else air_acceleration
		# Apply acceleration along wish direction whenever input is made
		current_horizontal += wish_dir * accel_rate * delta

		var cur_speed_after_accel = current_horizontal.length()
		var speed_cap = effective_max_speed

		# When steering on ground or in air with an intentional impulse (e.g. dash),
		# bleed excess speed smoothly rather than hard-clamping to max speed
		if is_intentional_movement and cur_speed_after_accel > speed_cap:
			var drag_rate = intentional_movement_friction if on_floor else air_drag
			var excess_bleed = min(drag_rate * delta, cur_speed_after_accel - speed_cap)
			current_horizontal -= current_horizontal.normalized() * excess_bleed
			if current_horizontal.length() <= speed_cap:
				is_intentional_movement = false
		elif cur_speed_after_accel > speed_cap:
			current_horizontal = current_horizontal.normalized() * speed_cap
	else:
		# No input: artificial deceleration towards 0 when no movement keys are pressed
		if on_floor:
			var decel_rate = intentional_movement_friction if (is_intentional_movement and cur_speed > effective_max_speed) else ground_deceleration
			current_horizontal = current_horizontal.move_toward(Vector2.ZERO, decel_rate * delta)
			if current_horizontal.length() <= effective_max_speed:
				is_intentional_movement = false
		else:
			current_horizontal = current_horizontal.move_toward(Vector2.ZERO, air_drag * delta)
			if current_horizontal.length() <= effective_max_speed:
				is_intentional_movement = false

	velocity.x = current_horizontal.x
	velocity.z = current_horizontal.y

	var pre_move_vel = velocity
	move_and_slide()
	_check_wall_impact(pre_move_vel)

func _check_wall_impact(pre_move_velocity: Vector3) -> void:
	if wall_impact_cooldown_timer > 0.0:
		return

	if get_slide_collision_count() == 0:
		return

	var kb_speed = knockback_velocity.length()
	if kb_speed < WALL_IMPACT_MIN_SPEED:
		return

	var is_violent_impact = false
	var max_impact_speed = 0.0

	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var normal = collision.get_normal()
		if normal.y > 0.7: # Floor/slopes do not trigger wall slams
			continue

		var impact_speed = -pre_move_velocity.dot(normal)
		if impact_speed >= WALL_IMPACT_MIN_SPEED:
			is_violent_impact = true
			max_impact_speed = max(max_impact_speed, impact_speed)

	if is_violent_impact:
		wall_impact_cooldown_timer = 0.5
		var impact_dmg = max_impact_speed * WALL_IMPACT_DAMAGE_FACTOR
		if knockback_wall_stun > 0.0:
			apply_stun(knockback_wall_stun)
		knockback_velocity = Vector3.ZERO
		knockback_wall_stun = 0.0
		velocity = Vector3.ZERO
		if is_server_authoritative():
			if has_method("take_damage"):
				call("take_damage", impact_dmg, 0, 2) # ActionType.ENVIRONMENT
		else:
			request_wall_impact_damage.rpc_id(1, impact_dmg)

@rpc("any_peer", "call_remote", "reliable")
func request_wall_impact_damage(amount: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	if str(sender_id) == name:
		if has_method("take_damage"):
			call("take_damage", amount, 0, 2) # ActionType.ENVIRONMENT
