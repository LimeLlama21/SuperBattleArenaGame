class_name PlayerPhysics
extends PlayerStatus

# --- Movement Parameters ---
@export var max_move_speed: float = 10.0
@export var ground_acceleration: float = 65.0
@export var ground_friction: float = 40.0
@export var intentional_movement_friction: float = 110.0
@export var air_acceleration: float = 8.0
@export var air_drag: float = 8.5
@export var jump_velocity: float = 11.2

var is_intentional_movement: bool = false
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 13.0)

# --- External Knockback & Wall Impact ---
var knockback_velocity: Vector3 = Vector3.ZERO
var knockback_wall_stun: float = 0.0
var wall_impact_cooldown_timer: float = 0.0
const WALL_IMPACT_MIN_SPEED: float = 6.0
const WALL_IMPACT_DAMAGE_FACTOR: float = 1.8

# --- Virtual hooks for subclass overrides ---
func modify_incoming_damage(amount: float, _attacker_id: int, _action_type: int) -> float:
	return amount

func get_effective_max_speed(current_speed: float) -> float:
	return current_speed

func has_custom_movement_control() -> bool:
	return false

func is_enemy(_other: Node) -> bool:
	return true

# --- Knockback & Impulse Application ---
func apply_knockback(impulse_vec: Vector3, _is_external: bool = true, wall_stun: float = 0.0) -> void:
	if is_cc_immune:
		return
	if is_multiplayer_match() and multiplayer.is_server():
		sync_knockback.rpc(impulse_vec, _is_external, wall_stun)
	else:
		_process_apply_knockback(impulse_vec, wall_stun)

@rpc("any_peer", "call_local", "reliable")
func sync_knockback(impulse_vec: Vector3, _is_external: bool = true, wall_stun: float = 0.0) -> void:
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
	
	var viewport = get_viewport()
	var cam = viewport.get_camera_3d() if viewport else null
	if not viewport or not cam:
		return default_fwd
	
	var mouse_pos = viewport.get_mouse_position()
	var ray_origin = cam.project_ray_origin(mouse_pos)
	var ray_dir = cam.project_ray_normal(mouse_pos)
	var space_state = get_world_3d().direct_space_state
	
	# 1. Direct Raycast Hit against characters (Collision layer 2: players / dummies)
	var player_query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 300.0, 2)
	player_query.collide_with_areas = false
	player_query.collide_with_bodies = true
	player_query.exclude = [get_rid()]
	var player_result = space_state.intersect_ray(player_query)
	
	if not player_result.is_empty():
		var hit_collider = player_result.collider
		if hit_collider != self and hit_collider is CharacterBody3D and not hit_collider.get("is_dead") and is_enemy(hit_collider):
			var target_pos = hit_collider.global_position + Vector3(0, 0.85, 0)
			var shoot_dir = target_pos - spawn_pos
			if shoot_dir.length_squared() > 0.0001:
				return shoot_dir.normalized()
	
	# 2. Forgiving Proximity Check: If cursor is near an enemy character
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	var best_target_pos: Vector3 = Vector3.ZERO
	var min_screen_dist: float = 80.0 # Forgiving pixel radius around mouse cursor
	var max_ray_dist: float = 2.5     # 3D distance tolerance to ray (meters)
	
	if players_container:
		for p in players_container.get_children():
			if p != self and p is CharacterBody3D and not p.get("is_dead") and is_enemy(p):
				var t_pos = p.global_position + Vector3(0, 0.85, 0)
				if not cam.is_position_behind(t_pos):
					var screen_pos = cam.unproject_position(t_pos)
					var screen_dist = mouse_pos.distance_to(screen_pos)
					var v = t_pos - ray_origin
					var t = v.dot(ray_dir)
					if t > 0.0:
						var closest_pt = ray_origin + ray_dir * t
						var dist_to_ray = (t_pos - closest_pt).length()
						if screen_dist <= min_screen_dist and dist_to_ray <= max_ray_dist:
							min_screen_dist = screen_dist
							best_target_pos = t_pos

	if best_target_pos != Vector3.ZERO:
		var shoot_dir = best_target_pos - spawn_pos
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
		var drag_rate = ground_friction if on_floor_check else air_drag
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, drag_rate * delta)
		if knockback_velocity.length_squared() <= 0.001 or knockback_velocity.is_zero_approx():
			knockback_velocity = Vector3.ZERO
			knockback_wall_stun = 0.0
	else:
		knockback_wall_stun = 0.0

func _process_dummy_physics(delta: float) -> void:
	var on_floor_dummy = is_on_floor()
	if not on_floor_dummy:
		# Gravity applied as continuous acceleration: a * delta
		velocity.y -= gravity * delta
		velocity.x = move_toward(velocity.x, 0.0, air_drag * delta)
		velocity.z = move_toward(velocity.z, 0.0, air_drag * delta)
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, ground_friction * delta)
	var pre_move_vel_dummy = velocity
	move_and_slide()
	_check_wall_impact(pre_move_vel_dummy)

func _process_player_movement_physics(delta: float, is_channeling_active: bool) -> void:
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

	# Movement Vector
	var input_dir := Vector2.ZERO
	if not stunned and not rooted and not is_channeling_active:
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

	var effective_friction = intentional_movement_friction if (is_intentional_movement and on_floor) else ground_friction

	var wish_dir = Vector2(target_dir.x, target_dir.z)

	if wish_dir.length_squared() > 0.001:
		wish_dir = wish_dir.normalized()
		var current_speed_along_wish = current_horizontal.dot(wish_dir)
		var add_speed = effective_max_speed - current_speed_along_wish
		if add_speed > 0.0:
			var accel_rate = ground_acceleration if on_floor else air_acceleration
			var accel_step = min(accel_rate * delta, add_speed)
			current_horizontal += wish_dir * accel_step

		# When steering on ground or over max speed, apply friction/drag to non-wish components or excess speed
		if on_floor:
			cur_speed = current_horizontal.length()
			if cur_speed > effective_max_speed:
				var excess_bleed = min(effective_friction * delta, cur_speed - effective_max_speed)
				current_horizontal -= current_horizontal.normalized() * excess_bleed
				if current_horizontal.length() <= effective_max_speed:
					is_intentional_movement = false
	else:
		# No input: decelerate smoothly with friction/drag
		var drag_rate = effective_friction if on_floor else air_drag
		current_horizontal = current_horizontal.move_toward(Vector2.ZERO, drag_rate * delta)
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
