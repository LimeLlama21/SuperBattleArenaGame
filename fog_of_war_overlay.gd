extends Control

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
			draw_rect(Rect2(Vector2.ZERO, vp_size), Color(0.0, 0.0, 0.0, 1.0))
			_hide_all_opponents(main_node)
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
	var obstacles_2d = PlayerVision.extract_map_obstacles_2d(main_node)

	# 2. Draw Vertex-Targeted Vision Shapes for all living teammates (1.0 = Full Color Vision)
	for tm in teammates:
		var tm_pos_3d = tm.global_position
		var tm_eye_pos = tm.get_predicted_vision_origin(1.25) if tm.has_method("get_predicted_vision_origin") else (tm_pos_3d + Vector3(0, 1.25, 0))
		var tm_fwd_3d = tm.get_facing_direction_3d() if tm.has_method("get_facing_direction_3d") else -tm.global_transform.basis.z.normalized()
		tm_fwd_3d.y = 0.0
		if tm_fwd_3d.length_squared() < 0.0001:
			tm_fwd_3d = Vector3.FORWARD
		tm_fwd_3d = tm_fwd_3d.normalized()

		# Height-scaled vision radii with finite limits
		var height_mult = PlayerVision.get_height_vision_multiplier(tm_pos_3d.y)
		var base_cone_radius = tm.get_custom_cone_radius() if tm.has_method("get_custom_cone_radius") else PlayerVision.CONE_RADIUS_M
		var base_half_angle = tm.get_custom_cone_half_angle_deg() if tm.has_method("get_custom_cone_half_angle_deg") else PlayerVision.CONE_HALF_ANGLE_DEG
		var effective_close_radius = PlayerVision.CLOSE_RADIUS_M * height_mult
		var effective_cone_radius = base_cone_radius * height_mult

		# Close circle (5.5m base, scaled with elevation, vertex-shadowed)
		var close_poly = PlayerVision.generate_vertex_vision_polygon(
			camera, space_state, tm_eye_pos, effective_close_radius, false, tm_fwd_3d, 0.0, false, obstacles_2d
		)
		if close_poly.size() >= 3:
			draw_colored_polygon(close_poly, vision_white)
			var close_loop = PackedVector2Array(close_poly)
			close_loop.append(close_poly[0])
			draw_polyline(close_loop, vision_white, 3.0, true)

		# Forward cone (scaled with elevation, vertex-shadowed)
		var cone_poly = PlayerVision.generate_vertex_vision_polygon(
			camera, space_state, tm_eye_pos, effective_cone_radius, true, tm_fwd_3d, deg_to_rad(base_half_angle), false, obstacles_2d
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
					camera, space_state, z_eye, z_rad_m, false, Vector3.FORWARD, 0.0, false, obstacles_2d
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
					camera, space_state, f_eye, f_rad_m, false, Vector3.FORWARD, 0.0, false, obstacles_2d
				)
				if f_poly.size() >= 3:
					draw_colored_polygon(f_poly, vision_white)
					var f_loop = PackedVector2Array(f_poly)
					f_loop.append(f_poly[0])
					draw_polyline(f_loop, vision_white, 3.0, true)
				active_reveal_sources.append({"pos": f_pos_3d, "radius": f_rad_m})

	# 4. Update enemies & projectile entities visibility (hide entities in fog)
	_update_team_enemies_visibility(main_node, teammates, space_state, active_reveal_sources, focus_team, focus_id, obstacles_2d)

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

func _hide_all_opponents(main_node: Node) -> void:
	var players_container = main_node.get_node_or_null("Players")
	if players_container:
		for p in players_container.get_children():
			if p.has_method("set_opponent_visible"):
				var is_local = p.is_local_player() if p.has_method("is_local_player") else false
				if is_local:
					p.set_opponent_visible(not p.get("is_dead"))
				else:
					p.set_opponent_visible(false)
	var proj_container = main_node.get_node_or_null("Projectiles")
	if proj_container:
		for proj in proj_container.get_children():
			proj.visible = false
	var hazard_container = main_node.get_node_or_null("HazardZones")
	if hazard_container:
		for h in hazard_container.get_children():
			h.visible = false

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

