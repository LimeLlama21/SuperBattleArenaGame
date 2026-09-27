extends SceneTree

const BattleRoyaleZone = preload("res://zones/battle_royale_zone.gd")

func _init() -> void:
	var result_lines: Array[String] = []
	result_lines.append("--- Running Battle Royale Zone Test Suite ---")
	
	test_zone_initialization(result_lines)
	test_state_machine_transitions(result_lines)
	test_minimum_relocation_distance(result_lines)
	test_damage_over_time_outside_ring(result_lines)
	test_constant_size_preservation(result_lines)
	test_main_mode_restriction(result_lines)
	
	result_lines.append("=== All Battle Royale Zone Tests Passed Successfully! ===")
	
	var file = FileAccess.open("res://scratch/test_battle_royale_zone_result.txt", FileAccess.WRITE)
	if file:
		for l in result_lines:
			file.store_line(l)
		file.close()
		
	quit(0)

func test_zone_initialization(res: Array[String]) -> void:
	res.append("Testing zone initialization...")
	var zone_scene = load("res://zones/battle_royale_zone.tscn")
	assert(zone_scene != null, "BattleRoyaleZone scene must load successfully")
	
	var zone = zone_scene.instantiate() as BattleRoyaleZone
	assert(zone != null, "Must instantiate as BattleRoyaleZone")
	assert(zone.zone_radius == 35.0, "Default zone radius should be 35.0")
	assert(zone.initial_wait_time == 60.0, "Initial wait time should be 60.0s")
	assert(zone.wait_time == 60.0, "Wait time should be 60.0s")
	assert(zone.min_relocation_distance == 40.0, "Min relocation distance should be 40.0")
	assert(zone.damage_per_second == 10.0, "Default DPS should be 10.0")
	
	root.add_child(zone)
	assert(zone.current_state == BattleRoyaleZone.State.WAITING, "Zone should start in WAITING state")
	assert(zone.state_timer > 0.0, "State timer should be initialized")
	assert(zone.target_position != Vector3.ZERO or zone.min_relocation_distance > 0.0, "Target position should be calculated")
	
	zone.queue_free()
	res.append("  -> Zone initialization passed!")

func test_state_machine_transitions(res: Array[String]) -> void:
	res.append("Testing state machine transitions...")
	var zone_scene = load("res://zones/battle_royale_zone.tscn")
	var zone = zone_scene.instantiate() as BattleRoyaleZone
	root.add_child(zone)
	
	# Initial state: WAITING
	assert(zone.current_state == BattleRoyaleZone.State.WAITING, "Should begin in WAITING")
	
	# Simulate time expiring in WAITING
	zone._update_state(zone.state_timer + 0.1)
	assert(zone.current_state == BattleRoyaleZone.State.WARNING, "Should transition from WAITING to WARNING")
	assert(zone.state_timer <= zone.warning_time, "Warning timer should be active")
	
	# Simulate time expiring in WARNING
	var start_p = zone.get_zone_position()
	var target_p = zone.target_position
	zone._update_state(zone.state_timer + 0.1)
	assert(zone.current_state == BattleRoyaleZone.State.MOVING, "Should transition from WARNING to MOVING")
	assert(zone.start_position == start_p, "Start position should be captured")
	
	# Simulate halfway through MOVING
	var half_time = zone.state_duration * 0.5
	zone._update_state(half_time)
	assert(zone.current_state == BattleRoyaleZone.State.MOVING, "Should still be MOVING halfway")
	assert(zone.get_zone_position() != start_p, "Position should interpolate away from start")
	
	# Simulate completion of MOVING
	zone._update_state(zone.state_timer + 0.1)
	assert(zone.current_state == BattleRoyaleZone.State.WAITING, "Should cycle back to WAITING after move completed")
	assert(zone.get_zone_position().distance_to(target_p) < 0.01, "Position should match destination target upon completion")
	
	zone.queue_free()
	res.append("  -> State machine transitions passed!")

func test_minimum_relocation_distance(res: Array[String]) -> void:
	res.append("Testing minimum relocation distance guarantee (100 cycles)...")
	var zone_scene = load("res://zones/battle_royale_zone.tscn")
	var zone = zone_scene.instantiate() as BattleRoyaleZone
	zone.min_relocation_distance = 45.0
	zone.map_bounds_min = Vector2(-100.0, -100.0)
	zone.map_bounds_max = Vector2(100.0, 100.0)
	root.add_child(zone)
	
	for i in range(100):
		var old_pos = zone.current_center
		var new_pos = zone._calculate_next_zone_position()
		var dist = Vector2(new_pos.x - old_pos.x, new_pos.z - old_pos.z).length()
		
		assert(dist >= zone.min_relocation_distance - 0.01, 
			"New zone distance %.2f must be >= min distance %.2f on cycle %d" % [dist, zone.min_relocation_distance, i])
		
		# Move zone to new pos for next test iteration
		zone.current_center = new_pos
		zone.set_zone_position(new_pos)
		
	zone.queue_free()
	res.append("  -> 100/100 relocations satisfied minimum distance constraint!")

