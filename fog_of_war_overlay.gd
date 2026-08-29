extends Control

const CLOSE_RADIUS_M: float = 5.5
const CONE_RADIUS_M: float = 24.0
const CONE_HALF_ANGLE_DEG: float = 30.0 # 60 degrees total cone

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
	
	var focus_player = local_player
	if not focus_player or focus_player.get("is_dead"):
		if local_player and local_player.get("spectate_target") != null and is_instance_valid(local_player.spectate_target) and not local_player.spectate_target.get("is_dead"):
			focus_player = local_player.spectate_target
		else:
			draw_rect(Rect2(Vector2.ZERO, vp_size), Color(1, 1, 1, 1))
			_reveal_all_players(main_node)
			return

	var focus_id = focus_player.name.to_int()
	var focus_team = focus_player.get("team_id") if focus_player.get("team_id") != null else 1
	var space_state = focus_player.get_world_3d().direct_space_state

	# Collect all living teammates (including focus player)
	var teammates: Array = []
	var players_container = main_node.get_node_or_null("Players")
	if players_container:
		for p in players_container.get_children():
			if not p.get("is_dead"):
				var p_team = p.get("team_id") if p.get("team_id") != null else 1
				if p_team == focus_team or p == focus_player:
					teammates.append(p)

	if teammates.is_empty():
		teammates.append(focus_player)

	# 1. Base dark Fog of War background (Multiply layer)
	draw_rect(Rect2(Vector2.ZERO, vp_size), Color(0.08, 0.09, 0.13, 1.0))

	var active_reveal_sources: Array = []
	var clear_color = Color(1.0, 1.0, 1.0, 1.0)
	var rim_color = Color(0.2, 0.85, 1.0, 0.5)

	# 2. Draw 3D Raycasted Vision Shapes for all living teammates
	for tm in teammates:
		var tm_pos_3d = tm.global_position
		var tm_eye_pos = tm_pos_3d + Vector3(0, 1.25, 0)
		var tm_fwd_3d = -tm.global_transform.basis.z.normalized()
		tm_fwd_3d.y = 0.0
		if tm_fwd_3d.length_squared() < 0.0001:
			tm_fwd_3d = Vector3.FORWARD
		tm_fwd_3d = tm_fwd_3d.normalized()

		# Close circle (5.5m)
		var close_poly = _make_circle_poly_3d(camera, space_state, tm_eye_pos, CLOSE_RADIUS_M, 28)
		if close_poly.size() >= 3:
			draw_colored_polygon(close_poly, clear_color)
			var close_loop = PackedVector2Array(close_poly)
			close_loop.append(close_poly[0])
			draw_polyline(close_loop, rim_color, 2.5, true)

		# Forward cone (24.0m normal or 70.0m Poke Ult)
		var is_poke_ult_buff = (tm.get("poke_ult_buff_timer") != null and tm.poke_ult_buff_timer > 0.0)
		var cone_radius = 70.0 if is_poke_ult_buff else CONE_RADIUS_M
		var see_through = is_poke_ult_buff

		var cone_poly = _make_cone_poly_3d(camera, space_state, tm_eye_pos, tm_fwd_3d, deg_to_rad(CONE_HALF_ANGLE_DEG), cone_radius, 28, see_through)
		if cone_poly.size() >= 3:
			draw_colored_polygon(cone_poly, clear_color)
			var cone_loop = PackedVector2Array(cone_poly)
			cone_loop.append(cone_poly[0])
			var current_rim_color = Color(1.0, 0.85, 0.2, 0.7) if is_poke_ult_buff else rim_color
			draw_polyline(cone_loop, current_rim_color, 2.5, true)

		# Teammates are always visible to each other
		if tm.has_method("set_opponent_visible"):
			tm.set_opponent_visible(true)

	# 3. Draw team-owned reveal zones & flares
	var vision_zones_container = main_node.get_node_or_null("VisionZones")
	if vision_zones_container:
		for zone in vision_zones_container.get_children():
			if zone.is_inside_tree():
				var z_team = zone.get("owner_team") if zone.get("owner_team") != null else 0
				var z_owner = zone.get("owner_id") if zone.get("owner_id") != null else 0
				if z_team != 0 and z_team != focus_team:
					continue
				if z_team == 0 and z_owner != 0 and z_owner != focus_id:
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
				var p_team = proj.get("shooter_team") if proj.get("shooter_team") != null else 0
				var p_shooter = proj.get("shooter_id") if proj.get("shooter_id") != null else 0
				if p_team != 0 and p_team != focus_team:
					continue
				if p_team == 0 and p_shooter != 0 and p_shooter != focus_id:
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

	# 4. Update enemies visibility across all teammates and active reveal sources
	_update_team_enemies_visibility(main_node, teammates, space_state, active_reveal_sources)

