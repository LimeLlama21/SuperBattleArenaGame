class_name NeutralEntity
extends CharacterBody3D

## NeutralEntity - Base active entity class for all neutral creatures.
## Parallels PlayerBase (which registers CharacterData); NeutralEntity registers a NeutralType.
## Implements:
##   1. Data-driven stats and tiering from NeutralType.
##   2. Sequential attack pattern rotation against nearest target in range.
##   3. Combo reset timer (grace period before attack rotation resets).
##   4. Leash range checking and disengage / reset behavior.
##   5. Special attack / ultimate override triggers.
##   6. Team-wide reward dispatching (shared XP, shared Gold, unique team Boon).
##   7. Orange sphere visual representation by default.

const NeutralTypeClass = preload("res://maps/neutral_type.gd")
const NeutralAttackClass = preload("res://maps/neutral_attack.gd")
const NeutralSpecialAttackClass = preload("res://maps/neutral_special_attack.gd")
const NeutralRegistryClass = preload("res://maps/neutral_registry.gd")

signal damage_taken(amount: float, attacker_id: int)
signal died(attacker_id: int)
signal entity_reset()
signal team_rewards_awarded(team_id: int, xp: float, gold: int, unique_reward: String)
signal attack_started(attack_name: String, is_special: bool)
signal attack_hit(attack_name: String, is_special: bool)

enum State {
	IDLE,
	CHASING,
	WINDUP,
	ATTACKING,
	RECOVERY,
	SPECIAL_OVERRIDE,
	LEASHING,
	DEAD
}

@export var neutral_type: Resource = null:
	set(val):
		neutral_type = val
		if is_inside_tree() or collision_shape != null:
			_apply_neutral_type()

@export var entity_name: String = "NeutralEntity"
@export var team_id: int = 0 # Neutral (no team)
@export var spawn_position: Vector3 = Vector3.ZERO
@export var custom_material: StandardMaterial3D = null

var max_health: float = 200.0
var current_health: float = 200.0
var is_dead: bool = false
var is_neutral: bool = true

var health: float:
	get:
		return current_health
	set(val):
		current_health = val

# State Machine & Combat Timers
var state: State = State.IDLE
var state_timer: float = 0.0
var current_target: Node3D = null
var current_pattern_index: int = 0
var combo_timer: float = 0.0 # Generic timer between attacks: resets combo if runs out before next attack
var special_cooldown_timer: float = 0.0
var special_used_count: int = 0
var current_attack: Resource = null
var is_executing_special: bool = false
var is_stunned: bool = false
var stun_timer: float = 0.0

# Visual and Physics Nodes
var collision_shape: CollisionShape3D = null
var mesh_instance: MeshInstance3D = null
var combat_hitbox: CombatHitbox = null
var default_material: StandardMaterial3D = null

func _init() -> void:
	collision_layer = 2 # Characters layer
	collision_mask = 1  # Environment

func _ready() -> void:
	if not collision_shape:
		_setup_components()

	if spawn_position == Vector3.ZERO:
		spawn_position = position

	if neutral_type == null:
		# Default to basic_mob from registry
		neutral_type = NeutralRegistryClass.get_type("basic_mob")
	
	_apply_neutral_type()

func _setup_components() -> void:
	# 1. Physics Collision Shape (Sphere of radius 0.75m default)
	collision_shape = CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 0.75
	collision_shape.shape = sphere_shape
	add_child(collision_shape)

	# 2. Visual Mesh (Vibrant orange sphere default)
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.75
	sphere_mesh.height = 1.5
	sphere_mesh.radial_segments = 32
	sphere_mesh.rings = 16

	default_material = StandardMaterial3D.new()
	default_material.albedo_color = Color(1.0, 0.48, 0.05, 1.0)
	default_material.roughness = 0.35
	default_material.metallic = 0.15
	default_material.emission_enabled = true
	default_material.emission = Color(1.0, 0.38, 0.02) * 0.45
	sphere_mesh.material = default_material
	mesh_instance.mesh = sphere_mesh
	add_child(mesh_instance)

	# 3. CombatHitbox (Area3D hurtbox on layer 2)
	combat_hitbox = CombatHitbox.new()
	combat_hitbox.name = "CombatHitbox"
	combat_hitbox.collision_layer = 2
	combat_hitbox.collision_mask = 0
	var hitbox_col = CollisionShape3D.new()
	hitbox_col.name = "CollisionShape3D"
	var hitbox_shape = SphereShape3D.new()
	hitbox_shape.radius = 0.8
	hitbox_col.shape = hitbox_shape
	combat_hitbox.add_child(hitbox_col)
	add_child(combat_hitbox)

