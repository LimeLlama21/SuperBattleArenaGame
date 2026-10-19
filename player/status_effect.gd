class_name StatusEffect
extends RefCounted

## StatusEffect - Object representation of a gameplay status effect / buff / debuff
## Supports timed durations, tick intervals (DoTs / HoTs), stack/intensity scaling,
## and decay.

var id: String = "" # e.g. "stun", "slow", "root", "silence", "grounded", "cripple", "ethereal", "taunt", "fear", "bleed", "invisibility", "speed_boost", "invulnerable", "bound", "blind", "float", "ink", "dive_mark", "feathers"
var duration: float = 0.0
var remaining: float = 0.0
var intensity: float = 0.0 # Slow %, speed boost %, cripple intensity %, etc.
var initial_intensity: float = 0.0
var applier_node: Node = null
var applier_id: int = 0
var is_decaying: bool = false
var custom_params: Dictionary = {}

# Tick-based periodic execution (e.g. Bleed, Burn, Poison)
var tick_interval: float = 0.0
var tick_timer: float = 0.0
var on_tick_callback: Callable = Callable()

func _init(p_id: String = "", p_duration: float = 0.0, p_intensity: float = 0.0, p_applier: Node = null, p_params: Dictionary = {}) -> void:
	id = p_id.to_lower()
	duration = p_duration
	remaining = p_duration
	intensity = p_intensity
	initial_intensity = p_intensity
	applier_node = p_applier
	if is_instance_valid(p_applier):
		if "name" in p_applier and str(p_applier.name).is_valid_int():
			applier_id = int(str(p_applier.name))
		elif "id" in p_applier and str(p_applier.id).is_valid_int():
			applier_id = int(str(p_applier.id))
	custom_params = p_params.duplicate()

func update(delta: float) -> bool:
	if remaining > 0.0:
		remaining -= delta
		if is_decaying and duration > 0.0:
			intensity = initial_intensity * max(0.0, remaining / duration)
		if tick_interval > 0.0:
			tick_timer += delta
			if tick_timer >= tick_interval:
				tick_timer -= tick_interval
				if on_tick_callback.is_valid():
					on_tick_callback.call(self)
		if remaining <= 0.0:
			remaining = 0.0
			return true
	return false

func is_active() -> bool:
	return remaining > 0.0

func refresh(new_duration: float, new_intensity: float = -1.0) -> void:
	remaining = max(remaining, new_duration)
	duration = max(duration, new_duration)
	if new_intensity >= 0.0:
		intensity = new_intensity
		initial_intensity = new_intensity
