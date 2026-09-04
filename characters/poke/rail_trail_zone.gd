class_name RailTrailZone
extends Area3D

@export var length: float = 70.0
@export var width: float = 3.2
@export var duration: float = 5.0
@export var dps: float = 30.0
@export var slow_percent: float = 0.20
@export var slow_duration: float = 1.0

var shooter_id: int = 0
var shooter_team: int = 0
var tick_timer: float = 0.0
const TICK_INTERVAL: float = 0.2

var vision_sub_nodes: Array[Node3D] = []

@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")
@onready var ground_mesh: MeshInstance3D = get_node_or_null("GroundMesh")

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Detects CharacterBody3D players
	
	if collision_shape and collision_shape.shape is BoxShape3D:
		collision_shape.shape.size = Vector3(width, 3.5, length)
	
	if ground_mesh and ground_mesh.mesh is BoxMesh:
		ground_mesh.mesh.size = Vector3(width, 0.15, length)
	
	_setup_vision_points()

	if is_server_authority():
		body_entered.connect(_on_body_entered)
		get_tree().create_timer(duration).timeout.connect(_on_lifetime_end)

func is_server_authority() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()

func _setup_vision_points() -> void:
	var main_node = get_tree().root.get_node_or_null("Main")
	var vision_container = main_node.get_node_or_null("VisionZones") if main_node else null
	if not vision_container:
		return
	
	# Place 5 vision reveal points along the 70m line
	var fwd = -global_transform.basis.z.normalized()
	var half_len = length * 0.5
	var start_p = global_position - fwd * half_len
	var count = 5
	for i in range(count):
		var t = float(i + 0.5) / float(count)
		var p = start_p + fwd * (length * t)
		var v_node = Node3D.new()
		v_node.name = "RailVisionPoint_%d" % i
		v_node.set("owner_id", shooter_id)
		v_node.set("owner_team", shooter_team)
		v_node.set("radius", 8.0)
		v_node.global_position = p
		vision_container.add_child(v_node)
		vision_sub_nodes.append(v_node)

func _physics_process(delta: float) -> void:
	if not is_server_authority():
		return
		
	tick_timer += delta
	if tick_timer >= TICK_INTERVAL:
		tick_timer = 0.0
		_apply_corridor_effects()

func _on_body_entered(body: Node) -> void:
	if not is_server_authority():
		return
	_apply_to_body(body, 0.0)

func _apply_corridor_effects() -> void:
	var bodies = get_overlapping_bodies()
	for b in bodies:
		_apply_to_body(b, dps * TICK_INTERVAL)

func _apply_to_body(body: Node, damage_amount: float) -> void:
	if not body or body.get("is_dead"):
		return
	if body.name == str(shooter_id):
		return
	if shooter_team > 0 and body.get("team_id") != null and body.team_id == shooter_team:
		return
		
	if damage_amount > 0.0 and body.has_method("take_damage"):
		body.take_damage(damage_amount, shooter_id, 1) # ActionType.ABILITY
		
	if body.has_method("apply_slow"):
		body.apply_slow(slow_duration, slow_percent)

func _on_lifetime_end() -> void:
	for vn in vision_sub_nodes:
		if is_instance_valid(vn):
			vn.queue_free()
	vision_sub_nodes.clear()
	queue_free()

func _exit_tree() -> void:
	for vn in vision_sub_nodes:
		if is_instance_valid(vn):
			vn.queue_free()
	vision_sub_nodes.clear()
