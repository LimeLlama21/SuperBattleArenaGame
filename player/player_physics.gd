class_name PlayerPhysics
extends Node

## PlayerPhysics - Sibling component handling movement parameters,
## acceleration, drag, knockback, wall collisions, and impulse physics.

var player: CharacterBody3D = null

func _get_player() -> CharacterBody3D:
	if is_instance_valid(player):
		return player
	var parent = get_parent()
	if parent is CharacterBody3D:
		return parent as CharacterBody3D
	return null

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
	var p = _get_player()
	if p and p != self and p.has_method("get_effective_max_speed"):
		return p.get_effective_max_speed(current_calculated_speed)
	return current_calculated_speed

func get_effective_acceleration(current_calculated_accel: float) -> float:
	var p = _get_player()
	if p and p != self and p.has_method("get_effective_acceleration"):
		return p.get_effective_acceleration(current_calculated_accel)
	return current_calculated_accel

func has_custom_movement_control() -> bool:
	var p = _get_player()
	if p and p != self and p.has_method("has_custom_movement_control"):
		return p.has_custom_movement_control()
	return false

func is_in_move_lockout() -> bool:
	var p = _get_player()
	if p and p.has_method("is_in_move_lockout"):
		return p.is_in_move_lockout()
	return false

func is_sliding_down_slope() -> bool:
	var p = _get_player()
	if not p or not p.is_on_floor():
		return false
	var floor_angle = p.get_floor_angle()
	if floor_angle > p.floor_max_angle:
		var floor_normal = p.get_floor_normal()
		if p.velocity.dot(floor_normal) < 0.1 and p.velocity.length_squared() > 0.2:
			return true
	return false

func is_enemy(_other: Node) -> bool:
	return true

# --- Helper Status Accessors ---

func _get_status() -> PlayerStatus:
	var p = _get_player()
	if p and "status_comp" in p and p.status_comp:
		return p.status_comp
	return null

func is_cc_immune() -> bool:
	var s = _get_status()
	return s.is_cc_immune if s else false

func is_displacement_immune() -> bool:
	var s = _get_status()
	return s.is_displacement_immune() if s else false

func is_invulnerable() -> bool:
	var s = _get_status()
	return s.is_invulnerable() if s else false

func is_bound() -> bool:
	var s = _get_status()
	return s.is_bound() if s else false

func is_stunned() -> bool:
	var s = _get_status()
	return s.is_stunned() if s else false

func is_rooted() -> bool:
	var s = _get_status()
	return s.is_rooted() if s else false

func is_grounded() -> bool:
	var s = _get_status()
	return s.is_grounded() if s else false

func is_ethereal_active() -> bool:
	var s = _get_status()
	return s.is_ethereal_active() if s else false

func is_phasing_walls() -> bool:
	var s = _get_status()
	return s.is_phasing_walls() if s else false

func get_slow_multiplier() -> float:
	var s = _get_status()
	return s.get_slow_multiplier() if s else 1.0

func apply_stun(duration: float) -> void:
	var s = _get_status()
	if s: s.apply_stun(duration)

func is_multiplayer_match() -> bool:
	var p = _get_player()
	if p and p.has_method("is_multiplayer_match"):
		return p.is_multiplayer_match()
	return multiplayer and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0

func is_server_authoritative() -> bool:
	var p = _get_player()
	if p and p.has_method("is_server_authoritative"):
		return p.is_server_authoritative()
	if not is_multiplayer_match():
		return true
	return multiplayer.is_server()

func is_local_player() -> bool:
	var p = _get_player()
	if p and p.has_method("is_local_player"):
		return p.is_local_player()
	return true

func _is_sender_host() -> bool:
	if not is_multiplayer_match():
		return true
	if multiplayer.is_server():
		return true
	return multiplayer.get_remote_sender_id() == 1

# --- Knockback & Impulse Application ---

func apply_knockback(impulse_vec: Vector3, _is_external: bool = true, wall_stun: float = 0.0) -> void:
	if is_cc_immune() or is_displacement_immune() or is_invulnerable() or is_bound():
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
	var p = _get_player()
	if p:
		p.velocity += impulse_vec
	knockback_velocity += impulse_vec
	if wall_stun > knockback_wall_stun:
		knockback_wall_stun = wall_stun

func apply_velocity_impulse(impulse_vec: Vector3, is_intentional: bool = true) -> void:
	var p = _get_player()
	if p:
		p.velocity.x = impulse_vec.x
		p.velocity.z = impulse_vec.z
		if impulse_vec.y != 0.0:
			p.velocity.y = impulse_vec.y
	if is_intentional:
		is_intentional_movement = true

