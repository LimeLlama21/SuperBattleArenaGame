extends Area3D

@export var radius: float = 4.5
@export var duration: float = 4.0
@export var damage_per_second: float = 24.0
@export var slow_percent: float = 0.5
@export var slow_duration: float = 1.0

var shooter_id: int = 0
var shooter_team: int = 0
var tick_timer: float = 0.0
const TICK_INTERVAL: float = 0.4

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var ring_instance: MeshInstance3D = $RingInstance3D

func _ready() -> void:
	$CollisionShape3D.shape.radius = radius
	if mesh_instance and mesh_instance.mesh is CylinderMesh:
		mesh_instance.mesh.top_radius = radius
		mesh_instance.mesh.bottom_radius = radius
	if ring_instance:
		if ring_instance.mesh is TorusMesh:
			ring_instance.mesh.inner_radius = max(0.1, radius - 0.2)
			ring_instance.mesh.outer_radius = radius
		elif ring_instance.mesh is CylinderMesh:
			ring_instance.mesh.top_radius = radius
			ring_instance.mesh.bottom_radius = radius

	if multiplayer.is_server():
		get_tree().create_timer(duration).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
		
	tick_timer += delta
	if tick_timer >= TICK_INTERVAL:
		tick_timer = 0.0
		_apply_hazard_tick()

func _apply_hazard_tick() -> void:
	var tick_damage = damage_per_second * TICK_INTERVAL
	for body in get_overlapping_bodies():
		if body.has_method("take_damage") and not body.get("is_dead") and body.name != str(shooter_id):
			if shooter_team > 0 and body.get("team_id") != null and body.team_id == shooter_team:
				continue
			body.take_damage(tick_damage, shooter_id, 1) # ActionType.ABILITY
			if body.has_method("apply_slow"):
				body.apply_slow(slow_duration, slow_percent)
