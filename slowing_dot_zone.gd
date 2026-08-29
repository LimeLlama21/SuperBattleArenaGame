extends Area3D

@export var radius: float = 2.2
@export var duration: float = 4.5
@export var speed_boost_percent: float = 0.30
@export var speed_boost_duration: float = 2.0
@export var slow_percent: float = 0.35
@export var slow_duration: float = 1.5

var shooter_id: int = 0
var shooter_team: int = 0
var tick_timer: float = 0.0
const TICK_INTERVAL: float = 0.15

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var ring_instance: MeshInstance3D = $RingInstance3D

func _ready() -> void:
	$CollisionShape3D.shape.radius = radius
	if mesh_instance and mesh_instance.mesh is CylinderMesh:
		mesh_instance.mesh.top_radius = max(0.1, radius - 0.2)
		mesh_instance.mesh.bottom_radius = max(0.1, radius - 0.2)
	if ring_instance:
		if ring_instance.mesh is TorusMesh:
			ring_instance.mesh.inner_radius = max(0.1, radius - 0.2)
			ring_instance.mesh.outer_radius = radius
		elif ring_instance.mesh is CylinderMesh:
			ring_instance.mesh.top_radius = radius
			ring_instance.mesh.bottom_radius = radius

	if multiplayer.is_server():
		body_entered.connect(_on_body_entered)
		get_tree().create_timer(duration).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
		
	tick_timer += delta
	if tick_timer >= TICK_INTERVAL:
		tick_timer = 0.0
		_apply_zone_effects()

func _on_body_entered(body: Node) -> void:
	if not multiplayer.is_server():
		return
	_apply_effect_to_body(body)

func _apply_zone_effects() -> void:
	for body in get_overlapping_bodies():
		_apply_effect_to_body(body)

func _apply_effect_to_body(body: Node) -> void:
	if not is_instance_valid(body) or body.get("is_dead"):
		return
		
	var is_ally = (body.name == str(shooter_id)) or (shooter_team > 0 and body.get("team_id") != null and body.team_id == shooter_team)
	
	if is_ally:
		if body.has_method("apply_speed_boost"):
			body.apply_speed_boost(speed_boost_duration, speed_boost_percent)
	else:
		if body.has_method("apply_slow"):
			body.apply_slow(slow_duration, slow_percent)