## Applies the registered NeutralType stats, rewards, and visual parameters
func _apply_neutral_type() -> void:
	if not neutral_type:
		return

	max_health = neutral_type.max_health
	current_health = max_health
	health = current_health

	var is_capsule: bool = ("mesh_shape" in neutral_type and neutral_type.mesh_shape == "capsule")
	var mat = custom_material if custom_material else default_material
	if mat:
		mat.albedo_color = neutral_type.mesh_color
		mat.emission_enabled = true
		mat.emission = neutral_type.emission_color * neutral_type.emission_energy

	if is_capsule:
		var cap_radius: float = neutral_type.capsule_radius if "capsule_radius" in neutral_type else 0.45
		var cap_height: float = neutral_type.capsule_height if "capsule_height" in neutral_type else 1.6
		if mesh_instance:
			var cap_mesh = CapsuleMesh.new()
			cap_mesh.radius = cap_radius
			cap_mesh.height = cap_height
			if mat:
				cap_mesh.material = mat
			mesh_instance.mesh = cap_mesh

		if collision_shape:
			var cap_col = CapsuleShape3D.new()
			cap_col.radius = cap_radius
			cap_col.height = cap_height
			collision_shape.shape = cap_col

		if combat_hitbox:
			var h_shape = combat_hitbox.get_node_or_null("CollisionShape3D") as CollisionShape3D
			if h_shape:
				var hit_cap = CapsuleShape3D.new()
				hit_cap.radius = cap_radius + 0.05
				hit_cap.height = cap_height + 0.1
				h_shape.shape = hit_cap
	else:
		var s_radius: float = neutral_type.sphere_radius if "sphere_radius" in neutral_type else 0.75
		if mesh_instance:
			var s_mesh = SphereMesh.new()
			s_mesh.radius = s_radius
			s_mesh.height = s_radius * 2.0
			if mat:
				s_mesh.material = mat
			mesh_instance.mesh = s_mesh

		if collision_shape:
			var col_s = SphereShape3D.new()
			col_s.radius = s_radius
			collision_shape.shape = col_s

		if combat_hitbox:
			var h_shape = combat_hitbox.get_node_or_null("CollisionShape3D") as CollisionShape3D
			if h_shape:
				var hit_s = SphereShape3D.new()
				hit_s.radius = s_radius + 0.05
				h_shape.shape = hit_s

## Main AI combat & leash loop
func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if special_cooldown_timer > 0.0:
		special_cooldown_timer -= delta

	# Generic combo reset timer: starts at the end of an attack and ticks down continuously
	# whenever current_pattern_index > 0 (between attacks: idle, chasing, leashing, or stunned).
	# If it runs out before starting the next attack, it automatically resets to the first attack!
	if current_pattern_index > 0 and state != State.WINDUP and state != State.ATTACKING and state != State.RECOVERY:
		combo_timer -= delta
		if combo_timer <= 0.0:
			current_pattern_index = 0
			combo_timer = 0.0

	# Hard CC Handling
	if is_stunned:
		stun_timer -= delta
		velocity = Vector3.ZERO
		if stun_timer <= 0.0:
			is_stunned = false
			stun_timer = 0.0
		return # Incapacitated, cannot move or initiate attacks

	match state:
		State.IDLE:
			_process_idle_state(delta)
		State.CHASING:
			_process_chase_state(delta)
		State.WINDUP:
			_process_windup_state(delta)
		State.ATTACKING:
			_process_attacking_state(delta)
		State.RECOVERY:
			_process_recovery_state(delta)
		State.SPECIAL_OVERRIDE:
			_process_windup_state(delta)
		State.LEASHING:
			_process_leashing_state(delta)

