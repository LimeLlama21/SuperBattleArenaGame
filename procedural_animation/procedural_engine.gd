class_name ProceduralAnimationEngine
extends RefCounted

## Procedural Locomotion & Dynamics Engine in GDScript.
## Computes full-body biomechanical kinematics:
## - Alternating gait cycle with stance & swing phases
## - Parabolic foot clearance and dynamic foot pitch (heel-strike to toe-off)
## - Pelvic vertical bobbing, lateral sway, hip drop roll, and pelvic yaw
## - Biomechanical spine counter-rotation and forward velocity lean
## - Contralateral arm swing coordination with apex clearance
## - Head stabilization and look-at target aiming
## - 2nd-order damped harmonic oscillators for organic inertia and follow-through

# ==============================================================================
# PARAMETERS & GAIT PROFILE
# ==============================================================================

class GaitParameters extends RefCounted:
	var cycle_duration: float = 0.65       # Duration of one full left+right stride cycle in seconds
	var stride_length: float = 0.60        # Forward/backward stride distance
	var step_height: float = 0.16          # Vertical clearance apex during swing
	var foot_spacing: float = 0.22         # Half-width distance between feet (X axis)
	var pelvis_bob: float = 0.045          # Vertical hip bob amplitude (Y axis)
	var pelvis_sway: float = 0.035         # Lateral hip sway amplitude (X axis)
	var pelvis_tilt_deg: float = 4.5       # Hip drop / roll amplitude in degrees
	var pelvis_yaw_deg: float = 5.0        # Hip rotation into step in degrees
	var spine_twist_deg: float = 6.5       # Torso counter-rotation amplitude in degrees
	var spine_lean_deg: float = 4.0        # Torso forward pitch lean at speed
	var arm_swing: float = 0.28            # Forward/backward arm swing distance
	var arm_lift: float = 0.06             # Vertical lift of hands at swing apex
	var use_springs: bool = true           # Enable 2nd-order spring-mass-damper physics
	var spring_stiffness: float = 130.0    # Spring stiffness for pelvis inertia
	var spring_damping: float = 14.0       # Spring damping ratio

# ==============================================================================
# POSE OUTPUT DATA STRUCTURE
# ==============================================================================

class ProceduralPose extends RefCounted:
	# Pelvis / Hips
	var hips_position: Vector3 = Vector3.ZERO
	var hips_rotation: Basis = Basis.IDENTITY

	# Chest / Spine
	var chest_position: Vector3 = Vector3.ZERO
	var chest_rotation: Basis = Basis.IDENTITY

	# Head
	var head_position: Vector3 = Vector3.ZERO
	var head_rotation: Basis = Basis.IDENTITY

	# Foot IK Targets (relative to character root origin)
	var left_foot_pos: Vector3 = Vector3.ZERO
	var left_foot_rot: Basis = Basis.IDENTITY
	var right_foot_pos: Vector3 = Vector3.ZERO
	var right_foot_rot: Basis = Basis.IDENTITY

	# Knee Pole Hints (forward bend direction)
	var left_knee_pole: Vector3 = Vector3.FORWARD
	var right_knee_pole: Vector3 = Vector3.FORWARD

	# Hand IK Targets (relative to character root origin)
	var left_hand_pos: Vector3 = Vector3.ZERO
	var right_hand_pos: Vector3 = Vector3.ZERO

	# Elbow Pole Hints (backward bend direction)
	var left_elbow_pole: Vector3 = Vector3.BACK
	var right_elbow_pole: Vector3 = Vector3.BACK

	# Gait metrics
	var phase_l: float = 0.0
	var phase_r: float = 0.0
	var is_moving: bool = false
	var speed_ratio: float = 0.0

# ==============================================================================
# INTERNAL ENGINE STATE
# ==============================================================================

var pelvis_spring: ProceduralAnimMath.SpringDamper3D
var head_spring: ProceduralAnimMath.SpringDamper3D
var lean_spring: ProceduralAnimMath.SpringDamper1D
var last_time: float = -1.0
var accumulated_phase: float = 0.0


