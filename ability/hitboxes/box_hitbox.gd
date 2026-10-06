class_name BoxHitbox
extends "res://ability/hitboxes/ability_hitbox.gd"

var width: float = 2.0
var length: float = 4.0
var height: float = 2.5

func _init() -> void:
	shape_type = AbilityPipeline.HitboxShape.BOX

func is_point_inside(origin: Vector3, facing: Vector3, point: Vector3, target_radius: float = 0.0) -> bool:
	var dy = abs(point.y - origin.y)
	if height > 0.0 and dy > height:
		return false
	var f = facing
	f.y = 0.0
	if f.length_squared() < 0.001:
		f = Vector3.FORWARD
	f = f.normalized()
	
	var to_point = point - origin
	to_point.y = 0.0
	var along = to_point.dot(f)
	if along < -target_radius or along > (length + target_radius):
		return false
	var proj = f * clamp(along, 0.0, length)
	var lat = (to_point - proj).length()
	return lat <= (width * 0.5 + target_radius)

func create_indicator(fill_color: Color = AbilityIndicator.EMPTY_FILL, outline_color: Color = AbilityIndicator.WHITE_OUTLINE) -> Node3D:
	return AbilityIndicator.create_line_indicator(length, width, fill_color, outline_color, false, 1.0, true)

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
	AbilityIndicator.update_line_indicator(indicator, origin, rot_y)
