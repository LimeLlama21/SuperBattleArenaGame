class_name Asparsas
extends BasePlayer

# Deflecting Guard (Block Stance)
var is_blocking: bool = false:
	set(value):
		is_blocking = value
		if block_visual:
			block_visual.visible = value
var block_timer: float = 0.0
const BLOCK_DURATION: float = 3.0
const BLOCK_DR_PERCENT: float = 0.75

# Rupture Marks Passive Tuning (11-15% missing HP heal based on marks)
const DIVE_MARK_HEAL_MIN_PERCENT: float = 0.11
const DIVE_MARK_HEAL_MAX_PERCENT: float = 0.15

# Tectonic Uprising (Ultimate Buff)
var dive_ult_buff_timer: float = 0.0
const DIVE_ULT_BUFF_DURATION: float = 6.0
const DIVE_ULT_SPEED_MULT: float = 0.35
const DIVE_ULT_ATTACK_SPEED_MULT: float = 0.40

# Dash, Wall Bounce & Aerial Crash Down
var is_wall_launched: bool = false
var dash_wall_bounce_timer: float = 0.0
var dive_dash_dir: Vector3 = Vector3.FORWARD
var is_crashing_down: bool = false:
	set(value):
		is_crashing_down = value
		if crash_visual:
			crash_visual.visible = value
var crash_target_pos: Vector3 = Vector3.ZERO
const CRASH_SPEED: float = 52.0
const CRASH_DAMAGE: float = 36.0
const CRASH_RADIUS: float = 6.0

@onready var block_visual: Node3D = get_node_or_null("BlockVisual")
@onready var crash_visual: Node3D = get_node_or_null("CrashVisual")

