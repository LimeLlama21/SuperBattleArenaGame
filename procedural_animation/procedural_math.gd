class_name ProceduralAnimMath
extends RefCounted

## Procedural Animation Math & Dynamics Utilities
## Provides analytical 2-bone IK solver, 2nd-order damped harmonic oscillators,
## Hermite smoothstep interpolation, and parabolic foot clearance arcs.

# ==============================================================================
# 1. SECOND-ORDER SPRING-MASS-DAMPER DYNAMICS
# ==============================================================================

class SpringDamper3D extends RefCounted:
	var stiffness: float = 120.0
	var damping: float = 14.0
	var mass: float = 1.0
	var position: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO

	func _init(p_stiffness: float = 120.0, p_damping: float = 14.0, p_mass: float = 1.0) -> void:
		stiffness = p_stiffness
		damping = p_damping
		mass = maxf(0.01, p_mass)
		position = Vector3.ZERO
		velocity = Vector3.ZERO

	func reset(initial_pos: Vector3) -> void:
		position = initial_pos
		velocity = Vector3.ZERO

	## Updates the spring system towards target_pos over dt seconds.
	## Integrates with clamped timestep to prevent numerical instability.
	func update(target_pos: Vector3, dt: float) -> Vector3:
		if dt <= 0.0:
			return position

		# Clamp maximum integration timestep to prevent explosion
		var step: float = minf(dt, 0.05)

		# Hooke's Law + viscous damping: F = -k*(x - target) - c*v
		var displacement: Vector3 = position - target_pos
		var spring_force: Vector3 = -stiffness * displacement
		var damping_force: Vector3 = -damping * velocity
		var net_force: Vector3 = spring_force + damping_force
		var acceleration: Vector3 = net_force / mass

		# Semi-implicit Euler integration for energy conservation
		velocity += acceleration * step
		position += velocity * step
		return position


class SpringDamper1D extends RefCounted:
	var stiffness: float = 120.0
	var damping: float = 14.0
	var mass: float = 1.0
	var value: float = 0.0
	var velocity: float = 0.0

	func _init(p_stiffness: float = 120.0, p_damping: float = 14.0, p_mass: float = 1.0) -> void:
		stiffness = p_stiffness
		damping = p_damping
		mass = maxf(0.01, p_mass)
		value = 0.0
		velocity = 0.0

	func reset(initial_val: float) -> void:
		value = initial_val
		velocity = 0.0

	func update(target_val: float, dt: float) -> float:
		if dt <= 0.0:
			return value

		var step: float = minf(dt, 0.05)
		var displacement: float = value - target_val
		var spring_force: float = -stiffness * displacement
		var damping_force: float = -damping * velocity
		var net_force: float = spring_force + damping_force
		var acceleration: float = net_force / mass

		velocity += acceleration * step
		value += velocity * step
		return value


# ==============================================================================
# 2. INTERPOLATION & GAIT CURVES
# ==============================================================================

## Parabolic vertical lift curve for foot swing clearance.
## Returns 0.0 at progress=0 and progress=1, and max_height at progress=0.5.
static func parabolic_lift(progress: float, max_height: float) -> float:
	var p: float = clampf(progress, 0.0, 1.0)
	return 4.0 * max_height * p * (1.0 - p)


## Cubic Hermite smoothstep: 3p^2 - 2p^3 for organic acceleration/deceleration.
static func smooth_step(progress: float) -> float:
	var p: float = clampf(progress, 0.0, 1.0)
	return p * p * (3.0 - 2.0 * p)


## Quintic smootherstep: 6p^5 - 15p^4 + 10p^3 (zero 1st and 2nd derivatives at endpoints).
static func smoother_step(progress: float) -> float:
	var p: float = clampf(progress, 0.0, 1.0)
	return p * p * p * (p * (p * 6.0 - 15.0) + 10.0)


## Computes cyclic phase in [0.0, 1.0) given current time, cycle duration, and phase offset.
static func cyclical_phase(time: float, cycle_duration: float, offset: float = 0.0) -> float:
	if cycle_duration <= 0.0:
		return 0.0
	var raw: float = (time / cycle_duration) + offset
	return fmod(fmod(raw, 1.0) + 1.0, 1.0)


# ==============================================================================
# 3. ANALYTICAL TWO-BONE INVERSE KINEMATICS (Zero Twist)
# ==============================================================================

