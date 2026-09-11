class_name PlayerSharedEffects

# --- Shared Takedown Constants ---
const TAKEDOWN_MANA_RECOVER_PERCENT: float = 0.30
const TAKEDOWN_MISSING_HP_HEAL_PERCENT: float = 0.10

# --- Shared Takedown Effect Handlers ---
static func restore_mana_on_takedown(player: Node, _victim: Node = null) -> void:
	if not is_instance_valid(player):
		return
	if player.has_method("restore_mana") and "max_mana" in player:
		player.restore_mana(player.max_mana * TAKEDOWN_MANA_RECOVER_PERCENT)

static func heal_missing_hp_on_takedown(player: Node, _victim: Node = null) -> void:
	if not is_instance_valid(player):
		return
	if player.has_method("heal") and "max_health" in player and "current_health" in player:
		var missing_hp = max(0.0, player.max_health - player.current_health)
		if missing_hp > 0.0:
			player.heal(missing_hp * TAKEDOWN_MISSING_HP_HEAL_PERCENT)

# Convenience aliases
static func restore_mana(player: Node, victim: Node = null) -> void:
	restore_mana_on_takedown(player, victim)

static func heal_missing_hp(player: Node, victim: Node = null) -> void:
	heal_missing_hp_on_takedown(player, victim)

# Query default list of shared takedown effects
static func get_default_takedown_effects() -> Array[Callable]:
	return [
		Callable(PlayerSharedEffects, "restore_mana_on_takedown"),
		Callable(PlayerSharedEffects, "heal_missing_hp_on_takedown")
	]

# Helper to register all default shared takedown effects onto a player
static func register_default_takedown_effects(player: Node) -> void:
	if not is_instance_valid(player):
		return
	if player.has_method("register_takedown_effect"):
		for effect in get_default_takedown_effects():
			player.register_takedown_effect(effect)
