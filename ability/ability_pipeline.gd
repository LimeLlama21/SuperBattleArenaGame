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
	ON_CHANNEL_COMPLETE,
	ON_TAKEDOWN
}

# --- 4. Riders: Additional payloads / outcomes applied upon triggers ---
enum RiderType {
	DAMAGE,
	STUN,
	SLOW,
	SPEED_BOOST,
	ATTACK_SPEED_BOOST,
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

# --- Critical Hit Constants ---
const CRIT_DAMAGE_MULTIPLIER: float = 2.0 # Standard critical strike deals double damage (200%)

# --- Pipeline Component Classes ---
class AbilityEffect extends RefCounted:
	var effect_type: EffectType = EffectType.PROJECTILE
	var speed: float = 0.0
	var max_range: float = 0.0
	var duration: float = 0.0
	var windup_time: float = 0.0
	var follow_caster: bool = false
	var pierces: bool = false
	var projectile_size: float = 1.0
	var count: int = 1
	var chargeable: bool = false
	var can_crit: bool = true
	var custom_params: Dictionary = {}

class AbilityHitbox extends RefCounted:
	var shape: HitboxShape = HitboxShape.NONE
	var radius: float = 0.0
	var length: float = 0.0
	var width: float = 0.0
	var height: float = 2.0
	var angle_deg: float = 0.0

class AbilityTrigger extends RefCounted:
	var trigger_type: TriggerType = TriggerType.ON_HIT_ENEMY
	var rider_ids: Array = [] # Names or indices of riders to execute

class AbilityRider extends RefCounted:
	var rider_type: RiderType = RiderType.DAMAGE
	var amount: float = 0.0
	var duration: float = 0.0
	var intensity: float = 0.0
	var can_crit: bool = true
	var crit_multiplier: float = CRIT_DAMAGE_MULTIPLIER
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
	
	# Lockout Tagging System
	var is_lockout: bool = false
	var can_cast_during_lockout: bool = false
	var lockout_duration: float = 0.0
	var tags: Array = []

	# Critical Strike Properties
	var can_crit: bool = true
	var crit_multiplier: float = CRIT_DAMAGE_MULTIPLIER
	var crit_chance: float = 0.0 # Per-ability override (0.0 uses caster base)

	# Pipeline Stages
	var icon: Variant = null
	var description: String = ""
	var effect: AbilityEffect = null
	var hitbox: AbilityHitbox = null # Skippable / optional
	var triggers: Array = []
	var riders: Array = []

	func has_hitbox() -> bool:
		return hitbox != null and hitbox.shape != HitboxShape.NONE

	func get_lockout_time() -> float:
		if lockout_duration > 0.0:
			return lockout_duration
		if effect:
			if effect.windup_time > 0.0:
				return effect.windup_time
			if effect.duration > 0.0 and effect.effect_type in [EffectType.CHARGE_SLAM, EffectType.CHANNEL]:
				return effect.duration
		return 0.25

# --- Declarative Helper / Factory Functions ---

static func create_ability(cfg: Dictionary) -> AbilityDefinition:
	var def = AbilityDefinition.new()
	def.id = cfg.get("id", "")
	def.name = cfg.get("name", def.id)
	def.icon = cfg.get("icon", null)
	def.description = cfg.get("description", "")
	def.slot_key = cfg.get("slot_key", cfg.get("slot", ""))
	def.cooldown = cfg.get("cooldown", 0.0)
	def.charges = cfg.get("charges", 1)
	def.recharge_time = cfg.get("recharge_time", 0.0)
	def.can_cast_while_stunned = cfg.get("can_cast_while_stunned", false)
	def.can_cast_while_silenced = cfg.get("can_cast_while_silenced", false)

	# Lockout properties & tags
	def.tags = cfg.get("tags", [])
	def.is_lockout = cfg.get("is_lockout", false) or ("lockout" in def.tags)
	var is_dash = def.slot_key == "SHIFT" or ("dash" in def.tags) or def.id.to_lower().contains("dash")
	def.can_cast_during_lockout = cfg.get("can_cast_during_lockout", is_dash or ("can_cast_during_lockout" in def.tags))
	def.lockout_duration = cfg.get("lockout_duration", cfg.get("lockout_time", 0.0))

