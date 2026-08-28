class_name BasePlayer
extends CharacterBody3D

@export var character_name: String = "Hunter"
@export var max_health: float = 100.0
@export var current_health: float = 100.0:
	set(value):
		current_health = clamp(value, 0.0, max_health)
		update_health_bar()

# Shield / Temp HP parameters
@export var max_shield: float = 100.0
var current_shield: float = 0.0:
	set(value):
		current_shield = clamp(value, 0.0, max_shield)
		update_health_bar()
var shield_timer: float = 0.0

# Movement Parameters
@export var max_move_speed: float = 10.0
@export var ground_acceleration: float = 65.0
@export var ground_friction: float = 40.0
@export var air_acceleration: float = 25.0
@export var air_drag: float = 3.5
@export var jump_velocity: float = 9.5

# Combat & Character Attack Timing
@export var is_melee_character: bool = false
@export var dash_impulse: float = 26.0
@export var max_dash_charges: int = 1
@export var dash_cooldown: float = 4.0 # Interval / lockout between dashes
@export var dash_recharge_time: float = 4.0 # Time to recover one dash charge
@export var attack_cooldown: float = 0.3 # Fire rate / attack interval
@export var windup_time: float = 0.0 # Attack windup delay
@export var melee_windup_time: float = 0.28 # Default melee windup

# Ability One (RMB) & Ability Two (Q) Parameters
@export var ability_one_cooldown: float = 6.0
@export var ability_two_cooldown: float = 8.0
@export var can_cast_while_stunned: bool = false
@export var is_cc_immune: bool = false

# Projectile Stats (Size, Damage, Speed)
@export var projectile_size: float = 1.0
@export var projectile_damage: float = 50.0
@export var projectile_speed: float = 70.0

# Melee Attack Stats (Size, Damage)
@export var melee_size: float = 4.2 # Radius / range of the melee hitbox
@export var melee_damage: float = 55.0
@export var melee_angle_deg: float = 120.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 24.0)

# Dash state
var current_dash_charges: int = 1
var dash_lockout_timer: float = 0.0
var dash_recharge_timer: float = 0.0

# Attack & Ability state
var attack_timer: float = 0.0
var ability_one_timer: float = 0.0
var ability_two_timer: float = 0.0
var is_casting_melee: bool = false
var is_casting_ability_one: bool = false
var is_casting_ability_two: bool = false
var is_dead: bool = false

# Status effects state
var stun_timer: float = 0.0
var slow_timer: float = 0.0
var slow_percent: float = 0.0

# Channeling state (Self-inflicted CC condition)
var is_channeling: bool = false
var channel_timer: float = 0.0
var channel_complete_callback: Callable = Callable()

# Spectator variables
var spectate_target: Node3D = null
var spectate_index: int = 0

const CAMERA_OFFSET: Vector3 = Vector3(0, 17, 9.5)
const VOID_DEATH_Y: float = -8.0

@onready var camera: Camera3D = $Camera3D
@onready var synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var health_bar: ProgressBar = $HealthBarViewport/ProgressBar
@onready var sprite_3d: Sprite3D = $HealthBarSprite
@onready var melee_visual: Node3D = get_node_or_null("MeleeVisual")
@onready var ability_one_visual: Node3D = get_node_or_null("AbilityOneVisual")
@onready var ability_two_visual: Node3D = get_node_or_null("AbilityTwoVisual")
@onready var hud: CanvasLayer = $PlayerHUD
@onready var status_cc_label: Label = get_node_or_null("PlayerHUD/VBox/StatusCCLabel")
@onready var attack_cd_label: Label = get_node_or_null("PlayerHUD/VBox/AttackCD")
@onready var ability_one_cd_label: Label = get_node_or_null("PlayerHUD/VBox/AbilityOneCD")
@onready var ability_two_cd_label: Label = get_node_or_null("PlayerHUD/VBox/AbilityTwoCD")
@onready var dash_cd_label: Label = get_node_or_null("PlayerHUD/VBox/DashCD")
@onready var spectator_panel: PanelContainer = $PlayerHUD/SpectatorPanel
@onready var spectator_label: Label = $PlayerHUD/SpectatorPanel/VBox/SpectatorLabel

func _enter_tree() -> void:
	var peer_id = name.to_int()
	if peer_id > 0:
		set_multiplayer_authority(peer_id)
		$MultiplayerSynchronizer.set_multiplayer_authority(peer_id)

