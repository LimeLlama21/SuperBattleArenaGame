class_name StickyGrenade
extends Area3D

enum State {
	FLYING,
	STUCK,
	EXPLODED
}

@export var speed: float = 42.0
@export var max_range: float = 17.5 # Half of Morrigan's primary fire (35.0 / 2)
@export var aoe_radius: float = 3.5
@export var damage: float = 70.0
@export var fuse_duration: float = 1.2
@export var shooter_id: int = 0
@export var shooter_team: int = 0
@export var direction: Vector3 = Vector3.FORWARD

var current_state: State = State.FLYING
var distance_traveled: float = 0.0
var fuse_timer: float = 0.0
var stuck_target: Node3D = null
var stuck_local_offset: Vector3 = Vector3.ZERO

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var pulse_light: OmniLight3D = get_node_or_null("OmniLight3D")
@onready var indicator_mesh: MeshInstance3D = get_node_or_null("IndicatorRing")

var pulse_tween: Tween = null

func _ready() -> void:
	if direction != Vector3.ZERO:
		var up_vec = Vector3.UP if abs(direction.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
		look_at(global_position + direction, up_vec)
	
	if indicator_mesh:
		indicator_mesh.visible = false
		if indicator_mesh.mesh is TorusMesh:
			indicator_mesh.mesh.outer_radius = aoe_radius
			indicator_mesh.mesh.inner_radius = max(0.1, aoe_radius - 0.15)

	if is_multiplayer_authority_or_offline():
		body_entered.connect(_on_body_entered)

func is_multiplayer_authority_or_offline() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()

func _physics_process(delta: float) -> void:
	match current_state:
		State.FLYING:
			var step = speed * delta
			global_position += direction * step
			distance_traveled += step
			
			if is_multiplayer_authority_or_offline() and distance_traveled >= max_range:
				# Hit nothing within range -> Disappears cleanly
				_fizzle_and_free()

		State.STUCK:
			if stuck_target and is_instance_valid(stuck_target):
				global_position = stuck_target.global_position + stuck_local_offset
			
			fuse_timer -= delta
			if pulse_light:
				pulse_light.energy = 2.0 + sin(fuse_timer * 25.0) * 1.5

			if is_multiplayer_authority_or_offline() and fuse_timer <= 0.0:
				_explode()

func _on_body_entered(body: Node) -> void:
	if current_state != State.FLYING:
		return
	if not is_instance_valid(body) or body.get("is_dead"):
		return
	
	# Don't hit shooter themselves immediately
	if body.name == str(shooter_id):
		return
	
	var is_enemy_or_dummy = (shooter_team == 0 or body.get("team_id") != shooter_team)
	
	if body is CharacterBody3D and is_enemy_or_dummy:
		_stick_to_target(body)
	elif body is StaticBody3D:
		var body_name = body.name.to_lower()
		if not body_name.contains("floor"):
			_stick_to_wall()

func is_multiplayer_match() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return false
	var main_node = get_tree().root.get_node_or_null("Main") if get_tree() else null
	if main_node and main_node.get("is_training_mode") == true:
		return false
	return multiplayer.get_peers().size() > 0

func _stick_to_target(target: CharacterBody3D) -> void:
	current_state = State.STUCK
	fuse_timer = fuse_duration
	stuck_target = target
	stuck_local_offset = Vector3(0, 0.85, 0)
	global_position = target.global_position + stuck_local_offset
	
	if is_multiplayer_match():
		sync_stick_state.rpc(target.get_path(), stuck_local_offset, global_position)
	else:
		sync_stick_state(target.get_path(), stuck_local_offset, global_position)

func _stick_to_wall() -> void:
	current_state = State.STUCK
	fuse_timer = fuse_duration
	stuck_target = null
	
	if is_multiplayer_match():
		sync_stick_state.rpc(NodePath(""), Vector3.ZERO, global_position)
	else:
		sync_stick_state(NodePath(""), Vector3.ZERO, global_position)

@rpc("any_peer", "call_local", "reliable")
func sync_stick_state(target_path: NodePath, local_offset: Vector3, stick_pos: Vector3) -> void:
	current_state = State.STUCK
	fuse_timer = fuse_duration
	global_position = stick_pos
	if target_path != NodePath(""):
		stuck_target = get_node_or_null(target_path) as Node3D
		stuck_local_offset = local_offset
	_setup_stuck_visuals()

func _setup_stuck_visuals() -> void:
	if indicator_mesh:
		indicator_mesh.visible = true
	
	if mesh_instance:
		var mat = mesh_instance.get_surface_override_material(0)
		if not mat:
			mat = StandardMaterial3D.new()
		else:
			mat = mat.duplicate()
		mat.albedo_color = Color(1.0, 0.2, 0.2, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.3, 0.1, 1.0)
		mat.emission_energy_multiplier = 4.0
		mesh_instance.set_surface_override_material(0, mat)
		
		var tw = create_tween().set_loops()
		tw.tween_property(mesh_instance, "scale", Vector3(1.3, 1.3, 1.3), 0.1)
		tw.tween_property(mesh_instance, "scale", Vector3(0.9, 0.9, 0.9), 0.1)

func _fizzle_and_free() -> void:
	if is_multiplayer_match():
		sync_fizzle.rpc()
	else:
		sync_fizzle()

@rpc("any_peer", "call_local", "reliable")
func sync_fizzle() -> void:
	current_state = State.EXPLODED
	var tw = create_tween()
	if mesh_instance:
		tw.tween_property(mesh_instance, "scale", Vector3(0.01, 0.01, 0.01), 0.15)
	tw.tween_callback(queue_free)

func _explode() -> void:
	if current_state == State.EXPLODED:
		return
	current_state = State.EXPLODED
	
	if is_multiplayer_match():
		sync_explode.rpc(global_position)
	else:
		sync_explode(global_position)

@rpc("any_peer", "call_local", "reliable")
func sync_explode(explode_pos: Vector3) -> void:
	global_position = explode_pos
	
	# Spawn explosion VFX ring
	var blast = Node3D.new()
	blast.top_level = true
	blast.global_position = explode_pos
	get_tree().root.add_child(blast)
	
	var blast_mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = aoe_radius
	cyl.bottom_radius = aoe_radius
	cyl.height = 0.5
	blast_mesh.mesh = cyl
	
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.15, 0.85, 1.0, 0.75)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.95, 1.0, 1.0)
	mat.emission_energy_multiplier = 5.0
	blast_mesh.material_override = mat
	blast.add_child(blast_mesh)
	
	var tw = blast.create_tween()
	tw.tween_property(blast_mesh, "scale", Vector3(1.2, 1.0, 1.2), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(blast.queue_free)
	
	if is_multiplayer_authority_or_offline():
		var players_container = get_tree().root.get_node_or_null("Main/Players")
		if players_container:
			for player in players_container.get_children():
				if player is Node3D and not player.get("is_dead"):
					var is_enemy = (player.name != str(shooter_id)) and (shooter_team == 0 or player.get("team_id") != shooter_team)
					if is_enemy:
						var to_p = player.global_position - explode_pos
						to_p.y = 0.0
						if to_p.length() <= aoe_radius:
							if player.has_method("take_damage"):
								player.take_damage(damage, shooter_id, BasePlayer.ActionType.ABILITY)
							var shooter = players_container.get_node_or_null(str(shooter_id))
							if shooter and shooter.has_method("_on_character_damage_dealt"):
								shooter._on_character_damage_dealt(player, damage, BasePlayer.ActionType.ABILITY)
	
	queue_free()
