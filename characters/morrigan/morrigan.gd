class_name Morrigan
extends BasePlayer

# Ability Cooldowns & Timers
var attack_timer: float = 0.0
var rmb_timer: float = 0.0
var q_timer: float = 0.0
var e_timer: float = 0.0
var r_timer: float = 0.0
var dash_timer: float = 0.0
var current_camera_offset: Vector3 = CAMERA_OFFSET

# --- Passive: Harbinger of Doom ---
var passive_crows_count: int = 0:
	set(value):
		passive_crows_count = value
		_update_crow_orbit_visuals()
const MAX_PASSIVE_CROWS: int = 3
const CROW_DETECT_RADIUS: float = 7.0
const CROW_DAMAGE: float = 12.0
const CROW_SLOW_PCT: float = 0.35
const CROW_SLOW_DUR: float = 1.8
var crow_orbit_angle: float = 0.0
var crow_seek_cooldown: float = 0.0

# --- Primary Fire (LMB): Black Plumage ---
var lmb_charging: bool = false
var lmb_charge_timer: float = 0.0
const LMB_FIRST_CHARGE: float = 0.35
const LMB_SUBSEQUENT_CHARGE: float = 0.18
const LMB_MAX_FEATHERS: int = 5
const LMB_FEATHER_DAMAGE: float = 9.0
var lmb_burst_queue: int = 0
var lmb_burst_timer: float = 0.0
var lmb_burst_dir: Vector3 = Vector3.FORWARD

# --- Ability 1 (RMB): Omen of Death (Mortar) ---
var mortar_charging: bool = false
var mortar_charge_timer: float = 0.0
const MORTAR_MIN_RANGE: float = 5.0
const MORTAR_MAX_RANGE: float = 22.0
const MORTAR_CHARGE_TIME: float = 0.85
const MORTAR_DAMAGE: float = 20.0
const MORTAR_RADIUS: float = 3.2
const MORTAR_SPEED: float = 38.0
const MORTAR_RECHARGE_TIME: float = 6.0
var current_mortar_charges: int = 1
var max_mortar_charges: int = 1
var mortar_recharge_timer: float = 0.0

# --- Ability 2 (Q): Inescapable Ends (Dual-Cast Tether) ---
var tether_recast_window: float = 0.0
var anchor_one_data: Dictionary = {}
var anchor_two_data: Dictionary = {}
var tether_pull_timer: float = 0.0
const TETHER_DURATION: float = 3.0
const TETHER_PULL_ACCEL: float = 26.0
const TETHER_COLLIDE_DIST: float = 1.5
var tether_visual_line: MeshInstance3D = null

# --- Ability 3 (E): Cry of the Banshee ---
const BANSHEE_RADIUS: float = 7.5
const BANSHEE_ANGLE: float = 85.0
const BANSHEE_DAMAGE: float = 24.0
const BANSHEE_SILENCE_DUR: float = 1.4

# --- Ultimate (R): Born of Blood, Return to Blood ---
const ULT_CHANNEL_TIME: float = 1.0
const ULT_WAVE_DAMAGE: float = 50.0
const ULT_WAVE_WIDTH: float = 12.0
const ULT_WAVE_SPEED: float = 22.0
const ULT_WAVE_RANGE: float = 45.0

# --- Dash (SHIFT): Crowstorm ---
var is_crowstorm_active: bool = false:
	set(value):
		is_crowstorm_active = value
		if crowstorm_mesh: crowstorm_mesh.visible = value
		if char_mesh: char_mesh.visible = not value
var crowstorm_timer: float = 0.0
var crowstorm_dir: Vector3 = Vector3.FORWARD
var crowstorm_turn_velocity: float = 0.0
const CROWSTORM_DURATION: float = 2.0
const CROWSTORM_FIXED_SPEED: float = 17.5
const CROWSTORM_TURN_ACCEL: float = 26.0
const CROWSTORM_MAX_TURN_RATE: float = 6.5
const CROWSTORM_TURN_DRAG: float = 20.0
const CROWSTORM_DR_MULT: float = 0.50

# Hold-to-aim Indicators
var ind_attack: Node3D = null
var ind_rmb: Node3D = null
var ind_q: Node3D = null
var ind_e: Node3D = null
var ind_r: Node3D = null
var is_holding_shoot: bool = false
var is_holding_dash: bool = false
var is_holding_rmb: bool = false
var is_holding_q: bool = false
var is_holding_e: bool = false
var is_holding_r: bool = false

# Visual nodes
@onready var crow_container: Node3D = get_node_or_null("CrowContainer")
@onready var crow_0: MeshInstance3D = get_node_or_null("CrowContainer/Crow0")
@onready var crow_1: MeshInstance3D = get_node_or_null("CrowContainer/Crow1")
@onready var crow_2: MeshInstance3D = get_node_or_null("CrowContainer/Crow2")
@onready var crowstorm_mesh: MeshInstance3D = get_node_or_null("CrowstormMesh")
@onready var char_mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")

const CAMERA_MORTAR_OFFSET = Vector3(0, 26.0, 6.97) # 15 degrees from vertical zoomed mortar mode

