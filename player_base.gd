class_name BasePlayer
extends CharacterBody3D

enum ActionType {
	ATTACK = 0,      # Primary / Basic Attack
	ABILITY = 1,     # Special Ability / Spell
	ENVIRONMENT = 2  # Map Hazards / Void / Wall Impact
}

signal attack_performed(attack_name: String)
signal ability_cast(ability_name: String, slot_key: String)
signal damage_dealt(target: Node, amount: float, action_type: int)
signal damage_taken(attacker_id: int, amount: float, action_type: int)

# Character Identification & Team
@export var character_name: String = "Character"
@export var team_id: int = 1

# Core Vitals & Defense
@export var max_health: float = 100.0
@export var current_health: float = 100.0:
	set(value):
		current_health = clamp(value, 0.0, max_health)
		update_health_bar()

@export var max_shield: float = 100.0
var current_shield: float = 0.0:
	set(value):
		current_shield = clamp(value, 0.0, max_shield)
		update_health_bar()
var shield_timer: float = 0.0
var is_dead: bool = false

# Universal Movement Mechanics
@export var max_move_speed: float = 10.0
@export var ground_acceleration: float = 65.0
@export var ground_friction: float = 40.0
@export var air_acceleration: float = 25.0
@export var air_drag: float = 3.5
@export var jump_velocity: float = 9.5

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 24.0)

# External Knockback & Wall Impact
var knockback_velocity: Vector3 = Vector3.ZERO
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

# Universal Channeling
var is_channeling: bool = false
var channel_timer: float = 0.0
var channel_complete_callback: Callable = Callable()

# Camera & Spectator Constants
const CAMERA_OFFSET: Vector3 = Vector3(0, 17, 9.5)
const VOID_DEATH_Y: float = -8.0
var spectate_target: Node3D = null
var spectate_index: int = 0

# UI & Node References
@onready var camera: Camera3D = get_node_or_null("Camera3D")
@onready var sprite_3d: Sprite3D = get_node_or_null("HealthBarSprite")
@onready var health_bar: ProgressBar = get_node_or_null("HealthBarViewport/ProgressBar")
@onready var gray_health_bar: ProgressBar = get_node_or_null("HealthBarViewport/GrayProgressBar")

@onready var hud: CanvasLayer = get_node_or_null("PlayerHUD")
@onready var hud_container: Control = get_node_or_null("PlayerHUD/HUDContainer")
@onready var status_cc_label: Label = get_node_or_null("PlayerHUD/HUDContainer/StatusCCLabel") if has_node("PlayerHUD/HUDContainer/StatusCCLabel") else get_node_or_null("PlayerHUD/VBox/StatusCCLabel")

@onready var slot_ability_one: PanelContainer = get_node_or_null("PlayerHUD/HUDContainer/AbilityBar/SlotRMB")
@onready var slot_ability_two: PanelContainer = get_node_or_null("PlayerHUD/HUDContainer/AbilityBar/SlotQ")
@onready var slot_ability_three: PanelContainer = get_node_or_null("PlayerHUD/HUDContainer/AbilityBar/SlotE")
@onready var slot_ability_four: PanelContainer = get_node_or_null("PlayerHUD/HUDContainer/AbilityBar/SlotR")
@onready var slot_dash: PanelContainer = get_node_or_null("PlayerHUD/HUDContainer/AbilityBar/SlotShift")

@onready var spectator_panel: PanelContainer = get_node_or_null("PlayerHUD/SpectatorPanel")
@onready var spectator_label: Label = get_node_or_null("PlayerHUD/SpectatorPanel/VBox/SpectatorLabel")


func _enter_tree() -> void:
	var peer_id = name.to_int()
	if peer_id > 0:
		set_multiplayer_authority(peer_id)
		if has_node("MultiplayerSynchronizer"):
			$MultiplayerSynchronizer.set_multiplayer_authority(peer_id)

func _ready() -> void:
	var peer_id = name.to_int()
	if peer_id > 0:
		set_multiplayer_authority(peer_id)
		if has_node("MultiplayerSynchronizer"):
			$MultiplayerSynchronizer.set_multiplayer_authority(peer_id)

	var is_local = (name.to_int() == multiplayer.get_unique_id())
	if camera:
		camera.current = is_local
		if is_local:
			camera.top_level = true
			camera.global_position = global_position + CAMERA_OFFSET
			camera.look_at(global_position, Vector3.UP)
	
	if hud:
		hud.visible = is_local
	if spectator_panel:
		spectator_panel.visible = false

	if sprite_3d and has_node("HealthBarViewport"):
		sprite_3d.texture = $HealthBarViewport.get_texture()
	update_health_bar()
	_update_team_visuals()

	# Call character-specific kit setup
	_setup_character_kit()

