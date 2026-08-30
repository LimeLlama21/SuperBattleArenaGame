class_name AbilityPipeline
extends RefCounted

# --- 1. Effect: What the ability actually is ---
enum EffectType {
	PROJECTILE,       # Ranged bullet / energy bolt / lance
	MELEE_STRIKE,     # Immediate arc or box strike in front of caster
	DASH,             # Directional velocity impulse
	BUFF,             # Stat modifier / transformation on caster
	AREA_ZONE,        # Persistent stationary field on the ground
	CHANNEL,          # Timed focus state with a completion trigger
	AERIAL_CRASH,     # Airborne plunge downward onto target area
	CHARGE_SLAM,      # Unstoppable dash forward that grabs/slams target on contact
	STANCE_BLOCK      # Defensive guard with directional mitigation
}

# --- 2. Hitbox: Geometric shape of the effect (skippable/optional) ---
enum HitboxShape {
	NONE,
	LINE,
	SECTOR,
	CIRCLE,
	BOX,
	CYLINDER,
	DONUT
}

# --- 3. Triggers: When the effect triggers actions/payloads ---
enum TriggerType {
	ON_CAST,
	ON_HIT_ENEMY,
	ON_HIT_WALL,
	ON_REACH_DESTINATION,
	ON_EXPIRE,
	ON_TICK,
	ON_ENTER,
	ON_CHANNEL_COMPLETE
}

# --- 4. Riders: Additional payloads / outcomes applied upon triggers ---
enum RiderType {
	DAMAGE,
	STUN,
	SLOW,
	SPEED_BOOST,
	KNOCKBACK,
	SHIELD,
	DIVE_MARK,
	CLEANSE,
	EMPOWER,
	SPAWN_TERRAIN,
	VISION_REVEAL,
	TETHER,
	ROOT,
	GROUND,
	CRIPPLE,
	ETHEREAL,
	MS_STEAL
}

# --- Pipeline Component Classes ---
class AbilityEffect extends RefCounted:
	var effect_type: EffectType = EffectType.PROJECTILE
	var speed: float = 0.0
	var max_range: float = 0.0
	var duration: float = 0.0
	var windup_time: float = 0.0
	var pierces: bool = false
	var projectile_size: float = 1.0
	var count: int = 1
	var chargeable: bool = false
	var custom_params: Dictionary = {}

class AbilityHitbox extends RefCounted:
	var shape: HitboxShape = HitboxShape.NONE
	var radius: float = 0.0
	var length: float = 0.0
	var width: float = 0.0
	var height: float = 0.0
	var angle_deg: float = 0.0

class AbilityTrigger extends RefCounted:
	var trigger_type: TriggerType = TriggerType.ON_HIT_ENEMY
	var rider_ids: Array = [] # Names or indices of riders to execute

class AbilityRider extends RefCounted:
	var rider_type: RiderType = RiderType.DAMAGE
	var amount: float = 0.0
	var duration: float = 0.0
	var intensity: float = 0.0
	var custom_params: Dictionary = {}

class AbilityDefinition extends RefCounted:
	var id: String = ""
	var name: String = ""
	var slot_key: String = "" # "LMB", "RMB", "Q", "E", "R", "SHIFT"
	var cooldown: float = 0.0
	var charges: int = 1
	var recharge_time: float = 0.0
	var can_cast_while_stunned: bool = false
	var can_cast_while_silenced: bool = false
	
	# Pipeline Stages
	var effect: AbilityEffect = null
	var hitbox: AbilityHitbox = null # Skippable / optional
	var triggers: Array = []
	var riders: Array = []

	func has_hitbox() -> bool:
		return hitbox != null and hitbox.shape != HitboxShape.NONE
