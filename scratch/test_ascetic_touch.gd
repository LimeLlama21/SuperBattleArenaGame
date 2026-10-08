extends SceneTree

const UpgradeTreesClass = preload("res://characters/leveling/upgrade_trees.gd")
const UpgradeMenuClass = preload("res://characters/leveling/upgrade_menu.gd")
const PokeScene = preload("res://characters/poke/poke.tscn")

func _init() -> void:
	print("--- BEGIN ASCETIC TOUCH TEST ---")

	# Test 1: UpgradeTrees Definition
	var tree = UpgradeTreesClass.get_tree("mortal")
	assert(tree.has("cunning"), "Must have cunning branch")
	var cunning_branch = tree["cunning"]
	assert(cunning_branch.size() == 3, "Cunning branch must have 3 tiers")

	var tier2 = cunning_branch[1]
	print("Tier 2 Cunning:", tier2)
	assert(tier2["id"] == "ascetic_touch", "Tier 2 id must be ascetic_touch")
	assert(tier2["name"] == "Ascetic Touch", "Tier 2 name must be Ascetic Touch")
	assert(tier2["tier"] == 2, "Tier 2 tier must be 2")
	print("✓ Test 1 Passed: UpgradeTrees definition for Ascetic Touch is correct")

	# Test 2: UpgradeMenu UI display and ordering
	var menu = UpgradeMenuClass.new()
	root.add_child(menu)
	menu._ready()
	menu.current_origin = "mortal"
	menu.refresh_menu()

	var name_boxes = menu.portrait_name_labels
	assert(name_boxes["cunning"][1].text == "Atalanta's Stride", "Tier 1 must show 'Atalanta\\'s Stride'")
	assert(name_boxes["cunning"][2].text == "Ascetic Touch", "Tier 2 must show 'Ascetic Touch'")
	assert(name_boxes["cunning"][3].text == "Hymn of the Underworld" or name_boxes["cunning"][3].text == "", "Tier 3 is Hymn of the Underworld")
	print("✓ Test 2 Passed: UpgradeMenu displays Atalanta's Stride (T1) and Ascetic Touch (T2)")

	# Test 3: Player setup and Sequential Progression
	var player = PokeScene.instantiate()
	player.name = "101"
	root.add_child(player)
	player._ready()
	menu.target_player = player

	# Try unlocking Tier 2 first (must fail since Tier 1 is locked)
	menu._on_upgrade_card_clicked("mortal", "cunning", 2, tier2)
	assert(menu.get_branch_tier("mortal", "cunning") == 0, "Tier 2 cannot unlock before Tier 1")
	assert(not player.has_upgrade("ascetic_touch"), "Player must not have ascetic_touch yet")

	# Unlock Tier 1 (Atalanta's Stride)
	var tier1 = cunning_branch[0]
	menu._on_upgrade_card_clicked("mortal", "cunning", 1, tier1)
	assert(menu.get_branch_tier("mortal", "cunning") == 1, "Tier 1 unlocked")
	assert(player.has_upgrade("atalantas_stride"), "Player has atalantas_stride")

	# Now unlock Tier 2 (Ascetic Touch)
	menu._on_upgrade_card_clicked("mortal", "cunning", 2, tier2)
	assert(menu.get_branch_tier("mortal", "cunning") == 2, "Tier 2 unlocked")
	assert(player.has_upgrade("ascetic_touch"), "Player has ascetic_touch")
	print("✓ Test 3 Passed: Sequential progression unlocks Ascetic Touch on player")

	# Test 4: Damage Types and Anti-Poke Armor Charge Bypass
	var target_dummy = PokeScene.instantiate()
	target_dummy.name = "102"
	root.add_child(target_dummy)
	target_dummy._ready()
	target_dummy.max_health = 200.0
	target_dummy.current_health = 200.0
	target_dummy.reset_armor_charges()
	assert(target_dummy.armor_charges == 2, "Dummy starts with 2 armor charges")

	# Standard projectile damage: should be absorbed by armor charges
	target_dummy.take_projectile_damage(40.0, 101, BasePlayer.ActionType.ATTACK, BasePlayer.DamageType.DAMAGE)
	assert(target_dummy.armor_charges == 1, "Standard projectile consumed 1 armor charge")
	assert(target_dummy.current_health == 200.0, "Standard projectile dealt 0 damage due to armor charge block")

	# True damage projectile: MUST ignore armor charges and traditional reduction
	target_dummy.take_projectile_damage(40.0, 101, BasePlayer.ActionType.ATTACK, BasePlayer.DamageType.TRUE_DAMAGE)
	assert(target_dummy.armor_charges == 1, "True damage did NOT consume or get blocked by armor charges")
	assert(target_dummy.current_health == 160.0, "True damage dealt full 40 damage ignoring anti-poke tool")

	# Test Damage Reduction bypass on True Damage:
	target_dummy.item_stats["armor"] = 50.0 # 50% damage reduction
	var initial_hp = target_dummy.current_health
	# Normal damage: 20 dmg reduced by 50% -> 10 dmg taken
	target_dummy.take_damage(20.0, 101, BasePlayer.ActionType.ATTACK, false, BasePlayer.DamageType.DAMAGE)
	assert(abs(target_dummy.current_health - (initial_hp - 10.0)) < 0.1, "Normal damage reduced by 50%")

	# True damage: 20 dmg ignores armor -> 20 dmg taken
	initial_hp = target_dummy.current_health
	target_dummy.take_damage(20.0, 101, BasePlayer.ActionType.ATTACK, false, BasePlayer.DamageType.TRUE_DAMAGE)
	assert(abs(target_dummy.current_health - (initial_hp - 20.0)) < 0.1, "True damage completely ignores armor/damage reduction")
	print("✓ Test 4 Passed: True damage ignores armor reduction and anti-poke armor charges")

	# Test 5: Spellthief Proc, 5% max HP True Damage, Mana Steal, and 10s Per-Target Cooldown
	var target_a = PokeScene.instantiate()
	target_a.name = "103"
	root.add_child(target_a)
	target_a._ready()
	target_a.max_health = 200.0
	target_a.current_health = 200.0
	target_a.max_mana = 100.0
	target_a.current_mana = 50.0

	player.max_mana = 100.0
	player.current_mana = 30.0

	assert(player.is_spellthief_ready_for_target(target_a) == true, "Spellthief ready for target A")

	# Player deals 20 base attack damage to Target A
	# Expect:
	# - Base damage: 20
	# - Spellthief proc deals 5% of 200 = 10 True Damage
	# - Total HP loss on Target A: 20 + 10 = 30 -> 170.0
	# - Mana stolen: 15.0 -> Target A mana: 35.0, Player mana: 45.0
	player.deal_damage(target_a, 20.0, BasePlayer.ActionType.ATTACK)

	print("Target A HP after hit 1:", target_a.current_health, "Mana:", target_a.current_mana)
	print("Player Mana after hit 1:", player.current_mana)
	assert(abs(target_a.current_health - 170.0) < 0.2, "Target A should take 20 base + 10 true damage = 30 total")
	assert(abs(target_a.current_mana - 35.0) < 0.2, "Target A lost 15 mana")
	assert(abs(player.current_mana - 45.0) < 0.2, "Player gained 15 mana")
	assert(player.is_spellthief_ready_for_target(target_a) == false, "Spellthief now on cooldown for Target A")

	# Immediate second hit on Target A (within 10s cooldown):
	# Expect only base damage (20), NO Spellthief proc (no extra true dmg, no extra mana steal)
	var hp_before_hit2 = target_a.current_health
	var mana_before_hit2 = player.current_mana
	player.deal_damage(target_a, 20.0, BasePlayer.ActionType.ATTACK)
	assert(abs(target_a.current_health - (hp_before_hit2 - 20.0)) < 0.2, "Hit 2 on Target A only dealt base damage")
	assert(player.current_mana == mana_before_hit2, "Hit 2 on Target A did not steal mana (on cooldown)")
	print("✓ Test 5 Passed: Spellthief proc dealt 5% True Damage and stole mana, respecting 10s cooldown")

	# Test 6: Independent Per-Target Cooldown on Target B
	var target_b = PokeScene.instantiate()
	target_b.name = "104"
	root.add_child(target_b)
	target_b._ready()
	target_b.max_health = 300.0
	target_b.current_health = 300.0
	target_b.max_mana = 100.0
	target_b.current_mana = 40.0

	assert(player.is_spellthief_ready_for_target(target_b) == true, "Target B has independent cooldown and is ready")

	# Hit Target B with 10 damage:
	# 5% of 300 max HP = 15 True Damage
	# Total dmg = 10 + 15 = 25 -> HP: 275.0
	# Mana stolen: 15 -> Target B: 25.0, Player: 45 + 15 = 60.0
	player.deal_damage(target_b, 10.0, BasePlayer.ActionType.ATTACK)
	print("Target B HP after hit 1:", target_b.current_health, "Mana:", target_b.current_mana)
	assert(abs(target_b.current_health - 275.0) < 0.2, "Target B took 10 base + 15 true dmg = 25 total")
	assert(abs(target_b.current_mana - 25.0) < 0.2, "Target B lost 15 mana")
	assert(abs(player.current_mana - 60.0) < 0.2, "Player gained 15 mana from Target B")
	assert(player.is_spellthief_ready_for_target(target_b) == false, "Target B is now on cooldown")
	print("✓ Test 6 Passed: Target B triggered independently with its own 5% max HP calculation and mana steal")

	# Test 7: Cooldown Expiry on Target A
	# Manually fast-forward Target A's cooldown in dictionary
	var target_a_id = target_a.get_instance_id()
	player.spellthief_target_cooldowns[target_a_id] -= 10.5 # past 10 seconds
	assert(player.is_spellthief_ready_for_target(target_a) == true, "Target A should be ready again after 10s")

	var hp_before_reset_hit = target_a.current_health
	var player_mana_before_reset_hit = player.current_mana
	player.deal_damage(target_a, 10.0, BasePlayer.ActionType.ATTACK)
	# 5% of 200 = 10 True Damage -> 20 total dmg
	assert(abs(target_a.current_health - (hp_before_reset_hit - 20.0)) < 0.2, "Target A triggered Spellthief again after cooldown expired")
	assert(abs(player.current_mana - (player_mana_before_reset_hit + 15.0)) < 0.2, "Player stole mana again after cooldown expired")
	print("✓ Test 7 Passed: Spellthief successfully triggers again after 10s cooldown expires")

	menu.queue_free()
	player.queue_free()
	target_dummy.queue_free()
	target_a.queue_free()
	target_b.queue_free()
	print("--- ALL ASCETIC TOUCH TESTS PASSED SUCCESSFULLY! ---")
	quit(0)
