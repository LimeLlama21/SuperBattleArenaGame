class_name AbilityIndicator
extends Node3D

# Procedural visual indicator system for ability hitboxes, ranges, and target zones

static func create_sector_indicator(radius: float, angle_deg: float, fill_color: Color, border_color: Color) -> Node3D:
	var root = Node3D.new()
	root.name = "SectorIndicator"
	
	var mesh_inst = MeshInstance3D.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var half_rad = deg_to_rad(angle_deg * 0.5)
	var segments = max(18, int(angle_deg / 3.5))
	var center = Vector3(0, 0.06, 0)
	
	for i in range(segments):
		var t0 = -half_rad + (float(i) / segments) * (half_rad * 2.0)
		var t1 = -half_rad + (float(i + 1) / segments) * (half_rad * 2.0)
		
		var p0 = center
		var p1 = Vector3(sin(t0) * radius, 0.06, -cos(t0) * radius)
		var p2 = Vector3(sin(t1) * radius, 0.06, -cos(t1) * radius)
		
		st.set_color(fill_color)
		st.add_vertex(p0)
		st.set_color(fill_color)
		st.add_vertex(p1)
		st.set_color(fill_color)
		st.add_vertex(p2)

	var fill_mat = StandardMaterial3D.new()
	fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.albedo_color = fill_color
	fill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fill_mat.vertex_color_use_as_albedo = true
	fill_mat.no_depth_test = true
	
	mesh_inst.mesh = st.commit()
	mesh_inst.material_override = fill_mat
	root.add_child(mesh_inst)
	
	# Border line
	var line_mesh_inst = MeshInstance3D.new()
	var st_line = SurfaceTool.new()
	st_line.begin(Mesh.PRIMITIVE_LINE_STRIP)
	st_line.set_color(border_color)
	st_line.add_vertex(center)
	for i in range(segments + 1):
		var t = -half_rad + (float(i) / segments) * (half_rad * 2.0)
		st_line.add_vertex(Vector3(sin(t) * radius, 0.08, -cos(t) * radius))
	st_line.add_vertex(center)
	
	var line_mat = StandardMaterial3D.new()
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = border_color
	line_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	line_mat.no_depth_test = true
	
	line_mesh_inst.mesh = st_line.commit()
	line_mesh_inst.material_override = line_mat
	root.add_child(line_mesh_inst)
	
	return root

static func create_circle_indicator(radius: float, fill_color: Color, border_color: Color) -> Node3D:
	var root = Node3D.new()
	root.name = "CircleIndicator"
	
	var mesh_inst = MeshInstance3D.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var segments = 56
	var center = Vector3(0, 0.06, 0)
	
	for i in range(segments):
		var t0 = (float(i) / segments) * TAU
		var t1 = (float(i + 1) / segments) * TAU
		
		var p0 = center
		var p1 = Vector3(cos(t0) * radius, 0.06, sin(t0) * radius)
		var p2 = Vector3(cos(t1) * radius, 0.06, sin(t1) * radius)
		
		st.set_color(fill_color)
		st.add_vertex(p0)
		st.set_color(fill_color)
		st.add_vertex(p1)
		st.set_color(fill_color)
		st.add_vertex(p2)
		
	var fill_mat = StandardMaterial3D.new()
	fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.albedo_color = fill_color
	fill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fill_mat.vertex_color_use_as_albedo = true
	fill_mat.no_depth_test = true
	
	mesh_inst.mesh = st.commit()
	mesh_inst.material_override = fill_mat
	root.add_child(mesh_inst)
	
	# Border ring
	var line_mesh_inst = MeshInstance3D.new()
	var st_line = SurfaceTool.new()
	st_line.begin(Mesh.PRIMITIVE_LINE_STRIP)
	st_line.set_color(border_color)
	for i in range(segments + 1):
		var t = (float(i) / segments) * TAU
		st_line.add_vertex(Vector3(cos(t) * radius, 0.08, sin(t) * radius))
		
	var line_mat = StandardMaterial3D.new()
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = border_color
	line_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	line_mat.no_depth_test = true
	
	line_mesh_inst.mesh = st_line.commit()
	line_mesh_inst.material_override = line_mat
	root.add_child(line_mesh_inst)
	
	return root

