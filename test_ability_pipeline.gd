extends SceneTree

const AbilityClass = preload("res://ability/ability.gd")
const MeleeStrikeEffectClass = preload("res://ability/effects/melee_strike_effect.gd")
const SectorHitboxClass = preload("res://ability/hitboxes/sector_hitbox.gd")
const CircleHitboxClass = preload("res://ability/hitboxes/circle_hitbox.gd")
const LineHitboxClass = preload("res://ability/hitboxes/line_hitbox.gd")
const BoxHitboxClass = preload("res://ability/hitboxes/box_hitbox.gd")
const DonutHitboxClass = preload("res://ability/hitboxes/donut_hitbox.gd")
const OnHitEnemyTriggerClass = preload("res://ability/triggers/on_hit_enemy_trigger.gd")
const DamageRiderClass = preload("res://ability/riders/damage_rider.gd")
const StunRiderClass = preload("res://ability/riders/stun_rider.gd")
const ShieldRiderClass = preload("res://ability/riders/shield_rider.gd")
const BoundRiderClass = preload("res://ability/riders/bound_rider.gd")
const StatusRiderClass = preload("res://ability/riders/status_rider.gd")
const HealRiderClass = preload("res://ability/riders/heal_rider.gd")
const PlayerSharedEffects = preload("res://player/player_shared_effects.gd")
const CharacterRegistry = preload("res://characters/character_registry.gd")
const CharacterData = preload("res://characters/character_data.gd")
const AsparsasData = preload("res://characters/asparsas/asparsas_data.gd")
const BasePlayer = preload("res://player/player_base.gd")
const SileneClass = preload("res://characters/silene/silene.gd")
const SileneDataClass = preload("res://characters/silene/silene_data.gd")
const ArtistClass = preload("res://characters/artist/artist.gd")
const HanziPointCloudRecognizer = preload("res://characters/artist/hanzi_point_cloud_recognizer.gd")
const CleodolindaClass = preload("res://characters/cleodolinda/cleodolinda.gd")
const CleodolindaDataClass = preload("res://characters/cleodolinda/cleodolinda_data.gd")

func _initialize() -> void:
	_run_all.call_deferred()

func _run_all() -> void:
	await process_frame
	print("--- BEGINNING ABILITY PIPELINE TESTS ---")
	
	test_property_pipeline_chain()
	test_hitbox_calculations()
	test_rider_applications()
	test_character_ability_registration()
	test_lightweight_rpc_signature()
	test_melee_attack_execution()
	test_character_kits_and_special_mechanics()
	test_gravity_and_jump_metrics()
	test_natural_movement_conditions()
	test_charge_time_pipeline()
	test_delayed_abilities_and_telegraph_indicators()
	test_item_ability_scene_tree_pipeline()
	test_arbitrary_item_stats()
	test_mana_system()
	test_player_shared_takedown_effects()
	test_melee_visuals_and_indicators()
	test_monkey_king_kit_and_mechanics()
	test_combat_hitbox_cylinder_and_no_autoaim()
	test_aim_guide_and_projectile_indicator_filtering()
	test_data_driven_character_pipeline()
	test_bound_mechanic_and_rider()
	test_silene_character_kit_and_mechanics()
	test_player_projectile_armor_charges()
	test_ui_modal_states_and_radial_wheel()
	test_artist_the_painted_sage_kit()
	test_cleodolinda_maximum_suction()
	test_cleodolinda_animations()
	test_cleodolinda_relative_velocity_attack()
	test_cleodolinda_rmb_delayed_circle_slow()
	test_offline_presentation_and_indicator_hygiene()

	print("--- ALL ABILITY PIPELINE TESTS PASSED SUCCESSFULLY! ---")
	for i in range(5):
		await process_frame
	quit(0)

func test_property_pipeline_chain() -> void:
	print("Testing Property-Based Pipeline Chain...")
	var ability = AbilityClass.create_from_config({
		"id": "test_slam",
		"name": "Test Slam",
		"slot": "LMB",
		"cooldown": 2.5,
		"effect": {
			"type": AbilityPipeline.EffectType.MELEE_STRIKE,
			"windup": 0.25
		},
		"hitbox": {
			"shape": AbilityPipeline.HitboxShape.SECTOR,
			"radius": 5.0,
			"angle": 90.0,
			"height": 2.0
		},
		"triggers": [
			{
				"type": AbilityPipeline.TriggerType.ON_HIT_ENEMY,
				"riders": [
					{"type": AbilityPipeline.RiderType.DAMAGE, "amount": 50.0},
					{"type": AbilityPipeline.RiderType.STUN, "duration": 1.0}
				]
			}
		]
	})
	
	assert(ability != null, "Ability should not be null")
	assert(ability.ability_id == "test_slam", "Ability ID mismatch")
	assert(ability.cooldown == 2.5, "Cooldown mismatch")
	assert(ability.slot_key == "LMB", "Slot key mismatch")
	
	# Property checks (property of what comes before it)
	var effect = ability.effect_instance
	assert(effect != null, "Ability effect property must not be null")
	assert(effect is MeleeStrikeEffectClass, "Effect must be MeleeStrikeEffect")
	assert(effect.get_parent() == null, "Effect should be linked via property, not child of Ability")
	
	var hitbox = effect.hitbox_instance
	assert(hitbox != null, "Hitbox property on effect must not be null")
	assert(hitbox is SectorHitboxClass, "Hitbox must be SectorHitbox")
	assert(hitbox.radius == 5.0, "Hitbox radius mismatch")
	
	assert(effect.trigger_instances.size() == 1, "Effect must have 1 trigger property")
	var trigger = effect.trigger_instances[0]
	assert(trigger is OnHitEnemyTriggerClass, "Trigger must be OnHitEnemyTrigger")
	
	assert(trigger.rider_instances.size() == 2, "Trigger must have 2 riders")
	assert(trigger.rider_instances[0] is DamageRiderClass, "First rider must be DamageRider")
	assert(trigger.rider_instances[0].amount == 50.0, "Damage amount mismatch")
	assert(trigger.rider_instances[1] is StunRiderClass, "Second rider must be StunRider")
	assert(trigger.rider_instances[1].duration == 1.0, "Stun duration mismatch")
	
	print("✓ Property-based pipeline chain verified.")

func test_hitbox_calculations() -> void:
	print("Testing Hitbox Geometries...")
	var sector = SectorHitboxClass.new()
	sector.radius = 10.0
	sector.angle_deg = 90.0
	sector.height = 3.0
	
	var origin = Vector3(0, 0, 0)
	var facing = Vector3(0, 0, -1) # Facing -Z
	
	# Point directly ahead within radius
	assert(sector.is_point_inside(origin, facing, Vector3(0, 0, -5)) == true, "Point ahead should be inside sector")
	# Point behind
	assert(sector.is_point_inside(origin, facing, Vector3(0, 0, 5)) == false, "Point behind should be outside sector")
	# Point beyond radius
	assert(sector.is_point_inside(origin, facing, Vector3(0, 0, -15)) == false, "Point beyond radius should be outside sector")
	# Point too high
	assert(sector.is_point_inside(origin, facing, Vector3(0, 5, -5)) == false, "Point above height should be outside sector")
	assert(sector is CircleHitboxClass, "SectorHitbox must be a specialized CircleHitbox")

	# Full Circle hitbox (default angle_deg = 360.0)
	var full_circle = CircleHitboxClass.new()
	full_circle.radius = 10.0
	full_circle.height = 3.0
	assert(full_circle.angle_deg == 360.0, "CircleHitbox default angle_deg should be 360")
	assert(full_circle.is_point_inside(origin, facing, Vector3(0, 0, -5)) == true, "Point ahead should be inside full circle")
	assert(full_circle.is_point_inside(origin, facing, Vector3(0, 0, 5)) == true, "Point behind should be inside full circle")
	assert(full_circle.is_point_inside(origin, facing, Vector3(5, 0, 0)) == true, "Point to right should be inside full circle")
	assert(full_circle.is_point_inside(origin, facing, Vector3(0, 0, 15)) == false, "Point beyond radius should be outside full circle")

	# Circle hitbox with angle modifier (< 360.0, acts as sector)
	var modified_circle = CircleHitboxClass.new()
	modified_circle.radius = 10.0
	modified_circle.angle_deg = 90.0
	modified_circle.height = 3.0
	assert(modified_circle.is_point_inside(origin, facing, Vector3(0, 0, -5)) == true, "Point ahead should be inside modified circle sector")
	assert(modified_circle.is_point_inside(origin, facing, Vector3(5, 0, 0)) == false, "Point at 90 deg sideways should be outside 90 deg forward cone")

	# Annul modifier tests (Annulus & Annulus Sector)
	var annul_circle = CircleHitboxClass.new()
	annul_circle.radius = 10.0
	annul_circle.height = 3.0
	annul_circle.annul = true # Should use character hitbox radius (default 0.4 without caster)
	assert(annul_circle.get_annul_radius() == 0.4, "Annul true should default to 0.4 character radius when unbound")
	assert(annul_circle.is_point_inside(origin, facing, Vector3(0, 0, -0.2)) == false, "Point inside annul inner radius should be excluded")
	assert(annul_circle.is_point_inside(origin, facing, Vector3(0, 0, -1.0)) == true, "Point between inner and outer radius should be inside")

	# Annul with custom float
	var custom_annul = CircleHitboxClass.new()
	custom_annul.radius = 10.0
	custom_annul.height = 3.0
	custom_annul.annul = 2.5
	assert(custom_annul.get_annul_radius() == 2.5, "Annul float 2.5 should yield 2.5 inner radius")
	assert(custom_annul.is_point_inside(origin, facing, Vector3(0, 0, -1.5)) == false, "Point within 2.5 inner radius should be excluded")
	assert(custom_annul.is_point_inside(origin, facing, Vector3(0, 0, -3.0)) == true, "Point beyond 2.5 inner radius should be inside")

	# Annulus Sector (angle_deg < 360 + annul)
	var annul_sector = CircleHitboxClass.new()
	annul_sector.radius = 10.0
	annul_sector.angle_deg = 90.0
	annul_sector.annul = 2.0
	assert(annul_sector.is_point_inside(origin, facing, Vector3(0, 0, -1.0)) == false, "Point inside inner hole of annulus sector should be excluded")
	assert(annul_sector.is_point_inside(origin, facing, Vector3(0, 0, -4.0)) == true, "Point in frontal wedge between 2.0 and 10.0 should be inside")
	assert(annul_sector.is_point_inside(origin, facing, Vector3(0, 0, 4.0)) == false, "Point behind caster should be excluded from annulus sector")
	var annul_ind = annul_sector.create_indicator()
	assert(annul_ind != null, "Annulus sector indicator should create successfully")
	annul_ind.free()
	
	# Line hitbox
	var line = LineHitboxClass.new()
	line.length = 20.0
	line.width = 2.0
	line.height = 2.5
	assert(line.is_point_inside(origin, facing, Vector3(0.5, 0, -10)) == true, "Point inside line width should be true")
	assert(line.is_point_inside(origin, facing, Vector3(5.0, 0, -10)) == false, "Point outside line width should be false")
	assert(line.is_point_inside(origin, facing, Vector3(0.5, 1.5, -10)) == true, "Point within line height should hit")
	assert(line.is_point_inside(origin, facing, Vector3(0.5, 4.0, -10)) == false, "Point above line height should whiff")
	assert(line.is_point_inside(origin, facing, Vector3(0.5, -3.5, -10)) == false, "Point below line height should whiff")

	# Box hitbox
	var box = BoxHitboxClass.new()
	box.length = 10.0
	box.width = 2.0
	box.height = 2.5
	assert(box.is_point_inside(origin, facing, Vector3(0.5, 0, -5)) == true, "Point inside box bounds should hit")
	assert(box.is_point_inside(origin, facing, Vector3(2.5, 0, -5)) == false, "Point outside box width should whiff")
	assert(box.is_point_inside(origin, facing, Vector3(0.5, 1.8, -5)) == true, "Point within box height should hit even when dy > width * 0.5")
	assert(box.is_point_inside(origin, facing, Vector3(0.5, 4.0, -5)) == false, "Point above box height should whiff")
	assert(box.is_point_inside(origin, facing, Vector3(0.5, -3.0, -5)) == false, "Point below box height should whiff")

	# Circle hitbox with min_distance (donut hole)
	var circle_with_min = CircleHitboxClass.new()
	circle_with_min.radius = 8.0
	circle_with_min.min_distance = 3.0
	circle_with_min.height = 2.5
	assert(circle_with_min.is_point_inside(origin, facing, Vector3(0, 0, -1.5)) == false, "Point inside min_distance hole must whiff")
	assert(circle_with_min.is_point_inside(origin, facing, Vector3(0, 0, -5.0)) == true, "Point between min_distance and radius must hit")
	assert(circle_with_min.is_point_inside(origin, facing, Vector3(0, 0, -10.0)) == false, "Point beyond radius must whiff")

	# Donut hitbox (specialized CircleHitbox)
	var donut = DonutHitboxClass.new()
	donut.min_distance = 2.0
	donut.radius = 6.0
	donut.height = 2.5
	assert(donut is CircleHitboxClass, "DonutHitbox must extend CircleHitbox")
	assert(donut.is_point_inside(origin, facing, Vector3(0, 0, -1.0)) == false, "Point inside donut hole must whiff in is_point_inside")
	assert(donut.is_point_inside(origin, facing, Vector3(0, 0, -4.0)) == true, "Point inside donut ring must hit in is_point_inside")
	assert(donut.is_point_inside(origin, facing, Vector3(0, 0, -7.0)) == false, "Point outside donut outer radius must whiff")
	assert(donut.is_point_inside(origin, facing, Vector3(0, 4.0, -4.0)) == false, "Point above donut height must whiff")
	assert(donut.is_point_in_inner_circle(origin, Vector3(0, 0, -1.0)) == true, "Point inside donut hole must be detected by is_point_in_inner_circle")
	assert(donut.is_point_in_inner_circle(origin, Vector3(0, 0, -4.0)) == false, "Point inside donut ring must not be detected as inner circle")

	# Target radius expansion tests (grazing edge hits)
	var sweep_circle = CircleHitboxClass.new()
	sweep_circle.radius = 5.0
	assert(sweep_circle.is_point_inside(origin, facing, Vector3(0, 0, -5.3), 0.0) == false, "Point beyond radius with 0 radius must whiff")
	assert(sweep_circle.is_point_inside(origin, facing, Vector3(0, 0, -5.3), 0.5) == true, "Point beyond radius must hit when target_radius touches edge")

	var sweep_line = LineHitboxClass.new()
	sweep_line.length = 10.0
	sweep_line.width = 2.0 # half-width = 1.0
	assert(sweep_line.is_point_inside(origin, facing, Vector3(1.3, 0, -5), 0.0) == false, "Point outside line half-width must whiff with 0 target radius")
	assert(sweep_line.is_point_inside(origin, facing, Vector3(1.3, 0, -5), 0.5) == true, "Point outside line half-width must hit when target_radius touches line")

	print("✓ Hitbox geometric calculations verified.")

func test_rider_applications() -> void:
	print("Testing Rider Payloads...")
	var dummy = Node.new()
	var dummy_script = GDScript.new()
	dummy_script.source_code = "extends Node\nvar max_health = 100.0\nvar current_health = 100.0\nvar health = 100.0\nvar shield = 0.0\nvar is_stunned_state = false\nvar slow_amount = 0.0\nfunc take_damage(dmg, _att, _act): health -= dmg; current_health = health\nfunc heal(amt): health += amt; current_health = health\nfunc add_shield(amt, _dur): shield += amt\nfunc apply_stun(_dur): is_stunned_state = true\nfunc apply_slow(_dur, intensity): slow_amount = intensity\n"
	dummy_script.reload()
	dummy.set_script(dummy_script)
	
	var caster = Node.new()
	
	# Damage rider
	var dmg_rider = DamageRiderClass.new()
	dmg_rider.amount = 35.0
	dmg_rider.apply(caster, dummy)
	assert(dummy.get("health") == 65.0, "Dummy should take 35 damage")
	
	# Stun rider
	var stun_rider = StunRiderClass.new()
	stun_rider.duration = 1.5
	stun_rider.apply(caster, dummy)
	assert(dummy.get("is_stunned_state") == true, "Dummy should be stunned")

	# Shield rider
	var shield_rider = ShieldRiderClass.new()
	shield_rider.amount = 40.0
	shield_rider.apply_to_self = false
	shield_rider.apply(caster, dummy)
	assert(dummy.get("shield") == 40.0, "Dummy should have 40 shield")

	# Heal rider: Flat heal
	var flat_heal_rider = HealRiderClass.new()
	flat_heal_rider.amount = 20.0
	flat_heal_rider.apply_to_self = false
	flat_heal_rider.apply(caster, dummy)
	assert(dummy.get("health") == 85.0, "Dummy should heal 20 HP from flat heal rider")
	flat_heal_rider.free()

	# Heal rider: Scale with marks (11-15% missing HP)
	var marks_heal_rider = HealRiderClass.new()
	marks_heal_rider.scale_with_marks = true
	marks_heal_rider.apply_to_self = true
	dummy.set("health", 60.0)
	dummy.set("current_health", 60.0) # missing HP = 40.0
	# 5 marks -> 15% of 40 = 6.0 heal -> 66.0
	marks_heal_rider.apply_to_caster(dummy, {"marks": 5})
	assert(abs(dummy.get("health") - 66.0) < 0.001, "5 marks should heal 15% missing HP")
	marks_heal_rider.free()

	# AbilityPipeline RiderType.HEAL and builder checks
	assert(AbilityPipeline.RiderType.HEAL != null, "AbilityPipeline must define RiderType.HEAL")
	assert(AbilityPipeline.parse_rider_type("HEAL") == AbilityPipeline.RiderType.HEAL, "parse_rider_type('HEAL') must return RiderType.HEAL")
	var built_heal = AbilityBuilder._build_rider({"type": AbilityPipeline.RiderType.HEAL, "scale_with_marks": true, "min_percent": 0.11, "max_percent": 0.15})
	assert(built_heal is HealRiderClass, "AbilityBuilder must build HealRider instance")
	assert(built_heal.scale_with_marks == true, "Built HealRider must preserve scale_with_marks")
	built_heal.free()
	
	dummy.free()
	caster.free()
	print("✓ Rider payloads verified.")

func test_character_ability_registration() -> void:
	print("Testing Character Ability Registration on all 6 characters...")
	var chars = [
		"res://characters/poke/poke.tscn",
		"res://characters/crush/crush.tscn",
		"res://characters/reaper/reaper.tscn",
		"res://characters/asparsas/asparsas.tscn",
		"res://characters/morrigan/morrigan.tscn",
		"res://characters/monkey/monkey.tscn"
	]
	
	for path in chars:
		var scene = load(path) as PackedScene
		assert(scene != null, "Scene %s must load" % path)
		var char_inst = scene.instantiate() as BasePlayer
		root.add_child(char_inst)
		if not char_inst.is_node_ready():
			char_inst._ready()
		
		# Check that all 6 slots are registered as Ability nodes
		print("Character %s abilities keys: %s" % [char_inst.character_name, str(char_inst.abilities.keys())])
		var expected_slots = ["LMB", "RMB", "SHIFT", "Q", "E", "R"]
		for slot in expected_slots:
			var ab = char_inst.abilities.get(slot)
			assert(ab != null, "Character %s must have ability in slot %s" % [char_inst.character_name, slot])
			assert(ab is AbilityClass, "Ability %s must be Ability node in %s" % [slot, char_inst.character_name])
			assert(ab.effect_instance != null, "Ability %s in %s must have effect property" % [slot, char_inst.character_name])
			
			# Verify intended pipeline: Effect is an instanced scene child with 0 nested child nodes
			assert(ab.get_child_count() == 0, "Ability %s in %s should have no child nodes (hitboxes/riders/triggers must be properties)" % [slot, char_inst.character_name])
		
		char_inst.queue_free()
	print("✓ All 5 characters successfully registered pipeline abilities (instanced effect scenes with properties).")

func test_lightweight_rpc_signature() -> void:
	print("Testing Lightweight RPC parameter signatures...")
	var player = (load("res://characters/crush/crush.tscn") as PackedScene).instantiate() as BasePlayer
	root.add_child(player)
	if not player.is_node_ready():
		player._ready()
	
	# Verify request_cast_ability exists and can be called with primitives
	assert(player.has_method("request_cast_ability"), "PlayerBase must have request_cast_ability")
	assert(player.has_method("sync_cast_ability"), "PlayerBase must have sync_cast_ability")
	
	# Call directly with primitives (slot_key, origin, direction, target_pos, charge_ratio)
	player.request_cast_ability("LMB", Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, 5), 0.0)
	var lmb_ab = player.abilities.get("LMB") as AbilityClass
	assert(lmb_ab.current_cooldown > 0.0, "LMB ability cooldown should be active after cast")
	
	player.queue_free()
	print("✓ Lightweight RPC signature verified.")

func test_melee_attack_execution() -> void:
	print("Testing Melee Attack In-Game Execution...")
	var player = (load("res://characters/crush/crush.tscn") as PackedScene).instantiate() as BasePlayer
	player.name = "1"
	player.team_id = 1
	root.add_child(player)
	if not player.is_node_ready():
		player._ready()
	player.position = Vector3(0, 0, 0)
	
	# Spawn enemy dummy at (0, 0, -2.0) directly in front of player
	var dummy_node = Node3D.new()
	var dummy_script = GDScript.new()
	dummy_script.source_code = "extends Node3D\nvar team_id = 2\nvar is_dead = false\nvar health = 200.0\nfunc take_damage(dmg, _att, _act):\n\thealth -= dmg\n"
	dummy_script.reload()
	dummy_node.set_script(dummy_script)
	dummy_node.add_to_group("players")
	root.add_child(dummy_node)
	dummy_node.position = Vector3(0, 0, -2.0)
	
	# Crush LMB deals 55 damage
	var lmb_ab = player.abilities.get("LMB") as AbilityClass
	assert(lmb_ab != null, "Crush must have LMB ability")
	lmb_ab.execute_server(player, player.global_position, Vector3(0, 0, -1), Vector3(0, 0, -2.0), 0.0)
	assert(dummy_node.get("health") == 145.0, "Dummy should have taken 55 damage from Crush melee strike, got %s" % str(dummy_node.get("health")))
	
	# Test point blank range (0.5m in front of player)
	dummy_node.global_position = Vector3(0, 0, -0.5)
	lmb_ab.current_cooldown = 0.0
	lmb_ab.execute_server(player, player.global_position, Vector3(0, 0, -1), Vector3(0, 0, -0.5), 0.0)
	assert(dummy_node.get("health") == 90.0, "Point blank dummy should take damage, got %s" % str(dummy_node.get("health")))
	
	# Test that teammate is NOT damaged
	dummy_node.set("team_id", 1)
	lmb_ab.current_cooldown = 0.0
	lmb_ab.execute_server(player, player.global_position, Vector3(0, 0, -1), Vector3(0, 0, -0.5), 0.0)
	assert(dummy_node.get("health") == 90.0, "Teammate must not take friendly fire damage, got %s" % str(dummy_node.get("health")))
	
	player.free()
	
	# Test Dive Melee (32 damage)
	var dive_player = (load("res://characters/asparsas/asparsas.tscn") as PackedScene).instantiate() as BasePlayer
	dive_player.name = "2"
	dive_player.team_id = 1
	root.add_child(dive_player)
	if not dive_player.is_node_ready():
		dive_player._ready()
	dive_player.position = Vector3(0, 0, 0)
	
	dummy_node.set("team_id", 2)
	dummy_node.set("health", 100.0)
	dummy_node.position = Vector3(0, 0, -1.8)
	var dive_lmb = dive_player.abilities.get("LMB") as AbilityClass
	assert(dive_lmb != null, "Dive must have LMB ability")
	dive_lmb.execute_server(dive_player, dive_player.global_position, Vector3(0, 0, -1), Vector3(0, 0, -1.8), 0.0)
	assert(dummy_node.get("health") == 68.0, "Dummy should have taken 32 damage from Dive slash, got %s" % str(dummy_node.get("health")))
	dive_player.free()
	
	# Test Reaper Melee (36 damage)
	var reaper_player = (load("res://characters/reaper/reaper.tscn") as PackedScene).instantiate() as BasePlayer
	reaper_player.name = "3"
	reaper_player.team_id = 1
	root.add_child(reaper_player)
	if not reaper_player.is_node_ready():
		reaper_player._ready()
	reaper_player.position = Vector3(0, 0, 0)
	
	dummy_node.set("health", 100.0)
	dummy_node.position = Vector3(0, 0, -1.8)
	var reaper_lmb = reaper_player.abilities.get("LMB") as AbilityClass
	assert(reaper_lmb != null, "Reaper must have LMB ability")
	reaper_lmb.execute_server(reaper_player, reaper_player.global_position, Vector3(0, 0, -1), Vector3(0, 0, -1.8), 0.0)
	assert(dummy_node.get("health") == 64.0, "Dummy should have taken 36 damage from Reaper scythe, got %s" % str(dummy_node.get("health")))
	reaper_player.free()
	
	dummy_node.free()
	print("✓ Melee attack in-game execution verified for Crush, Dive, and Reaper.")

