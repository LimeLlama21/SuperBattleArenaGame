class_name NeutralRegistry
extends RefCounted

## NeutralRegistry - Central registry for data-driven NeutralType definitions.
## Provides built-in archetypes across tiers with configured stats, rewards, and attack patterns.

const NeutralTypeClass = preload("res://maps/neutral_type.gd")
const NeutralAttackClass = preload("res://maps/neutral_attack.gd")
const NeutralSpecialAttackClass = preload("res://maps/neutral_special_attack.gd")

static var _registry: Dictionary = {}
static var _initialized: bool = false

static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_register_builtin_types()

static func register_type(type: Resource) -> void:
	_ensure_initialized()
	if type and "id" in type and not str(type.id).is_empty():
		_registry[type.id] = type

static func get_type(type_id: String) -> Resource:
	_ensure_initialized()
	if _registry.has(type_id):
		return _registry[type_id]
	# Fallback to Basic Mob (lowest tier default)
	return _registry.get("basic_mob", _registry.get("sentry_t1", null))

static func has_type(type_id: String) -> bool:
	_ensure_initialized()
	return _registry.has(type_id)

static func get_all_types() -> Array:
	_ensure_initialized()
	var list: Array = []
	for k in _registry.keys():
		list.append(_registry[k])
	return list

