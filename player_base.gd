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

# Ability One (RMB), Ability Two (Q), and Ability Three (E) Parameters
@export var ability_one_cooldown: float = 6.0
@export var ability_two_cooldown: float = 8.0
@export var ability_three_cooldown: float = 8.0
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
var is_dashing: bool = false
var dash_timer: float = 0.0
var current_dash_speed: float = 0.0

# Float Status Effect state
var is_floating: bool = false
var float_timer: float = 0.0
var current_gravity_mult: float = 1.0
const FLOAT_TOTAL_DURATION: float = 2.2
const FLOAT_SLOWDOWN_TIME: float = 0.7
const FLOAT_HOVER_TIME: float = 1.4

# Crash Down state
var is_crashing_down: bool = false
var crash_target_pos: Vector3 = Vector3.ZERO

# Attack & Ability state
var attack_timer: float = 0.0
var ability_one_timer: float = 0.0
var ability_two_timer: float = 0.0
var ability_three_timer: float = 0.0
var is_casting_melee: bool = false
var is_casting_ability_one: bool = false
var is_casting_ability_two: bool = false
var is_casting_ability_three: bool = false
var is_dead: bool = false

# Status effects state
var stun_timer: float = 0.0
var slow_timer: float = 0.0
var slow_initial_duration: float = 0.0
var slow_initial_percent: float = 0.0
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

# Passives & Special Ability State
# Crush: Titan's Surge & Gray Health / Iron Blood
var is_crush_empowered: bool = false
var gray_health: float = 0.0
var time_since_last_damage: float = 0.0

# Dive: Rupture Marks & Deflecting Guard
var dive_marks_count: int = 0
var dive_mark_timer: float = 0.0
var dive_mark_attacker_id: int = 0
const DIVE_MARK_DURATION: float = 3.5
const DIVE_MARK_MAX: int = 5
const DIVE_MARK_BURST_PER_STACK: float = 18.0

var is_blocking: bool = false
var block_timer: float = 0.0
const BLOCK_DURATION: float = 3.0
const BLOCK_MAX_TURN_SPEED: float = 2.2 # Max turn speed (rad/s) while blocking
const BLOCK_DR_PERCENT: float = 0.75 # 75% damage reduction from front 140 deg

# Poke: Fleet Foot
var poke_speed_boost_timer: float = 0.0
var poke_speed_boost_percent: float = 0.0

# Wall Impact Damage System (Calculated from knockback_velocity caused by external enemies/hazards)
var knockback_velocity: Vector3 = Vector3.ZERO
var wall_impact_cooldown_timer: float = 0.0
const WALL_IMPACT_MIN_SPEED: float = 14.0 # Minimum velocity directly into wall to trigger damage
const WALL_IMPACT_DAMAGE_FACTOR: float = 1.8 # Damage per m/s of normal impact speed

# Ability hold-to-aim and local hitbox indicator state
var is_holding_shoot: bool = false
var is_holding_ability_one: bool = false
var is_holding_ability_two: bool = false
var is_holding_ability_three: bool = false

var ind_attack: Node3D = null
var ind_ability_one: Node3D = null
var ind_ability_two: Node3D = null
var ind_ability_three: Node3D = null
var ind_dive_crash_range: MeshInstance3D = null
var ind_dive_crash_circle: Node3D = null
var ind_poke_flare_circle: Node3D = null
var ind_poke_dot_zone: Node3D = null

@onready var camera: Camera3D = $Camera3D
@onready var synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var health_bar: ProgressBar = $HealthBarViewport/ProgressBar
@onready var gray_health_bar: ProgressBar = get_node_or_null("HealthBarViewport/GrayProgressBar")
@onready var sprite_3d: Sprite3D = $HealthBarSprite
@onready var melee_visual: Node3D = get_node_or_null("MeleeVisual")
@onready var ability_one_visual: Node3D = get_node_or_null("AbilityOneVisual")
@onready var ability_two_visual: Node3D = get_node_or_null("AbilityTwoVisual")
@onready var block_visual: Node3D = get_node_or_null("BlockVisual")
@onready var crash_visual: Node3D = get_node_or_null("CrashVisual")
@onready var hud: CanvasLayer = $PlayerHUD
@onready var status_cc_label: Label = get_node_or_null("PlayerHUD/VBox/StatusCCLabel")
@onready var attack_cd_label: Label = get_node_or_null("PlayerHUD/VBox/AttackCD")
@onready var ability_one_cd_label: Label = get_node_or_null("PlayerHUD/VBox/AbilityOneCD")
@onready var ability_two_cd_label: Label = get_node_or_null("PlayerHUD/VBox/AbilityTwoCD")
@onready var ability_three_cd_label: Label = get_node_or_null("PlayerHUD/VBox/AbilityThreeCD")
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
		_setup_local_indicators()
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
	if block_visual:
		block_visual.visible = false
	if crash_visual:
		crash_visual.visible = false
	if spectator_panel:
		spectator_panel.hide()