static func create_line_indicator(length: float, width: float, fill_color: Color, border_color: Color, has_end_circle: bool = false, end_circle_radius: float = 1.0, is_horizontal_line: bool = false) -> Node3D:
	var root = Node3D.new()
	root.name = "LineIndicator"
	
	var mesh_inst = MeshInstance3D.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var p0: Vector3
	var p1: Vector3
	var p2: Vector3
	var p3: Vector3
	
	if is_horizontal_line:
		var half_l = length * 0.5
		var half_w = width * 0.5
		p0 = Vector3(-half_l, 0.06, -half_w)
		p1 = Vector3(half_l, 0.06, -half_w)
		p2 = Vector3(half_l, 0.06, half_w)
		p3 = Vector3(-half_l, 0.06, half_w)
	else:
		var half_w = width * 0.5
		p0 = Vector3(-half_w, 0.06, 0)
		p1 = Vector3(half_w, 0.06, 0)
		p2 = Vector3(half_w, 0.06, -length)
		p3 = Vector3(-half_w, 0.06, -length)
	
	st.set_color(fill_color)
	st.add_vertex(p0)
	st.set_color(fill_color)
	st.add_vertex(p1)
	st.set_color(fill_color)
	st.add_vertex(p2)
	
	st.set_color(fill_color)
	st.add_vertex(p0)
	st.set_color(fill_color)
	st.add_vertex(p2)
	st.set_color(fill_color)
	st.add_vertex(p3)
	
	var fill_mat = StandardMaterial3D.new()
	fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.albedo_color = fill_color
	fill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fill_mat.vertex_color_use_as_albedo = true
	fill_mat.no_depth_test = true
	
	mesh_inst.mesh = st.commit()
	mesh_inst.material_override = fill_mat
	root.add_child(mesh_inst)
	
	# Border lines
	var line_mesh_inst = MeshInstance3D.new()
	var st_line = SurfaceTool.new()
	st_line.begin(Mesh.PRIMITIVE_LINE_STRIP)
	st_line.set_color(border_color)
	st_line.add_vertex(p0 + Vector3(0, 0.02, 0))
	st_line.add_vertex(p1 + Vector3(0, 0.02, 0))
	st_line.add_vertex(p2 + Vector3(0, 0.02, 0))
	st_line.add_vertex(p3 + Vector3(0, 0.02, 0))
	st_line.add_vertex(p0 + Vector3(0, 0.02, 0))
	
	var line_mat = StandardMaterial3D.new()
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = border_color
	line_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	line_mat.no_depth_test = true
	
	line_mesh_inst.mesh = st_line.commit()
	line_mesh_inst.material_override = line_mat
	root.add_child(line_mesh_inst)
	
	if has_end_circle:
		var end_circle = create_circle_indicator(end_circle_radius, fill_color, border_color)
		end_circle.position = Vector3(0, 0, -length)
		root.add_child(end_circle)
		
	return root

static func create_ring_indicator(radius: float, border_color: Color) -> MeshInstance3D:
	var line_mesh_inst = MeshInstance3D.new()
	var st_line = SurfaceTool.new()
	st_line.begin(Mesh.PRIMITIVE_LINE_STRIP)
	st_line.set_color(border_color)
	var segments = 64
	for i in range(segments + 1):
		var t = (float(i) / segments) * TAU
		st_line.add_vertex(Vector3(cos(t) * radius, 0.05, sin(t) * radius))
		
	var line_mat = StandardMaterial3D.new()
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = border_color
	line_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	line_mat.no_depth_test = true
	
	line_mesh_inst.mesh = st_line.commit()
	line_mesh_inst.material_override = line_mat
	return line_mesh_inst

