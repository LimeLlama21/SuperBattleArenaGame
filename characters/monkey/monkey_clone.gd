class_name MonkeyClone
extends CharacterBody3D

signal died(clone: MonkeyClone)

var summoner: Node = null:
	set(value):
		if summoner != value and is_instance_valid(summoner) and summoner.has_method("unregister_clone"):
			summoner.unregister_clone(self)
		summoner = value
		if is_instance_valid(summoner):
			if summoner.has_method("register_clone"):
				summoner.register_clone(self)
			sync_stats_from_summoner(true)

var team_id: int = 1

var _max_health: float = 160.0
var _last_known_max_health: float = 160.0
var max_health: float:
	get:
		if is_instance_valid(summoner) and ("max_health" in summoner):
			return float(summoner.max_health)
		return _max_health
	set(value):
		_max_health = value
		_last_known_max_health = _max_health
		if current_health > _max_health:
			current_health = _max_health
		update_health_bar()

var current_health: float = 160.0:
	set(value):
		current_health = clamp(value, 0.0, max_health)
		update_health_bar()

var _damage: float = 24.0
var damage: float:
	get:
		if is_instance_valid(summoner) and ("damage" in summoner):
			return float(summoner.damage)
		return _damage
	set(value):
		_damage = value

var _max_move_speed: float = 6.0
var max_move_speed: float:
	get:
		if is_instance_valid(summoner) and ("max_move_speed" in summoner):
			return float(summoner.max_move_speed)
		return _max_move_speed
	set(value):
		_max_move_speed = value

var _haste: float = 0.0
var haste: float:
	get:
		if is_instance_valid(summoner) and ("haste" in summoner):
			return float(summoner.haste)
		return _haste
	set(value):
		_haste = value

var _crit_chance: float = 0.0
var crit_chance: float:
	get:
		if is_instance_valid(summoner) and ("crit_chance" in summoner):
			return float(summoner.crit_chance)
		return _crit_chance
	set(value):
		_crit_chance = value

var _crit_multiplier: float = 2.0
var crit_multiplier: float:
	get:
		if is_instance_valid(summoner) and ("crit_multiplier" in summoner):
			return float(summoner.crit_multiplier)
		return _crit_multiplier
	set(value):
		_crit_multiplier = value

var is_dead: bool = false
var lifetime: float = 10.0

var dash_cooldown: float = 0.0
const DASH_COOLDOWN_TIME: float = 3.5
const DASH_IMPULSE: float = 20.0

var attack_cooldown: float = 0.0
const ATTACK_COOLDOWN_TIME: float = 0.65
const ATTACK_RANGE: float = 3.2
const ATTACK_BASE_DAMAGE: float = 30.0
const ATTACK_DAMAGE_RATIO: float = 0.50

const TARGET_DETECTION_RANGE: float = 25.0
const FOLLOW_DISTANCE: float = 2.8

var _forward_vision_range: float = 24.0
var forward_vision_range: float:
	get:
		if is_instance_valid(summoner) and ("forward_vision_range" in summoner):
			return float(summoner.forward_vision_range)
		return _forward_vision_range
	set(value):
		_forward_vision_range = value

var _forward_vision_angle: float = 32.5
var forward_vision_angle: float:
	get:
		if is_instance_valid(summoner) and ("forward_vision_angle" in summoner):
			return float(summoner.forward_vision_angle)
		return _forward_vision_angle
	set(value):
		_forward_vision_angle = value

# Visual and UI nodes
var mesh_inst: MeshInstance3D = null
var staff_facing: MeshInstance3D = null
var health_bar_vp: SubViewport = null
var health_bar_progress: ProgressBar = null
var health_bar_sprite: Sprite3D = null

func _ready() -> void:
	add_to_group("players")
	collision_layer = 2
	collision_mask = 5

	_setup_nodes()
	_last_known_max_health = max_health
	update_health_bar()

