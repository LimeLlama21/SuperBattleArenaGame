class_name BattleRoyaleZone
extends Node3D

## Signals for state transitions, movement, and damage events
signal state_changed(old_state: int, new_state: int)
signal timer_updated(time_remaining: float, total_duration: float)
signal next_zone_chosen(target_position: Vector3, distance_from_last: float)
signal movement_started(from_pos: Vector3, to_pos: Vector3, duration: float)
signal movement_progress(progress_normalized: float)
signal movement_completed(final_position: Vector3)
signal player_damaged_by_zone(player: Node, damage: float)

## State Machine Definition
enum State {
	INACTIVE = 0,
	WAITING = 1,
	WARNING = 2,
	MOVING = 3
}

# --- Zone Geometry & Fixed Size ---
@export_group("Zone Size & Shape")
## The radius of the safe zone ring. Remains constant (never shrinks).
@export var zone_radius: float = 35.0:
	set(value):
		zone_radius = max(5.0, value)
		_update_geometry()
## Visual height of the cylindrical storm barrier wall.
@export var zone_height: float = 60.0:
	set(value):
		zone_height = max(10.0, value)
		_update_geometry()

# --- State Machine Timings ---
@export_group("Timings & State Machine")
## Initial stationary wait duration before first relocation (e.g. 1 minute to start).
@export var initial_wait_time: float = 60.0
## Stationary wait duration between relocations.
@export var wait_time: float = 60.0
## Duration of the warning alert before movement begins.
@export var warning_time: float = 12.0
## Movement duration in seconds. Should move fairly slowly, not taking more than a few minutes.
@export var move_duration: float = 75.0
## Whether to compute movement duration dynamically based on travel distance.
@export var use_dynamic_duration: bool = true
## Speed in units per second if using dynamic duration.
@export var move_speed: float = 0.8
## Minimum allowed move duration in seconds.
@export var min_move_duration: float = 45.0
## Maximum allowed move duration in seconds (capped so it never takes more than a few minutes).
@export var max_move_duration: float = 150.0

# --- Movement & Relocation Constraints ---
@export_group("Relocation Constraints")
## Minimum distance the next zone center must be from the current center.
@export var min_relocation_distance: float = 40.0
## Maximum distance the next zone center can be from the current center.
@export var max_relocation_distance: float = 100.0
## Playable map boundaries (XZ plane min / max) for safe zone relocation.
@export var map_bounds_min: Vector2 = Vector2(-80.0, -80.0)
@export var map_bounds_max: Vector2 = Vector2(80.0, 80.0)
## Automatically attempt to fit boundaries to current active map.
@export var auto_detect_bounds: bool = true

# --- Damage Over Time (DoT) Outside Ring ---
@export_group("Damage Over Time")
## Damage dealt per second to players outside the safe zone.
@export var damage_per_second: float = 10.0
## Interval between damage ticks in seconds.
@export var tick_interval: float = 0.5
## Optional damage scaling multiplier per relocation cycle.
@export var damage_escalation_per_cycle: float = 0.0

# --- Game Mode Restrictions ---
@export_group("Game Mode Restrictions")
## Whether this safe zone is restricted exclusively to the main game mode ("tdm")
@export var only_active_in_main_mode: bool = true
## Canonical ID of the main game mode
@export var main_game_mode_id: String = "tdm"

# --- State Machine Runtime Variables ---
var current_state: State = State.WAITING
var state_timer: float = 48.0
var state_duration: float = 48.0
var relocation_cycle_count: int = 0
var is_first_cycle: bool = true

func _init() -> void:
	current_state = State.WAITING
	state_duration = max(1.0, initial_wait_time - warning_time)
	state_timer = state_duration
	target_position = _calculate_next_zone_position()

# --- Positions ---
var current_center: Vector3 = Vector3.ZERO
var start_position: Vector3 = Vector3.ZERO
var target_position: Vector3 = Vector3.ZERO

# --- Internal Timers & Cache ---
var damage_tick_timer: float = 0.0
var network_sync_timer: float = 0.0
const NETWORK_SYNC_INTERVAL: float = 0.25

