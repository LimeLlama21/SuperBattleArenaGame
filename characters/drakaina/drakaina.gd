class_name Drakaina
extends BasePlayer

func _setup_character_kit() -> void:
	if character_name.is_empty() or character_name == "Character":
		character_name = "Drakaina"
	if display_name.is_empty() or display_name == "Character":
		display_name = "Kampé"
