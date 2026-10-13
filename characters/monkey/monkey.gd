class_name Monkey
extends BasePlayer

const MonkeyKing = Monkey
const MonkeyData = preload("res://characters/monkey/monkey_data.gd")
const MonkeyKingData = MonkeyData
const MonkeyCloneClass = preload("res://characters/monkey/monkey_clone.gd")

# --- Stone Monkey (Passive) ---
var stone_monkey_charge: float = 100.0 # 0.0 to 100.0%
const STONE_MONKEY_MAX_CHARGE: float = 100.0
const STONE_MONKEY_CHARGE_PER_DAMAGE: float = 0.1 # 0.1% per 1 point of dealt damage
const STONE_MONKEY_CHARGE_PER_TAKEDOWN: float = 10.0 # 10% per kill or assist
var stone_monkey_cd_timer: float = 0.0 # Deprecated, kept for backward compatibility
const STONE_MONKEY_CD: float = 0.0
const STONE_MONKEY_DURATION: float = 3.0
var stone_monkey_active_timer: float = 0.0
var stone_monkey_heal_rate: float = 0.0
var default_mesh_material: Material = null
var default_staff_material: Material = null

# --- Doppelganger Clone (Q) ---
const Q_BASE_COOLDOWN: float = 16.0
const Q_MANA_COST: float = 10.0

# --- Camouflage (E) ---
var is_camouflaged: bool = false
var camouflage_timer: float = 0.0
var is_camouflage_detected: bool = false
const CAMOUFLAGE_MAX_DURATION: float = 10.0
const CAMOUFLAGE_DETECTION_RANGE: float = 6.0
const E_BASE_COOLDOWN: float = 14.0
const E_MANA_COST: float = 10.0

# --- Smoke Duel & Recast (R) ---
var ult_recast_window: float = 0.0
const ULT_RECAST_MAX_WINDOW: float = 3.5
const ULT_COOLDOWN: float = 30.0
const ULT_MANA_COST: float = 30.0
var duel_target: Node = null
var smoke_cloud_instance: MeshInstance3D = null

# --- 5-Second Target Copy Disguise ---
var disguise_timer: float = 0.0
const DISGUISE_MAX_DURATION: float = 5.0
var disguised_target: Node = null
var original_abilities: Dictionary = {}
var original_display_name: String = ""
var original_mesh: Mesh = null

# --- 3-Hit Combo (LMB) ---
var combo_step: int = 0 # 0 = Swipe 1, 1 = Swipe 2, 2 = Slam 3
var combo_reset_timer: float = 0.0
const COMBO_RESET_WINDOW: float = 1.25

const SWIPE_BASE_DAMAGE: float = 30.0
const SWIPE_ATTACK_RATIO: float = 0.50
const SWIPE_RADIUS: float = 4.5
const SWIPE_ANGLE: float = 100.0

const SLAM_BASE_DAMAGE: float = 50.0
const SLAM_ATTACK_RATIO: float = 0.75
const SLAM_LENGTH: float = 8.5
const SLAM_WIDTH: float = 1.6

# --- Visual Indicators & Nodes ---
@onready var staff_facing: MeshInstance3D = get_node_or_null("FacingIndicator")

