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

# --- RMB: Ink Wall (Temporary Terrain Barrier) ---
const WALL_LENGTH: float = 7.2
const WALL_HEIGHT: float = 2.4
const WALL_THICKNESS: float = 1.44
const WALL_SIZE: Vector3 = Vector3(1.44, 2.4, 7.2)
const WALL_LIFETIME: float = 5.0
const WALL_MAX_CAST_RANGE: float = 25.0

var is_aiming_rmb_wall: bool = false
var rmb_wall_start_pos: Vector3 = Vector3.ZERO
var rmb_wall_aim_dir: Vector3 = Vector3.FORWARD
var rmb_wall_indicator: Node3D = null

# --- Q: Astral Projection (Strange Soul Tether) ---
enum SoulState { INACTIVE, PURSUING, PULLING_BACK }
var soul_state: SoulState = SoulState.INACTIVE
var is_soul_form: bool = false
var soul_marked_body_pos: Vector3 = Vector3.ZERO
var soul_body_puppet: Node3D = null
var soul_target: Node = null
var soul_grabbed_enemy: Node = null
var soul_timer: float = 0.0
var soul_max_duration: float = 3.5
var soul_pull_timer: float = 0.0
var soul_pull_total_time: float = 0.0
var soul_pull_start_pos: Vector3 = Vector3.ZERO
var soul_pull_enemy_start_pos: Vector3 = Vector3.ZERO
var _original_soul_material: Material = null

const SOUL_SPEED: float = 19.0
const SOUL_PULL_SPEED: float = 24.0
const SOUL_GRAB_RADIUS: float = 1.8


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
	# Primary (LMB) and E are left null
	abilities["LMB"] = null
	abilities["E"] = null

	# Q: Astral Projection (Strange Soul Tether)
	var q_ab = abilities.get("Q")
	if not q_ab:
		q_ab = get_node_or_null("Abilities/Q")
	if not q_ab:
		q_ab = AbilityClass.new()
		q_ab.name = "Q"
		q_ab.slot_key = "Q"
		q_ab.ability_id = "artist_astral_projection"
		var abs_node = get_node_or_null("Abilities")
		if abs_node:
			abs_node.add_child(q_ab)
		else:
			add_child(q_ab)
	abilities["Q"] = q_ab
	q_ab.ability_name = "Astral Projection"
	q_ab.icon_symbol = "👻"
	q_ab.description = "Leaves physical body behind as soul surges forward, pursuing the nearest visible enemy through walls. On contact, drags enemy back to body, stunning them during pull + 1.0s after. Soul receives 50% reduced damage and is immune to ground hazards."
	q_ab.cooldown = 12.0
	q_ab.mana_cost = 0.0
	q_ab.cast_on_press = true
	q_ab.damage_amount = 0.0
	q_ab.show_indicator = false

	# Secondary (RMB): Ink Wall (Two-part cast: click for start point, release for direction)
	var rmb_ab = abilities.get("RMB")
	if not rmb_ab:
		rmb_ab = get_node_or_null("Abilities/RMB")
	if not rmb_ab:
		rmb_ab = AbilityClass.new()
		rmb_ab.name = "RMB"
		rmb_ab.slot_key = "RMB"
		rmb_ab.ability_id = "artist_ink_wall"
		var abs_node = get_node_or_null("Abilities")
		if abs_node:
			abs_node.add_child(rmb_ab)
		else:
			add_child(rmb_ab)
	abilities["RMB"] = rmb_ab
	rmb_ab.ability_name = "Ink Wall"
	rmb_ab.icon_symbol = "🖌️"
	rmb_ab.description = "Two-part cast: click to set start point, release to set direction. Erects a temporary wall that pushes up anything above it."
	rmb_ab.cooldown = 7.0
	rmb_ab.mana_cost = 0.0
	rmb_ab.cast_on_press = false
	rmb_ab.damage_amount = 0.0
	rmb_ab.show_indicator = true

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
	_process_soul_form(delta)
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

func _exit_tree() -> void:
	if rmb_wall_indicator and is_instance_valid(rmb_wall_indicator):
		rmb_wall_indicator.queue_free()
		rmb_wall_indicator = null

