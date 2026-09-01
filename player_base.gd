class_name BasePlayer
extends PlayerVision

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
@export var team_id: int = 1:
	set(value):
		team_id = value
		_update_team_visuals()

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
@onready var shield_bar: ProgressBar = get_node_or_null("HealthBarViewport/ShieldProgressBar")

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


var active_windup_id: String = "":
	set(value):
		active_windup_id = value
		if active_windup_id != "":
			_on_windup_id_changed(active_windup_id)

var active_windup_facing: Vector3 = Vector3.FORWARD

func _enter_tree() -> void:
	_setup_synchronizer()

func _ready() -> void:
	_setup_synchronizer()

	var is_local = is_local_player()
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

	_setup_health_bars()
	if sprite_3d and has_node("HealthBarViewport"):
		sprite_3d.texture = $HealthBarViewport.get_texture()
	update_health_bar()
	_update_team_visuals()
	call_deferred("_update_team_visuals")

	# Call character-specific kit setup
	_setup_character_kit()

func _setup_synchronizer() -> void:
	if not is_multiplayer_match():
		return
	var sync = get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	if not sync:
		sync = MultiplayerSynchronizer.new()
		sync.name = "MultiplayerSynchronizer"
		add_child(sync)

	var peer_id = name.to_int()
	if peer_id > 0:
		set_multiplayer_authority(peer_id)
		sync.set_multiplayer_authority(peer_id)

	var config = sync.replication_config
	if not config:
		config = SceneReplicationConfig.new()
		sync.replication_config = config

	_add_sync_property(config, NodePath(".:position"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	_add_sync_property(config, NodePath(".:rotation"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	_add_sync_property(config, NodePath(".:team_id"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, NodePath(".:current_health"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, NodePath(".:current_shield"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, NodePath(".:is_dead"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, NodePath(".:active_windup_id"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, NodePath(".:active_windup_facing"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)

func _add_sync_property(config: SceneReplicationConfig, prop_path: NodePath, mode: int) -> void:
	if not config.has_property(prop_path):
		config.add_property(prop_path)
		config.property_set_replication_mode(prop_path, mode)

func set_team_id(new_team: int) -> void:
	team_id = new_team
	_refresh_all_team_visuals()

func is_enemy(other: Node) -> bool:
	if not other or other == self:
		return false
	if other.name == name:
		return false
	if other.get("team_id") != null:
		return other.team_id != team_id
	return true

func set_opponent_visible(is_vis: bool) -> void:
	if is_local_player():
		visible = not is_dead
		return
	if is_dead:
		visible = false
		return
	visible = is_vis
	if sprite_3d:
		sprite_3d.visible = is_vis

func get_local_player_team() -> int:
	var local_id = get_my_player_id()
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
	
	# Determine if this player is on the same team as the local player
	var local_id = get_my_player_id()
	var local_team = get_local_player_team()
	var is_same_team = (team_id == local_team) or (name == str(local_id))
	
	# Same team is always blue, enemy team is always red
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

	# Update Health Bar fill color: Blue for same team, Red for enemy team
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

func start_channel(duration: float, on_complete: Callable) -> void:
	is_channeling = true
	channel_timer = duration
	channel_complete_callback = on_complete

func cancel_channel() -> void:
	is_channeling = false
	channel_timer = 0.0
	channel_complete_callback = Callable()

func apply_shield(amount: float, duration: float = 5.0) -> void:
	if is_multiplayer_match() and not multiplayer.is_server():
		return
	current_shield = min(max_shield, current_shield + amount)
	shield_timer = max(shield_timer, duration)
	if is_multiplayer_match() and multiplayer.is_server():
		sync_shield.rpc(current_shield)

@rpc("any_peer", "call_local", "reliable")
func sync_shield(new_shield: float) -> void:
	current_shield = new_shield

func _physics_process(delta: float) -> void:
	# Deadzone / Void Check
	if is_server_authoritative() and not is_dead and global_position.y < VOID_DEATH_Y:
		die()

	# Shield timer decrement
	if shield_timer > 0.0:
		shield_timer -= delta
		if shield_timer <= 0.0:
			current_shield = 0.0
			if is_multiplayer_match() and is_server_authoritative():
				sync_shield.rpc(0.0)

	# Channeling process
	if is_channeling:
		channel_timer -= delta
		if channel_timer <= 0.0:
			is_channeling = false
			if channel_complete_callback.is_valid():
				var cb = channel_complete_callback
				channel_complete_callback = Callable()
				cb.call()

	# Base physics timers decrement (CC, float, wall impact cooldown)
	_process_physics_timers(delta)

	# Process Character-specific kit logic (both server and clients)
	_process_character_kit(delta)

	var is_local = is_local_player()
	var is_server_or_offline = multiplayer.is_server() if (multiplayer and multiplayer.has_multiplayer_peer()) else true
	var is_server_dummy = (name.to_int() == 0 and is_server_or_offline)

	if not is_local and not is_server_dummy:
		return

	if is_server_dummy:
		_process_dummy_physics(delta)
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

	_update_hud()

	# Aiming
	if not is_stunned():
		aim_at_mouse()

	# Delegate Character-specific inputs (LMB, RMB, Q, E, R, SHIFT)
	if not is_stunned():
		_handle_character_input(delta)

	# Execute Physics Move & Slide via PlayerPhysics
	_process_player_movement_physics(delta, is_channeling)

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
			if normal.y > 0.7:
				continue
			var impact_speed = -pre_move_vel.dot(normal)
			if impact_speed >= WALL_IMPACT_MIN_SPEED:
				wall_impact_cooldown_timer = 0.5
				var wall_dmg = impact_speed * WALL_IMPACT_DAMAGE_FACTOR
				if knockback_wall_stun > 0.0:
					apply_stun(knockback_wall_stun)
				knockback_velocity = Vector3.ZERO
				knockback_wall_stun = 0.0
				velocity = Vector3.ZERO
				if is_server_authoritative():
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

# --- Damage, Shields & Health Management ---
func take_damage(amount: float, attacker_id: int = 0, action_type: int = ActionType.ATTACK) -> void:
	if is_multiplayer_match() and not multiplayer.is_server():
		return
	if is_dead:
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
		if is_multiplayer_match() and multiplayer.is_server():
			sync_shield.rpc(current_shield)

	if remaining_dmg > 0.0:
		current_health -= remaining_dmg
		if is_multiplayer_match() and multiplayer.is_server():
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
	if (is_multiplayer_match() and not multiplayer.is_server()) or is_dead:
		return
	current_health = clamp(current_health + amount, 0.0, max_health)
	if is_multiplayer_match() and multiplayer.is_server():
		sync_health.rpc(current_health)

@rpc("any_peer", "call_local", "reliable")
func sync_health(new_health: float) -> void:
	current_health = new_health
	if current_health <= 0.0 and not is_dead:
		is_dead = true
		_update_death_state(true)

func _setup_health_bars() -> void:
	var vp = get_node_or_null("HealthBarViewport")
	if not vp:
		return
	
	var vp_size = vp.size if vp.size != Vector2i.ZERO else Vector2i(220, 28)
	var sz = Vector2(vp_size.x, vp_size.y)
	
	var bg_sb = StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.12, 0.12, 0.12, 0.85)
	bg_sb.corner_radius_top_left = 4
	bg_sb.corner_radius_top_right = 4
	bg_sb.corner_radius_bottom_right = 4
	bg_sb.corner_radius_bottom_left = 4

	var gray_fill_sb = StyleBoxFlat.new()
	gray_fill_sb.bg_color = Color(0.35, 0.37, 0.40, 0.95)
	gray_fill_sb.corner_radius_top_left = 4
	gray_fill_sb.corner_radius_top_right = 4
	gray_fill_sb.corner_radius_bottom_right = 4
	gray_fill_sb.corner_radius_bottom_left = 4

	var shield_fill_sb = StyleBoxFlat.new()
	shield_fill_sb.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	shield_fill_sb.corner_radius_top_left = 4
	shield_fill_sb.corner_radius_top_right = 4
	shield_fill_sb.corner_radius_bottom_right = 4
	shield_fill_sb.corner_radius_bottom_left = 4

	# 1. Gray Health Progress Bar (Layer 0 - Bottom)
	gray_health_bar = vp.get_node_or_null("GrayProgressBar") as ProgressBar
	if not gray_health_bar:
		gray_health_bar = ProgressBar.new()
		gray_health_bar.name = "GrayProgressBar"
		vp.add_child(gray_health_bar)
	
	gray_health_bar.custom_minimum_size = sz
	gray_health_bar.size = sz
	gray_health_bar.position = Vector2.ZERO
	gray_health_bar.show_percentage = false
	gray_health_bar.add_theme_stylebox_override("background", bg_sb)
	gray_health_bar.add_theme_stylebox_override("fill", gray_fill_sb)
	vp.move_child(gray_health_bar, 0)

	# 2. Shield Progress Bar (Layer 1 - Middle)
	shield_bar = vp.get_node_or_null("ShieldProgressBar") as ProgressBar
	if not shield_bar:
		shield_bar = ProgressBar.new()
		shield_bar.name = "ShieldProgressBar"
		vp.add_child(shield_bar)
	
	shield_bar.custom_minimum_size = sz
	shield_bar.size = sz
	shield_bar.position = Vector2.ZERO
	shield_bar.show_percentage = false
	shield_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	shield_bar.add_theme_stylebox_override("fill", shield_fill_sb)
	vp.move_child(shield_bar, 1)

	# 3. Main Health Progress Bar (Layer 2 - Top)
	health_bar = vp.get_node_or_null("ProgressBar") as ProgressBar
	if not health_bar:
		health_bar = ProgressBar.new()
		health_bar.name = "ProgressBar"
		vp.add_child(health_bar)
	
	health_bar.custom_minimum_size = sz
	health_bar.size = sz
	health_bar.position = Vector2.ZERO
	health_bar.show_percentage = false
	health_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	vp.move_child(health_bar, 2)

func update_health_bar() -> void:
	var gh: float = 0.0
	if "gray_health" in self:
		gh = self.get("gray_health")
	
	var total_display_max = max(max_health, current_health + current_shield + gh)
	
	if gray_health_bar:
		gray_health_bar.max_value = total_display_max
		gray_health_bar.value = current_health + current_shield + gh
	
	if shield_bar:
		shield_bar.max_value = total_display_max
		shield_bar.value = current_health + current_shield
	
	if health_bar:
		health_bar.max_value = total_display_max
		health_bar.value = current_health

func die() -> void:
	if is_dead:
		return
	is_dead = true
	cancel_channel()
	cleanse_cc()

	var main_node = get_tree().current_scene if get_tree() else null
	if not main_node or not main_node.has_method("on_player_died"):
		main_node = get_tree().root.get_node_or_null("Main")

	var in_training = (main_node and main_node.get("is_training_mode") == true) or not is_multiplayer_match()

	if in_training:
		_update_death_state(true)
		get_tree().create_timer(0.6).timeout.connect(func():
			if is_instance_valid(self):
				respawn()
		)
		return

	if is_multiplayer_match():
		sync_death_state.rpc(true)
	else:
		_update_death_state(true)

	if main_node and main_node.has_method("on_player_died"):
		main_node.on_player_died(name.to_int())

@rpc("any_peer", "call_local", "reliable")
func sync_death_state(dead: bool) -> void:
	is_dead = dead
	_update_death_state(dead)

func _update_death_state(dead: bool) -> void:
	visible = not dead
	set_process_mode(PROCESS_MODE_INHERIT)
	var main_node = get_tree().root.get_node_or_null("Main")
	var in_training = (main_node and main_node.get("is_training_mode") == true) or not is_multiplayer_match()

	if dead:
		velocity = Vector3.ZERO
		knockback_velocity = Vector3.ZERO
		knockback_wall_stun = 0.0
		if is_local_player() or name == "1":
			if spectator_panel and not in_training:
				spectator_panel.visible = true
	else:
		if is_local_player() or name == "1":
			if spectator_panel:
				spectator_panel.visible = false

func respawn() -> void:
	if is_multiplayer_match() and not multiplayer.is_server():
		return

	var spawn_pos = Vector3(-8.0, 0.1, 0.0)
	var main_node = get_tree().root.get_node_or_null("Main")
	var in_training = (main_node and main_node.get("is_training_mode") == true) or not is_multiplayer_match()

	if not in_training:
		var spawn_points = get_tree().root.get_node_or_null("Main/SpawnPoints")
		if spawn_points and spawn_points.get_child_count() > 0:
			var idx = randi() % spawn_points.get_child_count()
			spawn_pos = spawn_points.get_child(idx).global_position

	if is_multiplayer_match() and multiplayer.is_server():
		sync_respawn.rpc(spawn_pos)
	else:
		sync_respawn(spawn_pos)

@rpc("any_peer", "call_local", "reliable")
func sync_respawn(spawn_pos: Vector3) -> void:
	is_dead = false
	current_health = max_health
	current_shield = 0.0
	cleanse_cc()
	global_position = spawn_pos
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	knockback_wall_stun = 0.0
	_update_death_state(false)
	
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node and main_node.get("is_training_mode") == true and (is_local_player() or name == "1"):
		scale = Vector3(0.1, 0.1, 0.1)
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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

# --- Systemic Ability Hitbox & Delayed Telegraph Pipeline ---
func show_ability_telegraph(ability_def: RefCounted, origin: Vector3, facing_dir: Vector3, delay: float) -> Node3D:
	if not ability_def or not ability_def.has_hitbox():
		return null
	var ind = AbilityIndicator.create_from_hitbox(ability_def.hitbox)
	if not ind:
		return null
	
	var follows_caster = false
	if ability_def.effect and "follow_caster" in ability_def.effect and ability_def.effect.follow_caster:
		follows_caster = true

	if follows_caster:
		ind.top_level = false
		add_child(ind)
		ind.position = Vector3.ZERO
		ind.rotation = Vector3.ZERO
	else:
		ind.top_level = true
		get_tree().root.add_child(ind)
		ind.global_position = origin
		if facing_dir.length_squared() > 0.001:
			var target = origin + facing_dir
			ind.look_at(Vector3(target.x, origin.y, target.z), Vector3.UP)
			ind.rotation.x = 0.0
			ind.rotation.z = 0.0
	
	ind.show()
	
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(func():
			if is_instance_valid(ind):
				AbilityIndicator.flash_and_fade(ind, get_tree(), 0.15)
				get_tree().create_timer(0.20).timeout.connect(func():
					if is_instance_valid(ind):
						ind.queue_free()
				)
		)
	else:
		AbilityIndicator.flash_and_fade(ind, get_tree(), 0.15)
		get_tree().create_timer(0.20).timeout.connect(func():
			if is_instance_valid(ind):
				ind.queue_free()
		)
	return ind

func start_ability_windup(ability_id: String, facing_dir: Vector3 = Vector3.ZERO) -> void:
	var ability_def = null
	if "abilities" in self and self.abilities is Dictionary:
		ability_def = self.abilities.get(ability_id)
	if ability_def and ability_def.effect and ability_def.effect.windup_time > 0.0:
		active_windup_facing = facing_dir if facing_dir != Vector3.ZERO else -global_transform.basis.z.normalized()
		active_windup_id = ability_id
		# Also broadcast fallback RPC for peers connecting mid-frame or custom net setups
		sync_ability_windup.rpc(ability_id, global_position, active_windup_facing, ability_def.effect.windup_time)

func _on_windup_id_changed(ability_id: String) -> void:
	var ability_def = null
	if "abilities" in self and self.abilities is Dictionary:
		ability_def = self.abilities.get(ability_id)
	if ability_def and ability_def.has_hitbox():
		var delay = ability_def.effect.windup_time if (ability_def.effect and ability_def.effect.windup_time > 0.0) else 0.0
		if delay > 0.0:
			show_ability_telegraph(ability_def, global_position, active_windup_facing, delay)
			if is_multiplayer_authority():
				get_tree().create_timer(delay).timeout.connect(func():
					if active_windup_id == ability_id:
						active_windup_id = ""
				)

@rpc("any_peer", "call_local", "reliable")
func sync_ability_windup(ability_id: String, origin: Vector3, facing: Vector3, delay: float) -> void:
	if delay <= 0.0:
		return
	# If synchronizer already created the telegraph, avoid duplicate display
	if active_windup_id == ability_id and is_multiplayer_authority():
		return
	var ability_def = null
	if "abilities" in self and self.abilities is Dictionary:
		ability_def = self.abilities.get(ability_id)
	if ability_def:
		show_ability_telegraph(ability_def, origin, facing, delay)

func trigger_ability_hitbox(ability_key_or_id: String, origin: Vector3 = Vector3.ZERO, facing_dir: Vector3 = Vector3.ZERO) -> void:
	var ability_def = null
	if "abilities" in self and self.abilities is Dictionary:
		ability_def = self.abilities.get(ability_key_or_id)
	if not ability_def or not ability_def.has_hitbox():
		return
	
	var cast_origin = origin if origin != Vector3.ZERO else global_position
	var cast_facing = facing_dir if facing_dir != Vector3.ZERO else -global_transform.basis.z.normalized()
	cast_facing.y = 0.0
	if cast_facing.length_squared() > 0.001:
		cast_facing = cast_facing.normalized()
	else:
		cast_facing = -global_transform.basis.z.normalized()
	
	show_ability_telegraph(ability_def, cast_origin, cast_facing, 0.0)
	if is_multiplayer_match() and (is_multiplayer_authority() or multiplayer.is_server()):
		sync_trigger_hitbox.rpc(ability_key_or_id, cast_origin, cast_facing)

@rpc("any_peer", "call_remote", "reliable")
func sync_trigger_hitbox(ability_key_or_id: String, origin: Vector3, facing: Vector3) -> void:
	var ability_def = null
	if "abilities" in self and self.abilities is Dictionary:
		ability_def = self.abilities.get(ability_key_or_id)
	if ability_def and ability_def.has_hitbox():
		show_ability_telegraph(ability_def, origin, facing, 0.0)
