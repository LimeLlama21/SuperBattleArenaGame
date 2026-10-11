class_name CleoTrailZone
extends Node3D

class TrailPoint extends RefCounted:
	var position: Vector3
	var spawn_time: float
	func _init(pos: Vector3, t: float) -> void:
		position = pos
		spawn_time = t

var caster: Node = null
var shooter_id: int = 0
var shooter_team: int = 0
var base_tick_damage: float = 5.0
var attack_ratio: float = 0.10
var tick_interval: float = 0.25
var trail_width: float = 3.2
var trail_height: float = 2.5
var point_lifetime: float = 4.0

var points: Array[TrailPoint] = []
var is_emitting: bool = true
var tick_timer: float = 0.0
var min_point_dist_sq: float = 0.36 # ~0.6m min distance between sampled points

var mesh_instance: MeshInstance3D = null
var immediate_mesh: ImmediateMesh = null

func _ready() -> void:
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
	mat.albedo_color = Color(0.2, 0.85, 1.0, 0.8)
	mesh_instance.material_override = mat
	add_child(mesh_instance)

func add_trail_point(pos: Vector3) -> void:
	if not is_emitting:
		return
	var now = Time.get_ticks_msec() / 1000.0
	if points.is_empty():
		points.append(TrailPoint.new(pos, now))
		return
	var last_p = points[points.size() - 1].position
	if last_p.distance_squared_to(pos) >= min_point_dist_sq or (now - points[points.size() - 1].spawn_time >= 0.25):
		points.append(TrailPoint.new(pos, now))
	else:
		points[points.size() - 1].position = pos

func finish_emission() -> void:
	is_emitting = false

func _process(delta: float) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	while not points.is_empty() and (now - points[0].spawn_time > point_lifetime):
		points.remove_at(0)
	
	if not is_emitting and points.is_empty():
		queue_free()
		return
	
	_update_visual_mesh(now)

func _physics_process(delta: float) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	while not points.is_empty() and (now - points[0].spawn_time > point_lifetime):
		points.remove_at(0)
	
	if not is_emitting and points.is_empty():
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
	if points.is_empty():
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
	if points.is_empty():
		return false
	
	var p2d = Vector2(target_pos.x, target_pos.z)
	
	if points.size() == 1:
		var pt = points[0].position
		if abs(target_pos.y - pt.y) <= trail_height:
			if p2d.distance_to(Vector2(pt.x, pt.z)) <= half_width:
				return true
		return false
	
	for i in range(points.size() - 1):
		var p1 = points[i].position
		var p2 = points[i + 1].position
		var seg_y = (p1.y + p2.y) * 0.5
		if abs(target_pos.y - seg_y) > trail_height:
			continue
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
	if not immediate_mesh or points.is_empty():
		if immediate_mesh:
			immediate_mesh.clear_surfaces()
		return
	
	immediate_mesh.clear_surfaces()
	var half_w = trail_width * 0.5
	
	if points.size() == 1:
		var pt = points[0]
		var age = now - pt.spawn_time
		var alpha = clamp(1.0 - (age / point_lifetime), 0.0, 1.0)
		immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		var center = to_local(pt.position + Vector3.UP * 0.06)
		var segs = 16
		for s in range(segs):
			var a1 = (float(s) / float(segs)) * TAU
			var a2 = (float(s + 1) / float(segs)) * TAU
			var p1 = center + Vector3(cos(a1), 0, sin(a1)) * half_w
			var p2 = center + Vector3(cos(a2), 0, sin(a2)) * half_w
			immediate_mesh.surface_set_color(Color(0.2, 0.85, 1.0, alpha * 0.75))
			immediate_mesh.surface_add_vertex(center)
			immediate_mesh.surface_set_color(Color(0.2, 0.85, 1.0, 0.0))
			immediate_mesh.surface_add_vertex(p1)
			immediate_mesh.surface_set_color(Color(0.2, 0.85, 1.0, 0.0))
			immediate_mesh.surface_add_vertex(p2)
		immediate_mesh.surface_end()
		return

	immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(points.size()):
		var pt = points[i]
		var age = now - pt.spawn_time
		var alpha = clamp(1.0 - (age / point_lifetime), 0.0, 1.0)
		
		var dir = Vector3.FORWARD
		if i == 0:
			dir = (points[1].position - points[0].position).normalized()
		elif i == points.size() - 1:
			dir = (points[i].position - points[i - 1].position).normalized()
		else:
			dir = (points[i + 1].position - points[i - 1].position).normalized()
		dir.y = 0.0
		if dir.length_squared() < 0.001:
			dir = Vector3.FORWARD
		dir = dir.normalized()
		
		var side = dir.cross(Vector3.UP).normalized()
		var p_center = pt.position + Vector3.UP * 0.06
		var p_left = p_center + side * half_w
		var p_right = p_center - side * half_w
		
		var col = Color(0.2, 0.85, 1.0, alpha * 0.75)
		immediate_mesh.surface_set_color(col)
		immediate_mesh.surface_add_vertex(to_local(p_left))
		immediate_mesh.surface_set_color(col)
		immediate_mesh.surface_add_vertex(to_local(p_right))
	immediate_mesh.surface_end()