func _process_character_kit(delta: float) -> void:
	super._process_character_kit(delta)
	_process_rmb_wall_aiming()

func _process_rmb_wall_aiming() -> void:
	if not is_local_player() or is_dead:
		if is_aiming_rmb_wall:
			_cancel_rmb_wall_aim()
		return

	# If primed for R, RMB cancels primed state, not cast wall
	if is_primed_for_cast:
		if is_aiming_rmb_wall:
			_cancel_rmb_wall_aim()
		return

	# Part 1: Click selects starting point
	if Input.is_action_just_pressed("ability_one"):
		var rmb_ab = abilities.get("RMB")
		if rmb_ab and rmb_ab.can_cast(self):
			var mouse_ground = get_mouse_ground_intersection()
			if mouse_ground != null:
				rmb_wall_start_pos = mouse_ground
			else:
				var fwd = -global_transform.basis.z.normalized()
				fwd.y = 0.0
				rmb_wall_start_pos = global_position + fwd * 5.0

			var offset = rmb_wall_start_pos - global_position
			offset.y = 0.0
			if offset.length() > WALL_MAX_CAST_RANGE:
				rmb_wall_start_pos = global_position + offset.normalized() * WALL_MAX_CAST_RANGE

			rmb_wall_start_pos.y = 0.0
			is_aiming_rmb_wall = true
			_show_rmb_wall_indicator()

	if is_aiming_rmb_wall:
		if Input.is_action_just_pressed("ui_cancel"):
			_cancel_rmb_wall_aim()
			return

		var curr_mouse = get_mouse_ground_intersection()
		var dir = Vector3.ZERO
		if curr_mouse != null:
			dir = curr_mouse - rmb_wall_start_pos
			dir.y = 0.0
		if dir.length_squared() < 0.01:
			dir = -global_transform.basis.z
			dir.y = 0.0
		rmb_wall_aim_dir = dir.normalized()
		_update_rmb_wall_indicator(rmb_wall_start_pos, rmb_wall_aim_dir)

func _show_rmb_wall_indicator() -> void:
	if not rmb_wall_indicator or not is_instance_valid(rmb_wall_indicator):
		rmb_wall_indicator = Node3D.new()
		rmb_wall_indicator.name = "ArtistWallIndicator"
		rmb_wall_indicator.top_level = true

		var line_ind = AbilityIndicator.create_line_indicator(
			WALL_LENGTH,
			WALL_THICKNESS,
			Color(0.12, 0.20, 0.18, 0.40),
			Color(0.92, 0.82, 0.35, 0.95),
			false,
			1.0,
			false
		)
		line_ind.name = "Line"
		rmb_wall_indicator.add_child(line_ind)

		var anchor_mesh = MeshInstance3D.new()
		anchor_mesh.name = "Anchor"
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_LINE_STRIP)
		st.set_color(Color(0.92, 0.82, 0.35, 0.95))
		for i in range(33):
			var a = (float(i) / 32.0) * TAU
			st.add_vertex(Vector3(cos(a) * 0.4, 0.07, sin(a) * 0.4))
		anchor_mesh.mesh = st.commit()
		var mat = StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.92, 0.82, 0.35, 0.95)
		mat.no_depth_test = true
		anchor_mesh.material_override = mat
		rmb_wall_indicator.add_child(anchor_mesh)

		if get_tree() and get_tree().root:
			get_tree().root.add_child(rmb_wall_indicator)
		else:
			add_child(rmb_wall_indicator)

	rmb_wall_indicator.show()

func _update_rmb_wall_indicator(start_pos: Vector3, dir: Vector3) -> void:
	if not rmb_wall_indicator or not is_instance_valid(rmb_wall_indicator):
		return
	var rot_y = atan2(-dir.x, -dir.z)
	var line_node = rmb_wall_indicator.get_node_or_null("Line")
	if line_node:
		AbilityIndicator.update_line_indicator(line_node, start_pos, rot_y)
	var anchor_node = rmb_wall_indicator.get_node_or_null("Anchor")
	if anchor_node:
		anchor_node.global_position = Vector3(start_pos.x, 0.07, start_pos.z)

