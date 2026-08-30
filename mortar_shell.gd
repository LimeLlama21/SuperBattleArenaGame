class_name MortarShell
extends Node3D

@export var start_pos: Vector3 = Vector3.ZERO
@export var end_pos: Vector3 = Vector3.ZERO
@export var speed: float = 24.0
@export var aoe_radius: float = 3.2
@export var damage: float = 45.0
@export var shooter_id: int = 0
@export var shooter_team: int = 0

var apex_height: float = 5.0
var flight_duration: float = 1.0
var elapsed_time: float = 0.0
var is_exploded: bool = false

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var trail_mesh: MeshInstance3D = $TrailMesh

func _ready() -> void:
	global_position = start_pos
	var horizontal_dist = Vector2(start_pos.x - end_pos.x, start_pos.z - end_pos.z).length()
	apex_height = max(3.5, horizontal_dist * 0.42)
	flight_duration = max(0.4, horizontal_dist / max(1.0, speed))

func _physics_process(delta: float) -> void:
	if is_exploded:
		return
		
	elapsed_time += delta
	var alpha = clamp(elapsed_time / flight_duration, 0.0, 1.0)
	
	var current_xz = start_pos.lerp(end_pos, alpha)
	var current_y = lerp(start_pos.y, end_pos.y, alpha) + 4.0 * apex_height * alpha * (1.0 - alpha)
	global_position = Vector3(current_xz.x, current_y, current_xz.z)
	
	if alpha >= 1.0:
		_explode()

func _explode() -> void:
	if is_exploded:
		return
	is_exploded = true
	
	# Visual explosion
	var blast = Node3D.new()
	blast.top_level = true
	blast.global_position = end_pos + Vector3(0, 0.1, 0)
	get_tree().root.add_child(blast)
	
	var blast_mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = aoe_radius
	cyl.bottom_radius = aoe_radius
	cyl.height = 0.4
	blast_mesh.mesh = cyl
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.05, 0.35, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.1, 0.9, 1.0)
	mat.emission_energy_multiplier = 4.0
	blast_mesh.material_override = mat
	blast.add_child(blast_mesh)
	
	var tw = blast.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.28)
	tw.tween_callback(blast.queue_free)
	
	if multiplayer.is_server():
		var players_container = get_tree().root.get_node_or_null("Main/Players")
		if players_container:
			for player in players_container.get_children():
				if player is Node3D and not player.get("is_dead"):
					var is_enemy = (player.name != str(shooter_id)) and (shooter_team == 0 or player.get("team_id") != shooter_team)
					if is_enemy:
						var to_p = player.global_position - end_pos
						to_p.y = 0.0
						if to_p.length() <= aoe_radius:
							if player.has_method("take_damage"):
								player.take_damage(damage, shooter_id, BasePlayer.ActionType.ABILITY)
							var shooter = players_container.get_node_or_null(str(shooter_id))
							if shooter and shooter.has_method("_on_character_damage_dealt"):
								shooter._on_character_damage_dealt(player, damage, BasePlayer.ActionType.ABILITY)
	
	queue_free()
