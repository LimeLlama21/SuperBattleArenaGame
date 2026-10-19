class_name PlayerStatus
extends Node

## PlayerStatus - Sibling component managing status effects, crowd control (CC),
## and buff/debuff lifecycles using first-class StatusEffect objects.

const StatusEffectClass = preload("res://player/status_effect.gd")

var player: CharacterBody3D = null

func _get_player() -> CharacterBody3D:
	if is_instance_valid(player):
		return player
	var parent = get_parent()
	if parent is CharacterBody3D:
		return parent as CharacterBody3D
	return null

# --- Active Status Effects Dictionary: id (String) -> StatusEffect ---
var active_statuses: Dictionary = {}

# Non-timed or special state flags
var is_cc_immune: bool = false
var ground_hazard_immune: bool = false
var can_pass_through_walls: bool = false
var external_velocity: Vector3 = Vector3.ZERO

# Bound state reference
var bound_caster_node: Node = null
var bound_relative_offset: Vector3 = Vector3.ZERO

# Taunt state reference
var taunter_node: Node = null
var taunt_damage_reduction: float = 0.35

# Fear state reference
var fear_source_node: Node = null
var fear_source_pos: Vector3 = Vector3.ZERO

# Bleed state
var bleed_total_damage: float = 0.0
var bleed_applier_id: int = 0
var bleed_tick_timer: float = 0.0
var bleed_trail_spawn_timer: float = 0.0
const BLEED_TICK_INTERVAL: float = 0.5
const BLEED_TRAIL_INTERVAL: float = 0.12

# Transformation state
var is_transformed: bool = false
var transformed_prop_type: String = ""
var transformation_properties: Dictionary = {}

# Levitation / Float state
var is_floating: bool = false
var current_gravity_mult: float = 1.0
const FLOAT_TOTAL_DURATION: float = 2.2
const FLOAT_SLOWDOWN_TIME: float = 0.7
const FLOAT_HOVER_TIME: float = 1.4

# Channeling & Input Buffering
var is_channeling: bool = false
var channel_timer: float = 0.0
var channel_complete_callback: Callable = Callable()
var ability_buffer: AbilityBuffer = AbilityBuffer.new()

# Ethereal terrain phasing grace state
var ethereal_terrain_grace_timer: float = 0.0
var last_safe_ground_pos: Vector3 = Vector3.ZERO

# Rupture Marks (Aspara Passive) Constants
const DIVE_MARK_DURATION: float = 3.5
const DIVE_MARK_MAX: int = 5
const DIVE_MARK_BURST_PER_STACK: float = 18.0

# --- Core Status Object API ---

func apply_status_effect(effect: StatusEffect) -> void:
	if not effect:
		return
	if is_cc_immune and is_cc_type(effect.id):
		return
	if is_ethereal_active() and effect.id != "ethereal" and is_cc_type(effect.id):
		return

	var key = effect.id.to_lower()
	if active_statuses.has(key):
		var existing = active_statuses[key] as StatusEffect
		existing.refresh(effect.duration, effect.intensity)
		existing.applier_node = effect.applier_node
		existing.applier_id = effect.applier_id
		existing.custom_params.merge(effect.custom_params, true)
	else:
		active_statuses[key] = effect

func apply_status_by_name(id: String, duration: float, intensity: float = 0.0, applier: Node = null, params: Dictionary = {}) -> StatusEffect:
	var effect = StatusEffectClass.new(id, duration, intensity, applier, params)
	apply_status_effect(effect)
	return effect

func has_status(id: String) -> bool:
	var key = id.to_lower()
	if active_statuses.has(key):
		var eff = active_statuses[key] as StatusEffect
		return eff != null and eff.remaining > 0.0
	return false

func get_status(id: String) -> StatusEffect:
	var key = id.to_lower()
	return active_statuses.get(key, null)