# --- Child Nodes & Visual References ---
@onready var wall_mesh: MeshInstance3D = get_node_or_null("WallMesh")
@onready var ground_ring: MeshInstance3D = get_node_or_null("GroundRing")
@onready var telegraph_marker: Node3D = get_node_or_null("TelegraphMarker")
@onready var telegraph_ring: MeshInstance3D = get_node_or_null("TelegraphMarker/TelegraphRing")
@onready var guide_line: MeshInstance3D = get_node_or_null("GuideLine")
@onready var hud_layer: CanvasLayer = get_node_or_null("HUDLayer")
@onready var hud_warning_label: Label = get_node_or_null("HUDLayer/WarningContainer/WarningLabel")
@onready var hud_timer_label: Label = get_node_or_null("HUDLayer/StatusContainer/TimerLabel")
@onready var hud_arrow: Control = get_node_or_null("HUDLayer/WarningContainer/ArrowIndicator")

# Materials
var wall_material: ShaderMaterial
var ground_ring_material: StandardMaterial3D
var telegraph_material: StandardMaterial3D

func get_zone_position() -> Vector3:
	return global_position if is_inside_tree() else position

func set_zone_position(pos: Vector3) -> void:
	if is_inside_tree():
		global_position = pos
	else:
		position = pos

## Check whether the current game mode is the main game mode ("tdm")
func is_main_mode_active() -> bool:
	if not only_active_in_main_mode:
		return true
	var main_node: Node = null
	if is_inside_tree() and get_tree() and get_tree().root:
		main_node = get_tree().root.get_node_or_null("Main")
	if not main_node:
		var curr = get_parent()
		while curr:
			if curr.name == "Main" or curr.get("game_mode") != null or curr.has_meta("game_mode"):
				main_node = curr
				break
			curr = curr.get_parent()
	if not main_node:
		return true
	
	var is_training = main_node.get("is_training_mode")
	if is_training == null and main_node.has_meta("is_training_mode"):
		is_training = main_node.get_meta("is_training_mode")
	if is_training == true:
		return false
		
	var current_mode = main_node.get("game_mode")
	if current_mode == null and main_node.has_meta("game_mode"):
		current_mode = main_node.get_meta("game_mode")
	if current_mode == null:
		return true
	return str(current_mode) == main_game_mode_id

## Deactivate the zone completely (hidden, no damage ticks, inactive state)
func deactivate_zone() -> void:
	change_state(State.INACTIVE)
	visible = false
	set_process(false)
	set_physics_process(false)
	if telegraph_marker:
		telegraph_marker.visible = false
	if guide_line:
		guide_line.visible = false
	if hud_layer:
		hud_layer.visible = false

## Activate and start the zone for the main game mode
func activate_zone() -> void:
	visible = true
	set_process(true)
	set_physics_process(true)
	if hud_layer:
		hud_layer.visible = true
	if is_server_authority():
		start_zone()

## Re-evaluate activity state based on current game mode
func evaluate_mode_activity() -> void:
	if not only_active_in_main_mode:
		activate_zone()
		return
	if is_main_mode_active():
		activate_zone()
	else:
		deactivate_zone()

func _ready() -> void:
	current_center = get_zone_position()
	start_position = get_zone_position()
	target_position = get_zone_position()
	
	_setup_visual_components()
	_update_geometry()
	
	if auto_detect_bounds:
		_detect_arena_bounds()
	
	add_to_group("battle_royale_zone")
	
	if only_active_in_main_mode and not is_main_mode_active():
		deactivate_zone()
		return
	
	# Start zone automatically if ready in server or singleplayer
	if is_server_authority():
		start_zone()

func is_server_authority() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()

## Setup procedural meshes and shaders if not loaded from scene
func _setup_visual_components() -> void:
	# Ensure TelegraphMarker is detached from zone hierarchy position so it stays fixed in world space
	if telegraph_marker:
		telegraph_marker.top_level = true
		telegraph_marker.visible = false
	if guide_line:
		guide_line.top_level = true
		guide_line.visible = false

	# Setup shader for barrier wall
	if wall_mesh and wall_mesh.get_active_material(0) is ShaderMaterial:
		wall_material = wall_mesh.get_active_material(0)
	elif wall_mesh:
		var shader_res = load("res://zones/battle_royale_zone.gdshader")
		if shader_res:
			wall_material = ShaderMaterial.new()
			wall_material.shader = shader_res
			wall_mesh.set_surface_override_material(0, wall_material)

	if ground_ring and ground_ring.get_active_material(0) is StandardMaterial3D:
		ground_ring_material = ground_ring.get_active_material(0)

	if telegraph_ring and telegraph_ring.get_active_material(0) is StandardMaterial3D:
		telegraph_material = telegraph_ring.get_active_material(0)

