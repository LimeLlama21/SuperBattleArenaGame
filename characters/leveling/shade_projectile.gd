class_name ShadeProjectile
extends Area3D

const MAX_SPEED: float = 18.0 # ~3x player base speed (6.0 m/s)
const ACCELERATION: float = 32.0 # Rapidly accelerates to max speed in ~0.5s
const HIT_DISTANCE: float = 1.3
const MAX_LIFETIME: float = 10.0

var target: Node = null
var current_speed: float = 4.0
var current_direction: Vector3 = Vector3.FORWARD
var age: float = 0.0

func _ready() -> void:
	# Travels through walls: does not collide with environment terrain
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	
	_setup_visuals()

func _setup_visuals() -> void:
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "ShadeSquare"
	
	# Billboard pitch-black square
	var quad = QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.01, 0.01, 0.02, 1.0)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	
	mesh_inst.mesh = quad
	mesh_inst.material_override = mat
	add_child(mesh_inst)

func _physics_process(delta: float) -> void:
	age += delta
	if age >= MAX_LIFETIME:
		queue_free()
		return
	
	if not is_instance_valid(target) or ("is_dead" in target and target.is_dead):
		queue_free()
		return
	
	var target_center = target.global_position + Vector3(0, 1.0, 0)
	var to_target = target_center - global_position
	var dist = to_target.length()
	
	if dist > 0.001:
		current_direction = to_target.normalized()
	
	# Accelerate rapidly up to capped speed
	current_speed = min(MAX_SPEED, current_speed + ACCELERATION * delta)
	global_position += current_direction * (current_speed * delta)
	
	# Check collision with target
	if dist <= HIT_DISTANCE:
		_on_hit_target()

func is_shade_in_target_vision_cone(target_node: Node) -> bool:
	if not is_instance_valid(target_node):
		return false
	var diff = global_position - target_node.global_position
	var diff_2d = Vector2(diff.x, diff.z)
	if diff_2d.length_squared() < 0.0001:
		return true
	
	var fwd_3d = target_node.get_facing_direction_3d() if target_node.has_method("get_facing_direction_3d") else -target_node.global_transform.basis.z.normalized()
	fwd_3d.y = 0.0
	var fwd_2d = Vector2(fwd_3d.x, fwd_3d.z).normalized()
	if fwd_2d.length_squared() < 0.0001:
		fwd_2d = Vector2(0, -1)
	
	var angle_deg = rad_to_deg(fwd_2d.angle_to(diff_2d.normalized()))
	var cone_half_angle = target_node.get_custom_cone_half_angle_deg() if target_node.has_method("get_custom_cone_half_angle_deg") else PlayerVision.CONE_HALF_ANGLE_DEG
	return abs(angle_deg) <= cone_half_angle

func _on_hit_target() -> void:
	if is_instance_valid(target) and not ("is_dead" in target and target.is_dead):
		var facing = is_shade_in_target_vision_cone(target)
		if facing:
			if target.has_method("apply_blind"):
				target.apply_blind(2.0)
			elif target.has_method("apply_nearsight"):
				target.apply_nearsight(2.0)
			
			if target.has_method("apply_slow"):
				target.apply_slow(2.0, 0.50)
	queue_free()