func remove_status(id: String) -> void:
	var key = id.to_lower()
	if active_statuses.has(key):
		active_statuses.erase(key)

func clear_statuses() -> void:
	active_statuses.clear()

func get_status_remaining(id: String) -> float:
	var eff = get_status(id)
	return eff.remaining if eff else 0.0

func set_status_remaining(id: String, duration: float, intensity: float = 0.0) -> void:
	if duration <= 0.0:
		remove_status(id)
	else:
		var eff = get_status(id)
		if eff:
			eff.remaining = duration
			eff.duration = max(eff.duration, duration)
		else:
			apply_status_by_name(id, duration, intensity)

func is_cc_type(id: String) -> bool:
	var norm = id.to_lower()
	return norm in ["stun", "bound", "silence", "root", "grounded", "cripple", "taunt", "fear", "blind", "float"]

# --- Status Query Helpers (Preserves full backward compatibility) ---

func is_stunned() -> bool:
	return has_status("stun")

func is_bound() -> bool:
	return has_status("bound")

func get_bound_caster() -> Node:
	return bound_caster_node if is_instance_valid(bound_caster_node) else null

func is_slowed() -> bool:
	return has_status("slow")

func is_silenced() -> bool:
	return has_status("silence")

func is_rooted() -> bool:
	return has_status("root")

func is_grounded() -> bool:
	return has_status("grounded")

func is_crippled() -> bool:
	return has_status("cripple")

func is_ethereal_active() -> bool:
	return has_status("ethereal") or ethereal_terrain_grace_timer > 0.0

func is_invisible() -> bool:
	return has_status("invisibility")

func is_taunted() -> bool:
	return has_status("taunt")

func is_feared() -> bool:
	return has_status("fear")

func get_fear_source_node() -> Node:
	return fear_source_node if is_instance_valid(fear_source_node) else null

func is_bleeding() -> bool:
	return has_status("bleed")

func is_blinded() -> bool:
	return has_status("blind")

func is_nearsighted() -> bool:
	return has_status("blind")

func is_invulnerable() -> bool:
	return has_status("invulnerable")

func is_displacement_immune() -> bool:
	return has_status("displacement_immune") or is_invulnerable()

func is_ground_hazard_immune_active() -> bool:
	return ground_hazard_immune or has_status("ground_hazard_immunity")

func is_ground_hazard_immune() -> bool:
	return ground_hazard_immune or has_status("ground_hazard_immunity")

func is_phasing_walls() -> bool:
	return can_pass_through_walls or has_status("phasing_walls")

func is_unit_transformed() -> bool:
	return is_transformed

func is_inked() -> bool:
	return has_status("ink")

# --- Legacy Timer Property Wrappers (Full Property Accessors) ---

var stun_timer: float:
	get: return get_status_remaining("stun")
	set(val): set_status_remaining("stun", val)

var bound_timer: float:
	get: return get_status_remaining("bound")
	set(val): set_status_remaining("bound", val)

var slow_timer: float:
	get: return get_status_remaining("slow")
	set(val): set_status_remaining("slow", val)

var slow_percent: float:
	get:
		var s = get_status("slow")
		return s.intensity if s else 0.0
	set(val):
		var s = get_status("slow")
		if s: s.intensity = val

var slow_initial_duration: float = 0.0
var slow_initial_percent: float = 0.0

var silence_timer: float:
	get: return get_status_remaining("silence")
	set(val): set_status_remaining("silence", val)

var root_timer: float:
	get: return get_status_remaining("root")
	set(val): set_status_remaining("root", val)

var grounded_timer: float:
	get: return get_status_remaining("grounded")
	set(val): set_status_remaining("grounded", val)

var cripple_timer: float:
	get: return get_status_remaining("cripple")
	set(val): set_status_remaining("cripple", val)

var cripple_intensity: float:
	get:
		var s = get_status("cripple")
		return s.intensity if s else 0.35
	set(val):
		var s = get_status("cripple")
		if s: s.intensity = val