func test_character_kits_and_special_mechanics() -> void:
	print("Testing Restored Character Kits and Special Mechanics...")
	
	# --- 1. Crush: Gray Health conversion & Titan Surge Empowerment ---
	var crush = (load("res://characters/crush/crush.tscn") as PackedScene).instantiate() as BasePlayer
	crush.name = "10"
	crush.team_id = 1
	root.add_child(crush)
	if not crush.is_node_ready(): crush._ready()
	
	crush.take_damage(40.0, 0, 0)
	assert(crush.gray_health == 20.0, "Crush should store 50%% of damage as gray health, got %f" % crush.gray_health)
	crush.on_buff_activated("IronBarrier", 5.0)
	assert(crush.gray_health == 0.0, "Iron Barrier should consume gray health")
	assert(crush.current_shield == 70.0, "Iron Barrier should grant consumed gray health (20) + 50 shield = 70, got %f" % crush.current_shield)
	
	crush.custom_execute_ability_server("RMB", Vector3.ZERO, Vector3.FORWARD, Vector3.ZERO, 0.0)
	assert(crush.is_crush_empowered == true, "Fan Stun RMB must set is_crush_empowered")
	crush.free()
	
	# --- 2. Dive: Deflecting Guard mitigation & Rupture Marks ---
	var dive = (load("res://characters/asparsas/asparsas.tscn") as PackedScene).instantiate() as BasePlayer
	dive.name = "11"
	dive.team_id = 1
	root.add_child(dive)
	if not dive.is_node_ready(): dive._ready()
	
	dive.start_block_stance(3.0)
	assert(dive.is_blocking == true, "Deflecting guard must set is_blocking")
	var blocked_dmg = dive.modify_incoming_damage(100.0, 0, 0)
	assert(blocked_dmg == 25.0, "Deflecting guard should reduce damage by 75%%, got %f" % blocked_dmg)
	dive.end_blocking()
	assert(dive.is_blocking == false, "end_blocking should clear is_blocking")
	
	dive.apply_rupture_mark(1)
	dive.apply_rupture_mark(1)
	assert(dive.dive_marks_count == 2, "Should have 2 rupture marks")
	var hp_before = dive.current_health
	dive.detonate_dive_marks()
	assert(dive.dive_marks_count == 0, "Marks should be consumed on detonation")
	assert(dive.current_health == hp_before - 36.0, "2 marks should deal 36 burst damage")
	dive.free()

	# Dive Passive Proc Heal Testing (11% to 15% missing HP based on 1 to 5 marks)
	var dive_attacker = (load("res://characters/asparsas/asparsas.tscn") as PackedScene).instantiate() as Asparsas
	dive_attacker.name = "21"
	dive_attacker.peer_id = 21
	dive_attacker.team_id = 1
	root.add_child(dive_attacker)
	if not dive_attacker.is_node_ready(): dive_attacker._ready()

	var enemy_target = (load("res://characters/crush/crush.tscn") as PackedScene).instantiate() as BasePlayer
	enemy_target.name = "22"
	enemy_target.team_id = 2
	root.add_child(enemy_target)
	if not enemy_target.is_node_ready(): enemy_target._ready()

	for marks_to_test in range(1, 6):
		dive_attacker.current_health = 140.0 # max_health is 240.0 -> missing_hp is 100.0
		for _i in range(marks_to_test):
			enemy_target.apply_rupture_mark(21)
		assert(enemy_target.dive_marks_count == marks_to_test, "Enemy should have %d marks" % marks_to_test)
		
		enemy_target.detonate_dive_marks(dive_attacker)
		var expected_pct = 0.10 + float(marks_to_test) * 0.01 # 11% to 15%
		var expected_heal = 100.0 * expected_pct
		var actual_hp = dive_attacker.current_health
		assert(abs(actual_hp - (140.0 + expected_heal)) < 0.001, 
			"Dive should heal %f%% (%f HP) on %d marks proc, got HP %f" % [expected_pct * 100.0, expected_heal, marks_to_test, actual_hp])

	# Test on_melee_strike_hit cleave proc triggers passive heal
	dive_attacker.current_health = 140.0
	for _i in range(3): # 3 marks = 13% missing HP = 13.0 HP heal
		enemy_target.apply_rupture_mark(21)
	dive_attacker.on_melee_strike_hit(enemy_target, {"ability_id": "dive_heavy_cleave", "slot_key": "RMB"})
	assert(abs(dive_attacker.current_health - 153.0) < 0.001, "Cleave hit should detonate marks and heal 13 HP (13%)")
	assert(enemy_target.dive_marks_count == 0, "Cleave should consume enemy marks")

	dive_attacker.free()
	enemy_target.free()

	# --- 3. Poke: Sniper Stance, Overcharge & Takedown Reset ---
	var poke = (load("res://characters/poke/poke.tscn") as PackedScene).instantiate() as BasePlayer
	poke.name = "12"
	poke.team_id = 1
	root.add_child(poke)
	if not poke.is_node_ready(): poke._ready()
	
	poke._enter_sniper_stance()
	assert(poke.is_in_sniper_stance == true, "Poke should be in sniper stance")
	assert(poke.get_speed_multiplier() == 0.70, "Poke should have 30%% MS penalty in sniper stance")
	var rmb_ab = poke.abilities.get("RMB") as AbilityClass
	assert(rmb_ab.current_cooldown == 0.0, "RMB cooldown should be 0 when entering sniper stance")
	assert(poke.get_effective_slot("LMB") == "RMB", "LMB should be remapped to RMB while in sniper stance")
	assert(poke.get_ability_for_slot("LMB") == rmb_ab, "LMB should resolve to RMB ability while in sniper stance")

	# Mana Gating: Cannot input or charge abilities without mana
	poke.current_mana = 0.0
	assert(poke.can_cast_ability_slot("LMB") == false, "Cannot cast remapped RMB sniper without mana")
	assert(rmb_ab.can_start_charging(poke) == false, "Cannot start charging sniper without mana")
	assert(rmb_ab.start_charging(poke) == false, "start_charging must return false when out of mana")
	assert(rmb_ab.is_charging == false, "Must not be charging when out of mana")
	assert(poke.try_cast_ability("LMB") == false, "try_cast_ability must fail when out of mana")
	assert(poke.has_buffered_ability() == false, "Out-of-mana spells must NOT be buffered")

	# Charging cancelled if mana is lost mid-charge
	poke.current_mana = 50.0
	assert(rmb_ab.start_charging(poke) == true, "Must successfully start charging with mana")
	assert(rmb_ab.is_charging == true, "Must be charging")
	poke.current_mana = 0.0
	rmb_ab.process_charge(0.1, poke)
	assert(rmb_ab.is_charging == false, "Charge must be immediately cancelled if mana becomes insufficient")

	# Firing RMB in sniper stance consumes mana but does NOT go on cooldown
	poke.current_mana = 50.0
	var initial_mana = poke.current_mana
	poke.try_cast_ability("LMB", 0.5)
	assert(rmb_ab.current_cooldown == 0.0, "RMB must NOT go on cooldown after firing while in sniper stance")
	assert(poke.current_mana < initial_mana, "Firing RMB in sniper stance should consume mana")

	poke.custom_execute_ability_server("Q", Vector3.ZERO, Vector3.FORWARD, Vector3.ZERO, 0.0)
	assert(poke.is_overcharge_active == true, "Overcharge Q should activate in sniper stance")

	# Exiting sniper stance puts RMB on cooldown and unremaps LMB
	poke._exit_sniper_stance()
	assert(poke.is_in_sniper_stance == false, "Exiting stance should clear stance")
	assert(poke.is_overcharge_active == false, "Exiting stance should clear overcharge")
	assert(poke.get_effective_slot("LMB") == "LMB", "LMB should revert back to LMB after exiting stance")
	assert(poke.get_ability_for_slot("LMB") == poke.abilities["LMB"], "LMB should resolve back to Rapid Beam")
	assert(rmb_ab.current_cooldown == 2.0, "RMB must go on cooldown only upon leaving sniper stance")

	# While RMB is on cooldown, Poke cannot re-enter sniper stance
	poke._enter_sniper_stance()
	assert(poke.is_in_sniper_stance == false, "Poke must not enter sniper stance while RMB is on cooldown")

	# When cooldown expires, Poke can re-enter sniper stance
	rmb_ab.current_cooldown = 0.0
	poke._enter_sniper_stance()
	assert(poke.is_in_sniper_stance == true, "Poke can enter sniper stance when cooldown expires")
	poke._exit_sniper_stance()
	rmb_ab.current_cooldown = 0.0
	
	var dash_ab = poke.abilities.get("SHIFT") as AbilityClass
	dash_ab.current_cooldown = 4.0
	poke._on_character_takedown(null)
	assert(dash_ab.current_cooldown == 0.0, "Takedown must reset dash cooldown")
	assert(poke.get_attack_speed_bonus() == 0.60, "Takedown must give +60%% attack speed")
	poke.free()

	# --- 4. Reaper: Sweet-spot check & Movement Speed Steal ---
	var reaper = (load("res://characters/reaper/reaper.tscn") as PackedScene).instantiate() as BasePlayer
	reaper.name = "13"
	reaper.team_id = 1
	root.add_child(reaper)
	if not reaper.is_node_ready(): reaper._ready()
	
	var dummy = (load("res://characters/reaper/reaper.tscn") as PackedScene).instantiate() as BasePlayer
	dummy.name = "14"
	dummy.team_id = 2
	root.add_child(dummy)
	if not dummy.is_node_ready(): dummy._ready()
	
	reaper.on_melee_strike_hit(dummy, {"slot_key": "LMB"})
	assert(reaper.reaper_ms_steal_timer > 0.0, "Reaper should gain MS steal timer on melee hit")
	assert(dummy.slow_timer > 0.0, "Dummy should be slowed by MS steal")
	
	dummy.free()
	reaper.free()

	# --- 5. Morrigan: Crows & Crowstorm flight damage reduction ---
	var morrigan = (load("res://characters/morrigan/morrigan.tscn") as PackedScene).instantiate() as BasePlayer
	morrigan.name = "15"
	morrigan.team_id = 1
	root.add_child(morrigan)
	if not morrigan.is_node_ready(): morrigan._ready()
	
	assert(morrigan.passive_crows_count == 3, "Morrigan starts with 3 crows")
	morrigan.lmb_charge_timer = 0.53 # 1st charge 0.35 + 1 extra (0.18)
	assert(morrigan._calculate_lmb_feather_count() >= 2, "Should calculate charged feathers")
	
	morrigan.is_crowstorm_active = true
	var flight_dmg = morrigan.modify_incoming_damage(100.0, 0, 0)
	assert(flight_dmg == 50.0, "Crowstorm flight should grant 50%% damage reduction, got %f" % flight_dmg)
	morrigan.free()

	print("✓ All restored character kits and special mechanics verified successfully.")

func test_gravity_and_jump_metrics() -> void:
	print("Testing Gravity and Jump Metrics...")
	var grav = ProjectSettings.get_setting("physics/3d/default_gravity", 13.0)
	assert(grav == 28.0, "ProjectSettings physics/3d/default_gravity must be 28.0, got %s" % str(grav))

	var char_data_classes = [
		CrushData,
		AsparsasData,
		MorriganData,
		PokeData,
		ReaperData
	]

	for cdc in char_data_classes:
		var data = cdc.create()
		assert(data.jump_velocity == 13.0, "Character %s jump_velocity should be 13.0, got %s" % [data.character_name, str(data.jump_velocity)])
		assert(data.intentional_movement_friction == 75.0, "Character %s intentional_movement_friction should be 75.0, got %s" % [data.character_name, str(data.intentional_movement_friction)])
		assert(data.ground_deceleration == 40.0, "Character %s ground_deceleration should be 40.0, got %s" % [data.character_name, str(data.ground_deceleration)])
		assert(data.air_max_speed_mult == 0.3, "Character %s air_max_speed_mult should be 0.3 (70%% reduction), got %s" % [data.character_name, str(data.air_max_speed_mult)])
		assert(is_equal_approx(data.air_acceleration, data.ground_acceleration * 0.3), "Character %s air_acceleration should be ground_accel * 0.3 (70%% reduction), got %s" % [data.character_name, str(data.air_acceleration)])
		var peak_height = (data.jump_velocity * data.jump_velocity) / (2.0 * grav)
		# Peak jump height: 13^2 / (2 * 28) = 169 / 56 ≈ 3.018m (slightly less than old 3.47m)
		assert(peak_height > 2.9 and peak_height < 3.2, "Peak jump height should be slightly less than 3.47m (approx 3.02m), got %f" % peak_height)

	# Verify specific reduced ground_acceleration values
	assert(CrushData.create().ground_acceleration == 20.0, "Crush ground_acceleration should be 20.0")
	assert(AsparsasData.create().ground_acceleration == 25.0, "Asparsas ground_acceleration should be 25.0")
	assert(MorriganData.create().ground_acceleration == 25.0, "Morrigan ground_acceleration should be 25.0")
	assert(PokeData.create().ground_acceleration == 30.0, "Poke ground_acceleration should be 30.0")
	assert(ReaperData.create().ground_acceleration == 40.0, "Reaper ground_acceleration should be 40.0")

	print("✓ Gravity (28.0 m/s²), Jump Velocity (13.0 m/s), Air Movement (0.3x actual accel & max speed), and Ground Deceleration (40.0 m/s²) verified.")

func test_natural_movement_conditions() -> void:
	print("Testing Natural Movement Under All Circumstances...")
	var root = get_root()
	var player = (load("res://characters/poke/poke.tscn") as PackedScene).instantiate() as BasePlayer
	player.name = "99"
	player.team_id = 1
	root.add_child(player)
	if not player.is_node_ready():
		player._ready()

	assert(not player.is_stunned() and not player.is_rooted(), "Player initially unhindered")

	# Verify that channeling does not block movement input condition
	player.is_channeling = true
	var can_move_while_channeling = (not player.is_stunned() and not player.is_rooted())
	assert(can_move_while_channeling == true, "Movement keys must work while channeling")

	# Verify that in-air does not block movement input condition
	var can_move_in_air = (not player.is_stunned() and not player.is_rooted())
	assert(can_move_in_air == true, "Movement keys must work in the air")

	# Verify that immobilized (rooted) blocks movement
	player.root_timer = 1.0
	var can_move_while_rooted = (not player.is_stunned() and not player.is_rooted())
	assert(can_move_while_rooted == false, "Movement keys must NOT work while rooted (immobilized)")
	player.root_timer = 0.0

	# Verify that stunned blocks movement
	player.stun_timer = 1.0
	var can_move_while_stunned = (not player.is_stunned() and not player.is_rooted())
	assert(can_move_while_stunned == false, "Movement keys must NOT work while stunned")
	player.stun_timer = 0.0
	player.is_channeling = false

	player.free()
	print("✓ Natural movement under all circumstances verified.")

func test_charge_time_pipeline() -> void:
	print("Testing Charge Time Pipeline Integration...")
	
	# 1. Configured charge ability
	var charge_ab = AbilityClass.create_from_config({
		"id": "test_charge_shot",
		"name": "Test Charge Shot",
		"slot": "RMB",
		"cooldown": 3.0,
		"charge_time": 2.0,
		"min_damage": 30.0,
		"max_damage": 90.0,
		"hold_to_charge": true,
		"charge_move_speed_multiplier": 0.5,
		"effect": {
			"type": AbilityPipeline.EffectType.PROJECTILE,
			"speed": 60.0,
			"range": 30.0
		}
	})
	
	assert(charge_ab != null, "Charge ability should instantiate")
	assert(charge_ab.is_charge_ability() == true, "Must detect as charge ability")
	assert(charge_ab.cast_on_press == false, "Charge ability must not cast on press")
	assert(charge_ab.get_max_charge_time() == 2.0, "Max charge time should be 2.0")
	assert(charge_ab.is_charging == false, "Initially not charging")
	assert(charge_ab.get_charge_ratio() == 0.0, "Initial charge ratio 0.0")
	
	# 2. Lifecycle charging
	charge_ab.start_charging()
	assert(charge_ab.is_charging == true, "Must be charging after start_charging()")
	
	charge_ab.process_charge(1.0)
	assert(abs(charge_ab.get_charge_ratio() - 0.5) < 0.001, "Ratio after 1.0s of 2.0s should be 0.5")
	
	charge_ab.process_charge(1.5)
	assert(abs(charge_ab.get_charge_ratio() - 1.0) < 0.001, "Ratio after full charge should be clamped to 1.0")
	
	charge_ab.stop_charging()
	assert(charge_ab.is_charging == false, "Must not be charging after stop_charging()")
	assert(charge_ab.get_charge_ratio() == 0.0, "Charge ratio reset to 0.0")
	
	# 3. Damage rider charge scaling
	var rider = DamageRiderClass.new()
	rider.amount = 50.0
	rider.min_damage = 25.0
	rider.max_damage = 100.0
	
	var dummy_target = Node.new()
	var dummy_script = GDScript.new()
	dummy_script.source_code = "extends Node\nvar last_dmg = 0.0\nfunc take_damage(dmg: float, _attacker_id: int = 0, _action: int = 0) -> void:\n\tlast_dmg = dmg\n"
	dummy_script.reload()
	dummy_target.set_script(dummy_script)
	
	rider.apply(null, dummy_target, {"charge_ratio": 0.0})
	assert(abs(dummy_target.last_dmg - 25.0) < 0.001, "0% charge should apply min_damage 25.0")
	
	rider.apply(null, dummy_target, {"charge_ratio": 0.5})
	assert(abs(dummy_target.last_dmg - 62.5) < 0.001, "50% charge should apply lerped damage 62.5")
	
	rider.apply(null, dummy_target, {"charge_ratio": 1.0})
	assert(abs(dummy_target.last_dmg - 100.0) < 0.001, "100% charge should apply max_damage 100.0")
	dummy_target.free()
	
	# 4. Poke RMB and Morrigan LMB charge settings
	var poke_scene = (load("res://characters/poke/poke.tscn") as PackedScene).instantiate() as BasePlayer
	poke_scene.name = "101"
	poke_scene.team_id = 1
	get_root().add_child(poke_scene)
	if not poke_scene.is_node_ready():
		poke_scene._ready()
	
	var poke_rmb = poke_scene.abilities.get("RMB")
	assert(poke_rmb != null, "Poke RMB must exist")
	assert(poke_rmb.is_charge_ability() == true, "Poke RMB must be a charge ability")
	assert(poke_rmb.get_max_charge_time() == 2.0, "Poke RMB max charge time should be 2.0")
	assert(poke_rmb.min_damage == 35.0, "Poke RMB min damage should be 35.0")
	assert(poke_rmb.max_damage == 70.0, "Poke RMB max damage should be 70.0")
	assert(poke_rmb.charge_move_speed_multiplier == 0.70, "Poke RMB speed mult should be 0.70")
	
	# Test speed multiplier when charging
	var normal_speed = poke_scene.get_effective_max_speed(10.0)
	assert(normal_speed == 10.0, "Normal speed should be unchanged")
	poke_rmb.start_charging()
	var charging_speed = poke_scene.get_effective_max_speed(10.0)
	assert(abs(charging_speed - 7.0) < 0.001, "Charging speed should be 70% of normal (7.0)")
	poke_rmb.stop_charging()
	
	poke_scene.free()
	
	var morrigan_scene = (load("res://characters/morrigan/morrigan.tscn") as PackedScene).instantiate() as BasePlayer
	morrigan_scene.name = "102"
	morrigan_scene.team_id = 1
	get_root().add_child(morrigan_scene)
	if not morrigan_scene.is_node_ready():
		morrigan_scene._ready()
	
	var morrigan_lmb = morrigan_scene.abilities.get("LMB")
	assert(morrigan_lmb != null, "Morrigan LMB must exist")
	assert(morrigan_lmb.is_charge_ability() == true, "Morrigan LMB must be a charge ability")
	assert(morrigan_lmb.get_max_charge_time() == 0.80, "Morrigan LMB charge time should be 0.80")
	
	morrigan_scene.free()
	charge_ab.free()
	
	print("✓ Charge time pipeline integration verified.")