func sync_stats_from_summoner(is_initial_spawn: bool = false) -> void:
	if not is_instance_valid(summoner):
		return
	if "team_id" in summoner:
		team_id = summoner.team_id
	
	var cur_max_hp = max_health
	if is_initial_spawn:
		if "current_health" in summoner:
			current_health = summoner.current_health
		else:
			current_health = cur_max_hp
		_last_known_max_health = cur_max_hp
	else:
		if _last_known_max_health > 0.0 and cur_max_hp != _last_known_max_health:
			var diff = cur_max_hp - _last_known_max_health
			if diff > 0.0:
				current_health += diff
			else:
				current_health = min(current_health, cur_max_hp)
		_last_known_max_health = cur_max_hp

	update_health_bar()

func inherit_stats_from_summoner() -> void:
	sync_stats_from_summoner(true)

func _setup_nodes() -> void:
	# 1. CollisionShape3D
	var col = CollisionShape3D.new()
	var cap_shape = CapsuleShape3D.new()
	cap_shape.radius = 0.38
	cap_shape.height = 1.8
	col.shape = cap_shape
	col.position = Vector3(0, 0.9, 0)
	add_child(col)

	# 2. MeshInstance3D
	mesh_inst = MeshInstance3D.new()
	var cap_mesh = CapsuleMesh.new()
	cap_mesh.radius = 0.38
	cap_mesh.height = 1.8
	mesh_inst.mesh = cap_mesh
	mesh_inst.position = Vector3(0, 0.9, 0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.88, 0.45, 0.12, 1.0)
	mat.metallic = 0.45
	mat.roughness = 0.35
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.55, 0.1, 1.0)
	mat.emission_energy_multiplier = 0.5
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	# 3. Staff Indicator
	staff_facing = MeshInstance3D.new()
	var staff_mesh = CylinderMesh.new()
	staff_mesh.top_radius = 0.06
	staff_mesh.bottom_radius = 0.06
	staff_mesh.height = 2.2
	staff_facing.mesh = staff_mesh
	staff_facing.transform = Transform3D(
		Basis(Vector3.UP, deg_to_rad(90)) * Basis(Vector3.RIGHT, deg_to_rad(90)),
		Vector3(0.45, 1.1, -0.2)
	)
	var gold_mat = StandardMaterial3D.new()
	gold_mat.albedo_color = Color(1.0, 0.85, 0.2, 1.0)
	gold_mat.metallic = 0.8
	gold_mat.roughness = 0.2
	gold_mat.emission_enabled = true
	gold_mat.emission = Color(1.0, 0.8, 0.15, 1.0)
	gold_mat.emission_energy_multiplier = 2.5
	staff_facing.material_override = gold_mat
	add_child(staff_facing)

	# 4. HealthBar SubViewport & ProgressBar
	health_bar_vp = SubViewport.new()
	health_bar_vp.name = "HealthBarViewport"
	health_bar_vp.disable_3d = true
	health_bar_vp.transparent_bg = true
	health_bar_vp.size = Vector2i(220, 28)
	health_bar_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	health_bar_progress = ProgressBar.new()
	health_bar_progress.custom_minimum_size = Vector2(220, 28)
	health_bar_progress.show_percentage = false
	var bg_sb = StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.15, 0.15, 0.15, 0.8)
	bg_sb.corner_radius_top_left = 4
	bg_sb.corner_radius_top_right = 4
	bg_sb.corner_radius_bottom_right = 4
	bg_sb.corner_radius_bottom_left = 4
	var fg_sb = StyleBoxFlat.new()
	fg_sb.bg_color = Color(0.95, 0.65, 0.15, 1.0)
	fg_sb.corner_radius_top_left = 4
	fg_sb.corner_radius_top_right = 4
	fg_sb.corner_radius_bottom_right = 4
	fg_sb.corner_radius_bottom_left = 4
	health_bar_progress.add_theme_stylebox_override("background", bg_sb)
	health_bar_progress.add_theme_stylebox_override("fill", fg_sb)
	health_bar_vp.add_child(health_bar_progress)
	add_child(health_bar_vp)

	# 5. Sprite3D
	health_bar_sprite = Sprite3D.new()
	health_bar_sprite.name = "HealthBarSprite"
	health_bar_sprite.transform = Transform3D(Basis().scaled(Vector3(1.25, 1.25, 1.25)), Vector3(0, 2.5, 0))
	health_bar_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_bar_sprite.double_sided = false
	health_bar_sprite.no_depth_test = true
	health_bar_sprite.texture = health_bar_vp.get_texture()
	add_child(health_bar_sprite)