# Public accessors for test suites and gameplay controllers
func get_current_attack() -> Resource:
	return _get_current_attack()

func start_attack(atk: Resource, is_special: bool = false) -> void:
	_start_attack(atk, is_special)

func execute_attack_impact() -> void:
	_execute_attack_impact()

func can_trigger_special() -> bool:
	return _can_trigger_special()

func process_idle_state(delta: float) -> void:
	_process_idle_state(delta)

func process_chase_state(delta: float) -> void:
	_process_chase_state(delta)

func process_attacking_state(delta: float) -> void:
	_process_attacking_state(delta)

func process_recovery_state(delta: float) -> void:
	_process_recovery_state(delta)

func process_leashing_state(delta: float) -> void:
	_process_leashing_state(delta)

# -------------------------------------------------------------------------
# AI STATE MACHINE HANDLERS
# -------------------------------------------------------------------------

func _process_idle_state(delta: float) -> void:
	current_target = _find_nearest_target()

	if is_instance_valid(current_target):
		if _can_trigger_special():
			_start_attack(neutral_type.special_attack, true)
		else:
			_engage_target(current_target)
	else:
		# If displaced from spawn, leash back home
		if position.distance_to(spawn_position) > 0.5 and is_mobile():
			state = State.LEASHING

func _process_chase_state(delta: float) -> void:
	# 1. Leash check: distance from home anchor
	var dist_from_spawn = position.distance_to(spawn_position)
	var max_leash = neutral_type.leash_range if neutral_type else 14.0
	if dist_from_spawn > max_leash:
		_disengage_and_leash()
		return

	if not _is_target_valid(current_target):
		current_target = null
		state = State.IDLE
		return

	var dist_to_target = position.distance_to(current_target.position)
	var atk = _get_current_attack()
	var req_range = atk.attack_range if atk else 3.5

	if dist_to_target <= req_range:
		velocity = Vector3.ZERO
		if _can_trigger_special():
			_start_attack(neutral_type.special_attack, true)
		else:
			_start_attack(atk, false)
	else:
		# Move towards target if mobile
		if is_mobile():
			var dir = (current_target.position - position).normalized()
			dir.y = 0.0
			velocity = dir * neutral_type.move_speed
			move_and_slide()
		else:
			# Stationary mobs remain in place and wait for target to enter attack range
			state = State.IDLE

func _process_windup_state(delta: float) -> void:
	state_timer -= delta
	if is_instance_valid(current_target):
		# Turn to face target during windup
		var look_pos = current_target.position
		look_pos.y = position.y
		if look_pos != position:
			look_at(look_pos, Vector3.UP)

	if state_timer <= 0.0:
		_execute_attack_impact()

func _process_attacking_state(delta: float) -> void:
	# Transient execution frame -> transitions immediately to recovery
	state = State.RECOVERY
	var rec_time = current_attack.recovery_time if current_attack else 0.5
	state_timer = rec_time

