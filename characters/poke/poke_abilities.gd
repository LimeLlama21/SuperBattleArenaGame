class_name PokeAbilities
extends RefCounted

static func get_abilities() -> Dictionary:
	return PokeData.create().abilities
