extends Area3D

@export var speed: float = 55.0
@export var vision_radius: float = 8.0
@export var max_lifetime: float = 2.0

var shooter_id: int = 0
var shooter_team: int = 0
var direction: Vector3 = Vector3.FORWARD
var target_distance: float = 65.0
var distance_traveled: float = 0.0
var has_burst: bool = false

func _ready() -> void:
	if direction != Vector3.ZERO:
		var up_vec = Vector3.UP if abs(direction.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
		look_at(global_position + direction, up_vec)

	if multiplayer.is_server():
		body_entered.connect(_on_body_entered)
		get_tree().create_timer(max_lifetime).timeout.connect(_burst_and_free)

func _physics_process(delta: float) -> void:
	var move_step = speed * delta
	global_position += direction * move_step
	distance_traveled += move_step

	if distance_traveled >= target_distance:
		_burst_and_free()

func _on_body_entered(body: Node) -> void:
	if not multiplayer.is_server():
		return
	if body is StaticBody3D:
		_burst_and_free()

func _burst_and_free() -> void:
	if has_burst:
		return
	has_burst = true
	
	if multiplayer.is_server():
		var main_node = get_tree().root.get_node_or_null("Main")
		if main_node and main_node.has_method("spawn_vision_reveal_zone"):
			main_node.spawn_vision_reveal_zone(global_position, 12.0, 5.5, shooter_id, shooter_team)
			
	queue_free()