var ethereal_timer: float:
	get: return get_status_remaining("ethereal")
	set(val): set_status_remaining("ethereal", val)

var blind_timer: float:
	get: return get_status_remaining("blind")
	set(val): set_status_remaining("blind", val)

var invisibility_timer: float:
	get: return get_status_remaining("invisibility")
	set(val): set_status_remaining("invisibility", val)

var taunt_timer: float:
	get: return get_status_remaining("taunt")
	set(val): set_status_remaining("taunt", val)

var fear_timer: float:
	get: return get_status_remaining("fear")
	set(val): set_status_remaining("fear", val)

var bleed_timer: float:
	get: return get_status_remaining("bleed")
	set(val): set_status_remaining("bleed", val)

var invulnerable_timer: float:
	get: return get_status_remaining("invulnerable")
	set(val): set_status_remaining("invulnerable", val)

var displacement_immune_timer: float:
	get: return get_status_remaining("displacement_immune")
	set(val): set_status_remaining("displacement_immune", val)

var ground_hazard_immunity_timer: float:
	get: return get_status_remaining("ground_hazard_immunity")
	set(val): set_status_remaining("ground_hazard_immunity", val)

var phasing_walls_timer: float:
	get: return get_status_remaining("phasing_walls")
	set(val): set_status_remaining("phasing_walls", val)

var speed_boost_timer: float:
	get: return get_status_remaining("speed_boost")
	set(val): set_status_remaining("speed_boost", val)

var speed_boost_percent: float:
	get:
		var s = get_status("speed_boost")
		return s.intensity if s else 0.0
	set(val):
		var s = get_status("speed_boost")
		if s: s.intensity = val

var speed_boost_initial_duration: float = 0.0
var speed_boost_initial_percent: float = 0.0
var speed_boost_decaying: bool = false

var float_timer: float = 0.0

# Dynamic character-specific status adapters
var embedded_feathers_count: int = 0
var embedded_feathers_timer: float:
	get: return get_status_remaining("feathers")
	set(val): set_status_remaining("feathers", val)

var dive_marks_count: int = 0
var dive_mark_timer: float:
	get: return get_status_remaining("dive_mark")
	set(val): set_status_remaining("dive_mark", val)
var dive_mark_attacker_id: int = 0

var ink_timer: float:
	get: return get_status_remaining("ink")
	set(val): set_status_remaining("ink", val)
var ink_source_id: int = 0
var ink_slow_percent: float:
	get:
		var s = get_status("ink")
		return s.intensity if s else 0.20
	set(val):
		var s = get_status("ink")
		if s: s.intensity = val

# --- Multipliers and Calculations ---

func get_taunt_target() -> Node:
	return taunter_node if is_instance_valid(taunter_node) else null

func get_taunt_damage_multiplier() -> float:
	return (1.0 - taunt_damage_reduction) if is_taunted() else 1.0

func get_slow_multiplier() -> float:
	var mult = 1.0
	var slow_s = get_status("slow")
	if slow_s and slow_s.remaining > 0.0:
		mult *= (1.0 - slow_s.intensity)
	var ink_s = get_status("ink")
	if ink_s and ink_s.remaining > 0.0:
		mult *= (1.0 - ink_s.intensity)
	if is_crippled():
		mult *= (1.0 - cripple_intensity)
	return clamp(mult, 0.05, 1.0)

func get_hitbox_radius() -> float:
	var p = _get_player()
	if not p:
		return 0.4
	var ch = p.get_node_or_null("CombatHitbox")
	if ch:
		var cs = ch.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if cs and cs.shape and "radius" in cs.shape:
			return cs.shape.radius
	var col = p.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col and col.shape:
		if col.shape is CapsuleShape3D or col.shape is CylinderShape3D:
			return col.shape.radius
		elif col.shape is BoxShape3D:
			return max(col.shape.size.x, col.shape.size.z) * 0.5
	return 0.4

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
	var p = _get_player()
	if p and p.has_method("_on_channel_cancelled"):
		p._on_channel_cancelled()

