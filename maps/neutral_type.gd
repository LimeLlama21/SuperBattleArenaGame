class_name NeutralType
extends Resource

## NeutralType - Data-driven archetype resource defining a neutral creature type.
## Existing active entities are Players (registering a CharacterData) and Neutrals (registering a NeutralType).
## Defines tier, core stats, team-wide rewards (xp, gold, unique_reward), attack pattern rotation, and special attack.

const NeutralAttackClass = preload("res://maps/neutral_attack.gd")
const NeutralSpecialAttackClass = preload("res://maps/neutral_special_attack.gd")

@export_group("Identity & Tier")
@export var id: String = "basic_mob"
@export var display_name: String = "Basic Mob"
@export var tier: int = 1 # 1 = Low tier, 2 = Mid/Elite tier, 3 = High/Boss tier

@export_group("Core Stats")
@export var max_health: float = 100.0
@export var damage: float = 0.0
@export var move_speed: float = 3.0 # Half player base ms (6.0 * 0.5)
@export var aggro_range: float = 8.0 # Detection distance
@export var attack_range: float = 2.4 # Engagement distance to initiate attack (2/3 of attack reach)
@export var leash_range: float = 14.0 # Maximum distance from spawn before disengaging and returning home
@export var combo_reset_delay: float = 2.0 # Grace period before attack rotation resets when no target in range

@export_group("Rewards (Team-wide)")
## Every tier defines three reward values: XP, Gold, and Unique Reward (buff/boon).
## Gold and XP are shared among the entire killing team.
## Unique reward can be blank/empty string for lower tiers, or grant a team-wide buff/boon.
@export var team_xp: float = 50.0
@export var team_gold: int = 25
@export var unique_reward: String = "" # Unique team buff identifier (blank for lowest tier)
@export var unique_reward_duration: float = 0.0

@export_group("Attacks & Rotation")
## The sequential basic attack rotation that cycles against the nearest target in range.
@export var attack_pattern: Array = []
## Special attack / ultimate that temporarily overrides the normal rotation on triggers (can be null/blank).
@export var special_attack: Resource = null

@export_group("Visuals")
@export var mesh_shape: String = "capsule" # "capsule" or "sphere"
@export var capsule_radius: float = 0.45
@export var capsule_height: float = 1.6
@export var sphere_radius: float = 0.75
@export var mesh_color: Color = Color(0.78, 0.28, 0.22, 1.0)
@export var emission_color: Color = Color(0.9, 0.3, 0.1, 1.0)
@export var emission_energy: float = 0.35

# Backward compatibility alias
var sphere_color: Color:
	get:
		return mesh_color
	set(v):
		mesh_color = v
