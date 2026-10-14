class_name CleoTrailZone
extends Node3D

class TrailPoint extends RefCounted:
	var position: Vector3
	var spawn_time: float
	func _init(pos: Vector3, t: float = 0.0) -> void:
		position = pos
		spawn_time = t

class TrailSegment extends RefCounted:
	var start_pos: Vector3
	var end_pos: Vector3
	var spawn_time: float # Start timestamp when segment began measuring
	var unit_time: float # Measured unit of time for this segment
	var lifetime: float # Time to linger before shrinking begins
	
	func _init(p_start: Vector3, p_end: Vector3, p_spawn_time: float, p_unit_time: float, p_lifetime: float) -> void:
		start_pos = p_start
		end_pos = p_end
		spawn_time = p_spawn_time
		unit_time = max(0.0001, p_unit_time)
		lifetime = p_lifetime
	
	func get_length() -> float:
		return start_pos.distance_to(end_pos)
	
	func get_shrink_progress(now: float) -> float:
		var age = now - spawn_time
		if age <= lifetime:
			return 0.0
		var shrink_time = age - lifetime
		return clamp(shrink_time / unit_time, 0.0, 1.0)
	
	func is_fully_shrunk(now: float) -> bool:
		return get_shrink_progress(now) >= 1.0
	
	func get_current_start(now: float) -> Vector3:
		var p = get_shrink_progress(now)
		return start_pos.lerp(end_pos, p)
	
	func get_current_end(_now: float) -> Vector3:
		return end_pos
	
	func get_current_length(now: float) -> float:
		return get_current_start(now).distance_to(get_current_end(now))

var caster: Node = null
var shooter_id: int = 0
var shooter_team: int = 0
var base_tick_damage: float = 5.0
var attack_ratio: float = 0.10
var tick_interval: float = 0.25
var trail_width: float = 3.2
var trail_height: float = 2.5
var point_lifetime: float = 4.0 # Time each segment lingers before shrinking
var segment_unit_time: float = 0.05 # Measured unit of time for segment creation (0.05s / 20 checks per second)
var trail_color: Color = Color(0.2, 0.85, 1.0, 0.8)

var check_interval: float:
	get:
		return segment_unit_time
	set(val):
		segment_unit_time = val

var unit_time: float:
	get:
		return segment_unit_time
	set(val):
		segment_unit_time = val

var segments: Array[TrailSegment] = []
var points: Array[TrailPoint] = []
var is_emitting: bool = true
var tick_timer: float = 0.0
var min_point_dist_sq: float = 0.36 # ~0.6m min distance between sampled points

var active_segment_start_pos: Vector3 = Vector3.ZERO
var active_segment_current_pos: Vector3 = Vector3.ZERO
var active_segment_start_time: float = 0.0
var active_segment_has_started: bool = false
var current_time: float = 0.0

var mesh_instance: MeshInstance3D = null
var immediate_mesh: ImmediateMesh = null

func _ready() -> void:
	if current_time <= 0.0:
		current_time = Time.get_ticks_msec() / 1000.0
	_setup_mesh()

func _setup_mesh() -> void:
	mesh_instance = MeshInstance3D.new()
	immediate_mesh = ImmediateMesh.new()
	mesh_instance.mesh = immediate_mesh
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = trail_color
	mesh_instance.material_override = mat
	add_child(mesh_instance)

func _get_now() -> float:
	var wall = Time.get_ticks_msec() / 1000.0
	if wall > current_time:
		current_time = wall
	return current_time

func advance_time(dt: float) -> void:
	if current_time <= 0.0:
		current_time = Time.get_ticks_msec() / 1000.0
	current_time += dt

func add_trail_point(pos: Vector3, custom_delta: float = -1.0) -> void:
	if not is_emitting:
		return
	
	if custom_delta > 0.0:
		advance_time(custom_delta)
	var now = _get_now()
	
	if not active_segment_has_started:
		active_segment_start_pos = pos
		active_segment_current_pos = pos
		active_segment_start_time = now
		active_segment_has_started = true
		_sync_points_cache(now)
		return
	
	active_segment_current_pos = pos
	var elapsed = now - active_segment_start_time
	
	var should_finalize = elapsed >= segment_unit_time
	if not should_finalize and custom_delta <= 0.0 and active_segment_start_pos.distance_squared_to(pos) >= min_point_dist_sq:
		if elapsed <= 0.0001:
			should_finalize = true
			elapsed = segment_unit_time
			advance_time(segment_unit_time)
			now = current_time
	
	if should_finalize:
		var measured_unit = max(0.0001, elapsed)
		var seg = TrailSegment.new(active_segment_start_pos, pos, active_segment_start_time, measured_unit, point_lifetime)
		segments.append(seg)
		
		active_segment_start_pos = pos
		active_segment_current_pos = pos
		active_segment_start_time = now
	
	_sync_points_cache(now)

