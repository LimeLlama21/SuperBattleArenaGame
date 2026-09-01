class_name PlayerPhysics
extends CharacterBody3D

# Universal Movement Mechanics
@export var max_move_speed: float = 10.0
@export var ground_acceleration: float = 65.0
@export var ground_friction: float = 40.0
@export var intentional_movement_friction: float = 110.0
@export var air_acceleration: float = 25.0
@export var air_drag: float = 8.5
@export var jump_velocity: float = 11.2

var is_intentional_movement: bool = false

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 26.0)

# External Knockback & Wall Impact
var knockback_velocity: Vector3 = Vector3.ZERO
var knockback_wall_stun: float = 0.0
var wall_impact_cooldown_timer: float = 0.0
const WALL_IMPACT_MIN_SPEED: float = 6.0
const WALL_IMPACT_DAMAGE_FACTOR: float = 1.8

# Universal Status Effects & CC
var stun_timer: float = 0.0
var slow_timer: float = 0.0
var slow_initial_duration: float = 0.0
var slow_initial_percent: float = 0.0
var slow_percent: float = 0.0
var silence_timer: float = 0.0
var root_timer: float = 0.0
var grounded_timer: float = 0.0
var cripple_timer: float = 0.0
var cripple_intensity: float = 0.35
var ethereal_timer: float = 0.0
var speed_boost_timer: float = 0.0
var speed_boost_percent: float = 0.0
var is_cc_immune: bool = false

# Universal Levitation / Float State
var is_floating: bool = false
var float_timer: float = 0.0
var current_gravity_mult: float = 1.0
const FLOAT_TOTAL_DURATION: float = 2.2
const FLOAT_SLOWDOWN_TIME: float = 0.7
const FLOAT_HOVER_TIME: float = 1.4

# Virtual hooks for subclass overrides
func modify_incoming_damage(amount: float, _attacker_id: int, _action_type: int) -> float:
	return amount

func get_effective_max_speed(current_speed: float) -> float:
	return current_speed

# Status Query Helpers
func is_stunned() -> bool:
	return stun_timer > 0.0

func is_slowed() -> bool:
	return slow_timer > 0.0

func is_silenced() -> bool:
	return silence_timer > 0.0

func is_rooted() -> bool:
	return root_timer > 0.0

func is_grounded() -> bool:
	return grounded_timer > 0.0

func is_crippled() -> bool:
	return cripple_timer > 0.0

func is_ethereal_active() -> bool:
	return ethereal_timer > 0.0

func get_slow_multiplier() -> float:
	if slow_timer > 0.0:
		var mult = 1.0 - slow_percent
		if is_crippled():
			mult *= (1.0 - cripple_intensity)
		return clamp(mult, 0.05, 1.0)
	elif is_crippled():
		return clamp(1.0 - cripple_intensity, 0.05, 1.0)
	return 1.0

func is_multiplayer_match() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return false
	var main_node = get_tree().root.get_node_or_null("Main") if get_tree() else null
	if main_node:
		if main_node.get("is_training_mode") == true:
			return false
		if main_node.has_method("is_multiplayer_match"):
			return main_node.is_multiplayer_match()
		if "connected_players" in main_node and main_node.connected_players is Dictionary:
			return main_node.connected_players.size() > 1
	return multiplayer.get_peers().size() > 0

func get_my_player_id() -> int:
	if multiplayer and multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return 1

func is_local_player() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return name == "1" or name.to_int() == 1 or not is_multiplayer_match()
	return name.to_int() == multiplayer.get_unique_id()

func is_server_authoritative() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()

# Status Effect Application
func apply_stun(duration: float) -> void:
	if is_cc_immune:
		return
	stun_timer = max(stun_timer, duration)
	if has_method("cancel_channel"):
		call("cancel_channel")
	if is_multiplayer_match() and multiplayer.is_server():
		sync_status_effect.rpc("stun", duration, 0.0)

func apply_slow(duration: float, percent: float) -> void:
	if is_cc_immune:
		return
	slow_timer = max(slow_timer, duration)
	slow_initial_duration = max(slow_initial_duration, duration)
	slow_initial_percent = max(slow_initial_percent, percent)
	slow_percent = max(slow_percent, percent)
	if is_multiplayer_match() and multiplayer.is_server():
		sync_status_effect.rpc("slow", duration, slow_percent)

func apply_silence(duration: float) -> void:
	if is_cc_immune:
		return
	silence_timer = max(silence_timer, duration)
	if has_method("cancel_channel"):
		call("cancel_channel")
	if is_multiplayer_match() and multiplayer.is_server():
		sync_status_effect.rpc("silence", duration, 0.0)

func apply_root(duration: float) -> void:
	if is_cc_immune:
		return
	root_timer = max(root_timer, duration)
	if is_multiplayer_match() and multiplayer.is_server():
		sync_status_effect.rpc("root", duration, 0.0)

func apply_grounded(duration: float) -> void:
	if is_cc_immune:
		return
	grounded_timer = max(grounded_timer, duration)
	if is_multiplayer_match() and multiplayer.is_server():
		sync_status_effect.rpc("grounded", duration, 0.0)

func apply_cripple(duration: float, intensity: float = 0.35) -> void:
	if is_cc_immune:
		return
	cripple_timer = max(cripple_timer, duration)
	cripple_intensity = intensity
	if is_multiplayer_match() and multiplayer.is_server():
		sync_status_effect.rpc("cripple", duration, intensity)

func apply_ethereal(duration: float) -> void:
	ethereal_timer = max(ethereal_timer, duration)
	if is_multiplayer_match() and multiplayer.is_server():
		sync_status_effect.rpc("ethereal", duration, 0.0)

