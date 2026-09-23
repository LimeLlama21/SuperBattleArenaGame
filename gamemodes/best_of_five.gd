class_name BestOfFiveMode
extends GameMode

func _init() -> void:
	id = "bo5"
	display_name = "Best of Five (3v3v3)"
	short_name = "BO5"
	description = "Three teams battle across multiple rounds. First team to win 3 rounds claims ultimate victory! 100 gold awarded per round."
	is_team_based = true
	team_count = 3
	has_rounds = true
	round_win_target = 3
	max_rounds = 7
	match_time_limit = 0.0
	respawn_delay = -1.0
	gold_per_round = 100

## Check if any team has achieved the target round score (3) to win the match.
## Returns "TEAM 1", "TEAM 2", "TEAM 3", or empty string if match continues.
func check_match_winner(score_t1: int, score_t2: int, score_t3: int = 0) -> String:
	if score_t1 >= round_win_target:
		return "TEAM 1"
	elif score_t2 >= round_win_target:
		return "TEAM 2"
	elif score_t3 >= round_win_target:
		return "TEAM 3"
	return ""
