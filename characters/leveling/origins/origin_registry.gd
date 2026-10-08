class_name OriginRegistry
extends RefCounted

const CharacterOriginClass = preload("res://characters/leveling/origins/character_origin.gd")

static var _origins: Dictionary = {}
static var _initialized: bool = false

static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true

	# Register Mortal
	var mortal = CharacterOriginClass.new()
	mortal.id = CharacterOriginClass.ID_MORTAL
	mortal.display_name = "Mortal"
	mortal.description = "Born of flesh and blood; master of mortal limits, ingenuity, and unyielding will."
	mortal.theme_color = Color(0.95, 0.65, 0.3, 1.0) # Warm bronze/amber
	_origins[mortal.id] = mortal

	# Register Divine
	var divine = CharacterOriginClass.new()
	divine.id = CharacterOriginClass.ID_DIVINE
	divine.display_name = "Divine"
	divine.description = "Carriers of heavenly light and sacred sovereignty; wielding radiance, authority, and destiny."
	divine.theme_color = Color(0.35, 0.8, 1.0, 1.0) # Radiant cyan / gold-tinged sky
	_origins[divine.id] = divine

	# Register Monstrous
	var monstrous = CharacterOriginClass.new()
	monstrous.id = CharacterOriginClass.ID_MONSTROUS
	monstrous.display_name = "Monstrous"
	monstrous.description = "Beasts of primordial hunger, eldritch dread, and untamed fury."
	monstrous.theme_color = Color(0.85, 0.25, 0.35, 1.0) # Primal crimson / corruption
	_origins[monstrous.id] = monstrous

static func register_origin(origin: CharacterOrigin) -> void:
	_ensure_initialized()
	if origin and not origin.id.is_empty():
		_origins[origin.id.to_lower()] = origin

static func get_origin(val: Variant) -> CharacterOrigin:
	_ensure_initialized()
	var norm = CharacterOriginClass.normalize_id(val)
	return _origins.get(norm, null)

static func is_valid_origin(val: Variant) -> bool:
	_ensure_initialized()
	var norm = CharacterOriginClass.normalize_id(val)
	return _origins.has(norm)

static func get_all_origins() -> Array[CharacterOrigin]:
	_ensure_initialized()
	var list: Array[CharacterOrigin] = []
	for key in [CharacterOriginClass.ID_MORTAL, CharacterOriginClass.ID_DIVINE, CharacterOriginClass.ID_MONSTROUS]:
		if _origins.has(key):
			list.append(_origins[key])
	for key in _origins.keys():
		var orig = _origins[key]
		if not list.has(orig):
			list.append(orig)
	return list

static func get_all_origin_ids() -> Array[String]:
	_ensure_initialized()
	var ids: Array[String] = []
	for orig in get_all_origins():
		ids.append(orig.id)
	return ids