func _setup_character_kit() -> void:
	var data = MorriganData.create()
	load_character_data(data)
	
	_setup_local_indicators()
	_setup_tether_visual()

	var sync = get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	if sync and sync.replication_config:
		_add_sync_property(sync.replication_config, NodePath(".:passive_crows_count"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		_add_sync_property(sync.replication_config, NodePath(".:is_crowstorm_active"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)

func _setup_local_indicators() -> void:
	if not is_local_player():
		return
		
	var lmb_def = abilities.get("LMB")
	if lmb_def and lmb_def.hitbox:
		ind_attack = AbilityIndicator.create_emanating_indicator(lmb_def.hitbox, AbilityIndicator.EMPTY_FILL, AbilityIndicator.WHITE_OUTLINE)
		add_child(ind_attack)
		ind_attack.hide()
	
	ind_rmb = AbilityIndicator.create_mortar_indicator(MORTAR_RADIUS, Color(0.2, 0.05, 0.35, 0.25), Color(0.75, 0.2, 0.95, 0.95))
	add_child(ind_rmb)
	ind_rmb.hide()
	
	var q_def = abilities.get("Q")
	if q_def and q_def.hitbox:
		ind_q = AbilityIndicator.create_emanating_indicator(q_def.hitbox, AbilityIndicator.EMPTY_FILL, AbilityIndicator.WHITE_OUTLINE)
		add_child(ind_q)
		ind_q.hide()
	
	var e_def = abilities.get("E")
	if e_def and e_def.hitbox:
		ind_e = AbilityIndicator.create_emanating_indicator(e_def.hitbox, Color(0.2, 0.05, 0.35, 0.25), Color(0.7, 0.15, 0.9, 0.95))
		add_child(ind_e)
		ind_e.hide()
	
	var r_def = abilities.get("R")
	if r_def and r_def.hitbox:
		ind_r = AbilityIndicator.create_emanating_indicator(r_def.hitbox, Color(0.6, 0.05, 0.1, 0.3), Color(0.9, 0.1, 0.2, 0.95))
		add_child(ind_r)
		ind_r.hide()

func _setup_tether_visual() -> void:
	tether_visual_line = MeshInstance3D.new()
	tether_visual_line.name = "TetherVisualLine"
	tether_visual_line.top_level = true
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.7, 0.15, 0.9, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.2, 1.0, 1.0)
	mat.emission_energy_multiplier = 4.0
	tether_visual_line.material_override = mat
	add_child(tether_visual_line)
	tether_visual_line.hide()

func _exit_tree() -> void:
	if ind_rmb and is_instance_valid(ind_rmb): ind_rmb.queue_free()
	if tether_visual_line and is_instance_valid(tether_visual_line): tether_visual_line.queue_free()

func _process_character_kit(delta: float) -> void:
	# Passive Crow Orbiting
	crow_orbit_angle += delta * 2.5
	_update_crow_orbit_visuals()
	
	# Passive Crow Seeking Proximity Logic (Server)
	if multiplayer.is_server():
		if crow_seek_cooldown > 0.0:
			crow_seek_cooldown -= delta
		elif passive_crows_count > 0:
			_check_passive_crow_seek()
			
	# LMB Burst firing queue
	if lmb_burst_queue > 0:
		lmb_burst_timer -= delta
		if lmb_burst_timer <= 0.0:
			lmb_burst_timer = 0.06
			lmb_burst_queue -= 1
			_fire_single_feather(lmb_burst_dir)

	# Mortar recharge charges
	if current_mortar_charges < max_mortar_charges:
		mortar_recharge_timer += delta
		if mortar_recharge_timer >= MORTAR_RECHARGE_TIME:
			mortar_recharge_timer = 0.0
			current_mortar_charges += 1

	# Q Tether recast window
	if tether_recast_window > 0.0:
		tether_recast_window -= delta
		if tether_recast_window <= 0.0:
			tether_recast_window = 0.0
			anchor_one_data.clear()
			
	# Q Tether active pull physics (Server)
	if tether_pull_timer > 0.0:
		tether_pull_timer -= delta
		_process_tether_pull(delta)
		_update_tether_line_visual()
		if tether_pull_timer <= 0.0:
			_end_tether_pull()
			
	# Crowstorm Dash State
	if is_crowstorm_active:
		crowstorm_timer -= delta
		_process_crowstorm(delta)
		if crowstorm_timer <= 0.0:
			_end_crowstorm()

	# Cooldowns tracking
	if is_local_player():
		if attack_timer > 0.0: attack_timer -= delta
		if rmb_timer > 0.0: rmb_timer -= delta
		if q_timer > 0.0: q_timer -= delta
		if e_timer > 0.0: e_timer -= delta
		if r_timer > 0.0: r_timer -= delta
		if dash_timer > 0.0: dash_timer -= delta

func _process_camera(delta: float) -> void:
	if not camera:
		return
	var target_offset = CAMERA_MORTAR_OFFSET if mortar_charging else CAMERA_OFFSET
	current_camera_offset = current_camera_offset.lerp(target_offset, 5.0 * delta)
	camera.global_position = global_position + current_camera_offset
	camera.look_at(global_position, Vector3.UP)

func modify_incoming_damage(amount: float, _attacker_id: int, _action_type: int) -> float:
	if is_crowstorm_active:
		return amount * CROWSTORM_DR_MULT
	return amount

func has_custom_movement_control() -> bool:
	return is_crowstorm_active

func get_status_text() -> String:
	if is_crowstorm_active:
		return "✦ CROWSTORM (17.5 m/s / 50%% DR) (%.1fs) ✦" % crowstorm_timer
	return ""

func _handle_character_input(delta: float) -> void:
	if is_crowstorm_active:
		if Input.is_action_just_pressed("dash"):
			_end_crowstorm()
			return
		# Player steers direction with turning acceleration, not directional acceleration
		var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if input_dir != Vector2.ZERO:
			var target_dir = Vector3(input_dir.x, 0, input_dir.y).normalized()
			var current_angle = atan2(crowstorm_dir.z, crowstorm_dir.x)
			var target_angle = atan2(target_dir.z, target_dir.x)
			var angle_diff = wrapf(target_angle - current_angle, -PI, PI)
			
			var turn_dir = sign(angle_diff)
			crowstorm_turn_velocity = move_toward(
				crowstorm_turn_velocity,
				turn_dir * CROWSTORM_MAX_TURN_RATE,
				CROWSTORM_TURN_ACCEL * delta
			)
			if abs(angle_diff) < abs(crowstorm_turn_velocity * delta):
				crowstorm_turn_velocity = angle_diff / delta
		else:
			crowstorm_turn_velocity = move_toward(crowstorm_turn_velocity, 0.0, CROWSTORM_TURN_DRAG * delta)
		return
		
	if is_channeling:
		return

	# --- Dash (SHIFT): Crowstorm ---
	if is_cast_on_press("dash"):
		if Input.is_action_just_pressed("dash") and dash_timer <= 0.0 and not is_rooted() and not is_grounded():
			_execute_crowstorm_dash()
	else:
		if Input.is_action_just_pressed("dash") and dash_timer <= 0.0 and not is_rooted() and not is_grounded():
			is_holding_dash = true
		if Input.is_action_just_released("dash") and is_holding_dash:
			is_holding_dash = false
			if dash_timer <= 0.0 and not is_rooted() and not is_grounded():
				_execute_crowstorm_dash()

	# --- Primary Fire (LMB): Black Plumage (Chargeable) ---
	if is_cast_on_press("shoot"):
		if Input.is_action_just_pressed("shoot") and attack_timer <= 0.0:
			lmb_charging = true
			lmb_charge_timer = 0.0
		elif Input.is_action_pressed("shoot") and lmb_charging:
			lmb_charge_timer += delta
		if Input.is_action_just_released("shoot") and lmb_charging:
			lmb_charging = false
			if ind_attack: ind_attack.hide()
			_release_black_plumage()
	else:
		if Input.is_action_just_pressed("shoot") and attack_timer <= 0.0:
			lmb_charging = true
			lmb_charge_timer = 0.0
			if ind_attack:
				AbilityIndicator.reset_indicator(ind_attack)
				ind_attack.show()
		elif Input.is_action_pressed("shoot") and lmb_charging:
			lmb_charge_timer += delta
		if Input.is_action_just_released("shoot") and lmb_charging:
			lmb_charging = false
			if ind_attack: ind_attack.hide()
			_release_black_plumage()

	# --- Ability 1 (RMB): Omen of Death (Mortar Charge) ---
	if is_cast_on_press("ability_one"):
		if Input.is_action_just_pressed("ability_one") and not is_silenced() and current_mortar_charges > 0 and rmb_timer <= 0.0:
			mortar_charging = false
			mortar_charge_timer = 0.0
			_release_omen_of_death()
	else:
		if Input.is_action_just_pressed("ability_one") and not is_silenced() and current_mortar_charges > 0 and rmb_timer <= 0.0:
			mortar_charging = true
			mortar_charge_timer = 0.0
			if ind_rmb:
				AbilityIndicator.reset_indicator(ind_rmb)
				ind_rmb.show()
		elif Input.is_action_pressed("ability_one") and mortar_charging:
			mortar_charge_timer += delta
			_update_mortar_indicator()
		if Input.is_action_just_released("ability_one") and mortar_charging:
			mortar_charging = false
			if ind_rmb: ind_rmb.hide()
			_release_omen_of_death()

	# --- Ability 2 (Q): Inescapable Ends (Dual-Cast Tether) ---
	if is_cast_on_press("ability_two"):
		if Input.is_action_just_pressed("ability_two") and not is_silenced() and q_timer <= 0.0:
			_perform_tether_cast()
	else:
		if Input.is_action_just_pressed("ability_two") and not is_silenced() and q_timer <= 0.0:
			is_holding_q = true
			if ind_q:
				AbilityIndicator.reset_indicator(ind_q)
				ind_q.show()
		if Input.is_action_just_released("ability_two") and is_holding_q:
			is_holding_q = false
			if ind_q: ind_q.hide()
			if not is_silenced() and q_timer <= 0.0:
				_perform_tether_cast()

	# --- Ability 3 (E): Cry of the Banshee ---
	if is_cast_on_press("ability_three"):
		if Input.is_action_just_pressed("ability_three") and not is_silenced() and e_timer <= 0.0:
			_perform_banshee_cry()
	else:
		if Input.is_action_just_pressed("ability_three") and not is_silenced() and e_timer <= 0.0:
			is_holding_e = true
			if ind_e:
				AbilityIndicator.reset_indicator(ind_e)
				ind_e.show()
		if Input.is_action_just_released("ability_three") and is_holding_e:
			is_holding_e = false
			if ind_e: ind_e.hide()
			if e_timer <= 0.0 and not is_silenced():
				_perform_banshee_cry()

	# --- Ultimate (R): Born of Blood, Return to Blood ---
	if is_cast_on_press("ability_four"):
		if Input.is_action_just_pressed("ability_four") and not is_silenced() and r_timer <= 0.0:
			_perform_born_of_blood()
	else:
		if Input.is_action_just_pressed("ability_four") and not is_silenced() and r_timer <= 0.0:
			is_holding_r = true
			if ind_r:
				AbilityIndicator.reset_indicator(ind_r)
				ind_r.show()
		if Input.is_action_just_released("ability_four") and is_holding_r:
			is_holding_r = false
			if ind_r: ind_r.hide()
			if not is_silenced() and r_timer <= 0.0:
				_perform_born_of_blood()

# --- Passive Crows Implementation ---
func _update_crow_orbit_visuals() -> void:
	var crows = [crow_0, crow_1, crow_2]
	for i in range(3):
		if crows[i]:
			if i < passive_crows_count:
				crows[i].visible = true
				var ang = crow_orbit_angle + float(i) * (TAU / 3.0)
				crows[i].position = Vector3(cos(ang) * 1.6, 0.0, sin(ang) * 1.6)
			else:
				crows[i].visible = false

func _check_passive_crow_seek() -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	var nearest_enemy: Node3D = null
	var min_d = CROW_DETECT_RADIUS
	for player in players_container.get_children():
		if player is Node3D and player.name != name and not player.get("is_dead"):
			var is_enemy = (team_id == 0 or player.get("team_id") != team_id)
			if is_enemy:
				var dist = global_position.distance_to(player.global_position)
				if dist <= min_d:
					min_d = dist
					nearest_enemy = player
	if nearest_enemy:
		crow_seek_cooldown = 1.0
		passive_crows_count = max(0, passive_crows_count - 1)
		_update_crow_orbit_visuals()
		sync_passive_crows.rpc(passive_crows_count)
		_spawn_seeking_crow(global_position + Vector3(0, 1.2, 0), nearest_enemy)

func _spawn_seeking_crow(spawn_pos: Vector3, target_enemy: Node3D) -> void:
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node and main_node.has_method("spawn_projectile"):
		var shoot_dir = (target_enemy.global_position - spawn_pos).normalized()
		main_node.spawn_projectile(
			spawn_pos,
			shoot_dir,
			name.to_int(),
			CROW_DAMAGE,
			28.0,
			0.5,
			2.5,
			"slow",
			CROW_SLOW_DUR,
			CROW_SLOW_PCT,
			false,
			false,
			0,
			BasePlayer.ActionType.ENVIRONMENT,
			CROW_DETECT_RADIUS * 1.5
		)

@rpc("any_peer", "call_local", "reliable")
func sync_passive_crows(count: int) -> void:
	passive_crows_count = count
	_update_crow_orbit_visuals()

func _on_character_damage_dealt(_target: Node, _amount: float, _action_type: int) -> void:
	if multiplayer.is_server():
		if _action_type == BasePlayer.ActionType.ABILITY:
			if passive_crows_count < MAX_PASSIVE_CROWS:
				passive_crows_count += 1
				sync_passive_crows.rpc(passive_crows_count)

# --- Primary Fire: Black Plumage ---
func _calculate_lmb_feather_count() -> int:
	if lmb_charge_timer < LMB_FIRST_CHARGE:
		return 1
	var extra_time = lmb_charge_timer - LMB_FIRST_CHARGE
	var extra_feathers = int(extra_time / LMB_SUBSEQUENT_CHARGE)
	return clamp(1 + extra_feathers, 1, LMB_MAX_FEATHERS)

func _release_black_plumage() -> void:
	var def = abilities.get("LMB")
	attack_timer = def.cooldown if def else 0.25
	var facing_dir = -global_transform.basis.z.normalized()
	facing_dir.y = 0.0
	facing_dir = facing_dir.normalized()
	var spawn_pos = global_position + Vector3(0, 1.0, 0) + facing_dir * 0.8
	var shoot_dir = get_ranged_aim_direction(spawn_pos)
	var feather_count = _calculate_lmb_feather_count()
	
	attack_performed.emit("Black Plumage (%d)" % feather_count)
	lmb_burst_queue = feather_count
	lmb_burst_dir = shoot_dir
	lmb_burst_timer = 0.0

func _fire_single_feather(dir: Vector3) -> void:
	var spawn_pos = global_position + Vector3(0, 1.0, 0) + dir * 0.8
	if multiplayer.is_server():
		_spawn_feather(spawn_pos, dir, name.to_int())
	else:
		request_feather_fire.rpc_id(1, spawn_pos, dir)

func _spawn_feather(spawn_pos: Vector3, shoot_dir: Vector3, sender_id: int) -> void:
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node and main_node.has_method("spawn_projectile"):
		main_node.spawn_projectile(
			spawn_pos,
			shoot_dir,
			sender_id,
			LMB_FEATHER_DAMAGE,
			70.0,
			0.4,
			35.0 / 70.0,
			"",
			0.0,
			0.0,
			false,
			false,
			0,
			ActionType.ATTACK,
			35.0
		)

@rpc("any_peer", "call_remote", "reliable")
func request_feather_fire(spawn_pos: Vector3, shoot_dir: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_spawn_feather(spawn_pos, shoot_dir, sender_id)

# --- Ability 1: Omen of Death (Mortar) ---
func _update_mortar_indicator() -> void:
	if not ind_rmb:
		return
	var charge_ratio = clamp(mortar_charge_timer / MORTAR_CHARGE_TIME, 0.0, 1.0)
	var current_range = lerp(MORTAR_MIN_RANGE, MORTAR_MAX_RANGE, charge_ratio)
	var facing_dir = -global_transform.basis.z.normalized()
	var aim_angle = atan2(facing_dir.x, -facing_dir.z)
	
	var hit_pos = get_mouse_ground_intersection()
	if hit_pos != null:
		var mouse_dir = Vector3(hit_pos.x - global_position.x, 0.0, hit_pos.z - global_position.z)
		if mouse_dir.length_squared() > 0.001:
			aim_angle = atan2(mouse_dir.x, -mouse_dir.z)
	
	AbilityIndicator.update_mortar_distance_and_angle(ind_rmb, global_position, current_range, aim_angle)

func _release_omen_of_death() -> void:
	if current_mortar_charges <= 0:
		return
	current_mortar_charges -= 1
	var def = abilities.get("RMB")
	rmb_timer = def.cooldown if def else MORTAR_RECHARGE_TIME
	
	var charge_ratio = clamp(mortar_charge_timer / MORTAR_CHARGE_TIME, 0.0, 1.0)
	var current_range = lerp(MORTAR_MIN_RANGE, MORTAR_MAX_RANGE, charge_ratio)
	var facing_dir = -global_transform.basis.z.normalized()
	
	var hit_pos = get_mouse_ground_intersection()
	var target_pos = global_position + facing_dir * current_range
	if hit_pos != null:
		var mouse_dir = Vector3(hit_pos.x - global_position.x, 0.0, hit_pos.z - global_position.z)
		if mouse_dir.length_squared() > 0.001:
			target_pos = global_position + mouse_dir.normalized() * current_range
	target_pos.y = 0.05
	
	ability_cast.emit("Omen of Death", "RMB")
	var start_p = global_position + Vector3(0, 0.8, 0)
	if not is_multiplayer_match() or multiplayer.is_server():
		_spawn_mortar_shell(start_p, target_pos, name.to_int())
	else:
		request_mortar_shell.rpc_id(1, start_p, target_pos)

func _spawn_mortar_shell(start_p: Vector3, end_p: Vector3, sender_id: int) -> void:
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node and main_node.has_method("spawn_mortar_shell"):
		main_node.spawn_mortar_shell(start_p, end_p, sender_id, team_id, MORTAR_SPEED, MORTAR_RADIUS, MORTAR_DAMAGE)

@rpc("any_peer", "call_remote", "reliable")
func request_mortar_shell(start_p: Vector3, end_p: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_spawn_mortar_shell(start_p, end_p, sender_id)

# --- Ability 2: Inescapable Ends (Dual Tether) ---
func _perform_tether_cast() -> void:
	var facing_dir = -global_transform.basis.z.normalized()
	facing_dir.y = 0.0
	facing_dir = facing_dir.normalized()
	var spawn_pos = global_position + Vector3(0, 0.8, 0) + facing_dir * 1.0
	var shoot_dir = get_ranged_aim_direction(spawn_pos)
	var is_recast = (tether_recast_window > 0.0 and not anchor_one_data.is_empty())
	
	ability_cast.emit("Inescapable Ends" + (" (Recast)" if is_recast else ""), "Q")
	if not is_multiplayer_match() or multiplayer.is_server():
		_execute_tether_projectile(spawn_pos, shoot_dir, name.to_int(), is_recast)
	else:
		request_tether_cast.rpc_id(1, spawn_pos, shoot_dir, is_recast)

@rpc("any_peer", "call_remote", "reliable")
func request_tether_cast(spawn_pos: Vector3, shoot_dir: Vector3, is_recast: bool) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_execute_tether_projectile(spawn_pos, shoot_dir, sender_id, is_recast)

func _execute_tether_projectile(spawn_pos: Vector3, shoot_dir: Vector3, sender_id: int, is_recast: bool) -> void:
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node and main_node.has_method("spawn_projectile"):
		var eff = "morrigan_tether_recast" if is_recast else "morrigan_tether_first"
		main_node.spawn_projectile(
			spawn_pos,
			shoot_dir,
			sender_id,
			10.0,
			45.0,
			0.6,
			15.0 / 45.0,
			eff,
			0.0,
			0.0,
			false,
			false,
			0,
			ActionType.ABILITY,
			15.0
		)

func on_tether_impact_server(target_body: Node, hit_pos: Vector3, is_recast: bool) -> void:
	var is_player = target_body is Node3D and target_body.has_method("take_damage")
	var anchor_info = {
		"is_player": is_player,
		"player_id": target_body.name.to_int() if is_player else 0,
		"node": target_body,
		"pos": hit_pos
	}
	
	if not is_recast:
		anchor_one_data = anchor_info
		tether_recast_window = 4.0
		sync_tether_recast.rpc(true, hit_pos)
	else:
		anchor_two_data = anchor_info
		tether_recast_window = 0.0
		tether_pull_timer = TETHER_DURATION
		var p1_id = anchor_one_data.get("player_id", 0)
		var p2_id = anchor_two_data.get("player_id", 0)
		sync_tether_start.rpc(anchor_one_data.get("pos", Vector3.ZERO), anchor_two_data.get("pos", Vector3.ZERO), p1_id, p2_id)
		var def = abilities.get("Q")
		q_timer = def.cooldown if def else 9.0

@rpc("any_peer", "call_local", "reliable")
func sync_tether_recast(has_recast: bool, _hit_p: Vector3) -> void:
	tether_recast_window = 4.0 if has_recast else 0.0

@rpc("any_peer", "call_local", "reliable")
func sync_tether_start(p1_pos: Vector3, p2_pos: Vector3, p1_id: int, p2_id: int) -> void:
	tether_pull_timer = TETHER_DURATION
	anchor_one_data = {"pos": p1_pos, "player_id": p1_id, "is_player": (p1_id > 0)}
	anchor_two_data = {"pos": p2_pos, "player_id": p2_id, "is_player": (p2_id > 0)}
	if tether_visual_line:
		tether_visual_line.show()

func _process_tether_pull(delta: float) -> void:
	var p1 = null
	var p2 = null
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if players_container:
		if anchor_one_data.get("is_player"):
			p1 = players_container.get_node_or_null(str(anchor_one_data.get("player_id")))
		if anchor_two_data.get("is_player"):
			p2 = players_container.get_node_or_null(str(anchor_two_data.get("player_id")))
			
	var p1_pos = p1.global_position if (p1 and is_instance_valid(p1)) else anchor_one_data.get("pos", Vector3.ZERO)
	var p2_pos = p2.global_position if (p2 and is_instance_valid(p2)) else anchor_two_data.get("pos", Vector3.ZERO)
	
	# Check dual player collision
	if p1 and p2 and is_instance_valid(p1) and is_instance_valid(p2):
		var dist = p1.global_position.distance_to(p2.global_position)
		if dist <= TETHER_COLLIDE_DIST:
			if p1.has_method("apply_stun"): p1.apply_stun(1.0)
			if p2.has_method("apply_stun"): p2.apply_stun(1.0)
			_end_tether_pull()
			return
			
	# Pull logic (constant acceleration toward anchor/opposite target)
	if p1 and is_instance_valid(p1) and not p1.get("is_dead"):
		var dir_to_p2 = (p2_pos - p1.global_position).normalized()
		dir_to_p2.y = 0.0
		if p1.has_method("apply_knockback"):
			p1.apply_knockback(dir_to_p2 * TETHER_PULL_ACCEL * delta, false)
			
	if p2 and is_instance_valid(p2) and not p2.get("is_dead"):
		var dir_to_p1 = (p1_pos - p2.global_position).normalized()
		dir_to_p1.y = 0.0
		if p2.has_method("apply_knockback"):
			p2.apply_knockback(dir_to_p1 * TETHER_PULL_ACCEL * delta, false)

func _update_tether_line_visual() -> void:
	if not tether_visual_line:
		return
	var p1_pos = anchor_one_data.get("pos", Vector3.ZERO)
	var p2_pos = anchor_two_data.get("pos", Vector3.ZERO)
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if players_container:
		if anchor_one_data.get("player_id", 0) > 0:
			var p1 = players_container.get_node_or_null(str(anchor_one_data["player_id"]))
			if p1 and is_instance_valid(p1): p1_pos = p1.global_position + Vector3(0, 0.9, 0)
		if anchor_two_data.get("player_id", 0) > 0:
			var p2 = players_container.get_node_or_null(str(anchor_two_data["player_id"]))
			if p2 and is_instance_valid(p2): p2_pos = p2.global_position + Vector3(0, 0.9, 0)
			
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	st.set_color(Color(0.8, 0.2, 1.0, 1.0))
	st.add_vertex(p1_pos)
	st.add_vertex(p2_pos)
	tether_visual_line.mesh = st.commit()

func _end_tether_pull() -> void:
	tether_pull_timer = 0.0
	anchor_one_data.clear()
	anchor_two_data.clear()
	if tether_visual_line:
		tether_visual_line.hide()
	sync_tether_end.rpc()

@rpc("any_peer", "call_local", "reliable")
func sync_tether_end() -> void:
	tether_pull_timer = 0.0
	if tether_visual_line:
		tether_visual_line.hide()

# --- Ability 3: Cry of the Banshee ---
func _perform_banshee_cry() -> void:
	var def = abilities.get("E")
	e_timer = def.cooldown if def else 14.0
	var facing_dir = -global_transform.basis.z.normalized()
	ability_cast.emit("Cry of the Banshee", "E")
	trigger_ability_hitbox("E", global_position, facing_dir)
	
	if not is_multiplayer_match() or multiplayer.is_server():
		_execute_banshee_cry(global_position, facing_dir, name.to_int())
	else:
		request_banshee_cry.rpc_id(1, global_position, facing_dir)

func _execute_banshee_cry(origin_pos: Vector3, forward_dir: Vector3, sender_id: int) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	var def = abilities.get("E")
	var height = def.hitbox.height if (def and def.hitbox and def.hitbox.height > 0.0) else 2.6
	var half_angle_rad = deg_to_rad(BANSHEE_ANGLE * 0.5)
	for player in players_container.get_children():
		if player is Node3D and player.name != str(sender_id) and not player.get("is_dead"):
			var is_enemy = (team_id == 0 or player.get("team_id") != team_id)
			if is_enemy:
				var to_player = player.global_position - origin_pos
				var dy = to_player.y
				if dy < -2.0 or dy > height:
					continue
				to_player.y = 0.0
				var dist = to_player.length()
				if dist <= BANSHEE_RADIUS and dist > 0.001:
					if forward_dir.angle_to(to_player.normalized()) <= half_angle_rad:
						if player.has_method("take_damage"):
							player.take_damage(BANSHEE_DAMAGE, sender_id, ActionType.ABILITY)
						if player.has_method("apply_silence"):
							player.apply_silence(BANSHEE_SILENCE_DUR)
						var shooter = players_container.get_node_or_null(str(sender_id))
						if shooter and shooter.has_method("_on_character_damage_dealt"):
							shooter._on_character_damage_dealt(player, BANSHEE_DAMAGE, ActionType.ABILITY)

@rpc("any_peer", "call_remote", "reliable")
func request_banshee_cry(origin_pos: Vector3, forward_dir: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_execute_banshee_cry(origin_pos, forward_dir, sender_id)

# --- Ultimate: Born of Blood, Return to Blood ---
var blood_wave_charging_visual: Node3D = null

func _perform_born_of_blood() -> void:
	var def = abilities.get("R")
	r_timer = def.cooldown if def else 30.0
	ability_cast.emit("Born of Blood", "R")
	start_channel(ULT_CHANNEL_TIME, _on_born_of_blood_complete)
	if is_multiplayer_match():
		sync_blood_wave_charge_visual.rpc(true)
	else:
		_show_blood_wave_charging_visual(true)

func _cleanup_blood_wave_charging_visual() -> void:
	if blood_wave_charging_visual and is_instance_valid(blood_wave_charging_visual):
		blood_wave_charging_visual.queue_free()
	blood_wave_charging_visual = null

func _show_blood_wave_charging_visual(show: bool) -> void:
	_cleanup_blood_wave_charging_visual()
	if not show:
		return
	
	blood_wave_charging_visual = Node3D.new()
	blood_wave_charging_visual.name = "BloodWaveChargingVisual"
	# Position in front of Morrigan along local -Z axis (ground level Y=0.0, Z=-2.5)
	blood_wave_charging_visual.position = Vector3(0.0, 0.0, -2.5)
	
	# Pure visual preview of the tidal wave - NO hitbox / collision shape
	var wave_mesh = MeshInstance3D.new()
	var bmesh = BoxMesh.new()
	bmesh.size = Vector3(12.0, 3.2, 0.8)
	wave_mesh.mesh = bmesh
	wave_mesh.position = Vector3(0.0, 1.6, 0.0)
	
	var mat_wave = StandardMaterial3D.new()
	mat_wave.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_wave.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_wave.albedo_color = Color(0.75, 0.05, 0.1, 0.7)
	mat_wave.emission_enabled = true
	mat_wave.emission = Color(0.9, 0.08, 0.12, 1.0)
	mat_wave.emission_energy_multiplier = 4.5
	wave_mesh.material_override = mat_wave
	blood_wave_charging_visual.add_child(wave_mesh)
	
	var crest_mesh = MeshInstance3D.new()
	var cmesh = BoxMesh.new()
	cmesh.size = Vector3(12.6, 0.4, 1.2)
	crest_mesh.mesh = cmesh
	crest_mesh.position = Vector3(0.0, 3.3, 0.0)
	
	var mat_crest = StandardMaterial3D.new()
	mat_crest.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_crest.albedo_color = Color(1.0, 0.25, 0.3, 0.85)
	mat_crest.emission_enabled = true
	mat_crest.emission = Color(1.0, 0.2, 0.25, 1.0)
	mat_crest.emission_energy_multiplier = 5.0
	crest_mesh.material_override = mat_crest
	blood_wave_charging_visual.add_child(crest_mesh)
	
	add_child(blood_wave_charging_visual)
	
	# Rising / surging wave animation over ULT_CHANNEL_TIME without hitbox
	blood_wave_charging_visual.scale = Vector3(0.2, 0.05, 0.2)
	var tween = create_tween()
	tween.tween_property(blood_wave_charging_visual, "scale", Vector3(1.0, 1.0, 1.0), ULT_CHANNEL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

@rpc("any_peer", "call_local", "reliable")
func sync_blood_wave_charge_visual(active: bool) -> void:
	_show_blood_wave_charging_visual(active)

func _on_channel_cancelled() -> void:
	super._on_channel_cancelled()
	if is_multiplayer_match():
		sync_blood_wave_charge_visual.rpc(false)
	else:
		_show_blood_wave_charging_visual(false)

func _on_born_of_blood_complete() -> void:
	if is_multiplayer_match():
		sync_blood_wave_charge_visual.rpc(false)
	else:
		_show_blood_wave_charging_visual(false)
	
	var facing_dir = -global_transform.basis.z.normalized()
	var spawn_pos = global_position + Vector3(0, 0.4, 0) + facing_dir * 1.5
	if not is_multiplayer_match() or multiplayer.is_server():
		_spawn_blood_wave(spawn_pos, facing_dir, name.to_int())
	else:
		request_blood_wave.rpc_id(1, spawn_pos, facing_dir)

func _spawn_blood_wave(spawn_pos: Vector3, shoot_dir: Vector3, sender_id: int) -> void:
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node and main_node.has_method("spawn_blood_wave"):
		main_node.spawn_blood_wave(spawn_pos, shoot_dir, sender_id, team_id, ULT_WAVE_SPEED, ULT_WAVE_RANGE, ULT_WAVE_WIDTH, ULT_WAVE_DAMAGE)

@rpc("any_peer", "call_remote", "reliable")
func request_blood_wave(spawn_pos: Vector3, shoot_dir: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_spawn_blood_wave(spawn_pos, shoot_dir, sender_id)

# --- Dash: Crowstorm ---
func _execute_crowstorm_dash() -> void:
	crowstorm_dir = get_dash_direction()
	crowstorm_turn_velocity = 0.0
	
	is_crowstorm_active = true
	crowstorm_timer = CROWSTORM_DURATION
	ability_cast.emit("Crowstorm", "SHIFT")
	sync_crowstorm.rpc(true)

func _process_crowstorm(delta: float) -> void:
	# Update heading angle via turning velocity
	if abs(crowstorm_turn_velocity) > 0.001:
		var current_angle = atan2(crowstorm_dir.z, crowstorm_dir.x)
		var new_angle = current_angle + crowstorm_turn_velocity * delta
		crowstorm_dir = Vector3(cos(new_angle), 0, sin(new_angle)).normalized()

	# Fixed speed applied along current heading direction (reduced by slows)
	var effective_speed = get_effective_dash_impulse(CROWSTORM_FIXED_SPEED)
	velocity.x = crowstorm_dir.x * effective_speed
	velocity.z = crowstorm_dir.z * effective_speed
	if not is_on_floor():
		velocity.y -= gravity * delta * 0.4
	else:
		velocity.y = 0.0

func _end_crowstorm() -> void:
	if not is_crowstorm_active:
		return
	is_crowstorm_active = false
	crowstorm_timer = 0.0
	var def = abilities.get("SHIFT")
	dash_timer = def.cooldown if def else 6.0
	sync_crowstorm.rpc(false)

@rpc("any_peer", "call_local", "reliable")
func sync_crowstorm(active: bool) -> void:
	is_crowstorm_active = active
	if crowstorm_mesh: crowstorm_mesh.visible = active
	if char_mesh: char_mesh.visible = not active

# --- HUD Updates ---
func _update_character_hud() -> void:
	var def_rmb = abilities.get("RMB")
	var def_q = abilities.get("Q")
	var def_e = abilities.get("E")
	var def_r = abilities.get("R")
	var def_shift = abilities.get("SHIFT")

	if slot_ability_one and def_rmb:
		var cd = (MORTAR_RECHARGE_TIME - mortar_recharge_timer) if current_mortar_charges < max_mortar_charges else rmb_timer
		slot_ability_one.update_cooldown(cd, MORTAR_RECHARGE_TIME, current_mortar_charges, max_mortar_charges, is_silenced())
	if slot_ability_two and def_q:
		var q_cd = tether_recast_window if tether_recast_window > 0.0 else q_timer
		slot_ability_two.update_cooldown(q_cd, def_q.cooldown, 1, 1, is_silenced())
		slot_ability_two.set_active_state(tether_recast_window > 0.0)
	if slot_ability_three and def_e:
		slot_ability_three.update_cooldown(e_timer, def_e.cooldown, 1, 1, is_silenced())
	if slot_ability_four and def_r:
		slot_ability_four.update_cooldown(r_timer, def_r.cooldown, 1, 1, is_silenced())
	if slot_dash and def_shift:
		slot_dash.update_cooldown(dash_timer, def_shift.cooldown, 1, 1, is_rooted() or is_grounded())
		slot_dash.set_active_state(is_crowstorm_active)

func execute_ability_slot(slot_key: String) -> bool:
	if is_dead or is_stunned():
		return false
	match slot_key.to_upper():
		"LMB", "SHOOT":
			if attack_timer <= 0.0 and can_cast_ability_slot("LMB"):
				_release_black_plumage()
				return true
		"RMB", "ABILITY_ONE":
			if current_mortar_charges > 0 and rmb_timer <= 0.0 and not is_silenced() and can_cast_ability_slot("RMB"):
				_release_omen_of_death()
				return true
		"Q", "ABILITY_TWO":
			if q_timer <= 0.0 and not is_silenced() and can_cast_ability_slot("Q"):
				_perform_tether_cast()
				return true
		"E", "ABILITY_THREE":
			if e_timer <= 0.0 and not is_silenced() and can_cast_ability_slot("E"):
				_perform_banshee_cry()
				return true
		"R", "ABILITY_FOUR":
			if r_timer <= 0.0 and not is_silenced() and can_cast_ability_slot("R"):
				_perform_born_of_blood()
				return true
		"SHIFT", "DASH":
			if dash_timer <= 0.0 and not is_rooted() and not is_grounded() and can_cast_ability_slot("SHIFT"):
				_execute_crowstorm_dash()
				return true
	return false
