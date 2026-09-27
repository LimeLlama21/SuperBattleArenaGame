class_name ProceduralSpiderController
extends Node3D

## Multi-Legged Procedural Locomotion Controller for Arachnids / Mechs.
## Implements alternating tripod gait with adaptive stepping, body height stabilization,
## and 2-bone IK on each leg.

@export var leg_count: int = 6
@export var step_distance_threshold: float = 0.45
@export var step_lift_height: float = 0.18
@export var step_duration: float = 0.22
@export var body_ride_height: float = 0.45

var spider_refs: ProceduralRigGenerator.SpiderRigReferences
var last_root_pos: Vector3 = Vector3.ZERO
var parent_character: CharacterBody3D


func _ready() -> void:
	var p = get_parent()
	if p is CharacterBody3D:
		parent_character = p

	spider_refs = ProceduralRigGenerator.generate_spider_rig(self, leg_count, 0.65)
	last_root_pos = global_position


func _physics_process(delta: float) -> void:
	if delta <= 0.0 or not spider_refs:
		return

	var char_vel: Vector3
	if parent_character:
		char_vel = parent_character.velocity
	else:
		char_vel = (global_position - last_root_pos) / delta
		last_root_pos = global_position

	var move_speed: float = Vector2(char_vel.x, char_vel.z).length()
	var move_dir: Vector3 = char_vel.normalized() if move_speed > 0.1 else Vector3.ZERO

	# Check which leg groups can step (alternating tripod)
	var any_stepping_0: bool = false
	var any_stepping_1: bool = false
	for leg in spider_refs.legs:
		if leg.is_stepping:
			if leg.phase_group == 0:
				any_stepping_0 = true
			else:
				any_stepping_1 = true

	# Update legs
	for leg in spider_refs.legs:
		# Calculate ideal rest foot position in world coordinates
		var ideal_world_foot: Vector3 = global_transform * leg.default_planted_pos
		# Lead target foot position ahead of movement direction
		if move_speed > 0.1:
			ideal_world_foot += move_dir * (step_distance_threshold * 0.75)

		var dist_to_ideal: float = leg.current_planted_pos.distance_to(ideal_world_foot)

		# Trigger step if distance exceeds threshold and opposite group isn't stepping
		var can_step: bool = (leg.phase_group == 0 and not any_stepping_1) or (leg.phase_group == 1 and not any_stepping_0)
		if not leg.is_stepping and dist_to_ideal > step_distance_threshold and can_step:
			leg.is_stepping = true
			leg.step_progress = 0.0
			leg.target_step_pos = ideal_world_foot

		if leg.is_stepping:
			leg.step_progress += (delta / step_duration)
			var p: float = clampf(leg.step_progress, 0.0, 1.0)
			var t: float = ProceduralAnimMath.smooth_step(p)

			# Horizontal travel
			var current_pos: Vector3 = leg.current_planted_pos.lerp(leg.target_step_pos, t)
			# Parabolic vertical foot clearance
			current_pos.y += ProceduralAnimMath.parabolic_lift(p, step_lift_height)

			leg.target_marker.global_position = current_pos

			if leg.step_progress >= 1.0:
				leg.is_stepping = false
				leg.current_planted_pos = leg.target_step_pos
		else:
			leg.target_marker.global_position = leg.current_planted_pos

		# Solve IK for leg
		if leg.ik_solver:
			leg.ik_solver.solve_and_apply()
