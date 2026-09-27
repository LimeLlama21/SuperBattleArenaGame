class_name Cleodolinda
extends BasePlayer

const CleodolindaData = preload("res://characters/cleodolinda/cleodolinda_data.gd")

func _ready() -> void:
	super._ready()
	_play_model_animation("Idle")

func _setup_character_kit() -> void:
	if id.is_empty():
		id = "Cleodolinda"
	if character_name.is_empty() or character_name == "Character":
		character_name = "Cleodolinda"
	if display_name.is_empty() or display_name == "Character":
		display_name = "Cleo"

	var data = CleodolindaData.create()
	load_character_data(data)

	if id.is_empty():
		id = "Cleodolinda"
	if display_name.is_empty() or display_name == "Character":
		display_name = "Cleo"

func _play_model_animation(anim_name: String) -> void:
	var model = get_node_or_null("CharacterModel")
	if model:
		var anim_player = model.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if anim_player and anim_player.has_animation(anim_name):
			anim_player.play(anim_name)
