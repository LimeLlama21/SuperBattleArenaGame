class_name BasePlayer
extends PlayerVision

enum ActionType {
	ATTACK = 0,      # Primary / Basic Attack
	ABILITY = 1,     # Special Ability / Spell
	ENVIRONMENT = 2  # Map Hazards / Void / Wall Impact
}

signal attack_performed(attack_name: String)
signal ability_cast(ability_name: String, slot_key: String)
signal damage_dealt(target: Node, amount: float, action_type: int)
signal damage_taken(attacker_id: int, amount: float, action_type: int)
signal takedown_scored(victim: Node)
signal armor_charges_changed(current: int, max_val: int)
signal projectile_damage_resisted(attacker_id: int, original_amount: float)

# --- Character Identification & Team ---
@export var character_name: String = "Character"
@export var display_name: String = "Character"

func get_display_name() -> String:
	return display_name if not display_name.is_empty() else character_name

@export var team_id: int = 1:
	set(value):
		team_id = value
		_update_team_visuals()

# --- Core Vitals & Defense ---
@export var max_health: float = 200.0
@export var current_health: float = 200.0:
	set(value):
		current_health = clamp(value, 0.0, max_health)
		update_health_bar()

# --- Mana Parameters ---
@export var max_mana: float = 100.0
@export var current_mana: float = 100.0:
	set(value):
		current_mana = clamp(value, 0.0, max_mana)
		update_health_bar()
var base_max_mana: float = 100.0
var base_mana_regen: float = 3.0 # 3 mana per second base
var last_synced_mana: float = 100.0

@export var max_shield: float = 100.0
var current_shield: float = 0.0:
	set(value):
		current_shield = clamp(value, 0.0, max_shield)
		update_health_bar()
var shield_timer: float = 0.0
var is_dead: bool = false
var recent_damage_dealers: Dictionary = {} # attacker_id -> timestamp (seconds)
var respawn_countdown: float = 0.0

var peer_id: int:
	get: return name.to_int()

# --- Armor Charges (Anti-Poke Defense) ---
@export var max_armor_charges: int = 2
@export var armor_charges: int = 2:
	set(value):
		var clamped_val = clamp(value, 0, max_armor_charges)
		if armor_charges != clamped_val:
			armor_charges = clamped_val
			armor_charges_changed.emit(armor_charges, max_armor_charges)
			update_health_bar()

func get_armor_charges() -> int:
	return armor_charges

func consume_armor_charge() -> bool:
	if armor_charges > 0:
		armor_charges -= 1
		if is_multiplayer_match() and is_server_authoritative():
			sync_armor_charges.rpc(armor_charges)
		return true
	return false

func restore_armor_charge(amount: int = 1) -> void:
	armor_charges = min(max_armor_charges, armor_charges + amount)
	if is_multiplayer_match() and is_server_authoritative():
		sync_armor_charges.rpc(armor_charges)

func reset_armor_charges() -> void:
	armor_charges = max_armor_charges
	if is_multiplayer_match() and is_server_authoritative():
		sync_armor_charges.rpc(armor_charges)

func take_projectile_damage(amount: float, attacker_id: int = 0, action_type: int = ActionType.ATTACK) -> void:
	take_damage(amount, attacker_id, action_type, true)

func add_shield(amount: float, duration: float = 5.0) -> void:
	apply_shield(amount, duration)

func has_mana(amount: float) -> bool:
	return current_mana >= (amount - 0.001)