func apply_external_acceleration(accel_vec: Vector3, delta: float = 0.0) -> void:
	if is_cc_immune() or is_displacement_immune() or is_invulnerable() or is_bound():
		return
	var dt = delta if delta > 0.0 else get_physics_process_delta_time()
	var s = _get_status()
	if s:
		s.external_velocity += accel_vec * dt
		var max_ext_speed = max(12.0, accel_vec.length() * 1.5)
		if s.external_velocity.length() > max_ext_speed:
			s.external_velocity = s.external_velocity.normalized() * max_ext_speed

func get_facing_direction_3d() -> Vector3:
	var p = _get_player()
	if not p:
		return Vector3.FORWARD
	var fwd = -p.global_transform.basis.z.normalized()
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		fwd = Vector3.FORWARD
	return fwd.normalized()

# --- Aiming & Targeting Helpers ---

func aim_at_mouse() -> void:
	var p = _get_player()
	if not p:
		return
	if is_mouse_hijacked:
		return
	var s = _get_status()
	if s and s.is_taunted():
		var taunter = s.get_taunt_target()
		if is_instance_valid(taunter):
			var target: Vector3 = Vector3(taunter.global_position.x, p.global_position.y, taunter.global_position.z)
			if p.global_position.distance_squared_to(target) > 0.3:
				p.look_at(target, Vector3.UP)
				p.rotation.x = 0.0
				p.rotation.z = 0.0
		return
	if s and s.is_feared():
		var fear_source = s.get_fear_source_node()
		var away_dir := Vector3.ZERO
		if is_instance_valid(fear_source):
			away_dir = p.global_position - fear_source.global_position
		elif s.fear_source_pos != Vector3.ZERO:
			away_dir = p.global_position - s.fear_source_pos
		else:
			away_dir = -get_facing_direction_3d()
		away_dir.y = 0.0
		if away_dir.length_squared() > 0.01:
			var target: Vector3 = p.global_position + away_dir.normalized() * 5.0
			p.look_at(target, Vector3.UP)
			p.rotation.x = 0.0
			p.rotation.z = 0.0
		return
	var hit_pos = get_mouse_ground_intersection()
	if hit_pos != null:
		var target: Vector3 = Vector3(hit_pos.x, p.global_position.y, hit_pos.z)
		if p.global_position.distance_squared_to(target) > 0.3:
			p.look_at(target, Vector3.UP)
			p.rotation.x = 0.0
			p.rotation.z = 0.0

func get_mouse_ground_intersection():
	var p = _get_player()
	if not p:
		return null
	var viewport = p.get_viewport()
	var cam = viewport.get_camera_3d() if viewport else null
	if not viewport or not cam:
		return null
	var mouse_pos = viewport.get_mouse_position()
	var ray_origin = cam.project_ray_origin(mouse_pos)
	var ray_dir = cam.project_ray_normal(mouse_pos)

	var space = p.get_world_3d().direct_space_state if p.is_inside_tree() and p.get_world_3d() else null
	if space:
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 500.0, 1)
		var hit = space.intersect_ray(query)
		if not hit.is_empty():
			return hit.position

	var ground_y = p.global_position.y if p.is_on_floor() else 0.0
	if not p.is_on_floor() and space:
		var down_query = PhysicsRayQueryParameters3D.create(p.global_position, p.global_position + Vector3.DOWN * 200.0, 1)
		var down_hit = space.intersect_ray(down_query)
		if not down_hit.is_empty():
			ground_y = down_hit.position.y

	var ground_plane = Plane(Vector3.UP, ground_y)
	return ground_plane.intersects_ray(ray_origin, ray_dir)

