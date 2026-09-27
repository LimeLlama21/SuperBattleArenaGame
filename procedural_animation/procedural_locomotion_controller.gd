class_name ProceduralLocomotionController
extends Node3D

## High-performance Procedural Locomotion Controller for Godot 4.
## Can be attached to any CharacterBody3D or used standalone with procedural mannequin.
## Drives gait cycles, balance, secondary dynamics, terrain raycasting, and 2-bone IK.

@export_group("Gait Timing & Dimensions")
@export var walk_cycle_duration: float = 0.65
@export var run_cycle_duration: float = 0.45
@export var stride_length: float = 0.65
@export var step_height: float = 0.16
@export var foot_spacing: float = 0.20
@export var base_hips_height: float = 0.95

@export_group("Pelvis & Spine Dynamics")
@export var pelvis_bob: float = 0.045
@export var pelvis_sway: float = 0.035
@export var pelvis_tilt_deg: float = 4.5
@export var pelvis_yaw_deg: float = 5.0
@export var spine_twist_deg: float = 6.5
@export var spine_lean_deg: float = 5.0
@export var turn_banking_strength: float = 0.35

@export_group("Arms & Head")
@export var arm_swing: float = 0.28
@export var arm_lift: float = 0.06
@export var look_at_target_node: Node3D

@export_group("Spring Physics")
@export var use_springs: bool = true
@export var pelvis_stiffness: float = 130.0
@export var pelvis_damping: float = 14.0

@export_group("Terrain & Foot IK")
@export var enable_terrain_raycast: bool = true
@export var raycast_depth: float = 1.2
@export var foot_alignment_speed: float = 12.0

@export_group("Autonomous Rig Setup")
## If true, automatically generates and attaches a Procedural Mannequin rig at runtime if no rig is assigned.
@export var auto_spawn_mannequin: bool = true

# Internal components
var engine: ProceduralAnimationEngine
var gait_params: ProceduralAnimationEngine.GaitParameters
var rig_refs: ProceduralRigGenerator.BipedRigReferences

# Runtime tracking
var parent_character: CharacterBody3D
var last_position: Vector3 = Vector3.ZERO
var smoothed_velocity: Vector3 = Vector3.ZERO
var elapsed_time: float = 0.0
var landing_dip: float = 0.0
var was_on_floor_last_frame: bool = true


func _ready() -> void:
	engine = ProceduralAnimationEngine.new()
	gait_params = ProceduralAnimationEngine.GaitParameters.new()
	_sync_gait_params()

	# Check parent node
	var p = get_parent()
	if p is CharacterBody3D:
		parent_character = p

	last_position = global_position

	if auto_spawn_mannequin and not rig_refs:
		rig_refs = ProceduralRigGenerator.generate_biped_mannequin(self, "MannequinRig")

	engine.reset(Vector3(0, base_hips_height, 0))


func _sync_gait_params() -> void:
	gait_params.cycle_duration = walk_cycle_duration
	gait_params.stride_length = stride_length
	gait_params.step_height = step_height
	gait_params.foot_spacing = foot_spacing
	gait_params.pelvis_bob = pelvis_bob
	gait_params.pelvis_sway = pelvis_sway
	gait_params.pelvis_tilt_deg = pelvis_tilt_deg
	gait_params.pelvis_yaw_deg = pelvis_yaw_deg
	gait_params.spine_twist_deg = spine_twist_deg
	gait_params.spine_lean_deg = spine_lean_deg
	gait_params.arm_swing = arm_swing
	gait_params.arm_lift = arm_lift
	gait_params.use_springs = use_springs
	gait_params.spring_stiffness = pelvis_stiffness
	gait_params.spring_damping = pelvis_damping


func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return
	elapsed_time += delta

	_sync_gait_params()

	# Calculate current movement velocity
	var current_vel: Vector3
	var is_grounded: bool = true

	if parent_character:
		current_vel = parent_character.velocity
		is_grounded = parent_character.is_on_floor()
	else:
		current_vel = (global_position - last_position) / delta
		last_position = global_position

	# Smooth velocity for organic inertia
	smoothed_velocity = smoothed_velocity.lerp(current_vel, clampf(delta * 12.0, 0.0, 1.0))
	var horizontal_speed: float = Vector2(smoothed_velocity.x, smoothed_velocity.z).length()

	# Dynamic cycle duration between walking and running
	var speed_t: float = clampf(horizontal_speed / 5.0, 0.0, 1.0)
	gait_params.cycle_duration = lerpf(walk_cycle_duration, run_cycle_duration, speed_t)

	# Landing recoil detection
	if not was_on_floor_last_frame and is_grounded:
		# Touchdown impact: induce downward pelvis dip
		landing_dip = clampf(absf(smoothed_velocity.y) * 0.05, 0.05, 0.20)
	landing_dip = move_toward(landing_dip, 0.0, delta * 0.8)
	was_on_floor_last_frame = is_grounded

	var look_target: Vector3 = look_at_target_node.global_position if look_at_target_node else Vector3.ZERO

	# Evaluate full procedural animation pose
	var pose: ProceduralAnimationEngine.ProceduralPose = engine.evaluate(
		elapsed_time,
		delta,
		horizontal_speed,
		4.5,
		gait_params,
		base_hips_height - landing_dip,
		look_target,
		global_transform
	)

	# Apply centrifugal banking into turns
	if horizontal_speed > 0.5:
		var move_dir: Vector3 = smoothed_velocity.normalized()
		var char_fwd: Vector3 = -global_transform.basis.z.normalized()
		var lateral_slip: float = char_fwd.cross(move_dir).y
		var bank_angle: float = clampf(lateral_slip * turn_banking_strength, -deg_to_rad(15.0), deg_to_rad(15.0))
		pose.hips_rotation = pose.hips_rotation.rotated(Vector3.FORWARD, bank_angle)

	# Apply terrain floor raycasting to feet if enabled
	if enable_terrain_raycast and is_inside_tree():
		_adapt_feet_to_terrain(pose)

	# Apply pose to Rig
	_apply_pose_to_rig(pose)


