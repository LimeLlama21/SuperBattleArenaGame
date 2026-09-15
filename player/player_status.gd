class_name PlayerStatus
extends PlayerAuthority

# --- Universal Status Effects & CC ---
var stun_timer: float = 0.0
var bound_timer: float = 0.0
var bound_caster_node: Node = null
var bound_relative_offset: Vector3 = Vector3.ZERO
var slow_timer: float = 0.0
var slow_initial_duration: float = 0.0
var slow_initial_percent: float = 0.0
var slow_percent: float = 0.0
var silence_timer: float = 0.0
var root_timer: float = 0.0
var grounded_timer: float = 0.0
var cripple_timer: float = 0.0
var cripple_intensity: float = 0.35
var ethereal_timer: float = 0.0
var speed_boost_timer: float = 0.0
var speed_boost_percent: float = 0.0
var is_cc_immune: bool = false

# --- Extended Statuses: Invisibility, Taunt, Transformation, Invulnerability ---
var invisibility_timer: float = 0.0
var taunt_timer: float = 0.0
var taunter_node: Node = null
var taunt_damage_reduction: float = 0.35

var is_transformed: bool = false
var transformed_prop_type: String = ""
var transformation_properties: Dictionary = {}

var invulnerable_timer: float = 0.0
var displacement_immune_timer: float = 0.0

# --- Rupture Marks (Dive / Asparsas Passive) ---
var dive_marks_count: int = 0
var dive_mark_timer: float = 0.0
var dive_mark_attacker_id: int = 0
const DIVE_MARK_DURATION: float = 3.5
const DIVE_MARK_MAX: int = 5
const DIVE_MARK_BURST_PER_STACK: float = 18.0

# --- Universal Levitation / Float State ---
var is_floating: bool = false
var float_timer: float = 0.0
var current_gravity_mult: float = 1.0
const FLOAT_TOTAL_DURATION: float = 2.2
const FLOAT_SLOWDOWN_TIME: float = 0.7
const FLOAT_HOVER_TIME: float = 1.4

# --- Universal Channeling & Input Buffering ---
var is_channeling: bool = false
var channel_timer: float = 0.0
var channel_complete_callback: Callable = Callable()
var ability_buffer: AbilityBuffer = AbilityBuffer.new()

# --- Status Query Helpers ---
func is_stunned() -> bool:
	return stun_timer > 0.0

func is_bound() -> bool:
	return bound_timer > 0.0

func get_bound_caster() -> Node:
	return bound_caster_node if is_instance_valid(bound_caster_node) else null

func get_hitbox_radius() -> float:
	var ch = get_node_or_null("CombatHitbox")
	if ch:
		var cs = ch.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if cs and cs.shape and "radius" in cs.shape:
			return cs.shape.radius
	var col = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col and col.shape:
		if col.shape is CapsuleShape3D or col.shape is CylinderShape3D:
			return col.shape.radius
		elif col.shape is BoxShape3D:
			return max(col.shape.size.x, col.shape.size.z) * 0.5
	return 0.4

func is_slowed() -> bool:
	return slow_timer > 0.0

func is_silenced() -> bool:
	return silence_timer > 0.0

func is_rooted() -> bool:
	return root_timer > 0.0

func is_grounded() -> bool:
	return grounded_timer > 0.0

func is_crippled() -> bool:
	return cripple_timer > 0.0

func is_ethereal_active() -> bool:
	return ethereal_timer > 0.0

func is_invisible() -> bool:
	return invisibility_timer > 0.0

func is_taunted() -> bool:
	return taunt_timer > 0.0

func get_taunt_target() -> Node:
	return taunter_node if is_instance_valid(taunter_node) else null

func get_taunt_damage_multiplier() -> float:
	return (1.0 - taunt_damage_reduction) if is_taunted() else 1.0

func is_unit_transformed() -> bool:
	return is_transformed

func is_invulnerable() -> bool:
	return invulnerable_timer > 0.0

func is_displacement_immune() -> bool:
	return displacement_immune_timer > 0.0 or is_invulnerable()

func get_slow_multiplier() -> float:
	if slow_timer > 0.0:
		var mult = 1.0 - slow_percent
		if is_crippled():
			mult *= (1.0 - cripple_intensity)
		return clamp(mult, 0.05, 1.0)
	elif is_crippled():
		return clamp(1.0 - cripple_intensity, 0.05, 1.0)
	return 1.0

func cancel_active_windup() -> void:
	pass

# --- Channeling Operations ---
func start_channel(duration: float, on_complete: Callable) -> void:
	is_channeling = true
	channel_timer = duration
	channel_complete_callback = on_complete