func _process_recovery_state(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		# Attack completed! Advance rotation
		if not is_executing_special:
			if neutral_type and neutral_type.attack_pattern.size() > 0:
				current_pattern_index = (current_pattern_index + 1) % neutral_type.attack_pattern.size()
				# Generic combo timer starts right at the end of the attack!
				if current_pattern_index > 0:
					combo_timer = neutral_type.combo_reset_delay if neutral_type else 2.5
				else:
					combo_timer = 0.0
		else:
			is_executing_special = false

		state = State.IDLE

func _process_leashing_state(delta: float) -> void:
	current_target = null
	var dist_home = position.distance_to(spawn_position)
	if dist_home <= 0.4 or not is_mobile():
		position = spawn_position
		velocity = Vector3.ZERO
		state = State.IDLE
		current_pattern_index = 0
		combo_timer = 0.0
		# Soft regen upon returning home
		current_health = max_health
		health = max_health
	else:
		var dir = (spawn_position - position).normalized()
		dir.y = 0.0
		velocity = dir * (neutral_type.move_speed * 1.5 if neutral_type else 4.0)
		move_and_slide()

# -------------------------------------------------------------------------
# ATTACK EXECUTION & SPECIAL TRIGGER LOGIC
# -------------------------------------------------------------------------

func _start_attack(atk: Resource, is_special: bool) -> void:
	if not atk:
		state = State.IDLE
		return

	# Next attack started before combo timer ran out! Clear timer
	combo_timer = 0.0
	current_attack = atk
	is_executing_special = is_special
	state = State.SPECIAL_OVERRIDE if is_special else State.WINDUP
	state_timer = atk.windup_time
	attack_started.emit(atk.name, is_special)

func _execute_attack_impact() -> void:
	if not current_attack:
		state = State.IDLE
		return

	attack_hit.emit(current_attack.name, is_executing_special)

	match current_attack.attack_type:
		"melee":
			_strike_melee(current_attack)
		"cone":
			_strike_cone(current_attack)
		"bullet_spread", "projectile":
			_fire_bullet_spread(current_attack)
		"aoe":
			_strike_aoe(current_attack)
		_:
			_strike_melee(current_attack)

	if is_executing_special:
		special_used_count += 1
		var cd = neutral_type.special_attack.trigger_cooldown if neutral_type and neutral_type.special_attack else 15.0
		special_cooldown_timer = cd

	state = State.ATTACKING

func is_target_in_cone(target_pos: Vector3, reach: float, cone_angle_deg: float) -> bool:
	var to_target = target_pos - global_position
	to_target.y = 0.0
	var dist = to_target.length()
	if dist > reach:
		return false
	var forward = -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.0001:
		forward = forward.normalized()
	else:
		forward = Vector3.FORWARD
	var dir_to_target = to_target.normalized() if dist > 0.0001 else forward
	return forward.angle_to(dir_to_target) <= deg_to_rad(cone_angle_deg * 0.5)

func _strike_cone(atk: Resource) -> Array[Node3D]:
	var reach: float = atk.cone_range if "cone_range" in atk else 3.6
	var angle_deg: float = atk.cone_angle if "cone_angle" in atk else 60.0
	var hit_targets: Array[Node3D] = []
	var candidates = _get_players_in_range(reach)
	for p in candidates:
		if is_target_in_cone(p.global_position, reach, angle_deg):
			hit_targets.append(p)
			if p.has_method("take_damage"):
				p.take_damage(atk.damage, 0, 0)
	return hit_targets

func _strike_melee(atk: Resource) -> void:
	var hit_targets = _get_players_in_range(atk.attack_range * 1.25)
	for p in hit_targets:
		if p.has_method("take_damage"):
			p.take_damage(atk.damage, 0, 0)

func _strike_aoe(atk: Resource) -> void:
	var hit_targets = _get_players_in_range(atk.hitbox_radius)
	for p in hit_targets:
		if p.has_method("take_damage"):
			p.take_damage(atk.damage, 0, 0)

func _fire_bullet_spread(atk: Resource) -> void:
	var target_dir = -global_transform.basis.z
	if is_instance_valid(current_target):
		target_dir = (current_target.global_position - global_position).normalized()
		target_dir.y = 0.0

	var count = max(1, atk.bullet_count)
	var spread_rad = deg_to_rad(atk.spread_angle)
	var start_angle = -spread_rad * 0.5
	var angle_step = 0.0 if count <= 1 else spread_rad / float(count - 1)

	var proj_scene = load("res://projectile.tscn")
	for i in range(count):
		var angle = start_angle + (i * angle_step) if count > 1 else 0.0
		var bullet_dir = target_dir.rotated(Vector3.UP, angle).normalized()

		if proj_scene:
			var proj = proj_scene.instantiate()
			proj.shooter_id = 0
			proj.shooter_team = 0 # Neutral: can damage any player
			proj.damage = atk.damage
			proj.speed = atk.projectile_speed
			proj.direction = bullet_dir
			proj.global_position = global_position + Vector3(0, 0.75, 0) + bullet_dir * 0.9
			get_tree().root.add_child(proj)
		else:
			# Fallback if projectile scene unavailable: check direct ray
			_strike_melee(atk)
			break

func _can_trigger_special() -> bool:
	if not neutral_type or not neutral_type.special_attack:
		return false
	var spec = neutral_type.special_attack
	if spec.max_uses > 0 and special_used_count >= spec.max_uses:
		return false
	if special_cooldown_timer > 0.0:
		return false

	match spec.trigger_type:
		"hp_threshold":
			return (current_health / max_health) <= spec.trigger_hp_threshold
		"timer_cooldown":
			return special_cooldown_timer <= 0.0
		"player_count":
			return _get_players_in_range(neutral_type.aggro_range).size() >= spec.trigger_target_count
		_:
			return false

func _get_current_attack() -> Resource:
	if not neutral_type or neutral_type.attack_pattern.is_empty():
		return null
	var idx = clamp(current_pattern_index, 0, neutral_type.attack_pattern.size() - 1)
	return neutral_type.attack_pattern[idx]

func _engage_target(target: Node3D) -> void:
	var dist = position.distance_to(target.position)
	var atk = _get_current_attack()
	var req_range = atk.attack_range if atk else 3.5

	if dist <= req_range:
		_start_attack(atk, false)
	else:
		state = State.CHASING

func _disengage_and_leash() -> void:
	current_target = null
	current_pattern_index = 0
	combo_timer = 0.0
	state = State.LEASHING

func _is_target_valid(t: Node3D) -> bool:
	if not is_instance_valid(t):
		return false
	if "is_dead" in t and t.is_dead:
		return false
	var max_leash = neutral_type.leash_range if neutral_type else 14.0
	if t.position.distance_to(spawn_position) > max_leash:
		return false
	return true

func _find_nearest_target() -> Node3D:
	var candidates = _get_players_in_range(neutral_type.aggro_range if neutral_type else 8.0)
	var best_p: Node3D = null
	var best_dist: float = INF
	for p in candidates:
		var d = position.distance_to(p.position)
		if d < best_dist:
			best_dist = d
			best_p = p
	return best_p

func _get_players_in_range(search_radius: float) -> Array[Node3D]:
	var found: Array[Node3D] = []
	var p_container = get_tree().root.get_node_or_null("Main/Players") if get_tree() and get_tree().root else null
	if p_container:
		for child in p_container.get_children():
			if child is Node3D and "is_dead" in child and not child.is_dead:
				if position.distance_to(child.position) <= search_radius:
					found.append(child)
	if get_parent():
		for child in get_parent().get_children():
			if child != self and child is Node3D and "is_dead" in child and not child.is_dead:
				if not found.has(child) and position.distance_to(child.position) <= search_radius:
					found.append(child)
	return found

func is_mobile() -> bool:
	return neutral_type != null and neutral_type.move_speed > 0.0

func get_hitbox_radius() -> float:
	if not neutral_type:
		return 0.75
	if "mesh_shape" in neutral_type and neutral_type.mesh_shape == "capsule":
		return neutral_type.capsule_radius if "capsule_radius" in neutral_type else 0.45
	return neutral_type.sphere_radius if "sphere_radius" in neutral_type else 0.75

# -------------------------------------------------------------------------
# DAMAGE & DEATH / REWARD LIFECYCLE
# -------------------------------------------------------------------------

func take_damage(amount: float, attacker_id: int = 0, action_type: int = 0, is_projectile: bool = false, damage_type: int = 0) -> void:
	if is_dead:
		return
	current_health = max(0.0, current_health - amount)
	health = current_health
	damage_taken.emit(amount, attacker_id)
	if current_health <= 0.0:
		die(attacker_id)

func take_projectile_damage(amount: float, attacker_id: int = 0, action_type: int = 0) -> void:
	take_damage(amount, attacker_id, action_type, true)

func apply_stun(duration: float) -> void:
	if is_dead or duration <= 0.0:
		return
	is_stunned = true
	stun_timer = max(stun_timer, duration)

	# If interrupted during an attack windup:
	if state == State.WINDUP or state == State.SPECIAL_OVERRIDE:
		state = State.IDLE
		is_executing_special = false
		# Swing cancelled: ensure combo timer is ticking down if mid-combo
		if current_pattern_index > 0 and combo_timer <= 0.0:
			combo_timer = neutral_type.combo_reset_delay if neutral_type else 2.5

func apply_status_by_name(status_type: String, duration: float, intensity: float = 0.0, source: Node = null, params: Dictionary = {}) -> void:
	if status_type.to_lower() == "stun":
		apply_stun(duration)

func apply_status_effect(effect: StatusEffect) -> void:
	if effect and effect.id == "stun":
		apply_stun(effect.duration)

func die(attacker_id: int = 0) -> void:
	is_dead = true
	state = State.DEAD
	visible = false
	set_collision_layer_value(2, false)
	if combat_hitbox:
		combat_hitbox.set_collision_layer_value(2, false)

	distribute_team_rewards(attacker_id)
	died.emit(attacker_id)

## Grants shared XP, shared Gold, and unique Boon to the killer's entire team
func distribute_team_rewards(attacker_id: int) -> void:
	if not neutral_type:
		return

	var killer_team: int = 0
	var p_container = get_tree().root.get_node_or_null("Main/Players")
	if p_container and attacker_id > 0:
		var killer_node = p_container.get_node_or_null(str(attacker_id))
		if killer_node and "team_id" in killer_node:
			killer_team = killer_node.team_id

	if p_container and killer_team > 0:
		var main_node = get_tree().root.get_node_or_null("Main")
		for p in p_container.get_children():
			if "team_id" in p and p.team_id == killer_team:
				# 1. Team-wide XP
				if neutral_type.team_xp > 0.0 and p.has_method("add_xp"):
					p.add_xp(neutral_type.team_xp)
				# 2. Team-wide Gold
				if neutral_type.team_gold > 0 and "gold" in p:
					p.gold += neutral_type.team_gold
					if main_node and "connected_players" in main_node:
						var pid = int(str(p.name))
						if main_node.connected_players.has(pid):
							main_node.connected_players[pid]["gold"] = p.gold
					if p.has_method("sync_inventory") and p.has_method("is_server_authoritative") and p.is_server_authoritative():
						p.sync_inventory.rpc(p.item_slots, p.gold)
				# 3. Unique Reward / Team Boon
				if not neutral_type.unique_reward.is_empty():
					_apply_boon_to_player(p, neutral_type.unique_reward, neutral_type.unique_reward_duration)

	team_rewards_awarded.emit(killer_team, neutral_type.team_xp, neutral_type.team_gold, neutral_type.unique_reward)

func _apply_boon_to_player(p: Node, boon_id: String, duration: float) -> void:
	if not is_instance_valid(p):
		return
	if boon_id == "speed_boost" or boon_id == "boon_swiftness":
		if p.has_method("apply_status_by_name"):
			p.apply_status_by_name("speed_boost", duration, 0.25)
	elif boon_id == "boon_overlord":
		if p.has_method("apply_status_by_name"):
			p.apply_status_by_name("speed_boost", duration, 0.15)
		if p.has_method("apply_status_effect"):
			var eff = StatusEffect.new("boon_overlord", duration, 0.20, self)
			p.apply_status_effect(eff)
	else:
		if p.has_method("apply_status_by_name"):
			p.apply_status_by_name(boon_id, duration, 0.20)

func reset_entity() -> void:
	is_dead = false
	state = State.IDLE
	position = spawn_position
	velocity = Vector3.ZERO
	current_health = max_health
	health = max_health
	visible = true
	current_target = null
	current_pattern_index = 0
	combo_timer = 0.0
	special_used_count = 0
	special_cooldown_timer = 0.0
	is_executing_special = false
	is_stunned = false
	stun_timer = 0.0

	set_collision_layer_value(2, true)
	if combat_hitbox:
		combat_hitbox.set_collision_layer_value(2, true)

	entity_reset.emit()
