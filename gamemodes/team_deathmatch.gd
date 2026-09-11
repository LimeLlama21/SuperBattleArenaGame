class_name TeamDeathmatchMode
extends GameMode

func _init() -> void:
	id = "tdm"
	display_name = "Team Deathmatch (TDM)"
	short_name = "TDM"
	description = "Two teams enter the arena. The team that eliminates all opponents wins the match."
	is_team_based = true
	has_rounds = false
	round_win_target = 1
	max_rounds = 1
	match_time_limit = 0.0
	respawn_delay = -1.0
	gold_per_round = 0