func _setup_local_indicators() -> void:
	if character_name == "Crush":
		# LMB: 4.2m, 120 deg Slam
		ind_attack = AbilityIndicator.create_sector_indicator(melee_size, melee_angle_deg, Color(1.0, 0.4, 0.1, 0.28), Color(1.0, 0.65, 0.2, 0.95))
		# RMB: 5.2m, 100 deg Fan Stun
		ind_ability_one = AbilityIndicator.create_sector_indicator(5.2, 100.0, Color(1.0, 0.85, 0.1, 0.32), Color(1.0, 0.95, 0.3, 0.95))
		# Q: 6.5m Radius Shockwave Circle
		ind_ability_two = AbilityIndicator.create_circle_indicator(6.5, Color(1.0, 0.45, 0.15, 0.22), Color(1.0, 0.6, 0.25, 0.9))
	elif character_name == "Dive":
		# LMB: 2.8m, 135 deg Slash
		ind_attack = AbilityIndicator.create_sector_indicator(melee_size, melee_angle_deg, Color(0.9, 0.2, 0.85, 0.28), Color(1.0, 0.35, 0.95, 0.95))
		# RMB: 3.0m, 135 deg Heavy Cleave
		ind_ability_one = AbilityIndicator.create_sector_indicator(3.0, 135.0, Color(0.2, 0.9, 1.0, 0.32), Color(0.35, 0.95, 1.0, 0.95))
		# Q: 14.0m x 1.5m Earth Tremor path with end pillar circle
		ind_ability_two = AbilityIndicator.create_line_indicator(14.0, 1.5, Color(0.8, 0.3, 1.0, 0.28), Color(0.9, 0.45, 1.0, 0.95), true, 1.4)
		
		# E: 140 deg Frontal Guard Arc indicator
		ind_ability_three = AbilityIndicator.create_sector_indicator(2.5, 140.0, Color(0.2, 0.8, 1.0, 0.35), Color(0.3, 0.9, 1.0, 0.95))
		
		# Contextual Aerial Crash Down: Range ring + 6.0m landing circle
		ind_dive_crash_range = AbilityIndicator.create_ring_indicator(6.0, Color(1.0, 0.3, 0.9, 0.65))
		ind_dive_crash_range.top_level = true
		add_child(ind_dive_crash_range)
		ind_dive_crash_range.hide()
		
		ind_dive_crash_circle = AbilityIndicator.create_circle_indicator(6.0, Color(0.9, 0.2, 0.7, 0.32), Color(1.0, 0.4, 0.85, 0.95))
		ind_dive_crash_circle.top_level = true
		add_child(ind_dive_crash_circle)
		ind_dive_crash_circle.hide()
	elif character_name == "Poke":
		# LMB: 50m Rail Shot line
		ind_attack = AbilityIndicator.create_line_indicator(50.0, 1.0, Color(0.1, 0.85, 0.95, 0.25), Color(0.3, 0.95, 1.0, 0.95))
		# RMB: 60m Repulsor Bolt line
		ind_ability_one = AbilityIndicator.create_line_indicator(60.0, 0.7, Color(1.0, 0.8, 0.2, 0.28), Color(1.0, 0.9, 0.3, 0.95))
		
		# Q: 4.5m Radius Corrosive DoT Zone Ground Circle
		ind_poke_dot_zone = AbilityIndicator.create_circle_indicator(4.5, Color(0.1, 0.9, 0.6, 0.28), Color(0.2, 1.0, 0.7, 0.95))
		ind_poke_dot_zone.top_level = true
		add_child(ind_poke_dot_zone)
		ind_poke_dot_zone.hide()
		
		# E: Recon Flare Targeting Line and 12.0m radius reveal circle
		ind_ability_three = AbilityIndicator.create_line_indicator(65.0, 0.8, Color(0.2, 0.9, 0.9, 0.25), Color(0.3, 1.0, 0.95, 0.95))
		ind_poke_flare_circle = AbilityIndicator.create_circle_indicator(12.0, Color(0.2, 0.9, 0.9, 0.22), Color(0.3, 1.0, 0.95, 0.95))
		ind_poke_flare_circle.top_level = true
		add_child(ind_poke_flare_circle)
		ind_poke_flare_circle.hide()

	if ind_attack:
		add_child(ind_attack)
		ind_attack.hide()
	if ind_ability_one:
		add_child(ind_ability_one)
		ind_ability_one.hide()
	if ind_ability_two:
		add_child(ind_ability_two)
		ind_ability_two.hide()
	if ind_ability_three:
		add_child(ind_ability_three)
		ind_ability_three.hide()

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
		if slow_initial_duration > 0.0:
			slow_percent = slow_initial_percent * (slow_timer / slow_initial_duration)
		if slow_timer <= 0.0:
			slow_timer = 0.0
			slow_percent = 0.0
			slow_initial_duration = 0.0
			slow_initial_percent = 0.0

	if shield_timer > 0.0:
		shield_timer -= delta
		if shield_timer <= 0.0:
			current_shield = 0.0

	if poke_speed_boost_timer > 0.0:
		poke_speed_boost_timer -= delta
		if poke_speed_boost_timer <= 0.0:
			poke_speed_boost_timer = 0.0
			poke_speed_boost_percent = 0.0

	if wall_impact_cooldown_timer > 0.0:
		wall_impact_cooldown_timer -= delta
		if wall_impact_cooldown_timer < 0.0:
			wall_impact_cooldown_timer = 0.0

	# Knockback velocity decay (decays via friction/drag, separate from player movement & dashes)
	if knockback_velocity != Vector3.ZERO:
		if is_on_floor():
			knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, ground_friction * delta)
		else:
			knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, air_drag * delta)

	# Dive Rupture Marks tick (Server-authoritative)
	if multiplayer.is_server() and not is_dead and dive_marks_count > 0:
		dive_mark_timer -= delta
		if dive_mark_timer <= 0.0:
			detonate_dive_marks()

	# Dive Block Duration countdown
	if is_blocking:
		block_timer -= delta
		if block_timer <= 0.0:
			end_block_stance()
			ability_three_timer = ability_three_cooldown

	# Crush Gray Health Decay & Out-of-Combat Regen (Server-authoritative)
	time_since_last_damage += delta
	if multiplayer.is_server() and character_name == "Crush" and not is_dead:
		if time_since_last_damage >= 5.0 and gray_health > 0.0:
			var max_consume_rate = max_health * 0.1 # 10% max HP per sec
			var consume = min(gray_health, max_consume_rate * delta)
			gray_health -= consume
			heal(consume * 0.5) # Heals for 50% of consumed gray health
			sync_gray_health.rpc(gray_health)

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
		_cancel_all_hold_indicators()
		return

	if DisplayServer.window_is_focused() and camera and is_instance_valid(camera) and camera.is_inside_tree():
		camera.global_position = global_position + CAMERA_OFFSET

	if dash_lockout_timer > 0.0:
		dash_lockout_timer -= delta

	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false

	# Float status effect processing
	if is_floating:
		float_timer += delta
		if float_timer < FLOAT_SLOWDOWN_TIME:
			# Gravity artificially slows over time towards 0
			var t = float_timer / FLOAT_SLOWDOWN_TIME
			current_gravity_mult = lerp(1.0, 0.05, t)
		elif float_timer < FLOAT_HOVER_TIME:
			# Pauses at a low value for a moment
			current_gravity_mult = 0.05
		elif float_timer < FLOAT_TOTAL_DURATION:
			# Slowly goes back to normal for a moment
			var t = (float_timer - FLOAT_HOVER_TIME) / (FLOAT_TOTAL_DURATION - FLOAT_HOVER_TIME)
			current_gravity_mult = lerp(0.05, 1.0, t)
		else:
			end_float_state()

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

	if ability_three_timer > 0.0:
		ability_three_timer -= delta

	_update_hud()

	var on_floor = is_on_floor()
	if not on_floor:
		if not is_crashing_down:
			var effective_gravity = gravity * (current_gravity_mult if is_floating else 1.0)
			velocity.y -= effective_gravity * delta
	else:
		if is_floating and float_timer > 0.4:
			end_float_state()

	var stunned = is_stunned()
	var slow_mult = get_slow_multiplier()

	# Jump
	if not stunned and not is_channeling and not is_crashing_down and Input.is_action_just_pressed("jump") and on_floor:
		velocity.y = jump_velocity

	# Target direction from input (blocked if stunned, channeling, or crashing)
	var target_dir := Vector3.ZERO
	if not stunned and not is_channeling and not is_crashing_down:
		var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		target_dir = Vector3(input_dir.x, 0, input_dir.y).normalized()

	# Dash (Shift) or Crash Down
	if not stunned and not is_channeling and Input.is_action_just_pressed("dash"):
		if can_crash_down():
			_perform_dive_crash_down()
		elif current_dash_charges > 0 and dash_lockout_timer <= 0.0 and not is_crashing_down:
			current_dash_charges -= 1
			dash_lockout_timer = dash_cooldown
			var dash_dir = target_dir if target_dir != Vector3.ZERO else -global_transform.basis.z.normalized()
			var effective_impulse = dash_impulse * slow_mult
			current_dash_speed = effective_impulse
			velocity.x = dash_dir.x * effective_impulse
			velocity.z = dash_dir.z * effective_impulse
			is_dashing = true
			dash_timer = 0.45

	# Crash Down Descent Process
	if is_crashing_down:
		var to_target = crash_target_pos - global_position
		var dist_to_target = to_target.length()
		if on_floor or global_position.y <= (crash_target_pos.y + 0.6) or dist_to_target < 2.0:
			_execute_dive_crash_impact()

	# Momentum & Movement Physics (Existing velocity continues smoothly under physics!)
	if not is_crashing_down:
		var current_horizontal = Vector2(velocity.x, velocity.z)
		var speed = current_horizontal.length()
		var speed_mult = slow_mult * (1.0 + poke_speed_boost_percent)
		var effective_max_speed = max_move_speed * speed_mult
		var effective_accel = ground_acceleration * speed_mult

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

	aim_at_mouse(delta)

	# Dive Contextual Aerial Crash Down Auto-Indicator
	if character_name == "Dive" and ind_dive_crash_circle and ind_dive_crash_range:
		if can_crash_down():
			var hit_pos = _get_mouse_ground_hit()
			var current_height = max(0.0, global_position.y)
			var max_cast_range = 6.0 + 1.8 * current_height
			var caster_ground = Vector3(global_position.x, 0.04, global_position.z)
			
			ind_dive_crash_range.global_position = caster_ground
			ind_dive_crash_range.scale = Vector3.ONE * (max_cast_range / 6.0)
			ind_dive_crash_range.show()
			
			var target_pos = caster_ground
			if hit_pos != null:
				var diff = hit_pos - caster_ground
				diff.y = 0.0
				var dist = diff.length()
				if dist > max_cast_range:
					target_pos = caster_ground + diff.normalized() * max_cast_range
				else:
					target_pos = hit_pos
					target_pos.y = 0.04
			else:
				var fwd = -global_transform.basis.z.normalized()
				fwd.y = 0.0
				target_pos = caster_ground + fwd.normalized() * max_cast_range
				target_pos.y = 0.04
				
			ind_dive_crash_circle.global_position = target_pos
			ind_dive_crash_circle.show()
		else:
			ind_dive_crash_circle.hide()
			ind_dive_crash_range.hide()

	# Poke Q Slowing DoT Zone Indicator Update
	if character_name == "Poke" and is_holding_ability_two and ind_poke_dot_zone:
		var hit_pos = _get_mouse_ground_hit()
		var spawn_pos = Vector3(global_position.x, 0.04, global_position.z)
		var target_pos = spawn_pos + (-global_transform.basis.z.normalized()) * 16.0
		target_pos.y = 0.04
		if hit_pos != null:
			var diff = hit_pos - spawn_pos
			diff.y = 0.0
			var dist = clamp(diff.length(), 2.0, 24.0)
			if diff.length_squared() > 0.1:
				target_pos = spawn_pos + diff.normalized() * dist
				target_pos.y = 0.04
		ind_poke_dot_zone.global_position = target_pos

	# Poke E Flare Targeting Indicator Update
	if character_name == "Poke" and is_holding_ability_three and ind_poke_flare_circle:
		var hit_pos = _get_mouse_ground_hit()
		var spawn_pos = Vector3(global_position.x, 0.04, global_position.z)
		var target_pos = spawn_pos + (-global_transform.basis.z.normalized()) * 45.0
		target_pos.y = 0.04
		if hit_pos != null:
			var diff = hit_pos - spawn_pos
			diff.y = 0.0
			var dist = clamp(diff.length(), 6.0, 65.0)
			if diff.length_squared() > 0.1:
				target_pos = spawn_pos + diff.normalized() * dist
				target_pos.y = 0.04
		ind_poke_flare_circle.global_position = target_pos

	# Combat Inputs: Hold to Preview Hitbox / Cast on Release
	if stunned or is_dead or is_channeling or is_crashing_down:
		_cancel_all_hold_indicators()
	else:
		# Primary Attack [LMB]
		if Input.is_action_just_pressed("shoot") and attack_timer <= 0.0 and not is_casting_melee and not is_casting_ability_one and not is_casting_ability_two and not is_casting_ability_three:
			is_holding_shoot = true
			if ind_attack:
				ind_attack.show()

		if is_holding_shoot:
			if not Input.is_action_pressed("shoot"):
				is_holding_shoot = false
				if ind_attack:
					ind_attack.hide()
				if attack_timer <= 0.0 and not is_casting_melee and not is_casting_ability_one and not is_casting_ability_two and not is_casting_ability_three:
					if character_name == "Dive":
						_perform_dive_melee()
					elif is_melee_character:
						_perform_crush_melee_windup()
					else:
						_perform_poke_ranged_attack()

		# Ability One [RMB]
		if Input.is_action_just_pressed("ability_one") and ability_one_timer <= 0.0 and not is_casting_melee and not is_casting_ability_one and not is_casting_ability_two and not is_casting_ability_three:
			is_holding_ability_one = true
			if ind_ability_one:
				ind_ability_one.show()

		if is_holding_ability_one:
			if not Input.is_action_pressed("ability_one"):
				is_holding_ability_one = false
				if ind_ability_one:
					ind_ability_one.hide()
				if ability_one_timer <= 0.0 and not is_casting_melee and not is_casting_ability_one and not is_casting_ability_two and not is_casting_ability_three and (not stunned or can_cast_while_stunned) and not is_channeling and not is_crashing_down:
					_perform_ability_one()

		# Ability Two [Q]
		if Input.is_action_just_pressed("ability_two") and ability_two_timer <= 0.0 and not is_casting_melee and not is_casting_ability_one and not is_casting_ability_two and not is_casting_ability_three:
			is_holding_ability_two = true
			if ind_ability_two:
				ind_ability_two.show()
			if ind_poke_dot_zone:
				ind_poke_dot_zone.show()

		if is_holding_ability_two:
			if not Input.is_action_pressed("ability_two"):
				is_holding_ability_two = false
				if ind_ability_two:
					ind_ability_two.hide()
				if ind_poke_dot_zone:
					ind_poke_dot_zone.hide()
				if ability_two_timer <= 0.0 and not is_casting_melee and not is_casting_ability_one and not is_casting_ability_two and not is_casting_ability_three and (not stunned or can_cast_while_stunned) and not is_channeling and not is_crashing_down:
					_perform_ability_two()

		# Ability Three [E]
		if Input.is_action_just_pressed("ability_three") and (ability_three_timer <= 0.0 or (character_name == "Dive" and is_blocking)) and not is_casting_melee and not is_casting_ability_one and not is_casting_ability_two and not is_casting_ability_three:
			if character_name == "Poke":
				is_holding_ability_three = true
				if ind_ability_three:
					ind_ability_three.show()
				if ind_poke_flare_circle:
					ind_poke_flare_circle.show()
			else:
				_perform_ability_three()

		if is_holding_ability_three:
			if not Input.is_action_pressed("ability_three"):
				is_holding_ability_three = false
				if ind_ability_three:
					ind_ability_three.hide()
				if ind_poke_flare_circle:
					ind_poke_flare_circle.hide()
				if ability_three_timer <= 0.0 and not is_casting_melee and not is_casting_ability_one and not is_casting_ability_two and not is_casting_ability_three and (not stunned or can_cast_while_stunned) and not is_channeling and not is_crashing_down:
					_perform_ability_three()

	var pre_move_velocity = velocity
	move_and_slide()

	# High-Velocity Wall Impact Damage System (Calculated from knockback_velocity from external sources)
	if knockback_velocity.length_squared() > 1.0 and wall_impact_cooldown_timer <= 0.0 and not is_dead:
		for i in range(get_slide_collision_count()):
			var col = get_slide_collision(i)
			var normal = col.get_normal()
			
			# Check if surface is a steep wall / barrier (not flat walkable floor)
			if normal.y < 0.7:
				# Calculate component of knockback velocity directly into the wall
				var velocity_into_wall = -knockback_velocity.dot(normal)
				
				if velocity_into_wall >= WALL_IMPACT_MIN_SPEED:
					knockback_velocity = Vector3.ZERO # Consumed on wall impact
					wall_impact_cooldown_timer = 0.35 # Prevent multi-hit per collision event
					var excess_speed = velocity_into_wall - WALL_IMPACT_MIN_SPEED
					var wall_damage = 10.0 + excess_speed * WALL_IMPACT_DAMAGE_FACTOR
					
					show_wall_impact_effect.rpc(col.get_position(), normal)
					
					if multiplayer.is_server():
						take_damage(wall_damage)
					else:
						request_wall_impact_damage.rpc_id(1, wall_damage, velocity_into_wall)
					break

	# Dive Dash Terrain Wall Bounce Check
	if is_dashing and character_name == "Dive" and not is_floating and not is_crashing_down:
		var has_collided = false
		for i in range(get_slide_collision_count()):
			var col = get_slide_collision(i)
			var normal = col.get_normal()
			
			# Terrain angle conversion rule:
			# Converts 100% of horizontal velocity at 90 degree angle (vertical wall: normal.y == 0.0).
			# Decreases as angle increases (points up more: normal.y > 0.0) -> conversion = (1.0 - normal.y).
			# Goes to 0 at everything below 90 (overhang/ceiling: normal.y < 0.0) -> conversion = 0.0.
			# (Flat floor has normal.y == 1.0 -> conversion = 0.0).
			if normal.y >= 0.0 and normal.y < 0.98:
				var incoming_h = Vector2(pre_move_velocity.x, pre_move_velocity.z)
				var speed_h = max(incoming_h.length(), current_dash_speed)
				var conversion = clamp(1.0 - normal.y, 0.0, 1.0)
				if conversion > 0.0 and speed_h > 0.5:
					var upward_v = speed_h * conversion
					velocity.y = upward_v
					velocity.x = 0.0
					velocity.z = 0.0
					is_dashing = false
					dash_timer = 0.0
					has_collided = true
					start_float_state()
					break
		
		# Fallback wall check if collision count was already processed
		if not has_collided and is_on_wall():
			var normal = get_wall_normal()
			if normal.y >= 0.0 and normal.y < 0.98:
				var incoming_h = Vector2(pre_move_velocity.x, pre_move_velocity.z)
				var speed_h = max(incoming_h.length(), current_dash_speed)
				var conversion = clamp(1.0 - normal.y, 0.0, 1.0)
				if conversion > 0.0 and speed_h > 0.5:
					var upward_v = speed_h * conversion
					velocity.y = upward_v
					velocity.x = 0.0
					velocity.z = 0.0
					is_dashing = false
					dash_timer = 0.0
					start_float_state()

