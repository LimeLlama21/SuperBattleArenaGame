extends Control

const CLOSE_RADIUS_M: float = 5.5
const CONE_RADIUS_M: float = 24.0
const CONE_HALF_ANGLE_DEG: float = 30.0 # 60 degrees total cone
const HEIGHT_SCALE_FACTOR: float = 0.20 # +20% radius per meter of elevation
const MAX_HEIGHT_MULT: float = 2.5

static func get_height_vision_multiplier(pos_y: float) -> float:
	var height = max(0.0, pos_y)
	return clamp(1.0 + (height * HEIGHT_SCALE_FACTOR), 1.0, MAX_HEIGHT_MULT)

@onready var texture_rect: TextureRect = get_node_or_null("../../FogOfWarTexture")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not texture_rect:
		texture_rect = get_tree().root.get_node_or_null("Main/FogOfWarCanvas/FogOfWarTexture")
	if texture_rect:
		texture_rect.texture = get_viewport().get_texture()
		var shader = load("res://fog_of_war.gdshader")
		if shader:
			var sm = ShaderMaterial.new()
			sm.shader = shader
			texture_rect.material = sm

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

	var my_id = multiplayer.get_unique_id() if (multiplayer and multiplayer.has_multiplayer_peer()) else 1
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

	# 1. Base Fog of War mask: 0.0 (Black) = Grayed-out shader terrain
	draw_rect(Rect2(Vector2.ZERO, vp_size), Color(0.0, 0.0, 0.0, 1.0))

	var active_reveal_sources: Array = []
	var vision_white = Color(1.0, 1.0, 1.0, 1.0)
	var obstacle_vertices = PlayerVision.extract_map_obstacle_vertices(main_node)

	# 2. Draw Vertex-Targeted Vision Shapes for all living teammates (1.0 = Full Color Vision)
	for tm in teammates:
		var tm_pos_3d = tm.global_position
		var tm_eye_pos = tm.get_predicted_vision_origin(1.25) if tm.has_method("get_predicted_vision_origin") else (tm_pos_3d + Vector3(0, 1.25, 0))
		var tm_fwd_3d = tm.get_facing_direction_3d() if tm.has_method("get_facing_direction_3d") else -tm.global_transform.basis.z.normalized()
		tm_fwd_3d.y = 0.0
		if tm_fwd_3d.length_squared() < 0.0001:
			tm_fwd_3d = Vector3.FORWARD
		tm_fwd_3d = tm_fwd_3d.normalized()

		# Height-scaled vision radii
		var height_mult = PlayerVision.get_height_vision_multiplier(tm_pos_3d.y)
		var effective_close_radius = CLOSE_RADIUS_M * height_mult

		# Close circle (5.5m base, scaled with elevation, vertex-shadowed)
		var close_poly = PlayerVision.generate_vertex_vision_polygon(
			camera, space_state, tm_eye_pos, effective_close_radius, false, tm_fwd_3d, 0.0, false, obstacle_vertices
		)
		if close_poly.size() >= 3:
			draw_colored_polygon(close_poly, vision_white)
			var close_loop = PackedVector2Array(close_poly)
			close_loop.append(close_poly[0])
			draw_polyline(close_loop, vision_white, 3.0, true)

		# Forward cone (24.0m normal or 70.0m Poke Ult, scaled with elevation, vertex-shadowed)
		var is_poke_ult_buff = (tm.get("poke_ult_buff_timer") != null and tm.poke_ult_buff_timer > 0.0)
		var base_cone_radius = 70.0 if is_poke_ult_buff else CONE_RADIUS_M
		var effective_cone_radius = base_cone_radius * height_mult
		var see_through = is_poke_ult_buff

		var cone_poly = PlayerVision.generate_vertex_vision_polygon(
			camera, space_state, tm_eye_pos, effective_cone_radius, true, tm_fwd_3d, deg_to_rad(CONE_HALF_ANGLE_DEG), see_through, obstacle_vertices
		)
		if cone_poly.size() >= 3:
			draw_colored_polygon(cone_poly, vision_white)
			var cone_loop = PackedVector2Array(cone_poly)
			cone_loop.append(cone_poly[0])
			draw_polyline(cone_loop, vision_white, 3.0, true)

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
				var z_poly = PlayerVision.generate_vertex_vision_polygon(
					camera, space_state, z_eye, z_rad_m, false, Vector3.FORWARD, 0.0, false, obstacle_vertices
				)
				if z_poly.size() >= 3:
					draw_colored_polygon(z_poly, vision_white)
					var z_loop = PackedVector2Array(z_poly)
					z_loop.append(z_poly[0])
					draw_polyline(z_loop, vision_white, 3.0, true)
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
				var f_poly = PlayerVision.generate_vertex_vision_polygon(
					camera, space_state, f_eye, f_rad_m, false, Vector3.FORWARD, 0.0, false, obstacle_vertices
				)
				if f_poly.size() >= 3:
					draw_colored_polygon(f_poly, vision_white)
					var f_loop = PackedVector2Array(f_poly)
					f_loop.append(f_poly[0])
					draw_polyline(f_loop, vision_white, 3.0, true)
				active_reveal_sources.append({"pos": f_pos_3d, "radius": f_rad_m})

	# 4. Update enemies & projectile entities visibility (hide entities in fog)
	_update_team_enemies_visibility(main_node, teammates, space_state, active_reveal_sources, focus_team, focus_id)

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
	if not players_container:
		return null

	# 1. Match local player by exact peer ID
	if my_id > 0:
		var exact_p = players_container.get_node_or_null(str(my_id))
		if exact_p and exact_p.name != "TrainingDummy":
			return exact_p
		for p in players_container.get_children():
			if p.name != "TrainingDummy" and p.name.to_int() == my_id:
				return p

	# 2. Solo / Training mode fallback (single player or authority)
	if not multiplayer.has_multiplayer_peer() or multiplayer.get_peers().is_empty():
		for p in players_container.get_children():
			if p.name != "TrainingDummy" and (p.name == "1" or p.name.to_int() == 1 or p.is_multiplayer_authority()):
				return p

	return null

