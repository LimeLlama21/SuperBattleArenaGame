class_name MeleeStrikeEffect
extends "res://ability/effects/ability_effect.gd"

func _init() -> void:
	effect_name = "MeleeStrike"

func execute_effect_server(caster: Node, origin: Vector3, direction: Vector3, _target_pos: Vector3, charge_ratio: float = 0.0) -> void:
	setup()
	fire_trigger("OnCast", caster, null, {"charge_ratio": charge_ratio})
	
	if not hitbox_instance:
		return
	
	var tree = caster.get_tree() if (is_instance_valid(caster) and caster.is_inside_tree()) else null
	var hit_origin = caster.global_position if (is_instance_valid(caster) and caster.is_inside_tree()) else origin
	var targets = hitbox_instance.get_targets_in_hitbox(caster, hit_origin, direction, tree) if tree else []
	var hit_data = {
		"direction": direction,
		"charge_ratio": charge_ratio,
		"origin": hit_origin,
		"slot_key": slot_key,
		"ability_id": ability_id
	}
	
	for target in targets:
		if is_instance_valid(caster) and caster.has_method("on_melee_strike_hit"):
			caster.on_melee_strike_hit(target, hit_data)
		fire_trigger("OnHitEnemy", caster, target, hit_data)

func execute_effect_client(caster: Node, origin: Vector3, direction: Vector3, target_pos: Vector3, _charge_ratio: float = 0.0) -> void:
	if not is_instance_valid(caster):
		return
	if caster.has_signal("attack_performed"):
		caster.attack_performed.emit("Melee")

	# Ensure legacy placeholder indicator box meshes are hidden so they never double-render
	var melee_vis = caster.get_node_or_null("MeleeVisual")
	if melee_vis:
		melee_vis.visible = false
	var ab1_vis = caster.get_node_or_null("AbilityOneVisual")
	if ab1_vis:
		ab1_vis.visible = false
	var ab2_vis = caster.get_node_or_null("AbilityTwoVisual")
	if ab2_vis:
		ab2_vis.visible = false

	# Play dynamic, animated melee visual effect
	_spawn_melee_attack_visual(caster, origin, direction, target_pos)

func _spawn_melee_attack_visual(caster: Node, origin: Vector3, direction: Vector3, _target_pos: Vector3) -> void:
	var tree = caster.get_tree() if (is_instance_valid(caster) and caster.is_inside_tree()) else null
	if not tree:
		return

	var ab_id = ability_id
	var parent_node = get_parent()
	if ab_id.is_empty() and parent_node and "ability_id" in parent_node:
		ab_id = parent_node.ability_id

	var radius = hitbox_radius if hitbox_radius > 0.0 else (hitbox_instance.radius if (hitbox_instance and "radius" in hitbox_instance) else 3.5)
	var angle_deg = hitbox_angle_deg if hitbox_angle_deg > 0.0 else (hitbox_instance.angle_deg if (hitbox_instance and "angle_deg" in hitbox_instance) else 110.0)
	var facing = direction.normalized() if direction.length_squared() > 0.001 else -caster.global_transform.basis.z.normalized()
	facing.y = 0.0
	facing = facing.normalized()

	match ab_id:
		"crush_slam":
			_play_slam_wave_visual(caster, radius, angle_deg, facing, Color(1.0, 0.35, 0.1, 0.95), Color(1.0, 0.45, 0.1, 1.0) * 4.5)
		"crush_fan_stun":
			_play_slam_wave_visual(caster, radius, angle_deg, facing, Color(1.0, 0.85, 0.2, 0.95), Color(1.0, 0.8, 0.1, 1.0) * 5.0)
		"crush_ground_stomp":
			_play_stomp_shockwave_visual(caster, radius, Color(1.0, 0.5, 0.1, 0.9), Color(1.0, 0.45, 0.1, 1.0) * 4.0)
		"dive_slash":
			_play_crescent_slash_visual(caster, radius, angle_deg, facing, Color(1.0, 0.2, 0.85, 0.95), Color(1.0, 0.2, 0.9, 1.0) * 4.5)
		"dive_heavy_cleave":
			_play_crescent_slash_visual(caster, radius, angle_deg, facing, Color(0.2, 0.9, 1.0, 0.95), Color(0.2, 0.95, 1.0, 1.0) * 5.0)
		"reaper_slash":
			_play_crescent_slash_visual(caster, radius, angle_deg, facing, Color(0.65, 0.15, 0.95, 0.95), Color(0.7, 0.2, 1.0, 1.0) * 5.0)
		"reaper_cull_the_weak":
			_play_scythe_spin_visual(caster, radius, 3.2, Color(0.85, 0.15, 0.45, 0.95), Color(0.9, 0.2, 0.5, 1.0) * 5.0)
		"morrigan_banshee_cry":
			_play_sonic_shriek_visual(caster, radius, angle_deg, facing, Color(0.75, 0.1, 0.9, 0.9), Color(0.8, 0.2, 1.0, 1.0) * 4.5)
		_:
			var is_full_circle = (hitbox_type == 6 or (hitbox_instance and "shape_type" in hitbox_instance and hitbox_instance.shape_type in [AbilityPipeline.HitboxShape.CIRCLE, AbilityPipeline.HitboxShape.CYLINDER])) and (not hitbox_instance or not ("angle_deg" in hitbox_instance) or hitbox_instance.angle_deg >= 360.0)
			if is_full_circle:
				_play_stomp_shockwave_visual(caster, radius, Color(1.0, 0.6, 0.2, 0.9), Color(1.0, 0.5, 0.1, 1.0) * 4.0)
			else:
				_play_crescent_slash_visual(caster, radius, angle_deg, facing, Color(0.3, 0.85, 1.0, 0.95), Color(0.3, 0.9, 1.0, 1.0) * 4.5)

