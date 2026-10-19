class_name Cleodolinda
extends BasePlayer

const CleodolindaData = preload("res://characters/cleodolinda/cleodolinda_data.gd")
const CleoTrailZoneClass = preload("res://characters/cleodolinda/cleo_trail_zone.gd")

# --- Attack (LMB / Spell 1): Semicircle Velocity Strike ---
@export_group("Attack Settings")
@export var attack_base_damage: float = 0.0 # No base damage; damage primarily comes from relative velocity calculation
@export var attack_damage_ratio: float = 0.30 # 30% damage ratio based on character damage stat
@export var attack_velocity_scaling: float = 1.5 # Extra damage per m/s of relative velocity
@export var attack_hitbox_radius: float = 4.0
@export var attack_hitbox_angle_deg: float = 180.0
@export var attack_hitbox_height: float = 2.4

# --- RMB (Spell 2): Full-Circle Strike (30 Damage Flat with 50% Ratio) ---
@export_group("RMB Settings")
@export var rmb_base_damage: float = 30.0 # 30 damage flat
@export var rmb_damage_ratio: float = 0.50 # 50% attack ratio
@export var rmb_radius: float = 4.5
@export var rmb_height: float = 2.5

# --- Q (Spell 2): Damaging Trail Settings ---
@export_group("Q Trail Settings")
@export var q_trail_base_tick_damage: float = 5.0 # 5 base damage
@export var q_trail_attack_ratio: float = 0.10 # 10% attack
@export var q_trail_tick_interval: float = 0.25 # every 0.25 seconds
@export var q_trail_segment_unit_time: float = 0.05 # Check every 0.05 seconds (20 times per second)
@export var q_trail_width: float = 3.2 # Trail width
@export var q_trail_linger_duration: float = 4.0 # Time trail lingers after being left behind

var is_q_trail_active: bool = false
var q_trail_timer: float = 0.0
var _active_trail_zone = null

# --- Ultimate (R): Maximum Suction ---
@export_group("Maximum Suction Settings")
@export var suction_duration: float = 3.5
@export var suction_radius: float = 14.0
@export var suction_angle_deg: float = 80.0
@export var suction_height: float = 3.5
@export var suction_acceleration: float = 7.5 # Strictly greater than standard base move speed 6.0
@export var suction_accel_factor: float = 1.25 # 25% greater than target's base speed
@export var suction_base_tick_damage: float = 10.0 # 10 damage per tick
@export var suction_damage_ratio: float = 0.05 # 5% attack ratio
@export var suction_tick_interval: float = 0.5 # every 0.5 seconds

var is_suction_active: bool = false
var suction_timer: float = 0.0
var suction_tick_timer: float = 0.0
var suction_facing: Vector3 = Vector3.FORWARD
var _suction_mesh_instance: MeshInstance3D = null
var _suction_anim_phase: float = 0.0
var _vacuum_base_pos: Vector3 = Vector3(0.35, 0.75, -0.35)

# --- Spell 3 / E (Hover Boost Settings & State) ---
@export_group("Spell 3 / Hover Boost Settings")
@export var spell_3_boost_pct: float = 0.50 # 50% increase to normal movement acceleration and ms cap

var is_spell_3_active: bool = false
var _spell_3_holding: bool = false

func _ready() -> void:
	super._ready()
	_setup_animations()
	_play_model_animation("Idle")
	_sync_rmb_damage()
	_sync_q_settings()
	_sync_r_settings()
	_sync_attack_damage()