func cancel_channel() -> void:
	is_channeling = false
	channel_timer = 0.0
	channel_complete_callback = Callable()
	_on_channel_cancelled()
	clear_buffered_ability()

func _on_channel_cancelled() -> void:
	pass

func _on_channel_completed() -> void:
	_try_resolve_buffered_ability()

func _try_resolve_buffered_ability() -> void:
	pass

func clear_buffered_ability() -> void:
	if ability_buffer:
		ability_buffer.clear()

func has_buffered_ability() -> bool:
	return ability_buffer != null and ability_buffer.has_buffered_ability()

# --- Status Application & Authority / Replication Sync ---
func _is_sender_host() -> bool:
	if not is_multiplayer_match():
		return true
	if multiplayer.is_server():
		return true
	return multiplayer.get_remote_sender_id() == 1

func apply_stun(duration: float) -> void:
	if is_cc_immune or is_ethereal_active():
		return
	if is_multiplayer_match():
		if not is_server_authoritative():
			return
		sync_apply_stun.rpc(duration)
	else:
		sync_apply_stun(duration)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_stun(duration: float) -> void:
	if not _is_sender_host():
		return
	stun_timer = max(stun_timer, duration)
	cancel_channel()
	clear_buffered_ability()
	if has_method("cancel_active_windup"):
		cancel_active_windup()

func apply_bound(caster: Node, duration: float, custom_relocate_pos: Variant = null, buffer_offset: float = 0.2) -> void:
	if is_cc_immune or is_ethereal_active() or is_invulnerable():
		return
	if not is_instance_valid(caster):
		return
	var caster_path = caster.get_path()
	var rel_pos = custom_relocate_pos if (custom_relocate_pos != null and custom_relocate_pos is Vector3) else Vector3.ZERO
	if is_multiplayer_match():
		if not is_server_authoritative():
			return
		sync_apply_bound.rpc(caster_path, duration, rel_pos, buffer_offset)
	else:
		sync_apply_bound(caster_path, duration, rel_pos, buffer_offset)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_bound(caster_path: NodePath, duration: float, custom_relocate_pos: Vector3 = Vector3.ZERO, buffer_offset: float = 0.2) -> void:
	if not _is_sender_host():
		return
	bound_timer = max(bound_timer, duration)
	if not caster_path.is_empty():
		bound_caster_node = get_node_or_null(caster_path)
	else:
		bound_caster_node = null

	if is_instance_valid(bound_caster_node):
		# Relocation phase: relocate target to specified position or default directly in front of caster
		var target_relocate_pos: Vector3
		if not custom_relocate_pos.is_zero_approx():
			target_relocate_pos = custom_relocate_pos
		else:
			var r_caster = bound_caster_node.get_hitbox_radius() if bound_caster_node.has_method("get_hitbox_radius") else 0.4
			var r_target = get_hitbox_radius()
			var forward = -bound_caster_node.global_transform.basis.z
			forward.y = 0.0
			if forward.length_squared() > 0.001:
				forward = forward.normalized()
			else:
				forward = Vector3.FORWARD
			var sep_dist = r_caster + r_target + max(0.05, buffer_offset)
			target_relocate_pos = bound_caster_node.global_position + forward * sep_dist
			target_relocate_pos.y = global_position.y

		global_position = target_relocate_pos
		velocity = Vector3.ZERO
		bound_relative_offset = global_position - bound_caster_node.global_position
	else:
		bound_relative_offset = Vector3.ZERO

	cancel_channel()
	clear_buffered_ability()
	if has_method("cancel_active_windup"):
		cancel_active_windup()

func apply_slow(duration: float, percent: float) -> void:
	if is_cc_immune or is_ethereal_active():
		return
	if is_multiplayer_match():
		if not is_server_authoritative():
			return
		sync_apply_slow.rpc(duration, percent)
	else:
		sync_apply_slow(duration, percent)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_slow(duration: float, percent: float) -> void:
	if not _is_sender_host():
		return
	slow_timer = max(slow_timer, duration)
	slow_initial_duration = max(slow_initial_duration, duration)
	slow_initial_percent = max(slow_initial_percent, percent)
	slow_percent = slow_initial_percent

func apply_silence(duration: float) -> void:
	if is_cc_immune or is_ethereal_active():
		return
	if is_multiplayer_match():
		if not is_server_authoritative():
			return
		sync_apply_silence.rpc(duration)
	else:
		sync_apply_silence(duration)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_silence(duration: float) -> void:
	if not _is_sender_host():
		return
	silence_timer = max(silence_timer, duration)
	cancel_channel()
	clear_buffered_ability()
	if has_method("cancel_active_windup"):
		cancel_active_windup()

