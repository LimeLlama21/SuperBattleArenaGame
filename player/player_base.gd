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

@export var max_shield: float = 100.0
var current_shield: float = 0.0:
	set(value):
		current_shield = clamp(value, 0.0, max_shield)
		update_health_bar()
var shield_timer: float = 0.0
var is_dead: bool = false
var recent_damage_dealers: Dictionary = {} # attacker_id -> timestamp (seconds)

# --- Inventory & Items ---
@export var max_item_slots: int = 1
var item_slots: Array[String] = []
var gold: int = 0

var base_max_health: float = 200.0
var base_max_move_speed: float = 10.0
var item_damage_percent: float = 0.0
var item_health_bonus: float = 0.0
var item_move_speed_bonus: float = 0.0

# --- Critical Strike Stats ---
@export var crit_chance: float = 0.0 # Base crit chance (0.0 = 0%)
@export var crit_multiplier: float = AbilityPipeline.CRIT_DAMAGE_MULTIPLIER # 2.0 = 200% double damage

# --- Ability Registers & Lockout State ---
var abilities: Dictionary = {}
var ability_slots: Dictionary = {}
var ability_lockout_timer: float = 0.0
var current_lockout_ability_id: String = ""

# --- Ability Buffering System ---
var buffered_ability_slot: String = ""
var buffered_ability_timer: float = 0.0
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
	_setup_synchronizer()

	var is_local = is_local_player()
	if camera:
		camera.current = is_local
		if is_local:
			camera.top_level = true
			camera.global_position = global_position + CAMERA_OFFSET
			camera.look_at(global_position, Vector3.UP)
	
	if hud:
		hud.visible = is_local
	if spectator_panel:
		spectator_panel.visible = false

	_setup_health_bars()
	if sprite_3d and has_node("HealthBarViewport"):
		sprite_3d.texture = $HealthBarViewport.get_texture()
	update_health_bar()
	_update_team_visuals()
	call_deferred("_update_team_visuals")

	# Setup character-specific kit
	_setup_character_kit()
	_setup_hud_elements()
	base_max_health = max_health
	base_max_move_speed = max_move_speed
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

	# Firing box & LMB visual state (darkens when firing)
	if is_local_player() and hud and hud.has_method("set_firing_indicator"):
		var is_firing = Input.is_action_pressed("shoot") or firing_indicator_timer > 0.0
		if firing_indicator_timer > 0.0:
			firing_indicator_timer -= delta
		hud.set_firing_indicator(is_firing)

	# Base physics timers decrement (CC, float, wall impact, channeling)
	_process_physics_timers(delta)

	# Ability Lockout timer decrement
	if ability_lockout_timer > 0.0:
		ability_lockout_timer -= delta
		if ability_lockout_timer <= 0.0:
			ability_lockout_timer = 0.0
			current_lockout_ability_id = ""

	# Buffered ability timer decrement
	if buffered_ability_timer > 0.0:
		buffered_ability_timer -= delta
		if buffered_ability_timer <= 0.0:
			buffered_ability_slot = ""
			buffered_ability_timer = 0.0

	# Process input buffering during cast lockout
	if is_local_player() and not is_dead and not is_stunned():
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
		elif buffered_ability_slot != "":
			_try_resolve_buffered_ability()

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
	if not is_stunned():
		aim_at_mouse()

	# Delegate Character-specific inputs (LMB, RMB, Q, E, R, SHIFT)
	if not is_stunned():
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
	if is_dead:
		visible = false
		return
	visible = is_vis
	if sprite_3d:
		sprite_3d.visible = is_vis

func get_local_player_team() -> int:
	var local_id = get_my_player_id()
	var main_node = get_tree().root.get_node_or_null("Main") if get_tree() else null
	if main_node and main_node.has_method("get_player_team"):
		return main_node.get_player_team(local_id)
	
	var local_player = get_tree().root.get_node_or_null("Main/Players/" + str(local_id)) if get_tree() else null
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
	current_shield = new_shield