func _setup_character_kit() -> void:
	if id.is_empty():
		id = "cleodolinda"
	if character_name.is_empty() or character_name == "Character":
		character_name = "Cleodolinda"
	if display_name.is_empty() or display_name == "Character":
		display_name = "Cleo"

	var data = CleodolindaData.create()
	load_character_data(data)

	if id.is_empty():
		id = "cleodolinda"
	if display_name.is_empty() or display_name == "Character":
		display_name = "Cleo"

	_sync_rmb_damage()
	_sync_q_settings()
	_sync_r_settings()
	_sync_attack_damage()

	var sync = get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	if sync and sync.replication_config:
		_add_sync_property(sync.replication_config, NodePath(".:is_suction_active"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		_add_sync_property(sync.replication_config, NodePath(".:is_spell_3_active"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		_add_sync_property(sync.replication_config, NodePath(".:is_q_trail_active"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)

func character_handles_slot(slot_key: String) -> bool:
	if slot_key == "E":
		return true
	return false

func _process_character_kit(delta: float) -> void:
	_process_suction(delta)
	_process_spell_3_input()
	_process_q_trail(delta)

# --- RMB & Q Ability Setup & Lifecycles ---
func _sync_rmb_damage() -> void:
	var rmb_ab = abilities.get("RMB")
	if rmb_ab:
		rmb_ab.windup_time = 0.0
		rmb_ab.delay = 0.0
		if "damage_amount" in rmb_ab:
			rmb_ab.damage_amount = rmb_base_damage
		if "damage_ratio" in rmb_ab:
			rmb_ab.damage_ratio = rmb_damage_ratio

func _sync_q_settings() -> void:
	var q_ab = abilities.get("Q")
	if q_ab:
		q_ab.windup_time = 0.0
		q_ab.delay = 0.0
		if "damage_amount" in q_ab:
			q_ab.damage_amount = q_trail_base_tick_damage
		if "damage_ratio" in q_ab:
			q_ab.damage_ratio = q_trail_attack_ratio

func _sync_r_settings() -> void:
	var r_ab = abilities.get("R")
	if r_ab:
		if "damage_amount" in r_ab:
			r_ab.damage_amount = suction_base_tick_damage
		if "damage_ratio" in r_ab:
			r_ab.damage_ratio = suction_damage_ratio

func compute_suction_tick_damage() -> float:
	return suction_base_tick_damage + (damage * suction_damage_ratio)

func get_q_anim_duration() -> float:
	var ap = _get_anim_player()
	if ap and ap.has_animation("spell 2"):
		var anim = ap.get_animation("spell 2")
		if anim and anim.length > 0.0:
			return anim.length
	return 2.5

func _server_execute_q_trail() -> void:
	start_q_trail()
	if is_multiplayer_match() and multiplayer.is_server():
		sync_q_trail_start.rpc()

func _client_execute_q_trail() -> void:
	if is_local_player() and not is_server_authoritative():
		start_q_trail()

@rpc("any_peer", "call_local", "reliable")
func sync_q_trail_start() -> void:
	if not _is_sender_host():
		return
	if not is_server_authoritative():
		start_q_trail()

func start_q_trail() -> void:
	is_q_trail_active = true
	q_trail_timer = get_q_anim_duration()

	if is_instance_valid(_active_trail_zone):
		_active_trail_zone.finish_emission()

	var zone = CleoTrailZoneClass.new()
	zone.caster = self
	zone.shooter_id = int(str(name)) if str(name).is_valid_int() else 1
	zone.shooter_team = team_id
	zone.base_tick_damage = q_trail_base_tick_damage
	zone.attack_ratio = q_trail_attack_ratio
	zone.tick_interval = q_trail_tick_interval
	zone.trail_width = q_trail_width
	zone.point_lifetime = q_trail_linger_duration
	zone.segment_unit_time = q_trail_segment_unit_time

	var parent_node = get_parent()
	if parent_node:
		parent_node.add_child(zone)
	else:
		add_child(zone)

	zone.global_transform = Transform3D.IDENTITY
	zone.add_trail_point(global_position)
	_active_trail_zone = zone

	_play_model_animation("spell 2")

func end_q_trail() -> void:
	is_q_trail_active = false
	q_trail_timer = 0.0
	if is_instance_valid(_active_trail_zone):
		_active_trail_zone.finish_emission()
		_active_trail_zone = null
	if _get_current_animation() == "spell 2" and not is_suction_active and not is_spell_3_active:
		_play_model_animation("Idle")

func _process_q_trail(delta: float) -> void:
	if not is_q_trail_active:
		return

	if is_dead or is_stunned() or is_silenced():
		end_q_trail()
		return

	q_trail_timer -= delta
	if is_instance_valid(_active_trail_zone):
		_active_trail_zone.add_trail_point(global_position, delta)

	if q_trail_timer <= 0.0:
		end_q_trail()

func _on_windup_id_changed(ability_id_str: String) -> void:
	super._on_windup_id_changed(ability_id_str)
	if ability_id_str == "RMB" or ability_id_str == "cleo_rmb" or ability_id_str == "Q" or ability_id_str == "cleo_spell_2":
		_play_model_animation("spell 2")
		if is_multiplayer_match() and multiplayer.is_server():
			sync_play_animation.rpc("spell 2")

func cancel_active_windup() -> void:
	var was_q = (active_windup_id == "Q" or active_windup_id == "cleo_spell_2")
	super.cancel_active_windup()
	if was_q:
		end_q_trail()

func sync_cancel_windup() -> void:
	var was_q = (active_windup_id == "Q" or active_windup_id == "cleo_spell_2")
	super.sync_cancel_windup()
	if was_q:
		end_q_trail()

func _is_playing_animation(anim_name: String) -> bool:
	var ap = _get_anim_player()
	return ap != null and ap.is_playing() and ap.current_animation == anim_name

# --- Ability Execution Hooks ---
func custom_execute_ability_server(slot_key: String, origin: Vector3, dir: Vector3, _target_pos: Vector3, _charge_ratio: float) -> bool:
	match slot_key:
		"LMB":
			_play_model_animation("spell 1")
			if is_multiplayer_match() and multiplayer.is_server():
				sync_play_animation.rpc("spell 1")
			return false
		"RMB":
			_play_model_animation("spell 2")
			if is_multiplayer_match() and multiplayer.is_server():
				sync_play_animation.rpc("spell 2")
			return false
		"Q":
			_server_execute_q_trail()
			return true
		"E":
			press_spell_3()
			return true
		"SHIFT":
			_play_model_animation("dash")
			if is_multiplayer_match() and multiplayer.is_server():
				sync_play_animation.rpc("dash")
			return false
		"R":
			_server_execute_maximum_suction(origin, dir)
			return true
	return false

func custom_execute_ability_client(slot_key: String, origin: Vector3, dir: Vector3, _target_pos: Vector3, _charge_ratio: float) -> bool:
	match slot_key:
		"LMB":
			_play_model_animation("spell 1")
			return false
		"RMB":
			_play_model_animation("spell 2")
			return false
		"Q":
			_client_execute_q_trail()
			return true
		"E":
			press_spell_3()
			return true
		"SHIFT":
			_play_model_animation("dash")
			return false
		"R":
			_client_execute_maximum_suction(origin, dir)
			return true
	return false

# --- Primary Attack (LMB / Spell 1) Scaling ---
func get_attack_relative_velocity(target: Node) -> float:
	var target_vel = Vector3.ZERO
	if is_instance_valid(target):
		if "velocity" in target and target.velocity is Vector3:
			target_vel = target.velocity
		elif target.has_method("get_velocity"):
			target_vel = target.get_velocity()
	var rel_vel = self.velocity - target_vel
	return rel_vel.length()

func compute_attack_damage(target: Node) -> float:
	var rel_speed = get_attack_relative_velocity(target) if is_instance_valid(target) else 0.0
	return attack_base_damage + (damage * attack_damage_ratio) + (rel_speed * attack_velocity_scaling)

func on_melee_strike_hit(target: Node, hit_data: Dictionary) -> void:
	var ability_key = hit_data.get("slot_key", "")
	var ab_id = hit_data.get("ability_id", "")
	# Only her attack (LMB / cleo_spell_1) scales off relative velocity.
	# The slow (RMB / cleo_rmb) does NOT scale off relative velocity.
	if ability_key == "LMB" or ab_id == "cleo_spell_1":
		var rel_speed = get_attack_relative_velocity(target)
		var bonus = rel_speed * attack_velocity_scaling
		hit_data["bonus_damage"] = bonus
		hit_data["damage_ratio"] = attack_damage_ratio

func _sync_attack_damage() -> void:
	var lmb_ab = abilities.get("LMB")
	if lmb_ab:
		if "damage_amount" in lmb_ab:
			lmb_ab.damage_amount = attack_base_damage
		if "damage_ratio" in lmb_ab:
			lmb_ab.damage_ratio = attack_damage_ratio

# --- Movement Modifiers (Spell 3 / E: Hover Boost) ---
func get_effective_max_speed(current_speed: float) -> float:
	var speed = super.get_effective_max_speed(current_speed)
	if is_spell_3_active:
		speed *= (1.0 + spell_3_boost_pct)
	return speed

func get_effective_acceleration(current_accel: float) -> float:
	var accel = super.get_effective_acceleration(current_accel)
	if is_spell_3_active:
		accel *= (1.0 + spell_3_boost_pct)
	return accel

# --- Ultimate: Maximum Suction (Wield Vacuum Cleaner, Large Cone, Inward Acceleration) ---
func _server_execute_maximum_suction(origin: Vector3, dir: Vector3) -> void:
	start_maximum_suction(origin, dir)
	if is_multiplayer_match() and multiplayer.is_server():
		sync_suction_start.rpc(origin, dir)

func _client_execute_maximum_suction(origin: Vector3, dir: Vector3) -> void:
	if is_local_player() and not is_server_authoritative():
		start_maximum_suction(origin, dir)

@rpc("any_peer", "call_local", "reliable")
func sync_suction_start(origin: Vector3, dir: Vector3) -> void:
	if not _is_sender_host():
		return
	if not is_server_authoritative():
		start_maximum_suction(origin, dir)

func start_maximum_suction(_origin: Vector3, dir: Vector3) -> void:
	var fwd = dir
	fwd.y = 0.0
	if fwd.length_squared() < 0.001:
		fwd = -global_transform.basis.z
		fwd.y = 0.0
	suction_facing = fwd.normalized() if fwd.length_squared() > 0.001 else Vector3.FORWARD

	is_suction_active = true
	suction_timer = suction_duration
	suction_tick_timer = 0.0
	is_channeling = true
	channel_timer = suction_duration

	var vac = get_node_or_null("VacuumCleaner") as Node3D
	if vac:
		vac.visible = true
		_vacuum_base_pos = vac.position

	_spawn_suction_vortex_mesh()
	_play_model_animation("Vacuum Cleaner Ult")

func end_maximum_suction() -> void:
	is_suction_active = false
	suction_timer = 0.0
	suction_tick_timer = 0.0
	is_channeling = false

	var vac = get_node_or_null("VacuumCleaner") as Node3D
	if vac:
		vac.visible = false
		vac.position = _vacuum_base_pos

	if is_instance_valid(_suction_mesh_instance):
		_suction_mesh_instance.queue_free()
		_suction_mesh_instance = null

	_play_model_animation("Idle")

func _process_suction(delta: float) -> void:
	if not is_suction_active:
		return

	if is_stunned() or is_bound() or is_silenced() or is_dead:
		end_maximum_suction()
		return

	suction_timer -= delta
	if suction_timer <= 0.0:
		end_maximum_suction()
		return

	# Continuously track current aim/facing direction
	var fwd = -global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() > 0.001:
		suction_facing = fwd.normalized()

	# Vacuum cleaner wielding vibration/shake micro-animation
	var vac = get_node_or_null("VacuumCleaner") as Node3D
	if vac:
		vac.visible = true
		var shake = Vector3(randf_range(-0.015, 0.015), randf_range(-0.015, 0.015), randf_range(-0.015, 0.015))
		vac.position = _vacuum_base_pos + shake

	# Detect affected enemies in cone
	var affected_enemies = _get_enemies_in_suction_cone()

	# Apply continuous acceleration towards Cleo & tick damage (Server Authoritative)
	if is_server_authoritative():
		for enemy in affected_enemies:
			_apply_suction_to_enemy(enemy, delta)
		
		suction_tick_timer += delta
		if suction_tick_timer >= suction_tick_interval:
			suction_tick_timer = fmod(suction_tick_timer, suction_tick_interval)
			var tick_dmg = compute_suction_tick_damage()
			for enemy in affected_enemies:
				deal_damage(enemy, tick_dmg, ActionType.ABILITY)

	# Update visual streamlines & suction vortex mesh
	_update_suction_visual(delta)

func _get_enemies_in_suction_cone() -> Array[Node]:
	var result: Array[Node] = []
	var origin = global_position
	var facing = suction_facing
	var half_angle = suction_angle_deg * 0.5
	var space = get_world_3d().direct_space_state if is_inside_tree() and get_world_3d() else null

	for enemy in _get_all_enemy_targets():
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.get("is_dead") == true:
			continue
		var enemy_pos = enemy.global_position
		if abs(enemy_pos.y - origin.y) > suction_height:
			continue
		var diff = enemy_pos - origin
		diff.y = 0.0
		var dist = diff.length()
		if dist > suction_radius:
			continue

		# Point-blank range (<= 0.8m) is always sucked into the vacuum intake
		if dist > 0.8:
			var dir_to_enemy = diff.normalized()
			var dot = clamp(facing.dot(dir_to_enemy), -1.0, 1.0)
			var angle = rad_to_deg(acos(dot))
			if angle > half_angle:
				continue

		# Line of sight check: terrain walls block suction
		if space:
			var from_p = origin + Vector3.UP * 0.9
			var to_p = enemy_pos + Vector3.UP * 0.9
			var los_query = PhysicsRayQueryParameters3D.create(from_p, to_p, 5) # Layer 1 (Ground) + Layer 3 (Terrain)
			los_query.exclude = [get_rid()]
			if enemy.has_method("get_rid"):
				los_query.exclude.append(enemy.get_rid())
			var hit = space.intersect_ray(los_query)
			if not hit.is_empty():
				continue

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
		for c in tree.root.get_children():
			if c is BasePlayer and not candidate_pool.has(c):
				candidate_pool.append(c)
	for p in candidate_pool:
		if is_instance_valid(p) and not p.is_queued_for_deletion() and p != self and is_enemy(p) and not p.get("is_dead"):
			enemies.append(p)
	return enemies

func _apply_suction_to_enemy(enemy: Node, delta: float) -> void:
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.get("is_dead") == true:
		return

	# Vector pointing directly towards Cleo
	var to_cleo = global_position - enemy.global_position
	to_cleo.y = 0.0
	var dist = to_cleo.length()
	var pull_dir = to_cleo.normalized() if dist > 0.001 else -global_transform.basis.z.normalized()
	pull_dir.y = 0.0
	pull_dir = pull_dir.normalized()

	# Determine enemy base move speed
	var enemy_base_spd = 6.0
	if "base_max_move_speed" in enemy:
		enemy_base_spd = float(enemy.base_max_move_speed)
	elif "max_move_speed" in enemy:
		enemy_base_spd = float(enemy.max_move_speed)

	# The acceleration should be slightly greater than base movement speed
	var effective_accel = max(suction_acceleration, enemy_base_spd * suction_accel_factor)
	var accel_vec = pull_dir * effective_accel

	# Near the nozzle (dist <= 1.0m), smooth deceleration prevents flinging through Cleo
	if dist <= 1.0:
		accel_vec *= clamp(dist / 1.0, 0.25, 1.0)

	if enemy.has_method("apply_external_acceleration"):
		enemy.apply_external_acceleration(accel_vec, delta)
	elif enemy.has_method("apply_knockback"):
		enemy.apply_knockback(accel_vec * delta, true)
	elif "velocity" in enemy:
		enemy.velocity += accel_vec * delta
	elif enemy is Node3D:
		enemy.global_position += pull_dir * (effective_accel * delta)

# --- Visual Effects & Suction Vortex ---
func _spawn_suction_vortex_mesh() -> void:
	if is_instance_valid(_suction_mesh_instance):
		_suction_mesh_instance.queue_free()
	_suction_mesh_instance = MeshInstance3D.new()
	var im = ImmediateMesh.new()
	_suction_mesh_instance.mesh = im
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.3, 0.85, 1.0, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_suction_mesh_instance.material_override = mat
	add_child(_suction_mesh_instance)

func _update_suction_visual(delta: float) -> void:
	if not is_instance_valid(_suction_mesh_instance):
		return
	var im = _suction_mesh_instance.mesh as ImmediateMesh
	if not im:
		return
	im.clear_surfaces()

	_suction_anim_phase += delta * 2.8
	if _suction_anim_phase > 1.0:
		_suction_anim_phase -= 1.0

	var nozzle_local = Vector3(0.35, 0.75, -1.25)
	var half_angle_rad = deg_to_rad(suction_angle_deg * 0.5)
	var stream_count = 14

	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(stream_count):
		var frac = float(i) / max(1, stream_count - 1)
		var angle = lerp(-half_angle_rad, half_angle_rad, frac)
		var dir_local = Vector3(sin(angle), 0, -cos(angle)).normalized()

		# Generate rushing streamline segments flowing inward from cone boundary
		var stream_progress = fmod(_suction_anim_phase + (float(i) * 0.17), 1.0)
		var start_dist = lerp(suction_radius, 0.8, stream_progress)
		var end_dist = max(0.4, start_dist - 2.5)

		var p1 = dir_local * start_dist + Vector3.UP * (0.6 + sin(stream_progress * PI) * 0.3)
		var p2 = dir_local * end_dist + Vector3.UP * (0.65 + sin((stream_progress + 0.1) * PI) * 0.2)

		im.surface_add_vertex(p1)
		im.surface_add_vertex(p2)

		# Add spiral suction tendrils drawing into the nozzle
		var swirl_angle = angle + stream_progress * 1.5
		var p_swirl = Vector3(sin(swirl_angle), 0, -cos(swirl_angle)) * (start_dist * 0.6) + Vector3.UP * 0.7
		im.surface_add_vertex(p_swirl)
		im.surface_add_vertex(nozzle_local)
	im.surface_end()

func get_status_text() -> String:
	if is_suction_active:
		return "🌪️ MAXIMUM SUCTION (%.1fs) 🌪️" % max(0.0, suction_timer)
	if is_spell_3_active:
		return "🚀 BOOST 🚀"
	return ""

# --- Spell 3 / E Lifecycle Controls ---
func _process_spell_3_input() -> void:
	if not is_local_player():
		return
	if is_stunned() or is_silenced() or is_dead:
		if is_spell_3_active or _spell_3_holding:
			cancel_spell_3()
		return
	if Input.is_action_just_pressed("ability_three"):
		press_spell_3()
	elif Input.is_action_just_released("ability_three"):
		release_spell_3()

func press_spell_3() -> void:
	if is_stunned() or is_silenced() or is_dead:
		return
	_spell_3_holding = true
	is_spell_3_active = true
	_play_model_animation("spell 3 boost start")
	if is_multiplayer_match():
		if multiplayer.is_server():
			sync_spell_3_press.rpc()
		else:
			request_spell_3_press.rpc_id(1)

func release_spell_3() -> void:
	_spell_3_holding = false
	var cur = _get_current_animation()
	if cur == "spell 3 continuous":
		_play_model_animation("spell 3 end")
	elif cur != "spell 3 boost start":
		is_spell_3_active = false
		_play_model_animation("Idle")
	if is_multiplayer_match():
		if multiplayer.is_server():
			sync_spell_3_release.rpc()
		else:
			request_spell_3_release.rpc_id(1)

func cancel_spell_3() -> void:
	_spell_3_holding = false
	is_spell_3_active = false
	_play_model_animation("Idle")
	if is_multiplayer_match() and multiplayer.is_server():
		sync_spell_3_cancel.rpc()

@rpc("any_peer", "call_local", "reliable")
func request_spell_3_press() -> void:
	if not is_server_authoritative():
		return
	press_spell_3()

@rpc("any_peer", "call_local", "reliable")
func request_spell_3_release() -> void:
	if not is_server_authoritative():
		return
	release_spell_3()

@rpc("any_peer", "call_local", "reliable")
func sync_spell_3_press() -> void:
	if not is_server_authoritative():
		_spell_3_holding = true
		is_spell_3_active = true
		_play_model_animation("spell 3 boost start")

@rpc("any_peer", "call_local", "reliable")
func sync_spell_3_release() -> void:
	if not is_server_authoritative():
		_spell_3_holding = false
		var cur = _get_current_animation()
		if cur == "spell 3 continuous":
			_play_model_animation("spell 3 end")
		elif cur != "spell 3 boost start":
			is_spell_3_active = false
			_play_model_animation("Idle")

@rpc("any_peer", "call_local", "reliable")
func sync_spell_3_cancel() -> void:
	if not is_server_authoritative():
		cancel_spell_3()

@rpc("any_peer", "call_local", "reliable")
func sync_play_animation(anim_name: String) -> void:
	if not is_server_authoritative():
		_play_model_animation(anim_name)

# --- Animation Controller & Events ---
func _setup_animations() -> void:
	var ap = _get_anim_player()
	if not ap:
		return
	var nose = get_node_or_null("FacingIndicator") as MeshInstance3D
	if nose:
		nose.visible = false
	if not ap.animation_finished.is_connected(_on_animation_finished):
		ap.animation_finished.connect(_on_animation_finished)
	var idle_anim = ap.get_animation("Idle")
	if idle_anim:
		idle_anim.loop_mode = Animation.LOOP_LINEAR
	var cont_anim = ap.get_animation("spell 3 continuous")
	if cont_anim:
		cont_anim.loop_mode = Animation.LOOP_LINEAR

func _on_animation_finished(anim_name: StringName) -> void:
	var name_str = String(anim_name)
	match name_str:
		"spell 3 boost start":
			if _spell_3_holding:
				_play_model_animation("spell 3 continuous")
			else:
				_play_model_animation("spell 3 end")
		"spell 3 end":
			is_spell_3_active = false
			_spell_3_holding = false
			_play_model_animation("Idle")
		"dash", "spell 1":
			if not is_suction_active and not is_spell_3_active:
				_play_model_animation("Idle")
		"spell 2":
			if is_q_trail_active:
				end_q_trail()
			elif not is_suction_active and not is_spell_3_active:
				_play_model_animation("Idle")

func _get_anim_player() -> AnimationPlayer:
	var model = get_node_or_null("CharacterModel")
	if model:
		var ap = model.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if ap:
			return ap
		for child in model.get_children():
			if child is AnimationPlayer:
				return child
	return null

func _get_current_animation() -> String:
	var ap = _get_anim_player()
	return ap.current_animation if ap else ""

func _play_model_animation(anim_name: String) -> void:
	var anim_player = _get_anim_player()
	if anim_player and anim_player.has_animation(anim_name):
		anim_player.play(anim_name)

