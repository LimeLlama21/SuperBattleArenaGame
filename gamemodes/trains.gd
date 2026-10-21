class_name TrainsMode
extends GameMode

## Area cycle interval in seconds (every 2 minutes the trains move to the next area)
var area_cycle_interval: float = 120.0
## Transit interval in seconds between area departure and next area arrival
var transit_interval: float = 30.0

func _init() -> void:
	id = "trains"
	display_name = "Trains (3v3v3)"
	short_name = "Trains"
	description = "Three teams clash on static trains framing a rotating triangle map. Every two minutes, the trains depart, leaving behind anyone on the map. After 30 seconds of transit, the trains arrive at the next map."
	is_team_based = true
	team_count = 3
	has_rounds = false
	round_win_target = 1
	max_rounds = 1
	match_time_limit = 0.0
	respawn_delay = -1.0
	gold_per_round = 0
	has_zone = false
	has_battle_royale_zone = false

## Format HUD area timer string for Trains game mode (when at a map)
func format_area_timer(area_name: String, time_left: float) -> String:
	var mins = int(max(0.0, time_left)) / 60
	var secs = int(max(0.0, time_left)) % 60
	return "🚂 %s | ⏱ DEPARTURE IN: %02d:%02d" % [area_name.to_upper(), mins, secs]

## Format HUD transit timer string for Trains game mode (when in transit between maps)
func format_transit_timer(next_area_name: String, time_left: float) -> String:
	var mins = int(max(0.0, time_left)) / 60
	var secs = int(max(0.0, time_left)) % 60
	return "🚂 IN TRANSIT | ⏱ NEXT MAP (%s): %02d:%02d" % [next_area_name.to_upper(), mins, secs]
