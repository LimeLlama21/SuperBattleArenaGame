class_name CharactersLibrary
extends RefCounted

static var _registry: Dictionary = {}

static func _ensure_initialized() -> void:
	if not _registry.is_empty():
		return
	
	# --- Poke (Sharpshooter Character) ---
	var poke = CharacterData.new()
	poke.character_name = "Poke"
	poke.display_name = "Poke"
	poke.archetype = "Sharpshooter"
	poke.max_health = 80.0
	poke.max_move_speed = 11.5
	poke.ground_acceleration = 70.0
	poke.ground_friction = 40.0
	poke.air_acceleration = 25.0
	poke.air_drag = 3.5
	poke.jump_velocity = 9.5
	poke.dash_impulse = 28.0
	poke.max_dash_charges = 1
	poke.dash_cooldown = 4.0
	poke.dash_recharge_time = 4.0
	poke.is_melee = false
	poke.attack_cooldown = 0.9
	poke.windup_time = 0.0
	poke.projectile_size = 0.35
	poke.projectile_damage = 18.0
	poke.projectile_speed = 90.0
	poke.ability_slots = {
		"LMB": "poke_rail_shot",
		"RMB": "poke_repulsor_bolt",
		"Q": "poke_slipstream_field",
		"E": "poke_recon_flare",
		"R": "poke_overcharge",
		"SHIFT": "universal_dash"
	}
	poke.passive_data = {
		"fleet_foot_duration": 2.5,
		"fleet_foot_ms_percent": 0.15
	}
	_registry["Poke"] = poke
	_registry["poke"] = poke

	# --- Dive (Mobile Fighter Character) ---
	var dive = CharacterData.new()
	dive.character_name = "Dive"
	dive.display_name = "Dive"
	dive.archetype = "Skirmisher"
	dive.max_health = 120.0
	dive.max_move_speed = 9.5
	dive.ground_acceleration = 65.0
	dive.ground_friction = 40.0
	dive.air_acceleration = 25.0
	dive.air_drag = 3.5
	dive.jump_velocity = 9.5
	dive.dash_impulse = 26.0
	dive.max_dash_charges = 2
	dive.dash_cooldown = 0.85
	dive.dash_recharge_time = 5.0
	dive.is_melee = true
	dive.attack_cooldown = 0.45
	dive.melee_windup_time = 0.18
	dive.melee_damage = 32.0
	dive.melee_size = 3.4
	dive.melee_height = 2.4
	dive.melee_angle_deg = 100.0
	dive.ability_slots = {
		"LMB": "dive_slash",
		"RMB": "dive_heavy_cleave",
		"Q": "dive_earth_tremor",
		"E": "dive_deflecting_guard",
		"R": "dive_tectonic_uprising",
		"SHIFT": "dive_dash_or_crash"
	}
	dive.passive_data = {
		"rupture_mark_duration": 3.5,
		"rupture_mark_max": 5,
		"rupture_damage_per_mark": 12.0
	}
	_registry["Dive"] = dive
	_registry["dive"] = dive

	# --- Crush (Heavy Juggernaut Character) ---
	var crush = CharacterData.new()
	crush.character_name = "Crush"
	crush.display_name = "Crush"
	crush.archetype = "Juggernaut"
	crush.max_health = 160.0
	crush.max_move_speed = 8.5
	crush.ground_acceleration = 60.0
	crush.ground_friction = 40.0
	crush.air_acceleration = 20.0
	crush.air_drag = 3.5
	crush.jump_velocity = 9.5
	crush.dash_impulse = 24.0
	crush.max_dash_charges = 1
	crush.dash_cooldown = 8.0
	crush.dash_recharge_time = 8.0
	crush.is_melee = true
	crush.attack_cooldown = 0.65
	crush.melee_windup_time = 0.28
	crush.melee_damage = 55.0
	crush.melee_size = 4.2
	crush.melee_height = 2.4
	crush.melee_angle_deg = 120.0
	crush.ability_slots = {
		"LMB": "crush_slam",
		"RMB": "crush_fan_stun",
		"Q": "crush_ground_stomp",
		"E": "crush_iron_barrier",
		"R": "crush_juggernaut_charge",
		"SHIFT": "universal_dash"
	}
	crush.passive_data = {
		"titan_surge_damage_mult": 1.4,
		"gray_health_decay_delay": 5.0,
		"gray_health_heal_percent": 0.5
	}
	_registry["Crush"] = crush
	_registry["crush"] = crush
	
	# --- Reaper (Frightening Debuff Character)
	var reaper = CharacterData.new()
	reaper.character_name = "Reaper"
	reaper.display_name = "Reaper"
	reaper.archetype = "Reaper"
	reaper.max_health = 100.0
	reaper.max_move_speed = 10.0
	reaper.ground_acceleration = 80.0
	reaper.ground_friction = 40.0
	reaper.air_acceleration = 25.0
	reaper.air_drag = 3.5
	reaper.jump_velocity = 9.5
	reaper.dash_impulse = 28.0
	reaper.max_dash_charges = 1
	reaper.dash_cooldown = 5.0
	reaper.dash_recharge_time = 4.0
	reaper.is_melee = true
	reaper.attack_cooldown = 0.45
	reaper.windup_time = 0.18
	reaper.melee_windup_time = 0.18
	reaper.melee_size = 3.6
	reaper.melee_height = 2.4
	reaper.melee_damage = 36.0
	reaper.melee_angle_deg = 110.0
	reaper.projectile_size = 0.6
	reaper.projectile_damage = 25.0
	reaper.projectile_speed = 48.0
	reaper.ability_slots = {
		"LMB": "reaper_slash", # Slash that steals a small amount of ms, refreshing on subsequent hits
		"RMB": "reaper_tether", # Pyke hook but tethers instead of instantly stunning. Tether grounds on contact and slows over time until rooting.
		"Q": "reaper_cull_the_weak", # Darius q without healing. Sweet spot cripples, reducing attack speed and movement speed.
		"E": "reaper_nightmare", # Vlad pool. Deals aoe damage on cast and on end
		"R": "reaper_one_with_death", # Steroid, grants a large amount of movement speed and cdr, increases all riders (including damage) of all abilities
		"SHIFT": "ethereal_dash" # Grants ethereal, allowing unit to pass through terrain
	}
	reaper.passive_data = {
		"ms_steal_pct": 0.15,
		"ms_steal_duration": 2.5,
		"tether_range": 16.0,
		"tether_duration": 1.75,
		"tether_break_dist": 18.0,
		"tether_root_duration": 1.25,
		"cull_inner_damage": 30.0,
		"cull_outer_damage": 65.0,
		"cull_outer_radius": 5.5,
		"cull_inner_radius": 3.2,
		"cull_cripple_duration": 2.5,
		"nightmare_duration": 1.8,
		"nightmare_radius": 4.5,
		"nightmare_cast_damage": 35.0,
		"nightmare_end_damage": 45.0,
		"ult_duration": 8.0,
		"ult_ms_bonus": 0.45,
		"ult_cdr_mult": 0.50,
		"ult_damage_mult": 1.30
	}
	_registry["Reaper"] = reaper
	_registry["reaper"] = reaper

	# --- Training Dummy / Base Character ---
	var dummy = CharacterData.new()
	dummy.character_name = "Training Dummy"
	dummy.display_name = "Training Dummy"
	dummy.archetype = "Target"
	dummy.max_health = 100.0
	dummy.max_move_speed = 0.0
	dummy.ability_slots = {}
	_registry["Training Dummy"] = dummy
	_registry["dummy"] = dummy

static func get_character(char_name: String) -> CharacterData:
	_ensure_initialized()
	if _registry.has(char_name):
		return _registry[char_name]
	# Fallback to Poke if unrecognized
	return _registry.get("Poke", CharacterData.new())

static func get_all_characters() -> Dictionary:
	_ensure_initialized()
	return _registry