func consume_mana(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if not has_mana(amount):
		return false
	current_mana = clamp(current_mana - amount, 0.0, max_mana)
	if is_multiplayer_match() and is_server_authoritative():
		sync_mana.rpc(current_mana)
	return true

func restore_mana(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	var old = current_mana
	current_mana = clamp(current_mana + amount, 0.0, max_mana)
	if current_mana != old and is_multiplayer_match() and is_server_authoritative():
		sync_mana.rpc(current_mana)

# --- Inventory & Items ---
@export var max_item_slots: int = 1
var item_slots: Array[String] = []
var item_ability_nodes: Array[Node] = []
var item_stats: Dictionary = {} # Arbitrary aggregated stats from equipped items
var gold: int = 0

var base_max_health: float = 200.0
var base_max_move_speed: float = 6.0
var base_crit_chance: float = 0.0
var base_crit_multiplier: float = AbilityPipeline.CRIT_DAMAGE_MULTIPLIER
var base_max_shield: float = 100.0
var base_jump_velocity: float = 13.0
var base_ground_acceleration: float = 25.0

var item_damage_percent: float = 0.0
var item_health_bonus: float = 0.0
var item_move_speed_bonus: float = 0.0

# --- Critical Strike Stats ---
@export var crit_chance: float = 0.0 # Base crit chance (0.0 = 0%)
@export var crit_multiplier: float = AbilityPipeline.CRIT_DAMAGE_MULTIPLIER # 2.0 = 200% double damage

const AbilityClass = preload("res://ability/ability.gd")
const PlayerSharedEffects = preload("res://player/player_shared_effects.gd")

# --- Shared Takedown Effects ---
var takedown_effects: Array[Callable] = []
var _shared_effects_initialized: bool = false

func register_takedown_effect(effect: Callable) -> void:
	if not takedown_effects.has(effect):
		takedown_effects.append(effect)

func unregister_takedown_effect(effect: Callable) -> void:
	takedown_effects.erase(effect)

func clear_takedown_effects() -> void:
	takedown_effects.clear()

func get_takedown_effects() -> Array[Callable]:
	return takedown_effects

func _setup_shared_takedown_effects() -> void:
	if not _shared_effects_initialized:
		_shared_effects_initialized = true
		register_takedown_effect(PlayerSharedEffects.restore_mana_on_takedown)
		register_takedown_effect(PlayerSharedEffects.heal_missing_hp_on_takedown)

func _init() -> void:
	_setup_shared_takedown_effects()

# --- Ability Registers & Lockout State ---
@export_group("Character Data")
@export var character_data: CharacterData = null

@export_group("Abilities")
@export var ability_lmb: PackedScene = null
@export var ability_rmb: PackedScene = null
@export var ability_shift: PackedScene = null
@export var ability_q: PackedScene = null
@export var ability_e: PackedScene = null
@export var ability_r: PackedScene = null
@export var ability_passive: PackedScene = null

var abilities: Dictionary = {}
var ability_slots: Dictionary = {}
var slot_remaps: Dictionary = {}
var active_modal_slot: String = ""

func start_ability_cooldown(slot_key: String, duration: float) -> void:
	var ab = abilities.get(slot_key)
	if ab:
		var mult = get_cooldown_multiplier() if has_method("get_cooldown_multiplier") else 1.0
		ab.current_cooldown = duration * mult

func remap_slot(from_slot: String, to_slot: String) -> void:
	slot_remaps[from_slot] = to_slot

func unremap_slot(from_slot: String) -> void:
	slot_remaps.erase(from_slot)

func clear_slot_remaps() -> void:
	slot_remaps.clear()

func get_effective_slot(slot_key: String) -> String:
	if slot_remaps.has(slot_key):
		return slot_remaps[slot_key]
	return slot_key

func get_ability_for_slot(slot_key: String) -> AbilityClass:
	var eff_slot = get_effective_slot(slot_key)
	var ab = abilities.get(eff_slot)
	if not (ab is AbilityClass) and ability_slots.has(eff_slot):
		ab = abilities.get(ability_slots[eff_slot])
	return ab as AbilityClass

var cast_lockout_timer: float = 0.0
var move_lockout_timer: float = 0.0
var current_cast_lockout_ability_id: String = ""
var current_move_lockout_ability_id: String = ""
var ability_lockout_timer: float:
	get: return cast_lockout_timer
	set(val): cast_lockout_timer = val
var current_lockout_ability_id: String:
	get: return current_cast_lockout_ability_id
	set(val): current_cast_lockout_ability_id = val

# --- Ability Buffering System ---
var buffered_ability_slot: String:
	get: return ability_buffer.buffered_slot if ability_buffer else ""
	set(value): if ability_buffer: ability_buffer.buffered_slot = value
var buffered_ability_timer: float:
	get: return ability_buffer.buffer_timer if ability_buffer else 0.0
	set(value): if ability_buffer: ability_buffer.buffer_timer = value
const ABILITY_BUFFER_WINDOW: float = 0.65

# --- Ability Hitbox & Telegraph Pipeline State ---
var active_windup_id: String = "":
	set(value):
		active_windup_id = value
		if active_windup_id != "":
			_on_windup_id_changed(active_windup_id)

var active_windup_facing: Vector3 = Vector3.FORWARD

# --- Camera & Spectator Constants ---
const CAMERA_OFFSET: Vector3 = Vector3(0, 19.0, 5.09) # 15 degrees from vertical (top-down)
const VOID_DEATH_Y: float = -8.0
var spectate_target: Node3D = null
var spectate_index: int = 0

# --- UI & Node References ---
@onready var camera: Camera3D = get_node_or_null("Camera3D")
@onready var sprite_3d: Sprite3D = get_node_or_null("HealthBarSprite")
@onready var health_bar: ProgressBar = get_node_or_null("HealthBarViewport/ProgressBar")
@onready var gray_health_bar: ProgressBar = get_node_or_null("HealthBarViewport/GrayProgressBar")
@onready var shield_bar: ProgressBar = get_node_or_null("HealthBarViewport/ShieldProgressBar")

@onready var hud: CanvasLayer = get_node_or_null("PlayerHUD")

# Ability Bar Slots (Ordered: LMB -> RMB -> DASH -> Q -> E -> R)
@onready var slot_lmb: AbilitySlot = null
@onready var slot_ability_one: AbilitySlot = null
@onready var slot_dash: AbilitySlot = null
@onready var slot_ability_two: AbilitySlot = null
@onready var slot_ability_three: AbilitySlot = null
@onready var slot_ability_four: AbilitySlot = null
var firing_indicator_timer: float = 0.0

# Local Player Aim Guide (constant line from character to crosshair)
var aim_line_root: Node3D = null
var aim_line_mesh_inst: MeshInstance3D = null
var aim_line_mat: StandardMaterial3D = null
var aim_crosshair_root: Node3D = null

@onready var spectator_panel: PanelContainer = null
@onready var spectator_label: Label = null
@onready var status_cc_label: Label = null

# Vision cone properties (modifiable by character kits, e.g. Poke Sniper Stance)
var forward_vision_range: float = 24.0
var forward_vision_angle: float = 45.0

func get_custom_cone_radius() -> float:
	return forward_vision_range

func get_custom_cone_half_angle_deg() -> float:
	return forward_vision_angle

# --- Lifecycle Initialization ---
func _enter_tree() -> void:
	_setup_synchronizer()

func _ready() -> void:
	add_to_group("players")
	_setup_synchronizer()

	var is_local = is_local_player()
	if camera:
		camera.current = is_local
		if is_local and is_inside_tree() and camera.is_inside_tree():
			camera.top_level = true
			camera.global_position = global_position + CAMERA_OFFSET
			camera.look_at(global_position, Vector3.UP)
	
	if hud:
		hud.visible = is_local
	if spectator_panel:
		spectator_panel.visible = false

	_setup_combat_hitbox()
	_setup_health_bars()
	if sprite_3d and has_node("HealthBarViewport"):
		sprite_3d.texture = $HealthBarViewport.get_texture()
	update_health_bar()
	_update_team_visuals()
	call_deferred("_update_team_visuals")

	# Setup character-specific kit
	_setup_shared_takedown_effects()
	if character_data != null:
		load_character_data(character_data)
	_setup_character_kit()
	_setup_hud_elements()
	_setup_abilities()
	if is_local:
		_setup_local_aim_guide()
	base_max_health = max_health
	base_max_move_speed = max_move_speed
	base_crit_chance = crit_chance
	base_crit_multiplier = crit_multiplier
	base_max_shield = max_shield
	base_jump_velocity = jump_velocity
	base_ground_acceleration = ground_acceleration
	apply_all_items()

func _physics_process(delta: float) -> void:
	# Deadzone / Void Check
	if is_server_authoritative() and not is_dead and global_position.y < VOID_DEATH_Y:
		die()

	# Shield timer decrement
	if shield_timer > 0.0:
		shield_timer -= delta
		if shield_timer <= 0.0:
			current_shield = 0.0
			if is_multiplayer_match() and is_server_authoritative():
				sync_shield.rpc(0.0)

	# Mana Regeneration (3.0 mana per second base + arbitrary item stats)
	if not is_dead and current_mana < max_mana:
		var regen = base_mana_regen + get_item_stat("mana_regen")
		current_mana = min(max_mana, current_mana + (regen * delta))
		if is_multiplayer_match() and is_server_authoritative() and abs(current_mana - last_synced_mana) >= 5.0:
			last_synced_mana = current_mana
			sync_mana.rpc(current_mana)

	# Firing box & LMB visual state (darkens when firing)
	if is_local_player() and hud and hud.has_method("set_firing_indicator"):
		var is_firing = Input.is_action_pressed("shoot") or firing_indicator_timer > 0.0
		if firing_indicator_timer > 0.0:
			firing_indicator_timer -= delta
		hud.set_firing_indicator(is_firing)

	# Base physics timers decrement (CC, float, wall impact, channeling)
	_process_physics_timers(delta)

	# Ability Lockout timers decrement
	if cast_lockout_timer > 0.0:
		cast_lockout_timer -= delta
		if cast_lockout_timer <= 0.0:
			cast_lockout_timer = 0.0
			current_cast_lockout_ability_id = ""
			_try_resolve_buffered_ability()
	if move_lockout_timer > 0.0:
		move_lockout_timer -= delta
		if move_lockout_timer <= 0.0:
			move_lockout_timer = 0.0
			current_move_lockout_ability_id = ""

	# Update unified ability buffer
	if ability_buffer:
		ability_buffer.update(delta)

	# Process input buffering during active commitments (lockouts and channels)
	if is_local_player() and not is_dead and not is_stunned() and not is_bound():
		if is_in_cast_lockout():
			if Input.is_action_just_pressed("shoot") and not can_cast_ability_slot("LMB"):
				buffer_ability("LMB")
			elif Input.is_action_just_pressed("ability_one") and not can_cast_ability_slot("RMB"):
				buffer_ability("RMB")
			elif Input.is_action_just_pressed("ability_two") and not can_cast_ability_slot("Q"):
				buffer_ability("Q")
			elif Input.is_action_just_pressed("ability_three") and not can_cast_ability_slot("E"):
				buffer_ability("E")
			elif Input.is_action_just_pressed("ability_four") and not can_cast_ability_slot("R"):
				buffer_ability("R")
			elif Input.is_action_just_pressed("dash") and not can_cast_ability_slot("SHIFT"):
				buffer_ability("SHIFT")
		elif has_buffered_ability():
			_try_resolve_buffered_ability()

	# Process unified ability lifecycle (cooldowns & HUD sync)
	_process_abilities_lifecycle(delta)

	# Process input for abilities if local player
	if is_local_player():
		_process_abilities_input(delta)

	# Process Character-specific kit logic (both server and clients)
	_process_character_kit(delta)

	var is_local = is_local_player()
	var is_server_or_offline = multiplayer.is_server() if (multiplayer and multiplayer.has_multiplayer_peer()) else true
	var is_server_dummy = (name.to_int() == 0 and is_server_or_offline)

	if not is_local and not is_server_dummy:
		return

	if is_server_dummy:
		_process_dummy_physics(delta)
		return

	# If dead, process Spectator camera & inputs (skip spectator in training mode)
	if is_dead:
		var main_node = get_tree().root.get_node_or_null("Main")
		if main_node and main_node.get("is_training_mode") == true:
			if camera and is_instance_valid(camera) and camera.is_inside_tree():
				_process_camera(delta)
			return
		_process_spectator(delta)
		return

	if not DisplayServer.window_is_focused():
		return

	# Update camera position
	if camera and is_instance_valid(camera) and camera.is_inside_tree():
		_process_camera(delta)

	_update_hud()

	# Aiming
	if not is_stunned() and not is_bound():
		aim_at_mouse()

	_update_local_aim_guide(delta)

	# Taunt auto-attack: forces taunted unit to attack towards taunter
	if is_taunted() and not is_stunned() and not is_bound():
		var taunter = get_taunt_target()
		if is_instance_valid(taunter) and can_cast_ability_slot("LMB") and not is_in_cast_lockout():
			try_cast_ability("LMB")

	# Delegate Character-specific inputs (LMB, RMB, Q, E, R, SHIFT)
	if (not is_stunned() and not is_bound()) or can_cast_ability_slot("R"):
		_handle_character_input(delta)

	# Execute Physics Move & Slide via PlayerPhysics
	_process_player_movement_physics(delta, is_channeling)

# --- Team & Identification Operations ---
func set_team_id(new_team: int) -> void:
	team_id = new_team
	_refresh_all_team_visuals()

func is_enemy(other: Node) -> bool:
	if not other or other == self:
		return false
	if other.name == name:
		return false
	if other.get("team_id") != null:
		return other.team_id != team_id
	return true

func set_opponent_visible(is_vis: bool) -> void:
	if is_local_player():
		visible = not is_dead
		return
	if is_dead or is_invisible():
		visible = false
		if sprite_3d:
			sprite_3d.visible = false
		return
	visible = is_vis
	if sprite_3d:
		sprite_3d.visible = is_vis

func _on_invisibility_changed(is_invis: bool) -> void:
	if is_local_player():
		var mesh_inst: MeshInstance3D = get_node_or_null("MeshInstance3D")
		if mesh_inst:
			var mat = mesh_inst.material_override as StandardMaterial3D
			if not mat and mesh_inst.mesh and mesh_inst.mesh.material is StandardMaterial3D:
				mat = mesh_inst.mesh.material.duplicate() as StandardMaterial3D
				mesh_inst.material_override = mat
			if mat:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if is_invis else BaseMaterial3D.TRANSPARENCY_DISABLED
				var col = mat.albedo_color
				col.a = 0.40 if is_invis else 1.0
				mat.albedo_color = col
				if not is_invis:
					mesh_inst.material_override = null
		var facing_ind: MeshInstance3D = get_node_or_null("FacingIndicator")
		if facing_ind:
			var f_mat = facing_ind.material_override as StandardMaterial3D
			if not f_mat and facing_ind.mesh and facing_ind.mesh.material is StandardMaterial3D:
				f_mat = facing_ind.mesh.material.duplicate() as StandardMaterial3D
				facing_ind.material_override = f_mat
			if f_mat:
				f_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if is_invis else BaseMaterial3D.TRANSPARENCY_DISABLED
				var f_col = f_mat.albedo_color
				f_col.a = 0.40 if is_invis else 1.0
				f_mat.albedo_color = f_col
				if not is_invis:
					facing_ind.material_override = null
	else:
		if is_invis:
			visible = false
			if sprite_3d:
				sprite_3d.visible = false
		else:
			visible = not is_dead
			if sprite_3d:
				sprite_3d.visible = not is_dead

func get_local_player_team() -> int:
	var local_id = get_my_player_id()
	var tree = get_tree() if is_inside_tree() else null
	var main_node = tree.root.get_node_or_null("Main") if tree else null
	if main_node and main_node.has_method("get_player_team"):
		return main_node.get_player_team(local_id)
	
	var local_player = tree.root.get_node_or_null("Main/Players/" + str(local_id)) if tree else null
	if local_player and local_player.get("team_id") != null:
		return local_player.team_id
	
	if name == str(local_id):
		return team_id
		
	return 1

func _refresh_all_team_visuals() -> void:
	_update_team_visuals()
	var players_cont = get_tree().root.get_node_or_null("Main/Players") if get_tree() else null
	if players_cont:
		for p in players_cont.get_children():
			if p.has_method("_update_team_visuals"):
				p._update_team_visuals()

func _update_team_visuals() -> void:
	var mesh_inst: MeshInstance3D = get_node_or_null("MeshInstance3D")
	
	var local_id = get_my_player_id()
	var local_team = get_local_player_team()
	var is_same_team = (team_id == local_team) or (name == str(local_id))
	
	var model_color = Color(0.18, 0.58, 1.0, 1.0) if is_same_team else Color(0.95, 0.20, 0.20, 1.0)
	var emissive_color = Color(0.08, 0.25, 0.5, 1.0) if is_same_team else Color(0.45, 0.08, 0.08, 1.0)

	if mesh_inst:
		var mat = mesh_inst.material_override as StandardMaterial3D
		if not mat:
			mat = StandardMaterial3D.new()
		else:
			mat = mat.duplicate() as StandardMaterial3D
		mat.albedo_color = model_color
		mat.roughness = 0.35
		mat.metallic = 0.2
		mat.emission_enabled = true
		mat.emission = emissive_color
		mat.emission_energy_multiplier = 0.3
		mesh_inst.material_override = mat

	if health_bar:
		var fill_sb = health_bar.get_theme_stylebox("fill")
		if fill_sb:
			fill_sb = fill_sb.duplicate()
		else:
			fill_sb = StyleBoxFlat.new()
			fill_sb.corner_radius_top_left = 4
			fill_sb.corner_radius_top_right = 4
			fill_sb.corner_radius_bottom_right = 4
			fill_sb.corner_radius_bottom_left = 4
		
		if fill_sb is StyleBoxFlat:
			fill_sb.bg_color = Color(0.18, 0.65, 1.0, 1.0) if is_same_team else Color(1.0, 0.25, 0.25, 1.0)
			health_bar.add_theme_stylebox_override("fill", fill_sb)

# --- Damage, Shields & Health Management ---
func apply_shield(amount: float, duration: float = 5.0) -> void:
	if is_multiplayer_match() and not multiplayer.is_server():
		return
	current_shield = min(max_shield, current_shield + amount)
	shield_timer = max(shield_timer, duration)
	if is_multiplayer_match() and multiplayer.is_server():
		sync_shield.rpc(current_shield)

@rpc("any_peer", "call_local", "reliable")
func sync_shield(new_shield: float) -> void:
	if not _is_sender_host():
		return
	current_shield = new_shield

func modify_incoming_damage(amount: float, attacker_id: int, _action_type: int) -> float:
	if attacker_id > 0 and get_tree():
		var attacker = get_tree().root.get_node_or_null("Main/Players/" + str(attacker_id))
		if not attacker:
			attacker = get_tree().root.find_child(str(attacker_id), true, false)
		if attacker and attacker.has_method("get_taunt_damage_multiplier"):
			amount *= attacker.get_taunt_damage_multiplier()
	var dmg_reduction = get_item_stat("damage_reduction") + get_item_stat("armor")
	if dmg_reduction > 0.0:
		amount *= clamp(1.0 - (dmg_reduction / 100.0), 0.0, 1.0)
	return amount

func take_damage(amount: float, attacker_id: int = 0, action_type: int = ActionType.ATTACK, is_projectile: bool = false) -> void:
	if is_multiplayer_match() and not multiplayer.is_server():
		return
	if is_dead:
		return

	if is_ethereal_active() or is_invulnerable():
		return

	if is_projectile and amount > 0.0 and armor_charges > 0:
		consume_armor_charge()
		projectile_damage_resisted.emit(attacker_id, amount)
		return

	if is_transformed and transformation_properties.get("break_on_damage", true):
		break_transformation()

	if attacker_id > 0:
		var attacker = get_tree().root.get_node_or_null("Main/Players/" + str(attacker_id))
		if attacker and attacker.has_method("get_damage_multiplier"):
			amount *= attacker.get_damage_multiplier()

	var final_dmg = modify_incoming_damage(amount, attacker_id, action_type)
	if final_dmg <= 0.0:
		return

	var remaining_dmg = final_dmg
	if current_shield > 0.0:
		var absorbed = min(current_shield, remaining_dmg)
		current_shield -= absorbed
		remaining_dmg -= absorbed
		if is_multiplayer_match() and multiplayer.is_server():
			sync_shield.rpc(current_shield)

	if remaining_dmg > 0.0:
		current_health -= remaining_dmg
		if is_multiplayer_match() and multiplayer.is_server():
			sync_health.rpc(current_health)

	_on_damage_taken_hook(final_dmg, attacker_id, action_type)
	damage_taken.emit(attacker_id, final_dmg, action_type)

	if attacker_id > 0:
		recent_damage_dealers[attacker_id] = Time.get_ticks_msec() / 1000.0
		var attacker = null
		if get_tree() and get_tree().root:
			attacker = get_tree().root.get_node_or_null("Main/Players/" + str(attacker_id))
			if not attacker and get_parent():
				attacker = get_parent().get_node_or_null(str(attacker_id))
			if not attacker:
				attacker = get_tree().root.get_node_or_null(str(attacker_id))
		if attacker and attacker.has_method("_on_damage_dealt"):
			attacker._on_damage_dealt(self, final_dmg, action_type)

	if current_health <= 0.0:
		die()

func deal_damage(target: Node, amount: float, action_type: int = ActionType.ATTACK) -> void:
	if not is_instance_valid(target) or not target.has_method("take_damage"):
		return
	var my_id = str(name).to_int() if str(name).is_valid_int() else 0
	target.take_damage(amount, my_id, action_type)

func _on_damage_dealt(target: Node, amount: float, action_type: int) -> void:
	damage_dealt.emit(target, amount, action_type)
	_on_character_damage_dealt(target, amount, action_type)
	
	# Arbitrary stat: lifesteal / omnivamp
	var vamp = get_item_stat("lifesteal") + get_item_stat("omnivamp") + get_item_stat("vamp")
	if vamp > 0.0 and amount > 0.0:
		heal(amount * (vamp / 100.0))

func _on_takedown(victim: Node) -> void:
	takedown_scored.emit(victim)
	_on_character_takedown(victim)
	for effect in takedown_effects:
		if effect.is_valid():
			var arg_count = effect.get_argument_count()
			if arg_count == 1:
				effect.call(self)
			elif arg_count == 0:
				effect.call()
			else:
				effect.call(self, victim)

func _on_character_takedown(_victim: Node) -> void:
	pass

func heal(amount: float) -> void:
	if (is_multiplayer_match() and not multiplayer.is_server()) or is_dead:
		return
	current_health = clamp(current_health + amount, 0.0, max_health)
	if is_multiplayer_match() and multiplayer.is_server():
		sync_health.rpc(current_health)

@rpc("any_peer", "call_local", "reliable")
func sync_health(new_health: float) -> void:
	if not _is_sender_host():
		return
	current_health = new_health
	if current_health <= 0.0 and not is_dead:
		is_dead = true
		_update_death_state(true)

@rpc("any_peer", "call_local", "reliable")
func sync_mana(new_mana: float) -> void:
	if not _is_sender_host():
		return
	current_mana = new_mana
	update_health_bar()

@rpc("any_peer", "call_local", "reliable")
func sync_armor_charges(new_charges: int) -> void:
	if not _is_sender_host():
		return
	armor_charges = new_charges

func get_combat_hitbox() -> Area3D:
	return get_node_or_null("CombatHitbox") as Area3D

func _setup_combat_hitbox() -> void:
	var combat_hitbox = get_node_or_null("CombatHitbox")
	if not combat_hitbox:
		var hb_class = load("res://player/combat_hitbox.gd")
		if hb_class:
			combat_hitbox = hb_class.new()
		else:
			combat_hitbox = Area3D.new()
		combat_hitbox.name = "CombatHitbox"
		add_child(combat_hitbox)
	
	if "character" in combat_hitbox:
		combat_hitbox.character = self
	combat_hitbox.set_meta("character", self)
	combat_hitbox.collision_layer = 2 # Characters layer
	combat_hitbox.collision_mask = 0  # Passive receiver, does not check collisions
	combat_hitbox.monitoring = false
	combat_hitbox.monitorable = true
	
	# Determine character horizontal radius from existing collision shape (not altering physical collision mesh)
	var char_radius: float = 0.4
	var col_shape_node = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col_shape_node and col_shape_node.shape:
		if col_shape_node.shape is CapsuleShape3D or col_shape_node.shape is CylinderShape3D:
			char_radius = col_shape_node.shape.radius
		elif col_shape_node.shape is BoxShape3D:
			char_radius = max(col_shape_node.shape.size.x, col_shape_node.shape.size.z) * 0.5
	
	var col_child = combat_hitbox.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not col_child:
		col_child = CollisionShape3D.new()
		col_child.name = "CollisionShape3D"
		combat_hitbox.add_child(col_child)
	
	# Combat hitbox is a cylinder extending infinitely both up and down (+/- 2000m)
	var cyl = CylinderShape3D.new()
	cyl.radius = char_radius
	cyl.height = 4000.0
	col_child.shape = cyl
	col_child.position = Vector3.ZERO

func _setup_health_bars() -> void:
	var vp = get_node_or_null("HealthBarViewport")
	if not vp:
		return
	
	var vp_size = vp.size if vp.size != Vector2i.ZERO else Vector2i(220, 28)
	var sz = Vector2(vp_size.x, vp_size.y)
	
	var bg_sb = StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.12, 0.12, 0.12, 0.85)
	bg_sb.corner_radius_top_left = 4
	bg_sb.corner_radius_top_right = 4
	bg_sb.corner_radius_bottom_right = 4
	bg_sb.corner_radius_bottom_left = 4

	var gray_fill_sb = StyleBoxFlat.new()
	gray_fill_sb.bg_color = Color(0.35, 0.37, 0.40, 0.95)
	gray_fill_sb.corner_radius_top_left = 4
	gray_fill_sb.corner_radius_top_right = 4
	gray_fill_sb.corner_radius_bottom_right = 4
	gray_fill_sb.corner_radius_bottom_left = 4

	var shield_fill_sb = StyleBoxFlat.new()
	shield_fill_sb.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	shield_fill_sb.corner_radius_top_left = 4
	shield_fill_sb.corner_radius_top_right = 4
	shield_fill_sb.corner_radius_bottom_right = 4
	shield_fill_sb.corner_radius_bottom_left = 4

	# 1. Gray Health Progress Bar
	gray_health_bar = vp.get_node_or_null("GrayProgressBar") as ProgressBar
	if not gray_health_bar:
		gray_health_bar = ProgressBar.new()
		gray_health_bar.name = "GrayProgressBar"
		vp.add_child(gray_health_bar)
	
	gray_health_bar.custom_minimum_size = sz
	gray_health_bar.size = sz
	gray_health_bar.position = Vector2.ZERO
	gray_health_bar.show_percentage = false
	gray_health_bar.add_theme_stylebox_override("background", bg_sb)
	gray_health_bar.add_theme_stylebox_override("fill", gray_fill_sb)
	vp.move_child(gray_health_bar, 0)

	# 2. Shield Progress Bar
	shield_bar = vp.get_node_or_null("ShieldProgressBar") as ProgressBar
	if not shield_bar:
		shield_bar = ProgressBar.new()
		shield_bar.name = "ShieldProgressBar"
		vp.add_child(shield_bar)
	
	shield_bar.custom_minimum_size = sz
	shield_bar.size = sz
	shield_bar.position = Vector2.ZERO
	shield_bar.show_percentage = false
	shield_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	shield_bar.add_theme_stylebox_override("fill", shield_fill_sb)
	vp.move_child(shield_bar, 1)

	# 3. Main Health Progress Bar
	health_bar = vp.get_node_or_null("ProgressBar") as ProgressBar
	if not health_bar:
		health_bar = ProgressBar.new()
		health_bar.name = "ProgressBar"
		vp.add_child(health_bar)
	
	health_bar.custom_minimum_size = sz
	health_bar.size = sz
	health_bar.position = Vector2.ZERO
	health_bar.show_percentage = false
	health_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	vp.move_child(health_bar, 2)

func update_health_bar() -> void:
	var gh: float = 0.0
	if "gray_health" in self:
		gh = self.get("gray_health")
	
	var total_display_max = max(max_health, current_health + current_shield + gh)
	
	# Overhead 3D health bars
	if gray_health_bar:
		gray_health_bar.max_value = total_display_max
		gray_health_bar.value = current_health + current_shield + gh
	
	if shield_bar:
		shield_bar.max_value = total_display_max
		shield_bar.value = current_health + current_shield
	
	if health_bar:
		health_bar.max_value = total_display_max
		health_bar.value = current_health

	# Bottom-Left Large HUD Health & Mana Bars
	if hud and hud.has_method("update_health"):
		hud.update_health(current_health, max_health, current_shield, gh, armor_charges)
	if hud and hud.has_method("update_armor_charges"):
		hud.update_armor_charges(armor_charges, max_armor_charges)
	if hud and hud.has_method("update_mana"):
		hud.update_mana(current_mana, max_mana)

# --- Alive / Dead State & Respawn Lifecycle ---
func die() -> void:
	if is_multiplayer_match() and not multiplayer.is_server():
		return
	if is_dead:
		return
	is_dead = true
	cancel_channel()
	cleanse_cc()
	clear_buffered_ability()

	var current_time = Time.get_ticks_msec() / 1000.0
	var main_node = get_tree().current_scene if get_tree() else null
	if not main_node or not main_node.has_method("on_player_died"):
		main_node = get_tree().root.get_node_or_null("Main")

	# Notify all eligible attackers who damaged this player within the last 3.0s of takedown
	for attacker_id in recent_damage_dealers.keys():
		var damage_time = recent_damage_dealers[attacker_id]
		if current_time - damage_time <= 3.0:
			var attacker = null
			if main_node:
				var players_c = main_node.get_node_or_null("Players")
				if players_c:
					attacker = players_c.get_node_or_null(str(attacker_id))
			if attacker and attacker.has_method("_on_takedown"):
				attacker._on_takedown(self)

	var in_training = (main_node and main_node.get("is_training_mode") == true) if main_node else false

	if in_training:
		_update_death_state(true)
		get_tree().create_timer(0.6).timeout.connect(func():
			if is_instance_valid(self):
				respawn()
		)
		return

	var respawn_delay = -1.0
	if main_node and "game_mode" in main_node:
		var mode = GameModes.get_mode(main_node.game_mode)
		if mode and mode.respawn_delay > 0.0:
			respawn_delay = mode.respawn_delay

	if is_multiplayer_match():
		sync_death_state.rpc(true, respawn_delay)
	else:
		_update_death_state(true)
		respawn_countdown = respawn_delay
		if respawn_delay > 0.0:
			get_tree().create_timer(respawn_delay).timeout.connect(func():
				if is_instance_valid(self) and is_dead:
					respawn()
			)

	if main_node and main_node.has_method("on_player_died"):
		main_node.on_player_died(name.to_int())

@rpc("any_peer", "call_local", "reliable")
func sync_death_state(dead: bool, respawn_delay: float = -1.0) -> void:
	if not _is_sender_host():
		return
	is_dead = dead
	respawn_countdown = max(0.0, respawn_delay) if dead else 0.0
	_update_death_state(dead)

func _update_death_state(dead: bool) -> void:
	visible = not dead
	set_process_mode(PROCESS_MODE_INHERIT)
	if aim_line_root and is_instance_valid(aim_line_root):
		if dead:
			aim_line_root.hide()
		elif is_local_player():
			aim_line_root.show()

	var main_node = get_tree().root.get_node_or_null("Main")
	var in_training = (main_node and main_node.get("is_training_mode") == true) if main_node else false

	if dead:
		velocity = Vector3.ZERO
		knockback_velocity = Vector3.ZERO
		knockback_wall_stun = 0.0
		if is_local_player() or name == "1":
			if spectator_panel and not in_training:
				spectator_panel.visible = true
	else:
		if is_local_player() or name == "1":
			if spectator_panel:
				spectator_panel.visible = false

func respawn(target_spawn_pos: Vector3 = Vector3.ZERO) -> void:
	if is_multiplayer_match() and not multiplayer.is_server():
		return

	var spawn_pos = target_spawn_pos
	var main_node = get_tree().root.get_node_or_null("Main")
	var in_training = (main_node and main_node.get("is_training_mode") == true) if main_node else false

	if spawn_pos == Vector3.ZERO:
		if main_node and main_node.has_method("get_respawn_position"):
			spawn_pos = main_node.get_respawn_position(self)
		elif not in_training:
			var spawn_points = get_tree().root.get_node_or_null("Main/SpawnPoints")
			var candidate_spawns: Array[Vector3] = []
			if spawn_points:
				for team_node in spawn_points.get_children():
					for marker in team_node.get_children():
						if marker is Node3D:
							candidate_spawns.append(marker.global_position)
			if not candidate_spawns.is_empty():
				spawn_pos = candidate_spawns[randi() % candidate_spawns.size()]
			else:
				spawn_pos = Vector3(-24.0, 0.1, 0.0)
		elif main_node and main_node.get("training_selected_map") != null and main_node.get("training_selected_map") != -1:
			var t1_spawns = get_tree().root.get_node_or_null("Main/SpawnPoints/Team1_Spawns")
			if t1_spawns:
				var sp_center = t1_spawns.get_node_or_null("Spawn3")
				if sp_center:
					spawn_pos = sp_center.global_position
				elif t1_spawns.get_child_count() > 0:
					spawn_pos = t1_spawns.get_child(0).global_position
				else:
					spawn_pos = Vector3(-24.0, 0.1, 0.0)
			else:
				spawn_pos = Vector3(-24.0, 0.1, 0.0)
		else:
			spawn_pos = Vector3(-8.0, 0.1, 0.0)

	if is_multiplayer_match() and multiplayer.is_server():
		sync_respawn.rpc(spawn_pos)
	else:
		sync_respawn(spawn_pos)

@rpc("any_peer", "call_local", "reliable")
func sync_respawn(spawn_pos: Vector3) -> void:
	if not _is_sender_host():
		return
	is_dead = false
	current_health = max_health
	current_shield = 0.0
	current_mana = max_mana
	armor_charges = max_armor_charges
	cleanse_cc()
	cancel_channel()
	cancel_active_windup()
	clear_buffered_ability()
	recent_damage_dealers.clear()
	
	global_position = spawn_pos
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	knockback_wall_stun = 0.0
	spectate_target = null
	spectate_index = 0
	respawn_countdown = 0.0
	
	reset_physics_interpolation()
	if camera and is_instance_valid(camera):
		camera.reset_physics_interpolation()
		camera.global_position = spawn_pos + CAMERA_OFFSET
		camera.look_at(spawn_pos, Vector3.UP)
	
	_update_death_state(false)
	update_health_bar()
	
	if is_server_authoritative():
		apply_invulnerability(2.0)
	
	scale = Vector3(0.1, 0.1, 0.1)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# --- Spectator Processing ---
func _process_camera(_delta: float) -> void:
	if not camera:
		return
	camera.global_position = global_position + CAMERA_OFFSET
	camera.look_at(global_position, Vector3.UP)

func _process_spectator(delta: float) -> void:
	if respawn_countdown > 0.0:
		respawn_countdown = max(0.0, respawn_countdown - delta)

	if Input.is_action_just_pressed("spectate_next"):
		_cycle_spectate(1)
	elif Input.is_action_just_pressed("spectate_prev"):
		_cycle_spectate(-1)

	var target_to_watch = spectate_target
	if not target_to_watch or not is_instance_valid(target_to_watch) or target_to_watch.get("is_dead"):
		_cycle_spectate(1)
		target_to_watch = spectate_target

	var header_text = ""
	if respawn_countdown > 0.0:
		header_text = "⚔ RESPAWNING IN %.1fs ⚔\n" % respawn_countdown

	if target_to_watch and is_instance_valid(target_to_watch) and camera:
		camera.global_position = target_to_watch.global_position + CAMERA_OFFSET
		camera.look_at(target_to_watch.global_position, Vector3.UP)
		if spectator_label:
			var d_name = target_to_watch.get_display_name() if target_to_watch.has_method("get_display_name") else target_to_watch.get("character_name")
			spectator_label.text = "%sSPECTATING: %s (Player %s)\n[LMB / RMB to Cycle]" % [header_text, d_name, target_to_watch.name]
	elif spectator_label:
		if respawn_countdown > 0.0:
			spectator_label.text = "%s[Preparing Deployment]" % header_text
		else:
			spectator_label.text = "SPECTATING: None (All Players Eliminated)\n[LMB / RMB to Cycle]"

func _cycle_spectate(direction: int) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	var alive_players: Array = []
	for child in players_container.get_children():
		if child is Node3D and child.name != name and not child.get("is_dead"):
			alive_players.append(child)
	if alive_players.is_empty():
		spectate_target = null
		return
	spectate_index = (spectate_index + direction) % alive_players.size()
	if spectate_index < 0:
		spectate_index = alive_players.size() - 1
	spectate_target = alive_players[spectate_index]

# --- Universal HUD Updating ---
func _update_hud() -> void:
	if not hud or not hud.visible:
		return

	var status_text = ""
	if is_bound():
		status_text = "✦ BOUND (%.1fs) ✦" % bound_timer
	elif is_stunned():
		status_text = "✦ STUNNED (%.1fs) ✦" % stun_timer
	elif is_silenced():
		status_text = "✦ SILENCED (%.1fs) ✦" % silence_timer
	elif is_rooted():
		status_text = "✦ ROOTED (%.1fs) ✦" % root_timer
	elif is_grounded():
		status_text = "✦ GROUNDED (%.1fs) ✦" % grounded_timer
	elif is_crippled():
		status_text = "✦ CRIPPLED (%.1fs) ✦" % cripple_timer
	elif is_ethereal_active():
		status_text = "✦ ETHEREAL (%.1fs) ✦" % ethereal_timer
	elif is_slowed():
		status_text = "✦ SLOWED -%d%% (%.1fs) ✦" % [int(slow_percent * 100), slow_timer]
	elif speed_boost_timer > 0.0:
		status_text = "⚡ SPEED BOOST +%d%% (%.1fs) ⚡" % [int(speed_boost_percent * 100), speed_boost_timer]
	else:
		status_text = get_status_text()

	if hud and hud.has_method("set_status_text"):
		hud.set_status_text(status_text)
	if status_cc_label:
		status_cc_label.text = status_text

	_update_character_hud()

func _setup_hud_elements() -> void:
	if not hud:
		return
	if hud is PlayerHUD:
		slot_lmb = hud.slot_lmb
		slot_ability_one = hud.slot_rmb
		slot_dash = hud.slot_shift
		slot_ability_two = hud.slot_q
		slot_ability_three = hud.slot_e
		slot_ability_four = hud.slot_r
		status_cc_label = hud.status_cc_label
		spectator_panel = hud.spectator_panel
		spectator_label = hud.spectator_label
	else:
		slot_lmb = hud.get_node_or_null("HUDContainer/MainBar/AbilityBar/SlotLMB")
		slot_ability_one = hud.get_node_or_null("HUDContainer/MainBar/AbilityBar/SlotRMB")
		slot_dash = hud.get_node_or_null("HUDContainer/MainBar/AbilityBar/SlotShift")
		slot_ability_two = hud.get_node_or_null("HUDContainer/MainBar/AbilityBar/SlotQ")
		slot_ability_three = hud.get_node_or_null("HUDContainer/MainBar/AbilityBar/SlotE")
		slot_ability_four = hud.get_node_or_null("HUDContainer/MainBar/AbilityBar/SlotR")
		spectator_panel = hud.get_node_or_null("SpectatorPanel")
		spectator_label = hud.get_node_or_null("SpectatorPanel/VBox/SpectatorLabel")

	if not attack_performed.is_connected(_on_attack_performed_firing_visual):
		attack_performed.connect(_on_attack_performed_firing_visual)

	update_health_bar()

func _on_attack_performed_firing_visual(_attack_name: String) -> void:
	firing_indicator_timer = 0.15

# --- Local Aim Guide & Crosshair ---

func should_ability_have_indicator(ab: Variant) -> bool:
	if not ab:
		return false
	if "show_indicator" in ab and not ab.show_indicator:
		return false
	var eff = ab.get("effect_instance") if ab.get("effect_instance") != null else ab
	if eff and "show_indicator" in eff and not eff.show_indicator:
		return false
	var ab_id = str(ab.get("ability_id")).to_lower() if ab.get("ability_id") != null else ""
	if ab_id == "poke_sniper_stance" or ab_id == "poke_sniper":
		return false
	if ab.has_method("should_show_indicator"):
		return ab.should_show_indicator()
	var eff_name = eff.get("effect_name") if "effect_name" in eff else ""
	if eff_name != "Projectile" and not ("speed" in eff and eff.speed > 0.0 and "max_range" in eff and eff.max_range > 0.0):
		return true
	if ab.has_method("is_charge_ability") and ab.is_charge_ability():
		return true
	if ab.get("hold_to_charge") == true or (ab.get("charge_time") != null and ab.charge_time > 0.0):
		return true
	var custom_eff = str(eff.get("custom_effect_type")).to_lower() if eff.get("custom_effect_type") != null else ""
	if custom_eff == "mortar_shell" or ab_id.contains("mortar") or ab_id.contains("omen"):
		return true
	var rng = float(eff.get("max_range")) if eff.get("max_range") != null else 0.0
	if rng >= 35.0:
		return true
	return false

func _setup_local_aim_guide() -> void:
	if aim_line_root and is_instance_valid(aim_line_root):
		return
	if not is_local_player():
		return

	aim_line_root = Node3D.new()
	aim_line_root.name = "LocalAimGuide"
	aim_line_root.top_level = true
	add_child(aim_line_root)

	aim_line_mesh_inst = MeshInstance3D.new()
	aim_line_mesh_inst.name = "AimLaserLine"
	aim_line_mesh_inst.mesh = ImmediateMesh.new()
	aim_line_mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	aim_line_mat = StandardMaterial3D.new()
	aim_line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aim_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aim_line_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	aim_line_mat.vertex_color_use_as_albedo = true
	aim_line_mat.no_depth_test = true
	aim_line_mesh_inst.material_override = aim_line_mat
	aim_line_root.add_child(aim_line_mesh_inst)

	aim_crosshair_root = Node3D.new()
	aim_crosshair_root.name = "AimCrosshair"
	aim_line_root.add_child(aim_crosshair_root)

	var ch_mesh = _build_crosshair_mesh()
	aim_crosshair_root.add_child(ch_mesh)

	aim_line_root.hide()

func _build_crosshair_mesh() -> MeshInstance3D:
	var ch_inst = MeshInstance3D.new()
	ch_inst.name = "ReticleMesh"
	ch_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	
	var reticle_color = Color(0.2, 0.88, 1.0, 0.75)
	var center_color = Color(0.9, 0.98, 1.0, 0.90)

	# Cardinal cross ticks (North, South, East, West)
	var tick_inner = 0.20
	var tick_outer = 0.42
	st.set_color(reticle_color)
	st.add_vertex(Vector3(0, 0, -tick_inner))
	st.set_color(reticle_color)
	st.add_vertex(Vector3(0, 0, -tick_outer))

	st.set_color(reticle_color)
	st.add_vertex(Vector3(0, 0, tick_inner))
	st.set_color(reticle_color)
	st.add_vertex(Vector3(0, 0, tick_outer))

	st.set_color(reticle_color)
	st.add_vertex(Vector3(-tick_inner, 0, 0))
	st.set_color(reticle_color)
	st.add_vertex(Vector3(-tick_outer, 0, 0))

	st.set_color(reticle_color)
	st.add_vertex(Vector3(tick_inner, 0, 0))
	st.set_color(reticle_color)
	st.add_vertex(Vector3(tick_outer, 0, 0))

	# Outer reticle circle
	var segments = 24
	var ring_radius = 0.26
	for i in range(segments):
		var a0 = (float(i) / segments) * TAU
		var a1 = (float(i + 1) / segments) * TAU
		st.set_color(reticle_color)
		st.add_vertex(Vector3(cos(a0) * ring_radius, 0, sin(a0) * ring_radius))
		st.set_color(reticle_color)
		st.add_vertex(Vector3(cos(a1) * ring_radius, 0, sin(a1) * ring_radius))

	# Center cross pip
	var pip_len = 0.05
	st.set_color(center_color)
	st.add_vertex(Vector3(-pip_len, 0, 0))
	st.set_color(center_color)
	st.add_vertex(Vector3(pip_len, 0, 0))
	st.set_color(center_color)
	st.add_vertex(Vector3(0, 0, -pip_len))
	st.set_color(center_color)
	st.add_vertex(Vector3(0, 0, pip_len))

	var ch_mat = StandardMaterial3D.new()
	ch_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ch_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ch_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ch_mat.vertex_color_use_as_albedo = true
	ch_mat.no_depth_test = true

	ch_inst.mesh = st.commit()
	ch_inst.material_override = ch_mat
	return ch_inst

func _update_local_aim_guide(_delta: float) -> void:
	if not is_local_player():
		if aim_line_root and is_instance_valid(aim_line_root):
			aim_line_root.hide()
		return

	if not aim_line_root or not is_instance_valid(aim_line_root):
		_setup_local_aim_guide()
		if not aim_line_root:
			return

	if is_dead or not is_inside_tree() or not visible:
		aim_line_root.hide()
		return

	if not DisplayServer.window_is_focused():
		aim_line_root.hide()
		return

	var hit_pos = get_mouse_ground_intersection()
	if is_taunted():
		var taunter = get_taunt_target()
		if is_instance_valid(taunter):
			hit_pos = taunter.global_position

	if hit_pos == null:
		aim_line_root.hide()
		return

	aim_line_root.show()

	var start_pos = Vector3(global_position.x, global_position.y + 0.04, global_position.z)
	var end_pos = Vector3(hit_pos.x, global_position.y + 0.04, hit_pos.z)
	var to_target = end_pos - start_pos
	to_target.y = 0.0
	var dist = to_target.length()

	var im = aim_line_mesh_inst.mesh as ImmediateMesh
	if im:
		im.clear_surfaces()
		if dist > 0.35:
			var dir = to_target / dist
			var line_start = start_pos + dir * 0.45
			var line_end = end_pos
			var normal = Vector3(-dir.z, 0, dir.x).normalized()

			im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, aim_line_mat)

			# Outer glow ribbon (width ~0.07)
			var n_glow = normal * 0.035
			im.surface_set_color(Color(0.2, 0.85, 1.0, 0.30))
			im.surface_add_vertex(line_start - n_glow)
			im.surface_add_vertex(line_start + n_glow)
			im.surface_add_vertex(line_end + n_glow)
			im.surface_add_vertex(line_start - n_glow)
			im.surface_add_vertex(line_end + n_glow)
			im.surface_add_vertex(line_end - n_glow)

			# Inner bright laser core (width ~0.02)
			var n_core = normal * 0.010
			im.surface_set_color(Color(0.9, 0.98, 1.0, 0.85))
			im.surface_add_vertex(line_start - n_core)
			im.surface_add_vertex(line_start + n_core)
			im.surface_add_vertex(line_end + n_core)
			im.surface_add_vertex(line_start - n_core)
			im.surface_add_vertex(line_end + n_core)
			im.surface_add_vertex(line_end - n_core)

			im.surface_end()

	if aim_crosshair_root:
		aim_crosshair_root.global_position = end_pos