## Update geometry dimensions for cylinder barrier and perimeter ring
func _update_geometry() -> void:
	if wall_mesh:
		var cyl: CylinderMesh
		if wall_mesh.mesh is CylinderMesh:
			cyl = wall_mesh.mesh
		else:
			cyl = CylinderMesh.new()
			wall_mesh.mesh = cyl
		cyl.top_radius = zone_radius
		cyl.bottom_radius = zone_radius
		cyl.height = zone_height
		cyl.rings = 1
		cyl.radial_segments = 64
		cyl.cap_top = false
		cyl.cap_bottom = false
		wall_mesh.position.y = zone_height * 0.5 - 2.0

	if ground_ring:
		var torus: TorusMesh
		if ground_ring.mesh is TorusMesh:
			torus = ground_ring.mesh
		else:
			torus = TorusMesh.new()
			ground_ring.mesh = torus
		torus.outer_radius = zone_radius + 0.35
		torus.inner_radius = zone_radius - 0.35
		torus.rings = 64
		torus.ring_segments = 8
		ground_ring.position.y = 0.15

	if telegraph_ring:
		var t_torus: TorusMesh
		if telegraph_ring.mesh is TorusMesh:
			t_torus = telegraph_ring.mesh
		else:
			t_torus = TorusMesh.new()
			telegraph_ring.mesh = t_torus
		t_torus.outer_radius = zone_radius + 0.3
		t_torus.inner_radius = zone_radius - 0.3
		t_torus.rings = 64
		t_torus.ring_segments = 8
		telegraph_ring.position.y = 0.15

## Automatically adjust map bounds based on active map
func _detect_arena_bounds() -> void:
	var main_node = get_tree().root.get_node_or_null("Main")
	if not main_node:
		return
	var arena_node = main_node.get_node_or_null("Arena")
	if not arena_node:
		return
	
	# Check if any active map is visible
	for child in arena_node.get_children():
		if child is Node3D and child.visible:
			var m_name = child.name.to_lower()
			if "expanse" in m_name:
				map_bounds_min = Vector2(-95.0, -95.0)
				map_bounds_max = Vector2(95.0, 95.0)
				min_relocation_distance = 55.0
				max_relocation_distance = 125.0
			elif "chasm" in m_name:
				map_bounds_min = Vector2(-60.0, -60.0)
				map_bounds_max = Vector2(60.0, 60.0)
				min_relocation_distance = 40.0
				max_relocation_distance = 85.0
			elif "colosseum" in m_name:
				map_bounds_min = Vector2(-30.0, -30.0)
				map_bounds_max = Vector2(30.0, 30.0)
				min_relocation_distance = 25.0
				max_relocation_distance = 45.0
			break

# ==============================================================================
# STATE MACHINE IMPLEMENTATION
# ==============================================================================

## Start the battle royale zone state machine
func start_zone() -> void:
	is_first_cycle = true
	relocation_cycle_count = 0
	current_center = get_zone_position()
	start_position = get_zone_position()
	target_position = get_zone_position()
	change_state(State.WAITING)

## Transition to a new state with explicit exit/enter handlers
func change_state(new_state: State) -> void:
	if current_state == new_state and new_state != State.INACTIVE:
		return
		
	var old_state = current_state
	_exit_state(old_state)
	current_state = new_state
	_enter_state(new_state)
	
	state_changed.emit(old_state, new_state)
	
	if is_server_authority() and is_multiplayer_match():
		sync_zone_state.rpc(
			int(current_state),
			get_zone_position(),
			target_position,
			state_timer,
			state_duration
		)