func _update_hud() -> void:
	# Status Effects CC & Passive Display above hotbar
	if status_cc_label:
		if is_channeling:
			status_cc_label.text = "⏳ CHANNELING (%.1fs) ⏳" % channel_timer
			status_cc_label.modulate = Color(0.2, 0.95, 0.95)
		elif is_floating:
			status_cc_label.text = "☁ FLOAT (%.1fs - Gravity: %d%%) ☁" % [max(0.0, FLOAT_TOTAL_DURATION - float_timer), int(current_gravity_mult * 100)]
			status_cc_label.modulate = Color(0.85, 0.5, 1.0)
		elif dive_marks_count > 0:
			status_cc_label.text = "✦ RUPTURE MARKS: %d/5 (%.1fs) ✦" % [dive_marks_count, dive_mark_timer]
			status_cc_label.modulate = Color(1.0, 0.25, 0.9)
		elif is_stunned() and is_slowed():
			status_cc_label.text = "★ STUNNED (%.1fs) | SLOWED -%d%% (%.1fs) ★" % [stun_timer, int(slow_percent * 100), slow_timer]
			status_cc_label.modulate = Color(1.0, 0.3, 0.3)
		elif is_stunned():
			status_cc_label.text = "★ STUNNED (%.1fs) ★" % stun_timer
			status_cc_label.modulate = Color(1.0, 0.35, 0.35)
		elif is_slowed():
			status_cc_label.text = "▼ SLOWED -%d%% (%.1fs) ▼" % [int(slow_percent * 100), slow_timer]
			status_cc_label.modulate = Color(0.35, 0.85, 1.0)
		elif is_blocking:
			status_cc_label.text = "🛡 DEFLECTING GUARD (%.1fs - 75%% FRONT DR) 🛡" % block_timer
			status_cc_label.modulate = Color(0.2, 0.85, 1.0)
		elif poke_speed_boost_timer > 0.0:
			status_cc_label.text = "⚡ FLEET FOOT (+15%% MS) (%.1fs) ⚡" % poke_speed_boost_timer
			status_cc_label.modulate = Color(0.2, 1.0, 0.9)
		elif character_name == "Crush" and gray_health > 0.0:
			status_cc_label.text = "♥ GRAY HEALTH: %d HP (PRESS E) ♥" % int(gray_health)
			status_cc_label.modulate = Color(0.75, 0.8, 0.85)
		elif is_crush_empowered and character_name == "Crush":
			status_cc_label.text = "★ TITAN'S SURGE READY (+25 DMG / HEAL) ★"
			status_cc_label.modulate = Color(1.0, 0.8, 0.15)
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
		elif is_crush_empowered and character_name == "Crush":
			attack_cd_label.text = "Attack [LMB]: ✦ EMPOWERED ✦"
			attack_cd_label.modulate = Color(1.0, 0.85, 0.2)
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

	# Ability Three [E]
	if ability_three_cd_label:
		if is_stunned() and not can_cast_while_stunned:
			ability_three_cd_label.text = "Three [E]: DISABLED (STUNNED)"
			ability_three_cd_label.modulate = Color(0.7, 0.4, 0.4)
		elif is_channeling:
			ability_three_cd_label.text = "Three [E]: CHANNELING..."
			ability_three_cd_label.modulate = Color(0.7, 0.7, 0.3)
		elif character_name == "Dive" and is_blocking:
			ability_three_cd_label.text = "Three [E]: DROP GUARD (RECAST)"
			ability_three_cd_label.modulate = Color(0.2, 0.9, 1.0)
		elif ability_three_timer > 0.0:
			ability_three_cd_label.text = "Three [E]: %.1fs" % ability_three_timer
			ability_three_cd_label.modulate = Color(1, 0.5, 0.5)
		elif is_casting_ability_three:
			ability_three_cd_label.text = "Three [E]: CASTING..."
			ability_three_cd_label.modulate = Color(1, 0.8, 0.2)
		else:
			ability_three_cd_label.text = "Three [E]: READY"
			ability_three_cd_label.modulate = Color(0.4, 1, 0.4)

	# Dash [Shift]
	if dash_cd_label:
		if is_stunned():
			dash_cd_label.text = "Dash [Shift]: DISABLED (STUNNED)"
			dash_cd_label.modulate = Color(0.7, 0.4, 0.4)
		elif is_channeling:
			dash_cd_label.text = "Dash [Shift]: CHANNELING..."
			dash_cd_label.modulate = Color(0.7, 0.7, 0.3)
		elif can_crash_down():
			var current_height = max(0.0, global_position.y)
			var max_range = 6.0 + 1.8 * current_height
			dash_cd_label.text = "Crash Down [Shift]: READY (Range: %.0fm)" % max_range
			dash_cd_label.modulate = Color(1.0, 0.35, 0.95)
		elif is_crashing_down:
			dash_cd_label.text = "Crash Down [Shift]: CRASHING!"
			dash_cd_label.modulate = Color(1.0, 0.2, 0.7)
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
		get_tree().root.get_node("Main").spawn_projectile(spawn_pos, facing_dir, name.to_int(), projectile_damage, projectile_speed, projectile_size)
	else:
		request_fire.rpc_id(1, spawn_pos, facing_dir, projectile_damage, projectile_speed, projectile_size)

