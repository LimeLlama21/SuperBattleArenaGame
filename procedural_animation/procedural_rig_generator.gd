class_name ProceduralRigGenerator
extends RefCounted

## Procedural Rig & Mannequin Generator in GDScript.
## Programmatically constructs:
## 1. Stylized Biped Humanoid Character Rig with 2-Bone IK solvers for legs and arms
## 2. Multi-Legged Arachnid / Spider Rig with procedural tripod gait stepping
## All components are structured with clean Node3D hierarchies and PBR materials.

# ==============================================================================
# BIPED HUMANOID MANNEQUIN GENERATOR
# ==============================================================================

class BipedRigReferences extends RefCounted:
	var root: Node3D
	var hips: Node3D
	var spine: Node3D
	var chest: Node3D
	var head: Node3D
	# Left Leg
	var thigh_l: Node3D
	var shin_l: Node3D
	var foot_l: Node3D
	var foot_target_l: Marker3D
	var knee_pole_l: Marker3D
	var leg_ik_l: TwoBoneIKSolver3D
	# Right Leg
	var thigh_r: Node3D
	var shin_r: Node3D
	var foot_r: Node3D
	var foot_target_r: Marker3D
	var knee_pole_r: Marker3D
	var leg_ik_r: TwoBoneIKSolver3D
	# Left Arm
	var upper_arm_l: Node3D
	var forearm_l: Node3D
	var hand_l: Node3D
	var hand_target_l: Marker3D
	var elbow_pole_l: Marker3D
	var arm_ik_l: TwoBoneIKSolver3D
	# Right Arm
	var upper_arm_r: Node3D
	var forearm_r: Node3D
	var hand_r: Node3D
	var hand_target_r: Marker3D
	var elbow_pole_r: Marker3D
	var arm_ik_r: TwoBoneIKSolver3D