func _make_circle_poly_3d(camera: Camera3D, space_state: PhysicsDirectSpaceState3D, origin_3d: Vector3, radius: float, num_rays: int) -> PackedVector2Array:
	var pts_2d = PackedVector2Array()
	for i in range(num_rays):
		var a = float(i) / float(num_rays) * TAU
		var dir_3d = Vector3(cos(a), 0.0, sin(a))
		var ray_endpoint = _cast_ray_3d(space_state, origin_3d, dir_3d, radius)
		pts_2d.append(camera.unproject_position(ray_endpoint))
	return pts_2d

func _make_cone_poly_3d(camera: Camera3D, space_state: PhysicsDirectSpaceState3D, origin_3d: Vector3, fwd_3d: Vector3, half_angle_rad: float, max_radius: float, num_rays: int, see_through_terrain: bool = false) -> PackedVector2Array:
	var pts_2d = PackedVector2Array()
	pts_2d.append(camera.unproject_position(origin_3d))
	
	var right_3d = Vector3(fwd_3d.z, 0.0, -fwd_3d.x).normalized()
	
	for i in range(num_rays + 1):
		var t = float(i) / float(num_rays)
		var alpha = lerp(-half_angle_rad, half_angle_rad, t)
		var dir_3d = (fwd_3d * cos(alpha) + right_3d * sin(alpha)).normalized()
		var ray_endpoint: Vector3
		if see_through_terrain:
			ray_endpoint = origin_3d + dir_3d * max_radius
		else:
			ray_endpoint = _cast_ray_3d(space_state, origin_3d, dir_3d, max_radius)
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
			if p.name != "TrainingDummy" and (p.name.to_int() == my_id or p.name == "1" or p.is_multiplayer_authority()):
				return p
	return null

func _reveal_all_players(main_node: Node) -> void:
	var players_container = main_node.get_node_or_null("Players")
	if players_container:
		for p in players_container.get_children():
			if p.has_method("set_opponent_visible"):
				p.set_opponent_visible(true)

func _update_team_enemies_visibility(main_node: Node, teammates: Array, space_state: PhysicsDirectSpaceState3D, active_reveals: Array) -> void:
	var players_container = main_node.get_node_or_null("Players")
	if not players_container:
		return

	for player in players_container.get_children():
		if player in teammates:
			if player.has_method("set_opponent_visible"):
				player.set_opponent_visible(true)
			continue
		
		if not player.has_method("set_opponent_visible") or player.get("is_dead"):
			continue

		var target_pos = player.global_position
		var target_eye_pos = target_pos + Vector3(0, 1.25, 0)
		var is_visible: bool = false

		# Check line of sight from ANY living teammate
		for tm in teammates:
			var tm_pos = tm.global_position
			var tm_eye_pos = tm_pos + Vector3(0, 1.25, 0)
			var tm_fwd_3d = -tm.global_transform.basis.z.normalized()
			tm_fwd_3d.y = 0.0
			var tm_fwd_2d = Vector2(tm_fwd_3d.x, tm_fwd_3d.z).normalized()

			var diff = target_pos - tm_pos
			var diff_2d = Vector2(diff.x, diff.z)
			var dist = diff_2d.length()

			var is_poke_ult_buff = (tm.get("poke_ult_buff_timer") != null and tm.poke_ult_buff_timer > 0.0)
			var cone_radius = 70.0 if is_poke_ult_buff else CONE_RADIUS_M

			var in_vision_shape: bool = false

			# 1. Close proximity circle (5.5m)
			if dist <= CLOSE_RADIUS_M:
				in_vision_shape = true
			# 2. Acute forward cone (24.0m normal or 70.0m Poke Ult)
			elif dist <= cone_radius and tm_fwd_2d.length_squared() > 0.001:
				var to_target_2d = diff_2d.normalized()
				var angle_deg = rad_to_deg(tm_fwd_2d.angle_to(to_target_2d))
				if abs(angle_deg) <= CONE_HALF_ANGLE_DEG:
					in_vision_shape = true
					if is_poke_ult_buff:
						# Pierces terrain on Poke's empowered cone!
						is_visible = true
						break

			if in_vision_shape:
				var query = PhysicsRayQueryParameters3D.create(tm_eye_pos, target_eye_pos, 1)
				query.collide_with_areas = false
				query.collide_with_bodies = true
				var result = space_state.intersect_ray(query)
				if result.is_empty() or tm_eye_pos.y >= result.position.y + 0.3:
					is_visible = true
					break

		# Check active reveal sources (flares & reveal zones)
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