func _perform_dive_melee() -> void:
	attack_timer = attack_cooldown
	show_melee_effect.rpc(true)
	get_tree().create_timer(0.18).timeout.connect(func(): show_melee_effect.rpc(false))
	
	var facing_dir = -global_transform.basis.z.normalized()
	if multiplayer.is_server():
		execute_dive_melee_hit_on_server(global_position, facing_dir, name.to_int(), melee_damage, melee_size, melee_angle_deg)
	else:
		request_dive_melee_strike.rpc_id(1, global_position, facing_dir, melee_damage, melee_size, melee_angle_deg)

func _perform_crush_melee_windup() -> void:
	is_casting_melee = true
	var actual_windup = windup_time if windup_time > 0.0 else melee_windup_time
	attack_timer = attack_cooldown + actual_windup
	
	var was_empowered = is_crush_empowered
	set_crush_empowered(false) # Consumed whether it hits or not
	
	show_melee_effect.rpc(true)
	await get_tree().create_timer(actual_windup).timeout
	is_casting_melee = false
	show_melee_effect.rpc(false)
	
	var facing_dir = -global_transform.basis.z.normalized()
	if multiplayer.is_server():
		execute_melee_hit_on_server(global_position, facing_dir, name.to_int(), melee_damage, melee_size, melee_angle_deg, was_empowered)
	else:
		request_melee_strike.rpc_id(1, global_position, facing_dir, melee_damage, melee_size, melee_angle_deg, was_empowered)