func _on_channel_completed() -> void:
	var p = _get_player()
	if p and p.has_method("_try_resolve_buffered_ability"):
		p._try_resolve_buffered_ability()

func clear_buffered_ability() -> void:
	if ability_buffer:
		ability_buffer.clear()

func has_buffered_ability() -> bool:
	return ability_buffer != null and ability_buffer.has_buffered_ability()

# --- Authority & Network Sync Helpers ---

func is_multiplayer_match() -> bool:
	var p = _get_player()
	if p and p.has_method("is_multiplayer_match"):
		return p.is_multiplayer_match()
	return multiplayer and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0

func is_server_authoritative() -> bool:
	var p = _get_player()
	if p and p.has_method("is_server_authoritative"):
		return p.is_server_authoritative()
	if not is_multiplayer_match():
		return true
	return multiplayer.is_server()

func _is_sender_host() -> bool:
	if not is_multiplayer_match():
		return true
	if multiplayer.is_server():
		return true
	return multiplayer.get_remote_sender_id() == 1

# --- Concrete Status Application RPC Methods ---

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
	apply_status_by_name("stun", duration)
	cancel_channel()
	clear_buffered_ability()
	var p = _get_player()
	if p and p.has_method("cancel_active_windup"):
		p.cancel_active_windup()

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
func sync_apply_bound(caster_path: NodePath, duration: float, custom_rel_pos: Vector3 = Vector3.ZERO, buffer_offset: float = 0.2) -> void:
	if not _is_sender_host():
		return
	var caster = get_node_or_null(caster_path)
	if not is_instance_valid(caster):
		return
	bound_caster_node = caster
	apply_status_by_name("bound", duration)
	cancel_channel()
	clear_buffered_ability()
	var p = _get_player()
	if p and p.has_method("cancel_active_windup"):
		p.cancel_active_windup()

	if custom_rel_pos != Vector3.ZERO:
		bound_relative_offset = custom_rel_pos
	else:
		var caster_radius = 0.4
		if caster.has_method("get_hitbox_radius"):
			caster_radius = caster.get_hitbox_radius()
		var my_radius = get_hitbox_radius()
		var dist = caster_radius + my_radius + buffer_offset
		var dir_away = Vector3.FORWARD
		if p:
			var diff = p.global_position - caster.global_position
			diff.y = 0.0
			if diff.length_squared() > 0.001:
				dir_away = diff.normalized()
		bound_relative_offset = dir_away * dist

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
	var eff = get_status("slow")
	if eff:
		eff.remaining = max(eff.remaining, duration)
		eff.duration = max(eff.duration, duration)
		eff.intensity = max(eff.intensity, percent)
	else:
		eff = apply_status_by_name("slow", duration, percent)
	slow_initial_duration = eff.duration
	slow_initial_percent = eff.intensity

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
	apply_status_by_name("silence", duration)
	cancel_channel()
	clear_buffered_ability()
	var p = _get_player()
	if p and p.has_method("cancel_active_windup"):
		p.cancel_active_windup()

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
	apply_status_by_name("root", duration)
	cancel_channel()
	clear_buffered_ability()
	var p = _get_player()
	if p and p.has_method("cancel_active_windup"):
		p.cancel_active_windup()