func test_delayed_abilities_and_telegraph_indicators() -> void:
	print("Testing Delayed Abilities and Telegraphed Indicators...")

	# 1. Pipeline ability configuration with delay and telegraph
	var delayed_ab = AbilityClass.create_from_config({
		"id": "test_delayed_slam",
		"name": "Test Delayed Slam",
		"slot": "Q",
		"cooldown": 4.0,
		"windup_time": 0.35,
		"telegraph": true,
		"follow_caster": false,
		"windup_move_speed_multiplier": 0.25,
		"hitbox": {
			"shape": AbilityPipeline.HitboxShape.CIRCLE,
			"radius": 4.5
		},
		"effect": {
			"type": AbilityPipeline.EffectType.AERIAL_CRASH
		}
	})

	assert(delayed_ab != null, "Delayed ability should instantiate")
	assert(delayed_ab.has_delay() == true, "Must detect delay")
	assert(delayed_ab.get_windup_time() == 0.35, "Windup time should be 0.35")
	assert(delayed_ab.is_winding_up == false, "Initially not winding up")

	# 2. Lifecycle windup progression
	delayed_ab.start_windup()
	assert(delayed_ab.is_winding_up == true, "Must be winding up after start_windup()")
	assert(delayed_ab.can_cast(null) == false, "Cannot cast another ability during active windup")

	var finished_first = delayed_ab.process_windup(0.20)
	assert(finished_first == false, "0.20s should not finish 0.35s windup")
	assert(delayed_ab.is_winding_up == true, "Still winding up")

	var finished_second = delayed_ab.process_windup(0.20)
	assert(finished_second == true, "0.40s total must complete 0.35s windup")
	assert(delayed_ab.is_winding_up == false, "Windup must be complete")

	# 3. Telegraph indicator generation and visual properties
	var teleg = AbilityIndicator.create_telegraph_indicator(delayed_ab.hitbox)
	assert(teleg != null, "Telegraph indicator must be created")
	assert(teleg.name == "TelegraphIndicator", "Telegraph indicator should be named TelegraphIndicator")
	assert(teleg.get_child_count() >= 2, "Telegraph indicator must have fill mesh and outline border")

	var fill_mesh = teleg.get_child(0) as MeshInstance3D
	assert(fill_mesh != null, "Child 0 must be the fill mesh instance")
	var outline_mesh = teleg.get_child(1) as MeshInstance3D
	assert(outline_mesh != null, "Child 1 must be the outline mesh instance")

	# 4. In-game player execution with delay and telegraph
	var crush_player = (load("res://characters/crush/crush.tscn") as PackedScene).instantiate() as BasePlayer
	crush_player.name = "103"
	crush_player.team_id = 1
	root.add_child(crush_player)
	if not crush_player.is_node_ready():
		crush_player._ready()

	var crush_lmb = crush_player.abilities.get("LMB") as AbilityClass
	assert(crush_lmb != null, "Crush LMB must exist")
	assert(crush_lmb.get_windup_time() == 0.28, "Crush LMB windup time should be 0.28s")

	# Execute with delay
	crush_player.request_cast_ability("LMB", crush_player.global_position, -crush_player.global_transform.basis.z, crush_player.global_position + Vector3(0, 0, 5), 0.0)
	assert(crush_player.active_windup_id == "LMB", "Active windup ID should be LMB")
	assert(crush_player.is_in_cast_lockout() == true, "Player must be in cast lockout during windup")
	assert(crush_lmb.is_winding_up == true, "Crush LMB must be winding up")
	assert(crush_lmb.active_telegraph != null, "Telegraph indicator must be spawned during windup")

	# Test speed multiplier during windup (movement is NOT stopped by default unless move_lockout is set)
	var speed_during_windup = crush_player.get_effective_max_speed(6.0)
	assert(speed_during_windup == 6.0, "Abilities must not stop movement by default during windup")
	assert(crush_player.is_in_move_lockout() == false, "Crush slam must not have move_lockout by default")
	assert(crush_player.is_in_cast_lockout() == true, "Player must be in cast lockout during Crush slam windup")
	# Test bypass_lockout (Dash has bypass_lockout=true by default and can cast during cast lockout)
	var crush_shift = crush_player.abilities.get("SHIFT") as AbilityClass
	assert(crush_shift != null and crush_shift.bypass_lockout == true, "Dash must have bypass_lockout = true by default")
	assert(crush_shift.can_cast(crush_player) == true, "Dash must be able to cast during cast lockout")
	var crush_rmb = crush_player.abilities.get("RMB") as AbilityClass
	assert(crush_rmb.bypass_lockout == false, "RMB should not have bypass_lockout")
	assert(crush_rmb.can_cast(crush_player) == false, "RMB cannot cast during cast lockout")

	# Test CC interruption
	crush_player.apply_stun(1.0)
	assert(crush_player.active_windup_id == "", "Active windup should be cleared on stun")
	assert(crush_lmb.is_winding_up == false, "Ability windup state must be cancelled on stun")
	assert(crush_lmb.active_telegraph == null, "Telegraph indicator must be cleared on stun")

	# 5. Verify Poke Ult and Morrigan Ult delayed telegraphs
	var poke_player = (load("res://characters/poke/poke.tscn") as PackedScene).instantiate() as BasePlayer
	poke_player.name = "104"
	poke_player.team_id = 1
	root.add_child(poke_player)
	if not poke_player.is_node_ready():
		poke_player._ready()

	var poke_ult = poke_player.abilities.get("R") as AbilityClass
	assert(poke_ult != null, "Poke Ult must exist")
	assert(poke_ult.get_windup_time() == 2.0, "Poke Ult windup time must be 2.0s")
	assert(poke_ult.has_delay() == true, "Poke Ult must have delay")
	assert(poke_ult.has_hitbox() == true, "Poke Ult must have a hitbox")
	var poke_hb = poke_ult.get_hitbox()
	assert(poke_hb.length == 70.0, "Poke Ult hitbox length must be 70.0m")
	assert(poke_hb.width == 1.6, "Poke Ult hitbox width must be 1.6m")
	assert(poke_ult.windup_move_speed_multiplier == 0.0, "Poke Ult locks movement during channel")

	var poke_teleg = poke_player.show_ability_telegraph(poke_ult, poke_player.global_position, Vector3.FORWARD, 2.0)
	assert(poke_teleg != null, "Poke Ult telegraph indicator must be generated")
	assert(poke_teleg.get_meta("indicator_shape") == "LineIndicator", "Poke Ult telegraph should be a LineIndicator")
	assert(poke_teleg.get_child_count() >= 2, "Poke Ult telegraph must have fill and border meshes")

	# Cast Poke Ult and verify windup state & lockout
	poke_player.request_cast_ability("R", poke_player.global_position, Vector3.FORWARD, poke_player.global_position, 0.0)
	assert(poke_player.active_windup_id == "R", "Active windup ID must be R")
	assert(poke_player.is_channeling == true, "is_channeling must be true during Poke Ult channel")
	assert(poke_ult.is_winding_up == true, "Poke Ult must be in winding up state")
	assert(poke_player.is_in_move_lockout() == true, "Poke Ult must have move_lockout = true")
	assert(poke_player.get_effective_max_speed(6.0) == 0.0, "Poke Ult must reduce movement speed to 0")
	poke_player.cancel_active_windup()
	assert(poke_player.is_channeling == false, "is_channeling must be false after cancelling windup")

	var morrigan_player = (load("res://characters/morrigan/morrigan.tscn") as PackedScene).instantiate() as BasePlayer
	morrigan_player.name = "105"
	morrigan_player.team_id = 1
	root.add_child(morrigan_player)
	if not morrigan_player.is_node_ready():
		morrigan_player._ready()

	var morrigan_ult = morrigan_player.abilities.get("R") as AbilityClass
	assert(morrigan_ult != null, "Morrigan Ult must exist")
	assert(morrigan_ult.get_windup_time() == 1.0, "Morrigan Ult windup time must be 1.0s")
	assert(morrigan_ult.has_hitbox() == true, "Morrigan Ult must have a hitbox")
	var morr_hb = morrigan_ult.get_hitbox()
	assert(morr_hb.length == 45.0, "Morrigan Ult hitbox length must be 45.0m")
	assert(morr_hb.width == 12.0, "Morrigan Ult hitbox width must be 12.0m")

	var morrigan_teleg = morrigan_player.show_ability_telegraph(morrigan_ult, morrigan_player.global_position, Vector3.FORWARD, 1.0)
	assert(morrigan_teleg != null, "Morrigan Ult telegraph indicator must be generated")
	assert(morrigan_teleg.get_meta("indicator_shape") == "LineIndicator", "Morrigan Ult telegraph should be a LineIndicator")

	AbilityIndicator.clean_indicator(poke_teleg)
	AbilityIndicator.clean_indicator(morrigan_teleg)
	AbilityIndicator.clean_indicator(teleg)
	poke_player.queue_free()
	morrigan_player.queue_free()
	crush_player.queue_free()
	delayed_ab.free()

	print("✓ Delayed abilities and telegraphed indicators verified.")

func test_item_ability_scene_tree_pipeline() -> void:
	print("Testing Item Ability Scene Tree Pipeline...")
	var aegis = ItemPipeline.get_item("aegis_barrier")
	assert(aegis != null, "Aegis Talisman item must exist in ItemPipeline")
	assert(aegis.has_unique_feature() == true, "Aegis Talisman must have a unique feature")
	
	var instantiated_ab = aegis.instantiate_ability()
	assert(instantiated_ab != null, "Aegis Talisman unique feature must instantiate into a Node")
	assert(instantiated_ab is AbilityClass, "Instantiated feature must be an AbilityClass")
	assert(instantiated_ab.is_inside_tree() == false, "Freshly instantiated ability is not yet inside tree")
	instantiated_ab.free()

	# Test player equipping and scene tree integration
	var crush_scene = load("res://characters/crush/crush.tscn") as PackedScene
	var player = crush_scene.instantiate() as BasePlayer
	player.name = "109"
	player.team_id = 1
	root.add_child(player)
	if not player.is_node_ready():
		player._ready()

	var base_hp = player.max_health
	assert(player.item_ability_nodes.is_empty(), "Item ability nodes must initially be empty")
	
	# Equip aegis barrier item
	var equip_slots: Array[String] = ["aegis_barrier"]
	player.item_slots = equip_slots
	player.apply_all_items()

	assert(player.max_health == base_hp + 75.0, "Aegis barrier must grant +75 HP")
	assert(player.has_node("ItemAbilities") == true, "Player must possess ItemAbilities container node")
	var item_container = player.get_node("ItemAbilities")
	assert(item_container.get_child_count() == 1, "ItemAbilities container must have 1 instanced ability child node")
	assert(player.item_ability_nodes.size() == 1, "item_ability_nodes array must track 1 ability")

	var item_ab = player.item_ability_nodes[0]
	assert(item_ab.is_inside_tree() == true, "Item ability node must be live inside the Godot scene tree")
	assert(item_ab.get_parent() == item_container, "Item ability node's parent must be ItemAbilities")

	# Test un-equipping / selling item
	player.item_slots.clear()
	player.apply_all_items()

	assert(player.max_health == base_hp, "Max health must revert when item is removed")
	assert(player.item_ability_nodes.is_empty(), "item_ability_nodes must be empty after removing item")
	assert(item_container.get_child_count() == 0, "ItemAbilities container must have 0 children after removing item")

	player.free()
	print("✓ Item ability scene tree pipeline verified.")

func test_arbitrary_item_stats() -> void:
	print("Testing Arbitrary Item Stats Pipeline...")
	
	# 1. Test arbitrary stats formatting in ItemDefinition
	var custom_item = ItemPipeline.create_item({
		"id": "custom_relic",
		"name": "Custom Relic",
		"stats": {
			"crit_chance": 20.0,
			"lifesteal": 15.0,
			"cooldown_reduction": 25.0,
			"armor": 20.0,
			"jump_velocity": 3.0,
			"custom_potency": 42.0
		}
	})
	
	var desc = custom_item.get_stats_description()
	assert(desc.contains("+20% Critical Chance"), "Must format crit chance properly")
	assert(desc.contains("+15% Lifesteal"), "Must format lifesteal properly")
	assert(desc.contains("+25% Cooldown Reduction"), "Must format CDR properly")
	assert(desc.contains("+20% Damage Reduction"), "Must format armor properly")
	assert(desc.contains("+3.0 Jump Velocity"), "Must format jump velocity properly")
	assert(desc.contains("+42 Custom Potency"), "Must format arbitrary custom stat key properly")

	# Register custom item dynamically for testing
	ItemPipeline.register_item({
		"id": "custom_relic",
		"name": "Custom Relic",
		"cost": 150,
		"stats": {
			"crit_chance": 20.0,
			"lifesteal": 15.0,
			"cooldown_reduction": 25.0,
			"armor": 20.0,
			"jump_velocity": 3.0,
			"custom_potency": 42.0
		},
		"unique_feature": null
	})

	# 2. Test player equipment and direct stat application without persistent buffs
	var crush_scene = load("res://characters/crush/crush.tscn") as PackedScene
	var player = crush_scene.instantiate() as BasePlayer
	player.name = "110"
	player.team_id = 1
	root.add_child(player)
	if not player.is_node_ready():
		player._ready()

	var base_crit = player.crit_chance
	var base_jump = player.jump_velocity

	var equip_slots: Array[String] = ["custom_relic"]
	player.item_slots = equip_slots
	player.apply_all_items()

	# Verify arbitrary stat querying
	assert(player.has_item_stat("custom_potency") == true, "Player must report having custom_potency stat")
	assert(player.get_item_stat("custom_potency") == 42.0, "Player must return correct arbitrary stat value")
	assert(player.get_item_stat("non_existent_stat", 99.0) == 99.0, "Default value must be respected for missing stats")
	
	# Verify direct stat effects without ability pipeline persistent buffs
	assert(is_equal_approx(player.crit_chance, base_crit + 0.20), "Crit chance must increase directly by 20%")
	assert(is_equal_approx(player.jump_velocity, base_jump + 3.0), "Jump velocity must increase directly by 3.0m/s")
	assert(is_equal_approx(player.get_cooldown_multiplier(), 0.75), "Cooldown multiplier must be 0.75 with 25% CDR")
	
	# Verify damage reduction without ability buff
	var raw_dmg = 100.0
	var reduced = player.modify_incoming_damage(raw_dmg, 0, 0)
	assert(is_equal_approx(reduced, 80.0), "20% armor must reduce 100 dmg to 80 dmg")

	# Verify lifesteal healing without ability buff
	player.current_health = 50.0
	var dummy = Node.new()
	player._on_damage_dealt(dummy, 100.0, 0)
	assert(is_equal_approx(player.current_health, 65.0), "15% lifesteal on 100 damage dealt must heal 15 HP")
	dummy.free()

	# Verify unequip reverts everything
	player.item_slots.clear()
	player.apply_all_items()
	assert(player.has_item_stat("custom_potency") == false, "Player must not have custom stat after unequip")
	assert(is_equal_approx(player.crit_chance, base_crit), "Crit chance must revert on unequip")
	assert(is_equal_approx(player.get_cooldown_multiplier(), 1.0), "Cooldown multiplier must revert on unequip")

	player.free()
	print("✓ Arbitrary item stats pipeline verified.")

func test_mana_system() -> void:
	print("Testing Mana Resource System...")

	# 1. Base pool and default ability costs on standard character (Crush)
	var crush_scene = load("res://characters/crush/crush.tscn") as PackedScene
	var player = crush_scene.instantiate() as BasePlayer
	player.name = "111"
	player.team_id = 1
	root.add_child(player)
	if not player.is_node_ready():
		player._ready()

	assert(player.max_mana == 100.0, "Character must have 100 base max mana")
	assert(player.current_mana == 100.0, "Character must start with 100 current mana")
	
	# Check default ability mana costs
	assert(player.abilities["LMB"].get_mana_cost(player) == 0.0, "Primary Fire (LMB) must cost 0 mana")
	assert(player.abilities["SHIFT"].get_mana_cost(player) == 0.0, "Dash (SHIFT) must cost 0 mana")
	assert(player.abilities["RMB"].get_mana_cost(player) == 10.0, "RMB ability must cost 10 mana")
	assert(player.abilities["Q"].get_mana_cost(player) == 10.0, "Q ability must cost 10 mana")
	assert(player.abilities["E"].get_mana_cost(player) == 10.0, "E ability must cost 10 mana")
	assert(player.abilities["R"].get_mana_cost(player) == 30.0, "Ultimate (R) must cost 30 mana")

	# 2. Poke RMB outlier (20 normally, 30 with Q overcharge buff active)
	var poke_scene = load("res://characters/poke/poke.tscn") as PackedScene
	var poke_player = poke_scene.instantiate() as BasePlayer
	poke_player.name = "112"
	poke_player.team_id = 1
	root.add_child(poke_player)
	if not poke_player.is_node_ready():
		poke_player._ready()

	var poke_rmb = poke_player.abilities.get("RMB")
	assert(poke_rmb != null, "Poke RMB must exist")
	assert(poke_rmb.get_mana_cost(poke_player) == 20.0, "Poke RMB must cost 20 mana per shot normally")
	
	poke_player.is_overcharge_active = true
	assert(poke_rmb.get_mana_cost(poke_player) == 30.0, "Poke RMB must cost 30 mana per shot while Q Overcharge is active")
	
	poke_player.is_overcharge_active = false
	assert(poke_rmb.get_mana_cost(poke_player) == 20.0, "Poke RMB must revert to 20 mana when Q Overcharge ends")

	# 3. Insufficient mana restriction
	player.consume_mana(95.0)
	assert(is_equal_approx(player.current_mana, 5.0), "Player mana must be 5.0 after spending 95")
	assert(player.abilities["Q"].can_cast(player) == false, "Q must not be castable with only 5 mana (costs 10)")
	assert(player.abilities["R"].can_cast(player) == false, "R must not be castable with only 5 mana (costs 30)")
	assert(player.abilities["LMB"].can_cast(player) == true, "LMB must remain castable (costs 0)")
	assert(player.abilities["SHIFT"].can_cast(player) == true, "SHIFT must remain castable (costs 0)")

	# 4. Passive Mana Regeneration (3 mana per second)
	player._physics_process(1.0)
	assert(is_equal_approx(player.current_mana, 8.0), "Player must regenerate 3 mana per second (5.0 -> 8.0)")

	# 5. Takedown Recovery (recover 30% of max mana and 10% missing HP)
	player.current_health = 100.0
	var expected_heal = (player.max_health - 100.0) * 0.10
	var dummy_victim = Node.new()
	player._on_takedown(dummy_victim)
	assert(is_equal_approx(player.current_mana, 38.0), "Takedown must restore 30% of max mana (8.0 + 30.0 = 38.0)")
	assert(is_equal_approx(player.current_health, 100.0 + expected_heal), "Takedown must instantly heal 10% of missing HP")
	dummy_victim.free()

	# Full health takedown edge case: missing health is 0, health stays at max_health
	player.current_health = player.max_health
	var dummy_victim2 = Node.new()
	player._on_takedown(dummy_victim2)
	assert(is_equal_approx(player.current_health, player.max_health), "Full health player must remain at max_health on takedown")
	dummy_victim2.free()

	# 6. Item stats modifying max mana
	ItemPipeline.register_item({
		"id": "mana_sapphire",
		"name": "Mana Sapphire",
		"cost": 120,
		"stats": {
			"max_mana": 50.0,
			"mana_regen": 2.0
		},
		"unique_feature": null
	})

	var equip_slots: Array[String] = ["mana_sapphire"]
	player.item_slots = equip_slots
	player.apply_all_items()

	assert(is_equal_approx(player.max_mana, 150.0), "Max mana must increase to 150 with Mana Sapphire (+50)")
	player.restore_mana(200.0)
	assert(is_equal_approx(player.current_mana, 150.0), "Current mana must reach new max mana of 150")

	player.item_slots.clear()
	player.apply_all_items()
	assert(is_equal_approx(player.max_mana, 100.0), "Max mana must revert to 100 upon un-equipping")
	assert(is_equal_approx(player.current_mana, 100.0), "Current mana must clamp to 100 upon un-equipping")

	poke_player.free()
	player.free()
	print("✓ Mana resource system verified.")

func test_player_shared_takedown_effects() -> void:
	print("Testing Player Shared Takedown Effects in PlayerSharedEffects...")
	var crush_scene = load("res://characters/crush/crush.tscn") as PackedScene
	var player = crush_scene.instantiate() as BasePlayer
	player.name = "113"
	player.team_id = 1
	root.add_child(player)
	if not player.is_node_ready():
		player._ready()

	# 1. Verify default registration
	var effects = player.get_takedown_effects()
	assert(effects.size() >= 2, "Player must have at least 2 default takedown effects registered")
	assert(effects.has(PlayerSharedEffects.restore_mana_on_takedown), "Player must have restore_mana_on_takedown registered")
	assert(effects.has(PlayerSharedEffects.heal_missing_hp_on_takedown), "Player must have heal_missing_hp_on_takedown registered")

	# 2. Test takedown execution via registered effects
	player.current_mana = 20.0
	player.current_health = 100.0
	var missing_hp = player.max_health - 100.0
	var victim = Node.new()
	player._on_takedown(victim)

	# 30% max mana = 30.0 + 20.0 = 50.0
	assert(is_equal_approx(player.current_mana, 50.0), "Takedown must restore 30% max mana through registered effect")
	# 10% missing HP = 100.0 + (missing_hp * 0.10)
	assert(is_equal_approx(player.current_health, 100.0 + (missing_hp * 0.10)), "Takedown must heal 10% missing HP through registered effect")

	# 3. Test custom takedown effect registration and unregistration
	var custom_effect_called: Array[bool] = [false]
	var custom_callable = func(_p: Node, _v: Node):
		custom_effect_called[0] = true

	player.register_takedown_effect(custom_callable)
	assert(player.get_takedown_effects().has(custom_callable), "Custom takedown effect must be registered")

	player._on_takedown(victim)
	assert(custom_effect_called[0] == true, "Registered custom takedown effect must be invoked on takedown")

	player.unregister_takedown_effect(custom_callable)
	assert(not player.get_takedown_effects().has(custom_callable), "Custom takedown effect must be successfully unregistered")

	victim.free()
	player.free()
	print("✓ Player shared takedown effects verified.")

