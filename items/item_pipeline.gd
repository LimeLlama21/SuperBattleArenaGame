class_name ItemPipeline
extends RefCounted

# Pipeline: Name -> Stats -> Unique Feature (Node / Scene Tree based)

const AbilityClass = preload("res://ability/ability.gd")

enum ItemCategory {
	ALL = 0,
	DAMAGE = 1,
	TANKINESS = 2,
	UTILITY = 3
}

class ItemDefinition extends RefCounted:
	var id: String = ""
	var name: String = ""
	var cost: int = 100
	var category: ItemCategory = ItemCategory.ALL
	var stats: Dictionary = {} # e.g. {"damage_percent": 20.0}, {"max_health": 50.0}, {"move_speed": 2.5}
	var unique_feature: Variant = null # PackedScene, Ability Node, or scene path String (scene/node tree based)
	var unique_feature_config: Dictionary = {} # Declarative config compiled to node tree
	var description: String = ""
	var art_texture: Texture2D = null # Blank for now

	func has_unique_feature() -> bool:
		return unique_feature != null or not unique_feature_config.is_empty()

	func instantiate_ability() -> Node:
		if unique_feature is PackedScene:
			var node = unique_feature.instantiate()
			return node
		elif unique_feature is String and ResourceLoader.exists(unique_feature):
			var res = load(unique_feature)
			if res is PackedScene:
				return res.instantiate()
		elif unique_feature is Node:
			return unique_feature.duplicate()
		elif not unique_feature_config.is_empty():
			return AbilityClass.create_from_config(unique_feature_config)
		return null

	func get_stats_description() -> String:
		if stats.is_empty():
			return "No stat bonuses"
		var parts: Array[String] = []
		for stat_key in stats:
			var val = stats[stat_key]
			parts.append(_format_stat(str(stat_key), float(val)))
		if parts.is_empty():
			return "No stat bonuses"
		return "\n".join(parts)

	static func _format_stat(stat_key: String, val: float) -> String:
		var sign_str = "+" if val >= 0.0 else ""
		match stat_key:
			"damage_percent":
				return "%s%d%% Damage Dealt" % [sign_str, int(val)]
			"damage", "attack_damage":
				return "%s%d Attack Damage" % [sign_str, int(val)]
			"all_damage":
				return "%s%d%% All Damage" % [sign_str, int(val)]
			"max_health", "health":
				return "%s%d Maximum Health" % [sign_str, int(val)]
			"move_speed", "speed":
				return "%s%.1f Movement Speed" % [sign_str, val]
			"crit_chance", "critical_chance":
				var pct = val if val > 1.0 else (val * 100.0)
				return "%s%d%% Critical Chance" % [sign_str, int(pct)]
			"crit_multiplier", "crit_damage", "critical_damage":
				var pct = val if val > 1.0 else (val * 100.0)
				return "%s%d%% Critical Damage" % [sign_str, int(pct)]
			"max_shield", "shield":
				return "%s%d Maximum Shield" % [sign_str, int(val)]
			"cooldown_reduction", "cdr":
				return "%s%d%% Cooldown Reduction" % [sign_str, int(val)]
			"ability_haste", "haste":
				return "%s%d Ability Haste" % [sign_str, int(val)]
			"lifesteal":
				return "%s%d%% Lifesteal" % [sign_str, int(val)]
			"omnivamp", "vamp":
				return "%s%d%% Omnivamp" % [sign_str, int(val)]
			"armor", "damage_reduction":
				return "%s%d%% Damage Reduction" % [sign_str, int(val)]
			"tenacity":
				return "%s%d%% Tenacity" % [sign_str, int(val)]
			"jump_velocity", "jump_height":
				return "%s%.1f Jump Velocity" % [sign_str, val]
			"ground_acceleration", "acceleration":
				return "%s%.1f Ground Acceleration" % [sign_str, val]
			"health_regen":
				return "%s%.1f Health Regen/s" % [sign_str, val]
			"shield_regen":
				return "%s%.1f Shield Regen/s" % [sign_str, val]
			_:
				var words: Array[String] = []
				for w in stat_key.split("_"):
					if not w.is_empty():
						words.append(w.capitalize())
				var label = " ".join(words)
				if stat_key.ends_with("_percent") or stat_key.ends_with("_pct") or "chance" in stat_key or "reduction" in stat_key or "vamp" in stat_key:
					return "%s%g%% %s" % [sign_str, val, label]
				elif is_equal_approx(val, round(val)):
					return "%s%d %s" % [sign_str, int(val), label]
				else:
					return "%s%.1f %s" % [sign_str, val, label]

	func get_unique_feature_description() -> String:
		if not has_unique_feature():
			return "None (Stats only)"
		
		# If unique_feature is a PackedScene, instantiate temporarily or inspect
		if unique_feature is PackedScene:
			var temp = unique_feature.instantiate()
			if temp:
				var desc = ""
				if "ability_name" in temp and not str(temp.ability_name).is_empty():
					desc = str(temp.ability_name)
				elif "description" in temp and not str(temp.description).is_empty():
					desc = str(temp.description)
				elif "name" in temp:
					desc = str(temp.name)
				temp.free()
				if not desc.is_empty():
					return desc
		elif unique_feature is Node:
			if "ability_name" in unique_feature and not str(unique_feature.ability_name).is_empty():
				return str(unique_feature.ability_name)
			if "description" in unique_feature and not str(unique_feature.description).is_empty():
				return str(unique_feature.description)
			return str(unique_feature.name)
		elif not unique_feature_config.is_empty():
			if unique_feature_config.has("name"):
				return str(unique_feature_config["name"])
			if unique_feature_config.has("description"):
				return str(unique_feature_config["description"])
			return "Item Ability"
		return "None (Stats only)"