func apply_grounded(duration: float) -> void:
	if is_cc_immune or is_ethereal_active() or is_ground_hazard_immune_active() or is_ground_hazard_immune():
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
	if is_cc_immune or is_ethereal_active() or is_ground_hazard_immune_active() or is_ground_hazard_immune():
		return
	apply_status_by_name("grounded", duration)

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
func sync_apply_cripple(duration: float, intensity: float) -> void:
	if not _is_sender_host():
		return
	var eff = get_status("cripple")
	if eff:
		eff.remaining = max(eff.remaining, duration)
		eff.intensity = max(eff.intensity, intensity)
	else:
		apply_status_by_name("cripple", duration, intensity)

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
	apply_status_by_name("ethereal", duration)
	ethereal_terrain_grace_timer = 0.0
	cleanse_cc()
	var p = _get_player()
	if p and p.has_method("_update_terrain_phasing_collision"):
		p._update_terrain_phasing_collision(0.0)

func remove_ethereal() -> void:
	if is_multiplayer_match():
		if not is_server_authoritative():
			return
		sync_remove_ethereal.rpc()
	else:
		sync_remove_ethereal()

@rpc("any_peer", "call_local", "reliable")
func sync_remove_ethereal() -> void:
	if not _is_sender_host():
		return
	remove_status("ethereal")
	ethereal_terrain_grace_timer = 0.0
	var p = _get_player()
	if p and p.has_method("_update_terrain_phasing_collision"):
		p._update_terrain_phasing_collision(0.0)

func apply_blind(duration: float) -> void:
	if is_cc_immune or is_ethereal_active():
		return
	if is_multiplayer_match():
		if not is_server_authoritative():
			return
		sync_apply_blind.rpc(duration)
	else:
		sync_apply_blind(duration)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_blind(duration: float) -> void:
	if not _is_sender_host():
		return
	apply_status_by_name("blind", duration)

func apply_taunt(caster: Node, duration: float, damage_reduction: float = 0.35) -> void:
	if is_cc_immune or is_ethereal_active():
		return
	if not is_instance_valid(caster):
		return
	var caster_path = caster.get_path()
	if is_multiplayer_match():
		if not is_server_authoritative():
			return
		sync_apply_taunt.rpc(caster_path, duration, damage_reduction)
	else:
		sync_apply_taunt(caster_path, duration, damage_reduction)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_taunt(caster_path: NodePath, duration: float, damage_reduction: float = 0.35) -> void:
	if not _is_sender_host():
		return
	var caster = get_node_or_null(caster_path)
	if not is_instance_valid(caster):
		return
	taunter_node = caster
	taunt_damage_reduction = damage_reduction
	apply_status_by_name("taunt", duration)

func apply_fear(arg1: Variant = 1.0, arg2: Variant = null, arg3: Variant = null) -> void:
	if is_cc_immune or is_ethereal_active():
		return
	var duration: float = 1.0
	var src_node: Node = null
	var src_pos: Vector3 = Vector3.ZERO
	
	if typeof(arg1) in [TYPE_FLOAT, TYPE_INT]:
		duration = float(arg1)
		if arg2 is Node:
			src_node = arg2
			src_pos = arg2.global_position if is_instance_valid(arg2) else Vector3.ZERO
		elif arg2 is Vector3:
			src_pos = arg2
		if arg3 is Vector3:
			src_pos = arg3
		elif arg3 is Node:
			src_node = arg3
	else:
		if arg1 is Node:
			src_node = arg1
			src_pos = arg2 if arg2 is Vector3 else (arg1.global_position if is_instance_valid(arg1) else Vector3.ZERO)
			duration = float(arg3) if arg3 != null else 1.0
		elif arg1 is Vector3:
			src_pos = arg1
			duration = float(arg2) if arg2 != null else 1.0
			
	var node_path = src_node.get_path() if is_instance_valid(src_node) else NodePath("")
	if is_multiplayer_match():
		if not is_server_authoritative():
			return
		sync_apply_fear.rpc(node_path, src_pos, duration)
	else:
		sync_apply_fear(node_path, src_pos, duration)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_fear(node_path: NodePath, pos: Vector3, duration: float) -> void:
	if not _is_sender_host():
		return
	fear_source_node = get_node_or_null(node_path) if not str(node_path).is_empty() else null
	fear_source_pos = pos
	apply_status_by_name("fear", duration)
	cancel_channel()
	clear_buffered_ability()
	var p = _get_player()
	if p and p.has_method("cancel_active_windup"):
		p.cancel_active_windup()