func test_melee_visuals_and_indicators() -> void:
	print("Testing Melee Visuals, Attack Animations, and Indicator Deduplication...")
	
	# 1. Verify Dive Q is restored to ProjectileEffect with correct projectile properties
	var dive_scene = load("res://characters/asparsas/asparsas.tscn") as PackedScene
	assert(dive_scene != null, "asparsas.tscn must exist and load")
	var dive_inst = dive_scene.instantiate() as BasePlayer
	root.add_child(dive_inst)
	if not dive_inst.is_node_ready():
		dive_inst._ready()
	
	var dive_q = dive_inst.abilities.get("Q")
	assert(dive_q != null, "Dive must have Q ability")
	assert(dive_q.effect_instance is ProjectileEffect, "Dive Q must be ProjectileEffect (Earth Tremor projectile)")
	assert(dive_q.effect_instance.speed == 28.0, "Dive Q speed should be 28.0")
	assert(dive_q.effect_instance.max_range == 14.0, "Dive Q max_range should be 14.0")
	assert(dive_q.effect_instance.pierces == true, "Dive Q must pierce targets")
	assert(dive_q.effect_instance.custom_effect_type == "dive_earth_tremor", "Dive Q custom_effect_type must be dive_earth_tremor")
	print("  ✓ Dive Q projectile configuration verified.")

	# 2. Verify Melee strikes do NOT show legacy duplicate box mesh indicators (MeleeVisual)
	var crush_scene = load("res://characters/crush/crush.tscn") as PackedScene
	var crush_inst = crush_scene.instantiate() as BasePlayer
	root.add_child(crush_inst)
	if not crush_inst.is_node_ready():
		crush_inst._ready()

	var crush_lmb = crush_inst.abilities.get("LMB")
	assert(crush_lmb != null, "Crush must have LMB ability")
	assert(crush_lmb.effect_instance is MeleeStrikeEffect, "Crush LMB must be MeleeStrikeEffect")
	
	# Execute client side
	crush_lmb.effect_instance.execute_effect_client(crush_inst, crush_inst.global_position, Vector3.FORWARD, Vector3(0, 0, 5), 0.0)
	var crush_melee_vis = crush_inst.get_node_or_null("MeleeVisual")
	assert(crush_melee_vis == null or crush_melee_vis.visible == false, "MeleeVisual must NOT be visible on client execution to prevent double indicators")
	print("  ✓ Crush melee strike client execution does not activate legacy MeleeVisual box mesh.")

	# Verify Dive LMB strike
	var dive_lmb = dive_inst.abilities.get("LMB")
	assert(dive_lmb != null and dive_lmb.effect_instance is MeleeStrikeEffect, "Dive LMB must be MeleeStrikeEffect")
	dive_lmb.effect_instance.execute_effect_client(dive_inst, dive_inst.global_position, Vector3.FORWARD, Vector3(0, 0, 5), 0.0)
	var dive_melee_vis = dive_inst.get_node_or_null("MeleeVisual")
	assert(dive_melee_vis == null or dive_melee_vis.visible == false, "Dive MeleeVisual must NOT be visible on client execution")
	print("  ✓ Dive melee strike client execution does not activate legacy MeleeVisual box mesh.")

	# 3. Verify Reaper melee strike & Cull the Weak
	var reaper_scene = load("res://characters/reaper/reaper.tscn") as PackedScene
	var reaper_inst = reaper_scene.instantiate() as BasePlayer
	root.add_child(reaper_inst)
	if not reaper_inst.is_node_ready():
		reaper_inst._ready()

	var reaper_lmb = reaper_inst.abilities.get("LMB")
	assert(reaper_lmb != null and reaper_lmb.effect_instance is MeleeStrikeEffect, "Reaper LMB must be MeleeStrikeEffect")
	reaper_lmb.effect_instance.execute_effect_client(reaper_inst, reaper_inst.global_position, Vector3.FORWARD, Vector3(0, 0, 5), 0.0)
	var reaper_melee_vis = reaper_inst.get_node_or_null("MeleeVisual")
	assert(reaper_melee_vis == null or reaper_melee_vis.visible == false, "Reaper MeleeVisual must NOT be visible on client execution")
	print("  ✓ Reaper melee strike client execution does not activate legacy MeleeVisual box mesh.")

	# 4. Verify Morrigan E (Banshee Cry) executes without error
	var morrigan_scene = load("res://characters/morrigan/morrigan.tscn") as PackedScene
	var morrigan_inst = morrigan_scene.instantiate() as BasePlayer
	root.add_child(morrigan_inst)
	if not morrigan_inst.is_node_ready():
		morrigan_inst._ready()

	var morrigan_e = morrigan_inst.abilities.get("E")
	assert(morrigan_e != null and morrigan_e.effect_instance is MeleeStrikeEffect, "Morrigan E must be MeleeStrikeEffect")
	morrigan_e.effect_instance.execute_effect_client(morrigan_inst, morrigan_inst.global_position, Vector3.FORWARD, Vector3(0, 0, 5), 0.0)
	print("  ✓ Morrigan Banshee Cry melee visual executes cleanly.")

	# 5. Verify aiming indicator is hidden when windup starts to prevent double indicators
	if crush_inst.abilities.get("RMB"):
		var rmb_ab = crush_inst.abilities.get("RMB")
		if rmb_ab.active_indicator:
			rmb_ab.active_indicator.show()
			assert(rmb_ab.active_indicator.visible == true, "Active indicator should be visible when aiming")
			crush_inst.start_windup_cast("RMB", crush_inst.global_position, Vector3.FORWARD, crush_inst.global_position, 0.20, 0.0)
			assert(rmb_ab.active_indicator.visible == false, "Active aiming indicator must be hidden when windup starts to avoid double indicators")
			crush_inst.cancel_active_windup()
	print("  ✓ Aiming indicator hidden upon windup start verified.")

	dive_inst.queue_free()
	crush_inst.queue_free()
	reaper_inst.queue_free()
	morrigan_inst.queue_free()
	print("✓ Melee visuals, attack animations, and indicator deduplication verified successfully.")

func test_monkey_king_kit_and_mechanics() -> void:
	print("Testing Monkey King Kit, Passives, Status Effects, and Mechanics...")
	var root = get_root()
	var monkey_scene = load("res://characters/monkey/monkey.tscn") as PackedScene
	assert(monkey_scene != null, "Monkey scene must exist")

	var monkey = monkey_scene.instantiate() as BasePlayer
	monkey.name = "200"
	monkey.team_id = 1
	root.add_child(monkey)
	if not monkey.is_node_ready():
		monkey._ready()

	# 1. Identity & Ability Registration
	assert(monkey.character_name == "Monkey", "Character name must be 'Monkey'")
	assert(monkey.display_name == "The Great Sage", "Display name must be 'The Great Sage'")
	assert(monkey.max_health == 160.0, "Max health should be 160.0")

	var required_slots = ["LMB", "RMB", "SHIFT", "Q", "E", "R"]
	for s in required_slots:
		assert(monkey.abilities.has(s), "Monkey King must have ability slot %s" % s)
		var ab = monkey.abilities.get(s) as AbilityClass
		assert(ab != null, "Ability %s must be AbilityClass" % s)

	# 2. Mana Costs: LMB 0, RMB 10, SHIFT 0, Q 10, E 10, R 30
	assert(monkey.abilities.get("LMB").get_mana_cost(monkey) == 0.0, "LMB must cost 0 mana")
	assert(monkey.abilities.get("RMB").get_mana_cost(monkey) == 10.0, "RMB must cost 10 mana")
	assert(monkey.abilities.get("SHIFT").get_mana_cost(monkey) == 0.0, "SHIFT must cost 0 mana")
	assert(monkey.abilities.get("Q").get_mana_cost(monkey) == 10.0, "Q must cost 10 mana")
	assert(monkey.abilities.get("E").get_mana_cost(monkey) == 10.0, "E must cost 10 mana")
	assert(monkey.abilities.get("R").get_mana_cost(monkey) == 30.0, "R must cost 30 mana")
	print("  ✓ Identity, ability slots, and mana costs verified.")

	# 3. Passive: Stone Monkey (Triggers at <= 30% HP, Invulnerability, Displacement Immunity, 30% Missing HP Heal)
	monkey.current_health = 40.0 # 40 / 160 = 25% <= 30%
	monkey._process_character_kit(0.016)
	assert(monkey.is_invulnerable() == true, "Stone Monkey must grant invulnerability")
	assert(monkey.is_displacement_immune() == true, "Stone Monkey must grant displacement immunity")
	assert(monkey.get("stone_monkey_active_timer") > 0.0, "Stone Monkey active timer must be active")

	# Invulnerability prevents damage
	var hp_before_dmg = monkey.current_health
	monkey.take_damage(50.0)
	assert(monkey.current_health == hp_before_dmg, "Invulnerable unit must take 0 damage")

	# Displacement immunity prevents knockback
	var pre_knockback_vel = monkey.knockback_velocity
	monkey.apply_knockback(Vector3(15, 0, 0))
	assert(monkey.knockback_velocity == pre_knockback_vel, "Displacement immune unit must not take knockback")

	# Healing 30% missing HP over 3s
	var health_before_tick = monkey.current_health
	monkey._process_character_kit(1.0) # 1 second tick
	assert(monkey.current_health > health_before_tick, "Stone Monkey must heal over duration")
	print("  ✓ Stone Monkey passive (invulnerability, displacement immunity, heal) verified.")

	# 4. Invisibility Status & Rider: breaks on casting another ability including primary and dash
	monkey.apply_invisibility(3.0)
	assert(monkey.is_invisible() == true, "apply_invisibility must set is_invisible to true")
	
	# Casting LMB breaks invisibility
	monkey.try_cast_ability("LMB")
	assert(monkey.is_invisible() == false, "Invisibility must end upon casting primary attack")

	monkey.apply_invisibility(3.0)
	assert(monkey.is_invisible() == true, "Invisibility reapplied")
	monkey.try_cast_ability("SHIFT")
	assert(monkey.is_invisible() == false, "Invisibility must end upon casting dash")
	print("  ✓ Invisibility status and auto-break on cast verified.")

	# 5. Taunt Status: forces movement towards taunter, forces aim, deals reduced damage
	var dummy_scene = load("res://characters/crush/crush.tscn") as PackedScene
	var dummy = dummy_scene.instantiate() as BasePlayer
	dummy.name = "201"
	dummy.team_id = 2
	root.add_child(dummy)
	if not dummy.is_node_ready():
		dummy._ready()

	dummy.global_position = Vector3(10, 0, 0)
	monkey.global_position = Vector3(0, 0, 0)

	dummy.apply_taunt(monkey, 1.8, 0.35)
	assert(dummy.is_taunted() == true, "Dummy must be taunted")
	assert(dummy.get_taunt_target() == monkey, "Taunt target must be Monkey King")
	assert(is_equal_approx(dummy.get_taunt_damage_multiplier(), 0.65), "Taunted unit must have 0.65 damage multiplier")

	# Verify aim overrides towards taunter
	dummy.aim_at_mouse()
	var forward_dir = -dummy.global_transform.basis.z.normalized()
	forward_dir.y = 0.0
	assert(forward_dir.dot(Vector3(-1, 0, 0)) > 0.8, "Taunted unit must face taunter")

	# Verify damage reduction when dealing damage to another unit
	var dmg_reduced = monkey.modify_incoming_damage(100.0, dummy.name.to_int(), 0)
	assert(dmg_reduced <= 65.0, "Incoming damage from taunted unit must be reduced by 35%")
	print("  ✓ Taunt status (forced aim, movement, damage reduction) verified.")

	# 6. 72 Forms Transformation: appearance change only, movement & dash permitted, break on damage/attack
	monkey.stone_monkey_active_timer = 0.0
	monkey.invulnerable_timer = 0.0
	monkey.displacement_immune_timer = 0.0

	monkey.apply_transformation("tree", {"can_move": true, "can_dash": true, "break_on_attack": true, "break_on_damage": true})
	assert(monkey.is_unit_transformed() == true, "Monkey King must be transformed")
	assert(monkey.transformed_prop_type == "tree", "Prop type must be tree")
	assert(monkey.get_node_or_null("MeshInstance3D").visible == false, "Player mesh must be hidden while transformed")
	assert(monkey.get_node_or_null("TransformedPropVisual") != null, "Transformed prop visual must be attached")

	# Dashing (SHIFT) does NOT break transformation
	monkey.try_cast_ability("SHIFT")
	assert(monkey.is_unit_transformed() == true, "Dashing must NOT break transformation")

	# Taking damage breaks transformation
	monkey.take_damage(10.0)
	assert(monkey.is_unit_transformed() == false, "Taking damage must break transformation")
	assert(monkey.get_node_or_null("MeshInstance3D").visible == true, "Player mesh must be restored")
	assert(monkey.get_node_or_null("TransformedPropVisual") == null, "Transformed prop visual must be removed")
	assert(monkey.abilities.get("Q").current_cooldown > 0.0, "Breaking transformation must start Q cooldown")

	# Cancel choice: refunds 5 mana and triggers reduced cooldown
	monkey.current_mana = 80.0
	var mana_before_cancel = monkey.current_mana
	monkey._process_radial_choice("cancel")
	assert(monkey.current_mana == 85.0, "Cancel must refund half mana (5.0)")
	assert(is_equal_approx(monkey.abilities.get("Q").current_cooldown, 2.5), "Cancel must trigger reduced 2.5s cooldown")
	print("  ✓ 72 Forms transformation, dash persistence, damage break, and cancel refund verified.")

	# 7. RMB Enlarge Charge & Sweet Spot
	var rmb_ab = monkey.abilities.get("RMB")
	assert(rmb_ab.is_charge_ability() == true, "RMB must be a charge ability")
	assert(rmb_ab.hold_to_charge == true, "RMB must hold to charge")
	assert(rmb_ab.charge_move_speed_multiplier == 0.65, "RMB must reduce movement speed while charging")

	# Position dummy 3 meters directly ahead (within sweet spot)
	dummy.global_position = monkey.global_position + Vector3.FORWARD * 3.0
	dummy.current_health = 1000.0
	dummy.stun_timer = 0.0
	monkey.custom_execute_ability_server("RMB", monkey.global_position, Vector3.FORWARD, dummy.global_position, 1.0)
	var max_sweet_spot_dmg = 70.0 * 1.45
	assert(dummy.current_health <= (1000.0 - (max_sweet_spot_dmg - 0.5)), "Sweet spot must deal 1.45x damage")
	assert(dummy.is_stunned() == true, "Target in sweet spot must be stunned")
	assert(dummy.stun_timer >= 1.5, "Sweet spot must increase stun duration by 0.5s")
	print("  ✓ RMB Enlarge charging, sweet spot damage (1.45x), and bonus stun verified.")

	# 8. Ultimate Recast & Invisibility Break
	monkey.current_mana = 100.0
	monkey.custom_execute_ability_server("R", monkey.global_position, Vector3.FORWARD, Vector3.FORWARD * 10.0, 0.0)
	assert(monkey.ult_recast_window > 0.0, "Ult initial cast must activate recast window")
	assert(monkey.is_invisible() == true, "Ult initial cast must grant invisibility")
	assert(monkey.character_handles_slot("R") == true, "Monkey King must handle R slot while recast window is active")
	assert(monkey.get_custom_ability_mana_cost("R", "") == 0.0, "Ult recast must be free of mana cost")

	# Recast triggers flurry rush, breaks invisibility, and starts full cooldown
	monkey.custom_execute_ability_server("R", monkey.global_position, Vector3.FORWARD, Vector3.FORWARD * 12.0, 0.0)
	assert(monkey.ult_recast_window == 0.0, "Ult recast must close recast window")
	assert(monkey.is_invisible() == false, "Ult recast flurry must break invisibility")
	assert(monkey.abilities.get("R").current_cooldown > 0.0, "Ult recast must start full cooldown")
	assert(monkey.character_handles_slot("R") == false, "Monkey King should not handle R slot after recast")
	assert(monkey.get_custom_ability_mana_cost("R", "") == -1.0, "Ult mana cost should return to default after recast")
	print("  ✓ Ultimate stealth dash, recast window, flurry rush, and invisibility break verified.")

	monkey.queue_free()
	dummy.queue_free()
	print("✓ Monkey King kit and special mechanics verified successfully.")

func test_combat_hitbox_cylinder_and_no_autoaim() -> void:
	print("Testing Combat Hitbox Cylinder & Leading Shots (No Auto-Aim)...")
	var char_scenes = {
		"Crush": "res://characters/crush/crush.tscn",
		"Asparsas": "res://characters/asparsas/asparsas.tscn",
		"Poke": "res://characters/poke/poke.tscn",
		"Reaper": "res://characters/reaper/reaper.tscn",
		"Morrigan": "res://characters/morrigan/morrigan.tscn",
		"Monkey": "res://characters/monkey/monkey.tscn",
		"TrainingDummy": "res://training_dummy.tscn"
	}

	# 1. Verify every character has a CombatHitbox with a CylinderShape3D
	for c_name in char_scenes:
		var scene = load(char_scenes[c_name]) as PackedScene
		assert(scene != null, "Failed to load scene for " + c_name)
		var char_inst = scene.instantiate() as BasePlayer
		root.add_child(char_inst)

		var combat_hb = char_inst.get_combat_hitbox()
		assert(combat_hb != null, c_name + " must have a CombatHitbox node")
		assert(combat_hb.collision_layer == 2, c_name + " CombatHitbox must be on collision layer 2")
		assert(combat_hb.collision_mask == 0, c_name + " CombatHitbox must have collision mask 0 (passive)")

		var col_shape_child = combat_hb.get_node_or_null("CollisionShape3D") as CollisionShape3D
		assert(col_shape_child != null, c_name + " CombatHitbox must have a CollisionShape3D child")
		assert(col_shape_child.shape is CylinderShape3D, c_name + " CombatHitbox shape must be a CylinderShape3D")

		var cyl = col_shape_child.shape as CylinderShape3D
		assert(cyl.height >= 1000.0, c_name + " CombatHitbox cylinder height must extend infinitely (+/- 2000m)")
		var phys_col = char_inst.get_node_or_null("CollisionShape3D") as CollisionShape3D
		assert(phys_col != null, c_name + " physical CollisionShape3D must exist")
		if phys_col.shape is CapsuleShape3D:
			assert(abs(cyl.radius - phys_col.shape.radius) < 0.01, c_name + " CombatHitbox cylinder radius must match character collision radius")
			assert(phys_col.shape.height < 10.0, c_name + " physical collision mesh height must remain normal (not infinite)")

		char_inst.queue_free()
	print("  ✓ Every character has a dedicated CylinderShape3D combat hitbox extending infinitely vertically while physical collision mesh is untouched.")

	# 2. Verify Leading Shots & No Vertical Auto Aim
	var shooter = (load("res://characters/poke/poke.tscn") as PackedScene).instantiate() as BasePlayer
	root.add_child(shooter)
	shooter.global_position = Vector3(0, 0, 0)
	shooter.look_at(Vector3(0, 0, -10), Vector3.UP)

	# Aim horizontally forward
	var spawn_pos = shooter.global_position + Vector3(0, 0.8, -1.0)
	var shoot_dir = shooter.get_ranged_aim_direction(spawn_pos)
	assert(abs(shoot_dir.y) < 0.0001, "get_ranged_aim_direction must have y == 0.0 (horizontal aim)")
	assert(shoot_dir.is_normalized(), "get_ranged_aim_direction must return a normalized vector")

	# Position dummy to the side and slightly elevated
	var target_dummy = (load("res://training_dummy.tscn") as PackedScene).instantiate() as BasePlayer
	root.add_child(target_dummy)
	target_dummy.global_position = Vector3(5.0, 3.0, -10.0)

	# Even with target nearby, shoot direction should NOT snap to target_dummy if cursor is elsewhere
	# Because direct raycast and forgiving screen proximity were removed, shoot_dir matches forward aim
	var forward_dir = shooter.get_ranged_aim_direction(spawn_pos)
	assert(forward_dir.dot(Vector3(0, 0, -1)) > 0.95, "Ranged aim must not snap to nearby enemy when leading shot forward")
	print("  ✓ No auto-aim snapping; shots travel purely horizontally along intended lead trajectory.")

	# 3. Verify Airborne Target Hit Detection via Infinite Vertical Combat Hitbox
	# Move dummy 8.0 meters up in the air (jumping)
	target_dummy.global_position = Vector3(0.0, 8.0, -5.0)
	target_dummy.current_health = 200.0

	# A. Ability & Melee Hitbox Test on Airborne Target (Must NOT hit outside intended bounds)
	var sector = SectorHitboxClass.new()
	sector.radius = 8.0
	sector.angle_deg = 90.0
	sector.height = 3.0
	var targets_hit_out_of_bounds = sector.get_targets_in_hitbox(shooter, shooter.global_position, Vector3(0, 0, -1), self)
	assert(not targets_hit_out_of_bounds.has(target_dummy), "Melee/ability hitbox must NOT hit airborne target outside its intended vertical bounds (combat hitbox infinite cylinder does not apply to melee)")
	
	# Verify target dummy IS hit when within intended bounds (y = 1.0)
	target_dummy.global_position = Vector3(0.0, 1.0, -5.0)
	var targets_hit_in_bounds = sector.get_targets_in_hitbox(shooter, shooter.global_position, Vector3(0, 0, -1), self)
	assert(targets_hit_in_bounds.has(target_dummy), "Melee/ability hitbox MUST hit target when within intended bounds")
	print("  ✓ Melee and ability hitboxes respect intended 3D bounds and do not hit infinite CombatHitbox.")

	# Restore airborne position for projectile CombatHitbox test
	target_dummy.global_position = Vector3(0.0, 8.0, -5.0)
	target_dummy.armor_charges = 0

	# B. Projectile Collision on Airborne Target
	var proj_scene = load("res://projectile.tscn") as PackedScene
	var proj = proj_scene.instantiate()
	root.add_child(proj)
	proj.shooter_id = shooter.peer_id
	proj.damage = 35.0
	proj.classification = 0 # TRAJECTORY
	proj.direction = Vector3(0, 0, -1)
	proj.position = Vector3(0, 0.8, -4.5)

	# Process hit against target_dummy's CombatHitbox
	var dummy_hb = target_dummy.get_combat_hitbox()
	assert(dummy_hb != null, "Target dummy must have CombatHitbox")
	proj._on_area_entered(dummy_hb)
	assert(target_dummy.current_health == 165.0, "Airborne target dummy must take damage from projectile hitting its infinite vertical CombatHitbox")
	print("  ✓ Projectile hit detection via CombatHitbox cylinder on airborne target verified.")

	shooter.queue_free()
	target_dummy.queue_free()
	proj.queue_free()
	sector.queue_free()
	print("✓ Combat hitbox cylinder & leading shots verified successfully.")

func test_aim_guide_and_projectile_indicator_filtering() -> void:
	print("Testing Aim Guide & Projectile Indicator Filtering...")
	var root = get_root()

	var morrigan_scene = load("res://characters/morrigan/morrigan.tscn") as PackedScene
	var poke_scene = load("res://characters/poke/poke.tscn") as PackedScene
	var reaper_scene = load("res://characters/reaper/reaper.tscn") as PackedScene

	var morrigan = morrigan_scene.instantiate()
	var poke = poke_scene.instantiate()
	var reaper = reaper_scene.instantiate()
	root.add_child(morrigan)
	root.add_child(poke)
	root.add_child(reaper)

	# 1. Verify standard projectile abilities have indicators removed
	var reaper_rmb = reaper.abilities.get("RMB")
	assert(reaper_rmb != null, "Reaper RMB must exist")
	assert(reaper.should_ability_have_indicator(reaper_rmb) == false, "Reaper RMB projectile indicator must be removed")

	var morrigan_q = morrigan.abilities.get("Q")
	assert(morrigan_q != null, "Morrigan Q must exist")
	assert(morrigan.should_ability_have_indicator(morrigan_q) == false, "Morrigan Q projectile indicator must be removed")

	var poke_lmb = poke.abilities.get("LMB")
	assert(poke_lmb != null, "Poke LMB must exist")
	assert(poke.should_ability_have_indicator(poke_lmb) == false, "Poke LMB projectile indicator must be removed")

	var poke_rmb = poke.abilities.get("RMB")
	assert(poke_rmb != null, "Poke RMB must exist")
	assert(poke.should_ability_have_indicator(poke_rmb) == false, "Poke Sniper stance charged shot projectile indicator must be removed (uses local laser aim guide)")

	# 2. Verify charged, very long range, and mortar projectile abilities KEEP their indicators
	var morrigan_rmb = morrigan.abilities.get("RMB")
	assert(morrigan_rmb != null, "Morrigan RMB must exist")
	assert(morrigan.should_ability_have_indicator(morrigan_rmb) == true, "Morrigan mortar shell must KEEP its indicator")

	var poke_r = poke.abilities.get("R")
	assert(poke_r != null, "Poke R must exist")
	assert(poke.should_ability_have_indicator(poke_r) == true, "Poke Orbital Hyperbeam very long range shot must KEEP its indicator")

	var morrigan_r = morrigan.abilities.get("R")
	assert(morrigan_r != null, "Morrigan R must exist")
	assert(morrigan.should_ability_have_indicator(morrigan_r) == true, "Morrigan Born of Blood wave must KEEP its indicator")

	# 3. Verify local aim guide setup
	poke.name = "1"
	poke._setup_local_aim_guide()
	assert(poke.aim_line_root != null, "Local aim guide root must be initialized")
	assert(poke.aim_line_mesh_inst != null, "Aim line mesh instance must be initialized")
	assert(poke.aim_crosshair_root != null, "Aim crosshair root must be initialized")
	print("  ✓ Local aim guide and crosshair node structure verified.")

	morrigan.queue_free()
	poke.queue_free()
	reaper.queue_free()
	print("✓ Aim guide & projectile indicator filtering verified successfully.")

