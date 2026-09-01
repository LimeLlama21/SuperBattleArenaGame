extends CharacterBody3D

@export var max_health: float = 100.0
@export var team_id: int = 1:
	set(value):
		team_id = value
		_update_team_visuals()
@export var current_health: float = 100.0:
	set(value):
		current_health = clamp(value, 0.0, max_health)
		update_health_bar()

# Base Movement Parameters
@export var max_move_speed: float = 10.0
@export var ground_acceleration: float = 65.0
@export var ground_friction: float = 40.0
@export var air_acceleration: float = 25.0
@export var air_drag: float = 3.5  # Low drag preserves high dash momentum in mid-air

# Jump & Dash Parameters
@export var jump_velocity: float = 9.5
@export var dash_impulse: float = 26.0
@export var dash_cooldown: float = 0.75
@export var shoot_cooldown: float = 0.25
@export var projectile_damage: float = 50.0
@export var projectile_speed: float = 70.0
@export var projectile_size: float = 1.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 24.0)

var dash_timer: float = 0.0
var shoot_timer: float = 0.0

const CAMERA_OFFSET: Vector3 = Vector3(0, 17, 9.5)

@onready var camera: Camera3D = $Camera3D
@onready var synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var health_bar: ProgressBar = $HealthBarViewport/ProgressBar
@onready var sprite_3d: Sprite3D = $HealthBarSprite

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

	var my_id = multiplayer.get_unique_id() if (multiplayer and multiplayer.has_multiplayer_peer()) else 1
	var is_local = (name.to_int() == my_id or name == "1")
	camera.current = is_local
	if is_local:
		camera.top_level = true
		camera.global_position = global_position + CAMERA_OFFSET
		camera.look_at(global_position, Vector3.UP)
	
	sprite_3d.texture = $HealthBarViewport.get_texture()
	update_health_bar()
	_update_team_visuals()
	call_deferred("_update_team_visuals")

func _physics_process(delta: float) -> void:
	var my_id = multiplayer.get_unique_id() if (multiplayer and multiplayer.has_multiplayer_peer()) else 1
	if name.to_int() != my_id and name != "1":
		return

	if not DisplayServer.window_is_focused():
		return

	if camera:
		camera.global_position = global_position + CAMERA_OFFSET

	# Timers
	if dash_timer > 0.0:
		dash_timer -= delta
	if shoot_timer > 0.0:
		shoot_timer -= delta

	# 1. Gravity
	var on_floor = is_on_floor()
	if not on_floor:
		velocity.y -= gravity * delta

	# 2. Jump
	if Input.is_action_just_pressed("jump") and on_floor:
		velocity.y = jump_velocity

	# 3. Horizontal Input Vector
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target_dir := Vector3(input_dir.x, 0, input_dir.y).normalized()

	# 4. Dash Impulse Injection (Momentum-based)
	if Input.is_action_just_pressed("dash") and dash_timer <= 0.0:
		dash_timer = dash_cooldown
		var dash_dir = target_dir if target_dir != Vector3.ZERO else -global_transform.basis.z.normalized()
		
		# Set immediate high horizontal momentum along dash direction
		velocity.x = dash_dir.x * dash_impulse
		velocity.z = dash_dir.z * dash_impulse

	# 5. Physics Momentum & Friction / Drag
	var current_horizontal = Vector2(velocity.x, velocity.z)
	var speed = current_horizontal.length()

	if on_floor:
		if target_dir != Vector3.ZERO:
			# If above max_move_speed (from a dash), apply ground friction back down to max speed
			if speed > max_move_speed:
				current_horizontal = current_horizontal.move_toward(Vector2(target_dir.x, target_dir.z) * max_move_speed, ground_friction * delta)
			else:
				# Normal ground acceleration
				current_horizontal = current_horizontal.move_toward(Vector2(target_dir.x, target_dir.z) * max_move_speed, ground_acceleration * delta)
		else:
			# Decelerate to 0 when no input on ground
			current_horizontal = current_horizontal.move_toward(Vector2.ZERO, ground_friction * delta)
	else:
		# In air: Minimal drag preserves dash speed much longer
		if target_dir != Vector3.ZERO:
			if speed > max_move_speed:
				# Gently steer momentum without dropping dash speed immediately
				current_horizontal = current_horizontal.move_toward(Vector2(target_dir.x, target_dir.z) * speed, air_acceleration * 0.5 * delta)
				current_horizontal = current_horizontal.move_toward(Vector2.ZERO, air_drag * delta)
			else:
				current_horizontal = current_horizontal.move_toward(Vector2(target_dir.x, target_dir.z) * max_move_speed, air_acceleration * delta)
		else:
			current_horizontal = current_horizontal.move_toward(Vector2.ZERO, air_drag * delta)

	velocity.x = current_horizontal.x
	velocity.z = current_horizontal.y

	# 6. Aiming at Mouse (Dynamically aligned at current player height)
	aim_at_mouse()

	# 7. Shooting
	if Input.is_action_pressed("shoot") and shoot_timer <= 0.0:
		shoot_timer = shoot_cooldown
		var facing_dir = -global_transform.basis.z.normalized()
		facing_dir.y = 0.0
		facing_dir = facing_dir.normalized()
		var spawn_pos = global_position + Vector3(0, 0.8, 0) + facing_dir * 1.0
		var shoot_dir = get_ranged_aim_direction(spawn_pos)
		
		if multiplayer.is_server():
			get_tree().root.get_node("Main").spawn_projectile(spawn_pos, shoot_dir, 1, projectile_damage, projectile_speed, projectile_size)
		else:
			request_fire.rpc_id(1, spawn_pos, shoot_dir, projectile_damage, projectile_speed, projectile_size)

	move_and_slide()

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