func _hide_rmb_wall_indicator() -> void:
	if rmb_wall_indicator and is_instance_valid(rmb_wall_indicator):
		rmb_wall_indicator.hide()

func _cancel_rmb_wall_aim() -> void:
	is_aiming_rmb_wall = false
	_hide_rmb_wall_indicator()
	var rmb_ab = abilities.get("RMB")
	if rmb_ab:
		rmb_ab.is_holding = false
		if rmb_ab.active_indicator:
			rmb_ab.active_indicator.hide()

func try_cast_ability(slot_key: String, charge_ratio: float = 0.0) -> bool:
	if is_soul_form:
		return false

	if slot_key == "Q":
		var q_ab = abilities.get("Q")
		if not (q_ab is AbilityClass) or not q_ab.can_cast(self):
			return false
		q_ab.consume_resources(self)
		if not is_multiplayer_match() or multiplayer.is_server():
			cast_astral_projection()
		else:
			rpc_id(1, "request_cast_astral_projection")
		return true

	if slot_key == "RMB":
		var rmb_ab = abilities.get("RMB")
		if not (rmb_ab is AbilityClass) or not rmb_ab.can_cast(self):
			_cancel_rmb_wall_aim()
			return false

		# Part 2: Release selects direction!
		var curr_mouse = get_mouse_ground_intersection()
		var dir = Vector3.ZERO
		if is_aiming_rmb_wall:
			if curr_mouse != null:
				dir = curr_mouse - rmb_wall_start_pos
				dir.y = 0.0
		else:
			if rmb_wall_start_pos == Vector3.ZERO:
				var fwd = -global_transform.basis.z.normalized()
				fwd.y = 0.0
				rmb_wall_start_pos = global_position + fwd * 3.0
			if curr_mouse != null:
				dir = curr_mouse - rmb_wall_start_pos
				dir.y = 0.0

		if dir.length_squared() < 0.01:
			dir = -global_transform.basis.z
			dir.y = 0.0
		dir = dir.normalized()

		var start_pos = rmb_wall_start_pos
		_cancel_rmb_wall_aim()

		var center_pos = start_pos + dir * (WALL_LENGTH * 0.5)
		center_pos.y = start_pos.y

		if not is_multiplayer_match() or multiplayer.is_server():
			request_cast_ability("RMB", start_pos, dir, center_pos, charge_ratio)
		else:
			request_cast_ability.rpc_id(1, "RMB", start_pos, dir, center_pos, charge_ratio)
		return true
	return super.try_cast_ability(slot_key, charge_ratio)

func custom_execute_ability_server(slot_key: String, origin: Vector3, direction: Vector3, _target_pos: Vector3, _charge_ratio: float = 0.0) -> bool:
	if slot_key == "Q":
		cast_astral_projection()
		return true
	if slot_key == "RMB":
		spawn_ink_wall(origin, direction)
		return true
	return false

func custom_execute_ability_client(slot_key: String, _origin: Vector3, _direction: Vector3, _target_pos: Vector3, _charge_ratio: float = 0.0) -> bool:
	if slot_key == "Q":
		return true
	if slot_key == "RMB":
		return true
	return false

func spawn_ink_wall(start_pos: Vector3, dir: Vector3) -> Node:
	var aim_dir = dir
	aim_dir.y = 0.0
	if aim_dir.length_squared() < 0.01:
		aim_dir = -global_transform.basis.z
		aim_dir.y = 0.0
	aim_dir = aim_dir.normalized()

	var rot_y = atan2(-aim_dir.x, -aim_dir.z)
	var center_pos = start_pos + aim_dir * (WALL_LENGTH * 0.5)
	center_pos.y = start_pos.y
	var my_id = str(name).to_int() if str(name).is_valid_int() else 0
	if my_id == 0 and is_multiplayer_match():
		my_id = multiplayer.get_unique_id()

	var main_node = get_tree().root.get_node_or_null("Main") if (get_tree() and get_tree().root) else null
	if main_node and main_node.has_method("spawn_temporary_terrain"):
		return main_node.spawn_temporary_terrain(center_pos, WALL_LIFETIME, my_id, WALL_SIZE, rot_y, true)
	else:
		var terr = preload("res://maps/temporary_terrain.tscn").instantiate()
		terr.position = center_pos
		terr.rotation.y = rot_y
		terr.lifetime = WALL_LIFETIME
		terr.owner_id = my_id
		if terr.has_method("set_terrain_size"):
			terr.set_terrain_size(WALL_SIZE)
		if terr.has_method("set_as_wall"):
			terr.set_as_wall(true)
		var p = get_parent()
		if p:
			p.add_child(terr)
		else:
			add_child(terr)
		if not terr.is_node_ready():
			terr._ready()
		return terr

