class_name GameMode
extends RefCounted

## Unique identifier for the game mode (e.g., "tdm", "dm", "bo5")
var id: String = "tdm"

## Human-readable display name shown in UI
var display_name: String = "Team Deathmatch (TDM)"

## Short code or name for badges / labels
var short_name: String = "TDM"

## Description of rules and objectives
var description: String = "Eliminate all players on the opposing team to win the match."

## Whether players are partitioned into Team 1 vs Team 2
var is_team_based: bool = true

## Whether the match is divided into discrete rounds (e.g. Best of Five)
var has_rounds: bool = false

## Number of round wins required to win the entire match (if has_rounds is true)
var round_win_target: int = 1

## Maximum possible rounds in a match
var max_rounds: int = 1

## Timed match limit in seconds (0.0 means untimed / elimination)
var match_time_limit: float = 0.0

## Respawn delay in seconds (-1.0 means no respawns during a round/match)
var respawn_delay: float = -1.0

## Gold awarded to each player at the end of each round
var gold_per_round: int = 0

## Gold awarded for a kill
var gold_per_kill: int = 50

## Gold awarded for an assist
var gold_per_assist: int = 25

func _init() -> void:
	pass

## Check whether there is an insufficient player count to continue or start the match.
## Returns true if a deficit exists (e.g. fewer than 2 players in FFA, or one team empty).
func check_player_deficits(connected_players: Dictionary, is_peer_pending_disconnect_callable: Callable) -> bool:
	if not is_team_based:
		var active_count = 0
		for pid in connected_players.keys():
			if not is_peer_pending_disconnect_callable.call(int(pid)):
				active_count += 1
		if OS.is_debug_build() and active_count >= 1:
			return false
		return active_count < 2
	
	var t1_count = 0
	var t2_count = 0
	for pid in connected_players.keys():
		if is_peer_pending_disconnect_callable.call(int(pid)):
			continue
		var p = connected_players[pid]
		if p.get("team", 1) == 1:
			t1_count += 1
		elif p.get("team", 1) == 2:
			t2_count += 1
	return (t1_count == 0 or t2_count == 0)

## Evaluate match/round status from player entities.
## Returns Dictionary with:
##   - "over": bool (whether the round or match has concluded)
##   - "winner": String ("TEAM 1", "TEAM 2", "DRAW", or player winner name, or "" if undecided)
##   - "is_round_only": bool (true if this ends a round rather than the entire match)
func evaluate_combat_status(players_container: Node3D, connected_players: Dictionary) -> Dictionary:
	var result = {
		"over": false,
		"winner": "",
		"is_round_only": false
	}
	
	if not is_team_based:
		# FFA modes evaluate by timer or kill targets, not last-man-standing
		return result
	
	var total_t1 = 0
	var total_t2 = 0
	var alive_t1 = 0
	var alive_t2 = 0
	var alive_players: Array = []
	
	for p in players_container.get_children():
		if p is Node3D:
			var t = p.get("team_id")
			var dead = p.get("is_dead") == true or (p.get("current_health") != null and p.current_health <= 0.0)
			if t == 1:
				total_t1 += 1
				if not dead:
					alive_t1 += 1
					alive_players.append(p)
			elif t == 2:
				total_t2 += 1
				if not dead:
					alive_t2 += 1
					alive_players.append(p)
			else:
				if not dead:
					alive_players.append(p)
	
	if total_t1 > 0 and total_t2 > 0:
		if alive_t1 == 0 and alive_t2 == 0:
			result["over"] = true
			result["winner"] = "DRAW"
			result["is_round_only"] = has_rounds
		elif alive_t1 == 0 and alive_t2 > 0:
			result["over"] = true
			result["winner"] = "TEAM 2"
			result["is_round_only"] = has_rounds
		elif alive_t2 == 0 and alive_t1 > 0:
			result["over"] = true
			result["winner"] = "TEAM 1"
			result["is_round_only"] = has_rounds
	elif total_t1 > 0 or total_t2 > 0:
		var total_active = total_t1 + total_t2
		var total_alive = alive_t1 + alive_t2
		if total_alive == 0:
			result["over"] = true
			result["winner"] = "DRAW"
		elif total_active > 1 and total_alive <= 1:
			result["over"] = true
			if alive_players.size() == 1:
				var winner = alive_players[0]
				var winner_id = winner.name.to_int()
				var p_info = connected_players.get(winner_id, {})
				var p_name = p_info.get("name", "Player " + str(winner_id))
				var char_name = winner.get_display_name() if winner.has_method("get_display_name") else winner.get("display_name")
				if not char_name or str(char_name).is_empty():
					char_name = CharacterRegistry.get_display_name(p_info.get("character", "Hero"))
				result["winner"] = "%s (%s)" % [p_name, char_name]
			else:
				result["winner"] = "DRAW"
	
	return result

## Determine the winner of a timed FFA deathmatch
func evaluate_timed_winner(connected_players: Dictionary) -> String:
	var top_kills = -1
	var top_winner = "NOBODY"
	for pid in connected_players.keys():
		var k = connected_players[pid].get("kills", 0)
		if k > top_kills:
			top_kills = k
			var p_info = connected_players[pid]
			var p_name = p_info.get("name", "Player " + str(pid))
			top_winner = "%s (%d KILLS)" % [p_name, k]
	return top_winner

## Format match timer label
func format_timer(time_left: float) -> String:
	var mins = int(max(0.0, time_left)) / 60
	var secs = int(max(0.0, time_left)) % 60
	return "⏱ %s: %02d:%02d" % [display_name.to_upper(), mins, secs]

## Format scoreboard header string for round-based modes
func format_scoreboard_header(score_t1: int, score_t2: int) -> String:
	return "TEAM 1  [ %d ]   —   [ %d ]  TEAM 2" % [score_t1, score_t2]
