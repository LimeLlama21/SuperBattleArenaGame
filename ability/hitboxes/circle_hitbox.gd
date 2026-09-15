class_name CircleHitbox
extends "res://ability/hitboxes/ability_hitbox.gd"

@export var radius: float = 3.0
@export var height: float = 2.5
@export var angle_deg: float = 360.0
@export var annul: Variant = false

func _init() -> void:
	shape_type = AbilityPipeline.HitboxShape.CIRCLE

func get_annul_radius(caster: Node = null) -> float:
	if annul is bool:
		if not annul:
			return 0.0
		var c = caster if is_instance_valid(caster) else current_caster
		if not is_instance_valid(c):
			var p = get_parent()
			while is_instance_valid(p):
				if p.has_method("get_hitbox_radius"):
					c = p
					break
				p = p.get_parent()
		if is_instance_valid(c) and c.has_method("get_hitbox_radius"):
			return c.get_hitbox_radius()
		return 0.4
	elif (annul is float or annul is int) and annul > 0.0:
		return float(annul)
	return 0.0

func is_point_inside(origin: Vector3, facing: Vector3, point: Vector3) -> bool:
	if height > 0.0 and abs(point.y - origin.y) > height:
		return false
	var diff = point - origin
	diff.y = 0.0
	var dist = diff.length()
	if dist > radius:
		return false
	
	var inner_r = get_annul_radius()
	if inner_r > 0.0 and dist < inner_r:
		return false

	if angle_deg < 360.0:
		if inner_r <= 0.0 and dist <= 0.8:
			return true
		var f = facing
		f.y = 0.0
		if f.length_squared() < 0.001:
			f = Vector3.FORWARD
		f = f.normalized()
		var dir_to_point = diff.normalized()
		var dot = clamp(f.dot(dir_to_point), -1.0, 1.0)
		var angle_to_point = rad_to_deg(acos(dot))
		return angle_to_point <= (angle_deg * 0.5)
	return true

func create_indicator(fill_color: Color = AbilityIndicator.EMPTY_FILL, outline_color: Color = AbilityIndicator.WHITE_OUTLINE) -> Node3D:
	var inner_r = get_annul_radius()
	if inner_r > 0.0:
		if angle_deg < 360.0:
			return AbilityIndicator.create_sector_indicator(radius, angle_deg, fill_color, outline_color, inner_r)
		return AbilityIndicator.create_donut_indicator(inner_r, radius, fill_color, outline_color)
	if angle_deg < 360.0:
		return AbilityIndicator.create_sector_indicator(radius, angle_deg, fill_color, outline_color, 0.0)
	return AbilityIndicator.create_circle_indicator(radius, fill_color, outline_color)

func update_indicator(indicator: Node3D, origin: Vector3, facing: Vector3) -> void:
	if not indicator:
		return
	indicator.global_position = origin
	if angle_deg < 360.0:
		var aim_dir = facing
		aim_dir.y = 0.0
		if aim_dir.length_squared() > 0.001:
			aim_dir = aim_dir.normalized()
		else:
			aim_dir = Vector3.FORWARD
		var rot_y = atan2(-aim_dir.x, -aim_dir.z)
		indicator.rotation.y = rot_y
