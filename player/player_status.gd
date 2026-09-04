class_name PlayerStatus
extends PlayerNetwork

# --- Universal Status Effects & CC ---
var stun_timer: float = 0.0
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

func get_slow_multiplier() -> float:
	if slow_timer > 0.0:
		var mult = 1.0 - slow_percent
		if is_crippled():
			mult *= (1.0 - cripple_intensity)
		return clamp(mult, 0.05, 1.0)
	elif is_crippled():
		return clamp(1.0 - cripple_intensity, 0.05, 1.0)
	return 1.0

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

# --- Status Application & Network Sync ---
func apply_stun(duration: float) -> void:
	if is_cc_immune or is_ethereal_active():
		return
	if is_multiplayer_match() and is_server_authoritative():
		sync_apply_stun.rpc(duration)
	else:
		sync_apply_stun(duration)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_stun(duration: float) -> void:
	stun_timer = max(stun_timer, duration)
	cancel_channel()
	clear_buffered_ability()

func apply_slow(duration: float, percent: float) -> void:
	if is_cc_immune or is_ethereal_active():
		return
	if is_multiplayer_match() and is_server_authoritative():
		sync_apply_slow.rpc(duration, percent)
	else:
		sync_apply_slow(duration, percent)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_slow(duration: float, percent: float) -> void:
	slow_timer = max(slow_timer, duration)
	slow_initial_duration = max(slow_initial_duration, duration)
	slow_initial_percent = max(slow_initial_percent, percent)
	slow_percent = slow_initial_percent

func apply_silence(duration: float) -> void:
	if is_cc_immune or is_ethereal_active():
		return
	if is_multiplayer_match() and is_server_authoritative():
		sync_apply_silence.rpc(duration)
	else:
		sync_apply_silence(duration)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_silence(duration: float) -> void:
	silence_timer = max(silence_timer, duration)
	cancel_channel()
	clear_buffered_ability()

func apply_root(duration: float) -> void:
	if is_cc_immune or is_ethereal_active():
		return
	if is_multiplayer_match() and is_server_authoritative():
		sync_apply_root.rpc(duration)
	else:
		sync_apply_root(duration)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_root(duration: float) -> void:
	root_timer = max(root_timer, duration)

func apply_grounded(duration: float) -> void:
	if is_cc_immune or is_ethereal_active():
		return
	if is_multiplayer_match() and is_server_authoritative():
		sync_apply_grounded.rpc(duration)
	else:
		sync_apply_grounded(duration)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_grounded(duration: float) -> void:
	grounded_timer = max(grounded_timer, duration)

func apply_cripple(duration: float, intensity: float = 0.35) -> void:
	if is_cc_immune or is_ethereal_active():
		return
	if is_multiplayer_match() and is_server_authoritative():
		sync_apply_cripple.rpc(duration, intensity)
	else:
		sync_apply_cripple(duration, intensity)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_cripple(duration: float, intensity: float = 0.35) -> void:
	cripple_timer = max(cripple_timer, duration)
	cripple_intensity = intensity

func apply_ethereal(duration: float) -> void:
	if is_multiplayer_match() and is_server_authoritative():
		sync_apply_ethereal.rpc(duration)
	else:
		sync_apply_ethereal(duration)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_ethereal(duration: float) -> void:
	ethereal_timer = max(ethereal_timer, duration)

func apply_speed_boost(duration: float, percent: float) -> void:
	if is_multiplayer_match() and is_server_authoritative():
		sync_apply_speed_boost.rpc(duration, percent)
	else:
		sync_apply_speed_boost(duration, percent)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_speed_boost(duration: float, percent: float) -> void:
	speed_boost_timer = max(speed_boost_timer, duration)
	speed_boost_percent = max(speed_boost_percent, percent)

func apply_float(duration: float = FLOAT_TOTAL_DURATION) -> void:
	if is_cc_immune or is_ethereal_active():
		return
	if is_multiplayer_match() and is_server_authoritative():
		sync_apply_float.rpc(duration)
	else:
		sync_apply_float(duration)

@rpc("any_peer", "call_local", "reliable")
func sync_apply_float(duration: float) -> void:
	is_floating = true
	float_timer = duration

func start_float_state(duration: float = FLOAT_TOTAL_DURATION) -> void:
	apply_float(duration)

func end_float_state() -> void:
	is_floating = false
	float_timer = 0.0
	current_gravity_mult = 1.0
	if is_multiplayer_match() and is_server_authoritative():
		sync_end_float_state.rpc()

@rpc("any_peer", "call_local", "reliable")
func sync_end_float_state() -> void:
	is_floating = false
	float_timer = 0.0
	current_gravity_mult = 1.0

func cleanse_cc() -> void:
	if is_multiplayer_match() and is_server_authoritative():
		sync_cleanse_cc.rpc()
	else:
		sync_cleanse_cc()

@rpc("any_peer", "call_local", "reliable")
func sync_cleanse_cc() -> void:
	stun_timer = 0.0
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
