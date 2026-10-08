class_name UpgradeTrees
extends RefCounted

const CharacterOriginClass = preload("res://characters/leveling/origins/character_origin.gd")

const BRANCH_RESILIENCE = "resilience"
const BRANCH_FERVOR = "fervor"
const BRANCH_CUNNING = "cunning"

const BRANCHES: Array[String] = [
	BRANCH_RESILIENCE,
	BRANCH_FERVOR,
	BRANCH_CUNNING
]

const BRANCH_METADATA: Dictionary = {
	BRANCH_RESILIENCE: {
		"title": "RESILIENCE",
		"subtitle": "Defense & Vitality",
		"color": Color(0.2, 0.85, 0.65), # Emerald / Mint
		"icon_symbol": "🛡️"
	},
	BRANCH_FERVOR: {
		"title": "FERVOR",
		"subtitle": "Power & Offense",
		"color": Color(1.0, 0.45, 0.25), # Flame / Crimson
		"icon_symbol": "⚔️"
	},
	BRANCH_CUNNING: {
		"title": "CUNNING",
		"subtitle": "Mobility & Tactics",
		"color": Color(0.7, 0.45, 1.0), # Amethyst / Violet
		"icon_symbol": "⚡"
	}
}

## Dictionary containing upgrade trees for each Origin (mortal, divine, monstrous).
## Each origin tree defines 3 vertical branches: resilience (left), fervor (middle), cunning (right).
## Each branch contains exactly 3 upgrades in sequential tier order (Tier 1, Tier 2, Tier 3).
const TREES: Dictionary = {
	"mortal": {
		"resilience": [
			{"id": "mortal_resilience_1", "tier": 1, "name": "Mortal Resilience I", "description": "Tier 1 Resilience upgrade placeholder."},
			{"id": "mortal_resilience_2", "tier": 2, "name": "Mortal Resilience II", "description": "Tier 2 Resilience upgrade placeholder."},
			{"id": "mortal_resilience_3", "tier": 3, "name": "Mortal Resilience III", "description": "Tier 3 Resilience upgrade placeholder."}
		],
		"fervor": [
			{"id": "mortal_fervor_1", "tier": 1, "name": "Mortal Fervor I", "description": "Tier 1 Fervor upgrade placeholder."},
			{"id": "mortal_fervor_2", "tier": 2, "name": "Mortal Fervor II", "description": "Tier 2 Fervor upgrade placeholder."},
			{"id": "mortal_fervor_3", "tier": 3, "name": "Mortal Fervor III", "description": "Tier 3 Fervor upgrade placeholder."}
		],
		"cunning": [
			{
				"id": "atalantas_stride",
				"tier": 1,
				"name": "Atalanta's Stride",
				"description": "Increases dash charges by 1 (grants 1 immediately). Dashing grants +30% decaying movement speed over 2 seconds."
			},
			{
				"id": "ascetic_touch",
				"tier": 2,
				"name": "Ascetic Touch",
				"description": "Dealing damage to an enemy deals 5% max HP True Damage and steals mana. 10s cooldown per target."
			},
			{
				"id": "hymn_of_the_underworld",
				"tier": 3,
				"name": "Hymn of the Underworld",
				"description": "On death, sends a shade through walls after every enemy who saw you die. If a shade hits an enemy facing it, they are nearsighted and slowed 50% for 2s."
			}
		]
	},
	"divine": {
		"resilience": [
			{"id": "divine_resilience_1", "tier": 1, "name": "Divine Resilience I", "description": "Tier 1 Resilience upgrade placeholder."},
			{"id": "divine_resilience_2", "tier": 2, "name": "Divine Resilience II", "description": "Tier 2 Resilience upgrade placeholder."},
			{"id": "divine_resilience_3", "tier": 3, "name": "Divine Resilience III", "description": "Tier 3 Resilience upgrade placeholder."}
		],
		"fervor": [
			{"id": "divine_fervor_1", "tier": 1, "name": "Divine Fervor I", "description": "Tier 1 Fervor upgrade placeholder."},
			{"id": "divine_fervor_2", "tier": 2, "name": "Divine Fervor II", "description": "Tier 2 Fervor upgrade placeholder."},
			{"id": "divine_fervor_3", "tier": 3, "name": "Divine Fervor III", "description": "Tier 3 Fervor upgrade placeholder."}
		],
		"cunning": [
			{"id": "divine_cunning_1", "tier": 1, "name": "Divine Cunning I", "description": "Tier 1 Cunning upgrade placeholder."},
			{"id": "divine_cunning_2", "tier": 2, "name": "Divine Cunning II", "description": "Tier 2 Cunning upgrade placeholder."},
			{"id": "divine_cunning_3", "tier": 3, "name": "Divine Cunning III", "description": "Tier 3 Cunning upgrade placeholder."}
		]
	},
	"monstrous": {
		"resilience": [
			{"id": "monstrous_resilience_1", "tier": 1, "name": "Monstrous Resilience I", "description": "Tier 1 Resilience upgrade placeholder."},
			{"id": "monstrous_resilience_2", "tier": 2, "name": "Monstrous Resilience II", "description": "Tier 2 Resilience upgrade placeholder."},
			{"id": "monstrous_resilience_3", "tier": 3, "name": "Monstrous Resilience III", "description": "Tier 3 Resilience upgrade placeholder."}
		],
		"fervor": [
			{"id": "monstrous_fervor_1", "tier": 1, "name": "Monstrous Fervor I", "description": "Tier 1 Fervor upgrade placeholder."},
			{"id": "monstrous_fervor_2", "tier": 2, "name": "Monstrous Fervor II", "description": "Tier 2 Fervor upgrade placeholder."},
			{"id": "monstrous_fervor_3", "tier": 3, "name": "Monstrous Fervor III", "description": "Tier 3 Fervor upgrade placeholder."}
		],
		"cunning": [
			{"id": "monstrous_cunning_1", "tier": 1, "name": "Monstrous Cunning I", "description": "Tier 1 Cunning upgrade placeholder."},
			{"id": "monstrous_cunning_2", "tier": 2, "name": "Monstrous Cunning II", "description": "Tier 2 Cunning upgrade placeholder."},
			{"id": "monstrous_cunning_3", "tier": 3, "name": "Monstrous Cunning III", "description": "Tier 3 Cunning upgrade placeholder."}
		]
	}
}

static func get_tree(origin_id: String) -> Dictionary:
	var key = origin_id.to_lower().strip_edges()
	return TREES.get(key, TREES.get("mortal", {}))

static func get_branch(origin_id: String, branch_name: String) -> Array:
	var tree = get_tree(origin_id)
	return tree.get(branch_name.to_lower().strip_edges(), [])

static func get_upgrade(origin_id: String, branch_name: String, tier_index: int) -> Dictionary:
	var branch = get_branch(origin_id, branch_name)
	if tier_index >= 0 and tier_index < branch.size():
		return branch[tier_index]
	return {}

static func get_branch_metadata(branch_name: String) -> Dictionary:
	return BRANCH_METADATA.get(branch_name.to_lower().strip_edges(), {})
