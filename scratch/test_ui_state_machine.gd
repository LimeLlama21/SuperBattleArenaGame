extends SceneTree

const UIStateMachineScript = preload("res://ui_state_machine.gd")
const BattleRoyaleZoneScript = preload("res://zones/battle_royale_zone.gd")

func _init() -> void:
	print("--- Running UI State Machine & Categorization Test Suite ---")
	
	test_state_machine_lifecycle()
	test_non_diegetic_ui_categorization()
	test_spatial_ui_categorization()
	test_diegetic_ui_categorization()
	test_unified_top_hud_coordination()
	test_battle_royale_zone_ui_hygiene()
	
	print("=== All UI State Machine Tests Passed Successfully! ===")
	quit(0)

func test_state_machine_lifecycle() -> void:
	print("1. Testing state machine lifecycle...")
	var uism = UIStateMachineScript.new()
	root.add_child(uism)
	
	assert(uism.get_current_state() == uism.State.MAIN_MENU, "Initial state should be MAIN_MENU")
	assert(uism.is_menu_active() == true, "Menu should be active in MAIN_MENU")
	assert(uism.is_in_match() == false, "Match should not be in progress in MAIN_MENU")
	
	# Transition to LOBBY
	uism.transition_to(uism.State.LOBBY)
	assert(uism.get_current_state() == uism.State.LOBBY, "Current state should be LOBBY")
	assert(uism.is_menu_active() == true, "Menu should be active in LOBBY")
	assert(uism.is_in_match() == false, "Match should not be in progress in LOBBY")
	
	# Transition to IN_MATCH
	uism.transition_to(uism.State.IN_MATCH)
	assert(uism.get_current_state() == uism.State.IN_MATCH, "Current state should be IN_MATCH")
	assert(uism.is_menu_active() == false, "Menu should not be active in IN_MATCH")
	assert(uism.is_in_match() == true, "Match should be in progress in IN_MATCH")
	
	# Transition to MATCH_OVER
	uism.transition_to(uism.State.MATCH_OVER)
	assert(uism.get_current_state() == uism.State.MATCH_OVER, "Current state should be MATCH_OVER")
	assert(uism.is_in_match() == false, "Match should not be in progress in MATCH_OVER")
	
	uism.queue_free()
	print("   ✓ State machine lifecycle passed!")

func test_non_diegetic_ui_categorization() -> void:
	print("2. Testing Non-Diegetic UI categorization...")
	var uism = UIStateMachineScript.new()
	root.add_child(uism)
	
	var menu_panel = Panel.new()
	var lobby_panel = Panel.new()
	var in_game_hud = Control.new()
	root.add_child(menu_panel)
	root.add_child(lobby_panel)
	root.add_child(in_game_hud)
	
	uism.register_element(menu_panel, uism.UICategory.NON_DIEGETIC, [uism.State.MAIN_MENU])
	uism.register_element(lobby_panel, uism.UICategory.NON_DIEGETIC, [uism.State.LOBBY])
	uism.register_element(in_game_hud, uism.UICategory.NON_DIEGETIC, [uism.State.IN_MATCH])
	
	# In MAIN_MENU: only menu_panel should be visible
	uism.transition_to(uism.State.MAIN_MENU)
	assert(menu_panel.visible == true, "menu_panel must be visible in MAIN_MENU")
	assert(lobby_panel.visible == false, "lobby_panel must be hidden in MAIN_MENU")
	assert(in_game_hud.visible == false, "in_game_hud must be hidden in MAIN_MENU")
	
	# In LOBBY: only lobby_panel should be visible
	uism.transition_to(uism.State.LOBBY)
	assert(menu_panel.visible == false, "menu_panel must be hidden in LOBBY")
	assert(lobby_panel.visible == true, "lobby_panel must be visible in LOBBY")
	assert(in_game_hud.visible == false, "in_game_hud must be hidden in LOBBY")
	
	# In IN_MATCH: only in_game_hud should be visible
	uism.transition_to(uism.State.IN_MATCH)
	assert(menu_panel.visible == false, "menu_panel must be hidden in IN_MATCH")
	assert(lobby_panel.visible == false, "lobby_panel must be hidden in IN_MATCH")
	assert(in_game_hud.visible == true, "in_game_hud must be visible in IN_MATCH")
	
	menu_panel.queue_free()
	lobby_panel.queue_free()
	in_game_hud.queue_free()
	uism.queue_free()
	print("   ✓ Non-Diegetic UI categorization passed!")

func test_spatial_ui_categorization() -> void:
	print("3. Testing Spatial UI categorization (Overhead HP & 3D Telegraphs)...")
	var uism = UIStateMachineScript.new()
	root.add_child(uism)
	
	var overhead_hp = Sprite3D.new()
	var ground_telegraph = MeshInstance3D.new()
	root.add_child(overhead_hp)
	root.add_child(ground_telegraph)
	
	uism.register_element(overhead_hp, uism.UICategory.SPATIAL, [uism.State.IN_MATCH])
	uism.register_element(ground_telegraph, uism.UICategory.SPATIAL, [uism.State.IN_MATCH])
	
	# In MAIN_MENU or LOBBY, spatial elements must be hidden
	uism.transition_to(uism.State.MAIN_MENU)
	assert(overhead_hp.visible == false, "Overhead HP must be hidden in MAIN_MENU")
	assert(ground_telegraph.visible == false, "Ground telegraph must be hidden in MAIN_MENU")
	
	uism.transition_to(uism.State.LOBBY)
	assert(overhead_hp.visible == false, "Overhead HP must be hidden in LOBBY")
	assert(ground_telegraph.visible == false, "Ground telegraph must be hidden in LOBBY")
	
	# In IN_MATCH, spatial elements become visible
	uism.transition_to(uism.State.IN_MATCH)
	assert(overhead_hp.visible == true, "Overhead HP must be visible in IN_MATCH")
	assert(ground_telegraph.visible == true, "Ground telegraph must be visible in IN_MATCH")
	
	overhead_hp.queue_free()
	ground_telegraph.queue_free()
	uism.queue_free()
	print("   ✓ Spatial UI categorization passed!")

