class_name CrushAbilities
extends RefCounted

static func get_abilities() -> Dictionary:
	return CrushData.create().abilities