# --- Character Data & Ability Initialization ---
func load_character_data(data: CharacterData) -> void:
	if not data:
		return
	character_data = data
	character_name = data.character_name
	display_name = data.display_name if not data.display_name.is_empty() else data.character_name
	
	# Vitals & Defense
	base_max_health = data.max_health
	max_health = data.max_health
	current_health = data.max_health
	base_max_shield = data.max_shield
	max_shield = data.max_shield
	base_max_mana = data.max_mana
	max_mana = data.max_mana
	current_mana = data.max_mana
	if "mana_regen" in data:
		base_mana_regen = data.mana_regen
	
	# Combat stats
	if "crit_chance" in data:
		crit_chance = data.crit_chance
		base_crit_chance = data.crit_chance
	else:
		base_crit_chance = 0.0
	if "crit_multiplier" in data:
		crit_multiplier = data.crit_multiplier
		base_crit_multiplier = data.crit_multiplier
	else:
		base_crit_multiplier = AbilityPipeline.CRIT_DAMAGE_MULTIPLIER
	
	# Movement & Physics
	base_max_move_speed = data.max_move_speed
	max_move_speed = data.max_move_speed
	ground_acceleration = data.ground_acceleration
	base_ground_acceleration = data.ground_acceleration
	if "ground_deceleration" in data:
		ground_deceleration = data.ground_deceleration
	elif "ground_friction" in data:
		ground_deceleration = data.ground_friction
	if "intentional_movement_friction" in data:
		intentional_movement_friction = data.intentional_movement_friction
	air_acceleration = data.air_acceleration
	if "air_max_speed_mult" in data:
		air_max_speed_mult = data.air_max_speed_mult
	air_drag = data.air_drag
	jump_velocity = data.jump_velocity
	base_jump_velocity = data.jump_velocity
	if "jump_horizontal_impulse" in data:
		jump_horizontal_impulse = data.jump_horizontal_impulse
	
	# Visual Configuration (Heavy Lifting)
	_apply_character_visuals(data)
	
	# Ability Slots Instantiation & Registration (Heavy Lifting)
	_apply_character_ability_slots(data)

	_setup_abilities()
	apply_all_items()
	_setup_abilities_hud()
	update_health_bar()