func _ready() -> void:
	var peer_id = name.to_int()
	if peer_id > 0:
		set_multiplayer_authority(peer_id)
		$MultiplayerSynchronizer.set_multiplayer_authority(peer_id)

	var is_local = (name.to_int() == multiplayer.get_unique_id())
	
	if is_local:
		camera.top_level = true
		camera.make_current()
		camera.global_position = global_position + CAMERA_OFFSET
		camera.look_at(global_position, Vector3.UP)
		hud.show()
	else:
		# Completely remove remote player's camera so it can never take over local viewport
		camera.current = false
		camera.clear_current()
		camera.queue_free()
		hud.hide()
	
	current_dash_charges = max_dash_charges
	dash_lockout_timer = 0.0
	dash_recharge_timer = 0.0
	sprite_3d.texture = $HealthBarViewport.get_texture()
	update_health_bar()
	if melee_visual:
		melee_visual.visible = false
		if melee_size > 0.0 and character_name == "Crush":
			melee_visual.scale = Vector3(melee_size / 4.2, 1.0, melee_size / 4.2)
	if ability_one_visual:
		ability_one_visual.visible = false
	if ability_two_visual:
		ability_two_visual.visible = false
	if spectator_panel:
		spectator_panel.hide()

func is_stunned() -> bool:
	return stun_timer > 0.0 and not is_cc_immune

func is_slowed() -> bool:
	return slow_timer > 0.0 and not is_cc_immune

func get_slow_multiplier() -> float:
	if is_slowed():
		return clamp(1.0 - slow_percent, 0.1, 1.0)
	return 1.0

func start_channel(duration: float, on_complete: Callable) -> void:
	is_channeling = true
	channel_timer = duration
	channel_complete_callback = on_complete

func cancel_channel() -> void:
	is_channeling = false
	channel_timer = 0.0
	channel_complete_callback = Callable()

func apply_shield(amount: float, duration: float = 5.0) -> void:
	current_shield = amount
	shield_timer = duration
	if multiplayer.is_server():
		sync_shield.rpc(current_shield)

@rpc("any_peer", "call_local", "reliable")
func sync_shield(new_shield: float) -> void:
	current_shield = new_shield

