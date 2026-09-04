class_name SlowingDoTZone
extends Area3D

@export var radius: float = 2.2
@export var duration: float = 4.5
@export var damage_per_second: float = 0.0
@export var speed_boost_percent: float = 0.30
@export var speed_boost_duration: float = 2.0
@export var slow_percent: float = 0.35
@export var slow_duration: float = 1.5

var shooter_id: int = 0
var shooter_team: int = 0
var tick_timer: float = 0.0
const TICK_INTERVAL: float = 0.15

@onready var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D")
@onready var ring_instance: MeshInstance3D = get_node_or_null("RingInstance3D")
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")

func _ready() -> void:
	if collision_shape and collision_shape.shape is CylinderShape3D:
		collision_shape.shape.radius = radius
	elif collision_shape and collision_shape.shape is SphereShape3D:
		collision_shape.shape.radius = radius

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

	if is_server_authority():
		body_entered.connect(_on_body_entered)
		get_tree().create_timer(duration).timeout.connect(queue_free)

func is_server_authority() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()

func _physics_process(delta: float) -> void:
	if not is_server_authority():
		return
		
	tick_timer += delta
	if tick_timer >= TICK_INTERVAL:
		tick_timer = 0.0
		_apply_zone_effects()

func _on_body_entered(body: Node) -> void:
	if not is_server_authority():
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
		if speed_boost_percent > 0.0 and body.has_method("apply_speed_boost"):
			body.apply_speed_boost(speed_boost_duration, speed_boost_percent)
	else:
		if slow_percent > 0.0 and body.has_method("apply_slow"):
			body.apply_slow(slow_duration, slow_percent)
		if damage_per_second > 0.0 and body.has_method("take_damage"):
			var tick_damage = damage_per_second * TICK_INTERVAL
			body.take_damage(tick_damage, shooter_id, BasePlayer.ActionType.ABILITY)
			var players_container = get_tree().root.get_node_or_null("Main/Players")
			if players_container:
				var shooter = players_container.get_node_or_null(str(shooter_id))
				if shooter and shooter.has_method("_on_character_damage_dealt"):
					shooter._on_character_damage_dealt(body, tick_damage, BasePlayer.ActionType.ABILITY)
