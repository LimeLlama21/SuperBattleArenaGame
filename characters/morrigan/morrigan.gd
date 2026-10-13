class_name Morrigan
extends BasePlayer

# --- Passive: Harbinger of Doom (Single Empowering Crow) ---
const PASSIVE_COOLDOWN: float = 20.0
const PASSIVE_CD_REDUCTION: float = 3.0
var passive_cooldown_timer: float = 0.0
var passive_crows_count: int:
	get:
		return 1 if is_passive_empowered_ready else 0
	set(value):
		_update_crow_orbit_visuals()

var is_passive_empowered_ready: bool:
	get:
		return passive_cooldown_timer <= 0.0

var crow_orbit_angle: float = 0.0
var cast_refund_history: Dictionary = {} # cast_id -> bool
var current_cast_counter: int = 0

# --- LMB: Black Plumage Hold-to-Charge ---
var is_charging_lmb: bool = false
var lmb_charge_timer: float = 0.0
const LMB_FIRST_CHARGE: float = 0.35
const LMB_SUBSEQUENT_CHARGE: float = 0.18
const LMB_MAX_FEATHERS: int = 5

# --- Q: Inescapable Ends Tether State ---
var tether_recast_window: float = 0.0
var anchor_one_data: Dictionary = {}
var anchor_two_data: Dictionary = {}
var tether_pull_timer: float = 0.0
var tether_is_empowered: bool = false
var tether_cast_id: int = 0
const TETHER_DURATION: float = 3.0

# --- Dash (SHIFT): Crowstorm Visual State & Empowered Dash ---
var is_crowstorm_active: bool = false:
	set(value):
		is_crowstorm_active = value
		if crowstorm_mesh: crowstorm_mesh.visible = value
		if char_mesh: char_mesh.visible = not value
var crowstorm_timer: float = 0.0
const CROWSTORM_DURATION: float = 2.0

var is_empowered_dashing: bool = false
var empowered_dash_timer: float = 0.0
var empowered_dash_dir: Vector3 = Vector3.FORWARD
const EMPOWERED_DASH_DURATION: float = 0.35
const EMPOWERED_DASH_SPEED: float = 26.0

# --- Ability State Tracking for Empower & CD Reduction ---
var current_rmb_is_empowered: bool = false
var current_rmb_cast_id: int = 0
var current_e_is_empowered: bool = false
var current_e_cast_id: int = 0
var current_r_cast_id: int = 0

@onready var crowstorm_mesh: Node3D = get_node_or_null("CrowstormMesh")
@onready var char_mesh: Node3D = get_node_or_null("MeshInstance3D")
@onready var crow_container: Node3D = get_node_or_null("CrowContainer")

