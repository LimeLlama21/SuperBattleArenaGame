class_name Monkey
extends BasePlayer

const MonkeyKing = Monkey
const RadialSelectionWheel = preload("res://characters/monkey/radial_selection_wheel.gd")
const MonkeyData = preload("res://characters/monkey/monkey_data.gd")
const MonkeyKingData = MonkeyData

# --- Stone Monkey (Passive) ---
var stone_monkey_cd_timer: float = 0.0
const STONE_MONKEY_CD: float = 75.0
const STONE_MONKEY_DURATION: float = 3.0
var stone_monkey_active_timer: float = 0.0
var stone_monkey_heal_rate: float = 0.0
var default_mesh_material: Material = null
var default_staff_material: Material = null

# --- 72 Forms (Q) ---
var radial_wheel: Node = null
var pending_prop_type: String = "tree"
const Q_BASE_COOLDOWN: float = 22.0
const Q_CANCEL_COOLDOWN: float = 2.5
const Q_MANA_COST: float = 10.0

# --- Ultimate Recast & Flurry (R) ---
var ult_recast_window: float = 0.0
const ULT_RECAST_MAX_WINDOW: float = 4.0
const ULT_COOLDOWN: float = 28.0

# --- Visual Indicators & Nodes ---
@onready var staff_facing: MeshInstance3D = get_node_or_null("FacingIndicator")
@onready var transformed_prop_container: Node3D = get_node_or_null("TransformedPropContainer")

const TREE_SCENE_PATH: String = "res://assets/Tree1.glb"
const ROCK_SCENE_PATH: String = "res://assets/RockPlatform2.glb"

