class_name Silene
extends BasePlayer

# --- Passive: Draconic Ferocity ---
var passive_bonus_damage: float = 10.0
var _is_proccing_passive: bool = false

# --- Takedown Max Health Scaling (Permanent, persists across rounds) ---
var silene_takedown_bonus_hp: float = 0.0

# --- Dash (Shift): Dragon Leap & Juggernaut Rush (Grab & Slam) ---
var is_silene_dashing: bool = false
var is_charged_dash: bool = false
var dash_timer: float = 0.0
var dash_max_duration: float = 0.0
var dash_direction: Vector3 = Vector3.FORWARD
var dash_speed: float = 0.0
var dash_charge_ratio: float = 0.0
var grabbed_victim: Node = null
var collateral_hit_victims: Array[Node] = []

const DASH_UNCHARGED_SPEED: float = 22.0
const DASH_UNCHARGED_DIST: float = 8.0
const DASH_CHARGED_MIN_DIST: float = 12.0
const DASH_CHARGED_MAX_DIST: float = 28.0
const DASH_CHARGED_SPEED: float = 30.0
const DASH_OUTER_RADIUS: float = 3.2
const DASH_GRAB_RADIUS: float = 1.4

# --- E: Fire Breath (Height-Scaling, Terrain Raycasts) ---
var is_fire_breathing: bool = false
var fire_breath_timer: float = 0.0
var fire_breath_tick_timer: float = 0.0
var fire_breath_facing: Vector3 = Vector3.FORWARD
const FIRE_BREATH_DURATION: float = 2.2
const FIRE_BREATH_TICK_INTERVAL: float = 0.22
const FIRE_BREATH_TICK_DAMAGE: float = 6.0
const FIRE_BREATH_BASE_RADIUS: float = 8.0
const FIRE_BREATH_MAX_RADIUS: float = 17.0
const FIRE_BREATH_BASE_ANGLE: float = 60.0
const FIRE_BREATH_MAX_ANGLE: float = 95.0

# Visual node references
var _fire_mesh_instance: MeshInstance3D = null

