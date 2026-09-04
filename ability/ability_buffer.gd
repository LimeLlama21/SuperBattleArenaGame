3
class_name AbilityBuffer
extends RefCounted

## Dedicated Ability Buffering System
## Manages queuing of ability slot inputs during active commitments (lockouts, channels, windups).
## Automatically holds queued inputs until the active action completes, then resolves them seamlessly.

enum ActionSource {
	NONE,
	LOCKOUT,
	CHANNEL,
	WINDUP
}

const DEFAULT_BUFFER_WINDOW: float = 0.35

var buffered_slot: String = ""
var buffer_timer: float = 0.0
var action_source: int = ActionSource.NONE

func buffer_ability(slot_key: String, remaining_action_time: float = 0.0, source: int = ActionSource.NONE, window: float = DEFAULT_BUFFER_WINDOW) -> void:
	buffered_slot = slot_key
	buffer_timer = max(window, remaining_action_time + window)
	action_source = source

func clear() -> void:
	buffered_slot = ""
	buffer_timer = 0.0
	action_source = ActionSource.NONE

func update(delta: float) -> void:
	if buffer_timer > 0.0:
		buffer_timer -= delta
		if buffer_timer <= 0.0:
			clear()

func has_buffered_ability() -> bool:
	return buffered_slot != "" and buffer_timer > 0.0

func pop_buffered_ability() -> String:
	var slot = buffered_slot
	clear()
	return slot

func get_buffered_slot() -> String:
	return buffered_slot

func get_buffered_timer() -> float:
	return buffer_timer