func apply_root(duration: float) -> void:
	if is_cc_immune or is_ethereal_active():
		return
	if is_multiplayer_match():
		if not is_server_authoritative():
			return
		sync_apply_root.rpc(duration)
	else:
		sync_apply_root(duration)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_root(duration: float) -> void:
	if not _is_sender_host():
		return
	root_timer = max(root_timer, duration)

func apply_grounded(duration: float) -> void:
	if is_cc_immune or is_ethereal_active():
		return
	if is_multiplayer_match():
		if not is_server_authoritative():
			return
		sync_apply_grounded.rpc(duration)
	else:
		sync_apply_grounded(duration)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_grounded(duration: float) -> void:
	if not _is_sender_host():
		return
	grounded_timer = max(grounded_timer, duration)

func apply_cripple(duration: float, intensity: float = 0.35) -> void:
	if is_cc_immune or is_ethereal_active():
		return
	if is_multiplayer_match():
		if not is_server_authoritative():
			return
		sync_apply_cripple.rpc(duration, intensity)
	else:
		sync_apply_cripple(duration, intensity)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_cripple(duration: float, intensity: float = 0.35) -> void:
	if not _is_sender_host():
		return
	cripple_timer = max(cripple_timer, duration)
	cripple_intensity = intensity

func apply_ethereal(duration: float) -> void:
	if is_multiplayer_match():
		if not is_server_authoritative():
			return
		sync_apply_ethereal.rpc(duration)
	else:
		sync_apply_ethereal(duration)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_ethereal(duration: float) -> void:
	if not _is_sender_host():
		return
	ethereal_timer = max(ethereal_timer, duration)

func apply_speed_boost(duration: float, percent: float) -> void:
	if is_multiplayer_match():
		if not is_server_authoritative():
			return
		sync_apply_speed_boost.rpc(duration, percent)
	else:
		sync_apply_speed_boost(duration, percent)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_speed_boost(duration: float, percent: float) -> void:
	if not _is_sender_host():
		return
	speed_boost_timer = max(speed_boost_timer, duration)
	speed_boost_percent = max(speed_boost_percent, percent)

func apply_float(duration: float = FLOAT_TOTAL_DURATION) -> void:
	if is_cc_immune or is_ethereal_active():
		return
	if is_multiplayer_match():
		if not is_server_authoritative():
			return
		sync_apply_float.rpc(duration)
	else:
		sync_apply_float(duration)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_float(duration: float) -> void:
	if not _is_sender_host():
		return
	is_floating = true
	float_timer = duration

func start_float_state(duration: float = FLOAT_TOTAL_DURATION) -> void:
	apply_float(duration)

func end_float_state() -> void:
	is_floating = false
	float_timer = 0.0
	current_gravity_mult = 1.0
	if is_multiplayer_match():
		if not is_server_authoritative():
			return
		sync_end_float_state.rpc()

@rpc("any_peer", "call_local", "reliable")
func sync_end_float_state() -> void:
	if not _is_sender_host():
		return
	is_floating = false
	float_timer = 0.0
	current_gravity_mult = 1.0

func cleanse_cc() -> void:
	if is_multiplayer_match():
		if not is_server_authoritative():
			return
		sync_cleanse_cc.rpc()
	else:
		sync_cleanse_cc()

@rpc("any_peer", "call_local", "reliable")
func sync_cleanse_cc() -> void:
	if not _is_sender_host():
		return
	stun_timer = 0.0
	bound_timer = 0.0
	bound_caster_node = null
	bound_relative_offset = Vector3.ZERO
	slow_timer = 0.0
	slow_percent = 0.0
	slow_initial_duration = 0.0
	slow_initial_percent = 0.0
	silence_timer = 0.0
	root_timer = 0.0
	grounded_timer = 0.0
	cripple_timer = 0.0
	is_floating = false
	float_timer = 0.0
	taunt_timer = 0.0
	taunter_node = null

# --- Extended Status Application: Invisibility, Taunt, Transformation, Invulnerability ---
func _on_invisibility_changed(_is_invis: bool) -> void:
	pass

func _on_transformation_applied(_prop_type: String, _properties: Dictionary) -> void:
	pass

func _on_transformation_broken(_prev_prop: String) -> void:
	pass

func apply_invisibility(duration: float) -> void:
	if is_multiplayer_match():
		if not is_server_authoritative():
			return
		sync_apply_invisibility.rpc(duration)
	else:
		sync_apply_invisibility(duration)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_invisibility(duration: float) -> void:
	if not _is_sender_host():
		return
	invisibility_timer = max(invisibility_timer, duration)
	_on_invisibility_changed(true)