func get_cooldown_multiplier() -> float:
	if is_instance_valid(summoner) and summoner.has_method("get_cooldown_multiplier"):
		return summoner.get_cooldown_multiplier()
	if haste > 0.0:
		return 100.0 / (100.0 + haste)
	return 1.0

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if is_instance_valid(summoner):
		var cur_max = max_health
		if cur_max != _last_known_max_health:
			sync_stats_from_summoner(false)

	lifetime -= delta
	if lifetime <= 0.0:
		die()
		return

	if dash_cooldown > 0.0:
		dash_cooldown -= delta
	if attack_cooldown > 0.0:
		attack_cooldown -= delta

	if not is_on_floor():
		velocity.y -= 25.0 * delta

	var target = find_target()
	if target and is_instance_valid(target):
		var to_target = target.global_position - global_position
		to_target.y = 0.0
		var dist = to_target.length()
		var dir = to_target.normalized() if dist > 0.001 else -global_transform.basis.z.normalized()

		if dir.length_squared() > 0.001:
			look_at(global_position + dir, Vector3.UP)

		# Dash towards enemy if > 4.5m away
		if dist > 4.5 and dash_cooldown <= 0.0:
			dash_cooldown = DASH_COOLDOWN_TIME * get_cooldown_multiplier()
			velocity.x = dir.x * DASH_IMPULSE
			velocity.z = dir.z * DASH_IMPULSE
		elif dist > ATTACK_RANGE * 0.8:
			velocity.x = dir.x * max_move_speed
			velocity.z = dir.z * max_move_speed
		else:
			velocity.x = 0.0
			velocity.z = 0.0

		# Attack enemy if in range
		if dist <= ATTACK_RANGE and attack_cooldown <= 0.0:
			attack_cooldown = ATTACK_COOLDOWN_TIME * get_cooldown_multiplier()
			perform_attack(target, dir)
	else:
		# Follow summoner
		if is_instance_valid(summoner):
			var to_summoner = summoner.global_position - global_position
			to_summoner.y = 0.0
			var dist = to_summoner.length()
			var dir = to_summoner.normalized() if dist > 0.001 else -global_transform.basis.z.normalized()

			if dir.length_squared() > 0.001:
				look_at(global_position + dir, Vector3.UP)

			if dist > FOLLOW_DISTANCE:
				velocity.x = dir.x * max_move_speed
				velocity.z = dir.z * max_move_speed
			else:
				velocity.x = 0.0
				velocity.z = 0.0
		else:
			velocity.x = 0.0
			velocity.z = 0.0

	move_and_slide()

func find_target() -> Node:
	var tree = get_tree()
	if not tree:
		return null
	var nearest_enemy: Node = null
	var nearest_dist: float = TARGET_DETECTION_RANGE

	var candidates: Array[Node] = []
	for p in tree.get_nodes_in_group("players"):
		if not candidates.has(p):
			candidates.append(p)
	if tree.root:
		var pc = tree.root.get_node_or_null("Main/Players")
		if pc:
			for child in pc.get_children():
				if not candidates.has(child):
					candidates.append(child)
		for child in tree.root.get_children():
			if not candidates.has(child):
				candidates.append(child)

	for enemy in candidates:
		if not is_instance_valid(enemy) or enemy == self or enemy == summoner:
			continue
		if not (enemy is Node3D):
			continue
		if not enemy.has_method("take_damage"):
			continue
		if enemy.get("is_dead") == true:
			continue
		var enemy_team = enemy.get("team_id")
		if enemy_team != null and enemy_team == team_id:
			continue

		# Check invisibility
		if enemy.has_method("is_invisible") and enemy.is_invisible():
			continue

		if not enemy.visible:
			continue

		var d = global_position.distance_to(enemy.global_position)
		if d <= nearest_dist:
			nearest_dist = d
			nearest_enemy = enemy

	return nearest_enemy

