extends SceneTree

const MainScene = preload("res://main.tscn")
const CharacterRegistry = preload("res://characters/character_registry.gd")
const GameModes = preload("res://gamemodes/gamemodes.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	print("--- BEGINNING DEATHMATCH RESPAWN TESTS ---")

	test_deathmatch_mode_config()
	await test_main_spawn_positions()
	await test_player_death_and_respawn()

	print("--- ALL DEATHMATCH RESPAWN TESTS PASSED! ---")
	quit(0)

func test_deathmatch_mode_config() -> void:
	print("Testing Deathmatch Game Mode Configuration...")
	var dm = GameModes.get_mode("dm")
	assert(dm != null, "Deathmatch mode should exist in GameModes")
	assert(dm.respawn_delay == 5.0, "Deathmatch respawn delay should be 5.0s, got %f" % dm.respawn_delay)
	assert(dm.is_team_based == false, "Deathmatch should be Free For All (not team based)")
	print("✓ Deathmatch mode configuration verified (5.0s respawns, FFA).")

func test_main_spawn_positions() -> void:
	print("Testing Main Spawn Position Gathering...")
	var main_instance = MainScene.instantiate()
	main_instance.name = "Main"
	root.add_child(main_instance)
	current_scene = main_instance
	await process_frame

	main_instance.game_mode = "dm"
	var all_spawns = main_instance.get_all_spawn_positions()
	assert(all_spawns.size() >= 10, "Expected at least 10 spawn points, got %d" % all_spawns.size())

	for sp in all_spawns:
		assert(sp != Vector3.ZERO, "Spawn position should never be Vector3.ZERO! Got: %s" % str(sp))
		# Ensure spawns are at the expected perimeter positions (around x = -24 or +24)
		assert(abs(sp.x) >= 20.0, "Spawn points should be along arena perimeter (|x| >= 20), got %s" % str(sp))

	# Test get_respawn_position
	var p_dummy = Node3D.new()
	p_dummy.name = "DummyPlayer"
	main_instance.players_container.add_child(p_dummy)
	p_dummy.global_position = Vector3(24.0, 0.1, 0.0)

	var respawn_pos = main_instance.get_respawn_position(p_dummy)
	assert(respawn_pos != Vector3.ZERO, "get_respawn_position should never return Vector3.ZERO")
	assert(abs(respawn_pos.x) >= 20.0, "get_respawn_position should be along arena perimeter (|x| >= 20)")

	main_instance.queue_free()
	await process_frame
	print("✓ Main spawn position gathering verified (10 valid perimeter markers, non-zero).")

func test_player_death_and_respawn() -> void:
	print("Testing Player Death, Countdown, and Respawn State...")
	var main_instance = MainScene.instantiate()
	main_instance.name = "Main"
	root.add_child(main_instance)
	current_scene = main_instance
	await process_frame

	main_instance.game_mode = "dm"
	main_instance.is_training_mode = false
	main_instance.match_in_progress = true

	# Create player instance via CharacterRegistry
	var player = CharacterRegistry.create_player_instance("poke")
	player.name = "1"
	main_instance.players_container.add_child(player)
	player.global_position = Vector3(0.0, 0.1, 0.0)
	await process_frame

	assert(player.is_dead == false, "Player should start alive")
	assert(player.current_health == player.max_health, "Player should start with max health")
	assert(player.current_mana == player.max_mana, "Player should start with max mana")

	# Damage player to death
	player.current_mana = 20.0
	player.take_damage(9999.0)
	assert(player.is_dead == true, "Player should be dead after lethal damage")
	assert(player.visible == false, "Dead player should be invisible")
	assert(player.respawn_countdown == 5.0, "respawn_countdown should be set to mode delay (5.0s), got %f" % player.respawn_countdown)

	# Simulate spectator delta processing
	player._process_spectator(1.5)
	assert(is_equal_approx(player.respawn_countdown, 3.5), "respawn_countdown should decrease by delta, expected 3.5, got %f" % player.respawn_countdown)
	if player.spectator_label:
		assert("RESPAWNING IN" in player.spectator_label.text, "Spectator label should display RESPAWNING IN countdown")

	# Execute respawn
	var test_target_spawn = Vector3(-24.0, 0.1, 5.0)
	player.respawn(test_target_spawn)
	await process_frame

	assert(player.is_dead == false, "Player should be alive after respawn")
	assert(player.visible == true, "Respawned player should be visible")
	assert(player.current_health == player.max_health, "Respawned player should have full health")
	assert(player.current_mana == player.max_mana, "Respawned player should have full mana")
	assert(player.current_shield == 0.0, "Respawned player should have shield reset")
	assert(player.respawn_countdown == 0.0, "respawn_countdown should be reset to 0")
	assert(player.is_invulnerable() == true, "Respawned player should have spawn protection invulnerability")
	assert(player.global_position.distance_to(test_target_spawn) < 0.1, "Player should be relocated to target spawn position, got: %s" % str(player.global_position))
	assert(player.velocity == Vector3.ZERO, "Velocity should be zero on respawn")

	main_instance.queue_free()
	await process_frame
	print("✓ Player death, countdown, and respawn state restoration verified.")