func start_float_state() -> void:
	is_floating = true
	float_timer = 0.0
	current_gravity_mult = 1.0
	if multiplayer.is_server():
		sync_float_state.rpc(true)

func end_float_state() -> void:
	is_floating = false
	float_timer = 0.0
	current_gravity_mult = 1.0
	if multiplayer.is_server():
		sync_float_state.rpc(false)

@rpc("any_peer", "call_local", "reliable")
func sync_float_state(floating: bool) -> void:
	is_floating = floating
	if not floating:
		float_timer = 0.0
		current_gravity_mult = 1.0

func can_crash_down() -> bool:
	return character_name == "Dive" and is_floating and not is_crashing_down

func _perform_dive_crash_down() -> void:
	var hit_pos = _get_mouse_ground_hit()
	var current_height = max(0.0, global_position.y)
	var max_cast_range = 6.0 + 1.8 * current_height
	
	var target_pos = global_position
	target_pos.y = 0.0
	
	if hit_pos != null:
		var diff = hit_pos - global_position
		diff.y = 0.0
		var dist = diff.length()
		if dist > max_cast_range:
			target_pos = global_position + diff.normalized() * max_cast_range
			target_pos.y = 0.0
		else:
			target_pos = hit_pos
			target_pos.y = 0.0
	else:
		var fwd = -global_transform.basis.z.normalized()
		target_pos = global_position + fwd * max_cast_range
		target_pos.y = 0.0
	
	is_crashing_down = true
	crash_target_pos = target_pos
	is_floating = false
	current_gravity_mult = 1.0
	
	var to_target = (crash_target_pos - global_position)
	var crash_speed = 52.0
	velocity = to_target.normalized() * crash_speed

func _execute_dive_crash_impact() -> void:
	is_crashing_down = false
	velocity = Vector3.ZERO
	
	var impact_pos = global_position
	impact_pos.y = 0.0
	
	show_crash_impact_effect.rpc(impact_pos)
	
	if multiplayer.is_server():
		execute_crash_down_impact_on_server(impact_pos, name.to_int())
	else:
		request_crash_down_impact.rpc_id(1, impact_pos)

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
	
	var bolt_dmg: float = 20.0
	var bolt_spd: float = 85.0
	var bolt_size: float = 0.35
	var bolt_life: float = 1.0 # 85 meters range coverage
	var stun_dur: float = 1.0
	var kb_force: float = 36.0
	
	if multiplayer.is_server():
		get_tree().root.get_node("Main").spawn_projectile(spawn_pos, facing_dir, name.to_int(), bolt_dmg, bolt_spd, bolt_size, bolt_life, "knockback_stun", stun_dur, kb_force)
	else:
		request_fire_ability_one.rpc_id(1, spawn_pos, facing_dir, bolt_dmg, bolt_spd, bolt_size, bolt_life, "knockback_stun", stun_dur, kb_force)

func _perform_dive_ability_one() -> void:
	is_casting_ability_one = true
	var windup_delay = 0.18
	ability_one_timer = ability_one_cooldown + windup_delay
	
	show_ability_one_visual.rpc(true)
	await get_tree().create_timer(windup_delay).timeout
	is_casting_ability_one = false
	show_ability_one_visual.rpc(false)
	
	var facing_dir = -global_transform.basis.z.normalized()
	var heavy_dmg: float = 65.0
	var heavy_size: float = 3.0
	var heavy_angle: float = 135.0
	
	if multiplayer.is_server():
		execute_dive_ability_one_on_server(global_position, facing_dir, 1, heavy_dmg, heavy_size, heavy_angle)
	else:
		request_dive_ability_one.rpc_id(1, global_position, facing_dir, heavy_dmg, heavy_size, heavy_angle)