func _apply_character_visuals(data: CharacterData) -> void:
	if not data:
		return
	
	# 1. Custom 3D Model Scene
	if "model_scene" in data and data.model_scene != null:
		var existing_model = get_node_or_null("CharacterModel")
		if existing_model:
			existing_model.queue_free()
		var model_inst = data.model_scene.instantiate()
		model_inst.name = "CharacterModel"
		add_child(model_inst)
		var default_mesh = get_node_or_null("MeshInstance3D") as MeshInstance3D
		if default_mesh:
			default_mesh.visible = false
	else:
		# 2. Capsule color override
		var default_mesh = get_node_or_null("MeshInstance3D") as MeshInstance3D
		if default_mesh and "body_color" in data:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = data.body_color
			default_mesh.material_override = mat
	
	# 3. Nose / Accent color override
	var nose_mesh = get_node_or_null("FacingIndicator") as MeshInstance3D
	if nose_mesh and "accent_color" in data:
		var accent_mat = StandardMaterial3D.new()
		accent_mat.albedo_color = data.accent_color
		nose_mesh.material_override = accent_mat
	
	# 4. Capsule dimensions
	if "capsule_radius" in data and "capsule_height" in data and data.capsule_radius > 0 and data.capsule_height > 0:
		var col = get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col and col.shape is CapsuleShape3D:
			col.shape.radius = data.capsule_radius
			col.shape.height = data.capsule_height
		var default_mesh = get_node_or_null("MeshInstance3D") as MeshInstance3D
		if default_mesh and default_mesh.mesh is CapsuleMesh:
			default_mesh.mesh.radius = data.capsule_radius
			default_mesh.mesh.height = data.capsule_height

	# 5. Camera Offset
	if "custom_camera_offset" in data and data.custom_camera_offset != Vector3.ZERO:
		if is_local_player() and camera:
			camera.global_position = global_position + data.custom_camera_offset