func _physics_process(delta: float) -> void:
	# Deadzone / Void Check
	if multiplayer.is_server() and not is_dead and global_position.y < VOID_DEATH_Y:
		die()

	# Status effect timers decrement on all peers
	if stun_timer > 0.0:
		stun_timer -= delta
		if stun_timer < 0.0:
			stun_timer = 0.0

	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_timer = 0.0
			slow_percent = 0.0

	if shield_timer > 0.0:
		shield_timer -= delta
		if shield_timer <= 0.0:
			current_shield = 0.0

	# Channeling process
	if is_channeling:
		channel_timer -= delta
		if channel_timer <= 0.0:
			is_channeling = false
			if channel_complete_callback.is_valid():
				var cb = channel_complete_callback
				channel_complete_callback = Callable()
				cb.call()

	if name.to_int() != multiplayer.get_unique_id():
		return

	# If dead, process Spectator camera & inputs
	if is_dead:
		_process_spectator(delta)
		return

	if not DisplayServer.window_is_focused():
		return

	if camera and is_instance_valid(camera) and camera.is_inside_tree():
		camera.global_position = global_position + CAMERA_OFFSET

	if dash_lockout_timer > 0.0:
		dash_lockout_timer -= delta

	if current_dash_charges < max_dash_charges:
		dash_recharge_timer += delta
		if dash_recharge_timer >= dash_recharge_time:
			current_dash_charges += 1
			dash_recharge_timer = 0.0 if current_dash_charges == max_dash_charges else (dash_recharge_timer - dash_recharge_time)
	else:
		dash_recharge_timer = 0.0

	if attack_timer > 0.0:
		attack_timer -= delta
		
	if ability_one_timer > 0.0:
		ability_one_timer -= delta

	if ability_two_timer > 0.0:
		ability_two_timer -= delta

	_update_hud()

	var on_floor = is_on_floor()
	if not on_floor:
		velocity.y -= gravity * delta

	var stunned = is_stunned()
	var slow_mult = get_slow_multiplier()

	# Jump
	if not stunned and not is_channeling and Input.is_action_just_pressed("jump") and on_floor:
		velocity.y = jump_velocity

	# Target direction from input (blocked if stunned or channeling)
	var target_dir := Vector3.ZERO
	if not stunned and not is_channeling:
		var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		target_dir = Vector3(input_dir.x, 0, input_dir.y).normalized()

	# Dash (Shift)
	if not stunned and not is_channeling and Input.is_action_just_pressed("dash") and current_dash_charges > 0 and dash_lockout_timer <= 0.0:
		current_dash_charges -= 1
		dash_lockout_timer = dash_cooldown
		var dash_dir = target_dir if target_dir != Vector3.ZERO else -global_transform.basis.z.normalized()
		var effective_impulse = dash_impulse * slow_mult
		velocity.x = dash_dir.x * effective_impulse
		velocity.z = dash_dir.z * effective_impulse

	# Momentum & Movement Physics (Existing velocity continues smoothly under physics!)
	var current_horizontal = Vector2(velocity.x, velocity.z)
	var speed = current_horizontal.length()
	var effective_max_speed = max_move_speed * slow_mult
	var effective_accel = ground_acceleration * slow_mult

	if on_floor:
		if target_dir != Vector3.ZERO:
			if speed > effective_max_speed:
				current_horizontal = current_horizontal.move_toward(Vector2(target_dir.x, target_dir.z) * effective_max_speed, ground_friction * delta)
			else:
				current_horizontal = current_horizontal.move_toward(Vector2(target_dir.x, target_dir.z) * effective_max_speed, effective_accel * delta)
		else:
			current_horizontal = current_horizontal.move_toward(Vector2.ZERO, ground_friction * delta)
	else:
		if target_dir != Vector3.ZERO:
			if speed > effective_max_speed:
				current_horizontal = current_horizontal.move_toward(Vector2(target_dir.x, target_dir.z) * speed, air_acceleration * 0.5 * delta)
				current_horizontal = current_horizontal.move_toward(Vector2.ZERO, air_drag * delta)
			else:
				current_horizontal = current_horizontal.move_toward(Vector2(target_dir.x, target_dir.z) * effective_max_speed, air_acceleration * delta)
		else:
			current_horizontal = current_horizontal.move_toward(Vector2.ZERO, air_drag * delta)

	velocity.x = current_horizontal.x
	velocity.z = current_horizontal.y

	aim_at_mouse()

	# Primary Attack (LMB)
	if not stunned and not is_channeling and Input.is_action_pressed("shoot") and attack_timer <= 0.0 and not is_casting_melee and not is_casting_ability_one and not is_casting_ability_two:
		if is_melee_character:
			_perform_crush_melee_windup()
		else:
			_perform_poke_ranged_attack()

	# Ability One (RMB)
	if (not stunned or can_cast_while_stunned) and not is_channeling and Input.is_action_just_pressed("ability_one") and ability_one_timer <= 0.0 and not is_casting_melee and not is_casting_ability_one and not is_casting_ability_two:
		_perform_ability_one()

	# Ability Two (Q)
	if (not stunned or can_cast_while_stunned) and not is_channeling and Input.is_action_just_pressed("ability_two") and ability_two_timer <= 0.0 and not is_casting_melee and not is_casting_ability_one and not is_casting_ability_two:
		_perform_ability_two()

	move_and_slide()