func _setup_character_kit() -> void:
	if character_name.is_empty() or character_name == "Character":
		character_name = "The Dragon of Silene"
	if display_name.is_empty() or display_name == "Character":
		display_name = "Saint Silene"

	var data = SileneData.create()
	load_character_data(data)
	if data.passive_data.has("bonus_damage"):
		passive_bonus_damage = float(data.passive_data["bonus_damage"])

	var sync = get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	if sync and sync.replication_config:
		_add_sync_property(sync.replication_config, NodePath(".:silene_takedown_bonus_hp"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		_add_sync_property(sync.replication_config, NodePath(".:is_silene_dashing"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		_add_sync_property(sync.replication_config, NodePath(".:is_fire_breathing"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)

func _process_character_kit(delta: float) -> void:
	_process_dash(delta)
	_process_fire_breath(delta)

# --- 1. Passive: Draconic Ferocity (Separate Flat Damage Instance) ---

func _on_character_damage_dealt(target: Node, _amount: float, action_type: int) -> void:
	if _is_proccing_passive:
		return
	if is_dead:
		return
	if not is_instance_valid(target) or target == self:
		return
	if target.get("is_dead") == true:
		return
	
	# Any ability damage procs a separate flat damage instance
	if action_type == ActionType.ABILITY:
		_is_proccing_passive = true
		deal_damage(target, passive_bonus_damage, ActionType.ABILITY)
		_is_proccing_passive = false

# --- Takedown Health Scaling (+10 Max HP, Persists across rounds) ---
func _on_character_takedown(_victim: Node) -> void:
	apply_takedown_bonus_hp(10.0)

func apply_takedown_bonus_hp(amount: float) -> void:
	silene_takedown_bonus_hp += amount
	base_max_health += amount
	max_health += amount
	current_health += amount
	update_health_bar()
	
	# Store on main server if available to ensure persistence across round resets
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node and "connected_players" in main_node:
		var pid = peer_id
		if pid == 0 and str(name).is_valid_int():
			pid = str(name).to_int()
		if main_node.connected_players.has(pid):
			main_node.connected_players[pid]["silene_bonus_hp"] = silene_takedown_bonus_hp

func restore_saved_takedown_bonus_hp(saved_bonus: float) -> void:
	if saved_bonus <= 0.0 or saved_bonus == silene_takedown_bonus_hp:
		return
	var diff = saved_bonus - silene_takedown_bonus_hp
	silene_takedown_bonus_hp = saved_bonus
	base_max_health += diff
	max_health += diff
	current_health += diff
	update_health_bar()

# --- 2. Pipeline Execution Interceptor ---
func custom_execute_ability_server(slot_key: String, origin: Vector3, dir: Vector3, target_pos: Vector3, charge_ratio: float) -> bool:
	match slot_key:
		"LMB":
			_server_execute_claw_swipe(origin, dir)
			return true
		"SHIFT":
			_server_execute_dash(origin, dir, charge_ratio)
			return true
		"RMB":
			_server_execute_bite(origin, dir)
			return true
		"Q":
			_server_execute_tail_lash(origin, dir)
			return true
		"E":
			_server_execute_fire_breath(origin, dir)
			return true
		"R":
			_server_execute_roar(origin, dir)
			return true
	return false

func custom_execute_ability_client(slot_key: String, origin: Vector3, dir: Vector3, _target_pos: Vector3, charge_ratio: float) -> bool:
	match slot_key:
		"LMB":
			_client_play_claw_swipe_visual(origin, dir)
			return true
		"SHIFT":
			_client_execute_dash(origin, dir, charge_ratio)
			return true
		"RMB":
			_client_play_bite_visual(origin, dir)
			return true
		"Q":
			_client_play_tail_lash_visual(origin, dir)
			return true
		"E":
			_client_execute_fire_breath(origin, dir)
			return true
		"R":
			_client_play_roar_visual(origin, dir)
			return true
	return false

# --- 3. Annulus Sector Target Helper ---
func _get_enemies_in_annulus_sector(origin: Vector3, facing: Vector3, outer_radius: float, inner_radius: float, angle_deg: float, height: float = 3.0) -> Array[Node]:
	var result: Array[Node] = []
	var f = facing
	f.y = 0.0
	if f.length_squared() < 0.001:
		f = -global_transform.basis.z.normalized()
		f.y = 0.0
	f = f.normalized()
	var half_angle = angle_deg * 0.5
	
	for enemy in _get_all_enemy_targets():
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.get("is_dead") == true:
			continue
		if abs(enemy.global_position.y - origin.y) > height:
			continue
		var diff = enemy.global_position - origin
		diff.y = 0.0
		var dist = diff.length()
		if dist < inner_radius or dist > outer_radius:
			continue
		var dir_to_enemy = diff.normalized()
		var dot = clamp(f.dot(dir_to_enemy), -1.0, 1.0)
		var deg = rad_to_deg(acos(dot))
		if deg <= half_angle:
			result.append(enemy)
	return result

func _get_all_enemy_targets() -> Array[Node]:
	var enemies: Array[Node] = []
	var tree = get_tree()
	if not tree:
		return enemies
	var candidate_pool: Array[Node] = []
	for p in tree.get_nodes_in_group("players"):
		if not candidate_pool.has(p):
			candidate_pool.append(p)
	if tree.root:
		var pc = tree.root.get_node_or_null("Main/Players")
		if pc:
			for c in pc.get_children():
				if not candidate_pool.has(c):
					candidate_pool.append(c)
	for p in candidate_pool:
		if is_instance_valid(p) and not p.is_queued_for_deletion() and p != self and is_enemy(p) and not p.get("is_dead"):
			enemies.append(p)
	return enemies

# --- LMB: Claw Swipe (Annulus Sector) ---
func _server_execute_claw_swipe(origin: Vector3, dir: Vector3) -> void:
	# Annulus Sector: radius 3.8m, annul 0.8m, angle 100.0 deg
	var targets = _get_enemies_in_annulus_sector(origin, dir, 3.8, 0.8, 100.0)
	for target in targets:
		deal_damage(target, 24.0, ActionType.ABILITY)

# --- RMB: Dragon Bite (Annulus Sector, % Max Health DMG & Heal) ---
func _server_execute_bite(origin: Vector3, dir: Vector3) -> void:
	# Annulus Sector: radius 6.2m (same as Q), annul 1.0m, angle 63.0 deg (~30% thinner)
	var targets = _get_enemies_in_annulus_sector(origin, dir, 6.2, 1.0, 63.0)
	var total_damage_dealt: float = 0.0
	for target in targets:
		var target_max = target.get("max_health") if "max_health" in target else 100.0
		var bite_dmg = 18.0 + (float(target_max) * 0.16)
		deal_damage(target, bite_dmg, ActionType.ABILITY)
		total_damage_dealt += bite_dmg
	if total_damage_dealt > 0.0:
		heal(total_damage_dealt)

# --- Q: Tail Lash (Annulus Sector, Damage + Stun) ---
func _server_execute_tail_lash(origin: Vector3, dir: Vector3) -> void:
	# Annulus Sector: radius 6.2m, annul 2.0m, angle 180.0 deg
	var targets = _get_enemies_in_annulus_sector(origin, dir, 6.2, 2.0, 180.0)
	for target in targets:
		deal_damage(target, 30.0, ActionType.ABILITY)
		if target.has_method("apply_stun"):
			target.apply_stun(1.2)

# --- R: Primal Roar (Annulus Sector, Damage + Silence + Vacuum Drag) ---
func _server_execute_roar(origin: Vector3, dir: Vector3) -> void:
	# Annulus Sector: radius 13.0m, annul 2.2m, angle 100.0 deg
	var targets = _get_enemies_in_annulus_sector(origin, dir, 13.0, 2.2, 100.0)
	for target in targets:
		deal_damage(target, 45.0, ActionType.ABILITY)
		if target.has_method("apply_silence"):
			target.apply_silence(2.0)
		if target.has_method("apply_knockback"):
			var pull_dir = (global_position - target.global_position).normalized()
			pull_dir.y = 0.0
			if pull_dir.length_squared() < 0.001:
				pull_dir = -dir.normalized()
			target.apply_knockback(pull_dir * 16.0 + Vector3.UP * 3.0, true)

# --- Dash (Shift): Dragon Leap / Juggernaut Rush (Grab & Slam) ---
func _server_execute_dash(origin: Vector3, dir: Vector3, charge_ratio: float) -> void:
	start_dash(origin, dir, charge_ratio)
	if is_multiplayer_match() and multiplayer.is_server():
		sync_dash_start.rpc(origin, dir, charge_ratio)

func _client_execute_dash(origin: Vector3, dir: Vector3, charge_ratio: float) -> void:
	if is_local_player() and not is_server_authoritative():
		start_dash(origin, dir, charge_ratio)

@rpc("any_peer", "call_local", "reliable")
func sync_dash_start(origin: Vector3, dir: Vector3, charge_ratio: float) -> void:
	if not _is_sender_host():
		return
	if not is_server_authoritative():
		start_dash(origin, dir, charge_ratio)

func start_dash(_origin: Vector3, dir: Vector3, charge_ratio: float) -> void:
	var fwd = dir
	fwd.y = 0.0
	if fwd.length_squared() < 0.001:
		fwd = -global_transform.basis.z.normalized()
		fwd.y = 0.0
	dash_direction = fwd.normalized()
	dash_charge_ratio = charge_ratio
	is_charged_dash = (charge_ratio >= 0.25)
	
	if is_charged_dash:
		var norm_c = clamp((charge_ratio - 0.25) / 0.75, 0.0, 1.0)
		var total_dist = lerp(DASH_CHARGED_MIN_DIST, DASH_CHARGED_MAX_DIST, norm_c)
		dash_speed = DASH_CHARGED_SPEED
		dash_max_duration = total_dist / dash_speed
		dash_timer = dash_max_duration
		is_cc_immune = true # Charged is unstoppable
	else:
		dash_speed = DASH_UNCHARGED_SPEED
		dash_max_duration = DASH_UNCHARGED_DIST / dash_speed
		dash_timer = dash_max_duration
		is_cc_immune = false # Uncharged is vulnerable to CC
		velocity.y = 4.5 # Arced short leap
	
	is_silene_dashing = true
	grabbed_victim = null
	collateral_hit_victims.clear()
	look_at(global_position + dash_direction, Vector3.UP)

func _process_dash(delta: float) -> void:
	if not is_silene_dashing:
		return
	
	# CC check: If stopped by CC, release victim unharmed with NO damage and NO CC
	if is_stunned() or is_bound() or is_silenced():
		_cancel_dash_due_to_cc()
		return
	
	# Motion update
	velocity.x = dash_direction.x * dash_speed
	velocity.z = dash_direction.z * dash_speed
	dash_timer -= delta
	
	# Grab detection (Direct frontal contact)
	if grabbed_victim == null and is_server_authoritative():
		var grab_target = _find_first_enemy_in_grab_cone()
		if grab_target:
			grabbed_victim = grab_target
			if grabbed_victim.has_method("apply_bound"):
				grabbed_victim.apply_bound(self, 2.5)
	
	# Pin grabbed victim in front of Silene
	if is_instance_valid(grabbed_victim):
		grabbed_victim.global_position = global_position + dash_direction * 1.3
	
	# Charged Dash Outer Hitbox (Damages and knocks aside)
	if is_charged_dash and is_server_authoritative():
		_process_dash_outer_hitbox()
	
	# Wall collision detection: ends dash early but does not change effects
	var hit_wall = is_on_wall()
	if not hit_wall:
		hit_wall = _check_wall_ahead(1.1)
	
	if hit_wall or dash_timer <= 0.0:
		_execute_dash_slam()

func _find_first_enemy_in_grab_cone() -> Node:
	for enemy in _get_all_enemy_targets():
		if not is_instance_valid(enemy) or enemy.get("is_dead") == true:
			continue
		var diff = enemy.global_position - global_position
		diff.y = 0.0
		if diff.length() <= DASH_GRAB_RADIUS:
			var dot = dash_direction.dot(diff.normalized())
			if dot >= 0.65: # Within frontal ~50 deg cone
				return enemy
	return null

func _process_dash_outer_hitbox() -> void:
	for enemy in _get_all_enemy_targets():
		if not is_instance_valid(enemy) or enemy == grabbed_victim or enemy.get("is_dead") == true:
			continue
		if collateral_hit_victims.has(enemy):
			continue
		var diff = enemy.global_position - global_position
		diff.y = 0.0
		if diff.length() <= DASH_OUTER_RADIUS:
			collateral_hit_victims.append(enemy)
			deal_damage(enemy, 22.0, ActionType.ABILITY)
			if enemy.has_method("apply_knockback"):
				var aside_dir = diff.normalized()
				if aside_dir.length_squared() < 0.001:
					aside_dir = Vector3(-dash_direction.z, 0.0, dash_direction.x)
				enemy.apply_knockback(aside_dir * 14.0 + Vector3.UP * 4.0, true)

func _check_wall_ahead(reach: float) -> bool:
	var space_state = get_world_3d().direct_space_state
	if not space_state:
		return false
	var from_pos = global_position + Vector3.UP * 0.9
	var to_pos = from_pos + dash_direction * reach
	var query = PhysicsRayQueryParameters3D.create(from_pos, to_pos, 1) # Layer 1 = Environment
	query.exclude = [get_rid()]
	var res = space_state.intersect_ray(query)
	return not res.is_empty()

func _cancel_dash_due_to_cc() -> void:
	is_silene_dashing = false
	is_cc_immune = false
	velocity = Vector3.ZERO
	if is_instance_valid(grabbed_victim):
		if "bound_timer" in grabbed_victim:
			grabbed_victim.bound_timer = 0.0
		if "bound_caster_node" in grabbed_victim:
			grabbed_victim.bound_caster_node = null
		grabbed_victim = null

func _execute_dash_slam() -> void:
	is_silene_dashing = false
	is_cc_immune = false
	velocity = Vector3.ZERO
	
	if is_server_authoritative() and is_instance_valid(grabbed_victim):
		var slam_damage = 35.0 if not is_charged_dash else lerp(45.0, 75.0, clamp(dash_charge_ratio, 0.0, 1.0))
		var slam_stun = 0.8 if not is_charged_dash else 1.2
		deal_damage(grabbed_victim, slam_damage, ActionType.ABILITY)
		if grabbed_victim.has_method("apply_stun"):
			grabbed_victim.apply_stun(slam_stun)
		if "bound_timer" in grabbed_victim:
			grabbed_victim.bound_timer = 0.0
		if "bound_caster_node" in grabbed_victim:
			grabbed_victim.bound_caster_node = null
		grabbed_victim = null
	
	_spawn_slam_visual(global_position)

# --- E: Fire Breath (Cone DOT, Scales with Height, Raycast Vertices) ---
func _server_execute_fire_breath(origin: Vector3, dir: Vector3) -> void:
	start_fire_breath(origin, dir)
	if is_multiplayer_match() and multiplayer.is_server():
		sync_fire_breath_start.rpc(origin, dir)

func _client_execute_fire_breath(origin: Vector3, dir: Vector3) -> void:
	if is_local_player() and not is_server_authoritative():
		start_fire_breath(origin, dir)

@rpc("any_peer", "call_local", "reliable")
func sync_fire_breath_start(origin: Vector3, dir: Vector3) -> void:
	if not _is_sender_host():
		return
	if not is_server_authoritative():
		start_fire_breath(origin, dir)

func start_fire_breath(_origin: Vector3, dir: Vector3) -> void:
	var fwd = dir
	fwd.y = 0.0
	if fwd.length_squared() < 0.001:
		fwd = -global_transform.basis.z.normalized()
		fwd.y = 0.0
	fire_breath_facing = fwd.normalized()
	is_fire_breathing = true
	fire_breath_timer = FIRE_BREATH_DURATION
	fire_breath_tick_timer = 0.0
	_spawn_fire_breath_mesh()

func _process_fire_breath(delta: float) -> void:
	if not is_fire_breathing:
		return
	
	if is_stunned() or is_bound() or is_silenced():
		end_fire_breath()
		return
	
	fire_breath_timer -= delta
	fire_breath_tick_timer -= delta
	
	var height_above_ground = _get_height_above_ground()
	var current_radius = clamp(FIRE_BREATH_BASE_RADIUS + height_above_ground * 0.9, FIRE_BREATH_BASE_RADIUS, FIRE_BREATH_MAX_RADIUS)
	var current_angle = clamp(FIRE_BREATH_BASE_ANGLE + height_above_ground * 3.5, FIRE_BREATH_BASE_ANGLE, FIRE_BREATH_MAX_ANGLE)
	
	# Raycast boundary vertices and damage ticking
	if fire_breath_tick_timer <= 0.0:
		fire_breath_tick_timer = FIRE_BREATH_TICK_INTERVAL
		if is_server_authoritative():
			_tick_fire_breath_damage(current_radius, current_angle)
	
	_update_fire_breath_visual(current_radius, current_angle)
	
	if fire_breath_timer <= 0.0:
		end_fire_breath()

func end_fire_breath() -> void:
	is_fire_breathing = false
	fire_breath_timer = 0.0
	if is_instance_valid(_fire_mesh_instance):
		_fire_mesh_instance.queue_free()
		_fire_mesh_instance = null

func _get_height_above_ground() -> float:
	var space = get_world_3d().direct_space_state
	if not space:
		return 0.0
	var from_p = global_position + Vector3.UP * 0.2
	var to_p = from_p + Vector3.DOWN * 25.0
	var q = PhysicsRayQueryParameters3D.create(from_p, to_p, 1)
	q.exclude = [get_rid()]
	var res = space.intersect_ray(q)
	if not res.is_empty():
		return max(0.0, global_position.y - res.position.y)
	return 0.0

func calculate_fire_breath_vertices(origin: Vector3, facing: Vector3, radius: float, angle_deg: float, ray_count: int = 17) -> Array[Vector3]:
	var verts: Array[Vector3] = []
	var space = get_world_3d().direct_space_state
	var half_angle = deg_to_rad(angle_deg * 0.5)
	var step_angle = (half_angle * 2.0) / max(1, ray_count - 1)
	
	for i in range(ray_count):
		var ang = -half_angle + (step_angle * i)
		var ray_dir = facing.rotated(Vector3.UP, ang).normalized()
		var target_end = origin + ray_dir * radius
		
		if space:
			var query = PhysicsRayQueryParameters3D.create(origin, target_end, 1)
			query.exclude = [get_rid()]
			var res = space.intersect_ray(query)
			if not res.is_empty():
				verts.append(res.position)
				continue
		verts.append(target_end)
	return verts

func _tick_fire_breath_damage(radius: float, angle_deg: float) -> void:
	var origin = global_position + Vector3.UP * 1.1
	var facing = fire_breath_facing
	var half_angle = angle_deg * 0.5
	var space = get_world_3d().direct_space_state
	
	for enemy in _get_all_enemy_targets():
		if not is_instance_valid(enemy) or enemy.get("is_dead") == true:
			continue
		var enemy_pos = enemy.global_position + Vector3.UP * 0.9
		var diff = enemy_pos - origin
		diff.y = 0.0
		var dist = diff.length()
		if dist > radius:
			continue
		var dot = clamp(facing.dot(diff.normalized()), -1.0, 1.0)
		if rad_to_deg(acos(dot)) > half_angle:
			continue
		
		# Terrain line of sight check: must stop on terrain
		if space:
			var los_query = PhysicsRayQueryParameters3D.create(origin, enemy_pos, 1)
			los_query.exclude = [get_rid()]
			if enemy.has_method("get_rid"):
				los_query.exclude.append(enemy.get_rid())
			var los_hit = space.intersect_ray(los_query)
			if not los_hit.is_empty():
				# Terrain blocks fire from reaching this enemy
				continue
		
		deal_damage(enemy, FIRE_BREATH_TICK_DAMAGE, ActionType.ABILITY)

# --- Visual Effects & Aesthetics ---
func _play_claw_swipe_visual(origin: Vector3, dir: Vector3) -> void:
	_client_play_claw_swipe_visual(origin, dir)

func _client_play_claw_swipe_visual(_origin: Vector3, dir: Vector3) -> void:
	var tree = get_tree()
	if not tree or not tree.root:
		return
	var mesh_inst = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 3.8
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 0.9, 0.5, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_inst.mesh = torus
	mesh_inst.material_override = mat
	tree.root.add_child(mesh_inst)
	mesh_inst.global_position = global_position + Vector3.UP * 0.8 + dir * 1.5
	
	var tween = tree.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tween.tween_callback(mesh_inst.queue_free)

func _client_play_bite_visual(_origin: Vector3, dir: Vector3) -> void:
	var tree = get_tree()
	if not tree or not tree.root:
		return
	var bite_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1.26, 1.2, 2.2)
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.75, 0.15, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bite_mesh.mesh = box
	bite_mesh.material_override = mat
	tree.root.add_child(bite_mesh)
	bite_mesh.global_position = global_position + Vector3.UP * 0.9 + dir * 3.2
	
	var tween = tree.create_tween()
	tween.tween_property(bite_mesh, "scale", Vector3(0.2, 0.2, 0.2), 0.22)
	tween.tween_callback(bite_mesh.queue_free)

func _client_play_tail_lash_visual(_origin: Vector3, dir: Vector3) -> void:
	var tree = get_tree()
	if not tree or not tree.root:
		return
	var lash_mesh = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 2.0
	torus.outer_radius = 6.2
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.15, 0.85, 0.65, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lash_mesh.mesh = torus
	lash_mesh.material_override = mat
	tree.root.add_child(lash_mesh)
	lash_mesh.global_position = global_position + Vector3.UP * 0.5 + dir * 1.5
	
	var tween = tree.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tween.tween_callback(lash_mesh.queue_free)

func _client_play_roar_visual(_origin: Vector3, dir: Vector3) -> void:
	var tree = get_tree()
	if not tree or not tree.root:
		return
	var roar_mesh = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 2.2
	torus.outer_radius = 13.0
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.4, 0.1, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	roar_mesh.mesh = torus
	roar_mesh.material_override = mat
	tree.root.add_child(roar_mesh)
	roar_mesh.global_position = global_position + Vector3.UP * 0.7 + dir * 4.0
	
	var tween = tree.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tween.tween_callback(roar_mesh.queue_free)

func _spawn_slam_visual(pos: Vector3) -> void:
	var tree = get_tree()
	if not tree or not tree.root:
		return
	var slam_mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 3.0
	cyl.bottom_radius = 3.0
	cyl.height = 0.2
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.9, 0.6, 0.1, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	slam_mesh.mesh = cyl
	slam_mesh.material_override = mat
	tree.root.add_child(slam_mesh)
	slam_mesh.global_position = pos + Vector3.UP * 0.1
	
	var tween = tree.create_tween()
	tween.tween_property(slam_mesh, "scale", Vector3(1.4, 1.0, 1.4), 0.3)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tween.tween_callback(slam_mesh.queue_free)

func _spawn_fire_breath_mesh() -> void:
	if is_instance_valid(_fire_mesh_instance):
		_fire_mesh_instance.queue_free()
	_fire_mesh_instance = MeshInstance3D.new()
	var im = ImmediateMesh.new()
	_fire_mesh_instance.mesh = im
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.35, 0.05, 0.65)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fire_mesh_instance.material_override = mat
	add_child(_fire_mesh_instance)

func _update_fire_breath_visual(radius: float, angle_deg: float) -> void:
	if not is_instance_valid(_fire_mesh_instance):
		return
	var im = _fire_mesh_instance.mesh as ImmediateMesh
	if not im:
		return
	im.clear_surfaces()
	
	var origin = Vector3.UP * 1.1
	var verts = calculate_fire_breath_vertices(global_position + origin, fire_breath_facing, radius, angle_deg, 13)
	if verts.size() < 2:
		return
	
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(verts.size() - 1):
		var v1 = to_local(verts[i])
		var v2 = to_local(verts[i + 1])
		im.surface_add_vertex(origin)
		im.surface_add_vertex(v1)
		im.surface_add_vertex(v2)
	im.surface_end()

func get_status_text() -> String:
	if is_silene_dashing:
		return "✦ DRAGON RUSH (UNSTOPPABLE) ✦" if is_charged_dash else "✦ DRAGON LEAP ✦"
	elif is_fire_breathing:
		return "🔥 DRAGONFIRE BREATH 🔥"
	elif silene_takedown_bonus_hp > 0.0:
		return "✦ DRAGON MIGHT (+%d HP) ✦" % int(silene_takedown_bonus_hp)
	return ""
