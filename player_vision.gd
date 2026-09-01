class_name PlayerVision
extends PlayerPhysics

# Vision Geometry & Calculation Constants
const CLOSE_RADIUS_M: float = 5.5
const CONE_RADIUS_M: float = 24.0
const CONE_HALF_ANGLE_DEG: float = 30.0 # 60 degrees total acute forward cone
const HEIGHT_SCALE_FACTOR: float = 0.20 # +20% radius per meter of elevation
const MAX_HEIGHT_MULT: float = 2.5
const VELOCITY_LEAD_TIME: float = 0.045 # Predictive velocity lead for vision smoothing

# Elevation vision scale helper
static func get_height_vision_multiplier(pos_y: float) -> float:
	var height = max(0.0, pos_y)
	return clamp(1.0 + (height * HEIGHT_SCALE_FACTOR), 1.0, MAX_HEIGHT_MULT)

# Velocity-lead predicted eye position
func get_predicted_vision_origin(eye_height: float = 1.25) -> Vector3:
	var lead_offset = velocity * VELOCITY_LEAD_TIME
	lead_offset.y = 0.0 # Keep height grounded to actual player elevation
	var pred_pos = global_position + lead_offset
	pred_pos.y = global_position.y + eye_height
	return pred_pos

func get_facing_direction_3d() -> Vector3:
	var fwd = -global_transform.basis.z.normalized()
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		fwd = Vector3.FORWARD
	return fwd.normalized()

func set_opponent_visible(is_vis: bool) -> void:
	var my_id = multiplayer.get_unique_id() if (multiplayer and multiplayer.has_multiplayer_peer()) else 1
	if name.to_int() == my_id or name == "1":
		visible = not get("is_dead")
		return
	if get("is_dead"):
		visible = false
		return
	visible = is_vis
	var sprite_3d_node = get_node_or_null("HealthBarSprite")
	if sprite_3d_node:
		sprite_3d_node.visible = is_vis

# --- Static Obstacle Vertex Extraction & Vertex Vision Polygon Generation ---

# Extract 2D obstacle vertices from static arena bodies and temporary terrain
static func extract_map_obstacle_vertices(main_node: Node) -> Array[Vector2]:
	var vertices: Array[Vector2] = []
	if not main_node:
		return vertices

	var arena = main_node.get_node_or_null("Arena")
	if not arena:
		return vertices

	for child in _get_all_static_bodies_recursive(arena):
		if child is StaticBody3D and child.is_inside_tree() and child.is_visible_in_tree():
			var col_shape = child.get_node_or_null("CollisionShape3D") as CollisionShape3D
			if col_shape and col_shape.shape:
				var shape = col_shape.shape
				var xform = child.global_transform
				
				if shape is BoxShape3D:
					var size = shape.size
					var hx = size.x * 0.5
					var hz = size.z * 0.5
					var corners = [
						Vector3(-hx, 0, -hz),
						Vector3(hx, 0, -hz),
						Vector3(hx, 0, hz),
						Vector3(-hx, 0, hz)
					]
					for c in corners:
						var world_c = xform * c
						vertices.append(Vector2(world_c.x, world_c.z))

				elif shape is CylinderShape3D:
					var rad = shape.radius
					var segments = 12
					for i in range(segments):
						var a = (float(i) / float(segments)) * TAU
						var local_p = Vector3(cos(a) * rad, 0, sin(a) * rad)
						var world_p = xform * local_p
						vertices.append(Vector2(world_p.x, world_p.z))

				elif shape is ConvexPolygonShape3D:
					for p in shape.points:
						var world_p = xform * p
						vertices.append(Vector2(world_p.x, world_p.z))

	# Also collect temporary terrain (pillars, ice walls, fences)
	var temp_terrain = main_node.get_node_or_null("TemporaryTerrain")
	if temp_terrain:
		for child in temp_terrain.get_children():
			if child is Node3D and child.is_inside_tree() and child.visible:
				var col_shape = child.get_node_or_null("CollisionShape3D") as CollisionShape3D
				if col_shape and col_shape.shape is BoxShape3D:
					var size = (col_shape.shape as BoxShape3D).size
					var hx = size.x * 0.5
					var hz = size.z * 0.5
					var xform = child.global_transform
					var corners = [
						Vector3(-hx, 0, -hz),
						Vector3(hx, 0, -hz),
						Vector3(hx, 0, hz),
						Vector3(-hx, 0, hz)
					]
					for c in corners:
						var world_c = xform * c
						vertices.append(Vector2(world_c.x, world_c.z))

	return vertices

