class_name TestProceduralAnimation
extends Node

## Unit & Integration Test Suite for the GDScript Procedural Animation System.
## Runs math, IK solver, locomotion engine, and rig generator checks.

func _ready() -> void:
	print("============================================================")
	print("RUNNING GDSCRIPT PROCEDURAL ANIMATION SYSTEM TESTS")
	print("============================================================")

	var success: bool = true
	success = success and test_math_curves()
	success = success and test_spring_damper()
	success = success and test_two_bone_ik()
	success = success and test_procedural_engine_evaluation()
	success = success and test_rig_generators()

	if success:
		print("============================================================")
		print("ALL PROCEDURAL ANIMATION TESTS PASSED SUCCESSFULLY! (GDScript)")
		print("============================================================")
	else:
		printerr("ERROR: Some procedural animation tests failed!")


func test_math_curves() -> bool:
	print("[Test 1/5] Verifying Procedural Curves & Interpolation...")

	# Smoothstep
	var s0 = ProceduralAnimMath.smooth_step(0.0)
	var s05 = ProceduralAnimMath.smooth_step(0.5)
	var s1 = ProceduralAnimMath.smooth_step(1.0)
	assert(is_equal_approx(s0, 0.0), "smooth_step(0) must be 0")
	assert(is_equal_approx(s05, 0.5), "smooth_step(0.5) must be 0.5")
	assert(is_equal_approx(s1, 1.0), "smooth_step(1) must be 1.0")

	# Parabolic lift
	var p0 = ProceduralAnimMath.parabolic_lift(0.0, 0.2)
	var p05 = ProceduralAnimMath.parabolic_lift(0.5, 0.2)
	var p1 = ProceduralAnimMath.parabolic_lift(1.0, 0.2)
	assert(is_equal_approx(p0, 0.0), "parabolic_lift(0) must be 0")
	assert(is_equal_approx(p05, 0.2), "parabolic_lift(0.5) must equal max_height")
	assert(is_equal_approx(p1, 0.0), "parabolic_lift(1) must be 0")

	# Cyclical phase
	var phase = ProceduralAnimMath.cyclical_phase(0.75, 1.0, 0.5)
	assert(is_equal_approx(phase, 0.25), "cyclical_phase offset wrap failed")

	print("  -> Curves & interpolation verified.")
	return true


func test_spring_damper() -> bool:
	print("[Test 2/5] Verifying 2nd-Order Spring-Mass-Damper Dynamics...")
	var spring = ProceduralAnimMath.SpringDamper3D.new(120.0, 14.0, 1.0)
	spring.reset(Vector3.ZERO)

	var target = Vector3(1.0, 0.0, 0.0)
	# Simulate 1 second of physics at 60 fps
	for _i in range(60):
		spring.update(target, 1.0 / 60.0)

	# After 1 second with 14 damping and 120 stiffness, position should have converged closely to target
	var dist = spring.position.distance_to(target)
	assert(dist < 0.05, "Spring failed to converge toward target: dist=%.4f" % dist)
	assert(not is_nan(spring.position.x), "Spring produced NaN")

	print("  -> Spring-damper converged cleanly without explosion (dist=%.4f)." % dist)
	return true


func test_two_bone_ik() -> bool:
	print("[Test 3/5] Verifying Analytical Two-Bone Inverse Kinematics...")
	var root = Vector3(0.0, 1.0, 0.0)
	var target = Vector3(0.0, 0.2, -0.3)
	var pole = Vector3(0.0, 0.6, -1.0) # Forward knee hint
	var len1 = 0.45
	var len2 = 0.45

	var res = ProceduralAnimMath.solve_two_bone_ik(root, target, pole, len1, len2)
	assert(res.is_reachable, "Target should be within reach")

	# Upper limb length check
	var d1 = root.distance_to(res.joint_position)
	assert(is_equal_approx(d1, len1), "Upper limb length mismatch: %.4f vs %.4f" % [d1, len1])

	# Lower limb length check
	var d2 = res.joint_position.distance_to(res.tip_position)
	assert(is_equal_approx(d2, len2), "Lower limb length mismatch: %.4f vs %.4f" % [d2, len2])

	# Knee should be displaced in the pole forward direction (-Z)
	assert(res.joint_position.z < root.z, "Knee failed to bend forward towards pole")

	print("  -> Two-bone IK solved: joint=(%.3f, %.3f, %.3f), tip=(%.3f, %.3f, %.3f)." % [
		res.joint_position.x, res.joint_position.y, res.joint_position.z,
		res.tip_position.x, res.tip_position.y, res.tip_position.z
	])
	return true


func test_procedural_engine_evaluation() -> bool:
	print("[Test 4/5] Evaluating Procedural Locomotion Engine across full gait cycle...")
	var engine = ProceduralAnimationEngine.new()
	var params = ProceduralAnimationEngine.GaitParameters.new()
	engine.reset(Vector3(0, 0.95, 0))

	# Run 60 frames (1 second) of active locomotion
	for frame in range(60):
		var time = frame / 60.0
		var pose = engine.evaluate(time, 1.0 / 60.0, 3.5, 4.0, params)

		assert(not is_nan(pose.hips_position.y), "NaN in hips position")
		assert(not is_nan(pose.left_foot_pos.z), "NaN in left foot pos")
		assert(not is_nan(pose.right_foot_pos.z), "NaN in right foot pos")
		assert(not is_nan(pose.left_hand_pos.z), "NaN in left hand pos")

		# Ensure vertical foot clearance happens during swing phase
		if pose.phase_l < 0.5:
			assert(pose.left_foot_pos.y >= -0.001, "Left foot dipped below ground during swing")

	print("  -> 60 frames evaluated cleanly without NaNs or numerical anomalies.")
	return true


func test_rig_generators() -> bool:
	print("[Test 5/5] Testing Procedural Rig Generators (Biped & Spider)...")

	var dummy_root = Node3D.new()
	add_child(dummy_root)

	# 1. Biped Mannequin
	var biped_refs = ProceduralRigGenerator.generate_biped_mannequin(dummy_root, "TestMannequin")
	assert(biped_refs.root != null, "Biped root is null")
	assert(biped_refs.hips != null, "Hips node is null")
	assert(biped_refs.leg_ik_l != null, "Left leg IK solver is null")
	assert(biped_refs.leg_ik_r != null, "Right leg IK solver is null")

	# Solve leg IK
	biped_refs.leg_ik_l.solve_and_apply()
	biped_refs.leg_ik_r.solve_and_apply()
	print("  -> Biped Mannequin created and IK executed.")

	# 2. Spider Rig
	var spider_refs = ProceduralRigGenerator.generate_spider_rig(dummy_root, 6, 0.6)
	assert(spider_refs.root != null, "Spider root is null")
	assert(spider_refs.legs.size() == 6, "Expected 6 legs, got %d" % spider_refs.legs.size())

	for leg in spider_refs.legs:
		assert(leg.ik_solver != null, "Spider leg IK solver is null")
		leg.ik_solver.solve_and_apply()
	print("  -> Spider 6-Leg Rig created and IK executed.")

	dummy_root.queue_free()
	return true