func _update_hud() -> void:
	# Status Effects CC Display above hotbar
	if status_cc_label:
		if is_channeling:
			status_cc_label.text = "⏳ CHANNELING (%.1fs) ⏳" % channel_timer
			status_cc_label.modulate = Color(0.2, 0.95, 0.95)
		elif is_stunned() and is_slowed():
			status_cc_label.text = "★ STUNNED (%.1fs) | SLOWED -%d%% (%.1fs) ★" % [stun_timer, int(slow_percent * 100), slow_timer]
			status_cc_label.modulate = Color(1.0, 0.3, 0.3)
		elif is_stunned():
			status_cc_label.text = "★ STUNNED (%.1fs) ★" % stun_timer
			status_cc_label.modulate = Color(1.0, 0.35, 0.35)
		elif is_slowed():
			status_cc_label.text = "▼ SLOWED -%d%% (%.1fs) ▼" % [int(slow_percent * 100), slow_timer]
			status_cc_label.modulate = Color(0.35, 0.85, 1.0)
		else:
			status_cc_label.text = ""

	# Attack [LMB]
	if attack_cd_label:
		if is_stunned():
			attack_cd_label.text = "Attack [LMB]: DISABLED (STUNNED)"
			attack_cd_label.modulate = Color(0.7, 0.4, 0.4)
		elif is_channeling:
			attack_cd_label.text = "Attack [LMB]: CHANNELING..."
			attack_cd_label.modulate = Color(0.7, 0.7, 0.3)
		elif attack_timer > 0.0:
			attack_cd_label.text = "Attack [LMB]: %.1fs" % attack_timer
			attack_cd_label.modulate = Color(1, 0.5, 0.5)
		elif is_casting_melee:
			attack_cd_label.text = "Attack [LMB]: STRIKING..."
			attack_cd_label.modulate = Color(1, 0.8, 0.2)
		else:
			attack_cd_label.text = "Attack [LMB]: READY"
			attack_cd_label.modulate = Color(0.4, 1, 0.4)

	# Ability One [RMB]
	if ability_one_cd_label:
		if is_stunned() and not can_cast_while_stunned:
			ability_one_cd_label.text = "One [RMB]: DISABLED (STUNNED)"
			ability_one_cd_label.modulate = Color(0.7, 0.4, 0.4)
		elif is_channeling:
			ability_one_cd_label.text = "One [RMB]: CHANNELING..."
			ability_one_cd_label.modulate = Color(0.7, 0.7, 0.3)
		elif ability_one_timer > 0.0:
			ability_one_cd_label.text = "One [RMB]: %.1fs" % ability_one_timer
			ability_one_cd_label.modulate = Color(1, 0.5, 0.5)
		elif is_casting_ability_one:
			ability_one_cd_label.text = "One [RMB]: CASTING..."
			ability_one_cd_label.modulate = Color(1, 0.8, 0.2)
		else:
			ability_one_cd_label.text = "One [RMB]: READY"
			ability_one_cd_label.modulate = Color(0.4, 1, 0.4)

	# Ability Two [Q]
	if ability_two_cd_label:
		if is_stunned() and not can_cast_while_stunned:
			ability_two_cd_label.text = "Two [Q]: DISABLED (STUNNED)"
			ability_two_cd_label.modulate = Color(0.7, 0.4, 0.4)
		elif is_channeling:
			ability_two_cd_label.text = "Two [Q]: CHANNELING..."
			ability_two_cd_label.modulate = Color(0.7, 0.7, 0.3)
		elif ability_two_timer > 0.0:
			ability_two_cd_label.text = "Two [Q]: %.1fs" % ability_two_timer
			ability_two_cd_label.modulate = Color(1, 0.5, 0.5)
		elif is_casting_ability_two:
			ability_two_cd_label.text = "Two [Q]: CASTING..."
			ability_two_cd_label.modulate = Color(1, 0.8, 0.2)
		else:
			ability_two_cd_label.text = "Two [Q]: READY"
			ability_two_cd_label.modulate = Color(0.4, 1, 0.4)

	# Dash [Shift]
	if dash_cd_label:
		if is_stunned():
			dash_cd_label.text = "Dash [Shift]: DISABLED (STUNNED)"
			dash_cd_label.modulate = Color(0.7, 0.4, 0.4)
		elif is_channeling:
			dash_cd_label.text = "Dash [Shift]: CHANNELING..."
			dash_cd_label.modulate = Color(0.7, 0.7, 0.3)
		elif max_dash_charges > 1:
			var remaining_recharge = max(0.0, dash_recharge_time - dash_recharge_timer)
			if current_dash_charges > 0:
				if dash_lockout_timer > 0.0:
					dash_cd_label.text = "Dash [Shift]: %d/%d (%.1fs)" % [current_dash_charges, max_dash_charges, dash_lockout_timer]
					dash_cd_label.modulate = Color(1, 0.85, 0.3)
				elif current_dash_charges < max_dash_charges:
					dash_cd_label.text = "Dash [Shift]: %d/%d (+%.1fs)" % [current_dash_charges, max_dash_charges, remaining_recharge]
					dash_cd_label.modulate = Color(0.4, 1, 0.4)
				else:
					dash_cd_label.text = "Dash [Shift]: %d/%d READY" % [current_dash_charges, max_dash_charges]
					dash_cd_label.modulate = Color(0.4, 1, 0.4)
			else:
				dash_cd_label.text = "Dash [Shift]: 0/%d (%.1fs)" % [max_dash_charges, remaining_recharge]
				dash_cd_label.modulate = Color(1, 0.5, 0.5)
		else:
			var remaining = max(0.0, dash_recharge_time - dash_recharge_timer) if current_dash_charges == 0 else dash_lockout_timer
			if current_dash_charges > 0 and dash_lockout_timer <= 0.0:
				dash_cd_label.text = "Dash [Shift]: READY"
				dash_cd_label.modulate = Color(0.4, 1, 0.4)
			else:
				dash_cd_label.text = "Dash [Shift]: %.1fs" % remaining
				dash_cd_label.modulate = Color(1, 0.5, 0.5)