class TwoBoneIKResult extends RefCounted:
	var joint_position: Vector3 = Vector3.ZERO
	var tip_position: Vector3 = Vector3.ZERO
	var root_basis: Basis = Basis.IDENTITY
	var joint_basis: Basis = Basis.IDENTITY
	var is_reachable: bool = true


## Solves analytical 2-bone Inverse Kinematics (e.g. Hip -> Knee -> Foot or Shoulder -> Elbow -> Hand).
## root_pos: Position of root joint (e.g. Hip)
## target_pos: Desired end-effector position (e.g. Foot)
## pole_dir: Hint vector / bend direction (e.g. Vector3.FORWARD for knee, Vector3.BACK for elbow)
## len_upper: Length of upper segment (e.g. Thigh)
## len_lower: Length of lower segment (e.g. Shin)
## forward_axis: Default rest forward axis of the bone (typically -Vector3.FORWARD or -Z / +Y)
static func solve_two_bone_ik(
	root_pos: Vector3,
	target_pos: Vector3,
	pole_dir: Vector3,
	len_upper: float,
	len_lower: float,
	soft_extension_limit: float = 0.999
) -> TwoBoneIKResult:
	var result = TwoBoneIKResult.new()
	var to_target: Vector3 = target_pos - root_pos
	var dist: float = to_target.length()
	var total_len: float = len_upper + len_lower
	var min_len: float = absf(len_upper - len_lower) + 0.001

	# Prevent zero vector singularity
	var dir_to_target: Vector3
	if dist < 0.0001:
		dir_to_target = Vector3.DOWN
		dist = 0.0001
	else:
		dir_to_target = to_target / dist

	# Clamp target distance between min distance and max reach (with soft limit)
	var max_reach: float = total_len * soft_extension_limit
	var effective_dist: float = clampf(dist, min_len, max_reach)
	result.is_reachable = dist <= total_len

	# Actual tip position after reach clamping
	result.tip_position = root_pos + dir_to_target * effective_dist

	# Calculate bend plane normal perpendicular to target direction and pole hint
	var pole_normalized: Vector3 = pole_dir.normalized()
	# Project pole vector onto plane perpendicular to dir_to_target
	var pole_projected: Vector3 = pole_normalized - dir_to_target * pole_normalized.dot(dir_to_target)
	if pole_projected.length_squared() < 0.0001:
		# Collinear pole fallback: choose perpendicular arbitrary axis
		var fallback_axis: Vector3 = Vector3.RIGHT if absf(dir_to_target.x) < 0.9 else Vector3.UP
		pole_projected = (fallback_axis - dir_to_target * fallback_axis.dot(dir_to_target)).normalized()
	else:
		pole_projected = pole_projected.normalized()

	var bend_normal: Vector3 = dir_to_target.cross(pole_projected).normalized()

	# Law of Cosines to solve for interior angles:
	# c^2 = a^2 + b^2 - 2ab*cos(C)
	# cos(angle_root) = (len_upper^2 + dist^2 - len_lower^2) / (2 * len_upper * dist)
	var cos_root: float = (len_upper * len_upper + effective_dist * effective_dist - len_lower * len_lower) / (2.0 * len_upper * effective_dist)
	cos_root = clampf(cos_root, -1.0, 1.0)
	var angle_root: float = acos(cos_root)

	# Rotate dir_to_target around bend_normal by angle_root towards pole_projected
	# Rodrigues rotation formula / Basis rotation around bend_normal
	var rot_basis: Basis = Basis(bend_normal, angle_root)
	var upper_dir: Vector3 = (rot_basis * dir_to_target).normalized()

	# Compute joint position (e.g. Knee / Elbow)
	result.joint_position = root_pos + upper_dir * len_upper

	# Lower limb direction
	var lower_dir: Vector3 = (result.tip_position - result.joint_position).normalized()

	# Compute rotation bases with aligned bend plane and zero twist
	result.root_basis = _construct_look_basis(upper_dir, bend_normal)
	result.joint_basis = _construct_look_basis(lower_dir, bend_normal)

	return result


## Constructs a stable, twist-free orthonormal Basis from a forward direction and a lateral normal.
static func _construct_look_basis(forward_dir: Vector3, lateral_normal: Vector3) -> Basis:
	var f: Vector3 = forward_dir.normalized()
	var r: Vector3 = lateral_normal.normalized()
	var u: Vector3 = r.cross(f).normalized()
	# Recalculate r to ensure true orthonormality
	r = f.cross(u).normalized()
	return Basis(r, u, f)
