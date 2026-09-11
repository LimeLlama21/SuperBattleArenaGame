class_name Poke
extends BasePlayer

# Passive & Buff State (Attack Speed Steroid on Takedown + Dash Reset)
var poke_as_buff_timer: float = 0.0
var poke_as_buff_percent: float = 0.60
var poke_as_buff_duration: float = 4.0
var current_camera_offset: Vector3 = CAMERA_OFFSET

# Sniper Stance State (RMB)
var is_in_sniper_stance: bool = false
var is_charging_sniper: bool:
	get:
		var rmb_ab = abilities.get("RMB")
		return rmb_ab != null and rmb_ab.is_charging
	set(_v):
		pass

var sniper_charge_timer: float:
	get:
		var rmb_ab = abilities.get("RMB")
		return rmb_ab.current_charge_time if rmb_ab != null else 0.0
	set(_v):
		pass
const SNIPER_MAX_CHARGE_TIME: float = 2.0
const SNIPER_CAMERA_OFFSET: Vector3 = Vector3(0, 28.5, 7.64)
const SNIPER_CONE_RADIUS: float = 45.0
const SNIPER_CONE_HALF_ANGLE_DEG: float = 16.0

# Q Ability: Overcharged Rounds State
var is_overcharge_active: bool = false
const OVERCHARGE_BONUS_DAMAGE: float = 30.0

