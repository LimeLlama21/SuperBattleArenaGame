class_name Reaper
extends BasePlayer

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
var reaper_tether_target_id: int = 0
var reaper_tether_timer: float = 0.0
var reaper_tether_active: bool = false

@onready var nightmare_visual: Node3D = get_node_or_null("NightmareVisual")
@onready var ult_visual: Node3D = get_node_or_null("UltVisual")

func _setup_character_kit() -> void:
	var data = ReaperData.create()
	load_character_data(data)

	var sync = get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	if sync and sync.replication_config:
		_add_sync_property(sync.replication_config, NodePath(".:is_in_nightmare"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		_add_sync_property(sync.replication_config, NodePath(".:reaper_ult_buff_timer"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		_add_sync_property(sync.replication_config, NodePath(".:reaper_tether_active"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		_add_sync_property(sync.replication_config, NodePath(".:reaper_tether_target_id"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)

func _process_character_kit(delta: float) -> void:
	if reaper_ms_steal_timer > 0.0:
		reaper_ms_steal_timer = max(0.0, reaper_ms_steal_timer - delta)
		if reaper_ms_steal_timer <= 0.0:
			reaper_ms_steal_pct = 0.0

	if reaper_ult_buff_timer > 0.0:
		reaper_ult_buff_timer = max(0.0, reaper_ult_buff_timer - delta)
		if reaper_ult_buff_timer <= 0.0 and ult_visual:
			ult_visual.visible = false

	if is_in_nightmare:
		reaper_nightmare_timer -= delta
		if reaper_nightmare_timer <= 0.0:
			end_nightmare()

	if reaper_tether_active and is_server_authoritative():
		_process_server_tether(delta)

func _process_server_tether(delta: float) -> void:
	var target = get_tree().root.get_node_or_null("Main/Players/" + str(reaper_tether_target_id))
	if not is_instance_valid(target) or ("is_dead" in target and target.is_dead):
		end_reaper_tether_server(false)
		return
	
	var dist = global_position.distance_to(target.global_position)
	if dist > 22.0: # Tether breaks if target escapes
		end_reaper_tether_server(false)
		return
	
	reaper_tether_timer -= delta
	if reaper_tether_timer <= 0.0:
		# Full tether complete - root target and burst damage
		end_reaper_tether_server(true, target)

func start_reaper_tether_server(target_node: Node) -> void:
	if (is_multiplayer_match() and not multiplayer.is_server()) or not target_node or is_dead:
		return
	reaper_tether_target_id = target_node.name.to_int()
	reaper_tether_timer = 1.75
	reaper_tether_active = true
	if target_node.has_method("apply_grounded"):
		target_node.apply_grounded(1.75)
	if target_node.has_method("apply_slow"):
		target_node.apply_slow(1.75, 0.30)
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
		if target_node.has_method("apply_root"):
			target_node.apply_root(1.5)
		if target_node.has_method("take_damage"):
			var dmg_mult = REAPER_ULT_DMG_MULT if reaper_ult_buff_timer > 0.0 else 1.0
			target_node.take_damage(60.0 * dmg_mult, peer_id, 1)

@rpc("any_peer", "call_local", "reliable")
func sync_reaper_tether_state(is_active: bool, target_id: int) -> void:
	if not _is_sender_host():
		return
	reaper_tether_active = is_active
	reaper_tether_target_id = target_id
	if not is_active:
		reaper_tether_timer = 0.0

func on_melee_strike_hit(target: Node, hit_data: Dictionary) -> void:
	var slot = hit_data.get("slot_key", "")
	if slot == "LMB":
		reaper_ms_steal_timer = 2.5
		reaper_ms_steal_pct = 0.15
		if is_instance_valid(target) and target.has_method("apply_slow"):
			target.apply_slow(2.5, 0.15)

func custom_execute_ability_server(slot_key: String, origin: Vector3, _dir: Vector3, _target_pos: Vector3, _charge: float) -> bool:
	if slot_key == "Q":
		_execute_cull_hit(origin, peer_id, 30.0, 65.0)
		return true
	elif slot_key == "E":
		_execute_nightmare()
		return true
	elif slot_key == "SHIFT":
		apply_ethereal(0.45)
	return false

func custom_execute_ability_client(slot_key: String, _origin: Vector3, _dir: Vector3, _target_pos: Vector3, _charge: float) -> bool:
	if slot_key == "E":
		_execute_nightmare()
		return true
	elif slot_key == "SHIFT":
		apply_ethereal(0.45)
	return false

func _execute_cull_hit(origin_pos: Vector3, attacker_id: int, in_dmg: float, out_dmg: float) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	for body in players_container.get_children():
		if body is Node3D and body.name != str(attacker_id) and not body.get("is_dead") and is_enemy(body):
			var diff = body.global_position - origin_pos
			diff.y = 0.0
			var dist = diff.length()
			if dist <= 5.5:
				if dist >= 3.2: # Sweet spot
					if body.has_method("take_damage"):
						body.take_damage(out_dmg, attacker_id, 1)
					if body.has_method("apply_cripple"):
						body.apply_cripple(2.5, 0.35)
				else: # Inner radius
					if body.has_method("take_damage"):
						body.take_damage(in_dmg, attacker_id, 1)

func _execute_nightmare() -> void:
	is_in_nightmare = true
	reaper_nightmare_timer = NIGHTMARE_DURATION
	apply_ethereal(NIGHTMARE_DURATION)
	if nightmare_visual:
		nightmare_visual.visible = true
	
	if is_server_authoritative():
		var players_container = get_tree().root.get_node_or_null("Main/Players")
		if players_container:
			for body in players_container.get_children():
				if body is Node3D and body.name != str(peer_id) and not body.get("is_dead") and is_enemy(body):
					var diff = body.global_position - global_position
					diff.y = 0.0
					if diff.length() <= NIGHTMARE_RADIUS:
						if body.has_method("take_damage"):
							body.take_damage(35.0, peer_id, 1)
						if body.has_method("apply_slow"):
							body.apply_slow(NIGHTMARE_DURATION, 0.40)

func on_buff_activated(buff_name: String, duration: float) -> void:
	if buff_name == "OneWithDeath":
		reaper_ult_buff_timer = duration
		if ult_visual:
			ult_visual.visible = true
	elif buff_name in ["Nightmare", "DeathShroud"]:
		_execute_nightmare()

func end_nightmare() -> void:
	is_in_nightmare = false
	if nightmare_visual:
		nightmare_visual.visible = false

func get_speed_multiplier() -> float:
	var mult = 1.0
	if reaper_ult_buff_timer > 0.0:
		mult += REAPER_ULT_MS_MULT
	if reaper_ms_steal_timer > 0.0:
		mult += reaper_ms_steal_pct
	return mult

func get_damage_multiplier() -> float:
	var mult = 1.0
	if reaper_ult_buff_timer > 0.0:
		mult *= REAPER_ULT_DMG_MULT
	return mult

func get_status_text() -> String:
	if reaper_ult_buff_timer > 0.0:
		return "✦ ONE WITH DEATH (COMBAT TRANCE) ✦"
	elif is_in_nightmare:
		return "✦ NIGHTMARE FORM (ETHEREAL) ✦"
	elif reaper_ms_steal_timer > 0.0:
		return "✦ SOUL SIPHON (+%.0f%% MS) ✦" % (reaper_ms_steal_pct * 100.0)
	elif reaper_tether_active:
		return "✦ SPECTRAL TETHER ACTIVE (%.1fs) ✦" % max(0.0, reaper_tether_timer)
	return ""