func get_ranged_aim_direction(spawn_pos: Vector3) -> Vector3:
	var p = _get_player()
	var default_fwd = get_facing_direction_3d()
	if not is_local_player():
		return default_fwd

	var s = _get_status()
	if s and s.is_taunted():
		var taunter = s.get_taunt_target()
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
	var p = _get_player()
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move_dir = Vector3(input_dir.x, 0, input_dir.y).normalized()

	var mouse_dir = Vector3.ZERO
	var mouse_pos = get_mouse_ground_intersection()
	if mouse_pos != null and p:
		mouse_dir = mouse_pos - p.global_position
		mouse_dir.y = 0.0
		if mouse_dir.length_squared() > 0.001:
			mouse_dir = mouse_dir.normalized()
	if mouse_dir == Vector3.ZERO and p:
		mouse_dir = -p.global_transform.basis.z
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
	var s = _get_status()
	if s:
		s.process_status_effects(delta)
	_update_terrain_phasing_collision(delta)

	if wall_impact_cooldown_timer > 0.0:
		wall_impact_cooldown_timer = max(0.0, wall_impact_cooldown_timer - delta)

	if knockback_velocity != Vector3.ZERO:
		var p = _get_player()
		var on_floor_check = p.is_on_floor() if p else false
		var drag_rate = ground_deceleration if on_floor_check else air_drag
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, drag_rate * delta)
		if knockback_velocity.length_squared() <= 0.001 or knockback_velocity.is_zero_approx():
			knockback_velocity = Vector3.ZERO
			knockback_wall_stun = 0.0
	else:
		knockback_wall_stun = 0.0

func _process_bound_physics(_delta: float) -> void:
	var s = _get_status()
	if not s:
		return
	if not is_instance_valid(s.bound_caster_node) or (s.bound_caster_node.get("is_dead") == true):
		s.remove_status("bound")
		s.bound_caster_node = null
		s.bound_relative_offset = Vector3.ZERO
		return
	knockback_velocity = Vector3.ZERO
	var p = _get_player()
	if p:
		var target_pos = s.bound_caster_node.global_position + s.bound_relative_offset
		p.global_position = target_pos
		p.velocity = Vector3.ZERO

func _process_dummy_physics(delta: float) -> void:
	var p = _get_player()
	if not p:
		return
	if is_bound():
		_process_bound_physics(delta)
		return
	var s = _get_status()
	var ext_vel = s.external_velocity if s else Vector3.ZERO
	if ext_vel.length_squared() > 0.001 and s:
		s.external_velocity = s.external_velocity.move_toward(Vector3.ZERO, ground_deceleration * delta)
		ext_vel = s.external_velocity
	var on_floor_dummy = p.is_on_floor()
	if not on_floor_dummy:
		p.velocity.y -= gravity * delta
		p.velocity.x = move_toward(p.velocity.x, 0.0, air_drag * delta)
		p.velocity.z = move_toward(p.velocity.z, 0.0, air_drag * delta)
	else:
		if p.velocity.y < 0.0:
			p.velocity.y = 0.0
		p.velocity.x = move_toward(p.velocity.x, 0.0, ground_deceleration * delta)
		p.velocity.z = move_toward(p.velocity.z, 0.0, ground_deceleration * delta)
	p.velocity.x += ext_vel.x
	p.velocity.z += ext_vel.z
	var pre_move_vel_dummy = p.velocity
	p.move_and_slide()
	_check_wall_impact(pre_move_vel_dummy)