func cast_rmb_wall(start_pos: Vector3, dir: Vector3) -> Node:
	rmb_wall_start_pos = start_pos
	var rmb_ab = abilities.get("RMB")
	if rmb_ab and is_instance_valid(rmb_ab):
		rmb_ab.consume_resources(self)
	return spawn_ink_wall(start_pos, dir)

# --- Q: Astral Projection (Strange Soul Tether) Methods ---

func has_custom_movement_control() -> bool:
	if is_soul_form:
		return true
	return super.has_custom_movement_control()

func modify_incoming_damage(amount: float, attacker_id: int, action_type: int) -> float:
	var amt = super.modify_incoming_damage(amount, attacker_id, action_type)
	if is_soul_form and attacker_id != peer_id:
		amt *= 0.50 # Soul receives 50% reduced damage from enemies
	return amt

func can_see_target(target: Node) -> bool:
	if not is_instance_valid(target) or target.get("is_dead"):
		return false
	var diff = target.global_position - global_position
	var dist = Vector2(diff.x, diff.z).length()
	if dist > forward_vision_range:
		return false

	var space = get_world_3d().direct_space_state if get_world_3d() else null
	if space:
		var from_eye = global_position + Vector3(0, 1.25, 0)
		var to_target = target.global_position + Vector3(0, 1.0, 0)
		var query = PhysicsRayQueryParameters3D.create(from_eye, to_target, 1) # Layer 1 = terrain/walls
		var excludes = [get_rid()]
		if target.has_method("get_rid"):
			excludes.append(target.get_rid())
		query.exclude = excludes
		var hit = space.intersect_ray(query)
		if hit:
			return false
	return true

func cast_astral_projection() -> void:
	soul_marked_body_pos = global_position
	_spawn_dormant_body_puppet(soul_marked_body_pos)
	is_soul_form = true
	can_pass_through_walls = true
	ground_hazard_immune = true
	soul_state = SoulState.PURSUING
	soul_timer = 0.0
	soul_grabbed_enemy = null

	var fwd = -global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.001:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()
	velocity = fwd * SOUL_SPEED
	_set_soul_visuals(true)

func _spawn_dormant_body_puppet(pos: Vector3) -> void:
	if is_instance_valid(soul_body_puppet):
		soul_body_puppet.queue_free()
	var puppet = Node3D.new()
	puppet.name = "ArtistDormantBody"
	puppet.position = pos

	var mesh_inst = MeshInstance3D.new()
	var cap_mesh = CapsuleMesh.new()
	cap_mesh.radius = 0.45
	cap_mesh.height = 1.7
	mesh_inst.mesh = cap_mesh
	mesh_inst.position = Vector3(0, 0.85, 0)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.32, 0.28, 1.0)
	mat.roughness = 0.9
	mesh_inst.material_override = mat
	puppet.add_child(mesh_inst)

	var p = get_parent() if get_parent() else self
	p.add_child(puppet)
	soul_body_puppet = puppet

func _set_soul_visuals(active: bool) -> void:
	var mesh_inst = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not mesh_inst:
		return
	if active:
		_original_soul_material = mesh_inst.material_override
		var soul_mat = StandardMaterial3D.new()
		soul_mat.albedo_color = Color(0.2, 0.85, 1.0, 0.65)
		soul_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		soul_mat.emission_enabled = true
		soul_mat.emission = Color(0.3, 0.9, 1.0, 1.0)
		soul_mat.emission_energy_multiplier = 2.0
		mesh_inst.material_override = soul_mat
	else:
		mesh_inst.material_override = _original_soul_material