	# Critical strike properties
	def.can_crit = cfg.get("can_crit", true)
	def.crit_multiplier = cfg.get("crit_multiplier", CRIT_DAMAGE_MULTIPLIER)
	def.crit_chance = cfg.get("crit_chance", 0.0)

	if cfg.has("effect") and cfg["effect"] is Dictionary:
		def.effect = create_effect(cfg["effect"])
	elif cfg.has("effect") and cfg["effect"] is AbilityEffect:
		def.effect = cfg["effect"]

	if def.lockout_duration <= 0.0 and def.effect and def.effect.windup_time > 0.0:
		def.lockout_duration = def.effect.windup_time
	if def.lockout_duration > 0.0:
		def.is_lockout = true

	if cfg.has("hitbox") and cfg["hitbox"] is Dictionary:
		def.hitbox = create_hitbox(cfg["hitbox"])
	elif cfg.has("hitbox") and cfg["hitbox"] is AbilityHitbox:
		def.hitbox = cfg["hitbox"]

	if cfg.has("riders") and cfg["riders"] is Array:
		for r in cfg["riders"]:
			if r is Dictionary:
				def.riders.append(create_rider(r))
			elif r is AbilityRider:
				def.riders.append(r)

	if cfg.has("triggers") and cfg["triggers"] is Array:
		for t in cfg["triggers"]:
			if t is Dictionary:
				var trig = AbilityTrigger.new()
				trig.trigger_type = parse_trigger_type(t.get("type", TriggerType.ON_HIT_ENEMY))
				trig.rider_ids = t.get("riders", [])
				def.triggers.append(trig)
			elif t is AbilityTrigger:
				def.triggers.append(t)