func _setup_character_kit() -> void:
	if id.is_empty():
		id = "morrigan"
	var data = MorriganData.create()
	load_character_data(data)

	var sync = get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	if sync and sync.replication_config:
		_add_sync_property(sync.replication_config, NodePath(".:passive_crows_count"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		_add_sync_property(sync.replication_config, NodePath(".:passive_cooldown_timer"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		_add_sync_property(sync.replication_config, NodePath(".:is_crowstorm_active"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	
	passive_cooldown_timer = 0.0
	passive_crows_count = 1
	_update_crow_orbit_visuals()

func _get_next_cast_id() -> int:
	current_cast_counter += 1
	return current_cast_counter

func character_handles_slot(slot_key: String) -> bool:
	if slot_key == "LMB":
		return true
	if slot_key == "SHIFT" and is_passive_empowered_ready:
		return true
	if slot_key == "Q" and tether_recast_window > 0.0:
		return true
	return false

func _handle_character_input(delta: float) -> void:
	if is_dead or is_channeling or is_feared():
		is_charging_lmb = false
		lmb_charge_timer = 0.0
		var lmb_ab = abilities.get("LMB")
		if lmb_ab:
			lmb_ab.stop_charging()
		return

	# Empowered Dash via SHIFT when passive is off cooldown
	if is_passive_empowered_ready and Input.is_action_just_pressed("dash"):
		_perform_empowered_crow_dash()
		return

	# Black Plumage (LMB) charging
	if Input.is_action_pressed("shoot"):
		is_charging_lmb = true
		lmb_charge_timer += delta
		var lmb_ab = abilities.get("LMB")
		if lmb_ab:
			lmb_ab.is_charging = true
			lmb_ab.current_charge_time = lmb_charge_timer
	elif Input.is_action_just_released("shoot") and is_charging_lmb:
		_release_black_plumage()
		is_charging_lmb = false
		lmb_charge_timer = 0.0
		var lmb_ab = abilities.get("LMB")
		if lmb_ab:
			lmb_ab.stop_charging()

	# Tether Recast (Q)
	if tether_recast_window > 0.0 and Input.is_action_just_pressed("ability_two"):
		_perform_tether_recast()

func _calculate_lmb_feather_count() -> int:
	if lmb_charge_timer < LMB_FIRST_CHARGE:
		return 1
	var extra_time = lmb_charge_timer - LMB_FIRST_CHARGE
	var extra_feathers = int(extra_time / LMB_SUBSEQUENT_CHARGE)
	return clamp(2 + extra_feathers, 1, LMB_MAX_FEATHERS)

func _release_black_plumage() -> void:
	var feather_count = _calculate_lmb_feather_count()
	var is_emp = is_passive_empowered_ready
	if is_emp:
		passive_cooldown_timer = PASSIVE_COOLDOWN

	var facing_dir = -global_transform.basis.z.normalized()
	facing_dir.y = 0.0
	facing_dir = facing_dir.normalized()
	var origin = global_position + Vector3(0, 0.8, 0) + facing_dir * 1.0
	var shoot_dir = get_ranged_aim_direction(origin)

	# Determine targeted range convergence point
	var mouse_hit = get_mouse_ground_intersection()
	var target_dist = 35.0
	if mouse_hit != null:
		var diff = Vector3(mouse_hit.x, origin.y, mouse_hit.z) - origin
		target_dist = clamp(diff.length(), 6.0, 35.0)
	var target_pos = origin + shoot_dir * target_dist

	_fire_feathers_spread(origin, shoot_dir, target_pos, feather_count, is_emp)

func _fire_feathers_spread(origin: Vector3, shoot_dir: Vector3, target_pos: Vector3, feather_count: int, is_emp: bool) -> void:
	var tree = get_tree()
	var main_node = tree.root.get_node_or_null("Main") if (tree and tree.root) else null
	if not main_node:
		return

	var right_dir = shoot_dir.cross(Vector3.UP).normalized()
	var spacing = 0.45
	var proj_type = "morrigan_feather_empowered" if is_emp else "morrigan_feather"

	for i in range(feather_count):
		var offset_factor = (float(i) - float(feather_count - 1) * 0.5)
		var f_origin = origin + right_dir * (offset_factor * spacing)
		var f_dir = (target_pos - f_origin).normalized()
		var dist_to_target = (target_pos - f_origin).length()
		var effective_range = max(35.0, dist_to_target + 5.0)

		if is_server_authoritative():
			main_node.spawn_projectile(
				f_origin,
				f_dir,
				peer_id,
				11.0,
				70.0,
				0.4,
				effective_range / 70.0,
				proj_type,
				0.0,
				0.0,
				false,
				false,
				team_id,
				0,
				effective_range
			)
		else:
			request_cast_ability.rpc_id(1, "LMB", f_origin, f_dir, target_pos, 1.0 if is_emp else 0.0)

# --- SHIFT: Empowered Crow Dash ---
func _perform_empowered_crow_dash() -> void:
	if not is_passive_empowered_ready:
		return
	passive_cooldown_timer = PASSIVE_COOLDOWN

	var move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down") if is_local_player() else Vector2.ZERO
	var dash_dir := Vector3.ZERO
	if move_input.length_squared() > 0.01:
		dash_dir = Vector3(move_input.x, 0, move_input.y).normalized()
	else:
		dash_dir = -global_transform.basis.z.normalized()
		dash_dir.y = 0.0
		dash_dir = dash_dir.normalized()

	is_crowstorm_active = true
	is_empowered_dashing = true
	empowered_dash_timer = EMPOWERED_DASH_DURATION
	empowered_dash_dir = dash_dir
	velocity = dash_dir * EMPOWERED_DASH_SPEED

	if is_multiplayer_match():
		sync_empowered_crow_dash.rpc(dash_dir)

@rpc("any_peer", "call_local", "reliable")
func sync_empowered_crow_dash(dir: Vector3) -> void:
	is_crowstorm_active = true
	is_empowered_dashing = true
	empowered_dash_timer = EMPOWERED_DASH_DURATION
	empowered_dash_dir = dir
	velocity = dir * EMPOWERED_DASH_SPEED

# --- Q: Inescapable Ends ---
func _perform_tether_recast() -> void:
	var facing_dir = -global_transform.basis.z.normalized()
	facing_dir.y = 0.0
	facing_dir = facing_dir.normalized()
	var origin = global_position + Vector3(0, 0.8, 0) + facing_dir * 1.0
	var shoot_dir = get_ranged_aim_direction(origin)
	tether_recast_window = 0.0

	var tree = get_tree()
	var main_node = tree.root.get_node_or_null("Main") if (tree and tree.root) else null
	if main_node and is_server_authoritative():
		main_node.spawn_projectile(
			origin,
			shoot_dir,
			peer_id,
			20.0,
			45.0,
			0.6,
			15.0 / 45.0,
			"morrigan_tether_recast",
			0.0,
			0.0,
			false,
			false,
			team_id,
			1,
			15.0
		)
	elif not is_server_authoritative():
		request_cast_ability.rpc_id(1, "Q", origin, shoot_dir, global_position + shoot_dir * 15.0, 1.0)

func on_tether_impact_server(target_body: Node, hit_pos: Vector3, is_recast: bool) -> void:
	var is_player = target_body is Node3D and target_body.has_method("take_damage")
	var anchor_info = {
		"is_player": is_player,
		"player_id": target_body.name.to_int() if is_player else 0,
		"node": target_body,
		"pos": hit_pos
	}

	if is_player and not tether_is_empowered:
		_on_ability_hit(tether_cast_id)

	if not is_recast:
		anchor_one_data = anchor_info
		tether_recast_window = 4.0
		sync_tether_recast.rpc(true, hit_pos)
	else:
		anchor_two_data = anchor_info
		tether_recast_window = 0.0
		tether_pull_timer = TETHER_DURATION
		_apply_tether_pull()

func _apply_tether_pull() -> void:
	var p1 = anchor_one_data.get("node")
	var p2 = anchor_two_data.get("node")
	if is_instance_valid(p1) and is_instance_valid(p2):
		var mid_point = (p1.global_position + p2.global_position) * 0.5
		# Empowered Q: 50% faster acceleration (impulse 24.0 vs 16.0), longer stun (1.5s), decaying slow after
		var impulse_strength = 24.0 if tether_is_empowered else 16.0
		var stun_dur = 1.5 if tether_is_empowered else 0.75

		for p in [p1, p2]:
			if is_instance_valid(p):
				if p.has_method("apply_velocity_impulse"):
					var dir = (mid_point - p.global_position).normalized()
					p.apply_velocity_impulse(dir * impulse_strength, true)
				if p.has_method("apply_stun"):
					p.apply_stun(stun_dur)
				if tether_is_empowered and p.has_method("apply_slow"):
					# Decaying slow after stun
					var timer = get_tree().create_timer(stun_dur)
					timer.timeout.connect(func():
						if is_instance_valid(p) and p.has_method("apply_slow"):
							p.apply_slow(2.0, 0.40)
					)

@rpc("any_peer", "call_local", "reliable")
func sync_tether_recast(has_recast: bool, _hit_p: Vector3) -> void:
	tether_recast_window = 4.0 if has_recast else 0.0

# --- Process Kit Updates ---
func _process_character_kit(delta: float) -> void:
	# Passive cooldown timer
	if passive_cooldown_timer > 0.0:
		passive_cooldown_timer = max(0.0, passive_cooldown_timer - delta)

	# Orbit visual update
	crow_orbit_angle += 3.2 * delta
	if crow_orbit_angle > TAU:
		crow_orbit_angle -= TAU

	# Tether recast window expiration
	if tether_recast_window > 0.0:
		tether_recast_window -= delta

	# Process Crowstorm flight / Empowered dash
	if is_empowered_dashing:
		empowered_dash_timer -= delta
		velocity.x = empowered_dash_dir.x * EMPOWERED_DASH_SPEED
		velocity.z = empowered_dash_dir.z * EMPOWERED_DASH_SPEED
		if empowered_dash_timer <= 0.0:
			is_empowered_dashing = false
			is_crowstorm_active = false
	elif is_crowstorm_active:
		crowstorm_timer -= delta
		if not is_on_floor():
			velocity.y = max(velocity.y, 0.0) # Hover/flight
		if crowstorm_timer <= 0.0:
			is_crowstorm_active = false

func custom_execute_ability_server(slot_key: String, origin: Vector3, dir: Vector3, target_pos: Vector3, _charge: float) -> bool:
	if slot_key == "SHIFT":
		if is_passive_empowered_ready:
			_perform_empowered_crow_dash()
			return true # Intercepts normal shift so its CD is unaffected
		else:
			is_crowstorm_active = true
			crowstorm_timer = CROWSTORM_DURATION
			return false
	elif slot_key == "RMB":
		var is_emp = is_passive_empowered_ready
		var cast_id = _get_next_cast_id()
		if is_emp:
			passive_cooldown_timer = PASSIVE_COOLDOWN
		current_rmb_is_empowered = is_emp
		current_rmb_cast_id = cast_id

		var tree = get_tree()
		var main_node = tree.root.get_node_or_null("Main") if (tree and tree.root) else null
		if main_node:
			var p_type = "morrigan_mortar_empowered" if is_emp else "mortar_shell"
			main_node.spawn_mortar_shell(origin, target_pos, peer_id, team_id, 38.0, 3.2, 20.0)
			var proj_cont = main_node.projectiles_container if "projectiles_container" in main_node else null
			if proj_cont and proj_cont.get_child_count() > 0:
				var proj = proj_cont.get_child(proj_cont.get_child_count() - 1)
				if proj:
					proj.effect_type = p_type
					proj.set_meta("cast_id", cast_id)
					proj.set_meta("is_empowered", is_emp)
		return true
	elif slot_key == "Q":
		var is_emp = is_passive_empowered_ready
		var cast_id = _get_next_cast_id()
		if is_emp:
			passive_cooldown_timer = PASSIVE_COOLDOWN
		tether_is_empowered = is_emp
		tether_cast_id = cast_id
		return false
	elif slot_key == "E":
		var is_emp = is_passive_empowered_ready
		var cast_id = _get_next_cast_id()
		if is_emp:
			passive_cooldown_timer = PASSIVE_COOLDOWN
		current_e_is_empowered = is_emp
		current_e_cast_id = cast_id
		return false
	elif slot_key == "R":
		current_r_cast_id = _get_next_cast_id()
		return false
	return false

func custom_execute_ability_client(slot_key: String, _origin: Vector3, _dir: Vector3, _target_pos: Vector3, _charge: float) -> bool:
	if slot_key == "SHIFT":
		if is_passive_empowered_ready:
			_perform_empowered_crow_dash()
			return true
		else:
			is_crowstorm_active = true
			crowstorm_timer = CROWSTORM_DURATION
			return false
	return false

# --- E: Banshee Cry Hit Handler ---
func on_melee_strike_hit(target: Node, _hit_data: Dictionary) -> void:
	if not is_instance_valid(target) or not target.has_method("take_damage"):
		return
	if target.get("is_dead"):
		return

	if current_e_is_empowered:
		# 20% increased damage: 24.0 * 1.2 = 28.8, 0.5s silence, 30% slow for 1.0s
		target.take_damage(28.8, peer_id, ActionType.ABILITY)
		if target.has_method("apply_silence"):
			target.apply_silence(0.5)
		if target.has_method("apply_slow"):
			target.apply_slow(1.0, 0.30)
	else:
		# Unempowered: 24.0 damage, 30% slow for 1.0s (no silence/stun)
		target.take_damage(24.0, peer_id, ActionType.ABILITY)
		if target.has_method("apply_slow"):
			target.apply_slow(1.0, 0.30)
		_on_ability_hit(current_e_cast_id)

# --- Projectile Hit Callback for Passive Cooldown Reduction ---
func on_ability_projectile_hit_enemy(effect_type: String, _target: Node) -> void:
	if effect_type == "mortar_shell":
		_on_ability_hit(current_rmb_cast_id)
	elif effect_type == "blood_wave":
		_on_ability_hit(current_r_cast_id)

func _on_ability_hit(cast_id: int) -> void:
	if cast_id <= 0:
		return
	if cast_refund_history.has(cast_id):
		return
	cast_refund_history[cast_id] = true
	reduce_passive_cooldown(PASSIVE_CD_REDUCTION)

func reduce_passive_cooldown(seconds: float) -> void:
	if is_passive_empowered_ready:
		return
	passive_cooldown_timer = max(0.0, passive_cooldown_timer - seconds)
	if is_multiplayer_match() and is_server_authoritative():
		sync_passive_cd.rpc(passive_cooldown_timer)

@rpc("any_peer", "call_local", "reliable")
func sync_passive_cd(timer_val: float) -> void:
	passive_cooldown_timer = timer_val

func modify_incoming_damage(amount: float, _attacker_id: int, _action_type: int) -> float:
	if is_crowstorm_active:
		return amount * 0.50 # 50% damage reduction during Crowstorm flight / dash
	return amount

func _update_crow_orbit_visuals() -> void:
	if not crow_container:
		return
	var crow0 = crow_container.get_node_or_null("Crow0")
	if crow0:
		crow0.visible = is_passive_empowered_ready
	var crow1 = crow_container.get_node_or_null("Crow1")
	if crow1:
		crow1.visible = false
	var crow2 = crow_container.get_node_or_null("Crow2")
	if crow2:
		crow2.visible = false

func get_speed_multiplier() -> float:
	var mult = 1.0
	if is_crowstorm_active:
		mult += 0.60
	return mult

func get_status_text() -> String:
	if is_channeling:
		return "✦ CHANNELING DELUGE (%.1fs) ✦" % max(0.0, channel_timer)
	if is_feared():
		return "✦ FEARED (%.1fs) ✦" % fear_timer
	if is_crowstorm_active:
		return "✦ CROWSTORM (FLIGHT) ✦"
	elif tether_recast_window > 0.0:
		return "✦ TETHER READY (PRESS Q TO RECAST) ✦"
	elif is_charging_lmb:
		return "✦ BLACK PLUMAGE: %d FEATHERS ✦" % _calculate_lmb_feather_count()
	elif is_passive_empowered_ready:
		return "✦ DOOM CROW READY (NEXT SKILL EMPOWERED) ✦"
	elif passive_cooldown_timer > 0.0:
		return "✦ DOOM CROW (%.1fs) ✦" % passive_cooldown_timer
	return ""