func _perform_poke_ranged_attack() -> void:
	var actual_windup = windup_time
	if actual_windup > 0.0:
		await get_tree().create_timer(actual_windup).timeout

	attack_timer = attack_cooldown
	var facing_dir = -global_transform.basis.z.normalized()
	var spawn_pos = global_position + Vector3(0, 0.8, 0) + facing_dir * 1.1
	
	if multiplayer.is_server():
		get_tree().root.get_node("Main").spawn_projectile(spawn_pos, facing_dir, 1, projectile_damage, projectile_speed, projectile_size)
	else:
		request_fire.rpc_id(1, spawn_pos, facing_dir, projectile_damage, projectile_speed, projectile_size)

func _perform_crush_melee_windup() -> void:
	is_casting_melee = true
	var actual_windup = windup_time if windup_time > 0.0 else melee_windup_time
	attack_timer = attack_cooldown + actual_windup
	
	show_melee_effect.rpc(true)
	await get_tree().create_timer(actual_windup).timeout
	is_casting_melee = false
	show_melee_effect.rpc(false)
	
	var facing_dir = -global_transform.basis.z.normalized()
	if multiplayer.is_server():
		execute_melee_hit_on_server(global_position, facing_dir, 1, melee_damage, melee_size, melee_angle_deg)
	else:
		request_melee_strike.rpc_id(1, global_position, facing_dir, melee_damage, melee_size, melee_angle_deg)

# --- Ability One (RMB) ---
func _perform_ability_one() -> void:
	if character_name == "Crush":
		_perform_crush_ability_one()
	elif character_name == "Dive":
		_perform_dive_ability_one()
	else:
		_perform_poke_ability_one()

func _perform_poke_ability_one() -> void:
	ability_one_timer = ability_one_cooldown
	var facing_dir = -global_transform.basis.z.normalized()
	var spawn_pos = global_position + Vector3(0, 0.8, 0) + facing_dir * 1.1
	
	if multiplayer.is_server():
		get_tree().root.get_node("Main").spawn_projectile(spawn_pos, facing_dir, 1, 20.0, 85.0, 0.35, 0.2, "knockback_stun", 1.0, 36.0)
	else:
		request_fire_ability_one.rpc_id(1, spawn_pos, facing_dir, 20.0, 85.0, 0.35, 0.2, "knockback_stun", 1.0, 36.0)

func _perform_dive_ability_one() -> void:
	ability_one_timer = ability_one_cooldown
	var facing_dir = -global_transform.basis.z.normalized()
	var spawn_pos = global_position + Vector3(0, 0.8, 0) + facing_dir * 1.1
	
	if multiplayer.is_server():
		get_tree().root.get_node("Main").spawn_projectile(spawn_pos, facing_dir, 1, 15.0, 46.0, 0.6, 0.45, "slow", 2.0, 0.5)
	else:
		request_fire_ability_one.rpc_id(1, spawn_pos, facing_dir, 15.0, 46.0, 0.6, 0.45, "slow", 2.0, 0.5)

func _perform_crush_ability_one() -> void:
	is_casting_ability_one = true
	var windup_delay = 0.16
	ability_one_timer = ability_one_cooldown + windup_delay
	
	show_ability_one_visual.rpc(true)
	await get_tree().create_timer(windup_delay).timeout
	is_casting_ability_one = false
	show_ability_one_visual.rpc(false)
	
	var facing_dir = -global_transform.basis.z.normalized()
	if multiplayer.is_server():
		execute_crush_fan_stun_on_server(global_position, facing_dir, 1)
	else:
		request_crush_fan_stun.rpc_id(1, global_position, facing_dir)