func apply_bleed(arg1: Variant = 0.0, arg2: Variant = 5.0, arg3: Variant = 0) -> void:
	if is_ethereal_active():
		return
	var dmg: float = 0.0
	var dur: float = 5.0
	var app_id: int = 0
	if typeof(arg1) == TYPE_INT and typeof(arg2) in [TYPE_FLOAT, TYPE_INT] and typeof(arg3) in [TYPE_FLOAT, TYPE_INT] and float(arg3) > 0.0 and float(arg3) <= 10.0:
		app_id = int(arg1)
		dmg = float(arg2)
		dur = float(arg3)
	else:
		dmg = float(arg1)
		dur = float(arg2) if arg2 != null else 5.0
		app_id = int(arg3) if arg3 != null else 0
		
	if is_multiplayer_match():
		if not is_server_authoritative():
			return
		sync_apply_bleed.rpc(app_id, dmg, dur)
	else:
		sync_apply_bleed(app_id, dmg, dur)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_bleed(p_applier_id: int, total_damage: float, duration: float = 5.0) -> void:
	if not _is_sender_host():
		return
	bleed_applier_id = p_applier_id
	bleed_total_damage += total_damage
	bleed_tick_timer = 0.0
	bleed_trail_spawn_timer = 0.0
	apply_status_by_name("bleed", duration, total_damage)

func apply_speed_boost(duration: float, percent: float, decaying: bool = false) -> void:
	if is_multiplayer_match():
		if not is_server_authoritative():
			return
		sync_apply_speed_boost.rpc(duration, percent, decaying)
	else:
		sync_apply_speed_boost(duration, percent, decaying)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_speed_boost(duration: float, percent: float, decaying: bool = false) -> void:
	if not _is_sender_host():
		return
	var eff = get_status("speed_boost")
	if eff:
		eff.remaining = max(eff.remaining, duration)
		eff.duration = max(eff.duration, duration)
		eff.intensity = max(eff.intensity, percent)
	else:
		eff = apply_status_by_name("speed_boost", duration, percent)
	eff.is_decaying = decaying
	speed_boost_decaying = decaying
	speed_boost_initial_duration = eff.duration
	speed_boost_initial_percent = eff.intensity

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
	var to_remove: Array[String] = []
	for id in active_statuses:
		if is_cc_type(id) or id in ["slow", "bleed"]:
			to_remove.append(id)
	for id in to_remove:
		active_statuses.erase(id)
	bound_caster_node = null
	bound_relative_offset = Vector3.ZERO
	slow_initial_duration = 0.0
	slow_initial_percent = 0.0
	is_floating = false
	float_timer = 0.0
	taunter_node = null
	fear_source_node = null
	fear_source_pos = Vector3.ZERO
	bleed_total_damage = 0.0
	embedded_feathers_count = 0
	external_velocity = Vector3.ZERO
	ink_source_id = 0

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
	apply_status_by_name("invisibility", duration)
	_on_invisibility_changed(true)

func _on_invisibility_changed(is_invis: bool) -> void:
	var p = _get_player()
	if p and p.has_method("_on_invisibility_changed"):
		p._on_invisibility_changed(is_invis)

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

func _on_transformation_applied(prop_type: String, properties: Dictionary) -> void:
	var p = _get_player()
	if p and p.has_method("_on_transformation_applied"):
		p._on_transformation_applied(prop_type, properties)

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
	var p = _get_player()
	var sender_id = multiplayer.get_remote_sender_id()
	var my_id = str(p.name).to_int() if p else 1
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

