class_name CharacterRegistry
extends RefCounted

const CharacterDataClass = preload("res://characters/character_data.gd")

# Registry storage: key -> { "data": CharacterData, "scene": PackedScene }
static var _registry: Dictionary = {}
static var _initialized: bool = false

static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	
	# Pre-register built-in character factory functions / scenes
	_register_builtin("poke", "res://characters/poke/poke_data.gd", "res://characters/poke/poke.tscn")
	_register_builtin("crush", "res://characters/crush/crush_data.gd", "res://characters/crush/crush.tscn")
	_register_builtin("asparsas", "res://characters/asparsas/asparsas_data.gd", "res://characters/asparsas/asparsas.tscn")
	_register_builtin("reaper", "res://characters/reaper/reaper_data.gd", "res://characters/reaper/reaper.tscn")
	_register_builtin("morrigan", "res://characters/morrigan/morrigan_data.gd", "res://characters/morrigan/morrigan.tscn")
	_register_builtin("monkey", "res://characters/monkey/monkey_data.gd", "res://characters/monkey/monkey.tscn")
	_register_builtin("silene", "res://characters/silene/silene_data.gd", "res://characters/silene/silene.tscn")
	_register_builtin("artist", "res://characters/artist/artist_data.gd", "res://characters/artist/artist.tscn")
	_register_builtin("cleodolinda", "res://characters/cleodolinda/cleodolinda_data.gd", "res://characters/cleodolinda/cleodolinda.tscn")
	_registry["cleo"] = _registry["cleodolinda"]

static func _register_builtin(key: String, data_script_path: String, scene_path: String) -> void:
	var data: CharacterData = null
	if ResourceLoader.exists(data_script_path):
		var script = load(data_script_path)
		if script and script.has_method("create"):
			data = script.create()
	if data and data.id.is_empty():
		data.id = key.to_lower()
	var scene: PackedScene = null
	if ResourceLoader.exists(scene_path):
		scene = load(scene_path) as PackedScene
	
	_registry[key.to_lower()] = {
		"data": data,
		"scene": scene,
		"data_script": data_script_path,
		"scene_path": scene_path
	}

static func register_character(key: String, data: CharacterData, scene: PackedScene = null) -> void:
	_ensure_initialized()
	if data and data.id.is_empty():
		data.id = key.to_lower()
	_registry[key.to_lower()] = {
		"data": data,
		"scene": scene
	}

static func has_character(key: String) -> bool:
	_ensure_initialized()
	return _registry.has(key.to_lower())

static func get_character_data(key: String) -> CharacterData:
	_ensure_initialized()
	var entry = _registry.get(key.to_lower())
	if entry:
		var d = entry.get("data")
		if d:
			if d.id.is_empty():
				d.id = key.to_lower()
			return d
		# Fallback: recreate via script if needed
		var s_path = entry.get("data_script", "")
		if not s_path.is_empty() and ResourceLoader.exists(s_path):
			var scr = load(s_path)
			if scr and scr.has_method("create"):
				var created = scr.create()
				if created and created.id.is_empty():
					created.id = key.to_lower()
				entry["data"] = created
				return created
	return null

static func get_character_scene(key: String) -> PackedScene:
	_ensure_initialized()
	var entry = _registry.get(key.to_lower())
	if entry:
		var sc = entry.get("scene")
		if sc:
			return sc
		var s_path = entry.get("scene_path", "")
		if not s_path.is_empty() and ResourceLoader.exists(s_path):
			var loaded = load(s_path) as PackedScene
			entry["scene"] = loaded
			return loaded
	# Fallback to universal player scene if no custom scene is assigned
	if ResourceLoader.exists("res://player/player.tscn"):
		return load("res://player/player.tscn") as PackedScene
	return null

static func get_all_character_keys() -> Array[String]:
	_ensure_initialized()
	var unique_keys: Array[String] = []
	var canonical = ["poke", "crush", "asparsas", "reaper", "morrigan", "monkey", "silene", "artist", "cleodolinda"]
	for k in canonical:
		if _registry.has(k) and not unique_keys.has(k):
			unique_keys.append(k)
	for k in _registry.keys():
		if not unique_keys.has(k):
			unique_keys.append(k)
	return unique_keys

static func get_display_name(key: String) -> String:
	var k = key.to_lower()
	var data = get_character_data(k)
	if data and not data.display_name.is_empty():
		return data.display_name
	
	match k:
		"poke": return "Arash"
		"crush": return "Heracles"
		"asparsas": return "Urvashi"
		"reaper": return "Keres"
		"morrigan": return "Morrigan"
		"monkey": return "The Great Sage"
		"silene": return "Saint Silene"
		"artist": return "The Painted Sage"
		"cleodolinda": return "Cleo"
		"cleo": return "Cleo"
		"dummy": return "Training Dummy"
		_:
			if data and not data.character_name.is_empty():
				return data.character_name
			return key.capitalize()

static func get_character_id_by_display_name(name_or_key: String) -> String:
	_ensure_initialized()
	var clean = name_or_key.strip_edges().to_lower()
	for k in get_all_character_keys():
		if k.to_lower() == clean:
			return k
		if get_display_name(k).to_lower() == clean:
			return k
	return clean

static func create_player_instance(key: String) -> BasePlayer:
	_ensure_initialized()
	var k = key.to_lower()
	var scene = get_character_scene(k)
	var player: BasePlayer = null
	if scene:
		player = scene.instantiate() as BasePlayer
	if not player and ResourceLoader.exists("res://player/player.tscn"):
		var base_sc = load("res://player/player.tscn") as PackedScene
		player = base_sc.instantiate() as BasePlayer
	
	if player:
		player.id = k
		var data = get_character_data(k)
		if data:
			player.load_character_data(data)
		if player.id.is_empty():
			player.id = k
		if player.display_name.is_empty() or player.display_name == "Character":
			player.display_name = get_display_name(k)
	return player

static func get_enabled_character_keys() -> Array[String]:
	var script = load("res://characters/enabled_characters.gd")
	if script and script.has_method("get_enabled_characters"):
		return script.get_enabled_characters()
	return get_all_character_keys()

static func is_character_enabled(key: String) -> bool:
	var script = load("res://characters/enabled_characters.gd")
	if script and script.has_method("is_character_enabled"):
		return script.is_character_enabled(key)
	return has_character(key)

static func get_characters_by_origin(origin_val: Variant) -> Array[String]:
	_ensure_initialized()
	var norm = CharacterOrigin.normalize_id(origin_val)
	var matches: Array[String] = []
	for key in get_all_character_keys():
		var data = get_character_data(key)
		if data and data.has_origin(norm):
			matches.append(key)
	return matches

static func get_character_origins(character_key: String) -> Array[String]:
	_ensure_initialized()
	var data = get_character_data(character_key)
	if data:
		return data.get_origins()
	return []

static func character_has_origin(character_key: String, origin_val: Variant) -> bool:
	_ensure_initialized()
	var data = get_character_data(character_key)
	if data:
		return data.has_origin(origin_val)
	return false