# --- Ability Two (Q) ---
func _perform_ability_two() -> void:
	if character_name == "Crush":
		_perform_crush_ability_two()
	elif character_name == "Dive":
		_perform_dive_ability_two()
	else:
		_perform_poke_ability_two()

func _perform_crush_ability_two() -> void:
	ability_two_timer = ability_two_cooldown
	is_casting_ability_two = true
	
	# Grant Crush a temporary shield
	apply_shield(40.0, 5.0)
	
	show_ability_two_visual.rpc(true)
	get_tree().create_timer(0.3).timeout.connect(func():
		is_casting_ability_two = false
		show_ability_two_visual.rpc(false)
	)
	
	# Medium size AOE shockwave (radius 6.5m, 20 dmg, 30% slow for 2.5s)
	if multiplayer.is_server():
		execute_crush_aoe_two_on_server(global_position, 1)
	else:
		request_crush_aoe_two.rpc_id(1, global_position)

func _perform_dive_ability_two() -> void:
	# Dive pauses to channel for 0.35s (self-inflicted CC, canceled if stunned)
	start_channel(0.35, Callable(self, "_on_dive_q_channel_finished"))

func _on_dive_q_channel_finished() -> void:
	ability_two_timer = ability_two_cooldown
	var facing_dir = -global_transform.basis.z.normalized()
	var spawn_pos = global_position + Vector3(0, 0.4, 0) + facing_dir * 1.2
	
	# Dive sends forward a piercing tremor that slows and spawns temporary terrain at the end
	if multiplayer.is_server():
		get_tree().root.get_node("Main").spawn_projectile(spawn_pos, facing_dir, 1, 15.0, 22.0, 1.5, 0.7, "slow", 2.0, 0.4, true, true)
	else:
		request_fire_ability_two.rpc_id(1, spawn_pos, facing_dir, 15.0, 22.0, 1.5, 0.7, "slow", 2.0, 0.4, true, true)

func _perform_poke_ability_two() -> void:
	ability_two_timer = ability_two_cooldown
	var viewport = get_viewport()
	if not viewport or not camera:
		return

	var mouse_pos = viewport.get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	var ground_plane = Plane(Vector3.UP, global_position.y)
	var hit_pos = ground_plane.intersects_ray(ray_origin, ray_dir)

	var spawn_pos = global_position + Vector3(0, 0.8, 0)
	var shoot_dir = -global_transform.basis.z.normalized()
	var target_dist: float = 45.0

	if hit_pos != null:
		var diff = hit_pos - spawn_pos
		target_dist = clamp(diff.length(), 6.0, 65.0)
		diff.y = 0.0
		if diff.length_squared() > 0.1:
			shoot_dir = diff.normalized()

	if multiplayer.is_server():
		get_tree().root.get_node("Main").spawn_vision_flare(spawn_pos, shoot_dir, target_dist, name.to_int())
	else:
		request_fire_vision_flare.rpc_id(1, spawn_pos, shoot_dir, target_dist)

