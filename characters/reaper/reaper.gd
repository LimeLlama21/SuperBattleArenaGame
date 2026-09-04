class_name Reaper
extends BasePlayer

# Ability Cooldowns & Timers
var attack_timer: float = 0.0
var rmb_timer: float = 0.0
var q_timer: float = 0.0
var e_timer: float = 0.0
var r_timer: float = 0.0
var dash_timer: float = 0.0

var dash_impulse: float = 28.0
var dash_cooldown: float = 5.0

# Passive & Buff State
var reaper_ms_steal_timer: float = 0.0
var reaper_ms_steal_pct: float = 0.0

var reaper_ult_buff_timer: float = 0.0
const REAPER_ULT_BUFF_DURATION: float = 8.0
const REAPER_ULT_MS_MULT: float = 0.45
const REAPER_ULT_DMG_MULT: float = 1.30

# Nightmare Pool State
var is_in_nightmare: bool = false
var reaper_nightmare_timer: float = 0.0
const NIGHTMARE_DURATION: float = 1.8
const NIGHTMARE_RADIUS: float = 4.5

# Spectral Tether State
var is_holding_rmb: bool = false
const REAPER_RMB_MAX_RANGE: float = 24.0

var reaper_tether_target_id: int = 0
var reaper_tether_timer: float = 0.0
var reaper_tether_active: bool = false

# Cull the Weak Windup State
var reaper_q_windup_timer: float = 0.0

# Hold-to-aim Indicators
var shoot_hold_timer: float = 0.0
const LMB_HOLD_THRESHOLD: float = 0.18
var is_holding_shoot: bool = false
var is_holding_dash: bool = false
var is_holding_q: bool = false
var is_holding_e: bool = false
var is_holding_r: bool = false

var ind_attack: Node3D = null
var ind_rmb: Node3D = null
var ind_q: Node3D = null
var ind_e: Node3D = null
var ind_r: Node3D = null

@onready var melee_visual: Node3D = get_node_or_null("MeleeVisual")
@onready var ability_one_visual: Node3D = get_node_or_null("AbilityOneVisual")
@onready var ability_two_visual: Node3D = get_node_or_null("AbilityTwoVisual")
@onready var nightmare_visual: Node3D = get_node_or_null("NightmareVisual")
@onready var ult_visual: Node3D = get_node_or_null("UltVisual")

