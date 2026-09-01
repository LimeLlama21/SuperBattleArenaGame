class_name ReaperAbilities
extends RefCounted

static func get_abilities() -> Dictionary:
	return ReaperData.create().abilities
