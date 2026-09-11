class_name SectorHitbox
extends "res://ability/hitboxes/ability_hitbox.gd"

@export var radius: float = 4.0
@export var angle_deg: float = 90.0
@export var height: float = 2.5

func _init() -> void:
	shape_type = AbilityPipeline.HitboxShape.SECTOR

func is_point_inside(origin: Vector3, facing: Vector3, point: Vector3) -> bool:
	var dy = abs(point.y - origin.y)
	if dy > height:
		return false
	
	var f = facing
	f.y = 0.0
	if f.length_squared() < 0.001:
		f = Vector3.FORWARD
	f = f.normalized()
	
	var diff = point - origin
	diff.y = 0.0
	var dist = diff.length()
	if dist > radius:
		return false
	if dist <= 0.8:
		return true
	
	var dir_to_point = diff.normalized()
	var dot = clamp(f.dot(dir_to_point), -1.0, 1.0)
	var angle_to_point = rad_to_deg(acos(dot))
	return angle_to_point <= (angle_deg * 0.5)

func create_indicator(fill_color: Color = AbilityIndicator.EMPTY_FILL, outline_color: Color = AbilityIndicator.WHITE_OUTLINE) -> Node3D:
	return AbilityIndicator.create_sector_indicator(radius, angle_deg, fill_color, outline_color)

func update_indicator(indicator: Node3D, origin: Vector3, facing: Vector3) -> void:
	if not indicator:
		return
	var aim_dir = facing
	aim_dir.y = 0.0
	if aim_dir.length_squared() > 0.001:
		aim_dir = aim_dir.normalized()
	else:
		aim_dir = Vector3.FORWARD
	var rot_y = atan2(-aim_dir.x, -aim_dir.z)
	indicator.global_position = origin
	indicator.rotation.y = rot_y