func _update_team_enemies_visibility(main_node: Node, teammates: Array, space_state: PhysicsDirectSpaceState3D, active_reveals: Array, focus_team: int, focus_id: int, obstacles_2d: Array[Dictionary] = []) -> void:
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
			var is_visible = _is_point_in_team_vision(target_pos, 1.25, teammates, space_state, active_reveals, obstacles_2d)
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
				var p_vis = _is_point_in_team_vision(proj.global_position, 0.4, teammates, space_state, active_reveals, obstacles_2d)
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
				var h_vis = _is_point_in_team_vision(h.global_position, 0.4, teammates, space_state, active_reveals, obstacles_2d)
				h.visible = h_vis

func _is_point_in_team_vision(target_pos: Vector3, eye_offset_y: float, teammates: Array, _space_state: PhysicsDirectSpaceState3D, active_reveals: Array, obstacles_2d: Array[Dictionary] = []) -> bool:
	var target_eye_y = target_pos.y + eye_offset_y

	# Check line of sight from ANY living teammate
	for tm in teammates:
		var tm_pos = tm.global_position
		var tm_eye_pos = tm.get_predicted_vision_origin(1.25) if tm.has_method("get_predicted_vision_origin") else (tm_pos + Vector3(0, 1.25, 0))
		var tm_fwd_3d = tm.get_facing_direction_3d() if tm.has_method("get_facing_direction_3d") else -tm.global_transform.basis.z.normalized()
		tm_fwd_3d.y = 0.0
		if tm_fwd_3d.length_squared() < 0.0001:
			tm_fwd_3d = Vector3.FORWARD
		var tm_fwd_2d = Vector2(tm_fwd_3d.x, tm_fwd_3d.z).normalized()

		var diff = target_pos - tm_pos
		var diff_2d = Vector2(diff.x, diff.z)
		var dist = diff_2d.length()

		var height_mult = PlayerVision.get_height_vision_multiplier(tm_pos.y)
		var base_cone_radius = tm.get_custom_cone_radius() if tm.has_method("get_custom_cone_radius") else PlayerVision.CONE_RADIUS_M
		var base_half_angle = tm.get_custom_cone_half_angle_deg() if tm.has_method("get_custom_cone_half_angle_deg") else PlayerVision.CONE_HALF_ANGLE_DEG
		var effective_close_radius = PlayerVision.CLOSE_RADIUS_M * height_mult
		var effective_cone_radius = base_cone_radius * height_mult

		var in_vision_shape: bool = false

		# 1. Close proximity circle (finite size: 5.5m base, scaled with height)
		if dist <= effective_close_radius:
			in_vision_shape = true
		# 2. Forward cone (scaled with height & character stance)
		elif dist <= effective_cone_radius and tm_fwd_2d.length_squared() > 0.001:
			var to_target_2d = diff_2d.normalized()
			var angle_deg = rad_to_deg(tm_fwd_2d.angle_to(to_target_2d))
			if abs(angle_deg) <= base_half_angle:
				in_vision_shape = true

		if in_vision_shape:
			if PlayerVision.is_target_visible_2d(tm_pos, tm_eye_pos.y, target_pos, target_eye_y, obstacles_2d):
				return true

	# Check active reveal sources (flares & reveal zones)
	for r in active_reveals:
		var r_diff = target_pos - r["pos"]
		var r_dist = Vector2(r_diff.x, r_diff.z).length()
		if r_dist <= r["radius"]:
			var r_eye_y = r["pos"].y + 1.5
			if PlayerVision.is_target_visible_2d(r["pos"], r_eye_y, target_pos, target_eye_y, obstacles_2d):
				return true

	return false