static func create_donut_indicator(inner_radius: float, outer_radius: float, outer_fill_color: Color, outer_border_color: Color, inner_fill_color: Color = Color(0, 0, 0, 0), inner_border_color: Color = Color.WHITE) -> Node3D:
	var root = Node3D.new()
	root.name = "DonutIndicator"
	
	var mesh_inst = MeshInstance3D.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var segments = 64
	for i in range(segments):
		var t0 = (float(i) / segments) * TAU
		var t1 = (float(i + 1) / segments) * TAU
		
		var p0_in = Vector3(cos(t0) * inner_radius, 0.06, sin(t0) * inner_radius)
		var p1_in = Vector3(cos(t1) * inner_radius, 0.06, sin(t1) * inner_radius)
		var p0_out = Vector3(cos(t0) * outer_radius, 0.06, sin(t0) * outer_radius)
		var p1_out = Vector3(cos(t1) * outer_radius, 0.06, sin(t1) * outer_radius)
		
		st.set_color(outer_fill_color)
		st.add_vertex(p0_in)
		st.set_color(outer_fill_color)
		st.add_vertex(p0_out)
		st.set_color(outer_fill_color)
		st.add_vertex(p1_out)
		
		st.set_color(outer_fill_color)
		st.add_vertex(p0_in)
		st.set_color(outer_fill_color)
		st.add_vertex(p1_out)
		st.set_color(outer_fill_color)
		st.add_vertex(p1_in)

	if inner_fill_color.a > 0.0:
		var center = Vector3(0, 0.05, 0)
		for i in range(segments):
			var t0 = (float(i) / segments) * TAU
			var t1 = (float(i + 1) / segments) * TAU
			var p1 = Vector3(cos(t0) * inner_radius, 0.05, sin(t0) * inner_radius)
			var p2 = Vector3(cos(t1) * inner_radius, 0.05, sin(t1) * inner_radius)
			st.set_color(inner_fill_color)
			st.add_vertex(center)
			st.set_color(inner_fill_color)
			st.add_vertex(p1)
			st.set_color(inner_fill_color)
			st.add_vertex(p2)

	var fill_mat = StandardMaterial3D.new()
	fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fill_mat.vertex_color_use_as_albedo = true
	fill_mat.no_depth_test = true
	
	mesh_inst.mesh = st.commit()
	mesh_inst.material_override = fill_mat
	root.add_child(mesh_inst)
	
	var outer_ring = create_ring_indicator(outer_radius, outer_border_color)
	outer_ring.position.y = 0.02
	root.add_child(outer_ring)
	
	var inner_ring = create_ring_indicator(inner_radius, inner_border_color)
	inner_ring.position.y = 0.02
	root.add_child(inner_ring)
	
	return root

static func create_box_indicator(width: float, length: float, fill_color: Color, border_color: Color) -> Node3D:
	var root = Node3D.new()
	root.name = "BoxIndicator"
	
	var mesh_inst = MeshInstance3D.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var half_w = width * 0.5
	var half_l = length * 0.5
	var p0 = Vector3(-half_w, 0.06, -half_l)
	var p1 = Vector3(half_w, 0.06, -half_l)
	var p2 = Vector3(half_w, 0.06, half_l)
	var p3 = Vector3(-half_w, 0.06, half_l)
	
	st.set_color(fill_color)
	st.add_vertex(p0)
	st.set_color(fill_color)
	st.add_vertex(p1)
	st.set_color(fill_color)
	st.add_vertex(p2)
	
	st.set_color(fill_color)
	st.add_vertex(p0)
	st.set_color(fill_color)
	st.add_vertex(p2)
	st.set_color(fill_color)
	st.add_vertex(p3)
	
	var fill_mat = StandardMaterial3D.new()
	fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.albedo_color = fill_color
	fill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fill_mat.vertex_color_use_as_albedo = true
	fill_mat.no_depth_test = true
	
	mesh_inst.mesh = st.commit()
	mesh_inst.material_override = fill_mat
	root.add_child(mesh_inst)
	
	# Border lines
	var line_mesh_inst = MeshInstance3D.new()
	var st_line = SurfaceTool.new()
	st_line.begin(Mesh.PRIMITIVE_LINE_STRIP)
	st_line.set_color(border_color)
	st_line.add_vertex(p0 + Vector3(0, 0.02, 0))
	st_line.add_vertex(p1 + Vector3(0, 0.02, 0))
	st_line.add_vertex(p2 + Vector3(0, 0.02, 0))
	st_line.add_vertex(p3 + Vector3(0, 0.02, 0))
	st_line.add_vertex(p0 + Vector3(0, 0.02, 0))
	
	var line_mat = StandardMaterial3D.new()
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = border_color
	line_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	line_mat.no_depth_test = true
	
	line_mesh_inst.mesh = st_line.commit()
	line_mesh_inst.material_override = line_mat
	root.add_child(line_mesh_inst)
	
	return root

