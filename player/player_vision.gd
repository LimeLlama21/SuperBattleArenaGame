class_name PlayerVision
extends PlayerPhysics

# Vision Geometry & Calculation Constants
const CLOSE_RADIUS_M: float = 5.5
const CONE_RADIUS_M: float = 24.0
const CONE_HALF_ANGLE_DEG: float = 32.5 # 65 degrees total forward vision cone
const HEIGHT_SCALE_FACTOR: float = 0.20 # +20% radius per meter of elevation
const MAX_HEIGHT_MULT: float = 2.5
const VELOCITY_LEAD_TIME: float = 0.045 # Predictive velocity lead for vision smoothing

# Elevation vision scale helper
static func get_height_vision_multiplier(pos_y: float) -> float:
	var height = max(0.0, pos_y)
	return clamp(1.0 + (height * HEIGHT_SCALE_FACTOR), 1.0, MAX_HEIGHT_MULT)

func get_custom_cone_radius() -> float:
	return CONE_RADIUS_M

func get_custom_cone_half_angle_deg() -> float:
	return CONE_HALF_ANGLE_DEG

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

# --- 2D Obstacle Extraction & 2D Vertex Calculated Vision ---

# Extract 2D obstacles (platforms, walls, covers) with height information from arena and temporary terrain
static func extract_map_obstacles_2d(main_node: Node) -> Array[Dictionary]:
	var obstacles: Array[Dictionary] = []
	if not main_node:
		return obstacles

	var bodies: Array[StaticBody3D] = []
	var arena = main_node.get_node_or_null("Arena")
	if arena:
		bodies.append_array(_get_all_static_bodies_recursive(arena))

	var temp_terrain = main_node.get_node_or_null("TemporaryTerrain")
	if temp_terrain:
		for child in temp_terrain.get_children():
			if child is StaticBody3D:
				bodies.append(child)
			elif child is Node3D:
				bodies.append_array(_get_all_static_bodies_recursive(child))

	for body in bodies:
		if not body.is_inside_tree() or not body.is_visible_in_tree():
			continue
		var col_shape = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if not col_shape or not col_shape.shape:
			continue
		
		var shape = col_shape.shape
		var xform = col_shape.global_transform
		
		var obs_verts: Array[Vector2] = []
		var obs_segments: Array[PackedVector2Array] = []
		var top_y: float = -9999.0
		var bottom_y: float = 9999.0

		if shape is BoxShape3D:
			var size = (shape as BoxShape3D).size
			var hx = size.x * 0.5
			var hy = size.y * 0.5
			var hz = size.z * 0.5
			
			var c_local = [
				Vector3(-hx, hy, -hz),
				Vector3(hx, hy, -hz),
				Vector3(hx, hy, hz),
				Vector3(-hx, hy, hz),
				Vector3(-hx, -hy, -hz),
				Vector3(hx, -hy, -hz),
				Vector3(hx, -hy, hz),
				Vector3(-hx, -hy, hz)
			]
			for c in c_local:
				var cw = xform * c
				top_y = max(top_y, cw.y)
				bottom_y = min(bottom_y, cw.y)

			# 2D corners in counter-clockwise order
			var p0 = xform * Vector3(-hx, 0, -hz)
			var p1 = xform * Vector3(hx, 0, -hz)
			var p2 = xform * Vector3(hx, 0, hz)
			var p3 = xform * Vector3(-hx, 0, hz)
			var v0 = Vector2(p0.x, p0.z)
			var v1 = Vector2(p1.x, p1.z)
			var v2 = Vector2(p2.x, p2.z)
			var v3 = Vector2(p3.x, p3.z)
			obs_verts = [v0, v1, v2, v3]
			obs_segments = [
				PackedVector2Array([v0, v1]),
				PackedVector2Array([v1, v2]),
				PackedVector2Array([v2, v3]),
				PackedVector2Array([v3, v0])
			]

		elif shape is CylinderShape3D:
			var cyl = shape as CylinderShape3D
			var rad = cyl.radius
			var hy = cyl.height * 0.5
			var c_top = xform * Vector3(0, hy, 0)
			var c_bot = xform * Vector3(0, -hy, 0)
			top_y = max(c_top.y, c_bot.y)
			bottom_y = min(c_top.y, c_bot.y)
			
			var segs = 16
			for i in range(segs):
				var a = (float(i) / float(segs)) * TAU
				var pw = xform * Vector3(cos(a) * rad, 0, sin(a) * rad)
				obs_verts.append(Vector2(pw.x, pw.z))
			for i in range(segs):
				var next_i = (i + 1) % segs
				obs_segments.append(PackedVector2Array([obs_verts[i], obs_verts[next_i]]))

		elif shape is ConvexPolygonShape3D:
			var poly = shape as ConvexPolygonShape3D
			for p in poly.points:
				var pw = xform * p
				top_y = max(top_y, pw.y)
				bottom_y = min(bottom_y, pw.y)
				obs_verts.append(Vector2(pw.x, pw.z))
			if obs_verts.size() >= 3:
				for i in range(obs_verts.size()):
					var next_i = (i + 1) % obs_verts.size()
					obs_segments.append(PackedVector2Array([obs_verts[i], obs_verts[next_i]]))

		if obs_verts.size() >= 3:
			obstacles.append({
				"name": body.name,
				"top_y": top_y,
				"bottom_y": bottom_y,
				"vertices": obs_verts,
				"segments": obs_segments
			})

	return obstacles