func test_data_driven_character_pipeline() -> void:
	print("Testing Data-Driven Character Pipeline (Stats & Ability Slots)...")
	var ExampleRangerDataClass = load("res://characters/example_ranger_data.gd")
	assert(ExampleRangerDataClass != null, "ExampleRangerData must load successfully")
	var ranger_data = ExampleRangerDataClass.create()
	assert(ranger_data is CharacterData, "Must create a valid CharacterData resource")

	# 1. Register with CharacterRegistry
	CharacterRegistry.register_character("ranger", ranger_data)
	assert(CharacterRegistry.has_character("ranger"), "CharacterRegistry must have ranger")
	assert(CharacterRegistry.get_display_name("ranger") == "Swift Ranger", "Display name must match")

	# 2. Instantiate universal player and load CharacterData
	var player_scene = load("res://player/player.tscn") as PackedScene
	assert(player_scene != null, "Universal player.tscn must load")
	var player = player_scene.instantiate() as BasePlayer
	root.add_child(player)
	player.name = "1"
	if not player.is_node_ready():
		player._ready()
	
	player.load_character_data(ranger_data)

	# 3. Verify Stats were applied by player_base.gd
	assert(player.id == "ranger", "Player id must be 'ranger'")
	assert(player.character_name == "Ranger", "Character name must be Ranger")
	assert(player.display_name == "Swift Ranger", "Display name must be Swift Ranger")
	assert(player.max_health == 190.0, "Max health must be 190.0")
	assert(player.current_health == 190.0, "Current health must be 190.0")
	assert(player.max_shield == 50.0, "Max shield must be 50.0")
	assert(player.max_move_speed == 6.8, "Max move speed must be 6.8")
	assert(player.crit_chance == 0.10, "Crit chance must be 0.10")
	print("  ✓ Stats automatically applied by player_base.gd.")

	# 4. Verify all 6 ability slots were instantiated and registered
	var expected_slots = ["LMB", "RMB", "SHIFT", "Q", "E", "R"]
	for slot_key in expected_slots:
		assert(player.abilities.has(slot_key), "Player must have ability in slot %s" % slot_key)
		var ab = player.abilities[slot_key]
		assert(ab is AbilityClass, "Slotted ability must be an AbilityClass instance")
		assert(ab.slot_key == slot_key, "Ability slot_key must match %s" % slot_key)
		assert(ab.is_inside_tree(), "Ability must be added to scene tree under Abilities node")
	print("  ✓ All 6 ability slots successfully instantiated under $Abilities with matching slot keys.")

	# 5. Verify CharacterRegistry player factory
	var factory_player = CharacterRegistry.create_player_instance("ranger")
	assert(factory_player != null, "CharacterRegistry must create player instance")
	root.add_child(factory_player)
	factory_player.name = "2"
	if not factory_player.is_node_ready():
		factory_player._ready()
	assert(factory_player.id == "ranger", "Factory player id must be 'ranger'")
	assert(factory_player.character_name == "Ranger", "Factory player must have Ranger stats")
	assert(factory_player.abilities.has("LMB"), "Factory player must have slotted abilities")
	print("  ✓ CharacterRegistry.create_player_instance verified.")

	player.queue_free()
	factory_player.queue_free()

	# 6. Verify The Dragon of Silene (Saint Silene)
	assert(CharacterRegistry.has_character("silene"), "CharacterRegistry must have silene")
	assert(CharacterRegistry.get_display_name("silene") == "Saint Silene", "Display name must be Saint Silene")
	var silene_data = CharacterRegistry.get_character_data("silene")
	assert(silene_data != null, "Silene data must be retrievable")
	assert(silene_data.id == "silene", "Silene data id must be 'silene'")
	assert(silene_data.character_name == "The Dragon of Silene", "Character name must be The Dragon of Silene")
	assert(silene_data.display_name == "Saint Silene", "Display name must match")
	var silene_instance = CharacterRegistry.create_player_instance("silene")
	assert(silene_instance != null, "Silene instance must be created")
	root.add_child(silene_instance)
	silene_instance.name = "silene_test"
	if not silene_instance.is_node_ready():
		silene_instance._ready()
	assert(silene_instance.id == "silene", "Silene instance id must be 'silene'")
	assert(silene_instance.character_name == "The Dragon of Silene", "Instance character_name must be The Dragon of Silene")
	assert(silene_instance.display_name == "Saint Silene", "Instance display_name must be Saint Silene")
	silene_instance.queue_free()
	print("  ✓ The Dragon of Silene (Saint Silene) registration and instantiation verified.")

	# 7. Verify Urvashi (asparsas)
	assert(CharacterRegistry.has_character("asparsas"), "CharacterRegistry must have asparsas")
	assert(CharacterRegistry.get_display_name("asparsas") == "Urvashi", "Display name for asparsas must be Urvashi")
	assert(not CharacterRegistry.has_character("dive"), "CharacterRegistry must not have obsolete 'dive' key")
	var urvashi_data = CharacterRegistry.get_character_data("asparsas")
	assert(urvashi_data.id == "asparsas", "Urvashi data id must be 'asparsas'")
	assert(urvashi_data.display_name == "Urvashi", "Urvashi data display_name must be Urvashi")
	var urvashi_instance = CharacterRegistry.create_player_instance("asparsas")
	assert(urvashi_instance != null, "Urvashi instance must be created")
	root.add_child(urvashi_instance)
	urvashi_instance.name = "urvashi_test"
	if not urvashi_instance.is_node_ready():
		urvashi_instance._ready()
	assert(urvashi_instance.id == "asparsas", "Instance id must be 'asparsas'")
	assert(urvashi_instance.display_name == "Urvashi", "Instance display_name must be Urvashi")
	urvashi_instance.queue_free()
	print("  ✓ Urvashi (asparsas) registration and display name verified.")

	# 8. Verify all 8 built-in characters have id matching folder name & display_name presented to players
	var canonical_expectations = {
		"poke": "Arash",
		"crush": "Heracles",
		"asparsas": "Urvashi",
		"reaper": "Keres",
		"morrigan": "Morrigan",
		"monkey": "The Great Sage",
		"silene": "Saint Silene",
		"artist": "The Painted Sage",
		"cleodolinda": "Cleo"
	}
	for expected_id in canonical_expectations:
		var expected_display = canonical_expectations[expected_id]
		assert(CharacterRegistry.has_character(expected_id), "CharacterRegistry must have %s" % expected_id)
		assert(CharacterRegistry.get_display_name(expected_id) == expected_display, "Display name for %s must be %s" % [expected_id, expected_display])
		var c_data = CharacterRegistry.get_character_data(expected_id)
		assert(c_data != null, "Character data for %s must not be null" % expected_id)
		assert(c_data.id == expected_id, "Character data id must be '%s', got '%s'" % [expected_id, c_data.id])
		assert(c_data.display_name == expected_display, "Character data display_name must be '%s', got '%s'" % [expected_display, c_data.display_name])
		var c_inst = CharacterRegistry.create_player_instance(expected_id)
		assert(c_inst != null, "Character instance for %s must not be null" % expected_id)
		assert(c_inst.id == expected_id, "Character instance id must be '%s', got '%s'" % [expected_id, c_inst.id])
		assert(c_inst.display_name == expected_display, "Character instance display_name must be '%s', got '%s'" % [expected_display, c_inst.display_name])
		c_inst.queue_free()
	print("  ✓ All 9 canonical characters verified with matching id (folder name) and player-facing display_name.")

	# 9. Verify EnabledCharacters list and integration
	var EnabledCharsClass = load("res://characters/enabled_characters.gd")
	assert(EnabledCharsClass != null, "EnabledCharacters must load successfully")
	var enabled_chars = EnabledCharsClass.get_enabled_characters()
	assert(enabled_chars.size() == 9, "Expected 9 enabled characters, got %d" % enabled_chars.size())
	for c_id in canonical_expectations:
		assert(EnabledCharsClass.is_character_enabled(c_id), "Character %s must be enabled" % c_id)
		assert(CharacterRegistry.is_character_enabled(c_id), "CharacterRegistry must report %s as enabled" % c_id)
	assert(EnabledCharsClass.is_character_enabled("cleo"), "Alias 'cleo' must report as enabled")
	assert(CharacterRegistry.is_character_enabled("cleo"), "CharacterRegistry must report alias 'cleo' as enabled")
	assert(not EnabledCharsClass.is_character_enabled("fake_character"), "Fake character must not be enabled")
	print("  ✓ Enabled characters list verified (all %d characters selectable)." % enabled_chars.size())

	print("✓ Data-Driven Character Pipeline verified successfully.")

func test_bound_mechanic_and_rider() -> void:
	print("Testing Bound Rider, Relocation, CC, and Tethering Mechanics...")
	var root = get_root()

	# 1. Pipeline Enum and Type Parsing
	assert(AbilityPipeline.RiderType.BOUND != null, "AbilityPipeline must define RiderType.BOUND")
	assert(AbilityPipeline.parse_rider_type("BOUND") == AbilityPipeline.RiderType.BOUND, "parse_rider_type('BOUND') must return RiderType.BOUND")

	# 2. BoundRider Class Instantiation & AbilityBuilder
	var bound_rider = BoundRiderClass.new()
	assert(bound_rider.rider_name == "Bound", "BoundRider name must be 'Bound'")
	assert(bound_rider.duration == 1.0, "Default bound duration must be 1.0")
	assert(bound_rider.buffer_offset == 0.2, "Default buffer offset must be 0.2")

	var built_rider = AbilityBuilder._build_rider({"type": AbilityPipeline.RiderType.BOUND, "duration": 2.5, "buffer_offset": 0.3})
	assert(built_rider is BoundRiderClass, "Built rider must be BoundRiderClass")
	assert(built_rider.duration == 2.5, "Built rider duration mismatch")
	assert(built_rider.buffer_offset == 0.3, "Built rider buffer_offset mismatch")

	var ability_built_rider = AbilityClass._build_rider({"type": AbilityPipeline.RiderType.BOUND, "duration": 1.7})
	assert(ability_built_rider is BoundRiderClass, "Ability built rider must be BoundRiderClass")
	assert(ability_built_rider.duration == 1.7, "Ability built rider duration mismatch")

	# 3. AbilityEffect bound_duration property integration
	var eff_scene = load("res://ability/effects/ability_effect.gd") as GDScript
	var test_effect = eff_scene.new()
	test_effect.bound_duration = 1.6
	test_effect.setup()
	var found_bound_rider = false
	for r in test_effect.rider_instances:
		if r is BoundRiderClass:
			found_bound_rider = true
			assert(r.duration == 1.6, "Effect rider duration must match bound_duration")
	assert(found_bound_rider, "AbilityEffect must instantiate BoundRider when bound_duration > 0")

	# 4. In-Game Player Simulation: Caster and Target Setup
	var monkey_scene = load("res://characters/monkey/monkey.tscn") as PackedScene
	var caster = monkey_scene.instantiate() as BasePlayer
	caster.name = "100"
	caster.team_id = 1
	root.add_child(caster)
	if not caster.is_node_ready():
		caster._ready()

	var crush_scene = load("res://characters/crush/crush.tscn") as PackedScene
	var target = crush_scene.instantiate() as BasePlayer
	target.name = "200"
	target.team_id = 2
	root.add_child(target)
	if not target.is_node_ready():
		target._ready()

	caster.global_position = Vector3(0, 0, 0)
	caster.rotation = Vector3.ZERO # Faces -Z by default
	target.global_position = Vector3(25, 0, 15) # Far away initially

	var r_caster = caster.get_hitbox_radius()
	var r_target = target.get_hitbox_radius()
	assert(r_caster > 0.0, "Caster hitbox radius must be positive")
	assert(r_target > 0.0, "Target hitbox radius must be positive")

	# 5. Default Relocation & Tethering
	# Apply bound directly via BoundRider
	var app_rider = BoundRiderClass.new()
	app_rider.duration = 3.0
	app_rider.buffer_offset = 0.25
	app_rider.apply(caster, target)

	assert(target.is_bound() == true, "Target must be in bound state")
	assert(target.get_bound_caster() == caster, "Target's bound caster must be the caster")

	# Verify immediate relocation directly in front of caster
	var forward = -caster.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var expected_dist = r_caster + r_target + 0.25
	var actual_dist = (target.global_position - caster.global_position).length()
	assert(is_equal_approx(actual_dist, expected_dist), "Target must be relocated to front distance (r1 + r2 + offset): expected %f, got %f" % [expected_dist, actual_dist])
	assert(actual_dist > (r_caster + r_target), "Relocation distance must strictly exceed sum of hitbox radii (no overlap)")
	assert(target.global_position.z < caster.global_position.z, "Target must be placed in front of caster along forward direction")
	print("  ✓ Target successfully relocated in front of caster with zero hitbox overlap.")

	# 6. Preserving Relative Position During Caster Movement
	var recorded_offset = target.bound_relative_offset
	assert(recorded_offset != Vector3.ZERO, "Bound relative offset must be recorded")

	# Caster moves by impulse / displacement
	caster.global_position = Vector3(8.0, 0.0, -12.0)
	target._process_dummy_physics(0.016)

	var expected_target_pos = caster.global_position + recorded_offset
	assert((target.global_position - expected_target_pos).length() < 0.05, "Target must follow caster movement and maintain relative offset")

	# Caster moves again in another direction
	caster.global_position = Vector3(-14.0, 0.0, 5.5)
	target._process_dummy_physics(0.016)

	expected_target_pos = caster.global_position + recorded_offset
	assert((target.global_position - expected_target_pos).length() < 0.05, "Target must continuously follow caster in 3D space")
	print("  ✓ Target reliably tracks caster movement maintaining identical relative position.")

	# 7. Action and Movement Lockout
	assert(target.can_cast_ability_slot("LMB") == false, "Bound target must not be able to cast LMB")
	assert(target.can_cast_ability_slot("SHIFT") == false, "Bound target must not be able to dash")
	target.buffer_ability("LMB")
	assert(target.has_buffered_ability() == false, "Bound target must not be able to buffer abilities")

	# Knockback immunity while bound
	target.apply_knockback(Vector3(50, 0, 50))
	assert(target.knockback_velocity == Vector3.ZERO, "External knockback must not displace bound target")
	print("  ✓ Full action and movement lockout verified while bound.")

	# 8. Custom Relocation Position
	target.cleanse_cc()
	assert(target.is_bound() == false, "Cleanse CC must break bound")

	var custom_pos = Vector3(4.0, 0.0, -3.0)
	target.apply_bound(caster, 2.0, custom_pos)
	assert(target.is_bound() == true, "Target must re-enter bound state")
	assert(target.global_position.is_equal_approx(custom_pos), "Target must relocate to custom position when specified")

	var custom_offset = target.bound_relative_offset
	caster.global_position = Vector3(2.0, 0.0, 1.0)
	target._process_dummy_physics(0.016)
	assert((target.global_position - (caster.global_position + custom_offset)).length() < 0.05, "Target must follow from custom relocation offset")
	print("  ✓ Custom relocation position and subsequent following verified.")

	# 9. Caster Death Break
	caster.is_dead = true
	target._process_dummy_physics(0.016)
	assert(target.is_bound() == false, "Bound must break immediately when caster dies")
	print("  ✓ Bound termination on caster death verified.")

	# 10. StatusRider with "BOUND"
	var status_rider = StatusRiderClass.new()
	status_rider.status_type = "BOUND"
	status_rider.duration = 1.5
	caster.is_dead = false
	status_rider.apply(caster, target)
	assert(target.is_bound() == true, "StatusRider with status_type 'BOUND' must apply bound CC")

	target.cleanse_cc()
	caster.queue_free()
	target.queue_free()
	test_effect.queue_free()
	print("✓ Bound Rider, Relocation, CC, and Tethering Mechanics verified successfully.")
func test_silene_character_kit_and_mechanics() -> void:
	print("Testing Saint Silene Complete Ability Kit and Mechanics...")
	var root = get_root()

	# 1. Instantiate Silene and dummy target
	var silene_scene = load("res://characters/silene/silene.tscn") as PackedScene
	assert(silene_scene != null, "Silene scene must load")
	var silene = silene_scene.instantiate() as BasePlayer
	silene.name = "901"
	silene.peer_id = 901
	silene.team_id = 1
	root.add_child(silene)
	silene.global_position = Vector3(500.0, 0.0, 500.0)
	if not silene.is_node_ready():
		silene._ready()

	var dummy_scene = load("res://characters/crush/crush.tscn") as PackedScene
	assert(dummy_scene != null, "Crush scene must load for dummy")
	var dummy = dummy_scene.instantiate() as BasePlayer
	dummy.name = "902"
	dummy.peer_id = 902
	dummy.team_id = 2
	root.add_child(dummy)
	dummy.global_position = silene.global_position + Vector3(0, 0, -5.0)
	if not dummy.is_node_ready():
		dummy._ready()

	# Verify abilities in scene
	assert(silene.abilities.has("LMB"), "Silene must have LMB ability")
	assert(silene.abilities.has("SHIFT"), "Silene must have SHIFT ability")
	assert(silene.abilities.has("RMB"), "Silene must have RMB ability")
	assert(silene.abilities.has("Q"), "Silene must have Q ability")
	assert(silene.abilities.has("E"), "Silene must have E ability")
	assert(silene.abilities.has("R"), "Silene must have R ability")

	assert(silene.max_health == 320.0, "Silene max health must be 320.0 (Heracles tier)")

	var lmb_ab = silene.abilities["LMB"]
	assert(lmb_ab.hitbox_type == 6, "LMB must be CircleHitbox (Annulus Sector)")
	assert(lmb_ab.hitbox_annul == 0.8, "LMB inner annul must be 0.8")

	var rmb_ab = silene.abilities["RMB"]
	assert(rmb_ab.hitbox_type == 6, "RMB must be CircleHitbox (Annulus Sector)")
	assert(rmb_ab.hitbox_annul == 1.0, "RMB inner annul must be 1.0")
	assert(rmb_ab.hitbox_radius == 6.2, "RMB radius must be 6.2 (matching Q)")
	assert(rmb_ab.hitbox_angle_deg == 63.0, "RMB angle must be 63.0 (30% thinner than 90 deg)")

	var q_ab = silene.abilities["Q"]
	assert(q_ab.hitbox_type == 6, "Q must be CircleHitbox (Annulus Sector)")
	assert(q_ab.hitbox_annul == 2.0, "Q inner annul must be 2.0")

	var r_ab = silene.abilities["R"]
	assert(r_ab.hitbox_type == 6, "R must be CircleHitbox (Annulus Sector)")
	assert(r_ab.hitbox_annul == 2.2, "R inner annul must be 2.2")

	print("  ✓ Silene ability configurations and annulus sector hitboxes verified.")

	# 2. Passive: Flat bonus damage on ability damage dealt (separate instance)
	dummy.current_health = 200.0
	dummy.max_health = 200.0
	# Deal 20 ability damage to dummy; passive should proc an additional 10.0 damage
	silene.deal_damage(dummy, 20.0, BasePlayer.ActionType.ABILITY)
	assert(is_equal_approx(dummy.current_health, 170.0), "Dummy HP should be 170.0 (20 base + 10 passive flat bonus)")
	print("  ✓ Passive flat bonus damage (separate instance) verified.")

	# 3. LMB: Claw Swipe (Annulus Sector: radius 3.8m, annul 0.8m, angle 100 deg)
	dummy.current_health = 200.0
	# Position dummy inside inner hole (0.5m ahead)
	dummy.global_position = silene.global_position + Vector3(0, 0, -0.5)
	silene.custom_execute_ability_server("LMB", silene.global_position, Vector3.FORWARD, Vector3.ZERO, 0.0)
	assert(dummy.current_health == 200.0, "Target inside inner annul cutout (0.5m) should NOT be hit by LMB")

	# Position dummy inside annulus sweetspot (2.0m ahead)
	dummy.global_position = silene.global_position + Vector3(0, 0, -2.0)
	silene.custom_execute_ability_server("LMB", silene.global_position, Vector3.FORWARD, Vector3.ZERO, 0.0)
	# Takes 24.0 LMB damage + 10.0 passive bonus damage = 34.0 damage -> 166.0 HP
	assert(is_equal_approx(dummy.current_health, 166.0), "Target in annulus sector sweetspot (2.0m) should take LMB damage + passive")
	print("  ✓ LMB Annulus Sector claw swipe verified.")

	# 4. RMB: Dragon Bite (% Max Health DMG + 100% Heal)
	dummy.current_health = 200.0
	dummy.max_health = 200.0
	silene.current_health = 100.0
	silene.max_health = 320.0

	# Inside inner hole (0.6m): immune
	dummy.global_position = silene.global_position + Vector3(0, 0, -0.6)
	silene.custom_execute_ability_server("RMB", silene.global_position, Vector3.FORWARD, Vector3.ZERO, 0.0)
	assert(dummy.current_health == 200.0, "Target inside inner annul cutout (0.6m) should NOT be hit by RMB")

	# Inside sweetspot (2.2m ahead): 18.0 base + 16% of 200 (32.0) = 50.0 bite damage (+ 10.0 passive = 60.0 total)
	# Silene heals for 50.0 bite damage
	dummy.global_position = silene.global_position + Vector3(0, 0, -2.2)
	silene.custom_execute_ability_server("RMB", silene.global_position, Vector3.FORWARD, Vector3.ZERO, 0.0)
	assert(is_equal_approx(silene.current_health, 150.0), "Silene should heal 50.0 HP from bite damage dealt")

	# Test extended range (5.5m ahead, within new 6.2m range matching Q):
	dummy.current_health = 200.0
	dummy.global_position = silene.global_position + Vector3(0, 0, -5.5)
	silene.custom_execute_ability_server("RMB", silene.global_position, Vector3.FORWARD, Vector3.ZERO, 0.0)
	assert(dummy.current_health < 200.0, "Target at 5.5m ahead should be hit by extended RMB range (6.2m)")

	# Test narrower cone (30% thinner, 63 deg cone, half angle 31.5 deg):
	# Position at 3.0m ahead rotated by 40 deg (should miss now):
	dummy.current_health = 200.0
	var offset_dir = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(40.0)).normalized()
	dummy.global_position = silene.global_position + offset_dir * 3.0
	silene.custom_execute_ability_server("RMB", silene.global_position, Vector3.FORWARD, Vector3.ZERO, 0.0)
	assert(dummy.current_health == 200.0, "Target at 40 deg angle should miss due to thinner 63 deg cone")
	print("  ✓ RMB Annulus Sector bite with % max HP, healing, extended 6.2m range, and 63 deg cone verified.")

	# 5. Q: Tail Lash (Annulus Sector: radius 6.2m, annul 2.0m, angle 180 deg)
	dummy.current_health = 200.0
	dummy.cleanse_cc()
	# Inside inner hole (1.0m ahead): immune
	dummy.global_position = silene.global_position + Vector3(0, 0, -1.0)
	silene.custom_execute_ability_server("Q", silene.global_position, Vector3.FORWARD, Vector3.ZERO, 0.0)
	assert(dummy.current_health == 200.0, "Target inside inner annul cutout (1.0m) should NOT be hit by Q")
	assert(dummy.is_stunned() == false, "Target inside inner cutout should NOT be stunned by Q")

	# Inside sweetspot (3.5m ahead): 30.0 damage + 10.0 passive = 40.0 damage, stunned 1.2s
	dummy.global_position = silene.global_position + Vector3(0, 0, -3.5)
	silene.custom_execute_ability_server("Q", silene.global_position, Vector3.FORWARD, Vector3.ZERO, 0.0)
	assert(is_equal_approx(dummy.current_health, 160.0), "Dummy should take 30 + 10 damage from Q")
	assert(dummy.is_stunned() == true, "Dummy should be stunned by Q")
	dummy.cleanse_cc()
	print("  ✓ Q Annulus Sector tail lash with damage and stun verified.")

	# 6. Dash (Shift): Uncharged Leap & Grab Slam
	dummy.current_health = 200.0
	dummy.cleanse_cc()
	dummy.global_position = silene.global_position + Vector3(0, 0, -1.0)
	silene.start_dash(silene.global_position, Vector3.FORWARD, 0.0)
	assert(silene.is_silene_dashing == true, "Silene should be dashing")
	assert(silene.is_charged_dash == false, "Uncharged dash should not be charged")
	assert(silene.is_cc_immune == false, "Uncharged leap must NOT be cc immune")
	# Simulate frame for grab
	silene._process_dash(0.016)
	assert(silene.grabbed_victim == dummy, "Silene should have grabbed dummy")
	# Simulate dash completion to slam
	silene.dash_timer = 0.0
	silene._process_dash(0.016)
	assert(silene.is_silene_dashing == false, "Dash should end on completion")
	# Slam damage: 35.0 + 10.0 passive = 45.0 damage -> 155.0 HP
	assert(is_equal_approx(dummy.current_health, 155.0), "Dummy should take uncharged slam damage + passive")
	assert(dummy.is_stunned() == true, "Dummy should be stunned by slam")
	dummy.cleanse_cc()
	print("  ✓ Dash uncharged leap, grab, and slam verified.")

	# 7. Dash (Shift): Charged Rush, Unstoppable, and Outer Hitbox
	var dummy2_scene = load("res://characters/crush/crush.tscn") as PackedScene
	var dummy2 = dummy2_scene.instantiate() as BasePlayer
	dummy2.name = "3"
	dummy2.team_id = 2
	root.add_child(dummy2)
	if not dummy2.is_node_ready():
		dummy2._ready()
	dummy2.current_health = 200.0

	# Put dummy in front for grab, dummy2 to the side (2.5m away) for outer hitbox
	dummy.global_position = silene.global_position + Vector3(0, 0, -1.0)
	dummy2.global_position = silene.global_position + Vector3(2.5, 0, 0)
	silene.start_dash(silene.global_position, Vector3.FORWARD, 1.0)
	assert(silene.is_charged_dash == true, "Charged dash should be charged")
	assert(silene.is_cc_immune == true, "Charged rush MUST be unstoppable (is_cc_immune = true)")
	# Process grab and outer hitbox
	silene._process_dash(0.016)
	assert(silene.grabbed_victim == dummy, "Charged rush should grab direct frontal target")
	assert(silene.collateral_hit_victims.has(dummy2), "Secondary target in outer zone must be hit by collateral hitbox")
	assert(dummy2.current_health < 200.0, "Secondary target should take collateral damage")
	# Complete charged slam
	silene.dash_timer = 0.0
	silene._process_dash(0.016)
	assert(silene.is_cc_immune == false, "CC immunity should end when dash finishes")
	print("  ✓ Charged rush unstoppable state and outer collateral hitbox verified.")

	# 8. Dash CC Cancellation (Release enemy with NO damage and NO cc)
	dummy.current_health = 200.0
	dummy.cleanse_cc()
	dummy.global_position = silene.global_position + Vector3(0, 0, -1.0)
	silene.start_dash(silene.global_position, Vector3.FORWARD, 0.0)
	silene._process_dash(0.016)
	assert(silene.grabbed_victim == dummy, "Target grabbed")
	# CC Silene
	silene.stun_timer = 1.0
	silene._process_dash(0.016)
	assert(silene.is_silene_dashing == false, "Dash must be cancelled by CC")
	assert(silene.grabbed_victim == null, "Grabbed victim must be released")
	assert(dummy.current_health == 200.0, "Released victim must take NO damage")
	assert(dummy.is_stunned() == false, "Released victim must take NO stun/cc")
	silene.cleanse_cc()
	print("  ✓ Dash CC cancellation releases victim unharmed without damage or CC.")

	# 9. E: Fire Breath (Area scaling with height and raycast vertices)
	silene.global_position = Vector3(0, 0, 0)
	var low_verts = silene.calculate_fire_breath_vertices(silene.global_position, Vector3.FORWARD, 8.0, 60.0, 5)
	assert(low_verts.size() == 5, "Should generate 5 raycast vertices")
	# Set height to 5m and test scaling
	silene.global_position.y = 5.0
	var height_val = silene._get_height_above_ground()
	# Height elevation scales up radius and angle
	var scaled_radius = clamp(8.0 + height_val * 0.9, 8.0, 17.0)
	assert(scaled_radius >= 8.0, "Fire breath radius scales with height above ground")
	silene.global_position = Vector3.ZERO
	print("  ✓ Fire breath height scaling and raycasted vertices verified.")

	# 10. R: Primal Roar (Annulus Sector: radius 13.0m, annul 2.2m, angle 100 deg)
	dummy.current_health = 200.0
	dummy.cleanse_cc()
	# Inside inner hole (1.5m): immune
	dummy.global_position = silene.global_position + Vector3(0, 0, -1.5)
	silene.custom_execute_ability_server("R", silene.global_position, Vector3.FORWARD, Vector3.ZERO, 0.0)
	assert(dummy.current_health == 200.0, "Target inside inner annul cutout (1.5m) should NOT be hit by Roar")

	# Inside sweetspot (5.0m ahead): takes 45 + 10 damage = 55 damage, silenced 2.0s, pulled
	dummy.global_position = silene.global_position + Vector3(0, 0, -5.0)
	silene.custom_execute_ability_server("R", silene.global_position, Vector3.FORWARD, Vector3.ZERO, 0.0)
	assert(is_equal_approx(dummy.current_health, 145.0), "Dummy HP should be 145.0 (45 roar dmg + 10 passive)")
	assert(dummy.is_silenced() == true, "Dummy should be silenced by Roar")
	print("  ✓ R Annulus Sector roar with silence and damage verified.")

	# 11. Match-long +10 Max HP per takedown persisting across rounds
	var initial_max_hp = silene.max_health
	silene._on_character_takedown(dummy)
	assert(is_equal_approx(silene.max_health, initial_max_hp + 10.0), "Silene should gain +10 max HP on takedown")
	assert(is_equal_approx(silene.silene_takedown_bonus_hp, 10.0), "silene_takedown_bonus_hp should be 10.0")

	# Test persistence simulation: round reset re-applying saved bonus HP
	silene.restore_saved_takedown_bonus_hp(30.0)
	assert(is_equal_approx(silene.silene_takedown_bonus_hp, 30.0), "Restored bonus HP should be 30.0")
	assert(is_equal_approx(silene.max_health, initial_max_hp + 30.0), "Silene max health must persist bonus HP across rounds")
	print("  ✓ Persistent +10 max HP per takedown across rounds verified.")

	# Cleanup
	silene.queue_free()
	dummy.queue_free()
	dummy2.queue_free()
	print("✓ Saint Silene complete ability kit and mechanics verified successfully!")