func _init() -> void:
	pelvis_spring = ProceduralAnimMath.SpringDamper3D.new(130.0, 14.0, 1.0)
	head_spring = ProceduralAnimMath.SpringDamper3D.new(100.0, 12.0, 0.6)
	lean_spring = ProceduralAnimMath.SpringDamper1D.new(80.0, 10.0, 1.0)


func reset(initial_hips_pos: Vector3 = Vector3(0, 0.95, 0)) -> void:
	pelvis_spring.reset(initial_hips_pos)
	head_spring.reset(Vector3(0, 1.65, 0))
	lean_spring.reset(0.0)
	last_time = -1.0
	accumulated_phase = 0.0


# ==============================================================================
# FOOT TRAJECTORY SOLVER
# ==============================================================================

## Computes the 3D position and rotation of a foot for gait phase [0.0, 1.0).
## Godot 3D Coordinate System:
## - -Z is Forward, +Z is Backward
## - +Y is Up
## - +X is Right
## phase:
## - [0.0, 0.5): Swing phase (foot lifts, travels forward along -Z, heel strikes)
## - [0.5, 1.0): Stance phase (foot planted, travels backward along +Z relative to pelvis)
func compute_foot_ik(
	phase: float,
	stride_length: float,
	step_height: float,
	lateral_offset: float,
	rest_y: float = 0.0
) -> Dictionary:
	var pos: Vector3 = Vector3(lateral_offset, rest_y, 0.0)
	var rot_euler: Vector3 = Vector3.ZERO
	var half_stride: float = stride_length * 0.5

	if phase < 0.5:
		# --- SWING PHASE ---
		var swing_p: float = phase / 0.5  # [0.0, 1.0]

		# Horizontal travel: from rear (+half_stride) to forward (-half_stride)
		var t: float = ProceduralAnimMath.smooth_step(swing_p)
		pos.z = half_stride - (stride_length * t)

		# Parabolic vertical foot clearance arc
		pos.y += ProceduralAnimMath.parabolic_lift(swing_p, step_height)

		# Foot pitch rotation (pitch around X axis):
		# - Push-off: toe down (-pitch)
		# - Mid-swing: toe up / dorsiflexion (+pitch)
		# - Heel-strike: heel lands first (+pitch)
		var pitch_curve: float = sin((swing_p - 0.2) * TAU) * deg_to_rad(15.0)
		rot_euler.x = pitch_curve
	else:
		# --- STANCE PHASE ---
		var stance_p: float = (phase - 0.5) / 0.5  # [0.0, 1.0]

		# Planted on ground: travels backward from forward (-half_stride) to rear (+half_stride)
		pos.z = -half_stride + (stride_length * stance_p)
		pos.y = rest_y

		# Heel strike settling into flat stance then toe roll before takeoff
		if stance_p < 0.15:
			# Settling onto flat foot
			var settle: float = 1.0 - (stance_p / 0.15)
			rot_euler.x = deg_to_rad(8.0) * settle
		elif stance_p > 0.85:
			# Toe roll / push-off
			var takeoff: float = (stance_p - 0.85) / 0.15
			rot_euler.x = -deg_to_rad(18.0) * takeoff
		else:
			rot_euler.x = 0.0

	return {
		"position": pos,
		"basis": Basis.from_euler(rot_euler)
	}


# ==============================================================================
# MAIN PROCEDURAL EVALUATION
# ==============================================================================

