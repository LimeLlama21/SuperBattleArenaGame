class_name BasePlayer
extends CharacterBody3D

enum ActionType {
	ATTACK = 0,      # Primary / Basic Attack (e.g. LMB: Rail Shot, Melee Slam, Melee Slash)
	ABILITY = 1,     # Special Character Ability / Spell (e.g. RMB, Q, E, Shift / Crash)
	ENVIRONMENT = 2  # Map Hazards / Void / Wall Impact
}

signal attack_performed(attack_name: String)
signal ability_cast(ability_name: String, slot_key: String)
signal damage_dealt(target: Node, amount: float, action_type: int)
signal damage_taken(attacker_id: int, amount: float, action_type: int)

@export var character_name: String = "Character"
@export var team_id: int = 1
@export var max_health: float = 100.0
@export var current_health: float = 100.0:
	set(value):
		current_health = clamp(value, 0.0, max_health)
		update_health_bar()

# Shield / Temp HP parameters
@export var max_shield: float = 100.0
var current_shield: float = 0.0:
	set(value):
		current_shield = clamp(value, 0.0, max_shield)
		update_health_bar()
var shield_timer: float = 0.0

# Movement Parameters
@export var max_move_speed: float = 10.0
@export var ground_acceleration: float = 65.0
@export var ground_friction: float = 40.0
@export var air_acceleration: float = 25.0
@export var air_drag: float = 3.5
@export var jump_velocity: float = 9.5

# Combat & Character Attack Timing
@export var is_melee_character: bool = false
@export var dash_impulse: float = 26.0
@export var max_dash_charges: int = 1
@export var dash_cooldown: float = 4.0 # Interval / lockout between dashes
@export var dash_recharge_time: float = 4.0 # Time to recover one dash charge
@export var attack_cooldown: float = 0.3 # Fire rate / attack interval
@export var windup_time: float = 0.0 # Attack windup delay
@export var melee_windup_time: float = 0.28 # Default melee windup

# Ability One (RMB), Ability Two (Q), Ability Three (E), and Ultimate (R) Parameters
@export var ability_one_cooldown: float = 6.0
@export var ability_two_cooldown: float = 8.0
@export var ability_three_cooldown: float = 8.0
@export var ability_four_cooldown: float = 24.0
@export var can_cast_while_stunned: bool = false
@export var is_cc_immune: bool = false

# Projectile Stats (Size, Damage, Speed)
@export var projectile_size: float = 1.0
@export var projectile_damage: float = 50.0
@export var projectile_speed: float = 70.0

# Melee Attack Stats (Size, Damage, Height)
@export var melee_size: float = 4.2 # Radius / range of the melee hitbox
@export var melee_height: float = 2.4 # Vertical hit height / thickness (centered at chest/strike level)
@export var melee_damage: float = 55.0
@export var melee_angle_deg: float = 120.0

var character_data: CharacterData = null
var _ability_definitions: Dictionary = {}

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 24.0)

# Dash state
var current_dash_charges: int = 1
var dash_lockout_timer: float = 0.0
var dash_recharge_timer: float = 0.0
var is_dashing: bool = false
var dash_timer: float = 0.0
var current_dash_speed: float = 0.0

# Float Status Effect state
var is_floating: bool = false
var float_timer: float = 0.0
var current_gravity_mult: float = 1.0
const FLOAT_TOTAL_DURATION: float = 2.2
const FLOAT_SLOWDOWN_TIME: float = 0.7
const FLOAT_HOVER_TIME: float = 1.4

# Crash Down state
var is_crashing_down: bool = false
var crash_target_pos: Vector3 = Vector3.ZERO

# Attack & Ability state
var attack_timer: float = 0.0
var ability_one_timer: float = 0.0
var ability_two_timer: float = 0.0
var ability_three_timer: float = 0.0
var ability_four_timer: float = 0.0
var is_casting_melee: bool = false
var is_casting_ability_one: bool = false
var is_casting_ability_two: bool = false
var is_casting_ability_three: bool = false
var is_casting_ability_four: bool = false
var is_dead: bool = false

# Status effects state (Stun, Slow, Silence)
var stun_timer: float = 0.0
var slow_timer: float = 0.0
var slow_initial_duration: float = 0.0
var slow_initial_percent: float = 0.0
var slow_percent: float = 0.0
var silence_timer: float = 0.0

# Crush Ultimate: Juggernaut Charge & Grab State
var is_crush_charging: bool = false
var crush_charge_timer: float = 0.0
var crush_charge_dir: Vector3 = Vector3.FORWARD
const CRUSH_CHARGE_DURATION: float = 1.0
const CRUSH_CHARGE_SPEED: float = 28.0
const CRUSH_CHARGE_TURN_SPEED: float = 1.8

# Dive Ultimate: Tectonic Buff State
var dive_ult_buff_timer: float = 0.0
const DIVE_ULT_BUFF_DURATION: float = 6.0
const DIVE_ULT_SPEED_MULT: float = 0.35
const DIVE_ULT_ATTACK_SPEED_MULT: float = 0.40

# Channeling state (Self-inflicted CC condition)
var is_channeling: bool = false
var channel_timer: float = 0.0
var channel_complete_callback: Callable = Callable()

# Spectator variables
var spectate_target: Node3D = null
var spectate_index: int = 0

const CAMERA_OFFSET: Vector3 = Vector3(0, 17, 9.5)
const CAMERA_ZOOMED_OFFSET: Vector3 = Vector3(0, 30, 16.5)
var current_camera_offset: Vector3 = Vector3(0, 17, 9.5)
const VOID_DEATH_Y: float = -8.0

# Passives & Special Ability State
# Crush: Titan's Surge & Gray Health / Iron Blood
var is_crush_empowered: bool = false
var gray_health: float = 0.0
var time_since_last_damage: float = 0.0

# Dive: Rupture Marks & Deflecting Guard
var dive_marks_count: int = 0
var dive_mark_timer: float = 0.0
var dive_mark_attacker_id: int = 0
const DIVE_MARK_DURATION: float = 3.5
const DIVE_MARK_MAX: int = 5
const DIVE_MARK_BURST_PER_STACK: float = 18.0

var is_blocking: bool = false
var block_timer: float = 0.0
const BLOCK_DURATION: float = 3.0
const BLOCK_MAX_TURN_SPEED: float = 2.2 # Max turn speed (rad/s) while blocking
const BLOCK_DR_PERCENT: float = 0.75 # 75% damage reduction from front 140 deg

# Poke: Fleet Foot & Eagle Eye Ultimate
var poke_speed_boost_timer: float = 0.0
var poke_speed_boost_percent: float = 0.0
var poke_ult_buff_timer: float = 0.0
const POKE_ULT_BUFF_DURATION: float = 12.0

# Reaper: Soul Harvest / MS Steal, One with Death, Nightmare, Spectral Tether
var root_timer: float = 0.0
var grounded_timer: float = 0.0
var cripple_timer: float = 0.0
var cripple_intensity: float = 0.35
var ethereal_timer: float = 0.0

var reaper_ms_steal_timer: float = 0.0
var reaper_ms_steal_pct: float = 0.0
var reaper_ult_buff_timer: float = 0.0
const REAPER_ULT_BUFF_DURATION: float = 8.0
const REAPER_ULT_MS_MULT: float = 0.45
const REAPER_ULT_DMG_MULT: float = 1.30

var reaper_nightmare_timer: float = 0.0
var is_in_nightmare: bool = false
var reaper_tether_target_id: int = 0
var reaper_tether_timer: float = 0.0
var reaper_tether_active: bool = false

# Wall Impact Damage System (Calculated from knockback_velocity caused by external enemies/hazards)
var knockback_velocity: Vector3 = Vector3.ZERO
var wall_impact_cooldown_timer: float = 0.0
const WALL_IMPACT_MIN_SPEED: float = 14.0 # Minimum velocity directly into wall to trigger damage
const WALL_IMPACT_DAMAGE_FACTOR: float = 1.8 # Damage per m/s of normal impact speed

# Ability hold-to-aim and local hitbox indicator state
var is_holding_shoot: bool = false
var is_holding_ability_one: bool = false
var is_holding_ability_two: bool = false
var is_holding_ability_three: bool = false
var is_holding_ability_four: bool = false

var ind_attack: Node3D = null
var ind_ability_one: Node3D = null
var ind_ability_two: Node3D = null
var ind_ability_three: Node3D = null
var ind_ability_four: Node3D = null
var ind_dive_crash_range: MeshInstance3D = null
var ind_dive_crash_circle: Node3D = null
var ind_poke_flare_circle: Node3D = null
var ind_poke_dot_zone: Node3D = null

@onready var sprite_3d: Sprite3D = $HealthBarSprite
@onready var health_bar: ProgressBar = $HealthBarViewport/ProgressBar
@onready var gray_health_bar: ProgressBar = get_node_or_null("HealthBarViewport/GrayProgressBar")
@onready var camera: Camera3D = $Camera3D
@onready var melee_visual: Node3D = get_node_or_null("MeleeVisual")
@onready var ability_one_visual: Node3D = get_node_or_null("AbilityOneVisual")
@onready var ability_two_visual: Node3D = get_node_or_null("AbilityTwoVisual")
@onready var block_visual: Node3D = get_node_or_null("BlockVisual")
@onready var crash_visual: Node3D = get_node_or_null("CrashVisual")
@onready var nightmare_visual: Node3D = get_node_or_null("NightmareVisual")
@onready var ult_visual: Node3D = get_node_or_null("UltVisual")
const AbilitySlot = preload("res://ability_slot.gd")

@onready var hud: CanvasLayer = $PlayerHUD
@onready var hud_container: Control = get_node_or_null("PlayerHUD/HUDContainer")
@onready var status_cc_label: Label = get_node_or_null("PlayerHUD/HUDContainer/StatusCCLabel") if has_node("PlayerHUD/HUDContainer/StatusCCLabel") else get_node_or_null("PlayerHUD/VBox/StatusCCLabel")
@onready var slot_ability_one: PanelContainer = get_node_or_null("PlayerHUD/HUDContainer/AbilityBar/SlotRMB")
@onready var slot_ability_two: PanelContainer = get_node_or_null("PlayerHUD/HUDContainer/AbilityBar/SlotQ")
@onready var slot_ability_three: PanelContainer = get_node_or_null("PlayerHUD/HUDContainer/AbilityBar/SlotE")
@onready var slot_ability_four: PanelContainer = get_node_or_null("PlayerHUD/HUDContainer/AbilityBar/SlotR")
@onready var slot_dash: PanelContainer = get_node_or_null("PlayerHUD/HUDContainer/AbilityBar/SlotShift")
@onready var attack_cd_label: Label = get_node_or_null("PlayerHUD/VBox/AttackCD")
@onready var ability_one_cd_label: Label = get_node_or_null("PlayerHUD/VBox/AbilityOneCD")
@onready var ability_two_cd_label: Label = get_node_or_null("PlayerHUD/VBox/AbilityTwoCD")
@onready var ability_three_cd_label: Label = get_node_or_null("PlayerHUD/VBox/AbilityThreeCD")
@onready var ability_four_cd_label: Label = get_node_or_null("PlayerHUD/VBox/AbilityFourCD")
@onready var dash_cd_label: Label = get_node_or_null("PlayerHUD/VBox/DashCD")
@onready var spectator_panel: PanelContainer = $PlayerHUD/SpectatorPanel
@onready var spectator_label: Label = $PlayerHUD/SpectatorPanel/VBox/SpectatorLabel

func _enter_tree() -> void:
	var peer_id = name.to_int()
	if peer_id > 0:
		set_multiplayer_authority(peer_id)
		$MultiplayerSynchronizer.set_multiplayer_authority(peer_id)

func _exit_tree() -> void:
	if ind_attack and is_instance_valid(ind_attack): ind_attack.queue_free()
	if ind_ability_one and is_instance_valid(ind_ability_one): ind_ability_one.queue_free()
	if ind_ability_two and is_instance_valid(ind_ability_two): ind_ability_two.queue_free()
	if ind_ability_three and is_instance_valid(ind_ability_three): ind_ability_three.queue_free()
	if ind_ability_four and is_instance_valid(ind_ability_four): ind_ability_four.queue_free()
	if ind_poke_dot_zone and is_instance_valid(ind_poke_dot_zone): ind_poke_dot_zone.queue_free()
	if ind_poke_flare_circle and is_instance_valid(ind_poke_flare_circle): ind_poke_flare_circle.queue_free()
	if ind_dive_crash_circle and is_instance_valid(ind_dive_crash_circle): ind_dive_crash_circle.queue_free()
	if ind_dive_crash_range and is_instance_valid(ind_dive_crash_range): ind_dive_crash_range.queue_free()
	if camera and is_instance_valid(camera) and camera.top_level:
		camera.queue_free()

func _ready() -> void:
	_initialize_character_from_library()

	var peer_id = name.to_int()
	if peer_id > 0:
		set_multiplayer_authority(peer_id)
		$MultiplayerSynchronizer.set_multiplayer_authority(peer_id)

	if hud:
		hud.layer = 10

	var is_local = (name.to_int() == multiplayer.get_unique_id())
	
	if is_local:
		camera.top_level = true
		camera.make_current()
		camera.global_position = global_position + CAMERA_OFFSET
		camera.look_at(global_position, Vector3.UP)
		hud.show()
		_setup_local_indicators()
	else:
		# Completely remove remote player's camera so it can never take over local viewport
		camera.current = false
		camera.clear_current()
		camera.queue_free()
		hud.hide()
	
	current_dash_charges = max_dash_charges
	dash_lockout_timer = 0.0
	dash_recharge_timer = 0.0
	sprite_3d.texture = $HealthBarViewport.get_texture()
	_update_team_visuals()
	update_health_bar()
	if melee_visual:
		melee_visual.visible = false
		if melee_size > 0.0 and character_name == "Crush":
			melee_visual.scale = Vector3(melee_size / 4.2, 1.0, melee_size / 4.2)
	if ability_one_visual:
		ability_one_visual.visible = false
	if ability_two_visual:
		ability_two_visual.visible = false
	if block_visual:
		block_visual.visible = false
	if crash_visual:
		crash_visual.visible = false
	if nightmare_visual:
		nightmare_visual.visible = false
	if ult_visual:
		ult_visual.visible = false
	if spectator_panel:
		spectator_panel.hide()

func _initialize_character_from_library() -> void:
	character_data = CharactersLibrary.get_character(character_name)
	if character_data:
		max_health = character_data.max_health
		current_health = max_health
		max_move_speed = character_data.max_move_speed
		ground_acceleration = character_data.ground_acceleration
		ground_friction = character_data.ground_friction
		air_acceleration = character_data.air_acceleration
		air_drag = character_data.air_drag
		jump_velocity = character_data.jump_velocity
		
		dash_impulse = character_data.dash_impulse
		max_dash_charges = character_data.max_dash_charges
		dash_cooldown = character_data.dash_cooldown
		dash_recharge_time = character_data.dash_recharge_time
		
		is_melee_character = character_data.is_melee
		attack_cooldown = character_data.attack_cooldown
		windup_time = character_data.windup_time
		melee_windup_time = character_data.melee_windup_time
		
		projectile_size = character_data.projectile_size
		projectile_damage = character_data.projectile_damage
		projectile_speed = character_data.projectile_speed
		
		melee_size = character_data.melee_size
		melee_height = character_data.melee_height
		melee_damage = character_data.melee_damage
		melee_angle_deg = character_data.melee_angle_deg
		
		for slot in character_data.ability_slots.keys():
			var ability_id = character_data.ability_slots[slot]
			var ability_def = AbilitiesLibrary.get_ability(ability_id)
			if ability_def:
				_ability_definitions[slot] = ability_def
				match slot:
					"RMB": ability_one_cooldown = ability_def.cooldown
					"Q": ability_two_cooldown = ability_def.cooldown
					"E": ability_three_cooldown = ability_def.cooldown
					"R": ability_four_cooldown = ability_def.cooldown

func set_team_id(new_team: int) -> void:
	team_id = new_team
	_update_team_visuals()

func is_enemy(other: Node) -> bool:
	if not is_instance_valid(other) or not other.has_method("take_damage"):
		return false
	if other == self:
		return false
	if other.get("team_id") != null and other.team_id == team_id and team_id > 0:
		return false
	return true

func _update_team_visuals() -> void:
	if not health_bar:
		return
	var my_local_id = multiplayer.get_unique_id()
	var is_teammate = false
	var local_player = get_tree().root.get_node_or_null("Main/Players/" + str(my_local_id))
	if local_player and local_player.get("team_id") != null:
		is_teammate = (local_player.team_id == team_id)
	elif name.to_int() == my_local_id:
		is_teammate = true
	else:
		is_teammate = (team_id == 1 and my_local_id == 1)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_right = 4
	fill_style.corner_radius_bottom_left = 4
	if is_teammate:
		fill_style.bg_color = Color(0.1, 0.85, 0.95, 1.0) # Friendly Blue / Cyan
	else:
		fill_style.bg_color = Color(0.95, 0.3, 0.25, 1.0) # Enemy Red / Coral
	health_bar.add_theme_stylebox_override("fill", fill_style)