func _play_crescent_slash_visual(caster: Node, radius: float, angle_deg: float, facing: Vector3, albedo_col: Color, emission_col: Color) -> void:
	var tree = caster.get_tree() if is_instance_valid(caster) else null
	if not tree or not tree.root:
		return

	var mesh_inst = MeshInstance3D.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_rad = deg_to_rad(angle_deg * 0.5)
	var segments = max(18, int(angle_deg / 4.0))
	var inner_r = radius * 0.45

	for i in range(segments):
		var t0 = -half_rad + (float(i) / segments) * (half_rad * 2.0)
		var t1 = -half_rad + (float(i + 1) / segments) * (half_rad * 2.0)

		var in0 = Vector3(sin(t0) * inner_r, 0, -cos(t0) * inner_r)
		var out0 = Vector3(sin(t0) * radius, 0, -cos(t0) * radius)
		var in1 = Vector3(sin(t1) * inner_r, 0, -cos(t1) * inner_r)
		var out1 = Vector3(sin(t1) * radius, 0, -cos(t1) * radius)

		st.add_vertex(in0)
		st.add_vertex(out0)
		st.add_vertex(out1)

		st.add_vertex(in0)
		st.add_vertex(out1)
		st.add_vertex(in1)

	mesh_inst.mesh = st.commit()

	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = albedo_col
	mat.emission_enabled = true
	mat.emission = emission_col
	mat.emission_energy_multiplier = 4.0
	mesh_inst.material_override = mat

	mesh_inst.top_level = true
	tree.root.add_child(mesh_inst)
	mesh_inst.global_position = caster.global_position + Vector3(0, 0.75, 0)
	if facing.length_squared() > 0.001:
		mesh_inst.look_at(mesh_inst.global_position + facing, Vector3.UP)

	mesh_inst.scale = Vector3(0.35, 1.0, 0.35)
	var tween = tree.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh_inst, "scale", Vector3(1.06, 1.0, 1.06), 0.09).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(mesh_inst.queue_free)

func _play_slam_wave_visual(caster: Node, radius: float, angle_deg: float, facing: Vector3, albedo_col: Color, emission_col: Color) -> void:
	var tree = caster.get_tree() if is_instance_valid(caster) else null
	if not tree or not tree.root:
		return

	var mesh_inst = MeshInstance3D.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_rad = deg_to_rad(angle_deg * 0.5)
	var segments = max(18, int(angle_deg / 4.0))
	var center = Vector3.ZERO

	for i in range(segments):
		var t0 = -half_rad + (float(i) / segments) * (half_rad * 2.0)
		var t1 = -half_rad + (float(i + 1) / segments) * (half_rad * 2.0)

		var p0 = center
		var p1 = Vector3(sin(t0) * radius, 0.12, -cos(t0) * radius)
		var p2 = Vector3(sin(t1) * radius, 0.12, -cos(t1) * radius)

		st.add_vertex(p0)
		st.add_vertex(p1)
		st.add_vertex(p2)

	mesh_inst.mesh = st.commit()

	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = albedo_col
	mat.emission_enabled = true
	mat.emission = emission_col
	mat.emission_energy_multiplier = 4.5
	mesh_inst.material_override = mat

	mesh_inst.top_level = true
	tree.root.add_child(mesh_inst)
	mesh_inst.global_position = Vector3(caster.global_position.x, 0.08, caster.global_position.z)
	if facing.length_squared() > 0.001:
		mesh_inst.look_at(mesh_inst.global_position + facing, Vector3.UP)

	mesh_inst.scale = Vector3(0.15, 1.0, 0.15)
	var tween = tree.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh_inst, "scale", Vector3(1.05, 1.2, 1.05), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(mesh_inst.queue_free)

