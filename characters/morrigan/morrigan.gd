class_name Morrigan
extends BasePlayer

# --- Passive: Harbinger of Doom ---
var passive_crows_count: int = 3:
	set(value):
		passive_crows_count = value
		_update_crow_orbit_visuals()
const MAX_PASSIVE_CROWS: int = 3
const CROW_DETECT_RADIUS: float = 7.0
const CROW_DAMAGE: float = 18.0
const CROW_SLOW_PCT: float = 0.35
const CROW_SLOW_DUR: float = 1.8
var crow_orbit_angle: float = 0.0
var crow_seek_cooldown: float = 0.0
var crow_regen_timer: float = 0.0

# --- LMB: Black Plumage Hold-to-Charge ---
var is_charging_lmb: bool = false
var lmb_charge_timer: float = 0.0
var lmb_burst_queue: int = 0
var lmb_burst_timer: float = 0.0
var lmb_burst_dir: Vector3 = Vector3.FORWARD
const LMB_FIRST_CHARGE: float = 0.35
const LMB_SUBSEQUENT_CHARGE: float = 0.18
const LMB_MAX_FEATHERS: int = 5

# --- Q: Inescapable Ends Tether State ---
var tether_recast_window: float = 0.0
var anchor_one_data: Dictionary = {}
var anchor_two_data: Dictionary = {}
var tether_pull_timer: float = 0.0
const TETHER_DURATION: float = 3.0

# --- Dash (SHIFT): Crowstorm Visual State ---
var is_crowstorm_active: bool = false:
	set(value):
		is_crowstorm_active = value
		if crowstorm_mesh: crowstorm_mesh.visible = value
		if char_mesh: char_mesh.visible = not value
var crowstorm_timer: float = 0.0
const CROWSTORM_DURATION: float = 2.0

@onready var crowstorm_mesh: Node3D = get_node_or_null("CrowstormMesh")
@onready var char_mesh: Node3D = get_node_or_null("MeshInstance3D")
@onready var crow_container: Node3D = get_node_or_null("CrowContainer")