func break_invisibility() -> void:
	if invisibility_timer <= 0.0:
		return
	if is_multiplayer_match():
		if not is_server_authoritative():
			request_break_invisibility.rpc_id(1)
			return
		sync_break_invisibility.rpc()
	else:
		sync_break_invisibility()

@rpc("any_peer", "call_remote", "reliable")
func request_break_invisibility() -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var my_id = str(name).to_int()
	if sender_id != my_id and my_id != 1:
		return
	break_invisibility()

@rpc("any_peer", "call_local", "reliable")
func sync_break_invisibility() -> void:
	if not _is_sender_host():
		return
	invisibility_timer = 0.0
	_on_invisibility_changed(false)

func apply_taunt(taunter: Node, duration: float, damage_reduction: float = 0.35) -> void:
	if is_cc_immune or is_ethereal_active() or is_invulnerable():
		return
	var taunter_path = taunter.get_path() if is_instance_valid(taunter) else NodePath()
	if is_multiplayer_match():
		if not is_server_authoritative():
			return
		sync_apply_taunt.rpc(taunter_path, duration, damage_reduction)
	else:
		sync_apply_taunt(taunter_path, duration, damage_reduction)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_taunt(taunter_path: NodePath, duration: float, damage_reduction: float = 0.35) -> void:
	if not _is_sender_host():
		return
	taunt_timer = max(taunt_timer, duration)
	taunt_damage_reduction = damage_reduction
	if not taunter_path.is_empty():
		taunter_node = get_node_or_null(taunter_path)
	else:
		taunter_node = null

func apply_transformation(prop_type: String, properties: Dictionary = {}) -> void:
	if is_multiplayer_match():
		if not is_server_authoritative():
			return
		sync_apply_transformation.rpc(prop_type, properties)
	else:
		sync_apply_transformation(prop_type, properties)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_transformation(prop_type: String, properties: Dictionary = {}) -> void:
	if not _is_sender_host():
		return
	is_transformed = true
	transformed_prop_type = prop_type
	transformation_properties = properties
	_on_transformation_applied(prop_type, properties)

func break_transformation() -> void:
	if not is_transformed:
		return
	if is_multiplayer_match():
		if not is_server_authoritative():
			request_break_transformation.rpc_id(1)
			return
		sync_break_transformation.rpc()
	else:
		sync_break_transformation()

@rpc("any_peer", "call_remote", "reliable")
func request_break_transformation() -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var my_id = str(name).to_int()
	if sender_id != my_id and my_id != 1:
		return
	break_transformation()

@rpc("any_peer", "call_local", "reliable")
func sync_break_transformation() -> void:
	if not _is_sender_host():
		return
	is_transformed = false
	var prev_prop = transformed_prop_type
	transformed_prop_type = ""
	transformation_properties = {}
	_on_transformation_broken(prev_prop)

func apply_invulnerability(duration: float) -> void:
	if is_multiplayer_match():
		if not is_server_authoritative():
			return
		sync_apply_invulnerability.rpc(duration)
	else:
		sync_apply_invulnerability(duration)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_invulnerability(duration: float) -> void:
	if not _is_sender_host():
		return
	invulnerable_timer = max(invulnerable_timer, duration)
	displacement_immune_timer = max(displacement_immune_timer, duration)

func apply_displacement_immunity(duration: float) -> void:
	if is_multiplayer_match():
		if not is_server_authoritative():
			return
		sync_apply_displacement_immunity.rpc(duration)
	else:
		sync_apply_displacement_immunity(duration)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_displacement_immunity(duration: float) -> void:
	if not _is_sender_host():
		return
	displacement_immune_timer = max(displacement_immune_timer, duration)

# --- Rupture Marks (Dive / Asparsas Passive) Methods ---
func apply_rupture_mark(attacker_id: int) -> void:
	dive_marks_count = min(DIVE_MARK_MAX, dive_marks_count + 1)
	dive_mark_timer = DIVE_MARK_DURATION
	dive_mark_attacker_id = attacker_id