func _process_player_movement_physics(delta: float, is_channeling_active: bool) -> void:
	var p = _get_player()
	if not p:
		return
	if is_bound():
		_process_bound_physics(delta)
		return
	if is_phasing_walls():
		_process_phasing_movement_physics(delta)
		return
	if has_custom_movement_control():
		var pre_move_vel = p.velocity
		p.move_and_slide()
		_check_wall_impact(pre_move_vel)
		return

	var s = _get_status()
	var on_floor = p.is_on_floor()
	if not on_floor:
		var mult = s.current_gravity_mult if (s and s.is_floating) else 1.0
		var effective_gravity = gravity * mult
		p.velocity.y -= effective_gravity * delta
	else:
		if p.velocity.y < 0.0:
			p.velocity.y = 0.0
		if s and s.is_floating and s.float_timer > 0.4:
			s.is_floating = false
			s.float_timer = 0.0
			s.current_gravity_mult = 1.0

	var stunned = is_stunned()
	var rooted = is_rooted()
	var grounded = is_grounded()
	var slow_mult = get_slow_multiplier()

	# Jump
	if not stunned and not rooted and not grounded and not is_channeling_active and not is_in_move_lockout():
		if Input.is_action_just_pressed("jump") and on_floor:
			p.velocity.y = jump_velocity
			var jump_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
			var jump_h_dir := Vector3.ZERO
			if jump_input.length_squared() > 0.001:
				jump_h_dir = Vector3(jump_input.x, 0.0, jump_input.y).normalized()
			elif Vector2(p.velocity.x, p.velocity.z).length_squared() > 0.001:
				jump_h_dir = Vector3(p.velocity.x, 0.0, p.velocity.z).normalized()
			else:
				jump_h_dir = -p.global_transform.basis.z
				jump_h_dir.y = 0.0
				if jump_h_dir.length_squared() > 0.001:
					jump_h_dir = jump_h_dir.normalized()
				else:
					jump_h_dir = Vector3.FORWARD
			p.velocity.x += jump_h_dir.x * jump_horizontal_impulse
			p.velocity.z += jump_h_dir.z * jump_horizontal_impulse

	# Movement Vector
	var input_dir := Vector2.ZERO
	if not stunned and not rooted and not is_in_move_lockout():
		if s and s.is_taunted():
			var taunter = s.get_taunt_target()
			if is_instance_valid(taunter):
				var to_taunter = taunter.global_position - p.global_position
				to_taunter.y = 0.0
				if to_taunter.length_squared() > 0.01:
					var norm = to_taunter.normalized()
					input_dir = Vector2(norm.x, norm.z)
		elif s and s.is_feared():
			var fear_source = s.get_fear_source_node()
			var away := Vector3.ZERO
			if is_instance_valid(fear_source):
				away = p.global_position - fear_source.global_position
			elif s.fear_source_pos != Vector3.ZERO:
				away = p.global_position - s.fear_source_pos
			else:
				away = -get_facing_direction_3d()
			away.y = 0.0
			if away.length_squared() > 0.01:
				var norm = away.normalized()
				input_dir = Vector2(norm.x, norm.z)
		else:
			input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target_dir := Vector3(input_dir.x, 0, input_dir.y).normalized()

	var effective_max_speed = max_move_speed * slow_mult
	if s and s.speed_boost_timer > 0.0:
		effective_max_speed *= (1.0 + s.speed_boost_percent)
	effective_max_speed = get_effective_max_speed(effective_max_speed)

	var ext_vel = s.external_velocity if s else Vector3.ZERO
	if ext_vel.length_squared() > 0.001 and s:
		s.external_velocity = s.external_velocity.move_toward(Vector3.ZERO, ground_deceleration * delta)
		ext_vel = s.external_velocity

	var current_horizontal = Vector2(p.velocity.x - ext_vel.x, p.velocity.z - ext_vel.z)
	var cur_speed = current_horizontal.length()

	if is_intentional_movement and cur_speed <= effective_max_speed:
		is_intentional_movement = false

	var wish_dir = Vector2(target_dir.x, target_dir.z)

	if wish_dir.length_squared() > 0.001:
		wish_dir = wish_dir.normalized()
		var accel_rate = ground_acceleration if on_floor else air_acceleration
		accel_rate = get_effective_acceleration(accel_rate)
		current_horizontal += wish_dir * accel_rate * delta

		var cur_speed_after_accel = current_horizontal.length()
		var speed_cap = effective_max_speed

		if is_intentional_movement and cur_speed_after_accel > speed_cap:
			var drag_rate = intentional_movement_friction if on_floor else air_drag
			var excess_bleed = min(drag_rate * delta, cur_speed_after_accel - speed_cap)
			current_horizontal -= current_horizontal.normalized() * excess_bleed
			if current_horizontal.length() <= speed_cap:
				is_intentional_movement = false
		elif cur_speed_after_accel > speed_cap:
			current_horizontal = current_horizontal.normalized() * speed_cap
	else:
		if on_floor:
			var decel_rate = intentional_movement_friction if (is_intentional_movement and cur_speed > effective_max_speed) else ground_deceleration
			current_horizontal = current_horizontal.move_toward(Vector2.ZERO, decel_rate * delta)
			if current_horizontal.length() <= effective_max_speed:
				is_intentional_movement = false
		else:
			current_horizontal = current_horizontal.move_toward(Vector2.ZERO, air_drag * delta)
			if current_horizontal.length() <= effective_max_speed:
				is_intentional_movement = false

	p.velocity.x = current_horizontal.x + ext_vel.x
	p.velocity.z = current_horizontal.y + ext_vel.z

	var pre_move_vel = p.velocity
	p.move_and_slide()
	_check_wall_impact(pre_move_vel)

func _check_wall_impact(pre_move_velocity: Vector3) -> void:
	var p = _get_player()
	if not p:
		return
	if wall_impact_cooldown_timer > 0.0:
		return
	if p.get_slide_collision_count() == 0:
		return

	var kb_speed = knockback_velocity.length()
	if kb_speed < WALL_IMPACT_MIN_SPEED:
		return

	var is_violent_impact = false
	var max_impact_speed = 0.0

	for i in range(p.get_slide_collision_count()):
		var collision = p.get_slide_collision(i)
		var normal = collision.get_normal()
		if normal.y > 0.7:
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
		p.velocity = Vector3.ZERO
		if is_server_authoritative():
			if p.has_method("take_damage"):
				p.take_damage(impact_dmg, 0, 2) # ActionType.ENVIRONMENT
		else:
			request_wall_impact_damage.rpc_id(1, impact_dmg)