func apply_speed_boost(duration: float, percent: float) -> void:
	speed_boost_timer = max(speed_boost_timer, duration)
	speed_boost_percent = max(speed_boost_percent, percent)
	if is_multiplayer_match() and multiplayer.is_server():
		sync_status_effect.rpc("speed_boost", duration, percent)

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

func cleanse_cc() -> void:
	stun_timer = 0.0
	slow_timer = 0.0
	slow_percent = 0.0
	slow_initial_duration = 0.0
	slow_initial_percent = 0.0
	silence_timer = 0.0
	root_timer = 0.0
	grounded_timer = 0.0
	cripple_timer = 0.0
	knockback_velocity = Vector3.ZERO
	knockback_wall_stun = 0.0
	is_intentional_movement = false

@rpc("any_peer", "call_local", "reliable")
func sync_status_effect(effect_name: String, duration: float, param: float) -> void:
	match effect_name:
		"stun":
			stun_timer = max(stun_timer, duration)
			if has_method("cancel_channel"):
				call("cancel_channel")
		"slow":
			slow_timer = max(slow_timer, duration)
			slow_initial_duration = max(slow_initial_duration, duration)
			slow_initial_percent = max(slow_initial_percent, param)
			slow_percent = max(slow_percent, param)
		"silence":
			silence_timer = max(silence_timer, duration)
			if has_method("cancel_channel"):
				call("cancel_channel")
		"root":
			root_timer = max(root_timer, duration)
		"grounded":
			grounded_timer = max(grounded_timer, duration)
		"cripple":
			cripple_timer = max(cripple_timer, duration)
			cripple_intensity = param
		"ethereal":
			ethereal_timer = max(ethereal_timer, duration)
		"speed_boost":
			speed_boost_timer = max(speed_boost_timer, duration)
			speed_boost_percent = max(speed_boost_percent, param)

# Levitation / Float State
func start_float_state() -> void:
	is_floating = true
	float_timer = 0.0
	current_gravity_mult = 1.0
	if is_multiplayer_match() and multiplayer.is_server():
		sync_float_state.rpc(true)

func end_float_state() -> void:
	is_floating = false
	float_timer = 0.0
	current_gravity_mult = 1.0
	if is_multiplayer_match() and multiplayer.is_server():
		sync_float_state.rpc(false)

@rpc("any_peer", "call_local", "reliable")
func sync_float_state(floating: bool) -> void:
	is_floating = floating
	if not floating:
		float_timer = 0.0
		current_gravity_mult = 1.0

# Process Timers & Movement Physics
func _process_physics_timers(delta: float) -> void:
	if stun_timer > 0.0:
		stun_timer = max(0.0, stun_timer - delta)

	if slow_timer > 0.0:
		slow_timer = max(0.0, slow_timer - delta)
		if slow_initial_duration > 0.0:
			var progress = 1.0 - (slow_timer / slow_initial_duration)
			slow_percent = lerp(slow_initial_percent, 0.0, progress)
		if slow_timer <= 0.0:
			slow_percent = 0.0
			slow_initial_duration = 0.0
			slow_initial_percent = 0.0

	if speed_boost_timer > 0.0:
		speed_boost_timer = max(0.0, speed_boost_timer - delta)
		if speed_boost_timer <= 0.0:
			speed_boost_percent = 0.0

	if silence_timer > 0.0:
		silence_timer = max(0.0, silence_timer - delta)

	if root_timer > 0.0:
		root_timer = max(0.0, root_timer - delta)

	if grounded_timer > 0.0:
		grounded_timer = max(0.0, grounded_timer - delta)

	if cripple_timer > 0.0:
		cripple_timer = max(0.0, cripple_timer - delta)

	if ethereal_timer > 0.0:
		ethereal_timer = max(0.0, ethereal_timer - delta)

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

	if is_floating:
		float_timer += delta
		if float_timer < FLOAT_SLOWDOWN_TIME:
			var t = float_timer / FLOAT_SLOWDOWN_TIME
			current_gravity_mult = lerp(1.0, 0.05, t)
		elif float_timer < FLOAT_HOVER_TIME:
			current_gravity_mult = 0.05
		elif float_timer < FLOAT_TOTAL_DURATION:
			var t = (float_timer - FLOAT_HOVER_TIME) / (FLOAT_TOTAL_DURATION - FLOAT_HOVER_TIME)
			current_gravity_mult = lerp(0.05, 1.0, t)
		else:
			end_float_state()

func _process_dummy_physics(delta: float) -> void:
	var on_floor_dummy = is_on_floor()
	if not on_floor_dummy:
		velocity.y -= gravity * delta
		velocity.x = move_toward(velocity.x, 0.0, air_drag * delta)
		velocity.z = move_toward(velocity.z, 0.0, air_drag * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, ground_friction * delta)
	var pre_move_vel_dummy = velocity
	move_and_slide()
	_check_wall_impact(pre_move_vel_dummy)

func has_custom_movement_control() -> bool:
	return false

func _process_player_movement_physics(delta: float, is_channeling_active: bool) -> void:
	if has_custom_movement_control():
		var pre_move_vel = velocity
		move_and_slide()
		_check_wall_impact(pre_move_vel)
		return

	var on_floor = is_on_floor()
	if not on_floor:
		var effective_gravity = gravity * (current_gravity_mult if is_floating else 1.0)
		velocity.y -= effective_gravity * delta
	else:
		if is_floating and float_timer > 0.4:
			end_float_state()

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
		# Current speed projected onto wish direction
		var current_speed_along_wish = current_horizontal.dot(wish_dir)
		# Accelerate along wish direction up to effective_max_speed
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
		if has_method("take_damage"):
			call("take_damage", impact_dmg, 0, 2) # ActionType.ENVIRONMENT