func take_damage(amount: float, attacker_id: int = 0, action_type: int = ActionType.ATTACK) -> void:
	if is_multiplayer_match() and not multiplayer.is_server():
		return
	if is_dead:
		return

	if is_ethereal_active():
		return

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
		var attacker = get_tree().root.get_node_or_null("Main/Players/" + str(attacker_id))
		if attacker and attacker.has_method("_on_damage_dealt"):
			attacker._on_damage_dealt(self, final_dmg, action_type)

	if current_health <= 0.0:
		die()

func _on_damage_dealt(target: Node, amount: float, action_type: int) -> void:
	damage_dealt.emit(target, amount, action_type)
	_on_character_damage_dealt(target, amount, action_type)

func _on_takedown(victim: Node) -> void:
	takedown_scored.emit(victim)
	_on_character_takedown(victim)

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
	current_health = new_health
	if current_health <= 0.0 and not is_dead:
		is_dead = true
		_update_death_state(true)

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

	# Bottom-Left Large HUD Health Bar
	if hud and hud.has_method("update_health"):
		hud.update_health(current_health, max_health, current_shield, gh)

# --- Alive / Dead State & Respawn Lifecycle ---
func die() -> void:
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

	var in_training = (main_node and main_node.get("is_training_mode") == true) or not is_multiplayer_match()

	if in_training:
		_update_death_state(true)
		get_tree().create_timer(0.6).timeout.connect(func():
			if is_instance_valid(self):
				respawn()
		)
		return

	if is_multiplayer_match():
		sync_death_state.rpc(true)
	else:
		_update_death_state(true)

	if main_node and main_node.has_method("on_player_died"):
		main_node.on_player_died(name.to_int())

@rpc("any_peer", "call_local", "reliable")
func sync_death_state(dead: bool) -> void:
	is_dead = dead
	_update_death_state(dead)

func _update_death_state(dead: bool) -> void:
	visible = not dead
	set_process_mode(PROCESS_MODE_INHERIT)
	var main_node = get_tree().root.get_node_or_null("Main")
	var in_training = (main_node and main_node.get("is_training_mode") == true) or not is_multiplayer_match()

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

func respawn() -> void:
	if is_multiplayer_match() and not multiplayer.is_server():
		return

	var spawn_pos = Vector3(-8.0, 0.1, 0.0)
	var main_node = get_tree().root.get_node_or_null("Main")
	var in_training = (main_node and main_node.get("is_training_mode") == true) or not is_multiplayer_match()

	if not in_training:
		var spawn_points = get_tree().root.get_node_or_null("Main/SpawnPoints")
		if spawn_points and spawn_points.get_child_count() > 0:
			var idx = randi() % spawn_points.get_child_count()
			spawn_pos = spawn_points.get_child(idx).global_position

	if is_multiplayer_match() and multiplayer.is_server():
		sync_respawn.rpc(spawn_pos)
	else:
		sync_respawn(spawn_pos)

@rpc("any_peer", "call_local", "reliable")
func sync_respawn(spawn_pos: Vector3) -> void:
	is_dead = false
	current_health = max_health
	current_shield = 0.0
	cleanse_cc()
	global_position = spawn_pos
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	knockback_wall_stun = 0.0
	_update_death_state(false)
	
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node and main_node.get("is_training_mode") == true and (is_local_player() or name == "1"):
		scale = Vector3(0.1, 0.1, 0.1)
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# --- Spectator Processing ---
func _process_camera(_delta: float) -> void:
	if not camera:
		return
	camera.global_position = global_position + CAMERA_OFFSET
	camera.look_at(global_position, Vector3.UP)

func _process_spectator(_delta: float) -> void:
	if Input.is_action_just_pressed("spectate_next"):
		_cycle_spectate(1)
	elif Input.is_action_just_pressed("spectate_prev"):
		_cycle_spectate(-1)

	var target_to_watch = spectate_target
	if not target_to_watch or not is_instance_valid(target_to_watch) or target_to_watch.get("is_dead"):
		_cycle_spectate(1)
		target_to_watch = spectate_target

	if target_to_watch and is_instance_valid(target_to_watch) and camera:
		camera.global_position = target_to_watch.global_position + CAMERA_OFFSET
		camera.look_at(target_to_watch.global_position, Vector3.UP)
		if spectator_label:
			var d_name = target_to_watch.get_display_name() if target_to_watch.has_method("get_display_name") else target_to_watch.get("character_name")
			spectator_label.text = "SPECTATING: %s (Player %s)\n[LMB / RMB to Cycle]" % [d_name, target_to_watch.name]
	elif spectator_label:
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
	if is_stunned():
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