static func create_arc_trajectory_indicator(aoe_radius: float, fill_color: Color, border_color: Color) -> Node3D:
	var root = Node3D.new()
	root.name = "ArcTrajectoryIndicator"
	root.top_level = true
	
	# Endpoint circle
	var circle = create_circle_indicator(aoe_radius, fill_color, border_color)
	circle.name = "EndpointCircle"
	root.add_child(circle)
	
	# Parabolic Arc Line Mesh
	var line_mesh_inst = MeshInstance3D.new()
	line_mesh_inst.name = "ArcLineMesh"
	var line_mat = StandardMaterial3D.new()
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = border_color
	line_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	line_mat.no_depth_test = true
	line_mesh_inst.material_override = line_mat
	root.add_child(line_mesh_inst)
	
	return root

static func update_arc_trajectory_indicator(indicator: Node3D, start_pos: Vector3, end_pos: Vector3, apex_height: float) -> void:
	if not is_instance_valid(indicator):
		return
	
	var circle = indicator.get_node_or_null("EndpointCircle")
	if circle:
		circle.global_position = Vector3(end_pos.x, 0.06, end_pos.z)
		circle.rotation = Vector3.ZERO
		
	var line_mesh_inst = indicator.get_node_or_null("ArcLineMesh") as MeshInstance3D
	if line_mesh_inst:
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_LINE_STRIP)
		var segments = 24
		var inv_trans = indicator.global_transform.affine_inverse()
		for i in range(segments + 1):
			var t = float(i) / float(segments)
			var current_xz = start_pos.lerp(end_pos, t)
			var current_y = lerp(start_pos.y, end_pos.y, t) + 4.0 * apex_height * t * (1.0 - t)
			var world_pt = Vector3(current_xz.x, current_y, current_xz.z)
			var local_pt = inv_trans * world_pt
			st.add_vertex(local_pt)
		line_mesh_inst.mesh = st.commit()

# --- Unified Indicator APIs ---

# 1. Caster-Emanating Indicators: requires only the shape of the given hitbox and the aim angle
static func create_emanating_indicator(hitbox: RefCounted, fill_color: Color = EMPTY_FILL, border_color: Color = WHITE_OUTLINE) -> Node3D:
	return create_from_hitbox(hitbox, fill_color, border_color)

static func update_emanating_angle(indicator: Node3D, angle_rad: float) -> void:
	if is_instance_valid(indicator):
		indicator.rotation.y = angle_rad

# 2. Discrete Location Indicators: requires a discrete location instead of an aim angle
static func create_discrete_location_indicator(hitbox: RefCounted, fill_color: Color = EMPTY_FILL, border_color: Color = WHITE_OUTLINE) -> Node3D:
	var ind = create_from_hitbox(hitbox, fill_color, border_color)
	if ind:
		ind.top_level = true
	return ind

static func update_discrete_location(indicator: Node3D, target_location: Vector3) -> void:
	if is_instance_valid(indicator):
		indicator.global_position = Vector3(target_location.x, 0.06, target_location.z)

