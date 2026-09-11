extends Node3D

@export var radius: float = 12.0
@export var lifetime: float = 5.5
var owner_id: int = 0
var owner_team: int = 0

var current_time: float = 0.0

@onready var ring_mesh: MeshInstance3D = get_node_or_null("RingMesh")

func _ready() -> void:
	if is_server_authority():
		get_tree().create_timer(lifetime).timeout.connect(queue_free)

func is_server_authority() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()

func _process(delta: float) -> void:
	current_time += delta
	if ring_mesh:
		ring_mesh.rotation.y += delta * 1.5
		# Subtle pulse
		var pulse = 1.0 + sin(current_time * 4.0) * 0.05
		ring_mesh.scale = Vector3(pulse, 1.0, pulse)