static func create_item(cfg: Dictionary) -> ItemDefinition:
	var item = ItemDefinition.new()
	item.id = cfg.get("id", "")
	item.name = cfg.get("name", item.id)
	item.cost = cfg.get("cost", 100)
	item.category = cfg.get("category", ItemCategory.ALL)
	item.stats = cfg.get("stats", {})
	item.description = cfg.get("description", "")
	item.art_texture = cfg.get("art_texture", null)
	
	if cfg.has("unique_feature") and cfg["unique_feature"] != null:
		var feat = cfg["unique_feature"]
		if feat is PackedScene or feat is Node:
			item.unique_feature = feat
		elif feat is String:
			if ResourceLoader.exists(feat):
				item.unique_feature = load(feat)
			else:
				item.unique_feature = feat
		elif feat is Dictionary:
			item.unique_feature_config = feat
			# Compile dictionary into a real Node/Scene tree Ability
			var ab = AbilityClass.create_from_config(feat)
			if ab:
				var ps = PackedScene.new()
				ps.pack(ab)
				item.unique_feature = ps
				ab.free()
			else:
				item.unique_feature = null
	elif cfg.has("unique_feature_scene") and cfg["unique_feature_scene"] != null:
		item.unique_feature = cfg["unique_feature_scene"]
	else:
		item.unique_feature = null
		
	return item

# --- Catalog of Items ---
# Basic items (stats only) and advanced tier items (with unique feature scenes)
const ITEM_DEFINITIONS: Dictionary = {
	"basic_damage": {
		"id": "basic_damage",
		"name": "Iron Blade",
		"cost": 100,
		"category": ItemCategory.DAMAGE,
		"stats": {
			"damage_percent": 20.0
		},
		"unique_feature": null,
		"description": "A forged iron blade that increases all outgoing damage."
	},
	"basic_health": {
		"id": "basic_health",
		"name": "Vitality Crystal",
		"cost": 100,
		"category": ItemCategory.TANKINESS,
		"stats": {
			"max_health": 50.0
		},
		"unique_feature": null,
		"description": "An infused crystal that reinforces resilience and increases maximum health."
	},
	"basic_speed": {
		"id": "basic_speed",
		"name": "Swiftness Boots",
		"cost": 100,
		"category": ItemCategory.UTILITY,
		"stats": {
			"move_speed": 2.5
		},
		"unique_feature": null,
		"description": "Lightweight enchanted boots that grant increased mobility and movement speed."
	},
	"aegis_barrier": {
		"id": "aegis_barrier",
		"name": "Aegis Talisman",
		"cost": 250,
		"category": ItemCategory.TANKINESS,
		"stats": {
			"max_health": 75.0
		},
		"unique_feature": "res://ability/effects/buff_effect.tscn",
		"description": "An ancient warding talisman that reinforces health and holds a protective barrier effect."
	},
	"marksman_lens": {
		"id": "marksman_lens",
		"name": "Marksman's Lens",
		"cost": 175,
		"category": ItemCategory.DAMAGE,
		"stats": {
			"crit_chance": 25.0,
			"crit_damage": 30.0
		},
		"unique_feature": null,
		"description": "Precision crystalline lens maximizing critical strike accuracy and lethality."
	},
	"vampiric_scepter": {
		"id": "vampiric_scepter",
		"name": "Vampiric Scepter",
		"cost": 180,
		"category": ItemCategory.DAMAGE,
		"stats": {
			"damage": 15.0,
			"lifesteal": 15.0
		},
		"unique_feature": null,
		"description": "A blood-forged scepter that siphons life from stricken foes."
	},
	"chronos_pendant": {
		"id": "chronos_pendant",
		"name": "Chronos Pendant",
		"cost": 160,
		"category": ItemCategory.UTILITY,
		"stats": {
			"cooldown_reduction": 20.0,
			"move_speed": 1.0
		},
		"unique_feature": null,
		"description": "An arcane pendant warping temporal flow to accelerate cooldowns."
	},
	"titans_cuirass": {
		"id": "titans_cuirass",
		"name": "Titan's Cuirass",
		"cost": 220,
		"category": ItemCategory.TANKINESS,
		"stats": {
			"max_health": 100.0,
			"armor": 15.0,
			"tenacity": 25.0
		},
		"unique_feature": null,
		"description": "Heavy adamantine breastplate mitigating incoming harm and resisting crowd control."
	}
}

static var custom_items: Dictionary = {}

static func register_item(cfg: Dictionary) -> void:
	if cfg.has("id"):
		custom_items[cfg["id"]] = cfg

static func unregister_item(id: String) -> void:
	if custom_items.has(id):
		custom_items.erase(id)

static func get_item(id: String) -> ItemDefinition:
	if custom_items.has(id):
		return create_item(custom_items[id])
	if not ITEM_DEFINITIONS.has(id):
		return null
	return create_item(ITEM_DEFINITIONS[id])

static func get_all_items() -> Array[ItemDefinition]:
	var list: Array[ItemDefinition] = []
	for id in ["basic_damage", "basic_health", "basic_speed", "marksman_lens", "vampiric_scepter", "chronos_pendant", "titans_cuirass", "aegis_barrier"]:
		list.append(get_item(id))
	for custom_id in custom_items:
		if not list.any(func(it): return it.id == custom_id):
			list.append(get_item(custom_id))
	return list

static func get_items_by_category(cat: ItemCategory) -> Array[ItemDefinition]:
	var list: Array[ItemDefinition] = []
	for item in get_all_items():
		if cat == ItemCategory.ALL or item.category == cat:
			list.append(item)
	return list
