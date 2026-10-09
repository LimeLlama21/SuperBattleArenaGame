class_name Artist
extends BasePlayer

# The Painted Sage (Artist)
# Vancian talisman magic system with Hanzi calligraphy gesture recognition.

const VancianHanziModal = preload("res://characters/artist/vancian_hanzi_modal.gd")
const ArtistData = preload("res://characters/artist/artist_data.gd")

var vancian_slots: Array = [null, null, null, null] # 4 ammunition slots, null for blank slots
var active_element: String = "fire"

# --- Passive: Ink ---
var ink_damage_boost_percent: float = 0.15
var ink_duration: float = 4.0
var _is_dash_damage: bool = false
var _is_applying_passive_ink: bool = false
var inked_targets: Dictionary = {} # target_instance_id -> remaining_time


const ELEMENT_LABELS: Dictionary = {
	"fire": {"hanzi": "火", "name": "Fire", "color": Color(0.95, 0.35, 0.15, 0.95), "damage": 75.0, "speed": 65.0, "size": 1.0},
	"water": {"hanzi": "水", "name": "Water", "color": Color(0.25, 0.65, 0.95, 0.95), "damage": 50.0, "speed": 55.0, "size": 1.2},
	"air": {"hanzi": "风", "name": "Air", "color": Color(0.45, 0.90, 0.65, 0.95), "damage": 55.0, "speed": 85.0, "size": 0.6},
	"earth": {"hanzi": "土", "name": "Earth", "color": Color(0.85, 0.65, 0.25, 0.95), "damage": 80.0, "speed": 45.0, "size": 1.4}
}

func _ready() -> void:
	super._ready()
	_setup_abilities_kit()

func _setup_character_kit() -> void:
	if id.is_empty():
		id = "artist"
	if character_name.is_empty() or character_name == "Character":
		character_name = "Artist"
	if display_name.is_empty() or display_name == "Character":
		display_name = "Inky"

	var data = ArtistData.create()
	load_character_data(data)
	if data.passive_data.has("ink_slow_percent"):
		ink_slow_percent = float(data.passive_data["ink_slow_percent"])
	if data.passive_data.has("ink_damage_boost_percent"):
		ink_damage_boost_percent = float(data.passive_data["ink_damage_boost_percent"])
	if data.passive_data.has("ink_duration"):
		ink_duration = float(data.passive_data["ink_duration"])

	_setup_abilities_kit()

func _setup_abilities_kit() -> void:
	# Primary (LMB), Secondary (RMB), Q, E are left null
	abilities["LMB"] = null
	abilities["RMB"] = null
	abilities["Q"] = null
	abilities["E"] = null

	# Ultimate (R): Vancian Ammunition Wheel + Hanzi Scribing Canvas
	var r_ab = abilities.get("R")
	if not r_ab:
		r_ab = get_node_or_null("Abilities/R")
	if r_ab and r_ab is AbilityClass:
		abilities["R"] = r_ab
		r_ab.ability_name = "Ink Alchemy"
		r_ab.icon_symbol = "🖌️"
		r_ab.description = "Vancian talisman wheel. Inscribe Hanzi to prepare spells, or unleash prepared elements."
		r_ab.cooldown = 3.0
		r_ab.mana_cost = 0.0

		r_ab.ui_modal = AbilityPipeline.create_ui_modal({
			"type": AbilityPipeline.UIModalType.RADIAL_WHEEL,
			"click_to_cast": true,
			"dynamic_options_func": "get_vancian_modal_options",
			"cancel_cooldown": 1.0,
			"cancel_refund_percent": 1.0
		})

		var modal_inst = r_ab.active_modal_instance
		if not modal_inst or not is_instance_valid(modal_inst):
			modal_inst = VancianHanziModal.new()
			modal_inst.name = "VancianHanziModal"
			modal_inst.caster = self
			add_child(modal_inst)
			r_ab.active_modal_instance = modal_inst
		elif not modal_inst.is_inside_tree():
			add_child(modal_inst)

var is_primed_for_cast: bool:
	get:
		var r_ab = abilities.get("R")
		return r_ab.is_primed_for_cast if (r_ab and r_ab is AbilityClass) else false

func enter_primed_cast_state(slot_idx: int, elem: String) -> void:
	var r_ab = abilities.get("R")
	if r_ab and r_ab is AbilityClass:
		r_ab.enter_primed_state(self, "cast:%d:%s" % [slot_idx, elem])

func cast_primed_spell() -> bool:
	var r_ab = abilities.get("R")
	if r_ab and r_ab is AbilityClass:
		return r_ab.cast_primed_spell(self)
	return false

func cancel_primed_spell() -> void:
	var r_ab = abilities.get("R")
	if r_ab and r_ab is AbilityClass:
		r_ab.cancel_primed_state(self)

func _on_ability_primed(_slot_key: String, choice: String) -> void:
	if choice.begins_with("cast:"):
		var parts = choice.split(":")
		if parts.size() >= 3:
			var elem = parts[2]
			active_element = elem
			_apply_elemental_payload(elem)