func _setup_character_kit() -> void:
	var data = AsparsasData.create()
	load_character_data(data)
	if character_name == "Asparsas" or character_name.is_empty():
		character_name = "Urvashi"
	if display_name == "Asparsas" or display_name.is_empty():
		display_name = "Urvashi"

	var sync = get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	if sync and sync.replication_config:
		_add_sync_property(sync.replication_config, NodePath(".:is_blocking"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		_add_sync_property(sync.replication_config, NodePath(".:dive_ult_buff_timer"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		_add_sync_property(sync.replication_config, NodePath(".:is_crashing_down"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)

func _process_character_kit(delta: float) -> void:
	if is_blocking:
		block_timer -= delta
		if block_timer <= 0.0:
			end_blocking()

	if dive_ult_buff_timer > 0.0:
		dive_ult_buff_timer = max(0.0, dive_ult_buff_timer - delta)

	# Check wall bounce during dash
	if dash_wall_bounce_timer > 0.0:
		dash_wall_bounce_timer -= delta
		if is_on_wall():
			_trigger_wall_bounce()

	# Process Aerial Crash Down
	if is_crashing_down:
		velocity.y = -CRASH_SPEED
		velocity.x = 0.0
		velocity.z = 0.0
		if is_on_floor():
			_execute_crash_impact()

	if is_wall_launched and is_on_floor() and not is_crashing_down:
		is_wall_launched = false

func start_block_stance(duration: float = BLOCK_DURATION) -> void:
	is_blocking = true
	block_timer = duration
	if block_visual:
		block_visual.visible = true

func end_blocking() -> void:
	is_blocking = false
	if block_visual:
		block_visual.visible = false

func modify_incoming_damage(amount: float, attacker_id: int, _action_type: int) -> float:
	if is_blocking:
		var attacker = get_tree().root.get_node_or_null("Main/Players/" + str(attacker_id))
		if attacker:
			var forward_dir = -global_transform.basis.z.normalized()
			var to_attacker = (attacker.global_position - global_position).normalized()
			forward_dir.y = 0.0
			to_attacker.y = 0.0
			if forward_dir.dot(to_attacker) > 0.2:
				return amount * (1.0 - BLOCK_DR_PERCENT)
		else:
			return amount * (1.0 - BLOCK_DR_PERCENT)
	return amount

func proc_passive_heal(marks: int) -> float:
	var heal_rider = (load("res://ability/riders/heal_rider.gd") as GDScript).new()
	heal_rider.scale_with_marks = true
	heal_rider.min_missing_hp_percent = DIVE_MARK_HEAL_MIN_PERCENT
	heal_rider.max_missing_hp_percent = DIVE_MARK_HEAL_MAX_PERCENT
	heal_rider.apply_to_self = true
	var res = heal_rider._execute_heal(self, marks)
	heal_rider.free()
	return res

func on_melee_strike_hit(target: Node, hit_data: Dictionary) -> void:
	var ab_id = hit_data.get("ability_id", "")
	var slot = hit_data.get("slot_key", "")
	if ab_id == "dive_heavy_cleave" or slot == "RMB":
		if is_instance_valid(target) and target.has_method("detonate_dive_marks"):
			var marks_detonated = target.detonate_dive_marks(self)
			hit_data["marks"] = marks_detonated
			hit_data["marks_healed"] = true
	else:
		if is_instance_valid(target) and target.has_method("apply_rupture_mark"):
			target.apply_rupture_mark(peer_id)

func _trigger_wall_bounce() -> void:
	dash_wall_bounce_timer = 0.0
	is_wall_launched = true
	velocity.x = 0.0
	velocity.z = 0.0
	velocity.y = 16.0

func custom_execute_ability_server(slot_key: String, _origin: Vector3, dir: Vector3, target_pos: Vector3, _charge: float) -> bool:
	if slot_key == "SHIFT":
		if is_wall_launched:
			execute_crash_down(target_pos)
			return true
		else:
			dash_wall_bounce_timer = 0.5
			dive_dash_dir = dir
	elif slot_key == "R":
		_trigger_tectonic_uprising()
	return false

func custom_execute_ability_client(slot_key: String, _origin: Vector3, dir: Vector3, target_pos: Vector3, _charge: float) -> bool:
	if slot_key == "SHIFT":
		if is_wall_launched:
			execute_crash_down(target_pos)
			return true
		else:
			dash_wall_bounce_timer = 0.5
			dive_dash_dir = dir
	return false

func execute_crash_down(target_pos: Vector3) -> void:
	is_crashing_down = true
	crash_target_pos = target_pos
	global_position.x = target_pos.x
	global_position.z = target_pos.z
	velocity.y = -CRASH_SPEED

func _execute_crash_impact() -> void:
	is_crashing_down = false
	is_wall_launched = false
	velocity = Vector3.ZERO
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if players_container and is_server_authoritative():
		for player in players_container.get_children():
			if player is Node3D and player.name != str(peer_id) and not player.get("is_dead") and is_enemy(player):
				var diff = player.global_position - global_position
				diff.y = 0.0
				if diff.length() <= CRASH_RADIUS:
					if player.has_method("take_damage"):
						player.take_damage(CRASH_DAMAGE, peer_id, 1)
					if player.has_method("apply_knockback"):
						var kb_dir = (player.global_position - global_position).normalized()
						kb_dir.y = 0.0
						player.apply_knockback(Vector3.UP * 5.0 + kb_dir * 8.0, true)

func _trigger_tectonic_uprising() -> void:
	dive_ult_buff_timer = DIVE_ULT_BUFF_DURATION
	cleanse_cc()
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if players_container and is_server_authoritative():
		for p in players_container.get_children():
			if p is Node3D and p.name != str(peer_id) and not p.get("is_dead") and is_enemy(p):
				var diff = p.global_position - global_position
				diff.y = 0.0
				if diff.length() <= 7.0:
					if p.has_method("apply_knockback"):
						p.apply_knockback(Vector3.UP * 12.0, true)

func on_buff_activated(buff_name: String, duration: float) -> void:
	if buff_name == "TectonicUprising":
		dive_ult_buff_timer = duration
		cleanse_cc()

func get_speed_multiplier() -> float:
	var mult = 1.0
	if dive_ult_buff_timer > 0.0:
		mult += DIVE_ULT_SPEED_MULT
	return mult

func get_attack_speed_bonus() -> float:
	var bonus = 0.0
	if dive_ult_buff_timer > 0.0:
		bonus += DIVE_ULT_ATTACK_SPEED_MULT
	return bonus

func get_status_text() -> String:
	if dive_ult_buff_timer > 0.0:
		return "✦ TECTONIC UPRISING (HASTE) ✦"
	elif is_blocking:
		return "✦ DEFLECTING GUARD (75% DR) ✦"
	elif is_crashing_down:
		return "✦ CRASH DOWN ✦"
	elif is_wall_launched:
		return "✦ AIRBORNE (PRESS SHIFT TO CRASH) ✦"
	elif dive_marks_count > 0:
		return "✦ RUPTURE MARKS: %d/%d ✦" % [dive_marks_count, DIVE_MARK_MAX]
	return ""
