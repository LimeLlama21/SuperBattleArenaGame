class_name GameModeManager
extends Node

## GameModeManager - Subsystem governing round progression, warmup timers,
## Best-of-5 score evaluation, sudden death ring convergence, and match outcomes.

signal round_started(round_number: int)
signal round_ended(winning_team: int, scores: Dictionary)
signal match_over(winning_team: int)
signal round_timer_updated(time_remaining: float)

enum RoundState {
	WARMUP,
	IN_PROGRESS,
	POST_ROUND,
	MATCH_OVER
}

var current_state: RoundState = RoundState.WARMUP
var current_round: int = 1
var max_rounds: int = 5
var rounds_to_win: int = 3

var team_scores: Dictionary = {1: 0, 2: 0, 3: 0}
var round_duration: float = 180.0
var warmup_duration: float = 5.0
var post_round_duration: float = 5.0

var round_timer: float = 0.0
var warmup_timer: float = 0.0
var post_round_timer: float = 0.0

var match_winner: int = -1
var main_game: Node = null

func _ready() -> void:
	if not main_game:
		var p = get_parent()
		if p and (p is Node3D or p.name == "Main"):
			main_game = p

func start_match() -> void:
	current_round = 1
	team_scores = {1: 0, 2: 0, 3: 0}
	match_winner = -1
	start_warmup()

func start_warmup() -> void:
	current_state = RoundState.WARMUP
	warmup_timer = warmup_duration
	print("GameModeManager: Starting warmup for Round %d" % current_round)

func start_round() -> void:
	current_state = RoundState.IN_PROGRESS
	round_timer = round_duration
	print("GameModeManager: Round %d started!" % current_round)
	round_started.emit(current_round)

func end_round(winning_team: int) -> void:
	current_state = RoundState.POST_ROUND
	post_round_timer = post_round_duration
	if team_scores.has(winning_team):
		team_scores[winning_team] += 1
	print("GameModeManager: Round %d won by Team %d! Scores: %s" % [current_round, winning_team, str(team_scores)])
	round_ended.emit(winning_team, team_scores)

	if team_scores.get(winning_team, 0) >= rounds_to_win or current_round >= max_rounds:
		end_match(winning_team)
	else:
		current_round += 1

func end_match(winning_team: int) -> void:
	current_state = RoundState.MATCH_OVER
	match_winner = winning_team
	print("GameModeManager: Match over! Winning Team: %d" % winning_team)
	match_over.emit(winning_team)

func _process(delta: float) -> void:
	match current_state:
		RoundState.WARMUP:
			if warmup_timer > 0.0:
				warmup_timer -= delta
				if warmup_timer <= 0.0:
					start_round()
		RoundState.IN_PROGRESS:
			if round_timer > 0.0:
				round_timer -= delta
				round_timer_updated.emit(round_timer)
				if round_timer <= 0.0:
					# Time ran out, check tiebreak or sudden death
					pass
		RoundState.POST_ROUND:
			if post_round_timer > 0.0:
				post_round_timer -= delta
				if post_round_timer <= 0.0 and current_state != RoundState.MATCH_OVER:
					start_warmup()