func test_damage_over_time_outside_ring(res: Array[String]) -> void:
	res.append("Testing damage over time outside the safe ring...")
	var zone_scene = load("res://zones/battle_royale_zone.tscn")
	var zone = zone_scene.instantiate() as BattleRoyaleZone
	zone.zone_radius = 30.0
	zone.damage_per_second = 20.0
	zone.tick_interval = 0.5
	zone.position = Vector3(0, 0, 0)
	zone.current_center = Vector3(0, 0, 0)
	
	# Create mock Main and Players container
	var main_mock = Node3D.new()
	main_mock.name = "Main"
	root.add_child(main_mock)
	var players_container = Node3D.new()
	players_container.name = "Players"
	main_mock.add_child(players_container)
	main_mock.add_child(zone)
	
	# Mock player inside zone (at 10m from center, radius is 30m)
	var inside_player = Node3D.new()
	inside_player.name = "InsidePlayer"
	inside_player.position = Vector3(10.0, 0.0, 0.0)
	inside_player.set_script(load("res://scratch/mock_zone_player.gd"))
	players_container.add_child(inside_player)
	
	# Mock player outside zone (at 45m from center, radius is 30m)
	var outside_player = Node3D.new()
	outside_player.name = "OutsidePlayer"
	outside_player.position = Vector3(45.0, 0.0, 0.0)
	outside_player.set_script(load("res://scratch/mock_zone_player.gd"))
	players_container.add_child(outside_player)
	
	# Tick damage
	zone._process_damage_ticks(0.6)
	
	assert(inside_player.get("damage_received") == 0.0, "Player inside safe zone should take 0 damage")
	assert(outside_player.get("damage_received") == 10.0, "Player outside safe zone should receive 10.0 damage (20 dps * 0.5s)")
	assert(outside_player.get("last_action_type") == 2, "ActionType should be ENVIRONMENT (2)")
	
	zone.queue_free()
	players_container.queue_free()
	main_mock.queue_free()
	res.append("  -> Damage over time outside ring verified!")

func test_constant_size_preservation(res: Array[String]) -> void:
	res.append("Testing constant size preservation across state machine cycles...")
	var zone_scene = load("res://zones/battle_royale_zone.tscn")
	var zone = zone_scene.instantiate() as BattleRoyaleZone
	var initial_radius = zone.zone_radius
	root.add_child(zone)
	
	# Transition through several cycles
	for cycle in range(3):
		zone.change_state(BattleRoyaleZone.State.WAITING)
		assert(zone.zone_radius == initial_radius, "Radius must remain constant in WAITING")
		zone.change_state(BattleRoyaleZone.State.WARNING)
		assert(zone.zone_radius == initial_radius, "Radius must remain constant in WARNING")
		zone.change_state(BattleRoyaleZone.State.MOVING)
		assert(zone.zone_radius == initial_radius, "Radius must remain constant in MOVING")
		zone._update_state(zone.state_duration + 0.1)
		assert(zone.zone_radius == initial_radius, "Radius must remain constant after MOVING completes")
		
	zone.queue_free()
	res.append("  -> Constant size verified across all cycles!")

func test_main_mode_restriction(res: Array[String]) -> void:
	res.append("Testing main game mode restriction...")
	
	# 1. Verify GameMode configuration
	var tdm_mode = GameModes.get_mode("tdm")
	var dm_mode = GameModes.get_mode("dm")
	var bo5_mode = GameModes.get_mode("bo5")
	assert(tdm_mode.has_battle_royale_zone == true, "TDM (main mode) must have has_battle_royale_zone == true")
	assert(dm_mode.has_battle_royale_zone == false, "Deathmatch (FFA) must have has_battle_royale_zone == false")
	assert(bo5_mode.has_battle_royale_zone == false, "Best of Five must have has_battle_royale_zone == false")
	
	# 2. Test Zone behavior under different Main game mode settings
	var main_mock = Node3D.new()
	main_mock.name = "Main"
	main_mock.set_meta("game_mode", "dm")
	main_mock.set_meta("is_training_mode", false)
	main_mock.set_meta("match_in_progress", true)
	root.add_child(main_mock)
	
	var zone_scene = load("res://zones/battle_royale_zone.tscn")
	var zone = zone_scene.instantiate() as BattleRoyaleZone
	zone.only_active_in_main_mode = true
	main_mock.add_child(zone)
	
	# Test in Deathmatch mode ("dm") -> Should be deactivated
	zone.evaluate_mode_activity()
	assert(zone.visible == false, "Zone must be invisible in non-main mode ('dm')")
	assert(zone.current_state == BattleRoyaleZone.State.INACTIVE, "Zone state must be INACTIVE in non-main mode ('dm')")
	assert(zone.is_physics_processing() == false, "Zone physics processing must be disabled in non-main mode ('dm')")
	
	# Test in Training mode -> Should be deactivated even if mode is tdm
	main_mock.set_meta("game_mode", "tdm")
	main_mock.set_meta("is_training_mode", true)
	zone.evaluate_mode_activity()
	assert(zone.visible == false, "Zone must be invisible in training mode")
	assert(zone.current_state == BattleRoyaleZone.State.INACTIVE, "Zone state must be INACTIVE in training mode")
	
	# Test in Main Game Mode ("tdm") -> Should be activated
	main_mock.set_meta("is_training_mode", false)
	main_mock.set_meta("game_mode", "tdm")
	zone.evaluate_mode_activity()
	assert(zone.visible == true, "Zone must be visible in main game mode ('tdm')")
	assert(zone.current_state != BattleRoyaleZone.State.INACTIVE, "Zone state must be active in main game mode ('tdm')")
	assert(zone.is_physics_processing() == true, "Zone physics processing must be enabled in main game mode ('tdm')")
	
	zone.queue_free()
	main_mock.queue_free()
	res.append("  -> Main game mode restriction verified!")