func _apply_character_ability_slots(data: CharacterData) -> void:
	if not data:
		return
	
	# Ensure Abilities container exists
	var abilities_container = get_node_or_null("Abilities")
	if not abilities_container:
		abilities_container = Node.new()
		abilities_container.name = "Abilities"
		add_child(abilities_container)
	
	var slotted_abs = data.get_all_slotted_abilities() if data.has_method("get_all_slotted_abilities") else {}
	if slotted_abs.is_empty() and "abilities" in data:
		slotted_abs = data.abilities.duplicate()
	
	for slot_key in ["LMB", "RMB", "SHIFT", "Q", "E", "R", "PASSIVE"]:
		var ab_source = data.get_ability_for_slot(slot_key) if data.has_method("get_ability_for_slot") else slotted_abs.get(slot_key)
		if ab_source == null:
			continue
		
		# If an ability already exists under this slot, remove/replace it if different
		var existing = abilities.get(slot_key)
		if existing and is_instance_valid(existing):
			if ab_source is Object and existing == ab_source:
				continue
			# If the existing node came from the scene and has identical path, keep it
			if ab_source is PackedScene and existing.scene_file_path == ab_source.resource_path:
				continue
			if ab_source is String and existing.scene_file_path == ab_source:
				continue
			abilities.erase(slot_key)
			if existing.get_parent():
				existing.get_parent().remove_child(existing)
				existing.queue_free()
		
		# Instantiate or reference the ability
		var inst: AbilityClass = null
		if ab_source is PackedScene:
			inst = ab_source.instantiate() as AbilityClass
		elif ab_source is String and ResourceLoader.exists(ab_source):
			var sc = load(ab_source) as PackedScene
			if sc:
				inst = sc.instantiate() as AbilityClass
		elif ab_source is AbilityClass:
			inst = ab_source
		
		if inst:
			inst.name = slot_key
			inst.slot_key = slot_key
			if inst.get_parent() != abilities_container:
				if inst.get_parent():
					inst.get_parent().remove_child(inst)
				abilities_container.add_child(inst)
			abilities[slot_key] = inst
			if not inst.ability_id.is_empty():
				abilities[inst.ability_id] = inst

# --- Inventory & Item Management ---
func get_item_stat(stat_name: String, default_val: float = 0.0) -> float:
	return item_stats.get(stat_name, default_val)

func has_item_stat(stat_name: String) -> bool:
	return item_stats.has(stat_name)

func get_all_item_stats() -> Dictionary:
	return item_stats.duplicate()

func get_cooldown_multiplier() -> float:
	var cdr = get_item_stat("cooldown_reduction") + get_item_stat("cdr")
	if cdr > 0.0:
		return clamp(1.0 - (cdr / 100.0), 0.1, 1.0)
	var haste = get_item_stat("ability_haste") + get_item_stat("haste")
	if haste > 0.0:
		return 100.0 / (100.0 + haste)
	return 1.0