func _enter_state(state: State) -> void:
	match state:
		State.INACTIVE:
			state_timer = 0.0
			state_duration = 0.0
			if telegraph_marker:
				telegraph_marker.visible = false
			if guide_line:
				guide_line.visible = false
			_set_visual_warning(0.0)

		State.WAITING:
			# Stationary phase: wait initial_wait_time on start, otherwise wait_time
			var duration = initial_wait_time if is_first_cycle else wait_time
			# Deduct warning_time so WARNING state acts as the final countdown phase
			var wait_duration = max(1.0, duration - warning_time)
			state_duration = wait_duration
			state_timer = wait_duration
			is_first_cycle = false
			
			current_center = get_zone_position()
			start_position = get_zone_position()
			
			if is_server_authority():
				target_position = _calculate_next_zone_position()
				next_zone_chosen.emit(target_position, current_center.distance_to(target_position))
			
			_update_telegraph_visuals(true)
			_set_visual_warning(0.0)

		State.WARNING:
			# Warning phase: zone is about to relocate, sirens/pulsing telegraph
			state_duration = warning_time
			state_timer = warning_time
			_set_visual_warning(0.7)
			_update_telegraph_visuals(true)

		State.MOVING:
			# Moving phase: zone translates from start_position to target_position
			start_position = get_zone_position()
			var travel_dist = start_position.distance_to(target_position)
			
			if use_dynamic_duration and move_speed > 0.0:
				var calc_dur = travel_dist / move_speed
				state_duration = clamp(calc_dur, min_move_duration, max_move_duration)
			else:
				state_duration = clamp(move_duration, min_move_duration, max_move_duration)
				
			state_timer = state_duration
			relocation_cycle_count += 1
			
			movement_started.emit(start_position, target_position, state_duration)
			_set_visual_warning(1.0)
			_update_telegraph_visuals(true)

func _exit_state(state: State) -> void:
	match state:
		State.MOVING:
			# Snap to exact destination upon completing movement
			set_zone_position(target_position)
			current_center = target_position
			movement_completed.emit(get_zone_position())
		State.WARNING:
			pass
		State.WAITING:
			pass
		State.INACTIVE:
			pass

## Main physics process: updates state machine timers, interpolation, and damage
func _physics_process(delta: float) -> void:
	if current_state == State.INACTIVE:
		_update_hud_display(delta)
		return

	_update_state(delta)
	
	if is_server_authority():
		_process_damage_ticks(delta)
		_process_network_sync(delta)
		
	_update_hud_display(delta)

## State machine tick logic
func _update_state(delta: float) -> void:
	if state_timer > 0.0:
		state_timer -= delta
		timer_updated.emit(max(0.0, state_timer), state_duration)
		
	match current_state:
		State.WAITING:
			if is_server_authority() and state_timer <= 0.0:
				change_state(State.WARNING)

		State.WARNING:
			# Pulse telegraph marker
			if telegraph_ring:
				var pulse = 0.8 + 0.3 * sin(Time.get_ticks_msec() * 0.008)
				telegraph_ring.scale = Vector3(pulse, 1.0, pulse)
				
			if is_server_authority() and state_timer <= 0.0:
				change_state(State.MOVING)

		State.MOVING:
			var progress = 1.0 - clamp(state_timer / max(0.001, state_duration), 0.0, 1.0)
			movement_progress.emit(progress)
			
			# Smooth cubic S-curve easing for graceful acceleration and deceleration
			var eased_t = smoothstep(0.0, 1.0, progress)
			set_zone_position(start_position.lerp(target_position, eased_t))
			current_center = get_zone_position()
			
			# Update guide line between current zone and destination
			_update_guide_line()
			
			if is_server_authority() and state_timer <= 0.0:
				change_state(State.WAITING)

# ==============================================================================
# MINIMUM DISTANCE RELOCATION ALGORITHM
# ==============================================================================

