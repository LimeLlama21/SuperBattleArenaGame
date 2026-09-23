class_name TeamDeathmatchMode
extends GameMode

func _init() -> void:
	id = "tdm"
	display_name = "Team Deathmatch (3v3v3)"
	short_name = "3v3v3"
	description = "Three teams enter the arena in a 3v3v3 showdown. The last surviving team wins the match."
	is_team_based = true
	team_count = 3
	has_rounds = false
	round_win_target = 1
	max_rounds = 1
	match_time_limit = 0.0
	respawn_delay = -1.0
	gold_per_round = 0