func test_diegetic_ui_categorization() -> void:
	print("4. Testing Diegetic UI categorization (In-World Safe Zone & Physical Rings)...")
	var uism = UIStateMachineScript.new()
	root.add_child(uism)
	
	var storm_wall = MeshInstance3D.new()
	var ground_ring = MeshInstance3D.new()
	root.add_child(storm_wall)
	root.add_child(ground_ring)
	
	uism.register_element(storm_wall, uism.UICategory.DIEGETIC, [uism.State.IN_MATCH])
	uism.register_element(ground_ring, uism.UICategory.DIEGETIC, [uism.State.IN_MATCH])
	
	# In MAIN_MENU, diegetic elements must be inactive/hidden
	uism.transition_to(uism.State.MAIN_MENU)
	assert(storm_wall.visible == false, "Storm wall must be hidden in MAIN_MENU")
	assert(ground_ring.visible == false, "Ground ring must be hidden in MAIN_MENU")
	
	# In IN_MATCH, diegetic elements are active/visible
	uism.transition_to(uism.State.IN_MATCH)
	assert(storm_wall.visible == true, "Storm wall must be visible in IN_MATCH")
	assert(ground_ring.visible == true, "Ground ring must be visible in IN_MATCH")
	
	storm_wall.queue_free()
	ground_ring.queue_free()
	uism.queue_free()
	print("   ✓ Diegetic UI categorization passed!")

func test_unified_top_hud_coordination() -> void:
	print("5. Testing Unified Top-Center HUD coordination (No Clashing)...")
	var uism = UIStateMachineScript.new()
	root.add_child(uism)
	
	var top_container = VBoxContainer.new()
	var status_label = Label.new()
	var warn_container = VBoxContainer.new()
	var warn_label = Label.new()
	var arrow_label = Label.new()
	var map_label = Label.new()
	root.add_child(top_container)
	
	uism.setup_top_center_hud(top_container, status_label, warn_container, warn_label, arrow_label, map_label)
	
	# In MAIN_MENU: Top HUD must be hidden
	uism.transition_to(uism.State.MAIN_MENU)
	assert(top_container.visible == false, "Top HUD container must be hidden in MAIN_MENU")
	
	# In IN_MATCH: Top HUD container becomes active
	uism.transition_to(uism.State.IN_MATCH)
	assert(top_container.visible == true, "Top HUD container must be visible in IN_MATCH")
	
	# Update match status (e.g. from Zone or DM timer)
	uism.update_match_status("SAFE ZONE WAITING: 00:48", Color(0.4, 0.85, 1.0))
	assert(status_label.text == "SAFE ZONE WAITING: 00:48", "Status label text should match")
	assert(status_label.visible == true, "Status label should be visible")
	
	# Update Hazard Warning
	uism.update_hazard_warning(true, "⚠️ OUTSIDE SAFE ZONE (-10 HP/s) ⚠️", PI * 0.5)
	assert(warn_container.visible == true, "Hazard warning container should be visible")
	assert(warn_label.text == "⚠️ OUTSIDE SAFE ZONE (-10 HP/s) ⚠️", "Warning label text should match")
	assert(is_equal_approx(arrow_label.rotation, PI * 0.5), "Arrow rotation should match")
	
	top_container.queue_free()
	uism.queue_free()
	print("   ✓ Unified Top-Center HUD coordination passed!")

func test_battle_royale_zone_ui_hygiene() -> void:
	print("6. Testing BattleRoyaleZone UI hygiene (No Rogue CanvasLayers on boot)...")
	var zone_scene = load("res://zones/battle_royale_zone.tscn")
	assert(zone_scene != null, "Scene must exist")
	
	var main_mock = Node3D.new()
	main_mock.name = "Main"
	main_mock.set_meta("game_mode", "tdm")
	main_mock.set_meta("is_training_mode", false)
	# IMPORTANT: match_in_progress is FALSE initially (like on main menu)
	main_mock.set_meta("match_in_progress", false)
	root.add_child(main_mock)
	
	var zone = zone_scene.instantiate() as BattleRoyaleZone
	main_mock.add_child(zone)
	
	zone.evaluate_mode_activity()
	var hud_layer = zone.get_node_or_null("HUDLayer")
	assert(zone.current_state == BattleRoyaleZone.State.INACTIVE, "Zone must be INACTIVE when match is not in progress")
	assert(zone.visible == false, "Zone mesh must be invisible when match is not in progress")
	assert(zone.is_physics_processing() == false, "Zone physics processing must be disabled when match is not in progress")
	
	if hud_layer:
		assert(hud_layer.visible == false, "HUDLayer must be invisible when match is not in progress!")
	
	# When match starts (match_in_progress = true):
	main_mock.set_meta("match_in_progress", true)
	zone.evaluate_mode_activity()
	assert(zone.current_state != BattleRoyaleZone.State.INACTIVE, "Zone must activate when match is in progress")
	assert(zone.visible == true, "Zone must become visible when match is in progress")
	
	zone.queue_free()
	main_mock.queue_free()
	print("   ✓ BattleRoyaleZone UI hygiene passed!")
