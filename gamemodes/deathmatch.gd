class_name DeathmatchMode
extends GameMode

func _init() -> void:
	id = "dm"
	display_name = "Deathmatch (Free For All)"
	short_name = "FFA"
	description = "Every warrior for themselves! 5-minute timed match with 5-second respawns. The player with the most kills wins."
	is_team_based = false
	has_rounds = false
	round_win_target = 1
	max_rounds = 1
	match_time_limit = 300.0
	respawn_delay = 5.0
	gold_per_round = 0

func format_timer(time_left: float) -> String:
	var mins = int(max(0.0, time_left)) / 60
	var secs = int(max(0.0, time_left)) % 60
	return "⏱ DEATHMATCH: %02d:%02d" % [mins, secs]