func apply_all_items() -> void:
	item_damage_percent = 0.0
	item_health_bonus = 0.0
	item_move_speed_bonus = 0.0
	item_stats.clear()
	
	# Clean up previous item ability nodes from scene tree and ability registry
	for node in item_ability_nodes:
		if is_instance_valid(node):
			if node is AbilityClass:
				if not node.slot_key.is_empty() and abilities.get(node.slot_key) == node:
					abilities.erase(node.slot_key)
				if not node.ability_id.is_empty() and abilities.get(node.ability_id) == node:
					abilities.erase(node.ability_id)
				if node.active_indicator and is_instance_valid(node.active_indicator):
					node.active_indicator.queue_free()
			if node.get_parent():
				node.get_parent().remove_child(node)
			node.queue_free()
	item_ability_nodes.clear()

	var item_container = get_node_or_null("ItemAbilities")
	if not item_container:
		item_container = Node.new()
		item_container.name = "ItemAbilities"
		add_child(item_container)
	
	for item_id in item_slots:
		var item_def = ItemPipeline.get_item(item_id)
		if not item_def:
			continue
		
		# Aggregate all arbitrary stats directly from item
		for stat_key in item_def.stats:
			var val = float(item_def.stats[stat_key])
			item_stats[stat_key] = item_stats.get(stat_key, 0.0) + val
		
		# Instance unique feature ability into the scene tree
		if item_def.has_unique_feature():
			var ab_node = item_def.instantiate_ability()
			if ab_node:
				item_container.add_child(ab_node)
				item_ability_nodes.append(ab_node)
				if ab_node is AbilityClass:
					ab_node.setup()
					if not ab_node.ability_id.is_empty():
						abilities[ab_node.ability_id] = ab_node
					if not ab_node.slot_key.is_empty():
						abilities[ab_node.slot_key] = ab_node
					if is_local_player() and ab_node.hitbox and not ab_node.cast_on_press and not ab_node.active_indicator:
						if should_ability_have_indicator(ab_node):
							ab_node.active_indicator = ab_node.hitbox.create_indicator()
							if ab_node.active_indicator:
								ab_node.active_indicator.top_level = true
								if is_inside_tree() and get_tree() and get_tree().root:
									get_tree().root.call_deferred("add_child", ab_node.active_indicator)
								ab_node.active_indicator.hide()
	
	# Apply arbitrary stats to core player parameters
	item_damage_percent = get_item_stat("damage_percent") + get_item_stat("damage") + get_item_stat("attack_damage") + get_item_stat("all_damage")
	item_health_bonus = get_item_stat("max_health") + get_item_stat("health")
	item_move_speed_bonus = get_item_stat("move_speed") + get_item_stat("speed")

	# Maximum Health
	var old_max_hp = max_health
	max_health = base_max_health + item_health_bonus
	if max_health > old_max_hp:
		current_health += (max_health - old_max_hp)
	else:
		current_health = min(current_health, max_health)

	# Movement Speed
	max_move_speed = base_max_move_speed + item_move_speed_bonus

	# Critical Strike
	var bonus_crit_chance = get_item_stat("crit_chance") + get_item_stat("critical_chance")
	if bonus_crit_chance > 1.0:
		bonus_crit_chance /= 100.0
	crit_chance = base_crit_chance + bonus_crit_chance

	var bonus_crit_mult = get_item_stat("crit_multiplier")
	if bonus_crit_mult == 0.0 and (has_item_stat("crit_damage") or has_item_stat("critical_damage")):
		var raw_cd = get_item_stat("crit_damage") + get_item_stat("critical_damage")
		bonus_crit_mult = (raw_cd / 100.0) if raw_cd > 1.0 else raw_cd
	crit_multiplier = base_crit_multiplier + bonus_crit_mult

	# Maximum Shield
	var bonus_shield = get_item_stat("max_shield") + get_item_stat("shield")
	max_shield = base_max_shield + bonus_shield

	# Jump Velocity
	var bonus_jump = get_item_stat("jump_velocity") + get_item_stat("jump_height")
	jump_velocity = base_jump_velocity + bonus_jump

	# Ground Acceleration
	var bonus_accel = get_item_stat("ground_acceleration") + get_item_stat("acceleration")
	ground_acceleration = base_ground_acceleration + bonus_accel

	# Mana Capacity
	var bonus_mana = get_item_stat("max_mana") + get_item_stat("mana")
	max_mana = base_max_mana + bonus_mana
	current_mana = min(current_mana, max_mana)

	update_health_bar()

func get_damage_multiplier() -> float:
	return 1.0 + (item_damage_percent / 100.0)

func buy_item(item_id: String) -> bool:
	if is_multiplayer_match() and not multiplayer.is_server():
		request_buy_item.rpc_id(1, item_id)
		return false
	
	var item = ItemPipeline.get_item(item_id)
	if not item:
		return false
	if item_slots.size() >= max_item_slots:
		return false

	var main_node = get_tree().root.get_node_or_null("Main")
	var in_training = (main_node and main_node.get("is_training_mode") == true) or not is_multiplayer_match()
	
	if not in_training and gold < item.cost:
		return false
	
	if not in_training:
		gold -= item.cost
	item_slots.append(item_id)
	apply_all_items()
	
	if main_node and main_node.get("connected_players") != null:
		var pid = name.to_int()
		if main_node.connected_players.has(pid):
			main_node.connected_players[pid]["gold"] = gold
			main_node.connected_players[pid]["items"] = item_slots.duplicate()
	
	if is_multiplayer_match() and multiplayer.is_server():
		sync_inventory.rpc(item_slots, gold)
	elif main_node and main_node.has_method("_refresh_shop_ui"):
		main_node._refresh_shop_ui()
	return true

func sell_item(item_id: String) -> bool:
	if is_multiplayer_match() and not multiplayer.is_server():
		request_sell_item.rpc_id(1, item_id)
		return false
	
	var idx = item_slots.find(item_id)
	if idx == -1:
		return false
	
	var main_node = get_tree().root.get_node_or_null("Main")
	var in_training = (main_node and main_node.get("is_training_mode") == true) or not is_multiplayer_match()
	
	var item = ItemPipeline.get_item(item_id)
	var refund = int(item.cost * 0.5) if item else 50
	if not in_training:
		gold += refund
	item_slots.remove_at(idx)
	apply_all_items()
	
	if main_node and main_node.get("connected_players") != null:
		var pid = name.to_int()
		if main_node.connected_players.has(pid):
			main_node.connected_players[pid]["gold"] = gold
			main_node.connected_players[pid]["items"] = item_slots.duplicate()
			
	if is_multiplayer_match() and multiplayer.is_server():
		sync_inventory.rpc(item_slots, gold)
	elif main_node and main_node.has_method("_refresh_shop_ui"):
		main_node._refresh_shop_ui()
	return true