func _setup_character_kit() -> void:
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

	var q_ab = abilities.get("Q")
	if q_ab and q_ab is AbilityClass:
		q_ab.ui_modal = AbilityPipeline.create_ui_modal({
			"type": AbilityPipeline.UIModalType.RADIAL_WHEEL,
			"interaction_mode": AbilityPipeline.ModalInteractionMode.HOLD_AND_RELEASE,
			"cancel_cooldown": Q_CANCEL_COOLDOWN,
			"cancel_refund_percent": 0.5,
			"options": [
				{
					"id": "tree",
					"label": "🌲 TREE",
					"color": Color(0.12, 0.60, 0.28, 0.95),
					"inactive_color": Color(0.12, 0.28, 0.16, 0.70),
					"arc_color": Color(0.35, 1.0, 0.55, 1.0)
				},
				{
					"id": "rock",
					"label": "🪨 ROCK",
					"color": Color(0.70, 0.48, 0.20, 0.95),
					"inactive_color": Color(0.28, 0.22, 0.16, 0.70),
					"arc_color": Color(1.0, 0.80, 0.30, 1.0)
				}
			]
		})

	var sync = get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	if sync and sync.replication_config:
		_add_sync_property(sync.replication_config, NodePath(".:ult_recast_window"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		_add_sync_property(sync.replication_config, NodePath(".:stone_monkey_active_timer"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)

func character_handles_slot(slot_key: String) -> bool:
	if slot_key == "R" and ult_recast_window > 0.0:
		return true
	return false

func get_custom_ability_mana_cost(slot_key: String, _ability_id: String) -> float:
	if slot_key == "R" and ult_recast_window > 0.0:
		return 0.0 # Free recast of Ultimate
	if slot_key == "Q":
		return Q_MANA_COST
	return -1.0

func should_ability_start_cooldown_on_cast(slot_key: String, _ability_id: String) -> bool:
	if slot_key == "Q":
		return false
	if slot_key == "R":
		return false
	return true

func start_ability_cooldown(slot_key: String, duration: float) -> void:
	var ab = abilities.get(slot_key)
	if ab:
		var mult = get_cooldown_multiplier() if has_method("get_cooldown_multiplier") else 1.0
		ab.current_cooldown = duration * mult

func _process_character_kit(delta: float) -> void:
	# Passive: Stone Monkey Cooldown
	if stone_monkey_cd_timer > 0.0:
		stone_monkey_cd_timer = max(0.0, stone_monkey_cd_timer - delta)

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

	# Passive Proc Check: Critical health (<= 30%)
	if not is_dead and stone_monkey_cd_timer <= 0.0 and stone_monkey_active_timer <= 0.0:
		if current_health <= (max_health * 0.30):
			_trigger_stone_monkey()

	# Ultimate Recast Window Timer
	if ult_recast_window > 0.0:
		ult_recast_window -= delta
		if ult_recast_window <= 0.0:
			ult_recast_window = 0.0
			start_ability_cooldown("R", ULT_COOLDOWN)

func _on_damage_taken_hook(_amount: float, _attacker_id: int, _action_type: int) -> void:
	# Check if incoming damage brought Monkey King to or below critical health
	if not is_dead and stone_monkey_cd_timer <= 0.0 and stone_monkey_active_timer <= 0.0:
		if current_health <= (max_health * 0.30):
			if current_health <= 0.0:
				# Prevent instant death before passive can trigger
				current_health = max(1.0, max_health * 0.05)
			_trigger_stone_monkey()

func _trigger_stone_monkey() -> void:
	stone_monkey_cd_timer = STONE_MONKEY_CD
	stone_monkey_active_timer = STONE_MONKEY_DURATION
	var missing_hp = max(0.0, max_health - current_health)
	stone_monkey_heal_rate = (missing_hp * 0.30) / STONE_MONKEY_DURATION

	apply_invulnerability(STONE_MONKEY_DURATION)
	apply_displacement_immunity(STONE_MONKEY_DURATION)
	_set_stone_material(true)

	if is_multiplayer_match() and is_server_authoritative():
		sync_stone_visual.rpc(true)

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

# --- Input Handling for R Recast ---
func _handle_character_input(_delta: float) -> void:
	# R: Recast Rush Flurry
	if ult_recast_window > 0.0:
		if Input.is_action_just_pressed("ability_four"):
			_execute_ult_recast_rush()

func _on_modal_option_selected(slot_key: String, option_id: String) -> void:
	if slot_key == "Q":
		pending_prop_type = option_id

func _on_modal_cancelled(slot_key: String) -> void:
	if slot_key == "Q":
		if is_multiplayer_match() and not multiplayer.is_server():
			request_cancel_q.rpc_id(1)

func _process_radial_choice(choice: String) -> void:
	var q_ab = abilities.get("Q") as AbilityClass
	resolve_modal_choice("Q", q_ab, choice)

@rpc("any_peer", "call_remote", "reliable")
func request_cancel_q() -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id != peer_id and peer_id != 1:
		return
	consume_mana(5.0)
	start_ability_cooldown("Q", Q_CANCEL_COOLDOWN)

@rpc("any_peer", "call_remote", "reliable")
func request_transform_prop(prop_type: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id != peer_id and peer_id != 1:
		return
	if not can_cast_ability_slot("Q"):
		return
	consume_mana(Q_MANA_COST)
	_server_execute_72_forms(prop_type)

# --- Custom Ability Execution (Server & Client) ---
func custom_execute_ability_server(slot_key: String, origin: Vector3, dir: Vector3, _target_pos: Vector3, charge_ratio: float) -> bool:
	match slot_key:
		"RMB":
			_server_execute_enlarge(origin, dir, charge_ratio)
			return true
		"Q":
			_server_execute_72_forms(pending_prop_type)
			return true
		"E":
			_server_execute_sages_mockery(origin)
			return true
		"R":
			if ult_recast_window > 0.0:
				_server_execute_ult_recast(dir)
			else:
				_server_execute_ult_initial(dir)
			return true
	return false

func custom_execute_ability_client(slot_key: String, origin: Vector3, dir: Vector3, _target_pos: Vector3, charge_ratio: float) -> bool:
	match slot_key:
		"LMB":
			_client_execute_heavenly_pillar(origin, dir)
			return false # Let pipeline MeleeStrikeEffect run client triggers
		"RMB":
			_client_execute_enlarge(origin, dir, charge_ratio)
			return true
		"Q":
			return true
		"E":
			_client_execute_sages_mockery(origin)
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

	var enemies: Array[Node] = []
	for p in candidate_pool:
		if not is_instance_valid(p) or p == self:
			continue
		if p.get("is_dead") == true:
			continue
		if is_enemy(p):
			enemies.append(p)
	return enemies

# --- LMB: Heavenly Pillar ---
func _client_execute_heavenly_pillar(origin: Vector3, dir: Vector3) -> void:
	_spawn_golden_pillar_flash(origin, dir, 5.5, 1.2)

# --- RMB: Enlarge ---
func _server_execute_enlarge(_origin: Vector3, dir: Vector3, charge_ratio: float) -> void:
	var fwd = dir.normalized()
	fwd.y = 0.0
	if fwd.length_squared() < 0.001:
		fwd = -global_transform.basis.z.normalized()
		fwd.y = 0.0
	fwd = fwd.normalized()

	# Dash forward impulse scaling with charge
	var impulse_speed = lerp(14.0, 26.0, charge_ratio)
	apply_velocity_impulse(fwd * impulse_speed, true)

	var base_dmg = lerp(35.0, 70.0, charge_ratio)
	var base_stun = lerp(0.4, 1.1, charge_ratio)
	
	var hit_length = 6.5
	var outer_width = 3.2
	var sweet_spot_width = 1.2
	var right_vec = fwd.cross(Vector3.UP).normalized()

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

# --- Q: 72 Forms ---
func _server_execute_72_forms(prop_type: String) -> void:
	var props = {
		"can_move": true,
		"can_dash": true,
		"break_on_attack": true,
		"break_on_damage": true
	}
	apply_transformation(prop_type, props)

func _on_transformation_applied(prop_type: String, _properties: Dictionary) -> void:
	var mesh_inst: MeshInstance3D = get_node_or_null("MeshInstance3D")
	if mesh_inst:
		mesh_inst.visible = false
	if staff_facing:
		staff_facing.visible = false

	# Instantiate prop visual
	_attach_transformed_prop(prop_type)

func _on_transformation_broken(_prev_prop: String) -> void:
	var mesh_inst: MeshInstance3D = get_node_or_null("MeshInstance3D")
	if mesh_inst:
		mesh_inst.visible = true
	if staff_facing:
		staff_facing.visible = true

	_remove_transformed_prop()
	# Start Q long cooldown upon transformation broken
	start_ability_cooldown("Q", Q_BASE_COOLDOWN)

func _attach_transformed_prop(prop_type: String) -> void:
	_remove_transformed_prop()
	var scene_path = TREE_SCENE_PATH if prop_type == "tree" else ROCK_SCENE_PATH
	var res = load(scene_path) as PackedScene
	if res:
		var prop_inst = res.instantiate() as Node3D
		prop_inst.name = "TransformedPropVisual"
		if prop_type == "tree":
			prop_inst.scale = Vector3(0.55, 0.55, 0.55)
			prop_inst.position = Vector3(0, 0, 0)
		else:
			prop_inst.scale = Vector3(0.35, 0.35, 0.35)
			prop_inst.position = Vector3(0, 0.1, 0)
		add_child(prop_inst)

func _remove_transformed_prop() -> void:
	var prop_inst = get_node_or_null("TransformedPropVisual")
	if prop_inst:
		remove_child(prop_inst)
		prop_inst.queue_free()

# --- E: Sage's Mockery ---
func _server_execute_sages_mockery(origin: Vector3) -> void:
	var radius = 6.5
	var r2 = radius * radius
	var enemies = _get_all_enemy_targets()
	for enemy in enemies:
		var to_enemy = enemy.global_position - origin
		to_enemy.y *= 0.5
		if to_enemy.length_squared() <= r2:
			if enemy.has_method("apply_taunt"):
				enemy.apply_taunt(self, 1.8, 0.35)

func _client_execute_sages_mockery(origin: Vector3) -> void:
	_spawn_taunt_ring_visual(origin, 6.5)

# --- R: Ultimate (Phase 1 Initial & Phase 2 Recast) ---
func _server_execute_ult_initial(dir: Vector3) -> void:
	var fwd = dir.normalized()
	fwd.y = 0.0
	if fwd.length_squared() < 0.001:
		fwd = -global_transform.basis.z.normalized()
		fwd.y = 0.0
	fwd = fwd.normalized()

	apply_invisibility(3.0)
	apply_velocity_impulse(fwd * 18.0, true)
	ult_recast_window = ULT_RECAST_MAX_WINDOW
	if is_multiplayer_match():
		sync_ult_recast_state.rpc(true)

func _client_execute_ult_initial(dir: Vector3) -> void:
	ult_recast_window = ULT_RECAST_MAX_WINDOW
	if is_local_player():
		var fwd = dir.normalized()
		fwd.y = 0.0
		if fwd.length_squared() < 0.001:
			fwd = -global_transform.basis.z.normalized()
			fwd.y = 0.0
		fwd = fwd.normalized()
		apply_velocity_impulse(fwd * 18.0, true)
	_spawn_stealth_dash_visual(global_position, dir)

func _execute_ult_recast_rush() -> void:
	var fwd = -global_transform.basis.z.normalized()
	fwd.y = 0.0
	fwd = fwd.normalized()
	var origin = global_position
	var ground_hit = get_mouse_ground_intersection()
	var target_pos = ground_hit if ground_hit != null else (global_position + fwd * 12.0)
	var shoot_dir = get_ranged_aim_direction(origin)

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
	if is_multiplayer_match():
		sync_ult_recast_state.rpc(false)

	# User request: "The ult's flurry should be a recast. It should break invis as well, so count it as casting a spell if that's not natrual behavior"
	break_invisibility()

	# Rush forward moderate distance (12.0m)
	apply_velocity_impulse(fwd * 24.0, true)

	# Flurry of small overlapping, semi-randomly strewn but deterministic hitboxes along path
	var rush_dist = 12.0
	var num_flurries = 7
	var right_vec = fwd.cross(Vector3.UP).normalized()
	var hit_enemies: Dictionary = {}
	var all_enemies = _get_all_enemy_targets()

	for i in range(num_flurries):
		var progress = float(i + 1) / float(num_flurries)
		var forward_offset = fwd * (rush_dist * progress)
		# Deterministic strewn lateral offset
		var lateral_offset = right_vec * (sin(float(i) * 2.3) * 1.3)
		var flurry_center = global_position + forward_offset + lateral_offset
		var r2 = 1.8 * 1.8
		
		for target in all_enemies:
			var to_target = target.global_position - flurry_center
			to_target.y *= 0.5
			if to_target.length_squared() <= r2:
				var target_id = target.get_instance_id()
				var hits = hit_enemies.get(target_id, 0)
				if hits < 3: # Cap max hits per target from flurry
					hit_enemies[target_id] = hits + 1
					deal_damage(target, 22.0, ActionType.ABILITY)

	start_ability_cooldown("R", ULT_COOLDOWN)

func _client_execute_ult_recast(dir: Vector3) -> void:
	ult_recast_window = 0.0
	break_invisibility()
	if is_local_player():
		var fwd = dir.normalized()
		fwd.y = 0.0
		if fwd.length_squared() < 0.001:
			fwd = -global_transform.basis.z.normalized()
			fwd.y = 0.0
		fwd = fwd.normalized()
		apply_velocity_impulse(fwd * 24.0, true)
	_spawn_rush_flurry_visuals(global_position, dir, 12.0)

@rpc("any_peer", "call_local", "reliable")
func sync_ult_recast_state(active: bool) -> void:
	ult_recast_window = ULT_RECAST_MAX_WINDOW if active else 0.0

# --- Procedural Visual Effects ---
func _spawn_golden_pillar_flash(origin: Vector3, dir: Vector3, length: float, width: float) -> void:
	var root_node = get_tree().root.get_node_or_null("Main") if get_tree() else null
	if not root_node:
		return
	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(width, 0.3, length)
	mesh_inst.mesh = box
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.1, 1.0)
	mat.emission_energy_multiplier = 4.0
	mesh_inst.material_override = mat
	
	var fwd = dir.normalized()
	fwd.y = 0.0
	mesh_inst.global_position = origin + fwd * (length * 0.5)
	if fwd.length_squared() > 0.001:
		mesh_inst.look_at(mesh_inst.global_position + fwd, Vector3.UP)
	root_node.add_child(mesh_inst)
	
	var tween = mesh_inst.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.22)
	tween.tween_callback(mesh_inst.queue_free)

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

func _spawn_taunt_ring_visual(origin: Vector3, radius: float) -> void:
	var root_node = get_tree().root.get_node_or_null("Main") if get_tree() else null
	if not root_node:
		return
	var ring = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.15
	ring.mesh = cyl
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.15, 1.0)
	mat.emission_energy_multiplier = 4.0
	ring.material_override = mat
	
	ring.global_position = Vector3(origin.x, 0.08, origin.z)
	root_node.add_child(ring)

	var tween = ring.create_tween()
	tween.tween_property(ring, "scale", Vector3(1.15, 1.0, 1.15), 0.4)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tween.tween_callback(ring.queue_free)

func _spawn_stealth_dash_visual(origin: Vector3, dir: Vector3) -> void:
	var root_node = get_tree().root.get_node_or_null("Main") if get_tree() else null
	if not root_node:
		return
	var ribbon = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.8, 0.2, 4.0)
	ribbon.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.4, 0.6)
	ribbon.material_override = mat
	ribbon.global_position = origin
	var fwd = dir.normalized()
	if fwd.length_squared() > 0.001:
		ribbon.look_at(origin + fwd, Vector3.UP)
	root_node.add_child(ribbon)
	var tween = ribbon.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tween.tween_callback(ribbon.queue_free)

func _spawn_rush_flurry_visuals(origin: Vector3, dir: Vector3, distance: float) -> void:
	var root_node = get_tree().root.get_node_or_null("Main") if get_tree() else null
	if not root_node:
		return
	var fwd = dir.normalized()
	fwd.y = 0.0
	var right = fwd.cross(Vector3.UP).normalized()
	var num_flurries = 7

	for i in range(num_flurries):
		var progress = float(i + 1) / float(num_flurries)
		var p_center = origin + fwd * (distance * progress) + right * (sin(float(i) * 2.3) * 1.3)
		var box_inst = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(1.8, 0.3, 1.8)
		box_inst.mesh = box
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.9, 0.15, 0.85)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.85, 0.1, 1.0)
		mat.emission_energy_multiplier = 4.5
		box_inst.material_override = mat
		box_inst.global_position = Vector3(p_center.x, 0.12, p_center.z)
		root_node.add_child(box_inst)
		
		var tween = box_inst.create_tween()
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.35)
		tween.tween_callback(box_inst.queue_free)