func _on_transformation_broken(prev_prop: String) -> void:
	var p = _get_player()
	if p and p.has_method("_on_transformation_broken"):
		p._on_transformation_broken(prev_prop)

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
	apply_status_by_name("invulnerable", duration)
	apply_status_by_name("displacement_immune", duration)

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
	apply_status_by_name("displacement_immune", duration)

func apply_ground_hazard_immunity(duration: float) -> void:
	if is_multiplayer_match():
		if not is_server_authoritative():
			return
		sync_apply_ground_hazard_immunity.rpc(duration)
	else:
		sync_apply_ground_hazard_immunity(duration)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_ground_hazard_immunity(duration: float) -> void:
	if not _is_sender_host():
		return
	apply_status_by_name("ground_hazard_immunity", duration)

func apply_phasing(duration: float) -> void:
	if is_multiplayer_match():
		if not is_server_authoritative():
			return
		sync_apply_phasing.rpc(duration)
	else:
		sync_apply_phasing(duration)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_phasing(duration: float) -> void:
	if not _is_sender_host():
		return
	apply_status_by_name("phasing_walls", duration)

# --- Aspara Rupture Marks Adapter ---

func apply_rupture_mark(attacker_id: int) -> void:
	dive_marks_count = min(DIVE_MARK_MAX, dive_marks_count + 1)
	dive_mark_attacker_id = attacker_id
	apply_status_by_name("dive_mark", DIVE_MARK_DURATION, float(dive_marks_count))

func detonate_dive_marks(attacker: Node = null) -> int:
	if dive_marks_count <= 0:
		return 0
	var count = dive_marks_count
	var total_burst = count * DIVE_MARK_BURST_PER_STACK
	var att_id = dive_mark_attacker_id
	dive_marks_count = 0
	remove_status("dive_mark")
	var p = _get_player()
	if p and p.has_method("take_damage"):
		p.take_damage(total_burst, att_id, 1)

	var att_node = attacker
	if not is_instance_valid(att_node) and is_inside_tree():
		var scene_tree = get_tree()
		if scene_tree:
			for player_node in scene_tree.get_nodes_in_group("players"):
				if player_node.name == str(att_id) or (player_node.has_method("get_my_player_id") and player_node.get_my_player_id() == att_id):
					att_node = player_node
					break
	if is_instance_valid(att_node) and att_node.has_method("on_rupture_mark_detonated"):
		att_node.on_rupture_mark_detonated(count)
	return count

# --- Artist Ink Adapter ---

func apply_ink(duration: float, slow_pct: float = 0.20, source_id: int = 0) -> void:
	var eff = get_status("ink")
	if eff:
		eff.remaining = max(eff.remaining, duration)
		eff.duration = max(eff.duration, duration)
		eff.intensity = slow_pct
	else:
		eff = apply_status_by_name("ink", duration, slow_pct)
	if source_id > 0:
		ink_source_id = source_id
	apply_slow(duration, slow_pct)

# --- Morrigan Feathers Adapter ---

func get_embedded_feathers_count() -> int:
	return embedded_feathers_count

func apply_embedded_feather(duration: float = 5.0) -> void:
	if is_multiplayer_match():
		if not is_server_authoritative():
			return
		sync_apply_embedded_feather.rpc(duration)
	else:
		sync_apply_embedded_feather(duration)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_embedded_feather(duration: float = 5.0) -> void:
	if not _is_sender_host():
		return
	embedded_feathers_count += 1
	apply_status_by_name("feathers", duration, float(embedded_feathers_count))
	var feather_slow = 0.10 + float(max(0, embedded_feathers_count - 1)) * 0.05
	apply_slow(duration, feather_slow)

# --- Status Ticks & Lifecycle Processing ---

func _process_status_timers(delta: float) -> void:
	process_status_effects(delta)