func _setup_character_kit() -> void:
	if id.is_empty():
		id = "monkey"
	var data = MonkeyKingData.create()
	load_character_data(data)

	var mesh_inst: MeshInstance3D = get_node_or_null("MeshInstance3D")
	if mesh_inst:
		default_mesh_material = mesh_inst.material_override
		if not default_mesh_material and mesh_inst.mesh:
			default_mesh_material = mesh_inst.mesh.material

	if staff_facing:
		default_staff_material = staff_facing.material_override
		if not default_staff_material and staff_facing.mesh:
			default_staff_material = staff_facing.mesh.material

	var sync = get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	if sync and sync.replication_config:
		_add_sync_property(sync.replication_config, NodePath(".:ult_recast_window"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		_add_sync_property(sync.replication_config, NodePath(".:stone_monkey_active_timer"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		_add_sync_property(sync.replication_config, NodePath(".:combo_step"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		_add_sync_property(sync.replication_config, NodePath(".:stone_monkey_charge"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		_add_sync_property(sync.replication_config, NodePath(".:is_camouflaged"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		_add_sync_property(sync.replication_config, NodePath(".:is_camouflage_detected"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		_add_sync_property(sync.replication_config, NodePath(".:disguise_timer"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)

	_update_lmb_node_config()

func character_handles_slot(slot_key: String) -> bool:
	if slot_key == "R" and ult_recast_window > 0.0:
		return true
	return false

func get_custom_ability_mana_cost(slot_key: String, _ability_id: String) -> float:
	if slot_key == "R" and ult_recast_window > 0.0:
		return 0.0 # Free recast of Ultimate
	if slot_key == "Q":
		return Q_MANA_COST
	if slot_key == "E":
		return E_MANA_COST
	return -1.0

func should_ability_start_cooldown_on_cast(slot_key: String, _ability_id: String) -> bool:
	if slot_key == "R":
		return false
	if slot_key == "E":
		return false
	return true

func start_ability_cooldown(slot_key: String, duration: float) -> void:
	var ab = abilities.get(slot_key)
	if ab:
		var mult = get_cooldown_multiplier() if has_method("get_cooldown_multiplier") else 1.0
		ab.current_cooldown = duration * mult

func _process_character_kit(delta: float) -> void:
	# 3-Hit Combo Reset Timer
	if combo_reset_timer > 0.0:
		combo_reset_timer -= delta
		if combo_reset_timer <= 0.0:
			combo_reset_timer = 0.0
			combo_step = 0
			_update_lmb_node_config()

	# Passive: Active Stone Monkey Healing & State
	if stone_monkey_active_timer > 0.0:
		stone_monkey_active_timer -= delta
		if stone_monkey_heal_rate > 0.0:
			heal(stone_monkey_heal_rate * delta)
		if stone_monkey_active_timer <= 0.0:
			stone_monkey_active_timer = 0.0
			stone_monkey_heal_rate = 0.0
			_set_stone_material(false)
			if is_multiplayer_match() and is_server_authoritative():
				sync_stone_visual.rpc(false)

	# Passive Proc Check: Critical health (<= 30%) with full charge (100%)
	if not is_dead and is_stone_monkey_ready():
		if current_health <= (max_health * 0.30):
			_trigger_stone_monkey()

	# Camouflage (E) Timer & Proximity Detection
	if is_camouflaged:
		camouflage_timer -= delta
		if camouflage_timer <= 0.0:
			break_camouflage()
		else:
			var detected = false
			var enemies = _get_all_enemy_targets()
			for enemy in enemies:
				if not is_instance_valid(enemy) or enemy.get("is_dead") == true:
					continue
				if global_position.distance_to(enemy.global_position) <= CAMOUFLAGE_DETECTION_RANGE:
					detected = true
					break
			if is_camouflage_detected != detected:
				is_camouflage_detected = detected
				_update_camouflage_visuals()
				if is_multiplayer_match() and is_server_authoritative():
					sync_camouflage_detected.rpc(is_camouflage_detected)

	# 5-Second Target Copy Disguise Timer (R Phase 3)
	if disguise_timer > 0.0:
		disguise_timer -= delta
		if disguise_timer <= 0.0:
			_revert_disguise()

	# Ultimate Recast Window Timer (R Phase 1 -> Phase 2)
	if ult_recast_window > 0.0:
		ult_recast_window -= delta
		if ult_recast_window <= 0.0:
			ult_recast_window = 0.0
			var fwd = -global_transform.basis.z.normalized()
			fwd.y = 0.0
			_server_execute_ult_recast(fwd)

func _on_damage_taken_hook(_amount: float, _attacker_id: int, _action_type: int) -> void:
	# Taking damage breaks camouflage
	if is_camouflaged:
		break_camouflage()

	# Check if incoming damage brought Monkey King to or below critical health
	if not is_dead and is_stone_monkey_ready():
		if current_health <= (max_health * 0.30):
			if current_health <= 0.0:
				current_health = max(1.0, max_health * 0.05)
			_trigger_stone_monkey()

func _trigger_stone_monkey() -> void:
	stone_monkey_charge = 0.0
	stone_monkey_active_timer = STONE_MONKEY_DURATION
	var missing_hp = max(0.0, max_health - current_health)
	stone_monkey_heal_rate = (missing_hp * 0.30) / STONE_MONKEY_DURATION

	apply_invulnerability(STONE_MONKEY_DURATION)
	apply_displacement_immunity(STONE_MONKEY_DURATION)
	_set_stone_material(true)

	if is_multiplayer_match() and is_server_authoritative():
		sync_stone_visual.rpc(true)
		sync_stone_monkey_charge.rpc(0.0)

# --- Stone Monkey Charging & Helpers ---
func is_stone_monkey_ready() -> bool:
	return stone_monkey_charge >= STONE_MONKEY_MAX_CHARGE and stone_monkey_active_timer <= 0.0

func add_stone_monkey_charge(amount: float) -> void:
	if amount <= 0.0:
		return
	stone_monkey_charge = clamp(stone_monkey_charge + amount, 0.0, STONE_MONKEY_MAX_CHARGE)
	if is_multiplayer_match() and is_server_authoritative():
		sync_stone_monkey_charge.rpc(stone_monkey_charge)

func set_stone_monkey_charge(val: float) -> void:
	stone_monkey_charge = clamp(val, 0.0, STONE_MONKEY_MAX_CHARGE)
	if is_multiplayer_match() and is_server_authoritative():
		sync_stone_monkey_charge.rpc(stone_monkey_charge)

func get_stone_monkey_charge() -> float:
	return stone_monkey_charge

func _on_character_damage_dealt(_target: Node, amount: float, _action_type: int) -> void:
	if amount > 0.0:
		add_stone_monkey_charge(amount * STONE_MONKEY_CHARGE_PER_DAMAGE)

func _on_character_takedown(_victim: Node) -> void:
	add_stone_monkey_charge(STONE_MONKEY_CHARGE_PER_TAKEDOWN)

@rpc("any_peer", "call_local", "reliable")
func sync_stone_monkey_charge(new_charge: float) -> void:
	if not _is_sender_host():
		return
	stone_monkey_charge = new_charge

@rpc("any_peer", "call_local", "reliable")
func sync_stone_visual(is_stone: bool) -> void:
	_set_stone_material(is_stone)

func _set_stone_material(is_stone: bool) -> void:
	var mesh_inst: MeshInstance3D = get_node_or_null("MeshInstance3D")
	if mesh_inst:
		if is_stone:
			var stone_mat = StandardMaterial3D.new()
			stone_mat.albedo_color = Color(0.48, 0.48, 0.50, 1.0)
			stone_mat.roughness = 0.95
			stone_mat.metallic = 0.05
			mesh_inst.material_override = stone_mat
		else:
			mesh_inst.material_override = default_mesh_material if default_mesh_material else null

	if staff_facing:
		if is_stone:
			var stone_mat2 = StandardMaterial3D.new()
			stone_mat2.albedo_color = Color(0.40, 0.40, 0.42, 1.0)
			stone_mat2.roughness = 0.95
			stone_mat2.metallic = 0.05
			staff_facing.material_override = stone_mat2
		else:
			staff_facing.material_override = default_staff_material if default_staff_material else null

# --- Invisibility Override for Camouflage ---
func is_invisible() -> bool:
	if invisibility_timer > 0.0:
		return true
	if is_camouflaged and not is_camouflage_detected:
		return true
	return false

func set_opponent_visible(is_vis: bool) -> void:
	if is_local_player():
		visible = not is_dead
		return
	if is_dead or is_invisible():
		visible = false
		if sprite_3d:
			sprite_3d.visible = false
		return
	visible = is_vis
	if sprite_3d:
		sprite_3d.visible = is_vis

# --- Input Handling for R Recast ---
func _handle_character_input(_delta: float) -> void:
	if ult_recast_window > 0.0:
		if Input.is_action_just_pressed("ability_four"):
			_execute_ult_recast_rush()

# --- Dynamic LMB Ability Node Config ---
func _update_lmb_node_config() -> void:
	var lmb_ab = abilities.get("LMB")
	if lmb_ab:
		if combo_step < 2:
			lmb_ab.hitbox_type = 1 # Sector / Cone
			lmb_ab.hitbox_radius = SWIPE_RADIUS
			lmb_ab.hitbox_angle_deg = SWIPE_ANGLE
			lmb_ab.damage_amount = SWIPE_BASE_DAMAGE
			lmb_ab.damage_ratio = SWIPE_ATTACK_RATIO
		else:
			lmb_ab.hitbox_type = 5 # Line
			lmb_ab.hitbox_length = SLAM_LENGTH
			lmb_ab.hitbox_width = SLAM_WIDTH
			lmb_ab.damage_amount = SLAM_BASE_DAMAGE
			lmb_ab.damage_ratio = SLAM_ATTACK_RATIO

func try_cast_ability(slot_key: String, charge_ratio: float = 0.0) -> bool:
	var eff_slot = get_effective_slot(slot_key)
	if eff_slot != "SHIFT" and eff_slot != "E":
		if is_camouflaged:
			break_camouflage()
	return super.try_cast_ability(slot_key, charge_ratio)

func request_cast_ability(slot_key: String, origin: Vector3, direction: Vector3, target_pos: Vector3, charge_ratio: float = 0.0) -> void:
	var eff_slot = get_effective_slot(slot_key)
	if eff_slot != "SHIFT" and eff_slot != "E":
		if is_camouflaged:
			break_camouflage()
	super.request_cast_ability(slot_key, origin, direction, target_pos, charge_ratio)

# --- Custom Ability Execution (Server & Client) ---
func custom_execute_ability_server(slot_key: String, origin: Vector3, dir: Vector3, _target_pos: Vector3, charge_ratio: float) -> bool:
	if slot_key != "SHIFT" and slot_key != "E":
		if is_camouflaged:
			break_camouflage()

	match slot_key:
		"LMB":
			_server_execute_attack_combo(origin, dir)
			return true
		"RMB":
			_server_execute_enlarge(origin, dir, charge_ratio)
			return true
		"Q":
			_server_execute_clone()
			return true
		"E":
			_server_execute_camouflage()
			return true
		"R":
			if ult_recast_window > 0.0:
				_server_execute_ult_recast(dir)
			else:
				_server_execute_ult_initial(dir)
			return true
	return false

func custom_execute_ability_client(slot_key: String, origin: Vector3, dir: Vector3, _target_pos: Vector3, charge_ratio: float) -> bool:
	if slot_key != "SHIFT" and slot_key != "E":
		if is_camouflaged:
			break_camouflage()

	match slot_key:
		"LMB":
			_client_execute_attack_combo(origin, dir)
			return true
		"RMB":
			_client_execute_enlarge(origin, dir, charge_ratio)
			return true
		"Q":
			_client_execute_clone()
			return true
		"E":
			_client_execute_camouflage()
			return true
		"R":
			if ult_recast_window > 0.0:
				_client_execute_ult_recast(dir)
			else:
				_client_execute_ult_initial(dir)
			return true
	return false

# --- Universal Target Query Helper ---
func _get_all_enemy_targets() -> Array[Node]:
	var candidate_pool: Array[Node] = []
	var tree = get_tree()
	if not tree:
		return candidate_pool

	for p in tree.get_nodes_in_group("players"):
		if not candidate_pool.has(p):
			candidate_pool.append(p)

	if tree.root:
		var players_container = tree.root.get_node_or_null("Main/Players")
		if players_container:
			for child in players_container.get_children():
				if not candidate_pool.has(child):
					candidate_pool.append(child)
		for child in tree.root.get_children():
			if child is BasePlayer and not candidate_pool.has(child):
				candidate_pool.append(child)

	var enemies: Array[Node] = []
	for p in candidate_pool:
		if not is_instance_valid(p) or p == self:
			continue
		if p.get("is_dead") == true:
			continue
		if is_enemy(p):
			enemies.append(p)
	return enemies

# --- LMB: 3-Hit Combo (Swipes 1 & 2 Cone, Slam 3 Long Line) ---
func _server_execute_attack_combo(origin: Vector3, dir: Vector3) -> void:
	break_invisibility()
	var current_step = combo_step
	combo_step = (combo_step + 1) % 3
	combo_reset_timer = COMBO_RESET_WINDOW
	_update_lmb_node_config()

	var fwd = dir.normalized()
	fwd.y = 0.0
	if fwd.length_squared() < 0.001:
		fwd = -global_transform.basis.z.normalized()
		fwd.y = 0.0
	fwd = fwd.normalized()

	var hit_origin = global_position if is_inside_tree() else origin

	if current_step < 2:
		var targets = _get_targets_in_cone(hit_origin, fwd, SWIPE_RADIUS, SWIPE_ANGLE)
		var dmg = SWIPE_BASE_DAMAGE + (float(damage) * SWIPE_ATTACK_RATIO)
		for target in targets:
			deal_damage(target, dmg, ActionType.ATTACK)
	else:
		var targets = _get_targets_in_line(hit_origin, fwd, SLAM_LENGTH, SLAM_WIDTH)
		var dmg = SLAM_BASE_DAMAGE + (float(damage) * SLAM_ATTACK_RATIO)
		for target in targets:
			deal_damage(target, dmg, ActionType.ATTACK)

	if is_multiplayer_match() and is_server_authoritative():
		sync_attack_combo_visual.rpc(current_step, hit_origin, fwd)

func _client_execute_attack_combo(origin: Vector3, dir: Vector3) -> void:
	if has_signal("attack_performed"):
		attack_performed.emit("Melee")
	break_invisibility()
	var current_step = combo_step
	combo_step = (combo_step + 1) % 3
	combo_reset_timer = COMBO_RESET_WINDOW
	_update_lmb_node_config()

	var fwd = dir.normalized()
	fwd.y = 0.0
	if fwd.length_squared() < 0.001:
		fwd = -global_transform.basis.z.normalized()
		fwd.y = 0.0
	fwd = fwd.normalized()

	var hit_origin = global_position if is_inside_tree() else origin
	_play_combo_visual(current_step, hit_origin, fwd)

@rpc("any_peer", "call_remote", "reliable")
func sync_attack_combo_visual(step: int, origin: Vector3, dir: Vector3) -> void:
	_play_combo_visual(step, origin, dir)

func _get_targets_in_cone(origin: Vector3, facing: Vector3, radius: float, angle_deg: float, height: float = 2.5) -> Array[Node]:
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
		var target_r: float = 0.4
		if enemy.has_method("get_hitbox_radius"):
			target_r = enemy.get_hitbox_radius()
		elif enemy.get_node_or_null("CollisionShape3D"):
			var col = enemy.get_node_or_null("CollisionShape3D") as CollisionShape3D
			if col and col.shape:
				if col.shape is CapsuleShape3D or col.shape is CylinderShape3D:
					target_r = col.shape.radius
				elif col.shape is BoxShape3D:
					target_r = max(col.shape.size.x, col.shape.size.z) * 0.5
		if dist > (radius + target_r):
			continue
		if dist <= target_r:
			result.append(enemy)
			continue
		var dir_to_enemy = diff.normalized()
		var dot = clamp(f.dot(dir_to_enemy), -1.0, 1.0)
		var angle = rad_to_deg(acos(dot))
		var angular_margin = rad_to_deg(asin(clamp(target_r / max(dist, target_r + 0.001), 0.0, 1.0)))
		if angle <= (half_angle + angular_margin):
			result.append(enemy)
	return result

func _get_targets_in_line(origin: Vector3, facing: Vector3, length: float, width: float, height: float = 2.5) -> Array[Node]:
	var result: Array[Node] = []
	var f = facing
	f.y = 0.0
	if f.length_squared() < 0.001:
		f = -global_transform.basis.z.normalized()
		f.y = 0.0
	f = f.normalized()

	for enemy in _get_all_enemy_targets():
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.get("is_dead") == true:
			continue
		if abs(enemy.global_position.y - origin.y) > height:
			continue
		var diff = enemy.global_position - origin
		diff.y = 0.0
		var target_r: float = 0.4
		if enemy.has_method("get_hitbox_radius"):
			target_r = enemy.get_hitbox_radius()
		elif enemy.get_node_or_null("CollisionShape3D"):
			var col = enemy.get_node_or_null("CollisionShape3D") as CollisionShape3D
			if col and col.shape:
				if col.shape is CapsuleShape3D or col.shape is CylinderShape3D:
					target_r = col.shape.radius
				elif col.shape is BoxShape3D:
					target_r = max(col.shape.size.x, col.shape.size.z) * 0.5
		var along = diff.dot(f)
		if along < -target_r or along > (length + target_r):
			continue
		var proj = f * clamp(along, 0.0, length)
		var lateral_dist = (diff - proj).length()
		if lateral_dist <= (width * 0.5 + target_r):
			result.append(enemy)
	return result

func _play_combo_visual(step: int, origin: Vector3, dir: Vector3) -> void:
	match step:
		0:
			_spawn_golden_swipe_visual(origin, dir, SWIPE_RADIUS, SWIPE_ANGLE, false)
		1:
			_spawn_golden_swipe_visual(origin, dir, SWIPE_RADIUS, SWIPE_ANGLE, true)
		2:
			_spawn_golden_slam_visual(origin, dir, SLAM_LENGTH, SLAM_WIDTH)

func _spawn_golden_swipe_visual(origin: Vector3, dir: Vector3, radius: float, angle_deg: float, mirrored: bool = false) -> void:
	var root_node = null
	if get_tree() and get_tree().root:
		root_node = get_tree().root.get_node_or_null("Main")
		if not root_node:
			root_node = get_tree().root
	if not root_node:
		return

	var mesh_inst = MeshInstance3D.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_rad = deg_to_rad(angle_deg * 0.5)
	var segments = 16
	var inner_r = radius * 0.35

	for i in range(segments):
		var t0 = -half_rad + (float(i) / segments) * (half_rad * 2.0)
		var t1 = -half_rad + (float(i + 1) / segments) * (half_rad * 2.0)
		if mirrored:
			t0 = -t0
			t1 = -t1

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

	mesh_inst.mesh = st.commit()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.25, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.15, 1.0)
	mat.emission_energy_multiplier = 4.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_inst.material_override = mat

	root_node.add_child(mesh_inst)
	mesh_inst.global_position = origin
	var fwd = dir.normalized()
	fwd.y = 0.0
	if fwd.length_squared() > 0.001:
		mesh_inst.look_at(origin + fwd, Vector3.UP)

	var tween = mesh_inst.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.22)
	tween.tween_callback(mesh_inst.queue_free)

func _spawn_golden_slam_visual(origin: Vector3, dir: Vector3, length: float, width: float) -> void:
	var root_node = null
	if get_tree() and get_tree().root:
		root_node = get_tree().root.get_node_or_null("Main")
		if not root_node:
			root_node = get_tree().root
	if not root_node:
		return

	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(width, 0.45, length)
	mesh_inst.mesh = box

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.80, 0.2, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.75, 0.1, 1.0)
	mat.emission_energy_multiplier = 5.0
	mesh_inst.material_override = mat

	var fwd = dir.normalized()
	fwd.y = 0.0
	if fwd.length_squared() < 0.001:
		fwd = -global_transform.basis.z.normalized()
		fwd.y = 0.0
	fwd = fwd.normalized()

	mesh_inst.global_position = origin + fwd * (length * 0.5)
	mesh_inst.global_position.y += 0.2
	if fwd.length_squared() > 0.001:
		mesh_inst.look_at(mesh_inst.global_position + fwd, Vector3.UP)
	root_node.add_child(mesh_inst)

	var tween = mesh_inst.create_tween()
	tween.tween_property(mesh_inst, "scale", Vector3(1.15, 0.8, 1.0), 0.28)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.28)
	tween.tween_callback(mesh_inst.queue_free)

# --- RMB: Enlarge ---
func _server_execute_enlarge(_origin: Vector3, dir: Vector3, charge_ratio: float) -> void:
	var fwd = dir.normalized()
	fwd.y = 0.0
	if fwd.length_squared() < 0.001:
		fwd = -global_transform.basis.z.normalized()
		fwd.y = 0.0
	fwd = fwd.normalized()

	var impulse_speed = lerp(14.0, 26.0, charge_ratio)
	apply_velocity_impulse(fwd * impulse_speed, true)

	var base_dmg = lerp(35.0, 70.0, charge_ratio)
	var base_stun = lerp(0.4, 1.1, charge_ratio)
	var hit_length = 6.5
	var outer_width = 3.2
	var sweet_spot_width = 1.2

	var enemies = _get_all_enemy_targets()
	for target in enemies:
		var to_target = target.global_position - global_position
		to_target.y = 0.0
		var along = to_target.dot(fwd)
		if along < 0.0 or along > hit_length:
			continue
		var proj = global_position + fwd * along
		var lateral_dist = (target.global_position - proj).length()
		if lateral_dist > (outer_width * 0.5):
			continue

		var is_sweet_spot = (lateral_dist <= sweet_spot_width * 0.5)
		var dmg = base_dmg * (1.45 if is_sweet_spot else 1.0)
		var stun_dur = base_stun + (0.5 if is_sweet_spot else 0.0)

		deal_damage(target, dmg, ActionType.ABILITY)
		if target.has_method("apply_stun"):
			target.apply_stun(stun_dur)

func _client_execute_enlarge(origin: Vector3, dir: Vector3, charge_ratio: float) -> void:
	if is_local_player():
		var fwd = dir.normalized()
		fwd.y = 0.0
		if fwd.length_squared() < 0.001:
			fwd = -global_transform.basis.z.normalized()
			fwd.y = 0.0
		fwd = fwd.normalized()
		var impulse_speed = lerp(14.0, 26.0, charge_ratio)
		apply_velocity_impulse(fwd * impulse_speed, true)

	_spawn_golden_slam_wave(origin, dir, 6.5, 3.2, charge_ratio)

# --- Q: Doppelganger Clone ---
func _server_execute_clone() -> void:
	var clone = MonkeyCloneClass.new()
	clone.name = "MonkeyClone_%d" % int(Time.get_ticks_msec())
	clone.summoner = self
	clone.team_id = team_id
	clone.max_health = max_health
	clone.current_health = current_health
	clone.damage = damage
	clone.max_move_speed = max_move_speed
	clone.lifetime = 10.0

	var fwd = -global_transform.basis.z.normalized()
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 0.001 else Vector3.FORWARD
	var right_vec = fwd.cross(Vector3.UP).normalized()
	clone.position = global_position + fwd * 1.5 + right_vec * 0.5

	var target_parent = get_parent()
	if get_tree() and get_tree().root:
		var pc = get_tree().root.get_node_or_null("Main/Players")
		if pc:
			target_parent = pc
	if target_parent:
		target_parent.add_child(clone)
	else:
		add_child(clone)

	start_ability_cooldown("Q", Q_BASE_COOLDOWN)

func _client_execute_clone() -> void:
	start_ability_cooldown("Q", Q_BASE_COOLDOWN)

# --- E: Camouflage ---
func _server_execute_camouflage() -> void:
	apply_camouflage()
	if is_multiplayer_match() and is_server_authoritative():
		sync_camouflage.rpc(true)

func _client_execute_camouflage() -> void:
	apply_camouflage()

func apply_camouflage() -> void:
	is_camouflaged = true
	camouflage_timer = CAMOUFLAGE_MAX_DURATION
	is_camouflage_detected = false
	_update_camouflage_visuals()

func break_camouflage() -> void:
	if not is_camouflaged:
		return
	is_camouflaged = false
	camouflage_timer = 0.0
	is_camouflage_detected = false
	_update_camouflage_visuals()
	start_ability_cooldown("E", E_BASE_COOLDOWN)
	if is_multiplayer_match() and is_server_authoritative():
		sync_camouflage.rpc(false)

func _update_camouflage_visuals() -> void:
	var mesh_inst: MeshInstance3D = get_node_or_null("MeshInstance3D")
	if mesh_inst:
		var mat = mesh_inst.material_override as StandardMaterial3D
		if not mat and default_mesh_material:
			mat = default_mesh_material.duplicate() as StandardMaterial3D
			mesh_inst.material_override = mat
		if mat:
			if is_camouflaged and not is_camouflage_detected:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				var col = mat.albedo_color
				col.a = 0.45
				mat.albedo_color = col
			else:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				var col = mat.albedo_color
				col.a = 1.0
				mat.albedo_color = col

	set_opponent_visible(not is_invisible())

@rpc("any_peer", "call_local", "reliable")
func sync_camouflage(active: bool) -> void:
	if active:
		apply_camouflage()
	else:
		is_camouflaged = false
		camouflage_timer = 0.0
		is_camouflage_detected = false
		_update_camouflage_visuals()

@rpc("any_peer", "call_local", "reliable")
func sync_camouflage_detected(detected: bool) -> void:
	is_camouflage_detected = detected
	_update_camouflage_visuals()

# --- R: Ultimate (Smoke Duel, Recast Directional Dash & Target Separation, 5s Target Disguise) ---
func _server_execute_ult_initial(dir: Vector3) -> void:
	var fwd = dir.normalized()
	fwd.y = 0.0
	if fwd.length_squared() < 0.001:
		fwd = -global_transform.basis.z.normalized()
		fwd.y = 0.0
	fwd = fwd.normalized()

	apply_velocity_impulse(fwd * 24.0, true)

	var enemies = _get_all_enemy_targets()
	var hit_enemy: Node = null
	var closest_along: float = 999.0

	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.get("is_dead") == true:
			continue
		var to_enemy = enemy.global_position - global_position
		to_enemy.y = 0.0
		var along = to_enemy.dot(fwd)
		if along >= 0.0 and along <= 14.0:
			var proj = fwd * along
			var lateral = (to_enemy - proj).length()
			if lateral <= 2.5 and along < closest_along:
				closest_along = along
				hit_enemy = enemy

	if hit_enemy:
		# Striking the first enemy hit (but NOT dealing damage!)
		duel_target = hit_enemy
		ult_recast_window = ULT_RECAST_MAX_WINDOW

		global_position = hit_enemy.global_position - fwd * 1.5
		velocity = Vector3.ZERO
		if "velocity" in hit_enemy:
			hit_enemy.velocity = Vector3.ZERO

		var duel_center = (global_position + hit_enemy.global_position) * 0.5
		duel_center.y = global_position.y

		# Both players invisible and untargetable/intangible
		apply_invisibility(ULT_RECAST_MAX_WINDOW)
		apply_invulnerability(ULT_RECAST_MAX_WINDOW)
		apply_ethereal(ULT_RECAST_MAX_WINDOW)

		if hit_enemy.has_method("apply_invisibility"):
			hit_enemy.apply_invisibility(ULT_RECAST_MAX_WINDOW)
		if hit_enemy.has_method("apply_invulnerability"):
			hit_enemy.apply_invulnerability(ULT_RECAST_MAX_WINDOW)
		if hit_enemy.has_method("apply_ethereal"):
			hit_enemy.apply_ethereal(ULT_RECAST_MAX_WINDOW)
		if hit_enemy.has_method("apply_root"):
			hit_enemy.apply_root(ULT_RECAST_MAX_WINDOW)

		# Spawn smoke cloud (gray circle)
		_spawn_smoke_cloud(duel_center, 5.0)

		if is_multiplayer_match() and is_server_authoritative():
			sync_ult_duel_start.rpc(hit_enemy.get_path(), duel_center)
	else:
		ult_recast_window = 0.0
		start_ability_cooldown("R", ULT_COOLDOWN)

func _client_execute_ult_initial(dir: Vector3) -> void:
	if is_local_player():
		var fwd = dir.normalized()
		fwd.y = 0.0
		if fwd.length_squared() < 0.001:
			fwd = -global_transform.basis.z.normalized()
			fwd.y = 0.0
		apply_velocity_impulse(fwd.normalized() * 24.0, true)

func _execute_ult_recast_rush() -> void:
	var origin = global_position
	var shoot_dir = get_ranged_aim_direction(origin)
	var ground_hit = get_mouse_ground_intersection()
	var target_pos = ground_hit if ground_hit != null else (global_position + shoot_dir * 12.0)

	if not is_multiplayer_match() or multiplayer.is_server():
		request_cast_ability("R", origin, shoot_dir, target_pos, 0.0)
	else:
		request_cast_ability.rpc_id(1, "R", origin, shoot_dir, target_pos, 0.0)

func _server_execute_ult_recast(dir: Vector3) -> void:
	var fwd = dir.normalized()
	fwd.y = 0.0
	if fwd.length_squared() < 0.001:
		fwd = -global_transform.basis.z.normalized()
		fwd.y = 0.0
	fwd = fwd.normalized()

	ult_recast_window = 0.0
	_remove_smoke_cloud()

	# Remove intangibility and invisibility
	invulnerable_timer = 0.0
	ethereal_timer = 0.0
	break_invisibility()

	if is_instance_valid(duel_target):
		duel_target.invulnerable_timer = 0.0
		duel_target.ethereal_timer = 0.0
		if duel_target.has_method("break_invisibility"):
			duel_target.break_invisibility()
		if duel_target.has_method("cleanse_cc"):
			duel_target.cleanse_cc()

		# Player dashes in chosen direction
		apply_velocity_impulse(fwd * 24.0, true)

		# Target is sent in the opposite direction (-fwd)
		if duel_target.has_method("apply_velocity_impulse"):
			duel_target.apply_velocity_impulse(-fwd * 24.0, true)

		# Transform player into a copy of the target for 5 seconds
		_apply_target_copy_disguise(duel_target)

	if is_multiplayer_match() and is_server_authoritative():
		sync_ult_recast.rpc(fwd)

func _client_execute_ult_recast(dir: Vector3) -> void:
	ult_recast_window = 0.0
	if is_local_player():
		var fwd = dir.normalized()
		fwd.y = 0.0
		if fwd.length_squared() < 0.001:
			fwd = -global_transform.basis.z.normalized()
			fwd.y = 0.0
		apply_velocity_impulse(fwd.normalized() * 24.0, true)

@rpc("any_peer", "call_local", "reliable")
func sync_ult_duel_start(target_path: NodePath, duel_center: Vector3) -> void:
	ult_recast_window = ULT_RECAST_MAX_WINDOW
	var hit_enemy = get_node_or_null(target_path)
	if hit_enemy:
		duel_target = hit_enemy
	_spawn_smoke_cloud(duel_center, 5.0)

@rpc("any_peer", "call_local", "reliable")
func sync_ult_recast(fwd: Vector3) -> void:
	ult_recast_window = 0.0
	_remove_smoke_cloud()
	if is_instance_valid(duel_target):
		_apply_target_copy_disguise(duel_target)

func _spawn_smoke_cloud(center: Vector3, radius: float) -> void:
	_remove_smoke_cloud()
	var root_node = get_tree().root.get_node_or_null("Main") if (get_tree() and get_tree().root) else null
	if not root_node and get_tree():
		root_node = get_tree().root
	if not root_node:
		return

	var cloud = MeshInstance3D.new()
	cloud.name = "SmokeDuelCloud"
	var cyl = CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.1
	cloud.mesh = cyl

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.35, 0.38, 0.85)
	mat.roughness = 0.95
	mat.metallic = 0.05
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloud.material_override = mat

	root_node.add_child(cloud)
	cloud.global_position = Vector3(center.x, 0.06, center.z)
	smoke_cloud_instance = cloud

func _remove_smoke_cloud() -> void:
	if is_instance_valid(smoke_cloud_instance):
		smoke_cloud_instance.queue_free()
		smoke_cloud_instance = null

# --- 5-Second Target Copy Disguise Implementation ---
func _apply_target_copy_disguise(target: Node) -> void:
	if not is_instance_valid(target):
		return
	disguised_target = target
	disguise_timer = DISGUISE_MAX_DURATION

	# 1. Replace abilities for the duration
	original_abilities = abilities.duplicate()
	var target_abilities = target.get("abilities")
	if target_abilities is Dictionary:
		for slot in ["LMB", "RMB", "SHIFT", "Q", "E", "R"]:
			if target_abilities.has(slot):
				var src_ab = target_abilities[slot]
				if src_ab is AbilityClass:
					var copy_ab = src_ab.duplicate()
					copy_ab.name = "Copied_%s" % slot
					add_child(copy_ab)
					abilities[slot] = copy_ab

	_setup_abilities_hud()

	# 2. Appearance & Identity Disguise
	original_display_name = display_name
	var target_name = target.get_display_name() if target.has_method("get_display_name") else target.get("display_name")
	if target_name != null and not str(target_name).is_empty():
		display_name = str(target_name)
	else:
		display_name = target.name

	var my_mesh_inst: MeshInstance3D = get_node_or_null("MeshInstance3D")
	var target_mesh_inst: MeshInstance3D = target.get_node_or_null("MeshInstance3D")
	if my_mesh_inst and target_mesh_inst:
		if not original_mesh:
			original_mesh = my_mesh_inst.mesh
		if target_mesh_inst.mesh:
			my_mesh_inst.mesh = target_mesh_inst.mesh
		if target_mesh_inst.material_override:
			my_mesh_inst.material_override = target_mesh_inst.material_override.duplicate()

	if staff_facing:
		staff_facing.visible = false

	_update_team_visuals()

func _revert_disguise() -> void:
	disguise_timer = 0.0
	disguised_target = null

	# Clean up cloned ability nodes
	for slot in ["LMB", "RMB", "SHIFT", "Q", "E", "R"]:
		if abilities.has(slot) and abilities[slot] != original_abilities.get(slot):
			var ab = abilities[slot]
			if is_instance_valid(ab) and ab.get_parent() == self:
				ab.queue_free()

	abilities = original_abilities.duplicate()
	_setup_abilities_hud()

	if not original_display_name.is_empty():
		display_name = original_display_name

	var my_mesh_inst: MeshInstance3D = get_node_or_null("MeshInstance3D")
	if my_mesh_inst and original_mesh:
		my_mesh_inst.mesh = original_mesh
		my_mesh_inst.material_override = default_mesh_material

	if staff_facing:
		staff_facing.visible = true

	_update_team_visuals()
	start_ability_cooldown("R", ULT_COOLDOWN)

func _update_team_visuals() -> void:
	if disguise_timer > 0.0 and is_instance_valid(disguised_target):
		_apply_disguise_team_visuals()
	else:
		super._update_team_visuals()

func _apply_disguise_team_visuals() -> void:
	var local_id = get_my_player_id()
	var local_team = get_local_player_team()
	var is_viewer_ally = (team_id == local_team) or (name == str(local_id))

	var model_color: Color
	var emissive_color: Color
	var health_color: Color

	if is_viewer_ally:
		# Allies see them normally
		model_color = Color(0.18, 0.58, 1.0, 1.0)
		emissive_color = Color(0.08, 0.25, 0.5, 1.0)
		health_color = Color(0.18, 0.65, 1.0, 1.0)
	else:
		# Enemies see them as their ally!
		model_color = Color(0.18, 0.58, 1.0, 1.0)
		emissive_color = Color(0.08, 0.25, 0.5, 1.0)
		health_color = Color(0.18, 0.65, 1.0, 1.0)

	var mesh_inst: MeshInstance3D = get_node_or_null("MeshInstance3D")
	if mesh_inst:
		var mat = mesh_inst.material_override as StandardMaterial3D
		if not mat:
			mat = StandardMaterial3D.new()
		else:
			mat = mat.duplicate() as StandardMaterial3D
		mat.albedo_color = model_color
		mat.roughness = 0.35
		mat.metallic = 0.2
		mat.emission_enabled = true
		mat.emission = emissive_color
		mat.emission_energy_multiplier = 0.3
		mesh_inst.material_override = mat

	if health_bar:
		var fill_sb = health_bar.get_theme_stylebox("fill")
		if fill_sb:
			fill_sb = fill_sb.duplicate()
		else:
			fill_sb = StyleBoxFlat.new()
			fill_sb.corner_radius_top_left = 4
			fill_sb.corner_radius_top_right = 4
			fill_sb.corner_radius_bottom_right = 4
			fill_sb.corner_radius_bottom_left = 4
		if fill_sb is StyleBoxFlat:
			fill_sb.bg_color = health_color
			health_bar.add_theme_stylebox_override("fill", fill_sb)

# --- Procedural Visual Effects ---
func _spawn_golden_slam_wave(origin: Vector3, dir: Vector3, length: float, width: float, charge_ratio: float) -> void:
	var root_node = get_tree().root.get_node_or_null("Main") if get_tree() else null
	if not root_node:
		return
	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(width, 0.4, length)
	mesh_inst.mesh = box

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.7, 0.1, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.0, 1.0)
	mat.emission_energy_multiplier = lerp(3.0, 6.0, charge_ratio)
	mesh_inst.material_override = mat

	var fwd = dir.normalized()
	fwd.y = 0.0
	mesh_inst.global_position = origin + fwd * (length * 0.5)
	if fwd.length_squared() > 0.001:
		mesh_inst.look_at(mesh_inst.global_position + fwd, Vector3.UP)
	root_node.add_child(mesh_inst)

	var tween = mesh_inst.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tween.tween_callback(mesh_inst.queue_free)
