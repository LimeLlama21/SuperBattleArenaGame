class_name ProceduralAnimDemo
extends Node3D

## Demo Scene Manager for Procedural Animation System.
## Updates UI metrics, handles camera tracking, and provides interactive control buttons.

@onready var player: CharacterBody3D = $DemoPlayer
@onready var camera_mount: Node3D = $CameraMount
@onready var locomotion_controller: ProceduralLocomotionController = $DemoPlayer/ProceduralLocomotionController

@onready var speed_label: Label = $CanvasLayer/UI/Panel/VBox/SpeedLabel
@onready var state_label: Label = $CanvasLayer/UI/Panel/VBox/StateLabel
@onready var phase_label: Label = $CanvasLayer/UI/Panel/VBox/PhaseLabel
@onready var springs_btn: Button = $CanvasLayer/UI/Panel/VBox/SpringsButton
@onready var raycast_btn: Button = $CanvasLayer/UI/Panel/VBox/RaycastButton


func _ready() -> void:
	if springs_btn:
		springs_btn.pressed.connect(_on_toggle_springs)
	if raycast_btn:
		raycast_btn.pressed.connect(_on_toggle_raycast)
	_update_button_texts()


func _physics_process(delta: float) -> void:
	# Smooth camera follow
	if camera_mount and player:
		camera_mount.global_position = camera_mount.global_position.lerp(player.global_position, delta * 8.0)

	# Update UI telemetry
	if player and locomotion_controller:
		var h_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
		var state_str: String = "IDLE"
		if not player.is_on_floor():
			state_str = "AIRBORNE"
		elif h_speed > 4.5:
			state_str = "SPRINTING"
		elif h_speed > 0.2:
			state_str = "WALKING"

		if speed_label:
			speed_label.text = "Speed: %.2f m/s" % h_speed
		if state_label:
			state_label.text = "Gait State: %s" % state_str
		if phase_label and locomotion_controller.engine:
			phase_label.text = "Phase L: %.2f | Phase R: %.2f" % [
				locomotion_controller.engine.accumulated_phase,
				fmod(locomotion_controller.engine.accumulated_phase + 0.5, 1.0)
			]


func _on_toggle_springs() -> void:
	if locomotion_controller:
		locomotion_controller.use_springs = not locomotion_controller.use_springs
		_update_button_texts()


func _on_toggle_raycast() -> void:
	if locomotion_controller:
		locomotion_controller.enable_terrain_raycast = not locomotion_controller.enable_terrain_raycast
		_update_button_texts()


func _update_button_texts() -> void:
	if springs_btn and locomotion_controller:
		springs_btn.text = "Spring Dynamics: %s" % ("ON" if locomotion_controller.use_springs else "OFF")
	if raycast_btn and locomotion_controller:
		raycast_btn.text = "Terrain Raycast IK: %s" % ("ON" if locomotion_controller.enable_terrain_raycast else "OFF")
