class_name DonutHitbox
extends CircleHitbox

var outer_radius: float:
	get: return radius
	set(val): radius = val

func _init() -> void:
	shape_type = AbilityPipeline.HitboxShape.DONUT
	min_distance = 2.0
	radius = 5.0
	height = 2.5

func is_point_in_outer_sweetspot(origin: Vector3, point: Vector3) -> bool:
	return is_point_inside(origin, Vector3.FORWARD, point)

func is_point_in_inner_circle(origin: Vector3, point: Vector3) -> bool:
	if height > 0.0 and abs(point.y - origin.y) > height:
		return false
	var diff = point - origin
	diff.y = 0.0
	var dist = diff.length()
	return dist < min_distance