func _perform_crush_ability_one() -> void:
	is_casting_ability_one = true
	var windup_delay = 0.16
	ability_one_timer = ability_one_cooldown + windup_delay
	
	show_ability_one_visual.rpc(true)
	await get_tree().create_timer(windup_delay).timeout
	is_casting_ability_one = false
	show_ability_one_visual.rpc(false)
	
	set_crush_empowered(true) # Titan's Surge Passive Activation
	
	var facing_dir = -global_transform.basis.z.normalized()
	if multiplayer.is_server():
		execute_crush_fan_stun_on_server(global_position, facing_dir, name.to_int())
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
	set_crush_empowered(true) # Titan's Surge Passive Activation
	
	show_ability_two_visual.rpc(true)
	get_tree().create_timer(0.3).timeout.connect(func():
		is_casting_ability_two = false
		show_ability_two_visual.rpc(false)
	)
	
	# Medium size AOE shockwave (radius 6.5m, 20 dmg, 30% slow for 2.5s)
	if multiplayer.is_server():
		execute_crush_aoe_two_on_server(global_position, name.to_int())
	else:
		request_crush_aoe_two.rpc_id(1, global_position)

func _perform_dive_ability_two() -> void:
	# Dive pauses to channel for 0.35s (self-inflicted CC, canceled if stunned)
	start_channel(0.35, Callable(self, "_on_dive_q_channel_finished"))

func _on_dive_q_channel_finished() -> void:
	ability_two_timer = ability_two_cooldown
	var facing_dir = -global_transform.basis.z.normalized()
	facing_dir.y = 0.0
	facing_dir = facing_dir.normalized()
	var spawn_pos = global_position + Vector3(0, 0.8, 0) + facing_dir * 1.2
	
	var tremor_dmg: float = 18.0
	var tremor_speed: float = 28.0
	var tremor_size: float = 1.5
	var tremor_life: float = 0.5 # Distance: 14.0m (half range)
	var slow_dur: float = 2.0
	var slow_pct: float = 0.4
	
	# Dive sends forward a piercing tremor that travels far, slows enemies in its path, and spawns temporary terrain at the end
	if multiplayer.is_server():
		get_tree().root.get_node("Main").spawn_projectile(spawn_pos, facing_dir, name.to_int(), tremor_dmg, tremor_speed, tremor_size, tremor_life, "slow", slow_dur, slow_pct, true, true)
	else:
		request_fire_ability_two.rpc_id(1, spawn_pos, facing_dir, tremor_dmg, tremor_speed, tremor_size, tremor_life, "slow", slow_dur, slow_pct, true, true)

func _perform_poke_ability_two() -> void:
	ability_two_timer = ability_two_cooldown
	var hit_pos = _get_mouse_ground_hit()
	var spawn_pos = Vector3(global_position.x, 0.0, global_position.z)
	var target_pos = spawn_pos + (-global_transform.basis.z.normalized()) * 16.0
	if hit_pos != null:
		var diff = hit_pos - spawn_pos
		diff.y = 0.0
		var dist = clamp(diff.length(), 2.0, 24.0)
		target_pos = spawn_pos + diff.normalized() * dist
	target_pos.y = 0.0
	
	if multiplayer.is_server():
		get_tree().root.get_node("Main").spawn_slowing_dot_zone(target_pos, 4.5, 4.0, 24.0, 0.5, name.to_int())
	else:
		request_poke_dot_zone.rpc_id(1, target_pos)