func _setup_local_indicators() -> void:
	if character_name == "Crush":
		# RMB: 5.2m, 100 deg Fan Stun
		ind_ability_one = AbilityIndicator.create_sector_indicator(5.2, 100.0, Color(1.0, 0.85, 0.1, 0.32), Color(1.0, 0.95, 0.3, 0.95))
		# Q: 6.5m Radius Shockwave Circle
		ind_ability_two = AbilityIndicator.create_circle_indicator(6.5, Color(1.0, 0.45, 0.15, 0.22), Color(1.0, 0.6, 0.25, 0.9))
		# R: 28m x 2.4m Juggernaut Charge line
		ind_ability_four = AbilityIndicator.create_line_indicator(28.0, 2.4, Color(1.0, 0.4, 0.1, 0.32), Color(1.0, 0.65, 0.2, 0.95))
		ind_ability_four.top_level = true
	elif character_name == "Dive":
		# RMB: 3.0m, 135 deg Heavy Cleave
		ind_ability_one = AbilityIndicator.create_sector_indicator(3.0, 135.0, Color(0.2, 0.9, 1.0, 0.32), Color(0.35, 0.95, 1.0, 0.95))
		# Q: 14.0m x 1.5m Earth Tremor path with end pillar circle
		ind_ability_two = AbilityIndicator.create_line_indicator(14.0, 1.5, Color(0.8, 0.3, 1.0, 0.28), Color(0.9, 0.45, 1.0, 0.95), true, 1.4)
		ind_ability_two.top_level = true
		
		# E: 140 deg Frontal Guard Arc indicator
		ind_ability_three = AbilityIndicator.create_sector_indicator(2.5, 140.0, Color(0.2, 0.8, 1.0, 0.35), Color(0.3, 0.9, 1.0, 0.95))
		
		# R: 6.0m Tectonic Uprising Burst & Rock Ring Circle
		ind_ability_four = AbilityIndicator.create_circle_indicator(6.0, Color(0.75, 0.2, 1.0, 0.32), Color(0.9, 0.4, 1.0, 0.95))
		
		# Contextual Aerial Crash Down: Range ring + 6.0m landing circle
		ind_dive_crash_range = AbilityIndicator.create_ring_indicator(6.0, Color(1.0, 0.3, 0.9, 0.65))
		ind_dive_crash_range.top_level = true
		add_child(ind_dive_crash_range)
		ind_dive_crash_range.hide()
		
		ind_dive_crash_circle = AbilityIndicator.create_circle_indicator(6.0, Color(0.9, 0.2, 0.7, 0.32), Color(1.0, 0.4, 0.85, 0.95))
		ind_dive_crash_circle.top_level = true
		add_child(ind_dive_crash_circle)
		ind_dive_crash_circle.hide()
	elif character_name == "Poke":
		# RMB: 60m Repulsor Bolt line
		ind_ability_one = AbilityIndicator.create_line_indicator(60.0, 0.7, Color(1.0, 0.8, 0.2, 0.28), Color(1.0, 0.9, 0.3, 0.95))
		ind_ability_one.top_level = true
		
		# Q: 2.2m Radius Acceleration / Slipstream Field Ground Circle
		ind_poke_dot_zone = AbilityIndicator.create_circle_indicator(2.2, Color(0.1, 0.95, 0.85, 0.32), Color(0.2, 1.0, 0.9, 0.95))
		ind_poke_dot_zone.top_level = true
		add_child(ind_poke_dot_zone)
		ind_poke_dot_zone.hide()
		
		# E: Recon Flare Targeting Line and 12.0m radius reveal circle
		ind_ability_three = AbilityIndicator.create_line_indicator(65.0, 0.8, Color(0.2, 0.9, 0.9, 0.25), Color(0.3, 1.0, 0.95, 0.95))
		ind_ability_three.top_level = true
		ind_poke_flare_circle = AbilityIndicator.create_circle_indicator(12.0, Color(0.2, 0.9, 0.9, 0.22), Color(0.3, 1.0, 0.95, 0.95))
		ind_poke_flare_circle.top_level = true
		add_child(ind_poke_flare_circle)
		ind_poke_flare_circle.hide()
		
		# R: 75m Orbital Lance Piercing Beam line
		ind_ability_four = AbilityIndicator.create_line_indicator(75.0, 2.2, Color(0.15, 0.9, 1.0, 0.32), Color(0.35, 1.0, 1.0, 0.95))
		ind_ability_four.top_level = true
	elif character_name == "Reaper":
		# RMB: 16m Spectral Tether line
		ind_ability_one = AbilityIndicator.create_line_indicator(16.0, 0.8, Color(0.2, 1.0, 0.8, 0.28), Color(0.3, 1.0, 0.85, 0.95))
		ind_ability_one.top_level = true
		
		# Q: Cull the Weak Donut indicator (inner 3.2m, outer 5.5m)
		ind_ability_two = AbilityIndicator.create_donut_indicator(3.2, 5.5, Color(0.95, 0.15, 0.45, 0.35), Color(1.0, 0.3, 0.55, 0.95), Color(0.5, 0.1, 0.35, 0.15), Color(0.7, 0.25, 0.45, 0.7))
		
		# E: Nightmare shadow pool circle indicator (4.5m)
		ind_ability_three = AbilityIndicator.create_circle_indicator(4.5, Color(0.35, 0.05, 0.55, 0.32), Color(0.6, 0.15, 0.85, 0.95))
		
		# R: One with Death aura indicator (2.5m self ring)
		ind_ability_four = AbilityIndicator.create_circle_indicator(2.5, Color(0.55, 0.05, 0.85, 0.32), Color(0.75, 0.2, 1.0, 0.95))

	if ind_ability_one:
		add_child(ind_ability_one)
		ind_ability_one.hide()
	if ind_ability_two:
		add_child(ind_ability_two)
		ind_ability_two.hide()
	if ind_ability_three:
		add_child(ind_ability_three)
		ind_ability_three.hide()
	if ind_ability_four:
		add_child(ind_ability_four)
		ind_ability_four.hide()

func is_stunned() -> bool:
	return stun_timer > 0.0 and not is_cc_immune and not is_in_nightmare

func is_silenced() -> bool:
	return silence_timer > 0.0 and not is_cc_immune and not is_in_nightmare

func is_slowed() -> bool:
	return slow_timer > 0.0 and not is_cc_immune and not is_in_nightmare

func is_rooted() -> bool:
	return root_timer > 0.0 and not is_cc_immune and not is_in_nightmare

func is_grounded() -> bool:
	return grounded_timer > 0.0 and not is_cc_immune and not is_in_nightmare

func is_crippled() -> bool:
	return cripple_timer > 0.0 and not is_cc_immune and not is_in_nightmare

func is_ethereal_active() -> bool:
	return (ethereal_timer > 0.0 or is_in_nightmare) and not is_dead

func get_slow_multiplier() -> float:
	if is_slowed():
		return clamp(1.0 - slow_percent, 0.1, 1.0)
	return 1.0

func start_channel(duration: float, on_complete: Callable) -> void:
	is_channeling = true
	channel_timer = duration
	channel_complete_callback = on_complete

func cancel_channel() -> void:
	is_channeling = false
	channel_timer = 0.0
	channel_complete_callback = Callable()

func apply_shield(amount: float, duration: float = 5.0) -> void:
	current_shield = amount
	shield_timer = duration
	if multiplayer.is_server():
		sync_shield.rpc(current_shield)

@rpc("any_peer", "call_local", "reliable")
func sync_shield(new_shield: float) -> void:
	current_shield = new_shield