func _setup_character_kit() -> void:
	var data = MorriganData.create()
	load_character_data(data)

	var sync = get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	if sync and sync.replication_config:
		_add_sync_property(sync.replication_config, NodePath(".:passive_crows_count"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		_add_sync_property(sync.replication_config, NodePath(".:is_crowstorm_active"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	
	_update_crow_orbit_visuals()

func character_handles_slot(slot_key: String) -> bool:
	if slot_key == "LMB":
		return true
	if slot_key == "Q" and tether_recast_window > 0.0:
		return true
	return false

func _handle_character_input(delta: float) -> void:
	if is_dead or is_channeling:
		is_charging_lmb = false
		lmb_charge_timer = 0.0
		var lmb_ab = abilities.get("LMB")
		if lmb_ab:
			lmb_ab.stop_charging()
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
	var facing_dir = -global_transform.basis.z.normalized()
	facing_dir.y = 0.0
	facing_dir = facing_dir.normalized()
	var origin = global_position + Vector3(0, 0.8, 0) + facing_dir * 1.0
	var shoot_dir = get_ranged_aim_direction(origin)

	_fire_single_feather(origin, shoot_dir)
	if feather_count > 1:
		lmb_burst_queue = feather_count - 1
		lmb_burst_dir = shoot_dir
		lmb_burst_timer = 0.06

func _fire_single_feather(origin: Vector3, shoot_dir: Vector3) -> void:
	var tree = get_tree()
	var main_node = tree.root.get_node_or_null("Main") if (tree and tree.root) else null
	if not main_node:
		return
	if is_server_authoritative():
		main_node.spawn_projectile(
			origin,
			shoot_dir,
			peer_id,
			11.0,
			70.0,
			0.4,
			35.0 / 70.0,
			"morrigan_feather",
			0.0,
			0.0,
			false,
			false,
			team_id,
			0,
			35.0
		)
	else:
		request_cast_ability.rpc_id(1, "LMB", origin, shoot_dir, global_position + shoot_dir * 35.0, 0.0)

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
		if p1.has_method("apply_velocity_impulse"):
			var dir1 = (mid_point - p1.global_position).normalized()
			p1.apply_velocity_impulse(dir1 * 16.0, true)
		if p2.has_method("apply_velocity_impulse"):
			var dir2 = (mid_point - p2.global_position).normalized()
			p2.apply_velocity_impulse(dir2 * 16.0, true)

@rpc("any_peer", "call_local", "reliable")
func sync_tether_recast(has_recast: bool, _hit_p: Vector3) -> void:
	tether_recast_window = 4.0 if has_recast else 0.0

func _process_character_kit(delta: float) -> void:
	# Orbit visual update
	crow_orbit_angle += 3.2 * delta
	if crow_orbit_angle > TAU:
		crow_orbit_angle -= TAU

	# Crow regeneration (1 every 4s)
	if passive_crows_count < MAX_PASSIVE_CROWS:
		crow_regen_timer += delta
		if crow_regen_timer >= 4.0:
			crow_regen_timer = 0.0
			passive_crows_count = min(MAX_PASSIVE_CROWS, passive_crows_count + 1)

	# Passive crow seeking (host authoritative)
	if is_server_authoritative() and not is_dead and passive_crows_count > 0:
		if crow_seek_cooldown > 0.0:
			crow_seek_cooldown -= delta
		else:
			_seek_and_fire_passive_crow()

	# Tether recast expiration
	if tether_recast_window > 0.0:
		tether_recast_window -= delta

	# Process burst feather queue
	if lmb_burst_queue > 0:
		lmb_burst_timer -= delta
		if lmb_burst_timer <= 0.0:
			lmb_burst_timer = 0.06
			lmb_burst_queue -= 1
			var facing_dir = -global_transform.basis.z.normalized()
			var origin = global_position + Vector3(0, 0.8, 0) + facing_dir * 1.0
			_fire_single_feather(origin, lmb_burst_dir)

	# Process Crowstorm flight
	if is_crowstorm_active:
		crowstorm_timer -= delta
		if is_crowstorm_active and not is_on_floor():
			velocity.y = max(velocity.y, 0.0) # Hover/flight
		if crowstorm_timer <= 0.0:
			is_crowstorm_active = false

func custom_execute_ability_server(slot_key: String, _origin: Vector3, _dir: Vector3, _target_pos: Vector3, _charge: float) -> bool:
	if slot_key == "SHIFT":
		is_crowstorm_active = true
		crowstorm_timer = CROWSTORM_DURATION
	return false

func custom_execute_ability_client(slot_key: String, _origin: Vector3, _dir: Vector3, _target_pos: Vector3, _charge: float) -> bool:
	if slot_key == "SHIFT":
		is_crowstorm_active = true
		crowstorm_timer = CROWSTORM_DURATION
	return false

func modify_incoming_damage(amount: float, _attacker_id: int, _action_type: int) -> float:
	if is_crowstorm_active:
		return amount * 0.50 # 50% damage reduction during Crowstorm flight
	return amount

func _update_crow_orbit_visuals() -> void:
	if not crow_container:
		return
	for i in range(MAX_PASSIVE_CROWS):
		var crow_node = crow_container.get_node_or_null("Crow%d" % i)
		if crow_node:
			crow_node.visible = (i < passive_crows_count)

func _seek_and_fire_passive_crow() -> void:
	var players = get_tree().get_nodes_in_group("players")
	for p in players:
		if not is_instance_valid(p) or p == self:
			continue
		if "is_dead" in p and p.is_dead:
			continue
		if "team_id" in p and p.team_id == team_id and team_id != 0:
			continue
		var diff = global_position - p.global_position
		diff.y = 0.0
		var dist = diff.length()
		if dist <= CROW_DETECT_RADIUS:
			passive_crows_count -= 1
			crow_seek_cooldown = 1.0
			if p.has_method("take_damage"):
				p.take_damage(CROW_DAMAGE, peer_id, 1)
			if p.has_method("apply_slow"):
				p.apply_slow(CROW_SLOW_DUR, CROW_SLOW_PCT)
			break

func get_speed_multiplier() -> float:
	var mult = 1.0
	if is_crowstorm_active:
		mult += 0.60
	return mult

func get_status_text() -> String:
	if is_channeling:
		return "✦ CHANNELING DELUGE (%.1fs) ✦" % max(0.0, channel_timer)
	if is_crowstorm_active:
		return "✦ CROWSTORM (FLIGHT) ✦"
	elif tether_recast_window > 0.0:
		return "✦ TETHER READY (PRESS Q TO RECAST) ✦"
	elif is_charging_lmb:
		return "✦ BLACK PLUMAGE: %d FEATHERS ✦" % _calculate_lmb_feather_count()
	elif passive_crows_count > 0:
		return "✦ DOOM CROWS: %d/%d ✦" % [passive_crows_count, MAX_PASSIVE_CROWS]
	return ""