func _play_stomp_shockwave_visual(caster: Node, radius: float, albedo_col: Color, emission_col: Color) -> void:
	var tree = caster.get_tree() if is_instance_valid(caster) else null
	if not tree or not tree.root:
		return

	var mesh_inst = MeshInstance3D.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var segments = 48
	var inner_r = max(0.1, radius - 1.2)
	for i in range(segments):
		var t0 = (float(i) / segments) * TAU
		var t1 = (float(i + 1) / segments) * TAU

		var in0 = Vector3(cos(t0) * inner_r, 0.08, sin(t0) * inner_r)
		var out0 = Vector3(cos(t0) * radius, 0.08, sin(t0) * radius)
		var in1 = Vector3(cos(t1) * inner_r, 0.08, sin(t1) * inner_r)
		var out1 = Vector3(cos(t1) * radius, 0.08, sin(t1) * radius)

		st.add_vertex(in0)
		st.add_vertex(out0)
		st.add_vertex(out1)

		st.add_vertex(in0)
		st.add_vertex(out1)
		st.add_vertex(in1)

	mesh_inst.mesh = st.commit()

	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = albedo_col
	mat.emission_enabled = true
	mat.emission = emission_col
	mat.emission_energy_multiplier = 4.0
	mesh_inst.material_override = mat

	mesh_inst.top_level = true
	tree.root.add_child(mesh_inst)
	mesh_inst.global_position = Vector3(caster.global_position.x, 0.08, caster.global_position.z)

	mesh_inst.scale = Vector3(0.15, 1.0, 0.15)
	var tween = tree.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh_inst, "scale", Vector3(1.05, 1.0, 1.05), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(mesh_inst.queue_free)

func _play_scythe_spin_visual(caster: Node, outer_r: float, inner_r: float, albedo_col: Color, emission_col: Color) -> void:
	var tree = caster.get_tree() if is_instance_valid(caster) else null
	if not tree or not tree.root:
		return

	var mesh_inst = MeshInstance3D.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var segments = 36
	for i in range(segments):
		var t0 = (float(i) / segments) * TAU
		var t1 = (float(i + 1) / segments) * TAU

		var in0 = Vector3(cos(t0) * inner_r, 0, sin(t0) * inner_r)
		var out0 = Vector3(cos(t0) * outer_r, 0, sin(t0) * outer_r)
		var in1 = Vector3(cos(t1) * inner_r, 0, sin(t1) * inner_r)
		var out1 = Vector3(cos(t1) * outer_r, 0, sin(t1) * outer_r)

		st.add_vertex(in0)
		st.add_vertex(out0)
		st.add_vertex(out1)

		st.add_vertex(in0)
		st.add_vertex(out1)
		st.add_vertex(in1)

	mesh_inst.mesh = st.commit()

	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = albedo_col
	mat.emission_enabled = true
	mat.emission = emission_col
	mat.emission_energy_multiplier = 5.0
	mesh_inst.material_override = mat

	mesh_inst.top_level = true
	tree.root.add_child(mesh_inst)
	mesh_inst.global_position = caster.global_position + Vector3(0, 0.75, 0)

	mesh_inst.scale = Vector3(0.7, 1.0, 0.7)
	var tween = tree.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh_inst, "scale", Vector3(1.05, 1.0, 1.05), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh_inst, "rotation:y", mesh_inst.rotation.y + TAU, 0.22)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(mesh_inst.queue_free)

func _play_sonic_shriek_visual(caster: Node, radius: float, angle_deg: float, facing: Vector3, albedo_col: Color, emission_col: Color) -> void:
	var tree = caster.get_tree() if is_instance_valid(caster) else null
	if not tree or not tree.root:
		return

	var mesh_inst = MeshInstance3D.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_rad = deg_to_rad(angle_deg * 0.5)
	var segments = max(18, int(angle_deg / 4.0))
	var inner_r = radius * 0.7

	for i in range(segments):
		var t0 = -half_rad + (float(i) / segments) * (half_rad * 2.0)
		var t1 = -half_rad + (float(i + 1) / segments) * (half_rad * 2.0)

		var in0 = Vector3(sin(t0) * inner_r, 0, -cos(t0) * inner_r)
		var out0 = Vector3(sin(t0) * radius, 0, -cos(t0) * radius)
		var in1 = Vector3(sin(t1) * inner_r, 0, -cos(t1) * inner_r)
		var out1 = Vector3(sin(t1) * radius, 0, -cos(t1) * radius)

		st.add_vertex(in0)
		st.add_vertex(out0)
		st.add_vertex(out1)

		st.add_vertex(in0)
		st.add_vertex(out1)
		st.add_vertex(in1)

	mesh_inst.mesh = st.commit()

	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = albedo_col
	mat.emission_enabled = true
	mat.emission = emission_col
	mat.emission_energy_multiplier = 4.5
	mesh_inst.material_override = mat

	mesh_inst.top_level = true
	tree.root.add_child(mesh_inst)
	mesh_inst.global_position = caster.global_position + Vector3(0, 0.9, 0)
	if facing.length_squared() > 0.001:
		mesh_inst.look_at(mesh_inst.global_position + facing, Vector3.UP)

	mesh_inst.scale = Vector3(0.2, 1.0, 0.2)
	var tween = tree.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh_inst, "scale", Vector3(1.05, 1.0, 1.05), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(mesh_inst.queue_free)