# --- Character Data & Ability Initialization ---
func load_character_data(data: CharacterData) -> void:
	if not data:
		return
	character_name = data.character_name
	display_name = data.display_name if not data.display_name.is_empty() else data.character_name
	base_max_health = data.max_health
	max_health = data.max_health
	current_health = data.max_health
	if "crit_chance" in data:
		crit_chance = data.crit_chance
	if "crit_multiplier" in data:
		crit_multiplier = data.crit_multiplier
	base_max_move_speed = data.max_move_speed
	max_move_speed = data.max_move_speed
	ground_acceleration = data.ground_acceleration
	ground_friction = data.ground_friction
	if "intentional_movement_friction" in data:
		intentional_movement_friction = data.intentional_movement_friction
	air_acceleration = data.air_acceleration
	air_drag = data.air_drag
	jump_velocity = data.jump_velocity
	abilities = data.abilities
	ability_slots = data.ability_slots
	apply_all_items()
	if hud and data and data.has_method("get_ability_ui_configs"):
		hud.setup_character_ui(get_display_name(), data.get_ability_ui_configs())
	update_health_bar()

# --- Inventory & Item Management ---
func apply_all_items() -> void:
	item_damage_percent = 0.0
	item_health_bonus = 0.0
	item_move_speed_bonus = 0.0
	
	for item_id in item_slots:
		var item_def = ItemPipeline.get_item(item_id)
		if not item_def:
			continue
		if item_def.stats.has("damage_percent"):
			item_damage_percent += float(item_def.stats["damage_percent"])
		if item_def.stats.has("damage"):
			item_damage_percent += float(item_def.stats["damage"])
		if item_def.stats.has("max_health"):
			item_health_bonus += float(item_def.stats["max_health"])
		if item_def.stats.has("move_speed"):
			item_move_speed_bonus += float(item_def.stats["move_speed"])
	
	var old_max_hp = max_health
	max_health = base_max_health + item_health_bonus
	if max_health > old_max_hp:
		current_health += (max_health - old_max_hp)
	else:
		current_health = min(current_health, max_health)
	
	max_move_speed = base_max_move_speed + item_move_speed_bonus
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
func is_in_ability_lockout() -> bool:
	return ability_lockout_timer > 0.0

func is_in_cast_lockout() -> bool:
	return is_in_ability_lockout() or is_channeling or active_windup_id != ""

func trigger_ability_lockout(duration: float, ability_id: String = "") -> void:
	ability_lockout_timer = max(ability_lockout_timer, duration)
	current_lockout_ability_id = ability_id

func buffer_ability(slot_key: String) -> void:
	if is_dead or is_stunned():
		return
	buffered_ability_slot = slot_key
	buffered_ability_timer = max(ABILITY_BUFFER_WINDOW, ability_lockout_timer + 0.1)

func clear_buffered_ability() -> void:
	buffered_ability_slot = ""
	buffered_ability_timer = 0.0

func execute_ability_slot(_slot_key: String) -> bool:
	return false

func _try_resolve_buffered_ability() -> void:
	if buffered_ability_slot == "" or is_dead or is_stunned() or is_in_cast_lockout():
		return
	var slot_to_execute = buffered_ability_slot
	clear_buffered_ability()
	execute_ability_slot(slot_to_execute)

func can_cast_ability_slot(slot_key: String, char_abilities: Dictionary = {}) -> bool:
	if is_dead or is_stunned():
		return false
	if not is_in_cast_lockout():
		return true
	var source_abilities = char_abilities if not char_abilities.is_empty() else abilities
	var def = source_abilities.get(slot_key)
	if not def and ability_slots.has(slot_key):
		def = source_abilities.get(ability_slots[slot_key])
	if def and def.can_cast_during_lockout:
		return true
	if slot_key == "SHIFT" or slot_key == "dash":
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
		trigger_ability_lockout(l_time, ability_id)