func process_status_effects(delta: float) -> void:
	# Tick all active StatusEffect objects
	var expired_keys: Array[String] = []
	for key in active_statuses:
		var eff = active_statuses[key] as StatusEffect
		if eff:
			var expired = eff.update(delta)
			if expired:
				expired_keys.append(key)

	for key in expired_keys:
		active_statuses.erase(key)
		if key == "invisibility":
			_on_invisibility_changed(false)
		elif key == "taunt":
			taunter_node = null
		elif key == "fear":
			fear_source_node = null
			fear_source_pos = Vector3.ZERO
		elif key == "feathers":
			embedded_feathers_count = 0
		elif key == "dive_mark":
			dive_marks_count = 0
		elif key == "ink":
			ink_source_id = 0
		elif key == "slow":
			slow_initial_duration = 0.0
			slow_initial_percent = 0.0
		elif key == "speed_boost":
			speed_boost_initial_duration = 0.0
			speed_boost_initial_percent = 0.0
			speed_boost_decaying = false

	# Channeling timer decrement
	if is_channeling:
		channel_timer -= delta
		if channel_timer <= 0.0:
			is_channeling = false
			channel_timer = 0.0
			if channel_complete_callback.is_valid():
				channel_complete_callback.call()
			_on_channel_completed()

	# Bleed DoT processing
	if has_status("bleed"):
		bleed_tick_timer += delta
		if bleed_tick_timer >= BLEED_TICK_INTERVAL:
			var ticks_total = max(1.0, 5.0 / BLEED_TICK_INTERVAL)
			var tick_dmg = bleed_total_damage / ticks_total
			bleed_tick_timer = 0.0
			var p = _get_player()
			if p and p.has_method("take_damage") and is_server_authoritative():
				p.take_damage(tick_dmg, bleed_applier_id, 1)

		bleed_trail_spawn_timer += delta
		if bleed_trail_spawn_timer >= BLEED_TRAIL_INTERVAL:
			bleed_trail_spawn_timer = 0.0
			var p = _get_player()
			if p:
				_spawn_bleed_trail_segment(p.global_position, bleed_applier_id)
	else:
		bleed_total_damage = 0.0

	# Levitation / Float state processing
	var p = _get_player()
	if is_floating:
		float_timer -= delta
		var elapsed = FLOAT_TOTAL_DURATION - float_timer
		if elapsed < FLOAT_SLOWDOWN_TIME:
			current_gravity_mult = lerp(1.0, 0.0, elapsed / FLOAT_SLOWDOWN_TIME)
		elif elapsed < (FLOAT_SLOWDOWN_TIME + FLOAT_HOVER_TIME):
			current_gravity_mult = 0.0
			if p and p.velocity.y < 0.0:
				p.velocity.y = move_toward(p.velocity.y, 0.0, 15.0 * delta)
		else:
			var fall_progress = (elapsed - (FLOAT_SLOWDOWN_TIME + FLOAT_HOVER_TIME)) / (FLOAT_TOTAL_DURATION - FLOAT_SLOWDOWN_TIME - FLOAT_HOVER_TIME)
			current_gravity_mult = lerp(0.0, 1.0, fall_progress)
		if float_timer <= 0.0:
			is_floating = false
			current_gravity_mult = 1.0
	else:
		current_gravity_mult = 1.0

func _spawn_bleed_trail_segment(pos: Vector3, applier_id: int) -> void:
	var tree = get_tree()
	if not tree or not tree.root:
		return
	var main_node = tree.root.get_node_or_null("Main")
	if not main_node:
		return
	var hazard_cont = main_node.get_node_or_null("HazardZones")
	if not hazard_cont:
		return
	var trail_zone_scene = load("res://ability/zones/bleed_trail_zone.tscn") if ResourceLoader.exists("res://ability/zones/bleed_trail_zone.tscn") else null
	if trail_zone_scene:
		var zone = trail_zone_scene.instantiate()
		zone.global_position = pos
		if "applier_id" in zone:
			zone.applier_id = applier_id
		hazard_cont.add_child(zone)
