class_name NeutralSpecialAttack
extends "res://maps/neutral_attack.gd"

## NeutralSpecialAttack - Special / Ultimate attack for neutral entities.
## Temporarily overrides the standard attack pattern when specified triggers are met.

@export var trigger_type: String = "hp_threshold" # "hp_threshold", "timer_cooldown", "target_count", "manual"
@export var trigger_hp_threshold: float = 0.5 # Fraction of max health (e.g. 0.5 = 50% HP or lower)
@export var trigger_cooldown: float = 15.0 # Timer interval for recurring special attacks
@export var trigger_target_count: int = 2 # Trigger when >= N players are in aggro range
@export var max_uses: int = 0 # 0 = unlimited, 1 = once per spawn/encounter