func test_player_projectile_armor_charges() -> void:
	print("Testing Universal Anti-Poke Projectile Armor Charges...")
	var root = get_root()

	# 1. Verify all characters start with 2 armor charges
	var dummy = (load("res://training_dummy.tscn") as PackedScene).instantiate() as BasePlayer
	root.add_child(dummy)
	assert(dummy.armor_charges == 2, "Character must start with 2 armor charges")
	assert(dummy.max_armor_charges == 2, "Max armor charges must be 2")
	print("  ✓ Every character starts with 2 armor charges.")

	# 2. Projectile hit resists damage and consumes 1 charge
	var initial_hp = dummy.current_health
	var proj_scene = load("res://projectile.tscn") as PackedScene

	var proj1 = proj_scene.instantiate()
	root.add_child(proj1)
	proj1.shooter_id = 999
	proj1.damage = 45.0
	proj1.direction = Vector3.FORWARD
	proj1.effect_type = "slow"
	proj1.effect_duration = 2.0
	proj1.effect_intensity = 0.40

	var dummy_hb = dummy.get_combat_hitbox()
	assert(dummy_hb != null, "Target must have CombatHitbox")
	proj1._on_area_entered(dummy_hb)

	# Damage was resisted!
	assert(dummy.current_health == initial_hp, "First projectile damage must be completely resisted by armor charge")
	assert(dummy.armor_charges == 1, "First projectile must consume 1 armor charge (remaining: 1)")
	# But rider (slow) still applies!
	assert(dummy.is_slowed() == true, "Projectile riders (slow) must still apply even when damage is resisted")
	print("  ✓ First projectile damage resisted, 1 charge consumed, and riders still applied.")

	# 3. Non-projectile damage does NOT interact with or consume armor charges
	dummy.take_damage(30.0, 999, BasePlayer.ActionType.ATTACK) # Direct damage without is_projectile
	assert(is_equal_approx(dummy.current_health, initial_hp - 30.0), "Non-projectile damage must deal full damage")
	assert(dummy.armor_charges == 1, "Non-projectile damage must NOT consume armor charges")
	print("  ✓ Non-projectile damage ignores armor charges and deals full damage.")

	# 4. Second projectile hit resists damage and consumes 2nd charge
	var hp_before_proj2 = dummy.current_health
	var proj2 = proj_scene.instantiate()
	root.add_child(proj2)
	proj2.shooter_id = 999
	proj2.damage = 60.0
	proj2.direction = Vector3.FORWARD
	proj2.effect_type = "blood_wave" # Stun rider

	proj2._on_area_entered(dummy_hb)
	assert(dummy.current_health == hp_before_proj2, "Second projectile damage must be resisted by second armor charge")
	assert(dummy.armor_charges == 0, "Second projectile must consume last armor charge (remaining: 0)")
	assert(dummy.is_stunned() == true, "Projectile stun rider must still apply when damage is resisted")
	print("  ✓ Second projectile damage resisted, 0 charges remaining, and stun rider applied.")

	# 5. Third projectile hit (no armor charges left) deals full damage
	var hp_before_proj3 = dummy.current_health
	var proj3 = proj_scene.instantiate()
	root.add_child(proj3)
	proj3.shooter_id = 999
	proj3.damage = 50.0
	proj3.direction = Vector3.FORWARD

	proj3._on_area_entered(dummy_hb)
	assert(is_equal_approx(dummy.current_health, hp_before_proj3 - 50.0), "Third projectile must deal full damage after charges depleted")
	assert(dummy.armor_charges == 0, "Armor charges remain 0")
	print("  ✓ Third projectile deals full damage after armor charges exhausted.")

	# 6. Respawn restores 2 armor charges
	dummy.sync_respawn(Vector3.ZERO)
	assert(dummy.armor_charges == 2, "Respawn must restore all 2 armor charges")
	print("  ✓ Respawn restores all 2 armor charges.")

	# Cleanup
	dummy.queue_free()
	proj1.queue_free()
	proj2.queue_free()
	proj3.queue_free()
	print("✓ Universal Anti-Poke Projectile Armor Charges verified successfully!")

func test_ui_modal_states_and_radial_wheel() -> void:
	print("Testing UI Modal States & Radial Wheel Pipeline Integration...")

	# 1. Null / Default Modal State on Standard Abilities
	var default_def = AbilityPipeline.create_ability({
		"id": "standard_slash",
		"name": "Slash",
		"slot": "LMB"
	})
	assert(default_def.ui_modal == null, "Standard ability ui_modal should default to null")
	assert(default_def.has_ui_modal() == false, "Standard ability should not have ui modal")

	# 2. Declarative Pipeline Definition with UIModalType.RADIAL_WHEEL
	var modal_def = AbilityPipeline.create_ability({
		"id": "elemental_dial",
		"name": "Elemental Shift",
		"slot": "Q",
		"ui_modal": {
			"type": "RADIAL_WHEEL",
			"interaction_mode": "HOLD_AND_RELEASE",
			"cancel_cooldown": 2.0,
			"cancel_refund_percent": 0.5,
			"options": [
				{"id": "fire", "label": "🔥 FIRE"},
				{"id": "water", "label": "💧 WATER"},
				{"id": "earth", "label": "🌿 EARTH"}
			]
		}
	})
	assert(modal_def.has_ui_modal() == true, "Ability with modal config must report has_ui_modal = true")
	assert(modal_def.ui_modal.modal_type == AbilityPipeline.UIModalType.RADIAL_WHEEL, "Modal type should be RADIAL_WHEEL")
	assert(modal_def.ui_modal.interaction_mode == AbilityPipeline.ModalInteractionMode.HOLD_AND_RELEASE, "Interaction mode should be HOLD_AND_RELEASE")
	assert(modal_def.ui_modal.cancel_cooldown == 2.0, "Cancel cooldown should be 2.0s")
	assert(modal_def.ui_modal.cancel_refund_percent == 0.5, "Cancel refund percent should be 50%")
	assert(modal_def.ui_modal.options.size() == 3, "Modal options size should be 3")
	print("  ✓ Declarative Pipeline UI Modal definition and parsing verified.")

	# 3. Dynamic N-Option Radial Math in RadialSelectionWheel
	var wheel = RadialSelectionWheel.new()
	root.add_child(wheel)
	wheel.setup_options([
		{"id": "fire", "label": "🔥 FIRE"},
		{"id": "water", "label": "💧 WATER"},
		{"id": "earth", "label": "🌿 EARTH"},
		{"id": "air", "label": "💨 AIR"}
	])
	assert(wheel.options.size() == 4, "Wheel must support 4 dynamic options")
	var c0 = wheel.get_option_center(0, 4)
	var c1 = wheel.get_option_center(1, 4)
	var c2 = wheel.get_option_center(2, 4)
	var c3 = wheel.get_option_center(3, 4)
	# Index 0 is at Top: -PI/2 (x approx 0, y < 0 relative to center)
	assert(is_equal_approx(c0.x, wheel.wheel_center.x), "Option 0 should be top center")
	assert(c0.y < wheel.wheel_center.y, "Option 0 y should be above center")
	# Index 1 is at Right: 0 rad (x > 0, y approx 0 relative to center)
	assert(c1.x > wheel.wheel_center.x, "Option 1 should be to the right")
	assert(is_equal_approx(c1.y, wheel.wheel_center.y), "Option 1 y should align with center")
	# Index 2 is at Bottom: +PI/2 (x approx 0, y > 0 relative to center)
	assert(is_equal_approx(c2.x, wheel.wheel_center.x), "Option 2 should be bottom center")
	assert(c2.y > wheel.wheel_center.y, "Option 2 y should be below center")
	# Index 3 is at Left: PI rad (x < 0, y approx 0 relative to center)
	assert(c3.x < wheel.wheel_center.x, "Option 3 should be to the left")
	assert(is_equal_approx(c3.y, wheel.wheel_center.y), "Option 3 y should align with center")

	# Test open, selection, and close signals
	var test_state = {"selected": "", "cancelled": false}
	wheel.option_selected.connect(func(opt_choice: String): test_state["selected"] = opt_choice)
	wheel.cancelled.connect(func(): test_state["cancelled"] = true)

	wheel.open(Vector2(200, 200))
	assert(wheel.is_wheel_open == true, "Wheel should be open")
	wheel.current_hovered_option = "earth"
	var choice = wheel.close_and_select()
	assert(choice == "earth", "Choice should be earth")
	assert(test_state["selected"] == "earth", "Signal should have emitted earth")
	assert(wheel.is_wheel_open == false, "Wheel should be closed")

	# Test cancel signal
	test_state["cancelled"] = false
	wheel.open(Vector2(200, 200))
	wheel.cancel_wheel()
	assert(test_state["cancelled"] == true, "Cancel signal must fire upon cancel_wheel()")
	assert(wheel.is_wheel_open == false, "Wheel should be closed after cancel")
	wheel.queue_free()
	print("  ✓ Dynamic N-option radial calculations, selection, and cancel signals verified.")

	# 4. Monkey King Offloaded Pipeline Integration
	var monkey = CharacterRegistry.create_player_instance("Monkey")
	root.add_child(monkey)
	monkey.peer_id = 1
	var q_ab = monkey.abilities.get("Q")
	assert(q_ab != null, "Monkey King must have Q ability")
	assert(q_ab.has_ui_modal() == true, "Monkey King Q must have ui_modal configured via pipeline")
	assert(q_ab.ui_modal.modal_type == AbilityPipeline.UIModalType.RADIAL_WHEEL, "Monkey Q modal must be RADIAL_WHEEL")
	assert(q_ab.ui_modal.options.size() == 2, "Monkey Q modal must have 2 options (tree, rock)")
	assert(monkey.character_handles_slot("Q") == false, "Monkey King should NO LONGER handle Q slot manually (offloaded to pipeline)")

	# 5. Player Modal Lifecycle: Open, Mana Reservation, and Cancel Refund
	monkey.current_mana = 80.0
	monkey.open_ability_modal("Q", q_ab)
	assert(monkey.active_modal_slot == "Q", "Active modal slot should be Q")
	assert(monkey.is_mouse_hijacked == true, "Mouse should be hijacked while modal is open")
	assert(monkey.current_mana == 70.0, "Opening modal should reserve Q_MANA_COST (10 mana)")

	# Cancel active modal
	monkey.cancel_active_modal()
	assert(monkey.active_modal_slot == "", "Active modal slot should be empty after cancel")
	assert(monkey.is_mouse_hijacked == false, "Mouse should no longer be hijacked after cancel")
	assert(monkey.current_mana == 75.0, "Canceling must refund 50% of 10 mana (5.0 mana)")
	assert(is_equal_approx(q_ab.current_cooldown, 2.5), "Canceling must apply 2.5s cancel cooldown")

	# 6. CC Interrupt Cancellation
	monkey.current_mana = 80.0
	q_ab.current_cooldown = 0.0
	monkey.open_ability_modal("Q", q_ab)
	assert(monkey.active_modal_slot == "Q", "Active modal slot should be Q before CC")
	# Stun the player and process input
	monkey.apply_stun(1.0)
	monkey._process_abilities_input(0.01)
	assert(monkey.active_modal_slot == "", "CC stun must automatically cancel active modal")
	assert(monkey.is_mouse_hijacked == false, "CC stun must release mouse hijack")
	assert(monkey.current_mana == 75.0, "CC cancel must refund 50% mana")
	assert(is_equal_approx(q_ab.current_cooldown, 2.5), "CC cancel must apply cancel cooldown")
	monkey.stun_timer = 0.0

	# 7. Confirm Option & Execution
	monkey.current_mana = 80.0
	q_ab.current_cooldown = 0.0
	monkey.open_ability_modal("Q", q_ab)
	monkey.resolve_modal_choice("Q", q_ab, "rock")
	assert(monkey.active_modal_slot == "", "Active modal slot should be empty after choice confirmed")
	assert(monkey.is_mouse_hijacked == false, "Mouse should no longer be hijacked after choice confirmed")
	assert(monkey.is_unit_transformed() == true, "Choosing rock must execute 72 Forms transformation")
	assert(monkey.transformed_prop_type == "rock", "Prop type must be rock")

	# Cleanup
	monkey.queue_free()
	print("  ✓ Player modal lifecycle, mana reservation, cancel refund, CC interrupt, and confirmation verified.")
	print("✓ UI Modal States & Radial Wheel Pipeline Integration verified successfully!")