func detonate_dive_marks(attacker: Node = null) -> int:
	if dive_marks_count <= 0:
		return 0
	var count = dive_marks_count
	var total_burst = count * DIVE_MARK_BURST_PER_STACK
	var att_id = dive_mark_attacker_id
	dive_marks_count = 0
	dive_mark_timer = 0.0
	if has_method("take_damage"):
		call("take_damage", total_burst, att_id, 1)
	elif "health" in self:
		set("health", get("health") - total_burst)
	
	# Determine attacker instance if possible
	var att_node = attacker
	if not is_instance_valid(att_node) and is_inside_tree():
		if att_id != 0:
			if get_tree().root:
				att_node = get_tree().root.get_node_or_null("Main/Players/" + str(att_id))
			if not is_instance_valid(att_node):
				var players = get_tree().get_nodes_in_group("players")
				for p in players:
					if p.name == str(att_id) or (p.get("peer_id") == att_id):
						att_node = p
						break
	
	if is_instance_valid(att_node):
		if att_node.has_method("proc_passive_heal"):
			att_node.proc_passive_heal(count)
		elif att_node.has_method("heal"):
			var heal_rider = (load("res://ability/riders/heal_rider.gd") as GDScript).new()
			heal_rider.scale_with_marks = true
			heal_rider.apply_to_self = true
			heal_rider._execute_heal(att_node, count)
			heal_rider.free()
		
	return count

# --- Status & Timer Processing ---
func _process_status_timers(delta: float) -> void:
	# Channeling process
	if is_channeling:
		channel_timer -= delta
		if channel_timer <= 0.0:
			is_channeling = false
			if channel_complete_callback.is_valid():
				var cb = channel_complete_callback
				channel_complete_callback = Callable()
				cb.call()
			_on_channel_completed()

	# CC Timers
	if stun_timer > 0.0:
		stun_timer = max(0.0, stun_timer - delta)
	if bound_timer > 0.0:
		bound_timer = max(0.0, bound_timer - delta)
		if bound_timer <= 0.0 or not is_instance_valid(bound_caster_node) or (bound_caster_node.get("is_dead") == true):
			bound_timer = 0.0
			bound_caster_node = null
			bound_relative_offset = Vector3.ZERO
	if silence_timer > 0.0:
		silence_timer = max(0.0, silence_timer - delta)
	if root_timer > 0.0:
		root_timer = max(0.0, root_timer - delta)
	if grounded_timer > 0.0:
		grounded_timer = max(0.0, grounded_timer - delta)
	if cripple_timer > 0.0:
		cripple_timer = max(0.0, cripple_timer - delta)
	if ethereal_timer > 0.0:
		ethereal_timer = max(0.0, ethereal_timer - delta)
	if speed_boost_timer > 0.0:
		speed_boost_timer = max(0.0, speed_boost_timer - delta)
		if speed_boost_timer <= 0.0:
			speed_boost_percent = 0.0

	# Extended Status Timers
	if invisibility_timer > 0.0:
		invisibility_timer = max(0.0, invisibility_timer - delta)
		if invisibility_timer <= 0.0:
			_on_invisibility_changed(false)

	if taunt_timer > 0.0:
		taunt_timer = max(0.0, taunt_timer - delta)
		if taunt_timer <= 0.0:
			taunter_node = null

	if invulnerable_timer > 0.0:
		invulnerable_timer = max(0.0, invulnerable_timer - delta)
	if displacement_immune_timer > 0.0:
		displacement_immune_timer = max(0.0, displacement_immune_timer - delta)

	# Rupture mark timer
	if dive_marks_count > 0:
		dive_mark_timer -= delta
		if dive_mark_timer <= 0.0:
			dive_marks_count = 0

	# Linear decay slow
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_timer = 0.0
			slow_percent = 0.0
			slow_initial_duration = 0.0
			slow_initial_percent = 0.0
		elif slow_initial_duration > 0.0:
			var remaining_ratio = slow_timer / slow_initial_duration
			slow_percent = slow_initial_percent * remaining_ratio

	# Levitation / Float State
	if is_floating:
		float_timer -= delta
		var elapsed = FLOAT_TOTAL_DURATION - float_timer
		if elapsed < FLOAT_SLOWDOWN_TIME:
			current_gravity_mult = lerp(1.0, 0.0, elapsed / FLOAT_SLOWDOWN_TIME)
		elif elapsed < (FLOAT_SLOWDOWN_TIME + FLOAT_HOVER_TIME):
			current_gravity_mult = 0.0
			if velocity.y < 0.0:
				velocity.y = move_toward(velocity.y, 0.0, 15.0 * delta)
		else:
			var fall_progress = (elapsed - (FLOAT_SLOWDOWN_TIME + FLOAT_HOVER_TIME)) / (FLOAT_TOTAL_DURATION - FLOAT_SLOWDOWN_TIME - FLOAT_HOVER_TIME)
			current_gravity_mult = lerp(0.0, 1.0, fall_progress)
		if float_timer <= 0.0:
			is_floating = false
			current_gravity_mult = 1.0
	else:
		current_gravity_mult = 1.0