func _reveal_all_players(main_node: Node) -> void:
	var players_container = main_node.get_node_or_null("Players")
	if players_container:
		for p in players_container.get_children():
			if p.has_method("set_opponent_visible"):
				p.set_opponent_visible(true)
	var proj_container = main_node.get_node_or_null("Projectiles")
	if proj_container:
		for proj in proj_container.get_children():
			proj.visible = true
	var hazard_container = main_node.get_node_or_null("HazardZones")
	if hazard_container:
		for h in hazard_container.get_children():
			h.visible = true

func _update_team_enemies_visibility(main_node: Node, teammates: Array, space_state: PhysicsDirectSpaceState3D, active_reveals: Array, focus_team: int, focus_id: int) -> void:
	var players_container = main_node.get_node_or_null("Players")
	if players_container:
		for player in players_container.get_children():
			if player in teammates:
				if player.has_method("set_opponent_visible"):
					player.set_opponent_visible(true)
				continue
			
			if not player.has_method("set_opponent_visible") or player.get("is_dead"):
				continue

			var target_pos = player.global_position
			var is_visible = _is_point_in_team_vision(target_pos, 1.25, teammates, space_state, active_reveals)
			player.set_opponent_visible(is_visible)

	# Hide enemy projectiles in Fog of War
	var proj_container = main_node.get_node_or_null("Projectiles")
	if proj_container:
		for proj in proj_container.get_children():
			var p_team = proj.get("shooter_team") if proj.get("shooter_team") != null else 0
			var p_shooter = proj.get("shooter_id") if proj.get("shooter_id") != null else 0
			var is_friendly = (p_team != 0 and p_team == focus_team) or (p_team == 0 and p_shooter == focus_id)
			if is_friendly:
				proj.visible = true
			else:
				var p_vis = _is_point_in_team_vision(proj.global_position, 0.4, teammates, space_state, active_reveals)
				proj.visible = p_vis

	# Hide enemy hazard zones in Fog of War
	var hazard_container = main_node.get_node_or_null("HazardZones")
	if hazard_container:
		for h in hazard_container.get_children():
			var h_team = h.get("shooter_team") if h.get("shooter_team") != null else 0
			var h_shooter = h.get("shooter_id") if h.get("shooter_id") != null else 0
			var is_friendly = (h_team != 0 and h_team == focus_team) or (h_team == 0 and h_shooter == focus_id)
			if is_friendly:
				h.visible = true
			else:
				var h_vis = _is_point_in_team_vision(h.global_position, 0.4, teammates, space_state, active_reveals)
				h.visible = h_vis

func _is_point_in_team_vision(target_pos: Vector3, eye_offset_y: float, teammates: Array, space_state: PhysicsDirectSpaceState3D, active_reveals: Array) -> bool:
	var target_eye_pos = target_pos + Vector3(0, eye_offset_y, 0)

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
		var height_mult = get_height_vision_multiplier(tm_pos.y)
		var effective_close_radius = CLOSE_RADIUS_M * height_mult
		var base_cone_radius = 70.0 if is_poke_ult_buff else CONE_RADIUS_M
		var effective_cone_radius = base_cone_radius * height_mult

		var in_vision_shape: bool = false

		# 1. Close proximity circle (scaled with height)
		if dist <= effective_close_radius:
			in_vision_shape = true
		# 2. Acute forward cone (scaled with height)
		elif dist <= effective_cone_radius and tm_fwd_2d.length_squared() > 0.001:
			var to_target_2d = diff_2d.normalized()
			var angle_deg = rad_to_deg(tm_fwd_2d.angle_to(to_target_2d))
			if abs(angle_deg) <= CONE_HALF_ANGLE_DEG:
				in_vision_shape = true
				if is_poke_ult_buff:
					return true

		if in_vision_shape:
			var query = PhysicsRayQueryParameters3D.create(tm_eye_pos, target_eye_pos, 1)
			query.collide_with_areas = false
			query.collide_with_bodies = true
			var result = space_state.intersect_ray(query)
			if result.is_empty() or tm_eye_pos.y >= result.position.y + 0.3:
				return true

	# Check active reveal sources (flares & reveal zones)
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
				return true

	return false