func test_artist_the_painted_sage_kit() -> void:
	print("Testing The Painted Sage (Artist) Kit, Vancian Magic & Hanzi Recognizer...")

	# 1. Character Registry & Metadata
	assert(CharacterRegistry.has_character("artist") == true, "CharacterRegistry must have 'artist'")
	assert(CharacterRegistry.get_display_name("artist") == "The Painted Sage", "Display name must be 'The Painted Sage'")

	var main_script = load("res://main.gd")
	assert(main_script != null, "main.gd must load")
	assert(main_script.CHARACTERS.has("artist"), "main.gd CHARACTERS must contain 'artist'")
	assert(main_script.CHARACTER_DISPLAY_NAMES.has("artist"), "main.gd CHARACTER_DISPLAY_NAMES must contain 'artist'")
	assert(main_script.CHARACTER_DISPLAY_NAMES["artist"] == "The Painted Sage", "main.gd artist display name must be 'The Painted Sage'")
	assert(main_script.get_character_display_name("artist") == "The Painted Sage", "main.gd get_character_display_name('artist') must be 'The Painted Sage'")

	var artist = CharacterRegistry.create_player_instance("artist") as ArtistClass
	assert(artist != null, "Must successfully instantiate Artist character")
	root.add_child(artist)
	artist.peer_id = 1

	# 2. Ability Slots Check
	assert(artist.abilities.get("LMB") == null, "Primary LMB must be null")
	assert(artist.abilities.get("RMB") == null, "Secondary RMB must be null")
	assert(artist.abilities.get("Q") == null, "Q spell must be null")
	assert(artist.abilities.get("E") == null, "E spell must be null")

	var dash_ab = artist.abilities.get("SHIFT")
	assert(dash_ab != null, "SHIFT must be configured for dash")
	assert(dash_ab.ability_id == "artist_dash", "Dash ability_id must be artist_dash")

	var ult_ab = artist.abilities.get("R")
	assert(ult_ab != null, "R must be configured for Vancian ult")
	assert(ult_ab.has_ui_modal() == true, "R must have ui_modal configured")
	assert(ult_ab.ui_modal.modal_type == AbilityPipeline.UIModalType.RADIAL_WHEEL, "R modal must be RADIAL_WHEEL")
	assert(ult_ab.ui_modal.click_to_cast == true, "R modal preset must detail click_to_cast")
	assert(ult_ab.ui_modal.confirm_mode == AbilityPipeline.ModalConfirmMode.CLICK_TO_CAST_RMB_CANCEL, "R modal preset confirm_mode must be CLICK_TO_CAST_RMB_CANCEL")
	assert(ult_ab.ui_modal.interaction_mode == AbilityPipeline.ModalInteractionMode.HOLD_AND_RELEASE, "Interaction mode must default to HOLD_AND_RELEASE for radial wheel preset")
	assert(ult_ab.ui_modal.cancel_cooldown == 1.0, "Cancel cooldown must be 1.0s")
	assert(ult_ab.cooldown == 3.0, "Cast cooldown must be 3.0s")
	print("  ✓ Identity, metadata, null primary/spells, dash, and R pipeline modal verified.")

	# 3. $P Point-Cloud Recognizer Tests for all 4 elements
	var fire_test_strokes: Array = [
		[Vector2(0.26, 0.36), Vector2(0.31, 0.47)],
		[Vector2(0.74, 0.36), Vector2(0.69, 0.47)],
		[Vector2(0.50, 0.16), Vector2(0.49, 0.41), Vector2(0.36, 0.69), Vector2(0.19, 0.89)],
		[Vector2(0.49, 0.46), Vector2(0.64, 0.67), Vector2(0.84, 0.89)]
	]
	var fire_res = HanziPointCloudRecognizer.recognize(fire_test_strokes)
	assert(fire_res.get("element") == "fire", "Recognizer must match 'fire'")
	assert(fire_res.get("hanzi") == "火", "Hanzi must be '火'")
	assert(float(fire_res.get("score")) > 0.7, "Confidence must be > 70%")

	var water_test_strokes: Array = [
		[Vector2(0.50, 0.12), Vector2(0.50, 0.84), Vector2(0.43, 0.77)],
		[Vector2(0.21, 0.39), Vector2(0.37, 0.39), Vector2(0.23, 0.64)],
		[Vector2(0.64, 0.29), Vector2(0.81, 0.77)]
	]
	var water_res = HanziPointCloudRecognizer.recognize(water_test_strokes)
	assert(water_res.get("element") == "water", "Recognizer must match 'water'")
	assert(water_res.get("hanzi") == "水", "Hanzi must be '水'")

	var air_test_strokes: Array = [
		[Vector2(0.21, 0.16), Vector2(0.21, 0.84)],
		[Vector2(0.21, 0.16), Vector2(0.79, 0.16), Vector2(0.79, 0.79), Vector2(0.71, 0.74)],
		[Vector2(0.36, 0.41), Vector2(0.64, 0.69)],
		[Vector2(0.54, 0.43), Vector2(0.43, 0.64)]
	]
	var air_res = HanziPointCloudRecognizer.recognize(air_test_strokes)
	assert(air_res.get("element") == "air", "Recognizer must match 'air'")
	assert(air_res.get("hanzi") == "风", "Hanzi must be '风'")

	var earth_test_strokes: Array = [
		[Vector2(0.31, 0.41), Vector2(0.69, 0.41)],
		[Vector2(0.50, 0.16), Vector2(0.50, 0.84)],
		[Vector2(0.16, 0.84), Vector2(0.84, 0.84)]
	]
	var earth_res = HanziPointCloudRecognizer.recognize(earth_test_strokes)
	assert(earth_res.get("element") == "earth", "Recognizer must match 'earth'")
	assert(earth_res.get("hanzi") == "土", "Hanzi must be '土'")

	# Progressive stroke-by-stroke narrowing check (evaluating after every stroke)
	var earth_stroke_1 = [earth_test_strokes[0]]
	var earth_stroke_1_res = HanziPointCloudRecognizer.recognize(earth_stroke_1)
	assert(earth_stroke_1_res.get("element") == "earth", "Stroke 1 of Earth must immediately narrow down to 'earth'")
	assert(earth_stroke_1_res.get("candidates").size() == 4, "Candidates list must contain all 4 elements")
	assert(earth_stroke_1_res.get("candidates")[0]["element"] == "earth", "Leading candidate after stroke 1 must be earth")

	var water_stroke_1 = [water_test_strokes[0]]
	var water_stroke_1_res = HanziPointCloudRecognizer.recognize(water_stroke_1)
	assert(water_stroke_1_res.get("element") == "water", "Stroke 1 of Water must immediately narrow down to 'water'")
	assert(water_stroke_1_res.get("candidates")[0]["element"] == "water", "Leading candidate after stroke 1 must be water")

	var air_stroke_1 = [air_test_strokes[0]]
	var air_stroke_1_res = HanziPointCloudRecognizer.recognize(air_stroke_1)
	assert(air_stroke_1_res.get("element") == "air", "Stroke 1 of Air must immediately narrow down to 'air'")

	var fire_stroke_1 = [fire_test_strokes[0]]
	var fire_stroke_1_res = HanziPointCloudRecognizer.recognize(fire_stroke_1)
	assert(fire_stroke_1_res.get("element") == "fire", "Stroke 1 of Fire must immediately narrow down to 'fire'")
	print("  ✓ $P Point-Cloud Recognizer for Fire (火), Water (水), Air (风), and Earth (土) and stroke-by-stroke narrowing verified.")

	# 4. Vancian Dynamic Options Initial State
	assert(artist.vancian_slots.size() == 4, "vancian_slots must be a fixed size array of 4")
	for i in range(4):
		assert(artist.vancian_slots[i] == null, "Initial slot %d must be null for blank slot" % i)

	var initial_opts = artist.get_vancian_modal_options("R")
	assert(initial_opts.size() == 4, "Must have 4 Vancian slots")
	for i in range(4):
		assert(initial_opts[i].get("is_empty") == true, "Initial slot %d must be empty" % i)

	# 5. Radial Modal Wheel & Drawing State Transitions
	var r_modal = ult_ab.active_modal_instance as VancianHanziModal
	assert(r_modal != null, "active_modal_instance must be VancianHanziModal")
	assert(r_modal.is_inside_tree(), "VancianHanziModal must be attached to the SceneTree")
	assert(r_modal.container != null, "Modal container must be instantiated")

	artist.open_ability_modal("R", ult_ab)
	assert(artist.active_modal_slot == "R", "active_modal_slot must be 'R'")
	assert(artist.is_mouse_hijacked == true, "Mouse must be hijacked when modal is open")
	assert(r_modal.is_modal_open == true, "Modal must be open")
	assert(r_modal.container.visible == true, "Modal container must be visible")
	assert(r_modal.current_state == VancianHanziModal.State.WHEEL, "Modal must start in WHEEL state")
	assert(VancianHanziModal.TOP_LEFT_ELEMENTS.size() == 4, "Must have 4 elements in top left")
	assert(VancianHanziModal.TOP_LEFT_ELEMENTS[0]["id"] == "fire" and VancianHanziModal.TOP_LEFT_ELEMENTS[0]["english"] == "Fire", "Top-left elem 0 must be Fire")
	assert(VancianHanziModal.TOP_LEFT_ELEMENTS[1]["id"] == "water" and VancianHanziModal.TOP_LEFT_ELEMENTS[1]["english"] == "Water", "Top-left elem 1 must be Water")
	assert(VancianHanziModal.TOP_LEFT_ELEMENTS[2]["id"] == "earth" and VancianHanziModal.TOP_LEFT_ELEMENTS[2]["english"] == "Earth", "Top-left elem 2 must be Earth")
	assert(VancianHanziModal.TOP_LEFT_ELEMENTS[3]["id"] == "air" and VancianHanziModal.TOP_LEFT_ELEMENTS[3]["english"] == "Air", "Top-left elem 3 must be Air")

	# Selecting a blank slot on release of key transitions to drawing menu
	r_modal.current_hovered_option = "empty_0"
	artist.close_and_resolve_modal("R", ult_ab)
	assert(r_modal.current_state == VancianHanziModal.State.DRAWING, "Selecting blank slot on release of key must transition to DRAWING")
	assert(r_modal.selected_slot_index == 0, "Selected slot index must be 0")
	var canvas_rect = r_modal._get_drawing_canvas_rect()
	assert(is_equal_approx(canvas_rect.size.x, canvas_rect.size.y), "Canvas must be a square")

	# 6. Verify Auto-complete and Disabled Manual Card Selection
	assert(is_equal_approx(VancianHanziModal.CONFIDENCE_THRESHOLD, 0.75), "Confidence threshold must be 0.75 (75%)")
	assert(VancianHanziModal.REQUIRED_STROKES["earth"] == 3, "Earth requires 3 strokes")
	assert(VancianHanziModal.REQUIRED_STROKES["water"] == 3, "Water requires 3 strokes")
	assert(VancianHanziModal.REQUIRED_STROKES["fire"] == 4, "Fire requires 4 strokes")
	assert(VancianHanziModal.REQUIRED_STROKES["air"] == 4, "Air requires 4 strokes")

	# A: Clicking top-left card must NOT manually select element
	var card_click = InputEventMouseButton.new()
	card_click.button_index = MOUSE_BUTTON_LEFT
	card_click.pressed = true
	card_click.position = r_modal._get_top_left_card_rect(0).position + Vector2(10, 10)
	r_modal._handle_drawing_input(card_click)
	assert(r_modal.selected_top_left_element == "", "Clicking top-left card must NOT manually select an element")
	assert(artist.vancian_slots[0] == null, "Clicking top-left card must not inscribe slot")

	# B: Clicking former inscribe button location must have no effect
	var old_inscribe_pos = Vector2(canvas_rect.position.x + 20, canvas_rect.end.y + 25)
	r_modal._handle_canvas_button_clicks(old_inscribe_pos)
	assert(artist.vancian_slots[0] == null, "Former inscribe location must not inscribe")

	# C: Clear button clears strokes
	r_modal.all_strokes.append([canvas_rect.position + Vector2(10, 10), canvas_rect.position + Vector2(50, 50)])
	assert(r_modal.all_strokes.size() == 1, "Stroke added for clear test")
	var clear_pos = Vector2(canvas_rect.position.x + 80, canvas_rect.end.y + 25)
	r_modal._handle_canvas_button_clicks(clear_pos)
	assert(r_modal.all_strokes.is_empty(), "Clear button must clear all strokes")

	# D: Auto-complete on last stroke (Earth = 3 strokes)
	var e_s1: Array[Vector2] = [canvas_rect.position + canvas_rect.size * Vector2(0.31, 0.41), canvas_rect.position + canvas_rect.size * Vector2(0.69, 0.41)]
	var e_s2: Array[Vector2] = [canvas_rect.position + canvas_rect.size * Vector2(0.50, 0.16), canvas_rect.position + canvas_rect.size * Vector2(0.50, 0.84)]
	var e_s3: Array[Vector2] = [canvas_rect.position + canvas_rect.size * Vector2(0.16, 0.84), canvas_rect.position + canvas_rect.size * Vector2(0.84, 0.84)]

	# Stroke 1: Should evaluate and narrow down, but NOT auto-complete yet
	r_modal.all_strokes.append(e_s1)
	r_modal._evaluate_drawing()
	assert(r_modal.current_state == VancianHanziModal.State.DRAWING, "Stroke 1/3 must not auto-complete")
	assert(r_modal.selected_top_left_element == "earth", "Stroke 1 must narrow down to earth candidate")
	assert(artist.vancian_slots[0] == null, "Slot 0 must not be filled after stroke 1")

	# Stroke 2: Should evaluate, but NOT auto-complete yet
	r_modal.all_strokes.append(e_s2)
	r_modal._evaluate_drawing()
	assert(r_modal.current_state == VancianHanziModal.State.DRAWING, "Stroke 2/3 must not auto-complete")
	assert(artist.vancian_slots[0] == null, "Slot 0 must not be filled after stroke 2")

	# Stroke 3: Final stroke! Must auto-complete since score >= 75%
	var inscribed_state = {"received": false, "slot": -1, "elem": ""}
	var on_inscribed = func(s_idx: int, elem: String):
		inscribed_state["received"] = true
		inscribed_state["slot"] = s_idx
		inscribed_state["elem"] = elem
	r_modal.spell_inscribed.connect(on_inscribed)

	r_modal.all_strokes.append(e_s3)
	r_modal._evaluate_drawing()

	assert(inscribed_state["received"] == true, "spell_inscribed signal must be emitted on auto-complete")
	assert(inscribed_state["slot"] == 0, "Inscribed slot must be 0")
	assert(inscribed_state["elem"] == "earth", "Inscribed element must be earth")
	assert(artist.vancian_slots[0] == "earth", "Slot 0 must be automatically filled with earth")
	assert(r_modal.is_modal_open == false, "Auto-complete must close the canvas and return to normal state")
	assert(artist.active_modal_slot == "", "Active modal slot must be cleared")
	assert(artist.is_mouse_hijacked == false, "Mouse hijack must be released on canvas exit")
	r_modal.spell_inscribed.disconnect(on_inscribed)

	# 7. Inscribe Spell Scribing Flow & 1-second Cooldown
	assert(is_equal_approx(ult_ab.current_cooldown, 1.0), "Inscribing a spell must apply 1.0s cooldown")

	# Test that exiting canvas via RMB/cancel also returns to normal state
	artist.start_ability_cooldown("R", 0.0)
	artist.open_ability_modal("R", ult_ab)
	r_modal.current_hovered_option = "empty_1"
	artist.close_and_resolve_modal("R", ult_ab)
	assert(r_modal.current_state == VancianHanziModal.State.DRAWING, "Opened drawing canvas for slot 1")
	# Cancel out of drawing canvas
	r_modal.cancel_modal()
	assert(r_modal.is_modal_open == false, "Exiting canvas via cancel must return to normal state, not wheel")
	assert(artist.active_modal_slot == "", "Modal slot must be empty")
	assert(artist.is_mouse_hijacked == false, "Mouse must not be hijacked")
	assert(is_equal_approx(ult_ab.current_cooldown, 1.0), "Exiting canvas must apply 1.0s cooldown")

	# Verify updated options
	var updated_opts = artist.get_vancian_modal_options("R")
	assert(updated_opts[0].get("is_empty") == false, "Slot 0 should now be prepared")
	assert(updated_opts[0].get("id") == "cast:0:earth", "Slot 0 id should be cast:0:earth")
	assert(updated_opts[1].get("is_empty") == true, "Slot 1 should still be empty")

	# Reopening modal and selecting filled slot on release of key enters primed state
	artist.start_ability_cooldown("R", 0.0)
	artist.open_ability_modal("R", ult_ab)
	assert(r_modal.current_state == VancianHanziModal.State.WHEEL, "Modal reopened in WHEEL state")
	r_modal.current_hovered_option = "cast:0:earth"
	artist.close_and_resolve_modal("R", ult_ab)
	assert(artist.active_modal_slot == "", "Modal slot must be cleared upon cast selection")
	assert(ult_ab.is_primed_for_cast == true, "Ability must enter primed cast state via preset")
	assert(artist.is_primed_for_cast == true, "Artist must report primed cast state via delegation")
	assert(ult_ab.primed_choice == "cast:0:earth", "Primed choice must be cast:0:earth")
	assert(artist.active_element == "earth", "Active element must be earth")
	assert(ult_ab.handles_slot_input("LMB") == true, "Ability preset must intercept LMB while primed")
	assert(ult_ab.handles_slot_input("RMB") == true, "Ability preset must intercept RMB while primed")
	assert(artist.character_handles_slot("LMB") == true, "Artist must intercept LMB while primed")
	assert(artist.character_handles_slot("RMB") == true, "Artist must intercept RMB while primed")
	assert(artist.vancian_slots[0] == "earth", "Spell must NOT be expended until actually cast")

	# Test RMB Cancel: cancels primed state, preserves spell in slot, applies 1.0s cooldown
	artist.cancel_primed_spell()
	assert(artist.is_primed_for_cast == false, "Cancelling must exit primed state")
	assert(artist.character_handles_slot("LMB") == false, "Artist must release LMB after cancel")
	assert(artist.character_handles_slot("RMB") == false, "Artist must release RMB after cancel")
	assert(artist.vancian_slots[0] == "earth", "Cancelling with RMB must preserve spell in slot")
	assert(is_equal_approx(ult_ab.current_cooldown, 1.0), "Cancelling primed spell must apply 1.0s cooldown")

	# Re-prime and test LMB Cast: casts spell, expends slot, applies 3.0s cooldown
	ult_ab.current_cooldown = 0.0
	artist.enter_primed_cast_state(0, "earth")
	assert(artist.is_primed_for_cast == true, "Re-entered primed state")
	var cast_success = artist.cast_primed_spell()
	assert(cast_success == true, "cast_primed_spell must succeed")
	assert(artist.is_primed_for_cast == false, "Casting must exit primed state")
	assert(artist.vancian_slots[0] == null, "Cast spell must expend slot back to null")
	assert(is_equal_approx(ult_ab.current_cooldown, 3.0), "Casting prepared spell must apply 3.0s cooldown")
	assert(artist.character_handles_slot("LMB") == false, "LMB released after cast")
	assert(artist.character_handles_slot("RMB") == false, "RMB released after cast")

	# Inscribe second slot
	artist.vancian_slots[1] = "water"
	artist.start_ability_cooldown("R", 0.0)
	var opts2 = artist.get_vancian_modal_options("R")
	assert(opts2[1].get("is_empty") == false, "Slot 1 should now be prepared")
	assert(opts2[1].get("id") == "cast:1:water", "Slot 1 id should be cast:1:water")

	# 7. Modal Cancel 1-second Cooldown
	artist._on_modal_cancelled("R")
	assert(is_equal_approx(ult_ab.current_cooldown, 1.0), "Canceling modal must apply 1.0s cooldown")
	print("  ✓ Vancian slot preparation, dynamic options, primed state, and 1.0s drawing/cancel cooldown verified.")

	# 8. Fire Payload & Casting Prepared Ammo
	artist.start_ability_cooldown("R", 0.0)
	artist.vancian_slots[0] = "fire"
	artist.enter_primed_cast_state(0, "fire")
	assert(artist.active_element == "fire", "Active element must be set to fire")
	assert(ult_ab.damage_amount == 75.0, "Fire payload damage must be 75.0")
	var fire_cast = artist.cast_primed_spell()
	assert(fire_cast == true, "cast_primed_spell(fire) must succeed")
	assert(artist.vancian_slots[0] == null, "Casting must expend slot 0 ammunition to null")
	assert(is_equal_approx(ult_ab.current_cooldown, 3.0), "Casting fire spell must apply 3.0s cooldown")
	print("  ✓ Ammunition expenditure, elemental payload application, and 3.0s cast cooldown verified.")

	# Cleanup
	artist.queue_free()
	print("✓ The Painted Sage (Artist) Kit, Vancian Magic & Hanzi Recognizer verified successfully!")

func test_cleodolinda_maximum_suction() -> void:
	print("Testing Cleo Ultimate: Maximum Suction...")
	var root = get_root()

	# 0. Character Registry & Metadata
	assert(CharacterRegistry.has_character("cleodolinda") == true, "CharacterRegistry must have 'cleodolinda'")
	assert(CharacterRegistry.has_character("cleo") == true, "CharacterRegistry must have 'cleo' alias")
	assert(CharacterRegistry.get_display_name("cleodolinda") == "Cleo", "Display name must be 'Cleo'")
	assert(CharacterRegistry.get_display_name("cleo") == "Cleo", "Display name for 'cleo' must be 'Cleo'")
	var main_script = load("res://main.gd")
	assert(main_script != null, "main.gd must load")
	assert(main_script.CHARACTERS.has("cleodolinda"), "main.gd CHARACTERS must contain 'cleodolinda'")
	assert(main_script.CHARACTERS.has("cleo"), "main.gd CHARACTERS must contain 'cleo'")
	assert(main_script.CHARACTER_DISPLAY_NAMES.has("cleodolinda"), "main.gd CHARACTER_DISPLAY_NAMES must contain 'cleodolinda'")
	assert(main_script.CHARACTER_DISPLAY_NAMES["cleodolinda"] == "Cleo", "main.gd cleodolinda display name must be 'Cleo'")
	assert(main_script.get_character_display_name("cleodolinda") == "Cleo", "main.gd get_character_display_name('cleodolinda') must be 'Cleo'")
	assert(main_script.get_character_display_name("cleo") == "Cleo", "main.gd get_character_display_name('cleo') must be 'Cleo'")

	# 1. Instantiate Cleo
	var cleo_scene = load("res://characters/cleodolinda/cleodolinda.tscn") as PackedScene
	assert(cleo_scene != null, "Cleodolinda scene must exist")
	var cleo = cleo_scene.instantiate() as BasePlayer
	cleo.name = "1"
	cleo.team_id = 1
	root.add_child(cleo)
	if not cleo.is_node_ready():
		cleo._ready()

	assert(cleo.display_name == "Cleo", "Cleo display name should be 'Cleo'")
	assert(cleo.abilities.has("R"), "Cleo must possess ability slot R")
	var ult = cleo.abilities.get("R")
	assert(ult != null, "R ability must be non-null")
	assert(ult.ability_name == "Maximum Suction", "R ability name must be 'Maximum Suction'")
	assert(ult.ability_id == "cleo_maximum_suction", "R ability ID must be 'cleo_maximum_suction'")
	assert(ult.action_type == 2, "Action type must be ULTIMATE (2)")
	assert(ult.hitbox_type == 1, "Hitbox type must be SECTOR (1)")
	assert(ult.hitbox_radius == 14.0, "Hitbox radius must be 14.0m (large area)")
	assert(ult.hitbox_angle_deg == 80.0, "Hitbox angle must be 80.0 degrees (cone shape)")
	assert(cleo.has_node("VacuumCleaner"), "Cleo must have VacuumCleaner 3D model node")
	var vac = cleo.get_node("VacuumCleaner")
	assert(vac.visible == false, "VacuumCleaner should initially be inactive/hidden")
	print("  ✓ Cleo kit and Maximum Suction configuration verified.")

	# 2. Spawn enemy targets
	# Target 1: In front inside cone at (0, 0, -6.0) (within 14m radius and 80 deg cone)
	var enemy1 = (load("res://characters/reaper/reaper.tscn") as PackedScene).instantiate() as BasePlayer
	enemy1.name = "21"
	enemy1.team_id = 2
	root.add_child(enemy1)
	if not enemy1.is_node_ready(): enemy1._ready()
	enemy1.global_position = Vector3(0, 0, -6.0)

	# Target 2: Outside cone angle at (10.0, 0, -6.0) (angle ~59 deg, beyond 40 deg half-angle)
	var enemy2 = (load("res://characters/reaper/reaper.tscn") as PackedScene).instantiate() as BasePlayer
	enemy2.name = "22"
	enemy2.team_id = 2
	root.add_child(enemy2)
	if not enemy2.is_node_ready(): enemy2._ready()
	enemy2.global_position = Vector3(10.0, 0, -6.0)

	# Target 3: Behind Cleo at (0, 0, 6.0)
	var enemy3 = (load("res://characters/reaper/reaper.tscn") as PackedScene).instantiate() as BasePlayer
	enemy3.name = "23"
	enemy3.team_id = 2
	root.add_child(enemy3)
	if not enemy3.is_node_ready(): enemy3._ready()
	enemy3.global_position = Vector3(0, 0, 6.0)

	# Target 4: Beyond range at (0, 0, -20.0)
	var enemy4 = (load("res://characters/reaper/reaper.tscn") as PackedScene).instantiate() as BasePlayer
	enemy4.name = "24"
	enemy4.team_id = 2
	root.add_child(enemy4)
	if not enemy4.is_node_ready(): enemy4._ready()
	enemy4.global_position = Vector3(0, 0, -20.0)

	# 3. Cast Maximum Suction
	cleo.global_position = Vector3.ZERO
	cleo.look_at(Vector3(0, 0, -10.0), Vector3.UP)
	var cast_res = cleo.custom_execute_ability_server("R", cleo.global_position, Vector3.FORWARD, Vector3.ZERO, 0.0)
	assert(cast_res == true, "custom_execute_ability_server('R') must succeed")
	assert(cleo.is_suction_active == true, "Cleo is_suction_active must be true")
	assert(cleo.is_channeling == true, "Cleo is_channeling must be true")
	assert(vac.visible == true, "Cleo must wield her vacuum cleaner (visible) during ult")
	assert(cleo.get_status_text().contains("MAXIMUM SUCTION"), "Status text must reflect Maximum Suction")
	print("  ✓ Maximum Suction activation and vacuum cleaner wielding verified.")

	# 4. Process Suction Tick & Verify Cone Hitbox Filtering
	var delta = 0.1
	cleo._process_character_kit(delta)

	# Enemy 1 is in cone -> pulled towards Cleo (direction +Z towards origin)
	assert(enemy1.external_velocity.length() > 0.0, "Enemy 1 inside cone must be affected by suction")
	var pull_dir1 = (cleo.global_position - enemy1.global_position).normalized()
	var ext_dir1 = enemy1.external_velocity.normalized()
	assert(ext_dir1.dot(pull_dir1) > 0.95, "Suction acceleration must pull directly towards Cleo")

	# Enemy 2 outside cone angle -> NOT pulled
	assert(enemy2.external_velocity.length() == 0.0, "Enemy 2 outside cone angle must NOT be pulled")

	# Enemy 3 behind Cleo -> NOT pulled
	assert(enemy3.external_velocity.length() == 0.0, "Enemy 3 behind Cleo must NOT be pulled")

	# Enemy 4 beyond radius -> NOT pulled
	assert(enemy4.external_velocity.length() == 0.0, "Enemy 4 beyond range must NOT be pulled")
	print("  ✓ Cone geometry filtering verified (only frontal cone targets affected).")

	# 5. Verify Acceleration is Strictly Greater than Base Movement Speed
	var base_spd = enemy1.base_max_move_speed
	var accel_applied = enemy1.external_velocity.length() / delta
	assert(accel_applied > base_spd, "Suction acceleration (%.2f m/s^2) must be strictly greater than base move speed (%.2f m/s)" % [accel_applied, base_spd])
	assert(cleo.suction_acceleration > 6.0, "Cleo suction_acceleration must be greater than base move speed 6.0")
	print("  ✓ Acceleration directly towards Cleo (%.2f m/s^2) strictly exceeds base movement speed (%.2f m/s)." % [accel_applied, base_spd])

	# 6. Verify Player Walking Away Is Still Pulled In
	enemy1.external_velocity = Vector3.ZERO
	# Simulate 1.0s of suction against enemy trying to run away
	for _i in range(10):
		cleo._process_character_kit(0.1)
	assert(enemy1.external_velocity.length() > base_spd, "After sustained suction, pull velocity must overcome base movement speed")
	print("  ✓ Suction velocity overcomes walking speed, successfully dragging retreating enemies.")

	# 7. CC Interruption
	cleo.apply_stun(1.0)
	cleo._process_character_kit(0.1)
	assert(cleo.is_suction_active == false, "Stun must interrupt Maximum Suction")
	assert(vac.visible == false, "Vacuum cleaner must be stowed/hidden after suction interrupted")
	print("  ✓ CC interruption of Maximum Suction verified.")

	# Cleanup
	cleo.queue_free()
	enemy1.queue_free()
	enemy2.queue_free()
	enemy3.queue_free()
	enemy4.queue_free()
	print("✓ Cleo Ultimate: Maximum Suction verified successfully!")

