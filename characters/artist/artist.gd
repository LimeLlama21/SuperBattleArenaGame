class_name Artist
extends BasePlayer

# The Painted Sage (Artist)
# Vancian talisman magic system with Hanzi calligraphy gesture recognition.

const VancianHanziModal = preload("res://characters/artist/vancian_hanzi_modal.gd")
const ArtistData = preload("res://characters/artist/artist_data.gd")

var vancian_slots: Array = ["", "", "", ""] # 4 ammunition slots
var active_element: String = "fire"

const ELEMENT_LABELS: Dictionary = {
	"fire": {"hanzi": "火", "name": "Fire", "color": Color(0.95, 0.35, 0.15, 0.95), "damage": 75.0, "speed": 65.0, "size": 1.0},
	"water": {"hanzi": "水", "name": "Water", "color": Color(0.25, 0.65, 0.95, 0.95), "damage": 50.0, "speed": 55.0, "size": 1.2},
	"air": {"hanzi": "风", "name": "Air", "color": Color(0.45, 0.90, 0.65, 0.95), "damage": 55.0, "speed": 85.0, "size": 0.6},
	"earth": {"hanzi": "土", "name": "Earth", "color": Color(0.85, 0.65, 0.25, 0.95), "damage": 80.0, "speed": 45.0, "size": 1.4}
}

func _setup_character_kit() -> void:
	if character_name.is_empty() or character_name == "Character":
		character_name = "The Painted Sage"
	if display_name.is_empty() or display_name == "Character":
		display_name = "The Painted Sage"

	var data = ArtistData.create()
	load_character_data(data)

	_setup_abilities_kit()

func _setup_abilities_kit() -> void:
	# Primary (LMB), Secondary (RMB), Q, E are left null
	abilities["LMB"] = null
	abilities["RMB"] = null
	abilities["Q"] = null
	abilities["E"] = null

	# Ultimate (R): Vancian Ammunition Wheel + Hanzi Scribing Canvas
	var r_ab = abilities.get("R")
	if r_ab and r_ab is AbilityClass:
		r_ab.ability_name = "Ink Alchemy"
		r_ab.icon_symbol = "🖌️"
		r_ab.description = "Vancian talisman wheel. Inscribe Hanzi to prepare spells, or unleash prepared elements."
		r_ab.cooldown = 3.0
		r_ab.mana_cost = 0.0

		r_ab.ui_modal = AbilityPipeline.create_ui_modal({
			"type": AbilityPipeline.UIModalType.CUSTOM,
			"interaction_mode": AbilityPipeline.ModalInteractionMode.TOGGLE_AND_CLICK,
			"dynamic_options_func": "get_vancian_modal_options",
			"cancel_cooldown": 1.0,
			"cancel_refund_percent": 1.0
		})

		var modal_inst = VancianHanziModal.new()
		modal_inst.caster = self
		r_ab.active_modal_instance = modal_inst

func character_handles_slot(_slot_key: String) -> bool:
	return false # Pipeline handles SHIFT (dash) and R (modal & cast)

func get_vancian_modal_options(_slot_key: String) -> Array:
	var opts: Array = []
	for i in range(vancian_slots.size()):
		var elem = str(vancian_slots[i]).to_lower()
		if elem != "" and ELEMENT_LABELS.has(elem):
			var info = ELEMENT_LABELS[elem]
			opts.append({
				"id": "cast:%d:%s" % [i, elem],
				"slot_index": i,
				"label": "%s [%s]" % [info["hanzi"], info["name"]],
				"color": info["color"],
				"is_empty": false
			})
		else:
			opts.append({
				"id": "empty_%d" % i,
				"slot_index": i,
				"label": "⚪ [Empty - Draw]",
				"color": Color(0.35, 0.35, 0.40, 0.8),
				"is_empty": true
			})
	return opts

func _on_modal_option_selected(slot_key: String, choice: String) -> void:
	if slot_key != "R":
		return

	if choice.begins_with("inscribed:"):
		# Finished scribing a Hanzi talisman!
		# Requirement: 1 second cooldown after drawing or canceling
		start_ability_cooldown("R", 1.0)

	elif choice.begins_with("cast:"):
		# Selected a prepared ammunition slot to cast!
		var parts = choice.split(":")
		if parts.size() >= 3:
			var slot_idx = int(parts[1])
			var elem = parts[2]

			# Expend the Vancian ammunition slot
			if slot_idx >= 0 and slot_idx < vancian_slots.size():
				vancian_slots[slot_idx] = ""

			active_element = elem
			_apply_elemental_payload(elem)
		# Upon returning, player_base will call try_cast_ability("R"), starting 3.0s cooldown

func _on_modal_cancelled(slot_key: String) -> void:
	if slot_key == "R":
		# Requirement: 1 second cooldown after canceling
		start_ability_cooldown("R", 1.0)

func _apply_elemental_payload(elem: String) -> void:
	var r_ab = abilities.get("R")
	if not r_ab or not r_ab is AbilityClass:
		return

	var info = ELEMENT_LABELS.get(elem, ELEMENT_LABELS["fire"])
	r_ab.damage_amount = float(info.get("damage", 60.0))
	r_ab.speed = float(info.get("speed", 65.0))
	r_ab.projectile_size = float(info.get("size", 1.0))

	if r_ab.effect_instance and "speed" in r_ab.effect_instance:
		r_ab.effect_instance.speed = r_ab.speed
	if r_ab.effect_instance and "damage_amount" in r_ab.effect_instance:
		r_ab.effect_instance.damage_amount = r_ab.damage_amount
	if r_ab.effect_instance and "projectile_size" in r_ab.effect_instance:
		r_ab.effect_instance.projectile_size = r_ab.projectile_size
