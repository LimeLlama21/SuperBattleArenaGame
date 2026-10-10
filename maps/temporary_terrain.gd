class_name TemporaryTerrain
extends AnimatableBody3D

@export var lifetime: float = 5.0
@export var terrain_size: Vector3 = Vector3(2.4, 3.2, 2.4)
var owner_id: int = 0
var is_wall: bool = false
var rise_duration: float = 0.16

var _is_despawning: bool = false
var _is_rising: bool = false
var _rise_timer: float = 0.0
var _target_y: float = 0.0
var _start_y: float = 0.0

func _ready() -> void:
	sync_to_physics = false
	_apply_terrain_size()
	if is_wall:
		set_as_wall(true)

	_target_y = position.y
	_start_y = _target_y - terrain_size.y
	position.y = _start_y
	_is_rising = true
	_rise_timer = 0.0

	var initial_rise_vel = terrain_size.y / max(0.01, rise_duration)
	_push_characters_up(initial_rise_vel)

	if is_server_authority() and get_tree():
		get_tree().create_timer(lifetime).timeout.connect(_despawn)

func is_server_authority() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()

func _snap_to_ground() -> void:
	if not is_inside_tree():
		return
	var world_3d = get_world_3d()
	if not world_3d:
		return
	var space = world_3d.direct_space_state
	if not space:
		return
	var ray_start = Vector3(global_position.x, _target_y + 1.5, global_position.z)
	var ray_end = Vector3(global_position.x, _target_y - 20.0, global_position.z)
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end, 1)
	query.exclude = [get_rid()]
	var hit = space.intersect_ray(query)
	if hit:
		_target_y = hit.position.y

func set_terrain_size(new_size: Vector3) -> void:
	terrain_size = new_size
	if is_node_ready():
		_apply_terrain_size()
	
	if _is_rising:
		_start_y = _target_y - terrain_size.y
		var t = clamp(_rise_timer / rise_duration, 0.0, 1.0)
		position.y = lerp(_start_y, _target_y, t)

func _apply_terrain_size() -> void:
	var col_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col_shape:
		var box_shape = BoxShape3D.new()
		box_shape.size = terrain_size
		col_shape.shape = box_shape
		col_shape.position = Vector3(0, terrain_size.y * 0.5, 0)
	var mesh_inst = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_inst:
		var box_mesh = BoxMesh.new()
		box_mesh.size = terrain_size
		mesh_inst.mesh = box_mesh
		mesh_inst.position = Vector3(0, terrain_size.y * 0.5, 0)

func set_as_wall(enabled: bool) -> void:
	is_wall = enabled
	if enabled:
		var mesh_inst = get_node_or_null("MeshInstance3D") as MeshInstance3D
		if mesh_inst:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.12, 0.16, 0.18, 1.0)
			mat.metallic = 0.3
			mat.roughness = 0.5
			mat.emission_enabled = true
			mat.emission = Color(0.92, 0.82, 0.35, 1.0)
			mat.emission_energy_multiplier = 1.2
			mesh_inst.material_override = mat

func set_target_position(pos: Vector3) -> void:
	position = pos
	_target_y = pos.y
	_snap_to_ground()
	_start_y = _target_y - terrain_size.y
	position.y = _start_y
	_rise_timer = 0.0
	_is_rising = true
	var initial_rise_vel = terrain_size.y / max(0.01, rise_duration)
	_push_characters_up(initial_rise_vel)

func start_rising(from_target_y: float = INF) -> void:
	if from_target_y != INF:
		_target_y = from_target_y
	else:
		_target_y = position.y
		_snap_to_ground()
	_start_y = _target_y - terrain_size.y
	position.y = _start_y
	_rise_timer = 0.0
	_is_rising = true
	var initial_rise_vel = terrain_size.y / max(0.01, rise_duration)
	_push_characters_up(initial_rise_vel)

func _physics_process(delta: float) -> void:
	if _is_rising:
		_rise_timer += delta
		var t = clamp(_rise_timer / rise_duration, 0.0, 1.0)
		var prev_y = position.y
		position.y = lerp(_start_y, _target_y, t)
		var delta_y = position.y - prev_y
		var rise_vel_y = delta_y / delta if delta > 0.0 else 0.0
		_push_characters_up(rise_vel_y)
		if t >= 1.0:
			_is_rising = false
			position.y = _target_y
			_push_characters_up(0.0)

func _push_characters_up(rise_vel: float) -> void:
	if not is_inside_tree():
		return
	var current_top_y = global_position.y + terrain_size.y
	var current_bottom_y = global_position.y

	var candidates: Array = []
	var tree = get_tree()
	if tree:
		var players = tree.get_nodes_in_group("players")
		for p in players:
			if is_instance_valid(p) and p is CharacterBody3D and not candidates.has(p):
				candidates.append(p)

	var space = get_world_3d().direct_space_state if get_world_3d() else null
	if space:
		var query = PhysicsShapeQueryParameters3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(terrain_size.x + 0.9, terrain_size.y + 2.0, terrain_size.z + 0.9)
		query.shape = box
		query.transform = Transform3D(global_transform.basis, Vector3(global_position.x, _target_y + terrain_size.y * 0.5, global_position.z))
		query.collide_with_bodies = true
		query.collide_with_areas = false
		var hits = space.intersect_shape(query, 32)
		for hit in hits:
			var col = hit.get("collider")
			if is_instance_valid(col) and col is CharacterBody3D and not candidates.has(col):
				candidates.append(col)

	for p in candidates:
		if not is_instance_valid(p) or not (p is CharacterBody3D):
			continue
		if "is_dead" in p and p.is_dead:
			continue

		var local_pos = to_local(p.global_position)
		var hx = terrain_size.x * 0.5 + 0.45
		var hz = terrain_size.z * 0.5 + 0.45

		if abs(local_pos.x) <= hx and abs(local_pos.z) <= hz:
			var p_y = p.global_position.y
			if p_y <= current_top_y + 0.25 and p_y >= current_bottom_y - 2.0:
				p.global_position.y = max(p.global_position.y, current_top_y)
				if "velocity" in p:
					if rise_vel > 0.0:
						p.velocity.y = max(p.velocity.y, rise_vel)
					else:
						if p.velocity.y < 0.0:
							p.velocity.y = 0.0

func _despawn() -> void:
	if _is_despawning or not is_inside_tree():
		return
	_is_despawning = true
	var tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	if tween:
		tween.tween_property(self, "position:y", position.y - (terrain_size.y + 0.5), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(queue_free)
	else:
		queue_free()
