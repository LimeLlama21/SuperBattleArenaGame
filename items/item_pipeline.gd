class_name ItemPipeline
extends RefCounted

# Pipeline: Name -> Stats -> Unique Feature (uses AbilityPipeline, can be blank)

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
	var unique_feature: AbilityPipeline.AbilityDefinition = null # uses ability pipeline, blank for basic items
	var description: String = ""
	var art_texture: Texture2D = null # Blank for now

	func get_stats_description() -> String:
		var parts: Array[String] = []
		if stats.has("damage_percent"):
			parts.append("+%d%% Damage Dealt" % int(stats["damage_percent"]))
		if stats.has("damage"):
			parts.append("+%d Attack Damage" % int(stats["damage"]))
		if stats.has("max_health"):
			parts.append("+%d Maximum Health" % int(stats["max_health"]))
		if stats.has("move_speed"):
			parts.append("+%.1f Movement Speed" % float(stats["move_speed"]))
		if parts.is_empty():
			return "No stat bonuses"
		return "\n".join(parts)

	func get_unique_feature_description() -> String:
		if unique_feature == null:
			return "None (Stats only)"
		return unique_feature.name

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
		if cfg["unique_feature"] is Dictionary:
			item.unique_feature = AbilityPipeline.create_ability(cfg["unique_feature"])
		elif cfg["unique_feature"] is AbilityPipeline.AbilityDefinition:
			item.unique_feature = cfg["unique_feature"]
	else:
		item.unique_feature = null
		
	return item

# --- Catalog of Items ---
# The three basic items: basic damage, basic health, basic movement speed
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
	}
}

static func get_item(id: String) -> ItemDefinition:
	if not ITEM_DEFINITIONS.has(id):
		return null
	return create_item(ITEM_DEFINITIONS[id])

static func get_all_items() -> Array[ItemDefinition]:
	var list: Array[ItemDefinition] = []
	for id in ["basic_damage", "basic_health", "basic_speed"]:
		list.append(get_item(id))
	return list

static func get_items_by_category(cat: ItemCategory) -> Array[ItemDefinition]:
	var list: Array[ItemDefinition] = []
	for item in get_all_items():
		if cat == ItemCategory.ALL or item.category == cat:
			list.append(item)
	return list
