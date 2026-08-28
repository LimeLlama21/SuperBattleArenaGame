extends Area3D

@export var speed: float = 34.0
@export var damage: float = 22.0
@export var size: float = 1.0
@export var lifetime: float = 2.5
@export var effect_type: String = ""
@export var effect_duration: float = 0.0
@export var effect_intensity: float = 0.0
@export var pierces: bool = false
@export var spawn_terrain_on_death: bool = false

var shooter_id: int = 0
var direction: Vector3 = Vector3.FORWARD
var spawn_origin: Vector3 = Vector3.ZERO
var hit_targets: Array = []
var has_spawned_terrain: bool = false

func _ready() -> void:
	spawn_origin = global_position
	scale = Vector3.ONE * size
	if direction != Vector3.ZERO:
		look_at(global_position + direction, Vector3.UP)

	if multiplayer.is_server():
		body_entered.connect(_on_body_entered)
		get_tree().create_timer(lifetime).timeout.connect(_on_timeout)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

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
			main_node.spawn_temporary_terrain(global_position, 5.0)

func _on_body_entered(body: Node) -> void:
	if not multiplayer.is_server():
		return
	
	if body.has_method("take_damage") and body.name != str(shooter_id):
		if not body.get("is_dead") and not (body in hit_targets):
			hit_targets.append(body)
			
			var shooter = get_tree().root.get_node_or_null("Main/Players/" + str(shooter_id))
			if shooter and shooter.get("character_name") == "Poke":
				if shooter.has_method("apply_speed_boost"):
					shooter.apply_speed_boost(2.5, 0.15)
					
			body.take_damage(damage, shooter_id)
			if effect_type == "slow" and body.has_method("apply_slow"):
				body.apply_slow(effect_duration, effect_intensity)
			elif effect_type == "knockback_stun":
				if body.has_method("apply_knockback"):
					var kb_dir = Vector3(direction.x, 0.35, direction.z).normalized()
					body.apply_knockback(kb_dir * effect_intensity)
				if body.has_method("apply_stun"):
					body.apply_stun(effect_duration)
			
			if not pierces:
				_trigger_death_effects()
				queue_free()
	elif body is StaticBody3D:
		if body.name == "Floor":
			return
		_trigger_death_effects()
		queue_free()