@rpc("any_peer", "call_remote", "reliable")
func request_buy_item(item_id: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	if str(name) != str(sender_id):
		return
	buy_item(item_id)

@rpc("any_peer", "call_remote", "reliable")
func request_sell_item(item_id: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	if str(name) != str(sender_id):
		return
	sell_item(item_id)

@rpc("any_peer", "call_local", "reliable")
func sync_inventory(items_arr: Array, gold_val: int) -> void:
	if not _is_sender_host():
		return
	item_slots.clear()
	for it in items_arr:
		item_slots.append(str(it))
	gold = gold_val
	apply_all_items()
	
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node:
		var pid = name.to_int()
		if main_node.get("connected_players") != null and main_node.connected_players.has(pid):
			main_node.connected_players[pid]["gold"] = gold
			main_node.connected_players[pid]["items"] = item_slots.duplicate()
		if main_node.has_method("_refresh_shop_ui"):
			main_node._refresh_shop_ui()

# --- Critical Strike Helpers ---
func roll_critical_hit(bonus_chance: float = 0.0) -> bool:
	return AbilityPipeline.roll_crit(crit_chance + bonus_chance)

func calculate_outgoing_damage(base_damage: float, can_crit: bool = true, bonus_crit_chance: float = 0.0, custom_crit_multiplier: float = -1.0) -> Dictionary:
	var scaled_base = base_damage * get_damage_multiplier()
	if not can_crit:
		return {"damage": scaled_base, "is_crit": false, "multiplier": 1.0}
	var mult = crit_multiplier if custom_crit_multiplier <= 0.0 else custom_crit_multiplier
	return AbilityPipeline.apply_crit(scaled_base, crit_chance + bonus_crit_chance, mult)

func get_ability(slot_or_id: String) -> RefCounted:
	if abilities.has(slot_or_id):
		return abilities[slot_or_id]
	if ability_slots.has(slot_or_id):
		var id_val = ability_slots[slot_or_id]
		return abilities.get(id_val)
	return null

# --- Ability Registers, Buffering & Lockout Logic ---
func is_in_cast_lockout() -> bool:
	if cast_lockout_timer > 0.0 or is_channeling:
		return true
	if active_windup_id != "":
		var ab = get_ability_for_slot(active_windup_id)
		if ab and ("cast_lockout" in ab) and ab.cast_lockout:
			return true
	return false

func is_in_move_lockout() -> bool:
	if move_lockout_timer > 0.0:
		return true
	if active_windup_id != "":
		var ab = get_ability_for_slot(active_windup_id)
		if ab and ("move_lockout" in ab) and ab.move_lockout:
			return true
	return false

func is_in_ability_lockout() -> bool:
	return is_in_cast_lockout()

func trigger_cast_lockout(duration: float, ability_id: String = "") -> void:
	cast_lockout_timer = max(cast_lockout_timer, duration)
	current_cast_lockout_ability_id = ability_id

func trigger_move_lockout(duration: float, ability_id: String = "") -> void:
	move_lockout_timer = max(move_lockout_timer, duration)
	current_move_lockout_ability_id = ability_id

func trigger_ability_lockout(duration: float, ability_id: String = "") -> void:
	trigger_cast_lockout(duration, ability_id)

func get_remaining_action_time() -> float:
	var rem: float = 0.0
	if cast_lockout_timer > 0.0:
		rem = max(rem, cast_lockout_timer)
	if is_channeling and channel_timer > 0.0:
		rem = max(rem, channel_timer)
	return rem

func buffer_ability(slot_key: String) -> void:
	if is_dead or is_stunned() or is_bound():
		return
	var eff_slot = get_effective_slot(slot_key)
	var ab = get_ability_for_slot(eff_slot)
	if ab is AbilityClass:
		var cost = ab.get_mana_cost(self)
		if cost > 0.0 and not has_mana(cost):
			return
	var src = AbilityBuffer.ActionSource.CHANNEL if is_channeling else (AbilityBuffer.ActionSource.LOCKOUT if is_in_cast_lockout() else AbilityBuffer.ActionSource.NONE)
	var rem_time = get_remaining_action_time()
	ability_buffer.buffer_ability(eff_slot, rem_time, src, ABILITY_BUFFER_WINDOW)

func execute_ability_slot(slot_key: String) -> bool:
	return try_cast_ability(slot_key)

func _try_resolve_buffered_ability() -> void:
	if not has_buffered_ability() or is_dead or is_stunned() or is_bound() or is_in_cast_lockout():
		return
	var slot_to_execute = ability_buffer.pop_buffered_ability()
	execute_ability_slot(slot_to_execute)

func can_cast_ability_slot(slot_key: String, char_abilities: Dictionary = {}) -> bool:
	if is_dead:
		return false
	var source_abilities = char_abilities if not char_abilities.is_empty() else abilities
	var eff_slot = get_effective_slot(slot_key)
	var def = source_abilities.get(eff_slot)
	if not def and ability_slots.has(eff_slot):
		def = source_abilities.get(ability_slots[eff_slot])
	if def is AbilityClass:
		var cost = def.get_mana_cost(self)
		if cost > 0.0 and not has_mana(cost):
			return false
		return def.can_cast(self)
	if is_stunned() or is_bound():
		if def and "can_cast_while_stunned" in def and def.can_cast_while_stunned:
			return true
		return false
	if is_channeling:
		return false
	if not is_in_cast_lockout():
		return true
	if def and ("bypass_lockout" in def) and def.bypass_lockout:
		return true
	if def and "can_cast_during_lockout" in def and def.can_cast_during_lockout:
		return true
	return false

func start_ability_cast(slot_key: String, char_abilities: Dictionary = {}, custom_lockout: float = 0.0) -> void:
	var source_abilities = char_abilities if not char_abilities.is_empty() else abilities
	var def = source_abilities.get(slot_key)
	if not def and ability_slots.has(slot_key):
		def = source_abilities.get(ability_slots[slot_key])
	var l_time = custom_lockout
	var ability_id = slot_key
	if def:
		ability_id = def.id
		if l_time <= 0.0 and def.is_lockout:
			l_time = def.get_lockout_time()
	if l_time > 0.0:
		var should_cast_lock = def.cast_lockout if (def and "cast_lockout" in def) else true
		var should_move_lock = def.move_lockout if (def and "move_lockout" in def) else false
		if should_cast_lock:
			trigger_cast_lockout(l_time, ability_id)
		if should_move_lock:
			trigger_move_lockout(l_time, ability_id)

# --- Systemic Ability Hitbox & Delayed Telegraph Pipeline ---
func show_ability_telegraph(ability_def: Variant, origin: Vector3, facing_dir: Vector3, delay: float, target_pos: Vector3 = Vector3.ZERO) -> Node3D:
	if not ability_def:
		return null
	var ab: AbilityClass = null
	if ability_def is String:
		ab = abilities.get(ability_def) as AbilityClass
	elif ability_def is AbilityClass:
		ab = ability_def

	if not ab or not ab.has_hitbox():
		return null

	var hb = ab.get_hitbox() if ab.has_method("get_hitbox") else ab.hitbox
	if not hb:
		return null

	var ind = AbilityIndicator.create_telegraph_indicator(hb)
	if not ind:
		return null

	var follows_caster = false
	if "follow_caster" in ab and ab.follow_caster:
		follows_caster = true
	elif ab.effect_instance and "follow_caster" in ab.effect_instance and ab.effect_instance.follow_caster:
		follows_caster = true
	elif ab.effect_instance and ab.effect_instance is MeleeStrikeEffect:
		follows_caster = true

	var hb_shape = hb.shape_type if (hb and "shape_type" in hb) else -1
	var hb_angle = hb.angle_deg if (hb and "angle_deg" in hb) else 360.0

	var is_ground_targeted = false
	if target_pos != Vector3.ZERO:
		var eff_name = ""
		if "effect_name" in ab: eff_name = ab.effect_name
		elif ab.effect_instance and "effect_name" in ab.effect_instance: eff_name = ab.effect_instance.effect_name
		if eff_name in ["AerialCrash", "AreaZone"] or hb_shape == AbilityPipeline.HitboxShape.CYLINDER or (hb_shape == AbilityPipeline.HitboxShape.CIRCLE and hb_angle >= 360.0):
			is_ground_targeted = true

	var spawn_pos = target_pos if is_ground_targeted else global_position

	if follows_caster and not is_ground_targeted:
		ind.top_level = false
		add_child(ind)
		ind.position = Vector3(0, 0.06, 0)
		ind.rotation = Vector3.ZERO
	else:
		ind.top_level = true
		get_tree().root.add_child(ind)
		ind.global_position = Vector3(spawn_pos.x, 0.06, spawn_pos.z)
		if facing_dir.length_squared() > 0.001 and (not is_ground_targeted or hb_angle < 360.0):
			var target = spawn_pos + facing_dir
			ind.look_at(Vector3(target.x, ind.global_position.y, target.z), Vector3.UP)
			ind.rotation.x = 0.0
			ind.rotation.z = 0.0

	ind.show()

	if delay > 0.0:
		AbilityIndicator.animate_telegraph_fill(ind, delay, get_tree())
		get_tree().create_timer(delay).timeout.connect(func():
			if is_instance_valid(ind):
				AbilityIndicator.flash_and_fade(ind, get_tree(), 0.15)
				get_tree().create_timer(0.20).timeout.connect(func():
					if is_instance_valid(ind):
						ind.queue_free()
				)
		)
	else:
		AbilityIndicator.flash_and_fade(ind, get_tree(), 0.15)
		get_tree().create_timer(0.20).timeout.connect(func():
			if is_instance_valid(ind):
				ind.queue_free()
		)
	return ind

func start_windup_cast(slot_key: String, origin: Vector3, direction: Vector3, target_pos: Vector3, delay: float, charge_ratio: float = 0.0) -> void:
	var ab = abilities.get(slot_key) as AbilityClass
	if not ab:
		return

	if ab.active_indicator and is_instance_valid(ab.active_indicator):
		ab.active_indicator.hide()

	ab.consume_resources(self)
	ab.start_windup(delay)

	if ab.telegraph and ab.active_telegraph == null:
		var ind = show_ability_telegraph(ab, origin, direction, delay, target_pos)
		ab.active_telegraph = ind

	active_windup_facing = direction
	active_windup_id = slot_key
	is_channeling = true
	if ("cast_lockout" not in ab) or ab.cast_lockout:
		trigger_cast_lockout(delay, ab.id)
	if ("move_lockout" in ab) and ab.move_lockout:
		trigger_move_lockout(delay, ab.id)

	if is_multiplayer_match():
		sync_ability_windup.rpc(slot_key, origin, direction, target_pos, delay, charge_ratio)

	get_tree().create_timer(delay).timeout.connect(func():
		if not is_instance_valid(self) or is_dead:
			is_channeling = false
			return
		if is_stunned() or is_bound() or is_silenced():
			is_channeling = false
			cancel_active_windup()
			return
		is_channeling = false
		if ab.is_winding_up:
			ab.is_winding_up = false
			if active_windup_id == slot_key:
				active_windup_id = ""
			ab.active_telegraph = null
			ab.execute_server(self, origin, direction, target_pos, charge_ratio)
			if is_multiplayer_match():
				sync_cast_ability.rpc(slot_key, origin, direction, target_pos, charge_ratio)
	)

func cancel_active_windup() -> void:
	is_channeling = false
	if active_windup_id != "":
		var ab = abilities.get(active_windup_id) as AbilityClass
		if ab:
			if ab.active_telegraph and is_instance_valid(ab.active_telegraph):
				ab.active_telegraph.queue_free()
				ab.active_telegraph = null
			ab.cancel_windup()
		active_windup_id = ""
		if is_server_authoritative() and is_multiplayer_match():
			sync_cancel_windup.rpc()

@rpc("any_peer", "call_remote", "reliable")
func sync_cancel_windup() -> void:
	is_channeling = false
	if active_windup_id != "":
		var ab = abilities.get(active_windup_id) as AbilityClass
		if ab:
			ab.cancel_windup()
		active_windup_id = ""

func start_ability_windup(ability_id: String, facing_dir: Vector3 = Vector3.ZERO) -> void:
	var ab = abilities.get(ability_id) as AbilityClass
	if ab and ab.get_windup_time() > 0.0:
		var facing = facing_dir if facing_dir != Vector3.ZERO else -global_transform.basis.z.normalized()
		start_windup_cast(ability_id, global_position, facing, global_position, ab.get_windup_time(), 0.0)

func _on_windup_id_changed(ability_id: String) -> void:
	var ab = abilities.get(ability_id) as AbilityClass
	if ab and ab.has_hitbox():
		var delay = ab.get_windup_time()
		if delay > 0.0 and ab.telegraph and ab.active_telegraph == null:
			ab.active_telegraph = show_ability_telegraph(ab, global_position, active_windup_facing, delay)
			if is_multiplayer_authority():
				get_tree().create_timer(delay).timeout.connect(func():
					if active_windup_id == ability_id:
						active_windup_id = ""
				)

@rpc("any_peer", "call_remote", "reliable")
func sync_ability_windup(slot_key: String, origin: Vector3, direction: Vector3, target_pos: Vector3, delay: float, _charge_ratio: float = 0.0) -> void:
	var ab = abilities.get(slot_key) as AbilityClass
	if not ab:
		return
	ab.start_windup(delay)
	if ab.telegraph and ab.active_telegraph == null:
		var ind = show_ability_telegraph(ab, origin, direction, delay, target_pos)
		ab.active_telegraph = ind
	active_windup_facing = direction
	active_windup_id = slot_key
	is_channeling = true
	if ("cast_lockout" not in ab) or ab.cast_lockout:
		trigger_cast_lockout(delay, ab.id)
	if ("move_lockout" in ab) and ab.move_lockout:
		trigger_move_lockout(delay, ab.id)

func trigger_ability_hitbox(ability_key_or_id: String, origin: Vector3 = Vector3.ZERO, facing_dir: Vector3 = Vector3.ZERO) -> void:
	var ab = abilities.get(ability_key_or_id) as AbilityClass
	if not ab or not ab.has_hitbox():
		return
	
	var cast_origin = origin if origin != Vector3.ZERO else global_position
	var cast_facing = facing_dir if facing_dir != Vector3.ZERO else -global_transform.basis.z.normalized()
	cast_facing.y = 0.0
	if cast_facing.length_squared() > 0.001:
		cast_facing = cast_facing.normalized()
	else:
		cast_facing = -global_transform.basis.z.normalized()
	
	show_ability_telegraph(ab, cast_origin, cast_facing, 0.0)
	if is_multiplayer_match() and (is_multiplayer_authority() or multiplayer.is_server()):
		sync_trigger_hitbox.rpc(ability_key_or_id, cast_origin, cast_facing)

@rpc("any_peer", "call_remote", "reliable")
func sync_trigger_hitbox(ability_key_or_id: String, origin: Vector3, facing: Vector3) -> void:
	var ab = abilities.get(ability_key_or_id) as AbilityClass
	if ab and ab.has_hitbox():
		show_ability_telegraph(ab, origin, facing, 0.0)

# --- Virtual Methods for Character Kit Extension ---
func _setup_character_kit() -> void:
	pass

func _process_character_kit(_delta: float) -> void:
	pass

func _handle_character_input(_delta: float) -> void:
	pass

func _update_character_hud() -> void:
	pass

func get_status_text() -> String:
	return ""

func _on_damage_taken_hook(_amount: float, _attacker_id: int, _action_type: int) -> void:
	pass

func _on_character_damage_dealt(_target: Node, _amount: float, _action_type: int) -> void:
	pass

func character_handles_slot(_slot_key: String) -> bool:
	return false

func get_effective_max_speed(current_speed: float) -> float:
	if is_in_move_lockout():
		return 0.0
	var mult = 1.0
	for slot_key in abilities:
		var ab = abilities[slot_key]
		if ab is AbilityClass:
			if ab.is_charging:
				mult = min(mult, ab.charge_move_speed_multiplier)
			if ab.is_winding_up:
				if ("move_lockout" in ab) and ab.move_lockout:
					return 0.0
				mult = min(mult, ab.windup_move_speed_multiplier)
	return current_speed * mult

func _exit_tree() -> void:
	if aim_line_root and is_instance_valid(aim_line_root):
		aim_line_root.queue_free()
		aim_line_root = null
	for slot_key in abilities:
		var ab = abilities[slot_key]
		if ab is AbilityClass and ab.active_indicator and is_instance_valid(ab.active_indicator):
			ab.active_indicator.queue_free()

# --- Universal Ability System & Lightweight RPCs ---

func _setup_abilities() -> void:
	var prop_slots = {
		"LMB": ability_lmb,
		"RMB": ability_rmb,
		"SHIFT": ability_shift,
		"Q": ability_q,
		"E": ability_e,
		"R": ability_r
	}
	for slot_key in prop_slots:
		var scene = prop_slots[slot_key]
		if scene != null and not abilities.has(slot_key):
			var inst = scene.instantiate() as AbilityClass
			if inst:
				inst.slot_key = slot_key
				add_child(inst)
				abilities[slot_key] = inst

	var abilities_node = get_node_or_null("Abilities")
	var children_to_check = abilities_node.get_children() if abilities_node else get_children()
	for child in children_to_check:
		if child is AbilityClass and not child.slot_key.is_empty():
			abilities[child.slot_key] = child

	for slot_key in abilities:
		var ab = abilities[slot_key]
		if ab is AbilityClass:
			ab.setup()
			if is_local_player() and ab.hitbox and not ab.cast_on_press and not ab.active_indicator:
				if should_ability_have_indicator(ab):
					ab.active_indicator = ab.hitbox.create_indicator()
					if ab.active_indicator:
						ab.active_indicator.top_level = true
						if is_inside_tree() and get_tree() and get_tree().root:
							get_tree().root.call_deferred("add_child", ab.active_indicator)
						ab.active_indicator.hide()

	_setup_abilities_hud()

func _setup_abilities_hud() -> void:
	if not hud or not hud.has_method("setup_character_ui"):
		return
	var ui_configs = {}
	for slot_key in ["LMB", "RMB", "SHIFT", "Q", "E", "R"]:
		var ab = abilities.get(slot_key)
		if ab is AbilityClass:
			if ab.has_method("get_ui_config"):
				ui_configs[slot_key] = ab.get_ui_config()
			else:
				ui_configs[slot_key] = {
					"name": ab.name_text,
					"description": ab.description,
					"stats": "Cooldown: %.1fs" % ab.cooldown,
					"icon": ab.icon_symbol if not ab.icon_symbol.is_empty() else ab.icon_texture
				}
	hud.setup_character_ui(get_display_name(), ui_configs)

func _process_abilities_lifecycle(delta: float) -> void:
	for slot_key in abilities:
		var ab = abilities[slot_key]
		if ab is AbilityClass:
			ab.process_lifecycle(delta)

	if is_local_player() and hud and hud.has_method("update_ability_cooldown"):
		for slot_key in abilities:
			var ab = abilities[slot_key]
			if ab is AbilityClass:
				var is_dis = not ab.can_cast(self)
				var custom_text = ""
				if ab.is_charging:
					custom_text = "%d%%" % int(ab.get_charge_ratio() * 100.0)
				elif ab.is_winding_up:
					custom_text = "CAST"
				hud.update_ability_cooldown(
					slot_key,
					ab.current_cooldown,
					ab.cooldown,
					ab.current_charges,
					ab.max_charges,
					is_dis,
					custom_text
				)

func _process_abilities_input(delta: float) -> void:
	if is_dead or is_stunned() or is_bound() or is_silenced():
		cancel_active_windup()
		if not active_modal_slot.is_empty():
			cancel_active_modal()
		for slot_key in abilities:
			var ab = abilities[slot_key]
			if ab is AbilityClass:
				if ab.active_indicator:
					ab.active_indicator.hide()
				ab.is_holding = false
				ab.stop_charging()
				ab.cancel_windup()
		return

	if not active_modal_slot.is_empty() and Input.is_action_just_pressed("ui_cancel"):
		cancel_active_modal()
		return

	var slot_action_map = {
		"LMB": "shoot",
		"RMB": "ability_one",
		"SHIFT": "dash",
		"Q": "ability_two",
		"E": "ability_three",
		"R": "ability_four"
	}

	var hit_pos = get_mouse_ground_intersection()

	for slot_key in slot_action_map:
		if character_handles_slot(slot_key):
			continue
		var action_name = slot_action_map[slot_key]
		var ab = get_ability_for_slot(slot_key)
		if not (ab is AbilityClass):
			continue
		var effective_slot = get_effective_slot(slot_key)
		var cost = ab.get_mana_cost(self)
		var out_of_mana = (cost > 0.0 and not has_mana(cost))

		if ab.is_holding and ab.active_indicator and hit_pos != null:
			if should_ability_have_indicator(ab):
				var origin = global_position
				var facing = (Vector3(hit_pos.x, origin.y, hit_pos.z) - origin).normalized()
				if ab.hitbox:
					ab.hitbox.update_indicator(ab.active_indicator, origin, facing)
			else:
				ab.active_indicator.hide()

		if ab.has_ui_modal():
			var modal_cfg = ab.ui_modal
			var is_hold = (modal_cfg.interaction_mode == AbilityPipeline.ModalInteractionMode.HOLD_AND_RELEASE)
			if is_hold:
				if Input.is_action_just_pressed(action_name):
					if is_transformed and slot_key == "Q":
						# Recasting Q while transformed breaks transformation
						break_transformation()
					elif out_of_mana:
						pass
					elif ab.can_cast(self):
						open_ability_modal(slot_key, ab)
					else:
						buffer_ability(effective_slot)

				if Input.is_action_just_released(action_name) and active_modal_slot == slot_key:
					close_and_resolve_modal(slot_key, ab)
			else:
				# TOGGLE_AND_CLICK
				if Input.is_action_just_pressed(action_name):
					if active_modal_slot == slot_key:
						cancel_active_modal()
					elif not out_of_mana and ab.can_cast(self):
						open_ability_modal(slot_key, ab)

		elif ab.is_charge_ability():
			if Input.is_action_just_pressed(action_name):
				if out_of_mana:
					pass # Cannot input without mana: cannot charge while mana is regenerating, do not buffer
				elif ab.can_cast(self):
					ab.start_charging(self)
					ab.is_holding = true
					if ab.active_indicator and should_ability_have_indicator(ab):
						ab.active_indicator.show()
				else:
					buffer_ability(effective_slot)

			if ab.is_charging:
				if out_of_mana:
					ab.is_holding = false
					if ab.active_indicator:
						ab.active_indicator.hide()
					ab.stop_charging()
				elif Input.is_action_pressed(action_name):
					ab.process_charge(delta, self)
					if ab.auto_release_on_max_charge and ab.get_charge_ratio() >= 1.0:
						var ratio = ab.get_charge_ratio()
						ab.is_holding = false
						if ab.active_indicator:
							ab.active_indicator.hide()
						try_cast_ability(effective_slot, ratio)
						ab.stop_charging()

			if Input.is_action_just_released(action_name) and (ab.is_charging or ab.is_holding):
				var ratio = ab.get_charge_ratio()
				var can_release = true
				if ab.min_charge_time > 0.0 and ab.current_charge_time < ab.min_charge_time:
					can_release = false
				
				ab.is_holding = false
				if ab.active_indicator:
					ab.active_indicator.hide()
				
				if can_release and not out_of_mana and ab.can_cast(self):
					try_cast_ability(effective_slot, ratio)
				ab.stop_charging()

		elif ab.cast_on_press:
			var should_trigger = false
			if slot_key == "LMB" and effective_slot == "LMB":
				should_trigger = Input.is_action_pressed(action_name) and ab.can_cast(self)
			else:
				should_trigger = Input.is_action_just_pressed(action_name)
			
			if should_trigger:
				if not out_of_mana:
					try_cast_ability(effective_slot)
		else:
			if Input.is_action_just_pressed(action_name):
				if out_of_mana:
					pass # Cannot input without mana
				elif ab.can_cast(self):
					ab.is_holding = true
					if ab.active_indicator and should_ability_have_indicator(ab):
						ab.active_indicator.show()
				else:
					buffer_ability(effective_slot)

			if Input.is_action_just_released(action_name) and ab.is_holding:
				ab.is_holding = false
				if ab.active_indicator:
					ab.active_indicator.hide()
				if not out_of_mana and ab.can_cast(self):
					try_cast_ability(effective_slot)

func open_ability_modal(slot_key: String, ab: AbilityClass) -> void:
	if not active_modal_slot.is_empty():
		cancel_active_modal()

	var cost = ab.get_mana_cost(self)
	if cost > 0.0:
		consume_mana(cost)

	active_modal_slot = slot_key
	is_mouse_hijacked = true
	var mouse_screen_pos = get_viewport().get_mouse_position() if get_viewport() else Vector2.ZERO
	ab.open_modal(self, mouse_screen_pos)

func close_and_resolve_modal(slot_key: String, ab: AbilityClass) -> void:
	if active_modal_slot != slot_key:
		return
	var choice = ab.close_and_select_modal()
	active_modal_slot = ""
	is_mouse_hijacked = false
	resolve_modal_choice(slot_key, ab, choice)

func cancel_active_modal() -> void:
	if active_modal_slot.is_empty():
		return
	var slot = active_modal_slot
	var ab = get_ability_for_slot(slot)
	active_modal_slot = ""
	is_mouse_hijacked = false
	if ab and ab is AbilityClass:
		ab.cancel_modal()
		resolve_modal_choice(slot, ab, "cancel")

func resolve_modal_choice(slot_key: String, ab: AbilityClass, choice: String) -> void:
	if active_modal_slot == slot_key:
		active_modal_slot = ""
	is_mouse_hijacked = false

	var modal_cfg = ab.ui_modal if ab else null
	var cost = ab.get_mana_cost(self) if ab else 0.0

	if choice == "cancel":
		var refund_pct = modal_cfg.cancel_refund_percent if modal_cfg else 0.0
		if refund_pct > 0.0 and cost > 0.0:
			restore_mana(cost * refund_pct)
		var cancel_cd = modal_cfg.cancel_cooldown if modal_cfg else 0.0
		if cancel_cd > 0.0:
			start_ability_cooldown(slot_key, cancel_cd)
		if has_method("_on_modal_cancelled"):
			call("_on_modal_cancelled", slot_key)
	else:
		# Valid choice made: refund initial reserved mana so try_cast_ability / consume_resources can perform normal check & deduction
		if cost > 0.0:
			restore_mana(cost)
		if has_method("_on_modal_option_selected"):
			call("_on_modal_option_selected", slot_key, choice)
		var eff_slot = get_effective_slot(slot_key)
		try_cast_ability(eff_slot)

func try_cast_ability(slot_key: String, charge_ratio: float = 0.0) -> bool:
	var eff_slot = get_effective_slot(slot_key)
	var ab = get_ability_for_slot(eff_slot)
	if not (ab is AbilityClass):
		return false
	var cost = ab.get_mana_cost(self)
	if cost > 0.0 and not has_mana(cost):
		return false
	if not ab.can_cast(self):
		return false

	if active_windup_id != "" and active_windup_id != eff_slot:
		cancel_active_windup()

	if ab.active_indicator and is_instance_valid(ab.active_indicator):
		ab.active_indicator.hide()

	# Invisibility breaks upon casting another ability including primary and dash
	if is_invisible():
		break_invisibility()

	# Transformation handling: moving & dashing does not break it, but attacking or casting other abilities does
	if is_transformed:
		if eff_slot == "SHIFT" and transformation_properties.get("can_dash", true):
			pass
		elif (ab is TransformationEffect or (ab and ab.effect_instance is TransformationEffect)):
			pass
		else:
			break_transformation()

	var facing_dir = -global_transform.basis.z.normalized()
	facing_dir.y = 0.0
	facing_dir = facing_dir.normalized()
	var origin = global_position
	var hb = ab.get_hitbox() if ab.has_method("get_hitbox") else ab.hitbox
	var is_melee_or_centered = (ab.effect_instance is MeleeStrikeEffect) or (ab is MeleeStrikeEffect) or (hb and "shape_type" in hb and (hb.shape_type == AbilityPipeline.HitboxShape.SECTOR or hb.shape_type == AbilityPipeline.HitboxShape.CIRCLE))
	if not is_melee_or_centered:
		origin = global_position + Vector3(0, 0.8, 0) + facing_dir * 1.0
	var ground_hit = get_mouse_ground_intersection()
	var target_pos = ground_hit if ground_hit != null else (global_position + facing_dir * 10.0)
	var shoot_dir = get_ranged_aim_direction(origin)

	if not is_multiplayer_match() or multiplayer.is_server():
		request_cast_ability(eff_slot, origin, shoot_dir, target_pos, charge_ratio)
	else:
		request_cast_ability.rpc_id(1, eff_slot, origin, shoot_dir, target_pos, charge_ratio)
	return true

@rpc("any_peer", "call_local", "reliable")
func request_cast_ability(slot_key: String, origin: Vector3, direction: Vector3, target_pos: Vector3, charge_ratio: float = 0.0) -> void:
	if not is_server_authoritative():
		return
	if is_multiplayer_match():
		var sender_id = multiplayer.get_remote_sender_id()
		if sender_id != 0 and str(name) != str(sender_id):
			return
	var ab = abilities.get(slot_key) as AbilityClass
	if not ab or not ab.can_cast(self):
		return

	if is_invisible():
		break_invisibility()
	if is_transformed:
		if slot_key == "SHIFT" and transformation_properties.get("can_dash", true):
			pass
		elif (ab is TransformationEffect or (ab and ab.effect_instance is TransformationEffect)):
			pass
		else:
			break_transformation()

	var delay = ab.get_windup_time()
	if delay > 0.0:
		start_windup_cast(slot_key, origin, direction, target_pos, delay, charge_ratio)
	else:
		ab.execute_server(self, origin, direction, target_pos, charge_ratio)
		if is_multiplayer_match():
			sync_cast_ability.rpc(slot_key, origin, direction, target_pos, charge_ratio)

@rpc("any_peer", "call_local", "reliable")
func sync_cast_ability(slot_key: String, origin: Vector3, direction: Vector3, target_pos: Vector3, charge_ratio: float = 0.0) -> void:
	var ab = abilities.get(slot_key) as AbilityClass
	if ab:
		ab.execute_client(self, origin, direction, target_pos, charge_ratio)