static func generate_biped_mannequin(parent: Node, name: String = "ProceduralMannequin") -> BipedRigReferences:
	var refs = BipedRigReferences.new()

	# Root Node
	var root = Node3D.new()
	root.name = name
	parent.add_child(root)
	refs.root = root

	# Materials
	var mat_body = StandardMaterial3D.new()
	mat_body.albedo_color = Color(0.12, 0.14, 0.18) # Sleek slate-dark chassis
	mat_body.metallic = 0.4
	mat_body.roughness = 0.35

	var mat_accent = StandardMaterial3D.new()
	mat_accent.albedo_color = Color(0.18, 0.55, 0.95) # Cyan-blue accent trim
	mat_accent.metallic = 0.2
	mat_accent.roughness = 0.4

	var mat_visor = StandardMaterial3D.new()
	mat_visor.albedo_color = Color(0.0, 0.9, 1.0) # Glowing neon cyber visor
	mat_visor.emission_enabled = true
	mat_visor.emission = Color(0.0, 0.9, 1.0)
	mat_visor.emission_energy_multiplier = 2.5

	var mat_joint = StandardMaterial3D.new()
	mat_joint.albedo_color = Color(0.25, 0.28, 0.35)
	mat_joint.metallic = 0.8
	mat_joint.roughness = 0.25

	# --------------------------------------------------------------------------
	# HIPS / PELVIS
	# --------------------------------------------------------------------------
	var hips = Node3D.new()
	hips.name = "Hips"
	hips.position = Vector3(0, 0.95, 0)
	root.add_child(hips)
	refs.hips = hips

	_create_box_mesh(hips, Vector3(0.34, 0.16, 0.22), Vector3.ZERO, mat_body, "HipsMesh")

	# --------------------------------------------------------------------------
	# SPINE & CHEST
	# --------------------------------------------------------------------------
	var spine = Node3D.new()
	spine.name = "Spine"
	spine.position = Vector3(0, 0.15, 0)
	hips.add_child(spine)
	refs.spine = spine
	_create_box_mesh(spine, Vector3(0.28, 0.18, 0.20), Vector3(0, 0.08, 0), mat_body, "SpineMesh")

	var chest = Node3D.new()
	chest.name = "Chest"
	chest.position = Vector3(0, 0.22, 0)
	spine.add_child(chest)
	refs.chest = chest
	_create_box_mesh(chest, Vector3(0.36, 0.24, 0.24), Vector3(0, 0.12, 0), mat_body, "ChestMesh")
	_create_box_mesh(chest, Vector3(0.24, 0.14, 0.25), Vector3(0, 0.14, 0.01), mat_accent, "ChestPlateMesh")

	# --------------------------------------------------------------------------
	# HEAD & VISOR
	# --------------------------------------------------------------------------
	var head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.32, 0)
	chest.add_child(head)
	refs.head = head
	_create_box_mesh(head, Vector3(0.22, 0.24, 0.24), Vector3(0, 0.12, 0), mat_body, "HeadMesh")
	# Cyber visor
	_create_box_mesh(head, Vector3(0.20, 0.06, 0.06), Vector3(0, 0.12, -0.12), mat_visor, "VisorMesh")

	# --------------------------------------------------------------------------
	# IK TARGET MARKERS (Child of root so they can move freely in character space)
	# --------------------------------------------------------------------------
	var ik_targets_group = Node3D.new()
	ik_targets_group.name = "IK_Targets"
	root.add_child(ik_targets_group)

	refs.foot_target_l = _create_marker(ik_targets_group, "Foot_Target_L", Vector3(-0.20, 0.0, 0.0))
	refs.foot_target_r = _create_marker(ik_targets_group, "Foot_Target_R", Vector3(0.20, 0.0, 0.0))
	refs.knee_pole_l = _create_marker(ik_targets_group, "Knee_Pole_L", Vector3(-0.20, 0.45, -0.6))
	refs.knee_pole_r = _create_marker(ik_targets_group, "Knee_Pole_R", Vector3(0.20, 0.45, -0.6))

	refs.hand_target_l = _create_marker(ik_targets_group, "Hand_Target_L", Vector3(-0.38, 0.85, 0.0))
	refs.hand_target_r = _create_marker(ik_targets_group, "Hand_Target_R", Vector3(0.38, 0.85, 0.0))
	refs.elbow_pole_l = _create_marker(ik_targets_group, "Elbow_Pole_L", Vector3(-0.45, 1.15, 0.4))
	refs.elbow_pole_r = _create_marker(ik_targets_group, "Elbow_Pole_R", Vector3(0.45, 1.15, 0.4))

	# --------------------------------------------------------------------------
	# LEGS (Thigh -> Shin -> Foot)
	# --------------------------------------------------------------------------
	# Left Leg
	refs.thigh_l = _create_limb_segment(hips, "Thigh_L", Vector3(-0.18, -0.05, 0), Vector3(0.12, 0.44, 0.12), mat_body)
	refs.shin_l = _create_limb_segment(root, "Shin_L", Vector3(-0.18, 0.45, 0), Vector3(0.10, 0.44, 0.10), mat_body)
	refs.foot_l = _create_limb_segment(root, "Foot_L", Vector3(-0.18, 0.05, 0), Vector3(0.12, 0.08, 0.24), mat_accent)

	refs.leg_ik_l = TwoBoneIKSolver3D.new()
	refs.leg_ik_l.name = "Leg_IK_L"
	refs.leg_ik_l.upper_limb_node = refs.thigh_l
	refs.leg_ik_l.lower_limb_node = refs.shin_l
	refs.leg_ik_l.tip_node = refs.foot_l
	refs.leg_ik_l.target_node = refs.foot_target_l
	refs.leg_ik_l.pole_node = refs.knee_pole_l
	refs.leg_ik_l.upper_limb_length = 0.45
	refs.leg_ik_l.lower_limb_length = 0.45
	root.add_child(refs.leg_ik_l)

	# Right Leg
	refs.thigh_r = _create_limb_segment(hips, "Thigh_R", Vector3(0.18, -0.05, 0), Vector3(0.12, 0.44, 0.12), mat_body)
	refs.shin_r = _create_limb_segment(root, "Shin_R", Vector3(0.18, 0.45, 0), Vector3(0.10, 0.44, 0.10), mat_body)
	refs.foot_r = _create_limb_segment(root, "Foot_R", Vector3(0.18, 0.05, 0), Vector3(0.12, 0.08, 0.24), mat_accent)

	refs.leg_ik_r = TwoBoneIKSolver3D.new()
	refs.leg_ik_r.name = "Leg_IK_R"
	refs.leg_ik_r.upper_limb_node = refs.thigh_r
	refs.leg_ik_r.lower_limb_node = refs.shin_r
	refs.leg_ik_r.tip_node = refs.foot_r
	refs.leg_ik_r.target_node = refs.foot_target_r
	refs.leg_ik_r.pole_node = refs.knee_pole_r
	refs.leg_ik_r.upper_limb_length = 0.45
	refs.leg_ik_r.lower_limb_length = 0.45
	root.add_child(refs.leg_ik_r)

	# --------------------------------------------------------------------------
	# ARMS (UpperArm -> Forearm -> Hand)
	# --------------------------------------------------------------------------
	# Left Arm
	refs.upper_arm_l = _create_limb_segment(chest, "UpperArm_L", Vector3(-0.26, 0.18, 0), Vector3(0.09, 0.32, 0.09), mat_body)
	refs.forearm_l = _create_limb_segment(root, "Forearm_L", Vector3(-0.35, 1.15, 0), Vector3(0.08, 0.30, 0.08), mat_body)
	refs.hand_l = _create_limb_segment(root, "Hand_L", Vector3(-0.38, 0.85, 0), Vector3(0.08, 0.10, 0.12), mat_accent)

	refs.arm_ik_l = TwoBoneIKSolver3D.new()
	refs.arm_ik_l.name = "Arm_IK_L"
	refs.arm_ik_l.upper_limb_node = refs.upper_arm_l
	refs.arm_ik_l.lower_limb_node = refs.forearm_l
	refs.arm_ik_l.tip_node = refs.hand_l
	refs.arm_ik_l.target_node = refs.hand_target_l
	refs.arm_ik_l.pole_node = refs.elbow_pole_l
	refs.arm_ik_l.upper_limb_length = 0.32
	refs.arm_ik_l.lower_limb_length = 0.30
	root.add_child(refs.arm_ik_l)

	# Right Arm
	refs.upper_arm_r = _create_limb_segment(chest, "UpperArm_R", Vector3(0.26, 0.18, 0), Vector3(0.09, 0.32, 0.09), mat_body)
	refs.forearm_r = _create_limb_segment(root, "Forearm_R", Vector3(0.35, 1.15, 0), Vector3(0.08, 0.30, 0.08), mat_body)
	refs.hand_r = _create_limb_segment(root, "Hand_R", Vector3(0.38, 0.85, 0), Vector3(0.08, 0.10, 0.12), mat_accent)

	refs.arm_ik_r = TwoBoneIKSolver3D.new()
	refs.arm_ik_r.name = "Arm_IK_R"
	refs.arm_ik_r.upper_limb_node = refs.upper_arm_r
	refs.arm_ik_r.lower_limb_node = refs.forearm_r
	refs.arm_ik_r.tip_node = refs.hand_r
	refs.arm_ik_r.target_node = refs.hand_target_r
	refs.arm_ik_r.pole_node = refs.elbow_pole_r
	refs.arm_ik_r.upper_limb_length = 0.32
	refs.arm_ik_r.lower_limb_length = 0.30
	root.add_child(refs.arm_ik_r)

	return refs