func perform_attack(target: Node, dir: Vector3) -> void:
	var dmg = ATTACK_BASE_DAMAGE + (float(damage) * ATTACK_DAMAGE_RATIO)
	if is_instance_valid(summoner) and summoner.has_method("get_damage_multiplier"):
		dmg *= summoner.get_damage_multiplier()
	if crit_chance > 0.0 and randf() < crit_chance:
		dmg *= crit_multiplier
	if target.has_method("take_damage"):
		var attacker_id = summoner.name.to_int() if is_instance_valid(summoner) else 0
		target.take_damage(dmg, attacker_id, BasePlayer.ActionType.ATTACK if ("ActionType" in BasePlayer) else 0)
	_play_swipe_visual(global_position, dir)

func _play_swipe_visual(origin: Vector3, dir: Vector3) -> void:
	var root_node = get_tree().root.get_node_or_null("Main") if (get_tree() and get_tree().root) else null
	if not root_node and get_tree():
		root_node = get_tree().root
	if not root_node:
		return

	var mesh_v = MeshInstance3D.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radius = 3.5
	var inner_r = 1.0
	var half_rad = deg_to_rad(50.0)
	var segments = 12

	for i in range(segments):
		var t0 = -half_rad + (float(i) / segments) * (half_rad * 2.0)
		var t1 = -half_rad + (float(i + 1) / segments) * (half_rad * 2.0)
		var in0 = Vector3(sin(t0) * inner_r, 0.1, -cos(t0) * inner_r)
		var out0 = Vector3(sin(t0) * radius, 0.1, -cos(t0) * radius)
		var in1 = Vector3(sin(t1) * inner_r, 0.1, -cos(t1) * inner_r)
		var out1 = Vector3(sin(t1) * radius, 0.1, -cos(t1) * radius)
		st.add_vertex(in0)
		st.add_vertex(out0)
		st.add_vertex(out1)
		st.add_vertex(in0)
		st.add_vertex(out1)
		st.add_vertex(in1)

	mesh_v.mesh = st.commit()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.25, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.15, 1.0)
	mat.emission_energy_multiplier = 4.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_v.material_override = mat

	root_node.add_child(mesh_v)
	mesh_v.global_position = origin
	var fwd = dir.normalized()
	fwd.y = 0.0
	if fwd.length_squared() > 0.001:
		mesh_v.look_at(origin + fwd, Vector3.UP)

	var tween = mesh_v.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.2)
	tween.tween_callback(mesh_v.queue_free)

# --- Vision Provider Interface (Fog of War) ---
func get_predicted_vision_origin(eye_height: float = 1.25) -> Vector3:
	var pred = global_position + velocity * 0.045
	pred.y = global_position.y + eye_height
	return pred

func get_facing_direction_3d() -> Vector3:
	var fwd = -global_transform.basis.z.normalized()
	fwd.y = 0.0
	return fwd.normalized() if fwd.length_squared() > 0.0001 else Vector3.FORWARD

func get_custom_cone_radius() -> float:
	return forward_vision_range

func get_custom_cone_half_angle_deg() -> float:
	return forward_vision_angle

func set_opponent_visible(is_vis: bool) -> void:
	if is_dead:
		visible = false
		return
	visible = is_vis
	if health_bar_sprite:
		health_bar_sprite.visible = is_vis

# --- Combat, Health & Life Cycle ---
func take_damage(amount: float, _attacker_id: int = 0, _action_type: int = 0) -> void:
	if is_dead:
		return
	current_health = max(0.0, current_health - amount)
	update_health_bar()
	if current_health <= 0.0:
		die()

func heal(amount: float) -> void:
	if is_dead:
		return
	current_health = min(max_health, current_health + amount)
	update_health_bar()

func update_health_bar() -> void:
	if health_bar_progress:
		health_bar_progress.max_value = max_health
		health_bar_progress.value = current_health

func apply_velocity_impulse(imp: Vector3, _grounded: bool = true) -> void:
	velocity += imp

func is_enemy(other: Node) -> bool:
	if not other or other == self:
		return false
	if other.get("team_id") != null:
		return other.team_id != team_id
	return true

func die() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit(self)
	queue_free()