# 3. Emanating Distance + Angle Indicators: for abilities like Morrigan's Mortar
static func create_mortar_indicator(radius: float, fill_color: Color = Color(0.2, 0.05, 0.35, 0.25), border_color: Color = Color(0.75, 0.2, 0.95, 0.95)) -> Node3D:
	return create_arc_trajectory_indicator(radius, fill_color, border_color)

static func update_mortar_distance_and_angle(indicator: Node3D, start_pos: Vector3, distance: float, angle_rad: float, apex_height: float = -1.0) -> Vector3:
	var aim_dir = Vector3(sin(angle_rad), 0.0, -cos(angle_rad)).normalized()
	var end_pos = start_pos + aim_dir * distance
	end_pos.y = 0.05
	var apex = apex_height if apex_height > 0.0 else max(3.5, distance * 0.42)
	update_arc_trajectory_indicator(indicator, start_pos + Vector3(0, 0.8, 0), end_pos, apex)
	return end_pos

static func create_from_hitbox(hitbox: RefCounted, fill_color: Color = Color(1.0, 0.2, 0.2, 0.25), border_color: Color = Color(1.0, 0.4, 0.4, 0.95)) -> Node3D:
	if not hitbox:
		return null
	var shape = hitbox.get("shape")
	match shape:
		AbilityPipeline.HitboxShape.SECTOR:
			var rad = hitbox.get("radius") if hitbox.get("radius") != null else 4.0
			var ang = hitbox.get("angle_deg") if hitbox.get("angle_deg") != null else 90.0
			return create_sector_indicator(rad, ang, fill_color, border_color)
		AbilityPipeline.HitboxShape.CIRCLE, AbilityPipeline.HitboxShape.CYLINDER:
			var rad = hitbox.get("radius") if hitbox.get("radius") != null else 4.0
			return create_circle_indicator(rad, fill_color, border_color)
		AbilityPipeline.HitboxShape.LINE:
			var l = hitbox.get("length") if hitbox.get("length") != null else 10.0
			var w = hitbox.get("width") if hitbox.get("width") != null else 1.0
			return create_line_indicator(l, w, fill_color, border_color)
		AbilityPipeline.HitboxShape.BOX:
			var rad = hitbox.get("radius") if hitbox.get("radius") != null else (hitbox.get("length") if hitbox.get("length") != null else 4.0)
			var w = hitbox.get("width") if hitbox.get("width") != null else 2.0
			return create_line_indicator(rad, w, fill_color, border_color)
		AbilityPipeline.HitboxShape.DONUT:
			var inner_r = hitbox.get("width") if hitbox.get("width") != null else 3.0
			var outer_r = hitbox.get("radius") if hitbox.get("radius") != null else 5.5
			return create_donut_indicator(inner_r, outer_r, fill_color, border_color)
	return null

const WHITE_OUTLINE: Color = Color(1.0, 1.0, 1.0, 0.92)
const EMPTY_FILL: Color = Color(1.0, 1.0, 1.0, 0.0)

static func reset_indicator(target: Node) -> void:
	if not is_instance_valid(target):
		return
	if target is MeshInstance3D:
		target.material_override = null
	for child in target.get_children():
		reset_indicator(child)

static func flash_and_fade(node: Node3D, tree: SceneTree, duration: float = 0.14) -> void:
	if not is_instance_valid(node) or not tree:
		return
	
	var flash_mat = StandardMaterial3D.new()
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.95)
	flash_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1.0, 1.0, 1.0, 1.0)
	flash_mat.emission_energy_multiplier = 4.0
	flash_mat.no_depth_test = true
	
	_apply_flash_mat_recursive(node, flash_mat)
	node.show()
	
	var tween = tree.create_tween()
	tween.tween_property(flash_mat, "albedo_color:a", 0.0, duration).set_delay(0.04)
	tween.tween_callback(func():
		if is_instance_valid(node):
			reset_indicator(node)
			node.hide()
	)

static func _apply_flash_mat_recursive(target: Node, mat: Material) -> void:
	if target is MeshInstance3D:
		target.material_override = mat
	for child in target.get_children():
		_apply_flash_mat_recursive(child, mat)