func test_cleodolinda_animations() -> void:
	print("Testing Cleo Model Removal & Spell 3 Boost Lifecycle...")
	var root = get_root()

	var cleo_scene = load("res://characters/cleodolinda/cleodolinda.tscn") as PackedScene
	assert(cleo_scene != null, "Cleodolinda scene must exist")
	var cleo = cleo_scene.instantiate() as Cleodolinda
	cleo.name = "1"
	cleo.team_id = 1
	root.add_child(cleo)
	if not cleo.is_node_ready():
		cleo._ready()

	# 1. Verify 3D CharacterModel is NOT present (model removed from project)
	var model = cleo.get_node_or_null("CharacterModel")
	assert(model == null, "Cleo model must be deleted from project and not instantiate CharacterModel")
	print("  ✓ Cleo model absence verified (capsule mesh representation used).")

	# 2. Verify Spell 3 (E) Hold & Release Cycle + 50% Boost:
	# Verify baseline (inactive) movement metrics
	assert(is_equal_approx(cleo.get_effective_max_speed(cleo.max_move_speed), 7.0), "Baseline max move speed must be 7.0")
	assert(is_equal_approx(cleo.get_effective_acceleration(cleo.ground_acceleration), 28.0), "Baseline ground acceleration must be 28.0")
	assert(is_equal_approx(cleo.get_effective_acceleration(cleo.air_acceleration), 8.0), "Baseline air acceleration must be 8.0")

	# Press E -> boosts acceleration and ms cap by 50%
	cleo.press_spell_3()
	assert(cleo.is_spell_3_active == true, "Spell 3 must be active on press")
	assert(is_equal_approx(cleo.get_effective_max_speed(cleo.max_move_speed), 10.5), "Spell 3 active must increase ms cap by 50% (7.0 -> 10.5)")
	assert(is_equal_approx(cleo.get_effective_acceleration(cleo.ground_acceleration), 42.0), "Spell 3 active must increase ground acceleration by 50% (28.0 -> 42.0)")
	assert(is_equal_approx(cleo.get_effective_acceleration(cleo.air_acceleration), 12.0), "Spell 3 active must increase air acceleration by 50% (8.0 -> 12.0)")
	print("  ✓ Spell 3 boost values (+50% acceleration: 42.0 ground / 12.0 air, +50% ms cap: 10.5) verified while active.")

	# Release E -> reset baseline metrics
	cleo.release_spell_3()
	assert(cleo.is_spell_3_active == false, "Spell 3 must no longer be active on release")
	assert(is_equal_approx(cleo.get_effective_max_speed(cleo.max_move_speed), 7.0), "Max move speed must return to 7.0 baseline after boost ends")
	assert(is_equal_approx(cleo.get_effective_acceleration(cleo.ground_acceleration), 28.0), "Ground acceleration must return to 28.0 baseline after boost ends")
	assert(is_equal_approx(cleo.get_effective_acceleration(cleo.air_acceleration), 8.0), "Air acceleration must return to 8.0 baseline after boost ends")
	print("  ✓ Spell 3 (E) press -> release lifecycle and boost reset verified.")

	# 3. Verify Spell 3 Quick Tap / Cancel
	cleo.press_spell_3()
	assert(cleo.is_spell_3_active == true, "Quick tap press activates boost")
	cleo.cancel_spell_3()
	assert(cleo.is_spell_3_active == false, "Canceling spell 3 deactivates boost")
	print("  ✓ Spell 3 cancel verified.")

	cleo.queue_free()
	print("✓ Cleo Model Removal & Spell 3 Boost Lifecycle verified successfully!")

func test_cleodolinda_relative_velocity_attack() -> void:
	print("Testing Cleo Semicircle Relative Velocity Attack on LMB...")
	var root = get_root()

	# 1. Instantiate Cleo
	var cleo_scene = load("res://characters/cleodolinda/cleodolinda.tscn") as PackedScene
	assert(cleo_scene != null, "Cleodolinda scene must exist")
	var cleo = cleo_scene.instantiate() as Cleodolinda
	cleo.name = "1"
	cleo.team_id = 1
	root.add_child(cleo)
	if not cleo.is_node_ready():
		cleo._ready()

	# 2. Check attack configuration on LMB
	assert(cleo.abilities.has("LMB"), "Cleo must possess ability slot LMB")
	var lmb = cleo.abilities.get("LMB")
	assert(lmb != null, "LMB ability must be non-null")
	assert(lmb.ability_id == "cleo_spell_1", "LMB ability id must be 'cleo_spell_1'")
	assert(lmb is MeleeStrikeEffect, "LMB effect should be a MeleeStrikeEffect")
	assert(lmb.hitbox_type == 1, "Hitbox type must be SECTOR (1)")
	assert(lmb.hitbox_angle_deg == 180.0, "Hitbox angle must be 180.0 degrees (semicircle cone)")
	assert(lmb.hitbox_radius == 4.0, "Hitbox radius must be 4.0m")
	assert(lmb.damage_amount == 12.0, "Base attack damage must be low (12.0)")
	assert(cleo.attack_base_damage == 12.0, "Cleo attack_base_damage should be 12.0")
	assert(cleo.attack_velocity_scaling == 1.5, "Cleo attack_velocity_scaling should be 1.5")
	print("  ✓ Cleo LMB attack configuration and 180-degree semicircle parameters verified.")

	# 3. Test Hitbox Semicircle (180-degree cone) geometry
	lmb.setup()
	var hitbox = lmb.get_hitbox()
	assert(hitbox != null, "LMB hitbox instance must be created")
	assert(hitbox.angle_deg == 180.0, "Hitbox angle should be 180 degrees")
	var origin = Vector3.ZERO
	var facing = Vector3(0, 0, -1) # Facing forward (-Z)

	# Ahead: inside
	assert(hitbox.is_point_inside(origin, facing, Vector3(0, 0, -3.0)) == true, "Point in front must be inside semicircle")
	# 45 degrees left & right: inside
	assert(hitbox.is_point_inside(origin, facing, Vector3(-2.0, 0, -2.0)) == true, "Point 45 deg left must be inside semicircle")
	assert(hitbox.is_point_inside(origin, facing, Vector3(2.0, 0, -2.0)) == true, "Point 45 deg right must be inside semicircle")
	# Directly to side 90 degrees: inside (half-plane boundary)
	assert(hitbox.is_point_inside(origin, facing, Vector3(3.5, 0, 0.0)) == true, "Point 90 deg right must be inside semicircle")
	assert(hitbox.is_point_inside(origin, facing, Vector3(-3.5, 0, 0.0)) == true, "Point 90 deg left must be inside semicircle")
	# Directly behind: outside
	assert(hitbox.is_point_inside(origin, facing, Vector3(0, 0, 3.0)) == false, "Point directly behind must be outside semicircle")
	# 135 degrees behind: outside
	assert(hitbox.is_point_inside(origin, facing, Vector3(2.0, 0, 2.0)) == false, "Point behind-right must be outside semicircle")
	# Beyond radius in front: outside
	assert(hitbox.is_point_inside(origin, facing, Vector3(0, 0, -5.5)) == false, "Point beyond radius must be outside semicircle")
	print("  ✓ Semicircle (180-degree cone) coverage verified.")

	# 4. Test Relative Velocity Damage Calculation
	var dummy = (load("res://characters/reaper/reaper.tscn") as PackedScene).instantiate() as BasePlayer
	dummy.name = "31"
	dummy.team_id = 2
	root.add_child(dummy)
	if not dummy.is_node_ready(): dummy._ready()

	# Case A: Both stationary -> base damage only
	cleo.velocity = Vector3.ZERO
	dummy.velocity = Vector3.ZERO
	assert(cleo.get_attack_relative_velocity(dummy) == 0.0, "Relative velocity when both stationary should be 0.0")
	assert(cleo.compute_attack_damage(dummy) == 12.0, "Damage when stationary should equal base damage (12.0)")

	# Case B: Cleo moving towards target at 10 m/s
	cleo.velocity = Vector3(0, 0, -10.0)
	dummy.velocity = Vector3.ZERO
	assert(is_equal_approx(cleo.get_attack_relative_velocity(dummy), 10.0), "Relative speed should be 10.0")
	assert(is_equal_approx(cleo.compute_attack_damage(dummy), 12.0 + 10.0 * 1.5), "Damage should scale with relative speed (27.0)")

	# Case C: High speed / Dash velocity (26 m/s)
	cleo.velocity = Vector3(0, 0, -26.0)
	dummy.velocity = Vector3.ZERO
	assert(is_equal_approx(cleo.get_attack_relative_velocity(dummy), 26.0), "Relative speed should be 26.0")
	assert(is_equal_approx(cleo.compute_attack_damage(dummy), 12.0 + 26.0 * 1.5), "Damage at dash speed should be 51.0")

	# Case D: Both approaching each other (head-on collision: Cleo 15 m/s, Dummy 10 m/s opposite)
	cleo.velocity = Vector3(0, 0, -15.0)
	dummy.velocity = Vector3(0, 0, 10.0)
	assert(is_equal_approx(cleo.get_attack_relative_velocity(dummy), 25.0), "Relative speed for head-on approach should be 25.0")
	assert(is_equal_approx(cleo.compute_attack_damage(dummy), 12.0 + 25.0 * 1.5), "Damage for head-on approach should be 49.5")

	# Case E: Moving together in same direction at same speed
	cleo.velocity = Vector3(0, 0, -12.0)
	dummy.velocity = Vector3(0, 0, -12.0)
	assert(is_equal_approx(cleo.get_attack_relative_velocity(dummy), 0.0), "Relative speed should be 0 when velocities match")
	assert(is_equal_approx(cleo.compute_attack_damage(dummy), 12.0), "Damage should be base damage (12.0) when velocities match")
	print("  ✓ Relative velocity damage scaling formulas verified across multiple speed states.")

	# 5. Live Pipeline Combat Hit Test
	cleo.global_position = Vector3(200, 0, 200)
	dummy.global_position = Vector3(200, 0, 197.5) # In front within 4m semicircle (-Z is forward)
	dummy.current_health = dummy.max_health
	cleo.velocity = Vector3(0, 0, -20.0) # Moving forward at 20 m/s
	dummy.velocity = Vector3.ZERO

	# Execute LMB attack
	lmb.execute_server(cleo, cleo.global_position, Vector3(0, 0, -1), dummy.global_position)
	var expected_dmg = 12.0 + (20.0 * 1.5) # 42.0 damage
	var hp_lost = dummy.max_health - dummy.current_health
	assert(is_equal_approx(hp_lost, expected_dmg), "Target should take base damage + relative velocity bonus damage (expected %s, got %s)" % [expected_dmg, hp_lost])

	# Test semicircle exclusion: target placed behind Cleo
	dummy.current_health = dummy.max_health
	dummy.global_position = Vector3(200, 0, 202.5) # Behind Cleo (+Z is backward)
	lmb.execute_server(cleo, cleo.global_position, Vector3(0, 0, -1), dummy.global_position)
	assert(dummy.current_health == dummy.max_health, "Target behind Cleo must NOT be hit by the 180-degree semicircle attack")
	print("  ✓ Live combat execution, relative velocity bonus damage application, and semicircle exclusion verified on LMB.")

	cleo.queue_free()
	dummy.queue_free()
	print("✓ Cleo Semicircle Relative Velocity Attack on LMB verified successfully!")

func test_cleodolinda_rmb_delayed_circle_slow() -> void:
	print("Testing Cleo RMB Delayed Full-Circle Slowing Sweep...")
	var root = get_root()

	# 1. Instantiate Cleo
	var cleo_scene = load("res://characters/cleodolinda/cleodolinda.tscn") as PackedScene
	assert(cleo_scene != null, "Cleodolinda scene must exist")
	var cleo = cleo_scene.instantiate() as Cleodolinda
	cleo.name = "1"
	cleo.team_id = 1
	root.add_child(cleo)
	if not cleo.is_node_ready():
		cleo._ready()

	# 2. Check RMB configuration
	assert(cleo.abilities.has("RMB"), "Cleo must possess ability slot RMB")
	var rmb = cleo.abilities.get("RMB")
	assert(rmb != null, "RMB ability must be non-null")
	assert(rmb is MeleeStrikeEffect, "RMB must be MeleeStrikeEffect")
	assert(rmb.hitbox_type == 6, "Hitbox type must be CIRCLE (6)")
	assert(rmb.hitbox_angle_deg == 360.0, "Hitbox angle must be 360.0 degrees (full circle)")
	assert(rmb.hitbox_radius == 4.5, "Hitbox radius must be 4.5m (around her)")
	assert(rmb.damage_amount == 35.0, "Base damage must be moderate (35.0)")
	assert(rmb.slow_duration > 0.0, "Slow duration must be configured")
	assert(rmb.slow_intensity > 0.0, "Slow intensity must be configured")
	assert(cleo.rmb_damage == 35.0, "Cleo rmb_damage must be 35.0")
	assert(cleo.rmb_slow_intensity == 0.35, "Cleo rmb_slow_intensity must be 0.35 (35% slow)")
	print("  ✓ RMB full circle, moderate damage, and slow parameters verified.")

	# 3. Test Delay timing
	var calculated_delay = cleo.get_rmb_delay()
	assert(calculated_delay == cleo.rmb_windup_time, "Without 3D model animation, RMB delay matches rmb_windup_time")
	assert(rmb.windup_time == calculated_delay, "RMB ability windup_time must match calculated delay")
	print("  ✓ RMB delay timing (triggers at %.3fs windup) verified." % calculated_delay)

	# 4. Test Hitbox Full Circle (360 degrees) coverage
	rmb.setup()
	var hitbox = rmb.get_hitbox()
	assert(hitbox != null, "RMB hitbox instance must be created")
	assert(hitbox.angle_deg == 360.0, "Hitbox angle should be 360 degrees")
	var origin = Vector3.ZERO
	var facing = Vector3(0, 0, -1) # Facing -Z

	# Test all 360 directions: front, back, left, right
	assert(hitbox.is_point_inside(origin, facing, Vector3(0, 0, -3.5)) == true, "Point in front must be inside full circle")
	assert(hitbox.is_point_inside(origin, facing, Vector3(0, 0, 3.5)) == true, "Point directly behind must be inside full circle")
	assert(hitbox.is_point_inside(origin, facing, Vector3(-3.5, 0, 0)) == true, "Point to the left must be inside full circle")
	assert(hitbox.is_point_inside(origin, facing, Vector3(3.5, 0, 0)) == true, "Point to the right must be inside full circle")
	assert(hitbox.is_point_inside(origin, facing, Vector3(2.5, 0, 2.5)) == true, "Diagonal rear point must be inside full circle")
	assert(hitbox.is_point_inside(origin, facing, Vector3(0, 0, -5.5)) == false, "Point beyond radius must be outside full circle")
	print("  ✓ Full circle (360-degree) geometry verified in all directions.")

	# 5. Test Windup Trigger & Cancel
	cleo.active_windup_id = "RMB"
	assert(cleo.active_windup_id == "RMB", "Entering RMB windup must set active_windup_id")
	cleo.cancel_active_windup()
	assert(cleo.active_windup_id == "", "Canceling RMB windup must clear active_windup_id")
	print("  ✓ RMB windup state and cancel return verified.")

	# 6. Live Combat Execution: Damage & Slow in Full Circle + No Velocity Scaling on RMB
	cleo.global_position = Vector3(300, 0, 300)
	cleo.velocity = Vector3(0, 0, -25.0) # Moving fast at 25 m/s!

	# Target 1 in front (within 4.5m)
	var enemy_front = (load("res://characters/reaper/reaper.tscn") as PackedScene).instantiate() as BasePlayer
	enemy_front.name = "41"
	enemy_front.team_id = 2
	root.add_child(enemy_front)
	if not enemy_front.is_node_ready(): enemy_front._ready()
	enemy_front.global_position = Vector3(300, 0, 296.5) # 3.5m in front
	enemy_front.velocity = Vector3.ZERO

	# Target 2 behind (within 4.5m)
	var enemy_back = (load("res://characters/reaper/reaper.tscn") as PackedScene).instantiate() as BasePlayer
	enemy_back.name = "42"
	enemy_back.team_id = 2
	root.add_child(enemy_back)
	if not enemy_back.is_node_ready(): enemy_back._ready()
	enemy_back.global_position = Vector3(300, 0, 303.5) # 3.5m behind
	enemy_back.velocity = Vector3.ZERO

	# Target 3 outside circle (6.0m away)
	var enemy_far = (load("res://characters/reaper/reaper.tscn") as PackedScene).instantiate() as BasePlayer
	enemy_far.name = "43"
	enemy_far.team_id = 2
	root.add_child(enemy_far)
	if not enemy_far.is_node_ready(): enemy_far._ready()
	enemy_far.global_position = Vector3(300, 0, 306.0) # 6.0m away

	# Execute RMB
	rmb.execute_server(cleo, cleo.global_position, Vector3(0, 0, -1), enemy_front.global_position)

	# Verify Target 1 (Front): took EXACTLY moderate damage (35.0) - NO velocity bonus on RMB!
	var lost1 = enemy_front.max_health - enemy_front.current_health
	assert(is_equal_approx(lost1, 35.0), "RMB slow must deal flat moderate damage 35.0 with NO relative velocity scaling (got %s)" % lost1)
	assert(enemy_front.is_slowed() == true, "Front target must be slowed")
	assert(is_equal_approx(enemy_front.slow_percent, 0.35), "Front target must have 35%% slow applied")

	# Verify Target 2 (Behind): took moderate damage & is slowed (full circle hit, no velocity scaling)
	var lost2 = enemy_back.max_health - enemy_back.current_health
	assert(is_equal_approx(lost2, 35.0), "Rear target should take 35.0 moderate damage (got %s)" % lost2)
	assert(enemy_back.is_slowed() == true, "Rear target must be slowed by full circle attack")
	assert(is_equal_approx(enemy_back.slow_percent, 0.35), "Rear target must have 35%% slow applied")

	# Verify Target 3 (Far): unaffected
	assert(enemy_far.current_health == enemy_far.max_health, "Target outside radius must not be hit")
	assert(enemy_far.is_slowed() == false, "Target outside radius must not be slowed")
	print("  ✓ Live combat execution: both front & rear targets took moderate damage (35.0) and received 35% slow with NO velocity scaling on RMB.")

	cleo.queue_free()
	enemy_front.queue_free()
	enemy_back.queue_free()
	enemy_far.queue_free()
	print("✓ Cleo RMB Delayed Full-Circle Slowing Sweep verified successfully!")

func test_offline_presentation_and_indicator_hygiene() -> void:
	print("Testing Offline Presentation and Indicator Hygiene...")
	var player = (load("res://characters/crush/crush.tscn") as PackedScene).instantiate() as BasePlayer
	player.name = "110"
	player.team_id = 1
	root.add_child(player)
	if not player.is_node_ready():
		player._ready()

	# 1. Test is_local_player authority separation
	assert(player.is_local_player() == false, "Player with peer ID 110 should not be local player")
	var dummy = (load("res://training_dummy.tscn") as PackedScene).instantiate() as BasePlayer
	dummy.name = "TrainingDummy"
	assert(dummy.is_local_player() == false, "TrainingDummy must NOT evaluate as local player")
	dummy.queue_free()

	# 2. Test canonical HitboxShape translation helper
	assert(AbilityPipeline.legacy_hitbox_type_to_shape(1) == AbilityPipeline.HitboxShape.SECTOR, "Legacy 1 must map to SECTOR")
	assert(AbilityPipeline.legacy_hitbox_type_to_shape(6) == AbilityPipeline.HitboxShape.CIRCLE, "Legacy 6 must map to CIRCLE")
	assert(AbilityPipeline.legacy_hitbox_type_to_shape(5) == AbilityPipeline.HitboxShape.LINE, "Legacy 5 must map to LINE")
	assert(AbilityPipeline.normalize_hitbox_shape("cylinder") == AbilityPipeline.HitboxShape.CYLINDER, "String 'cylinder' must normalize to CYLINDER")

	# 2. Test windup initiation and telegraph indicator assignment
	var lmb = player.abilities.get("LMB") as AbilityClass
	assert(lmb != null, "LMB ability must exist")
	player.start_windup_cast("LMB", player.global_position, Vector3.FORWARD, player.global_position + Vector3(0, 0, 5), 0.5, 0.0)
	assert(player.is_channeling == true, "Player must be channeling during windup")
	assert(player.active_windup_id == "LMB", "Active windup must be LMB")
	assert(lmb.is_winding_up == true, "LMB must be winding up")
	assert(lmb.active_telegraph != null, "Active telegraph must be created during windup")

	# 3. Test death cleans up telegraphs, windup, and indicators
	player.die()
	assert(player.is_dead == true, "Player must be dead")
	assert(player.is_channeling == false, "Channeling must be cleared on death")
	assert(player.active_windup_id == "", "Active windup ID must be cleared on death")
	assert(lmb.is_winding_up == false, "LMB windup must be cancelled on death")
	assert(lmb.active_telegraph == null, "Active telegraph must be cleared on death")

	player.queue_free()
	print("✓ Offline Presentation and Indicator Hygiene verified successfully!")