## Projects raycasts downward from foot targets to sample terrain elevation and surface normal.
func _adapt_feet_to_terrain(pose: ProceduralAnimationEngine.ProceduralPose) -> void:
	var space_state = get_world_3d().direct_space_state
	if not space_state:
		return

	# Left Foot raycast
	var origin_l: Vector3 = global_transform * (pose.left_foot_pos + Vector3(0, 0.6, 0))
	var target_l: Vector3 = origin_l + Vector3.DOWN * raycast_depth
	var query_l = PhysicsRayQueryParameters3D.create(origin_l, target_l)
	if parent_character:
		query_l.exclude = [parent_character.get_rid()]

	var hit_l = space_state.intersect_ray(query_l)
	if hit_l:
		var floor_y_l: float = (global_transform.affine_inverse() * hit_l.position).y
		# Only ground during stance or lower portion of swing
		if pose.phase_l >= 0.5 or pose.left_foot_pos.y <= 0.05:
			pose.left_foot_pos.y = floor_y_l
			# Align foot with ground normal
			var normal_l: Vector3 = global_transform.basis.inverse() * hit_l.normal
			var align_basis = _align_up_to_normal(pose.left_foot_rot, normal_l)
			pose.left_foot_rot = align_basis

	# Right Foot raycast
	var origin_r: Vector3 = global_transform * (pose.right_foot_pos + Vector3(0, 0.6, 0))
	var target_r: Vector3 = origin_r + Vector3.DOWN * raycast_depth
	var query_r = PhysicsRayQueryParameters3D.create(origin_r, target_r)
	if parent_character:
		query_r.exclude = [parent_character.get_rid()]

	var hit_r = space_state.intersect_ray(query_r)
	if hit_r:
		var floor_y_r: float = (global_transform.affine_inverse() * hit_r.position).y
		if pose.phase_r >= 0.5 or pose.right_foot_pos.y <= 0.05:
			pose.right_foot_pos.y = floor_y_r
			var normal_r: Vector3 = global_transform.basis.inverse() * hit_r.normal
			var align_basis = _align_up_to_normal(pose.right_foot_rot, normal_r)
			pose.right_foot_rot = align_basis


func _align_up_to_normal(current_basis: Basis, target_normal: Vector3) -> Basis:
	var current_up: Vector3 = current_basis.y
	var axis: Vector3 = current_up.cross(target_normal)
	if axis.length_squared() < 0.0001:
		return current_basis
	var angle: float = current_up.angle_to(target_normal)
	return Basis(axis.normalized(), angle) * current_basis


## Applies evaluated procedural pose data to rig joints and IK target markers.
func _apply_pose_to_rig(pose: ProceduralAnimationEngine.ProceduralPose) -> void:
	if not rig_refs:
		return

	# Pelvis / Hips
	if rig_refs.hips:
		rig_refs.hips.position = pose.hips_position
		rig_refs.hips.transform.basis = pose.hips_rotation

	# Chest / Spine
	if rig_refs.chest:
		rig_refs.chest.transform.basis = pose.chest_rotation

	# Head
	if rig_refs.head:
		rig_refs.head.transform.basis = pose.head_rotation

	# Foot Targets
	if rig_refs.foot_target_l:
		rig_refs.foot_target_l.position = pose.left_foot_pos
		rig_refs.foot_target_l.transform.basis = pose.left_foot_rot
	if rig_refs.foot_target_r:
		rig_refs.foot_target_r.position = pose.right_foot_pos
		rig_refs.foot_target_r.transform.basis = pose.right_foot_rot

	# Knee Poles
	if rig_refs.knee_pole_l:
		rig_refs.knee_pole_l.position = pose.left_knee_pole
	if rig_refs.knee_pole_r:
		rig_refs.knee_pole_r.position = pose.right_knee_pole

	# Hand Targets
	if rig_refs.hand_target_l:
		rig_refs.hand_target_l.position = pose.left_hand_pos
	if rig_refs.hand_target_r:
		rig_refs.hand_target_r.position = pose.right_hand_pos

	# Elbow Poles
	if rig_refs.elbow_pole_l:
		rig_refs.elbow_pole_l.position = pose.left_elbow_pole
	if rig_refs.elbow_pole_r:
		rig_refs.elbow_pole_r.position = pose.right_elbow_pole

	# Execute Two-Bone IK solvers for limbs
	if rig_refs.leg_ik_l:
		rig_refs.leg_ik_l.solve_and_apply()
	if rig_refs.leg_ik_r:
		rig_refs.leg_ik_r.solve_and_apply()
	if rig_refs.arm_ik_l:
		rig_refs.arm_ik_l.solve_and_apply()
	if rig_refs.arm_ik_r:
		rig_refs.arm_ik_r.solve_and_apply()
