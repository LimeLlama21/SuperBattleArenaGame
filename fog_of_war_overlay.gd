extends Control

const CLOSE_RADIUS_M: float = 5.5
const CONE_RADIUS_M: float = 24.0
const CONE_HALF_ANGLE_DEG: float = 22.5 # 45 degrees total cone

@onready var texture_rect: TextureRect = get_node_or_null("../../FogOfWarTexture")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not texture_rect:
		texture_rect = get_tree().root.get_node_or_null("Main/FogOfWarCanvas/FogOfWarTexture")
	if texture_rect:
		texture_rect.texture = get_viewport().get_texture()

func _process(_delta: float) -> void:
	var root_vp = get_tree().root.get_viewport()
	if root_vp:
		var root_size = root_vp.get_visible_rect().size
		if root_size.x > 0 and root_size.y > 0:
			var my_vp = get_viewport()
			if my_vp is SubViewport and my_vp.size != Vector2i(root_size):
				my_vp.size = Vector2i(root_size)
	
	queue_redraw()

func _draw() -> void:
	var root_vp = get_tree().root.get_viewport()
	if not root_vp:
		return
	var vp_size = root_vp.get_visible_rect().size
	if vp_size.x <= 0 or vp_size.y <= 0:
		return

	var camera = root_vp.get_camera_3d()
	var main_node = get_tree().root.get_node_or_null("Main")
	if not main_node or not camera:
		draw_rect(Rect2(Vector2.ZERO, vp_size), Color(1, 1, 1, 1))
		return

	var my_id = multiplayer.get_unique_id()
	var local_player = _get_local_player(main_node, my_id)
	
	if not local_player or local_player.get("is_dead"):
		draw_rect(Rect2(Vector2.ZERO, vp_size), Color(1, 1, 1, 1))
		_reveal_all_players(main_node)
		return

	var player_pos_3d = local_player.global_position
	var eye_pos = player_pos_3d + Vector3(0, 1.25, 0)
	var space_state = local_player.get_world_3d().direct_space_state

	# Calculate 3D forward and right basis vectors
	var fwd_3d = -local_player.global_transform.basis.z.normalized()
	fwd_3d.y = 0.0
	if fwd_3d.length_squared() < 0.0001:
		fwd_3d = Vector3.FORWARD
	fwd_3d = fwd_3d.normalized()

	# 1. Base dark Fog of War background (Multiply layer)
	draw_rect(Rect2(Vector2.ZERO, vp_size), Color(0.08, 0.09, 0.13, 1.0))

	var active_reveal_sources: Array = []
	var clear_color = Color(1.0, 1.0, 1.0, 1.0)
	var rim_color = Color(0.2, 0.85, 1.0, 0.5)

	# 2. Draw 3D Raycasted Close Vision Circle (5.5m radius)
	var close_poly = _make_circle_poly_3d(camera, space_state, eye_pos, CLOSE_RADIUS_M, 32)
	if close_poly.size() >= 3:
		draw_colored_polygon(close_poly, clear_color)
		var close_loop = PackedVector2Array(close_poly)
		close_loop.append(close_poly[0])
		draw_polyline(close_loop, rim_color, 2.5, true)

	# 3. Draw 3D Raycasted Acute Forward Cone (24.0m radius, 45 degrees)
	var cone_poly = _make_cone_poly_3d(camera, space_state, eye_pos, fwd_3d, deg_to_rad(CONE_HALF_ANGLE_DEG), CONE_RADIUS_M, 24)
	if cone_poly.size() >= 3:
		draw_colored_polygon(cone_poly, clear_color)
		var cone_loop = PackedVector2Array(cone_poly)
		cone_loop.append(cone_poly[0])
		draw_polyline(cone_loop, rim_color, 2.5, true)

	# 4. Draw team/player-owned reveal zones & flares
	var vision_zones_container = main_node.get_node_or_null("VisionZones")
	if vision_zones_container:
		for zone in vision_zones_container.get_children():
			if zone.is_inside_tree():
				if zone.get("owner_id") != null and zone.owner_id != 0 and zone.owner_id != my_id:
					continue
				
				var z_pos_3d = zone.global_position
				var z_rad_m = zone.get("radius") if zone.get("radius") != null else 12.0
				var z_eye = z_pos_3d + Vector3(0, 1.5, 0)
				var z_poly = _make_circle_poly_3d(camera, space_state, z_eye, z_rad_m, 24)
				if z_poly.size() >= 3:
					draw_colored_polygon(z_poly, clear_color)
					var z_loop = PackedVector2Array(z_poly)
					z_loop.append(z_poly[0])
					draw_polyline(z_loop, rim_color, 2.5, true)
				active_reveal_sources.append({"pos": z_pos_3d, "radius": z_rad_m})

	var proj_container = main_node.get_node_or_null("Projectiles")
	if proj_container:
		for proj in proj_container.get_children():
			if proj.get("vision_radius") != null and proj.is_inside_tree():
				if proj.get("shooter_id") != null and proj.shooter_id != 0 and proj.shooter_id != my_id:
					continue

				var f_pos_3d = proj.global_position
				var f_rad_m = proj.vision_radius
				var f_eye = f_pos_3d + Vector3(0, 0.8, 0)
				var f_poly = _make_circle_poly_3d(camera, space_state, f_eye, f_rad_m, 16)
				if f_poly.size() >= 3:
					draw_colored_polygon(f_poly, clear_color)
					var f_loop = PackedVector2Array(f_poly)
					f_loop.append(f_poly[0])
					draw_polyline(f_loop, rim_color, 2.5, true)
				active_reveal_sources.append({"pos": f_pos_3d, "radius": f_rad_m})

	# Update opponent visibility with 3D Line-of-Sight & terrain occlusion
	_update_enemies_visibility(main_node, local_player, eye_pos, space_state, active_reveal_sources)

