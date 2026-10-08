extends SceneTree

const UpgradeTreesClass = preload("res://characters/leveling/upgrade_trees.gd")
const UpgradeMenuClass = preload("res://characters/leveling/upgrade_menu.gd")
const PokeScene = preload("res://characters/poke/poke.tscn")

func _init() -> void:
	print("--- BEGIN ATALANTA'S STRIDE TEST ---")
	
	# Test 1: UpgradeTrees definition
	var tree = UpgradeTreesClass.get_tree("mortal")
	assert(tree.has("cunning"), "Tree must have cunning branch")
	var cunning_branch = tree["cunning"]
	assert(cunning_branch.size() == 3, "Cunning branch must have 3 tiers")
	
	var tier1 = cunning_branch[0]
	print("Tier 1 Cunning:", tier1)
	assert(tier1["id"] == "atalantas_stride", "Tier 1 id must be atalantas_stride")
	assert(tier1["name"] == "Atalanta's Stride", "Tier 1 name must be Atalanta's Stride")
	assert(tier1["tier"] == 1, "Tier 1 tier must be 1")
	assert(tier1["description"].contains("dash"), "Description must mention dash")
	print("✓ Test 1 Passed: UpgradeTrees definition is correct")
	
	# Test 2: UpgradeMenu UI label and ordering
	var menu = UpgradeMenuClass.new()
	root.add_child(menu)
	menu._ready()
	menu.current_origin = "mortal"
	menu.refresh_menu()
	
	var name_boxes = menu.portrait_name_labels
	assert(name_boxes.has("cunning"), "Must have cunning labels")
	assert(name_boxes["cunning"].has(1), "Must have tier 1 cunning label")
	
	var cunning_t1_lbl = name_boxes["cunning"][1]
	print("Cunning Tier 1 label text:", cunning_t1_lbl.text)
	assert(cunning_t1_lbl.text == "Atalanta's Stride", "Cunning Tier 1 must show 'Atalanta\\'s Stride'")
	
	var cunning_t2_lbl = name_boxes["cunning"][2]
	print("Cunning Tier 2 label text:", cunning_t2_lbl.text)
	assert(cunning_t2_lbl.text == "Ascetic Touch", "Cunning Tier 2 must show 'Ascetic Touch'")
	
	var resilience_t1_lbl = name_boxes["resilience"][1]
	print("Resilience Tier 1 label text:", resilience_t1_lbl.text)
	assert(resilience_t1_lbl.text == "", "Resilience Tier 1 placeholder must be blank")
	print("✓ Test 2 Passed: UpgradeMenu displays 'Quick Feet' under tier 1 cunning portrait, others blank")
	
	# Test 3: Player setup and upgrade application
	var poke = PokeScene.instantiate()
	root.add_child(poke)
	poke._ready()
	
	var dash_ab = poke.get_ability_for_slot("SHIFT")
	assert(dash_ab != null, "Poke must have SHIFT ability")
	print("Initial dash max_charges:", dash_ab.max_charges, "current_charges:", dash_ab.current_charges, "cooldown:", dash_ab.cooldown)
	assert(dash_ab.max_charges == 1, "Initial max_charges must be 1")
	assert(dash_ab.current_charges == 1, "Initial current_charges must be 1")
	
	# Connect poke to menu
	menu.target_player = poke
	
	# Try clicking tier 2 first (should fail because tier 1 not unlocked)
	var t2_data = cunning_branch[1]
	menu._on_upgrade_card_clicked("mortal", "cunning", 2, t2_data)
	assert(menu.get_branch_tier("mortal", "cunning") == 0, "Tier 2 should not unlock before Tier 1")
	assert(not poke.has_upgrade("mortal_cunning_2"), "Player should not have Tier 2")
	print("✓ Test 3 Passed: Sequential tier locking works")
	
	# Now unlock Tier 1 (Quick Feet) via menu click
	menu._on_upgrade_card_clicked("mortal", "cunning", 1, tier1)
	assert(menu.get_branch_tier("mortal", "cunning") == 1, "Tier 1 should now be unlocked")
	assert(poke.has_upgrade("atalantas_stride"), "Player must have atalantas_stride upgrade")
	
	# Check dash charges after upgrade
	print("Upgraded dash max_charges:", dash_ab.max_charges, "current_charges:", dash_ab.current_charges)
	assert(dash_ab.max_charges == 2, "max_charges must increase by 1 to 2")
	assert(dash_ab.current_charges == 2, "current_charges must grant 1 immediately to 2")
	assert(dash_ab.recharge_time > 0.0, "recharge_time should fall back to cooldown")
	print("✓ Test 4 Passed: Quick Feet grants +1 max charge and +1 immediate charge")
	
	# Test 5: Dashing with Quick Feet grants decaying speed boost (+30% decaying over 2s)
	assert(poke.speed_boost_percent == 0.0, "Initial speed boost percent must be 0")
	poke.on_dash_performed()
	print("After dash 1 speed_boost_percent:", poke.speed_boost_percent, "timer:", poke.speed_boost_timer, "decaying:", poke.speed_boost_decaying)
	assert(abs(poke.speed_boost_percent - 0.30) < 0.01, "Speed boost must be +30% (0.30)")
	assert(abs(poke.speed_boost_timer - 2.0) < 0.01, "Speed boost duration must be 2.0s")
	assert(poke.speed_boost_decaying == true, "Speed boost decaying flag must be true")
	
	# Test decay over 1.0 second
	poke._process_status_timers(1.0)
	print("After 1.0s decay speed_boost_percent:", poke.speed_boost_percent, "timer:", poke.speed_boost_timer)
	assert(abs(poke.speed_boost_timer - 1.0) < 0.01, "Timer after 1s must be 1.0s")
	# Linear decay: at half duration (1.0 / 2.0 = 0.5), percent should be ~0.15 (+15%)
	assert(abs(poke.speed_boost_percent - 0.15) < 0.02, "Percent after 1s should be decaying to ~15%")
	
	# Test decay finish after another 1.1 second
	poke._process_status_timers(1.1)
	print("After expiration speed_boost_percent:", poke.speed_boost_percent, "timer:", poke.speed_boost_timer)
	assert(poke.speed_boost_percent == 0.0, "Speed boost should fully expire to 0")
	assert(poke.speed_boost_timer == 0.0, "Timer should be 0")
	assert(poke.speed_boost_decaying == false, "Decaying flag reset")
	print("✓ Test 5 Passed: Decaying speed boost operates correctly (+30% decaying over 2s)")
	
	# Test 6: Ability charge consumption and recharge
	# Cast dash charge 1
	dash_ab.consume_resources(poke)
	assert(dash_ab.current_charges == 1, "After 1 cast, charges must be 1")
	assert(dash_ab.can_cast(poke) == true, "Must be able to cast with 1 charge left")
	assert(dash_ab.current_cooldown == 0.0, "current_cooldown must be 0 while charges > 0")
	print("Charge 1 cast. Charges left:", dash_ab.current_charges, "recharge_timer:", dash_ab.recharge_timer)
	
	# Cast dash charge 2
	dash_ab.consume_resources(poke)
	assert(dash_ab.current_charges == 0, "After 2 casts, charges must be 0")
	assert(dash_ab.can_cast(poke) == false, "Cannot cast with 0 charges")
	assert(dash_ab.current_cooldown > 0.0, "current_cooldown > 0 when 0 charges")
	print("Charge 2 cast. Charges left:", dash_ab.current_charges, "current_cooldown:", dash_ab.current_cooldown)
	
	# Advance time by recharge duration
	var recharge_needed = dash_ab.recharge_timer
	dash_ab.process_lifecycle(recharge_needed + 0.05)
	assert(dash_ab.current_charges == 1, "Should recharge 1 charge")
	assert(dash_ab.can_cast(poke) == true, "Can cast again with 1 charge restored")
	print("Recharged 1 charge. Current charges:", dash_ab.current_charges)
	
	# Advance time for 2nd charge
	dash_ab.process_lifecycle(dash_ab.recharge_time + 0.05)
	assert(dash_ab.current_charges == 2, "Should recharge back to 2 max charges")
	print("Recharged to full:", dash_ab.current_charges)
	print("✓ Test 6 Passed: Charges consume and recharge back to max charges without hindrance")
	
	menu.queue_free()
	poke.queue_free()
	print("--- ALL ATALANTA'S STRIDE TESTS PASSED SUCCESSFULLY! ---")
	quit(0)