# ==============================================================================
# SPIDER / MULTI-LEG RIG GENERATOR
# ==============================================================================

class SpiderLegData extends RefCounted:
	var leg_id: int
	var root_joint: Node3D
	var mid_joint: Node3D
	var tip_joint: Node3D
	var target_marker: Marker3D
	var pole_marker: Marker3D
	var ik_solver: TwoBoneIKSolver3D
	var default_planted_pos: Vector3
	var current_planted_pos: Vector3
	var target_step_pos: Vector3
	var is_stepping: bool = false
	var step_progress: float = 0.0
	var phase_group: int = 0 # 0 or 1 for alternating tripod gait


class SpiderRigReferences extends RefCounted:
	var root: Node3D
	var body: Node3D
	var legs: Array[SpiderLegData] = []


static func generate_spider_rig(parent: Node, leg_count: int = 6, radius: float = 0.6) -> SpiderRigReferences:
	var refs = SpiderRigReferences.new()
	var root = Node3D.new()
	root.name = "ProceduralSpider"
	parent.add_child(root)
	refs.root = root

	var mat_chassis = StandardMaterial3D.new()
	mat_chassis.albedo_color = Color(0.10, 0.12, 0.15)
	mat_chassis.metallic = 0.6
	mat_chassis.roughness = 0.3

	var mat_glow = StandardMaterial3D.new()
	mat_glow.albedo_color = Color(1.0, 0.3, 0.1)
	mat_glow.emission_enabled = true
	mat_glow.emission = Color(1.0, 0.3, 0.1)
	mat_glow.emission_energy_multiplier = 2.0

	var body = Node3D.new()
	body.name = "SpiderBody"
	body.position = Vector3(0, 0.5, 0)
	root.add_child(body)
	refs.body = body

	_create_box_mesh(body, Vector3(0.5, 0.22, 0.7), Vector3.ZERO, mat_chassis, "BodyMesh")
	_create_box_mesh(body, Vector3(0.3, 0.08, 0.08), Vector3(0, 0.06, -0.36), mat_glow, "OpticsMesh")

	var targets_group = Node3D.new()
	targets_group.name = "Leg_Targets"
	root.add_child(targets_group)

	for i in range(leg_count):
		var leg = SpiderLegData.new()
		leg.leg_id = i
		leg.phase_group = i % 2

		# Distribute legs evenly along left and right sides
		var half_legs: int = int(float(leg_count) * 0.5)
		var is_left: bool = (i < half_legs)
		var side_idx: int = i if is_left else (i - half_legs)
		var side_count: int = half_legs
		var z_offset: float = lerpf(0.3, -0.3, float(side_idx) / maxf(1.0, float(side_count - 1)))
		var x_dir: float = -1.0 if is_left else 1.0

		var mount_pos: Vector3 = Vector3(x_dir * (radius * 0.4), 0.0, z_offset)
		var leg_root = Node3D.new()
		leg_root.name = "LegRoot_%d" % i
		leg_root.position = mount_pos
		body.add_child(leg_root)
		leg.root_joint = leg_root

		var mid_joint = Node3D.new()
		mid_joint.name = "LegMid_%d" % i
		root.add_child(mid_joint)
		leg.mid_joint = mid_joint
		_create_box_mesh(mid_joint, Vector3(0.06, 0.4, 0.06), Vector3.ZERO, mat_chassis, "MidMesh_%d" % i)

		var tip_joint = Node3D.new()
		tip_joint.name = "LegTip_%d" % i
		root.add_child(tip_joint)
		leg.tip_joint = tip_joint
		_create_box_mesh(tip_joint, Vector3(0.05, 0.05, 0.05), Vector3.ZERO, mat_glow, "TipMesh_%d" % i)

		# Rest foot position on ground
		var rest_foot: Vector3 = Vector3(x_dir * (radius * 1.5), 0.0, z_offset * 1.3)
		var target_marker = _create_marker(targets_group, "Target_%d" % i, rest_foot)
		leg.target_marker = target_marker
		leg.default_planted_pos = rest_foot
		leg.current_planted_pos = rest_foot
		leg.target_step_pos = rest_foot

		# Pole marker (elevated knee bend direction)
		var pole_marker = _create_marker(targets_group, "Pole_%d" % i, mount_pos + Vector3(x_dir * 0.4, 0.5, 0))
		leg.pole_marker = pole_marker

		# IK Solver
		var ik = TwoBoneIKSolver3D.new()
		ik.name = "IK_%d" % i
		ik.upper_limb_node = leg_root
		ik.lower_limb_node = mid_joint
		ik.tip_node = tip_joint
		ik.target_node = target_marker
		ik.pole_node = pole_marker
		ik.upper_limb_length = 0.45
		ik.lower_limb_length = 0.50
		root.add_child(ik)
		leg.ik_solver = ik

		refs.legs.append(leg)

	return refs


# ==============================================================================
# MESH & MARKER HELPERS
# ==============================================================================

static func _create_box_mesh(
	parent: Node3D,
	size: Vector3,
	pos: Vector3,
	mat: Material,
	name: String
) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.name = name
	var box = BoxMesh.new()
	box.size = size
	box.material = mat
	mi.mesh = box
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _create_limb_segment(
	parent: Node3D,
	name: String,
	pos: Vector3,
	size: Vector3,
	mat: Material
) -> Node3D:
	var node = Node3D.new()
	node.name = name
	node.position = pos
	parent.add_child(node)
	# Center mesh so pivot is at the top joint
	_create_box_mesh(node, size, Vector3(0, -size.y * 0.5, 0), mat, name + "_Mesh")
	return node


static func _create_marker(parent: Node3D, name: String, pos: Vector3) -> Marker3D:
	var marker = Marker3D.new()
	marker.name = name
	marker.position = pos
	parent.add_child(marker)
	return marker