func _physics_process(delta: float) -> void:
	# Deadzone / Void Check
	if multiplayer.is_server() and not is_dead and global_position.y < VOID_DEATH_Y:
		die()

	# Status effect timers decrement on all peers
	if stun_timer > 0.0:
		stun_timer -= delta
		if stun_timer < 0.0:
			stun_timer = 0.0

	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_initial_duration > 0.0:
			slow_percent = slow_initial_percent * (slow_timer / slow_initial_duration)
		if slow_timer <= 0.0:
			slow_timer = 0.0
			slow_percent = 0.0
			slow_initial_duration = 0.0
			slow_initial_percent = 0.0

	if shield_timer > 0.0:
		shield_timer -= delta
		if shield_timer <= 0.0:
			current_shield = 0.0

	if poke_speed_boost_timer > 0.0:
		poke_speed_boost_timer -= delta
		if poke_speed_boost_timer <= 0.0:
			poke_speed_boost_timer = 0.0
			poke_speed_boost_percent = 0.0

	if dive_ult_buff_timer > 0.0:
		dive_ult_buff_timer -= delta
		if dive_ult_buff_timer <= 0.0:
			dive_ult_buff_timer = 0.0

	if silence_timer > 0.0:
		silence_timer -= delta
		if silence_timer <= 0.0:
			silence_timer = 0.0

	if root_timer > 0.0:
		root_timer -= delta
		if root_timer <= 0.0:
			root_timer = 0.0

	if grounded_timer > 0.0:
		grounded_timer -= delta
		if grounded_timer <= 0.0:
			grounded_timer = 0.0

	if cripple_timer > 0.0:
		cripple_timer -= delta
		if cripple_timer <= 0.0:
			cripple_timer = 0.0

	if ethereal_timer > 0.0:
		ethereal_timer -= delta
		if ethereal_timer <= 0.0:
			ethereal_timer = 0.0

	if reaper_ms_steal_timer > 0.0:
		reaper_ms_steal_timer -= delta
		if reaper_ms_steal_timer <= 0.0:
			reaper_ms_steal_timer = 0.0
			reaper_ms_steal_pct = 0.0

	if reaper_ult_buff_timer > 0.0:
		reaper_ult_buff_timer -= delta
		if reaper_ult_buff_timer <= 0.0:
			reaper_ult_buff_timer = 0.0
			if ult_visual:
				ult_visual.visible = false

	# Toggle terrain collision mask during Ethereal state
	set_collision_mask_value(1, not is_ethereal_active())

	# Reaper Spectral Tether tick (Server-authoritative)
	if multiplayer.is_server() and not is_dead and reaper_tether_active:
		reaper_tether_timer -= delta
		var players_container = get_tree().root.get_node_or_null("Main/Players")
		var target = players_container.get_node_or_null(str(reaper_tether_target_id)) if players_container else null
		if not target or target.get("is_dead") or global_position.distance_to(target.global_position) > 18.0:
			end_reaper_tether_server(false)
		else:
			var progress = 1.0 - (reaper_tether_timer / 1.75)
			var slow_val = lerp(0.20, 0.65, clamp(progress, 0.0, 1.0))
			if target.has_method("apply_slow"):
				target.apply_slow(0.25, slow_val)
			if target.has_method("apply_grounded"):
				target.apply_grounded(0.25)
			if reaper_tether_timer <= 0.0:
				end_reaper_tether_server(true, target)

	# Reaper Nightmare countdown
	if is_in_nightmare:
		reaper_nightmare_timer -= delta
		if reaper_nightmare_timer <= 0.0:
			end_reaper_nightmare()

	if wall_impact_cooldown_timer > 0.0:
		wall_impact_cooldown_timer -= delta
		if wall_impact_cooldown_timer < 0.0:
			wall_impact_cooldown_timer = 0.0

	# Knockback velocity decay (decays via friction/drag, separate from player movement & dashes)
	if knockback_velocity != Vector3.ZERO:
		if is_on_floor():
			knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, ground_friction * delta)
		else:
			knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, air_drag * delta)

	# Dive Rupture Marks tick (Server-authoritative)
	if multiplayer.is_server() and not is_dead and dive_marks_count > 0:
		dive_mark_timer -= delta
		if dive_mark_timer <= 0.0:
			detonate_dive_marks()

	# Dive Block Duration countdown
	if is_blocking:
		block_timer -= delta
		if block_timer <= 0.0:
			end_block_stance()
			ability_three_timer = ability_three_cooldown

	# Crush Gray Health Decay & Out-of-Combat Regen (Server-authoritative)
	time_since_last_damage += delta
	if multiplayer.is_server() and character_name == "Crush" and not is_dead:
		if time_since_last_damage >= 5.0 and gray_health > 0.0:
			var max_consume_rate = max_health * 0.1 # 10% max HP per sec
			var consume = min(gray_health, max_consume_rate * delta)
			gray_health -= consume
			heal(consume * 0.5) # Heals for 50% of consumed gray health
			sync_gray_health.rpc(gray_health)

	# Channeling process
	if is_channeling:
		channel_timer -= delta
		if channel_timer <= 0.0:
			is_channeling = false
			if channel_complete_callback.is_valid():
				var cb = channel_complete_callback
				channel_complete_callback = Callable()
				cb.call()

	if name.to_int() != multiplayer.get_unique_id():
		return

	# If dead, process Spectator camera & inputs
	if is_dead:
		_process_spectator(delta)
		return

	if not DisplayServer.window_is_focused():
		_cancel_all_hold_indicators()
		return

	if DisplayServer.window_is_focused() and camera and is_instance_valid(camera) and camera.is_inside_tree():
		var target_cam_offset = CAMERA_ZOOMED_OFFSET if (character_name == "Poke" and poke_ult_buff_timer > 0.0) else CAMERA_OFFSET
		current_camera_offset = current_camera_offset.lerp(target_cam_offset, 5.0 * delta)
		camera.global_position = global_position + current_camera_offset
		camera.look_at(global_position, Vector3.UP)

	if dash_lockout_timer > 0.0:
		dash_lockout_timer -= delta

	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false

	# Float status effect processing
	if is_floating:
		float_timer += delta
		if float_timer < FLOAT_SLOWDOWN_TIME:
			# Gravity artificially slows over time towards 0
			var t = float_timer / FLOAT_SLOWDOWN_TIME
			current_gravity_mult = lerp(1.0, 0.05, t)
		elif float_timer < FLOAT_HOVER_TIME:
			# Pauses at a low value for a moment
			current_gravity_mult = 0.05
		elif float_timer < FLOAT_TOTAL_DURATION:
			# Slowly goes back to normal for a moment
			var t = (float_timer - FLOAT_HOVER_TIME) / (FLOAT_TOTAL_DURATION - FLOAT_HOVER_TIME)
			current_gravity_mult = lerp(0.05, 1.0, t)
		else:
			end_float_state()

	if current_dash_charges < max_dash_charges:
		dash_recharge_timer += delta
		if dash_recharge_timer >= dash_recharge_time:
			current_dash_charges += 1
			dash_recharge_timer = 0.0 if current_dash_charges == max_dash_charges else (dash_recharge_timer - dash_recharge_time)
	else:
		dash_recharge_timer = 0.0

	var cd_delta = delta * 2.0 if (character_name == "Reaper" and reaper_ult_buff_timer > 0.0) else delta
	if attack_timer > 0.0:
		attack_timer -= cd_delta
		
	if ability_one_timer > 0.0:
		ability_one_timer -= cd_delta

	if ability_two_timer > 0.0:
		ability_two_timer -= cd_delta

	if ability_three_timer > 0.0:
		ability_three_timer -= cd_delta

	if ability_four_timer > 0.0:
		ability_four_timer -= delta

	_update_hud()

	var on_floor = is_on_floor()
	if not on_floor:
		if not is_crashing_down:
			var effective_gravity = gravity * (current_gravity_mult if is_floating else 1.0)
			velocity.y -= effective_gravity * delta
	else:
		if is_floating and float_timer > 0.4:
			end_float_state()

	var stunned = is_stunned()
	var rooted = is_rooted()
	var grounded = is_grounded()
	var slow_mult = get_slow_multiplier()

	# Jump (blocked if stunned, rooted, grounded, channeling, crashing, ult charge)
	if not stunned and not rooted and not grounded and not is_channeling and not is_crashing_down and not is_casting_ability_four and not is_crush_charging and Input.is_action_just_pressed("jump") and on_floor:
		velocity.y = jump_velocity

	# Target direction from input (blocked if stunned, rooted, channeling, or crashing)
	var target_dir := Vector3.ZERO
	if not stunned and not rooted and not is_channeling and not is_crashing_down and not is_casting_ability_four and not is_crush_charging:
		var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		target_dir = Vector3(input_dir.x, 0, input_dir.y).normalized()

	# Dash (Shift) or Crash Down (blocked if grounded)
	if not stunned and not rooted and not grounded and not is_channeling and not is_casting_ability_four and not is_crush_charging and Input.is_action_just_pressed("dash"):
		if can_crash_down():
			_perform_dive_crash_down()
		elif current_dash_charges > 0 and dash_lockout_timer <= 0.0 and not is_crashing_down:
			current_dash_charges -= 1
			dash_lockout_timer = dash_cooldown
			var dash_dir = target_dir if target_dir != Vector3.ZERO else -global_transform.basis.z.normalized()
			var effective_impulse = dash_impulse * slow_mult
			current_dash_speed = effective_impulse
			velocity.x = dash_dir.x * effective_impulse
			velocity.z = dash_dir.z * effective_impulse
			is_dashing = true
			dash_timer = 0.45
			if character_name == "Reaper":
				apply_ethereal(0.45)

	# Crash Down Descent Process
	if is_crashing_down:
		var to_target = crash_target_pos - global_position
		var dist_to_target = to_target.length()
		if on_floor or global_position.y <= (crash_target_pos.y + 0.6) or dist_to_target < 2.0:
			_execute_dive_crash_impact()

	# Momentum & Movement Physics (Existing velocity continues smoothly under physics!)
	if is_crush_charging:
		crush_charge_timer -= delta
		# Limited steering during unstoppable charge
		var aim_info = get_3d_aim_info()
		var target_fwd_2d = Vector2(aim_info.dir.x, aim_info.dir.z).normalized()
		var curr_fwd_2d = Vector2(crush_charge_dir.x, crush_charge_dir.z).normalized()
		if target_fwd_2d.length_squared() > 0.1:
			var target_angle = atan2(-target_fwd_2d.x, -target_fwd_2d.y)
			var current_angle = atan2(-curr_fwd_2d.x, -curr_fwd_2d.y)
			var new_angle = rotate_toward(current_angle, target_angle, CRUSH_CHARGE_TURN_SPEED * delta)
			crush_charge_dir = Vector3(-sin(new_angle), 0, -cos(new_angle)).normalized()
			rotation.y = new_angle

		velocity.x = crush_charge_dir.x * CRUSH_CHARGE_SPEED
		velocity.z = crush_charge_dir.z * CRUSH_CHARGE_SPEED
		
		# Server-authoritative Grab & Wall Collision
		if multiplayer.is_server():
			var hit_enemy = false
			var players_container = get_tree().root.get_node_or_null("Main/Players")
			if players_container:
				for p in players_container.get_children():
					if is_enemy(p) and not p.get("is_dead"):
						var diff = p.global_position - global_position
						if diff.length() <= 3.2 and abs(diff.y) <= 3.0:
							var to_p = Vector2(diff.x, diff.z).normalized()
							var fwd_2d = Vector2(crush_charge_dir.x, crush_charge_dir.z).normalized()
							if fwd_2d.dot(to_p) > 0.15: # On contact with target
								hit_enemy = true
								_execute_crush_slam_sequence_server(p, crush_charge_dir)
								break

			if not hit_enemy and is_crush_charging:
				var hit_wall = false
				for i in range(get_slide_collision_count()):
					var col = get_slide_collision(i)
					var col_obj = col.get_collider()
					if col_obj is StaticBody3D and col_obj.name != "Floor":
						hit_wall = true
						break

				if crush_charge_timer <= 0.0 or hit_wall:
					_finish_crush_charge_empty_server(hit_wall)
	elif not is_crashing_down:
		if is_casting_ability_four and character_name == "Crush":
			velocity.x = 0.0
			velocity.z = 0.0
		elif rooted:
			var current_horizontal = Vector2(velocity.x, velocity.z).move_toward(Vector2.ZERO, ground_friction * 2.5 * delta)
			velocity.x = current_horizontal.x
			velocity.z = current_horizontal.y
		else:
			var current_horizontal = Vector2(velocity.x, velocity.z)
			var current_speed = current_horizontal.length()

			# Effective movement speed calculation with buffs and debuffs
			var effective_max_speed = max_move_speed * slow_mult
			if poke_speed_boost_timer > 0.0:
				effective_max_speed *= (1.0 + poke_speed_boost_percent)
			if dive_ult_buff_timer > 0.0:
				effective_max_speed *= (1.0 + DIVE_ULT_SPEED_MULT)
			if reaper_ms_steal_timer > 0.0:
				effective_max_speed *= (1.0 + reaper_ms_steal_pct)
			if reaper_ult_buff_timer > 0.0:
				effective_max_speed *= (1.0 + REAPER_ULT_MS_MULT)
			if is_crippled():
				effective_max_speed *= (1.0 - cripple_intensity)
			if is_in_nightmare:
				effective_max_speed *= 1.20
			var effective_accel = ground_acceleration * (1.0 + (DIVE_ULT_ATTACK_SPEED_MULT if dive_ult_buff_timer > 0.0 else 0.0))

			if on_floor:
				if target_dir != Vector3.ZERO:
					if current_speed > effective_max_speed:
						current_horizontal = current_horizontal.move_toward(Vector2(target_dir.x, target_dir.z) * effective_max_speed, ground_friction * delta)
					else:
						current_horizontal = current_horizontal.move_toward(Vector2(target_dir.x, target_dir.z) * effective_max_speed, effective_accel * delta)
				else:
					current_horizontal = current_horizontal.move_toward(Vector2.ZERO, ground_friction * delta)
			else:
				if target_dir != Vector3.ZERO:
					if current_speed > effective_max_speed:
						current_horizontal = current_horizontal.move_toward(Vector2(target_dir.x, target_dir.z) * current_speed, air_acceleration * 0.5 * delta)
						current_horizontal = current_horizontal.move_toward(Vector2.ZERO, air_drag * delta)
					else:
						current_horizontal = current_horizontal.move_toward(Vector2(target_dir.x, target_dir.z) * effective_max_speed, air_acceleration * delta)
				else:
					current_horizontal = current_horizontal.move_toward(Vector2.ZERO, air_drag * delta)

			velocity.x = current_horizontal.x
			velocity.z = current_horizontal.y

	aim_at_mouse(delta)

	# Dive Contextual Aerial Crash Down Auto-Indicator
	if character_name == "Dive" and ind_dive_crash_circle and ind_dive_crash_range:
		if can_crash_down():
			var hit_pos = _get_mouse_ground_hit()
			var current_height = max(0.0, global_position.y)
			var max_cast_range = 6.0 + 1.8 * current_height
			var caster_ground = Vector3(global_position.x, 0.04, global_position.z)
			
			ind_dive_crash_range.global_position = caster_ground
			ind_dive_crash_range.scale = Vector3.ONE * (max_cast_range / 6.0)
			ind_dive_crash_range.show()
			
			var target_pos = caster_ground
			if hit_pos != null:
				var diff = hit_pos - caster_ground
				diff.y = 0.0
				var dist = diff.length()
				if dist > max_cast_range:
					target_pos = caster_ground + diff.normalized() * max_cast_range
				else:
					target_pos = hit_pos
					target_pos.y = 0.04
			else:
				var fwd = -global_transform.basis.z.normalized()
				fwd.y = 0.0
				target_pos = caster_ground + fwd.normalized() * max_cast_range
				target_pos.y = 0.04
				
			ind_dive_crash_circle.global_position = target_pos
			ind_dive_crash_circle.show()
		else:
			ind_dive_crash_circle.hide()
			ind_dive_crash_range.hide()

	# Poke Q Acceleration Field Zone Indicator Update (Short Target Range)
	if character_name == "Poke" and is_holding_ability_two and ind_poke_dot_zone:
		var hit_pos = _get_mouse_ground_hit()
		var spawn_pos = Vector3(global_position.x, 0.04, global_position.z)
		var target_pos = spawn_pos + (-global_transform.basis.z.normalized()) * 3.5
		target_pos.y = 0.04
		if hit_pos != null:
			var diff = hit_pos - spawn_pos
			diff.y = 0.0
			var dist = clamp(diff.length(), 0.5, 6.0)
			if diff.length_squared() > 0.01:
				target_pos = spawn_pos + diff.normalized() * dist
				target_pos.y = 0.04
		ind_poke_dot_zone.global_position = target_pos

	# Poke E Flare Targeting Indicator Update
	if character_name == "Poke" and is_holding_ability_three and ind_poke_flare_circle:
		var hit_pos = _get_mouse_ground_hit()
		var spawn_pos = Vector3(global_position.x, 0.04, global_position.z)
		var target_pos = spawn_pos + (-global_transform.basis.z.normalized()) * 45.0
		target_pos.y = 0.04
		if hit_pos != null:
			var diff = hit_pos - spawn_pos
			diff.y = 0.0
			var dist = clamp(diff.length(), 6.0, 65.0)
			if diff.length_squared() > 0.1:
				target_pos = spawn_pos + diff.normalized() * dist
				target_pos.y = 0.04
		ind_poke_flare_circle.global_position = target_pos

	# Combat Inputs: Hold to Preview Hitbox / Cast on Release
	if stunned or is_dead or is_channeling or is_crashing_down:
		_cancel_all_hold_indicators()
	else:
		# Primary Attack [LMB] - Fires immediately on press/hold with no preview indicator
		if Input.is_action_pressed("shoot") and attack_timer <= 0.0 and not is_casting_melee and not is_casting_ability_one and not is_casting_ability_two and not is_casting_ability_three and not is_channeling and not is_crashing_down and not is_in_nightmare:
			if character_name == "Reaper":
				_perform_reaper_melee()
			elif character_name == "Dive":
				_perform_dive_melee()
			elif is_melee_character:
				_perform_crush_melee_windup()
			else:
				_perform_poke_ranged_attack()

		# Ability One [RMB]
		if Input.is_action_just_pressed("ability_one") and ability_one_timer <= 0.0 and not is_casting_melee and not is_casting_ability_one and not is_casting_ability_two and not is_casting_ability_three and not is_in_nightmare:
			is_holding_ability_one = true
			if ind_ability_one:
				ind_ability_one.show()

		if is_holding_ability_one:
			if not Input.is_action_pressed("ability_one"):
				is_holding_ability_one = false
				if ind_ability_one:
					ind_ability_one.hide()
				if ability_one_timer <= 0.0 and not is_casting_melee and not is_casting_ability_one and not is_casting_ability_two and not is_casting_ability_three and not is_in_nightmare and (not stunned or can_cast_while_stunned) and not is_channeling and not is_crashing_down:
					_perform_ability_one()

		# Ability Two [Q]
		if Input.is_action_just_pressed("ability_two") and ability_two_timer <= 0.0 and not is_casting_melee and not is_casting_ability_one and not is_casting_ability_two and not is_casting_ability_three and not is_in_nightmare:
			is_holding_ability_two = true
			if ind_ability_two:
				ind_ability_two.show()
			if ind_poke_dot_zone:
				ind_poke_dot_zone.show()

		if is_holding_ability_two:
			if not Input.is_action_pressed("ability_two"):
				is_holding_ability_two = false
				if ind_ability_two:
					ind_ability_two.hide()
				if ind_poke_dot_zone:
					ind_poke_dot_zone.hide()
				if ability_two_timer <= 0.0 and not is_casting_melee and not is_casting_ability_one and not is_casting_ability_two and not is_casting_ability_three and not is_in_nightmare and (not stunned or can_cast_while_stunned) and not is_channeling and not is_crashing_down:
					_perform_ability_two()

		# Ability Three [E]
		if Input.is_action_just_pressed("ability_three") and (ability_three_timer <= 0.0 or (character_name == "Dive" and is_blocking)) and not is_casting_melee and not is_casting_ability_one and not is_casting_ability_two and not is_casting_ability_three and not is_casting_ability_four and not is_silenced():
			if character_name == "Poke":
				is_holding_ability_three = true
				if ind_ability_three:
					ind_ability_three.show()
				if ind_poke_flare_circle:
					ind_poke_flare_circle.show()
			else:
				_perform_ability_three()

		if is_holding_ability_three:
			if not Input.is_action_pressed("ability_three"):
				is_holding_ability_three = false
				if ind_ability_three:
					ind_ability_three.hide()
				if ind_poke_flare_circle:
					ind_poke_flare_circle.hide()
				if ability_three_timer <= 0.0 and not is_casting_melee and not is_casting_ability_one and not is_casting_ability_two and not is_casting_ability_three and not is_casting_ability_four and (not stunned or can_cast_while_stunned) and not is_channeling and not is_crashing_down and not is_silenced():
					_perform_ability_three()

		# Ultimate Ability [R]
		# Dive's Ult can be cast while CC'd (except Silence) and cleanses CC!
		if character_name == "Dive":
			if Input.is_action_just_pressed("ability_four") and ability_four_timer <= 0.0 and not is_silenced() and not is_dead and not is_casting_ability_four:
				_perform_ability_four()
		elif character_name == "Reaper":
			if Input.is_action_just_pressed("ability_four") and ability_four_timer <= 0.0 and not is_silenced() and not stunned and not is_dead and not is_channeling and not is_crashing_down and not is_casting_melee and not is_casting_ability_one and not is_casting_ability_two and not is_casting_ability_three and not is_casting_ability_four:
				_perform_ability_four()
		else:
			if Input.is_action_just_pressed("ability_four") and ability_four_timer <= 0.0 and not is_silenced() and not stunned and not is_dead and not is_channeling and not is_crashing_down and not is_casting_melee and not is_casting_ability_one and not is_casting_ability_two and not is_casting_ability_three and not is_casting_ability_four:
				if character_name in ["Crush", "Poke"]:
					is_holding_ability_four = true
					if ind_ability_four:
						ind_ability_four.show()
				else:
					_perform_ability_four()

		if is_holding_ability_four:
			if not Input.is_action_pressed("ability_four"):
				is_holding_ability_four = false
				if ind_ability_four:
					ind_ability_four.hide()
				if ability_four_timer <= 0.0 and not is_silenced() and not stunned and not is_dead and not is_channeling and not is_crashing_down:
					_perform_ability_four()

	var pre_move_velocity = velocity
	move_and_slide()

	# High-Velocity Wall Impact Damage System (Calculated from knockback_velocity from external sources)
	if knockback_velocity.length_squared() > 1.0 and wall_impact_cooldown_timer <= 0.0 and not is_dead:
		for i in range(get_slide_collision_count()):
			var col = get_slide_collision(i)
			var normal = col.get_normal()
			
			# Check if surface is a steep wall / barrier (not flat walkable floor)
			if normal.y < 0.7:
				# Calculate component of knockback velocity directly into the wall
				var velocity_into_wall = -knockback_velocity.dot(normal)
				
				if velocity_into_wall >= WALL_IMPACT_MIN_SPEED:
					knockback_velocity = Vector3.ZERO # Consumed on wall impact
					wall_impact_cooldown_timer = 0.35 # Prevent multi-hit per collision event
					var excess_speed = velocity_into_wall - WALL_IMPACT_MIN_SPEED
					var wall_damage = 10.0 + excess_speed * WALL_IMPACT_DAMAGE_FACTOR
					
					show_wall_impact_effect.rpc(col.get_position(), normal)
					
					if multiplayer.is_server():
						take_damage(wall_damage)
					else:
						request_wall_impact_damage.rpc_id(1, wall_damage, velocity_into_wall)
					break

	# Dive Dash Terrain Wall Bounce Check
	if is_dashing and character_name == "Dive" and not is_floating and not is_crashing_down:
		var has_collided = false
		for i in range(get_slide_collision_count()):
			var col = get_slide_collision(i)
			var normal = col.get_normal()
			
			# Terrain angle conversion rule:
			# Converts 100% of horizontal velocity at 90 degree angle (vertical wall: normal.y == 0.0).
			# Decreases as angle increases (points up more: normal.y > 0.0) -> conversion = (1.0 - normal.y).
			# Goes to 0 at everything below 90 (overhang/ceiling: normal.y < 0.0) -> conversion = 0.0.
			# (Flat floor has normal.y == 1.0 -> conversion = 0.0).
			if normal.y >= 0.0 and normal.y < 0.98:
				var incoming_h = Vector2(pre_move_velocity.x, pre_move_velocity.z)
				var speed_h = max(incoming_h.length(), current_dash_speed)
				var conversion = clamp(1.0 - normal.y, 0.0, 1.0)
				if conversion > 0.0 and speed_h > 0.5:
					var upward_v = speed_h * conversion
					velocity.y = upward_v
					velocity.x = 0.0
					velocity.z = 0.0
					is_dashing = false
					dash_timer = 0.0
					has_collided = true
					start_float_state()
					break
		
		# Fallback wall check if collision count was already processed
		if not has_collided and is_on_wall():
			var normal = get_wall_normal()
			if normal.y >= 0.0 and normal.y < 0.98:
				var incoming_h = Vector2(pre_move_velocity.x, pre_move_velocity.z)
				var speed_h = max(incoming_h.length(), current_dash_speed)
				var conversion = clamp(1.0 - normal.y, 0.0, 1.0)
				if conversion > 0.0 and speed_h > 0.5:
					var upward_v = speed_h * conversion
					velocity.y = upward_v
					velocity.x = 0.0
					velocity.z = 0.0
					is_dashing = false
					dash_timer = 0.0
					start_float_state()