func finish_emission() -> void:
	if not is_emitting:
		return
	is_emitting = false
	var now = _get_now()
	if active_segment_has_started:
		var elapsed = max(0.0001, now - active_segment_start_time)
		if active_segment_start_pos.distance_squared_to(active_segment_current_pos) > 0.0001 or segments.is_empty():
			var seg = TrailSegment.new(active_segment_start_pos, active_segment_current_pos, active_segment_start_time, elapsed, point_lifetime)
			segments.append(seg)
		active_segment_has_started = false
	_sync_points_cache(now)

func _update_segments_lifecycle(now: float) -> void:
	while not segments.is_empty() and segments[0].is_fully_shrunk(now):
		segments.remove_at(0)
	_sync_points_cache(now)

func _sync_points_cache(now: float) -> void:
	points.clear()
	if segments.is_empty():
		if active_segment_has_started:
			points.append(TrailPoint.new(active_segment_start_pos, active_segment_start_time))
			if active_segment_start_pos.distance_squared_to(active_segment_current_pos) > 0.0001:
				points.append(TrailPoint.new(active_segment_current_pos, now))
		return
	
	var first_seg = segments[0]
	points.append(TrailPoint.new(first_seg.get_current_start(now), first_seg.spawn_time))
	for seg in segments:
		points.append(TrailPoint.new(seg.get_current_end(now), seg.spawn_time + seg.unit_time))
	
	if is_emitting and active_segment_has_started:
		if active_segment_start_pos.distance_squared_to(active_segment_current_pos) > 0.0001:
			points.append(TrailPoint.new(active_segment_current_pos, now))

func _process(delta: float) -> void:
	var now = _get_now()
	_update_segments_lifecycle(now)
	
	if not is_emitting and segments.is_empty() and not active_segment_has_started:
		queue_free()
		return
	
	_update_visual_mesh(now)

func _physics_process(delta: float) -> void:
	var now = _get_now()
	_update_segments_lifecycle(now)
	
	if not is_emitting and segments.is_empty() and not active_segment_has_started:
		queue_free()
		return
	
	if not is_server_authority():
		return
	
	tick_timer += delta
	if tick_timer >= tick_interval:
		tick_timer = fmod(tick_timer, tick_interval)
		_tick_damage()

func is_server_authority() -> bool:
	if is_instance_valid(caster) and caster.has_method("is_server_authoritative"):
		return caster.is_server_authoritative()
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()

func compute_tick_damage() -> float:
	var caster_dmg = 24.0
	if is_instance_valid(caster) and "damage" in caster:
		caster_dmg = float(caster.damage)
	return base_tick_damage + (caster_dmg * attack_ratio)

func force_tick_damage() -> void:
	_tick_damage()

func _tick_damage() -> void:
	if segments.is_empty() and not active_segment_has_started:
		return
	
	var enemies = _get_enemy_targets()
	if enemies.is_empty():
		return
	
	var half_width = trail_width * 0.5
	var tick_dmg = compute_tick_damage()
	
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.get("is_dead") == true:
			continue
		if is_point_in_trail(enemy.global_position, half_width):
			_apply_damage_to_enemy(enemy, tick_dmg)

func _apply_damage_to_enemy(enemy: Node, dmg: float) -> void:
	if is_instance_valid(caster) and caster.has_method("deal_damage"):
		caster.deal_damage(enemy, dmg, BasePlayer.ActionType.ABILITY)
	elif enemy.has_method("take_damage"):
		enemy.take_damage(dmg, shooter_id, BasePlayer.ActionType.ABILITY)

func is_point_in_trail(target_pos: Vector3, half_width: float) -> bool:
	var now = _get_now()
	var p2d = Vector2(target_pos.x, target_pos.z)
	
	for seg in segments:
		var p1 = seg.get_current_start(now)
		var p2 = seg.get_current_end(now)
		var seg_y = (p1.y + p2.y) * 0.5
		if abs(target_pos.y - seg_y) > trail_height:
			continue
		var a = Vector2(p1.x, p1.z)
		var b = Vector2(p2.x, p2.z)
		if _distance_to_segment_2d(p2d, a, b) <= half_width:
			return true
	
	if is_emitting and active_segment_has_started:
		var p1 = active_segment_start_pos
		var p2 = active_segment_current_pos
		var seg_y = (p1.y + p2.y) * 0.5
		if abs(target_pos.y - seg_y) <= trail_height:
			var a = Vector2(p1.x, p1.z)
			var b = Vector2(p2.x, p2.z)
			if _distance_to_segment_2d(p2d, a, b) <= half_width:
				return true
	
	return false