## Calculate the next zone location ensuring the minimum distance constraint is strictly met
func _calculate_next_zone_position() -> Vector3:
	var current_xz = Vector2(current_center.x, current_center.z)
	var bounds_min = map_bounds_min
	var bounds_max = map_bounds_max
	
	# Effective boundary with margin so the safe zone circle stays comfortably playable
	var margin = zone_radius * 0.4
	var effective_min = bounds_min + Vector2(margin, margin)
	var effective_max = bounds_max - Vector2(margin, margin)
	
	if effective_min.x >= effective_max.x or effective_min.y >= effective_max.y:
		effective_min = bounds_min
		effective_max = bounds_max

	var best_candidate = Vector3.ZERO
	var best_distance = -1.0
	var found = false

	# Attempt random sampling within [min_relocation_distance, max_relocation_distance]
	for attempt in range(80):
		var angle = randf() * TAU
		var dist = randf_range(min_relocation_distance, max_relocation_distance)
		var candidate_xz = current_xz + Vector2(cos(angle), sin(angle)) * dist
		
		# Verify bounds
		if candidate_xz.x >= effective_min.x and candidate_xz.x <= effective_max.x \
		   and candidate_xz.y >= effective_min.y and candidate_xz.y <= effective_max.y:
			var actual_dist = candidate_xz.distance_to(current_xz)
			if actual_dist >= min_relocation_distance:
				best_candidate = Vector3(candidate_xz.x, current_center.y, candidate_xz.y)
				found = true
				break
				
		# Keep track of furthest candidate inside bounds as fallback
		var clamped_xz = Vector2(
			clamp(candidate_xz.x, effective_min.x, effective_max.x),
			clamp(candidate_xz.y, effective_min.y, effective_max.y)
		)
		var c_dist = clamped_xz.distance_to(current_xz)
		if c_dist > best_distance:
			best_distance = c_dist
			best_candidate = Vector3(clamped_xz.x, current_center.y, clamped_xz.y)

	# If random ray casting did not immediately find a point meeting min_distance,
	# pick the perimeter opposite to current position to guarantee max relocation distance
	if not found and best_distance < min_relocation_distance:
		var center_to_mid = Vector2.ZERO - current_xz
		var fallback_dir = center_to_mid.normalized() if center_to_mid.length_squared() > 1.0 else Vector2(1, 0).rotated(randf() * TAU)
		var fallback_xz = current_xz + fallback_dir * min_relocation_distance
		fallback_xz.x = clamp(fallback_xz.x, effective_min.x, effective_max.x)
		fallback_xz.y = clamp(fallback_xz.y, effective_min.y, effective_max.y)
		best_candidate = Vector3(fallback_xz.x, current_center.y, fallback_xz.y)

	return best_candidate

# ==============================================================================
# DAMAGE OVER TIME (DOT) OUTSIDE THE RING
# ==============================================================================

## Process periodic damage to all living players outside the safe ring
func _process_damage_ticks(delta: float) -> void:
	damage_tick_timer += delta
	if damage_tick_timer < tick_interval:
		return
	damage_tick_timer = 0.0

	var effective_dps = damage_per_second + (relocation_cycle_count * damage_escalation_per_cycle)
	var tick_damage = effective_dps * tick_interval
	if tick_damage <= 0.0:
		return

	var players_container: Node = null
	if is_inside_tree() and get_tree() and get_tree().root:
		players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container and get_parent():
		players_container = get_parent().get_node_or_null("Players")
		if not players_container and get_parent().name == "Main":
			players_container = get_parent().get_node_or_null("Players")
	if not players_container:
		return

	var my_pos = get_zone_position()
	for player in players_container.get_children():
		if not is_instance_valid(player) or player.get("is_dead") == true:
			continue
		
		# Compute horizontal distance from the safe ring center (XZ plane)
		var p_pos = player.global_position if player.is_inside_tree() else player.position
		var dist_xz = Vector2(p_pos.x - my_pos.x, p_pos.z - my_pos.z).length()
		
		# Being outside the ring makes you take damage over time
		if dist_xz > zone_radius:
			if player.has_method("take_damage"):
				player.take_damage(tick_damage, 0, BasePlayer.ActionType.ENVIRONMENT)
				player_damaged_by_zone.emit(player, tick_damage)

# ==============================================================================
# VISUALS & TELEGRAPH INDICATORS
# ==============================================================================

func _update_telegraph_visuals(visible: bool) -> void:
	if telegraph_marker:
		telegraph_marker.visible = visible and (current_state != State.INACTIVE)
		telegraph_marker.global_position = target_position
		telegraph_marker.scale = Vector3.ONE

	if guide_line:
		guide_line.visible = visible and (current_state == State.MOVING or current_state == State.WARNING)
		_update_guide_line()

func _update_guide_line() -> void:
	if not guide_line or not guide_line.visible:
		return
	var from = global_position
	var to = target_position
	var diff = to - from
	var dist = diff.length()
	
	if dist < 0.5:
		guide_line.visible = false
		return
		
	guide_line.visible = true
	var mid = from + diff * 0.5
	guide_line.global_position = Vector3(mid.x, 0.2, mid.z)
	guide_line.look_at(Vector3(to.x, 0.2, to.z), Vector3.UP)
	guide_line.scale = Vector3(0.5, 1.0, dist)

func _set_visual_warning(intensity: float) -> void:
	if wall_material:
		wall_material.set_shader_parameter("warning_intensity", intensity)
	if ground_ring_material:
		var col = Color(0.1, 0.85, 1.0, 1.0).lerp(Color(1.0, 0.3, 0.1, 1.0), intensity)
		ground_ring_material.albedo_color = col
		ground_ring_material.emission = col

