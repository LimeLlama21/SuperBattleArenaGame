extends Area3D

@export var speed: float = 34.0
@export var damage: float = 22.0
@export var lifetime: float = 2.5

var shooter_id: int = 0
var direction: Vector3 = Vector3.FORWARD

func _ready() -> void:
	if direction != Vector3.ZERO:
		look_at(global_position + direction, Vector3.UP)

	if multiplayer.is_server():
		body_entered.connect(_on_body_entered)
		get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func _on_body_entered(body: Node) -> void:
	if not multiplayer.is_server():
		return
	
	if body.has_method("take_damage") and body.name != str(shooter_id):
		body.take_damage(damage)
		queue_free()
	elif body is StaticBody3D:
		queue_free()
