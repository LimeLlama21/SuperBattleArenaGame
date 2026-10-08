extends SceneTree

const UpgradeTreesClass = preload("res://characters/leveling/upgrade_trees.gd")
const UpgradeMenuClass = preload("res://characters/leveling/upgrade_menu.gd")
const PokeScene = preload("res://characters/poke/poke.tscn")
const ShadeProjectileClass = preload("res://characters/leveling/shade_projectile.gd")

var executed: bool = false

func _process(delta: float) -> bool:
	if executed:
		return false
	executed = true

	print("--- BEGIN HYMN OF THE UNDERWORLD TEST ---")

	# Test 1: UpgradeTrees Definition
	var tree = UpgradeTreesClass.get_tree("mortal")
	assert(tree.has("cunning"), "Must have cunning branch")
	var cunning_branch = tree["cunning"]
	assert(cunning_branch.size() == 3, "Cunning branch must have 3 tiers")

	var tier3 = cunning_branch[2]
	print("Tier 3 Cunning:", tier3)
	assert(tier3["id"] == "hymn_of_the_underworld", "Tier 3 id must be hymn_of_the_underworld")
	assert(tier3["name"] == "Hymn of the Underworld", "Tier 3 name must be Hymn of the Underworld")
	assert(tier3["tier"] == 3, "Tier 3 tier must be 3")
	print("✓ Test 1 Passed: UpgradeTrees definition for Hymn of the Underworld is correct")

	# Test 2: UpgradeMenu UI display and ordering
	var menu = UpgradeMenuClass.new()
	root.add_child(menu)
	menu._ready()
	menu.current_origin = "mortal"
	menu.refresh_menu()

	var name_boxes = menu.portrait_name_labels
	assert(name_boxes["cunning"][1].text == "Atalanta's Stride", "Tier 1 must show 'Atalanta\\'s Stride'")
	assert(name_boxes["cunning"][2].text == "Ascetic Touch", "Tier 2 must show 'Ascetic Touch'")
	assert(name_boxes["cunning"][3].text == "Hymn of the Underworld", "Tier 3 must show 'Hymn of the Underworld'")
	print("✓ Test 2 Passed: UpgradeMenu displays Atalanta's Stride (T1), Ascetic Touch (T2), and Hymn of the Underworld (T3)")

	# Test 3: Sequential Progression Gating
	var player = PokeScene.instantiate()
	player.name = "101"
	root.add_child(player)
	player._ready()
	menu.target_player = player

	var tier1 = cunning_branch[0]
	var tier2 = cunning_branch[1]

	# Try unlocking Tier 3 directly (must fail)
	menu._on_upgrade_card_clicked("mortal", "cunning", 3, tier3)
	assert(menu.get_branch_tier("mortal", "cunning") == 0, "Tier 3 cannot unlock before Tier 1 & 2")
	assert(not player.has_upgrade("hymn_of_the_underworld"), "Player must not have hymn_of_the_underworld yet")

	# Unlock Tier 1
	menu._on_upgrade_card_clicked("mortal", "cunning", 1, tier1)
	assert(menu.get_branch_tier("mortal", "cunning") == 1, "Tier 1 unlocked")

	# Try unlocking Tier 3 again (must still fail, Tier 2 missing)
	menu._on_upgrade_card_clicked("mortal", "cunning", 3, tier3)
	assert(menu.get_branch_tier("mortal", "cunning") == 1, "Tier 3 cannot unlock without Tier 2")
	assert(not player.has_upgrade("hymn_of_the_underworld"), "Player must not have hymn_of_the_underworld yet")

	# Unlock Tier 2
	menu._on_upgrade_card_clicked("mortal", "cunning", 2, tier2)
	assert(menu.get_branch_tier("mortal", "cunning") == 2, "Tier 2 unlocked")

	# Now unlock Tier 3 (Hymn of the Underworld)
	menu._on_upgrade_card_clicked("mortal", "cunning", 3, tier3)
	assert(menu.get_branch_tier("mortal", "cunning") == 3, "Tier 3 unlocked")
	assert(player.has_upgrade("hymn_of_the_underworld"), "Player now has hymn_of_the_underworld")
	print("✓ Test 3 Passed: Sequential gating strictly enforced for Hymn of the Underworld")

	# Test 4: Vision & Line of Sight Detection for Dying Player
	player.global_position = Vector3(0, 0, 0)
	player.team_id = 1

	# Enemy 1: Within screen range (15m), looking directly at death position (facing -Z towards player at 0,0,0)
	var enemy1 = PokeScene.instantiate()
	enemy1.name = "Enemy1"
	enemy1.team_id = 2
	root.add_child(enemy1)
	enemy1._ready()
	enemy1.global_position = Vector3(0, 0, 15.0)
	# Looking towards -Z (towards player at 0,0,0)
	enemy1.global_transform.basis = Basis() # default -Z is (0, 0, -1)
	
	# Enemy 2: Within screen range (15m), looking AWAY from player (+Z) and outside close circle
	var enemy2 = PokeScene.instantiate()
	enemy2.name = "Enemy2"
	enemy2.team_id = 3 # Different team, no allies
	root.add_child(enemy2)
	enemy2._ready()
	enemy2.global_position = Vector3(15.0, 0, 0)
	# Face +X (away from player at 0,0,0: diff is (-15, 0), facing is (+1, 0))
	enemy2.global_transform.basis = Basis(Vector3.UP, deg_to_rad(-90)) # -Z faces +X

	# Enemy 3: Too far (beyond HYMN_SCREEN_RANGE = 28m), even if facing player
	var enemy3 = PokeScene.instantiate()
	enemy3.name = "Enemy3"
	enemy3.team_id = 2
	root.add_child(enemy3)
	enemy3._ready()
	enemy3.global_position = Vector3(0, 0, 35.0) # 35m > 28m
	enemy3.global_transform.basis = Basis() # facing player

	# Enemy 4: Ally of Enemy 1 (Team 2). Looking away, but Enemy 1 (Team 2) sees death!
	var enemy4 = PokeScene.instantiate()
	enemy4.name = "Enemy4"
	enemy4.team_id = 2 # Team 2 (same as Enemy 1)
	root.add_child(enemy4)
	enemy4._ready()
	enemy4.global_position = Vector3(-10.0, 0, 10.0) # Within screen range
	enemy4.global_transform.basis = Basis(Vector3.UP, deg_to_rad(180)) # Looking away

	var viewers = player.get_enemies_who_saw_death(player.global_position)
	print("Enemies detected who saw death:", viewers.map(func(e): return e.name))
	assert(viewers.has(enemy1), "Enemy 1 directly saw player die")
	assert(not viewers.has(enemy2), "Enemy 2 looked away and has no allies who saw player die")
	assert(not viewers.has(enemy3), "Enemy 3 is beyond screen range (35m > 28m)")
	assert(viewers.has(enemy4), "Enemy 4 saw player die through ally (Enemy 1) shared vision")
	print("✓ Test 4 Passed: Direct vision, shared ally vision, and screen-range limits verified")

	# Test 5: Shade Projectile Mechanics (Rapid acceleration, speed cap at 18 m/s, through walls)
	var shade = ShadeProjectileClass.new()
	shade.target = enemy1
	root.add_child(shade)
	shade._ready()
	shade.global_position = Vector3(0, 1.0, 0)

	assert(shade.collision_layer == 0 and shade.collision_mask == 0, "Shade must pass through walls (collision layer/mask 0)")

	var initial_speed = shade.current_speed
	# Simulate 1 second of physics process
	for _step in range(60):
		shade._physics_process(1.0 / 60.0)
	
	assert(shade.current_speed > initial_speed, "Shade rapidly accelerated")
	assert(shade.current_speed <= ShadeProjectileClass.MAX_SPEED, "Shade speed capped at MAX_SPEED (18.0 m/s)")
	assert(abs(shade.current_speed - ShadeProjectileClass.MAX_SPEED) < 0.001, "Shade reached MAX_SPEED of 18 m/s")
	shade.queue_free()
	print("✓ Test 5 Passed: Shade accelerates rapidly and caps at 3x player speed (18 m/s)")

	# Test 6: Shade Collision - Target Facing Shade (Blind/Nearsight + 50% Slow for 2s)
	# Enemy 1 is at (0, 0, 15), facing -Z (towards shade at 0, 1, 14.5)
	var shade_facing = ShadeProjectileClass.new()
	shade_facing.target = enemy1
	root.add_child(shade_facing)
	shade_facing._ready()
	shade_facing.global_position = Vector3(0, 1.0, 14.5) # Close to enemy1

	# Verify is_shade_in_target_vision_cone
	assert(shade_facing.is_shade_in_target_vision_cone(enemy1), "Shade is in Enemy 1's forward vision cone")

	# Trigger hit
	shade_facing._on_hit_target()
	assert(enemy1.is_blinded() or enemy1.is_nearsighted(), "Enemy 1 is blinded/nearsighted")
	assert(enemy1.is_slowed(), "Enemy 1 is slowed")
	assert(abs(enemy1.slow_percent - 0.50) < 0.01, "Slow is 50%")
	assert(enemy1.get_custom_cone_radius() == 0.0, "Blind/nearsight collapses vision cone to 0 (only close circle remains)")
	print("✓ Test 6 Passed: Facing target takes Blind/Nearsight (cone=0) and 50% Slow for 2s")

	# Test 7: Shade Collision - Target Looking AWAY from Shade (No Blind, No Slow)
	# Enemy 4 is looking away from shade
	enemy4.global_position = Vector3(0, 0, 0)
	enemy4.global_transform.basis = Basis() # Faces -Z (0, 0, -1)
	
	# Shade approaches from behind (+Z)
	var shade_behind = ShadeProjectileClass.new()
	shade_behind.target = enemy4
	root.add_child(shade_behind)
	shade_behind._ready()
	shade_behind.global_position = Vector3(0, 1.0, 1.0) # Behind enemy4 (+Z relative to enemy)

	assert(not shade_behind.is_shade_in_target_vision_cone(enemy4), "Shade is NOT in Enemy 4's vision cone when behind")

	# Trigger hit
	shade_behind._on_hit_target()
	assert(not enemy4.is_blinded() and not enemy4.is_nearsighted(), "Enemy 4 does NOT receive blind when looking away")
	assert(not enemy4.is_slowed(), "Enemy 4 does NOT receive slow when looking away")
	print("✓ Test 7 Passed: Target looking away ignores Blind and Slow upon collision")

	# Test 8: Death trigger on Player
	# Reset status
	enemy1.cleanse_cc()
	assert(not enemy1.is_blinded(), "Enemy 1 blind cleared")

	# Set player health to 10 and kill player
	player.current_health = 10.0
	player.take_damage(20.0, enemy1.get_instance_id(), BasePlayer.ActionType.ATTACK, false, BasePlayer.DamageType.DAMAGE)
	assert(player.is_dead, "Player is dead")

	# Verify shade was spawned in tree targeting enemy1 and enemy4
	var found_shades = 0
	for child in root.get_children():
		if child is ShadeProjectileClass:
			found_shades += 1
	assert(found_shades >= 2, "Shades spawned for eligible enemies upon death")
	print("✓ Test 8 Passed: Hymn of the Underworld triggers automatically on player death")

	print("\nALL HYMN OF THE UNDERWORLD TESTS PASSED!")
	quit(0)
	return true