# ==============================================================================
# HUD & LOCAL PLAYER FEEDBACK
# ==============================================================================

func _update_hud_display(_delta: float) -> void:
	if not hud_layer:
		return
		
	var local_player = _get_local_player()
	if not local_player:
		if hud_warning_label:
			hud_warning_label.get_parent().visible = false
		return

	var p_pos = local_player.global_position
	var dist_to_center = Vector2(p_pos.x - global_position.x, p_pos.z - global_position.z).length()
	var is_outside = dist_to_center > zone_radius
	var dist_outside = dist_to_center - zone_radius

	# Update Outside Zone Hazard Warning
	if hud_warning_label:
		var warn_container = hud_warning_label.get_parent()
		warn_container.visible = is_outside and current_state != State.INACTIVE
		if is_outside:
			hud_warning_label.text = "⚠️ OUTSIDE SAFE ZONE: TAKING DAMAGE (-%d HP/s) ⚠️\nReturn to ring (%.1fm)" % [
				int(round(damage_per_second + (relocation_cycle_count * damage_escalation_per_cycle))),
				dist_outside
			]
			# Pulse red text
			var alpha = 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.01)
			hud_warning_label.modulate = Color(1.0, 0.25, 0.25, alpha)

	# Update Navigation Arrow pointing toward zone center
	if hud_arrow and is_outside:
		var camera = get_viewport().get_camera_3d()
		if camera:
			var dir_3d = (global_position - p_pos).normalized()
			var cam_forward = -camera.global_transform.basis.z
			var cam_right = camera.global_transform.basis.x
			var local_dir = Vector2(dir_3d.dot(cam_right), -dir_3d.dot(cam_forward)).normalized()
			hud_arrow.rotation = local_dir.angle() + PI * 0.5

	# Update Top Status Bar
	if hud_timer_label:
		hud_timer_label.visible = current_state != State.INACTIVE
		var mins = int(state_timer) / 60
		var secs = int(state_timer) % 60
		var time_str = "%02d:%02d" % [mins, secs]
		
		match current_state:
			State.WAITING:
				hud_timer_label.text = "SAFE ZONE WAITING: %s" % time_str
				hud_timer_label.modulate = Color(0.4, 0.85, 1.0, 1.0)
			State.WARNING:
				hud_timer_label.text = "⚠️ ZONE RELOCATING IN: %s ⚠️" % time_str
				hud_timer_label.modulate = Color(1.0, 0.5, 0.15, 1.0)
			State.MOVING:
				hud_timer_label.text = "🌀 ZONE MOVING TO NEW LOCATION: %s" % time_str
				hud_timer_label.modulate = Color(1.0, 0.85, 0.2, 1.0)

func _get_local_player() -> Node3D:
	var main_node = get_tree().root.get_node_or_null("Main")
	if not main_node:
		return null
	var my_id = multiplayer.get_unique_id() if (multiplayer and multiplayer.has_multiplayer_peer()) else 1
	var players = main_node.get_node_or_null("Players")
	if not players:
		return null
	var p = players.get_node_or_null(str(my_id))
	if p:
		return p
	# Fallback to first player
	for child in players.get_children():
		if child is Node3D and not child.name.begins_with("Training"):
			return child
	return null

# ==============================================================================
# MULTIPLAYER SYNCHRONIZATION
# ==============================================================================

func is_multiplayer_match() -> bool:
	return multiplayer and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0

func _process_network_sync(delta: float) -> void:
	if not is_multiplayer_match():
		return
	network_sync_timer += delta
	if network_sync_timer >= NETWORK_SYNC_INTERVAL:
		network_sync_timer = 0.0
		sync_zone_state.rpc(
			int(current_state),
			global_position,
			target_position,
			state_timer,
			state_duration
		)

@rpc("authority", "call_remote", "unreliable")
func sync_zone_state(synced_state: int, current_pos: Vector3, target_pos: Vector3, timer: float, duration: float) -> void:
	if is_server_authority():
		return
	if current_state != synced_state:
		current_state = synced_state as State
		_enter_state(current_state)
	
	global_position = current_pos
	current_center = current_pos
	target_position = target_pos
	state_timer = timer
	state_duration = duration
	_update_telegraph_visuals(true)