## Evaluates full procedural animation pose for given time, velocity, and gait parameters.
func evaluate(
	current_time: float,
	dt: float,
	current_speed: float,
	target_speed: float,
	params: GaitParameters,
	base_hips_height: float = 0.95,
	look_target_global: Vector3 = Vector3.ZERO,
	char_global_tf: Transform3D = Transform3D.IDENTITY
) -> ProceduralPose:
	var pose = ProceduralPose.new()

	# Determine movement activity
	var max_expected_speed: float = maxf(0.1, target_speed)
	var speed_ratio: float = clampf(current_speed / max_expected_speed, 0.0, 1.5)
	pose.speed_ratio = speed_ratio
	pose.is_moving = current_speed > 0.05

	# Update cyclic gait phase
	if pose.is_moving:
		# Cycle duration scales slightly with speed for natural cadence
		var dynamic_duration: float = params.cycle_duration / maxf(0.5, sqrt(speed_ratio))
		accumulated_phase += (dt / dynamic_duration)
		accumulated_phase = fmod(accumulated_phase, 1.0)
	else:
		# Return smoothly toward rest stance
		accumulated_phase = lerpf(accumulated_phase, 0.0, clampf(dt * 6.0, 0.0, 1.0))

	# Left and Right leg phases (180 degrees / 0.5 offset)
	var phase_l: float = accumulated_phase
	var phase_r: float = fmod(accumulated_phase + 0.5, 1.0)
	pose.phase_l = phase_l
	pose.phase_r = phase_r

	# Effective stride and lift scaled by speed ratio
	var effective_stride: float = params.stride_length * speed_ratio
	var effective_step_h: float = params.step_height * clampf(speed_ratio, 0.2, 1.2)

	# --------------------------------------------------------------------------
	# 1. PELVIS / HIPS KINEMATICS & DYNAMICS
	# --------------------------------------------------------------------------
	var target_hips_y: float = base_hips_height
	var target_hips_x: float = 0.0
	var target_hips_z: float = 0.0

	var hip_roll: float = 0.0
	var hip_yaw: float = 0.0

	if pose.is_moving:
		# Vertical bobbing: double frequency (two steps per walk cycle)
		# Pelvis drops lowest during foot contact/mid-stance impact
		var bob: float = cos(phase_l * TAU * 2.0) * params.pelvis_bob * speed_ratio
		target_hips_y -= bob

		# Lateral sway: shifts toward currently supporting planted foot
		# When phase_l is in stance (>0.5), shift towards left (+X); otherwise towards right (-X)
		var sway: float = sin(phase_l * TAU) * params.pelvis_sway * speed_ratio
		target_hips_x = sway

		# Hip drop / roll (around Z axis) and Hip yaw (around Y axis)
		hip_roll = sin(phase_l * TAU) * deg_to_rad(params.pelvis_tilt_deg * speed_ratio)
		hip_yaw = sin(phase_l * TAU) * deg_to_rad(params.pelvis_yaw_deg * speed_ratio)
	else:
		# Idle subtle breathing / weight shift
		var breathe_phase: float = current_time * 1.5
		target_hips_y += sin(breathe_phase) * 0.008
		target_hips_x += cos(breathe_phase * 0.5) * 0.004

	var ideal_hips_pos: Vector3 = Vector3(target_hips_x, target_hips_y, target_hips_z)
	if params.use_springs and dt > 0.0:
		pose.hips_position = pelvis_spring.update(ideal_hips_pos, dt)
	else:
		pose.hips_position = ideal_hips_pos

	var hips_basis: Basis = Basis.IDENTITY
	hips_basis = hips_basis.rotated(Vector3.FORWARD, hip_roll)
	hips_basis = hips_basis.rotated(Vector3.UP, hip_yaw)
	pose.hips_rotation = hips_basis

	# --------------------------------------------------------------------------
	# 2. SPINE & CHEST COUNTER-ROTATION
	# --------------------------------------------------------------------------
	var chest_yaw: float = 0.0
	var chest_lean: float = 0.0

	if pose.is_moving:
		# Chest twists counter to pelvis yaw for biomechanical conservation of angular momentum
		chest_yaw = -sin(phase_l * TAU) * deg_to_rad(params.spine_twist_deg * speed_ratio)
		# Forward lean pitching as speed increases
		chest_lean = deg_to_rad(params.spine_lean_deg * clampf(speed_ratio, 0.0, 1.2))

	var chest_basis: Basis = Basis.IDENTITY
	chest_basis = chest_basis.rotated(Vector3.RIGHT, chest_lean)
	chest_basis = chest_basis.rotated(Vector3.UP, chest_yaw)
	pose.chest_rotation = chest_basis
	pose.chest_position = pose.hips_position + Vector3(0, 0.35, 0)

	# --------------------------------------------------------------------------
	# 3. LEGS INVERSE KINEMATICS (Foot Targets & Knee Poles)
	# --------------------------------------------------------------------------
	var left_foot_data: Dictionary
	var right_foot_data: Dictionary

	if pose.is_moving:
		left_foot_data = compute_foot_ik(phase_l, effective_stride, effective_step_h, -params.foot_spacing)
		right_foot_data = compute_foot_ik(phase_r, effective_stride, effective_step_h, params.foot_spacing)
	else:
		# Idle stance
		left_foot_data = {
			"position": Vector3(-params.foot_spacing, 0.0, 0.0),
			"basis": Basis.IDENTITY
		}
		right_foot_data = {
			"position": Vector3(params.foot_spacing, 0.0, 0.0),
			"basis": Basis.IDENTITY
		}

	pose.left_foot_pos = left_foot_data["position"]
	pose.left_foot_rot = left_foot_data["basis"]
	pose.right_foot_pos = right_foot_data["position"]
	pose.right_foot_rot = right_foot_data["basis"]

	# Knee pole hints: point forward (-Z) with slight natural outward splay
	pose.left_knee_pole = Vector3(-0.15, 0.45, -0.6)
	pose.right_knee_pole = Vector3(0.15, 0.45, -0.6)

	# --------------------------------------------------------------------------
	# 4. ARMS INVERSE KINEMATICS (Contralateral Coordination)
	# --------------------------------------------------------------------------
	# Left arm swings forward (-Z) with Right leg (phase_r)
	# Right arm swings forward (-Z) with Left leg (phase_l)
	var arm_swing_l: float = 0.0
	var arm_swing_r: float = 0.0
	var arm_lift_l: float = 0.0
	var arm_lift_r: float = 0.0

	var hand_rest_y: float = 0.85
	var hand_spacing: float = 0.38

	if pose.is_moving:
		# Contralateral sinusoidal swing
		arm_swing_l = -sin(phase_r * TAU) * params.arm_swing * speed_ratio
		arm_lift_l = -absf(arm_swing_l) * (params.arm_lift / maxf(0.01, params.arm_swing))

		arm_swing_r = -sin(phase_l * TAU) * params.arm_swing * speed_ratio
		arm_lift_r = -absf(arm_swing_r) * (params.arm_lift / maxf(0.01, params.arm_swing))
	else:
		# Subtle idle arm sway
		var idle_arm: float = sin(current_time * 1.5) * 0.015
		arm_swing_l = idle_arm
		arm_swing_r = -idle_arm

	pose.left_hand_pos = Vector3(-hand_spacing, hand_rest_y + arm_lift_l, arm_swing_l)
	pose.right_hand_pos = Vector3(hand_spacing, hand_rest_y + arm_lift_r, arm_swing_r)

	# Elbow pole hints: point backward (+Z) with outward splay
	pose.left_elbow_pole = Vector3(-0.4, 1.15, 0.4)
	pose.right_elbow_pole = Vector3(0.4, 1.15, 0.4)

	# --------------------------------------------------------------------------
	# 5. HEAD STABILIZATION & LOOK-AT TARGET
	# --------------------------------------------------------------------------
	var head_yaw: float = 0.0
	if pose.is_moving:
		# Compensate against chest counter-rotation so head remains focused forward
		head_yaw = -chest_yaw * 0.75

	var head_basis: Basis = Basis.IDENTITY
	head_basis = head_basis.rotated(Vector3.UP, head_yaw)

	# Optional 3D look-at target tracking
	if look_target_global != Vector3.ZERO:
		var head_world_pos: Vector3 = char_global_tf.origin + Vector3(0, 1.65, 0)
		var look_dir: Vector3 = (look_target_global - head_world_pos).normalized()
		var local_look: Vector3 = char_global_tf.basis.inverse() * look_dir

		# Clamp look angles to prevent neck snapping
		var target_yaw: float = clampf(atan2(-local_look.x, -local_look.z), -deg_to_rad(65.0), deg_to_rad(65.0))
		var target_pitch: float = clampf(asin(local_look.y), -deg_to_rad(45.0), deg_to_rad(45.0))

		head_basis = Basis.IDENTITY
		head_basis = head_basis.rotated(Vector3.UP, target_yaw)
		head_basis = head_basis.rotated(Vector3.RIGHT, target_pitch)

	pose.head_rotation = head_basis
	pose.head_position = pose.chest_position + Vector3(0, 0.32, 0)

	last_time = current_time
	return pose