# --- Systemic Ability Hitbox & Delayed Telegraph Pipeline ---
func show_ability_telegraph(ability_def: RefCounted, origin: Vector3, facing_dir: Vector3, delay: float) -> Node3D:
	if not ability_def or not ability_def.has_hitbox():
		return null
	var ind = AbilityIndicator.create_from_hitbox(ability_def.hitbox)
	if not ind:
		return null
	
	var follows_caster = false
	if ability_def.effect and "follow_caster" in ability_def.effect and ability_def.effect.follow_caster:
		follows_caster = true

	if follows_caster:
		ind.top_level = false
		add_child(ind)
		ind.position = Vector3.ZERO
		ind.rotation = Vector3.ZERO
	else:
		ind.top_level = true
		get_tree().root.add_child(ind)
		ind.global_position = origin
		if facing_dir.length_squared() > 0.001:
			var target = origin + facing_dir
			ind.look_at(Vector3(target.x, origin.y, target.z), Vector3.UP)
			ind.rotation.x = 0.0
			ind.rotation.z = 0.0
	
	ind.show()
	
	if delay > 0.0:
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

func start_ability_windup(ability_id: String, facing_dir: Vector3 = Vector3.ZERO) -> void:
	var ability_def = null
	if "abilities" in self and self.abilities is Dictionary:
		ability_def = self.abilities.get(ability_id)
	if ability_def and ability_def.effect and ability_def.effect.windup_time > 0.0:
		active_windup_facing = facing_dir if facing_dir != Vector3.ZERO else -global_transform.basis.z.normalized()
		active_windup_id = ability_id
		sync_ability_windup.rpc(ability_id, global_position, active_windup_facing, ability_def.effect.windup_time)

func _on_windup_id_changed(ability_id: String) -> void:
	var ability_def = null
	if "abilities" in self and self.abilities is Dictionary:
		ability_def = self.abilities.get(ability_id)
	if ability_def and ability_def.has_hitbox():
		var delay = ability_def.effect.windup_time if (ability_def.effect and ability_def.effect.windup_time > 0.0) else 0.0
		if delay > 0.0:
			show_ability_telegraph(ability_def, global_position, active_windup_facing, delay)
			if is_multiplayer_authority():
				get_tree().create_timer(delay).timeout.connect(func():
					if active_windup_id == ability_id:
						active_windup_id = ""
				)

@rpc("any_peer", "call_local", "reliable")
func sync_ability_windup(ability_id: String, origin: Vector3, facing: Vector3, delay: float) -> void:
	if delay <= 0.0:
		return
	if active_windup_id == ability_id and is_multiplayer_authority():
		return
	var ability_def = null
	if "abilities" in self and self.abilities is Dictionary:
		ability_def = self.abilities.get(ability_id)
	if ability_def:
		show_ability_telegraph(ability_def, origin, facing, delay)

func trigger_ability_hitbox(ability_key_or_id: String, origin: Vector3 = Vector3.ZERO, facing_dir: Vector3 = Vector3.ZERO) -> void:
	var ability_def = null
	if "abilities" in self and self.abilities is Dictionary:
		ability_def = self.abilities.get(ability_key_or_id)
	if not ability_def or not ability_def.has_hitbox():
		return
	
	var cast_origin = origin if origin != Vector3.ZERO else global_position
	var cast_facing = facing_dir if facing_dir != Vector3.ZERO else -global_transform.basis.z.normalized()
	cast_facing.y = 0.0
	if cast_facing.length_squared() > 0.001:
		cast_facing = cast_facing.normalized()
	else:
		cast_facing = -global_transform.basis.z.normalized()
	
	show_ability_telegraph(ability_def, cast_origin, cast_facing, 0.0)
	if is_multiplayer_match() and (is_multiplayer_authority() or multiplayer.is_server()):
		sync_trigger_hitbox.rpc(ability_key_or_id, cast_origin, cast_facing)

@rpc("any_peer", "call_remote", "reliable")
func sync_trigger_hitbox(ability_key_or_id: String, origin: Vector3, facing: Vector3) -> void:
	var ability_def = null
	if "abilities" in self and self.abilities is Dictionary:
		ability_def = self.abilities.get(ability_key_or_id)
	if ability_def and ability_def.has_hitbox():
		show_ability_telegraph(ability_def, origin, facing, 0.0)

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
