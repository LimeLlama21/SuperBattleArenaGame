extends StaticBody3D

@export var lifetime: float = 5.0
var owner_id: int = 0
var _is_despawning: bool = false

func _ready() -> void:
	# Smooth rise animation
	var target_y = position.y
	position.y -= 3.0
	var tween = create_tween()
	if tween:
		tween.tween_property(self, "position:y", target_y, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if multiplayer.is_server():
		get_tree().create_timer(lifetime).timeout.connect(_despawn)

func _despawn() -> void:
	if _is_despawning or not is_inside_tree():
		return
	_is_despawning = true
	var tween = create_tween()
	if tween:
		tween.tween_property(self, "position:y", position.y - 3.5, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(queue_free)
	else:
		queue_free()