func get_ranged_aim_direction(spawn_pos: Vector3) -> Vector3:
	var default_fwd = -global_transform.basis.z.normalized()
	default_fwd.y = 0.0
	if default_fwd.length_squared() < 0.0001:
		default_fwd = Vector3.FORWARD
	default_fwd = default_fwd.normalized()
	
	var viewport = get_viewport()
	if not viewport or not camera:
		return default_fwd
	
	var mouse_pos = viewport.get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	var space_state = get_world_3d().direct_space_state
	
	# Raycast against characters (Collision layer 2: players / dummies)
	var player_query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 300.0, 2)
	player_query.collide_with_areas = false
	player_query.collide_with_bodies = true
	player_query.exclude = [get_rid()]
	var player_result = space_state.intersect_ray(player_query)
	
	if not player_result.is_empty():
		var hit_collider = player_result.collider
		if hit_collider != self and hit_collider is CharacterBody3D and not hit_collider.get("is_dead"):
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
			if p != self and p is CharacterBody3D and not p.get("is_dead"):
				var t_pos = p.global_position + Vector3(0, 0.85, 0)
				if not camera.is_position_behind(t_pos):
					var screen_pos = camera.unproject_position(t_pos)
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

@rpc("any_peer", "call_remote", "reliable")
func request_fire(spawn_pos: Vector3, shoot_dir: Vector3, dmg: float, spd: float, p_size: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	get_tree().root.get_node("Main").spawn_projectile(spawn_pos, shoot_dir, sender_id, dmg, spd, p_size)

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

func get_local_player_team() -> int:
	var local_id = multiplayer.get_unique_id() if (multiplayer and multiplayer.has_multiplayer_peer()) else 1
	var main_node = get_tree().root.get_node_or_null("Main") if get_tree() else null
	if main_node and main_node.has_method("get_player_team"):
		return main_node.get_player_team(local_id)
	var local_player = get_tree().root.get_node_or_null("Main/Players/" + str(local_id)) if get_tree() else null
	if local_player and local_player.get("team_id") != null:
		return local_player.team_id
	if name == str(local_id):
		return team_id
	return 1

func _refresh_all_team_visuals() -> void:
	_update_team_visuals()
	var players_cont = get_tree().root.get_node_or_null("Main/Players") if get_tree() else null
	if players_cont:
		for p in players_cont.get_children():
			if p.has_method("_update_team_visuals"):
				p._update_team_visuals()

func _update_team_visuals() -> void:
	var mesh_inst: MeshInstance3D = get_node_or_null("MeshInstance3D")
	var local_id = multiplayer.get_unique_id() if (multiplayer and multiplayer.has_multiplayer_peer()) else 1
	var local_team = get_local_player_team()
	var is_same_team = (team_id == local_team) or (name == str(local_id))
	var model_color = Color(0.18, 0.58, 1.0, 1.0) if is_same_team else Color(0.95, 0.20, 0.20, 1.0)
	var emissive_color = Color(0.08, 0.25, 0.5, 1.0) if is_same_team else Color(0.45, 0.08, 0.08, 1.0)

	if mesh_inst:
		var mat = mesh_inst.material_override as StandardMaterial3D
		if not mat:
			mat = StandardMaterial3D.new()
		else:
			mat = mat.duplicate() as StandardMaterial3D
		mat.albedo_color = model_color
		mat.roughness = 0.35
		mat.metallic = 0.2
		mat.emission_enabled = true
		mat.emission = emissive_color
		mat.emission_energy_multiplier = 0.3
		mesh_inst.material_override = mat

	if health_bar:
		var fill_sb = health_bar.get_theme_stylebox("fill")
		if fill_sb:
			fill_sb = fill_sb.duplicate()
		else:
			fill_sb = StyleBoxFlat.new()
			fill_sb.corner_radius_top_left = 4
			fill_sb.corner_radius_top_right = 4
			fill_sb.corner_radius_bottom_right = 4
			fill_sb.corner_radius_bottom_left = 4
		if fill_sb is StyleBoxFlat:
			fill_sb.bg_color = Color(0.18, 0.65, 1.0, 1.0) if is_same_team else Color(1.0, 0.25, 0.25, 1.0)
			health_bar.add_theme_stylebox_override("fill", fill_sb)
