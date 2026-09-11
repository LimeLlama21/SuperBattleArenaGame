class_name AbilityHitbox
extends Node

@export var shape_type: AbilityPipeline.HitboxShape = AbilityPipeline.HitboxShape.NONE

func get_targets_in_hitbox(caster: Node, origin: Vector3, facing: Vector3, scene_tree: SceneTree) -> Array[Node]:
	var hit_targets: Array[Node] = []
	if not is_instance_valid(caster) or not scene_tree:
		return hit_targets
	
	var caster_team = caster.team_id if "team_id" in caster else 0
	var candidate_pool: Array = []
	
	var players_group = scene_tree.get_nodes_in_group("players")
	for p in players_group:
		if not candidate_pool.has(p):
			candidate_pool.append(p)
			
	if scene_tree.root:
		var players_container = scene_tree.root.get_node_or_null("Main/Players")
		if players_container:
			for child in players_container.get_children():
				if not candidate_pool.has(child):
					candidate_pool.append(child)
					
	for p in candidate_pool:
		if not is_instance_valid(p) or p == caster:
			continue
		if "is_dead" in p and p.is_dead:
			continue
		if "team_id" in p and p.team_id == caster_team and caster_team != 0:
			continue
		# Evaluate candidate's actual physical vertical bounds (not the infinite CombatHitbox)
		var entity_bottom: float = p.global_position.y
		var entity_top: float = p.global_position.y + 1.8
		var phys_col = p.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if phys_col and phys_col.shape:
			var col_center_y = phys_col.global_position.y
			var h: float = 1.8
			if phys_col.shape is CapsuleShape3D or phys_col.shape is CylinderShape3D:
				h = phys_col.shape.height
			elif phys_col.shape is BoxShape3D:
				h = phys_col.shape.size.y
			entity_bottom = col_center_y - h * 0.5
			entity_top = col_center_y + h * 0.5
		
		# Find the closest point in Y on the entity's physical bounds to the cast origin
		var closest_y: float = clamp(origin.y, entity_bottom, entity_top)
		var check_pos = Vector3(p.global_position.x, closest_y, p.global_position.z)
		if is_point_inside(origin, facing, check_pos):
			hit_targets.append(p)
	return hit_targets

func is_point_inside(_origin: Vector3, _facing: Vector3, _point: Vector3) -> bool:
	return false

func create_indicator(_fill_color: Color = AbilityIndicator.EMPTY_FILL, _outline_color: Color = AbilityIndicator.WHITE_OUTLINE) -> Node3D:
	return null

func update_indicator(_indicator: Node3D, _origin: Vector3, _facing: Vector3) -> void:
	pass