func _update_hud() -> void:
	# Status Effects CC & Passive Display above hotbar
	if status_cc_label:
		if is_channeling:
			status_cc_label.text = "⏳ CHANNELING (%.1fs) ⏳" % channel_timer
			status_cc_label.modulate = Color(0.2, 0.95, 0.95)
		elif is_floating:
			status_cc_label.text = "☁ FLOAT (%.1fs - Gravity: %d%%) ☁" % [max(0.0, FLOAT_TOTAL_DURATION - float_timer), int(current_gravity_mult * 100)]
			status_cc_label.modulate = Color(0.85, 0.5, 1.0)
		elif dive_marks_count > 0:
			status_cc_label.text = "✦ RUPTURE MARKS: %d/5 (%.1fs) ✦" % [dive_marks_count, dive_mark_timer]
			status_cc_label.modulate = Color(1.0, 0.25, 0.9)
		elif is_in_nightmare:
			status_cc_label.text = "🌑 NIGHTMARE (%.1fs - INVULNERABLE) 🌑" % reaper_nightmare_timer
			status_cc_label.modulate = Color(0.65, 0.2, 0.95)
		elif reaper_ult_buff_timer > 0.0 and character_name == "Reaper":
			status_cc_label.text = "💀 ONE WITH DEATH (%.1fs - +45%% MS / +30%% DMG / 50%% CDR) 💀" % reaper_ult_buff_timer
			status_cc_label.modulate = Color(0.75, 0.15, 1.0)
		elif reaper_tether_active:
			status_cc_label.text = "⛓️ SPECTRAL TETHER (%.1fs) ⛓️" % reaper_tether_timer
			status_cc_label.modulate = Color(0.2, 1.0, 0.8)
		elif is_rooted():
			status_cc_label.text = "⛓️ ROOTED (%.1fs) ⛓️" % root_timer
			status_cc_label.modulate = Color(1.0, 0.3, 0.3)
		elif is_grounded():
			status_cc_label.text = "🛑 GROUNDED (%.1fs) 🛑" % grounded_timer
			status_cc_label.modulate = Color(1.0, 0.5, 0.2)
		elif is_crippled():
			status_cc_label.text = "🩸 CRIPPLED -%d%% MS/AS (%.1fs) 🩸" % [int(cripple_intensity * 100), cripple_timer]
			status_cc_label.modulate = Color(0.9, 0.2, 0.4)
		elif is_stunned() and is_slowed():
			status_cc_label.text = "★ STUNNED (%.1fs) | SLOWED -%d%% (%.1fs) ★" % [stun_timer, int(slow_percent * 100), slow_timer]
			status_cc_label.modulate = Color(1.0, 0.3, 0.3)
		elif is_stunned():
			status_cc_label.text = "★ STUNNED (%.1fs) ★" % stun_timer
			status_cc_label.modulate = Color(1.0, 0.35, 0.35)
		elif is_slowed():
			status_cc_label.text = "▼ SLOWED -%d%% (%.1fs) ▼" % [int(slow_percent * 100), slow_timer]
			status_cc_label.modulate = Color(0.35, 0.85, 1.0)
		elif is_blocking:
			status_cc_label.text = "🛡 DEFLECTING GUARD (%.1fs - 75%% FRONT DR) 🛡" % block_timer
			status_cc_label.modulate = Color(0.2, 0.85, 1.0)
		elif poke_speed_boost_timer > 0.0:
			status_cc_label.text = "⚡ FLEET FOOT (+15%% MS) (%.1fs) ⚡" % poke_speed_boost_timer
			status_cc_label.modulate = Color(0.2, 1.0, 0.9)
		elif reaper_ms_steal_timer > 0.0:
			status_cc_label.text = "⚡ SOUL STEAL (+15%% MS) (%.1fs) ⚡" % reaper_ms_steal_timer
			status_cc_label.modulate = Color(0.3, 1.0, 0.75)
		elif character_name == "Crush" and gray_health > 0.0:
			status_cc_label.text = "♥ GRAY HEALTH: %d HP (PRESS E) ♥" % int(gray_health)
			status_cc_label.modulate = Color(0.75, 0.8, 0.85)
		elif is_crush_empowered and character_name == "Crush":
			status_cc_label.text = "★ TITAN'S SURGE READY (+25 DMG / HEAL) ★"
			status_cc_label.modulate = Color(1.0, 0.8, 0.15)
		elif poke_ult_buff_timer > 0.0 and character_name == "Poke":
			status_cc_label.text = "✦ EMPOWERED PIERCING LANCE (%.1fs) ✦" % poke_ult_buff_timer
			status_cc_label.modulate = Color(0.2, 0.95, 1.0)
		else:
			status_cc_label.text = ""

	# Ability One [RMB]
	if slot_ability_one:
		var disabled = (is_stunned() and not can_cast_while_stunned) or is_silenced()
		var active = is_casting_ability_one or is_channeling or (character_name == "Reaper" and reaper_tether_active)
		var custom_txt = "LOCK" if disabled else ("TETHER" if (character_name == "Reaper" and reaper_tether_active) else ("CAST" if is_casting_ability_one else ""))
		slot_ability_one.set_cooldown_state(ability_one_timer, ability_one_cooldown, -1, -1, disabled, active, custom_txt)

	# Ability Two [Q]
	if slot_ability_two:
		var disabled = (is_stunned() and not can_cast_while_stunned) or is_silenced()
		var active = is_casting_ability_two
		var custom_txt = "LOCK" if disabled else ("CULL" if (character_name == "Reaper" and is_casting_ability_two) else ("CAST" if is_casting_ability_two else ""))
		slot_ability_two.set_cooldown_state(ability_two_timer, ability_two_cooldown, -1, -1, disabled, active, custom_txt)

	# Ability Three [E]
	if slot_ability_three:
		var disabled = (is_stunned() and not can_cast_while_stunned) or is_silenced()
		var active = is_casting_ability_three or (character_name == "Dive" and is_blocking) or (character_name == "Reaper" and is_in_nightmare)
		var custom_txt = ""
		if character_name == "Dive" and is_blocking:
			custom_txt = "GUARD"
		elif character_name == "Reaper" and is_in_nightmare:
			custom_txt = "POOL"
		elif disabled:
			custom_txt = "LOCK"
		elif is_casting_ability_three:
			custom_txt = "CAST"
		slot_ability_three.set_cooldown_state(ability_three_timer, ability_three_cooldown, -1, -1, disabled, active, custom_txt)

	# Ultimate [R]
	if slot_ability_four:
		var disabled = is_silenced() or (is_stunned() and character_name != "Dive")
		var active = is_casting_ability_four or is_crush_charging or dive_ult_buff_timer > 0.0 or (character_name == "Poke" and poke_ult_buff_timer > 0.0) or (character_name == "Reaper" and reaper_ult_buff_timer > 0.0)
		var custom_txt = ""
		if is_crush_charging:
			custom_txt = "CHARGE"
		elif dive_ult_buff_timer > 0.0:
			custom_txt = "SURGE"
		elif character_name == "Poke" and poke_ult_buff_timer > 0.0:
			custom_txt = "EAGLE"
		elif character_name == "Reaper" and reaper_ult_buff_timer > 0.0:
			custom_txt = "DEATH"
		elif disabled:
			custom_txt = "LOCK"
		elif is_casting_ability_four:
			custom_txt = "CAST"
		slot_ability_four.set_cooldown_state(ability_four_timer, ability_four_cooldown, -1, -1, disabled, active, custom_txt)

	# Dash [Shift]
	if slot_dash:
		var disabled = is_stunned() or is_silenced() or is_grounded()
		var active = is_crashing_down or can_crash_down() or (character_name == "Reaper" and is_ethereal_active())
		var custom_txt = ""
		var timer = 0.0
		var max_cd = dash_cooldown
		var charges = current_dash_charges
		var max_chg = max_dash_charges

		if can_crash_down():
			custom_txt = "CRASH"
		elif is_crashing_down:
			custom_txt = "SLAM"
		elif character_name == "Reaper" and is_ethereal_active():
			custom_txt = "PHASE"
		elif max_dash_charges > 1:
			var remaining_recharge = max(0.0, dash_recharge_time - dash_recharge_timer)
			if current_dash_charges == 0:
				timer = remaining_recharge
				max_cd = dash_recharge_time
			elif dash_lockout_timer > 0.0:
				timer = dash_lockout_timer
				max_cd = dash_cooldown
			elif current_dash_charges < max_dash_charges:
				timer = remaining_recharge
				max_cd = dash_recharge_time
			else:
				timer = 0.0
				max_cd = dash_recharge_time
		else:
			var remaining = max(0.0, dash_recharge_time - dash_recharge_timer) if current_dash_charges == 0 else dash_lockout_timer
			if current_dash_charges > 0 and dash_lockout_timer <= 0.0:
				timer = 0.0
			else:
				timer = remaining
			max_cd = dash_cooldown

		if disabled:
			custom_txt = "LOCK"

		slot_dash.set_cooldown_state(timer, max_cd, charges, max_chg, disabled, active, custom_txt)

func _perform_poke_ranged_attack() -> void:
	var actual_windup = windup_time
	if actual_windup > 0.0:
		await get_tree().create_timer(actual_windup).timeout

	attack_timer = attack_cooldown
	var is_empowered = (poke_ult_buff_timer > 0.0)
	if is_empowered:
		poke_ult_buff_timer = 0.0
		sync_poke_ult_buff.rpc(0.0)
		attack_performed.emit("Empowered Piercing Lance")
	else:
		attack_performed.emit("Rail Shot")

	var aim_info = get_3d_aim_info()
	var shoot_dir = aim_info.dir
	var spawn_pos = global_position + Vector3(0, 0.85, 0) + shoot_dir * 1.1
	var max_range: float = 95.0 if is_empowered else 50.0
	var speed: float = 95.0 if is_empowered else projectile_speed
	var size: float = 1.3 if is_empowered else projectile_size
	var proj_life: float = max_range / speed
	var eff_type: String = "execute_scaling" if is_empowered else ""
	var pierces: bool = is_empowered
	
	if multiplayer.is_server():
		get_tree().root.get_node("Main").spawn_projectile(spawn_pos, shoot_dir, name.to_int(), projectile_damage, speed, size, proj_life, eff_type, 0.0, 0.0, pierces, false, 0, ActionType.ATTACK, max_range)
	else:
		request_fire.rpc_id(1, spawn_pos, shoot_dir, projectile_damage, speed, size, proj_life, ActionType.ATTACK, eff_type, pierces, max_range)

func _perform_reaper_melee() -> void:
	var cd = attack_cooldown
	if is_crippled():
		cd *= 1.5
	attack_timer = cd
	attack_performed.emit("Reaper's Scythe")
	show_melee_effect.rpc(true)
	get_tree().create_timer(0.18).timeout.connect(func(): show_melee_effect.rpc(false))
	
	var facing_dir = -global_transform.basis.z.normalized()
	var dmg = melee_damage
	if reaper_ult_buff_timer > 0.0:
		dmg *= REAPER_ULT_DMG_MULT
	if multiplayer.is_server():
		execute_reaper_melee_hit_on_server(global_position, facing_dir, name.to_int(), dmg, melee_size, melee_angle_deg)
	else:
		request_reaper_melee_strike.rpc_id(1, global_position, facing_dir, dmg, melee_size, melee_angle_deg)