@rpc("any_peer", "call_remote", "reliable")
func request_poke_dot_zone(target_pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	get_tree().root.get_node("Main").spawn_slowing_dot_zone(target_pos, 4.5, 4.0, 24.0, 0.5, sender_id)

# --- Ability Three (E) ---
func _perform_ability_three() -> void:
	if character_name == "Crush":
		_perform_crush_ability_three()
	elif character_name == "Dive":
		_perform_dive_ability_three()
	else:
		_perform_poke_ability_three()

func _perform_crush_ability_three() -> void:
	ability_three_timer = ability_three_cooldown
	set_crush_empowered(true) # Titan's Surge Passive Activation
	
	if gray_health > 0.0:
		apply_shield(gray_health, 5.0)
		gray_health = 0.0
		if multiplayer.is_server():
			sync_gray_health.rpc(0.0)
		else:
			request_crush_consume_gray_health.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func request_crush_consume_gray_health() -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var player = get_tree().root.get_node_or_null("Main/Players/" + str(sender_id))
	if player and player.get("gray_health") > 0.0:
		var g_hp = player.get("gray_health")
		player.apply_shield(g_hp, 5.0)
		player.set("gray_health", 0.0)
		player.sync_gray_health.rpc(0.0)

func _perform_dive_ability_three() -> void:
	if is_blocking:
		# Recast early to drop block and start CD sooner
		end_block_stance()
		ability_three_timer = ability_three_cooldown
		if not multiplayer.is_server():
			request_cancel_dive_block.rpc_id(1)
	else:
		start_block_stance()
		if not multiplayer.is_server():
			request_start_dive_block.rpc_id(1)

func start_block_stance() -> void:
	is_blocking = true
	block_timer = BLOCK_DURATION
	if block_visual:
		block_visual.visible = true
	if multiplayer.is_server():
		sync_block_state.rpc(true)

func end_block_stance() -> void:
	is_blocking = false
	block_timer = 0.0
	if block_visual:
		block_visual.visible = false
	if multiplayer.is_server():
		sync_block_state.rpc(false)

@rpc("any_peer", "call_remote", "reliable")
func request_start_dive_block() -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var player = get_tree().root.get_node_or_null("Main/Players/" + str(sender_id))
	if player and player.has_method("start_block_stance"):
		player.start_block_stance()

@rpc("any_peer", "call_remote", "reliable")
func request_cancel_dive_block() -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var player = get_tree().root.get_node_or_null("Main/Players/" + str(sender_id))
	if player and player.has_method("end_block_stance"):
		player.end_block_stance()
		player.set("ability_three_timer", player.get("ability_three_cooldown"))

@rpc("any_peer", "call_local", "reliable")
func sync_block_state(active: bool) -> void:
	is_blocking = active
	if block_visual:
		block_visual.visible = active
	_update_hud()

func _perform_poke_ability_three() -> void:
	ability_three_timer = ability_three_cooldown
	var facing_dir = -global_transform.basis.z.normalized()
	var spawn_pos = global_position + Vector3(0, 0.8, 0) + facing_dir * 1.1
	
	var target_dist: float = 45.0
	var hit_pos = _get_mouse_ground_hit()
	if hit_pos != null:
		var diff = hit_pos - global_position
		diff.y = 0.0
		target_dist = clamp(diff.length(), 6.0, 65.0)
	
	if multiplayer.is_server():
		get_tree().root.get_node("Main").spawn_vision_flare(spawn_pos, facing_dir, target_dist, name.to_int())
	else:
		request_fire_vision_flare.rpc_id(1, spawn_pos, facing_dir, target_dist)

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
					player.take_damage(20.0, attacker_id)
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
				player.take_damage(20.0, attacker_id)
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
func request_melee_strike(origin_pos: Vector3, forward_dir: Vector3, dmg: float, size: float, angle_deg: float, was_empowered: bool = false) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	execute_melee_hit_on_server(origin_pos, forward_dir, sender_id, dmg, size, angle_deg, was_empowered)

func execute_melee_hit_on_server(origin_pos: Vector3, forward_dir: Vector3, attacker_id: int, dmg: float, size: float, angle_deg: float, was_empowered: bool = false) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	
	var final_dmg = dmg + (25.0 if was_empowered else 0.0)
	var fwd_2d = Vector2(forward_dir.x, forward_dir.z).normalized()
	var hit_count = 0
	
	for player in players_container.get_children():
		if player.name != str(attacker_id) and player.has_method("take_damage") and not player.get("is_dead"):
			var diff = player.global_position - origin_pos
			var diff_2d = Vector2(diff.x, diff.z)
			var dist = diff_2d.length()
			
			if abs(diff.y) <= 3.0 and dist <= size:
				var to_target_2d = diff_2d.normalized()
				var angle = rad_to_deg(fwd_2d.angle_to(to_target_2d))
				if abs(angle) <= (angle_deg * 0.5):
					player.take_damage(final_dmg, attacker_id)
					hit_count += 1
					
	# Crush Titan's Surge heal trigger (triggers once if at least 1 enemy was hit)
	if was_empowered and hit_count > 0:
		var attacker = players_container.get_node_or_null(str(attacker_id))
		if attacker and attacker.has_method("heal"):
			attacker.heal(24.0)

@rpc("any_peer", "call_remote", "reliable")
func request_dive_melee_strike(origin_pos: Vector3, forward_dir: Vector3, dmg: float, size: float, angle_deg: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	execute_dive_melee_hit_on_server(origin_pos, forward_dir, sender_id, dmg, size, angle_deg)

func execute_dive_melee_hit_on_server(origin_pos: Vector3, forward_dir: Vector3, attacker_id: int, dmg: float, size: float, angle_deg: float) -> void:
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
					player.take_damage(dmg, attacker_id)
					if player.has_method("apply_knockback"):
						var kb_dir = Vector3(forward_dir.x, 0.25, forward_dir.z).normalized()
						player.apply_knockback(kb_dir * 9.5)

@rpc("any_peer", "call_remote", "reliable")
func request_dive_ability_one(origin_pos: Vector3, forward_dir: Vector3, dmg: float, size: float, angle_deg: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	execute_dive_ability_one_on_server(origin_pos, forward_dir, sender_id, dmg, size, angle_deg)

func execute_dive_ability_one_on_server(origin_pos: Vector3, forward_dir: Vector3, attacker_id: int, dmg: float, size: float, angle_deg: float) -> void:
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
					player.take_damage(dmg, attacker_id)
					if player.has_method("apply_slow"):
						player.apply_slow(1.6, 0.75)
					if player.has_method("apply_knockback"):
						var kb_dir = Vector3(forward_dir.x, 0.2, forward_dir.z).normalized()
						player.apply_knockback(kb_dir * 8.0)

@rpc("any_peer", "call_local", "reliable")
func show_crash_impact_effect(pos: Vector3) -> void:
	if crash_visual:
		crash_visual.global_position = pos
		crash_visual.visible = true
		crash_visual.scale = Vector3(0.3, 1.0, 0.3)
		var tween = create_tween()
		tween.tween_property(crash_visual, "scale", Vector3(1.1, 1.0, 1.1), 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(crash_visual, "scale", Vector3(0.01, 1.0, 0.01), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): crash_visual.visible = false)

@rpc("any_peer", "call_remote", "reliable")
func request_crash_down_impact(impact_pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	execute_crash_down_impact_on_server(impact_pos, sender_id)

func execute_crash_down_impact_on_server(impact_pos: Vector3, attacker_id: int) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	
	var aoe_radius: float = 6.0
	var damage_amount: float = 48.0
	
	for player in players_container.get_children():
		if player.name != str(attacker_id) and player.has_method("take_damage") and not player.get("is_dead"):
			var diff = player.global_position - impact_pos
			var dist = diff.length()
			if dist <= aoe_radius:
				player.take_damage(damage_amount, attacker_id)
				if player.has_method("apply_knockback"):
					var horiz_diff = Vector3(diff.x, 0, diff.z)
					var horiz_dir = horiz_diff.normalized() if horiz_diff.length_squared() > 0.01 else -player.global_transform.basis.z.normalized()
					var dist_ratio = clamp(1.0 - (dist / aoe_radius), 0.35, 1.0)
					var airborne_impulse = horiz_dir * (14.0 * dist_ratio + 5.0) + Vector3.UP * (18.0 * dist_ratio + 6.0)
					player.apply_knockback(airborne_impulse)

func aim_at_mouse(delta: float = 0.0) -> void:
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
			if is_blocking and delta > 0.0:
				# Smoothly clamp turn speed while blocking in defensive stance
				var target_diff = target - global_position
				var target_angle = atan2(-target_diff.x, -target_diff.z)
				var current_angle = rotation.y
				rotation.y = rotate_toward(current_angle, target_angle, BLOCK_MAX_TURN_SPEED * delta)
				rotation.x = 0.0
				rotation.z = 0.0
			else:
				look_at(target, Vector3.UP)
				rotation.x = 0.0
				rotation.z = 0.0

@rpc("any_peer", "call_remote", "reliable")
func request_wall_impact_damage(dmg: float, impact_spd: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var player = get_tree().root.get_node_or_null("Main/Players/" + str(sender_id))
	if player and not player.get("is_dead"):
		player.take_damage(dmg)

@rpc("any_peer", "call_local", "reliable")
func show_wall_impact_effect(pos: Vector3, normal: Vector3) -> void:
	if crash_visual:
		crash_visual.global_position = pos + normal * 0.2
		crash_visual.visible = true
		crash_visual.scale = Vector3(0.2, 1.0, 0.2)
		var tween = create_tween()
		tween.tween_property(crash_visual, "scale", Vector3(0.7, 1.0, 0.7), 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(crash_visual, "scale", Vector3(0.01, 1.0, 0.01), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): crash_visual.visible = false)

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
	if is_floating:
		end_float_state()
	if is_blocking:
		end_block_stance()
		ability_three_timer = ability_three_cooldown
	is_crashing_down = false
	is_dashing = false
	_cancel_all_hold_indicators()
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
	velocity.x = impulse.x
	velocity.z = impulse.z
	velocity.y = max(velocity.y + impulse.y, impulse.y)
	knockback_velocity = impulse

@rpc("any_peer", "call_local", "reliable")
func sync_status_effects(s_timer: float, sl_timer: float, sl_pct: float) -> void:
	stun_timer = s_timer
	slow_timer = sl_timer
	slow_percent = sl_pct

func take_damage(amount: float, attacker_id: int = 0) -> void:
	if not multiplayer.is_server() or is_dead:
		return

	# Dive Directional Block Check (75% DR against frontal 140 deg arc)
	if is_blocking and attacker_id > 0:
		var attacker = get_tree().root.get_node_or_null("Main/Players/" + str(attacker_id))
		if attacker:
			var diff = attacker.global_position - global_position
			var diff_2d = Vector2(diff.x, diff.z).normalized()
			var fwd_3d = -global_transform.basis.z.normalized()
			var fwd_2d = Vector2(fwd_3d.x, fwd_3d.z).normalized()
			var angle_deg = rad_to_deg(fwd_2d.angle_to(diff_2d))
			if abs(angle_deg) <= 70.0:
				amount *= (1.0 - BLOCK_DR_PERCENT) # 75% reduction
	
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
		
		# Crush Gray Health Storage (stores 30% of damage taken)
		if character_name == "Crush":
			gray_health = min(gray_health + amount * 0.3, max_health - current_health)
			sync_gray_health.rpc(gray_health)
	
	time_since_last_damage = 0.0

	if current_health <= 0.0:
		die()
		return
		
	# Dive Passive Rupture Mark Application
	if attacker_id > 0:
		var attacker = get_tree().root.get_node_or_null("Main/Players/" + str(attacker_id))
		if attacker and attacker.get("character_name") == "Dive":
			apply_dive_mark(attacker_id)

func heal(amount: float) -> void:
	if not multiplayer.is_server() or is_dead:
		return
	current_health = min(max_health, current_health + amount)
	sync_health.rpc(current_health)

func set_crush_empowered(active: bool) -> void:
	is_crush_empowered = active
	sync_crush_empowered.rpc(active)

@rpc("any_peer", "call_local", "reliable")
func sync_crush_empowered(active: bool) -> void:
	is_crush_empowered = active
	_update_hud()

# --- Dive Rupture Marks Passive ---
func apply_dive_mark(attacker_id: int) -> void:
	if not multiplayer.is_server() or is_dead:
		return
	
	if dive_marks_count == 0:
		dive_marks_count = 1
		dive_mark_timer = DIVE_MARK_DURATION # 3.5s
		dive_mark_attacker_id = attacker_id
	else:
		dive_marks_count += 1
		dive_mark_attacker_id = attacker_id
		# Timer does not reset!
	
	sync_dive_marks.rpc(dive_marks_count, dive_mark_timer)
	
	if dive_marks_count >= DIVE_MARK_MAX:
		detonate_dive_marks()

func detonate_dive_marks() -> void:
	if not multiplayer.is_server() or is_dead or dive_marks_count <= 0:
		dive_marks_count = 0
		dive_mark_timer = 0.0
		sync_dive_marks.rpc(0, 0.0)
		return
	
	var count = dive_marks_count
	var burst_damage = count * DIVE_MARK_BURST_PER_STACK
	var attacker_id = dive_mark_attacker_id
	
	dive_marks_count = 0
	dive_mark_timer = 0.0
	sync_dive_marks.rpc(0, 0.0)
	show_mark_detonation_effect.rpc(global_position, count)
	
	take_damage(burst_damage, 0) # Apply burst damage (attacker_id=0 so it does not loop)

@rpc("any_peer", "call_local", "reliable")
func sync_dive_marks(marks: int, timer: float) -> void:
	dive_marks_count = marks
	dive_mark_timer = timer
	_update_hud()

@rpc("any_peer", "call_local", "reliable")
func show_mark_detonation_effect(pos: Vector3, count: int) -> void:
	if crash_visual:
		crash_visual.global_position = pos
		crash_visual.visible = true
		crash_visual.scale = Vector3(0.1, 1.0, 0.1) * float(count)
		var tween = create_tween()
		tween.tween_property(crash_visual, "scale", Vector3(0.5, 1.0, 0.5) * (float(count) * 0.3 + 0.5), 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(crash_visual, "scale", Vector3(0.01, 1.0, 0.01), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): crash_visual.visible = false)

# --- Poke Passive: Fleet Foot (15% non-stacking MS on hit, refreshes duration) ---
func apply_speed_boost(duration: float = 2.5, percent: float = 0.15) -> void:
	if is_dead:
		return
	poke_speed_boost_timer = duration # Refreshes duration on hit
	poke_speed_boost_percent = percent
	if multiplayer.is_server():
		sync_speed_boost.rpc(poke_speed_boost_timer, poke_speed_boost_percent)

@rpc("any_peer", "call_local", "reliable")
func sync_speed_boost(dur: float, pct: float) -> void:
	poke_speed_boost_timer = dur
	poke_speed_boost_percent = pct
	_update_hud()

@rpc("any_peer", "call_local", "reliable")
func sync_health(new_health: float) -> void:
	current_health = new_health

@rpc("any_peer", "call_local", "reliable")
func sync_gray_health(amount: float) -> void:
	gray_health = amount
	update_health_bar()
	_update_hud()

func die() -> void:
	if not multiplayer.is_server() or is_dead:
		return
	
	is_dead = true
	current_shield = 0.0
	gray_health = 0.0
	dive_marks_count = 0
	dive_mark_timer = 0.0
	if is_blocking:
		end_block_stance()
	sync_gray_health.rpc(0.0)
	sync_dive_marks.rpc(0, 0.0)
	sync_shield.rpc(0.0)
	notify_death.rpc()
	get_tree().root.get_node("Main").on_player_died(name.to_int())

@rpc("any_peer", "call_local", "reliable")
func notify_death() -> void:
	is_dead = true
	if is_floating:
		end_float_state()
	if is_blocking:
		end_block_stance()
	is_crashing_down = false
	is_dashing = false
	knockback_velocity = Vector3.ZERO
	gray_health = 0.0
	dive_marks_count = 0
	dive_mark_timer = 0.0
	is_crush_empowered = false
	poke_speed_boost_timer = 0.0
	poke_speed_boost_percent = 0.0
	_cancel_all_hold_indicators()
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
	if block_visual:
		block_visual.visible = false
	if crash_visual:
		crash_visual.visible = false
		
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
	if gray_health_bar:
		gray_health_bar.max_value = max_health
		gray_health_bar.value = current_health + gray_health

func _get_mouse_ground_hit() -> Variant:
	var viewport = get_viewport()
	if not viewport or not camera:
		return null
	var mouse_pos = viewport.get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	var ground_plane = Plane(Vector3.UP, 0.0)
	return ground_plane.intersects_ray(ray_origin, ray_dir)

func _cancel_all_hold_indicators() -> void:
	is_holding_shoot = false
	is_holding_ability_one = false
	is_holding_ability_two = false
	is_holding_ability_three = false
	if ind_attack:
		ind_attack.hide()
	if ind_ability_one:
		ind_ability_one.hide()
	if ind_ability_two:
		ind_ability_two.hide()
	if ind_ability_three:
		ind_ability_three.hide()
	if ind_poke_dot_zone:
		ind_poke_dot_zone.hide()
	if ind_poke_flare_circle:
		ind_poke_flare_circle.hide()
	if ind_dive_crash_circle:
		ind_dive_crash_circle.hide()
	if ind_dive_crash_range:
		ind_dive_crash_range.hide()