static func extract_map_obstacle_vertices(main_node: Node) -> Array[Vector2]:
	var vertices: Array[Vector2] = []
	var obstacles = extract_map_obstacles_2d(main_node)
	for obs in obstacles:
		for v in obs["vertices"]:
			vertices.append(v)
	return vertices

static func _get_all_static_bodies_recursive(node: Node) -> Array[StaticBody3D]:
	var result: Array[StaticBody3D] = []
	if node is StaticBody3D:
		result.append(node)
	for c in node.get_children():
		result.append_array(_get_all_static_bodies_recursive(c))
	return result

# 2D point-in-polygon test (Jordan curve theorem)
static func is_point_in_polygon_2d(pt: Vector2, poly: Array[Vector2]) -> bool:
	if poly.size() < 3:
		return false
	var inside = false
	var j = poly.size() - 1
	for i in range(poly.size()):
		var pi = poly[i]
		var pj = poly[j]
		if ((pi.y > pt.y) != (pj.y > pt.y)) and (pt.x < (pj.x - pi.x) * (pt.y - pi.y) / (pj.y - pi.y) + pi.x):
			inside = !inside
		j = i
	return inside

# 2D Ray - Segment intersection
static func _intersect_ray_segment_2d(ro: Vector2, rd: Vector2, max_dist: float, p1: Vector2, p2: Vector2) -> float:
	var v = p2 - p1
	var det = v.x * rd.y - v.y * rd.x
	if abs(det) < 0.000001:
		return -1.0
	var w = p1 - ro
	var t = (v.x * w.y - v.y * w.x) / det
	var u = (rd.x * w.y - rd.y * w.x) / det
	if t > 0.05 and t <= max_dist and u >= 0.0 and u <= 1.0:
		return t
	return -1.0

# Find closest intersection distance along a 2D ray against obstacle segments
static func cast_vision_ray_2d(ro: Vector2, rd: Vector2, max_dist: float, segments: Array[PackedVector2Array]) -> float:
	var closest_t = max_dist
	for seg in segments:
		var t = _intersect_ray_segment_2d(ro, rd, closest_t, seg[0], seg[1])
		if t > 0.0 and t < closest_t:
			closest_t = t
	return closest_t

# Check if a target position is visible to a viewer using 2D obstacle height rules:
# "If you are below a platform, you cannot see above it. If a player rises above, they can see above it."
static func is_target_visible_2d(
	viewer_pos: Vector3,
	viewer_eye_y: float,
	target_pos: Vector3,
	target_eye_y: float,
	obstacles: Array[Dictionary]
) -> bool:
	var v_2d = Vector2(viewer_pos.x, viewer_pos.z)
	var t_2d = Vector2(target_pos.x, target_pos.z)
	var diff = t_2d - v_2d
	var dist = diff.length()
	var rd = diff / dist if dist > 0.0001 else Vector2.ZERO

	for obs in obstacles:
		var top_y = obs["top_y"]
		# An obstacle/platform blocks vision if viewer is below it
		var is_below = (viewer_pos.y < top_y - 0.2) and (viewer_eye_y < top_y)
		if is_below:
			# 1. Target is on top of or above this platform within its 2D footprint:
			# If you are below a platform, you cannot see above it!
			if target_eye_y >= top_y - 0.3 and is_point_in_polygon_2d(t_2d, obs["vertices"]):
				return false

			# 2. Line of sight between viewer and target crosses the platform/obstacle boundary
			if dist > 0.05:
				for seg in obs["segments"]:
					var t = _intersect_ray_segment_2d(v_2d, rd, dist - 0.05, seg[0], seg[1])
					if t > 0.05 and t < dist - 0.05:
						return false
	return true

