class_name NeutralAttack
extends Resource

## NeutralAttack - Defines an individual attack step in a neutral entity's attack pattern.
## Supports melee hitboxes, frontal cones, directional projectiles, bullet hell spreads, and AOE bursts.

@export var name: String = "Basic Strike"
@export var damage: float = 20.0
@export var attack_range: float = 3.5 # Distance required to trigger/initiate attack
@export var windup_time: float = 0.4 # Telegraph / windup duration before damage
@export var recovery_time: float = 0.5 # Cooldown / recovery duration after strike
@export var attack_type: String = "melee" # "melee", "cone", "bullet_spread", "projectile", "aoe"
@export var hitbox_radius: float = 1.8 # Radius for melee cleave or ground AOE
@export var cone_range: float = 3.6 # Full reach of cone attacks
@export var cone_angle: float = 60.0 # Spread arc of cone attacks in degrees
@export var projectile_speed: float = 14.0 # Speed if firing projectiles
@export var bullet_count: int = 3 # Number of bullets for spreads (bullet hell)
@export var spread_angle: float = 45.0 # Total spread arc in degrees
@export var projectile_size: float = 1.0
@export var custom_params: Dictionary = {}
