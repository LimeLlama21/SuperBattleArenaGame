extends Area3D

enum ProjectileClassification {
	TRAJECTORY,     # Generic damage/effects: Always follows its entire trajectory (full max_range/lifetime)
	TARGET_LOCATION # Targeted: Travels to mouse/target distance when cast, then triggers payload/burst
}

@export var classification: ProjectileClassification = ProjectileClassification.TRAJECTORY
@export var speed: float = 34.0
@export var damage: float = 22.0
@export var size: float = 1.0
@export var lifetime: float = 2.5
@export var max_range: float = 0.0
@export var target_distance: float = 0.0
@export var effect_type: String = ""
@export var effect_duration: float = 0.0
@export var effect_intensity: float = 0.0
@export var pierces: bool = false
@export var spawn_terrain_on_death: bool = false

var shooter_id: int = 0
var shooter_team: int = 0
var action_type: int = 0 # 0 = ATTACK, 1 = ABILITY
var direction: Vector3 = Vector3.FORWARD
var spawn_origin: Vector3 = Vector3.ZERO
var hit_targets: Array = []
var has_spawned_terrain: bool = false
var has_hit_any_enemy: bool = false
var distance_traveled: float = 0.0

func _ready() -> void:
	spawn_origin = global_position
	scale = Vector3.ONE * size
	if classification == ProjectileClassification.TRAJECTORY:
		direction.y = 0.0
		if direction.length_squared() > 0.0001:
			direction = direction.normalized()
	if direction != Vector3.ZERO:
		var up_vec = Vector3.UP if abs(direction.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
		look_at(global_position + direction, up_vec)

	if effect_type == "poke_sniper_laser":
		var mesh_inst = get_node_or_null("MeshInstance3D") as MeshInstance3D
		var col_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
		if mesh_inst:
			var cap = CapsuleMesh.new()
			cap.radius = 0.22
			cap.height = 3.5
			mesh_inst.mesh = cap
			mesh_inst.rotation.x = deg_to_rad(90.0)
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.15, 0.95, 1.0, 1.0)
			mat.emission_enabled = true
			mat.emission = Color(0.3, 0.95, 1.0, 1.0)
			mat.emission_energy_multiplier = 6.0
			mesh_inst.material_override = mat
		if col_shape:
			var cap_shape = CapsuleShape3D.new()
			cap_shape.radius = 0.35
			cap_shape.height = 3.5
			col_shape.shape = cap_shape
			col_shape.rotation.x = deg_to_rad(90.0)
	elif effect_type == "poke_sniper_empowered":
		var mesh_inst = get_node_or_null("MeshInstance3D") as MeshInstance3D
		var col_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
		if mesh_inst:
			var cap = CapsuleMesh.new()
			cap.radius = 0.28
			cap.height = 4.0
			mesh_inst.mesh = cap
			mesh_inst.rotation.x = deg_to_rad(90.0)
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(1.0, 0.2, 0.85, 1.0)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.25, 0.9, 1.0)
			mat.emission_energy_multiplier = 8.0
			mesh_inst.material_override = mat
		if col_shape:
			var cap_shape = CapsuleShape3D.new()
			cap_shape.radius = 0.40
			cap_shape.height = 4.0
			col_shape.shape = cap_shape
			col_shape.rotation.x = deg_to_rad(90.0)
	elif effect_type == "poke_orbital_hyperbeam":
		var mesh_inst = get_node_or_null("MeshInstance3D") as MeshInstance3D
		var col_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
		if mesh_inst:
			var cap = CapsuleMesh.new()
			cap.radius = 1.4
			cap.height = 6.0
			mesh_inst.mesh = cap
			mesh_inst.rotation.x = deg_to_rad(90.0)
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.2, 0.95, 1.0, 0.9)
			mat.emission_enabled = true
			mat.emission = Color(0.4, 0.95, 1.0, 1.0)
			mat.emission_energy_multiplier = 10.0
			mesh_inst.material_override = mat
		if col_shape:
			var cap_shape = CapsuleShape3D.new()
			cap_shape.radius = 1.6
			cap_shape.height = 6.0
			col_shape.shape = cap_shape
			col_shape.rotation.x = deg_to_rad(90.0)
	elif effect_type == "morrigan_feather":
		var mesh_inst = get_node_or_null("MeshInstance3D") as MeshInstance3D
		var col_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
		if mesh_inst:
			var cap = CapsuleMesh.new()
			cap.radius = 0.16
			cap.height = 0.85
			mesh_inst.mesh = cap
			mesh_inst.rotation.x = deg_to_rad(90.0)
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.2, 0.02, 0.35, 1.0)
			mat.emission_enabled = true
			mat.emission = Color(0.75, 0.15, 0.95, 1.0)
			mat.emission_energy_multiplier = 5.0
			mesh_inst.material_override = mat
		if col_shape:
			var cap_shape = CapsuleShape3D.new()
			cap_shape.radius = 0.22
			cap_shape.height = 0.85
			col_shape.shape = cap_shape
			col_shape.rotation.x = deg_to_rad(90.0)
	elif effect_type == "blood_wave":
		var mesh_inst = get_node_or_null("MeshInstance3D") as MeshInstance3D
		var col_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
		if mesh_inst:
			var box = BoxMesh.new()
			box.size = Vector3(10.0, 2.5, 1.2)
			mesh_inst.mesh = box
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.85, 0.05, 0.1, 0.85)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.1, 0.2, 1.0)
			mat.emission_energy_multiplier = 4.0
			mesh_inst.material_override = mat
		if col_shape:
			var box_shape = BoxShape3D.new()
			box_shape.size = Vector3(10.0, 2.5, 1.6)
			col_shape.shape = box_shape
	elif effect_type == "mortar_shell":
		var mesh_inst = get_node_or_null("MeshInstance3D") as MeshInstance3D
		if mesh_inst:
			var sph = SphereMesh.new()
			sph.radius = 0.55
			sph.height = 1.1
			mesh_inst.mesh = sph
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.4, 0.05, 0.5, 1.0)
			mat.emission_enabled = true
			mat.emission = Color(0.8, 0.1, 0.9, 1.0)
			mat.emission_energy_multiplier = 4.0
			mesh_inst.material_override = mat
	elif effect_type == "vision_flare":
		var mesh_inst = get_node_or_null("MeshInstance3D") as MeshInstance3D
		if mesh_inst:
			var sph = SphereMesh.new()
			sph.radius = 0.4
			sph.height = 0.8
			mesh_inst.mesh = sph
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.1, 0.9, 1.0, 1.0)
			mat.emission_enabled = true
			mat.emission = Color(0.2, 0.95, 1.0, 1.0)
			mat.emission_energy_multiplier = 6.0
			mesh_inst.material_override = mat
	elif effect_type == "sticky_grenade":
		var mesh_inst = get_node_or_null("MeshInstance3D") as MeshInstance3D
		if mesh_inst:
			var sph = SphereMesh.new()
			sph.radius = 0.45
			sph.height = 0.9
			mesh_inst.mesh = sph
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(1.0, 0.6, 0.1, 1.0)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.7, 0.2, 1.0)
			mat.emission_energy_multiplier = 5.0
			mesh_inst.material_override = mat
	elif effect_type == "dive_earth_tremor":
		var mesh_inst = get_node_or_null("MeshInstance3D") as MeshInstance3D
		var col_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
		if mesh_inst:
			var box = BoxMesh.new()
			box.size = Vector3(2.4, 0.45, 1.4)
			mesh_inst.mesh = box
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.2, 0.85, 1.0, 0.95)
			mat.emission_enabled = true
			mat.emission = Color(0.2, 0.95, 1.0, 1.0)
			mat.emission_energy_multiplier = 4.5
			mesh_inst.material_override = mat
		if col_shape:
			var box_shape = BoxShape3D.new()
			box_shape.size = Vector3(2.4, 1.0, 1.4)
			col_shape.shape = box_shape

	if max_range <= 0.0:
		if speed > 0.0 and lifetime > 0.0:
			max_range = speed * lifetime
		else:
			max_range = 50.0

	if lifetime <= 0.0 and speed > 0.0:
		lifetime = max_range / speed

	if is_server_authority():
		body_entered.connect(_on_body_entered)
		area_entered.connect(_on_area_entered)
		if lifetime > 0.0:
			get_tree().create_timer(lifetime + 0.2).timeout.connect(_on_timeout)

