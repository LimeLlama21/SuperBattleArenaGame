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
var distance_traveled: float = 0.0

func _ready() -> void:
	spawn_origin = global_position
	scale = Vector3.ONE * size
	if direction != Vector3.ZERO:
		var up_vec = Vector3.UP if abs(direction.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
		look_at(global_position + direction, up_vec)

	if max_range <= 0.0 and speed > 0.0 and lifetime > 0.0:
		max_range = speed * lifetime

	if multiplayer.is_server():
		body_entered.connect(_on_body_entered)
		if lifetime > 0.0:
			get_tree().create_timer(lifetime + 0.5).timeout.connect(_on_timeout)

func _physics_process(delta: float) -> void:
	var step = speed * delta
	global_position += direction * step
	if multiplayer.is_server():
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
	if not multiplayer.is_server() or has_spawned_terrain:
		return
	has_spawned_terrain = true
	if spawn_terrain_on_death:
		var main_node = get_tree().root.get_node_or_null("Main")
		if main_node and main_node.has_method("spawn_temporary_terrain"):
			main_node.spawn_temporary_terrain(global_position, 5.0, shooter_id)

func _on_body_entered(body: Node) -> void:
	if not multiplayer.is_server():
		return
	
	if body.has_method("take_damage") and body.name != str(shooter_id):
		if shooter_team > 0 and body.get("team_id") != null and body.team_id == shooter_team:
			return
		if not body.get("is_dead") and not (body in hit_targets):
			hit_targets.append(body)
			
			var shooter = get_tree().root.get_node_or_null("Main/Players/" + str(shooter_id))
			if shooter and shooter.get("character_name") == "Poke":
				if shooter.has_method("apply_speed_boost"):
					shooter.apply_speed_boost(2.5, 0.15)
					
			var final_damage = damage
			if effect_type == "execute_scaling":
				var target_hp = body.get("current_health") if body.get("current_health") != null else 100.0
				var target_max_hp = body.get("max_health") if body.get("max_health") != null else 100.0
				if target_max_hp > 0.0:
					var hp_pct = clamp(target_hp / target_max_hp, 0.0, 1.0)
					# Deals max damage (2.0x of normal) at <= 30% HP
					var missing_ratio = clamp((1.0 - hp_pct) / 0.70, 0.0, 1.0)
					final_damage = damage * (1.0 + missing_ratio)

			body.take_damage(final_damage, shooter_id, action_type)
			if effect_type == "slow" and body.has_method("apply_slow"):
				body.apply_slow(effect_duration, effect_intensity)
			elif effect_type == "knockback_stun" or effect_type == "poke_repulsor":
				if body.has_method("apply_knockback"):
					var kb_dir = Vector3(direction.x, 0.0, direction.z).normalized()
					body.apply_knockback(kb_dir * effect_intensity, true)
			elif effect_type == "reaper_tether":
				if shooter and shooter.has_method("start_reaper_tether_server"):
					shooter.start_reaper_tether_server(body)
			elif effect_type == "morrigan_tether_first" or effect_type == "morrigan_tether_recast":
				if shooter and shooter.has_method("on_tether_impact_server"):
					shooter.on_tether_impact_server(body, global_position, effect_type == "morrigan_tether_recast")
			
			if not pierces:
				_trigger_death_effects()
				queue_free()
	elif body is StaticBody3D:
		var body_name = body.name.to_lower()
		if body_name.contains("floor") or pierces:
			return
		if effect_type == "morrigan_tether_first" or effect_type == "morrigan_tether_recast":
			var shooter = get_tree().root.get_node_or_null("Main/Players/" + str(shooter_id))
			if shooter and shooter.has_method("on_tether_impact_server"):
				shooter.on_tether_impact_server(body, global_position, effect_type == "morrigan_tether_recast")
		_trigger_death_effects()
		queue_free()
