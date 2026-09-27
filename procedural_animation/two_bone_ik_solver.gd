class_name TwoBoneIKSolver3D
extends Node3D

## Two-Bone Inverse Kinematics Node for Godot 4.
## Supports both hierarchical Node3D limbs and Skeleton3D bone chains.
## Features soft-stretch limits, zero-twist pole direction, and foot rotation alignment.

@export_group("Targets")
## Target end-effector node (e.g. Foot IK Target or Hand IK Target)
@export var target_node: Node3D
## Pole target / hint node (e.g. Knee Pole or Elbow Pole)
@export var pole_node: Node3D
## Optional fallback target vector when target_node is null
@export var target_position: Vector3 = Vector3.ZERO
## Optional fallback pole vector when pole_node is null
@export var pole_direction: Vector3 = Vector3.FORWARD

@export_group("Node-Based Limb")
## Upper limb node (Thigh or UpperArm)
@export var upper_limb_node: Node3D
## Lower limb node (Shin or Forearm)
@export var lower_limb_node: Node3D
## Tip node (Foot or Hand)
@export var tip_node: Node3D

@export_group("Skeleton3D Limb")
@export var skeleton: Skeleton3D
@export var upper_bone_name: String = ""
@export var lower_bone_name: String = ""
@export var tip_bone_name: String = ""

@export_group("Limb Dimensions")
@export var auto_calculate_lengths: bool = true
@export var upper_limb_length: float = 0.45
@export var lower_limb_length: float = 0.45
@export var soft_extension_limit: float = 0.99

@export_group("Foot Ground Alignment")
@export var align_tip_rotation: bool = true
@export var tip_target_rotation: Quaternion = Quaternion.IDENTITY

var _upper_bone_idx: int = -1
var _lower_bone_idx: int = -1
var _tip_bone_idx: int = -1


func _ready() -> void:
	if skeleton:
		_upper_bone_idx = skeleton.find_bone(upper_bone_name)
		_lower_bone_idx = skeleton.find_bone(lower_bone_name)
		_tip_bone_idx = skeleton.find_bone(tip_bone_name)

	if auto_calculate_lengths:
		_calculate_limb_lengths()


func _calculate_limb_lengths() -> void:
	if upper_limb_node and lower_limb_node and tip_node:
		upper_limb_length = upper_limb_node.global_position.distance_to(lower_limb_node.global_position)
		lower_limb_length = lower_limb_node.global_position.distance_to(tip_node.global_position)
	elif skeleton and _upper_bone_idx != -1 and _lower_bone_idx != -1 and _tip_bone_idx != -1:
		var p_upper: Vector3 = skeleton.get_bone_global_pose(_upper_bone_idx).origin
		var p_lower: Vector3 = skeleton.get_bone_global_pose(_lower_bone_idx).origin
		var p_tip: Vector3 = skeleton.get_bone_global_pose(_tip_bone_idx).origin
		upper_limb_length = p_upper.distance_to(p_lower)
		lower_limb_length = p_lower.distance_to(p_tip)

	# Ensure non-zero lengths
	if upper_limb_length < 0.05:
		upper_limb_length = 0.45
	if lower_limb_length < 0.05:
		lower_limb_length = 0.45


## Solves IK and applies transforms to the limb nodes or skeleton.
func solve_and_apply() -> void:
	var root_pos: Vector3
	if upper_limb_node:
		root_pos = upper_limb_node.global_position
	elif skeleton and _upper_bone_idx != -1:
		root_pos = skeleton.global_transform * skeleton.get_bone_global_pose(_upper_bone_idx).origin
	else:
		root_pos = global_position

	var solved_target: Vector3 = target_node.global_position if target_node else (global_position + target_position)
	var solved_pole: Vector3
	if pole_node:
		solved_pole = (pole_node.global_position - root_pos).normalized()
	else:
		solved_pole = (global_transform.basis * pole_direction).normalized()

	var ik_res: ProceduralAnimMath.TwoBoneIKResult = ProceduralAnimMath.solve_two_bone_ik(
		root_pos,
		solved_target,
		solved_pole,
		upper_limb_length,
		lower_limb_length,
		soft_extension_limit
	)

	# Apply to Node3D limb
	if upper_limb_node and lower_limb_node:
		# Position lower limb at joint position
		lower_limb_node.global_position = ik_res.joint_position
		# Point upper limb towards joint position
		upper_limb_node.look_at(ik_res.joint_position, ik_res.root_basis.y)

		# Point lower limb towards tip position
		var tip_pos: Vector3 = ik_res.tip_position
		if tip_node:
			tip_node.global_position = tip_pos
			lower_limb_node.look_at(tip_pos, ik_res.joint_basis.y)
			if align_tip_rotation:
				if target_node:
					tip_node.global_transform.basis = target_node.global_transform.basis
				else:
					tip_node.global_transform.basis = Basis(tip_target_rotation)
		else:
			lower_limb_node.look_at(tip_pos, ik_res.joint_basis.y)

	# Apply to Skeleton3D if configured
	if skeleton and _upper_bone_idx != -1 and _lower_bone_idx != -1:
		var inv_skel: Transform3D = skeleton.global_transform.affine_inverse()
		var local_joint: Vector3 = inv_skel * ik_res.joint_position
		var local_tip: Vector3 = inv_skel * ik_res.tip_position

		# Update bone global pose overrides
		var upper_tf: Transform3D = Transform3D(ik_res.root_basis, inv_skel * root_pos)
		var lower_tf: Transform3D = Transform3D(ik_res.joint_basis, local_joint)
		skeleton.set_bone_global_pose_override(_upper_bone_idx, upper_tf, 1.0, true)
		skeleton.set_bone_global_pose_override(_lower_bone_idx, lower_tf, 1.0, true)
		if _tip_bone_idx != -1:
			var tip_basis: Basis = target_node.global_transform.basis if target_node else Basis(tip_target_rotation)
			skeleton.set_bone_global_pose_override(_tip_bone_idx, Transform3D(tip_basis, local_tip), 1.0, true)
