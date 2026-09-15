class_name SectorHitbox
extends CircleHitbox

func _init() -> void:
	shape_type = AbilityPipeline.HitboxShape.SECTOR
	radius = 4.0
	angle_deg = 90.0
	height = 2.5

