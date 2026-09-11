class_name DonutHitbox
extends "res://ability/hitboxes/ability_hitbox.gd"

@export var inner_radius: float = 2.0
@export var outer_radius: float = 5.0
@export var height: float = 2.5

func _init() -> void:
	shape_type = AbilityPipeline.HitboxShape.DONUT

func is_point_inside(origin: Vector3, _facing: Vector3, point: Vector3) -> bool:
	if height > 0.0 and abs(point.y - origin.y) > height:
		return false
	var diff = point - origin
	diff.y = 0.0
	var dist = diff.length()
	return dist <= outer_radius

func is_point_in_outer_sweetspot(origin: Vector3, point: Vector3) -> bool:
	if height > 0.0 and abs(point.y - origin.y) > height:
		return false
	var diff = point - origin
	diff.y = 0.0
	var dist = diff.length()
	return dist >= inner_radius and dist <= outer_radius

func is_point_in_inner_circle(origin: Vector3, point: Vector3) -> bool:
	if height > 0.0 and abs(point.y - origin.y) > height:
		return false
	var diff = point - origin
	diff.y = 0.0
	var dist = diff.length()
	return dist < inner_radius

func create_indicator(fill_color: Color = AbilityIndicator.EMPTY_FILL, outline_color: Color = AbilityIndicator.WHITE_OUTLINE) -> Node3D:
	return AbilityIndicator.create_donut_indicator(inner_radius, outer_radius, fill_color, outline_color)

func update_indicator(indicator: Node3D, origin: Vector3, _facing: Vector3) -> void:
	if not indicator:
		return
	indicator.global_position = origin