	return def

static func create_effect(cfg: Dictionary) -> AbilityEffect:
	var eff = AbilityEffect.new()
	eff.effect_type = parse_effect_type(cfg.get("type", cfg.get("effect_type", EffectType.PROJECTILE)))
	eff.speed = cfg.get("speed", 0.0)
	eff.max_range = cfg.get("max_range", cfg.get("range", 0.0))
	eff.duration = cfg.get("duration", 0.0)
	eff.windup_time = cfg.get("windup_time", cfg.get("windup", 0.0))
	eff.follow_caster = cfg.get("follow_caster", false)
	eff.pierces = cfg.get("pierces", false)
	eff.projectile_size = cfg.get("projectile_size", cfg.get("size", 1.0))
	eff.count = cfg.get("count", 1)
	eff.chargeable = cfg.get("chargeable", false)
	eff.can_crit = cfg.get("can_crit", true)
	eff.custom_params = cfg.get("custom_params", {})
	return eff

static func create_hitbox(cfg: Dictionary) -> AbilityHitbox:
	var hb = AbilityHitbox.new()
	hb.shape = parse_hitbox_shape(cfg.get("shape", HitboxShape.NONE))
	hb.radius = cfg.get("radius", 0.0)
	hb.length = cfg.get("length", 0.0)
	hb.width = cfg.get("width", 0.0)
	hb.height = cfg.get("height", 2.0)
	hb.angle_deg = cfg.get("angle_deg", cfg.get("angle", 0.0))
	return hb

static func create_rider(cfg: Dictionary) -> AbilityRider:
	var r = AbilityRider.new()
	r.rider_type = parse_rider_type(cfg.get("type", cfg.get("rider_type", RiderType.DAMAGE)))
	r.amount = cfg.get("amount", cfg.get("damage", cfg.get("value", 0.0)))
	r.duration = cfg.get("duration", 0.0)
	r.intensity = cfg.get("intensity", cfg.get("percent", 0.0))
	r.can_crit = cfg.get("can_crit", true)
	r.crit_multiplier = cfg.get("crit_multiplier", CRIT_DAMAGE_MULTIPLIER)
	r.custom_params = cfg.get("custom_params", {})
	return r

# --- Critical Strike Helpers ---

static func roll_crit(chance: float) -> bool:
	if chance <= 0.0:
		return false
	return randf() < chance

static func calculate_crit_damage(base_damage: float, is_crit: bool, multiplier: float = CRIT_DAMAGE_MULTIPLIER) -> float:
	if is_crit:
		return base_damage * multiplier
	return base_damage

static func apply_crit(base_damage: float, crit_chance: float, crit_multiplier: float = CRIT_DAMAGE_MULTIPLIER) -> Dictionary:
	var is_crit = roll_crit(crit_chance)
	var final_damage = calculate_crit_damage(base_damage, is_crit, crit_multiplier)
	return {
		"damage": final_damage,
		"is_crit": is_crit,
		"multiplier": crit_multiplier if is_crit else 1.0
	}

static func parse_effect_type(val: Variant) -> EffectType:
	if val is EffectType:
		return val
	if val is int:
		return val as EffectType
	if val is String:
		var upper = val.to_upper()
		match upper:
			"PROJECTILE": return EffectType.PROJECTILE
			"MELEE_STRIKE", "MELEE": return EffectType.MELEE_STRIKE
			"DASH": return EffectType.DASH
			"BUFF": return EffectType.BUFF
			"AREA_ZONE", "ZONE": return EffectType.AREA_ZONE
			"CHANNEL": return EffectType.CHANNEL
			"AERIAL_CRASH", "CRASH": return EffectType.AERIAL_CRASH
			"CHARGE_SLAM", "SLAM": return EffectType.CHARGE_SLAM
			"STANCE_BLOCK", "BLOCK": return EffectType.STANCE_BLOCK
	return EffectType.PROJECTILE

static func parse_hitbox_shape(val: Variant) -> HitboxShape:
	if val is HitboxShape:
		return val
	if val is int:
		return val as HitboxShape
	if val is String:
		var upper = val.to_upper()
		match upper:
			"NONE": return HitboxShape.NONE
			"LINE": return HitboxShape.LINE
			"SECTOR", "CONE": return HitboxShape.SECTOR
			"CIRCLE": return HitboxShape.CIRCLE
			"BOX", "RECTANGLE": return HitboxShape.BOX
			"CYLINDER": return HitboxShape.CYLINDER
			"DONUT", "RING": return HitboxShape.DONUT
	return HitboxShape.NONE

static func parse_rider_type(val: Variant) -> RiderType:
	if val is RiderType:
		return val
	if val is int:
		return val as RiderType
	if val is String:
		var upper = val.to_upper()
		match upper:
			"DAMAGE": return RiderType.DAMAGE
			"STUN": return RiderType.STUN
			"SLOW": return RiderType.SLOW
			"SPEED_BOOST", "SPEED": return RiderType.SPEED_BOOST
			"KNOCKBACK": return RiderType.KNOCKBACK
			"SHIELD": return RiderType.SHIELD
			"DIVE_MARK", "MARK": return RiderType.DIVE_MARK
			"CLEANSE": return RiderType.CLEANSE
			"EMPOWER": return RiderType.EMPOWER
			"SPAWN_TERRAIN", "TERRAIN": return RiderType.SPAWN_TERRAIN
			"VISION_REVEAL", "REVEAL": return RiderType.VISION_REVEAL
			"TETHER": return RiderType.TETHER
			"ROOT": return RiderType.ROOT
			"GROUND": return RiderType.GROUND
			"CRIPPLE": return RiderType.CRIPPLE
			"ETHEREAL": return RiderType.ETHEREAL
			"MS_STEAL": return RiderType.MS_STEAL
	return RiderType.DAMAGE

static func parse_trigger_type(val: Variant) -> TriggerType:
	if val is TriggerType:
		return val
	if val is int:
		return val as TriggerType
	if val is String:
		var upper = val.to_upper()
		match upper:
			"ON_CAST": return TriggerType.ON_CAST
			"ON_HIT_ENEMY", "ON_HIT": return TriggerType.ON_HIT_ENEMY
			"ON_HIT_WALL": return TriggerType.ON_HIT_WALL
			"ON_REACH_DESTINATION", "ON_DESTINATION": return TriggerType.ON_REACH_DESTINATION
			"ON_EXPIRE": return TriggerType.ON_EXPIRE
			"ON_TICK": return TriggerType.ON_TICK
			"ON_ENTER": return TriggerType.ON_ENTER
			"ON_CHANNEL_COMPLETE": return TriggerType.ON_CHANNEL_COMPLETE
	return TriggerType.ON_HIT_ENEMY
