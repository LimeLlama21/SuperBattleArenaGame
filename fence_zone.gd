class_name FenceZone
extends Area3D

@export var fence_width: float = 8.0
@export var fence_height: float = 2.6
@export var fence_depth: float = 0.25
@export var duration: float = 6.0
@export var grounded_duration: float = 2.5
@export var slow_duration: float = 1.5
@export var slow_percent: float = 0.70

var shooter_id: int = 0
var shooter_team: int = 0
var tick_timer: float = 0.0
const TICK_INTERVAL: float = 0.1

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var laser_mesh: MeshInstance3D = $LaserMesh
@onready var base_line_mesh: MeshInstance3D = $BaseLineMesh
@onready var post_left: MeshInstance3D = $PostLeft
@onready var post_right: MeshInstance3D = $PostRight

func _ready() -> void:
	_update_geometry()
	if not is_multiplayer_match() or multiplayer.is_server():
		body_entered.connect(_on_body_entered)
		get_tree().create_timer(duration).timeout.connect(queue_free)

func is_multiplayer_match() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return false
	var main_node = get_tree().root.get_node_or_null("Main") if get_tree() else null
	if main_node and main_node.get("is_training_mode") == true:
		return false
	return multiplayer.get_peers().size() > 0

func _update_geometry() -> void:
	if collision_shape and collision_shape.shape is BoxShape3D:
		collision_shape.shape.size = Vector3(fence_width, fence_height, fence_depth)
		collision_shape.position = Vector3(0, fence_height * 0.5, 0)
	
	if laser_mesh and laser_mesh.mesh is BoxMesh:
		laser_mesh.mesh.size = Vector3(fence_width, fence_height, 0.08)
		laser_mesh.position = Vector3(0, fence_height * 0.5, 0)
		
	if base_line_mesh and base_line_mesh.mesh is BoxMesh:
		base_line_mesh.mesh.size = Vector3(fence_width, 0.04, fence_depth)
		base_line_mesh.position = Vector3(0, 0.02, 0)
		
	if post_left:
		post_left.position = Vector3(-fence_width * 0.5, fence_height * 0.5, 0)
		if post_left.mesh is CylinderMesh:
			post_left.mesh.height = fence_height
			
	if post_right:
		post_right.position = Vector3(fence_width * 0.5, fence_height * 0.5, 0)
		if post_right.mesh is CylinderMesh:
			post_right.mesh.height = fence_height

func _physics_process(delta: float) -> void:
	if is_multiplayer_match() and not multiplayer.is_server():
		return
		
	tick_timer += delta
	if tick_timer >= TICK_INTERVAL:
		tick_timer = 0.0
		_apply_zone_effects()

func _on_body_entered(body: Node) -> void:
	if is_multiplayer_match() and not multiplayer.is_server():
		return
	_apply_effect_to_body(body)

func _apply_zone_effects() -> void:
	for body in get_overlapping_bodies():
		_apply_effect_to_body(body)

func _apply_effect_to_body(body: Node) -> void:
	if not is_instance_valid(body) or body.get("is_dead"):
		return
		
	var is_ally = (body.name == str(shooter_id)) or (shooter_team > 0 and body.get("team_id") != null and body.team_id == shooter_team)
	if not is_ally:
		if body.has_method("apply_grounded"):
			body.apply_grounded(grounded_duration)
		if body.has_method("apply_slow"):
			body.apply_slow(slow_duration, slow_percent)
