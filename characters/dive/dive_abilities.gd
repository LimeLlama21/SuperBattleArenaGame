class_name DiveAbilities
extends RefCounted

static func get_abilities() -> Dictionary:
	return DiveData.create().abilities
