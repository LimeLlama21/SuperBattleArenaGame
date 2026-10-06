extends SceneTree

func _init():
	var cleo_scene = load("res://characters/cleodolinda/cleodolinda.tscn") as PackedScene
	var cleo = cleo_scene.instantiate()
	var ap = cleo.get_node("CharacterModel/AnimationPlayer") as AnimationPlayer
	for anim_name in ap.get_animation_list():
		var anim = ap.get_animation(anim_name)
		var max_t = 0.0
		for track_idx in range(anim.get_track_count()):
			for key_idx in range(anim.track_get_key_count(track_idx)):
				var t = anim.track_get_key_time(track_idx, key_idx)
				if t > max_t:
					max_t = t
		print(anim_name, " | length: ", anim.length, " | max_key_time: ", max_t, " | diff: ", anim.length - max_t)
	quit()