func _setup_character_kit() -> void:
	var data = ReaperData.create()
	load_character_data(data)

	dash_impulse = data.passive_data.get("dash_impulse", 28.0)
	dash_cooldown = data.passive_data.get("dash_cooldown", 5.0)

	_setup_local_indicators()

	var sync = get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	if sync and sync.replication_config:
		_add_sync_property(sync.replication_config, NodePath(".:is_in_nightmare"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		_add_sync_property(sync.replication_config, NodePath(".:reaper_ult_buff_timer"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		_add_sync_property(sync.replication_config, NodePath(".:reaper_tether_active"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		_add_sync_property(sync.replication_config, NodePath(".:reaper_tether_target_id"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)

func _setup_local_indicators() -> void:
	if not is_local_player():
		return

	var lmb_def = abilities.get("LMB")
	if lmb_def and lmb_def.hitbox:
		ind_attack = AbilityIndicator.create_emanating_indicator(lmb_def.hitbox, AbilityIndicator.EMPTY_FILL, AbilityIndicator.WHITE_OUTLINE)
		add_child(ind_attack)
		ind_attack.hide()

	var rmb_def = abilities.get("RMB")
	if rmb_def and rmb_def.hitbox:
		ind_rmb = AbilityIndicator.create_emanating_indicator(rmb_def.hitbox, AbilityIndicator.EMPTY_FILL, AbilityIndicator.WHITE_OUTLINE)
		add_child(ind_rmb)
		ind_rmb.hide()
	else:
		ind_rmb = AbilityIndicator.create_line_indicator(REAPER_RMB_MAX_RANGE, 0.8, AbilityIndicator.EMPTY_FILL, AbilityIndicator.WHITE_OUTLINE)
		add_child(ind_rmb)
		ind_rmb.hide()

	var q_def = abilities.get("Q")
	if q_def and q_def.hitbox:
		ind_q = AbilityIndicator.create_emanating_indicator(q_def.hitbox, AbilityIndicator.EMPTY_FILL, AbilityIndicator.WHITE_OUTLINE)
		add_child(ind_q)
		ind_q.hide()

	var e_def = abilities.get("E")
	if e_def and e_def.hitbox:
		ind_e = AbilityIndicator.create_emanating_indicator(e_def.hitbox, AbilityIndicator.EMPTY_FILL, AbilityIndicator.WHITE_OUTLINE)
		add_child(ind_e)
		ind_e.hide()

func _process_character_kit(delta: float) -> void:
	if reaper_ms_steal_timer > 0.0:
		reaper_ms_steal_timer -= delta
		if reaper_ms_steal_timer <= 0.0:
			reaper_ms_steal_timer = 0.0
			reaper_ms_steal_pct = 0.0

	if reaper_ult_buff_timer > 0.0:
		reaper_ult_buff_timer -= delta
		if reaper_ult_buff_timer <= 0.0:
			reaper_ult_buff_timer = 0.0
			if ult_visual:
				ult_visual.visible = false

	# Reaper Nightmare countdown
	if is_in_nightmare:
		reaper_nightmare_timer -= delta
		var is_srv = multiplayer.is_server() if (multiplayer and multiplayer.has_multiplayer_peer()) else true
		if reaper_nightmare_timer <= 0.0 and (is_local_player() or is_srv or name == "1"):
			end_reaper_nightmare()

	# Reaper Spectral Tether tick (Server-authoritative)
	if (not is_multiplayer_match() or multiplayer.is_server()) and not is_dead and reaper_tether_active:
		reaper_tether_timer -= delta
		var players_container = get_tree().root.get_node_or_null("Main/Players")
		var target = players_container.get_node_or_null(str(reaper_tether_target_id)) if players_container else null
		if not target or target.get("is_dead") or global_position.distance_to(target.global_position) > 22.0:
			end_reaper_tether_server(false)
		else:
			var progress = 1.0 - (reaper_tether_timer / 1.75)
			var slow_val = lerp(0.20, 0.85, clamp(progress, 0.0, 1.0))
			if target.has_method("apply_slow"):
				target.apply_slow(0.25, slow_val)
			if target.has_method("apply_grounded"):
				target.apply_grounded(0.25)
			if reaper_tether_timer <= 0.0:
				end_reaper_tether_server(true, target)

	if is_local_player():
		if attack_timer > 0.0: attack_timer -= delta
		if rmb_timer > 0.0: rmb_timer -= delta
		if q_timer > 0.0: q_timer -= delta
		if e_timer > 0.0: e_timer -= delta
		if r_timer > 0.0: r_timer -= delta
		if dash_timer > 0.0: dash_timer -= delta

		# Cull the Weak windup timer
		if reaper_q_windup_timer > 0.0:
			reaper_q_windup_timer -= delta
			if reaper_q_windup_timer <= 0.0:
				reaper_q_windup_timer = 0.0
				_on_cull_channel_finished()

func get_effective_max_speed(current_speed: float) -> float:
	var mult = 1.0
	if reaper_ms_steal_timer > 0.0:
		mult += reaper_ms_steal_pct
	if reaper_ult_buff_timer > 0.0:
		mult += REAPER_ULT_MS_MULT
	return current_speed * mult

func get_status_text() -> String:
	if is_in_nightmare:
		return "✦ NIGHTMARE FORM (INVULNERABLE) ✦"
	elif reaper_ult_buff_timer > 0.0:
		return "✦ ONE WITH DEATH (+45%% MS, +30%% DMG) (%.1fs) ✦" % reaper_ult_buff_timer
	elif reaper_ms_steal_timer > 0.0:
		return "✦ SOUL HARVEST (+15%% MS) (%.1fs) ✦" % reaper_ms_steal_timer
	return ""

func modify_incoming_damage(amount: float, _attacker_id: int, _action_type: int) -> float:
	if is_in_nightmare or is_ethereal_active():
		return 0.0
	return amount

func _handle_character_input(_delta: float) -> void:
	if is_in_nightmare:
		return

	# --- Dash (SHIFT): Ethereal Dash ---
	if is_cast_on_press("dash"):
		if Input.is_action_just_pressed("dash") and dash_timer <= 0.0 and not is_rooted() and not is_grounded():
			_execute_ethereal_dash()
	else:
		if Input.is_action_just_pressed("dash") and dash_timer <= 0.0 and not is_rooted() and not is_grounded():
			is_holding_dash = true
		if Input.is_action_just_released("dash") and is_holding_dash:
			is_holding_dash = false
			if dash_timer <= 0.0 and not is_rooted() and not is_grounded():
				_execute_ethereal_dash()

	# --- Primary Fire (LMB): Scythe Slash ---
	if is_cast_on_press("shoot"):
		if Input.is_action_just_pressed("shoot") or (Input.is_action_pressed("shoot") and attack_timer <= 0.0):
			if attack_timer <= 0.0:
				_perform_scythe_slash()
	else:
		if Input.is_action_just_pressed("shoot"):
			is_holding_shoot = true
			if ind_attack:
				AbilityIndicator.reset_indicator(ind_attack)
				ind_attack.show()
		if Input.is_action_just_released("shoot") and is_holding_shoot:
			is_holding_shoot = false
			if ind_attack: ind_attack.hide()
			if attack_timer <= 0.0:
				_perform_scythe_slash()

	# --- Ability 1 (RMB): Spectral Tether - Locked out during Q windup ---
	if is_cast_on_press("ability_one"):
		if Input.is_action_just_pressed("ability_one") and rmb_timer <= 0.0 and not is_silenced() and reaper_q_windup_timer <= 0.0:
			_perform_spectral_tether()
	else:
		if Input.is_action_just_pressed("ability_one") and not is_silenced() and reaper_q_windup_timer <= 0.0:
			if rmb_timer <= 0.0:
				is_holding_rmb = true
				if ind_rmb:
					AbilityIndicator.reset_indicator(ind_rmb)
					ind_rmb.show()
		if Input.is_action_just_released("ability_one") and is_holding_rmb:
			is_holding_rmb = false
			if ind_rmb: ind_rmb.hide()
			if rmb_timer <= 0.0 and not is_silenced() and reaper_q_windup_timer <= 0.0:
				_perform_spectral_tether()

	# --- Ability 2 (Q): Cull the Weak ---
	if is_cast_on_press("ability_two"):
		if Input.is_action_just_pressed("ability_two") and q_timer <= 0.0 and not is_silenced():
			_perform_cull_the_weak()
	else:
		if Input.is_action_just_pressed("ability_two") and not is_silenced():
			if q_timer <= 0.0:
				is_holding_q = true
				if ind_q:
					AbilityIndicator.reset_indicator(ind_q)
					ind_q.show()
		if Input.is_action_just_released("ability_two") and is_holding_q:
			is_holding_q = false
			if ind_q: ind_q.hide()
			if q_timer <= 0.0 and not is_silenced():
				_perform_cull_the_weak()

	# --- Ability 3 (E): Nightmare ---
	if is_cast_on_press("ability_three"):
		if Input.is_action_just_pressed("ability_three") and e_timer <= 0.0 and not is_silenced():
			_perform_nightmare()
	else:
		if Input.is_action_just_pressed("ability_three") and not is_silenced():
			if e_timer <= 0.0:
				is_holding_e = true
				if ind_e:
					AbilityIndicator.reset_indicator(ind_e)
					ind_e.show()
		if Input.is_action_just_released("ability_three") and is_holding_e:
			is_holding_e = false
			if ind_e: ind_e.hide()
			if e_timer <= 0.0 and not is_silenced():
				_perform_nightmare()

	# --- Ultimate (R): One with Death ---
	if is_cast_on_press("ability_four"):
		if Input.is_action_just_pressed("ability_four") and r_timer <= 0.0 and not is_silenced():
			_perform_one_with_death()
	else:
		if Input.is_action_just_pressed("ability_four") and not is_silenced():
			if r_timer <= 0.0:
				is_holding_r = true
				if ind_r:
					AbilityIndicator.reset_indicator(ind_r)
					ind_r.show()
		if Input.is_action_just_released("ability_four") and is_holding_r:
			is_holding_r = false
			if ind_r: ind_r.hide()
			if r_timer <= 0.0 and not is_silenced():
				_perform_one_with_death()

func _execute_ethereal_dash() -> void:
	dash_timer = dash_cooldown
	var effective_impulse = get_effective_dash_impulse(dash_impulse)
	apply_ethereal(0.45)
	var dash_dir = get_dash_direction()
	apply_velocity_impulse(Vector3(dash_dir.x * effective_impulse, 0, dash_dir.z * effective_impulse), true)

func _perform_scythe_slash() -> void:
	var def = abilities.get("LMB")
	attack_timer = def.cooldown if def else 0.45
	var facing_dir = -global_transform.basis.z.normalized()
	var dmg_mult = REAPER_ULT_DMG_MULT if reaper_ult_buff_timer > 0.0 else 1.0
	var dmg = 36.0
	attack_performed.emit("Reaper's Scythe")
	trigger_ability_hitbox("LMB", global_position, facing_dir)
	if not is_multiplayer_match() or multiplayer.is_server():
		_execute_scythe_strike(global_position, facing_dir, 1, dmg)
	else:
		request_scythe_strike.rpc_id(1, global_position, facing_dir, dmg)

func _execute_scythe_strike(origin_pos: Vector3, forward_dir: Vector3, attacker_id: int, dmg: float) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	var def = abilities.get("LMB")
	var rad = def.hitbox.radius if (def and def.hitbox) else 3.6
	var angle_deg = def.hitbox.angle_deg if (def and def.hitbox) else 110.0
	var height = def.hitbox.height if (def and def.hitbox and def.hitbox.height > 0.0) else 2.0
	var half_angle_rad = deg_to_rad(angle_deg * 0.5)
	var hit_enemy = false
	for body in players_container.get_children():
		if body is Node3D and body.name != str(attacker_id) and not body.get("is_dead") and is_enemy(body):
			var to_body = body.global_position - origin_pos
			var dy = to_body.y
			if dy < -2.0 or dy > height:
				continue
			to_body.y = 0.0
			var dist = to_body.length()
			if dist <= rad and dist > 0.001:
				if forward_dir.angle_to(to_body.normalized()) <= half_angle_rad:
					hit_enemy = true
					if body.has_method("take_damage"):
						body.take_damage(dmg, attacker_id, ActionType.ATTACK)
					if body.has_method("apply_slow"):
						body.apply_slow(2.5, 0.15)
	if hit_enemy:
		var attacker = players_container.get_node_or_null(str(attacker_id))
		if attacker and attacker.has_method("apply_soul_harvest"):
			attacker.apply_soul_harvest()

@rpc("any_peer", "call_remote", "reliable")
func request_scythe_strike(origin_pos: Vector3, forward_dir: Vector3, dmg: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_execute_scythe_strike(origin_pos, forward_dir, sender_id, dmg)

func apply_soul_harvest() -> void:
	reaper_ms_steal_timer = 2.5
	reaper_ms_steal_pct = 0.15

func _perform_spectral_tether(target_range: float = 0.0) -> void:
	var def = abilities.get("RMB")
	var max_rng = target_range if target_range > 0.0 else (def.effect.max_range if (def and def.effect and def.effect.max_range > 0.0) else REAPER_RMB_MAX_RANGE)
	rmb_timer = def.cooldown if def else 7.0
	var facing_dir = -global_transform.basis.z.normalized()
	facing_dir.y = 0.0
	facing_dir = facing_dir.normalized()
	var spawn_pos = global_position + Vector3(0, 0.8, 0) + facing_dir * 1.0
	var shoot_dir = get_ranged_aim_direction(spawn_pos)
	var dmg_mult = REAPER_ULT_DMG_MULT if reaper_ult_buff_timer > 0.0 else 1.0
	var dmg = 25.0 * dmg_mult
	var spd = def.effect.speed if (def and def.effect and def.effect.speed > 0.0) else 52.0
	var p_size = def.effect.projectile_size if (def and def.effect and def.effect.projectile_size > 0.0) else 0.6
	var lifetime = max_rng / spd
	ability_cast.emit("Spectral Tether", "RMB")
	if not is_multiplayer_match() or multiplayer.is_server():
		_spawn_tether_projectile(spawn_pos, shoot_dir, 1, dmg, spd, p_size, lifetime, max_rng)
	else:
		request_tether_fire.rpc_id(1, spawn_pos, shoot_dir, dmg, spd, p_size, lifetime, max_rng)

func _spawn_tether_projectile(spawn_pos: Vector3, shoot_dir: Vector3, sender_id: int, dmg: float, spd: float, p_size: float, lifetime: float, max_rng: float) -> void:
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node and main_node.has_method("spawn_projectile"):
		main_node.spawn_projectile(
			spawn_pos,
			shoot_dir,
			sender_id,
			dmg,
			spd,
			p_size,
			lifetime,
			"reaper_tether",
			1.75,
			0.0,
			false,
			false,
			0,
			ActionType.ABILITY,
			max_rng
		)

@rpc("any_peer", "call_remote", "reliable")
func request_tether_fire(spawn_pos: Vector3, shoot_dir: Vector3, dmg: float, spd: float, p_size: float, lifetime: float, max_rng: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_spawn_tether_projectile(spawn_pos, shoot_dir, sender_id, dmg, spd, p_size, lifetime, max_rng)

func start_reaper_tether_server(target_node: Node) -> void:
	if (is_multiplayer_match() and not multiplayer.is_server()) or not target_node or is_dead:
		return
	reaper_tether_target_id = target_node.name.to_int()
	reaper_tether_timer = 1.75
	reaper_tether_active = true
	if is_multiplayer_match() and multiplayer.is_server():
		sync_reaper_tether_state.rpc(true, reaper_tether_target_id)

func end_reaper_tether_server(completed: bool, target_node: Node = null) -> void:
	if is_multiplayer_match() and not multiplayer.is_server():
		return
	reaper_tether_active = false
	reaper_tether_timer = 0.0
	if is_multiplayer_match() and multiplayer.is_server():
		sync_reaper_tether_state.rpc(false, 0)
	if completed and target_node and is_instance_valid(target_node):
		if target_node.has_method("apply_stun"):
			target_node.apply_stun(1.5)
		if target_node.has_method("take_damage"):
			var dmg_mult = REAPER_ULT_DMG_MULT if reaper_ult_buff_timer > 0.0 else 1.0
			target_node.take_damage(60.0 * dmg_mult, name.to_int(), ActionType.ABILITY)

@rpc("any_peer", "call_local", "reliable")
func sync_reaper_tether_state(active: bool, target_id: int) -> void:
	reaper_tether_active = active
	reaper_tether_target_id = target_id
	if not active:
		reaper_tether_timer = 0.0

func _perform_cull_the_weak() -> void:
	var def = abilities.get("Q")
	q_timer = def.cooldown if def else 7.5
	ability_cast.emit("Cull the Weak", "Q")
	if is_holding_rmb:
		is_holding_rmb = false
		if ind_rmb: ind_rmb.hide()
	if ind_q:
		ind_q.hide()
	
	var delay = def.effect.windup_time if (def and def.effect and def.effect.windup_time > 0.0) else 0.75
	reaper_q_windup_timer = delay
	start_ability_cast("Q", {}, delay)
	
	# Systemic delayed telegraph through multiplayer synchronizer
	start_ability_windup("reaper_cull_the_weak")

func _on_cull_channel_finished() -> void:
	if ind_q:
		ind_q.hide()
	var dmg_mult = REAPER_ULT_DMG_MULT if reaper_ult_buff_timer > 0.0 else 1.0
	var in_dmg = 30.0 * dmg_mult
	var out_dmg = 65.0 * dmg_mult
	if not is_multiplayer_match() or multiplayer.is_server():
		_execute_cull_hit(global_position, 1, in_dmg, out_dmg)
	else:
		request_cull_hit.rpc_id(1, global_position, in_dmg, out_dmg)

func _execute_cull_hit(origin_pos: Vector3, attacker_id: int, in_dmg: float, out_dmg: float) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	for body in players_container.get_children():
		if body is Node3D and body.name != str(attacker_id) and not body.get("is_dead") and is_enemy(body):
			var dist = body.global_position.distance_to(origin_pos)
			if dist <= 5.5:
				if dist >= 3.2: # Sweet spot
					if body.has_method("take_damage"):
						body.take_damage(out_dmg, attacker_id, ActionType.ABILITY)
					if body.has_method("apply_cripple"):
						body.apply_cripple(2.5, 0.35)
				else: # Inner radius
					if body.has_method("take_damage"):
						body.take_damage(in_dmg, attacker_id, ActionType.ABILITY)

@rpc("any_peer", "call_remote", "reliable")
func request_cull_hit(origin_pos: Vector3, in_dmg: float, out_dmg: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_execute_cull_hit(origin_pos, sender_id, in_dmg, out_dmg)

func _perform_nightmare() -> void:
	var def = abilities.get("E")
	e_timer = def.cooldown if def else 12.0
	cleanse_cc()
	is_in_nightmare = true
	reaper_nightmare_timer = NIGHTMARE_DURATION
	apply_ethereal(NIGHTMARE_DURATION)
	ability_cast.emit("Nightmare", "E")
	if is_multiplayer_match() and multiplayer.is_server():
		sync_nightmare_state.rpc(true)
	if not is_multiplayer_match() or multiplayer.is_server():
		_execute_nightmare_aoe(global_position, 1, 35.0)
	else:
		request_nightmare_aoe.rpc_id(1, global_position, 35.0)

func end_reaper_nightmare() -> void:
	is_in_nightmare = false
	reaper_nightmare_timer = 0.0
	if is_multiplayer_match() and multiplayer.is_server():
		sync_nightmare_state.rpc(false)
	if not is_multiplayer_match() or multiplayer.is_server():
		_execute_nightmare_aoe(global_position, 1, 45.0)
	else:
		request_nightmare_aoe.rpc_id(1, global_position, 45.0)

@rpc("any_peer", "call_local", "reliable")
func sync_nightmare_state(in_nightmare: bool) -> void:
	is_in_nightmare = in_nightmare
	if in_nightmare:
		reaper_nightmare_timer = NIGHTMARE_DURATION
	else:
		reaper_nightmare_timer = 0.0
	if nightmare_visual:
		nightmare_visual.visible = in_nightmare

func _execute_nightmare_aoe(origin_pos: Vector3, attacker_id: int, dmg: float) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	var dmg_mult = REAPER_ULT_DMG_MULT if reaper_ult_buff_timer > 0.0 else 1.0
	var final_dmg = dmg * dmg_mult
	for body in players_container.get_children():
		if body is Node3D and body.name != str(attacker_id) and not body.get("is_dead") and is_enemy(body):
			if body.global_position.distance_to(origin_pos) <= NIGHTMARE_RADIUS:
				if body.has_method("take_damage"):
					body.take_damage(final_dmg, attacker_id, ActionType.ABILITY)
				if body.has_method("apply_slow"):
					body.apply_slow(1.8, 0.40)

@rpc("any_peer", "call_remote", "reliable")
func request_nightmare_aoe(origin_pos: Vector3, dmg: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_execute_nightmare_aoe(origin_pos, sender_id, dmg)

func _perform_one_with_death() -> void:
	var def = abilities.get("R")
	r_timer = def.cooldown if def else 25.0
	cleanse_cc()
	reaper_ult_buff_timer = REAPER_ULT_BUFF_DURATION
	ability_cast.emit("One with Death", "R")
	sync_reaper_ult.rpc(REAPER_ULT_BUFF_DURATION)

@rpc("any_peer", "call_local", "reliable")
func sync_reaper_ult(duration: float) -> void:
	reaper_ult_buff_timer = duration
	if ult_visual:
		ult_visual.visible = duration > 0.0

func _update_character_hud() -> void:
	var def_rmb = abilities.get("RMB")
	var def_q = abilities.get("Q")
	var def_e = abilities.get("E")
	var def_r = abilities.get("R")
	var def_shift = abilities.get("SHIFT")

	if slot_ability_one and def_rmb:
		slot_ability_one.update_cooldown(rmb_timer, def_rmb.cooldown, 1, 1, is_silenced() or reaper_q_windup_timer > 0.0)
	if slot_ability_two and def_q:
		slot_ability_two.update_cooldown(q_timer, def_q.cooldown, 1, 1, is_silenced())
	if slot_ability_three and def_e:
		slot_ability_three.update_cooldown(e_timer, def_e.cooldown, 1, 1, is_silenced())
		slot_ability_three.set_active_state(is_in_nightmare)
	if slot_ability_four and def_r:
		slot_ability_four.update_cooldown(r_timer, def_r.cooldown, 1, 1, is_silenced())
		slot_ability_four.set_active_state(reaper_ult_buff_timer > 0.0)
	if slot_dash and def_shift:
		slot_dash.update_cooldown(dash_timer, dash_cooldown, 1, 1, is_rooted() or is_grounded())

func is_in_cast_lockout() -> bool:
	return super.is_in_cast_lockout() or reaper_q_windup_timer > 0.0

func execute_ability_slot(slot_key: String) -> bool:
	if is_dead or is_stunned():
		return false
	match slot_key.to_upper():
		"LMB", "SHOOT":
			if attack_timer <= 0.0 and can_cast_ability_slot("LMB"):
				_perform_scythe_slash()
				return true
		"RMB", "ABILITY_ONE":
			if rmb_timer <= 0.0 and not is_silenced() and reaper_q_windup_timer <= 0.0 and can_cast_ability_slot("RMB"):
				_perform_spectral_tether()
				return true
		"Q", "ABILITY_TWO":
			if q_timer <= 0.0 and not is_silenced() and can_cast_ability_slot("Q"):
				_perform_cull_the_weak()
				return true
		"E", "ABILITY_THREE":
			if e_timer <= 0.0 and not is_silenced() and can_cast_ability_slot("E"):
				_perform_nightmare()
				return true
		"R", "ABILITY_FOUR":
			if r_timer <= 0.0 and not is_silenced() and can_cast_ability_slot("R"):
				_perform_one_with_death()
				return true
		"SHIFT", "DASH":
			if dash_timer <= 0.0 and not is_rooted() and not is_grounded() and can_cast_ability_slot("SHIFT"):
				_execute_reaper_dash()
				return true
	return false