func is_server_authority() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()

func _physics_process(delta: float) -> void:
	var step = speed * delta
	global_position += direction * step
	if is_server_authority():
		distance_traveled += step
		if classification == ProjectileClassification.TARGET_LOCATION:
			var effective_target = target_distance if target_distance > 0.0 else max_range
			if distance_traveled >= effective_target:
				_trigger_death_effects()
				queue_free()
		else: # TRAJECTORY: Generic damage/effect projectiles always follow their entire trajectory
			if max_range > 0.0 and distance_traveled >= max_range:
				_trigger_death_effects()
				queue_free()

func _on_timeout() -> void:
	_trigger_death_effects()
	queue_free()

func _trigger_death_effects() -> void:
	if not is_server_authority() or has_spawned_terrain:
		return
	has_spawned_terrain = true
	var main_node = get_tree().root.get_node_or_null("Main")
	if effect_type == "poke_sniper_empowered" and not has_hit_any_enemy:
		var shooter = get_tree().root.get_node_or_null("Main/Players/" + str(shooter_id))
		if shooter and shooter.has_method("on_empowered_sniper_miss"):
			shooter.on_empowered_sniper_miss("dissipated")
	elif effect_type == "mortar_shell":
		if main_node and main_node.has_method("spawn_slowing_dot_zone"):
			main_node.spawn_slowing_dot_zone(global_position, 3.2, 4.5, 15.0, 0.40, shooter_id, shooter_team)
	elif effect_type == "vision_flare":
		if main_node and main_node.has_method("spawn_vision_reveal_zone"):
			main_node.spawn_vision_reveal_zone(global_position, 12.0, 5.5, shooter_id, shooter_team)
	elif effect_type == "sticky_grenade":
		var players = get_tree().get_nodes_in_group("players")
		for p in players:
			if p != null and not p.get("is_dead") and p.name != str(shooter_id):
				if shooter_team > 0 and p.get("team_id") != null and p.team_id == shooter_team:
					continue
				var d = (p.global_position - global_position).length()
				if d <= 3.5 and p.has_method("take_damage"):
					p.take_damage(damage, shooter_id, action_type)
	if spawn_terrain_on_death:
		if main_node and main_node.has_method("spawn_temporary_terrain"):
			main_node.spawn_temporary_terrain(global_position, 5.0, shooter_id)

