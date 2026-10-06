class_name CylinderHitbox
extends "res://ability/hitboxes/ability_hitbox.gd"

var radius: float = 4.0
var height: float = 3.0

func _init() -> void:
	shape_type = AbilityPipeline.HitboxShape.CYLINDER

func is_point_inside(origin: Vector3, _facing: Vector3, point: Vector3, target_radius: float = 0.0) -> bool:
	var dy = abs(point.y - origin.y)
	if height > 0.0 and dy > height:
		return false
	var diff = point - origin
	diff.y = 0.0
	return diff.length() <= (radius + target_radius)

func create_indicator(fill_color: Color = AbilityIndicator.EMPTY_FILL, outline_color: Color = AbilityIndicator.WHITE_OUTLINE) -> Node3D:
	return AbilityIndicator.create_circle_indicator(radius, fill_color, outline_color)

func update_indicator(indicator: Node3D, origin: Vector3, _facing: Vector3) -> void:
	if not indicator:
		return
	indicator.global_position = origin