func _make_circle_poly_3d(camera: Camera3D, space_state: PhysicsDirectSpaceState3D, origin_3d: Vector3, radius: float, num_rays: int) -> PackedVector2Array:
	var pts_2d = PackedVector2Array()
	for i in range(num_rays):
		var a = float(i) / float(num_rays) * TAU
		var dir_3d = Vector3(cos(a), 0.0, sin(a))
		var ray_endpoint = _cast_ray_3d(space_state, origin_3d, dir_3d, radius)
		pts_2d.append(camera.unproject_position(ray_endpoint))
	return pts_2d

func _make_cone_poly_3d(camera: Camera3D, space_state: PhysicsDirectSpaceState3D, origin_3d: Vector3, fwd_3d: Vector3, half_angle_rad: float, max_radius: float, num_rays: int) -> PackedVector2Array:
	var pts_2d = PackedVector2Array()
	pts_2d.append(camera.unproject_position(origin_3d))
	
	var right_3d = Vector3(fwd_3d.z, 0.0, -fwd_3d.x).normalized()
	
	for i in range(num_rays + 1):
		var t = float(i) / float(num_rays)
		var alpha = lerp(-half_angle_rad, half_angle_rad, t)
		var dir_3d = (fwd_3d * cos(alpha) + right_3d * sin(alpha)).normalized()
		var ray_endpoint = _cast_ray_3d(space_state, origin_3d, dir_3d, max_radius)
		pts_2d.append(camera.unproject_position(ray_endpoint))
		
	return pts_2d

func _cast_ray_3d(space_state: PhysicsDirectSpaceState3D, origin_3d: Vector3, dir_3d: Vector3, max_dist: float) -> Vector3:
	var target_3d = origin_3d + dir_3d * max_dist
	
	var query = PhysicsRayQueryParameters3D.create(origin_3d, target_3d, 1) # Layer 1 = Static terrain / walls
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return target_3d
	
	var hit_pos: Vector3 = result.position
	# Check if player is above the terrain
	if origin_3d.y >= hit_pos.y + 0.3:
		return target_3d
	
	return hit_pos

func _get_local_player(main_node: Node, my_id: int) -> Node:
	var players_container = main_node.get_node_or_null("Players")
	if players_container:
		for p in players_container.get_children():
			if p.name.to_int() == my_id:
				return p
	return null

func _reveal_all_players(main_node: Node) -> void:
	var players_container = main_node.get_node_or_null("Players")
	if players_container:
		for p in players_container.get_children():
			if p.has_method("set_opponent_visible"):
				p.set_opponent_visible(true)

func _update_enemies_visibility(main_node: Node, local_player: Node, my_eye_pos: Vector3, space_state: PhysicsDirectSpaceState3D, active_reveals: Array) -> void:
	var players_container = main_node.get_node_or_null("Players")
	if not players_container:
		return

	var my_pos = local_player.global_position
	var fwd_3d = -local_player.global_transform.basis.z.normalized()
	fwd_3d.y = 0.0
	var fwd_2d = Vector2(fwd_3d.x, fwd_3d.z).normalized()

	for player in players_container.get_children():
		if player == local_player:
			continue
		
		if not player.has_method("set_opponent_visible") or player.get("is_dead"):
			continue

		var target_pos = player.global_position
		var target_eye_pos = target_pos + Vector3(0, 1.25, 0)
		var diff = target_pos - my_pos
		var diff_2d = Vector2(diff.x, diff.z)
		var dist = diff_2d.length()

		var in_vision_shape: bool = false

		# 1. Check close proximity circle (5.5m)
		if dist <= CLOSE_RADIUS_M:
			in_vision_shape = true
		
		# 2. Check acute forward cone (24.0m, 45 degrees)
		elif dist <= CONE_RADIUS_M and fwd_2d.length_squared() > 0.001:
			var to_target_2d = diff_2d.normalized()
			var angle_deg = rad_to_deg(fwd_2d.angle_to(to_target_2d))
			if abs(angle_deg) <= CONE_HALF_ANGLE_DEG:
				in_vision_shape = true

		var is_visible: bool = false

		if in_vision_shape:
			# Check 3D line-of-sight against terrain (layer 1)
			var query = PhysicsRayQueryParameters3D.create(my_eye_pos, target_eye_pos, 1)
			query.collide_with_areas = false
			query.collide_with_bodies = true
			var result = space_state.intersect_ray(query)
			
			if result.is_empty():
				is_visible = true
			else:
				var hit_pos: Vector3 = result.position
				if my_eye_pos.y >= hit_pos.y + 0.3:
					is_visible = true
				else:
					is_visible = false

		# 3. Check active reveal sources (flares & reveal zones)
		if not is_visible:
			for r in active_reveals:
				var r_diff = target_pos - r["pos"]
				var r_dist = Vector2(r_diff.x, r_diff.z).length()
				if r_dist <= r["radius"]:
					var z_eye = r["pos"] + Vector3(0, 1.5, 0)
					var q = PhysicsRayQueryParameters3D.create(z_eye, target_eye_pos, 1)
					q.collide_with_areas = false
					q.collide_with_bodies = true
					var res = space_state.intersect_ray(q)
					if res.is_empty() or z_eye.y >= res.position.y + 0.3:
						is_visible = true
						break

		player.set_opponent_visible(is_visible)