func set_team_id(new_team: int) -> void:
	team_id = new_team
	_update_team_visuals()

func is_enemy(other: Node) -> bool:
	if not other or other == self:
		return false
	if other.get("team_id") != null:
		return other.team_id != team_id
	return true

func _update_team_visuals() -> void:
	var mesh_inst: MeshInstance3D = get_node_or_null("MeshInstance3D")
	if mesh_inst and mesh_inst.material_override:
		var mat = mesh_inst.material_override.duplicate() as StandardMaterial3D
		if mat:
			if team_id == 1:
				mat.albedo_color = Color(0.2, 0.6, 1.0)
			elif team_id == 2:
				mat.albedo_color = Color(1.0, 0.3, 0.2)
			mesh_inst.material_override = mat

# --- Status Effects & CC Queries ---
func is_stunned() -> bool:
	return stun_timer > 0.0

func is_silenced() -> bool:
	return silence_timer > 0.0

func is_slowed() -> bool:
	return slow_timer > 0.0

func is_rooted() -> bool:
	return root_timer > 0.0

func is_grounded() -> bool:
	return grounded_timer > 0.0

func is_crippled() -> bool:
	return cripple_timer > 0.0

func is_ethereal_active() -> bool:
	return ethereal_timer > 0.0

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
	if not multiplayer.is_server():
		return
	current_shield = min(max_shield, current_shield + amount)
	shield_timer = max(shield_timer, duration)
	sync_shield.rpc(current_shield)

@rpc("authority", "call_local", "reliable")
func sync_shield(new_shield: float) -> void:
	current_shield = new_shield

func _physics_process(delta: float) -> void:
	# Deadzone / Void Check
	if multiplayer.is_server() and not is_dead and global_position.y < VOID_DEATH_Y:
		die()

	# Status effect timers decrement
	if stun_timer > 0.0:
		stun_timer = max(0.0, stun_timer - delta)

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

	if speed_boost_timer > 0.0:
		speed_boost_timer -= delta
		if speed_boost_timer <= 0.0:
			speed_boost_timer = 0.0
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

	# Knockback velocity decay
	if knockback_velocity != Vector3.ZERO:
		if is_on_floor():
			knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, ground_friction * delta)
		else:
			knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, air_drag * delta)

	# Channeling process
	if is_channeling:
		channel_timer -= delta
		if channel_timer <= 0.0:
			is_channeling = false
			if channel_complete_callback.is_valid():
				var cb = channel_complete_callback
				channel_complete_callback = Callable()
				cb.call()

	# Process Character-specific kit logic (both server and clients)
	_process_character_kit(delta)

	var is_local_player = (name.to_int() == multiplayer.get_unique_id())
	var is_server_dummy = (name.to_int() == 0 and (multiplayer.is_server() or not multiplayer.has_multiplayer_peer()))

	if not is_local_player and not is_server_dummy:
		return

	if is_server_dummy:
		var on_floor_dummy = is_on_floor()
		if not on_floor_dummy:
			velocity.y -= gravity * delta
		velocity.x += knockback_velocity.x
		velocity.z += knockback_velocity.z
		var pre_move_vel_dummy = velocity
		move_and_slide()
		_check_wall_impact(pre_move_vel_dummy)
		return

	# If dead, process Spectator camera & inputs (skip spectator in training mode)
	if is_dead:
		var main_node = get_tree().root.get_node_or_null("Main")
		if main_node and main_node.get("is_training_mode") == true:
			if camera and is_instance_valid(camera) and camera.is_inside_tree():
				_process_camera(delta)
			return
		_process_spectator(delta)
		return

	if not DisplayServer.window_is_focused():
		return

	# Update camera position
	if camera and is_instance_valid(camera) and camera.is_inside_tree():
		_process_camera(delta)

	# Universal float effect processing
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

	_update_hud()

	# Gravity
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
	if not stunned and not rooted and not grounded and not is_channeling:
		if Input.is_action_just_pressed("jump") and on_floor:
			velocity.y = jump_velocity

	# Movement Vector
	var input_dir := Vector2.ZERO
	if not stunned and not rooted and not is_channeling:
		input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target_dir := Vector3(input_dir.x, 0, input_dir.y).normalized()

	var effective_max_speed = max_move_speed * slow_mult
	if speed_boost_timer > 0.0:
		effective_max_speed *= (1.0 + speed_boost_percent)
	effective_max_speed = get_effective_max_speed(effective_max_speed)

	# Horizontal Velocity Handling
	var current_horizontal = Vector2(velocity.x, velocity.z)
	var speed = current_horizontal.length()

	if on_floor:
		if target_dir != Vector3.ZERO:
			if speed > effective_max_speed:
				current_horizontal = current_horizontal.move_toward(Vector2(target_dir.x, target_dir.z) * effective_max_speed, ground_friction * delta)
			else:
				current_horizontal = current_horizontal.move_toward(Vector2(target_dir.x, target_dir.z) * effective_max_speed, ground_acceleration * delta)
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

	velocity.x = current_horizontal.x + knockback_velocity.x
	velocity.z = current_horizontal.y + knockback_velocity.z

	# Aiming
	if not stunned:
		aim_at_mouse()

	# Delegate Character-specific inputs (LMB, RMB, Q, E, R, SHIFT)
	if not stunned:
		_handle_character_input(delta)

	# Execute Physics Move
	var pre_move_vel = velocity
	move_and_slide()

	# Wall Impact Damage Check
	_check_wall_impact(pre_move_vel)