func _process_soul_form(delta: float) -> void:
	if not is_soul_form:
		return

	if soul_state == SoulState.PURSUING:
		soul_timer += delta

		# 1. Persistently track nearest visible enemy
		var nearest_enemy: Node = null
		var nearest_dist: float = 999999.0
		var players = get_tree().get_nodes_in_group("players") if (is_inside_tree() and get_tree()) else []
		for p in players:
			if not is_instance_valid(p) or p == self or p.get("is_dead"):
				continue
			var p_team = p.team_id if "team_id" in p else 0
			if team_id > 0 and p_team == team_id:
				continue
			if not can_see_target(p):
				continue
			var d = global_position.distance_to(p.global_position)
			if d < nearest_dist:
				nearest_dist = d
				nearest_enemy = p

		if nearest_enemy != null:
			soul_target = nearest_enemy
			var dir = (nearest_enemy.global_position - global_position)
			dir.y = 0.0
			if dir.length_squared() > 0.001:
				dir = dir.normalized()
				velocity.x = dir.x * SOUL_SPEED
				velocity.z = dir.z * SOUL_SPEED
				var look_pos = global_position + dir
				if global_position.distance_squared_to(look_pos) > 0.001:
					look_at(look_pos, Vector3.UP)

		# 2. Check contact with enemies
		for p in players:
			if not is_instance_valid(p) or p == self or p.get("is_dead"):
				continue
			var p_team = p.team_id if "team_id" in p else 0
			if team_id > 0 and p_team == team_id:
				continue
			if global_position.distance_to(p.global_position) <= SOUL_GRAB_RADIUS:
				# Contact! Grab enemy and pull back
				soul_grabbed_enemy = p
				soul_state = SoulState.PULLING_BACK
				soul_pull_timer = 0.0
				soul_pull_start_pos = global_position
				soul_pull_enemy_start_pos = p.global_position
				var dist_to_body = global_position.distance_to(soul_marked_body_pos)
				soul_pull_total_time = max(0.35, dist_to_body / SOUL_PULL_SPEED)
				if p.has_method("apply_stun"):
					p.apply_stun(soul_pull_total_time + 1.0)
				velocity = Vector3.ZERO
				return

		if soul_timer >= soul_max_duration:
			_return_soul_to_body()

	elif soul_state == SoulState.PULLING_BACK:
		soul_pull_timer += delta
		var t = clamp(soul_pull_timer / max(0.01, soul_pull_total_time), 0.0, 1.0)
		global_position = soul_pull_start_pos.lerp(soul_marked_body_pos, t)
		velocity = Vector3.ZERO

		if is_instance_valid(soul_grabbed_enemy):
			var enemy_end_pos = soul_marked_body_pos + Vector3(0.5, 0, 0.5)
			soul_grabbed_enemy.global_position = soul_pull_enemy_start_pos.lerp(enemy_end_pos, t)
			if "velocity" in soul_grabbed_enemy:
				soul_grabbed_enemy.velocity = Vector3.ZERO

		if t >= 1.0:
			global_position = soul_marked_body_pos
			if is_instance_valid(soul_grabbed_enemy):
				soul_grabbed_enemy.global_position = soul_marked_body_pos + Vector3(0.5, 0, 0.5)
			_end_soul_form()

func _return_soul_to_body() -> void:
	global_position = soul_marked_body_pos
	_end_soul_form()

func _end_soul_form() -> void:
	if is_instance_valid(soul_body_puppet):
		soul_body_puppet.queue_free()
		soul_body_puppet = null
	is_soul_form = false
	can_pass_through_walls = false
	ground_hazard_immune = false
	soul_state = SoulState.INACTIVE
	soul_target = null
	soul_grabbed_enemy = null
	velocity = Vector3.ZERO
	_set_soul_visuals(false)

@rpc("any_peer", "call_local", "reliable")
func request_cast_astral_projection() -> void:
	if is_multiplayer_match() and not multiplayer.is_server():
		return
	cast_astral_projection()



