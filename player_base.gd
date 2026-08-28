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
@export var dash_cooldown: float = 4.0   # 4.0s for Poke, 8.0s for Crush
@export var attack_cooldown: float = 0.3
@export var melee_windup_time: float = 0.28
@export var melee_damage: float = 55.0
@export var melee_range: float = 3.2
@export var melee_angle_deg: float = 90.0
@export var projectile_damage: float = 22.0
@export var projectile_speed: float = 34.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 24.0)
var dash_timer: float = 0.0
var attack_timer: float = 0.0
var is_casting_melee: bool = false

const CAMERA_OFFSET: Vector3 = Vector3(0, 17, 9.5)

@onready var camera: Camera3D = $Camera3D
@onready var synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var health_bar: ProgressBar = $HealthBarViewport/ProgressBar
@onready var sprite_3d: Sprite3D = $HealthBarSprite
@onready var melee_visual: Node3D = get_node_or_null("MeleeVisual")
@onready var hud: CanvasLayer = $PlayerHUD
@onready var dash_cd_label: Label = $PlayerHUD/VBox/DashCD
@onready var attack_cd_label: Label = $PlayerHUD/VBox/AttackCD

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
	camera.current = is_local
	hud.visible = is_local
	
	if is_local:
		camera.top_level = true
		camera.global_position = global_position + CAMERA_OFFSET
		camera.look_at(global_position, Vector3.UP)
	
	sprite_3d.texture = $HealthBarViewport.get_texture()
	update_health_bar()
	if melee_visual:
		melee_visual.visible = false

func _physics_process(delta: float) -> void:
	if name.to_int() != multiplayer.get_unique_id():
		return

	if not DisplayServer.window_is_focused():
		return

	if camera:
		camera.global_position = global_position + CAMERA_OFFSET

	# Cooldown handling
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

	# Dash with explicit cooldown
	if Input.is_action_just_pressed("dash") and dash_timer <= 0.0:
		dash_timer = dash_cooldown
		var dash_dir = target_dir if target_dir != Vector3.ZERO else -global_transform.basis.z.normalized()
		velocity.x = dash_dir.x * dash_impulse
		velocity.z = dash_dir.z * dash_impulse

	# Momentum calculations
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

	# Primary Attack Trigger
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
	
	# Show windup / swing telegraph
	show_melee_effect.rpc(true)
	
	# Wait for cast delay (0.28s)
	await get_tree().create_timer(melee_windup_time).timeout
	
	is_casting_melee = false
	show_melee_effect.rpc(false)
	
	# Request server to execute authoritative area strike
	if multiplayer.is_server():
		execute_melee_hit_on_server(global_position, -global_transform.basis.z.normalized(), 1)
	else:
		request_melee_strike.rpc_id(1, global_position, -global_transform.basis.z.normalized())

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
	
	for player in players_container.get_children():
		if player.name != str(attacker_id) and player.has_method("take_damage"):
			var diff = player.global_position - origin_pos
			var dist = diff.length()
			if dist <= melee_range:
				var to_target_dir = diff.normalized()
				var angle = rad_to_deg(forward_dir.angle_to(to_target_dir))
				# Check cone angle (front arc)
				if angle <= (melee_angle_deg * 0.5):
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
	if not multiplayer.is_server():
		return
	
	current_health -= amount
	sync_health.rpc(current_health)
	
	if current_health <= 0.0:
		respawn()

@rpc("authority", "call_local", "reliable")
func sync_health(new_health: float) -> void:
	current_health = new_health

func respawn() -> void:
	current_health = max_health
	sync_health.rpc(current_health)
	
	var spawn_points = get_tree().root.get_node_or_null("Main/SpawnPoints")
	if spawn_points and spawn_points.get_child_count() > 0:
		var idx = randi() % spawn_points.get_child_count()
		global_position = spawn_points.get_child(idx).global_position
		velocity = Vector3.ZERO

func update_health_bar() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