@rpc("any_peer", "call_remote", "reliable")
func request_wall_impact_damage(amount: float) -> void:
	if not multiplayer.is_server():
		return
	var p = _get_player()
	var sender_id = multiplayer.get_remote_sender_id()
	if p and str(sender_id) == p.name:
		if p.has_method("take_damage"):
			p.take_damage(amount, 0, 2)

func _process_phasing_movement_physics(delta: float) -> void:
	var p = _get_player()
	if not p:
		return
	var s = _get_status()
	var ext_vel = s.external_velocity if s else Vector3.ZERO
	if ext_vel.length_squared() > 0.001 and s:
		s.external_velocity = s.external_velocity.move_toward(Vector3.ZERO, ground_deceleration * delta)
		ext_vel = s.external_velocity

	p.global_position.x += (p.velocity.x + ext_vel.x) * delta
	p.global_position.z += (p.velocity.z + ext_vel.z) * delta

	var space = p.get_world_3d().direct_space_state if p.get_world_3d() else null
	var floor_y = 0.0
	var found_floor = false
	if space:
		var ray_from = Vector3(p.global_position.x, p.global_position.y + 1.5, p.global_position.z)
		var ray_to = Vector3(p.global_position.x, p.global_position.y - 15.0, p.global_position.z)
		var query = PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1)
		query.exclude = [p.get_rid()]
		var hit = space.intersect_ray(query)
		if hit:
			floor_y = hit.position.y
			found_floor = true

	if not found_floor and p.global_position.y >= -0.5:
		floor_y = 0.0
		found_floor = true

	if found_floor:
		if p.global_position.y <= floor_y + 0.1:
			p.global_position.y = floor_y
			if p.velocity.y < 0.0:
				p.velocity.y = 0.0
		else:
			p.velocity.y -= gravity * delta
			p.global_position.y += p.velocity.y * delta
			if p.global_position.y <= floor_y:
				p.global_position.y = floor_y
				p.velocity.y = 0.0
	else:
		p.velocity.y -= gravity * delta
		p.global_position.y += p.velocity.y * delta

func _update_terrain_phasing_collision(delta: float) -> void:
	var p = _get_player()
	if not p:
		return
	if not p.get_collision_layer_value(2):
		p.set_collision_layer_value(2, true)
	if not p.get_collision_mask_value(1):
		p.set_collision_mask_value(1, true)

	var can_phase = is_ethereal_active() or is_phasing_walls()
	var overlapping_terrain = _is_overlapping_terrain()
	var s = _get_status()

	if p.is_on_floor() and not overlapping_terrain and s:
		s.last_safe_ground_pos = p.global_position

	if can_phase:
		if p.get_collision_mask_value(3):
			p.set_collision_mask_value(3, false)
		if s: s.ethereal_terrain_grace_timer = 0.0
	else:
		if overlapping_terrain:
			if s:
				if s.ethereal_terrain_grace_timer <= 0.0:
					s.ethereal_terrain_grace_timer = 1.5
				else:
					s.ethereal_terrain_grace_timer = max(0.0, s.ethereal_terrain_grace_timer - delta)
					if s.ethereal_terrain_grace_timer <= 0.0:
						if s.last_safe_ground_pos != Vector3.ZERO:
							p.global_position = s.last_safe_ground_pos
							p.velocity = Vector3.ZERO
			if p.get_collision_mask_value(3):
				p.set_collision_mask_value(3, false)
		else:
			if s: s.ethereal_terrain_grace_timer = 0.0
			if not p.get_collision_mask_value(3):
				p.set_collision_mask_value(3, true)

func _is_overlapping_terrain() -> bool:
	var p = _get_player()
	if not p:
		return false
	var space = p.get_world_3d().direct_space_state if p.is_inside_tree() and p.get_world_3d() else null
	if not space:
		return false
	var col_shape = p.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not col_shape or not col_shape.shape:
		return false
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = col_shape.shape
	query.transform = col_shape.global_transform
	query.collision_mask = 4 # Layer 3 (Terrain / Walls)
	query.exclude = [p.get_rid()]
	var hits = space.intersect_shape(query, 1)
	return not hits.is_empty()