@rpc("any_peer", "call_remote", "reliable")
func request_reaper_melee_strike(origin_pos: Vector3, forward_dir: Vector3, dmg: float, size: float, angle_deg: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	execute_reaper_melee_hit_on_server(origin_pos, forward_dir, sender_id, dmg, size, angle_deg)

func execute_reaper_melee_hit_on_server(origin_pos: Vector3, forward_dir: Vector3, attacker_id: int, dmg: float, size: float, angle_deg: float) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	
	var fwd_2d = Vector2(forward_dir.x, forward_dir.z).normalized()
	var hit_any = false
	
	for player in players_container.get_children():
		if is_enemy(player) and not player.get("is_dead"):
			var diff = player.global_position - origin_pos
			var diff_2d = Vector2(diff.x, diff.z)
			var dist = diff_2d.length()
			
			if abs(diff.y) <= (melee_height * 0.5) and dist <= size:
				var to_target_2d = diff_2d.normalized()
				var angle = rad_to_deg(fwd_2d.angle_to(to_target_2d))
				if abs(angle) <= (angle_deg * 0.5):
					hit_any = true
					player.take_damage(dmg, attacker_id, ActionType.ATTACK)
					if player.has_method("apply_slow"):
						player.apply_slow(2.5, 0.15)
					if player.has_method("apply_knockback"):
						var kb_dir = Vector3(forward_dir.x, 0.15, forward_dir.z).normalized()
						player.apply_knockback(kb_dir * 6.0)

	if hit_any:
		var attacker = players_container.get_node_or_null(str(attacker_id))
		if attacker and attacker.has_method("apply_reaper_ms_steal"):
			attacker.apply_reaper_ms_steal(2.5, 0.15)

func _perform_dive_melee() -> void:
	attack_timer = attack_cooldown
	attack_performed.emit("Slash")
	show_melee_effect.rpc(true)
	get_tree().create_timer(0.18).timeout.connect(func(): show_melee_effect.rpc(false))
	
	var facing_dir = -global_transform.basis.z.normalized()
	if multiplayer.is_server():
		execute_dive_melee_hit_on_server(global_position, facing_dir, name.to_int(), melee_damage, melee_size, melee_angle_deg)
	else:
		request_dive_melee_strike.rpc_id(1, global_position, facing_dir, melee_damage, melee_size, melee_angle_deg)

func _perform_crush_melee_windup() -> void:
	is_casting_melee = true
	var actual_windup = windup_time if windup_time > 0.0 else melee_windup_time
	attack_timer = attack_cooldown + actual_windup
	attack_performed.emit("Slam")
	
	var was_empowered = is_crush_empowered
	set_crush_empowered(false) # Consumed whether it hits or not
	
	show_melee_effect.rpc(true)
	await get_tree().create_timer(actual_windup).timeout
	is_casting_melee = false
	show_melee_effect.rpc(false)
	
	var facing_dir = -global_transform.basis.z.normalized()
	if multiplayer.is_server():
		execute_melee_hit_on_server(global_position, facing_dir, name.to_int(), melee_damage, melee_size, melee_angle_deg, was_empowered)
	else:
		request_melee_strike.rpc_id(1, global_position, facing_dir, melee_damage, melee_size, melee_angle_deg, was_empowered)

func start_float_state() -> void:
	is_floating = true
	float_timer = 0.0
	current_gravity_mult = 1.0
	if multiplayer.is_server():
		sync_float_state.rpc(true)

func end_float_state() -> void:
	is_floating = false
	float_timer = 0.0
	current_gravity_mult = 1.0
	if multiplayer.is_server():
		sync_float_state.rpc(false)

@rpc("any_peer", "call_local", "reliable")
func sync_float_state(floating: bool) -> void:
	is_floating = floating
	if not floating:
		float_timer = 0.0
		current_gravity_mult = 1.0

func can_crash_down() -> bool:
	return character_name == "Dive" and is_floating and not is_crashing_down

func _perform_dive_crash_down() -> void:
	var hit_pos = _get_mouse_ground_hit()
	var current_height = max(0.0, global_position.y)
	var max_cast_range = 6.0 + 1.8 * current_height
	
	var target_pos = global_position
	target_pos.y = 0.0
	
	if hit_pos != null:
		var diff = hit_pos - global_position
		diff.y = 0.0
		var dist = diff.length()
		if dist > max_cast_range:
			target_pos = global_position + diff.normalized() * max_cast_range
			target_pos.y = 0.0
		else:
			target_pos = hit_pos
			target_pos.y = 0.0
	else:
		var fwd = -global_transform.basis.z.normalized()
		target_pos = global_position + fwd * max_cast_range
		target_pos.y = 0.0
	
	is_crashing_down = true
	crash_target_pos = target_pos
	is_floating = false
	current_gravity_mult = 1.0
	
	var to_target = (crash_target_pos - global_position)
	var crash_speed = 52.0
	velocity = to_target.normalized() * crash_speed

func _execute_dive_crash_impact() -> void:
	is_crashing_down = false
	velocity = Vector3.ZERO
	
	var impact_pos = global_position
	impact_pos.y = 0.0
	
	show_crash_impact_effect.rpc(impact_pos)
	
	if multiplayer.is_server():
		execute_crash_down_impact_on_server(impact_pos, name.to_int())
	else:
		request_crash_down_impact.rpc_id(1, impact_pos)

# --- Ability One (RMB) ---
func _perform_ability_one() -> void:
	if character_name == "Crush":
		_perform_crush_ability_one()
	elif character_name == "Dive":
		_perform_dive_ability_one()
	elif character_name == "Reaper":
		_perform_reaper_ability_one()
	else:
		_perform_poke_ability_one()

func _perform_reaper_ability_one() -> void:
	var def = _ability_definitions.get("RMB", AbilitiesLibrary.get_ability("reaper_tether"))
	ability_one_timer = def.cooldown if def else ability_one_cooldown
	ability_cast.emit(def.name if def else "Spectral Tether", "RMB")
	
	var aim_info = get_3d_aim_info()
	var shoot_dir = aim_info.dir
	var spawn_pos = global_position + Vector3(0, 0.85, 0) + shoot_dir * 1.1
	
	var tether_dmg: float = 25.0
	var tether_spd: float = 48.0
	var tether_size: float = 0.6
	var max_range: float = 16.0
	if reaper_ult_buff_timer > 0.0:
		tether_dmg *= REAPER_ULT_DMG_MULT
	
	var tether_life = max_range / tether_spd
	
	show_ability_one_visual.rpc(true)
	get_tree().create_timer(0.2).timeout.connect(func(): show_ability_one_visual.rpc(false))
	
	if multiplayer.is_server():
		get_tree().root.get_node("Main").spawn_projectile(spawn_pos, shoot_dir, name.to_int(), tether_dmg, tether_spd, tether_size, tether_life, "reaper_tether", 1.75, 0.0, false, false, 0, ActionType.ABILITY, max_range)
	else:
		request_reaper_tether_fire.rpc_id(1, spawn_pos, shoot_dir, tether_dmg, tether_spd, tether_size, tether_life, max_range)

@rpc("any_peer", "call_remote", "reliable")
func request_reaper_tether_fire(spawn_pos: Vector3, shoot_dir: Vector3, dmg: float, spd: float, p_size: float, life: float, max_rng: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	get_tree().root.get_node("Main").spawn_projectile(spawn_pos, shoot_dir, sender_id, dmg, spd, p_size, life, "reaper_tether", 1.75, 0.0, false, false, 0, ActionType.ABILITY, max_rng)

func start_reaper_tether_server(target_node: Node) -> void:
	if not multiplayer.is_server() or not is_instance_valid(target_node):
		return
	reaper_tether_active = true
	reaper_tether_target_id = target_node.name.to_int()
	reaper_tether_timer = 1.75
	if target_node.has_method("apply_grounded"):
		target_node.apply_grounded(1.75)
	if target_node.has_method("apply_slow"):
		target_node.apply_slow(1.75, 0.25)
	sync_reaper_tether_state.rpc(true, reaper_tether_target_id)

func end_reaper_tether_server(completed: bool, target_node: Node = null) -> void:
	if not multiplayer.is_server():
		return
	reaper_tether_active = false
	var target_id = reaper_tether_target_id
	reaper_tether_target_id = 0
	reaper_tether_timer = 0.0
	sync_reaper_tether_state.rpc(false, 0)
	
	if completed:
		if not target_node:
			var players_container = get_tree().root.get_node_or_null("Main/Players")
			target_node = players_container.get_node_or_null(str(target_id)) if players_container else null
		if is_instance_valid(target_node) and not target_node.get("is_dead"):
			var root_dur = 1.25
			var bonus_dmg = 25.0 * (REAPER_ULT_DMG_MULT if reaper_ult_buff_timer > 0.0 else 1.0)
			target_node.take_damage(bonus_dmg, name.to_int(), ActionType.ABILITY)
			if target_node.has_method("apply_root"):
				target_node.apply_root(root_dur)
			if target_node.has_method("apply_knockback"):
				var pull_dir = (global_position - target_node.global_position).normalized()
				target_node.apply_knockback(pull_dir * 10.0 + Vector3.UP * 4.0)

@rpc("any_peer", "call_local", "reliable")
func sync_reaper_tether_state(active: bool, target_id: int) -> void:
	reaper_tether_active = active
	reaper_tether_target_id = target_id

func _perform_poke_ability_one() -> void:
	var def = _ability_definitions.get("RMB", AbilitiesLibrary.get_ability("poke_repulsor_bolt"))
	ability_one_timer = def.cooldown if def else ability_one_cooldown
	ability_cast.emit(def.name if def else "Repulsor Bolt", "RMB")
	var aim_info = get_3d_aim_info()
	var shoot_dir = aim_info.dir
	var spawn_pos = global_position + Vector3(0, 0.85, 0) + shoot_dir * 1.1
	
	var bolt_dmg: float = 20.0
	var bolt_spd: float = 85.0
	var bolt_size: float = 0.35
	var max_range: float = 60.0
	var stun_dur: float = 1.0
	var kb_force: float = 36.0
	
	if def and def.effect:
		bolt_spd = def.effect.speed
		bolt_size = def.effect.projectile_size
		max_range = def.effect.max_range
		for r in def.riders:
			if r.rider_type == AbilityPipeline.RiderType.DAMAGE:
				bolt_dmg = r.amount
			elif r.rider_type == AbilityPipeline.RiderType.KNOCKBACK:
				kb_force = r.amount
			elif r.rider_type == AbilityPipeline.RiderType.STUN:
				stun_dur = r.duration
	
	var bolt_life: float = max_range / bolt_spd
	
	if multiplayer.is_server():
		get_tree().root.get_node("Main").spawn_projectile(spawn_pos, shoot_dir, name.to_int(), bolt_dmg, bolt_spd, bolt_size, bolt_life, "knockback_stun", stun_dur, kb_force, false, false, 0, ActionType.ABILITY, max_range)
	else:
		request_fire_ability_one.rpc_id(1, spawn_pos, shoot_dir, bolt_dmg, bolt_spd, bolt_size, bolt_life, "knockback_stun", stun_dur, kb_force, ActionType.ABILITY, max_range)

func _perform_dive_ability_one() -> void:
	var def = _ability_definitions.get("RMB", AbilitiesLibrary.get_ability("dive_heavy_cleave"))
	is_casting_ability_one = true
	var windup_delay = def.effect.windup_time if (def and def.effect) else 0.18
	ability_one_timer = (def.cooldown if def else ability_one_cooldown) + windup_delay
	ability_cast.emit(def.name if def else "Heavy Cleave", "RMB")
	
	show_ability_one_visual.rpc(true)
	await get_tree().create_timer(windup_delay).timeout
	is_casting_ability_one = false
	show_ability_one_visual.rpc(false)
	
	var facing_dir = -global_transform.basis.z.normalized()
	var heavy_dmg: float = 65.0
	var heavy_size: float = 3.0
	var heavy_angle: float = 135.0
	if def and def.hitbox:
		heavy_size = def.hitbox.radius
		heavy_angle = def.hitbox.angle_deg
	if def:
		for r in def.riders:
			if r.rider_type == AbilityPipeline.RiderType.DAMAGE:
				heavy_dmg = r.amount
	
	if multiplayer.is_server():
		execute_dive_ability_one_on_server(global_position, facing_dir, 1, heavy_dmg, heavy_size, heavy_angle)
	else:
		request_dive_ability_one.rpc_id(1, global_position, facing_dir, heavy_dmg, heavy_size, heavy_angle)

func _perform_crush_ability_one() -> void:
	var def = _ability_definitions.get("RMB", AbilitiesLibrary.get_ability("crush_fan_stun"))
	is_casting_ability_one = true
	var windup_delay = def.effect.windup_time if (def and def.effect) else 0.16
	ability_one_timer = (def.cooldown if def else ability_one_cooldown) + windup_delay
	ability_cast.emit(def.name if def else "Fan Stun", "RMB")
	
	show_ability_one_visual.rpc(true)
	await get_tree().create_timer(windup_delay).timeout
	is_casting_ability_one = false
	show_ability_one_visual.rpc(false)
	
	set_crush_empowered(true) # Titan's Surge Passive Activation
	
	var facing_dir = -global_transform.basis.z.normalized()
	if multiplayer.is_server():
		execute_crush_fan_stun_on_server(global_position, facing_dir, name.to_int())
	else:
		request_crush_fan_stun.rpc_id(1, global_position, facing_dir)

# --- Ability Two (Q) ---
func _perform_ability_two() -> void:
	if character_name == "Crush":
		_perform_crush_ability_two()
	elif character_name == "Dive":
		_perform_dive_ability_two()
	elif character_name == "Reaper":
		_perform_reaper_ability_two()
	else:
		_perform_poke_ability_two()

func _perform_reaper_ability_two() -> void:
	var def = _ability_definitions.get("Q", AbilitiesLibrary.get_ability("reaper_cull_the_weak"))
	var windup = def.effect.windup_time if (def and def.effect) else 0.40
	ability_two_timer = (def.cooldown if def else ability_two_cooldown) + windup
	is_casting_ability_two = true
	ability_cast.emit(def.name if def else "Cull the Weak", "Q")
	
	show_ability_two_visual.rpc(true)
	await get_tree().create_timer(windup).timeout
	is_casting_ability_two = false
	show_ability_two_visual.rpc(false)
	
	if is_dead:
		return
		
	var mult = REAPER_ULT_DMG_MULT if reaper_ult_buff_timer > 0.0 else 1.0
	var inner_dmg = 30.0 * mult
	var outer_dmg = 65.0 * mult
	var inner_radius = 3.2
	var outer_radius = 5.5
	
	if multiplayer.is_server():
		execute_reaper_cull_on_server(global_position, name.to_int(), inner_dmg, outer_dmg, inner_radius, outer_radius)
	else:
		request_reaper_cull.rpc_id(1, global_position, inner_dmg, outer_dmg, inner_radius, outer_radius)

@rpc("any_peer", "call_remote", "reliable")
func request_reaper_cull(origin_pos: Vector3, in_dmg: float, out_dmg: float, in_rad: float, out_rad: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	execute_reaper_cull_on_server(origin_pos, sender_id, in_dmg, out_dmg, in_rad, out_rad)

func execute_reaper_cull_on_server(origin_pos: Vector3, attacker_id: int, in_dmg: float, out_dmg: float, in_rad: float, out_rad: float) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	
	for player in players_container.get_children():
		if is_enemy(player) and not player.get("is_dead"):
			var diff = player.global_position - origin_pos
			var dist = Vector2(diff.x, diff.z).length()
			if abs(diff.y) <= 2.4 and dist <= out_rad:
				if dist >= in_rad:
					# Sweet spot hit!
					player.take_damage(out_dmg, attacker_id, ActionType.ABILITY)
					if player.has_method("apply_cripple"):
						player.apply_cripple(2.5, 0.35)
					if player.has_method("apply_slow"):
						player.apply_slow(2.5, 0.35)
					if player.has_method("apply_knockback"):
						var push_dir = Vector3(diff.x, 0.15, diff.z).normalized()
						player.apply_knockback(push_dir * 8.0)
				else:
					# Inner handle hit
					player.take_damage(in_dmg, attacker_id, ActionType.ABILITY)

func _perform_crush_ability_two() -> void:
	var def = _ability_definitions.get("Q", AbilitiesLibrary.get_ability("crush_ground_stomp"))
	ability_two_timer = def.cooldown if def else ability_two_cooldown
	is_casting_ability_two = true
	ability_cast.emit(def.name if def else "Ground Stomp", "Q")
	
	# Grant Crush a temporary shield
	var shld_amt = 40.0
	var shld_dur = 5.0
	if def:
		for r in def.riders:
			if r.rider_type == AbilityPipeline.RiderType.SHIELD:
				shld_amt = r.amount
				shld_dur = r.duration
	apply_shield(shld_amt, shld_dur)
	set_crush_empowered(true) # Titan's Surge Passive Activation
	
	var windup = def.effect.windup_time if (def and def.effect) else 0.3
	show_ability_two_visual.rpc(true)
	get_tree().create_timer(windup).timeout.connect(func():
		is_casting_ability_two = false
		show_ability_two_visual.rpc(false)
	)
	
	# Medium size AOE shockwave (radius 6.5m, 20 dmg, 30% slow for 2.5s)
	if multiplayer.is_server():
		execute_crush_aoe_two_on_server(global_position, name.to_int())
	else:
		request_crush_aoe_two.rpc_id(1, global_position)

func _perform_dive_ability_two() -> void:
	var def = _ability_definitions.get("Q", AbilitiesLibrary.get_ability("dive_earth_tremor"))
	var windup = def.effect.windup_time if (def and def.effect) else 0.35
	# Dive pauses to channel for 0.35s (self-inflicted CC, canceled if stunned)
	start_channel(windup, Callable(self, "_on_dive_q_channel_finished"))

func _on_dive_q_channel_finished() -> void:
	var def = _ability_definitions.get("Q", AbilitiesLibrary.get_ability("dive_earth_tremor"))
	ability_two_timer = def.cooldown if def else ability_two_cooldown
	ability_cast.emit(def.name if def else "Earth Tremor", "Q")
	var aim_info = get_3d_aim_info()
	var shoot_dir = aim_info.dir
	var spawn_pos = global_position + Vector3(0, 0.85, 0) + shoot_dir * 1.2
	
	var tremor_dmg: float = 18.0
	var tremor_speed: float = 28.0
	var tremor_size: float = 1.5
	var max_range: float = 14.0
	var slow_dur: float = 2.0
	var slow_pct: float = 0.4
	
	if def and def.effect:
		tremor_speed = def.effect.speed
		tremor_size = def.effect.projectile_size
		max_range = def.effect.max_range
		for r in def.riders:
			if r.rider_type == AbilityPipeline.RiderType.DAMAGE:
				tremor_dmg = r.amount
			elif r.rider_type == AbilityPipeline.RiderType.SLOW:
				slow_dur = r.duration
				slow_pct = r.intensity

	var tremor_life: float = max_range / tremor_speed # Distance: 14.0m max distance always
	
	# Dive sends forward a piercing tremor that travels far, slows enemies in its path, and spawns temporary terrain at the end
	if multiplayer.is_server():
		get_tree().root.get_node("Main").spawn_projectile(spawn_pos, shoot_dir, name.to_int(), tremor_dmg, tremor_speed, tremor_size, tremor_life, "slow", slow_dur, slow_pct, true, true, 0, ActionType.ABILITY, max_range)
	else:
		request_fire_ability_two.rpc_id(1, spawn_pos, shoot_dir, tremor_dmg, tremor_speed, tremor_size, tremor_life, "slow", slow_dur, slow_pct, true, true, ActionType.ABILITY, max_range)

func _perform_poke_ability_two() -> void:
	var def = _ability_definitions.get("Q", AbilitiesLibrary.get_ability("poke_slipstream_field"))
	ability_two_timer = def.cooldown if def else ability_two_cooldown
	ability_cast.emit(def.name if def else "Slipstream Field", "Q")
	var hit_pos = _get_mouse_ground_hit()
	var spawn_pos = Vector3(global_position.x, 0.0, global_position.z)
	var target_pos = spawn_pos + (-global_transform.basis.z.normalized()) * 3.5
	var max_range = def.effect.max_range if (def and def.effect) else 6.0
	if hit_pos != null:
		var diff = hit_pos - spawn_pos
		diff.y = 0.0
		var dist = clamp(diff.length(), 0.5, max_range)
		target_pos = spawn_pos + diff.normalized() * dist
	target_pos.y = 0.0
	
	var radius = def.hitbox.radius if (def and def.hitbox) else 2.2
	var duration = def.effect.duration if (def and def.effect) else 4.5
	var slow_pct = 0.35
	if def:
		for r in def.riders:
			if r.rider_type == AbilityPipeline.RiderType.SLOW:
				slow_pct = r.intensity
	
	if multiplayer.is_server():
		get_tree().root.get_node("Main").spawn_slowing_dot_zone(target_pos, radius, duration, 0.0, slow_pct, name.to_int())
	else:
		request_poke_dot_zone.rpc_id(1, target_pos)

@rpc("any_peer", "call_remote", "reliable")
func request_poke_dot_zone(target_pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	get_tree().root.get_node("Main").spawn_slowing_dot_zone(target_pos, 2.2, 4.5, 0.0, 0.35, sender_id)

# --- Ability Three (E) ---
func _perform_ability_three() -> void:
	if character_name == "Crush":
		_perform_crush_ability_three()
	elif character_name == "Dive":
		_perform_dive_ability_three()
	elif character_name == "Reaper":
		_perform_reaper_ability_three()
	else:
		_perform_poke_ability_three()

func _perform_reaper_ability_three() -> void:
	var def = _ability_definitions.get("E", AbilitiesLibrary.get_ability("reaper_nightmare"))
	ability_three_timer = def.cooldown if def else ability_three_cooldown
	ability_cast.emit(def.name if def else "Nightmare", "E")
	
	var dur = def.effect.duration if (def and def.effect) else 1.8
	start_reaper_nightmare(dur)
	if multiplayer.is_server():
		execute_reaper_nightmare_cast_server(global_position, name.to_int())
	else:
		request_reaper_nightmare_cast.rpc_id(1, global_position)

func start_reaper_nightmare(dur: float = 1.8) -> void:
	is_in_nightmare = true
	reaper_nightmare_timer = dur
	apply_ethereal(dur)
	if nightmare_visual:
		nightmare_visual.visible = true
	if multiplayer.is_server():
		sync_reaper_nightmare.rpc(true, dur)

func end_reaper_nightmare() -> void:
	is_in_nightmare = false
	reaper_nightmare_timer = 0.0
	if nightmare_visual:
		nightmare_visual.visible = false
	if multiplayer.is_server():
		sync_reaper_nightmare.rpc(false, 0.0)
		execute_reaper_nightmare_end_server(global_position, name.to_int())
	else:
		request_reaper_nightmare_end.rpc_id(1, global_position)

@rpc("any_peer", "call_remote", "reliable")
func request_reaper_nightmare_cast(origin_pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var player = get_tree().root.get_node_or_null("Main/Players/" + str(sender_id))
	if player and player.has_method("start_reaper_nightmare"):
		player.start_reaper_nightmare(1.8)
	execute_reaper_nightmare_cast_server(origin_pos, sender_id)

@rpc("any_peer", "call_remote", "reliable")
func request_reaper_nightmare_end(origin_pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	execute_reaper_nightmare_end_server(origin_pos, sender_id)

func execute_reaper_nightmare_cast_server(origin_pos: Vector3, attacker_id: int) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	var mult = REAPER_ULT_DMG_MULT if reaper_ult_buff_timer > 0.0 else 1.0
	var dmg = 35.0 * mult
	for p in players_container.get_children():
		if is_enemy(p) and not p.get("is_dead"):
			var diff = p.global_position - origin_pos
			if Vector2(diff.x, diff.z).length() <= 4.5 and abs(diff.y) <= 2.2:
				p.take_damage(dmg, attacker_id, ActionType.ABILITY)
				if p.has_method("apply_slow"):
					p.apply_slow(1.8, 0.40)

func execute_reaper_nightmare_end_server(origin_pos: Vector3, attacker_id: int) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	var mult = REAPER_ULT_DMG_MULT if reaper_ult_buff_timer > 0.0 else 1.0
	var dmg = 45.0 * mult
	for p in players_container.get_children():
		if is_enemy(p) and not p.get("is_dead"):
			var diff = p.global_position - origin_pos
			if Vector2(diff.x, diff.z).length() <= 4.5 and abs(diff.y) <= 2.2:
				p.take_damage(dmg, attacker_id, ActionType.ABILITY)
				if p.has_method("apply_slow"):
					p.apply_slow(1.5, 0.40)

@rpc("any_peer", "call_local", "reliable")
func sync_reaper_nightmare(active: bool, dur: float) -> void:
	is_in_nightmare = active
	reaper_nightmare_timer = dur if active else 0.0
	if nightmare_visual:
		nightmare_visual.visible = active

func _perform_poke_ability_three() -> void:
	var def = _ability_definitions.get("E", AbilitiesLibrary.get_ability("poke_recon_flare"))
	ability_three_timer = def.cooldown if def else ability_three_cooldown
	ability_cast.emit(def.name if def else "Recon Flare", "E")
	var hit_pos = _get_mouse_ground_hit()
	var spawn_pos = Vector3(global_position.x, 0.0, global_position.z)
	var target_pos = spawn_pos + (-global_transform.basis.z.normalized()) * 45.0
	var max_range = def.effect.max_range if (def and def.effect) else 65.0
	if hit_pos != null:
		var diff = hit_pos - spawn_pos
		diff.y = 0.0
		var dist = clamp(diff.length(), 6.0, max_range)
		target_pos = spawn_pos + diff.normalized() * dist
	target_pos.y = 0.0
	
	if multiplayer.is_server():
		get_tree().root.get_node("Main").spawn_vision_flare(spawn_pos + Vector3(0, 1.2, 0), target_pos, name.to_int())
	else:
		request_poke_flare.rpc_id(1, spawn_pos + Vector3(0, 1.2, 0), target_pos)

func _perform_crush_ability_three() -> void:
	var def = _ability_definitions.get("E", AbilitiesLibrary.get_ability("crush_iron_barrier"))
	ability_three_timer = def.cooldown if def else ability_three_cooldown
	set_crush_empowered(true) # Titan's Surge Passive Activation
	
	if gray_health > 0.0:
		apply_shield(gray_health, 5.0)
		gray_health = 0.0
		if multiplayer.is_server():
			sync_gray_health.rpc(0.0)
		else:
			request_crush_consume_gray_health.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func request_crush_consume_gray_health() -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var player = get_tree().root.get_node_or_null("Main/Players/" + str(sender_id))
	if player and player.get("gray_health") > 0.0:
		var g_hp = player.get("gray_health")
		player.apply_shield(g_hp, 5.0)
		player.set("gray_health", 0.0)
		player.sync_gray_health.rpc(0.0)

func _perform_dive_ability_three() -> void:
	if is_blocking:
		# Recast early to drop block and start CD sooner
		end_block_stance()
		ability_three_timer = ability_three_cooldown
		if not multiplayer.is_server():
			request_cancel_dive_block.rpc_id(1)
	else:
		start_block_stance()
		if not multiplayer.is_server():
			request_start_dive_block.rpc_id(1)

func start_block_stance() -> void:
	is_blocking = true
	block_timer = BLOCK_DURATION
	if block_visual:
		block_visual.visible = true
	if multiplayer.is_server():
		sync_block_state.rpc(true)

func end_block_stance() -> void:
	is_blocking = false
	block_timer = 0.0
	if block_visual:
		block_visual.visible = false
	if multiplayer.is_server():
		sync_block_state.rpc(false)

@rpc("any_peer", "call_remote", "reliable")
func request_start_dive_block() -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var player = get_tree().root.get_node_or_null("Main/Players/" + str(sender_id))
	if player and player.has_method("start_block_stance"):
		player.start_block_stance()

@rpc("any_peer", "call_remote", "reliable")
func request_cancel_dive_block() -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var player = get_tree().root.get_node_or_null("Main/Players/" + str(sender_id))
	if player and player.has_method("end_block_stance"):
		player.end_block_stance()
		player.set("ability_three_timer", player.get("ability_three_cooldown"))

@rpc("any_peer", "call_local", "reliable")
func sync_block_state(active: bool) -> void:
	is_blocking = active
	if block_visual:
		block_visual.visible = active
	_update_hud()

func _perform_poke_ability_three() -> void:
	ability_three_timer = ability_three_cooldown
	ability_cast.emit("Recon Flare", "E")
	var hit_pos = _get_mouse_ground_hit()
	var spawn_origin = Vector3(global_position.x, 0.0, global_position.z)
	var shoot_dir = -global_transform.basis.z.normalized()
	var target_dist: float = 45.0
	
	if hit_pos != null and hit_pos is Vector3:
		var diff = hit_pos - spawn_origin
		diff.y = 0.0
		if diff.length_squared() > 0.01:
			shoot_dir = diff.normalized()
			target_dist = clamp(diff.length(), 6.0, 65.0)
	else:
		var aim_info = get_3d_aim_info()
		shoot_dir = aim_info.dir
		target_dist = 45.0

	var spawn_pos = global_position + Vector3(0, 0.85, 0) + shoot_dir * 1.1
	
	if multiplayer.is_server():
		get_tree().root.get_node("Main").spawn_vision_flare(spawn_pos, shoot_dir, target_dist, name.to_int())
	else:
		request_fire_vision_flare.rpc_id(1, spawn_pos, shoot_dir, target_dist)

@rpc("any_peer", "call_remote", "reliable")
func request_fire_vision_flare(spawn_pos: Vector3, shoot_dir: Vector3, target_dist: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	get_tree().root.get_node("Main").spawn_vision_flare(spawn_pos, shoot_dir, target_dist, sender_id)

func set_opponent_visible(is_vis: bool) -> void:
	if is_dead:
		return
	$MeshInstance3D.visible = is_vis
	$FacingIndicator.visible = is_vis
	$HealthBarSprite.visible = is_vis
	if melee_visual and is_casting_melee:
		melee_visual.visible = is_vis
	if ability_one_visual and is_casting_ability_one:
		ability_one_visual.visible = is_vis
	if ability_two_visual and is_casting_ability_two:
		ability_two_visual.visible = is_vis

@rpc("any_peer", "call_local", "reliable")
func show_ability_one_visual(active: bool) -> void:
	if ability_one_visual:
		ability_one_visual.visible = active

@rpc("any_peer", "call_local", "reliable")
func show_ability_two_visual(active: bool) -> void:
	if ability_two_visual:
		ability_two_visual.visible = active

@rpc("any_peer", "call_remote", "reliable")
func request_crush_fan_stun(origin_pos: Vector3, forward_dir: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	execute_crush_fan_stun_on_server(origin_pos, forward_dir, sender_id)

func execute_crush_fan_stun_on_server(origin_pos: Vector3, forward_dir: Vector3, attacker_id: int) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	
	var fwd_2d = Vector2(forward_dir.x, forward_dir.z).normalized()
	var fan_height = 2.6
	
	for player in players_container.get_children():
		if is_enemy(player) and not player.get("is_dead"):
			var diff = player.global_position - origin_pos
			var diff_2d = Vector2(diff.x, diff.z)
			var dist = diff_2d.length()
			
			if abs(diff.y) <= (fan_height * 0.5) and dist <= 5.2:
				var to_target_2d = diff_2d.normalized()
				var angle = rad_to_deg(fwd_2d.angle_to(to_target_2d))
				if abs(angle) <= (100.0 * 0.5):
					player.take_damage(20.0, attacker_id, ActionType.ABILITY)
					if player.has_method("apply_stun"):
						player.apply_stun(1.3)

@rpc("any_peer", "call_remote", "reliable")
func request_crush_aoe_two(origin_pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	execute_crush_aoe_two_on_server(origin_pos, sender_id)

func execute_crush_aoe_two_on_server(origin_pos: Vector3, attacker_id: int) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	
	var shockwave_height = 3.2
	
	for player in players_container.get_children():
		if is_enemy(player) and not player.get("is_dead"):
			var diff = player.global_position - origin_pos
			var dist = diff.length()
			if abs(diff.y) <= (shockwave_height * 0.5) and dist <= 6.5:
				player.take_damage(20.0, attacker_id, ActionType.ABILITY)
				if player.has_method("apply_slow"):
					player.apply_slow(2.5, 0.3)

@rpc("any_peer", "call_remote", "reliable")
func request_fire_ability_one(spawn_pos: Vector3, shoot_dir: Vector3, dmg: float, spd: float, p_size: float, life: float, eff_type: String, eff_dur: float, eff_int: float, action_type: int = ActionType.ABILITY, max_rng: float = 0.0) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	get_tree().root.get_node("Main").spawn_projectile(spawn_pos, shoot_dir, sender_id, dmg, spd, p_size, life, eff_type, eff_dur, eff_int, false, false, 0, action_type, max_rng)

@rpc("any_peer", "call_remote", "reliable")
func request_fire_ability_two(spawn_pos: Vector3, shoot_dir: Vector3, dmg: float, spd: float, p_size: float, life: float, eff_type: String, eff_dur: float, eff_int: float, pierce: bool, spawn_terr: bool, action_type: int = ActionType.ABILITY, max_rng: float = 0.0) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	get_tree().root.get_node("Main").spawn_projectile(spawn_pos, shoot_dir, sender_id, dmg, spd, p_size, life, eff_type, eff_dur, eff_int, pierce, spawn_terr, 0, action_type, max_rng)

@rpc("any_peer", "call_local", "reliable")
func show_melee_effect(active: bool) -> void:
	if melee_visual:
		melee_visual.visible = active

@rpc("any_peer", "call_remote", "reliable")
func request_melee_strike(origin_pos: Vector3, forward_dir: Vector3, dmg: float, size: float, angle_deg: float, was_empowered: bool = false) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	execute_melee_hit_on_server(origin_pos, forward_dir, sender_id, dmg, size, angle_deg, was_empowered)

func execute_melee_hit_on_server(origin_pos: Vector3, forward_dir: Vector3, attacker_id: int, dmg: float, size: float, angle_deg: float, was_empowered: bool = false) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	
	var final_dmg = dmg + (25.0 if was_empowered else 0.0)
	var fwd_2d = Vector2(forward_dir.x, forward_dir.z).normalized()
	var hit_count = 0
	
	for player in players_container.get_children():
		if is_enemy(player) and not player.get("is_dead"):
			var diff = player.global_position - origin_pos
			var diff_2d = Vector2(diff.x, diff.z)
			var dist = diff_2d.length()
			
			if abs(diff.y) <= (melee_height * 0.5) and dist <= size:
				var to_target_2d = diff_2d.normalized()
				var angle = rad_to_deg(fwd_2d.angle_to(to_target_2d))
				if abs(angle) <= (angle_deg * 0.5):
					player.take_damage(final_dmg, attacker_id, ActionType.ATTACK)
					hit_count += 1
					
	# Crush Titan's Surge heal trigger (triggers once if at least 1 enemy was hit)
	if was_empowered and hit_count > 0:
		var attacker = players_container.get_node_or_null(str(attacker_id))
		if attacker and attacker.has_method("heal"):
			attacker.heal(24.0)

@rpc("any_peer", "call_remote", "reliable")
func request_dive_melee_strike(origin_pos: Vector3, forward_dir: Vector3, dmg: float, size: float, angle_deg: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	execute_dive_melee_hit_on_server(origin_pos, forward_dir, sender_id, dmg, size, angle_deg)

func execute_dive_melee_hit_on_server(origin_pos: Vector3, forward_dir: Vector3, attacker_id: int, dmg: float, size: float, angle_deg: float) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	
	var fwd_2d = Vector2(forward_dir.x, forward_dir.z).normalized()
	
	for player in players_container.get_children():
		if is_enemy(player) and not player.get("is_dead"):
			var diff = player.global_position - origin_pos
			var diff_2d = Vector2(diff.x, diff.z)
			var dist = diff_2d.length()
			
			if abs(diff.y) <= (melee_height * 0.5) and dist <= size:
				var to_target_2d = diff_2d.normalized()
				var angle = rad_to_deg(fwd_2d.angle_to(to_target_2d))
				if abs(angle) <= (angle_deg * 0.5):
					player.take_damage(dmg, attacker_id, ActionType.ATTACK)
					if player.has_method("apply_knockback"):
						var kb_dir = Vector3(forward_dir.x, 0.25, forward_dir.z).normalized()
						player.apply_knockback(kb_dir * 9.5)

@rpc("any_peer", "call_remote", "reliable")
func request_dive_ability_one(origin_pos: Vector3, forward_dir: Vector3, dmg: float, size: float, angle_deg: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	execute_dive_ability_one_on_server(origin_pos, forward_dir, sender_id, dmg, size, angle_deg)

func execute_dive_ability_one_on_server(origin_pos: Vector3, forward_dir: Vector3, attacker_id: int, dmg: float, size: float, angle_deg: float) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	
	var fwd_2d = Vector2(forward_dir.x, forward_dir.z).normalized()
	var cleave_height = 2.4
	
	for player in players_container.get_children():
		if is_enemy(player) and not player.get("is_dead"):
			var diff = player.global_position - origin_pos
			var diff_2d = Vector2(diff.x, diff.z)
			var dist = diff_2d.length()
			
			if abs(diff.y) <= (cleave_height * 0.5) and dist <= size:
				var to_target_2d = diff_2d.normalized()
				var angle = rad_to_deg(fwd_2d.angle_to(to_target_2d))
				if abs(angle) <= (angle_deg * 0.5):
					player.take_damage(dmg, attacker_id, ActionType.ABILITY)
					if player.has_method("apply_slow"):
						player.apply_slow(1.6, 0.75)
					if player.has_method("apply_knockback"):
						var kb_dir = Vector3(forward_dir.x, 0.2, forward_dir.z).normalized()
						player.apply_knockback(kb_dir * 8.0)

@rpc("any_peer", "call_local", "reliable")
func show_crash_impact_effect(pos: Vector3) -> void:
	if crash_visual:
		crash_visual.global_position = pos
		crash_visual.visible = true
		crash_visual.scale = Vector3(0.3, 1.0, 0.3)
		var tween = create_tween()
		tween.tween_property(crash_visual, "scale", Vector3(1.1, 1.0, 1.1), 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(crash_visual, "scale", Vector3(0.01, 1.0, 0.01), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): crash_visual.visible = false)

@rpc("any_peer", "call_remote", "reliable")
func request_crash_down_impact(impact_pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	execute_crash_down_impact_on_server(impact_pos, sender_id)

func execute_crash_down_impact_on_server(impact_pos: Vector3, attacker_id: int) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	
	var aoe_radius: float = 6.0
	var damage_amount: float = 48.0
	var crash_height: float = 4.0
	
	for player in players_container.get_children():
		if is_enemy(player) and not player.get("is_dead"):
			var diff = player.global_position - impact_pos
			var dist = diff.length()
			if diff.y >= -1.0 and diff.y <= crash_height and dist <= aoe_radius:
				player.take_damage(damage_amount, attacker_id, ActionType.ABILITY)
				if player.has_method("apply_knockback"):
					var horiz_diff = Vector3(diff.x, 0, diff.z)
					var horiz_dir = horiz_diff.normalized() if horiz_diff.length_squared() > 0.01 else -player.global_transform.basis.z.normalized()
					var dist_ratio = clamp(1.0 - (dist / aoe_radius), 0.35, 1.0)
					var airborne_impulse = horiz_dir * (14.0 * dist_ratio + 5.0) + Vector3.UP * (18.0 * dist_ratio + 6.0)
					player.apply_knockback(airborne_impulse)

func aim_at_mouse(delta: float = 0.0) -> void:
	var aim_info = get_3d_aim_info()
	var dir_3d = aim_info.dir
	var horiz_dir = Vector3(dir_3d.x, 0.0, dir_3d.z)
	
	if horiz_dir.length_squared() > 0.001:
		var target := global_position + horiz_dir.normalized()
		if is_blocking and delta > 0.0:
			var target_diff = target - global_position
			var target_angle = atan2(-target_diff.x, -target_diff.z)
			var current_angle = rotation.y
			rotation.y = rotate_toward(current_angle, target_angle, BLOCK_MAX_TURN_SPEED * delta)
			rotation.x = 0.0
			rotation.z = 0.0
		else:
			look_at(target, Vector3.UP)
			rotation.x = 0.0
			rotation.z = 0.0

	var spawn_pos = global_position + Vector3(0, 0.85, 0)
	var up_vec = Vector3.UP if abs(dir_3d.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	
	# Update 3D orientation for straight line ability indicators when held
	if is_holding_ability_one and ind_ability_one and character_name == "Poke":
		ind_ability_one.global_position = spawn_pos
		ind_ability_one.look_at(spawn_pos + dir_3d, up_vec)
	elif is_holding_ability_two and ind_ability_two and character_name == "Dive":
		ind_ability_two.global_position = spawn_pos
		ind_ability_two.look_at(spawn_pos + dir_3d, up_vec)
	elif is_holding_ability_three and ind_ability_three and character_name == "Poke":
		ind_ability_three.global_position = spawn_pos
		ind_ability_three.look_at(spawn_pos + dir_3d, up_vec)
	elif is_holding_ability_four and ind_ability_four:
		if character_name in ["Crush", "Poke"]:
			ind_ability_four.global_position = spawn_pos
			ind_ability_four.look_at(spawn_pos + dir_3d, up_vec)

@rpc("any_peer", "call_remote", "reliable")
func request_wall_impact_damage(dmg: float, impact_spd: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var player = get_tree().root.get_node_or_null("Main/Players/" + str(sender_id))
	if player and not player.get("is_dead"):
		player.take_damage(dmg, 0, ActionType.ENVIRONMENT)

@rpc("any_peer", "call_local", "reliable")
func show_wall_impact_effect(pos: Vector3, normal: Vector3) -> void:
	if crash_visual:
		crash_visual.global_position = pos + normal * 0.2
		crash_visual.visible = true
		crash_visual.scale = Vector3(0.2, 1.0, 0.2)
		var tween = create_tween()
		tween.tween_property(crash_visual, "scale", Vector3(0.7, 1.0, 0.7), 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(crash_visual, "scale", Vector3(0.01, 1.0, 0.01), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): crash_visual.visible = false)

@rpc("any_peer", "call_remote", "reliable")
func request_fire(spawn_pos: Vector3, shoot_dir: Vector3, dmg: float, spd: float, p_size: float, life: float = 2.5, action_type: int = ActionType.ATTACK, eff_type: String = "", pierces: bool = false, max_rng: float = 0.0) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	get_tree().root.get_node("Main").spawn_projectile(spawn_pos, shoot_dir, sender_id, dmg, spd, p_size, life, eff_type, 0.0, 0.0, pierces, false, 0, action_type, max_rng)

func apply_stun(duration: float) -> void:
	if is_dead or is_cc_immune or is_in_nightmare:
		return
	if is_channeling:
		cancel_channel()
	if is_floating:
		end_float_state()
	if is_blocking:
		end_block_stance()
		ability_three_timer = ability_three_cooldown
	is_crashing_down = false
	is_dashing = false
	_cancel_all_hold_indicators()
	stun_timer = max(stun_timer, duration)
	if multiplayer.is_server():
		sync_status_effects.rpc(stun_timer, slow_timer, slow_percent, silence_timer, root_timer, grounded_timer, cripple_timer)

func apply_slow(duration: float, percent: float) -> void:
	if is_dead or is_cc_immune or is_in_nightmare:
		return
	slow_timer = max(slow_timer, duration)
	slow_percent = max(slow_percent, percent)
	if multiplayer.is_server():
		sync_status_effects.rpc(stun_timer, slow_timer, slow_percent, silence_timer, root_timer, grounded_timer, cripple_timer)

func apply_silence(duration: float) -> void:
	if is_dead or is_cc_immune or is_in_nightmare:
		return
	if is_channeling:
		cancel_channel()
	_cancel_all_hold_indicators()
	silence_timer = max(silence_timer, duration)
	if multiplayer.is_server():
		sync_status_effects.rpc(stun_timer, slow_timer, slow_percent, silence_timer, root_timer, grounded_timer, cripple_timer)

func apply_root(duration: float) -> void:
	if is_dead or is_cc_immune or is_in_nightmare:
		return
	root_timer = max(root_timer, duration)
	if multiplayer.is_server():
		sync_status_effects.rpc(stun_timer, slow_timer, slow_percent, silence_timer, root_timer, grounded_timer, cripple_timer)

func apply_grounded(duration: float) -> void:
	if is_dead or is_cc_immune or is_in_nightmare:
		return
	grounded_timer = max(grounded_timer, duration)
	if multiplayer.is_server():
		sync_status_effects.rpc(stun_timer, slow_timer, slow_percent, silence_timer, root_timer, grounded_timer, cripple_timer)

func apply_cripple(duration: float, intensity: float = 0.35) -> void:
	if is_dead or is_cc_immune or is_in_nightmare:
		return
	cripple_timer = max(cripple_timer, duration)
	cripple_intensity = intensity
	if multiplayer.is_server():
		sync_status_effects.rpc(stun_timer, slow_timer, slow_percent, silence_timer, root_timer, grounded_timer, cripple_timer)

func apply_ethereal(duration: float) -> void:
	if is_dead:
		return
	ethereal_timer = max(ethereal_timer, duration)

func apply_reaper_ms_steal(duration: float = 2.5, percent: float = 0.15) -> void:
	if is_dead:
		return
	reaper_ms_steal_timer = max(reaper_ms_steal_timer, duration)
	reaper_ms_steal_pct = percent

func apply_knockback(impulse: Vector3) -> void:
	if is_dead or is_in_nightmare:
		return
	receive_knockback.rpc(impulse)

@rpc("any_peer", "call_local", "reliable")
func receive_knockback(impulse: Vector3) -> void:
	velocity.x = impulse.x
	velocity.z = impulse.z
	if impulse.y < 0.0:
		velocity.y = impulse.y
	else:
		velocity.y = max(velocity.y + impulse.y, impulse.y)
	knockback_velocity = impulse

@rpc("any_peer", "call_local", "reliable")
func sync_status_effects(s_timer: float, sl_timer: float, sl_pct: float, sil_timer: float = 0.0, r_timer: float = 0.0, g_timer: float = 0.0, c_timer: float = 0.0) -> void:
	stun_timer = s_timer
	slow_timer = sl_timer
	slow_percent = sl_pct
	silence_timer = sil_timer
	root_timer = r_timer
	grounded_timer = g_timer
	cripple_timer = c_timer

func take_damage(amount: float, attacker_id: int = 0, action_type: int = ActionType.ABILITY) -> void:
	if not multiplayer.is_server() or is_dead or is_in_nightmare:
		return

	if attacker_id > 0:
		var attacker = get_tree().root.get_node_or_null("Main/Players/" + str(attacker_id))
		if attacker and not is_enemy(attacker):
			return
		if attacker and attacker.get("reaper_ult_buff_timer") != null and attacker.reaper_ult_buff_timer > 0.0 and attacker.get("character_name") == "Reaper":
			amount *= REAPER_ULT_DMG_MULT

	# Dive Directional Block Check (75% DR against frontal 140 deg arc)
	if is_blocking and attacker_id > 0:
		var attacker = get_tree().root.get_node_or_null("Main/Players/" + str(attacker_id))
		if attacker:
			var diff = attacker.global_position - global_position
			var diff_2d = Vector2(diff.x, diff.z).normalized()
			var fwd_3d = -global_transform.basis.z.normalized()
			var fwd_2d = Vector2(fwd_3d.x, fwd_3d.z).normalized()
			var angle_deg = rad_to_deg(fwd_2d.angle_to(diff_2d))
			if abs(angle_deg) <= 70.0:
				amount *= (1.0 - BLOCK_DR_PERCENT) # 75% reduction
	
	# Absorb damage into shield first
	if current_shield > 0.0:
		if amount <= current_shield:
			current_shield -= amount
			amount = 0.0
		else:
			amount -= current_shield
			current_shield = 0.0
		sync_shield.rpc(current_shield)
	
	if amount > 0.0:
		current_health -= amount
		sync_health.rpc(current_health)
		
		# Crush Gray Health Storage (stores 30% of damage taken)
		if character_name == "Crush":
			gray_health = min(gray_health + amount * 0.3, max_health - current_health)
			sync_gray_health.rpc(gray_health)
	
	time_since_last_damage = 0.0

	# Spawn floating damage number
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node and main_node.has_method("display_damage_number"):
		main_node.display_damage_number.rpc(amount, global_position + Vector3(0, 0.5, 0), action_type)

	# Emit combat signals on server
	damage_taken.emit(attacker_id, amount, action_type)
	if attacker_id > 0:
		var attacker = get_tree().root.get_node_or_null("Main/Players/" + str(attacker_id))
		if attacker and attacker.has_signal("damage_dealt"):
			attacker.damage_dealt.emit(self, amount, action_type)

	if current_health <= 0.0:
		die()
		return
		
	# Dive Passive Rupture Mark Application
	if attacker_id > 0:
		var attacker = get_tree().root.get_node_or_null("Main/Players/" + str(attacker_id))
		if attacker and attacker.get("character_name") == "Dive" and is_enemy(attacker):
			apply_dive_mark(attacker_id)

func heal(amount: float) -> void:
	if not multiplayer.is_server() or is_dead:
		return
	current_health = min(max_health, current_health + amount)
	sync_health.rpc(current_health)

func set_crush_empowered(active: bool) -> void:
	is_crush_empowered = active
	sync_crush_empowered.rpc(active)

@rpc("any_peer", "call_local", "reliable")
func sync_crush_empowered(active: bool) -> void:
	is_crush_empowered = active
	_update_hud()

# --- Dive Rupture Marks Passive ---
func apply_dive_mark(attacker_id: int) -> void:
	if not multiplayer.is_server() or is_dead:
		return
	
	if dive_marks_count == 0:
		dive_marks_count = 1
		dive_mark_timer = DIVE_MARK_DURATION # 3.5s
		dive_mark_attacker_id = attacker_id
	else:
		dive_marks_count += 1
		dive_mark_attacker_id = attacker_id
		# Timer does not reset!
	
	sync_dive_marks.rpc(dive_marks_count, dive_mark_timer)
	
	if dive_marks_count >= DIVE_MARK_MAX:
		detonate_dive_marks()

func detonate_dive_marks() -> void:
	if not multiplayer.is_server() or is_dead or dive_marks_count <= 0:
		dive_marks_count = 0
		dive_mark_timer = 0.0
		sync_dive_marks.rpc(0, 0.0)
		return
	
	var count = dive_marks_count
	var burst_damage = count * DIVE_MARK_BURST_PER_STACK
	var attacker_id = dive_mark_attacker_id
	
	dive_marks_count = 0
	dive_mark_timer = 0.0
	sync_dive_marks.rpc(0, 0.0)
	show_mark_detonation_effect.rpc(global_position, count)
	
	take_damage(burst_damage, 0) # Apply burst damage (attacker_id=0 so it does not loop)

@rpc("any_peer", "call_local", "reliable")
func sync_dive_marks(marks: int, timer: float) -> void:
	dive_marks_count = marks
	dive_mark_timer = timer
	_update_hud()

@rpc("any_peer", "call_local", "reliable")
func show_mark_detonation_effect(pos: Vector3, count: int) -> void:
	if crash_visual:
		crash_visual.global_position = pos
		crash_visual.visible = true
		crash_visual.scale = Vector3(0.1, 1.0, 0.1) * float(count)
		var tween = create_tween()
		tween.tween_property(crash_visual, "scale", Vector3(0.5, 1.0, 0.5) * (float(count) * 0.3 + 0.5), 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(crash_visual, "scale", Vector3(0.01, 1.0, 0.01), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): crash_visual.visible = false)

# --- Poke Passive: Fleet Foot (15% non-stacking MS on hit, refreshes duration) ---
func apply_speed_boost(duration: float = 2.5, percent: float = 0.15) -> void:
	if is_dead:
		return
	poke_speed_boost_timer = max(poke_speed_boost_timer, duration)
	poke_speed_boost_percent = max(poke_speed_boost_percent, percent)
	if multiplayer.is_server():
		sync_speed_boost.rpc(poke_speed_boost_timer, poke_speed_boost_percent)

@rpc("any_peer", "call_local", "reliable")
func sync_speed_boost(dur: float, pct: float) -> void:
	poke_speed_boost_timer = dur
	poke_speed_boost_percent = pct
	_update_hud()

@rpc("any_peer", "call_local", "reliable")
func sync_health(new_health: float) -> void:
	current_health = new_health

@rpc("any_peer", "call_local", "reliable")
func sync_gray_health(amount: float) -> void:
	gray_health = amount
	update_health_bar()
	_update_hud()

func die() -> void:
	if not multiplayer.is_server() or is_dead:
		return
	
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node and main_node.get("is_training_mode") == true:
		# In training mode, player respawns automatically at full health!
		current_health = max_health
		current_shield = 0.0
		gray_health = 0.0
		dive_marks_count = 0
		dive_mark_timer = 0.0
		stun_timer = 0.0
		slow_timer = 0.0
		silence_timer = 0.0
		knockback_velocity = Vector3.ZERO
		velocity = Vector3.ZERO
		global_position = Vector3(-8.0, 0.1, 0.0)
		sync_health.rpc(max_health)
		sync_status_effects.rpc(0.0, 0.0, 0.0, 0.0)
		sync_shield.rpc(0.0)
		sync_gray_health.rpc(0.0)
		return

	is_dead = true
	current_shield = 0.0
	gray_health = 0.0
	dive_marks_count = 0
	dive_mark_timer = 0.0
	if is_blocking:
		end_block_stance()
	sync_gray_health.rpc(0.0)
	sync_dive_marks.rpc(0, 0.0)
	sync_shield.rpc(0.0)
	notify_death.rpc()
	if main_node and main_node.has_method("on_player_died"):
		main_node.on_player_died(name.to_int())

@rpc("any_peer", "call_local", "reliable")
func notify_death() -> void:
	is_dead = true
	if is_floating:
		end_float_state()
	if is_blocking:
		end_block_stance()
	is_crashing_down = false
	is_dashing = false
	knockback_velocity = Vector3.ZERO
	gray_health = 0.0
	dive_marks_count = 0
	dive_mark_timer = 0.0
	is_crush_empowered = false
	poke_speed_boost_timer = 0.0
	poke_speed_boost_percent = 0.0
	_cancel_all_hold_indicators()
	$CollisionShape3D.disabled = true
	$MeshInstance3D.visible = false
	$FacingIndicator.visible = false
	$HealthBarSprite.visible = false
	if melee_visual:
		melee_visual.visible = false
	if ability_one_visual:
		ability_one_visual.visible = false
	if ability_two_visual:
		ability_two_visual.visible = false
	if block_visual:
		block_visual.visible = false
	if crash_visual:
		crash_visual.visible = false
		
	if name.to_int() == multiplayer.get_unique_id():
		spectator_panel.show()
		if hud_container:
			hud_container.hide()
		elif has_node("PlayerHUD/VBox"):
			$PlayerHUD/VBox.hide()
		_cycle_spectator(0)

func _process_spectator(delta: float) -> void:
	if not is_inside_tree():
		return
	
	var alive_players = _get_alive_players()
	if alive_players.is_empty():
		spectator_label.text = "SPECTATING: All players eliminated"
		return

	if Input.is_action_just_pressed("spectate_next"):
		_cycle_spectator(1)
	elif Input.is_action_just_pressed("spectate_prev"):
		_cycle_spectator(-1)

	if spectate_target != null and is_instance_valid(spectate_target):
		if camera and is_instance_valid(camera) and camera.is_inside_tree():
			camera.global_position = spectate_target.global_position + CAMERA_OFFSET
	else:
		_cycle_spectator(0)

func _cycle_spectator(dir: int) -> void:
	var alive_players = _get_alive_players()
	if alive_players.is_empty():
		spectate_target = null
		return
	
	spectate_index = (spectate_index + dir) % alive_players.size()
	if spectate_index < 0:
		spectate_index = alive_players.size() - 1
	
	spectate_target = alive_players[spectate_index]
	var t_name = "Player " + spectate_target.name
	if spectate_target.name == "1":
		t_name = "Host (P1)"
	var t_side = " (Teammate)" if spectate_target.get("team_id") == team_id else " (Enemy)"
	spectator_label.text = "SPECTATING: %s%s (%s)\n[LMB / RMB to Cycle]" % [t_name, t_side, spectate_target.get("character_name")]

func _get_alive_players() -> Array:
	var list = []
	var team_list = []
	var enemy_list = []
	var container = get_tree().root.get_node_or_null("Main/Players")
	if container:
		for p in container.get_children():
			if not p.get("is_dead") and p != self:
				if p.get("team_id") == team_id:
					team_list.append(p)
				else:
					enemy_list.append(p)
	list.append_array(team_list)
	list.append_array(enemy_list)
	return list

func update_health_bar() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	if gray_health_bar:
		gray_health_bar.max_value = max_health
		gray_health_bar.value = current_health + gray_health

func get_3d_aim_info() -> Dictionary:
	var default_fwd = -global_transform.basis.z.normalized()
	default_fwd.y = 0.0
	if default_fwd.length_squared() < 0.0001:
		default_fwd = Vector3.FORWARD
	default_fwd = default_fwd.normalized()
	
	var spawn_pos = global_position + Vector3(0, 0.85, 0)
	
	var viewport = get_viewport()
	if not viewport or not camera:
		return {
			"target_pos": spawn_pos + default_fwd * 50.0,
			"dir": default_fwd,
			"is_target_player": false,
			"target_node": null
		}
	
	var mouse_pos = viewport.get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	var space_state = get_world_3d().direct_space_state
	
	# 1. Direct Ray Hit: Check if mouse ray directly intersects an enemy collider
	var player_query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 300.0, 2)
	player_query.collide_with_areas = false
	player_query.collide_with_bodies = true
	player_query.exclude = [get_rid()]
	var player_result = space_state.intersect_ray(player_query)
	
	if not player_result.is_empty():
		var hit_collider = player_result.collider
		if hit_collider != self and hit_collider is CharacterBody3D and not hit_collider.get("is_dead") and is_enemy(hit_collider):
			var target_pos = hit_collider.global_position + Vector3(0, 0.85, 0)
			var shoot_dir = (target_pos - spawn_pos).normalized()
			return {
				"target_pos": target_pos,
				"dir": shoot_dir,
				"is_target_player": true,
				"target_node": hit_collider
			}
	
	# 2. Near-Target Proximity: Auto-aims only when mouse cursor is near the target (within ~48 screen pixels and 1.6m 3D ray distance)
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	var best_target: Node = null
	var best_target_pos: Vector3 = Vector3.ZERO
	var min_screen_dist: float = 48.0 # Pixel radius around mouse
	
	if players_container:
		for p in players_container.get_children():
			if p != self and is_enemy(p) and not p.get("is_dead"):
				var t_pos = p.global_position + Vector3(0, 0.85, 0)
				if not camera.is_position_behind(t_pos):
					var screen_pos = camera.unproject_position(t_pos)
					var screen_dist = mouse_pos.distance_to(screen_pos)
					var v = t_pos - ray_origin
					var t = v.dot(ray_dir)
					if t > 0.0:
						var closest_pt = ray_origin + ray_dir * t
						var dist_to_ray = (t_pos - closest_pt).length()
						var dist_from_shooter = (t_pos - spawn_pos).length()
						if dist_from_shooter <= 75.0 and screen_dist <= min_screen_dist and dist_to_ray <= 1.6:
							min_screen_dist = screen_dist
							best_target = p
							best_target_pos = t_pos

	if best_target != null:
		var shoot_dir = (best_target_pos - spawn_pos).normalized()
		return {
			"target_pos": best_target_pos,
			"dir": shoot_dir,
			"is_target_player": true,
			"target_node": best_target
		}

	# 3. Terrain & World Geometry (Layer 1): Pitches directly toward terrain hit point
	var terrain_query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 300.0, 1)
	terrain_query.collide_with_areas = false
	terrain_query.collide_with_bodies = true
	var terrain_result = space_state.intersect_ray(terrain_query)
	if not terrain_result.is_empty():
		var terrain_pos = terrain_result.position
		var shoot_dir = (terrain_pos - spawn_pos)
		if shoot_dir.length_squared() > 0.0001:
			return {
				"target_pos": terrain_pos,
				"dir": shoot_dir.normalized(),
				"is_target_player": false,
				"target_node": null
			}

	# 4. Fallback: Chest Plane intersection
	var chest_plane = Plane(Vector3.UP, spawn_pos.y)
	var plane_hit = chest_plane.intersects_ray(ray_origin, ray_dir)
	if plane_hit != null:
		var shoot_dir = (plane_hit - spawn_pos)
		if shoot_dir.length_squared() > 0.0001:
			return {
				"target_pos": plane_hit,
				"dir": shoot_dir.normalized(),
				"is_target_player": false,
				"target_node": null
			}
	
	# 5. Default forward
	return {
		"target_pos": spawn_pos + default_fwd * 50.0,
		"dir": default_fwd,
		"is_target_player": false,
		"target_node": null
	}

func _get_mouse_ground_hit() -> Variant:
	var viewport = get_viewport()
	if not viewport or not camera:
		return null
	var mouse_pos = viewport.get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	
	var space_state = get_world_3d().direct_space_state
	# First check terrain / obstacles surface (layer 1)
	var terrain_query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 300.0, 1)
	terrain_query.collide_with_areas = false
	terrain_query.collide_with_bodies = true
	var result = space_state.intersect_ray(terrain_query)
	if not result.is_empty():
		return result.position

	var ground_plane = Plane(Vector3.UP, 0.0)
	return ground_plane.intersects_ray(ray_origin, ray_dir)

func _cancel_all_hold_indicators() -> void:
	is_holding_shoot = false
	is_holding_ability_one = false
	is_holding_ability_two = false
	is_holding_ability_three = false
	is_holding_ability_four = false
	if ind_attack:
		ind_attack.hide()
	if ind_ability_one:
		ind_ability_one.hide()
	if ind_ability_two:
		ind_ability_two.hide()
	if ind_ability_three:
		ind_ability_three.hide()
	if ind_ability_four:
		ind_ability_four.hide()
	if ind_poke_dot_zone:
		ind_poke_dot_zone.hide()
	if ind_poke_flare_circle:
		ind_poke_flare_circle.hide()
	if ind_dive_crash_circle:
		ind_dive_crash_circle.hide()
	if ind_dive_crash_range:
		ind_dive_crash_range.hide()

# --- Ultimate Ability (R) Implementations ---
func _perform_ability_four() -> void:
	if character_name == "Crush":
		_perform_crush_ability_four()
	elif character_name == "Dive":
		_perform_dive_ability_four()
	elif character_name == "Reaper":
		_perform_reaper_ability_four()
	else:
		_perform_poke_ability_four()

func _perform_reaper_ability_four() -> void:
	var def = _ability_definitions.get("R", AbilitiesLibrary.get_ability("reaper_one_with_death"))
	ability_four_timer = def.cooldown if def else ability_four_cooldown
	var dur = def.effect.duration if (def and def.effect) else REAPER_ULT_BUFF_DURATION
	reaper_ult_buff_timer = dur
	ability_cast.emit(def.name if def else "One with Death", "R")
	
	if ult_visual:
		ult_visual.visible = true
	
	if multiplayer.is_server():
		sync_reaper_ult_buff.rpc(dur)
	else:
		request_reaper_ult.rpc_id(1, dur)

@rpc("any_peer", "call_remote", "reliable")
func request_reaper_ult(dur: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var player = get_tree().root.get_node_or_null("Main/Players/" + str(sender_id))
	if player and not player.get("is_dead"):
		player.reaper_ult_buff_timer = dur
		player.sync_reaper_ult_buff.rpc(dur)

@rpc("any_peer", "call_local", "reliable")
func sync_reaper_ult_buff(dur: float) -> void:
	reaper_ult_buff_timer = dur
	if ult_visual:
		ult_visual.visible = (dur > 0.0)

func _perform_crush_ability_four() -> void:
	var def = _ability_definitions.get("R", AbilitiesLibrary.get_ability("crush_juggernaut_charge"))
	ability_four_timer = def.cooldown if def else ability_four_cooldown
	is_casting_ability_four = true
	ability_cast.emit(def.name if def else "Juggernaut Charge", "R")
	var windup = def.effect.windup_time if (def and def.effect) else 0.45
	start_channel(windup, Callable(self, "_on_crush_ult_channel_complete"))

func _on_crush_ult_channel_complete() -> void:
	is_casting_ability_four = false
	var facing_dir = -global_transform.basis.z.normalized()
	facing_dir.y = 0.0
	facing_dir = facing_dir.normalized()
	
	if multiplayer.is_server():
		start_crush_charge_server(global_position, facing_dir)
	else:
		request_crush_ult_charge.rpc_id(1, global_position, facing_dir)

func start_crush_charge_server(start_pos: Vector3, charge_dir: Vector3) -> void:
	is_crush_charging = true
	is_cc_immune = true
	crush_charge_timer = CRUSH_CHARGE_DURATION
	crush_charge_dir = charge_dir
	sync_crush_charge_state.rpc(true, charge_dir)

@rpc("any_peer", "call_remote", "reliable")
func request_crush_ult_charge(start_pos: Vector3, charge_dir: Vector3) -> void:
	if not multiplayer.is_server():
		return
	start_crush_charge_server(start_pos, charge_dir)

@rpc("any_peer", "call_local", "reliable")
func sync_crush_charge_state(charging: bool, charge_dir: Vector3) -> void:
	is_crush_charging = charging
	is_cc_immune = charging
	crush_charge_dir = charge_dir
	if not charging:
		crush_charge_timer = 0.0

@rpc("any_peer", "call_local", "reliable")
func sync_crush_slam_state(slamming: bool, fwd_dir: Vector3 = Vector3.ZERO) -> void:
	is_casting_ability_four = slamming
	is_cc_immune = slamming
	if slamming:
		velocity = Vector3.ZERO
		knockback_velocity = Vector3.ZERO
		if fwd_dir != Vector3.ZERO:
			var target_angle = atan2(-fwd_dir.x, -fwd_dir.z)
			rotation.y = target_angle

func _execute_crush_slam_sequence_server(target: Node, fwd_dir: Vector3) -> void:
	# 1. Movement stops immediately upon contact with enemy
	is_crush_charging = false
	crush_charge_timer = 0.0
	velocity = Vector3.ZERO
	sync_crush_charge_state.rpc(false, fwd_dir)
	sync_crush_slam_state.rpc(true, fwd_dir)
	
	# 2. Apply a brief knock up to enemy
	var target_slam_pos = global_position + fwd_dir * 1.6
	if is_instance_valid(target) and not target.get("is_dead"):
		target.global_position.x = target_slam_pos.x
		target.global_position.z = target_slam_pos.z
		if target.has_method("apply_stun"):
			target.apply_stun(0.45 + 1.25)
		if target.has_method("apply_knockback"):
			target.apply_knockback(Vector3.UP * 16.0)
	
	show_melee_effect.rpc(true)
	
	# Brief knock up in the air
	await get_tree().create_timer(0.4).timeout
	
	show_melee_effect.rpc(false)
	
	if is_dead:
		sync_crush_slam_state.rpc(false, fwd_dir)
		return

	# 3. Slamming them back down, dealing damage and stunning
	var impact_pos = global_position + fwd_dir * 1.6
	show_crash_impact_effect.rpc(impact_pos)
	
	if is_instance_valid(target) and not target.get("is_dead"):
		if target.has_method("apply_knockback"):
			target.apply_knockback(Vector3.DOWN * 24.0)
		target.global_position.y = global_position.y
		target.take_damage(120.0, name.to_int(), ActionType.ABILITY)
		if target.has_method("apply_stun"):
			target.apply_stun(1.25)
	
	# AoE splash damage & stun to other nearby enemies caught in the impact
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if players_container:
		for p in players_container.get_children():
			if p != target and is_enemy(p) and not p.get("is_dead"):
				var diff = p.global_position - impact_pos
				if diff.length() <= 4.5 and abs(diff.y) <= 2.5:
					p.take_damage(55.0, name.to_int(), ActionType.ABILITY)
					if p.has_method("apply_stun"):
						p.apply_stun(0.8)
					if p.has_method("apply_knockback"):
						var kb = (Vector3(diff.x, 0.4, diff.z)).normalized() * 12.0
						p.apply_knockback(kb)

	sync_crush_slam_state.rpc(false, fwd_dir)

func _finish_crush_charge_empty_server(hit_wall: bool = false) -> void:
	is_crush_charging = false
	is_cc_immune = false
	is_casting_ability_four = false
	velocity = Vector3.ZERO
	sync_crush_charge_state.rpc(false, crush_charge_dir)
	if hit_wall:
		show_crash_impact_effect.rpc(global_position)

func _perform_dive_ability_four() -> void:
	var def = _ability_definitions.get("R", AbilitiesLibrary.get_ability("dive_tectonic_uprising"))
	ability_four_timer = def.cooldown if def else ability_four_cooldown
	ability_cast.emit(def.name if def else "Tectonic Uprising", "R")
	
	# Dive's Ult can be cast while under CC (except Silence), cleanses all CC immediately!
	stun_timer = 0.0
	slow_timer = 0.0
	slow_percent = 0.0
	if is_channeling:
		stop_channel()
	
	# Instantly grants +1 Dash Charge
	current_dash_charges = min(max_dash_charges, current_dash_charges + 1)
	
	var dur = def.effect.duration if (def and def.effect) else DIVE_ULT_BUFF_DURATION
	dive_ult_buff_timer = dur
	
	if multiplayer.is_server():
		sync_dive_ult_buff.rpc(dur)
	else:
		request_dive_ult_buff.rpc_id(1, dur)
	
	if multiplayer.is_server():
		execute_dive_ult_on_server(global_position, name.to_int())
	else:
		request_dive_ult.rpc_id(1, global_position)

@rpc("any_peer", "call_remote", "reliable")
func request_dive_ult(origin_pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	execute_dive_ult_on_server(origin_pos, sender_id)

func execute_dive_ult_on_server(origin_pos: Vector3, attacker_id: int) -> void:
	var players_container = get_tree().root.get_node_or_null("Main/Players")
	if not players_container:
		return
	
	var dive_player = players_container.get_node_or_null(str(attacker_id))
	if dive_player:
		# Cleanse all CC on Dive
		dive_player.stun_timer = 0.0
		dive_player.slow_timer = 0.0
		dive_player.slow_percent = 0.0
		dive_player.silence_timer = 0.0
		if dive_player.is_channeling:
			dive_player.cancel_channel()
		dive_player.dive_ult_buff_timer = DIVE_ULT_BUFF_DURATION
		if dive_player.current_dash_charges < 2:
			dive_player.current_dash_charges += 1
		dive_player.sync_dive_ult_buff.rpc(DIVE_ULT_BUFF_DURATION, dive_player.current_dash_charges)
		dive_player.sync_status_effects.rpc(0.0, 0.0, 0.0, 0.0)

	# Instantaneous burst damage & radial knockback to all enemies within 6.0m
	var aoe_radius: float = 6.0
	var ult_dmg: float = 65.0
	for p in players_container.get_children():
		if is_enemy(p) and not p.get("is_dead"):
			var diff = p.global_position - origin_pos
			var dist = diff.length()
			if dist <= aoe_radius and abs(diff.y) <= 3.5:
				p.take_damage(ult_dmg, attacker_id, ActionType.ABILITY)
				if p.has_method("apply_knockback"):
					var horiz = Vector3(diff.x, 0, diff.z)
					var horiz_dir = horiz.normalized() if horiz.length_squared() > 0.01 else -p.global_transform.basis.z.normalized()
					var impulse = horiz_dir * 18.0 + Vector3.UP * 16.0
					p.apply_knockback(impulse)

	# Spawn ring of 8 stone pillars around origin_pos at radius 5.5m
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node and main_node.has_method("spawn_temporary_terrain"):
		var ring_count = 8
		var ring_radius = 5.5
		for i in range(ring_count):
			var angle = i * (TAU / ring_count)
			var pillar_pos = origin_pos + Vector3(cos(angle), 0.0, sin(angle)) * ring_radius
			main_node.spawn_temporary_terrain(pillar_pos, 5.0, attacker_id)

	show_dive_ult_effect.rpc(origin_pos)

@rpc("any_peer", "call_local", "reliable")
func show_dive_ult_effect(pos: Vector3) -> void:
	if crash_visual:
		crash_visual.global_position = pos
		crash_visual.visible = true
		crash_visual.scale = Vector3(0.4, 1.0, 0.4)
		var tween = create_tween()
		tween.tween_property(crash_visual, "scale", Vector3(1.2, 1.0, 1.2), 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(crash_visual, "scale", Vector3(0.01, 1.0, 0.01), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): crash_visual.visible = false)

@rpc("any_peer", "call_local", "reliable")
func sync_dive_ult_buff(buff_time: float, dash_charges: int) -> void:
	dive_ult_buff_timer = buff_time
	current_dash_charges = dash_charges

func _perform_poke_ability_four() -> void:
	var def = _ability_definitions.get("R", AbilitiesLibrary.get_ability("poke_overcharge"))
	ability_four_timer = def.cooldown if def else ability_four_cooldown
	var dur = def.effect.duration if (def and def.effect) else 12.0
	poke_ult_buff_timer = dur
	ability_cast.emit(def.name if def else "Overcharge", "R")
	if multiplayer.is_server():
		sync_poke_ult_buff.rpc(dur)
	else:
		request_poke_ult.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func request_poke_ult() -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var player = get_tree().root.get_node_or_null("Main/Players/" + str(sender_id))
	if player and not player.get("is_dead"):
		var def = player._ability_definitions.get("R", AbilitiesLibrary.get_ability("poke_overcharge"))
		var dur = def.effect.duration if (def and def.effect) else 12.0
		player.poke_ult_buff_timer = dur
		player.sync_poke_ult_buff.rpc(dur)

@rpc("any_peer", "call_local", "reliable")
func sync_poke_ult_buff(buff_time: float) -> void:
	poke_ult_buff_timer = buff_time
