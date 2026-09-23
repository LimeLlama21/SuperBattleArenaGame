extends SceneTree

func _init() -> void:
	print("--- BEGIN 3v3v3 GAME MODE VERIFICATION ---")
	
	# 1. Test GameModes & TeamDeathmatchMode configuration
	var tdm = GameModes.get_mode("tdm")
	assert(tdm != null, "TDM mode must exist")
	assert(tdm.is_team_based, "TDM mode must be team based")
	assert(tdm.team_count == 3, "TDM mode must have team_count == 3 (got %d)" % tdm.team_count)
	assert("3v3v3" in tdm.display_name, "TDM display_name should mention 3v3v3 (got %s)" % tdm.display_name)
	print("✓ TDM mode properties verified: %s, team_count: %d" % [tdm.display_name, tdm.team_count])
	
	# 2. Test GameModes UI options
	var ui_opts = GameModes.get_ui_options()
	assert(ui_opts.size() >= 3, "Expected at least 3 UI game mode options")
	assert("3v3v3" in ui_opts[0]["label"], "Primary game mode UI option label should mention 3v3v3 (got %s)" % ui_opts[0]["label"])
	print("✓ UI options verified: %s" % ui_opts[0]["label"])
	
	# 3. Test BestOfFiveMode 3-team support
	var bo5 = GameModes.get_mode("bo5") as BestOfFiveMode
	assert(bo5 != null, "BO5 mode must exist")
	assert(bo5.team_count == 3, "BO5 mode must have team_count == 3")
	assert(bo5.check_match_winner(3, 1, 0) == "TEAM 1", "Team 1 should win at 3")
	assert(bo5.check_match_winner(1, 3, 2) == "TEAM 2", "Team 2 should win at 3")
	assert(bo5.check_match_winner(2, 1, 3) == "TEAM 3", "Team 3 should win at 3")
	assert(bo5.check_match_winner(2, 2, 2) == "", "No winner yet when all are at 2")
	print("✓ BestOfFiveMode 3-team win conditions verified")
	
	# 4. Test evaluate_combat_status with 3 teams
	var players_root = Node3D.new()
	var dummy_callable = func(pid: int): return false
	
	# Create mock players: 1 on Team 1, 1 on Team 2, 1 on Team 3
	var p1 = Node3D.new()
	p1.name = "1"
	p1.set("team_id", 1)
	p1.set("is_dead", false)
	players_root.add_child(p1)
	
	var p2 = Node3D.new()
	p2.name = "2"
	p2.set("team_id", 2)
	p2.set("is_dead", false)
	players_root.add_child(p2)
	
	var p3 = Node3D.new()
	p3.name = "3"
	p3.set("team_id", 3)
	p3.set("is_dead", false)
	players_root.add_child(p3)
	
	var conn_players = {
		1: {"team": 1, "name": "Alpha"},
		2: {"team": 2, "name": "Bravo"},
		3: {"team": 3, "name": "Charlie"}
	}
	
	# All 3 alive -> match not over
	var eval_ongoing = tdm.evaluate_combat_status(players_root, conn_players)
	assert(not eval_ongoing["over"], "Match should not be over when all 3 teams are alive")
	
	# Team 2 dies -> match still not over (Team 1 and Team 3 still alive)
	p2.set("is_dead", true)
	var eval_2teams = tdm.evaluate_combat_status(players_root, conn_players)
	assert(not eval_2teams["over"], "Match should not be over when 2 teams are still alive")
	
	# Team 3 dies -> Team 1 is sole survivor -> Team 1 wins
	p3.set("is_dead", true)
	var eval_t1_wins = tdm.evaluate_combat_status(players_root, conn_players)
	assert(eval_t1_wins["over"], "Match should be over when only Team 1 survives")
	assert(eval_t1_wins["winner"] == "TEAM 1", "Winner should be TEAM 1 (got %s)" % eval_t1_wins["winner"])
	
	# Reset: Team 3 alive, Team 1 and 2 dead -> Team 3 wins
	p1.set("is_dead", true)
	p3.set("is_dead", false)
	var eval_t3_wins = tdm.evaluate_combat_status(players_root, conn_players)
	assert(eval_t3_wins["over"], "Match should be over when only Team 3 survives")
	assert(eval_t3_wins["winner"] == "TEAM 3", "Winner should be TEAM 3 (got %s)" % eval_t3_wins["winner"])
	
	# All dead -> DRAW
	p3.set("is_dead", true)
	var eval_draw = tdm.evaluate_combat_status(players_root, conn_players)
	assert(eval_draw["over"], "Match should be over when all teams are dead")
	assert(eval_draw["winner"] == "DRAW", "Result should be DRAW (got %s)" % eval_draw["winner"])
	print("✓ 3-team combat evaluation verified (elimination and draw)")
	
	# 5. Test check_player_deficits
	# Missing team 3
	var conn_2teams = {
		1: {"team": 1},
		2: {"team": 2}
	}
	assert(tdm.check_player_deficits(conn_2teams, dummy_callable) == true, "Deficit should exist when Team 3 has no players")
	assert(tdm.check_player_deficits(conn_players, dummy_callable) == false, "No deficit when all 3 teams have players")
	print("✓ 3-team player deficits check verified")
	
	# 6. Test scoreboard header formatting
	var sb_header = tdm.format_scoreboard_header(2, 1, 3)
	assert("TEAM 1 [ 2 ]" in sb_header and "TEAM 2 [ 1 ]" in sb_header and "TEAM 3 [ 3 ]" in sb_header, "Scoreboard header should display all 3 teams (got %s)" % sb_header)
	print("✓ Scoreboard header verified: %s" % sb_header)
	
	# 7. Test main scene instantiation and nodes
	var main_scene = load("res://main.tscn")
	assert(main_scene != null, "main.tscn must be loadable")
	var main_instance = main_scene.instantiate()
	assert(main_instance != null, "main.tscn must instantiate")
	root.add_child(main_instance)
	
	# Check SpawnPoints
	var spawn_points = main_instance.get_node_or_null("SpawnPoints")
	assert(spawn_points != null, "SpawnPoints node must exist")
	var t1_spawns = spawn_points.get_node_or_null("Team1_Spawns")
	var t2_spawns = spawn_points.get_node_or_null("Team2_Spawns")
	var t3_spawns = spawn_points.get_node_or_null("Team3_Spawns")
	assert(t1_spawns != null and t1_spawns.get_child_count() == 3, "Team1_Spawns must have 3 markers")
	assert(t2_spawns != null and t2_spawns.get_child_count() == 3, "Team2_Spawns must have 3 markers")
	assert(t3_spawns != null and t3_spawns.get_child_count() == 3, "Team3_Spawns must have 3 markers")
	print("✓ All 3 team spawn nodes verified with 3 markers each")
	
	# Check Lobby Slots
	assert(main_instance.t1_slots.size() == 3, "t1_slots must have 3 buttons")
	assert(main_instance.t2_slots.size() == 3, "t2_slots must have 3 buttons")
	assert(main_instance.t3_slots.size() == 3, "t3_slots must have 3 buttons")
	print("✓ Lobby slot arrays verified (3 slots per team, 9 total)")
	
	# Check map spawn locations helper
	var all_spawns = main_instance.get_all_spawn_positions()
	assert(all_spawns.size() == 9, "get_all_spawn_positions should return 9 spawns (got %d)" % all_spawns.size())
	print("✓ get_all_spawn_positions returned 9 spawn vectors")
	
	print("\n=== ALL 3v3v3 VERIFICATIONS PASSED SUCCESSFULLY! ===")
	quit(0)