func _distance_to_segment_2d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab = b - a
	var ab_len_sq = ab.length_squared()
	if ab_len_sq < 0.0001:
		return p.distance_to(a)
	var t = clamp((p - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	var proj = a + ab * t
	return p.distance_to(proj)

func _get_enemy_targets() -> Array[Node]:
	if is_instance_valid(caster) and caster.has_method("_get_all_enemy_targets"):
		return caster._get_all_enemy_targets()
	var result: Array[Node] = []
	var tree = get_tree()
	if not tree:
		return result
	
	var candidates: Array[Node] = []
	for p in tree.get_nodes_in_group("players"):
		if not candidates.has(p):
			candidates.append(p)
	if tree.root:
		var pc = tree.root.get_node_or_null("Main/Players")
		if pc:
			for c in pc.get_children():
				if not candidates.has(c):
					candidates.append(c)
		for c in tree.root.get_children():
			if c is BasePlayer and not candidates.has(c):
				candidates.append(c)
	
	for p in candidates:
		if is_instance_valid(p) and not p.is_queued_for_deletion() and p != caster and not p.get("is_dead"):
			if is_instance_valid(caster) and caster.has_method("is_enemy"):
				if caster.is_enemy(p):
					result.append(p)
			else:
				var is_ally = (p.name == str(shooter_id)) or (shooter_team > 0 and p.get("team_id") != null and p.team_id == shooter_team)
				if not is_ally:
					result.append(p)
	return result

func _update_visual_mesh(now: float) -> void:
	if not immediate_mesh:
		return
	immediate_mesh.clear_surfaces()
	
	var r_points: Array[Dictionary] = []
	if segments.is_empty():
		if is_emitting and active_segment_has_started:
			r_points.append({"pos": active_segment_start_pos, "alpha": 1.0})
			if active_segment_start_pos.distance_to(active_segment_current_pos) > 0.05:
				r_points.append({"pos": active_segment_current_pos, "alpha": 1.0})
	else:
		for i in range(segments.size()):
			var seg = segments[i]
			var p1 = seg.get_current_start(now)
			var p2 = seg.get_current_end(now)
			var p_shrink = seg.get_shrink_progress(now)
			var alpha1 = clamp(1.0 - p_shrink * 0.5, 0.2, 1.0)
			
			if i == 0:
				r_points.append({"pos": p1, "alpha": alpha1})
			
			if p1.distance_to(p2) > 0.01:
				r_points.append({"pos": p2, "alpha": 1.0})
		
		if is_emitting and active_segment_has_started:
			if active_segment_start_pos.distance_to(active_segment_current_pos) > 0.05:
				r_points.append({"pos": active_segment_current_pos, "alpha": 1.0})
	
	if r_points.is_empty():
		return
	
	var half_w = trail_width * 0.5
	if r_points.size() == 1:
		var center = to_local(r_points[0]["pos"] + Vector3.UP * 0.06)
		var segs = 16
		immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for s in range(segs):
			var a1 = (float(s) / float(segs)) * TAU
			var a2 = (float(s + 1) / float(segs)) * TAU
			var p1 = center + Vector3(cos(a1), 0, sin(a1)) * half_w
			var p2 = center + Vector3(cos(a2), 0, sin(a2)) * half_w
			immediate_mesh.surface_set_color(Color(trail_color.r, trail_color.g, trail_color.b, r_points[0]["alpha"] * trail_color.a))
			immediate_mesh.surface_add_vertex(center)
			immediate_mesh.surface_set_color(Color(trail_color.r, trail_color.g, trail_color.b, 0.0))
			immediate_mesh.surface_add_vertex(p1)
			immediate_mesh.surface_set_color(Color(trail_color.r, trail_color.g, trail_color.b, 0.0))
			immediate_mesh.surface_add_vertex(p2)
		immediate_mesh.surface_end()
		return
	
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(r_points.size()):
		var pt_pos = r_points[i]["pos"] as Vector3
		var alpha = r_points[i]["alpha"] as float
		
		var dir = Vector3.FORWARD
		if i == 0:
			dir = (r_points[1]["pos"] - r_points[0]["pos"]).normalized()
		elif i == r_points.size() - 1:
			dir = (r_points[i]["pos"] - r_points[i - 1]["pos"]).normalized()
		else:
			dir = (r_points[i + 1]["pos"] - r_points[i - 1]["pos"]).normalized()
		dir.y = 0.0
		if dir.length_squared() < 0.001:
			dir = Vector3.FORWARD
		dir = dir.normalized()
		
		var side = dir.cross(Vector3.UP).normalized()
		var p_center = pt_pos + Vector3.UP * 0.06
		var p_left = p_center + side * half_w
		var p_right = p_center - side * half_w
		
		var col = Color(trail_color.r, trail_color.g, trail_color.b, alpha * trail_color.a)
		immediate_mesh.surface_set_color(col)
		immediate_mesh.surface_add_vertex(to_local(p_left))
		immediate_mesh.surface_set_color(col)
		immediate_mesh.surface_add_vertex(to_local(p_right))
	immediate_mesh.surface_end()