static func _get_all_static_bodies_recursive(node: Node) -> Array[StaticBody3D]:
	var result: Array[StaticBody3D] = []
	if node is StaticBody3D:
		result.append(node)
	for c in node.get_children():
		result.append_array(_get_all_static_bodies_recursive(c))
	return result

# Generate a vertex-targeted visibility polygon in 2D screen coordinates
static func generate_vertex_vision_polygon(
	camera: Camera3D,
	space_state: PhysicsDirectSpaceState3D,
	origin_3d: Vector3,
	max_radius: float,
	is_cone: bool,
	facing_dir_3d: Vector3,
	half_angle_rad: float,
	see_through_terrain: bool,
	obstacle_vertices: Array[Vector2]
) -> PackedVector2Array:
	if not camera or not space_state:
		return PackedVector2Array()

	var origin_2d = Vector2(origin_3d.x, origin_3d.z)
	var facing_2d = Vector2(facing_dir_3d.x, facing_dir_3d.z).normalized()
	if facing_2d.length_squared() < 0.0001:
		facing_2d = Vector2(0, -1)
	var facing_angle = facing_2d.angle()

	var angles_to_cast: Array[float] = []
	var eps = 0.0002 # Angular offset for corner grazing rays

	if is_cone:
		var min_angle = facing_angle - half_angle_rad
		var max_angle = facing_angle + half_angle_rad
		
		# Add cone boundaries
		angles_to_cast.append(min_angle)
		angles_to_cast.append(max_angle)

		# Add smooth arc interpolation steps across the cone
		var arc_steps = 14
		for i in range(1, arc_steps):
			var t = float(i) / float(arc_steps)
			angles_to_cast.append(lerp(min_angle, max_angle, t))

		# Add rays targeted at obstacle vertices inside the cone sector
		for v in obstacle_vertices:
			var diff = v - origin_2d
			var dist = diff.length()
			if dist <= max_radius and dist > 0.1:
				var a = diff.angle()
				var angle_diff = wrapf(a - facing_angle, -PI, PI)
				if abs(angle_diff) <= half_angle_rad:
					var normalized_a = facing_angle + angle_diff
					angles_to_cast.append(normalized_a)
					if normalized_a - eps >= min_angle:
						angles_to_cast.append(normalized_a - eps)
					if normalized_a + eps <= max_angle:
						angles_to_cast.append(normalized_a + eps)
	else:
		# Full 360 circle: regular radial curvature samples
		var circle_samples = 24
		for i in range(circle_samples):
			var a = (float(i) / float(circle_samples)) * TAU - PI
			angles_to_cast.append(a)

		# Add rays targeted at all obstacle vertices within range
		for v in obstacle_vertices:
			var diff = v - origin_2d
			var dist = diff.length()
			if dist <= max_radius and dist > 0.1:
				var a = diff.angle()
				angles_to_cast.append(a)
				angles_to_cast.append(a - eps)
				angles_to_cast.append(a + eps)

	# Deduplicate and sort angles
	angles_to_cast.sort()

	# Cast rays in each direction and collect 3D hit points
	var hit_points_3d: Array[Vector3] = []
	
	if is_cone:
		# For cones, origin is the center vertex
		hit_points_3d.append(origin_3d)

	for a in angles_to_cast:
		var dir_3d = Vector3(cos(a), 0.0, sin(a))
		var endpoint_3d: Vector3
		if see_through_terrain:
			endpoint_3d = origin_3d + dir_3d * max_radius
		else:
			endpoint_3d = _cast_vision_ray_3d(space_state, origin_3d, dir_3d, max_radius)
		hit_points_3d.append(endpoint_3d)

	# Project to 2D camera viewport points
	var poly_2d = PackedVector2Array()
	for pt in hit_points_3d:
		poly_2d.append(camera.unproject_position(pt))

	return poly_2d

static func _cast_vision_ray_3d(space_state: PhysicsDirectSpaceState3D, origin_3d: Vector3, dir_3d: Vector3, max_dist: float) -> Vector3:
	var target_3d = origin_3d + dir_3d * max_dist
	var query = PhysicsRayQueryParameters3D.create(origin_3d, target_3d, 1) # Layer 1 = Static terrain / walls
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return target_3d
	
	var hit_pos: Vector3 = result.position
	# Check if eye position is significantly elevated above obstacle
	if origin_3d.y >= hit_pos.y + 0.3:
		return target_3d
	
	return hit_pos