func _on_ability_primed_cast(slot_key: String, choice: String) -> void:
	if slot_key == "R" and choice.begins_with("cast:"):
		var parts = choice.split(":")
		if parts.size() >= 3:
			var slot_idx = int(parts[1])
			var elem = parts[2]
			if slot_idx >= 0 and slot_idx < vancian_slots.size():
				vancian_slots[slot_idx] = null
			active_element = elem
			_apply_elemental_payload(elem)


func get_vancian_modal_options(_slot_key: String) -> Array:
	if is_primed_for_cast:
		cancel_primed_spell()

	var opts: Array = []
	for i in range(vancian_slots.size()):
		var val = vancian_slots[i]
		if val != null and str(val).strip_edges() != "":
			var elem = str(val).to_lower()
			var info = ELEMENT_LABELS.get(elem, {
				"hanzi": "✦",
				"name": elem.capitalize(),
				"color": Color(0.85, 0.65, 0.25, 0.95),
				"damage": 60.0,
				"speed": 65.0,
				"size": 1.0
			})
			opts.append({
				"id": "cast:%d:%s" % [i, elem],
				"slot_index": i,
				"label": "%s [%s]" % [info["hanzi"], info["name"]],
				"hanzi": info["hanzi"],
				"name": info["name"],
				"element": elem,
				"color": info["color"],
				"is_empty": false
			})
		else:
			opts.append({
				"id": "empty_%d" % i,
				"slot_index": i,
				"label": "⚪ [Blank]",
				"hanzi": "",
				"name": "Blank",
				"element": "",
				"color": Color(0.35, 0.35, 0.40, 0.8),
				"is_empty": true
			})
	return opts

func _on_modal_option_selected(slot_key: String, choice: String) -> bool:
	if slot_key != "R":
		return true

	if choice.begins_with("inscribed:"):
		# Finished scribing a Hanzi talisman!
		var parts = choice.split(":")
		if parts.size() >= 3:
			var slot_idx = int(parts[1])
			var elem = parts[2]
			if slot_idx >= 0 and slot_idx < vancian_slots.size():
				vancian_slots[slot_idx] = elem
		start_ability_cooldown("R", 1.0)
		return false

	# For cast choices, the preset's click_to_cast handles entering primed state
	return true

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

# --- Passive: Ink Processing & Spell Damage Mechanics ---

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not inked_targets.is_empty():
		var to_remove: Array = []
		for tid in inked_targets.keys():
			inked_targets[tid] -= delta
			if inked_targets[tid] <= 0.0:
				to_remove.append(tid)
		for tid in to_remove:
			inked_targets.erase(tid)

func on_dash_performed() -> void:
	super.on_dash_performed()
	_is_dash_damage = true
	get_tree().create_timer(0.4).timeout.connect(func():
		_is_dash_damage = false
	)

func get_ink_damage_boost() -> float:
	return ink_damage_boost_percent

func is_valid_spell_damage(action_type: int) -> bool:
	# 1. Talent tree upgrade procs are not spells
	if _is_proc_damage:
		return false
	# 2. Basic attacks (LMB) are not spells
	if action_type == ActionType.ATTACK:
		return false
	# 3. Dash damage is not spell damage
	if _is_dash_damage:
		return false
	# 4. Spells (abilities/ultimates)
	return action_type == ActionType.ABILITY or action_type == 2

func is_spell_damage(action_type: int) -> bool:
	return is_valid_spell_damage(action_type)

func is_target_inked(target: Node) -> bool:
	if not is_instance_valid(target):
		return false
	if target.has_method("is_inked"):
		return target.is_inked()
	var tid = target.get_instance_id()
	return inked_targets.has(tid) and inked_targets[tid] > 0.0

func deal_damage(target: Node, amount: float, action_type: int = ActionType.ATTACK, damage_type: int = DamageType.DAMAGE, is_projectile: bool = false) -> void:
	var final_amount = amount
	var my_id = str(name).to_int() if str(name).is_valid_int() else 0
	# If my_id is not resolvable by victim (e.g. standalone test) or target is not BasePlayer:
	if (my_id <= 0 or not (target is BasePlayer)) and is_valid_spell_damage(action_type) and is_target_inked(target):
		final_amount *= (1.0 + ink_damage_boost_percent)
	super.deal_damage(target, final_amount, action_type, damage_type, is_projectile)

func _on_character_damage_dealt(target: Node, amount: float, action_type: int) -> void:
	super._on_character_damage_dealt(target, amount, action_type)
	if amount <= 0.0 or not is_instance_valid(target) or _is_applying_passive_ink:
		return
	if is_valid_spell_damage(action_type):
		apply_ink_to_target(target)

func apply_ink_to_target(target: Node) -> void:
	if not is_instance_valid(target):
		return
	var my_id = str(name).to_int() if str(name).is_valid_int() else 0
	if my_id == 0 and is_multiplayer_match():
		my_id = multiplayer.get_unique_id()
	
	inked_targets[target.get_instance_id()] = ink_duration
	if target.has_method("apply_ink"):
		target.apply_ink(ink_duration, ink_slow_percent, my_id)
	elif target.has_method("apply_slow"):
		target.apply_slow(ink_duration, ink_slow_percent)

func get_status_text() -> String:
	if is_inked():
		return "✦ INKED (-20% MS) ✦"
	elif not inked_targets.is_empty():
		return "✦ INK ACTIVE (%d TARGETS) ✦" % inked_targets.size()
	return ""