# Generate a vertex-targeted 2D visibility polygon projected into camera screen coordinates
static func generate_vertex_vision_polygon(
	camera: Camera3D,
	_space_state: PhysicsDirectSpaceState3D,
	origin_3d: Vector3,
	max_radius: float,
	is_cone: bool,
	facing_dir_3d: Vector3,
	half_angle_rad: float,
	see_through_terrain: bool,
	obstacles: Variant
) -> PackedVector2Array:
	if not camera:
		return PackedVector2Array()

	var origin_2d = Vector2(origin_3d.x, origin_3d.z)
	var viewer_eye_y = origin_3d.y
	var viewer_ground_y = origin_3d.y - 1.25

	var facing_2d = Vector2(facing_dir_3d.x, facing_dir_3d.z).normalized()
	if facing_2d.length_squared() < 0.0001:
		facing_2d = Vector2(0, -1)
	var facing_angle = facing_2d.angle()

	# Filter obstacles that block this viewer:
	# "If you are below a platform, you cannot see above it. If a player rises above, they can see above it."
	var active_segments: Array[PackedVector2Array] = []
	var active_vertices: Array[Vector2] = []

	if obstacles is Array and not obstacles.is_empty():
		if obstacles[0] is Dictionary:
			for obs in obstacles:
				var top_y = obs["top_y"]
				var is_below = (viewer_ground_y < top_y - 0.2) and (viewer_eye_y < top_y)
				if is_below:
					for seg in obs["segments"]:
						active_segments.append(seg)
					for v in obs["vertices"]:
						active_vertices.append(v)
		elif obstacles[0] is Vector2:
			for v in obstacles:
				active_vertices.append(v)

	var angles_to_cast: Array[float] = []
	var eps = 0.0002 # Angular offset for corner grazing rays

	if is_cone:
		var min_angle = facing_angle - half_angle_rad
		var max_angle = facing_angle + half_angle_rad
		
		angles_to_cast.append(min_angle)
		angles_to_cast.append(max_angle)

		var arc_steps = 18
		for i in range(1, arc_steps):
			var t = float(i) / float(arc_steps)
			angles_to_cast.append(lerp(min_angle, max_angle, t))

		for v in active_vertices:
			var diff = v - origin_2d
			var dist = diff.length()
			if dist <= max_radius and dist > 0.1:
				var a = diff.angle()
				var angle_diff = wrapf(a - facing_angle, -PI, PI)
				if abs(angle_diff) <= half_angle_rad:
					var norm_a = facing_angle + angle_diff
					angles_to_cast.append(norm_a)
					if norm_a - eps >= min_angle:
						angles_to_cast.append(norm_a - eps)
					if norm_a + eps <= max_angle:
						angles_to_cast.append(norm_a + eps)
	else:
		var circle_samples = 32
		for i in range(circle_samples):
			var a = (float(i) / float(circle_samples)) * TAU - PI
			angles_to_cast.append(a)

		for v in active_vertices:
			var diff = v - origin_2d
			var dist = diff.length()
			if dist <= max_radius and dist > 0.1:
				var a = diff.angle()
				angles_to_cast.append(a)
				angles_to_cast.append(a - eps)
				angles_to_cast.append(a + eps)

	angles_to_cast.sort()

	# Cast 2D rays in each direction and collect 2D hit points
	var hit_points_2d: Array[Vector2] = []
	for a in angles_to_cast:
		var dir_2d = Vector2(cos(a), sin(a))
		var hit_dist = max_radius
		if not see_through_terrain and not active_segments.is_empty():
			hit_dist = cast_vision_ray_2d(origin_2d, dir_2d, max_radius, active_segments)
		hit_points_2d.append(origin_2d + dir_2d * hit_dist)

	# Project 2D hit points to screen coordinates via camera
	var poly_2d = PackedVector2Array()
	if is_cone:
		poly_2d.append(camera.unproject_position(Vector3(origin_2d.x, viewer_ground_y, origin_2d.y)))

	for pt in hit_points_2d:
		poly_2d.append(camera.unproject_position(Vector3(pt.x, viewer_ground_y, pt.y)))

	return poly_2d
