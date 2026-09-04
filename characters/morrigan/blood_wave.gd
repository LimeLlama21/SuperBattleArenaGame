class_name BloodWave
extends Area3D

@export var speed: float = 22.0
@export var max_range: float = 45.0
@export var wave_width: float = 12.0
@export var wave_height: float = 3.2
@export var damage: float = 50.0
@export var stun_duration: float = 1.2
@export var shooter_id: int = 0
@export var shooter_team: int = 0

var direction: Vector3 = Vector3.FORWARD
var traveled_distance: float = 0.0
var hit_player_ids: Dictionary = {}

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var wave_mesh: MeshInstance3D = $WaveMesh
@onready var crest_mesh: MeshInstance3D = $CrestMesh

func _ready() -> void:
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		direction = direction.normalized()
		look_at(global_position + direction, Vector3.UP)
	
	if collision_shape and collision_shape.shape is BoxShape3D:
		collision_shape.shape.size = Vector3(wave_width, wave_height, 1.6)
		collision_shape.position = Vector3(0, wave_height * 0.5, 0)
		
	if wave_mesh and wave_mesh.mesh is BoxMesh:
		wave_mesh.mesh.size = Vector3(wave_width, wave_height, 0.8)
		wave_mesh.position = Vector3(0, wave_height * 0.5, 0)
		
	if crest_mesh and crest_mesh.mesh is BoxMesh:
		crest_mesh.mesh.size = Vector3(wave_width * 1.05, 0.4, 1.2)
		crest_mesh.position = Vector3(0, wave_height + 0.1, 0)

	if is_server_authority():
		body_entered.connect(_on_body_entered)

func is_server_authority() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()

func _physics_process(delta: float) -> void:
	var step = speed * delta
	global_position += direction * step
	traveled_distance += step
	
	if is_server_authority():
		for body in get_overlapping_bodies():
			_check_hit(body)
			
	if traveled_distance >= max_range:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if not is_server_authority():
		return
	_check_hit(body)

func _check_hit(body: Node) -> void:
	if not is_instance_valid(body) or body.get("is_dead"):
		return
	var b_id = body.name.to_int()
	if hit_player_ids.has(b_id):
		return
		
	var is_enemy = (body.name != str(shooter_id)) and (shooter_team == 0 or body.get("team_id") != shooter_team)
	if is_enemy:
		hit_player_ids[b_id] = true
		if body.has_method("take_damage"):
			body.take_damage(damage, shooter_id, BasePlayer.ActionType.ABILITY)
		if body.has_method("apply_knockback"):
			var kb = Vector3.UP * 5.5
			body.apply_knockback(kb, true)
		if body.has_method("apply_stun"):
			body.apply_stun(stun_duration)
			
		var players_container = get_tree().root.get_node_or_null("Main/Players")
		if players_container:
			var shooter = players_container.get_node_or_null(str(shooter_id))
			if shooter and shooter.has_method("_on_character_damage_dealt"):
				shooter._on_character_damage_dealt(body, damage, BasePlayer.ActionType.ABILITY)
