class_name ProceduralDemoPlayer
extends CharacterBody3D

## Demo Player Controller for testing procedural animation locomotion.
## Handles WASD movement, jumping, sprinting, and camera tracking.

@export var walk_speed: float = 3.2
@export var run_speed: float = 6.8
@export var jump_velocity: float = 7.5
@export var rotation_speed: float = 14.0

@onready var locomotion_controller: ProceduralLocomotionController = $ProceduralLocomotionController

var gravity: float = 24.0


func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Get input direction
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move_dir: Vector3 = Vector3(input_dir.x, 0.0, input_dir.y).normalized()

	var is_sprinting: bool = Input.is_action_pressed("dash")
	var target_speed: float = run_speed if is_sprinting else walk_speed

	if move_dir.length() > 0.1:
		velocity.x = move_toward(velocity.x, move_dir.x * target_speed, 25.0 * delta)
		velocity.z = move_toward(velocity.z, move_dir.z * target_speed, 25.0 * delta)

		# Smoothly rotate character to face movement direction
		var target_rot_y: float = atan2(-move_dir.x, -move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot_y, rotation_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)

	move_and_slide()