func _on_area_entered(area: Area3D) -> void:
	if not is_server_authority():
		return
	var target = null
	if area is CombatHitbox:
		target = area.get_character()
	elif area.has_meta("character"):
		target = area.get_meta("character")
	elif "character" in area and is_instance_valid(area.character):
		target = area.character
	elif area.name == "CombatHitbox":
		target = area.get_parent()
	elif area.has_method("take_damage"):
		target = area
	
	if target and target != self:
		_process_target_hit(target)

func _on_body_entered(body: Node) -> void:
	if not is_server_authority():
		return
	if body is StaticBody3D:
		_process_terrain_hit(body)
	elif body.has_method("take_damage"):
		_process_target_hit(body)

func _process_target_hit(body: Node) -> void:
	if body.name == str(shooter_id):
		return
	if shooter_team > 0 and body.get("team_id") != null and body.team_id == shooter_team:
		return
	if not body.get("is_dead") and not (body in hit_targets):
		hit_targets.append(body)
		
		var final_damage = damage
		if effect_type == "execute_scaling":
			var target_hp = body.get("current_health") if body.get("current_health") != null else 100.0
			var target_max_hp = body.get("max_health") if body.get("max_health") != null else 100.0
			if target_max_hp > 0.0:
				var hp_pct = clamp(target_hp / target_max_hp, 0.0, 1.0)
				var missing_ratio = clamp((1.0 - hp_pct) / 0.70, 0.0, 1.0)
				final_damage = damage * (1.0 + missing_ratio)

		body.take_damage(final_damage, shooter_id, action_type)
		if effect_type == "blood_wave" and body.has_method("apply_stun"):
			body.apply_stun(1.0)
		if (effect_type == "slow" or effect_type == "dive_earth_tremor") and body.has_method("apply_slow"):
			body.apply_slow(effect_duration if effect_duration > 0.0 else 2.0, effect_intensity if effect_intensity > 0.0 else 0.40)
		elif effect_type == "knockback_stun" or effect_type == "poke_repulsor":
			if body.has_method("apply_knockback"):
				var kb_dir = Vector3(direction.x, 0.0, direction.z).normalized()
				body.apply_knockback(kb_dir * effect_intensity, true, effect_duration)
		var shooter = get_tree().root.get_node_or_null("Main/Players/" + str(shooter_id))
		if effect_type == "poke_sniper_empowered":
			has_hit_any_enemy = true
			if shooter and shooter.has_method("on_empowered_sniper_hit"):
				shooter.on_empowered_sniper_hit(body)
		elif effect_type == "reaper_tether":
			if shooter and shooter.has_method("start_reaper_tether_server"):
				shooter.start_reaper_tether_server(body)
		elif effect_type == "morrigan_tether_first" or effect_type == "morrigan_tether_recast":
			if shooter and shooter.has_method("on_tether_impact_server"):
				shooter.on_tether_impact_server(body, global_position, effect_type == "morrigan_tether_recast")
		
		if not pierces:
			_trigger_death_effects()
			queue_free()

func _process_terrain_hit(body: StaticBody3D) -> void:
	var body_name = body.name.to_lower()
	if body_name.contains("floor"):
		return
	if effect_type == "poke_orbital_hyperbeam":
		return # Pierces terrain/walls!
	if pierces and effect_type != "poke_sniper_laser" and effect_type != "poke_sniper_empowered":
		return
	if effect_type == "poke_sniper_empowered":
		if not has_hit_any_enemy:
			var shooter = get_tree().root.get_node_or_null("Main/Players/" + str(shooter_id))
			if shooter and shooter.has_method("on_empowered_sniper_miss"):
				shooter.on_empowered_sniper_miss("wall")
	if effect_type == "morrigan_tether_first" or effect_type == "morrigan_tether_recast":
		var shooter = get_tree().root.get_node_or_null("Main/Players/" + str(shooter_id))
		if shooter and shooter.has_method("on_tether_impact_server"):
			shooter.on_tether_impact_server(body, global_position, effect_type == "morrigan_tether_recast")
	_trigger_death_effects()
	queue_free()