static func _register_builtin_types() -> void:
	# =========================================================================
	# TIER 1: Basic Mob (Lowest Tier, 100 HP, 0 DMG, 3.0 MS, Frontal Cone Attack)
	# =========================================================================
	var bm = NeutralTypeClass.new()
	bm.id = "basic_mob"
	bm.display_name = "Basic Mob"
	bm.tier = 1
	bm.max_health = 100.0
	bm.damage = 0.0
	bm.move_speed = 3.0 # Half player base ms (6.0 * 0.5)
	bm.aggro_range = 8.5
	bm.attack_range = 2.4 # Initiation range: exactly 2/3 of attack range (3.6 * 2/3 = 2.4)
	bm.leash_range = 14.0
	bm.combo_reset_delay = 2.0
	bm.team_xp = 50.0
	bm.team_gold = 25
	bm.unique_reward = "" # Blank for lowest tier
	bm.unique_reward_duration = 0.0

	# Single attack for its pattern: small cone in front of it
	var bm_atk = NeutralAttackClass.new()
	bm_atk.name = "Frontal Cleave"
	bm_atk.damage = 0.0
	bm_atk.attack_range = 2.4 # Initiation range
	bm_atk.cone_range = 3.6 # Full reach of the attack itself (2.4 / 3.6 = 2/3)
	bm_atk.cone_angle = 60.0 # Small cone in front of it (60 degrees)
	bm_atk.windup_time = 0.35
	bm_atk.recovery_time = 0.55
	bm_atk.attack_type = "cone"
	bm_atk.hitbox_radius = 3.6

	bm.attack_pattern = [bm_atk]
	bm.special_attack = null # Blank

	bm.mesh_shape = "capsule"
	bm.capsule_radius = 0.45
	bm.capsule_height = 1.6
	bm.mesh_color = Color(0.78, 0.28, 0.22, 1.0)
	bm.emission_color = Color(0.9, 0.3, 0.1, 1.0)
	bm.emission_energy = 0.35

	_registry[bm.id] = bm

	# =========================================================================
	# TIER 1: Basic Sentry (Stationary Orange Sphere, Melee Strike)
	# =========================================================================
	var t1 = NeutralTypeClass.new()
	t1.id = "sentry_t1"
	t1.display_name = "Orange Sentry"
	t1.tier = 1
	t1.max_health = 200.0
	t1.damage = 20.0
	t1.move_speed = 0.0 # Stationary
	t1.aggro_range = 8.0
	t1.attack_range = 3.5
	t1.leash_range = 14.0
	t1.combo_reset_delay = 2.5
	t1.team_xp = 75.0
	t1.team_gold = 40
	t1.unique_reward = "" # Blank for Tier 1
	t1.unique_reward_duration = 0.0
	t1.mesh_shape = "sphere"
	t1.sphere_radius = 0.75
	t1.mesh_color = Color(1.0, 0.48, 0.05, 1.0)
	t1.emission_color = Color(1.0, 0.38, 0.02, 1.0)
	t1.emission_energy = 0.45

	var t1_atk = NeutralAttackClass.new()
	t1_atk.name = "Sentry Swipe"
	t1_atk.damage = 20.0
	t1_atk.attack_range = 3.5
	t1_atk.windup_time = 0.35
	t1_atk.recovery_time = 0.5
	t1_atk.attack_type = "melee"
	t1_atk.hitbox_radius = 1.8
	t1.attack_pattern = [t1_atk]
	t1.special_attack = null # Blank

	_registry[t1.id] = t1

	# =========================================================================
	# TIER 2: Enforcer (Mobile, 2-Hit Rotation, Special AOE, Swiftness Boon)
	# =========================================================================
	var t2 = NeutralTypeClass.new()
	t2.id = "enforcer_t2"
	t2.display_name = "Arena Enforcer"
	t2.tier = 2
	t2.max_health = 450.0
	t2.damage = 35.0
	t2.move_speed = 3.2
	t2.aggro_range = 10.0
	t2.attack_range = 3.2
	t2.leash_range = 15.0
	t2.combo_reset_delay = 3.0
	t2.team_xp = 160.0
	t2.team_gold = 90
	t2.unique_reward = "speed_boost" # Grants team-wide speed boost boon
	t2.unique_reward_duration = 20.0
	t2.mesh_shape = "sphere"
	t2.sphere_radius = 0.9
	t2.mesh_color = Color(1.0, 0.55, 0.12, 1.0)
	t2.emission_color = Color(1.0, 0.45, 0.05, 1.0)

	var t2_atk1 = NeutralAttackClass.new()
	t2_atk1.name = "Enforcer Jab"
	t2_atk1.damage = 25.0
	t2_atk1.attack_range = 3.2
	t2_atk1.windup_time = 0.3
	t2_atk1.recovery_time = 0.4
	t2_atk1.attack_type = "melee"
	t2_atk1.hitbox_radius = 1.8

	var t2_atk2 = NeutralAttackClass.new()
	t2_atk2.name = "Heavy Crush"
	t2_atk2.damage = 45.0
	t2_atk2.attack_range = 3.4
	t2_atk2.windup_time = 0.55
	t2_atk2.recovery_time = 0.65
	t2_atk2.attack_type = "melee"
	t2_atk2.hitbox_radius = 2.2

	t2.attack_pattern = [t2_atk1, t2_atk2]

	var t2_spec = NeutralSpecialAttackClass.new()
	t2_spec.name = "Seismic Stomp"
	t2_spec.damage = 50.0
	t2_spec.attack_range = 4.5
	t2_spec.windup_time = 0.5
	t2_spec.recovery_time = 0.8
	t2_spec.attack_type = "aoe"
	t2_spec.hitbox_radius = 4.5
	t2_spec.trigger_type = "hp_threshold"
	t2_spec.trigger_hp_threshold = 0.5 # Triggers at <= 50% HP
	t2_spec.max_uses = 1
	t2.special_attack = t2_spec

	_registry[t2.id] = t2

	# =========================================================================
	# TIER 3: Overlord (High Tier Boss, 3-Hit Rotation + Minor Bullet Hell)
	# =========================================================================
	var t3 = NeutralTypeClass.new()
	t3.id = "overlord_t3"
	t3.display_name = "Core Overlord"
	t3.tier = 3
	t3.max_health = 900.0
	t3.damage = 50.0
	t3.move_speed = 3.6
	t3.aggro_range = 12.0
	t3.attack_range = 4.0
	t3.leash_range = 18.0
	t3.combo_reset_delay = 3.5
	t3.team_xp = 350.0
	t3.team_gold = 200
	t3.unique_reward = "boon_overlord" # Unique team-wide empowering boon
	t3.unique_reward_duration = 35.0
	t3.mesh_shape = "sphere"
	t3.sphere_radius = 1.2
	t3.mesh_color = Color(1.0, 0.40, 0.0, 1.0)
	t3.emission_color = Color(1.0, 0.30, 0.0, 1.0)
	t3.emission_energy = 0.7

	var t3_atk1 = NeutralAttackClass.new()
	t3_atk1.name = "Overlord Slash"
	t3_atk1.damage = 35.0
	t3_atk1.attack_range = 4.0
	t3_atk1.windup_time = 0.35
	t3_atk1.recovery_time = 0.4
	t3_atk1.attack_type = "melee"
	t3_atk1.hitbox_radius = 2.4

	# Minor Bullet Hell Spread Attack
	var t3_atk2 = NeutralAttackClass.new()
	t3_atk2.name = "Flame Arc Burst"
	t3_atk2.damage = 18.0
	t3_atk2.attack_range = 8.5
	t3_atk2.windup_time = 0.45
	t3_atk2.recovery_time = 0.55
	t3_atk2.attack_type = "bullet_spread"
	t3_atk2.bullet_count = 5
	t3_atk2.spread_angle = 60.0
	t3_atk2.projectile_speed = 15.0

	var t3_atk3 = NeutralAttackClass.new()
	t3_atk3.name = "Cataclysm Slam"
	t3_atk3.damage = 60.0
	t3_atk3.attack_range = 4.2
	t3_atk3.windup_time = 0.65
	t3_atk3.recovery_time = 0.75
	t3_atk3.attack_type = "melee"
	t3_atk3.hitbox_radius = 2.8

	t3.attack_pattern = [t3_atk1, t3_atk2, t3_atk3]

	# Special Ult: 360-degree Radial Bullet Hell Burst at <= 40% HP
	var t3_spec = NeutralSpecialAttackClass.new()
	t3_spec.name = "Supernova Barrage"
	t3_spec.damage = 22.0
	t3_spec.attack_range = 10.0
	t3_spec.windup_time = 0.75
	t3_spec.recovery_time = 0.9
	t3_spec.attack_type = "bullet_spread"
	t3_spec.bullet_count = 12
	t3_spec.spread_angle = 360.0
	t3_spec.projectile_speed = 14.0
	t3_spec.trigger_type = "hp_threshold"
	t3_spec.trigger_hp_threshold = 0.4
	t3_spec.max_uses = 1
	t3.special_attack = t3_spec

	_registry[t3.id] = t3