@rpc("any_peer", "call_remote", "reliable")
func request_fire_vision_flare(spawn_pos: Vector3, shoot_dir: Vector3, target_dist: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	get_tree().root.get_node("Main").spawn_vision_flare(spawn_pos, shoot_dir, target_dist, sender_id)

func set_opponent_visible(is_vis: bool) -> void:
	if is_dead:
		return
	$MeshInstance3D.visible = is_vis
	$FacingIndicator.visible = is_vis
	$HealthBarSprite.visible = is_vis
	if melee_visual and is_casting_melee:
		melee_visual.visible = is_vis
	if ability_one_visual and is_casting_ability_one:
		ability_one_visual.visible = is_vis
	if ability_two_visual and is_casting_ability_two:
		ability_two_visual.visible = is_vis

@rpc("any_peer", "call_local", "reliable")
func show_ability_one_visual(active: bool) -> void:
	if ability_one_visual:
		ability_one_visual.visible = active

@rpc("any_peer", "call_local", "reliable")
func show_ability_two_visual(active: bool) -> void:
	if ability_two_visual:
		ability_two_visual.visible = active

@rpc("any_peer", "call_remote", "reliable")
func request_crush_fan_stun(origin_pos: Vector3, forward_dir: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	execute_crush_fan_stun_on_server(origin_pos, forward_dir, sender_id)

func execute_crush_fan_stun_on_server(origin_pos: Vector3, forward_dir: Vector3, attacker_id: int) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	
	var fwd_2d = Vector2(forward_dir.x, forward_dir.z).normalized()
	
	for player in players_container.get_children():
		if player.name != str(attacker_id) and player.has_method("take_damage") and not player.get("is_dead"):
			var diff = player.global_position - origin_pos
			var diff_2d = Vector2(diff.x, diff.z)
			var dist = diff_2d.length()
			
			if abs(diff.y) <= 3.0 and dist <= 5.2:
				var to_target_2d = diff_2d.normalized()
				var angle = rad_to_deg(fwd_2d.angle_to(to_target_2d))
				if abs(angle) <= (100.0 * 0.5):
					player.take_damage(20.0)
					if player.has_method("apply_stun"):
						player.apply_stun(1.3)

@rpc("any_peer", "call_remote", "reliable")
func request_crush_aoe_two(origin_pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	execute_crush_aoe_two_on_server(origin_pos, sender_id)

func execute_crush_aoe_two_on_server(origin_pos: Vector3, attacker_id: int) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	
	for player in players_container.get_children():
		if player.name != str(attacker_id) and player.has_method("take_damage") and not player.get("is_dead"):
			var diff = player.global_position - origin_pos
			var dist = diff.length()
			if dist <= 6.5:
				player.take_damage(20.0)
				if player.has_method("apply_slow"):
					player.apply_slow(2.5, 0.3)

@rpc("any_peer", "call_remote", "reliable")
func request_fire_ability_one(spawn_pos: Vector3, shoot_dir: Vector3, dmg: float, spd: float, p_size: float, life: float, eff_type: String, eff_dur: float, eff_int: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	get_tree().root.get_node("Main").spawn_projectile(spawn_pos, shoot_dir, sender_id, dmg, spd, p_size, life, eff_type, eff_dur, eff_int)

@rpc("any_peer", "call_remote", "reliable")
func request_fire_ability_two(spawn_pos: Vector3, shoot_dir: Vector3, dmg: float, spd: float, p_size: float, life: float, eff_type: String, eff_dur: float, eff_int: float, pierce: bool, spawn_terr: bool) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	get_tree().root.get_node("Main").spawn_projectile(spawn_pos, shoot_dir, sender_id, dmg, spd, p_size, life, eff_type, eff_dur, eff_int, pierce, spawn_terr)

@rpc("any_peer", "call_local", "reliable")
func show_melee_effect(active: bool) -> void:
	if melee_visual:
		melee_visual.visible = active

@rpc("any_peer", "call_remote", "reliable")
func request_melee_strike(origin_pos: Vector3, forward_dir: Vector3, dmg: float, size: float, angle_deg: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	execute_melee_hit_on_server(origin_pos, forward_dir, sender_id, dmg, size, angle_deg)

func execute_melee_hit_on_server(origin_pos: Vector3, forward_dir: Vector3, attacker_id: int, dmg: float, size: float, angle_deg: float) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	
	var fwd_2d = Vector2(forward_dir.x, forward_dir.z).normalized()
	
	for player in players_container.get_children():
		if player.name != str(attacker_id) and player.has_method("take_damage") and not player.get("is_dead"):
			var diff = player.global_position - origin_pos
			var diff_2d = Vector2(diff.x, diff.z)
			var dist = diff_2d.length()
			
			if abs(diff.y) <= 3.0 and dist <= size:
				var to_target_2d = diff_2d.normalized()
				var angle = rad_to_deg(fwd_2d.angle_to(to_target_2d))
				if abs(angle) <= (angle_deg * 0.5):
					player.take_damage(dmg)

func aim_at_mouse() -> void:
	var viewport = get_viewport()
	if not viewport or not camera:
		return

	var mouse_pos = viewport.get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)

	var ground_plane = Plane(Vector3.UP, global_position.y)
	var hit_pos = ground_plane.intersects_ray(ray_origin, ray_dir)

	if hit_pos != null:
		var target := Vector3(hit_pos.x, global_position.y, hit_pos.z)
		if global_position.distance_squared_to(target) > 0.3:
			look_at(target, Vector3.UP)
			rotation.x = 0.0
			rotation.z = 0.0

@rpc("any_peer", "call_remote", "reliable")
func request_fire(spawn_pos: Vector3, shoot_dir: Vector3, dmg: float, spd: float, p_size: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	get_tree().root.get_node("Main").spawn_projectile(spawn_pos, shoot_dir, sender_id, dmg, spd, p_size)

func apply_stun(duration: float) -> void:
	if is_dead or is_cc_immune:
		return
	if is_channeling:
		cancel_channel()
	stun_timer = max(stun_timer, duration)
	if multiplayer.is_server():
		sync_status_effects.rpc(stun_timer, slow_timer, slow_percent)

func apply_slow(duration: float, percent: float) -> void:
	if is_dead or is_cc_immune:
		return
	slow_timer = max(slow_timer, duration)
	slow_percent = max(slow_percent, percent)
	if multiplayer.is_server():
		sync_status_effects.rpc(stun_timer, slow_timer, slow_percent)

func apply_knockback(impulse: Vector3) -> void:
	if is_dead:
		return
	receive_knockback.rpc(impulse)

@rpc("any_peer", "call_local", "reliable")
func receive_knockback(impulse: Vector3) -> void:
	velocity += impulse

@rpc("any_peer", "call_local", "reliable")
func sync_status_effects(s_timer: float, sl_timer: float, sl_pct: float) -> void:
	stun_timer = s_timer
	slow_timer = sl_timer
	slow_percent = sl_pct

func take_damage(amount: float) -> void:
	if not multiplayer.is_server() or is_dead:
		return
	
	# Absorb damage into shield first
	if current_shield > 0.0:
		if amount <= current_shield:
			current_shield -= amount
			amount = 0.0
		else:
			amount -= current_shield
			current_shield = 0.0
		sync_shield.rpc(current_shield)
	
	if amount > 0.0:
		current_health -= amount
		sync_health.rpc(current_health)
	
	if current_health <= 0.0:
		die()

@rpc("any_peer", "call_local", "reliable")
func sync_health(new_health: float) -> void:
	current_health = new_health

func die() -> void:
	if not multiplayer.is_server() or is_dead:
		return
	
	is_dead = true
	current_shield = 0.0
	sync_shield.rpc(0.0)
	notify_death.rpc()
	get_tree().root.get_node("Main").on_player_died(name.to_int())

@rpc("any_peer", "call_local", "reliable")
func notify_death() -> void:
	is_dead = true
	$CollisionShape3D.disabled = true
	$MeshInstance3D.visible = false
	$FacingIndicator.visible = false
	$HealthBarSprite.visible = false
	if melee_visual:
		melee_visual.visible = false
	if ability_one_visual:
		ability_one_visual.visible = false
	if ability_two_visual:
		ability_two_visual.visible = false
		
	if name.to_int() == multiplayer.get_unique_id():
		spectator_panel.show()
		$PlayerHUD/VBox.hide()
		_cycle_spectator(0)

func _process_spectator(delta: float) -> void:
	if not is_inside_tree():
		return
	
	var alive_players = _get_alive_players()
	if alive_players.is_empty():
		spectator_label.text = "SPECTATING: All players eliminated"
		return

	if Input.is_action_just_pressed("spectate_next"):
		_cycle_spectator(1)
	elif Input.is_action_just_pressed("spectate_prev"):
		_cycle_spectator(-1)

	if spectate_target != null and is_instance_valid(spectate_target):
		if camera and is_instance_valid(camera) and camera.is_inside_tree():
			camera.global_position = spectate_target.global_position + CAMERA_OFFSET
	else:
		_cycle_spectator(0)

func _cycle_spectator(dir: int) -> void:
	var alive_players = _get_alive_players()
	if alive_players.is_empty():
		spectate_target = null
		return
	
	spectate_index = (spectate_index + dir) % alive_players.size()
	if spectate_index < 0:
		spectate_index = alive_players.size() - 1
	
	spectate_target = alive_players[spectate_index]
	var t_name = "Player " + spectate_target.name
	if spectate_target.name == "1":
		t_name = "Host (P1)"
	spectator_label.text = "SPECTATING: %s (%s)\n[LMB / RMB to Cycle]" % [t_name, spectate_target.get("character_name")]

func _get_alive_players() -> Array:
	var list = []
	var container = get_tree().root.get_node_or_null("Main/Players")
	if container:
		for p in container.get_children():
			if not p.get("is_dead") and p != self:
				list.append(p)
	return list

func update_health_bar() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