func _setup_character_kit() -> void:
	var data = PokeData.create()
	load_character_data(data)

	poke_as_buff_duration = data.passive_data.get("takedown_as_duration", 4.0)
	poke_as_buff_percent = data.passive_data.get("takedown_as_percent", 0.60)

	var sync = get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	if sync and sync.replication_config:
		_add_sync_property(sync.replication_config, NodePath(".:is_in_sniper_stance"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		_add_sync_property(sync.replication_config, NodePath(".:is_overcharge_active"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)

func character_handles_slot(slot_key: String) -> bool:
	return slot_key == "RMB"

func _handle_character_input(_delta: float) -> void:
	if is_dead or is_channeling or is_stunned() or is_silenced():
		if is_in_sniper_stance:
			_exit_sniper_stance()
		return

	# Secondary Fire (RMB): Hold to Enter/Maintain Sniper Stance
	if Input.is_action_pressed("ability_one"):
		if not is_in_sniper_stance:
			var rmb_ab = abilities.get("RMB")
			if not rmb_ab or rmb_ab.can_cast(self):
				_enter_sniper_stance()
	elif is_in_sniper_stance:
		_exit_sniper_stance()

func _enter_sniper_stance() -> void:
	var rmb_ab = abilities.get("RMB")
	if rmb_ab and not rmb_ab.can_cast(self):
		return
	is_in_sniper_stance = true
	remap_slot("LMB", "RMB")

func _exit_sniper_stance() -> void:
	if not is_in_sniper_stance:
		return
	is_in_sniper_stance = false
	unremap_slot("LMB")
	var rmb_ab = abilities.get("RMB")
	if rmb_ab:
		rmb_ab.stop_charging()
		var cd = rmb_ab.cooldown
		if has_method("get_cooldown_multiplier"):
			cd *= get_cooldown_multiplier()
		rmb_ab.current_cooldown = cd
	if is_overcharge_active:
		is_overcharge_active = false

func should_ability_start_cooldown_on_cast(slot_key_param: String, ability_id_param: String) -> bool:
	if slot_key_param == "RMB" or ability_id_param == "poke_sniper_stance" or ability_id_param == "poke_sniper":
		return false
	return true

func _spawn_sniper_projectile(origin: Vector3, shoot_dir: Vector3, dmg: float) -> void:
	var tree = get_tree()
	var main_node = tree.root.get_node_or_null("Main") if (tree and tree.root) else null
	if not main_node:
		return
	var eff = "poke_sniper_empowered" if is_overcharge_active else "poke_sniper_laser"
	main_node.spawn_projectile(
		origin,
		shoot_dir,
		peer_id,
		dmg,
		120.0,
		0.45,
		70.0 / 120.0,
		eff,
		0.0,
		0.0,
		true,
		false,
		team_id,
		1,
		70.0
	)

func on_empowered_sniper_hit(_target: Node) -> void:
	# Persists on hit
	pass

func on_empowered_sniper_miss(_reason: String = "") -> void:
	# Ends on miss
	is_overcharge_active = false

func custom_execute_ability_server(slot_key: String, origin: Vector3, dir: Vector3, _target_pos: Vector3, charge_ratio: float) -> bool:
	if slot_key == "RMB":
		var base_dmg = lerp(35.0, 70.0, charge_ratio)
		if is_overcharge_active:
			base_dmg += OVERCHARGE_BONUS_DAMAGE
		_spawn_sniper_projectile(origin, dir, base_dmg)
		return true
	elif slot_key == "Q":
		if is_in_sniper_stance:
			is_overcharge_active = true
		return true
	return false

func get_custom_ability_mana_cost(slot_key_param: String, ability_id_param: String) -> float:
	if slot_key_param == "RMB" or ability_id_param == "poke_sniper_stance" or ability_id_param == "poke_sniper":
		return 30.0 if is_overcharge_active else 20.0
	return -1.0

func _process_character_kit(delta: float) -> void:
	if is_dead or is_channeling or is_stunned() or is_silenced():
		if is_in_sniper_stance:
			_exit_sniper_stance()

	if poke_as_buff_timer > 0.0:
		poke_as_buff_timer = max(0.0, poke_as_buff_timer - delta)

	# Dynamic Sniper Stance vision geometry
	if is_in_sniper_stance:
		forward_vision_range = SNIPER_CONE_RADIUS
		forward_vision_angle = SNIPER_CONE_HALF_ANGLE_DEG
	else:
		forward_vision_range = PlayerVision.CONE_RADIUS_M
		forward_vision_angle = PlayerVision.CONE_HALF_ANGLE_DEG

func _process_camera(delta: float) -> void:
	if not camera:
		return
	var target_offset = SNIPER_CAMERA_OFFSET if is_in_sniper_stance else CAMERA_OFFSET
	current_camera_offset = current_camera_offset.lerp(target_offset, 6.0 * delta)
	camera.global_position = global_position + current_camera_offset
	camera.look_at(global_position, Vector3.UP)

func get_speed_multiplier() -> float:
	var mult = 1.0
	if is_in_sniper_stance:
		mult *= 0.70
	return mult

func get_attack_speed_bonus() -> float:
	var bonus = 0.0
	if poke_as_buff_timer > 0.0:
		bonus += poke_as_buff_percent
	return bonus

func _on_character_takedown(_victim: Node) -> void:
	# Attack speed steroid and dash cooldown reset on takedown
	poke_as_buff_timer = poke_as_buff_duration
	var dash_ab = abilities.get("SHIFT")
	if dash_ab and "current_cooldown" in dash_ab:
		dash_ab.current_cooldown = 0.0

func get_status_text() -> String:
	if is_channeling:
		return "✦ CHARGING HYPERBEAM (%.1fs) ✦" % max(0.0, channel_timer)
	if is_overcharge_active:
		return "✦ OVERCHARGED SNIPER (+%.0f DMG) ✦" % OVERCHARGE_BONUS_DAMAGE
	if is_in_sniper_stance:
		var rmb_ab = abilities.get("RMB")
		var charge_pct = (rmb_ab.get_charge_ratio() * 100.0) if rmb_ab else 0.0
		return "✦ SNIPER STANCE (%.0f%%) ✦" % charge_pct
	if poke_as_buff_timer > 0.0:
		return "✦ HYPERDRIVE (+%.0f%% AS) ✦" % (poke_as_buff_percent * 100.0)
	return ""
