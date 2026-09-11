class_name BestOfFiveMode
extends GameMode

func _init() -> void:
	id = "bo5"
	display_name = "Best of Five"
	short_name = "BO5"
	description = "Two teams battle across multiple rounds. First team to win 3 rounds claims ultimate victory! 100 gold awarded per round."
	is_team_based = true
	has_rounds = true
	round_win_target = 3
	max_rounds = 5
	match_time_limit = 0.0
	respawn_delay = -1.0
	gold_per_round = 100

## Check if either team has achieved the target round score (3) to win the match.
## Returns "TEAM 1", "TEAM 2", or empty string if match continues.
func check_match_winner(score_t1: int, score_t2: int) -> String:
	if score_t1 >= round_win_target:
		return "TEAM 1"
	elif score_t2 >= round_win_target:
		return "TEAM 2"
	return ""
