class_name BasePlayer
extends CharacterBody3D

@export var character_name: String = "Hunter"
@export var max_health: float = 100.0
@export var current_health: float = 100.0:
	set(value):
		current_health = clamp(value, 0.0, max_health)
		update_health_bar()

# Movement Parameters
@export var max_move_speed: float = 10.0
@export var ground_acceleration: float = 65.0
@export var ground_friction: float = 40.0
@export var air_acceleration: float = 25.0
@export var air_drag: float = 3.5
@export var jump_velocity: float = 9.5

# Combat & Ability Cooldowns
@export var is_melee_character: bool = false
@export var dash_impulse: float = 26.0
@export var dash_cooldown: float = 4.0
@export var attack_cooldown: float = 0.3
@export var melee_windup_time: float = 0.28
@export var melee_damage: float = 55.0
@export var melee_range: float = 4.2
@export var melee_angle_deg: float = 120.0
@export var projectile_damage: float = 22.0
@export var projectile_speed: float = 34.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 24.0)
var dash_timer: float = 0.0
var attack_timer: float = 0.0
var is_casting_melee: bool = false
var is_dead: bool = false

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
@onready var hud: CanvasLayer = $PlayerHUD
@onready var dash_cd_label: Label = $PlayerHUD/VBox/DashCD
@onready var attack_cd_label: Label = $PlayerHUD/VBox/AttackCD
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
	
	sprite_3d.texture = $HealthBarViewport.get_texture()
	update_health_bar()
	if melee_visual:
		melee_visual.visible = false
	if spectator_panel:
		spectator_panel.hide()

func _physics_process(delta: float) -> void:
	# Deadzone / Void Check
	if multiplayer.is_server() and not is_dead and global_position.y < VOID_DEATH_Y:
		die()

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

	if dash_timer > 0.0:
		dash_timer -= delta
	if attack_timer > 0.0:
		attack_timer -= delta
		
	_update_hud()

	var on_floor = is_on_floor()
	if not on_floor:
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and on_floor:
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target_dir := Vector3(input_dir.x, 0, input_dir.y).normalized()

	# Dash
	if Input.is_action_just_pressed("dash") and dash_timer <= 0.0:
		dash_timer = dash_cooldown
		var dash_dir = target_dir if target_dir != Vector3.ZERO else -global_transform.basis.z.normalized()
		velocity.x = dash_dir.x * dash_impulse
		velocity.z = dash_dir.z * dash_impulse

	# Momentum
	var current_horizontal = Vector2(velocity.x, velocity.z)
	var speed = current_horizontal.length()

	if on_floor:
		if target_dir != Vector3.ZERO:
			if speed > max_move_speed:
				current_horizontal = current_horizontal.move_toward(Vector2(target_dir.x, target_dir.z) * max_move_speed, ground_friction * delta)
			else:
				current_horizontal = current_horizontal.move_toward(Vector2(target_dir.x, target_dir.z) * max_move_speed, ground_acceleration * delta)
		else:
			current_horizontal = current_horizontal.move_toward(Vector2.ZERO, ground_friction * delta)
	else:
		if target_dir != Vector3.ZERO:
			if speed > max_move_speed:
				current_horizontal = current_horizontal.move_toward(Vector2(target_dir.x, target_dir.z) * speed, air_acceleration * 0.5 * delta)
				current_horizontal = current_horizontal.move_toward(Vector2.ZERO, air_drag * delta)
			else:
				current_horizontal = current_horizontal.move_toward(Vector2(target_dir.x, target_dir.z) * max_move_speed, air_acceleration * delta)
		else:
			current_horizontal = current_horizontal.move_toward(Vector2.ZERO, air_drag * delta)

	velocity.x = current_horizontal.x
	velocity.z = current_horizontal.y

	aim_at_mouse()

	# Primary Attack
	if Input.is_action_pressed("shoot") and attack_timer <= 0.0 and not is_casting_melee:
		if is_melee_character:
			_perform_crush_melee_windup()
		else:
			_perform_poke_ranged_attack()

	move_and_slide()

func _update_hud() -> void:
	if dash_cd_label:
		if dash_timer > 0.0:
			dash_cd_label.text = "Dash [Shift]: %.1fs" % dash_timer
			dash_cd_label.modulate = Color(1, 0.5, 0.5)
		else:
			dash_cd_label.text = "Dash [Shift]: READY"
			dash_cd_label.modulate = Color(0.4, 1, 0.4)
			
	if attack_cd_label:
		if attack_timer > 0.0:
			attack_cd_label.text = "Attack [LMB]: %.1fs" % attack_timer
		elif is_casting_melee:
			attack_cd_label.text = "Attack [LMB]: STRIKING..."
			attack_cd_label.modulate = Color(1, 0.8, 0.2)
		else:
			attack_cd_label.text = "Attack [LMB]: READY"
			attack_cd_label.modulate = Color(0.4, 1, 0.4)

func _perform_poke_ranged_attack() -> void:
	attack_timer = attack_cooldown
	var facing_dir = -global_transform.basis.z.normalized()
	var spawn_pos = global_position + Vector3(0, 0.8, 0) + facing_dir * 1.1
	
	if multiplayer.is_server():
		get_tree().root.get_node("Main").spawn_projectile(spawn_pos, facing_dir, 1, projectile_damage, projectile_speed)
	else:
		request_fire.rpc_id(1, spawn_pos, facing_dir, projectile_damage, projectile_speed)

func _perform_crush_melee_windup() -> void:
	is_casting_melee = true
	attack_timer = attack_cooldown + melee_windup_time
	
	show_melee_effect.rpc(true)
	await get_tree().create_timer(melee_windup_time).timeout
	is_casting_melee = false
	show_melee_effect.rpc(false)
	
	var facing_dir = -global_transform.basis.z.normalized()
	if multiplayer.is_server():
		execute_melee_hit_on_server(global_position, facing_dir, 1)
	else:
		request_melee_strike.rpc_id(1, global_position, facing_dir)

@rpc("any_peer", "call_local", "reliable")
func show_melee_effect(active: bool) -> void:
	if melee_visual:
		melee_visual.visible = active

@rpc("any_peer", "call_remote", "reliable")
func request_melee_strike(origin_pos: Vector3, forward_dir: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	execute_melee_hit_on_server(origin_pos, forward_dir, sender_id)

func execute_melee_hit_on_server(origin_pos: Vector3, forward_dir: Vector3, attacker_id: int) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	
	var fwd_2d = Vector2(forward_dir.x, forward_dir.z).normalized()
	
	for player in players_container.get_children():
		if player.name != str(attacker_id) and player.has_method("take_damage") and not player.get("is_dead"):
			var diff = player.global_position - origin_pos
			var diff_2d = Vector2(diff.x, diff.z)
			var dist = diff_2d.length()
			
			if abs(diff.y) <= 3.0 and dist <= melee_range:
				var to_target_2d = diff_2d.normalized()
				var angle = rad_to_deg(fwd_2d.angle_to(to_target_2d))
				if abs(angle) <= (melee_angle_deg * 0.5):
					player.take_damage(melee_damage)

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
func request_fire(spawn_pos: Vector3, shoot_dir: Vector3, dmg: float, spd: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	get_tree().root.get_node("Main").spawn_projectile(spawn_pos, shoot_dir, sender_id, dmg, spd)

func take_damage(amount: float) -> void:
	if not multiplayer.is_server() or is_dead:
		return
	
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