func _process_camera(delta: float) -> void:
	if not camera:
		return
	camera.global_position = global_position + CAMERA_OFFSET
	camera.look_at(global_position, Vector3.UP)

func _check_wall_impact(pre_move_vel: Vector3) -> void:
	if is_on_wall() and knockback_velocity.length() >= WALL_IMPACT_MIN_SPEED and wall_impact_cooldown_timer <= 0.0:
		for i in range(get_slide_collision_count()):
			var collision = get_slide_collision(i)
			var normal = collision.get_normal()
			var impact_speed = -pre_move_vel.dot(normal)
			if impact_speed >= WALL_IMPACT_MIN_SPEED:
				wall_impact_cooldown_timer = 0.5
				var wall_dmg = impact_speed * WALL_IMPACT_DAMAGE_FACTOR
				apply_stun(1.0)
				knockback_velocity = Vector3.ZERO
				if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
					take_damage(wall_dmg, 0, ActionType.ENVIRONMENT)
				else:
					request_wall_impact_damage.rpc_id(1, wall_dmg)
				break

@rpc("any_peer", "call_remote", "reliable")
func request_wall_impact_damage(amount: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	if str(sender_id) == name:
		take_damage(amount, 0, ActionType.ENVIRONMENT)

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
	if not viewport or not camera:
		return null
	var mouse_pos = viewport.get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	var ground_plane = Plane(Vector3.UP, global_position.y)
	return ground_plane.intersects_ray(ray_origin, ray_dir)

# --- Damage, Shields & Health Management ---
func take_damage(amount: float, attacker_id: int = 0, action_type: int = ActionType.ATTACK) -> void:
	if not multiplayer.is_server() or is_dead:
		return

	if is_ethereal_active():
		return

	# Allow character kits to modify incoming damage (e.g. Deflecting Guard block reduction)
	var final_dmg = modify_incoming_damage(amount, attacker_id, action_type)
	if final_dmg <= 0.0:
		return

	var remaining_dmg = final_dmg
	if current_shield > 0.0:
		var absorbed = min(current_shield, remaining_dmg)
		current_shield -= absorbed
		remaining_dmg -= absorbed
		sync_shield.rpc(current_shield)

	if remaining_dmg > 0.0:
		current_health -= remaining_dmg
		sync_health.rpc(current_health)

	_on_damage_taken_hook(final_dmg, attacker_id, action_type)
	damage_taken.emit(attacker_id, final_dmg, action_type)

	if attacker_id > 0:
		var attacker = get_tree().root.get_node_or_null("Main/Players/" + str(attacker_id))
		if attacker and attacker.has_method("_on_damage_dealt"):
			attacker._on_damage_dealt(self, final_dmg, action_type)

	if current_health <= 0.0:
		die()

func _on_damage_dealt(target: Node, amount: float, action_type: int) -> void:
	damage_dealt.emit(target, amount, action_type)
	_on_character_damage_dealt(target, amount, action_type)

func heal(amount: float) -> void:
	if not multiplayer.is_server() or is_dead:
		return
	current_health = clamp(current_health + amount, 0.0, max_health)
	sync_health.rpc(current_health)

@rpc("authority", "call_local", "reliable")
func sync_health(new_health: float) -> void:
	current_health = new_health
	if current_health <= 0.0 and not is_dead:
		is_dead = true
		_update_death_state(true)

func update_health_bar() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

func die() -> void:
	if is_dead:
		return
	is_dead = true
	cancel_channel()
	cleanse_cc()

	var main_node = get_tree().root.get_node_or_null("Main")
	var in_training = (main_node and main_node.get("is_training_mode") == true)

	if in_training:
		sync_death_state.rpc(true)
		get_tree().create_timer(0.6).timeout.connect(func():
			if is_instance_valid(self):
				respawn()
		)
		return

	sync_death_state.rpc(true)
	if main_node and main_node.has_method("on_player_died"):
		main_node.on_player_died(name.to_int())

@rpc("authority", "call_local", "reliable")
func sync_death_state(dead: bool) -> void:
	is_dead = dead
	_update_death_state(dead)

func _update_death_state(dead: bool) -> void:
	visible = not dead
	set_process_mode(PROCESS_MODE_INHERIT)
	var main_node = get_tree().root.get_node_or_null("Main")
	var in_training = (main_node and main_node.get("is_training_mode") == true)

	if dead:
		velocity = Vector3.ZERO
		knockback_velocity = Vector3.ZERO
		if name.to_int() == multiplayer.get_unique_id():
			if spectator_panel and not in_training:
				spectator_panel.visible = true
	else:
		if name.to_int() == multiplayer.get_unique_id():
			if spectator_panel:
				spectator_panel.visible = false

func respawn() -> void:
	if not multiplayer.is_server() and multiplayer.has_multiplayer_peer():
		return
	is_dead = false
	current_health = max_health
	current_shield = 0.0
	cleanse_cc()
	sync_health.rpc(current_health)
	sync_shield.rpc(current_shield)
	sync_death_state.rpc(false)

	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node and main_node.get("is_training_mode") == true:
		global_position = Vector3(-8.0, 0.1, 0.0)
		velocity = Vector3.ZERO
		knockback_velocity = Vector3.ZERO
		scale = Vector3(0.1, 0.1, 0.1)
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return

	var spawn_points = get_tree().root.get_node_or_null("Main/SpawnPoints")
	if spawn_points and spawn_points.get_child_count() > 0:
		var idx = randi() % spawn_points.get_child_count()
		global_position = spawn_points.get_child(idx).global_position
		velocity = Vector3.ZERO
		knockback_velocity = Vector3.ZERO

# --- Universal Status Effect Appliers ---
func apply_stun(duration: float) -> void:
	if is_cc_immune:
		return
	stun_timer = max(stun_timer, duration)
	cancel_channel()
	sync_status_effect.rpc("stun", duration, 0.0)

func apply_slow(duration: float, percent: float) -> void:
	if is_cc_immune:
		return
	slow_timer = max(slow_timer, duration)
	slow_initial_duration = slow_timer
	slow_initial_percent = max(slow_initial_percent, clamp(percent, 0.0, 0.95))
	slow_percent = slow_initial_percent
	sync_status_effect.rpc("slow", duration, slow_percent)

func apply_silence(duration: float) -> void:
	if is_cc_immune:
		return
	silence_timer = max(silence_timer, duration)
	cancel_channel()
	sync_status_effect.rpc("silence", duration, 0.0)

func apply_root(duration: float) -> void:
	if is_cc_immune:
		return
	root_timer = max(root_timer, duration)
	sync_status_effect.rpc("root", duration, 0.0)

func apply_grounded(duration: float) -> void:
	if is_cc_immune:
		return
	grounded_timer = max(grounded_timer, duration)
	sync_status_effect.rpc("grounded", duration, 0.0)

func apply_cripple(duration: float, intensity: float = 0.35) -> void:
	if is_cc_immune:
		return
	cripple_timer = max(cripple_timer, duration)
	cripple_intensity = intensity
	sync_status_effect.rpc("cripple", duration, intensity)

func apply_ethereal(duration: float) -> void:
	ethereal_timer = max(ethereal_timer, duration)
	sync_status_effect.rpc("ethereal", duration, 0.0)

func apply_speed_boost(duration: float, percent: float) -> void:
	speed_boost_timer = max(speed_boost_timer, duration)
	speed_boost_percent = max(speed_boost_percent, percent)
	sync_status_effect.rpc("speed_boost", duration, percent)

func apply_knockback(impulse_vec: Vector3, is_external: bool = true) -> void:
	if is_cc_immune:
		return
	if is_external:
		knockback_velocity += impulse_vec
	else:
		velocity += impulse_vec

func cleanse_cc() -> void:
	stun_timer = 0.0
	slow_timer = 0.0
	slow_percent = 0.0
	silence_timer = 0.0
	root_timer = 0.0
	grounded_timer = 0.0
	cripple_timer = 0.0

@rpc("authority", "call_local", "reliable")
func sync_status_effect(effect_name: String, duration: float, param: float) -> void:
	match effect_name:
		"stun":
			stun_timer = max(stun_timer, duration)
			cancel_channel()
		"slow":
			slow_timer = max(slow_timer, duration)
			slow_initial_duration = slow_timer
			slow_initial_percent = max(slow_initial_percent, param)
			slow_percent = slow_initial_percent
		"silence":
			silence_timer = max(silence_timer, duration)
			cancel_channel()
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

# --- Universal Float / Levitation ---
func start_float_state() -> void:
	is_floating = true
	float_timer = 0.0
	current_gravity_mult = 1.0
	sync_float_state.rpc(true)

func end_float_state() -> void:
	is_floating = false
	float_timer = 0.0
	current_gravity_mult = 1.0
	sync_float_state.rpc(false)

@rpc("authority", "call_local", "reliable")
func sync_float_state(floating: bool) -> void:
	is_floating = floating
	if not floating:
		float_timer = 0.0
		current_gravity_mult = 1.0

# --- Spectator Processing ---
func _process_spectator(_delta: float) -> void:
	if Input.is_action_just_pressed("spectate_next"):
		_cycle_spectate(1)
	elif Input.is_action_just_pressed("spectate_prev"):
		_cycle_spectate(-1)

	var target_to_watch = spectate_target
	if not target_to_watch or not is_instance_valid(target_to_watch) or target_to_watch.get("is_dead"):
		_cycle_spectate(1)
		target_to_watch = spectate_target

	if target_to_watch and is_instance_valid(target_to_watch) and camera:
		camera.global_position = target_to_watch.global_position + CAMERA_OFFSET
		camera.look_at(target_to_watch.global_position, Vector3.UP)
		if spectator_label:
			spectator_label.text = "SPECTATING: %s (Player %s)\n[LMB / RMB to Cycle]" % [target_to_watch.get("character_name"), target_to_watch.name]
	elif spectator_label:
		spectator_label.text = "SPECTATING: None (All Players Eliminated)\n[LMB / RMB to Cycle]"

func _cycle_spectate(direction: int) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	var alive_players: Array = []
	for child in players_container.get_children():
		if child is Node3D and child.name != name and not child.get("is_dead"):
			alive_players.append(child)
	if alive_players.is_empty():
		spectate_target = null
		return
	spectate_index = (spectate_index + direction) % alive_players.size()
	if spectate_index < 0:
		spectate_index = alive_players.size() - 1
	spectate_target = alive_players[spectate_index]

# --- Universal HUD Updating ---
func _update_hud() -> void:
	if not hud or not hud.visible:
		return

	if status_cc_label:
		var status_text = ""
		if is_stunned():
			status_text = "✦ STUNNED (%.1fs) ✦" % stun_timer
		elif is_silenced():
			status_text = "✦ SILENCED (%.1fs) ✦" % silence_timer
		elif is_rooted():
			status_text = "✦ ROOTED (%.1fs) ✦" % root_timer
		elif is_grounded():
			status_text = "✦ GROUNDED (%.1fs) ✦" % grounded_timer
		elif is_crippled():
			status_text = "✦ CRIPPLED (%.1fs) ✦" % cripple_timer
		elif is_ethereal_active():
			status_text = "✦ ETHEREAL (%.1fs) ✦" % ethereal_timer
		elif is_slowed():
			status_text = "✦ SLOWED -%d%% (%.1fs) ✦" % [int(slow_percent * 100), slow_timer]
		elif speed_boost_timer > 0.0:
			status_text = "⚡ SPEED BOOST +%d%% (%.1fs) ⚡" % [int(speed_boost_percent * 100), speed_boost_timer]
		else:
			# Check character custom status text
			status_text = get_status_text()
		status_cc_label.text = status_text

	_update_character_hud()

# --- Virtual Methods for Character Kit Extension ---
func _setup_character_kit() -> void:
	pass

func _process_character_kit(_delta: float) -> void:
	pass

func _handle_character_input(_delta: float) -> void:
	pass

func _update_character_hud() -> void:
	pass

func get_effective_max_speed(current_speed: float) -> float:
	return current_speed

func get_status_text() -> String:
	return ""

func modify_incoming_damage(amount: float, _attacker_id: int, _action_type: int) -> float:
	return amount

func _on_damage_taken_hook(_amount: float, _attacker_id: int, _action_type: int) -> void:
	pass

func _on_character_damage_dealt(_target: Node, _amount: float, _action_type: int) -> void:
	pass
